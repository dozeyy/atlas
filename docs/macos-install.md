# Installing on a Mac

Atlas runs on macOS 12 or newer, on Apple Silicon and Intel Macs (one universal download).

1. Download [`Atlas-macOS.dmg`](https://github.com/dozeyy/atlas/releases/latest/download/Atlas-macOS.dmg).
2. Open it and drag Atlas into the Applications folder.
3. Open Atlas from Applications. The first time, the Mac stops it, because Atlas is not from the App
   Store and has no paid Apple developer ID yet. This happens once.

## macOS Sequoia (15) and newer

1. When the Mac says it could not check Atlas, click **Done**.
2. Open **System Settings**, then **Privacy & Security**.
3. Scroll down to the line about Atlas being blocked and click **Open Anyway**.
4. Click **Open Anyway** again and type your Mac password. Atlas opens, and from now on it opens like any other app.

## macOS Sonoma (14) and older

1. In Applications, hold **Control** and click Atlas, then pick **Open**.
2. Click **Open** in the box that appears. Atlas opens, and from now on it opens normally.
   (The Sequoia steps above also work here.)

Closing the Atlas window keeps it running in the Dock, so it can keep an eye on new chats.
**Cmd+Q** quits. Updates install from inside the app (Settings, About).

## Check your download (optional)

Each release lists a `SHA256SUMS.txt`. In Terminal:

```
shasum -a 256 ~/Downloads/Atlas-macOS.dmg
```

The result should equal the `Atlas-macOS.dmg` line in that file.
