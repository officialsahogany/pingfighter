# Stage 2 아라크네 파리티 수정 보고서

작성일: 2026-08-19
기준 커밋: `218cfbb3d0b90bd02903705aaeaf7657c9d67be8`
격리 워크트리: `C:\w\arafix218`
작업 브랜치: `codex/stage2-arachne-parity-fix-218c`
검증 HEAD(보고서 작성 전): `617c08669aedbc9c99a9090f9877e3ae1723b336`

## 결론

S1~S5를 모두 구현했고 범위 내 정적·실행·Vulkan·집중 라이브 게이트는 GREEN이다.
공용 `stage2_boss_skill_hud_renderer.gd`는 변경하지 않았으며 신규 텍스처도 만들지
않았다. 통합과 푸시는 수행하지 않았다.

두더지왕 선행 결과는 지시된 브랜치
`codex/stage2-molewang-parity-fix-69ed`의 `8d37bcc17`에서 먼저 확인했다. S2는
그 브랜치의 `_build_skill()`과 동일하게 기존
`active`/`cooldown`/`cooldown_total`/`cooldown_progress`를 보존하면서
`status`/`ready`/`progress`를 추가했다.

## 슬라이스 결과

| 슬라이스 | 커밋 | 결과 |
|---|---|---|
| S1 구조 5페이즈 | `53435f5f2` | `phase`/`progress`에 따라 shoot, hold_wait, pull, hold, strike가 서로 다른 생산 드로우 메서드로 분기한다. 다겹 채움·광대·보조 가닥·잔상·방사망·2중 충격파·8파편을 복원했다. |
| S2 HUD 키 계약 | `2d90962b9` | 두더지왕 생산자 해법을 그대로 적용했다. ready→charging→casting과 구·신 progress 키 동기화를 씰로 고정했다. |
| S3 상호작용 | `8bef9a6a2` | 원본 실제 호출 경로를 재확인한 뒤 구조 발동 시 활성 Power Smash 포물선만 취소하고, Chaos Spear가 비행 웹·일반/광폭 장판·구조 소유권을 흡수해 개체당 5골드를 지급하도록 복원했다. 다른 보스 활성 시에는 소비하지 않는다. |
| S4 광폭 웹 배치 | `afe43f4ba` | 3구간 순서를 섞고 각 구간에서 20개 정수 X 후보를 뽑아 기존 웹과 앞서 선택한 웹까지 포함한 최소 X거리가 최대인 후보를 선택한다. 동일 시드 원본 오라클을 씰로 고정했다. |
| S5 거미 정체성 | `953cdf77b` | 이동 방향·속도 기반 비선형 gait, body bob, 정지 시 8다리 twitch, 0.45초 방향성 피격 반동, 별도 표현 RNG의 독액 6~10개, 4마디 다리 렌더링을 복원했다. 표현 RNG가 게임플레이 RNG를 소비하지 않음을 확인했다. |
| 상단 경계 보정 | `63489c777` | 2020×1246 픽셀 검수에서 발견한 strike 파편 상단 클리핑을 수정해 최대 충격파·파편 반경을 화면 안쪽으로 고정했다. |
| 시각·라이브 게이트 | `617c08669` | 재현 가능한 2020×1246 Vulkan 5캡처와 집중 라이브 1라운드 래퍼를 추가했다. |

신규/개정 씰 `res://tests/stage2_arachne_boss_port_smoke.gd`는
`.github/workflows/godot-ci.yml`과 `godot/tools/run_pre_push_checks.ps1`에 각각 정확히
1회 등재되어 있다.

## 최종 실행 게이트

- 집중 회귀:
  `stage2_arachne_boss_port_smoke.gd`, `stage2_molewang_boss_port_smoke.gd`,
  `tower_boss_routing_smoke.gd` — `PASS=3 FAIL=0 TOTAL=3`, 종단선
  `All Godot smoke tests passed.`
- 변경 GDScript 7개 `-Paths` 경고 스캔 — 경고 0.
- `run_headless_load_check.ps1 -AllowDuringPlay` — PASS,
  `[ApplicationQuitCoordinator] graceful headless shutdown complete`.
- `git diff --check` — PASS.
- 공용 HUD 렌더러 기준 커밋 대비 변경 경로 수 — 0.
- CI/pre-push Arachne 씰 리터럴 수 — 각각 1.
- 최종 검증은 Godot 4.6.2 stable, Forward Mobile/Vulkan,
  NVIDIA GeForce RTX 5070에서 수행했다.

## 2020×1246 Vulkan 캡처

디렉터리:
`C:\w\arafix218\godot\.godot\codex_captures\stage2_arachne_parity_2020x1246`

