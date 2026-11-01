"""Serves the tools folder to this computer only, so the sprite tools page
can run in a browser (browsers won't run it from a plain file). Started by
the launchers; nothing here needs installing beyond Python 3.7+. -Elvie"""
import functools, http.server, os, sys, urllib.parse, webbrowser

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PORTS = range(8765, 8791)

class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map,
                      ".html": "text/html; charset=utf-8", ".css": "text/css; charset=utf-8",
                      ".js": "text/javascript", ".mjs": "text/javascript", ".wasm": "application/wasm",
                      ".json": "application/json", ".py": "text/plain; charset=utf-8",
                      ".md": "text/plain; charset=utf-8", ".txt": "text/plain; charset=utf-8",
                      ".whl": "application/zip"}

    # The same rules as serve.pl and serve.ps1: GET and HEAD only, no ".."
    # or dot-file parts, and no folder listings (a folder serves its
    # index.html or nothing).
    def send_head(self):
        path = urllib.parse.unquote(urllib.parse.urlsplit(self.path).path)
        parts = [p for p in path.split("/") if p]
        if any(p == ".." or p.startswith(".") or "\\" in p or ":" in p for p in parts):
            self.send_error(404, "Not found")
            return None
        full = os.path.join(self.directory, *parts)
        if os.path.isdir(full) and path.endswith("/") and not os.path.isfile(os.path.join(full, "index.html")):
            self.send_error(404, "Not found")
            return None
        return super().send_head()

    def not_allowed(self):
        self.send_error(405, "Method not allowed")

    do_POST = do_PUT = do_DELETE = do_PATCH = do_OPTIONS = not_allowed

    def end_headers(self):
        # always serve the newest files, so an update shows on reload
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def log_message(self, *args):
        pass

def main():
    for port in PORTS:
        try:
            httpd = http.server.ThreadingHTTPServer(("127.0.0.1", port), functools.partial(Handler, directory=ROOT))
            break
        except OSError:
            continue
    else:
        print("Couldn't find a free port between 8765 and 8790. Close other copies of this window and try again.")
        return 1
    url = f"http://127.0.0.1:{port}/web/"
    print()
    print("  Emerald Lens sprite tools")
    print(f"  Open {url} in your browser (it should open by itself).")
    print("  Leave this window open while you use the tools; close it to stop.")
    print()
    try:
        webbrowser.open(url)
    except Exception:
        pass
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0

if __name__ == "__main__":
    sys.exit(main())
