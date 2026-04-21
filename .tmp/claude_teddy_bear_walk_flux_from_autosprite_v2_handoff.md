# Claude Handoff: Teddy Bear Walk FLUX From AutoSprite V2

아래 내용을 Claude에 전달하면 됩니다.

```text
이번 단계는 AutoSprite V2를 motion-only ref로 받아서 Teddy Bear walk를 FLUX로 다시 잠그는 단계다.

결론:
- AutoSprite V2는 ACCEPT as motion-only reference
- 이유: front-facing 확보 성공, same-pose repeat 아님, direct strip differentiation 존재
- 단, identity drift / tiny-foot-shuffle / weak F1↔F5 inversion 때문에 final renderer로는 불가

중요 정책:
- canonical identity master는 여전히
  `d:\main\bosspong\.tmp\teddy_bear_stage3_redesign_anchor_v1.png`
- AutoSprite V2는 motion-only reference일 뿐이다
- direct full-sheet FLUX는 다시 하지 않는다
- F1/F5 contact anchor -> F2/F6 -> F3/F7 -> F4/F8 순으로 pair expansion 진행

사용 자산:
1. identity master
   `d:\main\bosspong\.tmp\teddy_bear_stage3_redesign_anchor_v1.png`
2. procedural plush-mechanics ref
   `d:\main\bosspong\.tmp\teddy_bear_procedural_reference_v1.png`
3. AutoSprite motion-only ref
   `d:\main\bosspong\.tmp\teddy_bear_walk_autosprite_motion_v2.png`
4. zoom aid
   `d:\main\bosspong\.tmp\teddy_bear_walk_autosprite_motion_v2_zoom.png`

금지:
- rejected direct full-sheet walk 사용 금지
- Menhera ref 사용 금지
- AutoSprite V2 identity를 따오지 말 것

==================================================
STEP 1. F1 CONTACT LOCK
==================================================

FLUX Kontext max로 F1 contact anchor 한 장 생성.

F1 brief:
- same exact teddy as redesign anchor
- front-facing teddy
- lateral travel is happening, but body/face still face the viewer
- compact plush contact pose
- one leg clearly planted
- opposite leg clearly lifted forward
- slight body bob
- slight ear bounce
- slight bow bounce
- dangling eye thread visible

hard identity lock:
- left X-button eye
- right dangling damaged eye on thread
- big pink gingham bow
- cream neck ribbon
- belly heart
- safety pin charm
- bandage patches
- mismatched paw patch
- black bow accent
- cocoa fur palette
- thick black pixel outlines

==================================================
STEP 2. F5 OPPOSITE CONTACT LOCK
==================================================

Generate F5 from accepted F1 + identity master + AutoSprite V2 motion ref.

Hard motion requirement:
- exact opposite support logic of F1
- if F1 = planted viewer-left / lifted viewer-right, F5 must invert that exactly
- do NOT mirror the prop layout
- only the walk support / leg role changes

==================================================
STEP 3. PAIR EXPANSION
==================================================

If F1 and F5 both pass:
- F2 / F6 = rise pair
- F3 / F7 = support-shift pair
- F4 / F8 = rebound / return pair

Important:
- increase amplitude slightly beyond AutoSprite V2
- preserve plush waddling read
- do NOT over-humanize
- do NOT collapse into tiny foot shuffle

Target walk feel:
- clearer than AutoSprite V2
- front-facing plush waddle
- visible body bob and weight shift
- no idle-gallery read

==================================================
STEP 4. STRIP GATE + QA
==================================================

Before any publish recommendation:
- inspect direct f1..f8 strip
- if it still looks like same teddy pasted 8 times, reject
- if F1↔F5 inversion is weak, reject
- if front-facing is lost, reject

Outputs:
- `.tmp/teddy_bear_walk_f1_v2.png` ... `f8_v2.png`
- `.tmp/teddy_bear_walk_stitched_v3_preview.png`
- `.tmp/teddy_bear_walk_stitched_v3_preview_gameplay.png`
- `.tmp/teddy_bear_walk_frame_expansion_v2_report.md`

Final report must answer:
1. Did AutoSprite V2 help as motion-only ref?
2. Did FLUX preserve redesign-anchor identity?
3. Is F1↔F5 inversion crisp?
4. Is direct strip clearly more separated than the rejected walk?
5. Does the sheet now read as a real plush waddling walk?
6. Is it strong enough for in-game wire-up candidate?
```
