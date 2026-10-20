"""
Configurazione di Catorweb Broadcaster - Edizione distribuibile.

Tutto cio' che nella versione originale e' scritto nel codice (server di
destinazione, password, cartelle, microfono) qui sta in un file config.json
dell'utente, compilato al primo avvio dalla pagina /impostazioni.

  %APPDATA%\\CatorwebPC\\config.json     impostazioni
  %APPDATA%\\CatorwebPC\\data\\           stato, log, backup

CWR_EDITION_HOME sostituisce %APPDATA%\\CatorwebPC (solo per le prove).
"""

import json, os, sys, threading
from pathlib import Path

EDITION_NAME = "Catorweb Broadcaster"

# ── Dove sta il programma ──────────────────────────────────────────────
# .exe (PyInstaller): CatorwebBroadcaster.exe accanto a app\ e liquidsoap\
# sorgente: app\radio_broadcaster_server.py
if getattr(sys, "frozen", False):
    BASE_DIR = Path(sys.executable).resolve().parent
    APP_DIR  = BASE_DIR / "app"
else:
    APP_DIR  = Path(__file__).resolve().parent
    BASE_DIR = APP_DIR.parent

# ── Dove stanno i dati dell'utente ─────────────────────────────────────
HOME_DIR = Path(os.environ.get("CWR_EDITION_HOME")
                or Path(os.environ.get("APPDATA") or Path.home()) / "CatorwebPC")
CONFIG_FILE = HOME_DIR / "config.json"


def _user_dir(*names):
    """Cartella standard di Windows (Musica, Documenti) con ripiego sulla home."""
    home = Path.home()
    for n in names:
        p = home / n
        if p.is_dir():
            return p
    return home


STREAM_TYPES = {
    # tipo        protocollo Liquidsoap, utente e mount di base
    "icecast":   {"label": "Icecast 2", "label_en": "Icecast 2",
                  "protocol": "http", "user": "source", "mount": "/stream"},
    "shoutcast": {"label": "Shoutcast (v1 / v2 legacy)", "label_en": "Shoutcast (v1 / v2 legacy)",
                  "protocol": "icy",  "user": "",       "mount": "/"},
    "harbor":    {"label": "Ingresso live Liquidsoap (harbor)", "label_en": "Liquidsoap live input (harbor)",
                  "protocol": "http", "user": "source", "mount": "/"},
}

def windows_language():
    """'it' se Windows e' in italiano, altrimenti 'en' (lingua di partenza)."""
    try:
        import ctypes
        return "it" if (ctypes.windll.kernel32.GetUserDefaultUILanguage() & 0x3FF) == 0x10 else "en"
    except Exception:
        return "it"


LANGUAGES = {"it": "Italiano", "en": "English"}


def defaults():
    docs = _user_dir("Documents", "Documenti")
    lang = windows_language()
    return {
        "configured": False,
        "language": lang,
        "station": {
            "name": "My radio" if lang == "en" else "La mia radio",
            "genre": "Various" if lang == "en" else "Varie",
            "description": "",
            "website": "",
            "listen_url": "",          # stream pubblico per "▶ Live" (facoltativo)
        },
        "stream": {
            "type": "icecast",
            "host": "",
            "port": 8000,
            "mount": "/stream",
            "user": "source",
            "password": "",
            "bitrate": 128,
            "public": False,
        },
        "paths": {
            "music":      str(_user_dir("Music", "Musica")),
            "database":   str(HOME_DIR / "database"),
            "recordings": str(docs / "Catorweb Broadcaster" / "Registrazioni"),
            "export":     str(docs / "Catorweb Broadcaster" / "Export"),
        },
        "audio": {
            "mic_device": "",          # nome DirectShow, "" = nessun microfono
            "voice_tone": 0.0,         # semitoni, -2..+2 (0 = voce naturale)
            "voice_bass": 3.5,         # dB di "voce piena" sotto 160 Hz, 0..6
        },
        "extras": {
            "ntfy_topic": "",          # notifiche push su silenzio (facoltativo)
            "claude_intro": True,      # "Proponi presentazione" se Claude Code c'e'
            "check_updates": True,     # chiede a GitHub il numero dell'ultima versione
        },
        "ports": {                     # diverse dalla versione originale: possono convivere
            "app": 8767, "telnet": 1235, "monitor": 8001,
        },
    }


def _merge(base, over):
    out = dict(base)
    for k, v in (over or {}).items():
        if isinstance(v, dict) and isinstance(base.get(k), dict):
            out[k] = _merge(base[k], v)
        else:
            out[k] = v
    return out


