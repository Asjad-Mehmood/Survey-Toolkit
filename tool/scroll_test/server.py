# The Windows test of scrolling: serves the test pages and writes each /log?m=... line the
# pages send to a file, so the test script can read what happened inside the Toolkit's window.
import http.server, sys, urllib.parse, os
PORT, LOG = int(sys.argv[1]), sys.argv[2]
os.chdir(os.path.dirname(os.path.abspath(__file__)))
class H(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        u = urllib.parse.urlparse(self.path)
        if u.path == '/log':
            m = urllib.parse.parse_qs(u.query).get('m', [''])[0]
            with open(LOG, 'a', encoding='utf-8') as f: f.write(m + '\n')
            self.send_response(204); self.end_headers(); return
        return super().do_GET()
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store'); super().end_headers()
    def log_message(self, *a): pass
http.server.ThreadingHTTPServer(('127.0.0.1', PORT), H).serve_forever()
