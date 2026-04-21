# Claude Handoff Prompt: Stage 3 Teddy Bear Walk FLUX Peak -> Frame Expansion V1

아래 프롬프트를 그대로 Claude에 전달하면 됩니다.

```text
이번 작업은 PingFighter Stage 3 Teddy Bear walk regeneration의 fallback Path B다.

핵심 결론:
- direct full-sheet FLUX walk V1은 REJECT
- 이유:
  - walk cycle이 아니라 idle gallery처럼 나옴
  - accepted teddy anchor identity가 8프레임에 걸쳐 유지되지 않음
  - dangling-eye / ears / accessories / fur tone drift 발생
  - style이 16-bit pixel class가 아니라 soft sticker / plush illustration 쪽으로 무너짐
- 따라서 direct full-sheet 재시도보다 peak-lock -> frame expansion으로 내려간다

중요:
- `d:\main\bosspong\CLAUDE.md`를 따른다
- 반드시 `d:\main\bosspong\.claude\skills\sprite-generation\SKILL.md` 기준으로 진행한다
- runtime integration은 하지 않는다
- canonical overwrite는 하지 않는다
- `.tmp` 후보 + QA + report까지만 만든다

현재 accepted identity anchor:
- `d:\main\bosspong\.tmp\teddy_bear_stage3_redesign_anchor_v1.png`

rejected direct full-sheet:
- `d:\main\bosspong\.tmp\teddy_bear_walk_v1.jpeg`
- this rejected sheet is QA evidence only
- do NOT use it as a generation anchor

reference stack for the fallback path:
1. strongest identity master
- `d:\main\bosspong\.tmp\teddy_bear_stage3_redesign_anchor_v1.png`

2. procedural teddy motion/plush reference
- `d:\main\bosspong\.tmp\teddy_bear_procedural_reference_v1.png`
- motion feel only
- do NOT let it downgrade the accepted redesign anchor

3. optional compare only after generation
- `d:\main\bosspong\.tmp\teddy_bear_walk_v1.jpeg`
- compare only, do NOT use as input

explicit exclusions:
- do NOT use human-shaped menhera walk as a generation ref for gait
- do NOT use rejected walk V1 as an anchor
- do NOT use any other teddy redesign candidate as a hidden identity source

==================================================
STEP 1. LOCK A SINGLE WALK ANCHOR FRAME
==================================================

Goal:
- create one canonical teddy walk anchor frame first
- this is not a "victory peak"; it is a representative walk key pose
- choose a strong walk-rise / support pose that preserves the accepted redesign anchor
- this image must prove:
  - exact teddy identity lock
  - front-biased walk read
  - readable plush motion

method:
- FLUX Kontext
- prefer `flux_kontext_max`
- single-character image-to-image
- square framing (1024x1024 preferred)
- pure white background
- full body fully visible
- generous margin

walk anchor pose brief:
- front-facing plush walk key pose
- one support leg slightly favored
- subtle body rise
- compact plush arm swing
- small ear bounce / bow flutter
- dangling-eye sway still visible
- unmistakably walking, not idle posing
- must still feel like a stuffed teddy, not a human gait pose

identity lock for the anchor frame:
- exact accepted redesign teddy
- cocoa-brown fur
- left button eye with X-thread
- right dangling damaged eye
- large pink gingham head bow
- cream neck ribbon
- safety pin chest charm
- stitched cream belly oval with pink heart motif
- bandage patches
- mismatched pink paw patch
- small black bow accent
- plush paws and stuffed-limb body logic

hard reject for anchor frame:
- dangling eye missing
- walk still looks like idle
- humanized leg / hip gait
- side-facing profile walk
- soft sticker rendering
- ear recolor / face redesign / accessory loss

anchor outputs:
- `.tmp/teddy_bear_walk_anchor_v1.png`
- `.tmp/teddy_bear_walk_anchor_v1.jpeg`
- optional:
  - `.tmp/teddy_bear_walk_anchor_v1_zoom.png`
  - `.tmp/teddy_bear_walk_anchor_v1_vs_redesign_anchor.png`
  - `.tmp/teddy_bear_walk_anchor_v1_report.md`

anchor QA:
1. same exact teddy as accepted redesign anchor?
2. clearly a walk pose rather than idle?
3. dangling-eye / bow / belly-heart / safety-pin all intact?
4. front-facing plush walk read preserved?
5. strong enough to become the primary anchor for frame expansion?

If anchor QA FAILS, stop there and report HOLD.
Do not move to frame expansion.

==================================================
STEP 2. FRAME EXPANSION FROM THE ACCEPTED WALK ANCHOR
==================================================

Only do this if Step 1 passes.

Goal:
- generate the remaining 7 walk frames individually from the accepted walk anchor
- build a real 8-frame walk sequence with readable plush rhythm
- prevent the identity drift and soft-style collapse seen in direct full-sheet V1

reference stack:
1. primary anchor
- `.tmp/teddy_bear_walk_anchor_v1.png`

2. accepted redesign anchor
- `d:\main\bosspong\.tmp\teddy_bear_stage3_redesign_anchor_v1.png`

3. procedural teddy reference
- `d:\main\bosspong\.tmp\teddy_bear_procedural_reference_v1.png`
- motion feel only

sequence definition:
- front-biased plush walk
- NOT idle posing
- NOT side-profile march
- NOT human strut
- the 8-frame read should be:
  contact -> rise -> support shift -> rebound -> contact -> rise -> support shift -> rebound

frame-by-frame brief:

Frame 1:
- plush contact / settle
- grounded
- slight compression

Frame 2:
- slight rise
- body bob upward
- beginning of opposite arm response

Frame 3:
- support shift
- one side favored a bit more
- dangling-eye sway readable

Frame 4:
- plush rebound
- transition back toward the second contact

Frame 5:
- second contact
- mirrored logic, still front-readable

Frame 6:
- second rise
- body bob upward again

Frame 7:
- second support shift
- asymmetry readable but identity still fixed

Frame 8:
- second rebound
- clean loop back to frame 1

generated outputs:
- `.tmp/teddy_bear_walk_f1_v1.png`
- `.tmp/teddy_bear_walk_f2_v1.png`
- `.tmp/teddy_bear_walk_f3_v1.png`
- `.tmp/teddy_bear_walk_f4_v1.png`
- `.tmp/teddy_bear_walk_f5_v1.png`
- `.tmp/teddy_bear_walk_f6_v1.png`
- `.tmp/teddy_bear_walk_f7_v1.png`
- `.tmp/teddy_bear_walk_f8_v1.png`
- stitched preview:
  - `.tmp/teddy_bear_walk_stitched_v2_preview.png`
- report:
  - `.tmp/teddy_bear_walk_frame_expansion_v1_report.md`

identity/style lock for every frame:
- exact accepted redesign teddy in every frame
- same fur family and palette
- same dangling-eye identity
- same bow / heart / safety-pin / patches / asymmetry language
- same 16-bit pixel class
- thick readable outline logic
- no soft illustration drift

sequence-level QA:
- real walk rhythm visible at gameplay scale
- no row split into different teddy identities
- no accessory dropouts
- front-facing read preserved in stable movement
- body read stable across all 8 frames
- dangling-eye remains part of the design, not a sometimes-on/sometimes-off feature

hard reject:
- identity drift across frames
- walk still reads like idle gallery
- dangling-eye missing in some frames
- ear recolor / face redesign / missing accessories
- style drift to sticker/plush illustration
- humanized gait
- side-facing walk bias

final report format:
1. whether Step 1 anchor passed or failed
2. if passed, which frames were generated in Step 2
3. reference stack actually used
4. per-frame pass/fail summary
5. stitched preview walk-read evaluation
6. whether this sequence is now strong enough to become the canonical teddy walk-sheet candidate
7. if accepted, whether the next step should be publish-pack staging or a narrow touch-up on specific frames
```
