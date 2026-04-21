# Claude Handoff Prompt: Menhera Victory FLUX Full-Sheet V1

아래 프롬프트를 그대로 Claude에게 전달하면 됩니다.

```text
이번 작업은 PingFighter Stage 3 Menheragirl victory sheet를 FLUX Kontext로 다시 만드는 것이다.

중요:
- `d:\main\bosspong\CLAUDE.md`를 따르고
- 반드시 `d:\main\bosspong\.claude\skills\sprite-generation\SKILL.md` 기준으로 진행해줘
- 이번 패스는 victory 전용
- walk / attack / dash / turn / defeat는 건드리지 않는다
- runtime integration은 하지 않는다
- canonical overwrite는 바로 하지 않고, `.tmp` 후보 + QA까지만 한다

현재 문제:
- 현재 `items/menhera_boss_victory.png`는 일부 프레임에서 face / identity drift가 있고
- canonical walk와 병치했을 때 "같은 Menhera"로 읽히는 안정성이 부족하다
- victory pose의 큰 흐름은 유지하고 싶지만, 얼굴 / cap / eyes / prop identity는 canonical walk 기준으로 다시 잠가야 한다

핵심 결정:
- canonical walk가 sole identity anchor다
- current victory는 identity master가 아니라 "motion intent / celebration energy / clarity tier 참고"로만 사용한다
- turn V3 같은 non-anchor auxiliary 자산은 이번 victory regen의 기준으로 쓰지 않는다

실제 사용할 reference stack:

1. identity master (strongest anchor)
- `d:\main\bosspong\items\menhera_boss_sheet.png`

2. current victory sheet (motion / celebration intent only, NOT identity master)
- `d:\main\bosspong\items\menhera_boss_victory.png`

3. dense identity board
- `d:\main\bosspong\.tmp\menhera_autosprite_reference_board_v2.png`

4. optional quality / current live turn compare only
- `d:\main\bosspong\items\menhera_boss_turn.png`
- turn은 identity anchor가 아니라 pixel / prop consistency 보조 참고용일 뿐

모델 / 방식:
- FLUX Kontext
- 가능하면 `flux_kontext_max`
- full 8-frame sheet direct generation first
- 이번 victory는 신규 branch이므로 예전처럼 framewise가 기본이 아님
- 기본 전략은 한 번에 8프레임 시트 생성
- 정말 실패할 때만 peak / framewise로 내려간다

시트 목표:
- 8-frame victory sheet
- 4x2 grid
- aspectRatio 16:9
- imageSize 2K
- pure white background
- no grid lines
- no labels
- no borders
- full body fully visible in every frame
- generous white margin

identity lock (must match canonical walk):
- fluffy pink outer hair
- cream/blonde inner front bangs
- rounded fluffy hair silhouette
- pink/white gingham nurse cap
- syringe on cap
- front ribbon language matching the canonical walk
- NO black cat ears
- large gray/silver eyes with lashes
- exactly one pink heart cheek mark on one cheek only
- pink outfit with white center panel
- exactly FOUR black bows in a clean vertical stack
- gray cat-paw gloves with visible pink pads
- same-side med-kit pouch
- pink check cloth-tail motif
- white thigh-highs
- black X ankle accessories
- same petite chibi body class
- thick black pixel outlines

style lock:
- 16-bit retro pixel art
- chibi proportions
- thick black pixel outlines
- flat limited-saturation pastel palette
- clean hard-edged pixels
- NO anime-soft rendering
- NO painterly shading
- NO mobile-game chibi gloss
- must stay in the same clarity class as the canonical walk

victory motion brief:
- front-facing celebration, not a different character
- confident / satisfied / eerie-cute Menhera energy
- same boss, same face, same prop language
- body rhythm should feel lively and victorious without drifting into unrelated idol / dance / mascot acting
- celebration can include modest arm lift, chest-open posture, small bounce, subtle prop / ribbon / hair rebound
- do NOT let the face morph into a different girl across frames
- do NOT let smile / eye shape / bangs treatment drift away from canonical Menhera

recommended 8-frame plan:
- row 1:
  1. post-fight release
  2. small chest rise / breath / relief
  3. victory lift begins
  4. clearer celebratory pose
- row 2:
  5. full victory pose
  6. held triumph
  7. softer satisfied hold
  8. final held victory frame

face lock requirements:
- face must remain recognizably the same Menhera in all 8 frames
- eye size / eye spacing / lashes / cheek heart / bangs framing must not drift
- do NOT let one or two "hero frames" become a cleaner or different-faced Menhera than the rest
- no bob-hair simplification
- no face softening that breaks the established walk identity

gameplay-scale readability:
- face, cap, syringe, ribbon, cheek heart, 4 bows, paw pads, med-kit, cloth-tail, thigh-highs must remain readable at gameplay size
- body read must stay within about +/-5% of the canonical walk
- do not let celebratory pose or outward accents shrink the body read

hard reject conditions:
- face drift from canonical walk
- eye color drift
- cream bangs loss
- gingham cap simplification
- syringe loss
- front ribbon drift
- 4-bow count drift
- pink paw-pad loss
- med-kit side drift
- anime-soft rendering
- body read smaller than walk
- one or more frames reading like a different Menhera

output targets:
- `.tmp/menhera_flux_kontext_victory_v1.png`
- `.tmp/menhera_flux_kontext_victory_v1.jpeg`
- optional:
  - `.tmp/menhera_flux_kontext_victory_v1_zoom.png`
  - `.tmp/menhera_flux_kontext_victory_v1_gameplay.png`
  - `.tmp/menhera_flux_kontext_victory_v1_report.md`

important QA rule:
- compare the new victory directly against `items/menhera_boss_sheet.png`
- current `items/menhera_boss_victory.png` may be used for pose / energy comparison only
- if the new result matches old victory motion better but drifts further from the canonical walk face, reject it

stop-and-ask:
- if FLUX can keep the body / motion but starts "prettifying" or reinterpreting the face, stop there and do not promote
- this regen succeeds only if it preserves canonical Menhera first and celebration second

최종 보고 형식:
1. 어떤 reference stack으로 생성했는지
2. current victory 대비 무엇이 좋아졌는지
3. canonical walk face / identity lock 통과 여부
4. 8프레임 direct generation이 usable한지 여부
5. 바로 후보로 올릴 수 있는지, 아니면 peak/framewise 보정으로 내려가야 하는지
```
