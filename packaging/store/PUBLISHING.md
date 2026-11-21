# Publishing on the KDE Store (store.kde.org)

The store hosts the widget's QML part. The C++ plugin cannot be installed by the store, so the listing must tell people to run
`install.sh` first (the text is ready in `LISTING.md`). The store's page layout changes now and then, so the names of buttons
below may differ a little. There is no reliable command-line route, so this is done in the browser.

## Before you start (about 5 minutes)

1. Decide the version. It is `Version` in `plasmoid/metadata.json` (now 2.1.0). A new upload should have a higher number than
   the last one on the store.
2. Build the package: `packaging/store/make-plasmoid.sh` writes `build/org.lyricwidget-<version>.plasmoid`. The same file is
   attached to each GitHub release, so you can download it from the release page instead.
3. Check it opens: `unzip -l build/org.lyricwidget-*.plasmoid | head` shows `metadata.json` at the top level and a `contents/` folder.
4. Have ready: `packaging/store/icon.png` (the logo, 512 x 512), 3 to 5 screenshots (see below), and the text in `LISTING.md`.

Screenshots worth uploading, 1280 px wide or more is best:

- The widget on a desktop with a card look (take it yourself, with a real wallpaper and a real song).
- The settings window on the Visualizer page showing the looks.
- A few renders from `docs/gallery/` (for example 02, 12, 20, 23): they are the widget's own pictures.

## Create the listing (once)

1. Go to <https://store.kde.org> and log in. The login is a KDE Identity account (identity.kde.org); create one if you have
   none and confirm the email.
2. Open your profile menu and choose **Products**, then **Add product** (the wording may be "Add a new product").
3. Fill in the form with the text from `LISTING.md`:
   - **Title:** Lyric Widget
   - **Category:** the Plasma 6 widgets category (look under Plasma extensions for "Plasma Widgets" or "Plasma 6 Widgets"; choose
     the one for Plasma 6, because the widget needs Plasma 6.0 or newer)
   - **Description:** the long text, including the sentence that the plugin has to be installed first, with the `install.sh` line
   - **Version:** 2.1.0 (the number in `metadata.json`)
   - **License:** GPL-3.0
   - **Homepage / source:** <https://github.com/AWeebTaku/Lyrics-Widget>
   - **Tags:** lyrics, spotify, youtube music, visualizer, karaoke
4. Upload the **logo/icon** (`icon.png`) and the **screenshots**.
5. Save. The product exists but has no file yet.

## Upload the package

1. On the product page open the **Files** tab and add `org.lyricwidget-<version>.plasmoid`.
2. Give the file a **version** (the same as in `metadata.json`) and a short description such as "Plasma 6, needs the plugin from
   install.sh".
3. If the form asks for a **file type or tag**, choose the plasmoid / Plasma widget option so "Get New Widgets" in Plasma offers it.
4. Publish the product (a **Publish** or **Set live** button, or a switch from "unpublished").
5. New products and first uploads can be held for a short moderation check. If it does not show up, look at the notification
   area of your account and the product's status.

## Check it like a user

1. On a clean test account or after `kpackagetool6 --type Plasma/Applet --remove org.lyricwidget` (this only affects the copy
   the store installed under `~/.local`):
   ```
   git clone https://github.com/AWeebTaku/Lyrics-Widget && cd Lyrics-Widget && ./install.sh
   ```
2. Right-click the desktop, **Add or Manage Widgets**, **Get New Widgets**, search "Lyric Widget", install it, drag it out.
3. Play a song. If Plasma shows "module org.lyricwidget is not installed", the plugin step was skipped: run `./install.sh`.

## For each new version

1. Raise `Version` in `plasmoid/metadata.json`, commit, push, and tag it (`git tag v2.2.0 && git push origin v2.2.0`). The workflow
   makes the GitHub release with the `.plasmoid` attached.
2. Download that `.plasmoid` (or run `packaging/store/make-plasmoid.sh`).
3. On the store product page add the new file (or replace the old one) with the new version number, and write what changed in
   the product's **Changelog / Updates** field. Remove very old files so "Get New Widgets" offers only the current one.
4. If the release changed the C++ plugin, say so in the changelog: users then run `git pull && ./install.sh` too.

## After it is live

- Put the product link in the README and on the website, and add a "KDE Store" tab to the website's Install section.
- Answer comments and ratings on the product page; they are the store's support channel. Point bug reports to GitHub issues.
