# Emoji/Unicode picker: learned ranking (deferred)

Status: **logging live; trainer/eval deferred.** Step 1 (pick-event logging) is implemented and running — accumulating training data now. Everything downstream (offline trainer, learned weights, eval) is deferred until there's enough real data AND the current hand-weighted ranking proves insufficient. The trigger for building the trainer is "hand-tuning the weights in `W` can no longer express the ranking I want," which for a personal picker may never happen — the log is cheap insurance either way.

## Where things stand today (`unicode.lua`, commit `e998615`)

Ranking is already a small **feature-weighted linear model**, just with hand-set weights. Final score for a (query, row) pair:

```
score = matchScore(q, row)            -- mutually-exclusive tiers, best one wins
      + prio      * row._prio         -- curated/emoji vs bulk Unicode db
      + recency   * 0.5^(age/halflife)
      + frequency * ln(1 + count)
      + query_hist                    -- buildBoostMap: picks under this query prefix
```

- All weights live in one table, `W` (near `scoreToken`). Tune ranking there.
- `scoreToken` returns the MATCH component only (one tier: `literal_char` 1200 → `trigger` 1000 (query is a curated `;`-trigger, `;` optional) → `exact_text` 1000 → `prefix_text` 800 → `word_text` 600 → `phrase_sub` 500 → `substr_text` 400 → `prefix_sub` 300 → `substr_sub` 200 → `stem_sub` 150 → `subseq_text` 100). Within a text tier, a length penalty (`- (#t - #q)`) breaks ties toward shorter names.
- `scoreQuery` handles multi-token AND matching; still returns pure match.
- `personalBoost(choice, now)` applies the additive priors (`prio`/`recency`/`frequency`). `_last`/`_count` are stamped onto each choice by `sortChoicesByMRU` before the query callback runs.
- `makeQueryCallback` sums it all: `scoreQuery + personalBoost + buildBoostMap`.
- Pick history: `recordPick` (global MRU, `HISTORY_KEY`) and `recordQueryPick` (query-conditioned, `QUERY_HISTORY_KEY`), both via `hs.settings`.

**This split is the whole point of the substrate: `scoreQuery` = features, `personalBoost`/`W` = a weight vector. A learned model drops in by replacing the weights, not the architecture.**

## Decision: offline-train / online-infer. No FFI.

LTR splits into training (needs libraries) and inference (a dot product). Only training needs anything heavy, and it runs out-of-band.

- **Inference stays pure Lua in Hammerspoon.** `Σ wᵢ·fᵢ` over ~12 features is trivial; it's already what the picker does. HS embeds PUC-Lua 5.4 (not LuaJIT), so there is no built-in FFI, and pulling CPython / a native LTR lib in-process is a fragile yak-shave we explicitly rejected.
- **Training is a standalone Python script** (its own venv, whatever libs) that reads a pick log and emits a weight vector. The picker never imports it.
- Handoff is a tiny JSON of weights the picker loads at startup into `W`.

Rationale for not FFI'ing: buys in-process native calls we don't need, at a fragility cost that's especially steep inside the HS .app sandbox. See the FFI discussion in session history if re-litigating.

## Implementation sketch (when/if picked up)

### 1. Log pick events — DONE (`unicode.lua`)
Implemented as `logPick`, called from the picker's pick callback. Appends one JSONL line per pick to **`<hs.configdir>/picker-picks.jsonl`** (i.e. `~/.hammerspoon/picker-picks.jsonl` — a real dir; the repo lives at `~/.rc/hammerspoon`, so the log is out-of-repo). Best-effort: guarded so a log error never breaks a pick; empty-query (MRU-list) picks are skipped (no query = no ranking signal); a stale slate (query mismatch) is skipped.

Line schema (one JSON object per line):
```
{ "ts": <unix>, "query": "<lowercased>", "chosen": "<char>",
  "slate": [ { "char", "rank", "score",           // rank 1..K, final score
               "match",                             // scoreQuery match component
               "prio", "recency", "frequency",      // additive prior components
               "query_hist" }, … ] }                // buildBoostMap boost
```
- The **slate is the top-K shown rows** (`LOG_SLATE_K = 20`), not all matches — the deep tail was never seen, so it's noise as negatives.
- Feature **components are logged at pick time** (not just the summed score) because the time-dependent ones (`recency`/`frequency`/`query_hist`) can't be reconstructed from a later snapshot — this is what avoids train/serve skew.
- Components come from `boostComponents(choice, now)` (the decomposed `personalBoost`) + `scoreQuery` + the `buildBoostMap` result, captured in `makeQueryCallback` into the module-level `lastSlate` (only one picker open at a time).

