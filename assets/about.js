/* I AM RATAN — the About page, third version.

   Three jobs, all driven from scroll POSITION rather than a timer, so the page
   moves exactly as fast as the reader and stops when they stop:

     1. the ground colour of the page, which narrates the story
     2. the filmstrip that travels sideways while the reader scrolls down
     3. the ethos, held on screen for three screens

   All the reading happens inside one requestAnimationFrame, so however many
   scroll events fire, the work happens at most once a frame and never blocks
   the scroll. Without this file the stylesheet still shows a complete page. */
(function (win, doc) {
  'use strict';

  var root  = doc.documentElement;
  var body  = doc.body;
  var reduce = win.matchMedia &&
               win.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* ---- 1. the ground changes with the act ----------------------------- */
  var acts = [].slice.call(doc.querySelectorAll('[data-act-when]'));
  /* Where the page asks itself which act it is in. This used to be 45% down,
     which meant a section took the ground the moment it had filled just over
     half the screen: the reader was still looking mostly at the section above
     when the colour under it changed. At 18% a section has to fill better than
     four fifths of the view before it takes over, so the ground turns when the
     reader has actually arrived rather than while they are still leaving. */
  var PROBE = 0.18;
  function paint() {
    var mid = win.innerHeight * PROBE, act = 'paper';
    for (var i = 0; i < acts.length; i++) {
      var r = acts[i].getBoundingClientRect();
      if (r.top <= mid && r.bottom >= mid) act = acts[i].getAttribute('data-act-when');
    }
    if (body.getAttribute('data-act') !== act) body.setAttribute('data-act', act);
  }

  /* ---- 2. the filmstrip ------------------------------------------------
     Only when the browser cannot do it itself. Where view timelines exist the
     stylesheet drives this on the compositor, exactly in step with the scroll,
     and this function would only fight it one frame late. */
  var cssDrives = win.CSS && CSS.supports &&
                  CSS.supports('animation-timeline', 'view()');
  var strip = doc.querySelector('.v3-strip');
  var track = strip && strip.querySelector('.v3-track');

  /* How far the strip must travel sideways, and therefore how much scroll it
     is worth. 1.25 so the track moves a little slower than the page, which
     reads as deliberate rather than as a slide being yanked past. Measured on
     load and on resize only; nothing here runs while scrolling. */
  function measure() {
    if (!strip || !track) return;
    var over = track.scrollWidth - win.innerWidth;
    strip.style.setProperty('--travel', (over > 0 ? Math.round(over * 1.25) : 0) + 'px');
  }

  function slide() {
    if (cssDrives || !strip || !track) return;
    var r = strip.getBoundingClientRect();
    var travel = r.height - win.innerHeight;
    if (travel <= 0) return;
    var p = Math.min(1, Math.max(0, -r.top / travel));
    /* how far the track must move so its last frame ends flush at the right */
    var over = track.scrollWidth - win.innerWidth;
    if (over < 0) over = 0;
    track.style.transform = 'translate3d(' + (-p * over).toFixed(1) + 'px,0,0)';
  }

  /* ---- 3. the held ethos ---------------------------------------------- */
  var stage  = doc.querySelector('.v3-stage');
  var shots  = stage ? stage.querySelectorAll('.v3-stage-shot img') : [];
  var panels = stage ? stage.querySelectorAll('.v3-stage-copy > div') : [];
  var ticks  = stage ? stage.querySelectorAll('.v3-rail i') : [];
  var n = Math.min(shots.length, panels.length);
  var current = -1;
  /* Everything before the current beat is parked above, everything after it is
     parked below, and the one in hand sits home. Setting all three every time
     means the motion reverses itself when the reader scrolls back up, without
     this ever needing to know which way they were going. */
  function show(i) {
    if (i === current) return;
    current = i;
    for (var k = 0; k < n; k++) {
      var above = k < i, on = k === i;
      shots[k].classList.toggle('on', on);
      shots[k].classList.toggle('above', above);
      panels[k].classList.toggle('on', on);
      panels[k].classList.toggle('above', above);
      /* the words that are off screen are clipped, not gone, so say so */
      panels[k].setAttribute('aria-hidden', on ? 'false' : 'true');
      if (ticks[k]) ticks[k].classList.toggle('on', k <= i);
    }
  }
  function hold() {
    if (!stage || !n) return;
    var r = stage.getBoundingClientRect();
    var travel = r.height - win.innerHeight;
    if (travel <= 0) { show(0); return; }
    var p = Math.min(1, Math.max(0, -r.top / travel));
    /* round, not floor across thirds: the beats are snap points now, so each
       one should sit squarely inside its word and the change should happen
       halfway between two stops rather than two thirds of the way to the next */
    show(Math.min(n - 1, Math.round(p * (n - 1))));
  }

  var queued = false;
  function frame() { queued = false; paint(); slide(); hold(); }
  function onScroll() {
    if (queued) return;
    queued = true;
    win.requestAnimationFrame(frame);
  }

  show(0);
  measure();
  paint();
  if (reduce) return;              /* everything stays readable, simply still */
  win.addEventListener('scroll', onScroll, { passive: true });
  win.addEventListener('resize', function () { measure(); onScroll(); });
  win.addEventListener('load', measure);   /* fonts and images settle the width */
  frame();
}(window, document));
