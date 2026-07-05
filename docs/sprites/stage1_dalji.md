# Stage 1 Dalji Sprite Notes

This is the compact per-boss runtime contract for Stage 1 Dalji in the
current Godot project, DiskHearts - Lingpia. The long provenance and
generation history still lives in `CLAUDE.md` for now, but new runtime work
should start here plus
`docs/sprites/boss_sprite_runtime_contract.md`.

## Asset Set

The current live Godot project is repo-local, so active runtime PNGs live
directly under `godot/assets/sprites/stage1/dalji/`. Python source assets
under `assets/` are frozen PingFighter reference / parity inputs, not the
current runtime target.

| State | Legacy Python reference asset | Active Godot runtime asset | Layout |
|---|---|---|---|
| Walk left | `assets/dalji_boss_walk_left.png` | `godot/assets/sprites/stage1/dalji/dalji_boss_run_left_16f_fullkeypose_autosprite_v15.png` | 1376x1536, 4x4, cell 344x384, 16 frames |
| Walk right | `assets/dalji_boss_walk_right.png` | `godot/assets/sprites/stage1/dalji/dalji_boss_run_right_16f_fullkeypose_autosprite_v15.png` | 1376x1536, 4x4, cell 344x384, 16 frames |
| Idle | `assets/dalji_boss_idle.png` | `godot/assets/sprites/stage1/dalji/dalji_boss_idle.png` | 1536x1024, 4x2, cell 384x512 |
| Attack / ball contact | `assets/dalji_boss_attack.png` | `godot/assets/sprites/stage1/dalji/dalji_boss_attack.png` | 1536x1024, 4x2, cell 384x512 |
| Dash | `assets/dalji_boss_dash.png` | `godot/assets/sprites/stage1/dalji/dalji_boss_dash.png` | 1536x1024, 4x2, cell 384x512 |
| Turn | `assets/dalji_boss_turn.png` | `godot/assets/sprites/stage1/dalji/dalji_boss_turn.png` | 1536x1024, 4x2, cell 384x512 |
| Victory | `assets/dalji_boss_victory.png` | `godot/assets/sprites/stage1/dalji/dalji_boss_victory.png` | 1536x1024, 4x2, cell 384x512 |
| Defeat | `assets/dalji_boss_defeat.png` | `godot/assets/sprites/stage1/dalji/dalji_boss_defeat.png` | 1536x1024, 4x2, cell 384x512 |
| Result-screen defeat cutscene loop legacy runtime | n/a | `godot/assets/sprites/stage1/dalji/dalji_result_defeat_cutscene_loop_64f_autosprite_v1_512.png` | 4096x4096, 8x8, cell 512x512, 64 frames |
| Result-screen defeat cutscene loop legacy master | n/a | `godot/assets/sprites/stage1/dalji/dalji_result_defeat_cutscene_loop_64f_autosprite_v1.png` | 8192x8192, 8x8, cell 1024x1024, 64 frames |
| Result-screen defeat cutscene Live2D hires | n/a | `godot/assets/sprites/stage1/dalji/dalji_result_defeat_cutscene_live2d_hires_64f_autosprite_v2.png` | 8192x8192, 8x8, cell 1024x1024, 64 frames, 32 px safe margin |
| Result-screen defeat cutscene Live2D hires sharp | n/a | `godot/assets/sprites/stage1/dalji/dalji_result_defeat_cutscene_live2d_hires_64f_autosprite_v2_sharp.png` | 8192x8192, 8x8, cell 1024x1024, 64 frames, v2 alpha/safe margin plus RGB presentation sharpening |
| Result-screen defeat cutscene Live2D hires v3 | n/a | `godot/assets/sprites/stage1/dalji/dalji_result_defeat_cutscene_live2d_hires_64f_autosprite_v3.png` | 8192x8192, 8x8, cell 1024x1024, 64 frames, 48 px safe margin |
| Result-screen defeat cutscene Live2D hires v3 sharp | n/a | `godot/assets/sprites/stage1/dalji/dalji_result_defeat_cutscene_live2d_hires_64f_autosprite_v3_sharp.png` | 8192x8192, 8x8, cell 1024x1024, 64 frames, v3 alpha/safe margin plus RGB presentation sharpening |
| Result-screen defeat cutscene Live2D hires v3 matte-clean | n/a | `godot/assets/sprites/stage1/dalji/dalji_result_defeat_cutscene_live2d_hires_64f_autosprite_v3_sharp_matteclean.png` | 8192x8192, 8x8, cell 1024x1024, 64 frames, v3 sharp plus edge RGB bleed / faint alpha dust cleanup |
| Result-screen defeat cutscene Live2D clean v4 | n/a | `godot/assets/sprites/stage1/dalji/dalji_result_defeat_cutscene_live2d_clean_98f_autosprite_v4.png` | 14336x7168, 14x7, cell 1024x1024, 98 frames, fresh 49+49 AutoSprite ultra-bg loops, 52 px safe margin, matte cleanup |
| Result-screen defeat cutscene Live2D clean-anchor v5 | n/a | `godot/assets/sprites/stage1/dalji/dalji_result_defeat_cutscene_live2d_clean_anchor_98f_autosprite_v5.png` | 14336x7168, 14x7, cell 1024x1024, 98 frames, fresh uploaded clean imagegen anchor, 49+49 AutoSprite ultra-bg loops, source-frame margins preserved |
| Result-screen defeat cutscene Live2D clean-anchor pingpong v6 | n/a | `godot/assets/sprites/stage1/dalji/dalji_result_defeat_cutscene_live2d_clean_anchor_pingpong_98f_autosprite_v6.png` | 14336x7168, 14x7, cell 1024x1024, 98 frames, v5 frames 0-48 then 48-0 return, exact loop seam |
| Result-screen click cry Live2D pingpong v1 | n/a | `godot/assets/sprites/stage1/dalji/dalji_result_click_cry_dont_talk_live2d_pingpong_98f_autosprite_v1.png` | 14336x7168, 14x7, cell 1024x1024, 98 frames, 49-frame AutoSprite click reaction where Dalji cries / mouths "말걸지마~" plus 48-0 deterministic return, legacy reference due face-side blue matte/color drift |
| Result-screen click cry Live2D face-fill v4 | n/a | `godot/assets/sprites/stage1/dalji/dalji_result_click_cry_dont_talk_live2d_facefill_pingpong_98f_autosprite_v4.png` | 14336x7168, 14x7, cell 1024x1024, 98 frames, legacy click reaction, v1 motion with deterministic face-right cyan matte / tear color cleanup and exact loop seam |
| Result-screen click cry Live2D tear-clean v5 | n/a | `godot/assets/sprites/stage1/dalji/dalji_result_click_cry_dont_talk_live2d_tearclean_pingpong_98f_autosprite_v5.png` | 14336x7168, 14x7, cell 1024x1024, 98 frames, legacy click reaction, v4 motion plus stronger under-eye blue/cyan tear-lane cleanup and exact loop seam |
| Result-screen click cry Live2D remake v6 | n/a | `godot/assets/sprites/stage1/dalji/dalji_result_click_cry_dont_talk_live2d_remake_pingpong_98f_autosprite_v6.png` | 14336x7168, 14x7, cell 1024x1024, 98 frames, active runtime click reaction, fresh AutoSprite remake from the clean-anchor character, no baked text/speech bubble, white/clear tear cleanup, exact loop seam |
| Result-screen click cry voice v1 | n/a | `godot/assets/sounds/voice/dalji_result_click_cry_aaang_v1.wav` | 2.27 sec mono 44.1 kHz PCM WAV, legacy Korean SAPI source "아아아앙..." with light pitch / tremolo / echo / fade processing |
| Result-screen click dont-touch voice v1 | n/a | `godot/assets/sounds/voice/dalji_result_click_dont_touch_sad_v1.wav` | 1.24 sec mono 44.1 kHz PCM WAV, legacy sad Korean SAPI source "건들지마..." with lower pitch / tremolo / echo / fade processing |
| Result-screen click dont-touch high voice v2 | n/a | `godot/assets/sounds/voice/dalji_result_click_dont_touch_high_v2.wav` | 0.93 sec mono 44.1 kHz PCM WAV, legacy high-tone game/anime-style Korean SAPI source "건들지마..." with pitch-up / tremolo / light echo / fade processing |
| Result-screen click tang + dont-touch voice v3 | n/a | `godot/assets/sounds/voice/dalji_result_click_tang_dont_touch_high_v3.wav` | 1.30 sec mono 44.1 kHz PCM WAV, legacy one-shot `탕!` trim from `gunshot.wav` followed by the high-tone `건들지마...` voice |
| Result-screen click supplied defeat voice | n/a | `godot/voice/dalzidefeat.mp3` | 1.07 sec mono 44.1 kHz MP3, active user-supplied Dalji click voice |
| Stun | `assets/dalji_boss_stun.png` | `godot/assets/sprites/stage1/dalji/dalji_boss_stun.png` | 1536x1024, 4x2, cell 384x512 |
| Whip yaw skill | `assets/dalji_boss_whip.png` | `godot/assets/sprites/stage1/dalji/dalji_boss_whip.png` | 1536x1024, 4x2, cell 384x512 |
| Paengi top-whip strike | `assets/dalji_boss_paengi.png` | `godot/assets/sprites/stage1/dalji/dalji_boss_paengi.png` | 1536x1024, 4x2, cell 384x512 |
| Paengi top-whip strike v1 (legacy) | reference-only Python source unchanged | `godot/assets/sprites/stage1/dalji/dalji_boss_paengi_top_whip_32f_autosprite_v1.png` | 4096x2048, 8x4, cell 512x512, 32 frames |
| Paengi top-whip strike v2 (active) | reference-only Python source unchanged | `godot/assets/sprites/stage1/dalji/dalji_boss_paengi_top_whip_32f_autosprite_v2.png` | 4096x2048, 8x4, cell 512x512, 32 frames, AutoSprite turbo regen, early crack at frame ~8 |

