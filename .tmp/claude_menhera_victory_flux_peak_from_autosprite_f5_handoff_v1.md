# Claude Handoff Prompt: Menhera Victory FLUX Peak From AutoSprite F5

아래 프롬프트를 그대로 Claude에 전달하면 됩니다.

```text
이번 작업은 PingFighter Stage 3 Menheragirl victory regeneration의 X1 descent step 1이다.

핵심 결론:
- AutoSprite motion block은 usable 했다
- 특히 f5가 명확한 victory peak triumph로 읽혔다
- 하지만 full-sheet FLUX render는 그 peak acting을 흡수하지 못하고 flat해졌다
- 따라서 이제는 full-sheet conditioning을 버리고, single-peak conditioning으로 내려간다

중요:
- `d:\main\bosspong\CLAUDE.md`를 따른다
- 반드시 `d:\main\bosspong\.claude\skills\sprite-generation\SKILL.md` 기준으로 진행한다
- 이번 패스는 single peak pose 생성이다
- walk / attack / dash / turn / defeat / runtime code는 건드리지 않는다
- canonical overwrite는 하지 말고 `.tmp` 후보 + QA까지만 한다

현재 브랜치 상태:
- live runtime victory는 여전히 P2 publish본 유지
- canonical walk remains the sole identity anchor
- old victory backup은 더 이상 generation input으로 쓰지 않는다
- V3 row 2 derived language도 input으로 쓰지 않는다

이번 패스 목표:
- AutoSprite motion block의 f5 peak pose를 FLUX가 제대로 imprint한
  single 1024x1024 canonical Menhera victory peak frame를 만든다
- 이 이미지가 통과하면 이후 f1/f2/f3/f4/f6/f7/f8 expansion의 strongest anchor가 된다

reference stack:
1. primary identity master
- `d:\main\bosspong\items\menhera_boss_sheet.png`

2. motion-only peak pose reference
- `d:\main\bosspong\.tmp\menhera_victory_autosprite_motion_v1_f5_peak.png`

3. dense identity board
- `d:\main\bosspong\.tmp\menhera_autosprite_reference_board_v2.png`

4. optional compare only after generation
- `d:\main\bosspong\items\menhera_boss_victory.png`
- current runtime victory is for QA compare only
- do NOT use it as a generation anchor

explicit exclusions:
- do NOT use `menhera_boss_victory_old.png`
- do NOT use rejected V3 frames
- do NOT use turn sheet as identity anchor
- do NOT use the whole AutoSprite motion sheet as input
- use only the cropped peak frame

model / method:
- FLUX Kontext
- prefer `flux_kontext_max`
- image-to-image single-character peak pose generation
- 1024x1024 square framing
- pure white background
- full body fully visible
- generous margin

identity lock (must match canonical walk exactly):
- fluffy pink outer hair
- cream/blonde inner front bangs
- rounded fluffy hair silhouette
- pink/white gingham nurse cap
- syringe on cap
- large gray/silver eyes with lashes
- exactly one pink heart cheek mark on viewer-right cheek
- pink outfit with white center panel
- target is four black bows in a clean vertical stack
- gray cat-paw gloves with visible pink pads
- same-side med-kit pouch
- pink check cloth-tail motif
- plain white thigh-highs
- black X ankle accessories
- same petite chibi body class
- thick black pixel outlines

hard anti-drift rules:
- no twin-tail branch
- no random red side-ribbon redesign
- no small-cap redesign
- no anime-soft rendering
- no pink sock trim
- no loss of syringe / paw pads / med-kit
- if the result resembles rejected V3 row 2, reject immediately

peak acting brief:
- this must read instantly as the happiest victory peak
- same exact Menhera identity, but triumphant
- clearly stronger celebration than the current runtime victory

required pose language:
- use the AutoSprite f5 composition as motion-only guidance
- raised paws / victorious uplift should be visible
- pink paw pads should face forward enough to read
- slight hop / lifted body energy is encouraged
- chest / shoulders can open slightly
- hair / ribbon / skirt / tail rebound can support the peak
- must read like "I won!" not neutral idle, not turn, not sway

required expression language:
- same exact Menhera face structure as canonical walk
- but allowed to look delighted
- acceptable:
  - brighter eyes
  - pleased or delighted smile
  - slightly open happy mouth
  - subtle happy squint only if identity stays locked
- unacceptable:
  - emoji-like generic closed-eye grin
  - prettier different hero-frame girl
  - changed eye spacing
  - changed bangs framing

negative constraints:
- do NOT let FLUX flatten the pose back into paws-near-hips neutral stance
- do NOT let the image read like a turn frame
- do NOT let the image read like attack impact
- do NOT trade away identity just to get more joy

gameplay-scale readability:
- face, cap, syringe, cheek heart, bows, paw pads, med-kit, cloth-tail, and socks must remain readable at gameplay size
- body read must stay within about +/-5% of canonical walk
- motion accents must not shrink the visible body

output targets:
- `.tmp/menhera_flux_kontext_victory_peak_from_autosprite_v1.png`
- `.tmp/menhera_flux_kontext_victory_peak_from_autosprite_v1.jpeg`
- optional:
  - `.tmp/menhera_flux_kontext_victory_peak_from_autosprite_v1_zoom.png`
  - `.tmp/menhera_flux_kontext_victory_peak_from_autosprite_v1_vs_walk.png`
  - `.tmp/menhera_flux_kontext_victory_peak_from_autosprite_v1_vs_runtime.png`
  - `.tmp/menhera_flux_kontext_victory_peak_from_autosprite_v1_vs_motion_peak.png`
  - `.tmp/menhera_flux_kontext_victory_peak_from_autosprite_v1_report.md`

QA requirements:
1. AutoSprite f5 peak acting was actually imprinted or not?
2. canonical walk identity lock pass/fail
3. any old-victory-style leak present or not?
4. 4-bow count intact or not?
5. pink paw pads, med-kit, syringe intact or not?
6. stronger celebration than the current runtime victory or not?
7. strong enough to become the primary anchor for frame expansion or not?

stop-and-ask:
- if identity is perfect but the peak still flattens out, HOLD and say FLUX is underweighting the motion crop
- if celebration is strong but any design leak appears, HOLD and reject
- this pass succeeds only if it captures BOTH canonical identity and clear triumph

final report format:
1. reference stack actually used
2. whether the AutoSprite f5 peak was successfully transferred
3. canonical walk identity lock pass/fail
4. peak celebration readability pass/fail
5. whether this image is strong enough to become the primary anchor for frame expansion
```
