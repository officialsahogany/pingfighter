# Claude Handoff Prompt: Menhera Turn FLUX Kontext Peak V2

아래 프롬프트를 그대로 Claude에게 전달하면 됩니다.

```text
이번 작업은 PingFighter Stage 3 Menheragirl turn 작업의 FLUX Kontext peak pose V2 패스다.

중요:
- `d:\main\bosspong\CLAUDE.md`를 따르고
- 반드시 `d:\main\bosspong\.claude\skills\sprite-generation\SKILL.md` 기준으로 진행해줘
- runtime integration은 하지 않는다
- canonical overwrite는 하지 않는다

현재 상태:
- FLUX Kontext Peak Pose V1은 identity lock과 pixel class에서 매우 강하게 성공했다
- canonical turn sheet로 바로 승격할 수는 없지만, 단일 peak anchor로는 충분히 유망하다
- V1의 사실상 유일한 눈에 띄는 drift는 bow count가 3으로 읽힌다는 점이다

이번 V2의 목적:
- V1의 장점은 그대로 유지하고
- "white center front panel에 black vertical bows가 정확히 4개"를 더 강하게 고정한다

핵심 reference:
1. dense identity board
- `d:\main\bosspong\.tmp\menhera_autosprite_reference_board_v2.png`

2. canonical walk
- `d:\main\bosspong\items\menhera_boss_sheet.png`

3. quality reference
- `d:\main\bosspong\items\menhera_boss_victory.png`

4. previous best FLUX anchor
- `d:\main\bosspong\.tmp\menhera_flux_kontext_peak_v1.png`
- 이것을 매우 강한 primary anchor로 써도 된다

5. optional compare only
- `d:\main\bosspong\.tmp\menhera_walk_cell3_for_compare.png`

모델 / 방식:
- FLUX Kontext image-to-image
- 가능하면 `flux_kontext_max`
- multi-reference edit

작업 범위:
- ONE single full-body image only
- peak direction-change key pose only
- 8-frame sheet는 아직 만들지 않는다

반드시 유지할 것:
- fluffy pink outer hair
- cream/blonde inner front bangs
- rounded fluffy hair silhouette
- pink/white gingham nurse cap
- syringe on cap
- front ribbon language
- one pink heart cheek mark
- gray/silver eyes with lashes
- gray cat-paw gloves with visible pink pads
- white med-kit on same side
- pink check cloth-tail motif
- white thigh-highs
- black X ankle accessories
- thick black pixel outlines
- same PingFighter 16-bit pixel clarity class as V1

이번 V2에서 특히 강화할 제약:
- the white center front panel MUST show exactly FOUR black bows
- the four bows must read as a clean vertical stack
- do not let the arm occlude the bow count so heavily that one disappears
- if needed, slightly adjust paw/arm placement only enough to keep all four bows legible
- preserving all four bows is more important than making the paw gesture larger

pose brief:
- conservative micro-turn peak
- front-lock 유지
- slight chin lift
- dreamy upward / middle-distance gaze
- tiny outward paw preparation
- tiny knee gather
- compact redirect accent
- do NOT turn it into a greeting wave
- do NOT turn it into an attack swing
- do NOT turn it into a side-facing turn

style lock:
- 16-bit retro pixel art
- chibi proportions
- thick black pixel outlines
- flat limited-saturation pastel palette
- clean hard-edged pixels
- no anti-aliased anime softness
- no painterly shading

output:
- `.tmp/menhera_flux_kontext_peak_v2.png`
- optional zoom QA:
  - `.tmp/menhera_flux_kontext_peak_v2_zoom.png`
- report:
  - `.tmp/menhera_flux_kontext_peak_v2_report.md`

hard reject:
- bow count still reading as 3
- different Menhera
- cap/syringe/ribbon simplification
- pink paw pads loss
- med-kit side drift
- soft anime rendering regression
- wave / attack / side-turn read

최종 보고 형식:
1. V1 대비 무엇을 조정했는지
2. 실제 사용 reference stack
3. 생성 파일 경로
4. 4-bow constraint 성공 여부
5. V2가 entry/recovery 확장용 primary anchor로 쓸 수 있는지 여부
```