## Runtime Identity

- Stage 1 boss display name: `달지` / Dalji. `풍악보이` is a legacy name and
  should not be used for new Godot labels or comments.
- Dalji's walk is the current per-boss exception to the default
  front-biased walk policy: she uses separate left/right off-frontal walk
  sheets and must not be runtime-mirrored.
- The walk pair is the identity anchor for future regeneration. Turn and
  skill sheets are runtime auxiliaries, not canonical identity anchors.

## Legacy Python Runtime Mapping

This section is a frozen PingFighter reference for parity checks only. The
Python runtime used `entities/stage1_boss_sprite.py` and the Stage 1 branch
in `pingfighter.py`; do not edit those files for current work unless the
user explicitly asks for original PingFighter source changes.

| Gameplay state | Python path |
|---|---|
| Walk / idle / attack / turn | `stage1_boss_sprite.get_current_frame(...)` |
| Anticipatory ball contact | `stage1_boss_sprite.trigger_attack(...)`; F5 should align near predicted contact |
| Dash | `stage1_boss_sprite.get_dash_frame(...)` while `boss_dashing` |
| Whip yaw | `stage1_boss_sprite.get_whip_frame(...)` while `whip_active` |
| Paengi strike | `stage1_boss_sprite.get_paengi_frame(...)` while `whip_animation_timer > 0` |
| Stun | `stage1_boss_sprite.get_stun_frame(...)` while `boss_stunned_timer > 0` |
| Victory | `stage1_boss_sprite.get_victory_frame(...)` after boss win |
| Defeat | `stage1_boss_sprite.get_defeat_frame(...)` after boss loss |

