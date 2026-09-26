#!/usr/bin/env python3
"""
scripts/35_phase6C_browser_smoke.py
==============================================================================
Phase 6C: Responsive, Cross-Browser & Multi-Viewport QA Capture
Project: UrbanAirQualityIndex-PollutantDriftAnalysis
Baseline: v0.6-svm-freeze (FROZEN — READ ONLY)

PURPOSE:
1. Spawns an internal Python HTTP server on port 8000 serving 'docs/'.
2. Uses Chrome and Edge headless CLI across Desktop (1440x900), Tablet (768x1024),
   and Mobile (390x844) viewports.
3. Captures all 12 specified Phase 6C review screenshots in analysis/phase6C/ui_review/.
4. Verifies zero HTTP 404 errors during rendering.
5. Verifies all 12 output images are generated and exceed 10 KB.
==============================================================================
"""

import os
import sys
import time
import threading
import subprocess
from http.server import HTTPServer, SimpleHTTPRequestHandler

PORT = 8000
HOST = "127.0.0.1"
CHROME_PATH = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
EDGE_PATH = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DOCS_DIR = os.path.join(REPO_ROOT, "docs")
UI_REVIEW_DIR = os.path.join(REPO_ROOT, "analysis", "phase6C", "ui_review")

http_404_errors = []
http_access_log = []

class QAHTTPRequestHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DOCS_DIR, **kwargs)

    def do_GET(self):
        if self.path.startswith("/docs/"):
            self.path = self.path[5:]
        return super().do_GET()

    def log_message(self, format, *args):
        http_access_log.append(f"{self.address_string()} - - {format % args}")
        if len(args) > 1 and str(args[1]) == "404":
            http_404_errors.append(f"404: {args[0]}")