Note the match component is currently logged as the single winning-tier scalar (e.g. 593 = `word_text` 600 − length penalty), NOT yet a one-hot over tiers. The trainer will need to re-expand it (see §2 crux) — or a later logging tweak could emit `match_tier` (the tier name) alongside the scalar. Deferred; the scalar + (query, char) is enough to recover the tier offline.

### 2. Offline trainer (Python, standalone script)
- Read the JSONL log. Each event → one query group: chosen row = positive, other shown rows = negatives.
- **Modeling subtlety (the crux):** the match tiers are currently a *mutually-exclusive categorical* taken as a max, not a sum. To learn them, represent match quality as a one-hot over which tier fired (learn one weight per tier) alongside the continuous features (length penalty, recency decay, frequency, query_hist, prio). Then the whole score genuinely is a linear model over that feature vector and standard LTR applies.
- **Objective:** pairwise (chosen > each non-chosen shown), i.e. a simplified RankNet / logistic-on-pairs, or point a gradient-boosted ranker (lightgbm `lambdarank`) at it. Start with plain **pairwise logistic regression** — interpretable, exports as a clean weight vector; boosted/neural models don't map back to a `W` table.
- **Position-bias caveat:** clicks are biased toward the top of the shown list. For a personal single-user tool this is probably ignorable at first; note it, don't over-engineer.

### 3. Robustness (the mechanisms raised in discussion)
Divergence on sparse single-user data is a solved problem — the cost is the harness, not the math. When implemented:
- **L2-regularize toward the current hand weights** (not toward zero) — the hand `W` is a strong prior; learning should nudge, not reset.
- **EMA the weight vector** across training runs so a noisy batch can't swing it.
- **LR decay** and **gradient clipping / trust region** to bound per-update movement.
- **Log every weight update** so drift is inspectable (a `W`-diff per retrain).
- Keep an easy **revert to hand weights** (the exported JSON is optional; absent → use in-code `W`).

### 4. Wire learned weights back in
- Picker loads `picker-weights.json` at startup if present; missing/malformed → fall back to the in-code `W` (never break the picker on a bad export).
- Retrain is a manual, occasional step (a CLI subcommand or a make target), not automatic.

## Offline evaluation (don't skip — this is where the real work is)
Before trusting learned weights, need a held-out eval so a retrain can't silently regress ranking:
- Metric: MRR / NDCG@k of the chosen item over held-out pick events.
- Golden regression set: the queries already in `tmp/stub_picker_test.lua` (`down`, `dwn`, `red x`, `thank you hands`, `raised hand`, `thinking`, `21b3`, `dagger`, `fire`, `·`, …) with their expected top rows — a learned model must not break these.
- Gate: only adopt exported weights that beat the current `W` on held-out MRR **and** pass the golden set.

The stub harness (`tmp/stub_picker_test.lua`, run with `/opt/homebrew/bin/lua` — note bare `lua` is shadowed by a shell function) already drives the real build + scoring path against real data; extend it into the eval.

## Open questions / deferred decisions
- Is per-user data volume ever enough to beat hand weights? Likely need weeks of picks. Until then this stays deferred.
- Query-conditioned history (`buildBoostMap`) is already the "safe learned component" (tabular, monotonic, can't diverge). Possibly the right move is to *extend that* (smarter prefix/decay handling) rather than learn the global weight vector at all — cheaper and lower-risk.
- Where should the trainer live — a subcommand of an existing CLI, or a one-off script under this repo? (Per global CLAUDE.md: prefer a CLI subcommand if the logic will recur.)

## When picking this up
Logging (§1) is already live and accumulating. Before writing any trainer, sanity-check the accrued `~/.hammerspoon/picker-picks.jsonl` — enough events, sane feature values, real ambiguous queries (not just single-result picks that teach nothing). Then start at §2 (trainer) → §3 (robustness) → offline eval as the gate. Don't adopt any learned weights that don't beat the hand `W` on held-out MRR and pass the golden regression set.
