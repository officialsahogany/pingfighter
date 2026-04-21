# Claude Handoff Prompt: Menhera Turn FLUX Kontext Peak V3 Narrow Touch-Up

아래 프롬프트를 그대로 Claude에게 전달하면 됩니다.

```text
이번 작업은 PingFighter Stage 3 Menheragirl turn의 FLUX Kontext peak V3 narrow touch-up 패스다.

중요:
- `d:\main\bosspong\CLAUDE.md`를 따르고
- 반드시 `d:\main\bosspong\.claude\skills\sprite-generation\SKILL.md` 기준으로 진행해줘
- runtime integration은 하지 않는다
- canonical overwrite는 하지 않는다
- 이번 패스는 "좋은 결과를 거의 유지한 채 drift 두 개만 제거"하는 보수적 touch-up이다

현재 상태:
- publish QA V1까지 결과가 매우 강하다
- edge QA after nukki PASS
- gameplay-scale QA materially PASS
- 하지만 strict same-Menhera + future identity-anchor rule에서
  아래 두 drift가 blocker로 판정되었다:
  1. white thigh-high socks top edge에 small pink accent band
  2. cap ribbon language가 canonical walk의 front-center 단일 ribbon보다 side accents 쪽으로 이동

이번 V3의 단 하나의 목적:
- peak V2 / publish candidate의 장점은 거의 전부 유지
- only remove the sock-top pink accent
- only restore the cap ribbon language toward a single front-center red bow / ribbon
- everything else must remain materially identical

핵심 reference stack:
1. primary anchor
- `d:\main\bosspong\.tmp\menhera_flux_kontext_peak_v2.png`

2. dense identity board
- `d:\main\bosspong\.tmp\menhera_autosprite_reference_board_v2.png`

3. canonical walk
- `d:\main\bosspong\items\menhera_boss_sheet.png`

4. quality reference
- `d:\main\bosspong\items\menhera_boss_victory.png`

5. publish QA compare references
- `d:\main\bosspong\.tmp\menhera_flux_kontext_turn_sheet_v1_gameplay_4x.png`
- `d:\main\bosspong\.tmp\menhera_turn_walk_pair_f4_peak_6x.png`

모델 / 방식:
- FLUX Kontext image-to-image
- 가능하면 `flux_kontext_max`
- narrow touch-up edit
- primary anchor는 반드시 peak_v2

절대 유지할 것:
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
- same PingFighter 16-bit pixel clarity class
- same conservative micro-turn peak pose silhouette

이번 V3에서 수정할 것 only:
- remove the small pink band / accent at the top of the white thigh-high socks
- restore plain white sock tops matching the canonical walk
- shift the cap red-ribbon language back toward a single front-center bow / ribbon accent

이번 V3에서 수정하면 안 되는 것:
- bow count
- paw pad visibility
- med-kit side or shape
- cloth-tail motif
- body read
- pose amplitude
- overall pixel class
- front-lock

아주 중요한 보수적 편집 지시:
- keep everything else materially identical to peak_v2
- do not redesign, reinterpret, embellish, or restyle the character
- this is not a new generation, it is a narrow corrective edit
- preserve all identity props already solved by V2

pose brief:
- conservative micro-turn peak
- front-facing
- slight chin lift
- tiny outward paw preparation
- tiny knee gather
- compact redirect accent
- NOT greeting wave
- NOT attack swing
- NOT side-profile turn

style lock:
- 16-bit retro pixel art
- chibi proportions
- thick black pixel outlines
- flat limited-saturation pastel palette
- clean hard-edged pixels
- no anti-aliased anime softness
- no painterly shading

output:
- `.tmp/menhera_flux_kontext_peak_v3.png`
- optional:
  - `.tmp/menhera_flux_kontext_peak_v3_zoom.png`
  - `.tmp/menhera_flux_kontext_peak_v3_socks_crop.png`
  - `.tmp/menhera_flux_kontext_peak_v3_cap_crop.png`
  - `.tmp/menhera_flux_kontext_peak_v2_vs_v3.png`
- report:
  - `.tmp/menhera_flux_kontext_peak_v3_report.md`

hard reject:
- pink sock-top accent still present
- cap ribbon still reading as side-accent branch rather than front-center language
- any loss of 4 bows
- any loss of pink paw pads
- med-kit drift
- anime-soft regression
- pose drift away from peak_v2

stop-and-ask:
- if removing the sock accent or restoring cap ribbon causes any collateral damage
  to 4 bows / paw pads / med-kit / cream bangs / syringe, stop there and do not
  promote V3 as the new primary anchor

최종 보고 형식:
1. V2 대비 실제 수정된 요소
2. sock-top pink accent 제거 성공 여부
3. cap ribbon front-center restoration 성공 여부
4. collateral drift 발생 여부
5. V3를 derived frames 재생성용 primary anchor로 쓸 수 있는지 여부

성공 시 다음 단계:
- 같은 reference stack으로 f1/f2/f3/f5/f6/f7 재생성
- 같은 drift-strip instruction 적용
- 4x2 stitch + jpeg + nukki + gameplay QA 재실행
```
