# Claude Handoff Prompt: Stage 3 Teddy Bear Walk Sheet via FLUX V1

아래 프롬프트를 그대로 Claude에 전달하면 됩니다.

```text
이번 작업은 PingFighter Stage 3 Teddy Bear boss의 첫 canonical walk sheet 제작이다.

이번 패스에서는 accepted redesign anchor가 이미 있으므로, Gemini가 아니라 FLUX Kontext를 우선 사용한다.

이유:
- 이제는 새 디자인 발명 단계가 아니라
  "accepted teddy redesign anchor를 보존한 채 gameplay walk sheet로 확장"하는 단계다
- 강한 identity anchor가 생겼으므로 reference-conditioned FLUX가 더 적합하다

중요:
- `d:\main\bosspong\CLAUDE.md`를 따른다
- 반드시 `d:\main\bosspong\.claude\skills\sprite-generation\SKILL.md` 기준으로 진행한다
- 이번 단계는 walk sheet candidate 제작이다
- runtime integration / canonical overwrite는 하지 않는다
- `.tmp` 후보 + QA까지만 만든다

현재 accepted identity anchor:
- `d:\main\bosspong\.tmp\teddy_bear_stage3_redesign_anchor_v1.png`

anchor 상태:
- accepted redesign anchor
- teddy species read PASS
- Stage 3 menhera decoration PASS
- no humanization
- strong enough to drive walk-sheet generation

reference stack:
1. strongest identity master
- `d:\main\bosspong\.tmp\teddy_bear_stage3_redesign_anchor_v1.png`

2. current procedural teddy reference (motion / plush-mechanics only)
- `d:\main\bosspong\.tmp\teddy_bear_procedural_reference_v1.png`
- use only for plush body logic, seam language, and general toy motion feel
- do NOT let it downgrade the accepted redesign anchor

3. optional Stage 3 mood / palette tone reference
- `d:\main\bosspong\items\menhera_boss_sheet.png`
- mood / accessory tone only
- do NOT copy human body design

모델 / 방식:
- FLUX Kontext
- prefer `flux_kontext_max`
- full 8-frame walk sheet direct generation first
- if direct sheet keeps identity and front-read, keep it
- if direct sheet drifts too much, HOLD and recommend peak / frame-expansion fallback

sheet target:
- 8-frame walk sheet
- 4x2 grid
- aspectRatio 16:9
- imageSize 2K
- pure white background
- no grid lines
- no labels
- no borders
- full body fully visible in every frame
- generous white margin

identity lock (must match accepted redesign anchor exactly):
- plush teddy silhouette
- warm cocoa-brown fur family
- thick black pixel outline logic
- left button eye with X-thread
- right dangling / damaged eye language
- large pink gingham head bow
- cream neck ribbon / collar accent
- safety pin chest charm
- stitched cream belly oval with pink heart motif
- bandage patch details
- mismatched pink paw / patch asymmetry
- small black bow accent on arm
- plush paws and stuffed-limb body logic
- no human face, no human body logic

style lock:
- 16-bit retro pixel art
- chibi plush proportions
- flat limited-saturation palette
- clean hard-edged pixels
- NO painterly rendering
- NO soft-anime illustration
- same clarity class as the accepted redesign anchor

walk design goal:
- unmistakably a walk cycle, not idle posing
- front-biased / front-facing during stable movement
- still the same teddy bear from the anchor
- should feel like a heavy-but-cute plush toy moving with stitched bounce

motion language to preserve from the procedural teddy:
- soft body bob
- slight body roll
- compact plush arm swing
- ear bounce
- bow / ribbon flutter
- dangling eye sway / thread pull feel
- tiny unstable plush wobble, not athletic human gait

very important movement constraints:
- do NOT make it stride like a human girl
- do NOT give it long elegant legs or human hip swing
- do NOT turn stable movement into a side-facing profile walk
- do NOT let the dangling-eye gimmick disappear
- do NOT let the head accessory or chest accessories vanish in motion

front-read requirement:
- stable movement must still read as facing the player
- it can have mild asymmetry and plush wobble
- but it must NOT read as persistently looking left or right during travel
- hair-like / ribbon-like bias that turns the whole teddy into a side-looking pose is a fail

recommended 8-frame walk rhythm:
- row 1:
  1. contact / plush settle
  2. slight rise
  3. opposite support
  4. plush rebound
- row 2:
  5. second contact
  6. second rise
  7. opposite support
  8. second plush rebound

readability priorities at gameplay scale:
- teddy species read first
- eyes / bow / belly heart / safety pin / patches / paw asymmetry must stay readable
- body read must stay stable across all 8 frames
- avoid outward accessory noise that shrinks the torso / face read

hard reject:
- humanized walk
- side-facing walk bias
- loss of dangling-eye identity
- loss of belly heart or main bow
- muddy or painterly rendering
- body read shrinking across frames
- one or more frames reading like a different teddy redesign

output targets:
- `.tmp/teddy_bear_walk_v1.png`
- `.tmp/teddy_bear_walk_v1.jpeg`
- optional:
  - `.tmp/teddy_bear_walk_v1_zoom.png`
  - `.tmp/teddy_bear_walk_v1_gameplay.png`
  - `.tmp/teddy_bear_walk_v1_vs_anchor.png`
  - `.tmp/teddy_bear_walk_v1_report.md`

QA priorities:
1. same exact teddy redesign as the accepted anchor?
2. stable front-facing gameplay walk rather than side-walk?
3. plush bob / ear bounce / dangling-eye motion still readable?
4. accessories preserved at gameplay scale?
5. strong enough to become the canonical teddy walk candidate?

stop-and-ask:
- if the sheet keeps identity but walk reads too side-facing, HOLD and reject
- if the sheet becomes too humanized in gait, HOLD and reject
- if FLUX washes out the dangling eye / bow / heart language, HOLD and reject
- this pass succeeds only if the teddy stays plush, front-readable, and stage-3-identifiable

final report format:
1. reference stack actually used
2. accepted anchor identity lock pass/fail
3. front-read walk pass/fail
4. plush motion language pass/fail
5. whether this is strong enough to become the canonical teddy walk-sheet candidate
6. if not, whether the next step should be narrow touch-up or peak/frame-expansion fallback
```
