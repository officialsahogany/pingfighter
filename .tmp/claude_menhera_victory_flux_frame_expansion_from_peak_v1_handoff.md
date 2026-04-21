# Claude Handoff Prompt: Menhera Victory FLUX Frame Expansion From Peak V1

아래 프롬프트를 그대로 Claude에 전달하면 됩니다.

```text
이번 작업은 PingFighter Stage 3 Menheragirl victory regeneration의 X1 descent step 2이다.

중요:
- `d:\main\bosspong\CLAUDE.md`를 따른다
- 반드시 `d:\main\bosspong\.claude\skills\sprite-generation\SKILL.md` 기준으로 진행한다
- runtime integration은 하지 않는다
- canonical overwrite는 하지 않는다
- `.tmp` 후보 + QA + report까지만 만든다

현재 상태:
- single peak anchor가 ACCEPTED 되었다
- accepted anchor:
  - `d:\main\bosspong\.tmp\menhera_flux_kontext_victory_peak_from_autosprite_v1.png`
- 이 이미지는 canonical walk identity를 완전히 유지하면서도
  clear victory peak acting을 확보했다
- live runtime victory는 아직 P2 publish본 유지 중이다
- canonical walk remains the sole identity anchor

이번 단계 목표:
- accepted peak anchor를 strongest identity/style/acting anchor로 사용해
  나머지 victory frames를 개별 생성한다
- 목표는 8-frame victory sequence:
  build -> rise -> gather -> pre-peak -> peak -> hold -> afterglow -> final hold
- full-sheet direct 재시도는 하지 않는다
- peak + frame expansion 파이프라인을 사용한다

reference stack:
1. primary anchor
- `d:\main\bosspong\.tmp\menhera_flux_kontext_victory_peak_from_autosprite_v1.png`

2. canonical walk
- `d:\main\bosspong\items\menhera_boss_sheet.png`

3. dense identity board
- `d:\main\bosspong\.tmp\menhera_autosprite_reference_board_v2.png`

4. AutoSprite motion block (motion amplitude reference only)
- `d:\main\bosspong\.tmp\menhera_victory_autosprite_motion_v1.png`

5. optional compare only after generation
- `d:\main\bosspong\items\menhera_boss_victory.png`
- current runtime P2 is compare-only, not a generation anchor

explicit exclusions:
- do NOT use old victory backup as input
- do NOT use rejected V3 frames as input
- do NOT use turn sheet as identity anchor

model / method:
- FLUX Kontext image-to-image
- prefer `flux_kontext_max`
- generate remaining frames individually
- accepted peak anchor is the strongest style + identity + acting lock

identity / style lock for every generated frame:
- same exact Menhera as canonical walk and accepted peak
- fluffy pink outer hair
- cream/blonde inner front bangs
- rounded fluffy hair silhouette
- pink/white gingham nurse cap
- syringe on cap
- large gray/silver eyes with lashes
- exactly one pink heart cheek mark on viewer-right cheek
- white center panel with exactly FOUR black bows in a clean vertical stack
- gray cat-paw gloves with visible pink pads
- same-side med-kit pouch
- pink check cloth-tail motif
- plain white thigh-highs
- black X ankle accessories
- same petite chibi body class
- thick black pixel outlines
- same PingFighter 16-bit pixel class as accepted peak / canonical walk

hard anti-drift rules:
- no twin-tail branch
- no big side-ribbon redesign
- no small-cap redesign
- no anime-soft regression
- no pink sock trim
- no loss of syringe / paw pads / med-kit
- no row-to-row identity drift
- no one-or-two-frame prettier hero-frame drift

victory sequence definition:
- unmistakable front-facing victory celebration
- NOT a walk loop
- NOT a turn extension
- NOT lateral sway posing
- NOT attack windup/impact
- must read as:
  recognition -> rising joy -> gather -> push into triumph -> peak triumph -> hold -> warm afterglow -> final satisfied hold

frame-by-frame motion brief:

Frame 1:
- post-win recognition
- calmer than the peak
- a small spark of delight begins
- near-neutral but clearly not walking

Frame 2:
- joy rises
- slight chest lift / brighter face
- subtle paw preparation begins
- body still grounded

Frame 3:
- excited gather
- more visible paw lift prep
- slight knee / body compress before the rise
- immediate predecessor to the push

Frame 4:
- push into triumph
- body begins to lift
- celebration energy clearly visible
- must read as right before the accepted peak

Frame 5:
- reuse accepted peak:
  - `d:\main\bosspong\.tmp\menhera_flux_kontext_victory_peak_from_autosprite_v1.png`

Frame 6:
- held triumph
- still clearly celebratory
- slightly less explosive than frame 5
- should preserve the happy face / raised-paw logic

Frame 7:
- warm satisfied afterglow
- joy relaxing
- still visibly victorious, not flat idle

Frame 8:
- final happy hold
- stable close frame
- relaxed but still unmistakably post-victory

important acting rule:
- frame 5 is the accepted peak
- frames 1-4 must build into it
- frames 6-8 must descend from it without collapsing into neutral turn-like poses
- expression progression is allowed, but the same Menhera face must remain locked

output targets:
- `.tmp/menhera_flux_kontext_victory_f1_v1.png`
- `.tmp/menhera_flux_kontext_victory_f2_v1.png`
- `.tmp/menhera_flux_kontext_victory_f3_v1.png`
- `.tmp/menhera_flux_kontext_victory_f4_v1.png`
- `.tmp/menhera_flux_kontext_victory_f6_v1.png`
- `.tmp/menhera_flux_kontext_victory_f7_v1.png`
- `.tmp/menhera_flux_kontext_victory_f8_v1.png`
- stitched preview:
  - `.tmp/menhera_flux_kontext_victory_stitched_v1_preview.png`
- summary report:
  - `.tmp/menhera_flux_kontext_victory_frame_expansion_v1_report.md`

after frame generation:
- build a quick ordered 4x2 preview
- frame order:
  - row 1: f1 f2 f3 f4
  - row 2: f5 f6 f7 f8
- do NOT overwrite `items/menhera_boss_victory.png` yet

QA requirements per frame:
- same Menhera as accepted peak and canonical walk
- same pixel class / outline class / palette class
- 4 black bows readable
- med-kit side stays locked
- pink paw pads stay visible
- no anime-soft regression
- no walk / turn / sway read
- no body-size drift
- plain white socks remain plain white

sequence-level QA:
- frames 1 -> 5 must read as a clean build into peak
- frames 5 -> 8 must read as a clean celebratory descent
- no row split where row 1 and row 2 feel like different characters
- no collapse back into the flat P2 acting problem
- if one or two frames fail identity or style, regenerate only those frames rather than discarding the whole set

if frame expansion passes:
- recommend next step:
  1. stitch to 2752x1536 uniform scaling
  2. JPEG export
  3. remove_bg.py nukki
  4. edge QA (4 bows / paw pads / med-kit / cream bangs / syringe / plain socks)
  5. gameplay QA vs canonical walk + current P2 runtime victory + old victory backup

hard reject:
- identity drift from accepted peak / canonical walk
- 4-bow loss
- med-kit side drift
- pink paw-pad loss
- pink sock trim reappears
- soft anime / anti-aliased rendering regression
- walk / turn / sway / attack read
- row 1 vs row 2 different-character split
- body scale drift beyond subtle tolerance

final report format:
1. which frames were generated
2. which reference stack was actually used
3. generated file paths
4. per-frame pass/fail summary
5. stitched preview sequence readability evaluation
6. whether the sequence now solves the flat-celebration problem
7. whether it is ready for publish-pack staging
```
