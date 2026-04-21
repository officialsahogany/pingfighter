# Claude Handoff Prompt: Menhera Turn FLUX Kontext Peak V4 Cap-Only Touch-Up

아래 프롬프트를 그대로 Claude에게 전달하면 됩니다.

```text
이번 작업은 PingFighter Stage 3 Menheragirl turn의 FLUX Kontext peak V4 cap-only touch-up 패스다.

중요:
- `d:\main\bosspong\CLAUDE.md`를 따르고
- 반드시 `d:\main\bosspong\.claude\skills\sprite-generation\SKILL.md` 기준으로 진행해줘
- runtime integration은 하지 않는다
- canonical overwrite는 하지 않는다
- 이번 패스는 "V3의 sock fix는 유지하고, cap ribbon drift만 고치는 극도로 좁은 수정"이다

현재 상태 요약:
- V2: identity / pixel class 강하게 성공, 하지만 sock-top pink accent + cap side-ribbon drift가 blocker
- V3: sock-top pink accent 제거는 성공
- 하지만 cap ribbon은 여전히 side accents branch로 남았고,
  thigh-gap 소폭 확장 / face softness 소폭 증가 / syringe 약화가 추가되었다
- 따라서 V3는 upgrade가 아니라 lateral move로 판정되었다

이번 V4의 목적:
- V3의 plain white socks는 그대로 유지
- cap ribbon language만 canonical walk 쪽으로 복원
- 즉, 양옆 red accents branch를 줄이고 single front-center red ribbon / bow language로 복귀
- 그 외의 모든 요소는 V3 또는 V2의 solved state를 그대로 보존

핵심 reference stack:
1. primary base
- `d:\main\bosspong\.tmp\menhera_flux_kontext_peak_v3.png`

2. compare anchor
- `d:\main\bosspong\.tmp\menhera_flux_kontext_peak_v2.png`

3. dense identity board
- `d:\main\bosspong\.tmp\menhera_autosprite_reference_board_v2.png`

4. canonical walk
- `d:\main\bosspong\items\menhera_boss_sheet.png`

5. quality reference
- `d:\main\bosspong\items\menhera_boss_victory.png`

6. explicit crop references for narrow correction
- `d:\main\bosspong\.tmp\menhera_flux_kontext_peak_v2_cap_crop.png`
- `d:\main\bosspong\.tmp\menhera_flux_kontext_peak_v3_cap_crop.png`
- `d:\main\bosspong\.tmp\menhera_flux_kontext_peak_v2_socks_crop.png`
- `d:\main\bosspong\.tmp\menhera_flux_kontext_peak_v3_socks_crop.png`
- `d:\main\bosspong\.tmp\menhera_flux_kontext_peak_v2_vs_v3.png`

모델 / 방식:
- FLUX Kontext image-to-image
- 가능하면 `flux_kontext_max`
- ultra narrow corrective edit
- base image는 반드시 peak_v3

이번 V4에서 수정할 것 only:
- reduce / remove the side red cap accents
- restore a single front-center red ribbon / bow language on the cap

이번 V4에서 절대 바꾸면 안 되는 것:
- plain white sock tops
- dress length / thigh gap
- face softness level
- syringe strength / visibility
- 4 black bows
- paw pad visibility
- med-kit side / shape
- cream/blonde inner bangs
- body read
- pose amplitude
- pixel class

non-negotiable keep rules:
- keep the V3 plain white thigh-high socks exactly as they are
- do NOT reintroduce any pink sock-top band
- keep dress hem / thigh gap no wider than V3, ideally slightly closer to V2/canonical
- do NOT soften the face further
- do NOT weaken the syringe further
- keep exactly FOUR black bows
- keep pink paw pads visible
- keep same-side med-kit pouch
- keep same conservative micro-turn peak pose
- keep same PingFighter 16-bit pixel class

identity / style lock:
- fluffy pink outer hair
- cream/blonde inner front bangs
- rounded fluffy hair silhouette
- pink/white gingham nurse cap
- syringe on cap
- one pink heart cheek mark
- gray/silver eyes with lashes
- white center panel with exactly FOUR black bows in a clean vertical stack
- gray cat-paw gloves with visible pink pads
- same-side med-kit pouch
- pink check cloth-tail motif
- white thigh-highs
- black X ankle accessories
- thick black pixel outlines
- flat limited-saturation pastel pixel-art class

editing philosophy:
- this is NOT a re-generation
- this is NOT a pose redesign
- this is NOT a style reinterpretation
- keep everything materially identical to V3 except the cap ribbon correction
- if FLUX tries to "improve" unrelated parts, reject that attempt

pose brief:
- conservative micro-turn peak
- front-facing
- slight chin lift
- tiny outward paw preparation
- tiny knee gather
- compact redirect accent
- not a wave
- not an attack
- not a side-turn

output:
- `.tmp/menhera_flux_kontext_peak_v4.png`
- optional:
  - `.tmp/menhera_flux_kontext_peak_v4_zoom.png`
  - `.tmp/menhera_flux_kontext_peak_v4_cap_crop.png`
  - `.tmp/menhera_flux_kontext_peak_v4_socks_crop.png`
  - `.tmp/menhera_flux_kontext_peak_v3_vs_v4.png`
- report:
  - `.tmp/menhera_flux_kontext_peak_v4_report.md`

hard reject:
- cap ribbon still reading as side-accent branch
- pink sock-top accent returns
- thigh-gap widens further
- face softens further
- syringe weakens further
- any loss of 4 bows
- any loss of pink paw pads
- med-kit drift
- anime-soft regression

stop-and-ask:
- if correcting the cap ribbon causes collateral drift in socks, dress length,
  face softness, syringe, 4 bows, paw pads, or med-kit, stop there and do not
  promote V4 as the new primary anchor
- V4 is only acceptable if it is a true upgrade over V3, not another lateral move

최종 보고 형식:
1. cap ribbon correction 성공 여부
2. plain white socks 유지 여부
3. thigh-gap / face softness / syringe collateral drift 여부
4. V4가 V3보다 명백한 upgrade인지 여부
5. V4를 derived frames 재생성용 primary anchor로 쓸 수 있는지 여부

성공 시 다음 단계:
- V4를 primary anchor로 f1/f2/f3/f5/f6/f7 재생성
- 같은 drift-strip instruction 적용
- 4x2 stitch + jpeg + nukki + gameplay QA 재실행
```
