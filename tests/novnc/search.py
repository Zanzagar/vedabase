"""search.py URL OUT.png: connect through noVNC, click Folio's quick-search box,
type a query and press Enter, then save a screenshot for a person to look at
(the status bar shows the hits). Exits 1 if the viewer does not connect."""
import os
import sys
import time

from playwright.sync_api import sync_playwright

url, out = sys.argv[1], sys.argv[2]
with sync_playwright() as p:
    browser = p.chromium.launch(executable_path=os.environ["CHROME_EXE"])
    page = browser.new_page(viewport={"width": 1600, "height": 1000})
    page.goto(url)
    time.sleep(10)
    status = page.evaluate("() => (document.getElementById('noVNC_status') || {}).textContent || ''")
    print(f"status: {status!r}")
    canvas = page.locator("#noVNC_container canvas")
    box = canvas.bounding_box()
    if not box or not status.startswith("Connected"):
        sys.exit(1)
    # The quick-search box sits at (430, 66) on the 1600x1000 remote screen.
    sx, sy = box["width"] / 1600, box["height"] / 1000
    page.mouse.click(box["x"] + 430 * sx, box["y"] + 66 * sy, click_count=3)
    time.sleep(0.5)
    page.keyboard.type("dehino 'smin yatha dehe", delay=40)
    page.keyboard.press("Enter")
    time.sleep(8)
    page.screenshot(path=out)
    browser.close()
