command! -nargs=0 Blognew  exec('py new_post()')
command! -nargs=1 Blogopen exec('py open_post(<f-args>)')
command! -nargs=0 Blogsave exec('py save_post()')

python <<EOF
# -*- coding: utf-8 -*-

from __future__ import with_statement
import vim, json, urllib, httplib, datetime, urlparse, contextlib

BLOG_HOSTNAME = 'www.superblog.net'
BLOG_PORT = 80
BLOG_URL = 'http://www.superblog.net'
BLOG_USERNAME = 'superuser'
BLOG_PASSWORD = 'superpassword'
BLOG_TIMEOUT = 5
BLOG_TEXTWIDTH = 79

EPOCH = datetime.datetime(1970, 1, 1)
POST_ID = None

def encode(things):
    if isinstance(things, list) or isinstance(things, tuple):
        return [isinstance(x, basestring) and x.encode('utf-8') or x]
    elif isinstance(things, basestring):
        return things.encode('utf-8')
    else:
        return things

class KyotoTycoon(object):

    @contextlib.contextmanager
    def connection(self):
        try:
            conn = httplib.HTTPConnection(
                BLOG_HOSTNAME, BLOG_PORT, False, BLOG_TIMEOUT
            )
            yield conn
        finally:
            conn.close()

    def send_request(self, rpc_method, data):
        url = '/'.join((BLOG_URL, 'rpc', rpc_method))
        auth_header = ':'.join((
            BLOG_USERNAME, BLOG_PASSWORD
        )).encode('base64').rstrip()
        enc_data = urllib.urlencode(dict([
            (k, encode(v)) for k, v in data.items()
        ]))
        headers = {
            'Authorization': 'Basic %s' % (auth_header),
            'Content-Length': str(len(enc_data)),
            'Content-Type': 'application/x-www-form-urlencoded'
        }
        status = 500
        retval = ''
        with self.connection() as conn:
            conn.request('POST', url, enc_data, headers)
            response = conn.getresponse()
            status = response.status
            body = response.read()
            content_type = response.getheader('content-type')
            if content_type:
                if 'colenc=U' in content_type:
                    k, v = body.split('\t', 1)
                    retval = urlparse.parse_qs('%s=%s' % (k, v))[k][0]
                elif 'colenc=B' in content_type:
                    retval = body[7:].decode('base64')
                elif body and 'text/tab-separated-values' in content_type:
                    retval = body.split('\t', 1)[1]
                else:
                    retval = ''
                retval = retval.decode('utf-8')
        return (status, retval)

    def get(self, key):
        status, body = self.send_request('get', {'key': key})
        if status != 200:
            raise Exception('Error getting %s: (%d) %s' % (key, status, body))
        return body

    def set(self, key, value):
        status, body = self.send_request('set', {'key': key, 'value': value})
        if status != 200:
            raise Exception('Error setting %s to %s: %s' % (key, value, body))
        return body

    def cas(self, key, old_value, new_value):
        return self.send_request('cas', {
            'key': key, 'oval': old_value, 'nval': new_value,
        })[0]

    def clear(self):
        return self.send_request('clear', {})[0]

    def zero(self):
        while True:
            old_value = int(self.get(key))
            new_value = 0
            status = self.cas(key, str(old_value), str(new_value))
            if status == 200:
                return new_value

    def increment(self, key, amount):
        while True:
            old_value = int(self.get(key))
            new_value = old_value + amount
            status = self.cas(key, str(old_value), str(new_value))
            if status == 200:
                return new_value

def load_buffer(dt=None, poster='', title='', body=None):
    vim.current.buffer[:] = None
    dt = dt or datetime.datetime.now()
    date = dt.strftime('%Y-%m-%d %H:%M:%S')
    vim.current.buffer[0] = (u'date: %s' % (date)).encode('utf8')
    vim.current.buffer.append('poster: ' + poster.encode('utf8'))
    vim.current.buffer.append('title: ' + title.encode('utf8'))
    vim.current.buffer.append('')
    if body is None:
        vim.current.buffer.append('')
        vim.current.window.cursor = (2, 8)
    else:
        vim.current.buffer.append(body.encode('utf8').strip().splitlines())
        vim.current.window.cursor = (len(vim.current.buffer), 0)
    vim.current.buffer.append('')
    vim.command('set encoding=utf8')
    vim.command('set nomodified')
    vim.command('set textwidth=' + str(BLOG_TEXTWIDTH))
    vim.command('set syntax=markdown')

def new_post():
    global POST_ID
    POST_ID = None
    load_buffer()

def open_post(post_id):
    global POST_ID
    POST_ID = post_id
    d = json.loads(KyotoTycoon().get(POST_ID))
    dt = (EPOCH + datetime.timedelta(seconds=long(d['timestamp'])))
    load_buffer(dt, d['poster'], d['title'], d['body'])

def save_post():
    global POST_ID
    kt = KyotoTycoon()
    if POST_ID is None:
        POST_ID = kt.increment('posts', 1) - 1
    td = datetime.datetime.strptime(
        vim.current.buffer[0], u'date: %Y-%m-%d %H:%M:%S'
    ) - EPOCH
    post = dict()
    post['timestamp'] = long((td.days * 86400) + td.seconds)
    post['poster'] = unicode(vim.current.buffer[1][8:])
    post['title'] = unicode(vim.current.buffer[2][7:])
    post['body'] = '\n'.join(vim.current.buffer[4:]).strip().decode('utf8')
    kt.set(POST_ID, json.dumps(post))
    vim.command('set nomodified')

def clear_all_posts():
    kt = KyotoTycoon()
    kt.clear()
    kt.set('posts', '0')

