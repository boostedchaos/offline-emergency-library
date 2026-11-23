s=open('../2026-11-22-oel-ai-safety/run.py').read()
def rep(a,b):
    global s
    assert s.count(a)==1,(a,s.count(a)); s=s.replace(a,b)
rep('HERE = os.path.dirname(os.path.abspath(__file__))','P2 = os.path.dirname(os.path.abspath(__file__))\nHERE = os.path.expanduser("~/holding/2026-11-22-oel-ai-safety")  # engine, models, questions: Phase 1 files, unchanged\nimport hashlib\nSYS = open(os.path.join(P2, "prompt.txt")).read()\nSYS_SHA = hashlib.sha256(SYS.encode()).hexdigest()\nassert SYS_SHA == "28104c250dbded8e9ac479c8ba8f8186b23d0e9ca64db5fa1567d7f5aa5a72dd", SYS_SHA\nUSE_SYS = os.environ.get("NOSYS") != "1"')
rep('OUT = sys.argv[1]','OUT = os.path.join(P2, sys.argv[1])')
rep('os.path.join(HERE, "run.pid")','os.path.join(P2, "run.pid")')
rep('"-st", "-p", q,','*(["-sys", SYS] if USE_SYS else []), "-st", "-p", q,')
rep('"engine": "b12638-1014775c8",','"engine": "b12638-1014775c8", "sys_sha256": SYS_SHA if USE_SYS else None,')
rep('SEEDS = [1, 2, 3]','SEEDS = [1, 2, 3]\nONLY = os.environ.get("ONLY_QIDS")  # reproduction check only')
rep('for i, x in enumerate(ho.HELDOUT)]','for i, x in enumerate(ho.HELDOUT)]\nif ONLY: ITEMS = [t for t in ITEMS if t[0] == "main" and str(t[1]) in ONLY.split(",")]; SEEDS = [1]')
rep('"""Phase 1 baseline:','"""Phase 2 (with system prompt; made from Phase 1 run.py by make_run2.py). Phase 1 baseline:')
open('run2.py','w').write(s)
