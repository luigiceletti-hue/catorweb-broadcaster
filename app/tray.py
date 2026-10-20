"""Icona di Catorweb Broadcaster nell'area di notifica di Windows (vicino all'orologio).

Sostituisce la finestra nera: il programma gira nascosto e da qui si apre la radio o si esce.
Solo funzioni di Windows via ctypes, nessuna libreria in piu'.

Uso:  tray.start(icon_path, tip, items, on_default)
      items = [(etichetta, funzione) | None per il separatore]; on_default = doppio clic
      tray.set_tip(testo), tray.balloon(titolo, testo), tray.stop()
"""
import ctypes
import ctypes.wintypes as w
import threading

user32 = ctypes.windll.user32
shell32 = ctypes.windll.shell32
kernel32 = ctypes.windll.kernel32

LRESULT = ctypes.c_ssize_t
WNDPROC = ctypes.WINFUNCTYPE(LRESULT, w.HWND, w.UINT, w.WPARAM, w.LPARAM)


class WNDCLASSW(ctypes.Structure):
    _fields_ = [("style", w.UINT), ("lpfnWndProc", WNDPROC), ("cbClsExtra", ctypes.c_int),
                ("cbWndExtra", ctypes.c_int), ("hInstance", w.HINSTANCE), ("hIcon", w.HICON),
                ("hCursor", w.HANDLE), ("hbrBackground", w.HBRUSH), ("lpszMenuName", w.LPCWSTR),
                ("lpszClassName", w.LPCWSTR)]


class NOTIFYICONDATAW(ctypes.Structure):
    _fields_ = [("cbSize", w.DWORD), ("hWnd", w.HWND), ("uID", w.UINT), ("uFlags", w.UINT),
                ("uCallbackMessage", w.UINT), ("hIcon", w.HICON), ("szTip", w.WCHAR * 128),
                ("dwState", w.DWORD), ("dwStateMask", w.DWORD), ("szInfo", w.WCHAR * 256),
                ("uTimeoutOrVersion", w.UINT), ("szInfoTitle", w.WCHAR * 64), ("dwInfoFlags", w.DWORD),
                ("guidItem", ctypes.c_byte * 16), ("hBalloonIcon", w.HICON)]


user32.DefWindowProcW.argtypes = [w.HWND, w.UINT, w.WPARAM, w.LPARAM]
user32.DefWindowProcW.restype = LRESULT
user32.CreateWindowExW.argtypes = [w.DWORD, w.LPCWSTR, w.LPCWSTR, w.DWORD, ctypes.c_int, ctypes.c_int,
                                   ctypes.c_int, ctypes.c_int, w.HWND, w.HMENU, w.HINSTANCE, w.LPVOID]
user32.CreateWindowExW.restype = w.HWND
user32.RegisterClassW.argtypes = [ctypes.POINTER(WNDCLASSW)]
user32.LoadImageW.argtypes = [w.HINSTANCE, w.LPCWSTR, w.UINT, ctypes.c_int, ctypes.c_int, w.UINT]
user32.LoadImageW.restype = w.HANDLE
user32.LoadIconW.argtypes = [w.HINSTANCE, w.LPVOID]
user32.LoadIconW.restype = w.HICON
user32.CreatePopupMenu.restype = w.HMENU
user32.AppendMenuW.argtypes = [w.HMENU, w.UINT, ctypes.c_size_t, w.LPCWSTR]
user32.TrackPopupMenu.argtypes = [w.HMENU, w.UINT, ctypes.c_int, ctypes.c_int, ctypes.c_int, w.HWND, w.LPVOID]
user32.PostMessageW.argtypes = [w.HWND, w.UINT, w.WPARAM, w.LPARAM]
user32.GetMessageW.argtypes = [ctypes.POINTER(w.MSG), w.HWND, w.UINT, w.UINT]
user32.DestroyMenu.argtypes = [w.HMENU]
user32.SetForegroundWindow.argtypes = [w.HWND]
user32.MessageBoxW.argtypes = [w.HWND, w.LPCWSTR, w.LPCWSTR, w.UINT]
shell32.Shell_NotifyIconW.argtypes = [w.DWORD, ctypes.POINTER(NOTIFYICONDATAW)]
kernel32.GetModuleHandleW.restype = w.HMODULE

NIM_ADD, NIM_MODIFY, NIM_DELETE = 0, 1, 2
NIF_MESSAGE, NIF_ICON, NIF_TIP, NIF_INFO = 0x1, 0x2, 0x4, 0x10
WM_APP_TRAY = 0x8001
WM_CLOSE, WM_DESTROY, WM_NULL = 0x0010, 0x0002, 0x0000
WM_LBUTTONDBLCLK, WM_RBUTTONUP = 0x0203, 0x0205
MF_STRING, MF_SEPARATOR = 0x0, 0x800
TPM_RETURNCMD, TPM_RIGHTBUTTON, TPM_BOTTOMALIGN = 0x100, 0x2, 0x20

_state = {"hwnd": None, "nid": None, "items": [], "on_default": None, "thread": None, "proc": None}


def message_box(text, title, flags=0x40):
    """Messaggio di Windows in primo piano (0x40 informazione, 0x30 avviso, 0x10 errore; +0x4 Si'/No)."""
    return user32.MessageBoxW(None, text, title, flags | 0x40000 | 0x1000)   # TOPMOST + SYSTEMMODAL


