// Posts the queue to the Lyric Widget on this computer, and asks it whether a skip is wanted. Port: Widget settings -> Accounts.
const PORT = 8899;
const HEADERS = { "Content-Type": "text/plain", "X-Lyric-Widget": "1" };

chrome.runtime.onMessage.addListener((msg, _sender, reply) => {
  if (!msg) return;
  if (msg.poll) {
    // relay.js asks every 1.5 s; the widget answers {"cmd": "next" | "previous" | ""}
    fetch(`http://127.0.0.1:${PORT}/poll`, { method: "POST", headers: HEADERS, body: "{}" })
      .then((r) => (r.ok ? r.json() : {}))
      .then((j) => reply({ ok: true, cmd: j.cmd || "" }))
      .catch(() => reply({ ok: false })); // widget not running / receiver off: nothing to do
    return true; // the answer comes later
  }
  if (!msg.payload) return;
  fetch(`http://127.0.0.1:${PORT}/queue`, {
    method: "POST",
    headers: HEADERS,
    body: JSON.stringify(msg.payload),
  }).catch(() => {}); // widget not running / receiver off: nothing to do
});
