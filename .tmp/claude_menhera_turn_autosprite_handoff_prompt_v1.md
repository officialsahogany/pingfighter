# Claude Handoff Prompt: Menhera Turn via AutoSprite MCP

아래 프롬프트를 그대로 Claude에게 전달하면 됩니다.

```text
이번 작업은 PingFighter 스테이지 3 멘헤라걸의 TURN 시트를 AutoSprite MCP로 실험하는 것입니다.

중요:
- 먼저 `d:\main\bosspong\CLAUDE.md`를 따르고,
- 보스 스프라이트 작업이므로 반드시 `d:\main\bosspong\.claude\skills\sprite-generation\SKILL.md` 기준으로 진행해줘.
- 보스 스프라이트 생성 규칙은 기억으로 재구성하지 말고, `sprite-generation` 스킬 기준을 우선 적용해줘.

작업 범위:
- 이번 패스는 TURN 전용 실험이다.
- walk / attack / dash / victory / defeat는 건드리지 않는다.
- runtime integration은 하지 않는다. Codex handoff 전까진 자산 후보 생성과 QA까지만 한다.

스테이지 컨텍스트:
- real Stage 3 Menheragirl
- code 기준으로는 `current_stage == 3`

핵심 목표:
- Menhera의 turn을 "옆으로 도는 angle chart"가 아니라
  "정면 읽힘을 유지한 채 잠깐 방향 전환 시 나오는 characterful gesture"로 만든다.
- 즉, profile rotation chart를 만들면 안 된다.
- walk를 대체하는 시트가 아니라, 방향 전환 순간에만 잠깐 쓰이는 auxiliary turn sheet를 만든다.

현재 상태 참고:
- canonical walk anchor는 `items/menhera_boss_sheet.png`
- quality / readability tier reference는 `items/menhera_boss_victory.png`
- 현재 runtime에서는 Menhera turn visible playback이 아직 꺼져 있을 수 있으므로,
  이번 작업은 우선 asset-side candidate 생성과 QA까지만 한다.
- 기존 turn 중 angle-chart 계열 / side-facing 계열은 shape anchor로 삼지 마라.

반드시 지킬 identity lock:
- `items/menhera_boss_sheet.png`와 EXACT SAME Menhera여야 한다.
- fluffy short pink outer hair mass + cream/blonde inner front bangs
- rounded fluffy hair silhouette, not flat bob
- pink/white gingham nurse cap
- red ribbon on cap
- syringe attached on cap
- NO black cat ears
- large gray/silver eyes with strong lashes
- exactly one pink heart cheek mark on one cheek only
- pink outfit with white center front panel
- exactly 4 black bows vertically stacked on the white front panel
- dark gray cat-paw gloves with visible pink pads
- med-kit accessory stays on the same side as the walk anchor
- pink check-pattern cloth-tail motif near the med-kit
- white thigh-highs
- black X ankle accessories
- petite chibi human body class
- thick black pixel outlines

turn motion brief:
- front-facing direction-change gesture only
- face and torso stay mostly frontal
- slightly lifted chin
- dreamy / middle-distance upward gaze
- one paw/arm softly sweeps outward with a loose flourish
- the other arm supports balance
- one knee lifts slightly at the peak
- tiny pivot / hop accent allowed
- hair, ribbon, med-kit, hem, and cloth-tail rebound subtly
- compact whole-body rhythm, not just hand motion

절대 하면 안 되는 것:
- side-view rotation chart
- +90 -> 0 -> -90 angle sequence
- profile showcase
- greeting wave처럼 보이는 큰 손흔들기
- attack swing처럼 보이는 모션
- taunt / dance loop처럼 보이는 과한 연기
- frontal read를 잃어버리는 strong 3/4 or side-facing turn

스타일 규칙:
- 16-bit retro pixel art
- chibi proportions
- thick black pixel outlines
- flat limited-saturation palette
- clean hard-edged pixels
- NO painterly rendering
- NO soft shading
- NO photorealism

1차 시도 목표:
- AutoSprite MCP를 사용해서 8-frame TURN sheet를 먼저 1차 시도해줘.
- sheet format:
  - exactly 8 frames
  - 4 columns x 2 rows
  - pure white background
  - no grid lines
  - no labels
  - no border
  - full body fully visible in every frame
  - character centered in every frame
  - generous white margin

추천 프레임 플랜:
- frame 1: walk-compatible carry-in
- frame 2: small plant / compress
- frame 3: lifted-chin wind-up
- frame 4: peak transition pose
- frame 5: rebound from peak
- frame 6: recovery step
- frame 7: settle toward neutral frontal walk
- frame 8: walk-compatible return

gameplay readability must be mandatory from the first generation:
- eyes, lashes, cheek heart, cap silhouette, ribbon, syringe, gloves, bows,
  med-kit, legwear, and cloth-tail must remain readable at small in-game size
- preserve clean separation between hair, face, arms, outfit, accessory, and legs
- reduce muddy midtones
- face / forehead must not read as clipped or squashed

scale rule:
- visible body read must stay within about +/-5% of the canonical walk
- do not let the turn read smaller than the walk in gameplay
- motion accents must not visually compress the body

출력 규칙:
- 아직 `items/menhera_boss_turn.png`를 덮어쓰지 마라.
- first candidate는 `.tmp` 아래에 저장해라.
- 추천 출력:
  - `.tmp/menhera_turn_autosprite_sheet_v1.jpeg` or `.png`
- 가능하면 background removal / nukki 후 PNG 후보까지 만든다.

실패 시 fallback:
- 8프레임 시트가 identity drift나 side-facing drift를 일으키면,
  full sheet를 고집하지 말고 framewise workflow로 전환해라.
- 그 경우:
  1. peak pose single-image 먼저 만들고
  2. entry 1~3 프레임을 single-image로 생성하고
  3. recovery 5~7 프레임도 single-image로 생성한 뒤
  4. QA 후 stitch하는 흐름으로 간다.

hard reject conditions:
- different Menhera
- side-facing / profile-like read
- greeting wave read
- attack swing read
- face / forehead clipped-looking read
- bow count drift from 4
- med-kit side drift
- eye color drift away from gray/silver
- blurrier / softer than `items/menhera_boss_victory.png`

QA comparison target:
- `items/menhera_boss_sheet.png`
- `items/menhera_boss_victory.png`

QA check list:
- same hair silhouette continuity
- same face read and eye color
- same one-heart cheek mark
- same 4-bow count
- same med-kit side lock
- same glove / paw-pad read
- frontal-read preservation across the sequence
- body-read parity with walk at gameplay size
- frame 7 -> frame 8 -> walk reconnection readability

최종 결과 보고 형식:
1. 어떤 방식으로 시도했는지
   - full 8-frame AutoSprite pass인지
   - or fallback framewise workflow인지
2. 생성된 후보 파일 경로
3. QA에서 통과한 점 / 실패한 점
4. canonical turn 후보로 볼 수 있는지 여부
5. Codex에 넘길 필요가 있는 handoff note

가능하면 이번 턴에서:
- `sprite-generation` skill을 사용해 작업하고,
- AutoSprite용 prompt wording을 다듬고,
- candidate output을 `.tmp`에 만들고,
- QA까지 진행한 뒤,
- 아직 canonical overwrite는 하지 않은 상태로 보고해줘.
```
