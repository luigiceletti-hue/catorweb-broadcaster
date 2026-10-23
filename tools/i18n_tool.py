"""Traduzione dell'interfaccia di Catorweb Broadcaster (edizione).

I testi italiani restano la fonte. Questo strumento trova i pezzi di testo
visibile in un file HTML (testo del markup, attributi title/placeholder/
aria-label, stringhe JavaScript spezzate su tag HTML e ${...}) e:

  extract  <file.html> <dizionario.json>   aggiunge al dizionario i testi nuovi (valore "")
  apply    <file.html> <dizionario.json> <uscita.html>
                                           scrive la pagina tradotta; i testi senza
                                           traduzione restano in italiano (elencati)

Si traduce solo il TESTO SCRITTO NEL CODICE, mai i dati (titoli dei brani,
artisti, nomi delle categorie): quelli arrivano dal server a pagina aperta.
Nel dizionario le chiavi sono il pezzo cosi' com'e' nel sorgente (con \\n e \\'
come scritti nel JavaScript); le traduzioni sono testo normale con \\n per
andare a capo: le virgolette vengono protette in automatico.
"""
import json, re, sys

# stringa JS che sembra testo: due parole, una lettera accentata o una parola
# con l'iniziale maiuscola (anche dopo un simbolo: "● Attivo", "Lun")
WORDY = re.compile(r"[a-zà-ÿ] [a-zà-ÿ]|[àèéìòù]|(?:^|[^\w])[A-ZÀ-Ý][a-zà-ÿ]{2,}")
ATTR = re.compile(r"""\b(?:title|placeholder|aria-label)=(["'])(.*?)\1""")


def _looks_text(s):
    t = s.strip()
    if not t or not re.search(r"[A-Za-zÀ-ÿ]{2}", t):
        return False
    if t.startswith(("http", "/api/", "var(--", "#", ".", "<", "data:")) or "=>" in t:
        return False
    if re.search(r"[{};]|:\s*\d+px|\bclass=|\bonclick=|\bstyle=", t):
        return False
    if " " not in t and not re.fullmatch(r"[^\w]*(?:[A-ZÀ-Ý][a-zà-ÿ]{2,}|[a-zà-ÿ]{3,})[^\w]*", t):
        return False     # identificatori, classi css, chiavi
    return True


def _fragments(src):
    """(inizio, fine, testo, tipo) per ogni pezzo di testo. tipo = 'html' (testo o
    attributo del markup) oppure il delimitatore della stringa JS (' " `)."""
    out = []
    # blocchi <script> e <style>
    blocks = [(m.start(1), m.end(1), "js") for m in re.finditer(r"<script[^>]*>([\s\S]*?)</script>", src)]
    blocks += [(m.start(1), m.end(1), "css") for m in re.finditer(r"<style[^>]*>([\s\S]*?)</style>", src)]
    blocks.sort()

    def in_block(pos):
        for a, b, k in blocks:
            if a <= pos < b:
                return k
        return None

    # markup: testo tra tag e attributi
    for m in re.finditer(r">([^<>]+)<", src):
        if in_block(m.start(1)) is None:
            out.append((m.start(1), m.end(1), m.group(1), "html"))
    for m in re.finditer(r'\b(?:title|placeholder|aria-label|label)="([^"]*)"', src):   # label: <optgroup>
        if in_block(m.start(1)) is None:
            out.append((m.start(1), m.end(1), m.group(1), "html"))

    # JavaScript: stringhe, spezzate su tag HTML e ${...}; dentro ${...} si
    # cercano altre stringhe (es. `${ok ? '● Collegato' : '● Scollegato'}`)
    def scan_js(js, a):
        i = 0
        while i < len(js):
            c = js[i]
            if js.startswith("//", i):                       # commento di riga
                j = js.find("\n", i); i = len(js) if j < 0 else j; continue
            if js.startswith("/*", i):
                j = js.find("*/", i + 2); i = len(js) if j < 0 else j + 2; continue
            if c in "'\"`":
                j = i + 1; depth = 0
                while j < len(js):
                    if js[j] == "\\":
                        j += 2; continue
                    if c == "`" and js.startswith("${", j):
                        depth += 1; j += 2; continue
                    if c == "`" and depth and js[j] == "}":
                        depth -= 1; j += 1; continue
                    if js[j] == c and depth == 0:
                        break
                    if c != "`" and js[j] == "\n":
                        break
                    j += 1
                body_start, body = a + i + 1, js[i + 1:j]
                if c == "`" or WORDY.search(body):
                    # spezza su ${...} (anche annidati) e tag HTML
                    pos = 0
                    for piece in re.finditer(r"\$\{(?:[^{}]|\{(?:[^{}]|\{[^{}]*\})*\})*\}|<[^<>]*>", body):
                        out.append((body_start + pos, body_start + piece.start(), body[pos:piece.start()], c))
                        if piece.group(0).startswith("${"):
                            scan_js(piece.group(0)[2:-1], body_start + piece.start() + 2)
                        elif piece.group(0).startswith("<"):
                            # ${...} dentro un tag: anche li' possono esserci stringhe
                            for em in re.finditer(r"\$\{((?:[^{}]|\{(?:[^{}]|\{[^{}]*\})*\})*)\}", piece.group(0)):
                                scan_js(em.group(1), body_start + piece.start() + em.start(1))
                            # title="..." scritti dentro un tag nella stringa JS
                            for am in ATTR.finditer(piece.group(0)):
                                if "${" in am.group(2):
                                    continue
                                a0 = body_start + piece.start() + am.start(2)
                                out.append((a0, a0 + len(am.group(2)), am.group(2), "attr" + c + am.group(1)))
                        pos = piece.end()
                    out.append((body_start + pos, body_start + len(body), body[pos:], c))
                i = j + 1
                continue
            i += 1

    for a, b, kind in blocks:
        if kind == "js":
            scan_js(src[a:b], a)
    res = []
    for s, e, t, k in out:
        lead = len(t) - len(t.lstrip()); trail = len(t) - len(t.rstrip())
        core = t.strip()
        if _looks_text(core):
            res.append((s + lead, e - trail, core, k))
    return res