def _run_safe(fn):
    if fn:
        threading.Thread(target=fn, daemon=True).start()


def _show_menu(hwnd):
    menu = user32.CreatePopupMenu()
    for i, it in enumerate(_state["items"], 1):
        if it is None:
            user32.AppendMenuW(menu, MF_SEPARATOR, 0, None)
        else:
            user32.AppendMenuW(menu, MF_STRING, i, it[0])
    pt = w.POINT()
    user32.GetCursorPos(ctypes.byref(pt))
    user32.SetForegroundWindow(hwnd)     # senza questo il menu non si chiude cliccando altrove
    cmd = user32.TrackPopupMenu(menu, TPM_RETURNCMD | TPM_RIGHTBUTTON | TPM_BOTTOMALIGN, pt.x, pt.y, 0, hwnd, None)
    user32.PostMessageW(hwnd, WM_NULL, 0, 0)
    user32.DestroyMenu(menu)
    if cmd and 0 < cmd <= len(_state["items"]) and _state["items"][cmd - 1]:
        _run_safe(_state["items"][cmd - 1][1])


def _wndproc(hwnd, msg, wparam, lparam):
    if msg == WM_APP_TRAY:
        ev = lparam & 0xFFFF
        if ev == WM_LBUTTONDBLCLK:
            _run_safe(_state["on_default"])
        elif ev == WM_RBUTTONUP:
            _show_menu(hwnd)
        return 0
    if msg == _state.get("taskbar_created"):       # Explorer riavviato: l'icona va rimessa
        if _state["nid"] is not None:
            _state["nid"].uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP
            shell32.Shell_NotifyIconW(NIM_ADD, ctypes.byref(_state["nid"]))
        return 0
    if msg == WM_CLOSE:
        user32.DestroyWindow(hwnd)
        return 0
    if msg == WM_DESTROY:
        if _state["nid"] is not None:
            shell32.Shell_NotifyIconW(NIM_DELETE, ctypes.byref(_state["nid"]))
        user32.PostQuitMessage(0)
        return 0
    return user32.DefWindowProcW(hwnd, msg, wparam, lparam)


def _loop(icon_path, tip, ready):
    hinst = kernel32.GetModuleHandleW(None)
    proc = WNDPROC(_wndproc)
    _state["proc"] = proc                          # deve restare vivo finche' c'e' la finestra
    wc = WNDCLASSW()
    wc.lpfnWndProc = proc
    wc.hInstance = hinst
    wc.lpszClassName = "CatorwebBroadcasterTray"
    user32.RegisterClassW(ctypes.byref(wc))
    _state["taskbar_created"] = user32.RegisterWindowMessageW("TaskbarCreated")
    hwnd = user32.CreateWindowExW(0, wc.lpszClassName, "Catorweb Broadcaster", 0, 0, 0, 0, 0,
                                  None, None, hinst, None)
    _state["hwnd"] = hwnd
    hicon = None
    if icon_path:
        hicon = user32.LoadImageW(None, str(icon_path), 1, 0, 0, 0x10 | 0x40)   # IMAGE_ICON, FROMFILE|DEFAULTSIZE
    if not hicon:
        hicon = user32.LoadIconW(None, ctypes.c_void_p(32512))               # IDI_APPLICATION
    nid = NOTIFYICONDATAW()
    nid.cbSize = ctypes.sizeof(NOTIFYICONDATAW)
    nid.hWnd = hwnd
    nid.uID = 1
    nid.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP
    nid.uCallbackMessage = WM_APP_TRAY
    nid.hIcon = hicon
    nid.szTip = tip[:127]
    _state["nid"] = nid
    shell32.Shell_NotifyIconW(NIM_ADD, ctypes.byref(nid))
    ready.set()
    msg = w.MSG()
    while user32.GetMessageW(ctypes.byref(msg), None, 0, 0) > 0:
        user32.TranslateMessage(ctypes.byref(msg))
        user32.DispatchMessageW(ctypes.byref(msg))


def start(icon_path, tip, items, on_default):
    """Mette l'icona vicino all'orologio (in un thread suo, con il suo ciclo di messaggi)."""
    _state["items"] = items
    _state["on_default"] = on_default
    ready = threading.Event()
    t = threading.Thread(target=_loop, args=(icon_path, tip, ready), daemon=True, name="tray")
    _state["thread"] = t
    t.start()
    ready.wait(5)


def set_tip(text):
    nid = _state["nid"]
    if nid is None:
        return
    nid.szTip = text[:127]
    nid.uFlags = NIF_TIP
    shell32.Shell_NotifyIconW(NIM_MODIFY, ctypes.byref(nid))


def balloon(title, text):
    """Fumetto vicino all'orologio (notifica di Windows)."""
    nid = _state["nid"]
    if nid is None:
        return
    nid.szInfoTitle = title[:63]
    nid.szInfo = text[:255]
    nid.dwInfoFlags = 0x1                      # NIIF_INFO
    nid.uFlags = NIF_INFO
    shell32.Shell_NotifyIconW(NIM_MODIFY, ctypes.byref(nid))


def stop():
    """Toglie l'icona (da chiamare prima di uscire, altrimenti resta un'icona 'fantasma')."""
    if _state["hwnd"]:
        user32.PostMessageW(_state["hwnd"], WM_CLOSE, 0, 0)
        if _state["thread"]:
            _state["thread"].join(2)
