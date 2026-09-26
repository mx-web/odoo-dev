#!/usr/bin/env python3
"""Screenshot of an Odoo page served from a specific database.

    python3 scripts/shot.py <db> <path> <out.png> [--mobile] [--full] [--login user:pw]

Examples:
    python3 scripts/shot.py odoo /shop /tmp/shop.png --full
    python3 scripts/shot.py odoo /odoo /tmp/backend.png --login admin:admin
    python3 scripts/shot.py odoo /my /tmp/portal.png --mobile --login portal:portal

Needs Playwright on the host:
    pip install playwright && playwright install chromium

Base URL: $ODOO_URL, otherwise http://localhost:$ODOO_PORT (default 8069).
Every call uses its own browser instance: no conflict with other sessions.
Prints JS console errors and a possible SCSS compile error at the end.
"""
import os
import sys

from playwright.sync_api import sync_playwright

args = sys.argv[1:]
if len(args) < 3:
    sys.exit(__doc__)
db, path, out = args[:3]
mobile = "--mobile" in args
full = "--full" in args
login = args[args.index("--login") + 1] if "--login" in args else None
base = os.environ.get("ODOO_URL") or f"http://localhost:{os.environ.get('ODOO_PORT', '8069')}"

with sync_playwright() as p:
    browser = p.chromium.launch()
    ctx = browser.new_context(viewport={"width": 390, "height": 844} if mobile else {"width": 1440, "height": 900},
                              device_scale_factor=1)
    page = ctx.new_page()
    errors = []
    page.on("console", lambda m: m.type == "error" and errors.append(m.text))
    page.on("pageerror", lambda e: errors.append(str(e)))
    # ?db= selects the database for this session (needs a matching dbfilter)
    page.goto(f"{base}/web/login?db={db}")
    if login:
        user, pw = login.split(":", 1)
        page.fill("input[name=login]", user)
        page.fill("input[name=password]", pw)
        page.press("input[name=password]", "Enter")
        page.wait_for_load_state("networkidle")
    page.goto(base + path, wait_until="networkidle")
    page.wait_for_timeout(800)
    page.screenshot(path=out, full_page=full)
    # Odoo reports failed SCSS compilation via body::before content
    css_err = page.evaluate("""() => {
        const s = getComputedStyle(document.body, '::before').content;
        return s && s.includes('css error') ? s : '';
    }""")
    print("OK", page.url, out)
    if css_err:
        print("SCSS ERROR:", css_err[:500])
    for e in errors[:10]:
        print("JS:", e[:300])
    browser.close()
