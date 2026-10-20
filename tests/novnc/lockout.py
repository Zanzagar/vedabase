"""lockout.py URL OUT.png: six logins with a wrong password must each be
refused, and the right password must still connect afterwards (the web display
runs without TigerVNC's failed-login lockout). Exits 1 otherwise."""
import os
import re
import sys
import time

from playwright.sync_api import sync_playwright

url, out = sys.argv[1], sys.argv[2]
wrong = re.sub(r"password=[^&]*", "password=wrongpw1", url).replace("reconnect=1", "reconnect=0")
STATUS = "() => (document.getElementById('noVNC_status') || {}).textContent || ''"
ok = True
with sync_playwright() as p:
    browser = p.chromium.launch(executable_path=os.environ["CHROME_EXE"])
    for i in range(6):
        page = browser.new_page()
        page.goto(wrong)
        time.sleep(3)
        status = page.evaluate(STATUS)
        print(f"wrong password {i + 1}: {status!r}")
        ok &= "Authentication failure" in status
        page.close()
    page = browser.new_page(viewport={"width": 1600, "height": 1000})
    page.goto(url)
    time.sleep(8)
    status = page.evaluate(STATUS)
    print(f"right password afterwards: {status!r}")
    ok &= status.startswith("Connected")
    page.screenshot(path=out)
    browser.close()
sys.exit(0 if ok else 1)
