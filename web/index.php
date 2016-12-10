<?php
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
        <form action="/" autocomplete="false">
          <input autocomplete="off" placeholder="Search" type="text" name="q" <?php if (! isset($_GET['q']) || ! trim($_GET['q']) != '') { echo 'autofocus="autofocus"'; } ?> class="form-control" value="<? if (isset($_GET['q'])) echo $_GET['q'] ?>">
        </form>
        <div style="display: none" id="counters"><span id="count">0</span> results (<span id="time">0ms</span>)</div>
      </div>
    </div>

    <div class="row">
      <div id="results" class="col-md-8 offset-md-2"></div>
    </div>

    <div class="row">
      <div id="stats" class="col-md-8 offset-md-2">
        <?php require('stats.php'); ?>
      </div>
    </div>

    <div id="footer">
      Not a search engine - Code available on <a href="https://github.com/berpj/sigma" target="_blank"><i class="fa fa-github"></i> Github</a><br>
      v0.4
    </div>
  </div>

  <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.1.1/jquery.min.js"></script>
  <script src="/script.js"></script>
</body>
</html>
