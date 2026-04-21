# Claude Handoff Prompt: Menhera Turn via FLUX Kontext MCP V1

아래 프롬프트를 그대로 Claude에게 전달하면 됩니다.

```text
이번 작업은 PingFighter 스테이지 3 멘헤라걸 TURN 작업을 FLUX Kontext MCP로 시도하는 것입니다.

중요:
- 먼저 `d:\main\bosspong\CLAUDE.md`를 따르고,
- 보스 스프라이트 작업이므로 반드시 `d:\main\bosspong\.claude\skills\sprite-generation\SKILL.md` 기준으로 진행해줘.
- 보스 스프라이트 생성 규칙은 기억으로 재구성하지 말고 `sprite-generation` 스킬 기준을 우선 적용해줘.

이번 패스의 목적:
- FLUX Kontext를 바로 "최종 8프레임 turn sheet 생성기"로 쓰지 않는다.
- 먼저 `single peak key pose` 1장을 image-to-image 편집으로 뽑아 본다.
- 이 한 장이 canonical Menhera identity + PingFighter pixel class + micro-turn motion을 동시에 잡는지 검증한다.
- 괜찮으면 그 다음에 entry / recovery 또는 full turn 쪽으로 확장할 수 있다.

현재 전제:
- canonical walk anchor는 `items/menhera_boss_sheet.png`
- quality / readability tier reference는 `items/menhera_boss_victory.png`
- AutoSprite V1/V2는 최종 turn 렌더러로는 부적합 판정이 났다.
- 다만 AutoSprite V2의 "conservative micro-turn" 방향성은 모션 ideation 참고로는 유효하다.
- runtime은 그대로 hop-only fallback 유지이며 이번 작업에서는 runtime integration을 하지 않는다.

이번에 사용할 핵심 reference:
1. dense identity board
- `d:\main\bosspong\.tmp\menhera_autosprite_reference_board_v2.png`
- 이것을 FLUX Kontext의 주 reference로 사용해줘.

2. canonical walk
- `d:\main\bosspong\items\menhera_boss_sheet.png`

3. quality reference
- `d:\main\bosspong\items\menhera_boss_victory.png`

4. optional motion ideation reference only
- `d:\main\bosspong\.tmp\menhera_turn_autosprite_v2_frame_3.png`
- 또는 `frame_4.png`
- 이것은 identity anchor가 아니라 "micro-turn peak pose amplitude" 참고용으로만 사용해라.

작업 범위:
- 이번 패스는 TURN peak key pose only
- walk / attack / dash / victory / defeat는 건드리지 않는다
- canonical overwrite 하지 않는다
- `.tmp` 후보 생성 + QA + 보고까지만 한다

핵심 목표:
- exact same Menhera identity 유지
- exact same or materially compatible PingFighter pixel-art clarity class 유지
- 포즈는 "conservative micro-turn peak"
- 즉, front-facing을 거의 유지한 채 아주 작은 direction-change accent만 만든다

원하는 pose:
- slight chin lift
- dreamy upward / middle-distance gaze
- tiny outward paw preparation
- tiny knee gather
- compact whole-body redirect accent
- NOT greeting wave
- NOT attack swing
- NOT dance
- NOT tray-hold pose
- NOT side-profile turn
- NOT strong 3/4 view

identity lock:
- fluffy short pink outer hair
- cream / blonde inner front bangs
- rounded fluffy hair silhouette
- pink / white gingham nurse cap
- syringe attached on cap
- red front ribbon language preserved
- NO black cat ears
- large gray / silver eyes with lashes
- exactly one pink heart cheek mark on one cheek only
- pink outfit with white center panel
- exactly 4 black bows vertically stacked
- gray cat-paw gloves with visible pink pads
- same-side med-kit pouch
- pink check cloth-tail motif
- white thigh-highs
- black X ankle accessories

style lock:
- 16-bit retro pixel art
- chibi proportions
- thick black pixel outlines
- flat limited-saturation pastel palette
- clean hard-edged pixels
- NO anti-aliased anime softness
- NO painterly shading
- NO modern mobile-game chibi rendering
- must stay in the same clarity class as `items/menhera_boss_sheet.png` and `items/menhera_boss_victory.png`

FLUX Kontext 사용 방향:
- image-to-image edit로 진행
- 가능하면 `flux_kontext_max` 우선 고려
- main reference는 dense identity board
- canonical walk와 victory를 추가 reference로 사용
- optional로 AutoSprite V2의 peak-ish frame은 motion amplitude hint로만 사용

1차 출력 목표:
- ONE single full-body image only
- pure white or easily removable background
- centered full body
- generous margin
- candidate output:
  - `.tmp/menhera_flux_kontext_peak_v1.png`
- 필요 시 nukki / background cleanup 후 비교 가능한 PNG로 정리

중요한 판단 기준:
- 이 한 장이 "same Menhera, same clarity class, better peak pose"로 보이면 성공
- identity props가 또 일반화되거나
- FLUX 특유의 soft illustration 느낌이 남거나
- pixel class가 canonical보다 부드러우면 실패

hard reject conditions:
- different Menhera
- cream bangs loss
- gingham cap simplification
- syringe loss
- front ribbon loss
- 4-bow drift
- glove pad loss
- med-kit side drift
- soft anime rendering
- anti-aliased / painterly look
- greeting wave read
- attack swing read
- side-facing turn read

QA comparison targets:
- `items/menhera_boss_sheet.png`
- `items/menhera_boss_victory.png`
- optional motion-only compare:
  - `.tmp/menhera_turn_autosprite_v2_frame_3.png`
  - `.tmp/menhera_turn_autosprite_v2_frame_4.png`

최종 보고 형식:
1. 어떤 FLUX Kontext 모델 / 방식으로 시도했는지
2. 어떤 reference를 실제로 사용했는지
3. 생성 파일 경로
4. identity lock 통과 / 실패 항목
5. style class 통과 / 실패 항목
6. 이 peak pose가 다음 단계(entry/recovery/full turn)의 usable anchor인지 여부
7. canonical overwrite 없이 유지해야 하는지 여부

가능하면 이번 턴에서:
- `sprite-generation` skill을 사용하고
- FLUX Kontext로 peak pose 1장 생성
- QA까지 진행하고
- canonical overwrite는 하지 않은 상태로 결과를 보고해줘.
```
