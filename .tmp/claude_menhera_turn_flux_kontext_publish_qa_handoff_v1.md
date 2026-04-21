# Claude Handoff Prompt: Menhera Turn FLUX Kontext Publish QA V1

아래 프롬프트를 그대로 Claude에게 전달하면 됩니다.

```text
이번 작업은 PingFighter Stage 3 Menheragirl turn의 "publishing QA candidate" 패스를 마무리하는 단계다.

중요:
- `d:\main\bosspong\CLAUDE.md`를 따르고
- 반드시 `d:\main\bosspong\.claude\skills\sprite-generation\SKILL.md` 기준으로 진행해줘
- 아직 canonical overwrite는 하지 않는다
- 먼저 `.tmp` 안에서 publishing candidate pack + QA까지 끝내고, 마지막에만 canonical 승격 여부를 판단한다

현재 상태:
- FLUX Kontext frame expansion V1까지 끝났다
- usable frames:
  - `d:\main\bosspong\.tmp\menhera_flux_kontext_turn_f1_v1.png`
  - `d:\main\bosspong\.tmp\menhera_flux_kontext_turn_f2_v1.png`
  - `d:\main\bosspong\.tmp\menhera_flux_kontext_turn_f3_v1.png`
  - `d:\main\bosspong\.tmp\menhera_flux_kontext_peak_v2.png`      = frame 4
  - `d:\main\bosspong\.tmp\menhera_flux_kontext_turn_f5_v1.png`
  - `d:\main\bosspong\.tmp\menhera_flux_kontext_turn_f6_v1.png`
  - `d:\main\bosspong\.tmp\menhera_flux_kontext_turn_f7_v1.png`
  - frame 8 = frame 1 reuse
- stitched preview already exists:
  - `d:\main\bosspong\.tmp\menhera_flux_kontext_turn_stitched_v1_preview.png`

목표:
1. final ordered 4x2 publishing sheet candidate를 만든다
2. JPEG + PNG nukki pair를 만든다
3. gameplay-scale QA까지 마친다
4. canonical overwrite 가능한지 판단한다

이번 패스에서 만들 것:
- ordered 4x2 sheet candidate
- candidate jpeg
- nukki png
- gameplay-size QA comparison
- final promotion recommendation

frame order:
- Row 1: f1, f2, f3, f4(peak_v2)
- Row 2: f5, f6, f7, f8(f1 reuse)

권장 산출물:
- `.tmp/menhera_flux_kontext_turn_sheet_v1.png`
- `.tmp/menhera_flux_kontext_turn_sheet_v1.jpeg`
- `.tmp/menhera_flux_kontext_turn_sheet_v1_nukki.png`
- `.tmp/menhera_flux_kontext_turn_sheet_v1_gameplay.png`
- `.tmp/menhera_flux_kontext_turn_sheet_v1_gameplay_4x.png`
- `.tmp/menhera_flux_kontext_turn_publish_qa_v1_report.md`

패키징 규칙:
- 8프레임을 정확한 4x2 배열로 스티치
- 동일 캔버스 논리 유지
- frame-to-frame body read가 흔들리지 않게 배치
- no extra border, no labels, no guide marks
- preview용 lanczos가 아니라, publishing candidate 자체는 sprite sheet 용도로 일관되게 빌드

JPEG / PNG 규칙:
- candidate jpeg를 만든 뒤
- `py d:\main\bosspong\.claude\skills\sprite-generation\remove_bg.py <src.jpeg> <dst.png>`
  로 nukki PNG를 만든다
- PNG는 crisp hard-edge 유지

identity / style QA:
- canonical walk:
  - `d:\main\bosspong\items\menhera_boss_sheet.png`
- quality reference:
  - `d:\main\bosspong\items\menhera_boss_victory.png`

반드시 체크:
- cream/blonde inner front bangs 유지
- gingham cap 유지
- syringe 유지
- front ribbon language 유지
- exactly 4 black bows readable
- pink paw pads 유지
- med-kit side 유지
- check cloth-tail motif 유지
- thick black pixel outlines 유지
- PingFighter 16-bit pixel clarity class 유지

minor cleanup judgment:
- peak V2 minor drift였던 sock-top pink accent가 canonical promotion을 막을 정도인지 판단
- cap side ribbon accent drift가 canonical promotion을 막을 정도인지 판단
- 만약 gameplay-scale에서 거의 읽히지 않는 minor drift라면 "acceptable minor drift"로 기록 가능
- 하지만 identity-class를 흔들 정도면 regenerate or touch-up로 보류

gameplay-scale QA:
- `entities/menhera_boss_sprite.py`의 target size 감각에 맞춰 small-size render comparison을 만들어라
- turn frame가 walk보다 작게 읽히지 않는지
- face / forehead clipped-looking read 없는지
- f7 -> f8 -> walk reconnect가 자연스러운지
- stable walk를 hijack하지 않는 auxiliary turn candidate인지

stop-and-ask rules:
- JPEG -> nukki PNG 직후 즉시 edge QA를 실행해라
- 특히 exactly 4 black bows, pink paw pads, med-kit edge를 최우선으로 검사해라
- 생성 단계에서 살아 있던 bow / paw / med-kit 디테일이
  hard-edge nukki 이후 halo, alpha punch-out, outline break로 손상되면
  그 자리에서 멈춰라
- 그 경우 canonical 승격 판단으로 넘어가지 말고 "promotion blocked after nukki"
  로 명시해라

drift judgment rule:
- drift는 turn sheet 단독 미감으로 판정하지 마라
- 반드시 canonical walk sheet와 나란히 병치해서 same-Menhera 여부를 판정해라
- sock-top pink accent나 cap ribbon drift가 단독으로는 귀여워 보여도,
  walk와 병치했을 때 다른 캐릭터나 다른 identity branch처럼 읽히면 blocker다
- 이 turn sheet가 이후 attack / dash realign의 identity anchor가 될 수 있다는
  전제를 기준으로 더 엄격하게 판정해라
- "turn 단독으론 허용"이 아니라 "walk와 병치해도 같은 Menhera인가"가 기준이다

중요:
- 이번 패스에서는 아직 `items/menhera_boss_turn.png`를 overwrite 하지 마라
- 먼저 `.tmp` publishing candidate로 QA 완료 후에만 승격 판단

최종 보고 형식:
1. 어떤 파일들을 publishing candidate로 만들었는지
2. JPEG / PNG nukki pair 생성 여부
3. gameplay-scale QA 통과 / 실패 요약
4. sock-top pink accent / cap ribbon drift가 blocker인지 여부
5. canonical 승격 가능한지 여부
6. 가능하다면 다음 단계:
   - `items/menhera_boss_turn.{jpeg,png}` 교체
   - Codex runtime smoke-check handoff
7. 불가하다면 다음 단계:
   - minor touch-up regenerate only
   - or keep hop-only fallback
```
