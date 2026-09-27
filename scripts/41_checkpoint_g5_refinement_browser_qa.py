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
SCREENSHOTS_DIR = os.path.join(DOCS_DIR, 'screenshots', 'g5_refinement')
os.makedirs(SCREENSHOTS_DIR, exist_ok=True)

class QuietHTTPHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DOCS_DIR, **kwargs)
    def log_message(self, format, *args):
        pass  # Quiet server

def run_browser_qa():
    PORT = 8895
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
        # 1. Desktop 1920x1080 Tests (Header Architecture & Dimensions)
        # =====================================================================
        context_1920 = browser.new_context(viewport={"width": 1920, "height": 1080})
        page_1920 = context_1920.new_page()
        page_1920.goto(f"http://localhost:{PORT}/index.html", wait_until="networkidle")
        page_1920.wait_for_timeout(500)

        header_box = page_1920.locator(".site-header").bounding_box()
        record("Desktop 1920: Header Height ~80px",
               header_box and 75 <= header_box["height"] <= 85,
               f"Header height: {header_box['height'] if header_box else 'None'}px")

        brand_badge = page_1920.locator(".brand-badge").inner_text().strip()
        record("Desktop 1920: Brand Badge [COURSE PROJECT]",
               brand_badge == "COURSE PROJECT",
               f"Found badge: '{brand_badge}'")

        brand_title = page_1920.locator(".brand-title").inner_text().strip()
        record("Desktop 1920: Brand Title 'Urban Air Quality'",
               brand_title == "Urban Air Quality",
               f"Found title: '{brand_title}'")

        brand_sub = page_1920.locator(".brand-descriptor").inner_text().strip()
        expected_sub = "Statistics for Machine Learning · Project Based Learning · Code-Crew-Nexus"
        record("Desktop 1920: Expanded Academic Subtitle",
               brand_sub == expected_sub,
               f"Found sub: '{brand_sub}'")

        # Nav links nowrap check
        nav_wrap = page_1920.evaluate("""() => {
            const list = document.querySelector('.main-nav');
            return window.getComputedStyle(list).flexWrap;
        }""")
        record("Desktop 1920: Nav List nowrap", nav_wrap == "nowrap", f"flex-wrap: {nav_wrap}")

        # Active link indicator check
        active_link_text = page_1920.locator(".nav-link.active").inner_text().strip()
        record("Desktop 1920: Active Link 'Home'", "Home" in active_link_text, f"Active link: '{active_link_text}'")

        # Zero horizontal overflow
        scroll_width = page_1920.evaluate("() => document.documentElement.scrollWidth")
        record("Desktop 1920: Zero Horizontal Overflow", scroll_width <= 1920, f"scrollWidth: {scroll_width}px")

        # Screenshot 1920
        page_1920.screenshot(path=os.path.join(SCREENSHOTS_DIR, "header_desktop_1920.png"), clip={"x": 0, "y": 0, "width": 1920, "height": 120})

        # =====================================================================
        # 2. Desktop 1440x900 Tests
        # =====================================================================
        context_1440 = browser.new_context(viewport={"width": 1440, "height": 900})
        page_1440 = context_1440.new_page()
        page_1440.goto(f"http://localhost:{PORT}/index.html", wait_until="networkidle")
        page_1440.wait_for_timeout(500)

        header_box_1440 = page_1440.locator(".site-header").bounding_box()
        record("Desktop 1440: Header Height ~80px",
               header_box_1440 and 75 <= header_box_1440["height"] <= 85,
               f"Header height: {header_box_1440['height'] if header_box_1440 else 'None'}px")

        scroll_width_1440 = page_1440.evaluate("() => document.documentElement.scrollWidth")
        record("Desktop 1440: Zero Horizontal Overflow", scroll_width_1440 <= 1440, f"scrollWidth: {scroll_width_1440}px")

        page_1440.screenshot(path=os.path.join(SCREENSHOTS_DIR, "header_desktop_1440.png"), clip={"x": 0, "y": 0, "width": 1440, "height": 120})

        # Also test About page at 1440
        page_1440.goto(f"http://localhost:{PORT}/about.html", wait_until="networkidle")
        page_1440.wait_for_timeout(500)

        about_active = page_1440.locator(".nav-link.active").inner_text().strip()
        record("Desktop 1440 About: Active Link 'About'", "About" in about_active, f"Active link: '{about_active}'")

        about_headings = [h.inner_text().strip() for h in page_1440.query_selector_all("h2")]
        has_team = any("Team" in h or "Investigators" in h for h in about_headings)
        has_scope = any("Scope" in h or "Design" in h for h in about_headings)
        has_objectives = any("Objectives" in h for h in about_headings)
        record("Desktop 1440 About: Core Academic Sections Present", has_team and has_scope and has_objectives, f"Headings: {about_headings[:4]}")

        # Check team casing
        about_body_text = page_1440.locator("body").inner_text()
        record("Desktop 1440 About: Team Name 'Rishit Ghosh' Title Case",
               "Rishit Ghosh" in about_body_text and "RISHIT GHOSH" not in about_body_text,
               "Verified Title Case for team member Rishit Ghosh")

        # Full page screenshot of About
        page_1440.screenshot(path=os.path.join(SCREENSHOTS_DIR, "about_desktop_1440.png"), full_page=True)

        # =====================================================================
        # 3. Small Laptop 1280x800 & Common Laptop 1366x768 Tests
        # =====================================================================
        for w, h, name in [(1366, 768, "Laptop 1366"), (1280, 800, "Laptop 1280")]:
            ctx = browser.new_context(viewport={"width": w, "height": h})
            pg = ctx.new_page()
            pg.goto(f"http://localhost:{PORT}/explore.html", wait_until="networkidle")
            pg.wait_for_timeout(500)

            sw = pg.evaluate("() => document.documentElement.scrollWidth")
            record(f"{name}: Zero Horizontal Overflow", sw <= w, f"scrollWidth: {sw}px (<= {w}px)")

            nav_toggle_visible = pg.locator(".nav-toggle").is_visible()
            record(f"{name}: Nav Toggle Hidden on Desktop", not nav_toggle_visible, "Nav toggle correctly hidden")

            if w == 1280:
                pg.screenshot(path=os.path.join(SCREENSHOTS_DIR, "header_desktop_1280.png"), clip={"x": 0, "y": 0, "width": 1280, "height": 120})

        # =====================================================================
        # 4. Tablet Landscape / Breakpoint Threshold 1024x768 (<= 1080px)
        # =====================================================================
        context_1024 = browser.new_context(viewport={"width": 1024, "height": 768})
        page_1024 = context_1024.new_page()
        page_1024.goto(f"http://localhost:{PORT}/statistics.html", wait_until="networkidle")
        page_1024.wait_for_timeout(500)

        nav_toggle_visible_1024 = page_1024.locator(".nav-toggle").is_visible()
        record("Tablet 1024: Nav Toggle Visible (<= 1080px Breakpoint)", nav_toggle_visible_1024, "Nav toggle visible")

        sw_1024 = page_1024.evaluate("() => document.documentElement.scrollWidth")
        record("Tablet 1024: Zero Horizontal Overflow", sw_1024 <= 1024, f"scrollWidth: {sw_1024}px")

        page_1024.screenshot(path=os.path.join(SCREENSHOTS_DIR, "header_tablet_1024_nav.png"), clip={"x": 0, "y": 0, "width": 1024, "height": 120})

        # =====================================================================
        # 5. Mobile Portrait 390x844 (iPhone 12/13/14)
        # =====================================================================
        context_390 = browser.new_context(viewport={"width": 390, "height": 844})
        page_390 = context_390.new_page()
        page_390.goto(f"http://localhost:{PORT}/machine-learning.html", wait_until="networkidle")
        page_390.wait_for_timeout(500)

        sw_390 = page_390.evaluate("() => document.documentElement.scrollWidth")
        record("Mobile 390: Zero Horizontal Overflow", sw_390 <= 390, f"scrollWidth: {sw_390}px")

        # Header collapsed screenshot
        page_390.screenshot(path=os.path.join(SCREENSHOTS_DIR, "header_mobile_390_nav.png"), clip={"x": 0, "y": 0, "width": 390, "height": 140})

        # Open Drawer
        nav_toggle = page_390.locator(".nav-toggle")
        nav_toggle.click()
        page_390.wait_for_timeout(400)

        drawer_open = page_390.locator(".main-nav.open").is_visible()
        aria_expanded = nav_toggle.get_attribute("aria-expanded")
        record("Mobile 390: Drawer Opens on Click", drawer_open and aria_expanded == "true",
               f"Drawer visible: {drawer_open}, aria-expanded: {aria_expanded}")

        page_390.screenshot(path=os.path.join(SCREENSHOTS_DIR, "header_mobile_390_drawer_open.png"))

        # Close Drawer
        nav_toggle.click()
        page_390.wait_for_timeout(300)
        drawer_closed = not page_390.locator(".main-nav.open").is_visible()
        record("Mobile 390: Drawer Closes on Click", drawer_closed, f"Drawer closed: {drawer_closed}")

        # =====================================================================
        # 6. file:// Protocol Fallback on Explore Data Page
        # =====================================================================
        context_file = browser.new_context(viewport={"width": 1440, "height": 900})
        page_file = context_file.new_page()
        explore_file_path = f"file:///{DOCS_DIR.replace(os.sep, '/')}/explore.html"
        page_file.goto(explore_file_path, wait_until="load")
        page_file.wait_for_timeout(800)

        # Verify #explore-load-error is displayed
        load_error = page_file.locator("#explore-load-error")
        load_error_visible = load_error.is_visible()
        record("file:// Explore: Load Error Alert Visible", load_error_visible, "Load error alert is visible")

        load_error_role = load_error.get_attribute("role")
        record("file:// Explore: Load Error Alert Role='alert'", load_error_role == "alert", f"role='{load_error_role}'")

        load_error_text = load_error.inner_text()
        has_guidance = "LOCAL PREVIEW REQUIRED" in load_error_text
        has_cmd = "serve_website_local.py" in load_error_text
        record("file:// Explore: Helpful Local Server Guidance", has_guidance and has_cmd,
               f"Guidance: {has_guidance}, Command: {has_cmd}")

        # Verify empty state is NOT displayed as error
        empty_state = page_file.locator("#explore-empty-state")
        empty_state_visible = empty_state.is_visible()
        record("file:// Explore: Empty State NOT Confused with Load Error", not empty_state_visible,
               f"Empty state visible: {empty_state_visible}")

        # Copy button test
        copy_btn = page_file.locator("#btn-copy-preview-cmd")
        copy_btn_exists = copy_btn.is_visible()
        record("file:// Explore: Copy Server Command Button Present", copy_btn_exists, "Found #btn-copy-preview-cmd")

        page_file.screenshot(path=os.path.join(SCREENSHOTS_DIR, "explore_file_protocol_error.png"))

    print("\n=======================================================")
    print(f"Browser QA Summary: {sum(1 for _, s, _ in results if s == 'PASS')}/{len(results)} PASSED")
    print("=======================================================")
    all_passed = all(s == "PASS" for _, s, _ in results)
    if not all_passed:
        sys.exit(1)

if __name__ == "__main__":
    run_browser_qa()
