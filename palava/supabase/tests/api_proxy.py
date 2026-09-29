"""Serves PostgREST under /rest/v1, the path Supabase clients call.

Usage: python3 api_proxy.py <listen-port> <postgrest-port>
Test helper only; see README.md in this folder.
"""
import http.server
import sys
import urllib.error
import urllib.request

LISTEN, UPSTREAM = int(sys.argv[1]), int(sys.argv[2])
PREFIX = "/rest/v1"
SKIP = {"host", "content-length", "connection", "transfer-encoding"}


class Proxy(http.server.BaseHTTPRequestHandler):
    def _forward(self):
        if not self.path.startswith(PREFIX):
            self.send_error(404)
            return
        body = None
        if "content-length" in self.headers:
            body = self.rfile.read(int(self.headers["content-length"]))
        request = urllib.request.Request(
            f"http://127.0.0.1:{UPSTREAM}{self.path[len(PREFIX):] or '/'}",
            data=body,
            method=self.command,
            headers={k: v for k, v in self.headers.items() if k.lower() not in SKIP},
        )
        try:
            response = urllib.request.urlopen(request)
        except urllib.error.HTTPError as error:
            response = error
        payload = response.read()
        self.send_response(response.status)
        for key, value in response.headers.items():
            if key.lower() not in SKIP:
                self.send_header(key, value)
        self.send_header("content-length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    do_GET = do_POST = do_PATCH = do_PUT = do_DELETE = do_HEAD = _forward

    def log_message(self, *args):
        pass


http.server.ThreadingHTTPServer(("127.0.0.1", LISTEN), Proxy).serve_forever()
