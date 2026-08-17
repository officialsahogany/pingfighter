# 탑 flow owner 분할 리팩토링 /goal 지시문 (2026-08-18)

- **목적**: `tower_ascent_flow_owner.gd`(2,122줄)를 저장소 오너 모듈 규율대로
  더 작은 안정 오너들로 분할한다. **행동 보존 리팩토링** — 기능·수치·표면
  변화 0이 절대 계약이다.
- **완료 보고**: `docs/tower_ascent_flow_owner_refactor_report.md`. 푸시 금지.

## 1. 분할 원칙

- 분할 경계는 실측으로 판단하되 자연 후보: 지도·경로 상태(그래프 소비·후보·
  이동), 노드 모달 진행(액션·트랜잭션 위임), 엔딩·결산 진행(9층 판정·선택·
  진엔딩), 연전 진행, 경제 위임(무혼·골드·보석 접근). 이미 분리된 모듈
  (record_store·settlement_state·gauntlet_state·노드 모듈들)은 유지하고
  중복 신설하지 않는다.
- **공개 API 시그니처 유지**: 페이즈 D 보고서 §7이 인계한 API
  (`begin_floor_nine_resolution`, `resolve_gauntlet_victory`,
  `begin_floor_twelve_true_ending`, `resolve_defeat`/결산, `collect_muhon` 등)와
  기존 소비자(`battle_scene_match_flow_driver`, 렌더러, 스모크)의 호출 계약을
  깨지 않는다. flow owner는 파사드로 남아 위임해도 된다.
- **스냅샷 스키마 불변**: `SNAPSHOT_SCHEMA_VERSION` 유지, 직렬화 왕복 동일성
  스모크 GREEN 필수.
- **씰 무개정 원칙**: 기존 씰의 단언은 바꾸지 않는다. 전 씰이 그대로 GREEN인
  것이 행동 보존의 증명이다. 허용 예외는 preload 경로·모듈 참조 갱신뿐이며,
  그 목록을 보고서에 기재한다.
- 신규 모듈은 `scripts/tower_ascent/` 아래, `.gd.uid` 동반, 소유권 이동은
  `docs/godot_module_ownership_ledger.md`·아키텍처 문서에 기록.

## 2. 겸사 정리 (같은 목표 안 별도 커밋)

- `tower_ascent_tuning.gd`의 도달 불가 사문 4항목
  (`TEMP_BOSS_STANDIN_BY_SLOT`의 molewang·arachne·teddy_bear·alice — 통합으로
  레지스트리 자체 라우팅이 우선해 소비되지 않음) 제거 + 표 주석 정리.
- 제거가 실제로 무해함을 보스 레지스트리·12층 지도 스모크로 재확인.

## 3. 검증·커밋 규율

- 단계별 분리 커밋(모듈 추출 단위), 한국어 커밋 제목. 커밋마다 관련 스모크 +
  `-Paths` 경고 + 헤드리스 + diff check.
- **최종 게이트**: 타워 전 스모크(30종+) + 기존 소비자 8종 + 플래그 OFF 무손상
  + Vulkan 비주얼 QA 래퍼 재실행(슬라이스·페이즈 C 노드·페이즈 D 6장 — 렌더
  불변 확인) 전부 GREEN.
- GRT-003(핫패스 lazy init 금지)·GRT-042(프리웜 경량화) 계약 유지 — 분할로
  콜드 생성 지점이 옮겨지지 않게 프리웜 경로를 함께 검증.
- 다른 도메인 파일·잔여 WIP 무접촉. 밸런스·기능 추가 금지.
- 판정 불가 지점(API를 깨야만 분할 가능한 경우 등)이 나오면 완료 처리하지
  말고 중단·보고.

**완료 선언 조건**: 분할 착지 + §3 최종 게이트 전부 GREEN(등록 baseline 제외
blocked/unverified 0건) + flow owner 본체가 목표 규모(파사드 수준, 500줄 이하
권장 — 미달 시 사유 보고)로 축소 + 보고서 완성. 이후 Claude(Fable)가 검증한다.
