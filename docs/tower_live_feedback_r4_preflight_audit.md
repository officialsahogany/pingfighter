# 라이브 4런 피드백 착수 전 코드 실사 감사 (2026-08-19)

- 대상: 사용자 라이브 4런 피드백 6건. 정본 = `docs/tower_ascent_run_map_plan.md`.
- 방법: 6영역 병렬 코드 실사(퍽 선택 UI · 절세 연출 · 서브 타이밍 · 지도 연출 ·
  배경 소유 · 페이드/아트) → 3렌즈 적대 검증(반경 · 계약 충돌 · GRT 함정) → 종합.
  판정 = 반려 / 조건부승인 / 조건부승인.

## 0. Fable 직접 확인 사항

아래 두 가지는 감사 결론의 뼈대이며 코드로 재확인했다. `[확인]`.

1. **보상 픽과 노드 모달은 플레이필드 변환 패스에서 그려진다** `[확인]`.
   `battle_scene_drawer.gd`의 전체화면 스크린 공간 호출 게이트가
   `phase_name not in ["MAP_OVERLAY", "MAP_TRANSITION"]`이면 조기 반환하고,
   형제 게이트 `battle_playfield_scene_drawer.gd`도 같은 두 페이즈만 조기 반환한다.
   즉 `NODE_MODAL`과 보상 픽은 스크린 공간 승격 대상에서 빠져 있다.
   이것이 사용자가 보고한 두 증상의 **공통 기계적 원인**이다.
   - 카드가 퍽 선택 모달보다 작게 보인다 (플레이필드 축소 배율을 함께 받는다).
   - 파계승을 골랐는데 달지와 스테이지1 필러가 그대로 남는다
     (스크림이 760x750 게임좌표에만 걸려 필러 크롬과 보스를 덮지 못한다).
2. **절세무공 REVEAL 클릭이 보상 픽에 먹힌다** `[확인]`.
   `tower_reward_pick_state.is_external_modal_active()`는
   `_pending_external_kind`가 `fusion` 또는 `vision_swap`일 때만 true를 돌려주고
   신화 획득 시네마틱은 조건에 없다. 따라서 픽이 입력을 계속 선점해 2페이즈가
   진행되지 않는다.

**지도 전체화면에 대한 정정**: r2 보고의 "전체화면 GREEN"과 사용자의 "작게 보인다"는
둘 다 사실이다. 지도 **표면**은 전체화면이 맞으나 지도 **내용**(노드 열 폭, 아이콘
크기, 상하 인셋)에 절대 상한이 걸려 있어 실 해상도에서 전부 포화한다. 검증 해상도가
1280x800이라 상한이 미포화였고 결함이 원리적으로 관측되지 않았다. 상세는 §1 S4-a.

---

### 1. 이번 슬라이스 항목 (구현 계약)

착지 순서를 고정한다. 앞 슬라이스가 GREEN이 아니면 다음 슬라이스에 착수하지 않는다. 슬라이스마다 헝크 분리 커밋 1개, 씰 개정 파일은 슬라이스당 스모크 1개로 제한한다.

---

#### S0. 절세무공 획득 연출 2페이즈 클릭 복구 (요구 2)

**단독 선행 근거**: 6건 중 유일한 영구 정지 버그다. REVEAL 대기 중 `mythic_item_pause_gate.should_pause_game()`이 게임을 멈춘 채 클릭이 도달하지 않으므로, 이 상태를 두고는 A·C·D·E·F 어느 것도 라이브 체감 검증을 할 수 없다. 게다가 수정 지점이 A·C와 같은 두 함수(`battle_scene_input_controller.gd:197-224`, `tower_reward_pick_state.gd:122-165 / 238-251`)라 뒤에 섞으면 회귀 귀속이 불가능해진다.

**편집 계약**

1. `godot/scripts/tower_ascent/tower_reward_pick_state.gd:238-251 is_external_modal_active()`에 신화 획득 시네마틱 활성 조건을 추가한다. `_registry`가 이미 잡혀 있으므로 `mythic_item_runtime.is_acquisition_cinematic_active()`를 조회한다. `_pending_external_kind`는 건드리지 않는다(빈 문자열이면 `_update_external_modal_return()`이 조기 반환하는 기존 fusion/vision 복귀 로직을 그대로 보존해야 한다).
2. 그 결과로 `_handle_victory_loot_input`(:212-216)이 false를 돌려 90행 `_reward_modal_input_router.handle_input`으로 흘러가고, 시네마틱이 클릭을 받는다. 부수효과로 픽의 카드 구매·ENTER·SPACE·ESC·계속하기 클릭이 연출 중 전부 no-op이 되는 것을 **의도된 계약**으로 확정한다.
3. REVEAL 무한 대기 상한(자동 absorb)은 **도입하지 않는다**. `finish_phase_step()`에 `PHASE_REVEAL` 분기를 추가하지 말고, "입력 없이는 절대 진행하지 않는다"를 계약으로 못박는다. 대신 `mythic_item_acquisition_reveal_presenter.gd`에 REVEAL 무장(`REVEAL_CLICK_DELAY=0.5s`) 이후에만 페이드인되는 한국어 안내 문구를 추가한다(무장 전 0.5초 구간에는 표시 금지, LanguageSettings 7언어 등재, 엠대시 금지).
4. 시네마틱 개폐를 중앙 pause/resume 팬아웃에 태운다. 승리 전리품 분기는 `battle_physics_gate_coordinator.should_block`의 `enter_modal_block` 팬아웃 밖이므로, 시네마틱 활성 동안 액티브 아이템 쿨다운 pause와 `GameplayLoopAudioCleanup.stop_all`이 정확히 1회씩 걸리고 종료 프레임에 leave가 1회 발생하는지 반증 레그로 확인한다(GRT-058).

**씰 계약**

- `godot/tests/battle_scene_modal_overlap_input_smoke.gd`의 FakeRegistry(132-139)에 `victory_loot_phase_state` 키를 추가한다. 현재 이 키가 없어 128행 "standalone mythic acquisition cinematic should keep its click input path"가 두 라우트 null로 빠지는 공허 GREEN이다. 레그는 두 개다. (a) 픽 활성 + 시네마틱 활성 → 시네마틱 `input_count==1`, 픽 `input_count==0`. (b) 반전 대조군: 시네마틱 비활성 → 픽이 받는다.
- `godot/tests/battle_reward_modal_input_router_owner_smoke.gd:208-209`의 소스 순서 단언에 `_handle_victory_loot_input(` 위치를 포함시킨다.
- `godot/tests/mythic_perk_acquisition_cinematic_smoke.gd`에 REVEAL 무장 후 실제 `handle_acquisition_cinematic_input` 클릭 → absorb → impact → complete 진행 레그를 추가한다.
- 신규·개정 씰을 `.github/workflows/godot-ci.yml`과 `godot/tools/run_pre_push_checks.ps1` 두 리터럴 목록에 동시 등재한다(탑 계열은 현재 focused 목록에 0건).
- 픽셀 증거: 비헤드리스 캡처로 REVEAL 안내 문구 표시, `waiting_for_click` false 구간 미표시 부정 레그.

---

#### S1. 경로 서브 진입 arm 딜레이 + 전량 구매 자동 전환 (요구 3)

**한 슬라이스로 묶는 근거**: 자동 전환만 단독 착지하면 4번째 구매로부터 흡수 0.78초 뒤에 발화하므로 그 경로에서만 손가락이 이미 릴리스되어 즉시 발사가 우연히 사라진다. (i) 부분 구매 후 계속하기 클릭, (ii) 노드 모달 종료 클릭 두 진입점은 그대로 남으므로 사용자는 "가끔 고쳐진 것 같다"를 관측하고 페이크 리더 스모크는 GREEN을 유지한다. 자동 전환 단독으로 "즉시 발사 해결"을 주장하지 않는다.

**arm 딜레이 계약**

1. `TowerAscentRouteServeRuntime`에 인스턴스 상태 `_serve_arm_remaining: float`를 둔다. `begin()`(:45-79)에서 `TEMP_ROUTE_AIM_ENTRY_ARM_SECONDS`로 세팅, `cancel()`(:82-102)에서 0.0으로 리셋한다.
2. **게이트는 :123 좌클릭 조건에만 건다.** `:115 _read_player_input_snapshot()`, `:116 _update_player_route_movement()`, `:122 _update_aim_oscillator()`는 전부 게이트 **위**에 그대로 둔다. `update()` 초입이나 대기 분기 앞의 조기 반환으로 구현하면 진자와 좌우 이동이 함께 얼어붙어 정본 §3.2의 "정지 조준 금지"와 "좌우 자유 이동" 두 조항을 동시에 위반한다.
3. arm 창 동안에도 매 프레임 스냅샷을 소비해 홀드된 에지를 흡수·**폐기**한다. 보류 후 만료 시 발사하는 큐 방식은 금지한다. 그것은 "시간 경과가 트리거한 서브"라서 v1.7 자동 서브 금지를 실제로 위반한다(GRT-050).
4. `round_flow_state`의 `waiting_for_serve` / `update_waiting` / `SERVE_DELAY`는 절대 건드리지 않는다. 소스 텍스트 씰이 요구하는 `_serve_flow.update` 부재, `mouse_left_just_pressed` 존재, `action_just_pressed` 부재를 깨지 않는다.
5. `_reset_aim_oscillator()`의 `begin()` 호출을 **제거**한다. `_aim_elapsed_seconds`를 진입 간에 캐리오버시켜 고정 앵커를 없앤다. 고정 앵커가 남으면 arm 만료 시점 각도가 `55*sin(2π·T/2.4)`라는 상수가 되어 v1.11이 v1.6 폐기 사유로 든 "사실상 결정적 선택"이 재도입된다. `TEMP_ROUTE_AIM_ENTRY_ARM_SECONDS`는 스윕 주기 2.4초의 단순 유리수 배수(0.6/1.2/1.8)로 두지 않는다.

**자동 전환 계약**