Legacy Python conceptual priority:

```text
defeat > victory > stun > dash > paengi > whip > walk/attack/turn > idle
```

## Godot Runtime Mapping

Current Godot Stage 1 is the active implementation target. The live Godot
project is repo-local at `godot/project.godot`.

Current keys:

| Godot key | Dalji asset | Meaning |
|---|---|---|
| `boss_walk_left_sheet` | `dalji_boss_run_left_16f_fullkeypose_autosprite_v15.png` | movement-left full-keypose knee-lift bounce run |
| `boss_walk_right_sheet` | `dalji_boss_run_right_16f_fullkeypose_autosprite_v15.png` | movement-right full-keypose knee-lift bounce run |
| `boss_idle_sheet` | `dalji_boss_idle.png` | stationary idle loop |
| `boss_attack_sheet` | `dalji_boss_attack.png` | ball-contact attack |
| `boss_dash_sheet` | `dalji_boss_dash.png` | emergency boss dash |
| `boss_victory_sheet` | `dalji_boss_victory.png` | boss win result animation |
| `boss_defeat_sheet` | `dalji_boss_defeat.png` | boss loss result animation |
| `boss_stun_sheet` | `dalji_boss_stun.png` | future real stun/electrocution |
| `boss_whip_sheet` | `dalji_boss_whip.png` | renderer-ready whip yaw auxiliary |
| `boss_paengi_top_whip_sheet` | `dalji_boss_paengi_top_whip_32f_autosprite_v2.png` | AutoSprite 32-frame spinning-top cast (v2 regen, front-facing single crack); v1 kept as legacy rollback |
| `boss_sprite_sheet` | `dalji_boss_run_right_16f_fullkeypose_autosprite_v15.png` | legacy `boss_has_sprite` compatibility |
| `boss_hit_sprite_sheet` | `dalji_boss_attack.png` | legacy compatibility for ball-contact attack |

