import time
import sys
from playwright.sync_api import sync_playwright

BASE = 'https://code-crew-nexus.github.io/UrbanAirQualityIndex-PollutantDriftAnalysis'

def verify_live():
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(viewport={'width': 1440, 'height': 900})

        print("Checking Live GitHub Pages Deployment Status...")
        # Poll up to 10 times (15s sleep) to allow GitHub Pages build to complete if in flight
        deployed = False
        for attempt in range(1, 11):
            try:
                # Add cache-buster query param to bypass CDN cache
                cache_buster = f"?v={int(time.time())}"
                resp = page.goto(f"{BASE}/index.html{cache_buster}", wait_until="networkidle")
                title = page.locator(".brand-title").inner_text().strip()
                if title == "Urban Air Quality":
                    print(f"[Attempt {attempt}] New header deployed successfully! Title: '{title}'")
                    deployed = True
                    break
                else:
                    print(f"[Attempt {attempt}] Title still '{title}'. Waiting for GitHub Pages deployment...")
                    time.sleep(15)
            except Exception as e:
                print(f"[Attempt {attempt}] Error connecting: {e}. Retrying...")
                time.sleep(15)

        if not deployed:
            print("Warning: GitHub Pages CDN may take a few minutes to invalidate cache.")
        
        # 1. Verify Header on Desktop
        badge = page.locator(".brand-badge").inner_text().strip()
        print(f"Live Brand Badge: '{badge}' (Expected: 'COURSE PROJECT')")
        
        subtitle = page.locator(".brand-descriptor").inner_text().strip()
        print(f"Live Brand Subtitle: '{subtitle}'")

        # 2. Check All 6 Pages
        pages = ['index.html', 'explore.html', 'statistics.html', 'machine-learning.html', 'documentation.html', 'about.html']
        for pg in pages:
            cb = f"?v={int(time.time())}"
            r = page.goto(f"{BASE}/{pg}{cb}", wait_until="networkidle")
            print(f"Live {pg}: HTTP {r.status}")

        # 3. Check About Page Content on Live
        page.goto(f"{BASE}/about.html?v={int(time.time())}", wait_until="networkidle")
        page.wait_for_timeout(1000)
        about_text = page.locator("body").inner_text()
        has_title_case_rishit = "Rishit Ghosh" in about_text and "RISHIT GHOSH" not in about_text
        print(f"Live About: Rishit Ghosh Title Case: {has_title_case_rishit}")
        has_21_stations = "21 unique physical" in about_text
        print(f"Live About: 21 unique stations present: {has_21_stations}")
        has_570_days = "570 continuous" in about_text
        print(f"Live About: 570 continuous days present: {has_570_days}")

        # 4. Check Mobile 390 on Live
        page_m = browser.new_page(viewport={'width': 390, 'height': 844})
        page_m.goto(f"{BASE}/index.html?v={int(time.time())}", wait_until="networkidle")
        page_m.wait_for_timeout(500)
        sw_390 = page_m.evaluate("() => document.documentElement.scrollWidth")
        print(f"Live Mobile 390 scrollWidth: {sw_390}px (Overflow <= 390: {sw_390 <= 390})")

        browser.close()
        print("\nAll Live Checks Finished!")

if __name__ == "__main__":
    verify_live()
