import asyncio
from playwright.async_api import async_playwright
import time
import subprocess

async def run_nav_tests():
    print("Starting server...")
    server = subprocess.Popen(["python", "scripts/serve_website_local.py"])
    time.sleep(2)  # wait for server to start

    try:
        async with async_playwright() as p:
            browser = await p.chromium.launch(headless=True)
            context = await browser.new_context(viewport={"width": 1440, "height": 900})
            page = await context.new_page()

            print("Loading page...")
            await page.goto("http://localhost:8000/")
            await page.wait_for_load_state("networkidle")
            
            # Initial state
            active_links = await page.locator(".main-nav .nav-link.active").count()
            assert active_links == 1, f"Expected 1 active link, found {active_links}"
            
            home_active = await page.locator(".main-nav .nav-link.active").text_content()
            assert "Home" in home_active, f"Expected 'Home' to be active, got {home_active}"
            
            print("Clicking Explore Data...")
            await page.locator(".main-nav .nav-link:has-text('Explore Data')").click()
            await page.wait_for_timeout(1000) # wait for smooth scroll and JS
            
            active_links = await page.locator(".main-nav .nav-link.active").count()
            assert active_links == 1, f"Expected 1 active link after click, found {active_links}"
            explore_active = await page.locator(".main-nav .nav-link.active").text_content()
            assert "Explore Data" in explore_active, f"Expected 'Explore Data' active, got {explore_active}"
            
            print("Scrolling to Statistics...")
            await page.evaluate("window.scrollTo(0, document.getElementById('statistics').offsetTop)")
            await page.wait_for_timeout(1000)
            
            active_links = await page.locator(".main-nav .nav-link.active").count()
            assert active_links == 1, f"Expected 1 active link after scroll, found {active_links}"
            stat_active = await page.locator(".main-nav .nav-link.active").text_content()
            assert "Statistical Analysis" in stat_active, f"Expected 'Statistical Analysis', got {stat_active}"
            
            print("Scrolling to Machine Learning...")
            await page.evaluate("window.scrollTo(0, document.getElementById('machine-learning').offsetTop)")
            await page.wait_for_timeout(1000)
            
            active_links = await page.locator(".main-nav .nav-link.active").count()
            assert active_links == 1, f"Expected 1 active link after scroll, found {active_links}"
            ml_active = await page.locator(".main-nav .nav-link.active").text_content()
            assert "Machine Learning" in ml_active, f"Expected 'Machine Learning', got {ml_active}"
            
            print("All Navigation Behavior tests passed.")
            await browser.close()
    finally:
        server.terminate()
        server.wait()

if __name__ == "__main__":
    asyncio.run(run_nav_tests())
