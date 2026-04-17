# Codex Hand-off Template (after sheet acceptance)

Use after walk / attack / dash (and optional turn) sheets have all been
generated, nukki'd, and passed QA checklists (`checklists.md`).

Runtime integration rules live in `AGENTS.md`. This template is the
request payload from Claude to Codex.

---

```
New assets ready for runtime integration.

Generated files:
- items/[name]_boss_sheet.png
- items/[name]_boss_attack.png
- items/[name]_boss_dash.png          # if dash sheet was made
- items/[name]_boss_turn.png          # if turn sheet was made (optional aux)

Please integrate per AGENTS.md:

- Add [boss name] sprite loader / render / trigger wiring in pingfighter.py
- Walk / attack / dash (and turn, if present) must share body scale computed
  from the walking sheet — do NOT let per-sheet trim-and-rescale change
  apparent body size (see AGENTS.md "Runtime Performance Rules")
- Minimize repeated runtime preprocessing; prefer lazy-load and cached
  frame data
- Attack motion triggers on actual ball-hit timing
- Dash motion triggers on actual dash-start timing
- If a turn sheet exists, use runtime priority
  dash > attack > turn-transition > walk > idle; turn plays only during
  brief facing changes and does not replace the main walking cycle
- After integration, run `py -3 -m py_compile pingfighter.py entities\\[name]_boss_sprite.py`
- Run one headless sprite-load smoke test and one in-game visual check
```
