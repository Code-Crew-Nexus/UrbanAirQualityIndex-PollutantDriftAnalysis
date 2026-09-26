#!/usr/bin/env python3
"""
scripts/34_phase6B_browser_smoke.py
==============================================================================
Phase 6B.1: Automated Browser Smoke QA & Screenshot Review Capture
Project: UrbanAirQualityIndex-PollutantDriftAnalysis
Baseline: v0.6-svm-freeze (FROZEN — READ ONLY)

PURPOSE:
1. Spawns an internal Python HTTP server on port 8000 serving 'docs/'.
2. Uses Chrome headless CLI to visit and capture 9 specified 1440x900 screenshots.
3. Asserts zero HTTP 404 errors during rendering.
4. Verifies all 9 output images are generated and non-empty.
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
REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DOCS_DIR = os.path.join(REPO_ROOT, "docs")
UI_REVIEW_DIR = os.path.join(REPO_ROOT, "analysis", "phase6B", "ui_review")

http_404_errors = []
http_access_log = []

class QAHTTPRequestHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DOCS_DIR, **kwargs)

    def do_GET(self):
        # Support both /explore.html and /docs/explore.html
        if self.path.startswith("/docs/"):
            self.path = self.path[5:]
        return super().do_GET()

    def log_message(self, format, *args):
        http_access_log.append(f"{self.address_string()} - - {format % args}")
        if len(args) > 1 and str(args[1]) == "404":
            http_404_errors.append(f"404: {args[0]}")
        # Quiet standard output during test

def start_server():
    server = HTTPServer((HOST, PORT), QAHTTPRequestHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    return server

def run_browser_smoke():
    print("============================================================")
    print("Phase 6B.1: Browser Smoke QA & Screenshot Capture")
    print("============================================================\n")

    os.makedirs(UI_REVIEW_DIR, exist_ok=True)

    if not os.path.exists(CHROME_PATH):
        raise FileNotFoundError(f"Chrome executable not found at: {CHROME_PATH}")

    server = start_server()
    print(f"HTTP Server started on http://{HOST}:{PORT}/ serving {DOCS_DIR}\n")

    # The 9 specified test views
    test_views = [
        {
            "id": "01_explore_aqi_1440x900.png",
            "url": f"http://{HOST}:{PORT}/explore.html",
            "desc": "Explore Data: Default AQI View (Zoo Park, Latest 90 Days)"
        },
        {
            "id": "02_explore_pm25_1440x900.png",
            "url": f"http://{HOST}:{PORT}/explore.html?scope=Hyderabad&station=PROJ_007&variable=PM2.5",
            "desc": "Explore Data: Deep-linked PM2.5 View (Zoo Park, µg/m³)"
        },
        {
            "id": "03_stat_drift_eligible_1440x900.png",
            "url": f"http://{HOST}:{PORT}/statistics.html?scope=Hyderabad&station=PROJ_179&variable=aqi_verified&tab=drift",
            "desc": "Statistical Analysis: Drift Tab Eligible Station (PROJ_179, Hyderabad)"
        },
        {
            "id": "04_stat_inference_tested_1440x900.png",
            "url": f"http://{HOST}:{PORT}/statistics.html?scope=Hyderabad&station=PROJ_007&variable=o3_8h_max&tab=inference",
            "desc": "Statistical Analysis: Inference Tab Tested Station (PROJ_007, Ozone)"
        },
        {
            "id": "05_ml_regression_1440x900.png",
            "url": f"http://{HOST}:{PORT}/machine-learning.html?tab=regression&scope=Hyderabad&split=TEST",
            "desc": "Machine Learning: Regression Tab (Hyderabad TEST evaluation)"
        },
        {
            "id": "06_ml_classification_india_test_1440x900.png",
            "url": f"http://{HOST}:{PORT}/machine-learning.html?tab=classification&scope=India&split=TEST",
            "desc": "Machine Learning: Classification Tab (India Panel TEST evaluation)"
        },
        {
            "id": "07_ml_classification_hyd_holdout_1440x900.png",
            "url": f"http://{HOST}:{PORT}/machine-learning.html?tab=classification&scope=Hyderabad&split=Recent%20Holdout",
            "desc": "Machine Learning: Single-Class Holdout Notice (Hyderabad Holdout)"
        },
        {
            "id": "08_ml_regimes_hyderabad_1440x900.png",
            "url": f"http://{HOST}:{PORT}/machine-learning.html?tab=regimes&scope=Hyderabad",
            "desc": "Machine Learning: Pollution Regimes Tab (Hyderabad PC1 x PC2)"
        },
        {
            "id": "09_ml_regimes_india_1440x900.png",
            "url": f"http://{HOST}:{PORT}/machine-learning.html?tab=regimes&scope=India",
            "desc": "Machine Learning: Pollution Regimes Tab (India Panel PC1 x PC2)"
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

        print(f"[{idx}/9] Capturing: {view['id']}")
        print(f"      URL: {view['url']}")
        print(f"      Description: {view['desc']}")

        chrome_cmd = [
            CHROME_PATH,
            "--headless=new",
            f"--screenshot={target_png}",
            "--window-size=1440,900",
            "--virtual-time-budget=3500",
            "--hide-scrollbars",
            view["url"]
        ]

        res = subprocess.run(chrome_cmd, capture_output=True, text=True)

        if res.returncode == 0 and os.path.exists(target_png):
            f_size = os.path.getsize(target_png)
            if f_size > 10000:
                print(f"      SUCCESS -> {f_size:,} bytes")
                captured_files.append((view["id"], f_size))
            else:
                print(f"      WARNING -> File too small ({f_size} bytes)")
                failed_captures.append((view["id"], f"Size too small: {f_size} bytes"))
        else:
            print(f"      FAILED -> Return code: {res.returncode}")
            failed_captures.append((view["id"], f"Exit code {res.returncode}: {res.stderr}"))

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
        print("PASS: Zero HTTP 404 errors encountered.")

    # Screenshot Audit
    print("\n--- Screenshot Verification Audit ---")
    print(f"Captured: {len(captured_files)} / {len(test_views)}")
    if failed_captures:
        print("Failed captures:")
        for fc in failed_captures:
            print(f"  {fc[0]}: {fc[1]}")
        raise RuntimeError(f"Failed to capture all 9 screenshots: {len(failed_captures)} failures")

    print("PASS: All 9 1440x900 screenshots captured successfully!")
    print("\n============================================================")
    print("Browser Smoke QA Completed Successfully (0 FAIL, 0 404s)")
    print("============================================================\n")

if __name__ == "__main__":
    run_browser_smoke()
