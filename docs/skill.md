# The /atlas skill

The skill puts your Claude Code usage in the chat, with the same numbers as the Atlas app: a day
here equals that day's bar in the app. It is read-only. It reads the chat transcripts Claude Code keeps in
`~/.claude` (or the folder in `CLAUDE_CONFIG_DIR`) and keeps its own index in Atlas's data folder.

The names and numbers below come from a made-up demo setup.

## Install

```
/plugin marketplace add dozeyy/atlas
/plugin install atlas@atlas
```

Then type `/atlas`, or ask in plain words: "what's my usage this week", "how many tokens has this
chat used", "usage for this project", "last week vs this week". Claude picks the skill up by itself.

Update later with `/plugin marketplace update atlas`.

## How it finds its program

The skill is a thin launcher around a small program, `atlas-usage`. It uses the first of these it finds:

1. `ATLAS_USAGE_BIN`, if you set it: the path of a program file to run instead of searching. It runs
   as-is, with no checksum check, so only point it at a build you trust.
2. `atlas-usage` on your PATH.
3. A copy it saved earlier, in a folder named after the plugin version. It lives in the plugin's data
   folder when Claude Code gives it one, otherwise in a per-user cache folder:
   `%LOCALAPPDATA%\atlas\skill` on Windows, `~/Library/Caches/atlas/skill` on macOS,
   `~/.cache/atlas/skill` on Linux. A saved copy is checked against its pinned checksum every time.
4. The copy that comes with the Atlas app (on Windows, next to `atlas.exe`).
5. Otherwise it downloads the right build for your computer, once, from the release of the same
   version number in this repository.

The plugin carries `skill/skills/atlas/bin/checksums.txt`, a list of `<version> <file> <sha256>` lines
fixed when that version was released. The download is run only if its SHA-256 matches the pinned line.
Otherwise it is deleted and never run. A plugin version with no pinned line downloads nothing, and the
launcher tells you to update the plugin.

A copy on PATH or in the app that is the pinned build of an older plugin version is passed over, so
updating the plugin moves you to the matching build. Your own builds still run. If the download fails,
the launcher falls back to an older copy and says so.

If the download cannot work (you are offline), the launcher prints one line saying what to do.

### Signature check

