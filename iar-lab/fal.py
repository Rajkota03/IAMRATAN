#!/usr/bin/env python3
"""fal.ai queue client for the I Am Ratan shot pipeline.

Submit → poll → download, with the key read from the project .env so it never
lands in a shell history or a command line.

    ./iar-lab/fal.py <model> <prompt-file> <out.png> <ref-url> [<ref-url> ...]

The queue is asynchronous: submit returns a request id, and the job is polled
until it leaves IN_QUEUE/IN_PROGRESS. Anything else is printed in full so a
schema mismatch shows the API's own error rather than a bare failure.
"""

import json
import os
import ssl
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# This python.org build ships without a populated trust store, so the default
# context fails every HTTPS call with CERTIFICATE_VERIFY_FAILED. certifi's
# bundle is the same one curl uses here, which is why curl worked and urllib
# did not.
try:
    import certifi

    CTX = ssl.create_default_context(cafile=certifi.where())
except ImportError:
    CTX = ssl.create_default_context()


def key():
    """Read FAL_KEY from the project .env."""
    path = os.path.join(ROOT, ".env")
    if not os.path.exists(path):
        sys.exit("No .env at %s — cannot authenticate to fal.ai." % path)
    for line in open(path):
        if line.startswith("FAL_KEY="):
            return line.split("=", 1)[1].strip()
    sys.exit("No FAL_KEY line in .env — add FAL_KEY=<key> and retry.")


def call(url, k, body=None, method="GET"):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", "Key " + k)
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, context=CTX, timeout=120) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        sys.exit("fal.ai %s %s\n%s" % (e.code, e.reason, e.read().decode()[:2000]))


def run(model, prompt, out, refs, size=None):
    k = key()
    body = {"prompt": prompt, "image_urls": refs, "num_images": 1}
    if size:
        body["image_size"] = size

    job = call("https://queue.fal.run/" + model, k, body, "POST")
    rid = job.get("request_id")
    if not rid:
        sys.exit("No request_id in response: %s" % json.dumps(job)[:600])
    print("submitted %s  request %s" % (model, rid))

    # Use the URLs fal hands back. Building them from the model path breaks for
    # nested apps like fal-ai/bytedance/seedream/v4/edit, where the queue route
    # is keyed on the owner/app prefix only and a constructed URL 405s.
    status_url = job.get("status_url")
    result_url = job.get("response_url")
    if not status_url or not result_url:
        sys.exit("No status_url/response_url in response: %s" % json.dumps(job)[:600])

    for i in range(150):
        time.sleep(4)
        st = call(status_url, k).get("status")
        if st not in ("IN_QUEUE", "IN_PROGRESS"):
            print("status %s after %ds" % (st, (i + 1) * 4))
            break
        if i % 5 == 0:
            print("  ... %s (%ds)" % (st, (i + 1) * 4))
    else:
        sys.exit("Timed out after 10 minutes. Request %s may still finish." % rid)

    res = call(result_url, k)
    imgs = res.get("images") or []
    if not imgs:
        sys.exit("No images returned:\n%s" % json.dumps(res, indent=2)[:2000])

    url = imgs[0]["url"]
    with urllib.request.urlopen(url, context=CTX, timeout=180) as r:
        open(out, "wb").write(r.read())
    print("wrote %s  (%.0f KB)" % (out, os.path.getsize(out) / 1024))
    return out


if __name__ == "__main__":
    if len(sys.argv) < 5:
        sys.exit(__doc__)
    model, pfile, out = sys.argv[1], sys.argv[2], sys.argv[3]
    refs = sys.argv[4:]

    # Optional trailing WxH forces the output aspect. Without it seedream
    # returns a square, which is wrong for every frame in this set.
    size = None
    if "x" in refs[-1] and not refs[-1].startswith("http"):
        w, h = refs.pop().split("x")
        size = {"width": int(w), "height": int(h)}

    run(model, open(pfile).read().strip(), out, refs, size)
