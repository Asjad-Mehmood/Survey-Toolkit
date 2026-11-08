// Each test page reports here: what runs in it, every press, the list when it opens, each choice.
(function () {
  var where = window === window.top ? 'top' : 'frame';
  function log(m) { try { fetch('/log?m=' + encodeURIComponent(where + ': ' + m)); } catch (e) {} }
  window.addEventListener('load', function () {
    var top = false; try { top = !!(window.top.chrome && window.top.chrome.webview); } catch (e) {}
    log('loaded; webview here=' + !!(window.chrome && window.chrome.webview) + ' webview top=' + top +
      ' toolkitFix=' + !!window.__toolkitSelectFix + ' siteFix=' + !!window.__siteSelectFix);
    var s = document.getElementById('pick'), r = s.getBoundingClientRect();
    log('select at ' + Math.round(r.left + r.width / 2) + ',' + Math.round(r.top + r.height / 2));
    s.addEventListener('change', function () { log('picked ' + s.value); document.getElementById('out').textContent = 'Picked: ' + s.value; });
    new MutationObserver(function () {
      var h = document.querySelector('[data-toolkit-select]');
      if (h && !h.__seen) {
        h.__seen = true;
        var items = h.shadowRoot ? h.shadowRoot.querySelectorAll('.item') : [];
        var it = items[2], ir = it && it.getBoundingClientRect();
        log('list open with ' + items.length + ' items' + (ir ? '; item 3 at ' + Math.round(ir.left + 30) + ',' + Math.round(ir.top + ir.height / 2) : ''));
      }
    }).observe(document.documentElement, { childList: true, subtree: true });
  });
  document.addEventListener('mousedown', function (e) { log('mousedown at ' + e.clientX + ',' + e.clientY + ' on ' + e.target.tagName); }, true);
})();
