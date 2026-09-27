import os
import sys
import http.server
import socketserver
import threading
import time
from playwright.sync_api import sync_playwright

if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

DOCS_DIR = os.path.abspath('docs')
SCREENSHOTS_DIR = os.path.join(DOCS_DIR, 'screenshots', 'g5_addons')
os.makedirs(SCREENSHOTS_DIR, exist_ok=True)

class QuietHTTPHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DOCS_DIR, **kwargs)
    def log_message(self, format, *args):
        pass # Quiet server

def run_browser_qa():
    PORT = 8765
    httpd = socketserver.TCPServer(("", PORT), QuietHTTPHandler)
    server_thread = threading.Thread(target=httpd.serve_forever, daemon=True)
    server_thread.start()
    print(f"Local static server running at http://localhost:{PORT}")
    time.sleep(1)

    results = []
    def record(name, passed, detail=""):
        status = "PASS" if passed else "FAIL"
        results.append((name, status, detail))
        print(f"[{status}] {name} - {detail}")

    with sync_playwright() as p:
        browser = p.chromium.launch()

        # =====================================================================
        # 1. Desktop 1440x900 Tests
        # =====================================================================
        context_desktop = browser.new_context(viewport={"width": 1440, "height": 900})
        page = context_desktop.new_page()

        # Explore Data Page
        page.goto(f"http://localhost:{PORT}/explore.html", wait_until="networkidle")
        page.wait_for_timeout(1000)

        # 1.1 Dataset Inspector Card & Heading
        card = page.query_selector("#dataset-inspector-card")
        record("Explore: Dataset Inspector Card Exists", card is not None, "Found #dataset-inspector-card")

        title = page.locator("#dataset-inspector-card .chart-card-title").inner_text()
        record("Explore: Title is 'Dataset Inspector'", title == "Dataset Inspector", f"Title: '{title}'")

        subtitle = page.locator("#dataset-inspector-card .chart-card-subtitle").inner_text()
        record("Explore: Authoritative Subtitle", "Filtered frozen daily observations" in subtitle, f"Subtitle: '{subtitle}'")

        # 1.2 Table & Column Headers (10 columns)
        headers = [h.inner_text().split('\n')[0].strip() for h in page.query_selector_all("#dataset-inspector-table thead th")]
        expected_cols = ["Date", "AQI", "Category", "Dominant", "PM2.5", "PM10", "O3 8h Max", "Temperature", "Humidity", "Wind Speed"]
        cols_match = all(exp in " ".join(headers) for exp in ["Date", "AQI", "Category", "Dominant", "PM2.5", "PM10", "O3", "Temperature", "Humidity", "Wind Speed"])
        record("Explore: 10 Table Column Headers", cols_match and len(headers) == 10, f"Found {len(headers)} columns: {headers}")

        # 1.3 Rows count & Status line
        rows = page.query_selector_all("#dataset-table-body tr.dataset-row")
        record("Explore: Table Populated with Observations", len(rows) > 0, f"Rendered {len(rows)} observation rows")

        status_text = page.locator("#dataset-status-bar").inner_text()
        record("Explore: Status Bar Counter", "scheduled" in status_text and "valid" in status_text, f"Status: '{status_text}'")

        # 1.4 Expand First Row & Check Details
        first_expand_btn = page.query_selector("#dataset-table-body tr.dataset-row:first-child .row-expand-btn")
        if first_expand_btn:
            aria_expanded_before = first_expand_btn.get_attribute("aria-expanded")
            controls_id = first_expand_btn.get_attribute("aria-controls")
            first_expand_btn.click()
            page.wait_for_timeout(300)

            aria_expanded_after = first_expand_btn.get_attribute("aria-expanded")
            detail_row = page.query_selector(f"#{controls_id}")
            detail_visible = detail_row.is_visible() if detail_row else False

            record("Explore: Row Expansion Toggle", aria_expanded_before == "false" and aria_expanded_after == "true" and detail_visible,
                   f"Before: {aria_expanded_before}, After: {aria_expanded_after}, Detail visible: {detail_visible}")

            # Verify detail sections: Identification, AQI Composite, Pollutant Inputs, Meteorology
            detail_text = detail_row.inner_text() if detail_row else ""
            has_id = "IDENTIFICATION" in detail_text.upper() and "Station ID:" in detail_text
            has_aqi = "AQI COMPOSITE" in detail_text.upper()
            has_pollutants = "POLLUTANT INPUTS" in detail_text.upper()
            has_met = "METEOROLOGY" in detail_text.upper()

            record("Explore: Expanded Record Detail Sections", has_id and has_aqi and has_pollutants and has_met,
                   f"Identification: {has_id}, AQI: {has_aqi}, Pollutants: {has_pollutants}, Meteorology: {has_met}")

            # Screenshot: Desktop Expanded Record
            shot_expanded = os.path.join(SCREENSHOTS_DIR, "desktop_dataset_inspector_expanded.png")
            page.locator("#dataset-inspector-card").screenshot(path=shot_expanded)
            print(f"Captured: {shot_expanded}")

        # 1.5 Sticky Column Checks
        sticky_th = page.evaluate("() => window.getComputedStyle(document.querySelector('.sticky-col')).position")
        record("Explore: Date Column is Sticky", sticky_th == "sticky", f"Computed position: {sticky_th}")

        # 1.6 Download Filtered CSV Button
        csv_btn = page.query_selector("#btn-download-csv")
        record("Explore: CSV Download Button Exists", csv_btn is not None and csv_btn.is_visible(), "Download button present")

        # 1.7 Header styling check (Light warm pearl)
        header_bg = page.evaluate("() => window.getComputedStyle(document.querySelector('.site-header')).backgroundColor")
        record("Explore: Light Header Background", "255" in header_bg or "252" in header_bg, f"Computed header bg: {header_bg}")

        # 1.8 Brand layout (Inline)
        brand_wrapper_display = page.evaluate("() => window.getComputedStyle(document.querySelector('.brand-wrapper')).display")
        record("Explore: Inline Brand Layout", "flex" in brand_wrapper_display, f"Brand wrapper display: {brand_wrapper_display}")

        # 1.9 Active Nav Link Underline
        active_border = page.evaluate("() => window.getComputedStyle(document.querySelector('.nav-link.active')).borderBottomColor")
        record("Explore: Active Nav Jade Underline", "40" in active_border or "25" in active_border or "jade" in active_border, f"Active border color: {active_border}")

        # 1.10 Footer check (3 columns, compact, release chips)
        footer_bg = page.evaluate("() => window.getComputedStyle(document.querySelector('.site-footer')).backgroundColor")
        record("Explore: Compact Dark Footer", "27" in footer_bg or "1B2721" in footer_bg or "rgb(27, 39, 33)" in footer_bg, f"Footer bg: {footer_bg}")

        footer_text = page.locator(".site-footer").inner_text()
        record("Explore: Footer Contains Release Chips", "Scientific v0.6" in footer_text and "Website v0.7.1" in footer_text, "Release chips found in footer")
        record("Explore: Footer Links to #theory", page.query_selector("footer a[href*='documentation.html#theory']") is not None, "Found link to documentation.html#theory")

        # Screenshot: Desktop Full Header & Nav
        shot_header_desktop = os.path.join(SCREENSHOTS_DIR, "desktop_1440_header.png")
        page.locator(".site-header").screenshot(path=shot_header_desktop)
        print(f"Captured: {shot_header_desktop}")

        # Screenshot: Desktop Footer
        shot_footer_desktop = os.path.join(SCREENSHOTS_DIR, "desktop_1440_footer.png")
        page.locator(".site-footer").screenshot(path=shot_footer_desktop)
        print(f"Captured: {shot_footer_desktop}")

        page.close()
        context_desktop.close()

        # =====================================================================
        # 2. Laptop 1366x768 Viewport
        # =====================================================================
        context_laptop = browser.new_context(viewport={"width": 1366, "height": 768})
        page = context_laptop.new_page()
        page.goto(f"http://localhost:{PORT}/explore.html", wait_until="networkidle")
        page.wait_for_timeout(500)

        # Check for horizontal overflow at page level
        has_page_overflow = page.evaluate("() => document.documentElement.scrollWidth > window.innerWidth")
        record("Laptop 1366: No Page Horizontal Overflow", not has_page_overflow, f"Page overflow: {has_page_overflow}")

        shot_header_1366 = os.path.join(SCREENSHOTS_DIR, "laptop_1366_header.png")
        page.locator(".site-header").screenshot(path=shot_header_1366)
        print(f"Captured: {shot_header_1366}")

        page.close()
        context_laptop.close()

        # =====================================================================
        # 3. Tablet 768x1024 Viewport
        # =====================================================================
        context_tablet = browser.new_context(viewport={"width": 768, "height": 1024})
        page = context_tablet.new_page()
        page.goto(f"http://localhost:{PORT}/explore.html", wait_until="networkidle")
        page.wait_for_timeout(500)

        # Mobile nav toggle should be visible at 768px
        nav_toggle = page.query_selector(".nav-toggle")
        toggle_visible = nav_toggle.is_visible() if nav_toggle else False
        record("Tablet 768: Nav Toggle Button Visible", toggle_visible, f"Toggle visible: {toggle_visible}")

        # Has SVG hamburger icon
        svg_icon = page.query_selector(".nav-toggle .hamburger-icon")
        record("Tablet 768: SVG Hamburger Icon Present", svg_icon is not None, "Found .hamburger-icon")

        # Click toggle to open mobile menu
        if nav_toggle:
            nav_toggle.click()
            page.wait_for_timeout(300)
            nav_open = page.evaluate("() => document.querySelector('.main-nav').classList.contains('open')")
            record("Tablet 768: Navigation Opens On Toggle Click", nav_open, f"Nav open: {nav_open}")

            shot_nav_tablet = os.path.join(SCREENSHOTS_DIR, "tablet_768_nav_open.png")
            page.screenshot(path=shot_nav_tablet)
            print(f"Captured: {shot_nav_tablet}")

        page.close()
        context_tablet.close()

        # =====================================================================
        # 4. Mobile 390x844 Viewport (iPhone 12/13/14)
        # =====================================================================
        context_mobile = browser.new_context(viewport={"width": 390, "height": 844})
        page = context_mobile.new_page()
        page.goto(f"http://localhost:{PORT}/explore.html", wait_until="networkidle")
        page.wait_for_timeout(800)

        # Check page level horizontal overflow
        page_overflow_mobile = page.evaluate("() => document.documentElement.scrollWidth > window.innerWidth")
        record("Mobile 390: No Page Horizontal Overflow", not page_overflow_mobile, f"Page overflow: {page_overflow_mobile}")

        # Table wrapper horizontal scrollability
        table_scrollable = page.evaluate("() => { const el = document.querySelector('.dataset-table-wrapper'); return el.scrollWidth > el.clientWidth; }")
        record("Mobile 390: Table Has Internal Horizontal Scroll", table_scrollable, f"Table scrollable: {table_scrollable}")

        # Expand button touch target size >= 40px
        expand_size = page.evaluate("""() => {
            const btn = document.querySelector('.row-expand-btn');
            if (!btn) return 0;
            const r = btn.getBoundingClientRect();
            return Math.min(r.width, r.height);
        }""")
        record("Mobile 390: Expand Button Touch Target >= 40px", expand_size >= 40, f"Target size: {expand_size}px")

        # Scroll table horizontally and take screenshot
        page.evaluate("() => { const el = document.querySelector('.dataset-table-wrapper'); el.scrollLeft = 200; }")
        page.wait_for_timeout(300)

        shot_mobile_table = os.path.join(SCREENSHOTS_DIR, "mobile_390_table_scrolled.png")
        page.locator("#dataset-inspector-card").screenshot(path=shot_mobile_table)
        print(f"Captured: {shot_mobile_table}")

        # Mobile footer screenshot
        shot_mobile_footer = os.path.join(SCREENSHOTS_DIR, "mobile_390_footer.png")
        page.locator(".site-footer").screenshot(path=shot_mobile_footer)
        print(f"Captured: {shot_mobile_footer}")

        page.close()
        context_mobile.close()

        # =====================================================================
        # 5. Favicon Network Verification across all pages
        # =====================================================================
        page = browser.new_page()
        pages_to_test = ["index.html", "explore.html", "statistics.html", "machine-learning.html", "documentation.html", "about.html"]
        for pg in pages_to_test:
            resp = page.goto(f"http://localhost:{PORT}/{pg}", wait_until="networkidle")
            status = resp.status if resp else 0
            record(f"Page Load: {pg}", status == 200, f"HTTP {status}")

            # Verify favicon href
            icon_link = page.query_selector("link[rel*='icon']")
            record(f"Favicon Link: {pg}", icon_link is not None, "Found favicon link tag")

        # Fetch favicon assets directly to verify 200 OK
        favicon_assets = ["favicon.svg", "favicon-16x16.png", "favicon-32x32.png", "favicon-48x48.png", "apple-touch-icon.png", "favicon.ico"]
        for icon in favicon_assets:
            resp = page.goto(f"http://localhost:{PORT}/{icon}")
            record(f"Asset Fetch: {icon}", resp.status == 200, f"HTTP {resp.status}, size {len(resp.body())} bytes")

        page.close()
        browser.close()

    httpd.shutdown()
    print("\n=======================================================")
    print("BROWSER QA VERIFICATION SUMMARY")
    print("=======================================================")
    total = len(results)
    passed = sum(1 for _, s, _ in results if s == "PASS")
    failed = sum(1 for _, s, _ in results if s == "FAIL")
    print(f"Total Checks: {total} | PASSED: {passed} | FAILED: {failed}")
    for name, status, detail in results:
        print(f"  [{status}] {name}: {detail}")
    return failed == 0

if __name__ == '__main__':
    success = run_browser_qa()
    sys.exit(0 if success else 1)
