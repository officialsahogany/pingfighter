# 탑 라이브 R3 피드백 완료 보고

- 기준 커밋: `887a1903e`
- 구현 커밋: `f867fe1a0`
- 작업 브랜치: `codex/tower-live-feedback-r3-887a`
- 판정: **요구 5건 완료, 범위 내 blocked 0건, unverified 0건**

## 구현 결과

1. **전투 HUD 무혼 표시**
   - 모든 스테이지가 공유하는 `stage1_pillar_hud_scene_drawer.gd` / `stage1_pillar_ui_renderer.gd` 경로에 골드와 같은 계측 구간(`stage1.pillar.gold_hud`)으로 배선했다.
   - 골드 바로 아래에 현재 탑 런의 무혼 잔액을 표시한다. 기존 무혼 불꽃 팔레트와 `CommonStarpointVisualHost` 합성을 재사용했다.
   - 그리기 중에는 `tower_ascent_flow_owner`를 `get_cached_instance()`로만 조회한다. 비탑 런에서는 숨고, 플래그 OFF 경로에는 무혼 경제가 생기지 않는다.

2. **기본 활주 2개 통일**
   - `DEFAULT_STARTING_DASH_TOKENS`를 2로 올리고 상태 스키마, 리셋 fallback, 캐릭터 퍽 문맥, 신화 아이템 런타임·스탯·표시 스냅샷의 1개 가정을 함께 제거했다.
   - 수련 분기는 삭제하지 않고 `JUNIOR_STARTING_DASH_TOKENS == DEFAULT_STARTING_DASH_TOKENS`로 유지했다. 즉 수련만의 추가 보너스가 아니라 모든 리그의 같은 기본값이다.
   - 오딘의 눈처럼 명시적으로 1개를 요구하는 별도 제약은 보존했다.

3. **구매 카드 무혼 흡수 연출**
   - 구매 즉시 카드가 플레이어 쪽으로 0.78초 동안 흡수되고, 종료 후 해당 고정 슬롯은 완전히 빈 공간으로 남는다.
   - 다른 카드의 위치·순서는 재정렬하지 않으며, 첫 연출 중에도 남은 카드를 연속 구매할 수 있다.
   - 기존 무혼 필드 드롭의 불꽃 합성을 재사용했고 입력 잠금은 추가하지 않았다.
   - 임시 조정값: `TEMP_REWARD_PICK_ABSORB_DURATION_SEC := 0.78`.

4. **경로 서브 화면 자유 이동**
   - 발사 대기와 공 비행 중 모두 좌우 이동은 이미 프로덕션 경로에서 동작하고 있었다. **선재 동작**으로 판정하고 대기·발사·비행 각 프레임의 이동 갱신을 회귀 테스트로 봉인했다.

5. **왕복 각도 게이지 발사**
   - 플레이어 위에 부채꼴 각도 게이지를 그려 `-55°..+55°`를 2.4초 주기로 왕복시킨다. 마우스 왼쪽 버튼의 누른 순간에만 현재 각도로 초속 522px 발사한다.
   - 정지 조준, 스냅, 자동 보정, 궤적 예측선은 추가하지 않았다. 물리 반사와 플레이어별 체감 속도를 그대로 사용하며 게임플레이 RNG를 소비하지 않는다.
   - 기존 좌클릭 소비자와 충돌하지 않도록 공유되는 프레임 단위 입력 스냅샷의 `mouse_left_just_pressed`만 읽는다. 키보드 accept는 발사하지 않는다.
   - 임시 조정값: `TEMP_ROUTE_AIM_MIN_DEGREES := -55.0`, `TEMP_ROUTE_AIM_MAX_DEGREES := 55.0`, `TEMP_ROUTE_AIM_SWEEP_PERIOD_SECONDS := 2.4`, `TEMP_ROUTE_AIM_SERVE_SPEED_PER_SECOND := 522.0`, `TEMP_ROUTE_AIM_GAUGE_PLAYER_GAP := 100.0`.

## 검증

### 자동 게이트

