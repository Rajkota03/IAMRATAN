/* I AM RATAN — what the house can learn from the site.

   The point of this file is one question the shop cannot otherwise answer:
   WHO WANTED A SHIRT WE DO NOT CUT? Every tap on a dashed 41, 43 or 45 is a
   person who wants that exact cloth in a neck the house does not stock. That is
   a bespoke lead, captured at the moment of intent, and until now it vanished
   silently. It is the highest-value event on the site, because bespoke is where
   the margin is.

   PRIVACY, DELIBERATELY. No cookies, no localStorage, no fingerprint, no IP
   stored. The visit id is a random number that lives in memory and dies with
   the tab, so two visits are never joined into a person. That is not only
   decent, it is practical: nothing here is personal data under the DPDP Act, so
   the site needs no consent banner — and a consent banner on the first screen
   would cost more sales than this file could ever explain.

   It also fails silently and completely. If the endpoint is not configured, or
   is down, or the visitor blocks it, the page carries on exactly as before.
   Analytics must never be able to break a shop.                              */

(function (window, document) {
  'use strict';

  /* Set both when the Supabase project exists. The anon key is public by
     design — row-level security allows INSERT on this table and nothing else,
     so a reader can post an event and can never read one back. */
  var URL_BASE = 'https://hckbqcphijihqbysibos.supabase.co';
  var ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhja2JxY3BoaWppaHFieXNpYm9zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY3MDY1ODQsImV4cCI6MjEwMjI4MjU4NH0.wg5IdL1ArScKk4dWWTtX8xyi8s4Z-1B9gKQQJBvX9V8';

  var TABLE   = 'events';
  var FLUSH_MS = 4000;      /* batch, so a fast scroll is not fifty requests */
  var MAX_QUEUE = 40;

  var queue = [];
  var timer = null;
  /* in memory only: gone when the tab closes, never written anywhere */
  var visit = Math.random().toString(36).slice(2, 11);
  /* Only the real shop is counted. Without this the table fills with our own
     work: a local page load writes to the same production project as a
     customer, and one afternoon of development outweighs a week of real
     visitors. Preview deploys are excluded for the same reason, which also
     matches vercel.json marking them noindex. An allowlist, not a blocklist,
     so a new preview host or a file:// open is silent by default. */
  var LIVE = { 'www.iamratan.co.in': 1, 'iamratan.co.in': 1 };
  var offsite = !LIVE[location.hostname];

  var off = offsite || !navigator.sendBeacon ||
            navigator.doNotTrack === '1' || window.doNotTrack === '1';

  function ready() { return !!(URL_BASE && ANON_KEY) && !off; }

  function send(rows, beacon) {
    if (!rows.length || !ready()) return;
    var url = URL_BASE.replace(/\/$/, '') + '/rest/v1/' + TABLE;
    var body = JSON.stringify(rows);
    if (beacon) {
      /* pagehide gets one shot and no promise — sendBeacon survives the unload
         where fetch does not. It cannot set headers, so the key rides the query
         string, which is what the anon key is for. */
      navigator.sendBeacon(url + '?apikey=' + encodeURIComponent(ANON_KEY),
        new Blob([body], { type: 'application/json' }));
      return;
    }
    fetch(url, {
      method: 'POST',
      keepalive: true,
      headers: {
        'Content-Type': 'application/json',
        'apikey': ANON_KEY,
        'Authorization': 'Bearer ' + ANON_KEY,
        'Prefer': 'return=minimal'
      },
      body: body
    }).catch(function () { /* a dropped event is not the visitor's problem */ });
  }

  function flush(beacon) {
    if (timer) { clearTimeout(timer); timer = null; }
    var rows = queue.splice(0, queue.length);
    send(rows, beacon);
  }

  /* '/checkout.html' is 'checkout', '/' is 'index'. Written once because two
     copies of the same tidy-up drift apart the first time a page is renamed. */
  function page() {
    return location.pathname.replace(/^\/|\.html$/g, '') || 'index';
  }

  /* the public call. track('uncut_size', {cloth:'cocoa-drift', size:'41'}) */
  function track(name, detail) {
    if (off) return;
    /* The channel rides along on every event. Without it the shop knows which
       links its ORDERS came from and nothing at all about which links its
       VISITS came from — so it can never answer the only question that matters
       about an ad: did the people it sent actually buy?

       It is still not a person. "instagram" is where a tab came from, joined to
       nothing, forgotten when the tab closes. */
    var d = detail || {}, src = from();
    if (src.utm_source) {
      d = { utm_source: src.utm_source, utm_medium: src.utm_medium,
            utm_campaign: src.utm_campaign };
      for (var k in (detail || {})) if (detail.hasOwnProperty(k)) d[k] = detail[k];
    }
    queue.push({
      visit: visit,
      name: name,
      path: page(),
      detail: d,
      viewport: window.innerWidth < 820 ? 'phone' : 'desktop',
      at: new Date().toISOString()
    });
    if (queue.length >= MAX_QUEUE) return flush();
    if (!timer) timer = setTimeout(flush, FLUSH_MS);
  }

  /* ---------- what gets watched ----------
     One delegated listener on the document rather than a handler per element,
     because the shop grid and the product page both rebuild their markup from
     JS and anything bound directly would be thrown away on the next draw. */

  document.addEventListener('click', function (e) {
    var t = e.target;
    if (!t || !t.closest) return;

    /* THE ONE THAT MATTERS: a neck the house does not cut */
    var uncut = t.closest('.sz[data-uncut]');
    if (uncut) {
      track('uncut_size', {
        cloth: new URLSearchParams(location.search).get('p') || '',
        size: uncut.getAttribute('data-size')
      });
      return;
    }

    var sz = t.closest('.sz[data-size]');
    if (sz) {
      track('size_chosen', {
        cloth: new URLSearchParams(location.search).get('p') || '',
        size: sz.getAttribute('data-size')
      });
      return;
    }

    /* BUY NOW IS AN ADD TO CART. shop.js puts the same shirt in the same bag
       for both buttons and differs only in where it lands you — Add stays on
       the page, Buy goes to the checkout (assets/shop.js:189-204). Watching
       [data-add] alone therefore reported every buy-now sale as a visitor who
       ordered without ever having a cart, and the cart step of the funnel was
       missing exactly the people who were surest about buying. */
    var act = t.closest('[data-add],[data-buy]');
    if (act) {
      /* A click with no size chosen is refused with a toast and nothing goes
         into the bag. Counting it would inflate the one step in the funnel that
         is supposed to mean intent, and make the drop to checkout look worse
         than it is. The test mirrors shop.js: the chosen neck is written onto
         the [data-sizes] host, and where there is no host we cannot tell, so we
         count it rather than guess it away. */
      var host = act.closest('[data-sizes]');
      var size = host ? host.getAttribute('data-size') : '';
      if (host && !size) return;
      track('add_to_customize', {
        cloth: new URLSearchParams(location.search).get('p') || '',
        size: size || '',
        /* one funnel step, two doors — the house can still tell them apart */
        how: act.hasAttribute('data-buy') ? 'buy_now' : 'add'
      });
      return;
    }

    /* The related rail at the foot of a product page draws .more-card, not
       .card (the related() rail in product.html), so every tap from one cloth
       to the next was
       invisible and the rail looked like it did nothing. It is the only route
       from a shirt somebody did not want to one they might. */
    var card = t.closest('.card[href],.more-card[href]');
    if (card) {
      var m = card.getAttribute('href').match(/[?&]p=([^&]+)/);
      track('cloth_opened', {
        cloth: card.getAttribute('data-cloth') || (m ? decodeURIComponent(m[1]) : ''),
        from: card.className.indexOf('more-card') > -1 ? 'rail' : 'grid'
      });
      return;
    }

    var chip = t.closest('.chip');
    if (chip) { track('filter', { collection: chip.textContent.trim() }); return; }

    var pick = t.closest('[data-pick]');
    if (pick) { track('service_chosen', { service: pick.getAttribute('data-pick') }); return; }

    /* an outbound tap is a conversion on this site: it is how the house sells */
    var link = t.closest('a[href]');
    if (link) {
      var href = link.getAttribute('href') || '';
      if (href.indexOf('wa.me') > -1)   track('whatsapp', {});
      else if (href.indexOf('tel:') === 0)    track('call', {});
      else if (href.indexOf('mailto:') === 0) track('email', {});
      else if (href.indexOf('instagram') > -1) track('instagram', {});
    }
  }, true);

  /* which questions a buyer actually needed answered before deciding */
  document.addEventListener('toggle', function (e) {
    var d = e.target;
    if (d && d.tagName === 'DETAILS' && d.open && d.querySelector('summary')) {
      track('question_opened', { question: d.querySelector('summary').textContent.trim() });
    }
  }, true);

  document.addEventListener('submit', function (e) {
    if (e.target && e.target.id === 'bookForm') track('consultation_requested', {});
  }, true);

  /* how far down a page anyone actually got — depth is the honest measure of
     whether a page held someone, where time on page is not */
  var deepest = 0;
  addEventListener('scroll', function () {
    var h = document.documentElement.scrollHeight - innerHeight;
    if (h <= 0) return;
    var pct = Math.min(100, Math.round(scrollY / h * 100));
    if (pct > deepest) deepest = pct;
  }, { passive: true });

  /* ---------- where they came in from ----------
     A visitor lands on the home page with ?utm_source=instagram and buys three
     pages later, by which time the parameter is long gone. So it is kept for
     the life of the tab and read again at the checkout.

     sessionStorage, deliberately, and not a cookie: it is scoped to this one
     tab, it dies when the tab closes, and it holds the word "instagram" and
     nothing about a person. Everything the privacy note at the top of this file
     promises still holds — two visits are still never joined into somebody. */

  var UTM_KEY = 'iar.from';
  var FIELDS = ['utm_source', 'utm_medium', 'utm_campaign'];

  function stash() {
    var q = new URLSearchParams(location.search), got = {}, any = false;
    FIELDS.forEach(function (f) {
      var v = (q.get(f) || '').trim().slice(0, 60);
      if (v) { got[f] = v; any = true; }
    });
    if (!any) return;
    try { sessionStorage.setItem(UTM_KEY, JSON.stringify(got)); } catch (e) {}
  }

  /* The last link wins over the first: somebody who arrives from a newsletter,
     wanders off and comes back through an ad was, on that visit, brought by the
     ad. Crediting the newsletter would flatter it. */
  stash();

  function from() {
    try { return JSON.parse(sessionStorage.getItem(UTM_KEY) || '{}'); }
    catch (e) { return {}; }
  }

  track('view', { ref: document.referrer ? new URL(document.referrer).hostname : 'direct' });

  /* ---------- the step nobody was counting ----------
     There has never been a checkout_started event, so the funnel went straight
     from a cart to an order with nothing in between — and the gap between those
     two is the largest single loss on the site. A number that big cannot be
     managed while it is reported as one drop with no middle.

     It is fired from here, keyed off the page, rather than from checkout.html:
     the checkout has one job and this file has the other, and a page that has
     to remember to call the tracker is a page that will one day forget.

     The bag is READ, never written. It is the shop's own basket (shop.js keeps
     it under 'iar-bag'), it holds cloth, neck and quantity, and it is not an
     identity — nothing here is stored against a person and no two visits are
     joined. Everything the note at the top of this file promises still holds. */
  function bag() {
    if (window.SHOP && SHOP.bag) return SHOP.bag;
    try { return JSON.parse(localStorage.getItem('iar-bag') || '[]'); }
    catch (e) { return []; }
  }

  if (page() === 'checkout') {
    var basket = bag();
    /* An empty checkout is somebody who has already paid and reloaded, or who
       wandered in from a link. Neither of them started a checkout. */
    if (basket.length) {
      track('checkout_started', {
        lines: basket.length,
        units: basket.reduce(function (n, x) { return n + (Number(x.qty) || 1); }, 0)
      });
    }
  }

  addEventListener('pagehide', function () {
    if (deepest) track('depth', { percent: Math.round(deepest / 10) * 10 });
    flush(true);
  });

  window.IARTRACK = { track: track, ready: ready, from: from };
})(window, document);
