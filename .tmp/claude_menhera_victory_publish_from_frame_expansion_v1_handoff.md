# Claude Handoff Prompt: Menhera Victory Publish From Frame Expansion V1

아래 프롬프트를 그대로 Claude에 전달하면 됩니다.

```text
이번 작업은 PingFighter Stage 3 Menheragirl victory regeneration의 P3A publish staging이다.

중요:
- `d:\main\bosspong\CLAUDE.md`를 따른다
- 반드시 `d:\main\bosspong\.claude\skills\sprite-generation\SKILL.md` 기준으로 진행한다
- 이번 패스에서는 새 생성/재생성보다 publish pack staging과 QA가 목적이다
- runtime integration은 하지 않는다
- canonical overwrite는 하지 말고 `.tmp` publish pack + QA까지만 만든다

현재 상태:
- frame expansion from accepted peak V1 is ACCEPTED for publish staging
- 8-frame sequence is now celebration-readable across all frames
- identity lock, 4 bows, paw pads, med-kit, plain socks, syringe, and pixel class all PASS
- V3 row-split and old-victory leak issues are gone
- live runtime victory is still the older P2 publish sheet
- canonical walk remains the sole identity anchor
- this victory candidate is runtime-only non-anchor until promoted

source frames:
- `d:\main\bosspong\.tmp\menhera_flux_kontext_victory_f1_v1.png`
- `d:\main\bosspong\.tmp\menhera_flux_kontext_victory_f2_v1.png`
- `d:\main\bosspong\.tmp\menhera_flux_kontext_victory_f3_v1.png`
- `d:\main\bosspong\.tmp\menhera_flux_kontext_victory_f4_v1.png`
- `d:\main\bosspong\.tmp\menhera_flux_kontext_victory_peak_from_autosprite_v1.png`  <-- frame 5
- `d:\main\bosspong\.tmp\menhera_flux_kontext_victory_f6_v1.png`
- `d:\main\bosspong\.tmp\menhera_flux_kontext_victory_f7_v1.png`
- `d:\main\bosspong\.tmp\menhera_flux_kontext_victory_f8_v1.png`

reference assets for QA:
- canonical walk:
  - `d:\main\bosspong\items\menhera_boss_sheet.png`
- current runtime victory (P2):
  - `d:\main\bosspong\items\menhera_boss_victory.png`
- old victory backup:
  - `d:\main\bosspong\.tmp\menhera_victory_runtime_backup_20260418\menhera_boss_victory_old.png`

목표:
1. stitch the accepted 8 frames into a runtime-ready 4x2 publish sheet
2. target final canvas must match the live victory sheet exactly:
   - `2752x1536`
   - 4x2 grid
   - 688x768 per cell
3. use uniform cross-frame scaling
4. do NOT let any frame become larger/smaller than the others
5. package JPEG + PNG(nukki) pair
6. run full edge QA + gameplay QA

publish outputs:
- `.tmp/menhera_flux_kontext_victory_publish_v2.png`
- `.tmp/menhera_flux_kontext_victory_publish_v2.jpeg`
- `.tmp/menhera_flux_kontext_victory_publish_v2_nukki.png`

QA visuals:
- `.tmp/menhera_flux_kontext_victory_publish_v2_zoom.png`
- `.tmp/menhera_flux_kontext_victory_publish_v2_gameplay.png`
- `.tmp/menhera_flux_kontext_victory_publish_v2_gameplay_4x.png`
- `.tmp/menhera_flux_kontext_victory_publish_v2_vs_walk.png`
- `.tmp/menhera_flux_kontext_victory_publish_v2_vs_runtime_p2.png`
- `.tmp/menhera_flux_kontext_victory_publish_v2_vs_old_victory.png`
- optional:
  - face consistency strip
  - torso/bow audit strip
  - selected edge crops pre/post nukki

report:
- `.tmp/menhera_flux_kontext_victory_publish_v2_report.md`

stitch / scaling guidance:
- preserve the authored frame content from the accepted expansion frames
- this is packaging, not regeneration
- use one consistent fit/scaling strategy across all 8 cells
- keep baseline/body-read consistency intact
- do not introduce new creative edits

nukki:
- export JPEG first
- then run the normal `remove_bg.py` JPEG -> PNG path
- preserve hard-edged pixel read

post-nukki hard-stop checks:
- 4 bows remain intact on every frame
- pink paw pads remain intact
- med-kit edges remain intact
- cream bangs remain intact
- syringe remains intact
- plain white socks remain plain white
- if halo, alpha punch-out, outline break, or prop damage appears, HOLD immediately

drift QA rule:
- do NOT judge the victory sheet in isolation
- compare directly against canonical walk
- compare against current runtime P2 victory
- compare against old victory backup

gameplay QA goals:
- final publish pack must remain the same exact Menhera as canonical walk
- final publish pack must read more celebratory than current runtime P2
- final publish pack must keep the stronger acting without reintroducing old-victory drift
- at gameplay scale, it should read like a true victory sequence, not turn-like sway

accepted non-blockers:
- if f1/f2/f8 remain slightly more celebratory than the calmer brief, that is acceptable
- do NOT spend credits on narrow touch-up for taste-only differences unless a real blocker appears

important policy:
- canonical walk remains the sole identity anchor
- this victory publish candidate is runtime-only non-anchor
- do NOT use it as a future identity anchor for regen work

final recommendation format:
1. publish pack generated successfully 여부
2. nukki pair generated successfully 여부
3. post-nukki edge QA pass/fail
4. gameplay-scale QA vs walk / current P2 / old victory
5. whether this is a real upgrade over the current runtime victory
6. whether Codex can now safely swap `items/menhera_boss_victory.{png,jpeg}`

important success wording:
- if QA passes, explicitly say:
  - `P3A accepted`
  - `victory frame-expansion publish pack is approved as a runtime-only non-anchor auxiliary sheet`
  - `canonical walk remains the sole identity anchor`
```
