/* The customer's account.
 *
 * The house rule survives intact: nobody is made to sign in to buy. Forced
 * registration is the second-highest cause of abandoned checkouts and this shop
 * sells a man two shirts a year. So there is no password anywhere in this file,
 * and no sign-up form. What exists instead:
 *
 *   - Placing an order creates the account. Silently, in the database, from the
 *     phone and email already on the order. The customer is told nothing and
 *     asked for nothing.
 *   - Signing in is asking for a code. Email or mobile, six digits, done.
 *   - The first time someone signs in, the account their orders already made is
 *     handed to them, with every past order attached.
 *   - We ask for a first and last name once, after that first code, and only if
 *     we do not already have one from an order.
 *
 * Written against PostgREST and GoTrue by hand, with no SDK, because that is
 * how every other file in this shop talks to Supabase and one convention beats
 * two. Keep the two auth worlds apart: this stores under `iar.acc`, the admin
 * desk stores under `iar.admin.session`. They share a user pool, and if they
 * shared a key a shopkeeper signing in as a customer would silently lose the
 * desk.
 */
(function (w) {
  'use strict';

  var URL_BASE = 'https://hckbqcphijihqbysibos.supabase.co';
  var ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhja2JxY3BoaWppaHFieXNpYm9zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY3MDY1ODQsImV4cCI6MjEwMjI4MjU4NH0.wg5IdL1ArScKk4dWWTtX8xyi8s4Z-1B9gKQQJBvX9V8';

  var KEY = 'iar.acc';
  var A = { url: URL_BASE, anon: ANON_KEY };

  /* ---------------------------------------------------------- the session --
     localStorage, not sessionStorage: a customer who comes back next month
     should still be himself. The refresh token is kept — the admin desk does
     not keep one and its session dies after an hour, which is fine for a
     shopkeeper at a desk and wrong for a shopper on a phone. */

  function load() {
    try { return JSON.parse(localStorage.getItem(KEY) || 'null'); } catch (e) { return null; }
  }
  function save(s) {
    try { s ? localStorage.setItem(KEY, JSON.stringify(s)) : localStorage.removeItem(KEY); }
    catch (e) {}
    A.session = s;
    fire();
  }
  A.session = load();

  function keep(j) {
    if (!j || !j.access_token) return null;
    save({
      t: j.access_token,
      r: j.refresh_token || null,
      /* expires_at is seconds since epoch; keep a minute of slack so we never
         send a token that dies in flight. */
      x: (j.expires_at ? j.expires_at * 1000 : Date.now() + 3600000) - 60000,
      email: (j.user && j.user.email) || null,
      phone: (j.user && j.user.phone) || null
    });
    return A.session;
  }

  A.signedIn = function () { return !!(A.session && A.session.t); };

  function fresh() {
    var s = A.session;
    if (!s || !s.t) return Promise.resolve(null);
    if (Date.now() < s.x) return Promise.resolve(s.t);
    if (!s.r) { save(null); return Promise.resolve(null); }
    return post('/auth/v1/token?grant_type=refresh_token', { refresh_token: s.r })
      .then(function (j) { return keep(j) ? A.session.t : null; })
      .catch(function () { save(null); return null; });
  }

  /* ------------------------------------------------------------ transport -- */

  function post(path, body) {
    return fetch(URL_BASE + path, {
      method: 'POST',
      headers: { apikey: ANON_KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify(body)
    }).then(readBody);
  }

  function readBody(r) {
    return r.text().then(function (t) {
      var j = null;
      try { j = t ? JSON.parse(t) : null; } catch (e) {}
      if (r.ok) return j;
      /* GoTrue puts the useful sentence in one of three fields depending on
         which failure it is. Reaching for only one of them is how a real error
         becomes "something went wrong". */
      var m = (j && (j.msg || j.message || j.error_description || j.error)) || ('HTTP ' + r.status);
      var e = new Error(m); e.status = r.status; e.body = j; throw e;
    });
  }

  /* Any REST call as the signed-in customer. Falls back to the anon key when
     nobody is signed in, which is correct — the shop must work either way. */
  A.api = function (path, opts) {
    opts = opts || {};
    return fresh().then(function (tok) {
      var h = {
        apikey: ANON_KEY,
        Authorization: 'Bearer ' + (tok || ANON_KEY),
        'Content-Type': 'application/json',
        Prefer: opts.prefer || 'return=representation'
      };
      return fetch(URL_BASE + '/rest/v1/' + path, {
        method: opts.method || 'GET',
        headers: h,
        body: opts.body ? JSON.stringify(opts.body) : undefined
      }).then(readBody);
    });
  };

  /* --------------------------------------------------------- what they type --
     One box. A man types his mobile or his email and should not have to tell us
     which. Ten digits or more of number = a phone; an @ = an email. */

  A.readIdentity = function (raw) {
    var v = String(raw || '').trim();
    if (!v) return null;
    if (v.indexOf('@') > -1) {
      return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(v) ? { kind: 'email', value: v.toLowerCase() } : null;
    }
    var d = v.replace(/\D/g, '');
    if (d.length < 10) return null;
    /* E.164, because GoTrue will not accept anything else. An Indian mobile is
       the last ten digits whatever the caller put in front of it. */
    return { kind: 'phone', value: '+91' + d.slice(-10) };
  };

  /* ------------------------------------------------------------- the code -- */

  /* create_user is true on purpose: a first-time visitor signing in is not an
     error to be corrected, it is the whole design. The account may already
     exist from an order, in which case GoTrue finds it. */
  A.sendCode = function (raw) {
    var id = A.readIdentity(raw);
    if (!id) return Promise.reject(new Error('That does not look like a mobile number or an email address.'));
    var body = { create_user: true };
    body[id.kind] = id.value;
    return post('/auth/v1/otp', body).then(function () { return id; });
  };

  A.verify = function (id, code) {
    var body = { token: String(code || '').trim(), type: id.kind === 'phone' ? 'sms' : 'email' };
    body[id.kind] = id.value;
    return post('/auth/v1/verify', body).then(function (j) {
      if (!keep(j)) throw new Error('That code did not work. Ask for another.');
      /* Hand them the account their orders already built, and pull every past
         order onto it. Done here rather than left to the page, because a
         customer who verifies and then closes the tab must still own his
         history next time. */
      return A.claim().then(function (p) { return p; }, function () { return null; });
    });
  };

  /* --------------------------------------------------------- the account --- */

  A.claim = function (first, last) {
    return A.api('rpc/claim_account', {
      method: 'POST',
      body: { in_first: first || null, in_last: last || null }
    }).then(function (rows) {
      A.profile = Array.isArray(rows) ? rows[0] : rows;
      fire();
      return A.profile;
    });
  };

  A.setName = function (first, last) {
    return A.api('rpc/set_my_name', {
      method: 'POST',
      body: { in_first: first, in_last: last }
    }).then(function (rows) {
      A.profile = Array.isArray(rows) ? rows[0] : rows;
      fire();
      return A.profile;
    });
  };

  A.me = function () {
    if (!A.signedIn()) return Promise.resolve(null);
    return A.api('profiles?select=*&limit=1').then(function (rows) {
      A.profile = (rows && rows[0]) || null;
      fire();
      return A.profile;
    }).catch(function () { return null; });
  };

  /* Do we still need to ask who they are? Only if no order ever told us. */
  A.needsName = function () {
    return A.signedIn() && !!A.profile && !A.profile.first_name;
  };

  A.orders = function () {
    if (!A.signedIn()) return Promise.resolve([]);
    return A.api('my_orders?select=*&order=placed_at.desc').catch(function () { return []; });
  };

  A.signOut = function () {
    var t = A.session && A.session.t;
    save(null);
    A.profile = null;
    if (t) {
      fetch(URL_BASE + '/auth/v1/logout', {
        method: 'POST',
        headers: { apikey: ANON_KEY, Authorization: 'Bearer ' + t }
      }).catch(function () {});
    }
  };

  /* ------------------------------------------------------------ listeners -- */

  var subs = [];
  A.on = function (fn) { subs.push(fn); return fn; };
  function fire() { subs.forEach(function (fn) { try { fn(A); } catch (e) {} }); }

  /* Signing in or out in one tab should not leave another tab lying. */
  w.addEventListener('storage', function (e) {
    if (e.key !== KEY) return;
    A.session = load();
    if (!A.session) A.profile = null;
    fire();
  });

  w.IARACCOUNT = A;

  /* Warm the profile so a page can ask "who is this" synchronously after load
     without every caller writing the same then(). */
  if (A.signedIn()) A.me();
})(window);
