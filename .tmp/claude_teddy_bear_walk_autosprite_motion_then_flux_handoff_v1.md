# Claude Handoff Prompt: Teddy Bear Walk AutoSprite Motion -> FLUX Anchor/Expansion

아래 프롬프트를 그대로 Claude에 전달하면 됩니다.

```text
이번 작업은 PingFighter Stage 3 Teddy Bear 보스의 walk sheet 재생성이다.

목표:
- 현재 rejected teddy walk를 버리고
- AutoSprite로 먼저 "명확한 plush waddling walk" motion block을 만든 뒤
- FLUX Kontext로 accepted teddy redesign anchor identity를 입혀
- 최종적으로 8프레임 walk candidate를 다시 만든다

중요한 전제:
- `d:\main\bosspong\CLAUDE.md`를 따른다
- 반드시 `d:\main\bosspong\.claude\skills\sprite-generation\SKILL.md` 기준으로 진행한다
- 이번 브랜치의 실패 원인은 identity가 아니라 walk acting 부족이었다
- 따라서 이번엔 AutoSprite를 motion ideation / walk blocking에 적극 사용한다
- 하지만 AutoSprite full-sheet를 final renderer로 승격하지 않는다
- 또한 AutoSprite full-sheet -> FLUX full-sheet 직결은 피한다
- 올바른 구조는:
  1) AutoSprite motion block
  2) FLUX contact/anchor lock
  3) FLUX pair / frame expansion

canonical identity source:
- accepted redesign anchor:
  `d:\main\bosspong\.tmp\teddy_bear_stage3_redesign_anchor_v1.png`

secondary plush-mechanics source:
- procedural teddy reference:
  `d:\main\bosspong\.tmp\teddy_bear_procedural_reference_v1.png`

do NOT use as refs:
- rejected direct full-sheet walk:
  `d:\main\bosspong\.tmp\teddy_bear_walk_v1.jpeg`
- rejected / superseded intermediate failures
- Menhera walk sheet or any human-body reference

==================================================
STEP 1. AUTOSPRITE WALK MOTION BLOCK
==================================================

목표:
- identity precision보다 walk rhythm을 먼저 만든다
- 8프레임 4x2 plush walk block
- 명확한 contact / rise / shift / rebound / opposite contact / rise / shift / rebound 구조

AutoSprite reference inputs:
1. redesign anchor
   `d:\main\bosspong\.tmp\teddy_bear_stage3_redesign_anchor_v1.png`
2. procedural teddy
   `d:\main\bosspong\.tmp\teddy_bear_procedural_reference_v1.png`

AutoSprite motion brief:
- front-facing plush teddy waddling toward the player while moving laterally
- this is NOT a human gait
- squat stuffed-toy walk
- clear side-to-side weight transfer
- visible body bob
- compact paw swing
- ear bounce
- bow bounce
- dangling eye thread swing
- belly-heart and plush mass wobble slightly with the step
- cute but slightly uncanny
- same teddy species all 8 frames

critical motion constraints:
- no static idle gallery
- no same pose repeated 8 times
- no "only feet shuffle" cycle
- no side-facing walk
- no human hips / human runway gait
- no dance loop
- no victory / bounce-in-place posing

hard motion QA for AutoSprite:
1. F1 and F5 must clearly invert support leg / contact role
2. F2/F3/F4 and F6/F7/F8 must not collapse into near-identical repeats
3. the direct f1..f8 strip must already read as a real waddling walk
4. if the strip still looks like the same teddy pasted 8 times, reject and retry

AutoSprite outputs:
- `.tmp/teddy_bear_walk_autosprite_motion_v1.png`
- optional:
  - `.tmp/teddy_bear_walk_autosprite_motion_v1_zoom.png`
  - `.tmp/teddy_bear_walk_autosprite_motion_v1_report.md`

If AutoSprite fails this, retry once with stronger language:
- "pronounced plush waddle"
- "clear contact inversion"
- "body bob and belly wobble"
- "do not repeat the same pose"

Do not move to FLUX unless the AutoSprite strip is visibly more walk-like
than the previous rejected FLUX walk candidate.

==================================================
STEP 2. FLUX CONTACT / ANCHOR LOCK
==================================================

Do NOT go straight to full-sheet FLUX.

Use the accepted redesign anchor as absolute identity master and the
AutoSprite motion block as motion-only reference.

2A. Lock F1 contact anchor:
- primary identity:
  `d:\main\bosspong\.tmp\teddy_bear_stage3_redesign_anchor_v1.png`
- motion guide:
  `.tmp/teddy_bear_walk_autosprite_motion_v1.png`
- optional secondary plush-mechanics:
  `d:\main\bosspong\.tmp\teddy_bear_procedural_reference_v1.png`

F1 brief:
- same exact teddy as redesign anchor
- front-facing
- compact plush walk contact pose
- one leg planted, opposite leg lifted forward
- slight body bob
- slight ear / bow / dangling-thread motion

2B. Lock F5 opposite contact:
- condition on accepted F1 anchor
- same exact teddy / same prop locations
- exact contralateral support inversion
- keep accessories fixed in world-facing design positions
- only the walk support logic inverts

hard identity lock:
- cocoa-brown plush bear silhouette
- left button eye with X thread
- right dangling damaged eye on thread
- big pink gingham bow
- cream neck ribbon
- stitched belly heart
- safety pin charm
- bandage patches
- mismatched pink paw patch
- small black bow accent
- thick black pixel outline
- no soft sticker rendering

hard fail:
- any face redesign across frames
- ear recolor drift
- dangling eye missing
- prop positions randomly moving
- humanized gait
- same-pose repeat

==================================================
STEP 3. FLUX PAIR / FRAME EXPANSION
==================================================

Only after F1 and F5 are both accepted:

Generate pairs:
- F2 / F6 = rise pair
- F3 / F7 = shift / support pair
- F4 / F8 = rebound / return pair

Use:
- accepted redesign anchor as absolute identity master
- accepted F1 / F5 as strongest motion anchors
- AutoSprite motion block as amplitude / slot-role guide only

walk-sheet hard gate:
- before any publish recommendation, inspect the direct `f1..f8` strip
- if it still reads like near-identical posing, reject
- do NOT let stitched preview or vague gameplay movement override a bad raw strip

==================================================
STEP 4. STITCH + QA
==================================================

Outputs:
- `.tmp/teddy_bear_walk_f1_v2.png` ... `f8_v2.png`
- `.tmp/teddy_bear_walk_stitched_v3_preview.png`
- `.tmp/teddy_bear_walk_stitched_v3_preview_gameplay.png`
- `.tmp/teddy_bear_walk_frame_expansion_v2_report.md`

Final QA must answer:
1. Is the direct f1..f8 strip clearly more separated than the rejected candidate?
2. Does the strip read as a true plush waddling walk, not a static pose gallery?
3. Do F1 and F5 invert support leg correctly?
4. Are F2/F3/F4 and F6/F7/F8 visibly distinct slots rather than repeats?
5. Is identity fully preserved from the redesign anchor?
6. Is this strong enough for in-game wire-up candidate, or does it still fail asset-side?

Success definition:
- same exact teddy identity as redesign anchor
- clear 8-frame plush waddling walk
- no near-static pose gallery
- stronger direct strip readability than the previous rejected walk
```
