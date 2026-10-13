/* calligram interactive layer (v2.3)
 * Inlined into the HTML page by calligram.ado. Works on the page's
 * .pane > svg.wc > .w elements: a <g> with the word's exact letter outlines
 * (the default) or a <text> (online option). The layout itself never changes.
 *
 * Right-hand panel with two states:
 *   open  - labelled sections: search, minimum count, top words, view,
 *           appearance, save
 *   rail  - a narrow column of icons with a vertical slider
 * Plus: hover card (count, rank, share) with hover focus, click to hide,
 * zoom/pan, fullscreen, light/dark, palettes, by() tabs, a gentle load
 * animation and keyboard shortcuts (press ? for the list).
 */
(function () {
  'use strict';
  var cfg = window.WC_CONFIG || {};
  var panes = Array.prototype.slice.call(document.querySelectorAll('.pane'));
  if (!panes.length) return;
  var doc = document, body = doc.body;
  var stage = doc.getElementById('stage');
  var tt = doc.getElementById('tt');
  var panelEl = doc.getElementById('panel');
  var tabsEl = doc.getElementById('tabs');
  var countEl = doc.getElementById('nw');
  var state = { active: 0, query: '', theme: 'orig', palette: 'orig', listAll: false };
  var drag = null, ui = {}, sliders = [];
  var reduceMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  var PALETTES = [
    { id: 'orig', name: 'As drawn' },
    { id: 'tableau', name: 'Tableau 10', colors: ['#4e79a7', '#f28e2b', '#e15759', '#76b7b2', '#59a14f', '#edc948', '#b07aa1', '#ff9da7', '#9c755f', '#bab0ac'], cycle: true },
    { id: 'viridis', name: 'Viridis', colors: ['#440154', '#3b528b', '#21918c', '#5ec962', '#fde725'] },
    { id: 'warm', name: 'Warm', colors: ['#9d0208', '#e85d04', '#ffba08'] },
    { id: 'cool', name: 'Cool', colors: ['#023e8a', '#0096c7', '#48cae4', '#90e0ef'] },
    { id: 'greys', name: 'Greys' }
  ];
  var THEMES = {
    orig: { bg: cfg.bg || '#16213e', ink: cfg.ink || '#eeeeee' },
    alt: cfg.light ? { bg: '#16213e', ink: '#eeeeee' } : { bg: '#ffffff', ink: '#222222' }
  };

  // ── icons (24x24, drawn with lines) ──────────────────────────────────────
  var ICON = {
    search: '<circle cx="11" cy="11" r="7"/><line x1="16.5" y1="16.5" x2="21" y2="21"/>',
    left: '<polyline points="15 6 9 12 15 18"/>',
    right: '<polyline points="9 6 15 12 9 18"/>',
    eye: '<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
    theme: '<circle cx="12" cy="12" r="9"/><path d="M12 3a9 9 0 0 0 0 18z" fill="currentColor"/>',
    palette: '<circle cx="12" cy="12" r="9"/><circle cx="8" cy="10" r="1.6" fill="currentColor"/><circle cx="12" cy="7.5" r="1.6" fill="currentColor"/><circle cx="16" cy="10" r="1.6" fill="currentColor"/><circle cx="14.5" cy="15" r="1.6" fill="currentColor"/>',
    plus: '<line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>',
    minus: '<line x1="5" y1="12" x2="19" y2="12"/>',
    reset: '<path d="M3 12a9 9 0 1 0 3-6.7"/><polyline points="3 3 3 8.5 8.5 8.5"/>',
    full: '<path d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5"/>',
    save: '<path d="M12 4v11"/><polyline points="7 10.5 12 15.5 17 10.5"/><line x1="5" y1="20" x2="19" y2="20"/>',
    help: '<circle cx="12" cy="12" r="9"/><path d="M9.6 9.2a2.5 2.5 0 1 1 3.4 2.4c-.7.3-1 .9-1 1.6"/><circle cx="12" cy="17" r=".6" fill="currentColor"/>'
  };
  function svgIcon(name) {
    return '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + ICON[name] + '</svg>';
  }

  // ── small helpers ─────────────────────────────────────────────────────────
  function make(tag, props, text) {
    var e = doc.createElement(tag);
    if (props) for (var k in props) e.setAttribute(k, props[k]);
    if (text != null) e.textContent = text;
    return e;
  }
  function iconButton(name, title, onClick) {
    var b = make('button', { type: 'button', 'class': 'ib', title: title, 'aria-label': title });
    b.innerHTML = svgIcon(name);
    b.addEventListener('click', onClick);
    return b;
  }
  function rgb(hex) {
    hex = hex.replace('#', '');
    if (hex.length === 3) hex = hex[0] + hex[0] + hex[1] + hex[1] + hex[2] + hex[2];
    return [parseInt(hex.slice(0, 2), 16), parseInt(hex.slice(2, 4), 16), parseInt(hex.slice(4, 6), 16)];
  }
  function hex2(v) { var s = Math.round(v).toString(16); return s.length < 2 ? '0' + s : s; }
  function interp(stops, t) {
    if (stops.length === 1) return stops[0];
    var x = t * (stops.length - 1), i = Math.min(Math.floor(x), stops.length - 2), f = x - i;
    var a = rgb(stops[i]), b = rgb(stops[i + 1]);
    return '#' + hex2(a[0] + f * (b[0] - a[0])) + hex2(a[1] + f * (b[1] - a[1])) + hex2(a[2] + f * (b[2] - a[2]));
  }
  function isLight(c) {
    if (!/^#[0-9a-f]{3}([0-9a-f]{3})?$/i.test(c)) return false;
    var v = rgb(c);
    return 0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2] > 127.5;
  }
  function pane() { return panes[state.active]; }
  /** the word element an event landed on (its hover box or letters, or a <text>) */
  function wordOf(t) {
    if (!t || t.nodeType !== 1) return null;
    if (t.classList && t.classList.contains('w')) return t;
    return t.closest ? t.closest('.w') : null;
  }
  function typing(ev) { var t = ev.target; return t && (t.tagName === 'INPUT' || t.tagName === 'SELECT' || t.tagName === 'TEXTAREA'); }

  // ── per-pane setup ────────────────────────────────────────────────────────
  panes.forEach(function (p) {
    var svg = p.querySelector('svg.wc');
    p._svg = svg;
    // a large cloud or a map: while zooming or dragging, move the drawn picture
    // (fast, done by the graphics card) and redraw it sharp once movement stops
    (function () {
      var n = svg.querySelectorAll('.w').length, ol = 0;
      var o = svg.querySelectorAll('path.outline');
      for (var i = 0; i < o.length; i++) ol += (o[i].getAttribute('d') || '').length;
      p._big = n > 300 || ol > 200000;
      if (p._big) {
        p._svg.classList.add('big');
        // prepared once (not at the start of every zoom): a zoom then starts at once
        p._svg.style.transformOrigin = '0 0';
        p._svg.style.willChange = 'transform';
        p._svg.style.transform = 'translate(0px,0px) scale(1)';
      }
    })();
    p._W = +svg.getAttribute('width');
    p._H = +svg.getAttribute('height');
    p._words = Array.prototype.slice.call(svg.querySelectorAll('.w'));
    p._max = 1;
    p._total = 0;
    p._words.forEach(function (w, i) {
      w.setAttribute('data-fill0', w.getAttribute('fill'));
      w.setAttribute('data-rank', i + 1);
      var c = +w.getAttribute('data-count');
      p._total += c;
      if (c > p._max) p._max = c;
    });
    p._thr = 1;
    p._rv = [0, 0, p._W, p._H];        // home view: the whole cloud (widened to the area's shape by fit)
    // the category key: clicking an entry hides or shows that group's words
    p._offCats = {};
    Array.prototype.forEach.call(p.querySelectorAll('.legend .sw[data-cat]'), function (sw) {
      sw.setAttribute('role', 'button');
      sw.setAttribute('tabindex', '0');
      sw.setAttribute('aria-pressed', 'false');
      sw.title = 'Click to hide or show these words';
      var toggle = function () {
        var k = sw.getAttribute('data-cat');
        if (p._offCats[k]) delete p._offCats[k]; else p._offCats[k] = 1;
        sw.classList.toggle('off', !!p._offCats[k]);
        sw.setAttribute('aria-pressed', p._offCats[k] ? 'true' : 'false');
        apply();
      };
      sw.addEventListener('click', toggle);
      sw.addEventListener('keydown', function (e) { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); e.stopPropagation(); toggle(); } });
    });
    p._vb = p._rv.slice();
    setupPointer(p);
  });

  // ── hover card and hover focus ────────────────────────────────────────────
  // Large clouds (maps): the cloud itself is never redrawn on hover. A
  // see-through layer covers it and a copy of the word is drawn on top, in a
  // small picture of its own; the browser only redraws those two.
  var veil = null, lift = null;
  function liftLayers() {
    if (veil) return;
    veil = make('div', { 'class': 'wc-veil' });
    lift = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    lift.setAttribute('class', 'wc-lift');
    document.body.appendChild(veil);
    document.body.appendChild(lift);
  }
  function focusWord(w, on) {
    var svg = w.ownerSVGElement;
    if (!svg) return;
    if (!svg.classList.contains('big')) {
      svg.classList.toggle('focusing', on);
      w.classList.toggle('hot', on);
      return;
    }
    liftLayers();
    if (!on) { veil.style.display = 'none'; lift.style.display = 'none'; while (lift.firstChild) lift.removeChild(lift.firstChild); return; }
    var r = svg.getBoundingClientRect(), box = 'left:' + r.left + 'px;top:' + r.top + 'px;width:' + r.width + 'px;height:' + r.height + 'px;';
    veil.style.cssText = box + 'display:block';
    lift.style.cssText = box + 'display:block;transform:' + (svg.style.transform || 'none') + ';transform-origin:0 0';
    lift.setAttribute('viewBox', svg.getAttribute('viewBox'));
    lift.setAttribute('preserveAspectRatio', svg.getAttribute('preserveAspectRatio') || 'xMidYMid meet');
    while (lift.firstChild) lift.removeChild(lift.firstChild);
    lift.appendChild(w.cloneNode(true));
  }
  var ttWord = null, ttW = 0, ttH = 0;
  function placeCard(x, y) {
    var left = x + 16, top = y + 16;
    if (left + ttW > window.innerWidth - 8) left = x - ttW - 16;
    if (top + ttH > window.innerHeight - 8) top = y - ttH - 16;
    tt.style.left = left + 'px';
    tt.style.top = top + 'px';
  }
  function showCard(w, x, y) {
    if (!tt) return;
    if (w === ttWord && tt.style.display === 'block') { placeCard(x, y); return; }
    ttWord = w;
    var p = pane(), c = +w.getAttribute('data-count');
    var share = p._total > 0 ? (100 * c / p._total) : 0;
    tt.innerHTML = '';
    tt.appendChild(make('div', { 'class': 'tw' }, w.getAttribute('data-word')));
    tt.appendChild(make('div', null, 'Count ' + fullCount(c) + '  \u00b7  rank ' + w.getAttribute('data-rank') + ' of ' + p._words.length));
    tt.appendChild(make('div', null, (share < 0.1 ? share.toFixed(2) : share.toFixed(1)) + '% of all word mentions shown'));
    var note = w.getAttribute('data-note');
    if (note) tt.appendChild(make('div', { 'class': 'tn' }, note));
    if (cfg.toolbar) tt.appendChild(make('div', { 'class': 'th' }, 'Click to hide'));
    tt.style.display = 'block';
    var r = tt.getBoundingClientRect();
    ttW = r.width; ttH = r.height;
    placeCard(x, y);
  }
  function hideCard() { if (tt) tt.style.display = 'none'; ttWord = null; }
  var hot = null;
  doc.addEventListener('mousemove', function (ev) {
    var zp = pane();
    var t = (drag || (zp && zp._cvb)) ? null : wordOf(ev.target);
    var isWord = !!t;
    if (isWord) {
      if (hot !== t) { if (hot) focusWord(hot, false); hot = t; focusWord(t, true); }
      showCard(t, ev.clientX, ev.clientY);
    } else {
      if (hot) { focusWord(hot, false); hot = null; }
      hideCard();
    }
  });

  // ── fit the cloud into the space left by the header and panel ─────────────
  function fit() {
    var p = pane(), svg = p._svg;
    if (cfg.fixed || !stage) { svg.style.width = ''; svg.style.height = ''; return; }
    var lab = p.querySelector('.plabel');
    var labH = (lab && lab.offsetParent !== null) ? lab.offsetHeight + 12 : 0;
    var lg = p.querySelector('.legend');
    var lgH = (lg && lg.offsetParent !== null) ? lg.offsetHeight + 10 : 0;
    var availW = stage.clientWidth - 24, availH = stage.clientHeight - 24 - labH - lgH;
    if (availW <= 0 || availH <= 0) return;
    // the cloud's box fills the whole area, so a zoomed cloud can use all of it;
    // the home view shows the whole cloud, centred, with the area's proportions
    var bw = Math.floor(availW), bh = Math.floor(availH);
    svg.style.width = bw + 'px';
    svg.style.height = bh + 'px';
    var A = bw / bh;
    if (A > p._W / p._H) { var vw = p._H * A; p._rv = [(p._W - vw) / 2, 0, vw, p._H]; }
    else { var vh = p._W / A; p._rv = [0, (p._H - vh) / 2, p._W, vh]; }
    p._vb = p._rv.slice();
    setVB(p);
  }
  window.addEventListener('resize', fit);
  // fixed: the cloud keeps its size and the page scrolls; the panel stays in view
  // with the height of the window below its top edge, and scrolls inside
  function sizePanel() {
    if (!cfg.fixed || !panelEl) return;
    var t = Math.max(0, panelEl.getBoundingClientRect().top);
    panelEl.style.height = Math.max(120, window.innerHeight - t) + 'px';
  }
  window.addEventListener('resize', sizePanel);
  window.addEventListener('scroll', sizePanel, { passive: true });
  window.addEventListener('load', sizePanel);
  doc.addEventListener('fullscreenchange', function () { setTimeout(fit, 50); });

  // ── load animation: words fade in, largest first ──────────────────────────
  // Runs on first paint and every time a group's tab is shown. Uses the Web
  // Animations API so it can be cancelled and restarted cleanly; 'backwards'
  // fill keeps each word hidden only until its turn, after which normal
  // styles (search dimming, hiding) apply again.
  function enter(p) {
    if (p._anims) p._anims.forEach(function (a) { try { a.cancel(); } catch (e) { /* ignore */ } });
    p._anims = [];
    if (reduceMotion || !p._words.length || typeof p._words[0].animate !== 'function') return;
    var vis = p._words.filter(function (w) { return w.style.display !== 'none'; });
    // large clouds fade in as one picture: animating hundreds of words one by one
    // makes the browser redraw them all on every frame
    if (vis.length > 300 && typeof p._svg.animate === 'function') {
      p._anims.push(p._svg.animate([{ opacity: 0 }, { opacity: 1 }], { duration: 600, easing: 'ease-out', fill: 'backwards' }));
      return;
    }
    var n = vis.length, step = Math.min(18, 900 / Math.max(n, 1));
    vis.forEach(function (w, i) {
      p._anims.push(w.animate([{ opacity: 0 }, { opacity: 1 }],
        { duration: 550, delay: Math.round(i * step), easing: 'ease-out', fill: 'backwards' }));
    });
  }

  // ── show / hide / dim words, and refresh the panel ────────────────────────
  function visible(w, p) {
    return w.getAttribute('data-hidden') !== '1' && (+w.getAttribute('data-count')) >= p._thr &&
      !(p._offCats && p._offCats[w.getAttribute('data-cat')]);
  }
  function apply() {
    var p = pane(), q = state.query.toLowerCase();
    var shown = 0, hits = 0, hidden = 0;
    p._words.forEach(function (w) {
      if (w.getAttribute('data-hidden') === '1') hidden++;
      var vis = visible(w, p);
      w.style.display = vis ? '' : 'none';
      var hit = q !== '' && w.getAttribute('data-word').toLowerCase().indexOf(q) >= 0;
      w.style.opacity = (vis && q !== '' && !hit) ? '0.12' : '';
      if (vis) { shown++; if (hit) hits++; }
    });
    if (ui.hits) ui.hits.textContent = q === '' ? '' : hits + (hits === 1 ? ' match' : ' matches');
    sliders.forEach(function (s) { if (+s.value !== p._thr) s.value = p._thr; });
    if (ui.thrLabel) ui.thrLabel.textContent = '\u2265 ' + p._thr;
    if (ui.railThr) ui.railThr.textContent = '\u2265' + p._thr;
    if (ui.unhide) {
      ui.unhide.textContent = hidden ? 'Show hidden words (' + hidden + ')' : 'No hidden words';
      ui.unhide.disabled = hidden === 0;
    }
    if (ui.railEye) {
      ui.railEye.disabled = hidden === 0;
      ui.railEye.setAttribute('data-badge', hidden ? String(hidden) : '');
    }
    if (countEl) countEl.textContent = shown === p._words.length ? shown + ' words' : shown + ' of ' + p._words.length + ' words shown';
    renderList();
  }

  // ── top words list ────────────────────────────────────────────────────────
  // counts for the list: large ones short (18.8M), full value in the tooltip
  function shortCount(c) {
    var a = Math.abs(c);
    var f = function (v, u) { return (Math.round(v * 10) / 10).toString() + u; };
    if (a >= 1e9) return f(c / 1e9, 'B');
    if (a >= 1e6) return f(c / 1e6, 'M');
    if (a >= 1e4) return f(c / 1e3, 'k');
    return String(c);
  }
  function fullCount(c) { return Math.abs(c) >= 1000 ? c.toLocaleString('en-US') : String(c); }
  function renderList() {
    if (!ui.list) return;
    var p = pane(), q = state.query.toLowerCase();
    var rows = p._words.filter(function (w) {
      return q === '' || w.getAttribute('data-word').toLowerCase().indexOf(q) >= 0;
    });
    var limit = state.listAll ? rows.length : Math.min(rows.length, 15);
    ui.list.innerHTML = '';
    for (var i = 0; i < limit; i++) {
      (function (w) {
        var c = +w.getAttribute('data-count');
        var row = make('li', { 'class': 'row', title: 'Click to ' + (w.getAttribute('data-hidden') === '1' ? 'show' : 'hide') + ' this word' });
        if (!visible(w, p)) row.classList.add('off');
        row.appendChild(make('span', { 'class': 'rk' }, w.getAttribute('data-rank')));
        row.appendChild(make('span', { 'class': 'nm' }, w.getAttribute('data-word')));
        var barWrap = make('span', { 'class': 'bw' });
        var bar = make('span', { 'class': 'bar' });
        bar.style.width = Math.max(3, Math.round(100 * c / p._max)) + '%';
        bar.style.background = w.getAttribute('fill');
        barWrap.appendChild(bar);
        row.appendChild(barWrap);
        row.appendChild(make('span', { 'class': 'ct', title: fullCount(c) }, shortCount(c)));
        row.addEventListener('mouseenter', function () { if (visible(w, p)) focusWord(w, true); });
        row.addEventListener('mouseleave', function () { focusWord(w, false); });
        row.addEventListener('click', function () {
          focusWord(w, false);
          if (w.getAttribute('data-hidden') === '1') w.removeAttribute('data-hidden');
          else w.setAttribute('data-hidden', '1');
          apply();
        });
        ui.list.appendChild(row);
      })(rows[i]);
    }
    if (ui.more) {
      ui.more.style.display = rows.length > 15 ? '' : 'none';
      ui.more.textContent = state.listAll ? 'Show top 15' : 'Show all ' + rows.length;
    }
  }

  // ── zoom and pan (by changing the SVG viewBox) ────────────────────────────
  function isZoomed(p) { return p._vb[2] < p._rv[2] - 0.5; }
  function commitVB(p) {
    if (p._ct) { clearTimeout(p._ct); p._ct = null; }
    p._svg.setAttribute('viewBox', p._vb.map(function (v) { return Math.round(v * 100) / 100; }).join(' '));
    if (p._cvb) { p._svg.style.transform = p._big ? 'translate(0px,0px) scale(1)' : ''; if (!p._big) p._svg.style.willChange = ''; p._cvb = null; }
  }
  function setVB(p, fast) {
    p._svg.classList.toggle('zoomed', isZoomed(p));
    // fast: only for large clouds, in the window-fitting layout (whose area clips)
    if (!fast || !p._big || !document.body.classList.contains('wc-fit')) { commitVB(p); return; }
    if (!p._cvb) {
      var a = (p._svg.getAttribute('viewBox') || '').split(/[\s,]+/).map(Number);
      p._cvb = a.length === 4 && a.every(isFinite) ? a : p._vb.slice();
      var r = p._svg.getBoundingClientRect();
      p._base = { left: r.left, top: r.top, width: r.width, height: r.height };
      p._svg.style.transformOrigin = '0 0';
      p._svg.style.willChange = 'transform';
    }
    var C = p._cvb, V = p._vb, s = C[2] / V[2];
    var tx = (C[0] - V[0]) / V[2] * p._base.width, ty = (C[1] - V[1]) / V[3] * p._base.height;
    p._svg.style.transform = 'translate(' + tx + 'px,' + ty + 'px) scale(' + s + ')';
    if (p._ct) clearTimeout(p._ct);
    p._ct = setTimeout(function () { commitVB(p); }, 300);
  }
  // keep the cloud in view: along a direction where the view is wider than the
  // cloud, the cloud stays centred; otherwise the view stays inside the cloud
  function clampVB(p, x, y, w, h, fast) {
    x = w >= p._W ? (p._W - w) / 2 : Math.min(Math.max(0, x), p._W - w);
    y = h >= p._H ? (p._H - h) / 2 : Math.min(Math.max(0, y), p._H - h);
    p._vb = [x, y, w, h];
    setVB(p, fast);
  }
  function zoomAt(p, cx, cy, k, fast) {
    var v = p._vb, r = p._rv;
    var w = Math.min(r[2], Math.max(r[2] / 10, v[2] * k)), h = w * r[3] / r[2];
    clampVB(p, cx - (cx - v[0]) * (w / v[2]), cy - (cy - v[1]) * (h / v[3]), w, h, fast);
  }
  function zoomCentre(k) { var p = pane(), v = p._vb; zoomAt(p, v[0] + v[2] / 2, v[1] + v[3] / 2, k); }
  function zoomReset() { var p = pane(); p._vb = p._rv.slice(); setVB(p); }
  function svgPoint(p, ev) {
    // the picture on screen shows the drawn view (p._cvb while moving fast)
    var r = p._svg.getBoundingClientRect(), v = p._cvb || p._vb;
    return [v[0] + (ev.clientX - r.left) / r.width * v[2], v[1] + (ev.clientY - r.top) / r.height * v[3]];
  }
  function setupPointer(p) {
    var svg = p._svg;
    if (!cfg.toolbar) return;
    svg.addEventListener('wheel', function (ev) {
      ev.preventDefault();
      var pt = svgPoint(p, ev);
      zoomAt(p, pt[0], pt[1], ev.deltaY < 0 ? 1 / 1.2 : 1.2, true);
    }, { passive: false });
    svg.addEventListener('pointerdown', function (ev) {
      drag = { x: ev.clientX, y: ev.clientY, vb: p._vb.slice(), moved: false, target: wordOf(ev.target) };
      if (svg.setPointerCapture && ev.pointerId != null) { try { svg.setPointerCapture(ev.pointerId); } catch (e) { /* ignore */ } }
    });
    svg.addEventListener('pointermove', function (ev) {
      if (!drag) return;
      var dx = ev.clientX - drag.x, dy = ev.clientY - drag.y;
      if (Math.abs(dx) + Math.abs(dy) > 4) drag.moved = true;
      if (drag.moved && isZoomed(p)) {
        var r = p._cvb ? p._base : svg.getBoundingClientRect();
        clampVB(p, drag.vb[0] - dx / r.width * drag.vb[2], drag.vb[1] - dy / r.height * drag.vb[3], drag.vb[2], drag.vb[3], true);
        svg.classList.add('dragging');
      }
    });
    svg.addEventListener('pointerup', function () {
      // a click (no drag) on a word hides it
      if (drag && !drag.moved && drag.target) {
        focusWord(drag.target, false);
        drag.target.setAttribute('data-hidden', '1');
        hideCard();
        apply();
      }
      drag = null;
      svg.classList.remove('dragging');
      if (p._cvb) commitVB(p);
    });
  }

  // ── theme and palette ─────────────────────────────────────────────────────
  function setTheme(t) {
    state.theme = t;
    var th = THEMES[t];
    body.style.setProperty('--bg', th.bg);
    body.style.setProperty('--ink', th.ink);
    body.classList.toggle('light', isLight(th.bg));
    panes.forEach(function (p) {
      var r = p._svg.querySelector('rect.bg');
      if (r) r.setAttribute('fill', th.bg);
      var o = p._svg.querySelector('path.outline');
      if (o && o.getAttribute('data-default') === '1') o.setAttribute('stroke', th.ink);
    });
    if (ui.themeBtn) ui.themeBtn.textContent = isLight(th.bg) ? 'Dark background' : 'Light background';
    if (state.palette === 'greys') setPalette('greys');
  }
  function paletteColor(id, i, n) {
    var pal = PALETTES.filter(function (q) { return q.id === id; })[0];
    if (pal.cycle) return pal.colors[i % pal.colors.length];
    var stops = id === 'greys' ? (isLight(THEMES[state.theme].bg) ? ['#111111', '#8a8a8a'] : ['#f5f5f5', '#8a8a8a']) : pal.colors;
    return interp(stops, n > 1 ? i / (n - 1) : 0);
  }
  function setPalette(id) {
    state.palette = id;
    panes.forEach(function (p) {
      var n = p._words.length;
      p._words.forEach(function (w, i) {
        w.setAttribute('fill', id === 'orig' ? w.getAttribute('data-fill0') : paletteColor(id, i, n));
      });
    });
    if (ui.swatches) ui.swatches.forEach(function (b) { b.classList.toggle('on', b.getAttribute('data-id') === id); });
    renderList();
  }
  function cyclePalette() {
    if (cfg.fixedcolors) return;          // the colours carry meaning (colorby() etc.)
    var k = 0;
    PALETTES.forEach(function (q, i) { if (q.id === state.palette) k = i; });
    var next = PALETTES[(k + 1) % PALETTES.length];
    setPalette(next.id);
    if (ui.railPal) ui.railPal.title = 'Colours: ' + next.name + ' (click for next)';
  }

  // ── tabs ──────────────────────────────────────────────────────────────────
  function show(k, animate) {
    state.active = k;
    panes.forEach(function (p, i) { p.style.display = i === k ? '' : 'none'; });
    if (ui.tabs) ui.tabs.forEach(function (b, i) { b.classList.toggle('on', i === k); b.setAttribute('aria-selected', i === k ? 'true' : 'false'); });
    var p = pane();
    sliders.forEach(function (s) { s.max = p._max; s.disabled = p._max <= 1; });
    apply();
    fit();
    if (animate) enter(p);
  }

  // ── fullscreen ────────────────────────────────────────────────────────────
  function toggleFullscreen() {
    var el = doc.documentElement;
    if (!doc.fullscreenElement) { if (el.requestFullscreen) el.requestFullscreen(); }
    else if (doc.exitFullscreen) doc.exitFullscreen();
  }

  // ── export what is shown ──────────────────────────────────────────────────
  function stem() {
    var s = cfg.stem || 'wordcloud';
    if (panes.length > 1) s += '_' + (pane().getAttribute('data-file') || (state.active + 1));
    return s;
  }
  // what is saved: the whole cloud at home zoom, else what is shown
  function saveView(p) {
    var vb = isZoomed(p) ? p._vb : [0, 0, p._W, p._H];
    return { vb: vb, w: p._W, h: Math.round(p._W * vb[3] / vb[2]) };
  }
  function serialize() {
    var p = pane(), c = p._svg.cloneNode(true), sv = saveView(p);
    c.removeAttribute('style');
    c.removeAttribute('class');
    c.setAttribute('viewBox', sv.vb.join(' '));
    c.setAttribute('width', sv.w);
    c.setAttribute('height', sv.h);
    c.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
    Array.prototype.forEach.call(c.querySelectorAll('.w'), function (w) {
      w.removeAttribute('class');
      w.style.animationDelay = '';
    });
    return new XMLSerializer().serializeToString(c);
  }
  function download(href, name) {
    var a = make('a', { href: href, download: name });
    body.appendChild(a);
    a.click();
    body.removeChild(a);
  }
  function save(fmt) {
    var xml = serialize(), name = stem() + '.' + fmt;
    if (fmt === 'svg') {
      var url = URL.createObjectURL(new Blob([xml], { type: 'image/svg+xml' }));
      download(url, name);
      setTimeout(function () { URL.revokeObjectURL(url); }, 1000);
      return;
    }
    var p = pane(), sv = saveView(p), W = sv.w, H = sv.h;
    var bytes = new TextEncoder().encode(xml), bin = '';
    for (var i = 0; i < bytes.length; i += 8192) bin += String.fromCharCode.apply(null, bytes.subarray(i, i + 8192));
    var canvas = make('canvas');
    canvas.width = 2 * W;
    canvas.height = 2 * H;
    var ctx = canvas.getContext('2d');
    ctx.fillStyle = THEMES[state.theme].bg;
    ctx.fillRect(0, 0, 2 * W, 2 * H);
    var img = new Image();
    img.onload = function () {
      ctx.drawImage(img, 0, 0, 2 * W, 2 * H);
      download(canvas.toDataURL(fmt === 'jpg' ? 'image/jpeg' : 'image/png', 0.95), name);
    };
    img.onerror = function (e) { console.error('calligram: image export failed', e); };
    img.src = 'data:image/svg+xml;base64,' + btoa(bin);
  }
  window.wcSave = save;

  // ── panel open / closed ───────────────────────────────────────────────────
  function setPanel(open) {
    if (!panelEl) return;
    panelEl.classList.toggle('open', open);
    panelEl.classList.toggle('rail', !open);
    fit();
    setTimeout(fit, 260);
  }
  function openSearch() {
    setPanel(true);
    if (ui.search) { ui.search.focus(); ui.search.select(); }
  }
  function unhideAll() {
    pane()._words.forEach(function (w) { w.removeAttribute('data-hidden'); });
    apply();
  }
  function setThreshold(v) { pane()._thr = +v; apply(); }

  // ── keyboard shortcuts ────────────────────────────────────────────────────
  var KEYS = [
    ['/', 'Search'], ['Esc', 'Clear search / close'], ['+  \u2212', 'Zoom in / out'], ['0', 'Reset zoom'],
    ['F', 'Fullscreen'], ['P', 'Open / collapse panel'], ['T', 'Light / dark background'],
    ['C', 'Next colour palette'], ['H', 'Show hidden words'], ['\u2190  \u2192', 'Previous / next group'], ['?', 'This list']
  ];
  function toggleHelp(force) {
    if (!ui.help) return;
    var on = force != null ? force : ui.help.style.display === 'none';
    ui.help.style.display = on ? 'flex' : 'none';
  }
  if (cfg.toolbar) {
    doc.addEventListener('keydown', function (ev) {
      if (ev.ctrlKey || ev.metaKey || ev.altKey) return;
      if (typing(ev)) {
        if (ev.key === 'Escape') { ev.target.value = ''; state.query = ''; ev.target.blur(); apply(); }
        return;
      }
      var k = ev.key;
      if (k === '/') { ev.preventDefault(); openSearch(); }
      else if (k === 'Escape') { toggleHelp(false); if (state.query) { state.query = ''; if (ui.search) ui.search.value = ''; apply(); } }
      else if (k === '+' || k === '=') zoomCentre(0.8);
      else if (k === '-' || k === '_') zoomCentre(1.25);
      else if (k === '0') zoomReset();
      else if (k === 'f' || k === 'F') toggleFullscreen();
      else if (k === 'p' || k === 'P') setPanel(!panelEl.classList.contains('open'));
      else if (k === 't' || k === 'T') setTheme(state.theme === 'orig' ? 'alt' : 'orig');
      else if (k === 'c' || k === 'C') cyclePalette();
      else if (k === 'h' || k === 'H') unhideAll();
      else if (k === '?') toggleHelp();
      else if (k === 'ArrowRight' && panes.length > 1) show((state.active + 1) % panes.length, true);
      else if (k === 'ArrowLeft' && panes.length > 1) show((state.active + panes.length - 1) % panes.length, true);
    });
  }

  // ── build the panel ───────────────────────────────────────────────────────
  function section(title) {
    var s = make('section', { 'class': 'sec' });
    if (title) s.appendChild(make('h2', null, title));
    return s;
  }
  function slider(vertical) {
    var s = make('input', { type: 'range', min: '1', max: '1', step: '1', value: '1', 'aria-label': 'Minimum count' });
    if (vertical) { s.setAttribute('orient', 'vertical'); s.className = 'vrange'; }
    s.addEventListener('input', function () { setThreshold(s.value); });
    sliders.push(s);
    return s;
  }
  if (cfg.toolbar && panelEl) {
    // the rail (collapsed state): icons and a vertical slider
    var rail = make('div', { 'class': 'railbox' });
    ui.toggle = iconButton('left', 'Expand panel (P)', function () { setPanel(true); });
    rail.appendChild(ui.toggle);
    rail.appendChild(iconButton('search', 'Search words (/)', openSearch));
    var vs = make('div', { 'class': 'vsl', title: 'Minimum count' });
    vs.appendChild(slider(true));
    ui.railThr = make('span', { 'class': 'vlab' });
    vs.appendChild(ui.railThr);
    rail.appendChild(vs);
    ui.railEye = iconButton('eye', 'Show hidden words (H)', unhideAll);
    ui.railEye.classList.add('badge');
    rail.appendChild(ui.railEye);
    rail.appendChild(iconButton('theme', 'Light / dark background (T)', function () { setTheme(state.theme === 'orig' ? 'alt' : 'orig'); }));
    if (!cfg.fixedcolors) {
      ui.railPal = iconButton('palette', 'Colours: As drawn (click for next)', cyclePalette);
      rail.appendChild(ui.railPal);
    }
    rail.appendChild(make('div', { 'class': 'sep' }));
    rail.appendChild(iconButton('plus', 'Zoom in (+)', function () { zoomCentre(0.8); }));
    rail.appendChild(iconButton('minus', 'Zoom out (\u2212)', function () { zoomCentre(1.25); }));
    rail.appendChild(iconButton('reset', 'Reset zoom (0)', zoomReset));
    rail.appendChild(iconButton('full', 'Fullscreen (F)', toggleFullscreen));
    rail.appendChild(make('div', { 'class': 'sep' }));
    rail.appendChild(iconButton('save', 'Save as PNG', function () { save('png'); }));
    rail.appendChild(iconButton('help', 'Keyboard shortcuts (?)', function () { toggleHelp(); }));

    // the open panel: labelled sections
    var full = make('div', { 'class': 'fullbox' });
    var head = make('div', { 'class': 'phead' });
    head.appendChild(make('span', { 'class': 'ptitle' }, 'Explore'));
    head.appendChild(iconButton('right', 'Collapse panel (P)', function () { setPanel(false); }));
    full.appendChild(head);

    var s1 = section(null);
    var sw = make('div', { 'class': 'searchwrap' });
    var si = make('span', { 'class': 'sicon' });
    si.innerHTML = svgIcon('search');
    sw.appendChild(si);
    ui.search = make('input', { type: 'search', placeholder: 'Search words', 'aria-label': 'Search words' });
    ui.search.addEventListener('input', function () { state.query = ui.search.value.trim(); apply(); });
    sw.appendChild(ui.search);
    s1.appendChild(sw);
    ui.hits = make('div', { 'class': 'note' });
    s1.appendChild(ui.hits);
    full.appendChild(s1);

    var s2 = section('Minimum count');
    var sr = make('div', { 'class': 'hrow' });
    sr.appendChild(slider(false));
    ui.thrLabel = make('span', { 'class': 'note' });
    sr.appendChild(ui.thrLabel);
    s2.appendChild(sr);
    full.appendChild(s2);

    var s3 = section('Top words');
    ui.list = make('ol', { 'class': 'list' });
    s3.appendChild(ui.list);
    ui.more = make('button', { type: 'button', 'class': 'linkbtn' }, 'Show all');
    ui.more.addEventListener('click', function () { state.listAll = !state.listAll; renderList(); });
    s3.appendChild(ui.more);
    ui.unhide = make('button', { type: 'button', 'class': 'linkbtn' }, 'No hidden words');
    ui.unhide.addEventListener('click', unhideAll);
    s3.appendChild(ui.unhide);
    s3.appendChild(make('div', { 'class': 'hint' }, 'Click a word in the cloud or in this list to hide it.'));
    full.appendChild(s3);

    var s4 = section('View');
    var vr = make('div', { 'class': 'brow' });
    vr.appendChild(iconButton('minus', 'Zoom out (\u2212)', function () { zoomCentre(1.25); }));
    vr.appendChild(iconButton('plus', 'Zoom in (+)', function () { zoomCentre(0.8); }));
    vr.appendChild(iconButton('reset', 'Reset zoom (0)', zoomReset));
    vr.appendChild(iconButton('full', 'Fullscreen (F)', toggleFullscreen));
    s4.appendChild(vr);
    s4.appendChild(make('div', { 'class': 'hint' }, 'Scroll to zoom, drag to move around.'));
    full.appendChild(s4);

    var s5 = section('Appearance');
    ui.themeBtn = make('button', { type: 'button', 'class': 'btn' }, '');
    ui.themeBtn.addEventListener('click', function () { setTheme(state.theme === 'orig' ? 'alt' : 'orig'); });
    s5.appendChild(ui.themeBtn);
    var sg = make('div', { 'class': 'swatches' });
    ui.swatches = PALETTES.map(function (q) {
      var b = make('button', { type: 'button', 'class': 'swatch', 'data-id': q.id, title: q.name, 'aria-label': 'Colours: ' + q.name });
      var cols = q.id === 'orig' ? panes[0]._words.slice(0, 4).map(function (w) { return w.getAttribute('data-fill0'); })
        : q.id === 'greys' ? ['#f5f5f5', '#bdbdbd', '#8a8a8a'] : q.colors.slice(0, 4);
      b.style.background = 'linear-gradient(90deg,' + cols.join(',') + ')';
      b.addEventListener('click', function () { setPalette(q.id); });
      sg.appendChild(b);
      return b;
    });
    if (!cfg.fixedcolors) s5.appendChild(sg);
    else s5.appendChild(make('div', { 'class': 'hint' }, 'Colours show a variable (see the key under the cloud).'));
    full.appendChild(s5);

    var s6 = section('Save image');
    var br = make('div', { 'class': 'brow' });
    ['png', 'svg', 'jpg'].forEach(function (f) {
      var b = make('button', { type: 'button', 'class': 'btn', title: 'Save what is shown as ' + f.toUpperCase() }, f.toUpperCase());
      b.addEventListener('click', function () { save(f); });
      br.appendChild(b);
    });
    s6.appendChild(br);
    full.appendChild(s6);

    var foot = make('div', { 'class': 'pfoot' });
    var hb = make('button', { type: 'button', 'class': 'linkbtn' }, 'Keyboard shortcuts  ?');
    hb.addEventListener('click', function () { toggleHelp(); });
    foot.appendChild(hb);
    foot.appendChild(make('span', { 'class': 'credit' }, 'calligram for Stata'));
    full.appendChild(foot);

    panelEl.appendChild(rail);
    panelEl.appendChild(full);

    // shortcuts list
    ui.help = make('div', { 'class': 'help', role: 'dialog', 'aria-label': 'Keyboard shortcuts' });
    ui.help.style.display = 'none';
    var card = make('div', { 'class': 'helpcard' });
    card.appendChild(make('h2', null, 'Keyboard shortcuts'));
    var tbl = make('table');
    KEYS.forEach(function (k) {
      var tr = make('tr');
      var td1 = make('td');
      td1.appendChild(make('kbd', null, k[0]));
      tr.appendChild(td1);
      tr.appendChild(make('td', null, k[1]));
      tbl.appendChild(tr);
    });
    card.appendChild(tbl);
    var close = make('button', { type: 'button', 'class': 'btn' }, 'Close');
    close.addEventListener('click', function () { toggleHelp(false); });
    card.appendChild(close);
    ui.help.appendChild(card);
    ui.help.addEventListener('click', function (ev) { if (ev.target === ui.help) toggleHelp(false); });
    body.appendChild(ui.help);
  }

  // A single save button (export() option without the panel)
  var legacy = doc.getElementById('expbtn');
  if (legacy) legacy.addEventListener('click', function () { save(legacy.getAttribute('data-fmt') || 'png'); });

  // ── tabs for by() groups ──────────────────────────────────────────────────
  if (panes.length > 1 && tabsEl) {
    tabsEl.setAttribute('role', 'tablist');
    ui.tabs = panes.map(function (p, k) {
      var b = make('button', { type: 'button', role: 'tab' }, p.getAttribute('data-label') || ('Group ' + (k + 1)));
      b.addEventListener('click', function () { if (k !== state.active) show(k, true); });
      tabsEl.appendChild(b);
      return b;
    });
    body.classList.add('has-tabs');
  }

  body.classList.add('wc-ui');
  if (!cfg.fixed) body.classList.add('wc-fit');   // lock the page to the window only when fitting
  setTheme('orig');
  setPalette('orig');
  if (panelEl && cfg.toolbar) setPanel(window.innerWidth >= 1100);
  show(0, false);

  // Start the fade-in once the page has loaded and is being drawn, so it is
  // never over before it is seen. The head of the page hides the words until
  // then (class wc-pre on <html>).
  function reveal() {
    var raf = window.requestAnimationFrame || function (f) { return setTimeout(f, 16); };
    raf(function () {
      fit();
      enter(pane());
      doc.documentElement.classList.remove('wc-pre');
    });
  }
  if (doc.readyState === 'complete') reveal();
  else window.addEventListener('load', reveal);
})();
