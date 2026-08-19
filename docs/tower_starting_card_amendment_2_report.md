# 시작 카드 개정 2 완료 보고

- 기준 커밋: `0c6067f83c73e468abb48fe1de3f20212d01d5a7`
- 격리 브랜치: `codex/tower-start-card-amend2-0c60`
- 구현 커밋: `8cbc635ce020f5e9655621cd649c9871daf0fef4`
- 통합 상태: **미통합**. 아카무 R5 재이식이 본 트리에 착지한 뒤 사용자의 통합 지시를 기다린다.
- 푸시: 하지 않음.

## 1. 구현 범위

| 파일 | 결과 |
|---|---|
| `godot/scripts/hud/runtime_perk_overlay_renderer.gd` | 시작 카드 경로에서만 하단 무공 저장고와 능력치 띠를 제거했다. 보상 픽과 일반 퍽 선택 모달의 기존 호출은 유지했다. |
| `godot/scripts/tower_ascent/tower_start_card_state.gd` | 시작 카드 뷰모델에서 하단 패널을 제거하고, 기존과 같은 카드 크기를 유지한 채 3장을 화면 세로 중앙에 재배치했다. 제목·안내·카드 rect·히트 테스트가 같은 레이아웃 값을 사용한다. |
| `godot/tests/tower_start_card_smoke.gd` | 시작 카드 하단 패널 부재, 보상 픽 역방향 보존, 카드 크기 불변, 세로 중앙 배치, 첫 카드 상단 모서리 히트, 선택 후 실제 레벨 2, 렌더러 호출 경계를 봉인했다. |
| `docs/tower_ascent_run_map_plan.md` | §3.17에 시작 카드 전용 3장 단독 표시 계약을 반영했다. |

구현 커밋에는 위 네 파일만 들어 있다. 변경량은 111줄 추가, 53줄 삭제다.

## 2. WIP 보호와 격리

- 본 트리를 직접 수정하지 않고 별도 워크트리에서 구현·커밋했다.
- `stash`, `checkout`, `reset`, 통짜 `git add`를 사용하지 않았다.
- 라이브 부팅 검증은 별도 폐기 가능 워크트리
  `C:/Users/woduq/.codex/tmp/bosspong_tower_start_card_amend2_live`에서 수행했다.
- 라이브 검증 트리는 현재 본 트리의 부팅 의존 WIP를 복제하되, 아래 세 구현 파일이 격리 구현본과 동일한 SHA-256임을 확인했다.
  - 렌더러: `C6658571674DC3B35778AF4C0D603178A2831CE028E1D4C178BE9568F506DB21`
  - 상태: `47F5C8AF93E0AC801CA8BAE81A31112DA51D00F1AAD682561652E5D0CC4F9426`
  - 씰: `89F621A19AFF816751D2239D7D33CF00F1D9071FC8D41EE2000B1A279069996F`
- 검증 전에 `.godot` 로그·캡처를
  `C:/Users/woduq/.codex/backups/tower_start_card_amend2_logs_20260819_193226`에 백업했다.
  파일 8,210개, 1,884,630,844바이트이며 전체 매니페스트 집계 SHA-256은
  `9106482BC1B6258ADF7A4FFDA1E3BCA0187FE2706A1F460123CD8ED0E4657981`이다.

## 3. 자동 검증

| 게이트 | 결과 | 종단선/증거 |
|---|---|---|
| 시작 카드 + 보상 픽 집중 스모크 | GREEN, 2/2 | `All Godot smoke tests passed.` |
| 탑 회귀 묶음 | GREEN, 8/8 | `All Godot smoke tests passed.` |
| 헤드리스 로드 | GREEN | `Godot headless load check passed.` |
| 변경 GDScript 경고 스캔 | GREEN, 3파일 | 경고 0건 |
| `git diff --check` | GREEN | 출력 없음 |
| CI/pre-push 락스텝 | GREEN | 두 목록 모두 `tower_start_card_smoke.gd`, `tower_reward_pick_smoke.gd` 포함 |

