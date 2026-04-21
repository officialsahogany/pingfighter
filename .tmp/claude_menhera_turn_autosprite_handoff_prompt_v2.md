# Claude Handoff Prompt: Menhera Turn via AutoSprite MCP V2

아래 프롬프트를 그대로 Claude에게 전달하면 됩니다.

```text
이번 작업은 PingFighter 스테이지 3 멘헤라걸 TURN 시트를 AutoSprite MCP로 다시 시도하는 것입니다.

중요:
- 먼저 `d:\main\bosspong\CLAUDE.md`를 따르고,
- 보스 스프라이트 작업이므로 반드시 `d:\main\bosspong\.claude\skills\sprite-generation\SKILL.md` 기준으로 진행해줘.
- 이번 시도는 AutoSprite를 완전히 버리는 게 아니라, 역할을 더 보수적으로 제한해서 활용하는 V2 패스다.

이번 V2의 핵심 변경점:
- V1은 단일 캐릭터 업로드 기준으로 generic nurse-chibi 쪽으로 일반화되었다.
- 그래서 이번에는 단일 프레임이 아니라 "dense identity reference board"를 업로드 기준으로 쓴다.
- 생성 목표도 "creative turn animation"이 아니라
  "canonical walk에서 살짝 파생된 conservative micro-turn"으로 낮춘다.

우선 이 파일을 레퍼런스 업로드 기준으로 사용해줘:
- `d:\main\bosspong\.tmp\menhera_autosprite_reference_board_v2.png`

이 reference board의 의도:
- canonical walk full-body
- alternate walk full-body
- victory full-body for crispness/readability tier
- cap detail
- face detail
- torso / bow arrangement detail
- med-kit / glove / cloth-tail accessory detail

즉 AutoSprite가 아래 요소를 generic simplification 하지 못하게 막는 용도다:
- cream/blonde inner front bangs
- pink/white gingham nurse cap
- syringe on cap
- front ribbon
- exactly 4 black bows
- gray cat-paw gloves with pink pads
- med-kit on the same side
- pink check cloth-tail motif

작업 범위:
- 이번 패스는 TURN only
- walk / attack / dash / victory / defeat는 건드리지 않는다
- runtime integration은 하지 않는다
- canonical overwrite도 하지 않는다

스테이지 컨텍스트:
- real Stage 3 Menheragirl
- code 기준 `current_stage == 3`

중요 판단:
- V1 실패 원인은 sequence coherence보다 style / identity drift였다
- 따라서 framewise fallback도 같은 엔진이면 큰 도움이 안 된다
- 이번 V2는 framewise로 쪼개기 전에 먼저 "reference density"와 "motion amplitude"를 줄여서 다시 full pass를 보수적으로 시도한다

생성 목표:
- full 8-frame turn sheet를 다시 시도하되
- 방향전환 gesture의 amplitude를 훨씬 줄여라
- creative acting을 줄이고, walk에서 자연스럽게 이어지는 micro-transition만 남겨라

turn 정의:
- auxiliary facing-transition sheet only
- NOT a walk replacement
- NOT a side rotation chart
- NOT a +90 -> 0 -> -90 sequence
- NOT a greeting wave
- NOT an attack swing
- NOT a tray-hold idle pose set

이번 V2에서 원하는 느낌:
- current canonical walk와 거의 같은 frontal read
- 아주 작은 plant / compress
- 아주 작은 chin lift
- 아주 작은 outward paw preparation
- 아주 작은 knee gather
- tiny pivot / hop accent 정도만
- 전체적으로 "same walk language, but briefly redirecting"

중요: motion을 크게 만들수록 AutoSprite가 generic cute acting으로 빠질 가능성이 높다.
이번에는 반드시 모션을 작고 보수적으로 유지해라.

identity lock:
- exact same Menhera as `items/menhera_boss_sheet.png`
- fluffy short pink outer hair + cream/blonde inner front bangs
- rounded fluffy hair silhouette
- pink/white gingham nurse cap
- syringe attached on cap
- red ribbon on cap front language preserved
- NO black cat ears
- large gray/silver eyes with lashes
- exactly one pink heart cheek mark on one cheek only
- pink outfit with white center panel
- exactly 4 black bows vertically stacked
- gray cat-paw gloves with visible pink pads
- med-kit accessory on same side as walk anchor
- pink check cloth-tail motif near med-kit
- white thigh-highs
- black X ankle accessories
- thick black pixel outlines

style lock:
- 16-bit retro pixel art
- chibi proportions
- thick black pixel outlines
- flat limited-saturation pastel palette
- clean hard-edged pixels
- NO anti-aliased anime-soft rendering
- NO soft shading
- NO painterly rendering
- NO modern mobile-game chibi look

sheet format:
- 8 frames total
- if AutoSprite insists on 3x3 packing, accept that as long as we still get 8 usable frames
- pure background preferred
- no decorative UI elements

recommended frame plan with reduced amplitude:
- frame 1: near-neutral carry-in from walk
- frame 2: tiny compress / plant
- frame 3: slight chin-lift preparation
- frame 4: restrained peak redirect pose
- frame 5: tiny rebound
- frame 6: recovery
- frame 7: settle
- frame 8: walk-compatible return

pose restrictions:
- no raised-hand greeting read
- no "holding tray" read
- no idle pose pack
- no random unrelated cute poses
- no strong side-facing 3/4 turn
- no strong arm flourish
- no big dance energy
- no strong theatrical acting

gameplay readability:
- face and accessory readability must survive small in-game size
- cap, syringe, ribbon, heart cheek mark, 4 bows, glove pads, med-kit, cloth-tail must still be visible

output rules:
- do NOT overwrite `items/menhera_boss_turn.png`
- save candidate in `.tmp`, recommended:
  - `.tmp/menhera_turn_autosprite_sheet_v2.png`
  - `.tmp/menhera_turn_autosprite_atlas_v2.json`
  - `.tmp/menhera_turn_autosprite_v2_report.md`

QA comparison targets:
- `items/menhera_boss_sheet.png`
- `items/menhera_boss_victory.png`
- compare also against V1 failure report:
  - `d:\main\bosspong\.tmp\menhera_turn_autosprite_v1_report.md`

V2 success condition:
- AutoSprite must stop generalizing Menhera into generic nurse-chibi
- identity props must survive
- pose set must read as one conservative direction-change micro-sequence
- style class must land materially closer to PingFighter pixel art than V1

V2 reject condition:
- if style still lands anime-soft / anti-aliased
- or key identity props still collapse
- or motion still reads as wave / idle-pose pack
- then conclude that AutoSprite can only be used as motion ideation / reference support, not as final turn-sheet generator for Menhera

최종 보고 형식:
1. V2에서 무엇을 바꿨는지
2. reference board 업로드를 실제로 사용했는지
3. 생성 파일 경로
4. V1 대비 개선점 / 동일 실패점
5. canonical 후보 여부
6. AutoSprite를 최종 생성기로 계속 쓸 수 있는지, 아니면 motion ideation 전용으로 낮춰야 하는지
```
