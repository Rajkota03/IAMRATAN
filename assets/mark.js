/* I AM RATAN — the mark.

   The badger greets you when you arrive, notices when you come back, and looks
   up once in a while if you are still reading. That is the whole idea, and the
   hard part of it is restraint: a logo that moves on a timer stops being alive
   and becomes a distraction. So every spontaneous reaction has to be EARNED,
   and there are more rules stopping one than starting one.

   WHEN IT MOVES
     · arrival     the walk-in, on every load
     · you return  coming back to the tab after being away 30s or more
     · you linger  while genuinely reading — first at 55s, then every 70–120s
     · you touch   hover or tap. Always allowed, never counted against the cap.

   WHAT STOPS IT
     · one clip at a time, ever
     · 22 seconds minimum between any two, the walk-in included
     · never while the tab is hidden — it would play to nobody and spend the cap
     · never mid-scroll; it waits for the page to settle
     · 45 seconds with no pointer, key or scroll and the spontaneous reactions
       stop dead until the visitor does something again. A tab left open on a
       desk is exactly the case where this would read as a nervous tic.
     · three spontaneous reactions per page view, and no more
     · prefers-reduced-motion: none of it, not even the walk-in

   Everything here is an animated image with an alpha channel, not video. Video
   autoplay is refused outright by iOS in Low Power Mode, so on a phone with the
   battery saver on the badger simply never walked. And the clips used to carry
   the house bone baked into their background at rgb(231,229,219), which against
   the header's #EDE9E0 read as a pale rectangle pasted in behind the logo. With
   the ground keyed out there is nothing left to match.

   Loaded by every page, because no other script is.                          */

