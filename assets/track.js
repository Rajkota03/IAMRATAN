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
  var off = !navigator.sendBeacon ||
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

  /* the public call. track('uncut_size', {cloth:'cocoa-drift', size:'41'}) */
  function track(name, detail) {
    if (off) return;
    queue.push({
      visit: visit,
      name: name,
      path: location.pathname.replace(/^\/|\.html$/g, '') || 'index',
      detail: detail || {},
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

    if (t.closest('[data-add]')) {
      track('add_to_customize', {
        cloth: new URLSearchParams(location.search).get('p') || ''
      });
      return;
    }

    var card = t.closest('.card[href]');
    if (card) {
      var m = card.getAttribute('href').match(/p=([^&]+)/);
      track('cloth_opened', { cloth: m ? decodeURIComponent(m[1]) : '' });
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

  track('view', { ref: document.referrer ? new URL(document.referrer).hostname : 'direct' });

  addEventListener('pagehide', function () {
    if (deepest) track('depth', { percent: Math.round(deepest / 10) * 10 });
    flush(true);
  });

  window.IARTRACK = { track: track, ready: ready };
})(window, document);
