# Reactive Pillar Portrait — Phase 1 Slice Plan

디스크하츠 - 링피아. 오른쪽 필러 HUD의 비어 있는 세로 밴드(보스 대쉬토큰 오브 `0/1`와
플레이어 대쉬토큰 오브 `1/1` 사이)에 **상단=보스 초상화 / 하단=플레이어 초상화**를 넣고,
스턴=아픈 얼굴 / 승리=기쁜 얼굴 / 패배=슬픈 얼굴로 실시간 반응하게 한다. 말풍선은 Phase 2.

출처: 2026-07-13 5방향 코드 조사 + 종합 검토(feasibility review). 판정 =
`recommend-with-reduced-scope`.

## 확정 스코프 (사용자 결정 2026-07-13)

- **v1 범위**: Stage 1 보스(달지 변종 우선) + 스매셔/바이퍼 2캐릭 **수직 슬라이스**.
  전 보스(+S1 변종)·전 5캐릭 확장은 슬라이스가 인게임에서 읽히는 걸 확인한 뒤 결정.
- **아트 전략**: **기존 전신 시트/셀렉트 컷아웃에서 head-crop Rect2**. 전용 얼굴 아트
  신규 생성 아님. (전신 시트는 애니라 프레임별 크롭 튜닝 필요.)
- **말풍선**: **Phase 2로 분리.** v1에는 없음. 초상화는 단독으로 성립.

## 왜 가능한가 (이미 있는 부품)

- 스턴/승리/패배 상태는 이미 **매 프레임 context key로 발행** — 구독만 하면 됨.
  - 보스 스턴: `active_item_boss_stun_active` OR `status_boss_stun_active` OR
    `ragnarok_hammer_boss_stun_active` (`status_effect_state.gd`).
  - 플레이어 스턴: `status_player_stun_active`.
  - 승/패: `boss_victory_active`/`boss_defeat_active`,
    `player_victory_active`/`player_defeat_active`
    (`match_score_event_controller.gd`, `battle_draw_actor_result_context.gd`).
  - ⚠️ 스턴은 **공격/타격 플래그(`boss_hit`/attack)가 아니라 스턴 채널**에서 읽어야 함
    (보스 시트 계약 hit≠stun 함정).
- **리액티브 표정 선례**: `stage2_boss_expression_state.gd` — neutral/happy/sad +
  타임드 자동감쇠 + `get_snapshot()`. **복제해서 공용 ExpressionState로 승격.**
- 점수→표정 프로듀서: `match_score_event_controller._apply_stage_score_reaction`
  (실점→sad, 득점→happy, `has_method('set_expression')` 게이트).
- 상태→아트 우선순위 디스패치 선례: `stage2_boss_actor_renderer.draw()` 의
  bool-플래그 우선순위 사다리(defeat>victory>...>idle, 첫 성공 early-return).
- 플레이어 얼굴 아트 일부 존재: 스매셔 `smasher_defeat_sad_expression_16f...` 시트,
  캐릭별 승/패/스턴 시트, 셀렉트 컷아웃(`character_select_data.gd` portrait_path).
- 필러 기하: `Stage1PillarUiLayout.build_layout()` 단일 소스.

## 새로 만들어야 하는 것

1. **공용 ExpressionState** (`godot/scripts/hud/reactive_portrait_expression_state.gd`)
   - `stage2_boss_expression_state.gd` 복제 + **`pained` 를 ALLOWED에 추가**
     (안 넣으면 `set_expression`이 조용히 neutral로 클램프하는 no-op 함정).
   - 상태: `neutral | happy | sad | pained`. `set_expression(id, hold_sec)`,
     `update(delta)` 자동 감쇠, `get_snapshot()`.
2. **래치+감쇠 레이어** — 승/패 플래그는 점수당 ~1.75s(scoreboard 창)만 켜짐.
   지속 "기분"을 위해 라이징 엣지에서 표정을 latch하고 hold_sec 뒤 neutral로 decay.
   최종 게임 승/패 얼굴은 `battle_scene_match_flow_driver`(`_resolve_match_defeat`/
   `_show_stage_clear_result`) 를 별도로 읽어 확정.
3. **스턴 엣지 프로듀서** — 스턴 라이징 엣지에서 `set_expression('pained', dur)`
   (보스·플레이어 각각). 현재 이런 배선 없음.
4. **필러 초상화 호스트/렌더러**
   (`godot/scripts/hud/right_pillar_portrait_renderer.gd`)
   - `Stage1PillarUiLayout` 기하 재사용. 자유 밴드 대략
     `y ∈ [game_offset.y + 125*scale, game_offset.y + game_size.y - 135*scale]`,
     `x = right_center_x`, 폭 ~110*scale. 상/하 박스가 위(보스 오브 하단 ~y+125*scale)·
     아래(플레이어 오브+위험감지센서 클러스터 ~y+game_h-135*scale) 오브를 **침범 안 하도록
     draw-time 용량 체크**(Stats-Panel Row Budget 함정 유사).
   - **스크린/뷰 좌표**, post-playfield pillar HUD 패스에서 그림
     (`draw_set_transform(game_offset)` 블록 **바깥**). 80px 레거시 인셋 금지.
   - immediate-mode `draw_texture_rect_region` (TextureRect 금지 — min-size 클램프 함정).
   - 프레임 크롬은 `PremiumPanelFrame` 재사용해 오브들과 톤 통일.
