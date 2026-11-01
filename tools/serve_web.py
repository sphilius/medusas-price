"""serve_web.py - dev-only static server for the Web export in build/web.

Sends "Cache-Control: no-store" on every file, so after a re-export a plain
refresh loads the new build (no hard refresh needed). Also pins the MIME types
Godot's loader needs, since Windows' registry can map .js/.wasm oddly.

Usage: python tools/serve_web.py [port]      (default 8060, Ctrl+C to stop)
"""
import functools
import http.server
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent / "build" / "web"


class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".js": "text/javascript",
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
    }

    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, format: str, *args) -> None:
        pass  # keep the terminal quiet; errors still raise


def main() -> None:
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8060
    if not (ROOT / "index.html").exists():
        sys.exit(f"No build at {ROOT}. Export first (tools/play_web.ps1 does it for you).")
    handler = functools.partial(NoCacheHandler, directory=str(ROOT))
    with http.server.ThreadingHTTPServer(("", port), handler) as httpd:
        print(f"Serving {ROOT} at http://localhost:{port}  (Ctrl+C to stop)")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == "__main__":
    main()
