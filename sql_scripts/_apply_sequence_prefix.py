"""Plan (and optionally apply) a sequence-number prefix scheme for sql_scripts.

Classifies each *.sql by its primary CREATE type for dependency-correct order:
  schema/migrate -> tables -> functions -> views -> data
Within each band, current alphabetical order is preserved, step 10 for headroom.

Run with no args = DRY RUN (prints plan, writes revert script, renames nothing).
Run with  --apply = performs `git mv` for each file.
"""
import os, re, sys, subprocess, glob

HERE = os.path.dirname(os.path.abspath(__file__))
APPLY = "--apply" in sys.argv

BANDS = [  # (band base, step, label)
    ("schema", 10, 10),
    ("tables", 100, 10),
    ("functions", 300, 10),
    ("views", 1000, 10),
    ("data", 5000, 10),
]
BASE = {"schema": 10, "tables": 100, "functions": 300, "views": 1000, "data": 5000}
STEP = 10

# already-prefixed?  NNNN_...
_PREFIXED = re.compile(r"^\d{4}_")

def classify(name, text):
    t = text.lower()
    n = name.lower()
    # schema / migrations FIRST so partition work runs before everything else
    if n.startswith("00_migrate") or "attach partition" in t or "create schema" in t:
        return "schema"
    if "create table" in t or "create unlogged table" in t:
        return "tables"
    if re.search(r"create\s+(or\s+replace\s+)?function", t) or n.startswith(("fn_", "get_root_cause")):
        return "functions"
    if re.search(r"create\s+(or\s+replace\s+)?(materialized\s+)?view", t):
        return "views"
    return "data"  # inserts/updates/registrations + bare-select/other

files = [os.path.basename(p) for p in glob.glob(os.path.join(HERE, "*.sql"))]
files = [f for f in files if not _PREFIXED.match(f)]   # skip already-prefixed
buckets = {k: [] for k in BASE}
empties = []
for name in sorted(files, key=str.lower):
    with open(os.path.join(HERE, name), "r", encoding="utf-8", errors="ignore") as fh:
        text = fh.read()
    if not text.strip():
        empties.append(name)                 # dead/empty -> leave as-is (runtime skips it)
        continue
    buckets[classify(name, text)].append(name)

def base_name(name):                          # strip an existing leading NN_ numeric prefix
    return re.sub(r"^\d+_", "", name)

plan = []  # (old, new)
order = ["schema", "tables", "functions", "views", "data"]
for band in order:
    seq = BASE[band]
    for name in buckets[band]:
        new = f"{seq:04d}_{base_name(name)}"
        plan.append((name, new))
        seq += STEP

# summary
print("=== plan summary ===")
for band in order:
    if buckets[band]:
        lo = f"{BASE[band]:04d}"
        print(f"  {band:10} {len(buckets[band]):3} files  (band {lo}+, step {STEP})")
print(f"  total: {len(plan)} renames")
if empties:
    print(f"  (skipped {len(empties)} empty file(s), left as-is: {', '.join(empties)})")
print()
print("=== first/last few ===")
for old, new in plan[:4] + [("...", "...")] + plan[-4:]:
    print(f"  {old}  ->  {new}")

# write revert script (new -> old) regardless, for safety
rev = os.path.join(HERE, "_revert_sequence_prefix.sh")
with open(rev, "w", encoding="utf-8", newline="\n") as fh:
    fh.write("#!/usr/bin/env bash\nset -e\ncd \"$(dirname \"$0\")\"\n")
    for old, new in plan:
        fh.write(f'git mv "{new}" "{old}"\n')
print(f"\nrevert script -> {rev}")

if not APPLY:
    print("\nDRY RUN — nothing renamed. Re-run with --apply to perform git mv.")
    sys.exit(0)

# apply: git mv for tracked files, plain os.rename for untracked
ok = err = 0
for old, new in plan:
    src, dst = os.path.join(HERE, old), os.path.join(HERE, new)
    if not os.path.exists(src):
        continue                                  # already moved
    r = subprocess.run(["git", "mv", old, new], cwd=HERE, capture_output=True, text=True)
    if r.returncode == 0:
        ok += 1
        continue
    if "not under version control" in r.stderr:
        try:
            os.rename(src, dst)
            ok += 1
        except OSError as e:
            err += 1
            print(f"  ERR {old} -> {new}: {e}")
    else:
        err += 1
        print(f"  ERR {old} -> {new}: {r.stderr.strip()}")
print(f"\nAPPLIED: {ok} renamed, {err} error(s).")
