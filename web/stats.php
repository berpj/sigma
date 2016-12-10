<?php
  function nice_number($n) {
      $n = (0+str_replace(",", "", $n));

      if (!is_numeric($n)) return false;
      elseif ($n > 1000000) return round(($n / 1000000), 1) . 'M';
      elseif ($n > 1000) return round(($n / 1000), 0) . 'k';

      return number_format($n);
  }

  $stats = [
    'pages_indexed' => 999,
    'pages_crawled' => 999,
    'crawling_speed' => '0/s'
  ];

  $db_hostname = getenv('DB_HOSTNAME');
  $db_username = getenv('DB_USERNAME');
  $db_password = getenv('DB_PASSWORD');
  $db_name = getenv('DB_NAME');
  $db_port = getenv('DB_PORT');

  $pg = pg_connect("host=$db_hostname port=$db_port dbname=$db_name user=$db_username password=$db_password") or die ("Could not connect to server\n");

  $query = "SELECT reltuples FROM pg_class WHERE oid = 'public.doc_index'::regclass;";
  $rs = pg_query($pg, $query) or die("Error\n");
  $row = pg_fetch_row($rs);
  $stats['pages_indexed'] = nice_number($row[0]);


  $query = "SELECT reltuples FROM pg_class WHERE oid = 'public.repository'::regclass;";
  $rs = pg_query($pg, $query) or die("Error\n");
  $row = pg_fetch_row($rs);
  $stats['pages_crawled'] = nice_number($row[0]);


  $query = "SELECT COUNT(*) FROM doc_index WHERE status='OK' AND parsed_at > ROUND(extract(epoch from now())) - 120";
  $rs = pg_query($pg, $query) or die("Error\n");
  $row = pg_fetch_row($rs);
  $stats['crawling_speed'] = round($row[0] / 120, 1) . '/s';

  echo json_encode($stats);

  pg_close($pg);
?>
