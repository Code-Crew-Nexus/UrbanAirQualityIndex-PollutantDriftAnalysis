import os
import time
import subprocess
import threading
from http.server import SimpleHTTPRequestHandler, HTTPServer
from playwright.sync_api import sync_playwright

PORT = 8877
DOCS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "docs"))
SCREENSHOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "scratch", "g6_screenshots"))
os.makedirs(SCREENSHOT_DIR, exist_ok=True)

class QuietHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DOCS_DIR, **kwargs)
    def log_message(self, format, *args):
        pass

def run_server():
    server = HTTPServer(("127.0.0.1", PORT), QuietHandler)
    server.serve_forever()

def main():
    print(f"Starting static web server on http://127.0.0.1:{PORT} serving {DOCS_DIR}")
    server_thread = threading.Thread(target=run_server, daemon=True)
    server_thread.start()
    time.sleep(1)

    results = []

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(viewport={"width": 1280, "height": 900})
        page = context.new_page()

        console_errors = []
        page.on("console", lambda msg: console_errors.append(msg.text) if msg.type == "error" else None)

        pages_to_test = [
            ("Home", "/index.html"),
            ("Explore", "/explore.html"),
            ("Statistics", "/statistics.html"),
            ("Machine Learning", "/machine-learning.html"),
            ("Documentation", "/documentation.html"),
            ("About", "/about.html")
        ]

        print("\n=== STEP 1: VERIFYING ALL 6 PAGES & LIVE STATUS BANNER ===")
        for name, path in pages_to_test:
            url = f"http://127.0.0.1:{PORT}{path}"
            console_errors.clear()
            resp = page.goto(url, wait_until="networkidle")
            status = resp.status if resp else "NO_RESP"
            
            # Check banner
            banner = page.locator(".live-status-banner")
            banner_count = banner.count()
            banner_text = banner.inner_text() if banner_count > 0 else "NONE"
            
            # Screenshot
            shot_path = os.path.join(SCREENSHOT_DIR, f"{name.lower().replace(' ', '_')}.png")
            page.screenshot(path=shot_path, full_page=False)

            has_banner = "operational extension active" in banner_text.lower()
            if console_errors:
                print(f"Console errors on {name}: {console_errors}")
            res = {
                "page": name,
                "status": status,
                "has_banner": has_banner,
                "banner_text": banner_text[:60] + "...",
                "errors": len(console_errors)
            }
            results.append(res)
            passed = (status == 200 and has_banner)
            print(f"[{'PASS' if passed else 'FAIL'}] {name} ({status}): Banner='{banner_text[:45]}...', Errors={len(console_errors)}")
            assert passed, f"Page {name} failed banner verification"

        print("\n=== STEP 2: VERIFYING EXPLORE DATA MODES & DATASET INSPECTOR ===")
        page.goto(f"http://127.0.0.1:{PORT}/explore.html", wait_until="networkidle")
        
        # Check default data mode is frozen
        mode_val = page.locator("#filter-data-mode").input_value()
        callout_text = page.locator("#data-mode-callout-title").inner_text()
        print(f"Default Data Mode: {mode_val} (Callout: {callout_text})")
        assert mode_val == "frozen", f"Expected frozen, got {mode_val}"
        assert "Academic Review Mode" in callout_text

        # Switch to live mode
        print("Switching to 'live' mode...")
        page.select_option("#filter-data-mode", "live")
        page.wait_for_timeout(1000)
        callout_text_live = page.locator("#data-mode-callout-title").inner_text()
        print(f"Live Mode Callout: {callout_text_live}")
        assert "Extended / Live Mode" in callout_text_live

        # Check Dataset Inspector Stream badges
        badges = page.locator(".stream-badge--live").all_text_contents()
        print(f"Found {len(badges)} 'Live Extension' badges in Dataset Inspector")
        assert len(badges) > 0, "No live badges found in Dataset Inspector"
        page.screenshot(path=os.path.join(SCREENSHOT_DIR, "explore_live_mode.png"))

        # Switch to combined mode
        print("Switching to 'combined' mode...")
        page.select_option("#filter-data-mode", "combined")
        page.wait_for_timeout(1000)
        callout_text_comb = page.locator("#data-mode-callout-title").inner_text()
        print(f"Combined Mode Callout: {callout_text_comb}")
        assert "Complete Continuity Mode" in callout_text_comb
        page.screenshot(path=os.path.join(SCREENSHOT_DIR, "explore_combined_mode.png"))

        print("\n=== STEP 3: VERIFYING FROZEN BASELINE NOTICES ON STATS & ML PAGES ===")
        for pg_name, pg_url in [("Statistics", "/statistics.html"), ("Machine Learning", "/machine-learning.html")]:
            page.goto(f"http://127.0.0.1:{PORT}{pg_url}", wait_until="networkidle")
            notice = page.locator(".frozen-baseline-notice")
            assert notice.count() > 0, f"Missing .frozen-baseline-notice on {pg_name}"
            notice_text = notice.inner_text()
            print(f"{pg_name} notice: {notice_text[:75]}...")
            assert "September 21, 2026" in notice_text
            page.screenshot(path=os.path.join(SCREENSHOT_DIR, f"{pg_name.lower().replace(' ', '_')}_notice.png"))

        browser.close()

    print("\nALL BROWSER QA CHECKS PASSED PERFECTLY!")

if __name__ == "__main__":
    main()