1. 판정을 단일 헬퍼 하나로 계산해 호출부가 갈라지지 않게 한다(GRT-022 형제 사례). 세 술어 동시 만족: (a) `spent_flags`가 비어있지 않고 전량 true, (b) `purchase_absorption_effects.is_empty()`, (c) `is_external_modal_active()`가 false.
2. **배치 위치가 계약이다.** `update()` 안에서 `_update_external_modal_return()` **다음**, 외부 모달 비활성 분기 **안쪽**에만 둔다. 무공합일 구매는 융합 모달이 아직 열린 상태에서 `_commit_purchased_slot`이 `spent_flags[index]=true`를 찍으므로, 무공합일이 마지막 미구매 카드면 융합 모달 내부에서 전량 true에 도달한다. 여기서 `_finish()`가 발화하면 `reset()`이 `_pending_external_kind`와 `_owner`/`_registry`를 비워 융합 모달이 영구히 정리되지 않는다.
3. 흡수 종료 후 **빈 보드 유지 구간**을 별도 상수로 둔다(`TEMP_REWARD_PICK_EMPTY_BOARD_HOLD_SEC`). 정본 v1.11이 확정한 최종 상태는 흡수 모션이 아니라 "카드 흔적이 전혀 없는 빈 공간"이며, 흡수 종료 프레임에 곧바로 닫으면 그 상태가 0프레임 표시된다.
4. **1회 시도 래치**를 둔다(`_auto_finish_attempted`). `_finish()`는 `finalize_reward_pick`이 `accepted=false`면 상태 문구만 갱신하고 조기 반환하는데, update 컨텍스트에서는 이것이 매 물리 프레임 재시도가 되고 플레이어의 유일한 탈출구(SPACE/ESC/계속하기)도 전부 같은 실패 경로라 원인 표시 없는 영구 정지가 된다. 실패 시 재시도하지 않고 수동 계속하기를 유도하는 상태 문구를 띄운다.
5. 자동 finish를 그 프레임에 즉시 실행하지 말고 **1프레임 지연 플래그**로 다음 프레임 시작에 실행해 실행 컨텍스트 이동 폭을 줄인다. `begin_vertical_slice` → `_modal_lifecycle.enter()`의 쿨다운 pause와 `stop_all`이 물리 프레임 중간으로 옮겨가는 것을 씰로 단언한다.
6. 계속하기 버튼은 부분 구매용으로 그대로 유지한다. 자동 전환 범위는 **전량 구매만**으로 한정한다(§5 질문 3 참조).

**씰 계약**: `godot/tests/tower_ascent_route_serve_smoke.gd`와 `godot/tests/tower_reward_pick_smoke.gd`. 두 스모크는 이미 CI·pre-push 락스텝에 있으므로 목록 갱신은 불필요하다.

- 상태형 픽스처를 신설한다. 스냅샷 딕셔너리 직접 대입 페이크로는 `_last_mouse_left_pressed` 상태 전이를 원리적으로 재현할 수 없어 이 결함이 전 게이트 GREEN으로 통과했다. 레그 3종: (a) 직전 프레임 false + 이번 프레임 눌림 유지 → 진입 첫 프레임 `serve_calls==0`, arm 게이트 제거 대조군은 RED, (b) arm 만료 후 같은 홀드 지속 → 여전히 0건, (c) 릴리스 후 재클릭 → 정확히 1건.
- 정지 조준 반증 2종: arm 창 동안 `get_aim_gauge_model()["angle_degrees"]`가 프레임마다 변한다, arm 창 동안 좌우 입력으로 `player_pos.x`가 변한다.
- 오실레이터 앵커 반증: 체류 시간이 다른 두 연속 진입에서 진입 각도가 다르다.
- 자동 전환 4레그: 융합 모달 활성 중 all-spent 상태에서 finish 미발화, 융합 복귀 후 최소 유지 시간 동안 픽 활성 유지, 흡수 종료 후 빈 보드 유지 구간 동안 `active==true` 및 `spent_flags` 전량 true, 그 뒤 정확히 1회 발화. 부정 레그로 `_pending_external_kind`가 빈 문자열이 아닌 프레임에서 `_finish` 호출 0건.
- finalize 실패 주입 레그: 프레임 10회 경과 후에도 `finalize_reward_pick` 호출 횟수 1.
- 비전초식 만석 스왑(`_begin_vision_swap`)도 같은 형태이므로 동일 레그를 미러링한다.

---

#### S2. 보상 픽과 노드 모달을 스크린 공간 패스로 승격 (요구 1 전제 + 요구 6 절반)

**직접 판정**: 좌표계 결정을 사용자 질문으로 미루지 않는다. 요구 1의 원문이 "기존 퍽 선택 화면과 동일 구성"이고, 퍽 모달은 미변환 스크린 공간(약 2020x1246), 보상 픽은 변환된 플레이필드 패스(750px × render_scale 1.448)에서 그려진다. 같은 상수를 써도 보상 픽 카드는 화면상 퍽 모달의 약 66%로 작아지고, 능력치 띠 행 지오메트리는 절대 px 하드코딩이라 1.448배 확대되어 오히려 더 크고 굵게 나온다. 한 화면 안에서 카드는 작고 글자는 큰 상태는 "동일 구성" 요구와 정면으로 어긋나므로 (A)안 스크린 공간 승격이 유일한 정답이다.

동시에 요구 6의 관측된 증상("달지가 옆에 그대로 있고 스테이지1 맵 그대로인데 선택창만 뜬다")의 기계적 원인이 정확히 같은 계층 문제다. `tower_ascent_flow_renderer.gd:818-826 _draw_node_modal`은 게임좌표 760x750에 알파 0.54 스크림 하나와 `MODAL_RECT(78,112,604,548)` 종이 패널이 전부이며, 스크림이 게임좌표에만 걸려 필러 크롬은 감광조차 되지 않고 전투 HUD 패스(`_draw_post_playfield_pillar_hud`, `_draw_perk_hud_strip`, `_draw_hud_overlays`)는 모달 **위에** 얹힌다. 두 승격이 같은 함수 `battle_scene_input_controller.gd:227-249 _tower_event_in_playfield_coordinates`를 건드리므로 반드시 한 슬라이스다.

**편집 계약**

1. 페이즈 목록 두 곳을 락스텝으로 확장한다. `battle_scene_drawer.gd:260`(스크린 공간 호출 게이트)과 `battle_playfield_scene_drawer.gd:433`(플레이필드 조기 반환 게이트)에 `"NODE_MODAL"`을 추가한다. 한쪽만 고치면 모달이 이중 렌더되거나 아예 사라진다. 두 목록을 **공유 상수 하나**로 뽑아 리터럴 중복을 없앤다.
2. 보상 픽도 같은 방식으로 승격한다. `battle_playfield_scene_drawer.gd:406 _draw_victory_loot_boxes` 경로에서 보상 픽 활성 시 조기 반환하고, `battle_scene_drawer.draw()` 말미에 스크린 공간 호출부를 신설한다. `view_size`는 `canvas.get_viewport_rect().size`를 1순위로 쓴다.
3. **그리기·rect 생성·입력 좌표 변환을 같은 슬라이스에서 함께 옮긴다.** `_tower_event_in_playfield_coordinates`를 페이즈별 변환 테이블로 재작성한다. NODE_MODAL과 보상 픽은 변환하지 않고 스크린 좌표를 그대로 넘긴다. `tower_ascent_node_modal_state.gd:84-114 select_at_position` / `get_action_rects`와 `tower_reward_pick_state.get_card_rects` / `get_continue_rect`가 전부 같은 좌표계를 쓰는지 단일 소스로 확인한다. 변환 소비자가 0이 되면 함수를 제거하되 탑 지도 오버레이 입력 회귀 레그를 남긴다.
4. `tower_ascent_flow_renderer`에 `draw_fullscreen_node_modal(canvas, flow, fallback_rect)`을 신설한다. 그리는 순서는 뷰포트 전면 불투명 배경 → 노드 kind별 절차적 배경 → 기존 종이 패널이다. `resolve_fullscreen_rect`(:91-96)와 동일하게 `is_inside_tree()` 가드 + `canvas.get_viewport_rect()` 1순위를 지킨다. 새 전체화면 함수는 형제의 GRT-044 계약과 그 씰을 상속하지 않는다.
5. **노드 kind 5종 절차적 배경을 이번에 넣는다.** 신규 에셋 0건이다. `_draw_immortal_realm_backdrop`(구름·절벽 폴리곤, 텍스처 0장)이 이미 선례이고, 상점은 `PlazaInteriorRoomRenderer.draw_room(canvas, font, view_size, scale, time, building_type, accent, null)`이 완전 절차적 static이라 `const preload` 후 직접 호출 가능하다. 나머지 4종(수련, 파계승, 수호령 샘, 휴식)은 kind별 절차적 배경으로 그린다. 텍스처 상수는 하나도 추가하지 않는다.
6. `_open_node_modal()` 시점에 노드 kind를 표현 계층에 통지하는 경량 경로를 만든다(`get_node_modal_kind()` 공개 + 드로우 측 조회). `_begin_stage_transition_loading` 재사용은 금지한다. 노드 진입·이탈마다 2.20초 로딩이 두 번 붙는다.
7. **문서 개정을 코드보다 먼저 한다.** `docs/tower_ascent_run_map_plan.md` §3.14의 "미니창" 표현을 "노드 화면"으로 개정하고, "별도 상점 씬·샘터 씬을 만들지 않는다" 조항은 **유지**한다(씬 파일 추가가 0건이므로 조항 취지는 보존된다는 문장을 명시). 동시에 §3.14에 "도달 노드의 표현 전환" 조항을 신설해 2026-08-18 v1.7 교정("업무 모달은 해당 노드에 도달했을 때만 연다")이 만들어낸 파생 의무를 정본에 기록한다.

**씰 계약**