- 본 트리 탑 스모크 전체: `PASS=40 FAIL=0 TOTAL=40`.
- `tower_ascent_route_serve_smoke.gd`: 독립 프로세스 반복 `5/5 PASS`. 물리 왕복 검증은 표적 타격과 분리했고, 프로덕션 최소 수직 반사각 25°의 전체 횡단 시간을 수용해 간헐 실패를 제거했다.
- 활주 핵심 감사: `default_dash_token_baseline_smoke`, `runtime_perk_character_context_smoke`, `runtime_perk_level_side_effects_smoke`, `mythic_item_capacity_gauge_runtime_smoke`, `perk_overlay_dash_token_slot_cells_smoke` 모두 PASS.
- 긴급 회귀 봉인: `tower_ascent_vertical_slice_smoke.gd`가 실물 `BattleSceneShell`의 첫 승리 활성화와 중복 진입 거부를 PASS했다.
- 변경 GDScript 26개 `run_warning_scan.ps1 -Paths`: 경고 0.
- `run_headless_load_check.ps1`: PASS, graceful shutdown 확인.
- 신규/변경 핵심 테스트 4개가 CI와 pre-push 목록에 각각 정확히 1회 등재됨.
- `git diff --check 887a1903e..HEAD`: GREEN.
- 변경 29경로에서 `pingfighter.py`, `.godot` 캐시, `builds` 등 금지 경로: 0건.

범위 밖 탐색으로 실행한 `dash_token_slot_cost_smoke.gd`는 현재 본 트리의 별도 미커밋 WIP 상태에서 “슬롯 만석 시 일반 보유 퍽 레벨업” 기존 기대가 실패했다. R3 변경 경로나 등록 게이트가 아니며, 위 R3 활주 기본값 검증 5건은 모두 통과했다. 앞서 확인한 `match_reset_controller_smoke.gd`의 기존 보물 리셋 기대 불일치도 같은 방식으로 범위 밖 기준선으로 분리했으며, 이 작업이 추가한 2토큰 리셋 단언은 통과했다.

### 실제 Vulkan 및 라이브 재생

- `run_tower_route_serve_owner_meta_visual_qa.ps1`: PASS, 4캡처.
  - 각도 게이지: `godot/.godot/codex_captures/tower_route_serve_owner_meta/route_aim_angle_gauge.png`
    - SHA-256 `9D90A5072EA5140A26A3E0DD80F2ABA1F81844403DF686B3AF801A5DE9419241`
  - 무혼 HUD(골드 0 아래 무혼 8): `godot/.godot/codex_captures/tower_route_serve_owner_meta/battle_hud_muhon.png`
    - SHA-256 `C391CE99709BF211C9DE736833882723C9ADEBF5AC1D3BD25D811FA8330AB764`
- `run_tower_reward_pick_visual_qa.ps1`: PASS, 3캡처.
  - 구매 후 고정 빈 슬롯: `godot/.godot/codex_captures/tower_reward_pick/post_purchase_empty_slot.png`
    - SHA-256 `8A297A8BEA2878E7EB05FC96C9B5C79E5CFA2F48C2A1E89A2DA5CCCAF236DC62`
- `run_tower_mode.ps1` 실제 플레이에서 한미량 선택 후 첫 승리 → 계속 → `ROUTE_AIM` 진입을 재현했다.
  - 캡처: `godot/.godot/codex_captures/tower_live/r3_first_victory_route_aim.png`
    - SHA-256 `9DFE95E4092697C21F3F42BA988DA0ACE9F5A2C9B67833CB9448A38E440453E1`
  - 로그: `godot/.godot/codex_logs/tower_mode_live_33524_20260818144144710.log`
    - SHA-256 `3177D5E0EC858AD3A1C5C49ED1A5AE86A08B6E68F0243D6C123ED23E47D5155F`
  - `physics.frame.gate.tower_ascent_flow`: 총 239 블록 중 비활성 148, 활성(250us 초과) 91. 활성 평균 최저 364.2us, 최고 533.5us, 마지막 392.8us.
  - `[TowerAscent] ... rejected`: 0건. 실물 셸에서 첫 승리 후 탑 슬라이스가 실제 활성화됨을 확인했다.

라이브 QA용 Godot 프로세스만 정상 종료했고 사용자 게임 PID 36600과 에디터 PID 18096은 종료하거나 조작하지 않았다. 외부 실행 감시 셸은 증거 확보와 QA 창 정상 종료 뒤 600초 대기 상한에 도달했으나, 제품 프로세스·캡처·로그 판정에는 영향이 없다.

## WIP 보존과 통합

- 격리 워크트리 `D:\main\bosspong_tower_live_feedback_r3_887a`에서 경로별 커밋으로 구현했다.
- 본 트리와 겹친 사용자 WIP 6경로는 패치 역적용 → fast-forward → 패치 재적용으로 보존했고, 전후 추가·삭제 내용과 최종 해시가 동일함을 확인했다.
- 백업: `D:\codex_backups\tower_live_feedback_r3_20260818_204620`
- WIP 패치 SHA-256: `1388BC78FC0B8BA0210C0D865CAB451BBEC47AB2186529AB99B260F353540320`
- stash, checkout, reset, broad staging, push를 사용하지 않았다.
