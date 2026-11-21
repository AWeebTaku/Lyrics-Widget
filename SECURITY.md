# Security

## Reporting a problem

Please report a security problem privately, not as a public issue: use
[Report a vulnerability](https://github.com/AWeebTaku/Lyrics-Widget/security/advisories/new) on the repository's Security tab.
You will get an answer as soon as I can give one. Please do not share details publicly until there is a fix.

## What is worth reporting

- The local listener for the browser extension (`127.0.0.1`, port 8899, off unless you turn it on): anything that lets a web page
  or another program on the network talk to it.
- The Spotify app connection (a local debugging port that is only read): anything that makes the widget change Spotify, or send
  its data elsewhere.
- Files the widget reads or writes outside its own folders, and the installer, updater and uninstaller scripts.

## What leaves your computer

The README section "Privacy" lists every request the widget makes. There is no account, identifier or telemetry.

## Supported versions

The latest release. Older ones are not patched.