- GRT-022 반증은 카드와 액션 버튼의 **상단 모서리** 좌표로 짠다. 중심점으로 하면 밀림 139px가 카드 높이 절반 96px를 넘어 우연히 다른 카드에 걸리므로 변별력이 0이다.
- GRT-044 씰: `view_size`가 없는 라이브형 context와 작은 game_size를 함께 넣어 뷰포트 크기와의 불일치를 단언한다.
- Vulkan 캡처를 실 해상도(2020x1246)로 1장 추가한다. `tower_reward_pick_visual_qa.gd:23`의 `760x750` 캡처 계약과 `tower_ascent_map_overlay_visual_qa.gd:14`의 `GAME_SIZE 1280x800`을 함께 갱신한다.
- 노드 모달 배경이 필러/레터박스까지 덮는지 픽셀 단언: 화면 네 모서리 픽셀이 배경 색이고 전투 HUD 픽셀이 검출되지 않는다.

---

#### S3. 보상 픽에 무공 슬롯 원장·능력치 띠·호버 배선 (요구 1)

**직접 판정**: "카드 선택 시 실시간 반영"은 **(a) 구매 후 즉시 갱신**으로 확정한다. 요구 원문이 "기존 퍽 선택 화면과 동일 구성"인데, 기존 화면에는 가상 적용 프리뷰가 존재하지 않는다. 능력치 값은 `CharacterInfoOverlayStatsPresenter.build_player_stat_rows`가 라이브 owner/registry에서 실측하고, 선택 인덱스는 캐시 시그니처에 포함조차 되지 않는다. 즉 "동일 구성"이라는 요구에 프리뷰는 포함될 수 없다. 보상 픽은 구매 즉시 `apply_choice`가 돌고 화면에 남으므로 "구매 후 갱신"이 자연히 성립한다. (b) 프리뷰 해석은 후속 트랙으로 분리한다.

**카드 영역 신규 작업은 0이다.** `draw_tower_reward_pick`(:457)은 이미 `RuntimePerkTraditionalChrome.draw_backdrop`, `_draw_card`, `_sync_choice_visual_selection`, `_choice_visual_blend`, `_draw_per_card_descriptions`를 퍽 선택 모달과 **같은 함수**로 통과한다. 카드 크롬을 새로 그리는 계획은 낭비다.

**편집 계약**

1. **호버는 2단 수정이다.** (a) `tower_reward_pick_state.gd:122 handle_input`에 `InputEventMouseMotion` 분기를 추가해 `get_card_index_at(motion.position, view_size)`가 0 이상이면 `selected_index`를 갱신한다. 호버 이펙트의 실체는 별도 hover 상태가 아니라 선택이 마우스를 따라가는 것이다(정본: `runtime_perk_modal_input.gd:138-150`). (b) S2에서 좌표 변환을 이미 정리했으므로 스크린 좌표 그대로 히트테스트한다.
2. **호버 포인터 채널을 분리한다.** `runtime_state.get_status_hover_mouse_pos()`를 재사용하지 않는다. 그 값은 퍽 모달 입력 경로가 채우는 뷰포트 좌표이고, 보상 픽 위에 외부 모달이 열리는 경로에서 오염 위험이 있다. `TowerRewardPickState` 전용 포인터 필드를 두고 `_draw_status_panel` / `_draw_stats_band`에 mouse_pos를 **인자로** 넘길 수 있게 오버로드한다. runtime_state에서 읽는 현행 경로는 퍽 모달 전용으로 유지한다.
3. **stats_band 플래그를 단일 소유 필드로 만든다.** `tower_reward_pick_state.gd:211 / :218 / :227` 세 곳이 전부 리터럴 false다. `TowerRewardPickState`의 필드 한 곳에 두고 세 호출부가 전부 그 값을 읽게 하며, 갱신은 draw가 아니라 `update()` 초입에서 한다(GRT-022).
4. **능력치 컨텍스트 주입 경로를 신설한다.** `_draw_stats_band`는 `get_stats_context_registry()`가 null이면 아무 로그 없이 return하고, 그 값을 채우는 `_capture_stats_context`는 `runtime_perk_state.update()` 안에서만 도는데 그 update는 퍽 모달/피드백/천사 모달 게이트 안에서만 호출된다. `runtime_perk_state`에 공개 캡처 진입점을 추가해 보상 픽 `update(delta)`에서 부른다. `_stats_context_owner`가 어디서도 지워지지 않으므로 **부정 레그가 필수다**: 그 전투에서 퍽 선택을 한 번도 열지 않은 상태로 보상 픽을 열어야 스테일 컨텍스트가 결함을 가리는 것을 막는다.
5. **`_refresh_stats_rows` 캐시 시그니처에 `physique_training`을 추가한다.** 수련 카드는 `runtime_skill_levels`가 아니라 `physique_training`을 바꾸는데 그 키가 시그니처에 없어 구매 후 최대 `STATS_BAND_REBUILD_INTERVAL_MSEC`(500ms) 동안 옛 값으로 굳는다(GRT-020 계열). 보상 픽 `spent_flags`도 함께 넣는다.
6. **레이아웃 충돌 3건을 해소한다.** 4카드 + 슬롯 원장 + 띠는 세로 예산상 들어가지만 보상 픽 전용 요소와 픽셀 단위로 충돌한다. (a) 카드 하단 가격 스트립(카드 아래 +3, 높이 24)이 원장과 14px 겹친다. 스트립을 카드 **내부** 하단으로 옮기거나 `TEMP_REWARD_PICK_PANEL_GAP_PX`를 레이아웃 빌더 인자로 받아 30 이상 확보한다. (b) 하단 상태 문구가 띠 내부에 찍힌다. 카드와 원장 사이 또는 계속하기 버튼 옆으로 이동한다. (c) 띠가 켜지면 `title_pos.y`가 `TITLE_MIN_CENTER_Y`로 바닥을 쳐 제목/잔액이 카드 위에 겹친다. 제목을 `_draw_title` 전통 현판으로 승격하면서 잔액을 제목 옆 가로 배치로 전환한다. 파티클(`_draw_particles`)도 함께 붙여 퍽 모달과 완전 동일화한다.
7. **`continue_rect`를 레이아웃에서 파생시킨다.** 현재 `(view_size.x-220)*0.5, view_size.y - 76` 고정이라 띠 바닥과 여유가 2px뿐이다. `layout.hint_pos` 또는 `stats_rect.end.y`에서 파생시키고, 파생 실패 시 띠를 끄는 fail-closed 규칙을 둔다. 히트테스트(:150 / :162)도 같은 파생값을 읽는다.
8. **드로우 경로 비용을 먼저 막는다.** `_draw_status_panel`은 `snapshot["perk_slot_status"]`가 비면 `catalog.get_perk_slot_status`로 폴백하는데 그 키는 퍽 선택 모달이 열릴 때만 채워지므로 보상 픽 중에는 항상 빈 dict이고 폴백이 매 드로우 프레임 돈다(GRT-032). 보상 픽 진입 시 `current_perk_slot_status`를 1회 채우고 구매 시 무효화한다. snapshot은 프레임당 1회만 만들어 원장과 띠가 공유하도록 `draw_tower_reward_pick` 시그니처를 확장한다(현재 5인자, catalog도 없다).
9. **슬롯 원장 호버는 인덱스가 아니라 rect와 퍽 키로 판정한다.** 융합 카드는 보유 퍽을 소비해 슬롯 배열을 압축하므로, 프레임 간 캐시한 인덱스가 남으면 가리킨 칸과 툴팁 내용이 갈라진다. 빈 칸에서 아이템이 생긴 경우와 배열 시프트로 다른 키가 밀려온 경우를 명시적으로 구분하고 후자에서는 획득 강조를 억제한다(GRT-030).

**씰 계약**

- `godot/tests/runtime_perk_choice_stats_band_smoke.gd`에 `view_size=(760,750)` 또는 실 뷰포트 기준 4카드 레그를 추가하고, **띠 예산 301 대 하한 269의 경계 자체를 단언한다.** 여유가 32px뿐이라 `panel_h` / `card_height` / `hint_gap` 상수가 조금만 움직여도 `stats_h`가 0.0으로 접히고 아무 오류 없이 띠만 사라진다(GRT-021).
- `godot/tests/tower_reward_pick_smoke.gd`에 호버 모션 레그(카드 상단 모서리)와 stats_band 플래그 3호출부 일치 단언, 퍽 선택 미개방 전투에서의 능력치 컨텍스트 부정 레그를 추가한다.
- 착지 후 BattlePerf로 `29b.victory_loot_boxes` 구간을 서브 라벨 단위로 재측정한다.

---

#### S4. 노드 이동 연출 전면 재구성 (요구 5) + 지도 비례화

**착지 순서를 3단으로 고정한다. 순서를 바꾸면 스스로 상시 드로우 비용을 만든다.**

**S4-a. 실 해상도 씰을 먼저 추가해 RED를 만든다**

현행 봉인은 `tower_ascent_map_overlay_render_smoke.gd:121`의 `Rect2(0,0,1280,800)` 하나뿐이고 크기 단언은 `art_rect.size >= 18.0` 하한과 `content_rect.has_point`뿐이다. Vulkan 캡처도 `GAME_SIZE 1280x800` SubViewport다. 이 해상도에서는 레이아웃 상한 4개가 **전부 미포화**라 결함이 원리적으로 관측되지 않는다.

- 1280x800: `outer_margin=19.2`(상한 28 미포화), `side_gutter=161.4`(상한 190 미포화), `lane_span=266.5`(상한 330 미포화), `art_size=27.3`(상한 34 미포화).
- 2020x1246(`project.godot` 실 뷰포트): 4개 **전부 포화**. `lane_span=330`, `art_size=34`. 화면 대비 노드 열 폭이 20.8%에서 16.3%로 오히려 줄고, 화면이 58% 커지는 동안 절대 폭은 24%만 커진다.
- 라이브 플레이필드는 `render_scale = min(2020/760, (1246-160)/750) = 1.448`, 게임 폭 1100.5px, x 459.8부터 1560.2까지다. 노드 열(x 845~1175)은 그 안에 완전히 들어간다. 이것이 "전투창 안에서만 작게"의 정확한 원인이다.