집중 씰은 시작 화면에 하단 두 패널이 없음을 단언하는 동시에 보상 픽에는 기존 패널이 남음을 역방향으로 단언한다. 레이아웃은 카드 중앙점이 아니라 첫 카드 상단 모서리 안쪽 좌표로 히트 테스트했으며, 선택 결과는 플래그가 아니라 런타임 퍽의 실제 레벨 `2`로 단언했다.

## 4. Vulkan·픽셀 검증

두 QA 모두 2020×1246 실제 Vulkan 렌더를 사용했다.

| 화면 | 판정 | 캡처 SHA-256 |
|---|---|---|
| 시작 카드 3장 | GREEN: 카드 3장만 보이고 하단 패널이 없으며 세로 중앙 배치 | `48037814919AA272327D44F56485909F80B1AD331A2F6F3DED93456DF6F27B5F` |
| 시작 카드 선택 | GREEN: 상단 모서리 입력 후 선택 상태 표시 | `57F10512E791712C30A08CF1C65093EB604586CC5D7AA5ABF1E302DDD8ACCC05` |
| 시작 카드 후속 이행 | GREEN: 선택 뒤 프롤로그 인계 | `41320D7AE203AEFE110B5001329211F5179E7185FAA8A35CA2E653AA057164ED` |
| 보상 픽 역방향 | GREEN: 무공 저장고·능력치 띠 유지 | `1F968C1344EF1E8974B0A2F4C85E617DBC3A4E9B92BC2DFC38E98BA85B244E5C` |

- 시작 카드 QA 종단선: `tower_start_card_visual_qa: ok`
- 보상 픽 QA 종단선: `tower_reward_pick_visual_qa: ok`
- 겹침·클리핑·하단 유령 패널은 발견하지 못했다.

## 5. 실제 `run_tower_mode.ps1` 검증

- 사용자 세이브와 분리한 사용자 루트
  `D:/main/.codex_validation_userdata/tower_start_card_amend2_finalseq_20260819_1210`로 새 런을 시작했다.
- 실제 메인 메뉴 → 캐릭터 선택 → 탑 부팅 경로에서 시작 카드 3장이 나타나는 것을 확인했다.
- 첫 카드의 좌상단 경계 안쪽을 클릭했고, 카드 화면이 닫히며 실제 후속 단계인 `파지법 선택`으로 이행했다.
- 시작 카드 표시 캡처: `frame_39.png`, 2063×1151,
  SHA-256 `12841844270B47E1CEC8FC74B51B180D9EF4B091DFF0878F64536C3C99C2664F`.
- 클릭 후 캡처: `actual_run_after_top_corner_click.png`, 2063×1151,
  SHA-256 `65DA74D308886A54AB323A0DA3CABC288577F1B529F24D9E9737E9AD8F79F843`.
- 라이브 로그 `tower_mode_live_31752_20260819121110779.log`에서 `SCRIPT ERROR`는 0건이다.
- 종료 시 변경 범위 밖 `victory_highlight_frame_capture_state.gd` 정리 경로에서 비스크립트 엔진 `ERROR` 3건이 출력됐다. 시작 카드 실행·선택 중 오류가 아니며 이번 지시문의 판정 조건인 `SCRIPT ERROR` 0건에는 영향이 없다. 후속 소유 트랙 부채로 분리한다.
- 검증용 Godot와 래퍼 프로세스는 모두 종료됐고 사용자 Godot 프로세스는 건드리지 않았다.

## 6. 판정

- fixed: §1~§4 전건.
- blocked: 0건.
- unverified: 0건.
- deferred: 시작 카드 범위 0건. 종료 시 비스크립트 엔진 오류 3건은 별도 승리 하이라이트 정리 트랙 소유.
- 통합: 사용자 지시대로 의도적으로 보류. 본 트리 아카무 R5 재이식 착지 확인 후 다시 스냅샷하고 정확 경로로 통합한다.

**최종 판정: 통합 준비 GREEN. 아직 본 트리에는 통합하지 않았다.**
