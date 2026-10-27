"""copy.py URL EXPECTED OUT.png: connect through noVNC and copy a word in Folio
as someone using the browser viewer does: search Bg 2.13's first line,
double-click 'kaumāraṁ' in the passage found (at (912, 323) on the 1600x1000
remote screen), press Ctrl+C. Exits 0 if noVNC's clipboard panel then shows
EXPECTED within 10 seconds, 1 otherwise; OUT.png shows the double-click."""
import os
import sys
import time

from playwright.sync_api import sync_playwright

url, expected, out = sys.argv[1], sys.argv[2], sys.argv[3]
with sync_playwright() as p:
    browser = p.chromium.launch(executable_path=os.environ["CHROME_EXE"])
    page = browser.new_page(viewport={"width": 1600, "height": 1000})
    page.goto(url)
    time.sleep(10)
    status = page.evaluate("() => (document.getElementById('noVNC_status') || {}).textContent || ''")
    print(f"status: {status!r}")
    box = page.locator("#noVNC_container canvas").bounding_box()
    if not box or not status.startswith("Connected"):
        sys.exit(1)
    sx, sy = box["width"] / 1600, box["height"] / 1000
    page.mouse.click(box["x"] + 430 * sx, box["y"] + 66 * sy, click_count=3)
    time.sleep(0.5)
    page.keyboard.type("dehino 'smin yatha dehe", delay=40)
    page.keyboard.press("Enter")
    time.sleep(8)
    page.mouse.dblclick(box["x"] + 912 * sx, box["y"] + 323 * sy)
    time.sleep(1)
    page.screenshot(path=out)
    page.keyboard.press("Control+c")
    text, deadline = "", time.time() + 10
    while time.time() < deadline:
        text = page.evaluate("() => (document.getElementById('noVNC_clipboard_text') || {}).value || ''")
        if text == expected:
            break
        time.sleep(0.5)
    print(f"clipboard panel: {text!r}")
    browser.close()
    sys.exit(0 if text == expected else 1)