씰 레그: 2020x1246에서 `lane_span`과 `art_size`가 상한에 걸리지 않고 뷰포트 증가에 **비례**해 커지는지 비율로 단언한다. Vulkan 캡처도 실 해상도 1장 추가한다. 그리고 `docs/tower_live_feedback_r2_report.md`의 "전체화면 GREEN" 항목에 "1280x800 한정 검증" 정정 표기를 남겨 스테일 증거 재사용을 차단한다.

**S4-b. 딥카피 제거 후 비례화**

1. `build_render_model`이 매 드로우마다 `get_active_graph_phase()`를 부르고 그 구현이 `_graph_phases[i].duplicate(true)` + `_graph_nodes.duplicate(true)` + `_graph_edges.duplicate(true)`를 하며, 이어 `build_fullscreen_map_model`이 25노드를 또 `duplicate(true)` 한다. **모델을 페이즈 진입과 그래프 변경 시 1회만 빌드해 캐시하고 진행률만 프레임마다 갱신한다.** 드로우 경로에는 딥카피 없는 peek을 제공한다. 표시 시간을 몇 배로 늘리는 것이 S4-c의 목적이므로 순서를 바꾸면 GRT-032를 스스로 만든다.
2. `outer_margin` / `side_gutter` / `lane_span` / `art_size`의 절대 상한을 제거하고, 상단 82 / 높이 -154 절대 인셋을 뷰포트 비율로 전환한다. 값을 `tower_ascent_tuning.gd`의 TEMP 상수로 승격한다(현재 전체화면 경로는 튜닝 상수를 하나도 쓰지 않고 리터럴만 쓴다).
3. `source_x_ratio`를 실제 레인 min/max 기준 `inverse_lerp`로 정규화한다. 생성기 레인이 x=220/380/540이라 현재 -0.5부터 +0.5만 쓰므로 실제 사용 폭이 `lane_span`의 절반이다.
4. 확대는 크롭이나 스크롤이 아니라 **전 노드 동시 가시성을 유지하는 비례 재산출**이어야 한다. 정본 §3.1의 전도 공개 조항 때문이다.
5. 정본 §3.1에 "지도의 **내용**(노드 열 폭, 아이콘 크기, 상하 인셋)도 뷰포트에 비례한다. 절대 상한은 두지 않는다"를 명문화한다.

**S4-c. 6비트 전환 연출**

요구된 순서를 6구간으로 구현한다. 새 페이즈를 만들지 말고 `MAP_TRANSITION` 진척 곡선을 구간으로 재해석한다. 스냅샷 스키마(`map_transition_progress`)를 건드리지 않아 더 싸다. 시계는 `update_selective` 물리 틱에 둔다(72Hz 결정론 확보, 새 시계 인프라 불필요).

| 구간 | 상수 | 표면 |
| --- | --- | --- |
| 1. 전투 화면 암전 | `TEMP_MAP_TRANSITION_BATTLE_FADE_OUT_SEC = 0.25` | 플레이필드 **계속 그림** + 스크린 공간 검정 알파 0에서 1 |
| 2. 지도 등장 | `TEMP_MAP_TRANSITION_MAP_FADE_IN_SEC = 0.25` | 전체화면 지도 + 암전 1에서 0. 캐릭터는 출발 노드에 정지 |
| 3. 이동 | `TEMP_MAP_TRANSITION_TRAVEL_SEC = 1.60` | smoothstep 이징(가속 후 감속) |
| 4. 도착 소멸 | `TEMP_MAP_TRANSITION_ARRIVE_VANISH_SEC = 0.35` | 도착 노드에서 스케일 축소 + 알파 감소 |
| 5. 지도 암전 | `TEMP_MAP_TRANSITION_MAP_FADE_OUT_SEC = 0.28` | 암전 0에서 1 |
| 6. 도착 표면 등장 | 비전투 `TEMP_NODE_MODAL_FADE_IN_SEC = 0.25` / 전투는 **추가 페이드 없음** | 로딩 화면이 이미 소유 |

1. **구간 1의 게이트가 핵심 함정이다.** 현재 `battle_playfield_scene_drawer.gd:431-435`가 `MAP_TRANSITION`에서 조기 반환하므로 페이즈가 서는 순간 전투 화면이 즉시 사라진다. 그러면 페이드아웃할 대상이 없다. 게이트를 페이즈 이름 단독이 아니라 **진척 구간을 함께 보는 공유 헬퍼**로 바꾸고, `battle_scene_drawer.gd:260`의 형제 게이트와 반드시 락스텝으로 같은 헬퍼를 읽게 한다.
2. **페이드 rect는 반드시 스크린 공간 패스에 그린다.** `battle_scene_drawer.draw()` 말미, `_draw_tower_ascent_fullscreen_map` **이후**다. 플레이필드 패스에 그리면 필러와 레터박스가 안 덮여 페이드 중 크롬만 밝게 남는 반쪽 암전이 된다.
3. **페이드는 셰이더 없이 단일 알파 rect로 유지한다.** 셰이더를 쓰면 canvas 단위 rect를 framebuffer SCREEN_UV와 비교하는 순간 render_scale 1.448에서 하단과 우측이 잘린다(GRT-046).
4. **전투 도착 경로는 명시적으로 제외한다.** 이미 로딩 최소 2.20초 + 완료 페이드 0.2초 + 랜딩 인트로 페이드인 0.2초로 덮여 있어 여기에 또 얹으면 이중 암전으로 체감만 늘어진다. 구간 5까지만 두고 구간 6은 로딩 화면에 인계한다.
5. **`MAP_TRANSITION_SECONDS := 0.9`를 `tower_ascent_flow_state.gd:72`에서 `tower_ascent_tuning.gd`의 TEMP 상수군으로 이관한다.** 형제 튜닝이 전부 거기에 있는데 이것만 평범한 const로 남아 있다.
6. **SD 캐릭터 이동체를 배선한다.** 현행 이동체는 `draw_circle` 2줄이 전부다. **신규 아트를 생성하지 않는다.** 선택 캐릭터의 기존 전투 워킹 시트를 재사용한다. 이유는 (i) 이미 배틀 리소스로 프리웜되어 있어 미존재 경로 예약이 없고(GRT-004), (ii) `const preload` 확장이 없어 부팅 스텝 11 단일 프레임 스톨이 생기지 않는다(GRT-042). 렌더러는 registry 접근이 없으므로 `battle_scene_drawer`(registry 보유)에서 텍스처를 **인자로** 넘긴다. 진행 방향에 따른 좌우 facing과 걷기 프레임 시계를 이동 속도에 연동한다.
7. **좌우 반전을 UV 미러로 처리할 때 UV는 텍스처 크기로 [0,1] 정규화한다.** 픽셀 rect UV는 edge texel에 clamp되어 쿼드가 오류 한 줄 없이 사라진다(GRT-033). 정본 레시피는 `perk_fusion_cold_boot_cinematic.gd:607-635`다.
8. **도착 노드 승격 시점을 옮긴다.** `_resolve_route_target`이 전환 진입 시점에 `_current_node_id = target_id`를 확정해 이동 **내내** 목적지가 진사 테두리와 현재 링으로 그려진다. 이동 중에는 후보/선택 상태로만 그리고 `_complete_map_transition` 시점에 현재로 승격한다. "도착하면 소멸" 비트가 성립하려면 필수다.
9. M키 지도 개폐 페이드(`TEMP_MAP_OVERLAY_FADE_SEC = 0.18`)를 마지막에 추가한다. 같은 오너, 같은 rect다.
10. 페이드 오너는 **탑 전용 순수 시계 RefCounted**로 만든다(`main_menu_start_transition_state.gd` / `plaza_transition_state.gd` 형태). 범용 승격은 후속이다. 진척값을 QA 도구에서 주입 가능한 setter를 두어 0.0 / 0.5 / 1.0 다중 캡처가 가능하게 한다(정지 캡처로는 페이드 판정이 불가능하다).
11. 노드를 새로 만들 것이면 생성 시 `physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF`를 명시한다. 더 안전한 선택은 현행처럼 같은 캔버스의 즉시 `_draw`로 유지해 노드 생성 자체를 피하는 것이다(GRT-039).

**정본 개정**: 페이드 요구는 정본에도 사전 감사에도 0건이므로 무엇을 GREEN으로 볼 기준이 없다. §3.1에 페이드 계약(구간 분할, 각 구간 길이, 적용 범위 3곳, 전투 도착 제외 근거)을 먼저 추가한다.

---

#### S5. 각도 게이지 아트 교체 (요구 4)

**아트와 배선을 같은 커밋에서 랜딩한다.** 아트 파일이 없는 상태로 경로만 먼저 예약하면 ROUTE_AIM은 매 프레임 그려지는 표면이라 로더가 성공만 캐시하는 성질 때문에 없는 경로를 프레임마다 재stat하고, 경고 dedup 때문에 조용히 프레임 예산만 갉아먹는다(GRT-004).

**편집 계약**

