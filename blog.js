/* [CG] Configuration starts here. */

var base_url = '/blog';
var kt_url = '/blog.kch';
var blog_title = 'Easily the most badass blog ever';
var posts_per_page = 10;

/* [CG] Configuration ends here. */

var converter = new Showdown.converter();
var posts = {};
var current_page = 0;
var current_post = 0;
var post_count = 0;
var teaser_separator = '<!-- MORE -->';

// [CG] TODO:
//      - RSS?
//      - Disqus?
//      - How to handle non-JavaScript situations... probably can't?

function zeroPad(n, digits) {
    n = n.toString();
    while (n.length < digits) {
        n = '0' + n;
    }
    return n;
}

function getTimestamp(d) {
    return d.getFullYear() + '-' + zeroPad(d.getMonth() + 1, 2)
                           + '-' + zeroPad(d.getDate(), 2)
                           + ' ' + zeroPad(d.getHours(), 2)
                           + ':' + zeroPad(d.getMinutes(), 2)
                           + ':' + zeroPad(d.getSeconds(), 2);
}

function setCurrentPost(index) {
    window.location.hash = '#' + index;
}

function loadBlog() {
    document.title = blog_title;
    $('#title_link').html(blog_title);
    $.ajaxSetup({ async: false, mimeType: 'application/json' });
    $.ajax({
        type: 'GET',
        url: kt_url + '/posts',
        dataType: "text",
        mimeType: "text/plain",
        success: function (data, text_status, xhr) {
            post_count = parseInt(data) - 1;
            if (document.location.hash.length > 1) {
                current_post = parseInt(document.location.hash.substr(1));
            }
            else {
                current_post = post_count;
            }
            setCurrentPost(current_post);
            loadPost();
            loadSideBar();
            $('#rss_link').attr('title', blog_title + ' RSS');
            $(window).hashchange(function() {
                current_post = parseInt(document.location.hash.substr(1));
                loadPost();
                updateSideBar($('#post_header').html());
            });
        },
        error: function (xhr, status, error) {
            if (xhr.responseText) {
                $('#post').empty().append(
                    '<div class="error">Error (' + xhr.status + '): ' +
                    xhr.responseText + '</div>'
                );
            }
            else {
                $('#post').empty().append(
                    '<div class="error">Error ' + xhr.status + '</div>'
                );
            }
        }
    });
}

function getPostLoader(index) {
    return function() {
        var this_post_index = index;
        setCurrentPost(this_post_index);
    };
}

function updateSideBar(post_title) {
    var start_post_index = post_count - (current_page * posts_per_page);
    $(".post_selector").each(function(index) {
        var post_index = start_post_index - index;
        var elem = $(this);
        elem.unbind('click');
        if (elem.text() == post_title) {
            elem.addClass('current_post');
        }
        else {
            elem.removeClass('current_post');
            elem.click(getPostLoader(post_index));
        }
    });
}

function loadSideBar() {
    var start_post_index = post_count - (current_page * posts_per_page);
    if (start_post_index <= posts_per_page) {
        var end_post_index = 0;
    }
    else {
        var end_post_index = start_post_index - posts_per_page;
    }
    $('#sidebar').empty();
    if (start_post_index < post_count) {
        $('<div id="newer_posts">').click(function() {
            current_page--;
            loadSideBar();
        }).html('Newer Posts').appendTo('#sidebar');
    }
    if (start_post_index == 0) {
        $.getJSON(kt_url + '/0', function(data) {
            $('<div class="post_selector">')
              .html(data.title)
              .appendTo('#sidebar');
        });
    }
    else {
        for (var i = start_post_index; i > end_post_index; i--) {
            $.getJSON(kt_url + '/' + i, function(data) {
                $('<div class="post_selector">')
                  .html(data.title)
                  .appendTo('#sidebar');
            });
        }
        if (end_post_index >= 0) {
            $('<div id="older_posts">').click(function() {
                current_page++;
                loadSideBar();
            }).html('Older Posts').appendTo('#sidebar');
        }
    }
    updateSideBar($('#post_header').html());
}

function loadPost() {
    $.getJSON(kt_url + '/' + current_post, function(data) {
        $('#post').empty().append(
            '<h2><a id="post_header"></a></h2>' +
            '<div id="post_body"></div>'
        );
        $('#post_header').addClass('post_header').html(data.title);
        $('#post_body').html(converter.makeHtml(data.body));
        $('#post').append(
          '<div id="post_footer">Posted by ' +
              '<span id="post_poster"></span> at ' +
              '<span id="post_timestamp"></span>' +
          '</div>'
        );
        $('#post_header').attr('href', '#' + current_post);
        $('#post_poster').html(data.poster);
        $('#post_timestamp').html(getTimestamp(
            new Date(parseInt(data.timestamp) * 1000)
        ));
        $('#title_link').html(blog_title).click(loadPage);
    });
}

