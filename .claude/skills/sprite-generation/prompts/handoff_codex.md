# Codex Hand-off Template (after sheet acceptance)

Use after walk / attack / dash (and optional turn) sheets have all been
generated, nukki'd, and passed QA checklists (`checklists.md`).

Runtime integration rules live in `AGENTS.md`. This template is the
request payload from Claude to Codex.

Hard precondition:

- Do NOT use this handoff if the candidate walk sheet failed frontal-
  neutrality QA.
- If the new walk is more side-biased than the previous accepted walk,
  restore / keep the older walk and regenerate the art instead of
  handing the candidate to Codex.
- Do NOT use runtime facing remaps, blind sprite flips, or travel-
  direction hacks as a substitute for rejected walk art.

---

```text
New assets ready for runtime integration.

Generated files:
- items/[name]_boss_sheet.png
- items/[name]_boss_attack.png
- items/[name]_boss_dash.png          # if dash sheet was made
- items/[name]_boss_turn.png          # if turn sheet was made (optional aux)

Please integrate per AGENTS.md:

- Add [boss name] sprite loader / render / trigger wiring in pingfighter.py
- Treat this walk sheet as accepted ONLY because it already passed the
  frontal-neutrality gate against the previous accepted walk
- Walk / attack / dash (and turn, if present) must share body scale computed
  from the walking sheet; do NOT let per-sheet trim-and-rescale change
  apparent body size (see AGENTS.md "Runtime Performance Rules")
- Minimize repeated runtime preprocessing; prefer lazy-load and cached
  frame data
- Attack motion triggers on actual ball-hit timing
- Dash motion triggers on actual dash-start timing
- Explicitly verify that stable left travel and stable right travel both
  still read as forward-facing in gameplay
- Do NOT remap left/right travel directions or apply blind walk-frame
  flips to rescue a side-biased walk sheet; if frontal read fails, kick
  it back to asset regeneration
- If a turn sheet exists, use runtime priority
  dash > attack > turn-transition > walk > idle; turn plays only during
  brief facing changes and does not replace the main walking cycle
- If the user intent is "walk stays frontal, direction changes get a
  small hop / pivot accent," visible turn-frame playback may be
  disabled while a hop-only runtime transition remains active
- After integration, run `py -3 -m py_compile pingfighter.py entities\\[name]_boss_sprite.py`
- Run one headless sprite-load smoke test and one in-game visual check
```
