/* A copy of the website's public/toolkit-selects.js for the Windows test (with a marker) */
/* Drop-down lists inside the Survey Toolkit (and any Windows program that shows these pages in an
   embedded WebView2 window).

   The Toolkit draws its web view off-screen, so the native pop-up of a <select> never shows: the
   list doesn't open, and a choice such as Excel to KML's coordinate system can't be made. The
   Toolkit adds its own fix to the pages it shows, but a page inside a frame (the Excel to KML web
   app at /api/app-html) can miss it. So the site carries the same fix itself: an in-page list in
   place of the native pop-up; picking an item sets the <select> and sends the same input and change
   events a real choice does. It switches itself on only inside WebView2 (window.chrome.webview, here
   or in the window around this frame) and does nothing in an ordinary browser. If the Toolkit's
   copy already runs in this page, this one leaves it to it. Same code as the Toolkit's
   lib/src/workspace/select_fix.dart. */
(() => {
  let embedded = false;
  try {
    const has = (w) => !!(w && w.chrome && w.chrome.webview);
    embedded = has(window) || has(window.parent) || has(window.top) || !!(window.top && window.top.__toolkitSelectFix);
  } catch (e) {
    embedded = false;
  }
  if (!embedded) return;
  window.__siteSelectFix = true;
  (() => {
    if (window.__toolkitSelectFix) return;
    window.__toolkitSelectFix = true;

    let open = null; // { select, host, list, items, active }

    const isSingle = (s) => s instanceof HTMLSelectElement && !s.multiple && s.size <= 1 && !s.disabled;

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
          border:1px solid ${dark ? '#3c4043' : '#d1d5db'};box-shadow:0 10px 30px rgba(0,0,0,.22);outline:none}
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
          el.addEventListener('click', (e) => { e.preventDefault(); choose(select, index); });
        }
        list.appendChild(el);
      });
      // a click outside the list closes it, and doesn't reach the page
      host.addEventListener('mousedown', (e) => { if (e.composedPath()[0] === host) { e.preventDefault(); close(true); } });
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

    // the native pop-up opens on mousedown, and from the keyboard with Alt+Down, F4, Space or Enter
    document.addEventListener('mousedown', (e) => {
      const s = e.target;
      if (e.button !== 0 || !isSingle(s)) return;
      e.preventDefault();
      s.focus({ preventScroll: true });
      if (open && open.select === s) close(true); else show(s);
    }, true);
    document.addEventListener('keydown', (e) => {
      const s = e.target;
      if (!isSingle(s) || (open && open.select === s)) return;
      if ((e.key === 'ArrowDown' && e.altKey) || e.key === 'F4' || e.key === ' ' || e.key === 'Enter') {
        e.preventDefault();
        show(s);
      }
    }, true);
  })();
})();
