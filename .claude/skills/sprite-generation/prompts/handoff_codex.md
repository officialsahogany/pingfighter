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
- godot/assets/sprites/bosses/[name]/[name]_boss_sheet.png
- godot/assets/sprites/bosses/[name]/[name]_boss_attack.png
- godot/assets/sprites/bosses/[name]/[name]_boss_dash.png    # if dash sheet was made
- godot/assets/sprites/bosses/[name]/[name]_boss_turn.png    # if turn sheet was made (optional aux)

Please integrate per AGENTS.md:

- Add [boss name] sprite loader / render / trigger wiring in the owning
  Godot module under `godot/scripts/`. Treat `pingfighter.py` as a frozen
  behavior reference only unless the user explicitly asks for legacy-source
  work.
- Treat this walk sheet as accepted ONLY because it already passed the
  frontal-neutrality gate against the previous accepted walk
- Walk / attack / dash (and turn, if present) must share body scale computed
  from the walking sheet; do NOT let per-sheet trim-and-rescale change
  apparent body size (see AGENTS.md "Runtime Performance Rules")
- **Cross-boss size standard: hit the Stage 3 Menhera body class.** Use
  the Godot boss renderer's canvas / source-rect / stage-scale settings
  so the in-game body read matches the accepted Menhera size class. The
  legacy Python reference used a `176 x 88` target frame canvas for this
  class; use that as a parity measurement, not as a reason to edit
  `pingfighter.py`. After install, run a side-by-side gameplay-size
  comparison vs Menhera (head height, face size, torso silhouette) and
  reject the integration as not done if the new boss reads materially
  smaller or larger. If the boss is an explicit size-class exception
  (Tauren-style large frame, Honglyeon-style tall vertical silhouette, or
  a design-led oversized / undersized concept), record the canvas /
  stage-scale override and design reason in the focused boss runtime contract
  or asset manifest AND in this hand-off before merging. Run §10 of
  `checklists.md` for the formal gate.
- Minimize repeated runtime preprocessing; prefer lazy-load and cached
  frame data
- Attack motion triggers on actual ball-hit timing
- Audit attack-vs-stun runtime keys using
  `docs/sprites/boss_sprite_runtime_contract.md`. A legacy key such as
  `boss_hit_sprite_sheet` means ball-contact attack, not a real stun
  reaction; do not wire it to `[name]_boss_stun.png`.
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
- After integration, run the repo-local Godot checks from `godot/`:
  `.\tools\run_headless_load_check.ps1` and `.\tools\run_warning_scan.ps1`
- Run one focused Godot sprite-load smoke test and one in-game visual check
```
