/* I AM RATAN — shop engine.

   The commerce is identical across the three versions; only the transition
   language differs. So state, the bag, the enquiry and the toast live here once,
   and each version supplies its own motion.

   Sizes are the real five the house cuts. 41, 43 and 45 are shown and refused,
   because a size that does not exist is a bespoke lead rather than a dead end. */

(function (root, doc) {
  'use strict';

  var CUT = ['39', '40', '42', '44', '46'];
  var ALL = ['39', '40', '41', '42', '43', '44', '45', '46'];
  var KEY = 'iar-bag';

  var Shop = {
    range: (root.IAR && root.IAR.RANGE) || [],
    bag: [],
    reduce: matchMedia('(prefers-reduced-motion:reduce)').matches,
    supportsVT: typeof doc.startViewTransition === 'function'
  };

  /* The bag comes out of localStorage, which anybody can edit, so nothing that
     comes back is trusted. The database is the thing that actually decides what
     an order costs — see price_the_order() — but a basket holding minus five
     shirts of a cloth that does not exist should never be drawn either: it
     showed a total of ₹599,870,005 on the checkout page.

     A line survives only if it names a real cloth and carries a whole quantity
     between one and fifty. Everything else is dropped without comment; there is
     nothing useful to tell somebody who has been editing their own storage. */
  function clean(rows) {
    if (!Array.isArray(rows)) return [];
    return rows.filter(function (b) {
      /* Shop.range, not Shop.find — find() is defined further down this file
         and is not there yet when the bag is read. */
      if (!b || typeof b.slug !== 'string') return false;
      for (var i = 0; i < Shop.range.length; i++) {
        if (Shop.range[i].slug === b.slug) return true;
      }
      return false;
    }).map(function (b) {
      var q = parseInt(b.qty, 10);
      var sz = String(b.size == null ? '' : b.size);
      return {
        slug: b.slug,
        /* a neck the house actually cuts, or the middle of the range. Anything
           else would travel into the order and onto the WhatsApp message. */
        size: ALL.indexOf(sz) > -1 ? sz : '40',
        qty: (isFinite(q) && q > 0) ? Math.min(q, 50) : 1
      };
    });
  }

  try {
    Shop.bag = clean(JSON.parse(localStorage.getItem(KEY) || '[]'));
  } catch (e) { Shop.bag = []; }
  function save() { try { localStorage.setItem(KEY, JSON.stringify(Shop.bag)); } catch (e) {} }

  Shop.find = function (slug) {
    for (var i = 0; i < Shop.range.length; i++) {
      if (Shop.range[i].slug === slug) return Shop.range[i];
    }
    return null;
  };
  Shop.add = function (slug, size) {
    var p = Shop.find(slug); if (!p) return null;
    var hit = Shop.bag.filter(function (b) { return b.slug === slug && b.size === size; })[0];
    if (hit) hit.qty++; else Shop.bag.push({ slug: slug, size: size, qty: 1 });
    save(); Shop.emit();
    return p;
  };
  Shop.remove = function (i) { Shop.bag.splice(i, 1); save(); Shop.emit(); };

  /* Emptied once an order is paid for. Same reason setQty lives here: saving is
     private to this file, so a page that emptied Shop.bag itself would clear the
     screen and find the old bag waiting on the next reload. */
  Shop.clear = function () { Shop.bag.length = 0; save(); Shop.emit(); };

  /* Quantity belongs here rather than in the checkout page, because saving is
     private to this file — a page nudging bag[i].qty directly would change the
     number on screen and lose it on the next reload. Going to zero removes the
     line, which is what a customer means by pressing minus once more. */
  Shop.setQty = function (i, n) {
    var item = Shop.bag[i];
    if (!item) return;
    if (n <= 0) return Shop.remove(i);
    item.qty = n;
    save();
    Shop.emit();
  };
  Shop.count = function () {
    return Shop.bag.reduce(function (n, b) { return n + b.qty; }, 0);
  };
  Shop.total = function () {
    return Shop.bag.reduce(function (n, b) {
      var p = Shop.find(b.slug); return n + (p ? p.price * b.qty : 0);
    }, 0);
  };
  Shop.rupees = function (n) {
    return '₹' + String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  };

  /* one payment, nothing recurring — the order leaves as a written note to the
     house, which is how bespoke actually works */
  Shop.enquiry = function () {
    var lines = Shop.bag.map(function (b) {
      var p = Shop.find(b.slug);
      return '  ' + (p ? p.name : b.slug) + '  ·  size ' + b.size +
             '  ·  x' + b.qty + '  ·  ' + (p ? p.priceText : '');
    });
    var body =
      'I would like to order the following shirts from the house.\n\n' +
      lines.join('\n') +
      '\n\n  Total  ' + Shop.rupees(Shop.total()) +
      '\n\nName:\nPhone:\nCity:\n\nAnything else you should know:\n';
    return 'mailto:prashanth@iamratan.co.in' +
      '?subject=' + encodeURIComponent('Order — ' + Shop.count() + ' shirt' +
        (Shop.count() === 1 ? '' : 's')) +
      '&body=' + encodeURIComponent(body);
  };

  /* size chips; the three the house does not cut are present and refusable */
  Shop.sizes = function (p) {
    return ALL.map(function (z) {
      var has = p.sizes.indexOf(z) > -1;
      return '<button class="sz' + (has ? '' : ' uncut') + '" type="button" ' +
        'data-size="' + z + '"' + (has ? '' : ' data-uncut="1"') +
        ' aria-label="Size ' + z + (has ? '' : ', not cut. Made to measure') + '">' +
        z + '</button>';
    }).join('');
  };

  var subs = [];
  Shop.on = function (fn) { subs.push(fn); };
  Shop.emit = function () { subs.forEach(function (f) { f(); }); };

  /* ---- the bag, mounted once per page and styled by the page ------------- */
  Shop.mountBag = function () {
    var d = doc.createElement('dialog');
    d.className = 'bag';
    d.setAttribute('aria-label', 'Your cart');
    d.innerHTML =
      '<div class="bag-in">' +
        '<div class="bag-top"><h2 class="bag-title">Your cart</h2>' +
        '<button class="bag-x" type="button" aria-label="Close">✕</button></div>' +
        '<div class="bag-body" id="bagBody"></div>' +
        '<div class="bag-foot">' +
          '<div class="bag-row"><span>Total</span><b class="fig" id="bagTotal"></b></div>' +
          '<a class="bag-send" href="checkout.html">Checkout</a>' +
          /* The written order stays, one step quieter. Some customers would
             rather talk to the house than type a card number into a shirt shop
             they met yesterday, and losing that sale to tidiness would be
             expensive. */
          '<a class="bag-alt" id="bagSend" href="#">Or send the order in writing</a>' +
        '</div>' +
      '</div>';
    doc.body.appendChild(d);

    function render() {
      var body = doc.getElementById('bagBody');
      if (!Shop.bag.length) {
        body.innerHTML = '<p class="bag-empty">Nothing yet. The range is to your left.</p>';
      } else {
        body.innerHTML = Shop.bag.map(function (b, i) {
          var p = Shop.find(b.slug);
          return '<div class="bag-item">' +
            '<span class="bag-sw" style="background:' + (p ? p.hex : '#888') + '"></span>' +
            '<span class="bag-nm">' + (p ? p.name : b.slug) +
              '<em>size ' + b.size + (b.qty > 1 ? ' · ×' + b.qty : '') + '</em></span>' +
            '<span class="fig">' + (p ? Shop.rupees(p.price * b.qty) : '') + '</span>' +
            '<button class="bag-rm" type="button" data-i="' + i + '" aria-label="Remove">–</button>' +
          '</div>';
        }).join('');
      }
      doc.getElementById('bagTotal').textContent = Shop.rupees(Shop.total());
      doc.getElementById('bagSend').setAttribute('href', Shop.enquiry());
      doc.querySelectorAll('[data-bag-count]').forEach(function (el) {
        el.textContent = Shop.count();
      });
    }
    Shop.on(render); render();

    d.addEventListener('click', function (e) {
      if (e.target === d) d.close();
      var rm = e.target.closest('.bag-rm');
      if (rm) Shop.remove(+rm.dataset.i);
      if (e.target.closest('.bag-x')) d.close();
    });
    Shop.openBag = function () {
      if (typeof d.showModal === 'function') d.showModal(); else d.setAttribute('open', '');
    };
    return d;
  };

  /* a quiet confirmation, styled by the page via .toast */
  var toastEl, toastT;
  Shop.toast = function (msg) {
    if (!toastEl) {
      toastEl = doc.createElement('div');
      toastEl.className = 'toast';
      toastEl.setAttribute('role', 'status');
      doc.body.appendChild(toastEl);
    }
    toastEl.innerHTML = msg;
    toastEl.classList.add('on');
    clearTimeout(toastT);
    toastT = setTimeout(function () { toastEl.classList.remove('on'); }, 2600);
  };

  /* wire any container of .sz chips + an add button, with the refusal built in */
  Shop.wireSizes = function (scope, getSlug) {
    scope.addEventListener('click', function (e) {
      var sz = e.target.closest('.sz');
      if (sz) {
        var box = sz.closest('[data-sizes]') || scope;
        if (sz.dataset.uncut) {
          Shop.toast('Size ' + sz.dataset.size + ' is not cut — it is made to measure. ' +
            '<a href="bespoke.html">The bespoke house →</a>');
          return;
        }
        box.querySelectorAll('.sz').forEach(function (b) { b.classList.remove('on'); });
        sz.classList.add('on');
        box.setAttribute('data-size', sz.dataset.size);
        return;
      }
      /* Add to Cart and Buy now put the same shirt in the same cart. The only
         difference is where you land: Add stays on the page so the range can
         keep being browsed, Buy goes straight to checkout. Adding never opens
         the drawer — the count changes and that is all, because a cart that
         throws itself open interrupts the browse it was meant to serve. */
      var act = e.target.closest('[data-add],[data-buy]');
      if (act) {
        var buying = act.hasAttribute('data-buy');
        var host = act.closest('[data-sizes]') || scope;
        var size = host.getAttribute('data-size');
        if (!size) { Shop.toast('Choose a size first.'); return; }
        var p = Shop.add(getSlug(act), size);
        if (!p) return;
        if (buying) { location.href = 'checkout.html'; return; }
        Shop.toast(p.name + ' · size ' + size + ' added to your cart.');
      }
    });
  };

  root.SHOP = Shop;
})(window, document);
