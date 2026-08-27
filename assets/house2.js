/* I AM RATAN — the held stage on the second About page.

   One job: as the reader scrolls the three-screen ethos section, work out which
   third they are in and mark that word and that photograph. Everything else on
   the page is CSS.

   It reads scroll position inside a rAF, never in the scroll handler itself, so
   the work happens once per frame at most and never blocks the scroll. If this
   file does not run, the stylesheet shows the first word and the first picture
   rather than an empty black screen. */
(function (win, doc) {
  'use strict';

  var stage = doc.querySelector('.v2-stage');
  if (!stage) return;

  var shots  = stage.querySelectorAll('.v2-stage-shot img');
  var panels = stage.querySelectorAll('.v2-stage-copy > .v2-panel');
  var ticks  = stage.querySelectorAll('.v2-tick i');
  var n = Math.min(shots.length, panels.length);
  if (!n) return;

  var reduce = win.matchMedia &&
               win.matchMedia('(prefers-reduced-motion: reduce)').matches;

  var current = -1;
  function show(i) {
    if (i === current) return;
    current = i;
    for (var k = 0; k < n; k++) {
      var on = k === i;
      shots[k].classList.toggle('on', on);
      panels[k].classList.toggle('on', on);
      if (ticks[k]) ticks[k].classList.toggle('on', on);
    }
  }

  var queued = false;
  function measure() {
    queued = false;
    var r = stage.getBoundingClientRect();
    var travel = r.height - win.innerHeight;      /* how far it is pinned for */
    if (travel <= 0) { show(0); return; }
    /* 0 when the stage first sticks, 1 when it releases */
    var p = Math.min(1, Math.max(0, -r.top / travel));
    /* a hair inside each boundary so the last panel is fully reached */
    show(Math.min(n - 1, Math.floor(p * n * 0.999)));
  }
  function onScroll() {
    if (queued) return;
    queued = true;
    win.requestAnimationFrame(measure);
  }

  show(0);
  if (reduce) return;                 /* still readable, simply does not follow */
  win.addEventListener('scroll', onScroll, { passive: true });
  win.addEventListener('resize', onScroll);
  measure();
}(window, document));
