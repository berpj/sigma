$(function() {
  function doSearch() {
    var keywords = $('input[name="q"]').val().toLowerCase();

    $.get("search.php", {q: keywords}, function(data) {
      $('#count').text(data['count']);
      $('#time').text(data['time']);

      var html = '';
      $.each(data['results'], function(k, v) {
        html += '<strong><a href="' + v['url'] + '"><img class="favicon" width="16px" src="//logo.clearbit.com/' + v['domain'] + '?size=32" onError="this.onerror=null;this.src=\'/default_favicon.png\';"> ' + v['title'] + '</a></strong><br>' + v['description'] + '<br><span class="text-muted">' + v['url'] + '</span> <span class="text-muted hidden-sm-down"><br>[lang: ' + v['lang'] + '] [scores: ' + v['position_quality'] + ', ' + v['pagerank'] + ']</span><br><br>';
      });

      if (html == '') {
        $('#counters').hide();
        $('#results').html('No result');
      } else {
        $('#counters').show();
        $('#results').html(html);
      }
    }, 'json');
  }

  doSearch();

  $('form').submit(function(e) {
    var keywords = $('input[name="q"]').val().toLowerCase();

    window.history.pushState(null, null, '/?q=' + keywords);

    doSearch();
    return false;
  })
});