_lock = threading.Lock()

def load():
    """Config dell'utente unita ai valori di base (chiavi nuove dopo un aggiornamento)."""
    with _lock:
        try:
            # utf-8-sig: regge anche un config.json salvato col Blocco note (BOM)
            raw = json.loads(CONFIG_FILE.read_text(encoding="utf-8-sig"))
        except Exception:
            raw = {}
    return _merge(defaults(), raw)


def save(cfg):
    with _lock:
        HOME_DIR.mkdir(parents=True, exist_ok=True)
        tmp = CONFIG_FILE.with_suffix(".tmp")
        tmp.write_text(json.dumps(cfg, ensure_ascii=False, indent=2), encoding="utf-8")
        os.replace(tmp, CONFIG_FILE)


def public_view(cfg):
    """Config senza la password dello stream (per la pagina Impostazioni)."""
    c = json.loads(json.dumps(cfg))
    c["stream"]["has_password"] = bool(c["stream"].get("password"))
    c["stream"]["password"] = ""
    return c


def server_configured(cfg):
    """True se c'e' un server di streaming (indirizzo inserito)."""
    return bool(str(cfg["stream"].get("host", "")).strip())


def validate(cfg):
    """Errori leggibili (in italiano: il server li traduce), lista vuota se va bene."""
    err = []
    if cfg.get("language") not in LANGUAGES:
        cfg["language"] = "it"
    s = cfg["stream"]
    if s.get("type") not in STREAM_TYPES:
        err.append("Tipo di server non valido")
    # Server facoltativo: chi non ha ancora i dati lascia vuoto l'indirizzo e usa 🎧 Prova.
    # Se l'indirizzo c'e', serve anche la password.
    try:
        p = int(s.get("port"))
        if not 1 <= p <= 65535: raise ValueError
    except Exception:
        err.append("Porta del server non valida")
    if server_configured(cfg) and not str(s.get("password", "")).strip():
        err.append("Password del server obbligatoria")
    elif "#{" in str(s.get("password")):
        err.append("La password non puo' contenere #{")
    try:
        if int(s.get("bitrate")) not in (64, 96, 128, 160, 192, 256, 320): raise ValueError
    except Exception:
        err.append("Bitrate non valido")
    if s.get("type") != "shoutcast" and not str(s.get("mount", "")).startswith("/"):
        err.append("Il mount deve iniziare con /")
    for key, label in (("music", "Cartella musica"), ("database", "Cartella database"),
                       ("recordings", "Cartella registrazioni"), ("export", "Cartella export")):
        if not str(cfg["paths"].get(key, "")).strip():
            err.append(f"{label} obbligatoria")
    for key, lo, hi, label in (("voice_tone", -2, 2, "Tono della voce"), ("voice_bass", 0, 6, "Voce piena")):
        try:
            v = float(cfg["audio"].get(key, 0))
            if not lo <= v <= hi: raise ValueError
            cfg["audio"][key] = v
        except Exception:
            err.append(f"{label}: valore non valido")
    if not Path(cfg["paths"]["music"]).is_dir():
        err.append(f"La cartella musica non esiste: {cfg['paths']['music']}")
    return err


def list_microphones():
    """Microfoni attivi di Windows con il nome usato da DirectShow,
    es. "Microfono (Yeti Classic)". Letti dal registro: niente programmi esterni."""
    names = []
    if os.name != "nt":
        return names
    try:
        import winreg
        base = r"SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Capture"
        DESC = "{a45c254e-df1c-4efd-8020-67d146a850e0},2"   # es. "Microfono"
        IFACE = "{b3f8fa53-0004-438e-9003-51a46e139bfc},6"  # es. "Yeti Classic"
        with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, base) as root:
            i = 0
            while True:
                try:
                    dev = winreg.EnumKey(root, i)
                except OSError:
                    break
                i += 1
                try:
                    with winreg.OpenKey(root, dev) as k:
                        state, _ = winreg.QueryValueEx(k, "DeviceState")
                    if state != 1:  # 1 = attivo
                        continue
                    with winreg.OpenKey(root, dev + r"\Properties") as k:
                        desc, _ = winreg.QueryValueEx(k, DESC)
                        iface, _ = winreg.QueryValueEx(k, IFACE)
                    names.append(f"{desc} ({iface})")
                except OSError:
                    continue
    except Exception:
        pass
    return sorted(set(names))
