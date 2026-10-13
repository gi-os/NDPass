#!/usr/bin/env python3
"""Create or update NDPass's in-app purchases in App Store Connect, through its API.

Idempotent: run it as often as you like. For each product in PRODUCTS it makes sure there is
an in-app purchase with that product ID, an English name and description, a price, every
territory, and App Review's screenshot (fastlane/iap_review.png, from the screenshot run).
With SUBMIT=true it also sends each one that's ready to App Review.

Reads ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8 from the environment (GitHub secrets); nothing
secret is printed.
"""
import hashlib, json, os, sys, time
import jwt, requests

BUNDLE = "com.gios.ndpass"
PRODUCTS = [
    {"productId": "com.gios.ndpass.gold", "name": "NDPass Gold", "price": "4.99",
     "description": "A gold app icon and a thank-you.",
     "review": "A one-time purchase to support NDPass. It unlocks a gold alternate app icon and a supporter badge in Settings > Support NDPass. No features are locked; the app is fully free without it."},
    {"productId": "com.gios.ndpass.goldplus", "name": "NDPass Gold Plus", "price": "14.99",
     "description": "Gold, plus a rare platinum icon.",
     "review": "A one-time purchase to support NDPass. It unlocks a platinum alternate app icon, the gold icon and a supporter badge in Settings > Support NDPass. No features are locked; the app is fully free without it."},
]
API = "https://api.appstoreconnect.apple.com"
SHOT = os.path.join(os.path.dirname(__file__), "..", "fastlane", "iap_review.png")

