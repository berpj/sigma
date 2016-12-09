<?php
  $db_hostname = getenv('DB_HOSTNAME');
  $db_username = getenv('DB_USERNAME');
  $db_password = getenv('DB_PASSWORD');
  $db_name = getenv('DB_NAME');
  $db_port = getenv('DB_PORT');

  $pg = pg_connect("host=$db_hostname port=$db_port dbname=$db_name user=$db_username password=$db_password") or die ("Could not connect to server\n");

  if (getenv('SHOW_ERRORS') == 'True') {
    error_reporting(E_ALL);
    ini_set('display_errors', 1);
  } else {
    error_reporting(0);
    ini_set('display_errors', 0);
  }
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
  <style>
    h1 {
      font-size: 3.6em;
      text-align: center;
    }
    #query {
      margin-top: 40px;
      margin-bottom: 30px;
    }
    #results {
      margin-bottom: 40px;
      word-break: break-all;
    }
    #results strong {
      font-weight: 500;
    }
    #stats {
      text-align: center;
    }
    #footer {
      margin-top: 30px;
      text-align: center;
    }
    body {
      margin: 30px;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>&Sigma;</h1>

    <div class="row">
      <div id="query" class="col-md-8 offset-md-2">
        <form action="/">
          <input placeholder="Search" type="text" name="q" <?php if (! isset($_GET['q']) || ! trim($_GET['q']) != '') { echo 'autofocus="autofocus"'; } ?> class="form-control" value="<? if (isset($_GET['q'])) echo $_GET['q'] ?>">
        </form>

        <?php
          if (isset($_GET['q']) && trim($_GET['q']) != '') {
            $time_start = microtime(true);

            $keywords = explode(' ', trim($_GET['q']));

            // Get the top 1000 docs for each keyword
            $tmp_results_array = Array();

            $i = 0;
            foreach ($keywords as $keyword) {
              if ($i++ == 16) break; //max number of keywords

              $doc_ids = Array();

              $keyword = trim(strtolower($keyword));
              setlocale(LC_CTYPE, 'en_US.UTF-8');
              $keyword = iconv("UTF-8", "ASCII//TRANSLIT//IGNORE", $keyword);

              if ($keyword == '') continue;

              $redis_address = getenv('REDIS_ADDRESS');
              $redis_port = getenv('REDIS_PORT');

              $redis = new Redis();
              $redis->connect($redis_address, $redis_port, 2);

              $results = Array();

              // Get top doc_ids for this keyword from Redis
              $doc_ids = $redis->zRevRange("words_$keyword", 0, 999, true);

              $tmp_results_array[] = $doc_ids;
            }

            // Intersect results
            $doc_ids = $tmp_results_array[0];
            for ($i = 1; $i < count($tmp_results_array); $i++) {
              $doc_ids = array_intersect_key($doc_ids, $tmp_results_array[$i]);
            }

            echo '<p class="text-muted" style="font-size: 0.9em; margin-top: 5px">Results: ' . count($doc_ids);

            // Get pageranks for these doc_ids from Redis
            foreach ($doc_ids as $key => $value) {
              $pagerank = $redis->hGet("pageranks_$key", 'pagerank');

              $results[] = array('doc_id' => $key, 'pagerank' => $pagerank, 'position' => $value, 'url' => null, 'title' => null);
            }

            // Order by score
            uasort($results, function($a, $b) { //or usort?
              return $a['pagerank'] + $a['position'] <= $b['pagerank'] + $b['position'];
            });

            // Only keep the first 8 elements
            $results = array_slice($results, 0, 7);

            // Get metadata for these doc_ids from PG
            foreach ($results as $key => $value) {
              $query = "SELECT url, title, description FROM doc_index WHERE doc_id=$value[doc_id]";
              $rs = pg_query($pg, $query) or die("Error\n");
              $row = pg_fetch_row($rs);

              $url = $row[0];
              $title = $row[1];
              $description = $row[2];

              $results[$key]['url'] = $url;
              $results[$key]['title'] = $title;

              if ($description) {
                $results[$key]['description'] = $description;
              }
              else {
                $results[$key]['description'] = 'No description';
              }

              if ($title) {
                $results[$key]['title'] = $title;
              }
              else {
                $results[$key]['title'] = $url;
              }
            }

            $time_end = microtime(true);

            echo ' - Query time: ' . (round($time_end - $time_start, 3)) . 's</p>';
          }
        ?>
      </div>
    </div>

    <div class="row">
      <div id="results" class="col-md-8 offset-md-2">
        <?php

          if (isset($results)) {
            // Print results
            $results = array_slice($results, 0, 16);

            $i = 0;
            foreach ($results as $key => $value) {
              $domain = parse_url($value['url'])['host'];
              echo '<strong><a href="' . $value['url'] . '"><img class="favicon" width="16px" src="//logo.clearbit.com/' . $domain . '?size=32"> ' . $value['title'] . '</a></strong><br>' . $value['description'] . '<br><span class="text-muted">' . $value['url'] . '</span> <span class="text-muted hidden-sm-down">(scores: ' . round($value['position'], 3) . ', ' . round($value['pagerank'], 3) . ')</span><br><br>';
            }
            if (!$results) {
              echo 'No result<br>';
            }

            $redis->close();
          }
        ?>
      </div>
    </div>

    <div class="row">
      <div id="stats" class="col-md-8 offset-md-2">
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
      </div>
    </div>

    <div id="footer">
      Not a search engine - Code available on <a href="https://github.com/berpj/sigma" target="_blank"><i class="fa fa-github"></i> Github</a><br>
      v0.4
    </div>
  </div>

  <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.1.1/jquery.min.js"></script>
</body>
</html>
