# Claude Handoff Prompt: Menhera Victory P2 Publish Pipeline

아래 프롬프트를 그대로 Claude에 전달하면 됩니다.

```text
이번 작업은 PingFighter Stage 3 Menheragirl victory sheet의 P2 publishing pipeline이다.

중요:
- `d:\main\bosspong\CLAUDE.md`를 따른다
- 반드시 `d:\main\bosspong\.claude\skills\sprite-generation\SKILL.md` 기준으로 진행한다
- 이번 패스에서는 새 FLUX / AutoSprite / Gemini 생성 테스트를 하지 않는다
- asset-side generation branch는 닫혔다
- 목표는 `menhera_flux_kontext_victory_v1.png`를 publish candidate pack으로 정리하고 QA하는 것이다
- canonical overwrite는 하지 말고 `.tmp` 산출물과 리포트까지만 만든다

결정 상태:
- victory V1은 current live victory보다 명확히 낫다
- V1은 8프레임 전체에서 canonical walk와 같은 Menhera로 읽힌다
- 남은 차이는 center-panel bow count가 4가 아닌 3이라는 점이다
- victory는 future regen anchor가 아니다
- 따라서 3-bow는 P2 아래에서 accepted cosmetic runtime drift로 수용한다
- victory V2 bow-only pass는 catastrophic layout drift로 실패했으므로 더 이상 narrow FLUX pass를 하지 않는다

정책:
- canonical walk is the sole identity anchor
- victory V1 is runtime playback candidate only
- do NOT use victory V1 or V2 as a future identity anchor for regeneration work
- future regen must still anchor on canonical walk plus approved prop references

입력 자산:
1. publish source
- `d:\main\bosspong\.tmp\menhera_flux_kontext_victory_v1.png`

2. canonical walk for side-by-side QA
- `d:\main\bosspong\items\menhera_boss_sheet.png`

3. current live victory for before/after compare
- `d:\main\bosspong\items\menhera_boss_victory.png`

4. dense identity board for prop reference if needed during QA only
- `d:\main\bosspong\.tmp\menhera_autosprite_reference_board_v2.png`

목표 산출물:
1. publish sheet
- upscale / stitch V1 into canonical victory canvas size
- target size must match current live victory sheet exactly: `2752x1536`
- preserve 4x2 layout
- each cell should land on the canonical 688x768 cell grid

2. publishing pair
- `.tmp/menhera_flux_kontext_victory_publish_v1.png`
- `.tmp/menhera_flux_kontext_victory_publish_v1.jpeg`

3. nukki pair
- run `remove_bg.py` through the normal JPEG -> PNG path
- output:
  - `.tmp/menhera_flux_kontext_victory_publish_v1_nukki.png`

4. QA visuals
- `.tmp/menhera_flux_kontext_victory_publish_v1_zoom.png`
- `.tmp/menhera_flux_kontext_victory_publish_v1_gameplay.png`
- `.tmp/menhera_flux_kontext_victory_publish_v1_gameplay_4x.png`
- `.tmp/menhera_flux_kontext_victory_publish_v1_vs_current.png`
- `.tmp/menhera_flux_kontext_victory_publish_v1_vs_walk.png`
- optional per-frame crops if needed for evidence

5. report
- `.tmp/menhera_flux_kontext_victory_publish_v1_report.md`

packing / upscale guidance:
- preserve the authored frame content of V1
- do not creatively redraw or reinterpret anything
- this is packaging, not regeneration
- use a clean upscale / fit workflow that keeps the 4x2 layout intact
- if a trim or fit step is required, keep it conservative and uniform across all 8 cells
- do not let one frame end up larger or smaller than the others

accepted divergence:
- center white panel reads as 3 bows instead of 4
- this is accepted only as a runtime cosmetic divergence for the victory sheet
- it must not be upgraded into a new canonical identity rule

hard stop after nukki:
- immediately inspect the nukki PNG for:
  - accepted 3-bow read staying intact
  - pink paw pads intact
  - med-kit edges intact
  - cream bangs intact
  - syringe intact
- if halo, alpha punch-out, or prop damage appears around those regions, stop and report HOLD

drift QA rule:
- do NOT judge victory in isolation
- compare directly against canonical walk side-by-side
- compare directly against current live victory side-by-side
- if walk pairing makes V1 read as a different character, HOLD
- if V1 still reads materially more stable than current live victory, say so clearly

gameplay QA rule:
- confirm the 2752x1536 publish pack still reads better than current live victory at gameplay scale
- confirm face consistency survives the upscale / JPEG / nukki round-trip
- confirm no new closed-eye happy-face drift appears
- confirm no pink trim reappears on the thigh-highs

final recommendation format:
1. publish pack generated successfully 여부
2. nukki pair generated successfully 여부
3. post-nukki edge QA 통과/실패
4. gameplay-scale QA에서 current live victory 대비 upgrade인지 여부
5. accepted 3-bow cosmetic divergence가 runtime shipping에 문제 없는지 여부
6. Codex가 바로 `items/menhera_boss_victory.{png,jpeg}` swap 해도 되는지 여부

중요 결론 문구:
- if QA passes, explicitly say:
  - `P2 accepted`
  - `victory V1 publish pack is approved as a runtime-only non-anchor auxiliary sheet`
  - `canonical walk remains the sole identity anchor`
```
