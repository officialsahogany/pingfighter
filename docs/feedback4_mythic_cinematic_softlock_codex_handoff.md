# 지시문 H — [P0] 신화 획득 시네마틱 동결 소프트락 (피드백4 4항)

- **발행**: 관제탑 2026-08-24. 기준 HEAD `bc5890dd1`. CI/pre-push 락스텝 227.
- **격리 워크트리**: `D:\codex_tmp\bosspong_fb4_mythic_bc58` (브랜치
  `codex/fb4-mythic-cinematic-20260824`). 주 파일 core 게이트/드라이버 —
  타 지시문과 교집합 없음.
- **금지**: 본 트리 직접 편집·푸시·통합. 보고 후 대기.
- **⚠WIP 지뢰 (2건)**: 본 트리에는 ① `mythic_item_acquisition_cinematic_v2.gd`
  미커밋 대형 리팩터, ② **미추적** `battle_physics_gate_coordinator.gd`
  (게이트 래더를 frame_controller에서 추출한 진행 중 리팩터)가 있다.
  HEAD(=워크트리)에는 코디네이터가 없고 같은 래더가
  `battle_scene_frame_controller.gd:228` 인라인이다. 기아 결함은 양쪽
  구조 공통. **워크트리에서는 HEAD 구조(frame_controller 인라인 래더)에
  수리**하고, 훅 삽입 지점을 "모달 차단 return 직전"이라는 의미 앵커로
  주석 명시할 것 — 라이브 코디네이터로의 이식은 통합 시 관제탑이 수행.
  두 WIP 파일 재현·수정 금지(필요 판단 시 보고만).

## 원인 (실측 확정 — E 통합 무죄, 게임 진행 불가 P0)

8/19 커밋 `830d49bb9`가 `is_acquisition_cinematic_active`를 물리 모달
게이트에 등재(`battle_scene_modal_gate_controller.gd:169`)했는데, 그
게이트는 시네마틱의 **유일한 프로덕션 틱 경로**(frame_controller →
update_driver → `update_mythic_items` → cinematic.update)보다 먼저
프레임을 차단한다(HEAD 기준 `battle_scene_frame_controller.gd:228`
인라인 래더 — update_driver 도달 전 return; 교차검증으로 유일-틱-경로
전수 확인 완료: stage_clear_result 화면의 idle 핸들러 외 대체 틱 없음,
시네마틱 노드에 _process류 부재). 결과:

- phase_timer가 BUILDUP/0.0 영구 동결. `VisualEnvelope.begin()`은
  vignette_alpha=1.0만 켜므로 어두운 소프트 원형
  `mythic_soft_vignette.png`만 풀필드로 그려짐 = 스크린샷의 검은 얼룩.
  밝은 레이어(만다라/아크/아이콘)는 전부 alpha 0 초기값에서 불변.
- 클릭은 `battle_reward_modal_input_router.gd:17`이 시네마틱으로 넘겨
  전부 소비하지만 `request_absorb()`는 REVEAL+0.5s에서만 유효
  (`mythic_item_acquisition_timeline_state.gd:59`) — 영원히 도달 불가.
  리워드 픽도 `is_external_modal_active()`로 양보 → 완전 소프트락.
- 드로우 순서 가설(E 재배치)은 반증됨: 시네마틱은 top_level·z=100
  자체 렌더로 항상 위에 그려진다(얼룩이 카드 위에 보이는 것과 일치).
- 8/19의 씰은 게이트 '등재'와 입력 라우팅만 봉인, 실 물리 경로 관통
  페이즈 전진은 무봉인(직접 update 호출 씰 = 공허 GREEN, GRT-053/040).

## 작업 (방향 A: 차단 프레임 유지보수 틱 — 게이트 등재는 유지)

1. 물리 차단 분기(HEAD 기준 `battle_scene_frame_controller.gd:228` 근방
   인라인 래더의 차단 return 직전)에서, 차단 사유에 신화 획득
   시네마틱이 포함되고 상위 우선 모달(퍽 선택/엔젤 모달)이 비활성일 때
   물리 틱당 **정확히 1회** `update_mythic_items` 동형 유지보수 틱 +
   `request_battle_redraw` 호출. stage_clear_result 화면이 이미 쓰는
   형제 훅(`stage_clear_result_mythic_acquisition_handler.update_cinematic`)
   이식이 정본 패턴(GRT-058).
2. ⚠이중 틱 금지(GRT-018): 게이트 개방 프레임은 기존 flow-controller
   경로가 틱한다 — 유지보수 틱은 **차단된 프레임에서만**. 한 물리 틱에
   phase_timer 전진은 정확히 delta×1. `_update_mythic_once`의 시네마틱
   활성 중 dedup 우회(`battle_scene_item_update_driver.gd:187`)와의
   상호작용 확인.
3. 830d49b의 게이트 등재·"시네마틱 중 전리품/플레이어 동결" 의도는
   유지(설계 반전 금지 — 파리티 복원=기록 결정 대조 규칙). 게이트
   철회안(B)은 채택하지 말 것.
4. natural completion 연쇄(`_notify_natural_completion` → 엔젤 블레싱
   해제)가 새 경로에서도 발화하고, 종료 프레임에 리워드 픽이 입력을
   되찾는지(기존 reclaim 씰) 배선.
5. **공통 경로 배치 필수**(교차검증 확정): 기아는 리워드 픽 구매만이
   아니라 전투 중 픽업·전리품 상자 `show_acquisition_cinematic`
   (`victory_loot_phase_state.gd:544`) 등 **모든 획득 시네마틱 진입점**을
   동일하게 동결시킨다 — 유지보수 틱은 진입점별이 아닌 전투씬 공통
   차단 분기에 심을 것.
6. 모달 개폐 부수효과(액티브 아이템 쿨다운 pause/resume, 루프 오디오
   정지 GRT-034)는 기존 enter/leave 훅 소유 유지 — 새로 호출하거나
   중복시키지 말 것(GRT-058).

## 씰

- **프로덕션 경로 페이즈 전진 씰**: 실 프레임 컨트롤러/게이트 코디네이터
  관통 다수 틱으로 BUILDUP→IGNITE→WHITE_FADE→REVEAL(waiting_for_click)
  도달 단언. cinematic.update() 직접 호출 금지(공허 GREEN 재발 방지).
- **선재 RED 반증**: 유지보수 틱 제거 상태에서 같은 픽스처 phase_timer
  ==0.0 RED 먼저 확인.
- **클릭 진행 씰**: REVEAL 도달 후 실 입력 컨트롤러로 클릭 →
  ABSORB→COMPLETE → active false → 리워드 픽 입력 reclaim.
- **BUILDUP 클릭 음성 레그**: REVEAL 전 클릭은 폐기(지연 발동 금지,
  GRT-050 폐기/유예 선언)·이후 정상 완주.
- **이중 틱 가드**: 차단↔개방 경계 프레임에서 phase_timer 전진 delta×1.
- 픽셀 QA: `battle_scene_victory_modal_zorder_visual_qa.ps1` 확장 —
  REVEAL 중앙 강한 임계 밝은 픽셀 >0(검은-얼룩 반증, GRT-047 판정),
  완료 후 얼룩 잔존 0.
- 신규/확장 씰 CI·pre-push 양 목록 등재(227 → 갱신 수 보고).

## 게이트·보고

포커스드 스모크(+RED 반증) → `-Paths` 경고 → 헤드리스 로드 →
`git diff --check` → 절세무공 획득 재현 캡처(동결 전/후). 보고=워크트리·
커밋 해시·씰 종단선 원문·캡처 경로·전투 중 상자 시네마틱 판정·미해결.
