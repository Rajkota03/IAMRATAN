/* I AM RATAN — the menu, on a phone.

   The bar was fitting the mark, four links and the town onto 375px by taking
   the type down to 9px and the gaps to 8px. Nothing there was a reliable
   target and none of it was comfortably readable.

   This file builds a button and turns the existing <nav> into a panel. It adds
   nothing to the page's meaning: the same four links, in the same order, in
   the same element. If this script never runs, the attribute it sets never
   appears, every rule in the stylesheet that depends on it stays inert, and
   the visitor keeps the row of links they had. A menu that needs a script in
   order to exist is a menu that can disappear. */
(function () {
  'use strict';

  var head = document.querySelector('header.top');
  var nav  = head && head.querySelector('nav.nav');
  if (!head || !nav) return;

  /* the button, built rather than written into twenty-two files by hand */
  var btn = document.createElement('button');
  btn.className = 'navbtn';
  btn.type = 'button';
  btn.setAttribute('aria-label', 'Menu');
  btn.setAttribute('aria-expanded', 'false');
  btn.innerHTML = '<i></i><i></i><i></i>';

  if (!nav.id) nav.id = 'sitenav';
  btn.setAttribute('aria-controls', nav.id);

  var veil = document.createElement('div');
  veil.className = 'navveil';

  head.appendChild(btn);
  /* The veil goes on <body>, not in the header. As a header child it was a grid
     item, and the grid laid it out despite position:fixed — measured 0px wide,
     pinned to the right edge. An overlay over the whole page does not belong
     inside the bar anyway. */
  document.body.appendChild(veil);
  /* the flag lives on <html> so it can reach the bar AND the veil at once */
  var root = document.documentElement;
  root.setAttribute('data-nav', 'closed');

  var open = false;
  var lastFocus = null;

  function set(state) {
    open = state;
    root.setAttribute('data-nav', state ? 'open' : 'closed');
    btn.setAttribute('aria-expanded', state ? 'true' : 'false');
    /* the page behind a panel should not scroll under it */
    root.style.overflow = state ? 'hidden' : '';
    if (state) {
      lastFocus = document.activeElement;
      var first = nav.querySelector('a');
      if (first) first.focus();
    } else if (lastFocus) {
      lastFocus.focus();
      lastFocus = null;
    }
  }

  btn.addEventListener('click', function () { set(!open); });
  veil.addEventListener('click', function () { set(false); });

  /* Following a link closes it. Without this the panel is still sitting there
     over the new page on a same-document jump like bespoke.html#book. */
  nav.addEventListener('click', function (e) {
    if (e.target.closest('a')) set(false);
  });

  document.addEventListener('keydown', function (e) {
    if (!open) return;
    if (e.key === 'Escape') { set(false); return; }
    if (e.key !== 'Tab') return;
    /* hold the tab ring inside the panel while it is over the page */
    var stops = nav.querySelectorAll('a');
    if (!stops.length) return;
    var first = stops[0], last = stops[stops.length - 1];
    if (e.shiftKey && document.activeElement === first) { e.preventDefault(); btn.focus(); }
    else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); btn.focus(); }
    else if (e.shiftKey && document.activeElement === btn) { e.preventDefault(); last.focus(); }
  });

  /* Widen past the breakpoint with the panel open and the links belong to the
     bar again — leaving overflow:hidden on the page would freeze the scroll.
     Kept in step with the stylesheet's 1024px drawer breakpoint. */
  var wide = window.matchMedia('(min-width:1025px)');
  (wide.addEventListener ? wide.addEventListener.bind(wide, 'change')
                         : wide.addListener.bind(wide))(function (m) {
    if (m.matches && open) set(false);
  });
})();
