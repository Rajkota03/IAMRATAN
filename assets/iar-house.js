/* I AM RATAN — house behaviour, v1 language.

   Three jobs only: reveal on entry, play films while they are on stage, stamp the
   year. Everything else a page needs, that page owns.

   The reveal is never the only path to visible content: a timeout releases every
   element regardless, so a starved observer (zero-height embeds, odd webviews,
   a print stylesheet) can never leave the page blank. */

(function (doc, win) {
  'use strict';

  var reduce = win.matchMedia('(prefers-reduced-motion:reduce)').matches;

  /* ---- ground ------------------------------------------------------------
     ?ground=bone|white swaps the token set so the same page can be compared
     against the client's white references without a second build. Applied
     before first paint would be better, but this file is loaded at the end of
     <body>, so the attribute is set on documentElement and the transition is
     suppressed for one frame to avoid a visible flash. */
  try {
    var g = new URLSearchParams(win.location.search).get('ground');
    if (g === 'dark' || g === 'white') {
      doc.documentElement.setAttribute('data-ground', g);
      var m = doc.querySelector('meta[name="theme-color"]');
      if (m) m.setAttribute('content', g === 'dark' ? '#101214' : '#FFFFFF');
    }
  } catch (e) {}

  /* ---- reveals ---------------------------------------------------------- */
  /* .settle and .lines hold their contents hidden until .in arrives, exactly as
     .rise does, so they belong in the same pass.

     The flag on <html> is why the hiding is safe at all. Every "start hidden"
     rule is scoped behind it, so a photograph is only ever made invisible once
     this script is running and can be relied on to reveal it. If the file never
     loads, fails, or is blocked, the attribute never appears, none of those
     rules match, and the page is simply the page. Same contract nav.js uses for
     the drawer. */
  doc.documentElement.setAttribute('data-reveal', 'on');
  var marks = doc.querySelectorAll('.snap,.rise,.settle,.lines,.stag');

  function releaseAll() {
    for (var i = 0; i < marks.length; i++) marks[i].classList.add('in');
  }

  if (reduce || !('IntersectionObserver' in win)) {
    releaseAll();
  } else {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (!e.isIntersecting) return;
        e.target.classList.add('in');
        io.unobserve(e.target);
      });
    }, { rootMargin: '0px 0px -8% 0px' });

    for (var i = 0; i < marks.length; i++) io.observe(marks[i]);
    win.setTimeout(releaseAll, 2500);
  }

  /* ---- films ------------------------------------------------------------
     autoplay is a request, not a guarantee; a rejected promise is normal on
     iOS low-power mode and must not throw. */
  var films = doc.querySelectorAll('video[data-film]');
  if (films.length && !reduce && 'IntersectionObserver' in win) {
    var vo = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) {
          var p = e.target.play();
          if (p && p.catch) p.catch(function () {});
        } else {
          e.target.pause();
        }
      });
    }, { threshold: 0.15 });
    for (var j = 0; j < films.length; j++) vo.observe(films[j]);
  }

  /* ---- the year ---------------------------------------------------------- */
  var year = doc.getElementById('year');
  if (year) year.textContent = new Date().getFullYear();

})(document, window);
