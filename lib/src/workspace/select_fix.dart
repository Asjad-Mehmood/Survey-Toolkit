// Drop-down lists inside the Toolkit's web view.
//
// webview_windows draws the page off-screen (it captures the WebView2 visual), so the native
// pop-up of a <select> is a separate window that is never captured: the list doesn't open, and
// a choice such as Excel to KML's "Coordinates in my sheet are" can't be made. This script is
// added to every page the Toolkit shows. It opens an in-page list instead of the native pop-up;
// picking an item sets the <select> and sends the same input and change events a real choice
// does, so the page works exactly as in a browser. Touch and pen taps are handled from pointer
// events, not from the mouse events WebView2 makes out of them. Lists with `multiple` or a size
// above 1 are drawn in the page already and are left alone. The website carries the same code in
// public/toolkit-selects.js; whichever copy is newer handles the lists.

/// Added with addScriptToExecuteOnDocumentCreated before the first page loads
const selectFixScript = r'''
(() => {
  // Version 2 handles touch and pen itself. Version 1 (Survey Toolkit 1.0.x) opened the list from
  // the mouse events WebView2 makes out of a tap, and in the Toolkit a tap on an item didn't pick
  // it. A newer copy takes over from an older one: its listeners sit on the window, which comes
  // before the older copy's listeners on the document, and stop the events they handle.
  const VERSION = 2;
  if ((window.__toolkitSelectFixVersion || 0) >= VERSION) return;
  window.__toolkitSelectFixVersion = VERSION;
  window.__toolkitSelectFix = true;

  let open = null; // { select, host, list, items, active }
  let press = null; // a touch or pen press on a closed <select>: { id, select, x, y }
  let tappedAt = 0; // when a touch or pen tap last opened or closed a list

  const SLOP = 12; // a press that moves further than this is a scroll, not a tap
  const isSingle = (s) => s instanceof HTMLSelectElement && !s.multiple && s.size <= 1 && !s.disabled;
  const moved = (p, e) => Math.abs(e.clientX - p.x) > SLOP || Math.abs(e.clientY - p.y) > SLOP;
  const fromTouch = (e) => !!(e.sourceCapabilities && e.sourceCapabilities.firesTouchEvents);
  // no tap, click or mouse events made from this touch: the list has handled it
  const eatTouchEnd = (e) => { if (e.cancelable) e.preventDefault(); };

  function close(refocus) {
    if (!open) return;
    const { select, host } = open;
    open = null;
    host.remove();
    window.removeEventListener('resize', onWindowChange, true);
    window.removeEventListener('scroll', onScroll, true);
    if (refocus) select.focus({ preventScroll: true });
  }

  function choose(select, index) {
    if (index !== select.selectedIndex) {
      select.selectedIndex = index;
      select.dispatchEvent(new Event('input', { bubbles: true }));
      select.dispatchEvent(new Event('change', { bubbles: true }));
    }
    close(true);
  }

  function toggle(select) {
    select.focus({ preventScroll: true });
    if (open && open.select === select) close(true); else show(select);
  }

  function setActive(i) {
    if (!open) return;
    const { items } = open;
    if (!items.length) return;
    const n = Math.max(0, Math.min(items.length - 1, i));
    items.forEach((it, k) => it.el.classList.toggle('active', k === n));
    open.active = n;
    items[n].el.scrollIntoView({ block: 'nearest' });
  }

  function onWindowChange() { close(false); }
  function onScroll(e) {
    if (open && !open.host.contains(e.target) && e.target !== open.host) close(false);
  }

  function show(select) {
    close(false);
    const host = document.createElement('div');
    host.setAttribute('data-toolkit-select', '');
    host.style.cssText = 'position:fixed;inset:0;z-index:2147483647;';
    const root = host.attachShadow({ mode: 'open' });
    const cs = getComputedStyle(select);
    const dark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches &&
      !/light/.test(cs.colorScheme || '');
    root.innerHTML = `<style>
      .list{position:fixed;box-sizing:border-box;overflow-y:auto;margin:0;padding:4px;
        font:${cs.fontSize}/1.35 ${cs.fontFamily};border-radius:8px;
        background:${dark ? '#1f2329' : '#fff'};color:${dark ? '#e8eaed' : '#111827'};
        border:1px solid ${dark ? '#3c4043' : '#d1d5db'};box-shadow:0 10px 30px rgba(0,0,0,.22);outline:none;
        touch-action:pan-y;-webkit-user-select:none;user-select:none}
      .item{padding:6px 10px;border-radius:5px;cursor:default;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
      .item.sel{font-weight:600}
      .item.active{background:${dark ? '#2f6feb' : '#2563eb'};color:#fff}
      .item.off{opacity:.45}
      .group{padding:6px 10px 2px;font-weight:700;font-size:.85em;opacity:.7}
      .group ~ .item.in{padding-left:20px}
    </style><div class="list" role="listbox" tabindex="-1"></div>`;
    const list = root.querySelector('.list');
    const items = [];
    let group = null;
    let itemPress = null; // a touch or pen press on an item: { id, k, x, y }
    Array.from(select.options).forEach((o, index) => {
      const g = o.parentElement instanceof HTMLOptGroupElement ? o.parentElement : null;
      if (g && g !== group) {
        const h = document.createElement('div');
        h.className = 'group';
        h.textContent = g.label;
        list.appendChild(h);
      }
      group = g;
      if (o.hidden) return;
      const el = document.createElement('div');
      el.className = 'item' + (g ? ' in' : '') + (o.selected ? ' sel' : '') + (o.disabled || (g && g.disabled) ? ' off' : '');
      el.setAttribute('role', 'option');
      el.setAttribute('aria-selected', o.selected ? 'true' : 'false');
      el.textContent = o.label || o.text;
      const usable = !(o.disabled || (g && g.disabled));
      if (usable) {
        const k = items.length;
        items.push({ el, index });
        el.addEventListener('mousemove', () => { if (open && open.active !== k) setActive(k); });
        el.addEventListener('click', (e) => { e.preventDefault(); if (open && open.host === host) choose(select, index); });
        // touch and pen pick on lifting, so a drag still scrolls a long list
        el.addEventListener('pointerdown', (e) => {
          if (e.pointerType === 'mouse') return;
          itemPress = { id: e.pointerId, k, x: e.clientX, y: e.clientY };
          setActive(k);
        });
        el.addEventListener('pointerup', (e) => {
          const p = itemPress;
          itemPress = null;
          if (!p || p.id !== e.pointerId || p.k !== k || moved(p, e)) return;
          tappedAt = Date.now();
          if (open && open.host === host) choose(select, index);
        });
      }
      list.appendChild(el);
    });
    list.addEventListener('pointercancel', () => { itemPress = null; });
    // a press outside the list closes it, and doesn't reach the page
    host.addEventListener('pointerdown', (e) => {
      if (e.pointerType === 'mouse' || e.composedPath()[0] !== host) return;
      e.preventDefault();
      tappedAt = Date.now();
      close(true);
    });
    host.addEventListener('mousedown', (e) => {
      if (e.composedPath()[0] !== host) return;
      e.preventDefault();
      if (!fromTouch(e)) close(true);
    });
    host.addEventListener('touchend', eatTouchEnd, { passive: false });
    host.addEventListener('wheel', (e) => { if (e.composedPath()[0] === host) close(false); }, { passive: true });
    list.addEventListener('keydown', (e) => keys(e, select));
    document.documentElement.appendChild(host);

    // under the list's box, or above it when there isn't room below
    const r = select.getBoundingClientRect();
    const vh = window.innerHeight, vw = window.innerWidth;
    const below = vh - r.bottom - 8, above = r.top - 8;
    const want = Math.min(list.scrollHeight + 2, 360);
    const up = below < Math.min(want, 160) && above > below;
    const h = Math.min(want, up ? above : below);
    list.style.maxHeight = Math.max(h, 80) + 'px';
    list.style.minWidth = r.width + 'px';
    list.style.maxWidth = Math.max(r.width, vw - 16) + 'px';
    list.style.left = Math.max(8, Math.min(r.left, vw - Math.max(r.width, list.offsetWidth) - 8)) + 'px';
    if (up) list.style.bottom = (vh - r.top + 2) + 'px'; else list.style.top = (r.bottom + 2) + 'px';

    open = { select, host, list, items, active: -1 };
    const cur = items.findIndex((it) => it.index === select.selectedIndex);
    setActive(cur < 0 ? 0 : cur);
    list.focus({ preventScroll: true });
    window.addEventListener('resize', onWindowChange, true);
    window.addEventListener('scroll', onScroll, true);
  }

  let typed = '', typedAt = 0;
  function keys(e, select) {
    if (!open) return;
    const k = e.key;
    if (k === 'ArrowDown') setActive(open.active + 1);
    else if (k === 'ArrowUp') setActive(open.active - 1);
    else if (k === 'Home' || k === 'PageUp') setActive(k === 'Home' ? 0 : open.active - 8);
    else if (k === 'End' || k === 'PageDown') setActive(k === 'End' ? open.items.length - 1 : open.active + 8);
    else if (k === 'Enter' || k === ' ') { if (open.items[open.active]) choose(select, open.items[open.active].index); }
    else if (k === 'Escape' || (k === 'ArrowUp' && e.altKey)) close(true);
    else if (k === 'Tab') { close(true); return; }
    else if (k.length === 1) {
      const now = Date.now();
      typed = (now - typedAt < 800 ? typed : '') + k.toLowerCase();
      typedAt = now;
      const hit = open.items.findIndex((it) => it.el.textContent.trim().toLowerCase().startsWith(typed));
      if (hit >= 0) setActive(hit);
    } else return;
    e.preventDefault();
    e.stopPropagation();
  }

  // Touch and pen: the list opens when the finger or pen lifts. Cancelling the press keeps the
  // pen's mouse events away, and cancelling the touch's end keeps away the tap WebView2 would make
  // from it (in the Toolkit that tap could also start the native pop-up, which grabs the input).
  window.addEventListener('pointerdown', (e) => {
    if (e.pointerType === 'mouse' || !e.isPrimary || !isSingle(e.target)) return;
    e.preventDefault();
    press = { id: e.pointerId, select: e.target, x: e.clientX, y: e.clientY };
  }, true);
  window.addEventListener('pointerup', (e) => {
    const p = press;
    if (!p || p.id !== e.pointerId) return;
    press = null;
    if (moved(p, e)) return;
    tappedAt = Date.now();
    toggle(p.select);
  }, true);
  window.addEventListener('pointercancel', (e) => { if (press && press.id === e.pointerId) press = null; }, true);
  window.addEventListener('touchend', (e) => { if (isSingle(e.target)) eatTouchEnd(e); }, { capture: true, passive: false });

  // the mouse: the native pop-up opens on mousedown
  window.addEventListener('mousedown', (e) => {
    const s = e.target;
    if (e.button !== 0 || !isSingle(s)) return;
    e.preventDefault();
    e.stopPropagation();
    // made from a touch or pen press that the pointer events above already handle
    if (fromTouch(e) || (press && press.select === s) || Date.now() - tappedAt < 800) return;
    toggle(s);
  }, true);
  // the keyboard: Alt+Down, F4, Space or Enter
  window.addEventListener('keydown', (e) => {
    const s = e.target;
    if (!isSingle(s) || (open && open.select === s)) return;
    if ((e.key === 'ArrowDown' && e.altKey) || e.key === 'F4' || e.key === ' ' || e.key === 'Enter') {
      e.preventDefault();
      e.stopPropagation();
      show(s);
    }
  }, true);
})();
''';
