# Claude Handoff: Teddy Bear Walk FLUX Yaw-Only Touch-Up (Precise)

아래 내용을 그대로 Claude에 전달하면 됩니다.

```text
이번 단계는 선택적 precise-mode touch-up이다.

목표:
- Teddy Bear walk Gemini V4의 slight rightward glance만 줄이거나 제거
- 다른 identity 요소나 motion은 건드리지 않는다
- 실제 gameplay blocker를 해결한다:
  stable walk가 약간 screen-right를 보고 있어서, left travel 시
  뒷걸음질처럼 읽히는 문제를 없앤다

중요:
- 이 작업은 "새 walk를 다시 생성"하는 것이 아니다
- "existing V4 candidate의 국소 보정"이다
- 교정 대상은 오직:
  - head yaw
  - eye aim
  - muzzle center alignment

절대 유지해야 하는 것:
- big pink gingham bow stays on the HEAD, not the neck
- cream neck ribbon stays under the chin
- safety pin stays on the upper chest above the heart
- stitched heart belly patch stays the same
- left button eye + right dangling eye system stays intact
- black paw bow stays on the same paw
- front-facing walk structure stays intact
- leg alternation and motion energy must not flatten

Primary source:
- Gemini V4 candidate image
  If your actual saved filename differs, use the real file path.
  Expected path if needed:
  `.tmp/teddy_bear_walk_gemini_frontwalk_v4.png`

Secondary identity source:
- `d:\main\bosspong\.tmp\teddy_bear_stage3_redesign_anchor_v1.png`

Optional plush-mechanics source:
- `d:\main\bosspong\.tmp\teddy_bear_procedural_reference_v1.png`

Method:
- use FLUX Kontext max
- perform ONE narrow touch-up pass only
- do not branch into frame expansion from this step
- treat this as a surgical correction, not a redesign

Prompt intent:
- same exact teddy as the V4 candidate
- same exact bow placement, ribbon placement, safety pin placement, heart patch placement
- same walk sheet, same motion, same frame separation
- reduce only the slight rightward gaze bias
- eyes centered forward
- muzzle centered forward
- head yaw zero
- torso yaw zero
- stable left travel and stable right travel must both still read as
  front-facing walk, not as forward on one side and backward-stepping on
  the other
- keep the body front-facing and lively

Hard reject:
- head bow moves to neck
- cream neck ribbon deforms into a different accessory
- safety pin drifts from upper chest
- heart patch color or shape drifts
- dangling eye gimmick weakens or moves
- motion becomes flatter than V4
- frame differentiation decreases
- any side-facing / 3/4 drift appears
- if leftward travel would still read like the teddy is looking right and
  stepping backward, reject

Output:
- `.tmp/teddy_bear_walk_flux_yawfix_v1.png`
- `.tmp/teddy_bear_walk_flux_yawfix_v1.jpeg`
- optional:
  - `.tmp/teddy_bear_walk_flux_yawfix_v1_zoom.png`
  - `.tmp/teddy_bear_walk_flux_yawfix_v1_report.md`

Final decision must be explicit:
- ACCEPT only if the rightward glance is reduced and V4 identity / motion are preserved
- otherwise REJECT and keep Gemini V4 as the best candidate

Do NOT over-iterate.
One pass only.
If this pass drifts, stop and recommend keeping V4.
```
