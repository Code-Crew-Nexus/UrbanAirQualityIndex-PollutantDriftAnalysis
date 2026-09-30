import asyncio
from playwright.async_api import async_playwright
import time
import subprocess
import os

async def run_visual_qa():
    print("Starting server...")
    server = subprocess.Popen(["python", "scripts/serve_website_local.py"])
    time.sleep(2)  # wait for server to start
    
    os.makedirs("scratch/screenshots", exist_ok=True)

    try:
        async with async_playwright() as p:
            browser = await p.chromium.launch(headless=True)
            
            # Desktop
            context = await browser.new_context(viewport={"width": 1440, "height": 900})
            page = await context.new_page()
            
            print("Loading Desktop...")
            await page.goto("http://localhost:8000/")
            await page.wait_for_load_state("networkidle")
            
            # Check overflow
            overflow = await page.evaluate("document.documentElement.scrollWidth > document.documentElement.clientWidth")
            print(f"Desktop Overflow: {overflow}")
            
            await page.screenshot(path="scratch/screenshots/desktop_home.png")
            
            await page.evaluate("window.scrollTo(0, document.getElementById('explore').offsetTop)")
            await page.wait_for_timeout(1000)
            await page.screenshot(path="scratch/screenshots/desktop_explore.png")
            
            await page.evaluate("window.scrollTo(0, document.getElementById('statistics').offsetTop)")
            await page.wait_for_timeout(1000)
            await page.screenshot(path="scratch/screenshots/desktop_statistics.png")
            
            await page.evaluate("window.scrollTo(0, document.getElementById('machine-learning').offsetTop)")
            await page.wait_for_timeout(1000)
            await page.screenshot(path="scratch/screenshots/desktop_ml.png")
            
            await context.close()
            
            # Mobile
            context_m = await browser.new_context(viewport={"width": 390, "height": 844})
            page_m = await context_m.new_page()
            
            print("Loading Mobile...")
            await page_m.goto("http://localhost:8000/")
            await page_m.wait_for_load_state("networkidle")
            
            # Check overflow
            overflow_m = await page_m.evaluate("document.documentElement.scrollWidth > document.documentElement.clientWidth")
            print(f"Mobile Overflow: {overflow_m}")
            if overflow_m:
                width = await page_m.evaluate("document.documentElement.scrollWidth")
                print(f"Mobile scrollWidth is {width} but clientWidth is 390")
            
            await page_m.screenshot(path="scratch/screenshots/mobile_home.png")
            
            await page_m.evaluate("window.scrollTo(0, document.getElementById('explore').offsetTop)")
            await page_m.wait_for_timeout(1000)
            await page_m.screenshot(path="scratch/screenshots/mobile_explore.png")
            
            await context_m.close()
            
            print("Visual QA complete.")
            await browser.close()
    finally:
        server.terminate()
        server.wait()

if __name__ == "__main__":
    asyncio.run(run_visual_qa())
