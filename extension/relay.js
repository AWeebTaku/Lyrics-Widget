// Isolated world: passes the page script's message to the background worker (which may talk to
// 127.0.0.1; the page itself must not).
window.addEventListener("message", (e) => {
  if (e.source === window && e.data && e.data.source === "lyric-widget-ytm")
    chrome.runtime.sendMessage({ payload: e.data.payload });
});

// Back-up for Next / Previous. Chrome's media controls sometimes stop answering until the browser restarts; the widget then asks
// (through background.js) for the page's own buttons to be pressed. Only the tab that is playing asks, so a second tab never
// takes the request. Backs off while the widget is not running.
(() => {
  const BUTTON = { next: ".next-button", previous: ".previous-button" };
  let wait = 1500;
  function poll() {
    const video = document.querySelector("video");
    if (!video || video.paused) return setTimeout(poll, 1500);
    try {
      chrome.runtime.sendMessage({ poll: true }, (r) => {
        if (chrome.runtime.lastError || !r) { wait = Math.min(wait * 2, 15000); }
        else {
          wait = r.ok ? 1500 : Math.min(wait * 2, 15000);
          if (r.cmd && BUTTON[r.cmd]) { const b = document.querySelector("ytmusic-player-bar " + BUTTON[r.cmd]); if (b) b.click(); }
        }
        setTimeout(poll, wait);
      });
    } catch (e) { /* the extension was reloaded: this page's script is orphaned */ }
  }
  setTimeout(poll, 1500);
})();
