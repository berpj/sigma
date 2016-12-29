<?php
  $time_start = microtime(true);

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
  }

  if (count($keywords) == 0) {
    echo $_GET['callback']."(".json_encode($data).")";
    return;
  }


  // DB

  $db_hostname = getenv('DB_HOSTNAME');
  $db_username = getenv('DB_USERNAME');
  $db_password = getenv('DB_PASSWORD');
  $db_name = getenv('DB_NAME');
  $db_port = getenv('DB_PORT');

  $pg = pg_connect("host=$db_hostname port=$db_port dbname=$db_name user=$db_username password=$db_password") or die ("Could not connect to server\n");


  // Get the top 1000 docs for each keyword

  $tmp_results_array = Array();

  $i = 0;
  foreach ($keywords as $keyword) {
    if ($i++ == 16) //max number of keywords
      break;

    $doc_ids = Array();

    $redis_address = getenv('REDIS_ADDRESS');
    $redis_port = getenv('REDIS_PORT');

    $redis = new Redis();
    $redis->connect($redis_address, $redis_port, 2);

    $results = Array();

    // Get the first 100,000 doc_ids for this keyword from Redis
    $doc_ids = $redis->zRevRange("words_$keyword", 0, 100000, true);

    $tmp_results_array[] = $doc_ids;
  }


  // Intersect results

  $doc_ids = [];
  foreach ($tmp_results_array[0] as $key => $value) {
    $count = 0.0;
    $score = 0.0;
    foreach ($tmp_results_array as $key2 => $value2) {
      if (array_key_exists($key, $tmp_results_array[$key2])) {
        $score += $tmp_results_array[$key2][$key];
        $count++;
      }
    }

    if ($count == count($tmp_results_array)) {
      $score /= $count;
      $doc_ids[$key] = $score;
    }
  }

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


  // End time

  $time_end = microtime(true);
  $data['time'] =  round(($time_end - $time_start) * 1000, 0) . 'ms';


  // Output results in JSON

  echo $_GET['callback']."(".json_encode($data).")";
?>