(function (doc, win) {
  'use strict';

  var mk = doc.querySelector('.mk');
  if (!mk) return;
  if (win.matchMedia('(prefers-reduced-motion:reduce)').matches) return;

  var ENTRY    = 'assets/mark-walk.webp';
  var ENTRY_MS = 4400;                    /* 51 frames at 84ms, plus a beat */

  /* Each clip starts and ends on the resting pose and is fitted so its logo
     fills the frame to within a per-cent of the CSS mask mark — otherwise the
     handover back to the still logo visibly jumps in scale. The durations
     differ because the dead air was trimmed off each one: the shake was 1.18s
     of nothing at either end of a 1.76s move. */
  var CLIPS = [
    { src: 'assets/mark-r-shake.webp', ms: 2700 },  /* the wet-dog shake */
    { src: 'assets/mark-r-look.webp',  ms: 3950 },  /* a look back over the shoulder */
    { src: 'assets/mark-r-sniff.webp', ms: 3860 }   /* catches a scent */
  ];

  var AWAY_MS   = 30000;   /* time off the tab that makes coming back worth noticing */
  var GAP_MS    = 22000;   /* the floor between any two spontaneous clips */
  var TOUCH_MS  =  6000;   /* the floor between two the visitor asked for */
  var IDLE_MS   = 45000;   /* no input for this long and the visitor has gone */
  var FIRST_MS  = 55000;   /* the first look-up, if anyone is still here */
  var CAP       = 3;       /* spontaneous reactions per page view */

  var busy = false, last = -1, spent = 0, restedAt = 0;
  var lastInput = Date.now(), scrolling = 0, hiddenAt = 0;

  /* ---------- playing one ---------- */

  /* `bust` forces a fresh URL. The walk-in needs it: a cached animated image can
     resume mid-walk on a soft reload instead of starting at the first frame, and
     that is the one clip a visitor sees every single time. The reactions are
     left cacheable — a fresh element restarts them, and if a browser ever did
     resume one it is a two-second flourish that begins and ends on the resting
     pose either way. */
  function play(src, ms, bust) {
    var img = doc.createElement('img');
    img.className = 'mk-clip';
    img.alt = '';
    img.setAttribute('aria-hidden', 'true');
    img.src = bust ? src + '?r=' + Date.now() : src;

    var done = false;
    function finish() {
      if (done) return;
      done = true;
      mk.classList.remove('mk--clip');
      busy = false;
      restedAt = Date.now();
      /* let the still mark fade up under it before the clip goes */
      win.setTimeout(function () { if (img.parentNode) img.remove(); }, 400);
    }
    img.addEventListener('error', finish);

    busy = true;
    mk.appendChild(img);
    mk.classList.add('mk--clip');
    win.setTimeout(finish, ms);
  }

  function deal() {
    var i = Math.floor(Math.random() * CLIPS.length);
    if (i === last && CLIPS.length > 1) i = (i + 1) % CLIPS.length;
    last = i;
    play(CLIPS[i].src, CLIPS[i].ms, false);
  }

  /* ---------- when it is allowed to ---------- */

  function quiet() {                      /* the page is settled and watched */
    return !busy && !doc.hidden && !scrolling &&
           Date.now() - restedAt > GAP_MS;
  }

  function present() {                    /* somebody is actually here */
    return Date.now() - lastInput < IDLE_MS;
  }

  function spontaneous() {
    if (spent >= CAP || !quiet() || !present()) return false;
    spent++;
    deal();
    return true;
  }

  /* ---------- the three ways in ---------- */

  /* 1. touch. A deliberate act, so it never counts against the cap and is not
        held to the 22-second floor — but it keeps a short one of its own, or a
        cursor wandering in and out of the header machine-guns the poor animal.
        pointerenter, not mouseenter: it covers pen and touch too, and unlike
        mouseover it does not re-fire as the cursor crosses the child layers. */
  var hit = mk.closest('.markwrap') || mk;
  function touched() {
    if (!busy && !doc.hidden && Date.now() - restedAt > TOUCH_MS) deal();
  }
  hit.addEventListener('pointerenter', touched);
  /* a touch has no hover, so the tap itself is the reaction — the link still
     follows, this just runs alongside it */
  hit.addEventListener('touchstart', touched, { passive: true });

  /* 2. coming back. Leaving counts as input, so a visitor who tabs away and
        returns is 'present' by definition — the idle rule does not apply here.
        The beat before it fires lets the page finish repainting first. */
  doc.addEventListener('visibilitychange', function () {
    if (doc.hidden) { hiddenAt = Date.now(); return; }
    lastInput = Date.now();
    var away = hiddenAt && Date.now() - hiddenAt;
    hiddenAt = 0;
    if (away < AWAY_MS) return;
    win.setTimeout(function () { if (spent < CAP && quiet()) { spent++; deal(); } }, 700);
  });

  /* 3. lingering. Jittered rather than on a fixed clock — a regular interval is
        the thing that reads as a timer instead of an animal. If the moment is
        refused (scrolling, hidden, too soon, gone), it simply tries again later
        without spending anything. */
  function later() {
    win.setTimeout(function () {
      spontaneous();
      if (spent < CAP) later();
    }, 70000 + Math.random() * 50000);
  }

  /* ---------- what counts as somebody being here ---------- */

  function stir() { lastInput = Date.now(); }
  ['pointerdown', 'pointermove', 'keydown', 'wheel', 'touchstart']
    .forEach(function (e) { doc.addEventListener(e, stir, { passive: true }); });

  var settle = null;
  win.addEventListener('scroll', function () {
    lastInput = Date.now();
    scrolling = 1;
    win.clearTimeout(settle);
    settle = win.setTimeout(function () { scrolling = 0; }, 400);
  }, { passive: true });

  /* ---------- arrival ---------- */

  play(ENTRY, ENTRY_MS, true);
  /* the idle glance starts when the walk hands over, not underneath it */
  win.setTimeout(function () { mk.classList.add('mk--idle'); }, ENTRY_MS);

  /* The walk-in owns the first four seconds, so the reactions are fetched only
     once it is over — the first hover is then not a blank frame while 130KB
     arrives, and the load is not competing with the hero. */
  win.setTimeout(function () {
    CLIPS.forEach(function (c) { (new win.Image()).src = c.src; });
  }, ENTRY_MS + 600);

  win.setTimeout(function () { spontaneous(); later(); }, FIRST_MS);

})(document, window);
