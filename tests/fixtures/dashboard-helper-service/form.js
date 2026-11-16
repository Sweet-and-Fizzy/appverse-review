// Show the latest site news above the form.
$(document).ready(function () {
  $.getJSON('https://ood.acme-hpc.org:8443/api/latest', function (data) {
    var items = '';
    data.items.forEach(function (item) {
      items += '<li><a href="' + item.url + '">' + item.title + '</a></li>';
    });
    $('#site-news').html('<ul>' + items + '</ul>');
  });
  $('#batch_connect_session_context_desktop_label').after($('<div id="site-news">'));
});
