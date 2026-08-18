/* I AM RATAN — the shop's data, and who decides it.

   THE RULE THIS FILE EXISTS TO ENFORCE
   A business decision belongs to the house, in the database, changeable without
   a deploy. A design decision belongs in the code, and is mine. So:

     the house decides   price · stock · what is visible · what is sold out
                         whether stock counts show at all · at what number
                         the delivery window · whether the shop takes orders
     the code decides    how any of that is drawn

   Nothing about stock is written into a page. "Only 2 left" is not a sentence
   I typed — it is a number the house edited, shown because the house left the
   switch on, at a threshold the house chose.

   IT MUST NEVER BREAK THE SHOP. Supabase is a free project and free projects
   sleep. If it is asleep, slow, blocked or not yet built, the site falls back
   to the catalogue bundled with it and behaves exactly as it did before. A shop
   that cannot show stock is a small problem; a shop that shows nothing is not
   a shop.                                                                    */

(function (window) {
  'use strict';

  var URL_BASE = 'https://hckbqcphijihqbysibos.supabase.co';
  var ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhja2JxY3BoaWppaHFieXNpYm9zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY3MDY1ODQsImV4cCI6MjEwMjI4MjU4NH0.wg5IdL1ArScKk4dWWTtX8xyi8s4Z-1B9gKQQJBvX9V8';

  var CACHE_KEY = 'iar.shop.v1';
  var CACHE_MS  = 5 * 60 * 1000;   /* the house edits stock; five minutes stale
                                      is honest enough and saves a round trip
                                      on every page of a browse */

  /* defaults that apply until the database says otherwise — chosen so that a
     site with no database behaves like the site did before there was one */
  var Store = {
    products: null,       /* null = the database has not answered yet */
    settings: {
      show_stock_counts: true,
      low_stock_at: 3,
      hide_sold_out: false,
      shop_open: true,
      delivery_min_days: 3,
      delivery_max_days: 7,
      announcement: ''
    },
    live: false,          /* did the database actually answer? */
    ready: null
  };

  function bool(v, dflt) {
    if (v === undefined || v === null || v === '') return dflt;
    return String(v).toLowerCase() === 'true';
  }
  function num(v, dflt) {
    var n = parseInt(v, 10);
    return isNaN(n) ? dflt : n;
  }

  function get(path) {
    return fetch(URL_BASE + '/rest/v1/' + path, {
      headers: { apikey: ANON_KEY, Authorization: 'Bearer ' + ANON_KEY }
    }).then(function (r) {
      if (!r.ok) throw new Error(r.status);
      return r.json();
    });
  }

  function applySettings(rows) {
    var s = {};
    (rows || []).forEach(function (r) { s[r.key] = r.value; });
    Store.settings = {
      /* The facts the e-commerce rules require on the page. Blank until the
         house types them in, and a blank one prints NOTHING — a made-up GSTIN
         or an invented Grievance Officer is worse than an absent one. */
      legal_name:        s.legal_name || '',
      registered_address:s.registered_address || '',
      gstin:             s.gstin || '',
      grievance_officer: s.grievance_officer || '',
      grievance_email:   s.grievance_email || '',
      grievance_phone:   s.grievance_phone || '',
      /* False while the seller details are stand-ins. See sellerHTML. */
      facts_are_real:    bool(s.facts_are_real, false),
      show_stock_counts: bool(s.show_stock_counts, true),
      low_stock_at:      num(s.low_stock_at, 3),
      hide_sold_out:     bool(s.hide_sold_out, false),
      shop_open:         bool(s.shop_open, true),
      delivery_min_days: num(s.delivery_min_days, 3),
      delivery_max_days: num(s.delivery_max_days, 7),
      /* the bar. Off unless the house has switched it on and written a line —
         both, so a stale sentence left in the box cannot reappear on the shop
         front the day somebody flicks the switch to see what it does. */
      announcement:      s.announcement || '',
      bar_on:            bool(s.bar_on, false),
      bar_link:          s.bar_link || '',
      bar_link_text:     s.bar_link_text || '',
      bar_bg:            s.bar_bg || '#141210',
      bar_fg:            s.bar_fg || '#F5F2EC',
      bar_where:         s.bar_where || 'all'
    };
  }

  function load() {
    /* a fresh cache answers instantly and keeps a browse from re-asking */
    try {
      var c = JSON.parse(sessionStorage.getItem(CACHE_KEY) || 'null');
      if (c && Date.now() - c.at < CACHE_MS) {
        Store.products = c.products;
        applySettings(c.settings);
        Store.live = true;
        return Promise.resolve(Store);
      }
    } catch (e) { /* a broken cache is not worth a thought */ }

    return Promise.all([
      get('shop?select=*'),
      get('settings?select=key,value')
    ]).then(function (res) {
      var rows = res[0] || [];
      /* An empty products table means the house has not seeded it yet — that is
         not the same as "the house hid everything", so the bundled catalogue
         still stands. Once there is one row, the database is the truth. */
      if (rows.length) Store.products = rows;
      applySettings(res[1]);
      Store.live = true;
      try {
        sessionStorage.setItem(CACHE_KEY, JSON.stringify({
          at: Date.now(), products: rows, settings: res[1]
        }));
      } catch (e) {}
      return Store;
    }).catch(function () {
      /* asleep, slow, blocked, or not built yet. The shop carries on. */
      Store.live = false;
      return Store;
    });
  }

  /* ---------- what the pages ask ---------- */

  function row(slug) {
    if (!Store.products) return null;
    for (var i = 0; i < Store.products.length; i++) {
      if (Store.products[i].slug === slug) return Store.products[i];
    }
    return null;
  }

  /* how many of this cloth in this neck. null = the house is not tracking it,
     which is different from zero, and must never be drawn as "sold out". */
  Store.stock = function (slug, size) {
    var r = row(slug);
    if (!r || !r.stock) return null;
    var q = r.stock[size];
    return (q === undefined || q === null) ? null : Number(q);
  };

  Store.soldOut = function (slug, size) {
    var q = Store.stock(slug, size);
    return q !== null && q <= 0;
  };

  Store.allGone = function (slug) {
    var r = row(slug);
    if (!r || r.total_stock === undefined || r.total_stock === null) return false;
    return Number(r.total_stock) <= 0;
  };

  /* the sentence, or nothing at all — the house owns both the switch and the
     number, so this returns '' far more often than it returns words */
  Store.lowNote = function (slug, size) {
    if (!Store.settings.show_stock_counts) return '';
    var q = Store.stock(slug, size);
    if (q === null || q <= 0) return '';
    if (q > Store.settings.low_stock_at) return '';
    return q === 1 ? 'Last one' : 'Only ' + q + ' left';
  };

  Store.priceOf = function (slug) {
    var r = row(slug);
    return r ? Number(r.price) : null;
  };

  /* slugs the house has hidden, so the grid can drop them */
  Store.hidden = function (slug) {
    if (!Store.products) return false;                 /* nothing known yet */
    if (!row(slug)) return true;                       /* not in the shop view */
    return Store.settings.hide_sold_out && Store.allGone(slug);
  };

  Store.deliveryLine = function () {
    var a = Store.settings.delivery_min_days, b = Store.settings.delivery_max_days;
    return a === b ? 'Ships in ' + a + ' working days'
                   : 'Ships in ' + a + '–' + b + ' working days';
  };

  /* The seller block every page must carry. Returns '' until there is
     something TRUE to say, so nothing half-finished reaches a customer.

     THE GUARD, AND WHY IT IS A GUARD RATHER THAN A NOTE TO MYSELF.
     These are statutory facts. A GSTIN, a registered address and a named
     Grievance Officer are what an Indian shopper is legally entitled to, and a
     complaints line that nobody answers is worse than no line at all. So while
     the values are stand-ins — `facts_are_real` false — this prints NOTHING,
     exactly as it did when the fields were empty.

     The stand-ins can still be SEEN, at ?preview=facts, which is how the block
     gets built and checked on all twelve pages without a customer ever meeting
     it. The preview cannot be reached by accident and is not linked from
     anywhere.

     The failure this prevents is not "I might forget". It is that forgetting
     would be invisible: a page carrying a plausible fake GSTIN looks exactly
     like a page carrying a real one. */
  function previewing() {
    try {
      return /(^|[?&])preview=facts(&|$)/.test(location.search);
    } catch (e) { return false; }
  }

  Store.sellerHTML = function () {
    var t = Store.settings, out = [];
    if (!t.facts_are_real && !previewing()) return '';
    if (t.legal_name)         out.push(esc(t.legal_name));
    if (t.registered_address) out.push(esc(t.registered_address));
    if (t.gstin)              out.push('GSTIN ' + esc(t.gstin));
    if (t.grievance_officer) {
      var g = 'Grievance Officer: ' + esc(t.grievance_officer);
      if (t.grievance_email)
        g += ' &middot; <a href="mailto:' + esc(t.grievance_email) + '">' +
             esc(t.grievance_email) + '</a>';
      if (t.grievance_phone)
        g += ' &middot; <a href="tel:' + esc(t.grievance_phone.replace(/\s/g,'')) +
             '">' + esc(t.grievance_phone) + '</a>';
      out.push(g);
    }
    if (!out.length) return '';
    var line = out.join(' &middot; ');
    /* A preview must never be mistakable for the real page — including in a
       screenshot, which is how it would actually be mistaken. */
    if (!t.facts_are_real) {
      line = '<b style="color:#8C2F2F">SPECIMEN — these details are stand-ins ' +
             'and are not shown to customers.</b><br>' + line;
    }
    return line;
  };

  function esc(v) {
    return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) {
      return { '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;' }[c];
    });
  }

  Store.ready = load();
  window.IARSTORE = Store;
})(window);