Important: in Godot, `boss_hit_sprite_sheet` means "boss hit the ball,"
not "boss got hit." It must remain mapped to `dalji_boss_attack.png`.
Real stun must use `boss_stun_sheet` or another explicit stun key.

Current Godot renderer priority:

```text
defeat > victory > stun contexts > dash > paengi top-whip context > whip context > ball-contact attack > walk_left/walk_right > idle
```

Current Godot animation timing:

- Dalji left/right movement uses 16-frame AutoSprite MCP runtime sheets
  (`4` columns, `344x384` cells, `0.050s` per frame). The current pair was
  regenerated from the pre-AutoSprite original walk frame as a full-keypose
  loop: all 16 frames are distinct AutoSprite source frames instead of an
  8-frame repeat. The motion keeps the compact side-run rhythm while giving
  clearer contact, high-knee, airborne-hop, and landing-prep beats. Final
  runtime sizing trims, scales, aligns, and adds a small baked vertical bob.
  The left PNG is a deterministic baked mirror of the accepted right-source
  frames, so left movement faces left consistently without runtime mirroring.
- Current AutoSprite provenance: character `cmosppixk00388czerl48g9uq`;
  shipped right-source job `wf_ce472a3d-2f91-458e-87e6-33f686998dc1`, sheet
  `cmosrz9s80057w35afdce07ro`, video `cmosrx26l004uw35aw2r2xxzt`.
- `boss_actor_animation_state.gd` predicts upward ball approaches and
  starts Dalji's attack before contact using the same conservative
  16/12/8/4-frame start-window model as the Python runtime.
- F5 (frame index 4) is the intended contact apex.
- The real paddle-bounce event still triggers the attack as a fallback
  when prediction misses, but it must not restart an already anticipated
  attack from F1.
- `boss_ai_state.gd` owns the Stage 1 emergency dash lifecycle: one token,
  Python-style close-ball trigger tests, 40 px/frame dash speed, 316.8 px
  max distance, 40-55 sec base recharge, and 0.60 sec post-dash recovery.
- The Godot spinning-top cast exposes `boss_paengi_top_whip_active` and a
  32-frame `boss_paengi_top_whip_frame` from
  `stage1_dalji_spinning_top_skill_state.gd`. The skill was reworked to a
  staggered per-top hit sequence: Dalji plays one `PER_HIT_WHIP_FRAMES` (36)
  whip cycle per top (2 normal / 4 enraged), and the sprite frame maps per
  cycle as `frame = int((1 - hit_whip_timer / PER_HIT_WHIP_FRAMES) * 32)`.
  Each cycle's struck top launches forward at `STRIKE_FRAME_RATIO` (0.25 =
  sprite frame ~8, the v2 sheet's early crack). The renderer maps this to
  `boss_paengi_top_whip_sheet` with an 8x4, 512 px cell grid.
- `stage1_dalji_spinning_top_renderer.gd` anchors its procedural whip line to
  the v2 paengi sheet's per-frame stick-tip coordinate
  (`PAENGI_STICK_TIP_SOURCE_POINTS`, re-measured for v2) instead of the boss
  hitbox center, so the launching top cord exits from Dalji's drawn switch.
  The v2 anchors are manual phase-based estimates (~+/-20px) — fine-tune in
  live QA if the cord origin drifts.

Victory and defeat are rendered during every round-score scoreboard window:
player scoring triggers Dalji defeat, and boss scoring triggers Dalji victory,
including tied-score transitions where score comparison alone cannot identify
the scoring side. The sheets use Python's 0.18s-per-frame,
play-once-and-hold timing. Turn, paengi, and broader game-flow result screens
are still tracked as separate runtime slices. Whip drawing is renderer-ready;
skill activation and ball/AI behavior are tracked as a separate runtime slice.

