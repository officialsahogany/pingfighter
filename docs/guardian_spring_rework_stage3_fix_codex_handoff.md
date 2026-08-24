# 지시문 S3-수정 — 살핀다 비교창 입력 도달 P0 외 (관제탑 검토 회신)

- **발행**: 관제탑 2026-08-24. 대상: 브랜치
  `codex/guardian-spring-rework-20260824`(워크트리
  `D:\codex_tmp\bosspong_spring_s1_63f8`)의 S3 `46d521090` 위에 **추가
  커밋**으로 수리. S1 `5c29122e2`·S2 `4949344c1`은 APPROVE — 재작업 금지.
- **금지**: 본 트리 직접 편집·푸시·통합. 기존 3커밋 리베이스/amend 금지.

## [P0] 살핀다 비교창이 샘터에서 입력을 받지 못함 (GRT-058 본체)

- 원인(검토 실측): `battle_scene_input_controller.gd:59~61`
  `_handle_tower_ascent_flow_input`이 `flow_owner.is_active()`면 무조건
  `_mark_handled` 후 return true — overflow 오버레이 입력 소유자
  (:96 overlay controller)에 도달 불가. 탑 플로는 PHASE_NODE_MODAL 동안
  active라 정예 카드 클릭 후 비교창 조작(확정/취소)이 전부 삼켜진다.
  파생: 비교창 pending 중 ESC → 노드 모달만 닫히고
  `is_overflow_choice_active`=true 잔존 → 다음 전투 진입 시
  `battle_scene_modal_gate_controller.gd:191` 물리 게이트가 스테일
  비교창으로 전투 개시를 탈취(소프트락 등가).
- 수리(정공): tower flow 입력 분기 **앞**(또는
  `_handle_tower_ascent_flow_input` 선두)에서
  overflow-choice/acquire-cutin 활성 시 overlay controller로 위임.
  기존 영접 컷인은 타이머 자동 진행이라 무영향 — 위임 조건은 입력
  구동형 오버레이 활성 여부로만.
- ⚠기존 씰이 못 잡은 이유(GRT-053/040): stage3 스모크의 훅 레그가
  소스텍스트 단언+직접 호출뿐. **실 경로 씰 필수**: tower flow active +
  비교창 활성 상태에서 실 입력 컨트롤러 관통 → 오버레이에 입력 도달·
  교체 확정·취소 왕복 단언 + 위임 제거 시 RED 반증.
- ESC 스테일 가드: 노드 모달 닫힘 시 pending 비교창을 함께
  정리(cancel_browse_compare)하거나 닫힘을 차단 — 어느 쪽이든 다음
  전투 진입 시 잔존 비교창 0 단언 레그.

## [P1] 첫픽/구매 확정의 획득 컷인 dismiss 불가 (같은 뿌리)

- 첫픽 `_grant_and_activate_pet`·구매 확정의 `start_acquire_cutin`이
  입력 대기형 컷인을 tower flow active 중에 띄움 — P0 위임에 acquire
  컷인 dismiss 입력(`battle_scene_overlay_input_controller.gd:50~63`)
  포함. 구매 확정 컷인의 `display_pet_id=""` 폴백도 실제 pet_id로 교정.

## [P1] 실 런타임 구매 경로 무씰

- `begin_tower_spring_overflow_compare`→`commit_tower_spring_overflow_replace`
  를 실 `LingpetEggRuntime`으로 관통하는 레그 신설: 엘리트 롤 재적용
  로드아웃 == 오퍼 빌더 산정치, 구 수호령 망각 3종, 롤백 원복까지.

## [P2] 동반 수리

1. 리롤 동선: 지시문 원안 "리롤=살핀다 재실행"이 현재 비교창 취소
   경유로만 가능 — 카드 화면에 리롤 진입(재실행) 경로 복원.
2. 코덱스 등재(관제탑 판정): **열람만으로 도감 first_seen 등재 금지** —
   `begin_..._compare`의 `_record_guardian_discovery_at_reveal` 호출을
   구매 확정 시점으로 이동.
3. 기도 락 강화: `record_guardian_identity_reveal`의 락이
   `result.accepted`에만 걸림 — codex 스토어 실패와 무관하게 실제 획득
   시 락 걸리게.
4. 페이지 컨트롤 씰 복원: rest_card_adapter에서 삭제된 GRT-022 페이지
   버튼 레그(top-corner press·draw=hit-test)를 페이징 기계가 잔존하는 한
   최소 1레그 유지(합성 7카드 픽스처 가능).
5. S2 표시면 확인: 능력치 패널 "기력 획득량" 행에 기도 +6%가 반영되는지
   (캡처상 50pt 무부스트 의심) — 반영 대상이면 수리, 의도 제외면 근거
   보고.
6. 위생: 죽은 로케일 키(KEY_SPRING_SWAP/ABSORB/BROWSE_PLACEHOLDER 등)·
   죽은 Fake 메서드 정리.

## 게이트·보고

수리 커밋(들) 후: stage2/stage3/노드/오버플로 스모크 + 신규 실경로 씰
(+P0 위임 제거 RED 반증) → `-Paths` 경고 → 헤드리스 로드 →
`git diff --check` → **비교창 실조작 라이브 캡처**(확정 1장·취소 1장)와
첫픽 컷인 dismiss 캡처. 보고=추가 커밋 해시·씰 종단선 원문·캡처 경로·
P2 6건 각각의 처리 여부·미해결.