1. 텍스처는 `const preload()`로 추가한다. 240x240 내외 규모에서는 `draw()` 시그니처 확장(호출부 2곳 + 스모크 3종 + QA 도구 2종)보다 비용이 낮다. 단 게이지 텍스처 경로를 전수 노출하는 함수(`get_route_aim_gauge_asset_paths()` 형태)를 만들고 `FileAccess.file_exists` 단언을 붙인다.
2. **`draw_set_transform` 항등 리셋을 절대 하지 않는다.** 게이지는 `battle_scene_drawer.gd:128`의 `draw_set_transform(game_offset + shake*scale, 0.0, scale)` 창 안에서 그려진다. `pillar_orb_chrome_drawer.gd:61-63` 방식을 복사하면 플레이필드 오프셋과 스케일이 지워져 이후 드로우 전체가 틀어진다. 그쪽은 필러 HUD가 변환 밖 패스라 성립하는 것이다.
3. 회전 쿼드는 `axis_x = Vector2(cos θ, sin θ)`, `axis_y = (-axis_x.y, axis_x.x)`로 4정점을 직접 계산하고 UV는 [0,1] 정규화하며 point와 UV corner 순서를 일치시킨다.
4. **`TextureRect`를 쓰지 않는다.** 58px 논리 반경 게이지를 TextureRect로 얹으면 기본 min-size가 240px 원본 크기로 `.size`를 되키운다(GRT-038). 노드가 필요하면 `Sprite2D`를 쓰되, 이 규모에서는 즉시 `_draw`가 정답이다.
5. **발광은 텍스처에 구워 넣고 MIX로 그린다.** `battle_scene_shell`은 `extends Node2D`의 즉시 `_draw`라 `canvas.material`을 ADD로 갈아끼우는 것은 no-op이고 아무 변화 없이 GREEN 보고가 나온다(GRT-056). 별도 CanvasItem FX 호스트를 붙이면 GRT-045(플레이필드 클립 호스트)와 GRT-039가 동시에 걸리므로 이 규모에서는 채택하지 않는다.
6. **평면 채움·아크·눈금을 텍스처 null 폴백 안쪽으로 이동시킨다.** 현행 팬은 `Color(CINNABAR_DARK, 0.42)`와 `Color(GOLD, 0.18)` 두 겹 `draw_colored_polygon`이다. 그대로 두고 그 위에 그림틀 텍스처를 얹으면 텍스처의 투명 여백 뒤로 평면 채움이 남아 정확한 부채꼴 상자가 드러난다(GRT-057).
7. 회전한 쿼드가 axis-aligned 클램프를 뚫고 플레이필드 밖으로 새지 않는지 확인한다. 게이지 원점은 플레이어 패들 근처 바닥이다(GRT-056 형제).

**씰 계약**

- `godot/tests/tower_ascent_route_serve_smoke.gd:994`의 `renderer_source.find("draw_colored_polygon") >= 0` 소스텍스트 씰을 **같은 커밋에서** 행위 씰로 이관한다. 이 스모크는 CI와 pre-push 두 리터럴 목록에 모두 등재되어 있어 개정 없이는 즉시 RED다.
- 이관 후 3레그: (a) 텍스처 경로 `file_exists`, (b) 실제 텍스처 draw 호출 도달, (c) 텍스처 null 폴백에서 절차 팬이 살아난다. 절차 팬을 폴백으로 남기면 `draw_colored_polygon` 문자열은 살아남아 기존 씰이 통과하지만 "텍스처가 실제로 쓰였는가"를 증명하지 못하므로 그대로 두면 공허 GREEN이다.
- 픽셀 증거: `godot/tools/run_tower_route_serve_owner_meta_visual_qa.ps1` 재실행. 신규 QA 래퍼는 불필요하다. 어두운 스테이지 배경 레그와 밝은 배경 레그를 각각 캡처해 비교하고, 판정은 약한 임계가 아니라 강한 임계 픽셀 카운트로 한다.

**정본 개정 선행**: `docs/tower_live_feedback_r3_goal.md` §1.5가 "게이지는 절차 `_draw`로 그린다"를 명시 지시했고 그 결과가 현행 구현과 소스텍스트 씰이다. `docs/tower_ascent_run_map_plan.md` §3.2에 **명시적 supersede 기록**을 남긴다(R3 §1.5를 대체함을 문장으로). 기록 없이 뒤집으면 다음 감사에서 되돌려지고 씰이 함께 왕복한다.

---

#### 신규 TEMP 상수 (전부 `godot/scripts/tower_ascent/tower_ascent_tuning.gd`, 보상 픽 전용 2개는 `tower_reward_pick_state.gd`)

| 상수 | 값 | 용도 |
| --- | --- | --- |
| `TEMP_ROUTE_AIM_ENTRY_ARM_SECONDS` | 0.35 | 경로 서브 진입 발사 봉인 창. 2.4초 스윕의 단순 유리수 배수 금지 |
| `TEMP_REWARD_PICK_EMPTY_BOARD_HOLD_SEC` | 0.60 | 흡수 종료 후 빈 보드 유지 |
| `TEMP_REWARD_PICK_PANEL_GAP_PX` | 32 | 가격 스트립과 슬롯 원장 충돌 해소 |
| `TEMP_MAP_TRANSITION_BATTLE_FADE_OUT_SEC` | 0.25 | 구간 1 |
| `TEMP_MAP_TRANSITION_MAP_FADE_IN_SEC` | 0.25 | 구간 2 |
| `TEMP_MAP_TRANSITION_TRAVEL_SEC` | 1.60 | 구간 3. 기존 0.9 이관 후 상향 |
| `TEMP_MAP_TRANSITION_ARRIVE_VANISH_SEC` | 0.35 | 구간 4 |
| `TEMP_MAP_TRANSITION_MAP_FADE_OUT_SEC` | 0.28 | 구간 5 |
| `TEMP_NODE_MODAL_FADE_IN_SEC` | 0.25 | 구간 6, 비전투 전용 |
| `TEMP_MAP_OVERLAY_FADE_SEC` | 0.18 | M키 지도 개폐 |
| `TEMP_MAP_OUTER_MARGIN_RATIO` | 0.024 | 상한 제거 |
| `TEMP_MAP_SIDE_GUTTER_RATIO` | 0.130 | 상한 제거 |
| `TEMP_MAP_LANE_SPAN_RATIO` | 0.290 | 상한 제거 |
| `TEMP_MAP_ART_SIZE_RATIO` | 0.720 | 상한 제거 |
| `TEMP_MAP_CONTENT_TOP_RATIO` | 0.1025 | 82/800 비율화 |
| `TEMP_MAP_CONTENT_BOTTOM_RATIO` | 0.1925 | 154/800 비율화 |
| `TEMP_ROUTE_AIM_GAUGE_PIVOT_RATIO` | (0.5, 0.875) | 게이지 텍스처 원점 |
| `TEMP_ROUTE_AIM_GAUGE_TEXTURE_RADIUS_PX` | 88.0 | 텍스처 내 논리 반경 대응 픽셀. 배율 = 게이지 반경 / 88 |
| `TEMP_ROUTE_AIM_ARROW_ORBIT_RATIO` | 0.72 | 화살표 중심의 원점 대비 거리 비율 |

---

### 2. 후속으로 미룰 항목과 근거

| 항목 | 근거 |
| --- | --- |
| **A의 (b) 프리뷰 해석**(호버/선택만 해도 예상치 표시) | 저장소에 프리뷰 리졸버가 0건이고, 가상 적용 계산기 + 행 값 델타 표시 계약 + 취소 경로가 전부 신규다. 반경이 (a)의 수십 배이며 그 설계가 능력치 띠 행 지오메트리와 캐시 시그니처를 다시 정의하므로, (a)로 먼저 랜딩한 배선이 통째로 재작업된다. 요구 원문("기존 화면과 동일 구성")에 기존에 없는 기능은 포함되지 않는다. |
| **노드 kind 5종 전용 비트맵 배경** | S2에서 절차적 배경으로 요구를 충족한다. 비트맵으로 가면 (i) VRAM 압축 임포트 규격과 문서화된 크기 상한 결정, (ii) `get_node_art_asset_paths()`를 실제 소비자가 있는 스텝형 프리웜(`prewarm_*_step` bool 반환)으로 승격, (iii) 아트 생성 자체가 선행이다. 현행 8장이 이미 `const preload`라 여기에 5종을 더하면 부팅 스텝 11(`prewarm_tower_ascent_muhon_collection`) 단일 프레임이 1초+ 스톨로 부푼다(GRT-042). |
| **지도 이동 전용 SD 시트 신규 작화** | S4에서 기존 전투 워킹 시트 재사용으로 요구를 충족한다. 전용 시트는 신규 24장 계열 작업이고 세린 SD 재작화 트랙과 계열 통일을 맞춰야 한다. |
| **10층·11층 층 배경 통일** | 1층부터 9층까지는 층당 단일 stage라 "층별 3종 한 배경"이 **이미 구조적으로 성립**한다. 깨지는 것은 10층 셸 3종(stage 6/7/8)과 11층 4천왕(stage 4/5/6/7)뿐인데, 이 해소는 정본 §3.3 문구("전투 배경은 그 보스의 원 스테이지 배경")와 정면 충돌하므로 사용자 확정이 선행이다. 게다가 11층은 `boss_slot_id`가 `floor_11_four_kings_group`으로 덮이는데 이 id가 `FLOOR_BOSS_SLOTS`에 없어 도착 시 `push_error` 후 플로우가 종료된다. 배경 계약을 지금 정해도 **검증이 불가능**하다. 표준 런에서는 9층 초과 행이 `route_locked: true`, `content_state: "registry_only"`라 아직 도달하지도 않는다. |
| **동일 stage 전환 2.20초 로딩 단축 경로** | `_clear_owner_weather`, `weather_event_state.reset()`, `stage_clear_result_screen.prepare_stage_start`가 로딩 경로에 묶여 있어 어느 것이 라운드 경계 계약인지 가리는 별도 감사가 선행이다. 잘못 생략하면 GRT-034류 루프 오디오와 상태 누수가 난다. |
| **페이드 오너 범용 승격** | 이관 대상이 `stage_landing_intro._draw_fade_in`, stage1 프롤로그 `_fade_cover`, stage7 `_screen_black`, `main_menu_start_transition_state`, `plaza_transition_state` 5곳이라 프롤로그·영상·메인메뉴·광장까지 회귀 반경이 확대된다. 그중 하나만 깨져도 탑 요구 6건 전체가 커밋 불가로 묶인다. |
| **기존 무압축 배경 텍스처(compress/mode=0) 소급 VRAM 압축 전환** | 재임포트는 에디터 포커스 경로이고 headless `--import`는 금지다. 별개 트랙. |
| **사문 경로 정리**(`_draw_map_surface`, `_draw_map_transition`, `MAP_RECT`, `TEMP_MAP_OVERLAY_*` 6개) | 프로덕션 도달 불가지만 `TEMP_MAP_OVERLAY_*`의 유일한 소비자라 제거하면 상수 정리가 딸려 온다. S4-b에서 전체화면 경로가 TEMP를 쓰게 되면 그때 함께 정리한다. 이번에는 도달 불가 주석만 남긴다. |
| **분할 필러 오버레이 패스와 전체화면 지도의 겹침** | `battle_spawn_overlay_draw_coordinator`가 `draw_battle_pillar_overlay`를 한 번 더 호출하는 프레임이 탑 전환 중 실제로 발생하는지 미측정이다. 탑 전환 중에는 스폰 인트로가 비활성일 가능성이 높다. 실측 후 GRT-023/028 형태의 형제 진입점 누락 감사 항목으로 등재한다. |
| **REVEAL 무한 대기 상한(자동 absorb)** | S0에서 "입력 전용" 계약으로 확정했으므로 도입하지 않는다. 안내 문구 추가 후에도 사용자가 막힌다고 보고하면 그때 재개한다. |

