import asyncio
from playwright.async_api import async_playwright
import subprocess
import time
import colorsys

def parse_rgb(rgb_str):
    if not rgb_str.startswith('rgb'):
        return None
    
    rgb_str = rgb_str.replace('rgba(', '').replace('rgb(', '').replace(')', '')
    parts = [float(x.strip()) for x in rgb_str.split(',')]
    return parts[:3]

def get_luminance(r, g, b):
    a = [x / 255.0 for x in [r, g, b]]
    a = [x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4 for x in a]
    return a[0] * 0.2126 + a[1] * 0.7152 + a[2] * 0.0722

def get_contrast_ratio(rgb1, rgb2):
    l1 = get_luminance(*rgb1)
    l2 = get_luminance(*rgb2)
    return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)

async def check_contrast(page, selector, min_ratio=4.5):
    elements = await page.locator(selector).all()
    for el in elements:
        try:
            color = await el.evaluate("window.getComputedStyle(element).color", arg="element")
            bg = await el.evaluate("""
                (element) => {
                    let bg = window.getComputedStyle(element).backgroundColor;
                    if (bg === 'rgba(0, 0, 0, 0)' || bg === 'transparent') {
                        let parent = element.parentElement;
                        while (parent) {
                            bg = window.getComputedStyle(parent).backgroundColor;
                            if (bg !== 'rgba(0, 0, 0, 0)' && bg !== 'transparent') return bg;
                            parent = parent.parentElement;
                        }
                        return 'rgb(255, 255, 255)'; // Default white
                    }
                    return bg;
                }
            """, arg="element")
            
            c_rgb = parse_rgb(color)
            b_rgb = parse_rgb(bg)
            
            if c_rgb and b_rgb:
                ratio = get_contrast_ratio(c_rgb, b_rgb)
                if ratio < min_ratio:
                    text = await el.text_content()
                    print(f"FAIL: Contrast ratio {ratio:.2f} < {min_ratio} for {selector} ('{text[:30]}...')")
                    print(f"      Color: {color}, Background: {bg}")
                    return False
        except Exception as e:
            pass
    return True

async def run_contrast_tests():
    print("Starting server...")
    server = subprocess.Popen(["python", "scripts/serve_website_local.py"])
    time.sleep(2)
    
    try:
        async with async_playwright() as p:
            browser = await p.chromium.launch(headless=True)
            page = await browser.new_page()
            await page.goto("http://localhost:8000/")
            await page.wait_for_load_state("networkidle")
            
            passed = True
            
            # Normal text (4.5:1)
            tests_normal = [
                ".home-hero__summary",
                ".presentation-card__body",
                ".tech-chip",
                ".journey-node",
                ".split-card__list",
                ".section-lead",
                ".footer-desc",
                ".footer-list a"
            ]
            
            for selector in tests_normal:
                if not await check_contrast(page, selector, 4.5):
                    passed = False
            
            # Large text (3:1)
            tests_large = [
                ".home-hero__title",
                ".presentation-card__title",
                ".split-card__title",
                ".footer-heading"
            ]
            
            for selector in tests_large:
                if not await check_contrast(page, selector, 3.0):
                    passed = False
                    
            if not passed:
                raise Exception("Contrast QA failed!")
            else:
                print("All Contrast QA tests passed.")
                
            await browser.close()
    finally:
        server.terminate()
        server.wait()

if __name__ == "__main__":
    asyncio.run(run_contrast_tests())
