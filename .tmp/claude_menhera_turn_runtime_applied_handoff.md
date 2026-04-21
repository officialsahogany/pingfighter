# Claude Handoff Prompt: Menhera Turn Runtime Applied

아래 프롬프트를 그대로 Claude에게 전달하면 됩니다.

```text
Stage 3 Menheragirl turn runtime migration has now been applied by Codex.

Current live/runtime state:
- `entities/menhera_boss_sprite.py` turn loader has been migrated from `8x1` to `4x2`
- `TURN_GRID_COLS = 4`
- `TURN_GRID_ROWS = 2`
- `TURN_FRAME_ORDER = ((0,0),(1,0),(2,0),(3,0),(0,1),(1,1),(2,1),(3,1))`
- `RENDER_TURN_FRAMES = True` was enabled because the user explicitly asked to apply visible turn playback

Turn asset swap:
- `items/menhera_boss_turn.png` now points to the FLUX publish candidate PNG
- `items/menhera_boss_turn.jpeg` now points to the matching FLUX JPEG
- old `8x1` turn PNG backup is preserved at:
  - `d:\main\bosspong\.tmp\menhera_turn_runtime_backup_20260418\menhera_boss_turn_old_8x1.png`

Important policy remains unchanged:
- canonical walk = sole identity anchor
- turn V3 / applied runtime turn sheet = runtime playback auxiliary sheet only
- non-anchor
- do not use the turn sheet as regen anchor for attack / dash / victory / defeat

Local runtime-side checks already completed by Codex:
- 4x2 loader reads 8 turn frames successfully
- visible turn playback path is active
- facing-change transition completes and reconnects back into walk
- no immediate slicing failure

What Claude should assume going forward:
- asset-side generation branch for this Menhera turn line is closed
- no more FLUX / AutoSprite / Gemini passes on this branch unless a new bug is observed in runtime
- if future art work is requested for Menhera, use the canonical walk as the only identity anchor

If a future runtime regression is reported, only then help with:
- identifying whether the problem is asset-side vs runtime-side
- checking if the applied turn should be treated as playback-only while preserving canonical walk identity rules

Do NOT reopen generation just because the turn is now live.
Only reopen if a concrete runtime-visible issue appears and the user explicitly asks.
```
