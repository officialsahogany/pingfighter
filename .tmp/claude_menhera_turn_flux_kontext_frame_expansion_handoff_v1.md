# Claude Handoff Prompt: Menhera Turn FLUX Kontext Frame Expansion V1

아래 프롬프트를 그대로 Claude에게 전달하면 됩니다.

```text
이번 작업은 PingFighter Stage 3 Menheragirl turn 작업의 FLUX Kontext frame expansion 패스다.

중요:
- `d:\main\bosspong\CLAUDE.md`를 따르고
- 반드시 `d:\main\bosspong\.claude\skills\sprite-generation\SKILL.md` 기준으로 진행해줘
- runtime integration은 하지 않는다
- canonical overwrite는 하지 않는다

현재 상태:
- `d:\main\bosspong\.tmp\menhera_flux_kontext_peak_v2.png` 가 single peak anchor로 통과했다
- identity lock, pixel class, 4-bow count 모두 usable 수준
- 이제 이 peak를 기준으로 entry 3장 + recovery 3장을 생성해 8-frame turn sequence의 나머지 프레임을 확보하려고 한다

작업 목표:
- FLUX Kontext image-to-image로 frame 1, 2, 3, 5, 6, 7을 개별 생성
- frame 4는 기존 `menhera_flux_kontext_peak_v2.png`
- frame 8은 우선 frame 1 재사용을 기본안으로 둔다
- 모든 프레임은 SAME Menhera, SAME pixel class, SAME body read를 유지해야 한다

핵심 reference stack:
1. primary anchor
- `d:\main\bosspong\.tmp\menhera_flux_kontext_peak_v2.png`

2. dense identity board
- `d:\main\bosspong\.tmp\menhera_autosprite_reference_board_v2.png`

3. canonical walk
- `d:\main\bosspong\items\menhera_boss_sheet.png`

4. victory quality reference
- `d:\main\bosspong\items\menhera_boss_victory.png`

5. optional motion amplitude reference only
- `d:\main\bosspong\.tmp\menhera_turn_autosprite_v2_frame_3.png`
- `d:\main\bosspong\.tmp\menhera_turn_autosprite_v2_frame_4.png`

모델 / 방식:
- FLUX Kontext image-to-image
- 가능하면 `flux_kontext_max`
- 각 프레임을 별도 생성
- peak V2를 strongest identity/style anchor로 유지

절대 잃으면 안 되는 것:
- fluffy pink outer hair
- cream/blonde inner front bangs
- rounded fluffy hair silhouette
- pink/white gingham nurse cap
- syringe on cap
- front ribbon language
- one pink heart cheek mark
- gray/silver eyes with lashes
- white center panel with exactly FOUR black bows in a clean vertical stack
- gray cat-paw gloves with visible pink pads
- same-side med-kit pouch
- pink check cloth-tail motif
- white thigh-highs
- black X ankle accessories
- thick black pixel outlines
- same PingFighter 16-bit pixel class as peak V2 / canonical walk / victory

minor drift cleanup guidance:
- do NOT amplify the small V2 drift where pink accents appeared at the top of the thigh-highs
- if possible, nudge those back toward the canonical without destabilizing identity
- do NOT let the cap ribbon drift farther away from the canonical front-ribbon language

turn sequence definition:
- front-facing conservative micro-turn
- NOT a greeting wave
- NOT an attack swing
- NOT a dance loop
- NOT a side-profile turn
- NOT strong 3/4 rotation
- the whole arc should read as:
  carry-in -> compress -> wind-up -> peak -> rebound -> recovery -> settle -> walk return

frame-by-frame motion brief:

Frame 1:
- near-neutral carry-in from walk
- almost canonical walk language
- only a faint hint of the future redirect
- compact, centered, walk-compatible

Frame 2:
- tiny compress / plant
- subtle weight shift begins
- torso participates slightly
- still restrained, not theatrical

Frame 3:
- slight chin-lift wind-up
- small outward paw preparation
- slight knee gather
- must read as the immediate predecessor to the peak

Frame 4:
- reuse `d:\main\bosspong\.tmp\menhera_flux_kontext_peak_v2.png`

Frame 5:
- rebound from peak
- same direction logic as frame 4
- motion relaxing, not snapping

Frame 6:
- recovery step
- soft settling of paw / chin / torso
- body read stays matched to frame 4

Frame 7:
- settle toward neutral frontal walk
- nearly ready to drop back into canonical walk

Frame 8:
- default plan is reuse frame 1 for loop closure
- only generate a separate frame 8 if reuse clearly fails at QA

output targets:
- `.tmp/menhera_flux_kontext_turn_f1_v1.png`
- `.tmp/menhera_flux_kontext_turn_f2_v1.png`
- `.tmp/menhera_flux_kontext_turn_f3_v1.png`
- `.tmp/menhera_flux_kontext_turn_f5_v1.png`
- `.tmp/menhera_flux_kontext_turn_f6_v1.png`
- `.tmp/menhera_flux_kontext_turn_f7_v1.png`
- optional QA zoom / compare sheets as needed
- summary report:
  - `.tmp/menhera_flux_kontext_turn_frame_expansion_v1_report.md`

QA requirements per frame:
- same Menhera as peak V2 and canonical walk
- same pixel class / outline class / palette class
- 4 black bows still readable
- med-kit side stays locked
- pink paw pads stay visible
- no anime-soft regression
- no wave / attack / side-turn read
- no body-size drift

sequence-level QA:
- frames 1 -> 4 must read as a clean build into peak
- frames 4 -> 7 must read as a clean recovery
- frame 7 -> frame 8 -> walk must reconnect naturally
- if one or two frames fail identity or style, regenerate only those frames rather than discarding the whole set

after frame generation:
- build a quick ordered contact sheet or stitched 4x2 preview for QA
- keep frame order:
  - row 1: f1 f2 f3 f4
  - row 2: f5 f6 f7 f8
- do NOT overwrite `items/menhera_boss_turn.png` yet

hard reject:
- identity drift from peak V2 / canonical walk
- 4-bow loss
- med-kit side drift
- pink paw-pad loss
- soft anime / anti-aliased rendering regression
- wave / attack / side-facing read
- body scale drift larger than a subtle tolerance

최종 보고 형식:
1. 어떤 frame들을 생성했는지
2. 어떤 reference stack을 실제 사용했는지
3. 생성 파일 경로
4. 프레임별 통과 / 실패 요약
5. stitched preview 기준 sequence readability 평가
6. frame 8 재사용으로 충분한지 여부
7. canonical turn sheet 후보 단계까지 왔는지 여부
```
