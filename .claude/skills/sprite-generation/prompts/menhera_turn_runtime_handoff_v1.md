# Menhera Turn Runtime Hand-off V1

Use this after the new Menhera turn animation has passed asset-side QA and we
need Codex/runtime work to adopt it safely.

Important:
- Do NOT drop the new candidate straight into `items/menhera_boss_turn.png`
  without updating the runtime loader first.
- `entities/menhera_boss_sprite.py` still expects the old angle-chart turn
  format and still has visible turn playback disabled.

Current runtime state to account for:
- `entities/menhera_boss_sprite.py:29`
  `RENDER_TURN_FRAMES = False`
- `entities/menhera_boss_sprite.py:54`
  `TURN_GRID_COLS = 7`
- `entities/menhera_boss_sprite.py:55`
  `TURN_GRID_ROWS = 2`
- `entities/menhera_boss_sprite.py:60`
  `TURN_ANGLE_STEPS = (90, 75, 60, 45, 30, 15, 0, -15, -30, -45, -60, -75, -90)`

That runtime format no longer matches the accepted Menhera turn design.

---

```text
New Menhera turn art is ready for runtime integration, but this is NOT the old
angle-chart turn format.

Accepted design:
- front-facing characterful direction-change gesture
- 8-frame loopable turn sequence
- not a +90 -> 0 -> -90 angle chart
- walk stays frontal; turn appears only during brief facing changes

Accepted frame order:
- F1 = carry-in
- F2 = plant / compress
- F3 = wind-up
- F4 = peak
- F5 = release
- F6 = mid-arc retract
- F7 = settled walk-ready
- F8 = reuse of F1 for loop closure

Approved source frames:
- .tmp/menhera_turn_entry_f1_analysisdriven_v2.png
- .tmp/menhera_turn_entry_f2_analysisdriven_v1.png
- .tmp/menhera_turn_entry_f3_analysisdriven_v2.png
- .tmp/menhera_turn_peak_keypose_gemini_analysisdriven_v1.png
- .tmp/menhera_turn_recovery_f5_analysisdriven_v2.png
- .tmp/menhera_turn_recovery_f6_analysisdriven_v1.png
- .tmp/menhera_turn_recovery_f7_analysisdriven_v1.png
- F8 should reuse F1

Asset-side QA status:
- entry arc reads:
  carry-in -> plant/compress -> wind-up -> peak
- recovery arc reads:
  peak -> release -> mid-arc retract -> settled walk-ready
- F7 -> F8 loop reads naturally as settled -> next-step carry-in
- side-lock is stable across the accepted frames
- body-preserving scale parity with the walk anchor was maintained

Known accepted minor drift:
- F2 bow count drift
- F3 / F7 collar-bow drift
- some hair-volume fluctuation across frames
- these were judged acceptable at gameplay size and should NOT trigger another
  asset-regeneration round unless runtime playback reveals a new regression

Please integrate per AGENTS.md with these constraints:

1. Treat the new Menhera turn as an 8-frame front-facing gesture sequence,
   not an angle-indexed 7x2 / 13-angle turn chart.
2. Do NOT reuse the old `TURN_ANGLE_STEPS` selection model for this asset.
3. Keep stable left/right travel on the accepted frontal walk sheet.
4. Use turn playback only during short facing changes.
5. Preserve the existing hop / pivot accent behavior unless there is a clear
   reason to retime it.
6. Keep turn body size matched to the walking-sheet body read; do not let the
   new turn read smaller than walk in gameplay.
7. If needed, export or assemble a runtime-ready turn sheet from the approved
   source frames before wiring it to `items/menhera_boss_turn.png`.
8. Only re-enable visible turn playback after the loader matches the new asset
   format and one real gameplay sanity check passes.

Recommended runtime tasks:
- update `entities/menhera_boss_sprite.py` to parse the new Menhera turn format
- remove or bypass old angle-chart assumptions for Menhera's turn playback
- keep a safe fallback path: if the new turn asset is missing or rejected at
  load time, remain on hop-only frontal walk transitions
- run:
  `py -3 -m py_compile pingfighter.py entities\\menhera_boss_sprite.py`
- run one headless sprite-load smoke test
- run one real in-game visual check focused on:
  - walk -> turn -> walk readability
  - turn body scale vs walk
  - no accidental stable-walk replacement
  - no stage-entry hitch regression
```