On a download the launcher also fetches the release's `SHA256SUMS.txt` and `SHA256SUMS.txt.sig`. The
list must be signed by the Atlas release key (the same key the app's updater trusts), and it must give
the program the pinned checksum. If either check fails, the download is deleted and not run. The pinned
checksum always decides first, so the signature can only add a refusal.

On Windows, PowerShell checks the signature itself. On macOS and Linux it needs OpenSSL 3.0 or later.
OpenSSL 1.1.1 and macOS's own LibreSSL can't check these signatures, so there the pinned checksum alone
decides unless a newer OpenSSL (for example Homebrew's `openssl@3`) is on your PATH.

### Which copy is it using?

Ask Claude to run the launcher with `launcher-doctor`, or run it yourself from the plugin's folder:

```
sh skills/atlas/bin/atlas-usage.sh launcher-doctor
powershell -NoProfile -ExecutionPolicy Bypass -File skills/atlas/bin/atlas-usage.ps1 launcher-doctor
```

It lists each place it looks, what it found there, whether signatures can be checked on this computer,
and which copy it would run. It runs nothing and downloads nothing.

## Scopes

| Words | Meaning |
|---|---|
| `chat` (or nothing) | This chat |
| `today`, `yesterday` | One day |
| `week`, `last-week` | This week so far, last week |
| `7d`, `30d`, `<N>d` | The past N days |
| `month`, `last-month` | A calendar month |
| `all` | All time: every chat Atlas has counted, including chats Claude Code has since deleted (combine with `project` or `--project=<name>` for one project) |
| `2026-11-02` or `2026-11-02..2026-11-07` | A day or a range |
| `project` | The current folder's project (add a range, for example `project week`) |
| `--project=<name>` | A named project |
| `A --vs B` | Compare two scopes |
| `--top <N>` | More rows in the tables |
| `--ascii` | Plain `#` bars for a terminal that draws boxes for blocks (or `ATLAS_ASCII=1`) |
| `--json` | JSON for scripts |

Activity is a bar per day up to 14 days. From 15 days to 12 weeks it is the app's terrain grid: a cell
per day, seven days to a row, today at the bottom right, and a triangle on the busiest day. Longer ranges
are a bar per week, then per month.

Tokens are input plus output plus cache writes. Cache reads are shown apart. Numbers use three
significant digits (7.3k, 56.1M). The dollar figure on the last line is an estimate at API prices.

## What each one prints

### This chat: `/atlas`

````text
**This chat** · **109k tokens** plus 724k cache reads
"Check the cron schedule" · budget-bot · 1h 31m · 23 messages · 1 helper

Where it went
```text
Main chat    ████████████████████████  94.6k  87%
Helpers (1)  ███▌                      13.9k  13%
```

Models
```text
Sonnet 5.5  ████████████████████████  94.1k  87%
Haiku 5.5   ███▋                      14.4k  13%
```

| Helper | Type | Model | Tokens |
|---|---|---|--:|
| Run the suite and summarise failures | test-runner | Sonnet 5.5 | 13.9k |

Activity
```text
12:00  ██████████▉                 23k
13:00  ████████████████████████  50.8k  ▲
14:00  ████████████████▍         34.7k
```

_Estimated at API prices: $0.44. Not a bill._
````
### A week: `/atlas this week`

````text
**This week** · Nov 8 · all projects
**560k tokens** plus 3.85M cache reads · 3 sessions

Models
```text
Sonnet 5.5  ████████████████████████  364k  65%
Haiku 5.5   ████████████▉             196k  35%
```

| Project | Tokens | Sessions |
|---|--:|--:|
| maple-api | 373k | 2 |
| dotfiles | 187k | 1 |

| Biggest sessions | Project | Tokens |
|---|---|--:|
| Move settings into one file | maple-api | 209k |
| Wire the budget chart | dotfiles | 187k |
| Tidy the invoice rounding | maple-api | 165k |

_Estimated at API prices: $2.02. Not a bill._
````
### A month, as a terrain grid: `/atlas 30d`

````text
**Last 30 days** · Oct 10 - Nov 8 · all projects
**5.7M tokens** plus 37.7M cache reads · 41 sessions

Activity · 7 days a row
```text
Oct 10            ▅ ▃
Oct 12  · ▲ · · · ▆ ·
Oct 19  · ▆ ▅ ▅ ▂ ▂ ▃
Oct 26  · ▃ ▂ ▅ ▆ ▂ ▆
Nov 2   ▃ ▃ ▂ ▅ ▅ █ █  Today
· idle  ▂ ▃ ▅ ▆ █ busier  ▲ busiest day, Tue Oct 13: 649k
```

Models
```text
Sonnet 5.5  ████████████████████████  2.49M  44%
Haiku 5.5   ███████████████████▉      2.07M  36%
Opus 5.5    ███████████               1.14M  20%
```

| Project | Tokens | Sessions |
|---|--:|--:|
| maple-api | 2.55M | 15 |
| budget-bot | 862k | 7 |
| dotfiles | 786k | 6 |
| pixel-garden | 777k | 7 |
| field-notes | 726k | 6 |

| Biggest sessions | Project | Tokens |
|---|---|--:|
| Check the cron schedule | maple-api | 383k |
| Sort out the weekly digest | budget-bot | 327k |
| Tidy the invoice rounding | maple-api | 322k |
| Speed up the search page | maple-api | 303k |
| Review the sync code | field-notes | 244k |

_Estimated at API prices: $25.91. Not a bill._
````
### One project: `/atlas project`

````text
**All time** · Aug 11 - Nov 8 · project **maple-api**
**8.3M tokens** plus 56.3M cache reads · 47 sessions

Activity
```text
Wk of Aug 9   ███████████▊               487k
Wk of Aug 16  ██████████████████████▏    920k
Wk of Aug 23  ████████████████████▏      836k
Wk of Aug 30  ████████████████▍          683k
Wk of Sep 6   ████████████████████████     1M  ▲
Wk of Sep 13  ██████████▊                449k
Wk of Sep 20  █▉                        78.8k
Wk of Sep 27  ██████████████████▌        773k
Wk of Oct 4   ██████████████             586k
Wk of Oct 11  ████████▋                  362k
Wk of Oct 18  ▉                         37.6k
Wk of Oct 25  ████████████████████▊      863k
Wk of Nov 1   ████████████████████▌      856k
Wk of Nov 8   █████████                  373k
```

Models
```text
Sonnet 5.5  ████████████████████████  3.43M  41%
Haiku 5.5   ███████████████████████▋  3.37M  41%
Opus 5.5    ██████████▌                1.5M  18%
```

| Biggest sessions | Tokens |
|---|--:|
| Port the shell aliases | 555k |
| Check the cron schedule | 383k |
| Move settings into one file | 381k |
| Tidy the invoice rounding | 379k |
| Plan the next release | 365k |

_Estimated at API prices: $35.84. Not a bill._
````
### Two periods: `/atlas last week vs this week`

````text
**This week** (Nov 8) vs **Last week** (Nov 1 - Nov 7)

| | Last week | This week | Change |
|---|--:|--:|--:|
| Tokens | 1.64M | 560k | -66% |
| Cache reads | 11.6M | 3.85M | -67% |
| Sessions | 13 | 3 | -77% |

| Model | Last week | This week | Change |
|---|--:|--:|--:|
| Sonnet 5.5 | 573k | 364k | -36% |
| Haiku 5.5 | 528k | 196k | -63% |
| Opus 5.5 | 539k | 0 | -100% |

| Project | Last week | This week | Change |
|---|--:|--:|--:|
| maple-api | 856k | 373k | -56% |
| pixel-garden | 420k | 0 | -100% |
| dotfiles | 167k | 187k | +12% |
| field-notes | 98.6k | 0 | -100% |
| budget-bot | 97.8k | 0 | -100% |

_Estimated at API prices, not a bill: Last week $9.00, This week $2.02._
````
## Permissions

When Claude picks the skill up from a plain question it uses the Skill tool. If your permission mode
asks, allow it once or add `Skill(atlas)` to `permissions.allow`. Typing `/atlas` needs no approval. The
skill itself allows only its own launcher script.

## Running the program directly

```
atlas-usage                      # this chat ($CLAUDE_CODE_SESSION_ID), markdown
atlas-usage last-week --vs week  # comparison
atlas-usage project 30d --json   # JSON for scripts
atlas-usage 30d --ascii          # plain # bars
atlas-usage --help
```

## Troubleshooting

See the table in the [README](../README.md#troubleshooting).
