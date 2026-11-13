.pragma library
// Word timing for the karaoke effect. A word's time is its start, in ms from the start of its line.
// Saved times are pairs [start ms, end char]: where the word ends in the line's text.

// Japanese and Chinese have no spaces: each kana / kanji is a word (a mark after it stays with it)
const CJK = "\\u3040-\\u30ff\\u3400-\\u4dbf\\u4e00-\\u9fff\\uf900-\\ufaff"
const wordRe = new RegExp("[" + CJK + "][^\\s" + CJK + "]*|[^\\s" + CJK + "]+", "g")

// the words of a line: where each starts and ends in the text
function spans(text) {
    const out = []
    let m
    wordRe.lastIndex = 0
    while ((m = wordRe.exec(text)) !== null)
        out.push({ s: m.index, e: m.index + m[0].length })
    return out
}

// no times saved: start the words spread over the line, longer words taking longer
function spread(lengths, durMs) {
    const total = lengths.reduce((a, n) => a + n + 1, 0)
    let acc = 0
    return lengths.map(n => { const t = Math.round(durMs * acc / total); acc += n + 1; return t })
}

// saved times that are for this very text
function fits(text, saved) {
    return saved && saved.length > 0 && saved[saved.length - 1][1] === text.length
}

// how many characters of the text are lit at `elapsed` ms into the line (a word lights when it starts);
// -1 = no karaoke. Without saved times the words are spread over the line.
function lit(text, saved, durMs, elapsed) {
    if (elapsed < 0)
        return -1
    if (fits(text, saved)) {
        let end = 0
        for (const w of saved) {
            if (w[0] > elapsed)
                break
            end = w[1]
        }
        return end
    }
    const sp = spans(text)
    if (sp.length === 0)
        return -1
    const st = spread(sp.map(p => p.e - p.s), durMs)
    let n = 0
    while (n < st.length && st[n] <= elapsed)
        ++n
    return n === 0 ? 0 : sp[n - 1].e
}

// the editor shows one time per word of `sp`: from the saved pairs (their words may be cut differently), or null
function offsets(text, sp, saved) {
    if (!fits(text, saved))
        return null
    return sp.map(p => { for (const w of saved) if (w[1] > p.s) return w[0]; return saved[saved.length - 1][0] })
}

function pairs(sp, offs) {
    return offs.map((ms, i) => [ms, sp[i].e])
}
