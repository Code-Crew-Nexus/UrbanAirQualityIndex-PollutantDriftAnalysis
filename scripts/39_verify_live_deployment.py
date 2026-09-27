from playwright.sync_api import sync_playwright
import sys

BASE = 'https://code-crew-nexus.github.io/UrbanAirQualityIndex-PollutantDriftAnalysis'

def verify():
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(viewport={'width': 1440, 'height': 900})
        
        print("Verifying Live GitHub Pages Deployment...")
        # Check explore.html
        resp = page.goto(f'{BASE}/explore.html', wait_until='networkidle')
        page.wait_for_timeout(1000)
        print(f"explore.html HTTP status: {resp.status}")
        
        card = page.query_selector('#dataset-inspector-card')
        print(f"Live #dataset-inspector-card present: {card is not None}")
        
        title = page.locator('#dataset-inspector-card .chart-card-title').inner_text()
        print(f"Live title: '{title}'")
        
        rows = page.query_selector_all('#dataset-table-body tr.dataset-row')
        print(f"Live observation rows rendered: {len(rows)}")
        
        sticky = page.evaluate("() => window.getComputedStyle(document.querySelector('.sticky-col')).position")
        print(f"Live sticky Date column position: {sticky}")
        
        csv_btn = page.query_selector('#btn-download-csv')
        print(f"Live CSV download button visible: {csv_btn.is_visible() if csv_btn else False}")
        
        footer_text = page.locator('.site-footer').inner_text()
        has_chips = 'Scientific v0.6' in footer_text and 'Website v0.7.1' in footer_text
        print(f"Live footer has release chips: {has_chips}")
        
        favicon_link = page.query_selector("link[rel*='icon']")
        print(f"Live favicon link present: {favicon_link is not None}")
        
        # Expand row test
        expand_btn = page.query_selector('#dataset-table-body tr.dataset-row:first-child .row-expand-btn')
        if expand_btn:
            expand_btn.click()
            page.wait_for_timeout(300)
            controls_id = expand_btn.get_attribute('aria-controls')
            detail = page.query_selector(f'#{controls_id}')
            print(f"Live row expansion working: {detail.is_visible() if detail else False}")
            
        # Check mobile on live site
        page_m = browser.new_page(viewport={'width': 390, 'height': 844})
        resp_m = page_m.goto(f'{BASE}/explore.html', wait_until='networkidle')
        page_m.wait_for_timeout(1000)
        
        overflow = page_m.evaluate("() => document.documentElement.scrollWidth > window.innerWidth")
        print(f"Live mobile 390 page overflow: {overflow}")
        
        scrollable = page_m.evaluate("() => { const el = document.querySelector('.dataset-table-wrapper'); return el.scrollWidth > el.clientWidth; }")
        print(f"Live mobile table internal scrollable: {scrollable}")
        
        touch_size = page_m.evaluate("""() => {
            const btn = document.querySelector('.row-expand-btn');
            if (!btn) return 0;
            const r = btn.getBoundingClientRect();
            return Math.min(r.width, r.height);
        }""")
        print(f"Live mobile expand button touch target: {touch_size}px")
        
        # Test other pages
        pages = ['index.html', 'statistics.html', 'machine-learning.html', 'documentation.html', 'about.html']
        for pg in pages:
            r = page.goto(f'{BASE}/{pg}', wait_until='networkidle')
            print(f"Live {pg}: HTTP {r.status}")
            
        # Test favicon assets
        assets = ['favicon.svg', 'favicon-32x32.png', 'favicon.ico', 'apple-touch-icon.png']
        for a in assets:
            r = page.goto(f'{BASE}/{a}')
            print(f"Live {a}: HTTP {r.status} ({len(r.body())} bytes)")
            
        browser.close()
        print("\nAll Live Checks Completed Successfully!")

if __name__ == '__main__':
    verify()
