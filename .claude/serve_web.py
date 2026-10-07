# Dev server for the Flutter web build: like `python -m http.server`, but never cached,
# so each `flutter build web` shows up on reload.
import functools
import http.server

class NoCache(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

http.server.ThreadingHTTPServer(
    ("127.0.0.1", 8090), functools.partial(NoCache, directory="app/build/web")
).serve_forever()