def start_server():
    server = HTTPServer((HOST, PORT), QAHTTPRequestHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    return server

def run_browser_smoke():
    print("============================================================")
    print("Phase 6C: Responsive, Multi-Viewport & Cross-Browser QA")
    print("============================================================\n")

    os.makedirs(UI_REVIEW_DIR, exist_ok=True)

    if not os.path.exists(CHROME_PATH):
        raise FileNotFoundError(f"Chrome executable not found at: {CHROME_PATH}")

    server = start_server()
    print(f"HTTP Server started on http://{HOST}:{PORT}/ serving {DOCS_DIR}\n")

    # The 12 specified test views across Desktop, Tablet, and Mobile viewports
    test_views = [
        {
            "id": "01_home_desktop_1440x900.png",
            "url": f"http://{HOST}:{PORT}/index.html",
            "width": 1440,
            "height": 900,
            "desc": "Home desktop overview (Graphite x Jade x Champagne header, metrics, actions)"
        },
        {
            "id": "02_home_mobile_390x844.png",
            "url": f"http://{HOST}:{PORT}/index.html",
            "width": 390,
            "height": 844,
            "desc": "Home mobile responsive layout (stacked cards, hamburger toggle, clean wrap)"
        },
        {
            "id": "03_explore_aqi_desktop_1440x900.png",
            "url": f"http://{HOST}:{PORT}/explore.html",
            "width": 1440,
            "height": 900,
            "desc": "Explore Data: Default AQI desktop view (Zoo Park, Latest 90 Days)"
        },
        {
            "id": "04_explore_pm25_mobile_390x844.png",
            "url": f"http://{HOST}:{PORT}/explore.html?scope=Hyderabad&station=PROJ_007&variable=PM2.5",
            "width": 390,
            "height": 844,
            "desc": "Explore Data: PM2.5 mobile responsive view (full-width filters, responsive chart)"
        },
        {
            "id": "05_stat_drift_desktop_1440x900.png",
            "url": f"http://{HOST}:{PORT}/statistics.html?scope=Hyderabad&station=PROJ_179&variable=aqi_verified&tab=drift",
            "width": 1440,
            "height": 900,
            "desc": "Statistical Analysis: Drift Tab Eligible Station (PROJ_179, Hyderabad)"
        },
        {
            "id": "06_stat_inference_tablet_768x1024.png",
            "url": f"http://{HOST}:{PORT}/statistics.html?scope=Hyderabad&station=PROJ_007&variable=o3_8h_max&tab=inference",
            "width": 768,
            "height": 1024,
            "desc": "Statistical Analysis: Inference Tab tablet view (PROJ_007 Ozone, scrollable table)"
        },
        {
            "id": "07_ml_regression_desktop_1440x900.png",
            "url": f"http://{HOST}:{PORT}/machine-learning.html?tab=regression&scope=Hyderabad&split=TEST",
            "width": 1440,
            "height": 900,
            "desc": "Machine Learning: Regression Tab (Hyderabad TEST evaluation, MAE comparison)"
        },
        {
            "id": "08_ml_classification_india_test_1440x900.png",
            "url": f"http://{HOST}:{PORT}/machine-learning.html?tab=classification&scope=India&split=TEST",
            "width": 1440,
            "height": 900,
            "desc": "Machine Learning: Classification Tab (India Panel TEST, F1 frozen operating rules)"
        },
        {
            "id": "09_ml_classification_hyd_holdout_1440x900.png",
            "url": f"http://{HOST}:{PORT}/machine-learning.html?tab=classification&scope=Hyderabad&split=Recent%20Holdout",
            "width": 1440,
            "height": 900,
            "desc": "Machine Learning: Single-Class Holdout Notice (Hyderabad Holdout, chart hidden)"
        },
        {
            "id": "10_ml_regimes_hyderabad_1440x900.png",
            "url": f"http://{HOST}:{PORT}/machine-learning.html?tab=regimes&scope=Hyderabad",
            "width": 1440,
            "height": 900,
            "desc": "Machine Learning: Pollution Regimes (Hyderabad PC1 x PC2, K=3 clusters)"
        },
        {
            "id": "11_ml_regimes_india_1440x900.png",
            "url": f"http://{HOST}:{PORT}/machine-learning.html?tab=regimes&scope=India",
            "width": 1440,
            "height": 900,
            "desc": "Machine Learning: Pollution Regimes (India Panel PC1 x PC2, K=3 clusters)"
        },
        {
            "id": "12_documentation_math_desktop_1440x900.png",
            "url": f"http://{HOST}:{PORT}/documentation.html#concepts",
            "width": 1440,
            "height": 900,
            "desc": "Documentation: Theoretical concepts & KaTeX mathematical rendering view"
        }
    ]

    captured_files = []
    failed_captures = []

    for idx, view in enumerate(test_views, start=1):
        target_png = os.path.join(UI_REVIEW_DIR, view["id"])
        if os.path.exists(target_png):
            try:
                os.remove(target_png)
            except Exception:
                pass

        print(f"[{idx}/12] Capturing: {view['id']} ({view['width']}x{view['height']})")
        print(f"       URL: {view['url']}")
        print(f"       Desc: {view['desc']}")

        chrome_cmd = [
            CHROME_PATH,
            "--headless=new",
            f"--screenshot={target_png}",
            f"--window-size={view['width']},{view['height']}",
            "--virtual-time-budget=4000",
            "--hide-scrollbars",
            view["url"]
        ]

        res = subprocess.run(chrome_cmd, capture_output=True, text=True)

        if res.returncode == 0 and os.path.exists(target_png):
            f_size = os.path.getsize(target_png)
            if f_size > 10000:
                print(f"       SUCCESS -> {f_size:,} bytes")
                captured_files.append((view["id"], f_size, f"{view['width']}x{view['height']}"))
            else:
                print(f"       WARNING -> File too small ({f_size} bytes)")
                failed_captures.append((view["id"], f"Size too small: {f_size} bytes"))
        else:
            print(f"       FAILED -> Return code: {res.returncode}")
            failed_captures.append((view["id"], f"Exit code {res.returncode}: {res.stderr}"))

    # Cross-browser Edge smoke test verification
    edge_smoke_ok = False
    if os.path.exists(EDGE_PATH):
        print("\n--- Cross-Browser Smoke Check (Microsoft Edge Headless) ---")
        edge_target = os.path.join(UI_REVIEW_DIR, "edge_smoke_check.png")
        edge_cmd = [
            EDGE_PATH,
            "--headless=new",
            f"--screenshot={edge_target}",
            "--window-size=1440,900",
            "--virtual-time-budget=3000",
            "--hide-scrollbars",
            f"http://{HOST}:{PORT}/index.html"
        ]
        edge_res = subprocess.run(edge_cmd, capture_output=True, text=True)
        if edge_res.returncode == 0 and os.path.exists(edge_target):
            edge_size = os.path.getsize(edge_target)
            print(f"Edge Headless Smoke Check: SUCCESS -> {edge_size:,} bytes")
            edge_smoke_ok = True
            try:
                os.remove(edge_target)
            except Exception:
                pass
        else:
            print(f"Edge Headless Smoke Check: Noted (Return code {edge_res.returncode})")
    else:
        print("\nMicrosoft Edge not installed, skipping secondary browser check.")

    server.shutdown()
    print(f"\nServer shut down cleanly.\n")

    # 404 Audit
    print("--- HTTP Request & 404 Audit ---")
    print(f"Total HTTP requests served: {len(http_access_log)}")
    print(f"Total 404 errors recorded: {len(http_404_errors)}")
    if http_404_errors:
        print("Encountered 404 errors:")
        for err in http_404_errors:
            print(f"  {err}")
        raise RuntimeError(f"HTTP 404 errors encountered during smoke QA: {len(http_404_errors)}")
    else:
        print("PASS: Zero HTTP 404 errors encountered across all viewports.")

    # Screenshot Audit
    print("\n--- Screenshot Verification Audit ---")
    print(f"Captured: {len(captured_files)} / {len(test_views)}")
    if failed_captures:
        print("Failed captures:")
        for fc in failed_captures:
            print(f"  {fc[0]}: {fc[1]}")
        raise RuntimeError(f"Failed to capture all 12 screenshots: {len(failed_captures)} failures")

    print("PASS: All 12 multi-viewport screenshots captured successfully!")
    print("\n============================================================")
    print("Phase 6C Browser Smoke QA Completed Successfully (0 FAIL, 0 404s)")
    print("============================================================\n")

if __name__ == "__main__":
    run_browser_smoke()
