<?php
  $db_hostname = getenv('DB_HOSTNAME');
  $db_username = getenv('DB_USERNAME');
  $db_password = getenv('DB_PASSWORD');
  $db_name = getenv('DB_NAME');
  $db_port = getenv('DB_PORT');

  $pg = pg_connect("host=$db_hostname port=$db_port dbname=$db_name user=$db_username password=$db_password") or die ("Could not connect to server\n");

  error_reporting(E_ALL);
  ini_set('display_errors', 1);
?>

<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Sigma Search Engine</title>
  <meta name="description" content="Homemade full-scale web search engine.">
  <link href="data:image/x-icon;base64,AAABAAEAEBAAAAAAAABoBQAAFgAAACgAAAAQAAAAIAAAAAEACAAAAAAAAAEAAAAAAAAAAAAAAAEAAAAAAAAAAAAA////AN3d3QB4eHgAu7u7AP7+/gBWVlYAmZmZAHd3dwC6uroAMzMzABEREQAyMjIA7u7uAHV1dQDMzMwAZ2dnAKqqqgCIiIgAIyMjAGZmZgABAQEAREREAIeHhwAiIiIAZWVlAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAABUAFRUAAAwAAAAAAAAKFQAAFQAAFRUVAAAAAAAAAgwNAAAAAAAJGAIAAAAAAAAPCgAAAAAAAAkRAAAAAAAAAAcZAAAAAAAAAAAAAAAAAAAAAxcBAAAAAAAAAAAAAAAAAAAGCQEAAAAAAAAAAAAAAAAAFgsCAAAAAAAAAAAAAAAACAAGAAAAAAAAAAAAAAAABwATDQAAAAAAAAAAAAAADxULAgAAAAAAAAAAAAAAAgsABAAAAAAAEgEAAAAAAAoAEgAAAAAAEhAFAAAAABQVABUAAAAAFQAOAQAAAAAAAAAAAAAAAAAAAAAAAP//AADABwAA4AcAAOPjAADz8wAA+f8AAPx/AAD+PwAA/j8AAPx/AAD4fwAA8P8AAOHzAADj4wAAwAMAAP//AAA=" rel="icon" type="image/x-icon" />
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/4.0.0-alpha.4/css/bootstrap.css">
  <link href="https://maxcdn.bootstrapcdn.com/font-awesome/4.7.0/css/font-awesome.min.css" rel="stylesheet" integrity="sha384-wvfXpqpZZVQGK6TAh5PVlGOfQNHSoD2xbE+QkPxCAFlNEevoEH3Sl0sibVcOQVnN" crossorigin="anonymous">
  <script src="/algolia.js"></script>
  <style>
    h1 {
      font-size: 3.6em;
    }
    #query {
      margin-top: 40px;
      margin-bottom: 50px;
    }
    #results {
      margin-bottom: 60px;
    }
    #footer {
      margin-top: 30px;
    }
    body {
      text-align: center;
      margin: 30px;
    }
  </style>
</head>
<body>
  <h1>&Sigma;</h1>

  <div id="query">
    <form action="/">
      <input type="text" name="q" autofocus="autofocus" class="form-control" style="width: 450px; margin: auto" value="<? if (isset($_GET['q'])) echo $_GET['q'] ?>">
    </form>
  </div>

  <div id="results">
  <?php
    if (isset($_GET['q']) && $_GET['q'] != '') {
      $time_start = microtime(true);

      $query = explode(' ', $_GET['q'])[0];

      $query = strtolower($query);
      setlocale(LC_CTYPE, 'en_US.UTF-8');
      $query = iconv("UTF-8", "ASCII//TRANSLIT//IGNORE", $query);

      $redis_address = getenv('REDIS_ADDRESS');
      $redis_port = getenv('REDIS_PORT');

      $redis = new Redis();
      $redis->connect($redis_address, $redis_port, 2);

      $results = Array();

      // Get top doc_ids for this query from Redis
      $doc_ids = $redis->zRevRange("words_$query", 0, 7, true);

      if (! is_array($doc_ids)) {
        $doc_ids = Array();
      }

      // Get pageranks for these doc_ids from Redis
      foreach ($doc_ids as $key => $value) {
        $pagerank = $redis->hGet("pageranks_$key", 'pagerank');

        $results[] = array('doc_id' => $key, 'pagerank' => $pagerank, 'position' => $value, 'url' => null, 'title' => null);
      }

      // Get metadata for these doc_ids from PG
      foreach ($results as $key => $value) {
        $query = "SELECT url, title FROM doc_index WHERE doc_id=$value[doc_id]";
        $rs = pg_query($pg, $query) or die("Error\n");
        $row = pg_fetch_row($rs);

        $url = $row[0];
        $title = $row[1];

        $results[$key]['url'] = $url;
        $results[$key]['title'] = $title;
      }

      // Order by score
      uasort($results, function($a, $b) { //or usort?
        return $a['pagerank'] + $a['position'] <= $b['pagerank'] + $b['position'];
      });

      // Print results
      $results = array_slice($results, 0, 16);

      $time_end = microtime(true);

      foreach ($results as $key => $value) {
        echo '<a href="' . $value['url'] . '">' . $value['title'] . '</a><br>' . $value['url'] . ' <span class="text-muted">(score: ' . round($value['position'] + $value['pagerank'], 3) . ')</span><br><br>';
      }
      if (!$results) {
        echo 'No result<br>';
      }

      $redis->close();

      echo '<br><p class="text-muted">Query time: ' . (round($time_end - $time_start, 3)) . 's</p>';
    }
  ?>
  </div>

  <div id="stats">
    <?php
      function nice_number($n) {
          $n = (0+str_replace(",", "", $n));

          if (!is_numeric($n)) return false;
          elseif ($n > 1000000) return round(($n / 1000000), 1) . 'M';
          elseif ($n > 1000) return round(($n / 1000), 0) . 'k';

          return number_format($n);
      }

      $query = "SELECT reltuples FROM pg_class WHERE oid = 'public.doc_index'::regclass;";
      $rs = pg_query($pg, $query) or die("Error\n");
      $row = pg_fetch_row($rs);

      echo  "<strong>Pages indexed:</strong> " . nice_number($row[0]) . "<br>";


      $query = "SELECT reltuples FROM pg_class WHERE oid = 'public.repository'::regclass;";
      $rs = pg_query($pg, $query) or die("Error\n");
      $row = pg_fetch_row($rs);

      echo  "<strong>Pages crawled:</strong> " . nice_number($row[0]) . "<br>";


      $query = "SELECT COUNT(*) FROM doc_index WHERE status='OK' AND parsed_at > ROUND(extract(epoch from now())) - 120";
      $rs = pg_query($pg, $query) or die("Error\n");
      $row = pg_fetch_row($rs);

      echo  "<strong>Crawling speed:</strong> " . round($row[0] / 120, 1) . "/s<br>";

      pg_close($pg);
    ?>
  </p>

  <div id="footer">
    Not a search engine - Code available on <a href="https://github.com/berpj/sigma" target="_blank"><i class="fa fa-github"></i> Github</a><br>
    v0.4
  </div>
</body>
</html>
