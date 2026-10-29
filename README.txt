CATORWEB BROADCASTER  -  radio automation for Windows
==========================================================

WHAT IT IS
  Plays your music from this PC and broadcasts it live to your streaming
  server (Icecast, Shoutcast or a Liquidsoap live input). Queue,
  clockwheels, scheduler, jingles, microphone with ducking, recording,
  manual mode.

FIRST START
  1. Open "Catorweb Broadcaster" (Desktop icon or Start menu).
     The radio window opens, and the program's icon appears next to the
     clock (bottom right): double-click reopens it, right-click -> Quit
     closes it. If you don't see it, it's among the hidden icons (small
     arrow next to the clock): drag it onto the taskbar to keep it visible.
  2. Fill in the Settings page:
     - Language: English or Italiano
     - The radio: name, genre, public listen address (optional)
     - Streaming server: type, address, port, mount, password
       (the details from your provider). "Test connection" checks them.
     - Folders: music, database, recordings, export
     - Microphone (optional)
  3. Save: the Dashboard opens (no login, the app only answers on this
     PC). Then in "Library" import your music folder.
     No server details yet? Leave the address empty and use
     ▶ Start offline until you get them.

GOING ON AIR
  At the top press "OFF AIR - Go on air" and confirm -> "ON AIR".
  To stop: "ON AIR - End broadcast".
  Quitting the program (icon next to the clock -> Quit) also ends the
  broadcast; closing just the radio window does not.
  While the program is open the PC does not go to sleep
  (closing a laptop lid still puts it to sleep).

▶ START OFFLINE (the radio on this PC only)
  "▶ Start offline" button next to OFF AIR: the radio runs normally
  (queue, clockwheel, jingles, microphone, recording) but only on this PC;
  nothing is sent to the server and no internet is needed. Use it to
  listen to your music, record a podcast or try things out before going
  on air. After a few seconds listening starts by itself.
  Offline the green button reads "🎧 OFFLINE (this PC only) - ⏹ Stop";
  the big button still reads "OFF AIR - Go on air": press it (and
  confirm) and the server connects WITHOUT stopping the music, the track
  you are listening to goes on air as it is. "⏹ Stop" turns everything
  off. Automatic recording does not start offline (it starts when you go
  on air). If you save the Settings (microphone, server) while offline,
  the radio restarts with the new values.

CHANGING THE SETTINGS
  "⚙ Settings", right of the tabs. The server applies from the next
  "Go on air"; if you change the folders the program restarts by itself.

MICROPHONE
  "🎙 MIC" at the top (or hold the space bar). Slider = voice volume.
  Button next to MIC (same box):
   "🤖 Auto"   (default) the music ducks only while you speak and comes
               back ~1 s after your last word
   "🎚 Studio" you talk while holding the space bar: the music drops
               straight away and comes back when you let go, like a
               mixer fader
  Don't confuse it with "▶ Automatic / ✋ Manual", which only decides how
  tracks start.

SERVER TYPES
  Icecast 2 ........ host, port, mount (e.g. /stream), user "source"
  Shoutcast ........ host and public port (it connects to port+1 by itself)
  Liquidsoap harbor  like Icecast, mount usually "/"

WHERE YOUR DATA IS
  %APPDATA%\CatorwebPC\config.json   settings
  %APPDATA%\CatorwebPC\data\         logs, state, backups
  The database and recordings are in the folders you chose.
  Uninstalling the program keeps this data.

INTRO WITH CLAUDE (optional)
  If Claude Code is installed on the PC and signed in to your account,
  the Studio tab shows "✍ Suggest intro": it writes 2-3 sentences about
  the next track. Turn it off in Settings -> Extra.

TROUBLESHOOTING
  - Reopening the program while it is running brings back the window
    that is already open.
  - It won't go on air: Settings -> Test connection; check the Log tab.
  - The program uses ports 8767, 8001 and 1235 on this PC only.

LICENSES
  In the program folder, under "licenze", the list of components
  (Liquidsoap, mutagen, Python...) with licenses and source links.