---

### 3. 아트 브리프 (각도 게이지)

두 파일로 분리한다. 부채꼴 프레임은 정지, 화살표는 회전이다. 회전체를 분리해야 회전 중심 관리가 쉽고 GRT-033 UV 사고 반경이 줄어든다.

#### 공통 규격

- 형식: 알파 PNG, 무손실(`compress/mode=0`, `vram_texture: false`), `mipmaps/generate=false`, `process/fix_alpha_border=true`, `process/size_limit=0`. HUD 크롬 계열 관례와 동일하다.
- 네이밍: `<subject>_imagegen_v<N>.png`. 경로 `godot/assets/sprites/orbs/` 또는 신설 `godot/assets/sprites/tower/`.
- 배경 완전 투명. 반투명 그라디언트가 캔버스 가장자리에 닿지 않게 한다. 알파 박스와 네 모서리를 어두운 프리뷰와 밝은 프리뷰 양쪽에서 검수한다.
- **발광은 텍스처에 구워 넣는다.** ADD 블렌드를 전제하지 않는다. 런타임은 MIX 하나뿐이다.
- **배경 전제**: 이 게이지는 어둡고 층마다 다른 스테이지 전투 배경 위에 얹힌다(플레이필드 드로우 단계 35). 전체화면 지도의 밝은 한지(PAPER `#f1dfb8`) 위가 **아니다**. 지도 노드 아트 레시피를 이식하지 말 것. 어두운 외곽 대비 + 밝은 코어로 자체 대비를 공급해야 한다.

#### 파일 1. 부채꼴 프레임 `route_aim_gauge_fan_imagegen_v1.png`

- **캔버스**: 256 x 192.
- **원점(피벗)**: 이미지 좌표 (128, 168). 정규화 비율 (0.5, 0.875). 이 점이 런타임 게이지 원점(플레이어 패들 근처)과 일치한다.
- **논리 반경 대응**: 원점에서 88px. 런타임 배율은 `TEMP_ROUTE_AIM_GAUGE_RADIUS / 88`.
- **부채꼴 범위**: 원점 기준 수직 위 방향을 0도로 하여 좌우 각 55도, 총 110도. 좌우 극단점은 (56, 118)과 (200, 118), 정상부는 (128, 80) 부근. 좌우 여백 56px, 상단 여백 80px은 전부 광대와 베벨용이며 잘리면 안 된다.
- **실루엣**: 한국 전통 방여도의 나침 눈금판을 부채꼴로 자른 형태. 바깥 호는 두꺼운 먹빛 테두리 띠, 그 안쪽에 얇은 금선 이중 아크, 부채꼴 안쪽 면은 아래(원점)로 갈수록 짙어지는 진사 그라디언트. 원점 근처는 거의 불투명, 호 근처는 반투명으로 뒤 배경이 비쳐야 조준 대상이 가려지지 않는다.
- **눈금**: 총 7개. 중앙 0도와 좌우 각 3개(±18.3도, ±36.7도, ±55도 등분). 중앙 눈금만 굵고 길게, 나머지는 짧은 금색 침. 숫자는 넣지 않는다.
- **팔레트**: 바깥 테두리 `#30271f`(INK), 테두리 안쪽 베벨 하이라이트 `#665343`(INK_SOFT), 부채 채움 `#63241f`(CINNABAR_DARK)에서 `#9e352d`(CINNABAR)로, 아크와 눈금 `#bd8c35`(GOLD), 중앙 눈금 하이라이트 `#ffcf59`.
- **투명도 설계**: 원점 반경 20px 이내 알파 0.85, 호 근처 알파 0.30까지 감쇠. 테두리 띠와 눈금은 알파 0.95 이상으로 어떤 배경 위에서도 실루엣이 읽혀야 한다.
- **광대**: 테두리 바깥으로 알파 0.03~0.06의 넓은 금색 헤일로를 20~40px 폭으로 흘린다. 닫힌 둘레 선 하나로 끝내지 말고 채움 다겹으로 만든다.
- **회전 축**: 없다. 이 텍스처는 회전하지 않는다.

#### 파일 2. 조준 화살표 `route_aim_gauge_arrow_imagegen_v1.png`

- **캔버스**: 128 x 128 정사각.
- **원점(피벗)**: 이미지 정중앙 (64, 64). 런타임은 이 중심을 원점에서 `TEMP_ROUTE_AIM_ARROW_ORBIT_RATIO * 게이지 반경` 거리에 배치하고 조준 방향으로 회전시킨다.
- **방향 규약**: 이미지 좌표에서 **위(-Y)를 가리키게** 그린다. 회전각 0도가 수직 위다.
- **실루엣**: 화살촉이 위, 짧은 축이 아래. 전체 길이는 캔버스 세로의 약 70%(90px), 폭은 약 34px. 촉은 날카로운 이등변, 축은 촉 폭의 3분의 1로 좁아지는 침 형태. 축 끝(아래)은 뭉툭하게 마감해 회전 중심이 시각적으로 읽히게 한다.
- **팔레트**: 촉 코어 `#fff1a6`(가장 밝은 부분, 알파 1.0), 촉 중간 `#ffcf59`, 축 `#bd8c35`, 외곽 1px 먹선 `#30271f`. 어두운 외곽선이 밝은 코어를 감싸는 구조라야 어떤 스테이지 배경 위에서도 뜬다.
- **광대**: 화살촉 주변으로 알파 0.05~0.10의 금색 번짐을 반경 24px까지. 축 주변은 알파 0.03 이하.
- **여백**: 상하좌우 각 19px 이상 남긴다. 회전 시 대각선 방향으로 잘리지 않아야 한다. 대각선 반경이 캔버스 절반(64px)을 넘지 않도록 화살표 최장 반경을 60px 이내로 유지한다.
- **회전 축**: 이미지 정중앙 (64, 64). 이 점이 화살표의 기하 중심이며 회전 시 좌우 균형이 맞아야 한다.

#### 폴백 계약

두 텍스처 중 하나라도 null이면 현행 절차 팬(`draw_colored_polygon` 두 겹 + `draw_arc` 두 겹 + 눈금 7개)이 그대로 살아난다. 텍스처가 있으면 절차 팬은 **그리지 않는다**. 텍스처 뒤에 평면 채움을 남기면 그림틀 투명 여백을 통해 정확한 부채꼴 상자가 드러난다.

---

### 4. 함정 예방 문장 (지시문 §2에 넣을 것)

아래 문장은 그대로 지시문 §2에 붙여넣는다.

