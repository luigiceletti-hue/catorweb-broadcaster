"""Messaggi del server Python (errori e conferme mostrati nell'app) da tradurre.

  extract <server.py> <server_en.json>   aggiunge i pezzi nuovi (valore "")

Prende le stringhe (anche f-string, spezzate su {...}) che sembrano frasi
italiane, salta docstring e pagine HTML intere. A runtime il server sostituisce
questi pezzi dentro "error"/"msg" delle risposte JSON (vedi _tr_msg).
"""
import io, json, re, sys, tokenize

IT = re.compile(r"\b(il|lo|la|le|gli|di|da|non|del|della|dei|nel|nella|per|con|una|uno|brani|brano|"
                r"coda|onda|errore|nessun\w*|file|cartella|categoria|trovat\w|obbligatori\w|"
                r"già|può|è|sul|sulla|alla|al|ai|in)\b", re.I)


def extract(py_path, dict_path):
    src = open(py_path, encoding="utf-8").read()
    try:
        d = json.load(open(dict_path, encoding="utf-8"))
    except FileNotFoundError:
        d = {}
    toks = list(tokenize.generate_tokens(io.StringIO(src).readline))
    new = 0
    for i, t in enumerate(toks):
        if t.type != tokenize.STRING:
            continue
        prev = toks[i - 1] if i else None
        if prev is not None and prev.type in (tokenize.INDENT, tokenize.NEWLINE, tokenize.NL, tokenize.DEDENT):
            continue                                   # docstring / stringa da sola
        m = re.match(r"(?is)^([rbuf]*)('''|\"\"\"|'|\")(.*)\2$", t.string)
        if not m:
            continue
        prefix, body = m.group(1).lower(), m.group(3)
        if len(body) > 300 or "<" in body or "b" in prefix:
            continue
        pieces = re.split(r"\{[^{}]*\}", body) if "f" in prefix else [body]
        for p in pieces:
            p = p.strip(" :—-·,.")
            if len(p) < 4 or not re.search(r"[A-Za-zÀ-ÿ]{3}", p):
                continue
            if not (IT.search(p) or re.search(r"[àèéìòù]", p)):
                continue
            if p not in d:
                d[p] = ""; new += 1
    json.dump(d, open(dict_path, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    print(f"{new} nuovi, {len(d)} in tutto")


if __name__ == "__main__":
    extract(sys.argv[2], sys.argv[3])
