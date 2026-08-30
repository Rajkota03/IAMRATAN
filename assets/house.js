/* I AM RATAN — what the house has changed, applied to a page that was already
   correct without it.

   THE SHAPE OF THIS FILE, AND WHY
   Every page of this site is finished, hand-built HTML. The header is right,
   the bands are in order, and all of it renders with no JavaScript and no
   database. This file NEVER BUILDS ANYTHING. It only ever overrides — and only
   when the house has actually changed something from the default.

   That is the whole design. The alternative, a page that is blank until a
   database answers, would give the house nothing it uses twice a year and cost
   a white screen on a slow phone, a worse Google result, and a shop that dies
   when a free Supabase project goes to sleep.

   So: if this file is blocked, slow, or broken, every page is exactly the site
   I built. If the house has edited something, the edit lands a beat later.
   Nothing here can ever empty a page.                                        */

(function (window, document) {
  'use strict';

  var S = window.IARSTORE;
  if (!S || !S.ready) return;          /* store.js absent: the page stands alone */

  var URL_BASE = 'https://hckbqcphijihqbysibos.supabase.co';
  var ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhja2JxY3BoaWppaHFieXNpYm9zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY3MDY1ODQsImV4cCI6MjEwMjI4MjU4NH0.wg5IdL1ArScKk4dWWTtX8xyi8s4Z-1B9gKQQJBvX9V8';

  function get(path) {
    return fetch(URL_BASE + '/rest/v1/' + path, {
      headers: { apikey: ANON_KEY, Authorization: 'Bearer ' + ANON_KEY }
    }).then(function (r) {
      if (!r.ok) throw new Error(r.status);
      return r.json();
    });
  }

  function esc(v) {
    return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) {
      return { '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;' }[c];
    });
  }

  /* ---------- the announcement bar ----------
     This setting has existed since the first day and nothing has ever drawn it.
     The house could type a line into the desk and it went precisely nowhere.

     It is inserted ABOVE the header rather than fixed over it, so it pushes the
     page down instead of covering the first thing anybody reads. Dismissing it
     is remembered for the tab only — a bar the house just turned on should come
     back tomorrow, not be silenced for ever by one stray tap. */

  var BAR_OFF = 'iar.bar.off';

  function bar(t) {
    if (String(t.bar_on).toLowerCase() !== 'true') return;
    var words = (t.announcement || '').trim();
    if (!words) return;                        /* nothing to say: say nothing */
    if (t.bar_where === 'home' && !/(^\/$|index\.html$)/.test(location.pathname)) return;
    try { if (sessionStorage.getItem(BAR_OFF) === words) return; } catch (e) {}

    var el = document.createElement('aside');
    el.className = 'housebar';
    el.setAttribute('role', 'note');
    el.style.cssText =
      'background:' + (t.bar_bg || '#141210') + ';color:' + (t.bar_fg || '#F5F2EC') + ';' +
      'display:flex;align-items:center;justify-content:center;gap:.75rem;' +
      'padding:.6rem 1rem;font-size:.8125rem;line-height:1.4;text-align:center;' +
      'position:relative;z-index:60';

    var body = t.bar_link
      ? '<a href="' + esc(t.bar_link) + '" style="color:inherit;text-decoration:underline;' +
        'text-underline-offset:.2em">' + esc(words) +
        (t.bar_link_text ? ' &mdash; ' + esc(t.bar_link_text) : '') + '</a>'
      : '<span>' + esc(words) + '</span>';

    el.innerHTML = body +
      '<button type="button" aria-label="Dismiss" style="position:absolute;right:.5rem;' +
      'background:none;border:0;color:inherit;font:inherit;line-height:1;cursor:pointer;' +
      'padding:.35rem .5rem;opacity:.7">&times;</button>';

    el.querySelector('button').addEventListener('click', function () {
      try { sessionStorage.setItem(BAR_OFF, words); } catch (e) {}
      el.remove();
    });

    document.body.insertBefore(el, document.body.firstChild);
  }

  /* ---------- how many cloths ----------
     "Twenty-five cloths" was written into eleven places when there were
     twenty-five. There are twenty-seven. Replacing the word with 27 fixes it
     until the house cuts a twenty-eighth, so this counts them instead.

     It SPELLS the number, because this house spells its numbers — "Twenty-seven
     cloths, cut in five sizes" is the voice and "27 cloths" is a spreadsheet.
     Twenty lines of number-words is a smaller thing to carry than a sentence
     that goes quietly wrong every season.

     The HTML still ships with the right word in it, so this only ever corrects
     a page that has fallen behind, and a reader with no JavaScript sees a
     number that was true when the page was built. */

  var ONES = ['', 'One','Two','Three','Four','Five','Six','Seven','Eight','Nine',
              'Ten','Eleven','Twelve','Thirteen','Fourteen','Fifteen','Sixteen',
              'Seventeen','Eighteen','Nineteen'];
  var TENS = ['', '', 'Twenty','Thirty','Forty','Fifty','Sixty','Seventy',
              'Eighty','Ninety'];

  function inWords(n) {
    n = Number(n) || 0;
    if (n < 20) return ONES[n] || String(n);
    if (n < 100) {
      return TENS[Math.floor(n / 10)] + (n % 10 ? '-' + ONES[n % 10].toLowerCase() : '');
    }
    return String(n);                    /* past a hundred, digits read better */
  }

  function count(st) {
    var els = document.querySelectorAll('[data-cloths]');
    if (!els.length || !st.products || !st.products.length) return;
    var n = st.products.length, word = inWords(n);
    [].forEach.call(els, function (el) {
      /* keep the sentence's own capitalisation: mid-sentence it is lower case */
      var was = el.textContent.trim();
      var lower = was && was[0] === was[0].toLowerCase();
      el.textContent = lower ? word.toLowerCase() : word;
    });
  }

  /* ---------- the menu ----------
     Four links that change about once a year, and they are already in the HTML
     of every page. This rewrites them ONLY if what the house has stored differs
     from what is on the page — so the common case does no work, touches no DOM,
     and cannot make the header flicker. */

  function menu(rows) {
    var nav = document.querySelector('header.top nav.nav');
    if (!nav || !rows || !rows.length) return;

    var want = rows.filter(function (r) { return r.live && r.place === 'main'; })
                   .sort(function (a, b) { return a.sort_order - b.sort_order; });
    if (!want.length) return;             /* never leave a page with no menu */

    /* Only the PAGE links are the desk's to manage. The account action and the
       panel's tail are not menu rows: they come from the markup and from
       nav.js. Counting them here made every page look changed against the
       stored menu, so the nav was rewritten and they were deleted on the way
       past. That is why Sign in vanished from a page that plainly had it. */
    var keepAcc  = nav.querySelector('.nav-acc');
    var keepReg  = nav.querySelector('.nav-reg');
    var keepTail = nav.querySelector('.nav-tail');
    var pageLinks = [].filter.call(nav.children, function (el) {
      return el.tagName === 'A' &&
             el.className.indexOf('nav-acc') < 0 &&
             el.className.indexOf('nav-reg') < 0;
    });

    var have = pageLinks.map(function (a) {
      return a.getAttribute('href') + ' ' + a.textContent.trim();
    }).join('|');
    var next = want.map(function (r) {
      return r.href + ' ' + r.label;
    }).join('|');
    if (have === next) return;            /* identical: leave the page alone */

    var here = location.pathname.split('/').pop() || 'index.html';
    nav.innerHTML = want.map(function (r) {
      return '<a href="' + esc(r.href) + '"' +
        (r.href === here ? ' aria-current="page"' : '') + '>' + esc(r.label) + '</a>';
    }).join('');
    /* put back what was never the menu's to remove */
    if (keepAcc)  nav.appendChild(keepAcc);
    if (keepReg)  nav.appendChild(keepReg);
    if (keepTail) nav.appendChild(keepTail);
  }

  /* ---------- the bands on the home page ----------
     Hiding is done by removing the element, not by display:none, so a hidden
     band is not read aloud to somebody using a screen reader and not found by
     an in-page search. Reordering moves the real nodes. Neither can invent a
     band: a section that is not in the HTML has no design, no photographs and
     no words, and a switch for it would be a switch wired to nothing. */

  function bands(rows) {
    if (!rows || !rows.length) return;
    var main = document.querySelector('main');
    if (!main) return;

    rows.slice().sort(function (a, b) { return a.sort_order - b.sort_order; })
      .forEach(function (r) {
        var el = main.querySelector('[data-band="' + r.key + '"]');
        if (!el) return;                 /* not a band on this page. fine. */
        if (!r.live) { el.remove(); return; }
        /* appending in the house's order is enough to reorder them */
        main.appendChild(el);
        if (r.heading) {
          var h = el.querySelector('h1, h2');
          if (h) h.textContent = r.heading;
        }
      });

    /* A [data-band] section the house has no row for — a band added to the HTML
       after this table was seeded — is left in its authored place. Without this
       it floats to the top: every KNOWN band is re-appended to the end above,
       so an unknown one becomes the only child that never moved, and lands
       first. Re-appending unknowns in DOM order keeps them last, which is where
       a new closing panel is written to sit. */
    var known = {};
    rows.forEach(function (r) { known[r.key] = true; });
    [].forEach.call(main.querySelectorAll('[data-band]'), function (el) {
      if (!known[el.getAttribute('data-band')]) main.appendChild(el);
    });
  }

  /* ---------- go ----------
     Settings arrive with the shop's own single call, so the bar costs no extra
     request. The menu and the bands are asked for only on a page that has them,
     and every one of the three fails silently and separately: a broken menu
     must never be able to take the announcement bar down with it. */

  S.ready.then(function (st) {
    try { bar(st.settings || {}); } catch (e) {}
    try { count(st); } catch (e) {}

    /* Once more when the document is finished, because some pages draw their
       own [data-cloths] AFTER this file has run — the product page's "not in
       the range" state is one.

       It only shows on a second visit, which is what makes it worth a comment.
       Cold, the store has to fetch, S.ready settles late, and the span is long
       since on the page. Warm, the cache answers from sessionStorage and
       S.ready is ALREADY resolved, so this callback runs as a microtask the
       moment this file ends — three script tags before the span exists. First
       visit right, every visit after it stale. */
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', function () {
        try { count(st); } catch (e) {}
      });
    }

    if (document.querySelector('header.top nav.nav')) {
      get('nav_items?select=*&order=sort_order.asc')
        .then(function (rows) { try { menu(rows); } catch (e) {} })
        .catch(function () {});
    }
    if (document.querySelector('main [data-band]')) {
      get('home_sections?select=*&order=sort_order.asc')
        .then(function (rows) { try { bands(rows); } catch (e) {} })
        .catch(function () {});
    }
  });
})(window, document);