def _key(core, kind):
    return re.sub(r"\s+", " ", core) if kind == "html" else core



def extract(html_path, dict_path):
    src = open(html_path, encoding="utf-8").read()
    try:
        d = json.load(open(dict_path, encoding="utf-8"))
    except FileNotFoundError:
        d = {}
    new = 0
    for s, e, core, kind in _fragments(src):
        k = _key(core, kind)
        if k not in d:
            d[k] = ""; new += 1
    json.dump(d, open(dict_path, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    print(f"{new} testi nuovi, {len(d)} in tutto")


def _escape(text, kind):
    if kind == "html":
        return text.replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")
    if kind.startswith("attr"):
        # attributo HTML (virgolette kind[5]) dentro una stringa JS (delimitatore kind[4])
        js_delim, attr_q = kind[4], kind[5]
        text = text.replace(attr_q, "&quot;" if attr_q == '"' else "&#39;")
        return _escape(text, js_delim)
    # testo normale -> dentro una stringa JS con delimitatore 'kind'
    out = re.sub(r"(?<!\\)" + re.escape(kind), "\\" + kind, text)
    if kind == "`":
        out = out.replace("${", "\\${")
    return out


def apply(html_path, dict_path, out_path):
    src = open(html_path, encoding="utf-8").read()
    d = json.load(open(dict_path, encoding="utf-8"))
    missing = set()
    parts, last = [], 0
    for s, e, core, kind in sorted(_fragments(src)):
        if s < last:
            continue
        tr = d.get(_key(core, kind))
        if tr is None or tr == "":
            if tr == "":
                missing.add(_key(core, kind))
            continue
        if tr == "=":                      # "=" = resta uguale (nome proprio, termine tecnico)
            continue
        parts.append(src[last:s]); parts.append(_escape(tr, kind)); last = e
    parts.append(src[last:])
    result = "".join(parts)
    # "raw:<pezzo di sorgente>": sostituzione esatta per i pochi casi che lo
    # scanner non isola (testo dentro onclick, title con ${...} dentro)
    for k, v in d.items():
        if k.startswith("raw:"):
            if k[4:] not in result:
                print("   ! raw non trovato:", k[4:80])
            result = result.replace(k[4:], v)
    open(out_path, "w", encoding="utf-8").write(result)
    print(f"scritto {out_path}; senza traduzione: {len(missing)}")
    for m in sorted(missing)[:40]:
        print("   -", m[:90])


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "extract":
        extract(sys.argv[2], sys.argv[3])
    elif cmd == "apply":
        apply(sys.argv[2], sys.argv[3], sys.argv[4])
