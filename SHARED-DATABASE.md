# Shared timed-lyrics database: plan for later

Status: **not started, deliberately.** Decision (2026-11-13): keep it as future development and do only the
cheap preparation below. This file records why, what the options are, and the steps, so the idea can be picked
up again without redoing the thinking.

## The idea

A repository where users contribute timed lyrics (line-timed, and word-timed for the karaoke effect) for the
songs and videos they play, so the widget can find lyrics that no current provider has: covers, remixes,
fan uploads, videos, obscure songs.

## Why not now

1. **Cold start.** The widget already finds most songs through LRCLIB, NetEase, QQ Music and Kugou. A new
   database only helps for the gaps, and it is empty until it has contributors. It has no contributors until the
   widget has users. Building the service first answers a question nobody is asking yet.
2. **Legal exposure.** Today the widget fetches lyrics from other services and keeps copies on the user's own
   machine; the README says lyrics belong to their owners. A public database of submitted lyric text makes the
   operator a publisher of that text. It needs terms of use, a takedown (DMCA-style) process and a contact
   address. This is not legal advice: ask someone qualified before launching anything public.
3. **Ongoing work.** Spam, vandalism, wrong or fake lyrics and abuse of the upload endpoint need moderation.
   Solo, the cost is the upkeep, not the hosting.
4. **Song identity is not good enough for shared data.** Keys come from the player's title, artist and length
   (`Keys::songKey`). YouTube titles are messy, so two users can get different keys for the same song. A shared
   database needs a better fingerprint first (see step 3).

## Free options for hosting (check current limits: free tiers change)

| Option | Good for | Watch out for |
|---|---|---|
| **Cloudflare Workers + D1 (SQL) + R2 (files)** | An API plus a small database with no server to run. Best fit. | Free-tier request and write limits; vendor lock-in. |
| **Supabase** (hosted Postgres, auth) | Accounts, row-level security, a ready REST API. | Free projects pause when idle; storage cap. |
| **Turso** (hosted SQLite) | Matches the widget's SQLite habits. | Free-tier size and row-read limits. |
| **GitHub repo of JSON files, served as static files, contributions as pull requests** | Completely free; review, history and takedowns are built in. A good first version. | Does not scale past tens of thousands of songs; a pull request is a high bar for casual users. |
| **LRCLIB** (existing open database) | Line-timed lyrics, public API, already searched by the widget. | No word timing. Uploading needs its own client flow. |

## What to do now (cheap preparation)

1. **Export from the library.** A button that writes the saved songs to a JSON file in a documented format.
   The library table already keeps title, artist, album, length, language, source and the word times, which is
   what a shared catalogue needs. Good for backups too.
2. **Write the data format down.** One song record: `title`, `artist`, `album`, `durationSec`, `lang`,
   `synced` (LRC), `plain`, `words` (JSON, see `src/WordTiming.h`), `origTitle` / `origArtist` for covers,
   `source`, `updated`. Add a `formatVersion` field.
3. **Optional: an "upload to LRCLIB" button** for line-timed lyrics the user edited, instead of running a
   service. It reaches more people than a private database and costs no hosting.

## Steps when the time comes

Do these in order; stop at any step that shows nobody needs the next one.

1. **Check demand.** Are people asking for songs the providers lack? Does anyone use the Word timing tab? If the
   library exports are empty or unshared, the database has nothing to start from.
2. **Settle the legal side.** Decide: store lyric text, or store only timings plus a hash of each line and let
   the widget fetch the text elsewhere (reduces the copyright exposure, but cannot serve songs no other source
   has text for). Write terms of use and a takedown process either way. Ask a lawyer.
3. **Fix the song fingerprint.** A key that two users playing the same recording will share: normalised title and
   artist, rounded length, plus the YouTube or Spotify track id when there is one. Keep several keys per song so
   a lookup can try each. Reuse `Text::candidates` for name variants.
4. **Choose the start.** Smallest first: a GitHub repository of JSON files with pull-request contributions, read
   by the widget over plain HTTPS. Move to Cloudflare Workers + D1 only when pull requests become the bottleneck.
5. **Define the API** (when there is a server): `GET /song?key=...` returns a record; `POST /song` submits one;
   `POST /report` flags a record. Version it (`/v1`). Rate-limit by IP.
6. **Contribution and trust.** Anonymous submissions with a proof-of-work or a lightweight sign-in (GitHub)
   to slow abuse. A submission starts as pending; it is served once a second user confirms it matches, or a
   moderator approves it. Keep every version so a bad edit can be reverted.
7. **Widget side.** A new provider, **off by default**, queried after the others fail (or before, if its record
   is a human-corrected one). Cache answers in `lyrics.db` like any provider. Add an opt-in "share my edited
   lyrics" setting; never upload anything without it.
8. **Launch small.** Seed it with your own library, invite a few testers, watch the reports, then widen.

## Risks to keep in view

- A takedown request must be answered quickly; plan who does it.
- Do not collect more than the record needs: no listening history, no account data beyond a sign-in handle.
- Free tiers can change or end; keep the data exportable so moving host is a copy, not a rewrite.
- A provider's terms may forbid automated use (see the README's "Lyric sources and terms"); a shared database
  that re-publishes data scraped from them would make that problem larger, so contributions should be the
  user's own timing work.
