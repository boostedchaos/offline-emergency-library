# Chat AI safety, phase 2: one system prompt (it did not pass)

Start with `RESULTS.txt`. The pass rule is `DECISION-RULE.txt`, written before any answer was made; the prompt is `prompt.txt`.
Questions, official lines and survival-llm controls (MIT, credit Ronny Fernandez) are in `../ai-safety-baseline/`.

- `results/base`, `results/sys`: 270 answers without and 270 with the prompt (same day, same machine).
- `judging/`: the blind batches, the judges' and skeptics' JSON. `key.json` maps each label to its arm, model and seed
  (the judges did not have it). `scored-rows.json`, `score-output.txt`, `analysis-output.txt`: the scores.
- Scripts: `run2.py` (from `../ai-safety-baseline/run.py` by `make_run2.py`), `make_batches2.py`, `make_skeptic2.py`, `score2.py`.
  Their folder names are ours; change them before a re-run.
- Copied from our notes with machine and people names replaced.
