// Isolated world: passes the page script's message to the background worker (which may talk to
// 127.0.0.1; the page itself must not).
window.addEventListener("message", (e) => {
  if (e.source === window && e.data && e.data.source === "lyric-widget-ytm")
    chrome.runtime.sendMessage({ payload: e.data.payload });
});
