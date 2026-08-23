# 지시문 C — 수련장 표시 정리 4건 (피드백3 5·6·7·8항)

- **발행**: 관제탑 2026-08-23. 기준 HEAD `d7d5c5b6b`. CI/pre-push 락스텝 226.
- **격리 워크트리**: `D:\codex_tmp\bosspong_fb3_training_d7d5` (브랜치
  `codex/fb3-training-display-20260823`).
- **의존/순서**: 지시문 A(상점 카드 축소)가 같은 렌더러·모달 정본·씰을
  만진다 — **본 지시문을 먼저 착지**하고 A가 뒤따른다. 지시문 D(게이지
  아트)와는 파일 교집합 낮음(D는 게이지 드로어, C는 카드/호버).
- **금지**: 본 트리 직접 편집·푸시·통합. 보고 후 대기.
- ⚠4건이 같은 씰 3종(`tower_training_screen_layout_smoke`·
  `tower_training_lucky_bonus_smoke`·`tower_node_modal_feedback_smoke`)의
  정확 행수 단언을 공유한다(GRT-021 행 예산) — **항목별 커밋을 나누되 씰
  갱신은 항목마다 원자적으로**.

## 5항 — 하단 배지 문구 제거

생산자: `tower_ascent_flow_economy_progress.gd:487~501`
(`bonus_badge_text` 주입 — 타이밍 배지 + 수납술 '고정 +1칸' 분기).
**결정: 타이밍 배지("행운 판정 폭…")만 제거, 수납술 '고정 +1칸'은 유지**
(슬롯 고정 안내는 오해 방지 정보). 렌더러 배지 기계는 존치(수납술이 씀).
씰: layout smoke의 LONGEST 상수+4행 예산 레그를 3행 계약으로 재작성,
호버 레인 씰의 badge_lane 단언 갱신, `lucky_bonus_smoke:267` 문구 단언을
'타이밍 배지 부재' 소스 단언으로 전환(`timing_judgment_smoke:233` 은퇴
카피 부재 관례), `timing_judgment_smoke` 로케일 키 목록에서 BADGE 키
제거 여부는 **키 자체는 존치**(수납술 외 재사용 대비)로 하되 미사용
정리 시 7로케일 동기.

## 6항 — 설명 폰트 확대

현행: compact 설명 폰트 `clampi(round(9.0*cs), 9, 18)`
(`runtime_perk_overlay_renderer.gd:681`), 행 스텝 `10*cs`(:1100), 그리드
시작 `64*cs`(:1122), 설명 3행 예산. 기본 뷰(cs≈0.70)에서 폰트 9px 하한
고정이 작음의 실체.
작업: 배지 레인(end.y-18*cs)이 5항으로 비므로 그 공간을 흡수해 폰트
기울기 9→11~12, 행 스텝 10→12*cs로 한 세트 상향(호버 상세 베이스라인
정본 `tower_node_hover_detail_row_baseline`과 min-shrink `:1129`도 같은
세트로). ⚠GRT-021: 랩이 길어져 3행 초과분은 통째 숨김 — 씰의 정확
행수(기본 3행/라이브 2행) 재측정·재봉인. 픽셀 QA로 겹침 0 확인.

## 7항 — 누적치 표기 정책

원인(실측): 설명은 매 리프레시
`physique_training_catalog.build_card → _build_effect_line`
(`:197~226`, `:265~284`)이 `amount × (applied_count+1) × 숙련배율`로
재계산 — 유운보 4% × (1.3great+1) = **9.2%**. 버그가 아니라 실효 표기.
작업(사용자 확정 방향): **기본 퍼레벨 고정 표기 + 괄호 누적** — 예:
`이동 속도 4% 증가 (누적 9.2%)`. `_build_effect_line` 개정 + 호출부
2곳(비한국어 재주입 258 포함, 7언어 동기 원칙). 누적 0회(applied 0)면
괄호 생략. 동반: `training_mastery_mugong_smoke:137` 정확 문자열(⚠이
스모크는 선재 RED 기저선 — 3성 전환 전 기대값, 귀속 분리),
`lucky_bonus_smoke:270`, 문구 길이 증가로 compact 1행→2행 랩 가능성 —
6항의 새 행 예산 안에서 수용 확인(그래서 6·7은 같은 워크트리 순차).

## 8항 — 호버 '현재→결과' 예측 행 제거

원인: `economy_progress:534~538` training presentation의 current/result +
`_tower_node_training_hover_preview`(`runtime_perk_overlay_renderer.gd:
1517~1545`)의 실측 덮어쓰기. 행 생산 게이트(`:798`)는 둘 다 비면 스킵.
작업(**training 한정** — shop·fallen_monk는 '진열 중→획득' 등으로 키
공유하므로 로케일 키·렌더러 행 게이트는 불변):
1. 생산자 쪽에서 끊기: training presentation의 current/result 미주입.
2. 죽은 기계 철거: `_tower_node_training_hover_preview`·호버 프리뷰
   캐시(:197~199)·`flow_node_progress:98~107` hover_detail_context 주입
   (GRT-043 dead work). ⚠`RuntimePerkTrainingStatPreview` 클래스는 퍽
   선택 능력치 띠가 계속 소비 — **삭제 금지**, 타워 호버 소비만 철거.
3. 남는 호버 행 = '대상 · 비용'(+비활성 시 거부 사유).
씰: `feedback_smoke:185` 호버 3행→2행, `:243~256` training adapter 레그
(⚠현재 선재 RED — 이 기회에 새 계약으로 재작성해 해소하고 귀속 기록),
no-hover 게이트 레그(:189~203)와 카운터(:308) 갱신, layout smoke 호버
레인 씰에서 training 3행 도달 불가화 반영.

## 게이트·보고

항목별 커밋 4개(헝크 분리). 각 커밋마다: 포커스드 스모크+반전 RED 반증 →
`-Paths` 경고 스캔. 마지막에 헤드리스 로드 + `git diff --check` +
`run_tower_training_timing_visual_qa.ps1 -BeforeCardPath
.godot/codex_captures/tower_training_timing/training_card_overlap_before.png`
재캡처(카드 4장 이상 시야 확보 캡처 포함). 보고=워크트리·커밋 해시·씰
종단선 원문·캡처 경로·선재 RED 2건(mastery_mugong·feedback adapter) 귀속
로그·미해결.
