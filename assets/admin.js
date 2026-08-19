/* I AM RATAN — the house's own desk.

   WHAT THIS IS FOR
   Everything the shop knows lives in Supabase, and Supabase's own dashboard is
   a developer's tool: raw tables, SQL, row editors. Handing a shirtmaker that
   is handing him phpMyAdmin and calling it a business. This file is the other
   thing — the counter, in the house's language, showing only what somebody
   needs in order to decide something today.

   HOW IT IS KEPT SAFE
   Signing in proves who you are; the admins table decides what that is worth.
   Every policy in the database asks whether the signed-in email is on that
   list, so a stranger who creates an account lands in an empty room. This file
   holds no secret the browser could leak: the anon key is public, and the
   session token belongs to the person who signed in.                        */

(function (window, document) {
  'use strict';

  var URL_BASE = 'https://hckbqcphijihqbysibos.supabase.co';
  var ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhja2JxY3BoaWppaHFieXNpYm9zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY3MDY1ODQsImV4cCI6MjEwMjI4MjU4NH0.wg5IdL1ArScKk4dWWTtX8xyi8s4Z-1B9gKQQJBvX9V8';
  var SESSION = 'iar.admin.session';

  var A = { token: null, refresh: null, expires: 0, email: null, onLost: null };

  /* ---------- talking to the database ---------- */

  /* Every failure carries WHY on the error itself. The desk used to be handed a
     bare message and had to guess, so an expired sign-in and a missing table
     read identically — and the house was told to run SQL files at four in the
     afternoon because its hour was up. */
  function fault(status, j) {
    var e = new Error((j && (j.message || j.hint)) || ('HTTP ' + status));
    e.status = status;
    e.code = j && j.code;
    return e;
  }

  function send(path, opts) {
    opts = opts || {};
    var h = {
      apikey: ANON_KEY,
      Authorization: 'Bearer ' + (A.token || ANON_KEY),
      'Content-Type': 'application/json'
    };
    if (opts.prefer) h.Prefer = opts.prefer;
    return fetch(URL_BASE + '/rest/v1/' + path, {
      method: opts.method || 'GET',
      headers: h,
      body: opts.body ? JSON.stringify(opts.body) : undefined
    }).then(function (r) {
      if (r.status === 204) return null;
      return r.json().then(function (j) {
        if (!r.ok) throw fault(r.status, j);
        return j;
      });
    });
  }

  function api(path, opts) {
    return fresh().then(function () { return send(path, opts); })
      .catch(function (e) {
        /* A 401 the clock did not see coming — a token pulled at the other end,
           or a session left over from before the desk kept expiry times. Spend
           the refresh token once and try again; only then is it honestly over. */
        if (e.expired || e.status !== 401) throw e;
        if (!A.refresh) throw lost();
        return fresh(true).then(function () { return send(path, opts); });
      });
  }

  function auth(path, body) {
    return fetch(URL_BASE + '/auth/v1/' + path, {
      method: 'POST',
      headers: { apikey: ANON_KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify(body)
    }).then(function (r) {
      return r.json().then(function (j) {
        if (!r.ok) throw new Error(j.error_description || j.msg || j.message || 'Sign-in failed');
        return j;
      });
    });
  }

  /* ---------- who is at the desk ----------

     A Supabase access token is good for about an hour. Only the access token
     used to be kept, and nothing ever renewed it, so the desk quietly stopped
     working an hour into the day and every screen blamed a missing table. The
     refresh token is kept beside it now and spent BEFORE the hour is up, so
     the house never sees the moment it happens. */

  var SKEW = 60;          /* seconds of headroom, because clocks disagree */
  var renewing = null;    /* the one refresh in flight, if there is one */

  function nowSec() { return Math.floor(Date.now() / 1000); }

  function remember(j, email) {
    A.token = j.access_token;
    A.refresh = j.refresh_token || null;
    A.expires = nowSec() + (Number(j.expires_in) || 3600);
    A.email = email;
    try {
      sessionStorage.setItem(SESSION, JSON.stringify(
        { t: A.token, r: A.refresh, x: A.expires, e: email }));
    } catch (e) {}
  }
  function forget() {
    A.token = A.refresh = A.email = null; A.expires = 0; renewing = null;
    try { sessionStorage.removeItem(SESSION); } catch (e) {}
  }
  function restore() {
    try {
      var s = JSON.parse(sessionStorage.getItem(SESSION) || 'null');
      if (s && s.t) {
        A.token = s.t; A.refresh = s.r || null; A.expires = s.x || 0;
        A.email = s.e; return true;
      }
    } catch (e) {}
    return false;
  }

  /* When the sign-in cannot be saved there is nothing clever left to do, so it
     is ended properly and said out loud. The desk hears this and shows the
     gate — an honest "sign in again" rather than the SQL notice, which sent
     the house looking for a database fault that was never there. */
  function lost() {
    forget();
    var e = new Error('Your sign-in has run out. Please sign in again.');
    e.expired = true;
    if (typeof A.onLost === 'function') { try { A.onLost(e); } catch (x) {} }
    return e;
  }

  /* One renewal at a time. Eight panels on the dashboard all ask at once, and
     GoTrue rotates the refresh token on use — seven of those eight would come
     back invalid and sign a perfectly good desk out.

     An expiry of nothing means a session saved before the desk kept the time,
     so it is left alone until a 401 proves it stale. */
  function fresh(force) {
    if (!A.token) return Promise.resolve();
    if (!force && (!A.refresh || !A.expires || nowSec() < A.expires - SKEW))
      return Promise.resolve();
    if (!A.refresh) return Promise.reject(lost());
    if (renewing) return renewing;
    var email = A.email;
    renewing = auth('token?grant_type=refresh_token', { refresh_token: A.refresh })
      .then(function (j) {
        if (!j.access_token) throw new Error('no token returned');
        remember(j, email);
        renewing = null;
      })
      .catch(function () { renewing = null; throw lost(); });
    return renewing;
  }

  /* Being signed in is not the same as being allowed. The allowlist is checked
     by asking the database a question only an admin can answer — if the reply
     is empty, this person has an account and no business here. */
  function isAdmin() {
    return api('admins?select=email&limit=1')
      .then(function (rows) { return !!(rows && rows.length); })
      .catch(function () { return false; });
  }

  A.signIn = function (email, password) {
    return auth('token?grant_type=password', { email: email, password: password })
      .then(function (j) { remember(j, email); return isAdmin(); });
  };

  /* First-time setup: an allowlisted person who has no Supabase account yet.
     Creating the account is harmless on its own — the allowlist still decides. */
  A.signUp = function (email, password) {
    return auth('signup', { email: email, password: password })
      .then(function (j) {
        if (j.access_token) { remember(j, email); return isAdmin(); }
        /* the project asks for email confirmation */
        return 'confirm';
      });
  };

  A.signOut = function () { forget(); };
  A.session = function () { return restore() ? A : null; };
  A.check = isAdmin;

  /* ---------- what the desk can do ---------- */

  A.dashboard  = function () { return api('dashboard?select=*').then(one); };
  A.products   = function () {
    /* sku is asked for because the range table has a column for it — without it
       every row showed an em dash and the house thought the codes had gone */
    return api('products?select=id,slug,name,sku,price,hex,collection,visible,sort_order' +
               '&order=sort_order.asc');
  };
  A.stock      = function () {
    return api('inventory?select=product_id,size,qty&order=product_id.asc,size.asc');
  };
  A.settings   = function () { return api('settings?select=key,value,note&order=key.asc'); };
  A.orders     = function () {
    return api('orders?select=*&order=placed_at.desc&limit=100');
  };
  A.enquiries  = function () {
    return api('enquiries?select=*&order=came_at.desc&limit=100');
  };
  A.demand     = function () { return api('bespoke_demand?select=*&limit=40'); };
  A.kpis       = function () { return api('kpis?select=*').then(one); };
  A.actions    = function () { return api('action_required?select=*'); };
  A.best       = function () { return api('best_sellers?select=*&limit=30'); };
  A.necks      = function () { return api('neck_demand?select=*'); };
  A.people     = function () { return api('customers?select=*&limit=200'); };
  A.funnel     = function () { return api('funnel?select=*').then(one); };
  A.deltas     = function () { return api('kpi_deltas?select=*').then(one); };
  A.pipeline   = function () { return api('order_pipeline?select=*'); };
  A.neckStock  = function () { return api('neck_stock?select=*&limit=40'); };
  A.recent     = function () {
    return api('orders?select=ref,name,total,status,placed_at&order=placed_at.desc&limit=6');
  };
  A.productStats = function () { return api('product_stats?select=*').then(one); };
  A.invStats     = function () { return api('inventory_stats?select=*').then(one); };
  A.people2      = function () { return api('customer_list?select=*&limit=300'); };
  A.timeline     = function (id) {
    return api('order_events?order_id=eq.' + id + '&select=*&order=at.asc');
  };
  /* Orders come back a page at a time with the total in a header, so a shop
     with four thousand orders does not send them all to a browser. */
  A.ordersPage = function (opts) {
    opts = opts || {};
    var q = 'orders?select=*&order=placed_at.desc';
    if (opts.status && opts.status !== 'all') q += '&status=eq.' + opts.status;
    if (opts.find) {
      /* Inside or=(...) PostgREST reads , . ( ) : as grammar, and
         encodeURIComponent leaves every one of them alone — so searching for
         "R. Rao" or anything with a comma came back 400 and the house was told
         to run SQL files. Double quotes make the term a plain value; the
         backslashes are for quotes and backslashes inside it. A * still counts
         as a wildcard, which is harmless and arguably what was meant. */
      var term = String(opts.find).replace(/\\/g, '\\\\').replace(/"/g, '\\"');
      var f = encodeURIComponent('"%' + term + '%"');
      q += '&or=(ref.ilike.' + f + ',name.ilike.' + f + ',phone.ilike.' + f + ')';
    }
    var from = (opts.page || 0) * (opts.size || 10);
    return fresh().then(function () {
      return fetch(URL_BASE + '/rest/v1/' + q, {
        headers: {
          apikey: ANON_KEY, Authorization: 'Bearer ' + (A.token || ANON_KEY),
          Range: from + '-' + (from + (opts.size || 10) - 1),
          Prefer: 'count=exact'
        }
      }).then(function (r) {
        var cr = r.headers.get('content-range') || '';
        var total = Number(String(cr).split('/')[1]) || 0;
        /* This used to hand the error body back as if it were rows, so the
           screen died on rows.map and blamed the database. It throws like
           everything else now. */
        return r.json().then(function (rows) {
          if (!r.ok) throw fault(r.status, rows);
          return { rows: rows, total: total };
        });
      });
    });
  };
  A.series     = function (period) {
    return api('rpc/revenue_series', { method: 'POST', body: { period: period } });
  };
  A.returns    = function () { return api('returns?select=*&order=opened_at.desc&limit=200'); };
  A.moves      = function () {
    return api('stock_moves?select=*&order=at.desc&limit=60');
  };
  /* One order, everything about it, for the invoice and the label. */
  A.order      = function (id) { return api('orders?id=eq.' + id + '&select=*').then(one); };
  A.tax        = function (id) {
    return api('rpc/invoice_for', { method: 'POST', body: { order_id: Number(id) } })
      .then(one);
  };
  /* Stamps a number the first time and returns the same one ever after — an
     invoice number that changes is a serious problem at audit. */
  A.invoiceNo  = function (id) {
    return api('rpc/stamp_invoice', { method: 'POST', body: { order_id: Number(id) } });
  };
  A.setReturn  = function (id, patch) {
    return api('returns?id=eq.' + id, { method: 'PATCH', body: patch, prefer: 'return=minimal' });
  };
  /* A stock change is two writes: the new number, and the reason it changed.
     Without the second one nobody can ever answer "where did twelve shirts
     go?" — and that question always gets asked eventually. */
  A.moveStock  = function (productId, size, before, after, reason) {
    return A.setStock(productId, size, after).then(function () {
      return api('stock_moves', { method: 'POST', prefer: 'return=minimal', body: [{
        product_id: productId, size: size, delta: after - before,
        before_qty: before, after_qty: after,
        reason: reason || 'correction', by_email: A.email
      }] });
    });
  };

  A.setProduct = function (id, patch) {
    return api('products?id=eq.' + id, { method: 'PATCH', body: patch, prefer: 'return=minimal' });
  };
  A.setStock   = function (productId, size, qty) {
    return api('inventory?product_id=eq.' + productId + '&size=eq.' + encodeURIComponent(size),
      { method: 'PATCH', body: { qty: qty }, prefer: 'return=minimal' });
  };
  A.setSetting = function (key, value) {
    return api('settings?key=eq.' + encodeURIComponent(key),
      { method: 'PATCH', body: { value: String(value) }, prefer: 'return=minimal' });
  };
  A.setOrder   = function (id, patch) {
    return api('orders?id=eq.' + id, { method: 'PATCH', body: patch, prefer: 'return=minimal' });
  };
  A.setEnquiry = function (id, patch) {
    return api('enquiries?id=eq.' + id, { method: 'PATCH', body: patch, prefer: 'return=minimal' });
  };

  /* ---------- the measurement book ----------
     A customer is recognised by phone, because that is the one thing he gives
     at every order. Each sitting is kept; `book` is only the latest sheet. */

  A.book       = function () { return api('measurement_book?select=*&order=taken_at.desc'); };
  A.sittings   = function (phone) {
    return api('measurements?phone=eq.' + encodeURIComponent(phone) +
               '&select=*&order=taken_at.desc');
  };
  A.addSitting = function (row) {
    row.taken_by = A.email;
    return api('measurements', { method: 'POST', prefer: 'return=minimal', body: [row] });
  };

  /* ---------- the range, in full ---------- */

  A.product    = function (id) { return api('products?id=eq.' + id + '&select=*').then(one); };
  A.images     = function (productId) {
    return api('product_images?product_id=eq.' + productId +
               '&select=*&order=sort_order.asc');
  };
  A.addImage   = function (row) {
    return api('product_images', { method: 'POST', prefer: 'return=minimal', body: [row] });
  };
  A.setImage   = function (id, patch) {
    return api('product_images?id=eq.' + id,
      { method: 'PATCH', body: patch, prefer: 'return=minimal' });
  };
  A.delImage   = function (id) {
    return api('product_images?id=eq.' + id, { method: 'DELETE', prefer: 'return=minimal' });
  };

  /* ---------- collections, offers, the shop windows ---------- */

  A.collections   = function () { return api('collections?select=*&order=sort_order.asc'); };
  A.addCollection = function (row) {
    return api('collections', { method: 'POST', prefer: 'return=minimal', body: [row] });
  };
  A.setCollection = function (id, patch) {
    return api('collections?id=eq.' + id,
      { method: 'PATCH', body: patch, prefer: 'return=minimal' });
  };

  /* the performance view, so a code is never shown without what it cost */
  A.discounts   = function () { return api('discount_performance?select=*'); };
  A.addDiscount = function (row) {
    return api('discounts', { method: 'POST', prefer: 'return=minimal', body: [row] });
  };
  A.setDiscount = function (code, patch) {
    return api('discounts?code=eq.' + encodeURIComponent(code),
      { method: 'PATCH', body: patch, prefer: 'return=minimal' });
  };

  A.content     = function () { return api('content?select=*&order=slot.asc'); };
  A.setContent  = function (slot, value) {
    return api('content?slot=eq.' + encodeURIComponent(slot),
      { method: 'PATCH', body: { value: String(value) }, prefer: 'return=minimal' });
  };

  A.delDiscount = function (code) {
    return api('discounts?code=eq.' + encodeURIComponent(code),
      { method: 'DELETE', prefer: 'return=minimal' });
  };

  /* ---------- marketing ----------
     Attribution, carts and audiences are read straight from what happened.
     Nothing in here estimates, models or projects anything. */

  A.marketing   = function () { return api('marketing_overview?select=*').then(one); };
  A.channels    = function () { return api('marketing_channels?select=*'); };
  A.activity    = function () { return api('marketing_activity?select=*'); };
  A.cartStats   = function () { return api('cart_stats?select=*').then(one); };
  A.carts       = function () { return api('abandoned_carts?select=*&limit=200'); };
  A.spend       = function () { return api('ad_spend?select=*&order=month.desc'); };
  A.setSpend    = function (row) {
    /* one figure per channel per month — typing it twice corrects it */
    return api('ad_spend?on_conflict=month,channel', {
      method: 'POST', prefer: 'return=minimal,resolution=merge-duplicates', body: [row]
    });
  };

  A.audiences   = function () { return api('audience_sizes?select=*'); };
  A.campaigns   = function () { return api('campaign_list?select=*'); };
  A.campaign    = function (id) { return api('campaign_list?id=eq.' + id + '&select=*').then(one); };
  A.addCampaign = function (row) {
    return api('campaigns', { method: 'POST', prefer: 'return=representation', body: [row] })
      .then(one);
  };
  A.setCampaign = function (id, patch) {
    return api('campaigns?id=eq.' + id,
      { method: 'PATCH', body: patch, prefer: 'return=minimal' });
  };
  A.delCampaign = function (id) {
    return api('campaigns?id=eq.' + id, { method: 'DELETE', prefer: 'return=minimal' });
  };
  A.buildAudience = function (id) {
    return api('rpc/build_audience', { method: 'POST', body: { camp_id: id } });
  };
  A.recipients  = function (id) {
    return api('campaign_recipients?campaign_id=eq.' + id +
               '&select=*&order=sent_at.nullsfirst,id.asc');
  };
  A.markSent    = function (rowId) {
    return api('campaign_recipients?id=eq.' + rowId,
      { method: 'PATCH', body: { sent_at: new Date().toISOString() },
        prefer: 'return=minimal' });
  };

  /* ---------- the shop windows ----------
     Media, the home page bands, the menu and the pages. Everything here
     OVERRIDES hand-built HTML that is already correct; none of it builds a
     page from nothing. See assets/house.js for the other half. */

  A.siteStats = function () { return api('site_stats?select=*').then(one); };

  A.media     = function () { return api('media?select=*&order=added_at.desc'); };
  A.setMedia  = function (id, patch) {
    return api('media?id=eq.' + id, { method: 'PATCH', body: patch, prefer: 'return=minimal' });
  };

  /* The file goes to Storage; the row that says what the picture is OF goes to
     the table. Storage first — a catalogue entry pointing at a file that failed
     to upload is worse than a file nobody has catalogued. */
  A.upload = function (file, folder) {
    var clean = file.name.toLowerCase().replace(/[^a-z0-9.]+/g, '-').replace(/^-|-$/g, '');
    /* the name is kept, because "cocoa-drift-cuff.jpg" is findable and a uuid is
       not, and a short stamp is enough to stop two uploads colliding */
    var path = (folder || 'uncategorised').toLowerCase().replace(/[^a-z0-9]+/g, '-') +
               '/' + Date.now().toString(36) + '-' + clean;

    /* Storage does not go through api(), so it asks for a fresh token itself —
       otherwise a long afternoon's first upload is the thing that fails. */
    return fresh().then(function () {
      return fetch(URL_BASE + '/storage/v1/object/house/' + encodeURI(path), {
        method: 'POST',
        headers: {
          apikey: ANON_KEY,
          Authorization: 'Bearer ' + (A.token || ANON_KEY),
          'Content-Type': file.type || 'application/octet-stream',
          'x-upsert': 'false'
        },
        body: file
      });
    }).then(function (r) {
      if (!r.ok) {
        return r.text().then(function (t) {
          throw new Error('Upload failed (' + r.status + '). ' + t.slice(0, 160));
        });
      }
      return api('media', {
        method: 'POST', prefer: 'return=representation',
        body: [{
          path: path,
          url: URL_BASE + '/storage/v1/object/public/house/' + encodeURI(path),
          name: file.name,
          folder: folder || 'Uncategorised',
          kind: file.type,
          bytes: file.size
        }]
      }).then(one);
    });
  };

  A.delMedia = function (row) {
    /* the file goes first: a catalogue row pointing at nothing is recoverable,
       an orphaned file nobody can see or delete is not */
    return fresh().then(function () {
      return fetch(URL_BASE + '/storage/v1/object/house/' + encodeURI(row.path), {
        method: 'DELETE',
        headers: { apikey: ANON_KEY, Authorization: 'Bearer ' + (A.token || ANON_KEY) }
      });
    }).then(function () {
      return api('media?id=eq.' + row.id, { method: 'DELETE', prefer: 'return=minimal' });
    });
  };

  A.bands    = function () { return api('home_sections?select=*&order=sort_order.asc'); };
  A.setBand  = function (key, patch) {
    return api('home_sections?key=eq.' + encodeURIComponent(key),
      { method: 'PATCH', body: patch, prefer: 'return=minimal' });
  };

  A.navItems = function () { return api('nav_items?select=*&order=sort_order.asc'); };
  A.addNav   = function (row) {
    return api('nav_items', { method: 'POST', prefer: 'return=minimal', body: [row] });
  };
  A.setNav   = function (id, patch) {
    return api('nav_items?id=eq.' + id, { method: 'PATCH', body: patch, prefer: 'return=minimal' });
  };
  A.delNav   = function (id) {
    return api('nav_items?id=eq.' + id, { method: 'DELETE', prefer: 'return=minimal' });
  };

  A.pages    = function () { return api('pages?select=*&order=title.asc'); };
  A.setPage  = function (slug, patch) {
    return api('pages?slug=eq.' + encodeURIComponent(slug),
      { method: 'PATCH', body: patch, prefer: 'return=minimal' });
  };

  /* Which of the statutory facts are still stand-ins. The desk refuses to be
     quiet about this: a shop that goes live with an invented GSTIN and a
     complaints line nobody answers is the most expensive mistake on the list. */
  A.facts = function () { return api('facts_status?select=*'); };

  /* ---------- analytics ---------- */

  A.aKpis     = function () { return api('analytics_kpis?select=*').then(one); };
  A.aSeries   = function (period) {
    return api('rpc/analytics_series', { method: 'POST', body: { period: period } });
  };
  A.insights  = function () { return api('customer_insights?select=*').then(one); };
  A.locations = function () { return api('top_locations?select=*&limit=8'); };
  A.traffic   = function () { return api('traffic_sources?select=*&limit=8'); };
  A.devices   = function () { return api('device_split?select=*'); };
  A.campaignResults = function () { return api('campaign_results?select=*&limit=8'); };

  /* ---------- reports ---------- */

  A.reportSales    = function () { return api('report_sales?select=*'); };
  A.reportProducts = function () { return api('report_products?select=*'); };
  A.exchangeRate   = function () { return api('size_exchange_rate?select=*&limit=40'); };

  function one(rows) { return (rows && rows[0]) || {}; }

  window.IARADMIN = A;
})(window, document);
