"""Carica i file dell'edizione su GitHub senza Git: blob -> albero -> commit -> main (API via gh).
Esclusi: build/, _prova/, liquidsoap/, github/, __pycache__, *.zip, *.pyc, il PDF del manuale."""
import base64, json, os, subprocess, sys, tempfile
GH = r"C:\Program Files\GitHub CLI\gh.exe"
REPO = "luigiceletti-hue/catorweb-broadcaster"
ROOT = r"I:\CatorwebPC_Edizione"
SKIP_DIRS = {"build", "_prova", "liquidsoap", "github", "__pycache__", ".git", "confronto"}   # confronto: prezzi da verificare
MSG = sys.argv[1] if len(sys.argv) > 1 else "Catorweb Broadcaster 2.11"

def api(method, path, body=None):
    args = [GH, "api", "-X", method, f"repos/{REPO}/{path}"]
    tmp = None
    if body is not None:
        tmp = tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8")
        json.dump(body, tmp); tmp.close()
        args += ["--input", tmp.name]
    r = subprocess.run(args, capture_output=True, text=True, encoding="utf-8")
    if tmp: os.unlink(tmp.name)
    if r.returncode != 0:
        sys.exit(f"ERRORE {method} {path}: {r.stderr or r.stdout}")
    return json.loads(r.stdout) if r.stdout.strip() else {}

files = []
for d, dirs, fs in os.walk(ROOT):
    dirs[:] = [x for x in dirs if x not in SKIP_DIRS and not x.startswith("_")]   # _prova, _nuovo...: copie di prova
    for f in fs:
        if f.endswith((".pyc", ".zip", ".pdf")):
            continue
        files.append(os.path.relpath(os.path.join(d, f), ROOT).replace("\\", "/"))
files.sort()
tree = []
for i, f in enumerate(files, 1):
    data = open(os.path.join(ROOT, f), "rb").read()
    blob = api("POST", "git/blobs", {"content": base64.b64encode(data).decode(), "encoding": "base64"})
    tree.append({"path": f, "mode": "100644", "type": "blob", "sha": blob["sha"]})
    print(f"{i:3}/{len(files)}  {f}", flush=True)
parent = api("GET", "git/ref/heads/main")["object"]["sha"]
t = api("POST", "git/trees", {"tree": tree})           # senza base_tree: sostituisce il README iniziale
c = api("POST", "git/commits", {"message": MSG, "tree": t["sha"], "parents": [parent]})
api("PATCH", "git/refs/heads/main", {"sha": c["sha"]})
print("\ncommit", c["sha"][:10], "-", len(files), "file su main")
