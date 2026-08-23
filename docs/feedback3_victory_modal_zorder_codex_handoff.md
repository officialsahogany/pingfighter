# 지시문 E — 승리보상 뒤 모달 매몰 버그 (피드백3 10·14항)

- **발행**: 관제탑 2026-08-23. 기준 HEAD `d7d5c5b6b`. CI/pre-push 락스텝 226.
- **격리 워크트리**: `D:\codex_tmp\bosspong_fb3_modalz_d7d5` (브랜치
  `codex/fb3-victory-modal-z-20260823`). 병렬 안전(주 수정 파일
  `battle_scene_drawer.gd`+신규 씰 — 타 지시문과 교집합 없음).
- **금지**: 본 트리 직접 편집·푸시·통합. 보고 후 대기.

## 원인 (실측 확정 — 두 버그 동일 원인)

`battle_scene_drawer.gd:56~69` 패스 순서: 스텝8 `_draw_hud_overlays`(:59,
퍽 오버레이 렌더러 = 초식 교체 스왑·무공합일 모달의 드로어) → 스텝9
`_draw_tower_reward_pick`(:62, 승리보상 보드). 즉 **모달이 보상 보드보다
먼저(아래에) 그려진다**. 보상 백드롭이 의도적 반투명(전통 크롬
BACKDROP_DIM_ALPHA=0.64)이라 아래 모달의 '…슬롯 교체'/'무공 합일' 글자가
비쳐 보이는 것까지 스크린샷과 일치. 입력은 반대로 이미 모달
우선(`battle_scene_input_controller.gd:89~94`, victory loot 양보
`:229~233`) — 보이는 화면(보상)이 입력을 안 받아 체감 클릭 불가이고,
**보이지 않는 모달 rect를 우연히 눌러 블라인드 확정되는 역위험**까지 있다.
전투 중 같은 모달은 보상 보드가 비활성이라 정상.

## 작업

1. `battle_scene_drawer.draw()`에서
   `victory_loot_phase_state.is_reward_pick_external_modal_active()`(기존
   술어, `victory_loot_phase_state.gd:378`)가 true인 프레임에만:
   (a) 스텝8의 퍽 오버레이 렌더러 호출 스킵, (b) 스텝9
   `_draw_tower_reward_pick` **직후** 동일 인자(같은 canvas·view_size)로
   후패스 1회 호출. 스킵과 후패스는 반드시 같은 술어 하나로
   락스텝(이중 드로우 금지).
2. ⚠게이트를 '보상 활성 && 외부모달 활성'보다 넓게 잡으면 전투 중 퍽
   선택 모달이 사라진다 — 술어는 위 파사드 하나만.
3. ⚠GRT-058: 이번 수정은 드로우 순서만 — 모달 개폐 훅(쿨다운
   pause/resume·resume safety)을 새로 호출하거나 중복시키지 말 것.
4. ⚠GRT-022: 후패스는 동일 view_size·동일 렌더러 경로 — 위치/스케일
   변형 재드로우 금지(그린 자리=클릭 자리 유지).
5. 신화 획득 시네마틱(외부모달 3종째)은 다른 이른
   패스(`mythic_item_field_effect_renderer.gd:387~391`) 소유의 **동종 잠재
   매몰 후보** — 승리보상 중 재현 여부를 확인해 포함/제외를 보고에 명시
   (재현되면 같은 술어로 포함).

## 씰 (z순서는 현재 무봉인 지대 — 신설 필수)

- 호출 순서 기록형 페이크 렌더러/캔버스로: (i) 외부모달 활성 시 모달
  드로우가 reward pick 드로우보다 **나중** 단언, (ii) 비활성 시 기존 순서
  보존 음성 레그, (iii) 프레임당 모달 드로우 정확 1회(이중 드로우 0).
- 기존 락스텝 재실행: `battle_scene_frame_controller_draw_order_smoke`,
  `tower_node_modal_pointer_smoke:624~637`(보상 화면 스크린스페이스 1회
  드로우 계약), `tower_reward_pick_smoke`, 
  `battle_scene_modal_overlap_input_smoke`. 신규 씰은
  `.github/workflows/godot-ci.yml`·`run_pre_push_checks.ps1` 두 목록 동시
  등재(현 226 → 갱신 수 보고).
- 구조 GREEN ≠ 픽셀(GRT-041/045): 승리보상+만석 초식 구매/무공합일 재현
  Vulkan 캡처로 모달이 보상 위에 보이는지 최종 확인.

## 게이트·보고

포커스드 스모크(+순서 반전 RED 반증) → `-Paths` 경고 → 헤드리스 로드 →
`git diff --check` → 재현 캡처 2장(10항·14항). 보고=워크트리·커밋 해시·
씰 종단선 원문·캡처 경로·신화 시네마틱 판정·미해결.
