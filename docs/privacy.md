# Privacy

Atlas is local software. This page says exactly what it touches.

## What it reads

- The chat transcripts and config files Claude Code keeps in your Claude folder: `~/.claude`, or the
  folder named by `CLAUDE_CONFIG_DIR`, plus the global `~/.claude.json`.
- Project folders Claude Code already knows about, to show their instructions, skills and rules.

## What it never reads

- `.credentials.json`, session key files, OAuth keys and admin keys. They are not listed, not readable and
  not writable, in the app or through the connector.
- Secret-looking values inside files it does show (tokens, passwords in URLs, API keys) are masked with
  dots, and writing the dots back is refused.

## What it writes

- Its own data folder, `atlas`, in your user data folder: a chat index (a cache you can delete),
  settings, and backups.
- Your Claude files, only when you or Claude (through the connector) change something. Every such
  write makes a backup first, is done atomically, keeps line endings and unknown keys, appears in
  History and can be undone. Deleting moves a file to the system trash or Atlas's backups.

## What goes over the network

- **Update check (app only):** a request to `github.com` for this repository's `latest.json`, shortly
  after start and every six hours. Updates are signed, and the app checks the signature against a
  public key built into it. It never installs by itself.
- **Skill download (skill only, once per version, only if no local copy exists):** the `atlas-usage`
  program from this repository's releases, checked against a checksum pinned inside the plugin.
- Nothing else. No analytics, no crash reports, no account, no upload of chats.

The connector (`atlas-mcp`) talks to Claude Code over a local pipe and never opens a network port.

## Cost figures

Dollar amounts are estimates from a built-in price table. They are not read from any bill.
