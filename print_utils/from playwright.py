from playwright import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch()
    print("Playwright working")
    browser.close()