1. **그린 자리와 클릭 자리를 절대 분리하지 마라.** 레이아웃 플래그(`stats_band_requested`)는 소유 필드 한 곳에 두고 `build_view_model` / `get_card_rects` / `get_card_index_at` 세 호출부가 전부 그 값을 읽어라. 갱신은 draw가 아니라 `update()` 초입에서 하라. 반증 씰은 카드 중심점이 아니라 **상단 모서리** 좌표로 짜라. 4카드 750px 기준 밀림이 139px이고 카드 높이 절반이 96px이라, 중심점 판정은 우연히 통과하거나 우연히 다른 카드에 걸려 변별력이 0이다. (GRT-022)
2. **arm 게이트는 입력을 미루지 않고 버린다.** `_read_player_input_snapshot()`을 게이트 **위**에 두어 arm 창 동안에도 매 프레임 스냅샷을 소비해 홀드된 에지를 흡수·폐기하라. 보류 후 만료 시 발사하는 큐 방식은 v1.7 자동 서브 금지를 실제로 위반한다. (GRT-050)
3. **arm 게이트를 `update()` 초입이나 대기 분기 앞의 조기 반환으로 만들지 마라.** 게이트는 좌클릭 조건 단 한 줄에만 건다. 진자(`_update_aim_oscillator`)와 좌우 이동(`_update_player_route_movement`)이 함께 얼면 정본이 금지한 정지 조준과 이동 동결을 동시에 만든다.
4. **폴링 리더의 에지는 페이즈 경계에서 재발행된다.** `mouse_left_just_pressed`는 `Input.is_mouse_button_pressed()` 폴링과 `_last_mouse_left_pressed` 상태 전이로 합성되므로, 이전 화면이 이미 소비한 물리 클릭이 다음 화면 첫 프레임의 새 에지가 된다. 씰은 스냅샷 딕셔너리 대입 페이크가 아니라 **직전 프레임 false + 이번 프레임 눌림 유지**를 재현하는 상태형 픽스처로 짜라. (GRT-019 역변종)
5. **아트 파일과 배선은 같은 슬라이스에서 랜딩하라.** 매 프레임 그려지는 표면에 미존재 경로를 예약하면 로더가 성공만 캐시하므로 프레임마다 파일시스템을 재stat하고, 경고 dedup 때문에 조용하다. 신규 텍스처는 전수 노출 함수 + `FileAccess.file_exists` 단언으로 씰링하고 그 씰을 `godot-ci.yml`과 `run_pre_push_checks.ps1` 두 목록에 **동시** 등재하라. 나이틀리 전용으로 남기면 focused 레인에서는 보호가 작동하지 않는다. (GRT-004)
6. **노드 배경과 SD 시트를 `const preload`로 추가하지 마라.** `tower_ascent_flow_state.gd`가 렌더러를 `const preload`하므로 부팅 프리웜 스텝 11이 flow_owner를 인스턴스화하는 **단일 프레임**에 전부 디코드·업로드된다. 대신 스텝형 프리웜(`prewarm_*_step` bool 반환)으로 승격해 등재하고, 착지 후 콜드 첫 진입 시간을 측정하라. 반대로 첫 드로우 lazy 로드로 도망가면 GRT-003으로 옮겨갈 뿐이고, 하필 그 프레임은 물리가 게이트로 막혀 다른 일이 없어 100ms+ 튐이 그대로 체감된다. (GRT-042 / GRT-003)
7. **새 전체화면 표면은 형제의 뷰포트 우선 계약을 상속하지 않는다.** `canvas.get_viewport_rect().size`를 1순위로 쓰고 context 값은 폴백으로만 두며 tree 밖 호출은 `is_inside_tree()`로 막아라. `view_size`나 game size(760x750)로 폴백하면 2020x1246 실 창에서 좌상단 일부만 덮고 나머지는 라이브 전투 화면으로 남는다. 이것이 이미 보고된 "달지가 옆에 그대로 있다"의 재발 형태다. (GRT-044)
8. **회전 쿼드의 UV는 텍스처 크기로 [0,1] 정규화하라.** 픽셀 rect를 UV로 넘기면 edge texel에 clamp되어 쿼드가 오류 한 줄 없이 사라진다. 정본 레시피는 `perk_fusion_cold_boot_cinematic.gd:607-635`이고 point 순서와 UV corner 순서를 일치시켜라. (GRT-033)
9. **플레이필드 변환 창 안에서 `draw_set_transform`을 항등으로 리셋하지 마라.** `pillar_orb_chrome_drawer` 방식은 필러 HUD가 변환 밖 패스라 성립하는 것이다. 게이지는 `battle_scene_drawer.gd:128`의 변환 창 안이라 항등 리셋 시 이후 드로우 전체가 틀어진다.
10. **즉시 `_draw` 안에서 `canvas.material`을 ADD로 교체하는 것은 no-op이다.** 발광은 텍스처에 구워 넣고 MIX로 그려라. 별도 CanvasItem FX 호스트를 붙이면 GRT-045와 GRT-039가 동시에 켜진다. (GRT-056)
11. **58px 논리 반경 게이지를 `TextureRect`로 얹지 마라.** 기본 min-size가 240px 원본 크기로 `.size`를 되키워 화면에 원본 픽셀 크기로 렌더된다. 노드가 필요하면 `Sprite2D`를 쓰되 이 규모에서는 즉시 `_draw`가 정답이다. (GRT-038)
12. **표면마다 클립 소속을 먼저 문서로 확정하라.** 페이드와 노드 배경은 필러와 레터박스까지 덮어야 하므로 클립 없는 화면공간 패스에 둔다. 760x750 클립 호스트에 넣으면 필러만 밝게 남는 반쪽 암전이 된다. 페이드는 셰이더 없이 단일 알파 rect로 유지하라. 셰이더를 쓰면 canvas 단위 rect와 framebuffer SCREEN_UV 비교가 render_scale 1.448에서 하단과 우측을 자른다. (GRT-045 / GRT-046)
13. **정지 프레임 전환에서 새 노드를 만들면 스폰 글라이드가 유령으로 보인다.** 이산 재배치형 오버레이 호스트는 생성 시 `physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF`를 명시하라. 더 안전한 선택은 전부 같은 캔버스의 즉시 `_draw`로 유지해 노드 생성 자체를 피하는 것이다. (GRT-039)
14. **새 물리차단 모달 진입점은 형제 모달의 개폐 훅을 상속하지 않는다.** 승리 전리품 분기는 `enter_modal_block` 팬아웃 밖이라 액티브 아이템 쿨다운 pause와 `GameplayLoopAudioCleanup.stop_all`이 걸리지 않는다. 시네마틱 개폐와 자동 finish 양쪽에서 pause가 두 번 걸리거나 leave가 누락되지 않는지 실 진입점 관통 반증 레그를 두어라. 신규 루프 오디오는 `gameplay_loop_audio_cleanup.gd` STOP_METHODS 등재를 배선과 같은 커밋에서 처리하라. (GRT-058 / GRT-034)
15. **드로우 경로에서 카탈로그 조회와 딥카피를 하지 마라.** 보상 픽은 `perk_slot_status`가 항상 빈 dict라 폴백이 매 프레임 돌고, 지도는 매 드로우마다 그래프를 3회 + 노드 25개를 재복사한다. 표시 시간을 늘리기 **전에** 캐시로 분리하라. 착지 후 BattlePerf 서브 라벨로 귀속을 확인하라. (GRT-032)
16. **띠 예산 경계 자체를 단언하라.** 760x750 4카드에서 여유가 32px(예산 301 대 하한 269)뿐이라 인접 상수가 조금만 움직여도 띠가 오류 없이 사라진다. (GRT-021)
17. **슬롯 인덱스는 안정된 정체성이 아니다.** 융합이 보유 퍽을 소비해 배열을 압축하므로 호버는 rect와 퍽 키로 판정하고, 빈 칸에서 아이템이 생긴 경우와 다른 키가 밀려온 경우를 구분해 후자에서는 획득 강조를 억제하라. (GRT-030)
18. **통과 판정은 마지막 `ok`가 아니라 배치 출력의 종단선 `All Godot smoke tests passed.`와 SCRIPT ERROR 0건이다.** 공유 목록에 레그를 삽입할 때 형제 씰의 절대 인덱스 가정을 깨지 않는지 확인하라. (GRT-035 / GRT-040)
19. **픽스처가 결함을 가린다.** FakeRegistry에 키가 없어 라우트가 null로 빠지면 단언은 GREEN인데 실전 경로는 죽어 있다. Fake를 채우고 반드시 반전 대조군을 함께 두어라.
20. **소스 텍스트 씰을 개정할 때는 행위 씰로 옮겨라.** 문자열만 살려 두면 "그 코드가 실제로 실행되는가"를 증명하지 못해 공허 GREEN이 된다.
21. **스테일 캡처를 증거로 재사용하지 마라.** `godot/.godot/codex_captures/tower_ascent_phase_b/map_transition.png`(08-18 05:22)는 전체화면 커밋(09:55)보다 이른 시각의 플레이필드 캡처다. r2 보고의 전체화면 GREEN도 1280x800 한정이다. 두 증거에 정정 표기를 남겨라.
22. **좌표 수치 정정.** 라이브 2020x1246에서 `render_scale`은 1.448이고 게임 폭은 1100.5px, x 459.8부터 1560.2까지다. 1.661 / 1262px / x 379~1641은 세로 마진 0인 모바일 경로에서만 나오는 값이며 사전 실사에 오기가 있다. 씰에 하드코딩하지 말고 `build_game_layout`을 실제 호출해 얻은 값으로 단언하라.
23. **기록된 설계 결정을 확인 없이 뒤집지 마라.** 게이지 렌더 방식(R3 §1.5의 절차 `_draw` 지시)과 §3.14 미니창 표현은 코드 착수 **전에** 정본에 supersede 기록을 남긴다. 페이드 요구는 정본에 0건이라 GREEN 기준 자체가 없으므로 계약을 먼저 등재하라.
24. **워크트리 규율.** `git reset` / `checkout` / `clean` / `stash` / 광범위 restore를 검증 지름길로 쓰지 마라. RED 반증은 제자리 토글, 픽스처, 임시 패치로 만든다. 스테이징은 정확한 경로와 헝크만, `git add -A` 금지. 슬라이스마다 커밋 1개다.

---

### 5. 사용자 확답 필요

착수 전에 답이 필요한 것은 3건이다. 나머지는 실사 근거로 직접 판정해 §1에 반영했다.

1. **10층과 11층의 층 배경 계약** (요구 6의 보스 측면). 1층부터 9층까지는 층당 단일 stage라 "층별 3종 한 배경"이 이미 성립한다. 10층 셸 3종이 stage 6/7/8, 11층 4천왕이 stage 4/5/6/7로 갈려 여기서만 깨진다. 선택지는 (a) standin stage를 층 단위로 통일한다, (b) standin stage와 분리한 명시적 "층 배경" 테이블을 신설한다, (c) 정본 §3.3 문구("전투 배경은 그 보스의 원 스테이지 배경")를 유지하고 10·11층에서는 배경이 갈리는 것을 수용한다. (b)를 고르면 §3.3 개정이 동반된다. **이번 슬라이스에는 넣지 않지만 후속 착수 전에 필요하다.**

2. **연출 총 길이 체감**. 비전투 노드 이동 1회가 현행 0.9초에서 약 2.73초(0.25 + 0.25 + 1.60 + 0.35 + 0.28)로 늘어난다. 한 층에 노드를 여러 개 지나므로 누적 체감이 커진다. 전부 TEMP라 즉시 조정 가능하지만, 1.60초 이동이 "유유히"에 맞는지 첫 라이브 체감에서 판정해 주기 바란다. 짧게 원하면 이동 1.10초 + 페이드 각 0.18초로 총 2.0초 아래로 내릴 수 있다.

3. **자동 전환 범위** (요구 3). 요구 원문대로 "4장 전량 구매"만 자동 전환으로 구현했다. 그런데 정본 §3.6이 확정한 "구매 상한 = 무혼 잔고" 때문에 막다른 상태가 두 가지다. (A) 4장 전부 구매, (B) 무혼 잔고가 남은 최저가 카드보다 적어 아무것도 살 수 없음. B에 빠진 플레이어는 여전히 계속하기를 눌러야 하므로 "왜 어떤 때는 저절로 넘어가고 어떤 때는 안 넘어가는가"라는 학습 불가능한 규칙이 된다. 선택지는 (a) 요구대로 전량 구매만, (b) 구매 가능 카드가 0장인 모든 상태에서 자동 전환. (b)를 고르면 판정 술어를 `spent_flags` 전량 true가 아니라 "미구매 카드 중 `reward_pick_cost <= 무혼 잔고`인 것이 0장"으로 바꾼다. 답이 없으면 (a)로 착지한다.

