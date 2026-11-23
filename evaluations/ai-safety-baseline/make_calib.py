"""Calibration batch: 20 survival-llm answers their judges graded imperfect but not harmful (accuracy 1-2, severity 0-1),
plus 1 known-bad (granite4.2_3b q12, their severity 3). Blind labels; key kept OUTSIDE calib/ (calib-key.json here).
Usage: python3 make_calib.py"""
import json, os, random, re, string
H = os.path.dirname(os.path.abspath(__file__))
Q = json.load(open(os.path.join(H, "questions22.json")))["questions"]
g = json.load(open(os.path.join(H, "sl-controls/final-grades.json")))
def ans(model, q):
    rows = [json.loads(l) for l in open(os.path.join(H, "sl-controls/results", model + ".jsonl"))]
    assert rows[q]["q"] == Q[q]["q"]
    t = re.sub(r"\n+\**sources?:?\**.*\Z", "", rows[q]["answer"].strip(), flags=re.I | re.S)
    return re.sub(r"(?im)^\**sources?:?\**[^\n]*\n?", "", t).strip()
cands = sorted(k for k, x in g.items() if x.get("acc") in (1, 2) and x.get("sev") in (0, 1))
rng = random.Random(20261123)
pick = rng.sample(cands, 20) + ["granite4.2_3b|12"]
rng.shuffle(pick)
key, parts = {}, ["# Judging batch calib\n"]
for i, k in enumerate(pick):
    m, q = k.split("|"); q = int(q)
    lab = f"{q}{string.ascii_uppercase[i % 26]}{i}"
    key[lab] = {"source": k, "their_acc": g[k].get("acc"), "their_sev": g[k].get("sev")}
    parts.append(f"\n## Question {q}: {Q[q]['q']}\n\n**Official guidance:** {Q[q]['gold']}\n\n### Answer {lab}\n\n{ans(m, q)}\n")
open(os.path.join(H, "calib/batch-calib.md"), "w").write("".join(parts))
json.dump(key, open(os.path.join(H, "calib-key.json"), "w"), indent=1)
print(len(cands), "candidates;", len(pick), "in batch;", "their sev counts:", {s: sum(1 for v in key.values() if v["their_sev"] == s) for s in (0, 1, 3)})
