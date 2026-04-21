# Claude Handoff Prompt: Menhera Victory FLUX Peak V1

아래 프롬프트를 그대로 Claude에 전달하면 됩니다.

```text
이번 작업은 PingFighter Stage 3 Menheragirl victory regeneration의 descent step 1이다.

중요:
- `d:\main\bosspong\CLAUDE.md`를 따른다
- 반드시 `d:\main\bosspong\.claude\skills\sprite-generation\SKILL.md` 기준으로 진행한다
- 이번 패스는 full-sheet가 아니라 single peak pose 생성이다
- walk / attack / dash / turn / defeat / runtime code는 건드리지 않는다
- canonical overwrite는 하지 말고 `.tmp` 후보 + QA까지만 한다

왜 peak-first로 내려가는가:
- direct full-sheet P2 publish본은 identity는 좋았지만 celebration acting이 flat했다
- V3 celebration-first full-sheet는 row 2 acting은 좋아졌지만 identity leak로 HOLD / REJECT 되었다
- 특히 old victory를 motion master로 넣자 twin-tail + red-ribbon design이 row 2에 leak되었다
- 따라서 이제는 old victory를 generation input stack에서 완전히 제외한다
- acting은 reference image가 아니라 prompt design으로 만든다

현재 live 상태:
- `items/menhera_boss_victory.png`는 P2 publish본이 적용되어 있다
- 이건 runtime-only non-anchor auxiliary sheet다
- canonical walk remains the sole identity anchor
- V3 row 2 or old victory must NOT be used as a future identity anchor

이번 패스 목표:
- single 1024x1024 peak victory pose를 만든다
- same exact Menhera identity를 유지하면서도
- unmistakable "I won" celebration peak frame를 확보한다
- 이 이미지가 통과하면 이후 f1/f2/f3/f4/f6/f7/f8 expansion의 strongest anchor가 된다

reference stack:
1. primary identity master
- `d:\main\bosspong\items\menhera_boss_sheet.png`

2. dense identity board
- `d:\main\bosspong\.tmp\menhera_autosprite_reference_board_v2.png`

3. optional negative comparison only after generation
- `d:\main\bosspong\items\menhera_boss_victory.png`
- current runtime victory is for QA compare only
- do NOT feed it as input if avoidable

explicit exclusions:
- do NOT use `menhera_boss_victory_old.png` as input
- do NOT use any V3 row-2-derived frame as input
- do NOT use turn sheet as identity anchor

model / method:
- FLUX Kontext
- prefer `flux_kontext_max`
- image-to-image single-character peak pose generation
- 1024x1024 or equivalent single-figure square framing
- pure white background
- full body fully visible
- generous margin

identity lock (must match canonical walk exactly):
- fluffy pink outer hair
- cream/blonde inner front bangs
- rounded fluffy hair silhouette
- pink/white gingham nurse cap
- syringe on cap
- same Menhera face structure
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

hard anti-leak rule:
- absolutely NO twin-tail design
- absolutely NO two red side ribbons replacing the canonical hair / cap language
- absolutely NO small cap redesign
- absolutely NO old-victory character branch
- if the result looks like row 2 of rejected V3, reject immediately

style lock:
- 16-bit retro pixel art
- chibi proportions
- thick black pixel outlines
- flat limited-saturation pastel palette
- clean hard-edged pixels
- NO anime-soft rendering
- NO painterly shading
- NO glossy mobile-game chibi feel

peak acting brief:
- this is the happiest / clearest victory peak frame
- must read instantly as "I won"
- triumphant, delighted, excited Menhera
- front-facing celebration
- same eerie-cute boss personality, not generic idol dance

required motion language for the peak:
- visible upward body energy
- slight hop / lift / buoyant rise is encouraged
- one or both paw-gloves can lift in an excited victorious gesture
- shoulders and chest can open slightly
- hair / ribbon / skirt / tail rebound should support the upward beat
- pose must feel like the climax of a celebration, not a neutral idle or turn pose

required expression language:
- same exact Menhera face
- but clearly happier than walk
- acceptable:
  - brighter eyes
  - pleased or delighted smile
  - slightly open happy mouth
  - subtle happy squint only if still recognizably the same face
- unacceptable:
  - generic emoji closed-eye grin if identity collapses
  - different eye spacing
  - prettier or different "hero-frame" girl
  - changed bangs framing

negative constraints:
- do NOT make it read like left-right sway
- do NOT make it read like a turn frame
- do NOT make it read like quiet idle posing
- do NOT make it read like an attack impact
- do NOT sacrifice identity just to get more celebration

gameplay-scale readability:
- face, cap, syringe, cheek heart, bows, paw pads, med-kit, cloth-tail, and socks must remain readable at gameplay size
- body read must stay within about +/-5% of canonical walk
- motion accents must not shrink the visible body

output targets:
- `.tmp/menhera_flux_kontext_victory_peak_v1.png`
- `.tmp/menhera_flux_kontext_victory_peak_v1.jpeg`
- optional:
  - `.tmp/menhera_flux_kontext_victory_peak_v1_zoom.png`
  - `.tmp/menhera_flux_kontext_victory_peak_v1_vs_walk.png`
  - `.tmp/menhera_flux_kontext_victory_peak_v1_vs_runtime_v2.png`
  - `.tmp/menhera_flux_kontext_victory_peak_v1_report.md`

QA requirements:
1. same exact Menhera as canonical walk?
2. unmistakable victory peak rather than turn / idle / sway?
3. any old-victory twin-tail / red-ribbon leak?
4. 4-bow count intact?
5. pink paw pads, med-kit, syringe intact?
6. true upgrade over current runtime victory in celebration acting without losing identity?

stop-and-ask:
- if identity is perfect but the pose is still too flat, HOLD and say peak acting needs a stronger prompt or motion block
- if celebration is strong but any old-victory branch leaks in, HOLD and reject
- this pass succeeds only if it captures BOTH identity and triumph

final report format:
1. reference stack actually used
2. whether old-victory leak was fully prevented
3. canonical walk identity lock pass/fail
4. celebration peak readability pass/fail
5. whether this image is strong enough to become the primary anchor for frame expansion
```
