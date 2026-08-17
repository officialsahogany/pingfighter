# 퍽 기준선 부채 11종 수리 /goal 지시문 (2026-08-17)

- **목적**: 클러스터 스냅샷(`c2cc477a6`)과 함께 등록된 기준선 부채 씰 11종을
  소유 트랙별로 GREEN으로 수리한다. 부채 표(씰명·실패 서명·소유 트랙)는
  `docs/perk_cluster_commit_report.md` §8이 정본이다.
- **완료 보고**: `docs/perk_cluster_baseline_debt_repair_report.md`.

## 1. 수리 그룹 (그룹별 독립 커밋, 푸시 금지)

1. **런타임 퍽 모듈 분리 이관 계약 5종**: `runtime_perk_callback_map`,
   `runtime_perk_character_context`, `runtime_perk_general_icon_static`,
   `runtime_perk_payload_access`, `runtime_perk_runtime_state_access`.
   미완 이관을 계약대로 완성한다 (모듈 분리 트랙의 잔여 Risk 완결).
2. **융합 4종**: 콜드부트 2종(수호령 강화 사운드 3종 등록 + ObjectDB
   leak/81 resources 수명 정리 — 러너의 리소스 승격 기준 준수),
   TAB 재료 섹션 헤더 계약, es/pt-BR/ru 무공 용어·one-off 태그 라우팅
   (다국어 동기화 계약 준수), Golden Trajectory 가시 골드 피드백 경로.
3. **팔자윷 1종**: `mystic_dice_active_item_smoke` 아이콘 32px 계약
   (에셋 규격 또는 로더 중 어느 쪽이 정본인지 대조 후 맞춘다).

## 2. 수리 원칙

- **씰 약화 금지가 기본**: 원칙은 런타임·에셋을 계약에 맞추는 것이다.
  씰의 기대 자체가 낡은 경우(정본 문서·사용자 확정과 어긋나는 구 계약 잔재)에만
  씰을 개정할 수 있으며, 그때는 정본 근거를 보고서에 기록하고 반증
  (구 기대 주입 RED → 원복 GREEN)을 남긴다.
- 새 게임플레이 수치·기능 발명 금지. 수리에 필요한 미확정 값이 나오면
  중단·보고.
- 그룹별 독립 커밋 + 커밋마다 표준 게이트(집중 스모크+부정 레그, `-Paths`
  경고, 헤드리스, diff check). 공유 파일은 격리 스테이징 트리 증명.
- `stage_clear_result_reward_plan_builder.gd`와 무관 WIP(코만도 물자 등)는
  건드리지 않는다.
- 플레이 중 검증 신정책 준수, 검증 전 로그 백업.

## 3. 완료 기준

- 11종 전부 GREEN + **124종 합집합 배터리 재실행에서 기준선 113 PASS 유지 +
  RED 0** (부채 11 → 0 개선 증명).
- 타워 회귀 23종 + 페이즈 A·B·C 핵심 회귀 GREEN.
- 보고서: 그룹별 커밋·서명별 수리 내용(런타임 수리 vs 씰 개정 구분)·게이트
  종단선·fixed/deferred/blocked/unverified.
- 일부 씰이 수리 불가(설계 미결 의존)로 판명되면 완료 처리하지 말고 해당
  씰만 사유와 함께 blocked로 남기고 중단을 보고한다.
