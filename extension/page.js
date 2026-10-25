// Runs inside the YouTube Music page (MAIN world: the queue items keep their data on the element
// objects, which an isolated content script cannot see). Reads the queue and hands it to relay.js.
(() => {
  const text = (r) => (r && r.runs ? r.runs.map((x) => x.text).join("") : (r && r.simpleText) || "");
  const seconds = (s) => s.split(":").reduce((a, p) => a * 60 + (parseInt(p, 10) || 0), 0);

  // "Artist • Album • 2019" arrives as runs separated by " • ": regroup into fields.
  function fields(runs) {
    const groups = [[]];
    for (const r of runs || []) (r.text.trim() === "•" ? groups.push([]) : groups[groups.length - 1].push(r.text));
    return groups.map((g) => g.join("").trim()).filter(Boolean);
  }

  // elements: the queue item elements, in order. Returns {currentVideoId, next: [...]}.
  function extractQueue(elements, urlVideoId) {
    const items = [];
    let current = -1;
    for (const el of elements) {
      let d = el.data || {};
      // wrapper items hold the song and its video variant: take the primary one
      d = d.playlistPanelVideoRenderer || (d.primaryRenderer && d.primaryRenderer.playlistPanelVideoRenderer) || d;
      if (!d.videoId) continue;
      const f = fields(d.longBylineText ? d.longBylineText.runs : d.shortBylineText && d.shortBylineText.runs);
      items.push({
        videoId: d.videoId,
        title: text(d.title),
        artist: f[0] || "",
        album: f[1] || "",
        durationSec: seconds(text(d.lengthText)),
      });
      const selected = (el.hasAttribute && el.hasAttribute("selected")) || d.selected === true;
      if (selected) current = items.length - 1;
    }
    if (current < 0 && urlVideoId) current = items.findIndex((i) => i.videoId === urlVideoId);
    return { currentVideoId: current >= 0 ? items[current].videoId : urlVideoId || "", next: items.slice(current + 1) };
  }

  if (typeof module !== "undefined") module.exports = { extractQueue, fields };
  if (typeof document === "undefined") return;

  let last = "", lastSent = 0;
  setInterval(() => {
    const els = document.querySelectorAll("ytmusic-player-queue-item");
    if (!els.length) return;
    const v = new URLSearchParams(location.search).get("v") || "";
    const payload = extractQueue(Array.from(els), v);
    const json = JSON.stringify(payload);
    // resend when it changed, and every 25 s so the widget knows the data is fresh
    if (json !== last || Date.now() - lastSent > 25000) {
      last = json;
      lastSent = Date.now();
      window.postMessage({ source: "lyric-widget-ytm", payload }, window.location.origin);
    }
  }, 3000);
})();
