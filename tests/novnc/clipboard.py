"""clipboard.py URL EXPECTED -- COMMAND...: connect through noVNC, run COMMAND
(which changes the remote clipboard), then read noVNC's clipboard panel, where
someone using the browser viewer copies text out. Exits 0 if the panel shows
EXPECTED within 20 seconds, 1 otherwise (or if the viewer does not connect)."""
import os
import subprocess
import sys
import time

from playwright.sync_api import sync_playwright

url, expected, sep, cmd = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:]
if sep != "--" or not cmd:
    sys.exit("usage: clipboard.py URL EXPECTED -- COMMAND...")
with sync_playwright() as p:
    browser = p.chromium.launch(executable_path=os.environ["CHROME_EXE"])
    page = browser.new_page(viewport={"width": 1600, "height": 1000})
    page.goto(url)
    time.sleep(10)
    status = page.evaluate("() => (document.getElementById('noVNC_status') || {}).textContent || ''")
    print(f"status: {status!r}")
    if not status.startswith("Connected"):
        sys.exit(1)
    print(f"command exited {subprocess.run(cmd, check=False).returncode}")
    text, deadline = "", time.time() + 20
    while time.time() < deadline:
        text = page.evaluate("() => (document.getElementById('noVNC_clipboard_text') || {}).value || ''")
        if text == expected:
            break
        time.sleep(0.5)
    print(f"clipboard panel: {text!r}")
    browser.close()
    sys.exit(0 if text == expected else 1)