def token():
    key = os.environ["ASC_KEY_P8"]
    now = int(time.time())
    return jwt.encode({"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 1000, "aud": "appstoreconnect-v1"},
                      key, algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"})

S = requests.Session()
def call(method, path, body=None, ok=(200, 201, 204)):
    S.headers["Authorization"] = "Bearer " + token()
    r = S.request(method, API + path, json=body, timeout=60)
    if r.status_code not in ok:
        detail = ""
        try:
            detail = "; ".join(f"{e.get('code')}: {e.get('detail') or e.get('title')}" for e in r.json().get("errors", []))
        except Exception:
            detail = r.text[:300]
        raise RuntimeError(f"{method} {path.split('?')[0]} → {r.status_code} {detail}")
    return r.json() if r.content else {}

def all_pages(path):
    out, url = [], path
    while url:
        j = call("GET", url)
        out += j.get("data", [])
        nxt = j.get("links", {}).get("next")
        url = nxt.replace(API, "") if nxt else None
    return out

def ensure(p, app_id, territories):
    pid = p["productId"]
    existing = [i for i in all_pages(f"/v1/apps/{app_id}/inAppPurchasesV2?limit=200") if i["attributes"].get("productId") == pid]
    if existing:
        iap = existing[0]
        print(f"· {pid}: exists ({iap['attributes'].get('state')})")
    else:
        iap = call("POST", "/v2/inAppPurchases", {"data": {"type": "inAppPurchases",
            "attributes": {"name": p["name"], "productId": pid, "inAppPurchaseType": "NON_CONSUMABLE",
                           "reviewNote": p["review"], "familySharable": False},
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}})["data"]
        print(f"+ {pid}: created")
    iid = iap["id"]

    # English name and description (what the purchase sheet and App Store show).
    locs = call("GET", f"/v2/inAppPurchases/{iid}/inAppPurchaseLocalizations")["data"]
    en = [l for l in locs if l["attributes"].get("locale") == "en-US"]
    if en:
        a = en[0]["attributes"]
        if a.get("name") != p["name"] or a.get("description") != p["description"]:
            call("PATCH", f"/v1/inAppPurchaseLocalizations/{en[0]['id']}", {"data": {"type": "inAppPurchaseLocalizations", "id": en[0]["id"],
                 "attributes": {"name": p["name"], "description": p["description"]}}})
            print(f"  ~ English name/description updated")
    else:
        call("POST", "/v1/inAppPurchaseLocalizations", {"data": {"type": "inAppPurchaseLocalizations",
             "attributes": {"locale": "en-US", "name": p["name"], "description": p["description"]},
             "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iid}}}}})
        print(f"  + English name/description")

    # Price: the US price point, with Apple's equivalents everywhere else.
    has_price = False
    try:
        sched = call("GET", f"/v2/inAppPurchases/{iid}/iapPriceSchedule?include=manualPrices")
        has_price = bool(sched.get("data", {}).get("relationships", {}).get("manualPrices", {}).get("data"))
    except RuntimeError:
        has_price = False
    if not has_price:
        points = all_pages(f"/v2/inAppPurchases/{iid}/pricePoints?filter[territory]=USA&limit=200")
        match = [x for x in points if x["attributes"].get("customerPrice") == p["price"]]
        if not match: raise RuntimeError(f"no US price point of ${p['price']}")
        call("POST", "/v1/inAppPurchasePriceSchedules", {
            "data": {"type": "inAppPurchasePriceSchedules", "relationships": {
                "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iid}},
                "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${price}"}]}}},
            "included": [{"type": "inAppPurchasePrices", "id": "${price}", "attributes": {"startDate": None},
                          "relationships": {"inAppPurchasePricePoint": {"data": {"type": "inAppPurchasePricePoints", "id": match[0]["id"]}}}}]})
        print(f"  + price ${p['price']}")

    # Every territory, and new ones as Apple adds them.
    has_avail = False
    try:
        av = call("GET", f"/v2/inAppPurchases/{iid}/inAppPurchaseAvailability")
        has_avail = bool(av.get("data"))
    except RuntimeError:
        has_avail = False
    if not has_avail:
        call("POST", "/v1/inAppPurchaseAvailabilities", {"data": {"type": "inAppPurchaseAvailabilities",
             "attributes": {"availableInNewTerritories": True},
             "relationships": {"inAppPurchase": {"data": {"type": "inAppPurchases", "id": iid}},
                               "availableTerritories": {"data": [{"type": "territories", "id": t} for t in territories]}}}})
        print(f"  + available in {len(territories)} territories")

    # App Review's screenshot of the purchase screen.
    has_shot = False
    try:
        cur = call("GET", f"/v2/inAppPurchases/{iid}/appStoreReviewScreenshot")
        has_shot = bool(cur.get("data")) and cur["data"]["attributes"].get("assetDeliveryState", {}).get("state") != "FAILED"
    except RuntimeError:
        has_shot = False
    if not has_shot and os.path.exists(SHOT):
        data = open(SHOT, "rb").read()
        res = call("POST", "/v1/inAppPurchaseAppStoreReviewScreenshots", {"data": {"type": "inAppPurchaseAppStoreReviewScreenshots",
              "attributes": {"fileName": "iap_review.png", "fileSize": len(data)},
              "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iid}}}}})["data"]
        for op in res["attributes"].get("uploadOperations", []):
            chunk = data[op["offset"]:op["offset"] + op["length"]]
            hdrs = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
            r = requests.request(op["method"], op["url"], data=chunk, headers=hdrs, timeout=120)
            if r.status_code >= 300: raise RuntimeError(f"screenshot upload part → {r.status_code}")
        call("PATCH", f"/v1/inAppPurchaseAppStoreReviewScreenshots/{res['id']}", {"data": {"type": "inAppPurchaseAppStoreReviewScreenshots",
             "id": res["id"], "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
        print(f"  + review screenshot")
    elif not has_shot:
        print(f"  ! no review screenshot yet (run the App Store workflow to make one)")

    state = call("GET", f"/v2/inAppPurchases/{iid}")["data"]["attributes"].get("state")
    print(f"  = {state}")
    return iid, state

def main():
    apps = call("GET", f"/v1/apps?filter[bundleId]={BUNDLE}")["data"]
    if not apps: sys.exit(f"no App Store Connect app for {BUNDLE}")
    app_id = apps[0]["id"]
    territories = [t["id"] for t in all_pages("/v1/territories?limit=200")]
    results = []
    failed = False
    for p in PRODUCTS:
        try:
            results.append(ensure(p, app_id, territories))
        except RuntimeError as e:
            failed = True
            print(f"! {p['productId']}: {e}")
    if os.environ.get("SUBMIT") == "true":
        for iid, state in results:
            if state != "READY_TO_SUBMIT":
                print(f"! not submitting {iid}: {state}"); continue
            try:
                call("POST", "/v1/inAppPurchaseSubmissions", {"data": {"type": "inAppPurchaseSubmissions",
                     "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iid}}}}})
                print(f"→ {iid} sent to App Review")
            except RuntimeError as e:
                # The first purchase has to go with an app version: select it on the version page.
                print(f"! couldn't submit {iid} on its own: {e}")
    if failed: sys.exit(1)

if __name__ == "__main__":
    main()
