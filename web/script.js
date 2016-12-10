$(function() {
  function getUrlParameter(sParam) {
    var sPageURL = decodeURIComponent(window.location.search.substring(1)),
      sURLVariables = sPageURL.split('&'),
      sParameterName,
      i;

    for (i = 0; i < sURLVariables.length; i++) {
      sParameterName = sURLVariables[i].split('=');

      if (sParameterName[0] === sParam) {
        return sParameterName[1] === undefined ? true : sParameterName[1];
      }
    }
  };

  function doSearch(page = 0) {
    var keywords = $('input[name="q"]').val().toLowerCase();

    $.ajax({
      type: 'GET',
      url: "http://" + document.domain + ":8080/search.php",
      data: {q: keywords, page: page},
      dataType: 'jsonp',
      success: function(data) {
        $('#count').text(data['count']);
        $('#time').text(data['time']);

        var html = '';
        $.each(data['results'], function(k, v) {
          html += '<strong><a href="' + v['url'] + '"><img class="favicon" width="16px" src="//logo.clearbit.com/' + v['domain'] + '?size=32" onError="this.onerror=null;this.src=\'/default_favicon.png\';"> ' + v['title'] + '</a></strong><br>' + v['description'] + '<br><span class="text-muted">' + v['url'] + '</span> <span class="text-muted hidden-sm-down"><br>[lang: ' + v['lang'] + '] [scores: ' + v['position_quality'] + ', ' + v['pagerank'] + ']</span><br><br>';
        });

        $('#results').css('opacity', '1');

        if (html == '') {
          $('#counters').hide();
          $('#results').html('No result');
        } else {
          $('input').blur();
          $('#counters').show();
          if (page > 0) {
            $('#results').append(html);
          } else {
            $('#results').html(html);
          }
          $('#see-more').remove();
          if (data['results'].length + page * 10 < data['count'] || data['count'] == '1000+') {
            $('#results').append('<div class="col-sm-12" style="text-align: center!important"><a href="#" id="see-more" class="btn btn-secondary" data-page="' + (page + 1) + '">See more</a></div>')
          }
        }
      }
    })
  }

  function getStats() {
    $.ajax({
      type: 'GET',
      url: "http://" + document.domain + ":8080/stats.php",
      dataType: 'jsonp',
      success: function(data) {
        $('#pages_indexed').text(data['pages_indexed']);
        $('#pages_crawled').text(data['pages_crawled']);
        $('#crawling_speed').text(data['crawling_speed']);
      }
    })
  }

  $('form').submit(function(e) {
    var keywords = $('input[name="q"]').val().toLowerCase();

    window.history.pushState(null, null, '/?q=' + keywords);

    $('#results').css('opacity', '0.1');

    doSearch();
    return false;
  })

  $(document).on('click', '#see-more', function(){
    doSearch($(this).data('page'));
    return false;
  });

  $('input[name="q"]').val(getUrlParameter('q'));

  doSearch();

  getStats();

  $('input').focus();
});