The result-screen defeat cutscene loop is a separate larger presentation
asset for the future victory/reward/settlement scene. It must not replace the
round-score `boss_defeat_sheet`. The active match-clear result scene
(`scenes/stage_clear_result.tscn` +
`scripts/ui/stage_clear_result_scene.gd`) uses the Live2D clean-anchor
pingpong v6 sheet. The v5 source starts from a new imagegen clean cutout anchor
(`dalji_result_defeat_clean_anchor_imagegen_v2.png`) centered on a square
transparent canvas and uploaded as its own AutoSprite character
(`cmoy31zgz005ii79yc7iya8wl`). Two fresh AutoSprite legendary 49-frame
cutscene loops with `ultra` background removal are combined into one
98-frame runtime sheet and lightly presentation-sharpened / edge-cleaned
for large result-screen placement. The v6 runtime sheet supersedes the direct
A+B v5 timeline by preserving the first 49-frame clean-anchor motion as the
forward half and using frames 48-0 as the second 49-frame return half. This
keeps the requested 49+49 structure while guaranteeing exact seam closure:
frame 48 equals frame 49, and frame 97 equals frame 0.
AutoSprite returned a 49-frame source loop even when 64 frames were requested;
the checked-in 64-frame sheets expand that AutoSprite-derived timeline by
deterministic frame duplication. The v3 runtime sheet applies a centered
48 px transparent safe-margin pass so Dalji's extended right shoe and toe no
longer sit on the source-cell edge during settlement-screen placement. The
sharp sibling preserves that alpha and safe-margin layout while applying only
RGB contrast/color micro-boost and unsharp masking. The v4 98-frame sheet
uses the same cleanup family while starting from new AutoSprite `ultra`
background-removal output. The v5 sheet supersedes v4 because its AutoSprite
character is built from the cleaner imagegen anchor instead of the older
character identity: source frames already keep at least ~100 px horizontal
and ~210 px vertical transparent margins, then the final pass drops
near-invisible alpha dust and bleeds nearby subject RGB into transparent /
soft-edge pixels to reduce dirty matte halos around Dalji's head ornaments,
tassels, and hair during linear-filtered scene rendering. The v6 sheet keeps
those cleaned v5 frames but replaces the second independently generated
49-frame half with a deterministic reverse return to remove the visible loop
break. The older v1 512 px, v1 1024 px, v2, v3, v4, and direct A+B v5 sheets
remain legacy references.

The Stage 1 player result poses mirror the same scoreboard window contract:
player scoring triggers Smasher victory, and boss scoring triggers Smasher
defeat. These are round-result poses, not match-end-only poses, so they must
not be gated on `pending_game_reset`. Current Smasher victory is a
full-helmet 64-frame runtime sheet (`8` columns, 160 px cells, 0.020s per
frame); keep the helmet sealed throughout the celebration unless the character
direction is explicitly changed again. Current Smasher defeat remains a
16-frame 4x4 sheet.

The result-screen Dalji click reaction is a separate optional interaction
sheet, not the default settlement idle loop. `stage_clear_result_scene.gd`
plays the active remake v6 sheet once when the player clicks Dalji, shows the
dialogue line `건들지마`, plays the supplied `voice/dalzidefeat.mp3`,
then returns to the base defeat loop. Runtime
entry / exit must not hard-cut between sheets: the scene freezes the current
base Live2D frame, crossfades into the click reaction, then crossfades out
through the base neutral frame and resyncs the base loop to frame 0. It uses
the same clean-anchor AutoSprite character (`cmoy31zgz005ii79yc7iya8wl`) and
source spritesheet `cmoy5gzyj0001bvpf3qs201q6`, with the runtime timeline
assembled as frames 0-48 forward and 48-0 return for a 98-frame sheet. No
audio was generated, so voice playback should be wired separately if needed.
The older v1/v4/v5 click motion is preserved as reference only. Active remake
v6 comes from a fresh AutoSprite 49-frame source (`cmoyasa8r00605wy690977ukh`;
job `wf_2fd43dec-c361-419e-9208-a0e5ffc3c5d0`) after rejecting an earlier
remake candidate (`cmoyambhu00lamumy763zzdl0`) because it baked a speech
bubble/text into the sheet. The v6 final pass warms/desaturates the tear lanes
so the in-game click reaction keeps white/clear tears instead of blue/cyan
breakage. QC for v6: transparent corners, no edge-touch frames, minimum
margins `[104, 169, 99, 214]`, `frame48 == frame49`, `frame97 == frame0`, and
remaining cyan-candidate pixels in the face cleanup region `[0, 0]`.
The click voice is loaded through `ProjectResourceLoader.load_audio_stream()`
and replayed from the start on accepted Dalji clicks; if the result scene has
not entered the tree yet, playback is deferred so smoke tests and preview
instantiation cannot hit an early audio-node error.

