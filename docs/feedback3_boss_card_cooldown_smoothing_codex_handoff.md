# 지시문 F — 보스 스킬카드 쿨타임 뚝뚝 끊김 (피드백3 12항)

- **발행**: 관제탑 2026-08-23. 기준 HEAD `d7d5c5b6b`. CI/pre-push 락스텝 226.
- **★선행 조건**: `D:\codex_tmp\boss_skill_round_cd_98fa`(베이스
  `98fa51ad5`)에 라운드 전환 쿨다운 보존 WIP 11파일이 미보고 상태로 살아
  있다. 교집합 확실: 쿨다운 계약 문서·contract 씰·motion QA gd/ps1·GRT
  문서 2종(+게이지 레일 건드리면 molewang/alice/hongryun state 3종).
  **그 세션의 보고→관제탑 통합이 끝난 뒤 새 워크트리에서 착수**하라.
  (그 워크트리에서 이어서 작업하는 것은 금지 — 베이스가 5커밋 낡았다.)
- **격리 워크트리**(선행 통합 후): `D:\codex_tmp\bosspong_fb3_cardanim_<HEAD>`
  (브랜치 `codex/fb3-card-cooldown-smoothing-20260823`).
- **금지**: 본 트리 직접 편집·푸시·통합. 보고 후 대기.

## 실측 진단 (정적 — 라이브 확정 필요)

- 진행도 데이터는 물리 틱 delta 적산 live 상태이고, 리드로우는 (a) 매
  물리 틱 `battle_frame_flow_controller:150` + (b) 매 렌더 프레임
  `frame_controller.process_idle:158` 양쪽에서 프레임당 1회로 합쳐진다 —
  즉 **시간계약(TIME=32/39) 카드는 구조상 72Hz로 부드럽게 차야 한다**.
  '보스 타격 시에만 리드로우' 가설은 이 트리에선 반증됨.
- 유력 재현체: **게이지-급유(RESOURCE_GAUGE=2)·on_boss_hit(17/39) 카드** —
  지굴왕 게이지 +60/타격, 아카무 GAUGE_COST 100+pity(적격실패가 보스 타격
  롤에서만 누적) 등은 표시가 타격 순간에만 점프하는 것이 **데이터의
  실체**다. 시전 리셋→재정렬 셔플→플래시도 타격 순간에 몰린다.
- 씰 사각: contract 씰·motion QA 모두 state.update 직접 구동 — 실
  리드로우 케이던스 미봉인, QA 샘플 1초 간격이라 끊김/부드러움 구분 불가.

## 작업

1. **재현 특정 선행**: 라이브 1판으로 어떤 보스·어떤 카드가 끊기는지
   특정(시간계약 카드가 끊기면 리드로우 기아 — 계측 플래그로 실측 후
   별도 보고; 게이지/타격 카드면 2번으로).
2. **표시 스무딩(권위 레일 불변)**: `boss_skill_card_hud_spec.gd`에
   `advance_card_shuffle`과 동일한 호출부-소유 store 패턴으로
   `advance_card_fill(store, key, target_fill, time_sec)` 신설 — 표시
   fill이 목표 progress로 0.2~0.4s ease 수렴. 감소 방향(시전 리셋)은 즉시
   스냅(오독 방지). 9개 스테이지 렌더러의 fill 산출 직후 통과, prune는
   `prune_shuffle_store` 패턴 공용화(사라진 카드·수호령 레일 동승 카드
   누수 금지).
3. ⚠GRT-060 락스텝: progress/ready/trigger_type **게시 payload 의미
   불변** — 스무딩은 렌더러 표시층 전용. 발동 분기를 metadata로 옮기지
   않는다. 게임플레이 수치·RNG 불변.
4. ⚠GRT-043/032: 상시 per-frame 절차 드로우 예산 재평가, 핫패스 카탈로그
   스캔 금지.

## 씰

- 스무딩 수렴 헤드리스 씰: 게이지 +60 스텝 입력 시 표시 fill이 단조
  ease로 유한시간 내 권위 progress에 수렴 + 리셋 스냅 레그 + store prune
  레그. RED 반증(스무딩 무력화 시 스텝 점프 검출).
- motion QA에 sub-초 샘플 레그(0.1s×10) 추가 — 인접 캡처 픽셀 모션 단언.
- `boss_skill_card_cooldown_contract_smoke`(CI `:70~72`·pre-push `:74~76`
  락스텝) 재실행 — 선행 통합된 라운드 보존 레그(+180줄)와 충돌 없는지.
- ⚠본 트리의 `boss_skill_card_hud_spec.gd`·stage2 HUD 렌더러는 사용자
  WIP 3-way 병합본으로 더티 — 통짜 add 금지, 헝크 분리.

## 게이트·보고

포커스드 스모크(+RED 반증) → `-Paths` 경고 → 헤드리스 로드 →
`git diff --check` → `run_boss_skill_card_cooldown_motion_visual_qa.ps1`
재캡처(끊김 재현 보스 포함). 보고=재현 특정 결과(어느 레일이었는지)·
워크트리·커밋 해시·씰 종단선 원문·캡처 경로·미해결.