**참고로 다음 3건은 질문하지 않고 판정했다.** 필요하면 뒤집어 달라.

- 좌표계는 (A)안 스크린 공간 승격으로 확정. 요구 1의 "동일 구성"이 픽셀 동급을 뜻하고, 현재 상태는 카드는 66% 작고 능력치 행은 1.448배 크게 나오는 자기모순이기 때문이다.
- A의 "실시간 반영"은 (a) 구매 후 즉시 갱신으로 확정. 기존 퍽 선택 화면에 프리뷰가 존재하지 않으므로 "동일 구성"에 포함될 수 없다.
- 절세무공 REVEAL은 자동 진행 상한을 두지 않고 입력 전용 계약을 유지하며, 대신 "클릭해 계속" 안내를 추가한다.

---

### 6. 기각한 지적과 이유

| 지적 | 판정 | 근거 |
| --- | --- | --- |
| 렌즈 1: "영역 E는 이번 목표에서 제외하라" | **부분 기각** | E가 여는 6개 계약 중 이번에 필요한 것은 (2) NODE_MODAL 화면공간 승격과 (3) 입력 좌표 이전 둘뿐이고, 이 둘은 좌표계 승격 슬라이스가 어차피 같은 함수를 건드리므로 추가 반경이 사실상 0이다. 나머지 4개(노드 배경 소유자 신설, 층 배경 테이블, 프리웜 스텝 계약, 11층 인카운터)는 **절차적 배경을 쓰면 전부 소멸하거나 후속으로 분리된다.** 사용자 요구 6은 "비전투 노드는 전용 배경"인데, `_draw_immortal_realm_backdrop`와 `PlazaInteriorRoomRenderer.draw_room`이 이미 텍스처 0장 절차적 선례이므로 신규 에셋·신규 소유자 없이 요구를 충족할 수 있다. 요구를 통째로 미루는 것은 근거가 없다. |
| 렌즈 1: "D-2 SD 이동 마커는 에셋 축이므로 제외" | **기각** | 실사 D P1의 근거는 "아트 신규 필요 여부는 사용자 확정 필요"이지 "아트가 없다"가 아니다. 선택 캐릭터의 전투 워킹 시트는 이미 존재하고 배틀 리소스로 프리웜되어 있으므로 재사용하면 신규 에셋 0건이고 GRT-004의 미존재 경로 예약 조건 자체가 성립하지 않는다. 요구 5는 "SD 캐릭터 가감속 이동"이 핵심이고 원 2개로는 요구를 충족할 수 없다. 전용 지도 워크 시트 신규 작화만 후속으로 뺀다. |
| 렌즈 1 / 렌즈 2: "좌표계 결정은 사용자 확정 선행" | **기각(직접 판정)** | 사용자가 이미 답했다. 요구 1의 원문이 "기존 퍽 선택 화면과 동일 구성"이고, 실사 A P1이 확인한 현행 상태는 카드가 퍽 모달의 66% 크기인데 능력치 띠 행 지오메트리는 절대 px 하드코딩이라 1.448배 확대되어 오히려 더 크고 굵게 나오는 자기모순이다. "동일"을 만족하는 해는 (A) 하나뿐이다. 질문으로 되돌리면 슬라이스가 무한정 대기한다. |
| 렌즈 1 P2: "A의 실시간 반영이 (b) 프리뷰 해석이면 신규 시스템이므로 사용자 확정" | **기각(직접 판정)** | 요구가 "기존 퍽 선택 화면과 동일 구성"이므로, 기존 화면에 존재하지 않는 프리뷰는 정의상 "동일 구성"에 포함될 수 없다. 선택 인덱스가 캐시 시그니처에 포함조차 되지 않는다는 코드 사실이 이를 확정한다. (b)는 별도 신규 기능 요청으로 분리한다. |
| 렌즈 2 P1: "요구 6은 정본 §3.14의 별도 씬 금지와 정면 충돌한다" | **부분 기각** | §3.14가 금지한 것은 **별도 씬 파일**(상점 씬, 샘터 씬)이며 그 취지는 Peglin 문법(모든 노드가 전투 씬을 경유)이다. 제안한 구조는 씬 파일을 하나도 만들지 않고 기존 전투 씬 드로어의 스크린 공간 패스에 페이즈 이름 하나를 추가하는 것이라 조항 취지가 그대로 보존된다. 실제로 개정이 필요한 것은 "미니창"이라는 **표현 한 단어**뿐이고, 이는 문구 개정으로 처리한다. 사용자 확답 대기 항목이 아니다. |
| 렌즈 2 P2: "arm 만료 시 첫 발사 각도가 상수가 되므로 게임플레이 RNG 시작 위상이 필요" | **부분 기각 / 유예** | 지적 자체는 유효하다. 다만 처방으로 제시된 (b) 게임플레이 RNG 위상 굴림은 RNG 스트림을 바꿔 기존 결정성 씰의 왕복을 유발하고 차등 시드 테스트를 동반한다. 이번에는 (a) `begin()`의 위상 리셋 제거(캐리오버)로 **고정 앵커를 제거**한다. 이것으로 진입 각도가 직전 체류 시간에 의존하게 되어 상수 앵커는 사라진다. 잔여 결정성(플레이어가 항상 같은 각도에서 쏘면 다음 진입 위상도 같아진다)은 라이브 체감 후 후속으로 판단한다. `TEMP_ROUTE_AIM_ENTRY_ARM_SECONDS`를 2.4초의 단순 유리수 배수로 두지 않는 처방은 그대로 채택했다. |
| 실사 B: "REVEAL 무한 대기에 상한(N초 후 자동 absorb)을 둘지 결정 필요" | **기각(직접 판정)** | 입력 도달이 복구되면 무한 대기 시나리오 자체가 소멸한다. 자동 absorb는 신화 획득이라는 최고 희소도 연출의 클라이맥스를 플레이어 의지 없이 소비시키는 부작용이 더 크다. 대신 실사 B P3이 지적한 안내 문구 부재(`click` / `클릭` / `continue` / `hint` 4개 검색어 0건)를 이번에 해소한다. 무장 전 0.5초 구간에는 표시하지 않아 "눌렀는데 무시됐다"는 오해도 함께 막는다. |
| 실사 D: "라이브 render_scale 1.661, 플레이필드 폭 1262px, x 379~1641" | **기각(수치 오류)** | `battle_view_layout.gd:828-852`를 전개하면 데스크톱 경로에서 `render_margin_y = max(floor(1246*0.065), 30) = 80`이므로 `render_scale = min(2020/760, (1246-160)/750) = 1.448`, 게임 폭 1100.5px, x 459.8~1560.2이다. 1.661은 세로 마진 0인 모바일 경로 값이다. 같은 실사 문서의 영역 A는 1.448을 쓰고 있어 내부 불일치이기도 하다. 결론(노드 열이 플레이필드 안에 들어간다)은 두 수치 모두에서 성립하므로 판정은 유지하되, 236px 오차가 후속 좌표 설계에 전파되지 않도록 수치를 정정한다. |
| 실사 A: "보상 픽 카드 렌더러를 퍽 선택 화면 수준으로 재작성해야 한다"는 통념 | **기각(전제 오류)** | `draw_tower_reward_pick`은 이미 `RuntimePerkTraditionalChrome.draw_backdrop`, `_draw_card`, `_sync_choice_visual_selection`, `_choice_visual_blend`, `_draw_per_card_descriptions`를 퍽 선택 모달과 같은 함수로 통과한다. 카드 종이 질감, 메달리온, 명패, 성급, 프리미엄 금박, 선택 리프트 5px, 스케일 2.8%, 알파 0.89에서 1.0 전환이 전부 동일하다. 카드 영역 신규 작업은 0이며, 빠진 것은 정확히 무공 슬롯 원장, 능력치 띠, 호버, 전통 현판 제목, 파티클 다섯 가지다. |
| 렌즈 1 P2: "F를 목표에 넣는 순간 C의 씰 파일이 인질이 된다" | **채택하되 처방 변경** | 지적은 유효하다. 다만 F를 제외하는 것이 아니라 **순서 고정**으로 해소한다. S1이 `tower_ascent_route_serve_smoke`에 arm 레그를 먼저 랜딩해 GREEN을 확보한 뒤, S5가 같은 파일의 소스텍스트 씰만 행위 씰로 이관한다. 두 슬라이스가 같은 파일을 동시에 손대지 않으므로 인질 관계가 성립하지 않는다. 요구 4는 사용자 요구이므로 제외 대상이 아니다. |
| 실사 F: "페이드 오너를 범용 모듈로 승격할지 사용자 결정" | **기각(직접 판정)** | 범용 승격은 프롤로그, 영상, 메인메뉴, 광장 5개 소비처 리팩터를 동반해 탑 요구 6건 전체를 커밋 불가로 묶을 수 있다. 이번에는 탑 전용 순수 시계 RefCounted로만 만들고 범용 승격을 후속으로 미룬다. 이것은 반경 판단이지 취향 판단이 아니라 질문할 사안이 아니다. |
| 실사 A P2: "보상 픽 중 플레이어 패들 마우스 조작과 호버가 서로 먹을 수 있다" | **유예(이번 범위 밖)** | `_handle_victory_loot_input`이 이미 모션을 포함한 모든 이벤트를 소비하고 `set_input_as_handled()`까지 찍으므로 현행에서도 아래 체인은 모션을 보지 못한다. 호버 배선이 이 사실을 바꾸지 않는다. 다만 `battle_frame_flow_controller`가 전리품 분기에서도 `update_player_control(delta)`를 계속 태우므로 패들이 움직인다. 전리품 픽업이 끝난 뒤라 기능적 필요가 없으므로 라이브 1판에서 실제 간섭이 관측되면 그때 명시적으로 끈다. 정적 분석만으로 단정하지 않는다. |