Current Smasher left/right movement uses full-helmet 8-frame runtime sheets
(`4x2`, 160 px cells, 0.050s per frame). The active runtime pair is restored to
the original pre-AutoSprite left subculture movement sheet:
`smasher_subculture_left_walk_sheet.png`. The right movement sheet intentionally
uses a horizontal mirror of that same left sheet,
`smasher_subculture_left_walk_sheet_mirrored_right.png`, so left / right share
the same compact rear-view hoverboard strafe rhythm, fixed head / feet height,
small board yaw / roll, planted feet, and visible short rear jet flame. Future
replacement attempts should still start from AutoSprite output, but do not ship
synthetic board-sway, row-warp, rotation, deformation, or procedural motion
effects as the final movement source unless explicitly accepted. Keep the
movement frame count, 4-column grid, and playback cadence in sync across update
context, draw context, renderer source-rect calculation, dash afterimages, and
the resource smoke.

Current Smasher stationary idle uses
`smasher_idle_back_sheet_16f.png` (`4x4`, 160 px cells, 0.15s per frame). In
Godot, both `player_idle_back_sheet` and the fallback
`player_idle_sprite_texture` must resolve to this same full-helmet standing
sheet so older direct-read paths cannot show `smasher_idle_strip.png` or the
obsolete `smasher_idle_front_breath_8f_autosprite_v1.png` by accident. The
actor renderer applies the existing procedural idle-breath scale and Y-offset
on top of this sheet. If this idle sheet changes, update the primary idle path,
fallback idle path, frame count, grid rows / columns, animation cadence,
draw-context priority, and resource smoke together.

Standing-sheet vocabulary: for Smasher player runtime work, "standing",
"idle", "가만히 있을 때", and "스탠딩 시트" all mean this stationary idle
runtime sheet. Do not treat standing as a separate concept-art surface,
round-result pose, card preview, or old front-facing placeholder unless the
task explicitly says so.

## Regression Checks

Before claiming Dalji sprite work is done:

- Search for `풍악보이`, `Pungakboy`, and `pungak` in active Godot scripts;
  only legacy backup files should retain those names.
- Search for `boss_hit_sprite_sheet`; confirm it maps to attack, not stun.
- Confirm `boss_stun_sheet` exists separately if stun assets are loaded.
- Confirm anticipated attack and exact-contact fallback do not double-fire
  or restart the sheet from F1 at contact.
- Headless-load the repo-local live Godot project at `godot/project.godot`.
- For Godot, run a resource smoke that loads:
  `boss_walk_left_sheet`, `boss_walk_right_sheet`, `boss_idle_sheet`,
  `boss_attack_sheet`, `boss_dash_sheet`, `boss_victory_sheet`,
  `boss_defeat_sheet`, and `boss_stun_sheet`.
- For Godot player result poses, confirm `player_victory_sheet` and
  `player_defeat_sheet` load, and that `last_scoring_side == "player"`
  activates Smasher victory while `last_scoring_side == "boss"` activates
  Smasher defeat even when `pending_game_reset` is false.
- If the Smasher victory frame count changes, update the Godot context frame
  count, grid column count, smoke-test texture size, and playback cadence
  together. The current 64-frame victory sheet is timed to fit inside the
  round-score scoreboard window.
- If the Smasher directional walk frame count changes, update the walk sheet
  paths, update-context frame count and cadence, draw-context grid metadata,
  player renderer, dash afterimage source rects, and smoke-test texture size
  together.
- If the Smasher stationary idle sheet changes, update the idle sheet path,
  fallback idle path, update-context frame count and cadence, draw-context
  grid rows / columns, actor-renderer sheet detection, draw-context priority,
  renderer source-rect logic, and smoke-test texture size together. Search for
  `player_idle_back_sheet`, `player_idle_sprite_texture`,
  `smasher_idle_strip`, and the obsolete
  `smasher_idle_front_breath_8f_autosprite_v1`; only documented backup files
  should retain old idle source names. Confirm "standing" and "가만히 있을 때"
  requests resolve to this same active idle path rather than a card preview,
  result pose, concept image, or legacy fallback sheet.
- If Dalji's boss skill-card HUD size changes, update
  `godot/scripts/stages/common/boss_skill_card_hud_spec.gd` and every
  stage boss skill-card renderer that consumes it. The current official
  Godot boss skill-card contract is Dalji's compact size: base pillar width
  `80`, card base `33.6x9.0`, min rect `24x10`, gap `2`, right margin `3`,
  and left-pillar Y margin `5`.
- If a future live project is moved outside the repo again, verify
  mirror/live hashes for every edited `.gd` file and every copied Dalji PNG.
