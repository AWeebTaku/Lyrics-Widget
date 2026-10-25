// Posts the queue to the Lyric Widget on this computer. Port: Widget settings -> Accounts.
const PORT = 8899;

chrome.runtime.onMessage.addListener((msg) => {
  if (!msg || !msg.payload) return;
  fetch(`http://127.0.0.1:${PORT}/queue`, {
    method: "POST",
    headers: { "Content-Type": "text/plain", "X-Lyric-Widget": "1" },
    body: JSON.stringify(msg.payload),
  }).catch(() => {}); // widget not running / receiver off: nothing to do
});
