# 📻 Catorweb Broadcaster

**Regia radio per Windows** — suona la tua musica dal PC e la manda in diretta al tuo server di streaming (Icecast, Shoutcast o Liquidsoap).
*A radio automation studio for Windows — plays your music from your PC and broadcasts it live to your streaming server.*

## ⬇ Scarica / Download

👉 **[Ultima versione / Latest release](../../releases/latest)** → `Setup_CatorwebBroadcaster.exe`

Windows 10 / 11 · gratuito e open source / free and open source · niente permessi di amministratore / no admin rights needed

## Cosa fa / What it does

- **Libreria** con categorie, import senza copiare i file, Tag Editor, embargo per data
- **Clockwheel** e **Scheduler**: la radio va avanti da sola 24 ore su 24
- **🎛 Regia**: conto alla rovescia, scaletta, modo manuale, 8 pulsanti jingle
- **🎙 Microfono** con abbassamento automatico della musica e processore della voce
- **🎧 Prova**: la radio suona solo sul PC, per provare o registrare un podcast
- **⏺ Registrazione** della diretta (anche la sola voce, per il montaggio)
- Italiano e English · manuale completo in [`manuale/`](manuale/)

*Library with categories, clockwheels and scheduler, live studio with countdown and jingle buttons, microphone with ducking and voice processing, rehearsal mode, recording — in Italian and English. Full manual in [`manuale/`](manuale/).*

## Installare / Installing

1. Scarica `Setup_CatorwebBroadcaster.exe` dalla pagina delle release. / *Download it from the releases page.*
2. Avvialo. Se Windows mostra **"Il PC è stato protetto"**, clicca **Ulteriori informazioni → Esegui comunque**: il programma è gratuito e non è firmato digitalmente. / *If Windows shows "Windows protected your PC", click **More info → Run anyway**: the program is free and not digitally signed.*
3. Al primo avvio compila le **Impostazioni**. / *Fill in the **Settings** on first start.*

Aggiornare: installa la nuova versione sopra la vecchia, i tuoi dati restano. / *Updating: install the new version over the old one, your data is kept.*

## Codice sorgente / Source code

Il programma è scritto in Python (server locale + interfaccia HTML) e usa [Liquidsoap](https://www.liquidsoap.info) come motore audio.
*The program is written in Python (local server + HTML interface) and uses Liquidsoap as its audio engine.*

| Cartella / Folder | Contenuto / Contents |
|---|---|
| `app/` | server Python, interfaccia, script Liquidsoap, traduzioni, guida, jingle di esempio |
| `tools/` | strumenti per le traduzioni / translation tools |
| `licenze/` | licenze dei componenti / third-party licenses |
| `manuale/` | manuale HTML (IT/EN) |
| `build_exe.ps1`, `installer.iss` | creazione del programma e dell'installatore / build scripts |

**Ricostruirlo / Building it**
1. Windows, Python 3.13: `py -3 -m pip install mutagen pyinstaller`
2. Liquidsoap **2.2.4** per Windows (dal [sito ufficiale](https://github.com/savonet/liquidsoap/releases/tag/v2.2.4)): metti `liquidsoap.exe` nella cartella `liquidsoap/` (non è nel repository: pesa 128 MB). / *Put `liquidsoap.exe` in `liquidsoap/` (not in the repository: 128 MB).*
3. [Inno Setup 6](https://jrsoftware.org/isinfo.php) per creare l'installatore.
4. `powershell -ExecutionPolicy Bypass -File build_exe.ps1` → `build\Setup_CatorwebBroadcaster.exe`

Per provarlo senza compilarlo / *To run it from source*: `py -3 app\radio_broadcaster_server.py`

## Licenza / License

Catorweb Broadcaster è software libero, distribuito secondo la **GNU General Public License versione 2 o successiva** ([LICENSE](LICENSE)).
*Catorweb Broadcaster is free software under the **GNU GPL v2 or later**.*
Componenti di terze parti e relative licenze: [`licenze/LICENZE.txt`](licenze/LICENZE.txt). I jingle di esempio in `app/jingle` sono © DJ Catoper, liberi da usare dentro l'app.
