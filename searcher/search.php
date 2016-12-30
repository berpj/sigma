<?php
  $time_start = microtime(true);

  require('stemming.php');


  // Errors

  if (getenv('SHOW_ERRORS') == 'True') {
    error_reporting(E_ALL);
    ini_set('display_errors', 1);
  } else {
    error_reporting(0);
    ini_set('display_errors', 0);
  }

  if (!isset($_GET['q']) || trim($_GET['q']) == '' || !isset($_GET['page']) || trim($_GET['page']) == '')
    die();


  // Init

  $redis_address = getenv('REDIS_ADDRESS');
  $redis_port = getenv('REDIS_PORT');

  $redis = new Redis();
  $redis->connect($redis_address, $redis_port, 2);

  setlocale(LC_CTYPE, 'en_US.UTF-8');

  $data = [
    'count' => '0',
    'time' => 0,
    'results' => []
  ];


  // Keywords normalization

  $keywords = explode(' ', trim($_GET['q']));
  $keywords = array_unique($keywords);

  foreach ($keywords as $key => $value) {

    $keywords[$key] = trim(strtolower($value));
    $keywords[$key] = iconv("UTF-8", "ASCII//TRANSLIT//IGNORE", $value);

    if (preg_match('/[^a-z0-9$]/', $keywords[$key])) {
      unset($keywords[$key]);
      continue;
    }

    $keywords[$key] = PorterStemmer::Stem($value); // Stemming
  }

  if (count($keywords) == 0) {
    echo $_GET['callback']."(".json_encode($data).")";
    return;
  }


  // Try to get the result for this query from redis
  $key = "results_" . $_GET['page'] . '_' . implode("_", $keywords);

  $tmp_result = $redis->get($key);

  if ($tmp_result) {
    $tmp_result = json_decode($tmp_result);

    $data['results'] = $tmp_result;

    $key_count = "results_counts_" . implode("_", $keywords);

    $data['count'] = $redis->get($key_count);
  } else {
    // DB

    $db_hostname = getenv('DB_HOSTNAME');
    $db_username = getenv('DB_USERNAME');
    $db_password = getenv('DB_PASSWORD');
    $db_name = getenv('DB_NAME');
    $db_port = getenv('DB_PORT');

    $pg = pg_connect("host=$db_hostname port=$db_port dbname=$db_name user=$db_username password=$db_password") or die ("Could not connect to server\n");


    // Intersect redis ordered sets to get only the docs matching all keywords

    $tmp_results_array = Array();

    $key = "inters_" . implode("_", $keywords);

    $sets = Array();

    $i = 0;
    foreach ($keywords as $keyword) {
      if ($i++ == 16) //max number of keywords
        break;

      $sets[] = "words_$keyword";

      $i++;
    }

    $redis->zInter($key, $sets);

    $doc_ids = $redis->zRevRange($key, 0, 999, true); // Get the top 1000 docs

    $redis->del($key); // Delete tmp inter set

    $data['count'] = count($doc_ids);
    if (count($doc_ids) == 1000)
      $data['count'] .= '+';


    // Get pageranks for these doc_ids from Redis
    foreach ($doc_ids as $key => $value) {
      $pagerank = $redis->hGet("pageranks_$key", 'pagerank');

      $data['results'][] = array('doc_id' => $key, 'pagerank' => $pagerank, 'position_quality' => round($value, 3), 'url' => null, 'title' => null);
    }


    // Scale Pagerank (between 0 and 1)
    if ($data['results']) {
      $max_pagerank = max(array_column($data['results'], 'pagerank'));
      if ($max_pagerank == 0)
        $max_pagerank = 1;
      foreach ($data['results'] as $key => $value) {
        $data['results'][$key]['pagerank'] /= $max_pagerank;
        $data['results'][$key]['pagerank'] = round($data['results'][$key]['pagerank'], 3);
        if ($data['results'][$key]['pagerank'] == 0)
          $data['results'][$key]['pagerank'] = 0.15;
      }
    }


    // Order by score
    uasort($data['results'], function($a, $b) { //or usort?
      return $a['pagerank'] * $a['position_quality'] <= $b['pagerank'] * $b['position_quality'];
    });


    // Only keep the first 10 elements
    $data['results'] = array_slice($data['results'], 10 * $_GET['page'], 10);


    // Get metadata for these doc_ids from PG
    foreach ($data['results'] as $key => $value) {
      $query = "SELECT url, title, description, lang FROM doc_index WHERE doc_id=$value[doc_id]";
      $rs = pg_query($pg, $query) or die("Error\n");
      $row = pg_fetch_row($rs);

      $url = $row[0];
      $domain = parse_url($url)['host'];
      $title = $row[1];
      $description = $row[2];
      $lang = $row[3];

      $data['results'][$key]['url'] = $url;
      $data['results'][$key]['domain'] = $domain;
      $data['results'][$key]['title'] = $title;

      if ($lang)
        $data['results'][$key]['lang'] = $lang;
      else
        $data['results'][$key]['lang'] = '?';

      if ($description)
        $data['results'][$key]['description'] = $description;
      else
        $data['results'][$key]['description'] = 'No description';

      if ($title)
        $data['results'][$key]['title'] = $title;
      else
        $data['results'][$key]['title'] = $url;
    }


    // Cache result for next queries

    $key = "results_" . $_GET['page'] . '_' . implode("_", $keywords);
    $key_count = "results_counts_" . implode("_", $keywords);

    $redis->setEx($key, getenv('SEARCH_RESULTS_CACHE_EXPIRATION'), json_encode($data['results'])); // Sets value with a time to live
    $redis->setEx($key_count, getenv('SEARCH_RESULTS_CACHE_EXPIRATION'), $data['count']);
  }


  // End time

  $time_end = microtime(true);
  $data['time'] =  round(($time_end - $time_start) * 1000, 0) . 'ms';


  // Output results in JSON

  echo $_GET['callback']."(".json_encode($data).")";
?>
