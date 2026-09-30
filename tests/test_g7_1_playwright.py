import asyncio
from playwright.async_api import async_playwright
import time
import sys
import subprocess

async def run_tests():
    print("Starting server...")
    server = subprocess.Popen(["python", "scripts/serve_website_local.py"])
    time.sleep(2)  # wait for server to start

    try:
        async with async_playwright() as p:
            browser = await p.chromium.launch(headless=True)
            context = await browser.new_context(viewport={"width": 1440, "height": 900})
            page = await context.new_page()

            errors = []
            page.on("console", lambda msg: [print("CONSOLE:", msg.text), errors.append(msg.text)] if msg.type == "error" else print("CONSOLE:", msg.text))
            
            responses = {}
            page.on("response", lambda res: responses.update({res.url: res.status}))
            
            print("Testing HOME...")
            resp = await page.goto("http://localhost:8000/")
            assert resp.status == 200, "Home page failed to load"
            
            # Check dynamic date
            await page.wait_for_function("document.getElementById('dynamic-live-dates').innerText.includes('2026')", timeout=5000)
            
            # Check KaTeX
            katex_elements = await page.query_selector_all(".katex")
            assert len(katex_elements) > 0, "KaTeX formulas not rendered"

            print("Testing EXPLORE (Live)...")
            await page.goto("http://localhost:8000/?mode=live#explore")
            await page.evaluate("window.initExploreSection()")
            await page.wait_for_selector("#exploreChart", state="attached")
            
            # Ensure init function exists
            init_exists = await page.evaluate("typeof window.initExploreSection === 'function'")
            assert init_exists, "initExploreSection missing"
            
            # Wait for data to load
            await page.wait_for_selector("#dataset-table-body tr", state="attached")
            
            # Validate DOM states
            mode_val = await page.evaluate("document.getElementById('filter-data-mode').value")
            assert mode_val == "live", f"Expected mode live, got {mode_val}"
            
            options = await page.evaluate("document.querySelectorAll('#filter-station option').length")
            assert options > 1, f"Expected station options > 1, got {options}"
            
            rows = await page.evaluate("document.querySelectorAll('#dataset-table-body tr').length")
            assert rows > 0, f"Expected dataset rows > 0, got {rows}"
            
            metric = await page.evaluate("document.getElementById('metric-valid-obs').innerText")
            assert metric != "—", "Metric valid obs not populated"
            
            chart_exists = await page.evaluate("!!Chart.getChart('exploreChart')")
            assert chart_exists, "Explore chart instance missing"
            
            print("Testing STATISTICS...")
            await page.goto("http://localhost:8000/#statistics")
            await page.evaluate("window.initStatisticsSection()")
            await page.wait_for_selector("#driftComparisonChart", state="attached")
            await page.wait_for_selector("#stat-filter-station option", state="attached")
            
            stat_options = await page.evaluate("document.querySelectorAll('#stat-filter-station option').length")
            assert stat_options > 1, f"Expected stat options > 1, got {stat_options}"
            
            drift_text = await page.evaluate("document.getElementById('drift-dz').innerText")
            assert drift_text != "—", "Drift text not populated"
            
            stat_chart_exists = await page.evaluate("!!Chart.getChart('driftComparisonChart')")
            assert stat_chart_exists, "Stat chart instance missing"
            
            print("Testing MACHINE LEARNING...")
            await page.goto("http://localhost:8000/#machine-learning")
            await page.evaluate("window.initMachineLearningSection()")
            await page.wait_for_selector("#regressionComparisonChart", state="attached")
            await page.wait_for_selector("#regression-table-tbody tr", state="attached")
            
            ml_rows = await page.evaluate("document.querySelectorAll('#regression-table-tbody tr').length")
            assert ml_rows > 0, "ML regression table rows missing"
            
            ml_chart_exists = await page.evaluate("!!Chart.getChart('regressionComparisonChart')")
            assert ml_chart_exists, "Regression chart instance missing"
            
            # Check 404s
            for url, status in responses.items():
                if "favicon" not in url and status == 404:
                    assert False, f"404 Error for {url}"
            
            assert len(errors) == 0, f"Console errors found: {errors}"
            
            print("All functional tests passed.")
            await browser.close()
            
    finally:
        server.terminate()
        server.wait()

if __name__ == "__main__":
    asyncio.run(run_tests())
