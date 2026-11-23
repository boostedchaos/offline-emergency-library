"""Write blind judging batches for the 22 main questions (Phase 1).

Usage: python3 make_batches.py RESULTS_DIR SURVIVAL_LLM_DIR OUT_DIR
- RESULTS_DIR: our run.py output (*.jsonl), set == "main" rows only (held-out stays unjudged until Phase 2).
- SURVIVAL_LLM_DIR: survival-llm evals files at 7d1fe29 (results/*.jsonl, final-grades.json) for controls.
Each batch gets 1 known-bad control (survival-llm answer its skeptic upheld at severity 2-3) and
1 known-clean control (accuracy 3, severity 0). Labels are shuffled per question (seed 20261122);
key.json maps "<qid><label>" -> {"model", "seed"} or {"control": ...}.
"""
import json, os, random, re, string, sys

RES, SL, OUT = sys.argv[1:4]
HERE = os.path.dirname(os.path.abspath(__file__))
Q = json.load(open(os.path.join(HERE, "questions22.json")))["questions"]
BATCHES = [[0, 1, 2, 3, 4, 5], [6, 7, 8, 9, 10, 16], [11, 12, 13, 17, 18], [14, 15, 19, 20, 21]]
BAD = {0: ("granite4.2_3b", 2), 1: ("granite4.2_3b", 6), 2: ("granite4.2_3b", 12), 3: ("granite4.2_3b", 15)}
assert sorted(sum(BATCHES, [])) == list(range(22))

grades = json.load(open(os.path.join(SL, "final-grades.json")))


def sl_answer(model, qid):
    rows = [json.loads(l) for l in open(os.path.join(SL, "results", model + ".jsonl"))]
    assert rows[qid]["q"] == Q[qid]["q"], (model, qid)
    # drop every "Sources:" line (first or last) so the control does not stand out
    text = re.sub(r"\n+\**sources?:?\**.*\Z", "", rows[qid]["answer"].strip(), flags=re.I | re.S)
    return re.sub(r"(?im)^\**sources?:?\**[^\n]*\n?", "", text).strip()


def pick_clean(qids, rng):
    cands = sorted(k for k, g in grades.items() if g.get("acc") == 3 and g.get("sev") == 0 and int(k.split("|")[1]) in qids)
    return rng.choice(cands).split("|")


ours = {}
for name in sorted(os.listdir(RES)):
    if name.endswith(".jsonl"):
        for line in open(os.path.join(RES, name)):
            r = json.loads(line)
            if r["set"] == "main":
                ours.setdefault(r["qid"], []).append(r)

rng = random.Random(20261122)
os.makedirs(OUT, exist_ok=True)
key = {}
for b, qids in enumerate(BATCHES):
    cm, cq = pick_clean(qids, rng)
    cq = int(cq)
    bm, bq = BAD[b]
    parts = [f"# Judging batch {b}\n"]
    for qid in qids:
        items = [({"model": r["model"], "seed": r["seed"]}, r["answer"] if r["answer"] else "[no answer: the program printed nothing usable]") for r in ours.get(qid, [])]
        if qid == bq:
            items.append(({"control": "bad", "source": f"survival-llm {bm} q{bq}", "their_sev": grades[f'{bm}|{bq}']['sev']}, sl_answer(bm, bq)))
        if qid == cq:
            items.append(({"control": "clean", "source": f"survival-llm {cm} q{cq}"}, sl_answer(cm, cq)))
        rng.shuffle(items)
        parts.append(f"\n## Question {qid}: {Q[qid]['q']}\n\n**Official guidance:** {Q[qid]['gold']}\n")
        for i, (meta, ans) in enumerate(items):
            label = string.ascii_uppercase[i]
            key[f"{qid}{label}"] = meta
            parts.append(f"\n### Answer {label}\n\n{ans}\n")
    open(os.path.join(OUT, f"batch-{b}.md"), "w").write("".join(parts))
json.dump(key, open(os.path.join(OUT, "key.json"), "w"), indent=1)
n_ours = sum(1 for v in key.values() if "model" in v)
n_ctl = sum(1 for v in key.values() if "control" in v)
print(f"{len(BATCHES)} batches, {n_ours} of our answers, {n_ctl} controls")
