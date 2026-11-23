"""Phase 2 (with system prompt; made from Phase 1 run.py by make_run2.py). Phase 1 baseline: ask OEL's 3 chat models the 22 survival-llm questions + 8 held-out questions.

Runs the real llama-cli exactly as OEL's chat launchers do (`-m <model> -c 4096`, no system prompt,
default sampler), plus only: -st (one turn, then exit), -p <question> (the first user message),
-s <seed> (repeatable), -n 2048 (answer cap). Python 3.9 stdlib. Resumable: finished rows are kept.

Usage (on the Mac mini, in ~/holding/2026-11-22-oel-ai-safety):
  python3 run.py OUTDIR
Stop: kill "$(cat run.pid)"   (run.py writes its own pid there; on SIGTERM it kills its llama-cli child and exits 143)
"""
import json, os, re, signal, subprocess, sys, time, importlib.util

P2 = os.path.dirname(os.path.abspath(__file__))
HERE = os.path.expanduser("~/holding/2026-11-22-oel-ai-safety")  # engine, models, questions: Phase 1 files, unchanged
import hashlib
SYS = open(os.path.join(P2, "prompt.txt")).read()
SYS_SHA = hashlib.sha256(SYS.encode()).hexdigest()
assert SYS_SHA == "28104c250dbded8e9ac479c8ba8f8186b23d0e9ca64db5fa1567d7f5aa5a72dd", SYS_SHA
USE_SYS = os.environ.get("NOSYS") != "1"
OUT = os.path.join(P2, sys.argv[1])
ENGINE = os.path.join(HERE, "engine/llama-b12638/llama-cli")
MODELS = {  # file -> sha256 from Hugging Face (setup.sh checked each)
    "Llama-3.2-3B-Instruct-Q4_K_M.gguf": "6c1a2b41161032677be168d354123594c0e6e67d2b9227c84f296ad037c728ff",
    "Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf": "7b064f5842bf9532c91456deda288a1b672397a54fa729aa665952863033557c",
    "Qwen2.5-7B-Instruct-Q4_K_M.gguf": "65b8fcd92af6b4fefa935c625d1ac27ea29dcb6ee14589c55a8f115ceaaa1423",
}
SEEDS = [1, 2, 3]
ONLY = os.environ.get("ONLY_QIDS")  # reproduction check only
PER_ANSWER_SECS = 300
RUN_LIMIT_SECS = 3 * 3600
CAP = 2048

q22 = json.load(open(os.path.join(HERE, "questions22.json")))["questions"]
spec = importlib.util.spec_from_file_location("heldout", os.path.join(HERE, "heldout.py"))
ho = importlib.util.module_from_spec(spec); spec.loader.exec_module(ho)
ITEMS = [("main", i, x["q"]) for i, x in enumerate(q22)] + [("heldout", i, x["q"]) for i, x in enumerate(ho.HELDOUT)]
if ONLY: ITEMS = [t for t in ITEMS if t[0] == "main" and str(t[1]) in ONLY.split(",")]; SEEDS = [1]

ANSI = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")


def parse(stdout, question):
    text = ANSI.sub("", stdout)
    lines = text.split("\n")
    start = next((i for i, l in enumerate(lines) if l.startswith("> ")), None)
    end = next((i for i, l in enumerate(lines) if l.startswith("[ Prompt:")), None)
    if start is None or end is None or end < start:
        return None, None
    first = lines[start][2:]
    if first.strip() != question.strip():
        return None, None
    answer = "\n".join(lines[start + 1:end]).strip()
    m = re.search(r"Generation:\s*([\d.]+)\s*t/s", lines[end])
    return answer, (float(m.group(1)) if m else None)


CHILD = None


def stop(signum, frame):
    if CHILD is not None and CHILD.poll() is None:
        CHILD.kill()
    sys.exit(143)


def main():
    signal.signal(signal.SIGTERM, stop)
    open(os.path.join(P2, "run.pid"), "w").write(str(os.getpid()))
    os.makedirs(OUT, exist_ok=True)
    t0 = time.time()
    for model, sha in MODELS.items():
        path = os.path.join(OUT, model.replace(".gguf", "") + ".jsonl")
        done = set()
        if os.path.exists(path):
            for line in open(path):
                r = json.loads(line)
                done.add((r["set"], r["qid"], r["seed"]))
        with open(path, "a") as f:
            for seed in SEEDS:
                for qset, qid, q in ITEMS:
                    if (qset, qid, seed) in done:
                        continue
                    if time.time() - t0 > RUN_LIMIT_SECS:
                        print("RUN LIMIT reached, stopping", flush=True)
                        sys.exit(4)
                    cmd = [ENGINE, "-m", os.path.join(HERE, "models", model), "-c", "4096",
                           *(["-sys", SYS] if USE_SYS else []), "-st", "-p", q, "-s", str(seed), "-n", str(CAP)]
                    s = time.time()
                    global CHILD
                    CHILD = subprocess.Popen(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                             stderr=subprocess.PIPE, text=True)
                    try:
                        out, err = CHILD.communicate(timeout=PER_ANSWER_SECS)
                        rc, timed_out = CHILD.returncode, False
                    except subprocess.TimeoutExpired:
                        CHILD.kill()
                        out, err = CHILD.communicate()
                        rc, timed_out = None, True
                    CHILD = None
                    secs = round(time.time() - s, 1)
                    answer, rate = parse(out, q)
                    row = {"model": model, "sha256": sha, "engine": "b12638-1014775c8", "sys_sha256": SYS_SHA if USE_SYS else None, "set": qset, "qid": qid,
                           "seed": seed, "q": q, "answer": answer, "gen_tps": rate, "secs": secs, "rc": rc,
                           "timed_out": timed_out, "parse_ok": answer is not None,
                           "raw_tail": None if answer is not None else ANSI.sub("", out)[-1500:]}
                    f.write(json.dumps(row) + "\n"); f.flush()
                    print(f"{model[:22]} s{seed} {qset}{qid:02d} rc={rc} {secs}s parse={answer is not None}", flush=True)


if __name__ == "__main__":
    main()
