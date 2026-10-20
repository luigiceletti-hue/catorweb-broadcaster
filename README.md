# 📻 Catorweb Broadcaster

**A radio automation studio for Windows.** It plays your music from your PC and broadcasts it live to your streaming server (Icecast, Shoutcast or Liquidsoap).

🇮🇹 *[Leggi in italiano](README.it.md)*

## ⬇ Download

👉 **[Latest release](../../releases/latest)** → `Setup_CatorwebBroadcaster.exe`

Windows 10 / 11 · free and open source · no admin rights needed

## Features

- **Library** with categories: import your music without copying the files, Tag Editor, release-date embargo
- **Clockwheels** and **Scheduler**: the station runs on its own, 24/7
- **🎛 Live studio**: big countdown, running order, manual mode, 8 jingle buttons
- **🎙 Microphone** with automatic music ducking and voice processing
- **🎧 Rehearsal mode**: the station plays only on your PC, to practise or record a podcast
- **⏺ Recording** of the live show (voice only too, for editing)
- Interface in **English and Italian** · full manual in [`manuale/`](manuale/) (`manual.html` in English)

## Installing

1. Download `Setup_CatorwebBroadcaster.exe` from the [releases page](../../releases/latest).
2. Run it. If Windows shows **"Windows protected your PC"**, click **More info → Run anyway**: the program is free and not digitally signed.
3. On first start, fill in the **Settings** (station name, music folder, streaming server).

**Updating:** install the new version over the old one, your data is kept. The program tells you when a new version is available.

## Source code

The program is written in Python (local server + HTML interface) and uses [Liquidsoap](https://www.liquidsoap.info) as its audio engine.

| Folder | Contents |
|---|---|
| `app/` | Python server, interface, Liquidsoap script, translations, help pages, sample jingles |
| `tools/` | translation and publishing tools |
| `licenze/` | third-party licenses |
| `manuale/` | HTML manual (English and Italian) |
| `build_exe.ps1`, `installer.iss` | build scripts for the program and the installer |

**Building it**
1. Windows, Python 3.13: `py -3 -m pip install mutagen pyinstaller`
2. Liquidsoap **2.2.4** for Windows ([official release](https://github.com/savonet/liquidsoap/releases/tag/v2.2.4)): put `liquidsoap.exe` in the `liquidsoap/` folder (not in the repository: it is 128 MB).
3. [Inno Setup 6](https://jrsoftware.org/isinfo.php) to build the installer.
4. `powershell -ExecutionPolicy Bypass -File build_exe.ps1` → `build\Setup_CatorwebBroadcaster.exe`

To run it from source: `py -3 app\radio_broadcaster_server.py`

## License

Catorweb Broadcaster is free software, released under the **GNU General Public License version 2 or later** ([LICENSE](LICENSE)).
Third-party components and their licenses: [`licenze/LICENZE.txt`](licenze/LICENZE.txt). The sample jingles in `app/jingle` are © DJ Catoper, free to use within the app.
