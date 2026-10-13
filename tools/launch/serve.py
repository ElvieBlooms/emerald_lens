"""Serves the tools folder to this computer only, so the sprite tools page
can run in a browser (browsers won't run it from a plain file). Started by
the launchers; nothing here needs installing beyond Python 3.7+. -Elvie"""
import functools, http.server, os, sys, webbrowser

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PORTS = range(8765, 8791)

class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map,
                      ".js": "text/javascript", ".mjs": "text/javascript", ".wasm": "application/wasm",
                      ".json": "application/json", ".py": "text/plain; charset=utf-8",
                      ".md": "text/plain; charset=utf-8", ".whl": "application/zip"}

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
