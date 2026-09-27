#!/usr/bin/env python3
"""
scripts/serve_website_local.py
Lightweight local HTTP preview server for the Urban Air Quality website.

Project: UrbanAirQualityIndex-PollutantDriftAnalysis
Standard Library Only (no external dependencies, no npm, no flask)
"""

import argparse
import http.server
import os
import socket
import sys
import threading
import time
import webbrowser

DEFAULT_PORT = 8000
DEFAULT_HOST = "127.0.0.1"


def is_port_in_use(port: int, host: str = DEFAULT_HOST) -> bool:
    """Checks whether a given TCP port is already in use."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        try:
            s.bind((host, port))
            return False
        except OSError:
            return True


def find_available_port(start_port: int, host: str = DEFAULT_HOST, max_tries: int = 50) -> int:
    """Finds the first available port starting from start_port."""
    for p in range(start_port, start_port + max_tries):
        if not is_port_in_use(p, host):
            return p
    raise RuntimeError(f"Could not find an available port in range {start_port}..{start_port + max_tries}")


def main():
    parser = argparse.ArgumentParser(
        description="Serve the Urban Air Quality interactive presentation website locally."
    )
    parser.add_argument(
        "--port",
        type=int,
        default=DEFAULT_PORT,
        help=f"Port to bind to (default: {DEFAULT_PORT}). Automatically advances if occupied.",
    )
    parser.add_argument(
        "--host",
        type=str,
        default=DEFAULT_HOST,
        help=f"Host address to bind to (default: {DEFAULT_HOST}).",
    )
    parser.add_argument(
        "--no-browser",
        action="store_true",
        help="Do not open the default web browser automatically.",
    )
    parser.add_argument(
        "--dir",
        type=str,
        default=None,
        help="Directory to serve (defaults to 'docs' in the project root).",
    )
    args = parser.parse_args()

    # Determine docs directory relative to this script
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    docs_dir = os.path.abspath(args.dir) if args.dir else os.path.join(project_root, "docs")

    if not os.path.isdir(docs_dir):
        print(f"Error: Documentation directory not found at '{docs_dir}'", file=sys.stderr)
        sys.exit(1)

    # Determine available port
    target_port = args.port
    if is_port_in_use(target_port, args.host):
        print(f"Notice: Port {target_port} is already in use.")
        target_port = find_available_port(target_port + 1, args.host)
        print(f"Selected next available port: {target_port}")

    url = f"http://{args.host}:{target_port}/"

    # Define custom HTTP request handler serving docs_dir
    class DocsHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *handler_args, **handler_kwargs):
            super().__init__(*handler_args, directory=docs_dir, **handler_kwargs)

        def log_message(self, format_str, *log_args):
            # Clean logging
            sys.stdout.write(f"[{self.log_date_time_string()}] {self.address_string()} - {format_str % log_args}\n")
            sys.stdout.flush()

    # Start server
    try:
        # Use ThreadingHTTPServer if available (Python 3.7+)
        server_class = getattr(http.server, "ThreadingHTTPServer", http.server.HTTPServer)
        httpd = server_class((args.host, target_port), DocsHTTPRequestHandler)
    except Exception as e:
        print(f"Failed to start HTTP server on {args.host}:{target_port} - {e}", file=sys.stderr)
        sys.exit(1)

    print("=" * 60)
    print("Urban Air Quality local website preview")
    print(f"Serving: {docs_dir}")
    print(f"URL: {url}")
    print("Press Ctrl+C to stop.")
    print("=" * 60)

    # Optionally launch browser in background thread
    if not args.no_browser:
        def open_browser():
            time.sleep(0.5)
            webbrowser.open(url)
        threading.Thread(target=open_browser, daemon=True).start()

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping local website preview server...")
    finally:
        httpd.server_close()
        print("Server stopped cleanly.")


if __name__ == "__main__":
    main()
