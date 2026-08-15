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

  var A = { token: null, email: null };

  /* ---------- talking to the database ---------- */

  function api(path, opts) {
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
        if (!r.ok) throw new Error(j.message || j.hint || ('HTTP ' + r.status));
        return j;
      });
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

  /* ---------- who is at the desk ---------- */

  function remember(tok, email) {
    A.token = tok; A.email = email;
    try { sessionStorage.setItem(SESSION, JSON.stringify({ t: tok, e: email })); } catch (e) {}
  }
  function forget() {
    A.token = A.email = null;
    try { sessionStorage.removeItem(SESSION); } catch (e) {}
  }
  function restore() {
    try {
      var s = JSON.parse(sessionStorage.getItem(SESSION) || 'null');
      if (s && s.t) { A.token = s.t; A.email = s.e; return true; }
    } catch (e) {}
    return false;
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
      .then(function (j) { remember(j.access_token, email); return isAdmin(); });
  };

  /* First-time setup: an allowlisted person who has no Supabase account yet.
     Creating the account is harmless on its own — the allowlist still decides. */
  A.signUp = function (email, password) {
    return auth('signup', { email: email, password: password })
      .then(function (j) {
        if (j.access_token) { remember(j.access_token, email); return isAdmin(); }
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
    return api('products?select=id,slug,name,price,hex,collection,visible,sort_order' +
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

  /* ---------- reports ---------- */

  A.reportSales    = function () { return api('report_sales?select=*'); };
  A.reportProducts = function () { return api('report_products?select=*'); };
  A.exchangeRate   = function () { return api('size_exchange_rate?select=*&limit=40'); };

  function one(rows) { return (rows && rows[0]) || {}; }

  window.IARADMIN = A;
})(window, document);
