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

  function auth(path, body) {
    return fetch(URL_BASE + '/auth/v1/' + path, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', apikey: ANON_KEY },
      body: JSON.stringify(body)
    }).then(function (r) {
      return r.json().then(function (j) {
        if (!r.ok) {
          /* Supabase speaks in codes; a customer should not have to. */
          var m = (j.error_description || j.msg || j.message || '').toLowerCase();
          if (m.indexOf('invalid login') > -1)
            throw new Error('That email and password do not match. Try again, or register.');
          if (m.indexOf('already registered') > -1)
            throw new Error('That address already has an account. Sign in instead.');
          if (m.indexOf('password') > -1 && m.indexOf('6') > -1)
            throw new Error('Use at least six characters for the password.');
          throw new Error(j.error_description || j.msg || 'That did not work. Please try again.');
        }
        return j;
      });
    });
  }

  A.signIn = function (email, password) {
    return auth('token?grant_type=password', { email: email, password: password })
      .then(function (j) {
        save(j.access_token, email, j.user && j.user.user_metadata && j.user.user_metadata.name);
        return true;
      });
  };

  A.register = function (email, password, name) {
    return auth('signup', {
      email: email, password: password, data: { name: name }
    }).then(function (j) {
      if (j.access_token) { save(j.access_token, email, name); return 'in'; }
      return 'confirm';           /* the project asks for email confirmation */
    });
  };

  A.reset = function (email) {
    return auth('recover', { email: email }).then(function () { return true; });
  };

  /* The orders placed against this address. The policy decides what comes
     back; this asks for everything and trusts the database to refuse. */
  A.orders = function () {
    return fetch(URL_BASE + '/rest/v1/orders?select=ref,total,status,placed_at,items' +
                 '&order=placed_at.desc', {
      headers: { apikey: ANON_KEY, Authorization: 'Bearer ' + A.token }
    }).then(function (r) { return r.ok ? r.json() : []; })
      .catch(function () { return []; });
  };
}(window));
