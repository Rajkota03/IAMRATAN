/* I AM RATAN — the customer's own account.

   Deliberately small. Supabase Auth already runs this project for the desk, so
   a customer account is the same mechanism with a different allowlist: none.
   Anyone may register, and an account by itself can read exactly one thing,
   the orders placed against that email address, because that is what the
   row-level policy permits and nothing else.

   The token lives in localStorage under its own key, kept apart from the
   desk's, so signing in here can never be mistaken for signing in there. */

(function (root) {
  'use strict';

  var URL_BASE = 'https://hckbqcphijihqbysibos.supabase.co';
  var ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhja2JxY3BoaWppaHFieXNpYm9zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY3MDY1ODQsImV4cCI6MjEwMjI4MjU4NH0.wg5IdL1ArScKk4dWWTtX8xyi8s4Z-1B9gKQQJBvX9V8';
  var KEY = 'iar.account.v1';

  var A = root.IARACCOUNT = {};
  A.token = null; A.email = null; A.name = null;

  function save(tok, email, name) {
    A.token = tok; A.email = email; A.name = name || null;
    try { localStorage.setItem(KEY, JSON.stringify({ t: tok, e: email, n: A.name })); } catch (e) {}
  }
  A.restore = function () {
    try {
      var s = JSON.parse(localStorage.getItem(KEY) || 'null');
      if (s && s.t) { A.token = s.t; A.email = s.e; A.name = s.n; return true; }
    } catch (e) {}
    return false;
  };
  A.signOut = function () {
    A.token = A.email = A.name = null;
    try { localStorage.removeItem(KEY); } catch (e) {}
  };

  function auth(path, body, qs) {
    return fetch(URL_BASE + '/auth/v1/' + path + (qs || ''), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', apikey: ANON_KEY },
      body: JSON.stringify(body)
    }).then(function (r) {
      return r.json().then(function (j) {
        if (!r.ok) {
          /* Supabase speaks in codes and in its own voice; a customer should
             have to read neither. Anything not caught here used to reach the
             page verbatim — "Database error saving new user" and "For security
             purposes, you can only request this after 51 seconds" were both
             being shown to whoever was trying to open an account. */
          var code = (j.error_code || j.code || '') + '';
          var m = (j.error_description || j.msg || j.message || '').toLowerCase();

          if (m.indexOf('invalid login') > -1 || code === 'invalid_credentials')
            throw new Error('That email and password do not match. Try again, or register.');

          if (m.indexOf('already registered') > -1 || code === 'user_already_exists')
            throw new Error('That address already has an account. Sign in instead.');

          if (code === 'weak_password' || (m.indexOf('password') > -1 && m.indexOf('6') > -1))
            throw new Error('Use at least six characters for the password.');

          if (m.indexOf('not confirmed') > -1 || code === 'email_not_confirmed')
            throw new Error('This account is made but not confirmed yet. Open the email we sent and follow the link, then sign in.');

          /* The one most likely to be hit while testing: Supabase's own mail
             service allows only a few messages an hour. It is not the
             customer's fault and it is not permanent. */
          if (r.status === 429 || code.indexOf('rate_limit') > -1 ||
              m.indexOf('rate limit') > -1 || m.indexOf('for security purposes') > -1)
            throw new Error('Too many attempts in a short while. Wait a minute and try once more, or write to us and the house will set it up for you.');

          if (m.indexOf('database error') > -1 || r.status >= 500)
            throw new Error('Something went wrong at our end, not yours. Please try again in a moment, or write to us and we will open the account for you.');

          if (m.indexOf('unable to validate email') > -1 || code === 'validation_failed')
            throw new Error('That email address does not look right. Check it and try again.');

          if (m.indexOf('signups not allowed') > -1 || code === 'signup_disabled')
            throw new Error('New accounts are closed just now. Write to us and the house will open one for you.');

          throw new Error('That did not work. Please try again, or write to us and we will help.');
        }
        return j;
      });
    });
  }

  A.signIn = function (email, password) {
    return auth('token?grant_type=password', { email: email, password: password })
      .then(function (j) {
        save(j.access_token, email, j.user && j.user.user_metadata && j.user.user_metadata.name);
        A.stoppedWaiting(); A.forget();
        return true;
      });
  };

  A.register = function (email, password, name) {
    return auth('signup', {
      email: email, password: password, data: { name: name }
    }, '?redirect_to=' + encodeURIComponent(A.landing())).then(function (j) {
      if (j.access_token) { save(j.access_token, email, name); return 'in'; }
      return 'confirm';           /* the project asks for email confirmation */
    });
  };

  A.reset = function (email) {
    /* Where the link in the email should land. Without this Supabase uses the
       project's Site URL, which is a dashboard setting nobody looking at this
       code can see — and if it is wrong the customer lands on an error. */
    return auth('recover', {
      email: email,
      gotrue_meta_security: {}
    }, '?redirect_to=' + encodeURIComponent(A.landing())).then(function () { return true; });
  };

  /* ---------- somebody who is waiting on an email ----------
     The check-your-email page invites them to go and look at the range while
     they wait, and then forgot them the moment they did: back on this page they
     got the empty register form again, as though nothing had happened. Anybody
     who has just typed their name, address and a password will not enjoy being
     asked for all three a second time.

     So the wait is remembered. A day is the outside life of a confirmation
     link; past that the form is the honest thing to show. */
  var PENDING = 'iar.account.pending';
  var DAY = 24 * 60 * 60 * 1000;

  A.waiting = function () {
    try {
      var w = JSON.parse(localStorage.getItem(PENDING) || 'null');
      if (w && w.email && (Date.now() - (w.at || 0)) < DAY) return w.email;
      if (w) localStorage.removeItem(PENDING);      /* stale */
    } catch (e) {}
    return null;
  };
  A.startedWaiting = function (email) {
    try {
      localStorage.setItem(PENDING, JSON.stringify({ email: email, at: Date.now() }));
    } catch (e) {}
  };
  A.stoppedWaiting = function () {
    try { localStorage.removeItem(PENDING); } catch (e) {}
  };

  /* What they typed into the register form, so leaving the page and coming back
     does not cost them the typing. The PASSWORD IS NEVER KEPT — a password in
     localStorage is readable by any script that ever runs on this origin, and
     saving somebody two seconds is not worth that. */
  var TYPED = 'iar.account.typed';
  A.remember = function (name, email) {
    try {
      localStorage.setItem(TYPED, JSON.stringify({ n: name || '', e: email || '' }));
    } catch (e) {}
  };
  A.recall = function () {
    try { return JSON.parse(localStorage.getItem(TYPED) || 'null') || {}; }
    catch (e) { return {}; }
  };
  A.forget = function () { try { localStorage.removeItem(TYPED); } catch (e) {} };

  /* Send the confirmation again. The first one goes astray often enough —
     spam folders, a mistyped address, a phone that was offline — that a
     customer stuck on "check your email" with no way forward will simply
     give up. */
  A.resend = function (email) {
    return auth('resend', { type: 'signup', email: email },
                '?redirect_to=' + encodeURIComponent(A.landing()))
      .then(function () { return true; });
  };

  /* The one address every auth email should come back to. */
  A.landing = function () {
    return location.origin + '/account.html';
  };

  /* ---------- finishing what an email link started ----------
     Supabase sends the customer to the Site URL carrying the result in the hash
     — #access_token=… on success, #error=… when the link has expired. Nothing
     read it, so confirming an account or resetting a password ended on a page
     that said nothing at all about either.

     Returns what the page should do about it, and clears the hash so a reload
     or a shared URL cannot replay it. */
  A.fromEmail = function () {
    var h = (location.hash || '').replace(/^#/, '');
    var q = location.search || '';
    if (!h && q.indexOf('error') < 0) return null;

    var p = {};
    (h || q.replace(/^\?/, '')).split('&').forEach(function (kv) {
      if (!kv) return;
      var i = kv.indexOf('=');
      var k = decodeURIComponent(i < 0 ? kv : kv.slice(0, i));
      var v = decodeURIComponent((i < 0 ? '' : kv.slice(i + 1)).replace(/\+/g, ' '));
      p[k] = v;
    });

    if (!p.access_token && !p.error && !p.error_description) return null;

    /* Never leave a live token sitting in the address bar. */
    try {
      history.replaceState(null, '',
        location.pathname + (p.type === 'recovery' ? '?recovery' : ''));
    } catch (e) {}

    if (p.error || p.error_description) {
      return { ok: false, kind: p.type || 'signup',
               why: p.error_description || p.error };
    }

    /* A recovery link signs them in exactly long enough to choose a new
       password. A signup link signs them in for good. */
    save(p.access_token, '', '');
    return { ok: true, kind: p.type || 'signup', token: p.access_token };
  };

  /* Who the token belongs to. The email link hands over a token and nothing
     else, so without this the page would greet a confirmed customer by no name
     and show a blank address where theirs should be. */
  A.whoami = function () {
    if (!A.token) return Promise.resolve(null);
    return fetch(URL_BASE + '/auth/v1/user', {
      headers: { apikey: ANON_KEY, Authorization: 'Bearer ' + A.token }
    }).then(function (r) {
      if (!r.ok) throw new Error(r.status);
      return r.json();
    }).then(function (u) {
      save(A.token, u.email || '', (u.user_metadata || {}).name || '');
      return u;
    }).catch(function () { return null; });
  };

  /* Set a new password, using the session the recovery link just gave us. */
  A.setPassword = function (password) {
    return fetch(URL_BASE + '/auth/v1/user', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', apikey: ANON_KEY,
                 Authorization: 'Bearer ' + A.token },
      body: JSON.stringify({ password: password })
    }).then(function (r) {
      return r.json().then(function (j) {
        if (!r.ok) throw new Error(j.msg || j.message || 'That password could not be saved.');
        if (j.email) save(A.token, j.email, (j.user_metadata || {}).name || '');
        return true;
      });
    });
  };

  /* The orders placed against this address, each with its own timeline, in one
     round trip. The policy decides what comes back; this asks and trusts the
     database to refuse.

     order_events is embedded rather than fetched per order. A customer has a
     handful of orders, so one query beats one-plus-N, and the same row-level
     policy covers the embedded rows as covers the parent.

     by_email is deliberately NOT selected. The desk stamps its own address on
     every stage it advances, and that is the house's business, not the
     customer's. Ask only for the three fields the page actually prints. */
  var FIELDS = [
    'ref', 'total', 'status', 'placed_at', 'updated_at', 'items',
    'address', 'city', 'pincode', 'state',
    'payment_state', 'payment_ref', 'payment_method',
    'discount_code', 'discount_amount', 'courier',
    'order_events(stage,note,at)'
  ].join(',');

  A.orders = function () {
    return fetch(URL_BASE + '/rest/v1/orders?select=' + FIELDS +
                 '&order=placed_at.desc', {
      headers: { apikey: ANON_KEY, Authorization: 'Bearer ' + A.token }
    }).then(function (r) {
      /* A token that has expired comes back 401, and returning [] for that is
         how an expired session came to look exactly like an account with no
         orders in it — "No orders against this address yet" shown to somebody
         who has ordered three times. Say which it is. */
      if (r.status === 401 || r.status === 403) {
        var e = new Error('signed out');
        e.expired = true;
        throw e;
      }
      return r.ok ? r.json() : [];
    }).catch(function (err) {
      if (err && err.expired) throw err;
      return [];                 /* a network wobble is not a sign-out */
    });
  };
}(window));