5. **정체성 해석**
   - 보스: `current_stage` + context key `stage1_boss_variant`
     (레거시 `current_boss_name` 없음 — 정체성 = (stage, variant)).
   - 플레이어: `selected_character_type` (`player_character_runtime.normalize`).
6. **head-crop rect 정의** — 캐릭/보스/표정별 소스 시트 + Rect2 + 셀 프레임.
   v1은 (a) 달지 보스, (b) 스매셔, (c) 바이퍼만.
7. **context key 스레딩** — `stage1_pillar_hud_scene_drawer._draw_stage1_pillar_ui`
   의 ~40키 ui_context에 표정/초상화 키 추가.

## 구현 순서 (de-risk = 아트보다 레이아웃·상태 먼저)

- **Step 1 (아트 무관, 레이아웃·상태 검증)**: ExpressionState + 필러 호스트를
  **플레이스홀더(색 박스 or 절차적 얼굴)** 로 그리고 실제 상태(스턴/승/패)에 배선.
  인게임에서 (1) 두 박스가 오브를 안 침범하는지, (2) 스턴/득점/실점에 표정 플래그가
  바뀌는지 먼저 확인.
- **Step 2**: 달지/스매셔/바이퍼 head-crop rect 튜닝 → 플레이스홀더를 실제 크롭으로 교체.
  프레임별 크롭 흔들림(전신 애니라) 확인, neutral 소스 확보.
- **Step 3**: 래치+감쇠 튜닝(hold_sec), 최종 게임 승/패 얼굴 확정 경로 배선.
- **Step 4**: 씰(behavioral smoke) + 픽셀 QA.

## QA / 씰 게이트

- 상태 스모크: 스턴 엣지→pained, 득점→happy, 실점→sad, 감쇠 후 neutral 복귀
  (반증검증 = 버그 코드에서 실패하는지 in-place 토글로 확인, `git reset` 금지).
- draw-time 용량 assert: 최소 실제 scale에서 두 박스가 오브 클러스터를 침범 안 함.
- 픽셀 QA: 라이브 프로세스로 인게임 확인(비헤드리스 .import 주의). 필러 배경 위
  z=0, 음수-z/조상-fill 함정 비해당(단일 immediate-mode Node2D).
- 성능: 없는 에셋 경로 per-frame draw 금지(옵티머스 승/패 없음 — 확장 시 file_exists
  가드/placeholder), draw 경로 lazy-load 금지(prewarm + 스케일 캐시 분리).

## Phase 2 (말풍선) — 분리, 아직 안 함

- Godot에 말풍선 UI 전무. 위젯(패널+꼬리+wrap+fade) + 트리거 매니저 포팅
  (`downtown/boss_dialogues.py` BossDialogueManager: 쿨 900f, 50%, 점수차 상황선택) +
  대사 7언어 이관(레거시 4언어 → es/pt-BR/ru 추가, `language_settings_data.gd` TEXT).
- 스테이지 리맵: 레거시 5→Godot5, 레거시 6(네메시스) 제외, 7→Godot6, 8→Godot7.
- 트리거는 초상화가 이미 쓰는 스턴/점수/결과 엣지에 편승 가능.
- 플레이어 대사 코퍼스는 없음 — 신규 작성 필요.

## 핵심 파일 지도

| 역할 | 파일 |
|---|---|
| 표정 상태 선례(복제 원본) | `godot/scripts/stages/stage2/stage2_boss_expression_state.gd` |
| 표정 프로듀서 선례 | `godot/scripts/core/match_score_event_controller.gd` (`_apply_stage_score_reaction`) |
| 상태→아트 우선순위 디스패치 선례 | `godot/scripts/stages/stage2/stage2_boss_actor_renderer.gd` (`draw()`, `_draw_expression()`) |
| 스턴/상태 소스 | `godot/scripts/status/status_effect_state.gd` |
| 승/패 컨텍스트 리졸버 | `godot/scripts/core/battle_draw_actor_result_context.gd` |
| 필러 기하 단일 소스 | `godot/scripts/hud/stage1_pillar_ui_layout.gd` |
| 필러 HUD 엔트리(호스트 삽입점) | `godot/scripts/hud/stage1_pillar_ui_renderer.gd` |
| 필러 ui_context 빌더(키 추가처) | `godot/scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd` |
| 보스 정체성 | `godot/scripts/core/game_selection_state.gd` (`stage1_boss_variant`) |
| 플레이어 정체성 | `godot/scripts/characters/player_character_runtime.gd`, `battle_scene_state.gd:87` |
| 플레이어 승/패/스턴 시트 선택 | `godot/scripts/resources/battle_resources.gd` (~579-591) |
| 스매셔 슬픔 시트 | `godot/scripts/resources/battle_smasher_sprite_paths.gd` (`SMASHER_DEFEAT_SHEET_PATH`) |
| 셀렉트 컷아웃 초상화 | `godot/scripts/ui/character_select_data.gd` (portrait_path) |

## 알려진 갭 (확장 시 처리)

- 옵티머스는 승리/패배 아트가 아예 없음 → 전 로스터 확장 시 신규 아트 or neutral 폴백.
- 스턴 리액션 시트는 현재 바이퍼 전용 → 비바이퍼 pained 얼굴은 크롭 소스 별도 확보.
- 얼굴 전용 파츠 리그는 스매셔 Live2D만 있음(head_face/eyes/mouth 분리).