| 파일 | SHA-256 | 픽셀 판정 |
|---|---|---|
| `01_rescue_shoot.png` | `9A461C15CFA6F1A70B6B5CE205A8B51CBAB64FA61A692907C42B4BA34BB85EFD` | 주실, 보조 가닥, 선두 발광, 표적이 구분되고 상단에서 읽힌다. |
| `02_rescue_strike.png` | `C64F86CCBD1CC8B725C454A6EA8877FAD534EC4EA977CDE092126E98F7CA6765` | 2중 충격파와 8파편이 상단 경계 안에 남는다. |
| `03_hud_progress.png` | `47FF30B2F41AA035332DC49D57A21F1852D2BD340BFF1F7AAEC4ABE9F38CF4F6` | 공용 HUD 카드의 50% 충전 채움이 실제로 보인다. |
| `04_rage_non_overlap.png` | `93C09410DD4705900B01A83ADD1EED29B96DD7E7E51DB48501B1159D442AFEA7` | 기존 2개 웹과 광폭 3개 웹이 반경 50 기준 서로 겹치지 않는다. |
| `05_gait_hit_venom.png` | `6F2063BCD10A1C3851C940B7403239E11FE010B1C140CDDBF970D7005B4202A4` | 4마디 다리, 비대칭 gait 피격 자세, 독액이 생산 렌더러에 나타난다. |
| `06_live_round_strike.png` | `6F113F3C4428531588F5111319ED84E62D1C76A25BAEBFF5CE73A5C161F570F6` | 집중 라이브 라운드의 실제 strike/HUD 프레임이다. |

시각 게이트 로그:
`C:\w\arafix218\godot\logs\stage2_arachne_parity_visual_qa_47132_20260819131342564.log`
(`FC5EDFD21895788FAF1C984BCD11B4C04FA4B47C4D620E9CFE7C43FA11FC0BC4`).

## 집중 라이브 1라운드

`run_stage2_arachne_live_round_qa.ps1`는 실제 생산
`stage2_boss_variant_skill_state.gd`, `stage2_variant_boss_renderer.gd`, 변경하지 않은
`stage2_boss_skill_hud_renderer.gd`를 실제 2020×1246 Vulkan 창에서 매 프레임 함께
구동한다. 거리 조건을 발명하지 않고 공 상단·상향 진행·게이지 50·쿨다운 0의 실제
발동 조건으로 시작했다.

결과:

- 페이즈 순서: `shoot → hold_wait → pull → hold → strike → release`.
- 관측 프레임: shoot 16, hold_wait 60, pull 50, hold 60, strike 8.
- 방출 속도: `(-1.31911, 17.9516)` — 플레이어 방향 방출.
- 종료 쿨다운: `21.750s` — 25초가 연출 중 정상 감소한 값.
- 로그:
  `C:\w\arafix218\godot\logs\stage2_arachne_live_round_qa_47132_20260819131347472.log`
  (`9B6AD9392D70B224FCD392996ED8709B6ABD5097466B0DAFDE8BD9B6F1D5FFED`).

## 기준선 분리 관찰

추가로 전체 `main.tscn` 타워 진입 래퍼도 실행했으나, 기준 커밋에 이미 존재하는
Arachne 비관련 오류 때문에 전환 프리웜에서 종료됐다. 최초 원인은
`HOLOGRAM_DISK_ICON_PATH` 외부 멤버 해석, `active_item_effect_reset` 인자 수,
`WritheEmberMaterial`, Stage 2 ambient/water/rage state의 인스턴스 API 불일치다.
이는 Arachne 변경 전 `stage2_router_smoke.gd`와
`chaos_spear_stage2_rock_absorb_smoke.gd`에서도 재현된 독립 기준선 결함이며 이번
범위에서 고치지 않았다. 보존 로그:
`C:\w\arafix218\godot\.godot\codex_logs\tower_boss_entry_visual_qa_floor_02_arachne_52112_20260819130411797.log`
(`E0A8D6FD8C205CD57B5A743FA08B4BAA9CF2490C137D7A28A6D323CD5B9E3DF4`).

이 관찰은 범위 내 필수 라이브 판정을 대체하지 않는다. 위 집중 라이브 라운드가
Arachne 생산 상태·렌더러·HUD의 실제 연속 프레임과 완전한 구조 시퀀스를 별도로
GREEN으로 증명했다. 범위 내 blocked/unverified 항목은 0이다.

## 보존·통합 상태

- 선행 로그 백업:
  `C:\Users\woduq\.codex\backups\stage2_arachne_fix_logs_20260819_121456`
  (416개, 834,098 bytes).
- 본 트리 상태 전수 조회는 수행하지 않았다.
- 작업 중 본 트리 HEAD가 외부 동시 작업으로 `9f8714d08f46a0c4611d502376ce1d9285f8af9c`까지
  전진했음을 `rev-parse`로만 확인했다. 이 작업은 기준 `218cfbb3d`의 격리 브랜치에
  남아 있으며 본 트리에 통합하지 않았다.
- 푸시하지 않았다. 통합 대기 상태다.
