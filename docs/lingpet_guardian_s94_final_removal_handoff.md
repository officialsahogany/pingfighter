# §9-4 최종 삭제 핸드오프 (Codex 실행용) — 구 포만도·피딩·E/RT 청소 + 대조군 봉인

작성 2026-07-29. 기획 정본 = `docs/lingpet_guardian_duration_redesign_plan.md`
§9-4 (E/RT 트림 범위 기록 있음) + 정산표 D 결정. 선행 = 교감·링코어·칩은
이미 은퇴됨(79413220e·cbc186742). 가드레일·씰 실행 규정 기존과 동일.

**커밋 순서 (고정)**: ①hatch 저장 이전 → ②E/RT 트림 → ③포만도·피딩 제거 →
④영구 수집 표면 정리 → ⑤대조군 씰·문서.

## 0. 착수 전 전수 조사 (필수 선행)

- 삭제 대상 각각에 대해 **소비자·dirty 의존성 전수 조사**를 먼저 수행하고
  보고서에 목록 첨부: 구 식별자 grep(소비자 본문까지 — grep 0건 단정 금지),
  외래 dirty 파일과의 교차(발견 시 해당 헝크만 분리 커밋 or 보류), 씰·
  manifest·preload 참조.
- **이번 슬라이스와 분리(불가침 유지)**: focused/CI 등재·ownership ledger,
  광장 골드+AP 대체 싱크, 심령수 정식 아이콘, 라이브 튜닝(소식가 수치 포함).

## 1. hatch 개성 롤 저장 owner 이전 (커밋 ①)

- `lingpet_hatch_stat_roll_state`의 per-pet 헤드스타트 롤 저장을 affinity
  잔재에서 **정식 owner(buff store 또는 duration/펫 상태 owner 중 자연
  소유자)로 이전**. **직렬화·복원·구 키 관용 파서(읽고 폐기)를 같은 커밋**에
  처리 — 저장 이전과 세이브 왕복이 분리되면 고아 필드가 생긴다.
- 씰: 롤 1회성·저장 왕복·구 키 세이브 로드 시 신 owner로 흡수.

## 2. E/RT 인터랙트 트림 (커밋 ② — 정산 D 결정 이행)

- 제거 (정본 §9-4 기록 범위): `battle_lingpet_interaction_input_router`의
  E/RT 섹션 — `LINGPET_INTERACT_KEY`(E)·`LINGPET_INTERACT_TRIGGER_*`(RT)
  상수·래치·헬퍼·`_handle_companion_interact`·집계 호출 +
  `battle_scene_input_controller`의 `LINGPET_INTERACT_*` 재노출 +
  라우터 owner smoke의 RT 단언.
- **보존 (대조군)**: 우선 컷인 입력·클릭 리액션(코스메틱 — 트리거 입력이
  E였다면 클릭/마우스 경로만 남기고 E 키만 제거인지, 리액션 자체가 E 의존
  인지 먼저 조사해 보고)·L/Shift+L 사이클.

## 3. 구 포만도·피딩 제거 (커밋 ③ — 코드→정의→번역→PNG 역참조 순)

- **코드**: `lingpet_satiety_runtime_state` 및 satiety 별칭 표면(§9-2 B버킷
  추출 원본 — duration 이관이 끝났으므로 은퇴), duration_state에 남은
  satiety 명칭 별칭(SAVE 키 관용 read는 유지 가능하되 쓰기 0), 탈진 Zzz
  렌더 잔재, `character_info_lingpet_satiety_bar_smoke` 명칭 계열 정리.
  소식가(`lingpet_light_eater`)는 **이미 duration 드레인 배율 소비자로
  이관돼 있음** — 삭제 금지, 카탈로그 명칭·설명·툴팁만 지속시간 어휘로
  갱신(수치 하향은 라이브 튜닝 미결 유지).
- **정의**: 피딩 4종 카탈로그 엔트리·차단 마크·feed_controller/bowl 잔재
  (슬라이스 4에서 차단만 한 분기② 완결 — 플라자 참조는 이미 물리 삭제됨).
- **번역**: 포만도·피딩 다국어 키 일괄 (7언어, 키-쌍 삭제).
- **PNG**: 피딩 아이콘 중 apple/melon/기본 3종 + import 삭제.
  **`lingpet_special_feed_icon.png`은 심령수 placeholder로 사용 중 —
  삭제 금지**, 심령수 정식 아이콘 랜딩 시 함께 정리(미결 연동 명시).
- `lingpet_feed_active_item_smoke.gd`: **파일 삭제 금지** (플라자 보류 헝크
  보존) — "구 피딩 식별자 참조 0건" 단언으로 최종 재조준만.

## 4. 영구 수집 표면 정리 (커밋 ④ — 결정 게이트)

- 대상: '하트 공명' 타이틀, 교감 유래 수집/도감 표기 등 영구 표면.
- **권고안으로 구현하되 결정 게이트로 보고**: 수집·정체성용 코스메틱
  표면(타이틀 보유 기록 등)은 **유지**, 교감 수치·성장·"다음 보상" 의미는
  **완전 제거**. 처리한 표면 목록(유지/제거/문구 변경)을 보고서에 게이트
  항목으로 첨부 — 사용자 최종 승인 후 종결.

## 5. 대조군 씰·잔존 참조 0건 (커밋 ⑤)

- **잔존 0건 스윕**: 삭제된 구 식별자(satiety/feed/interact/ring_core/chip/
  affinity 성장 계열)·다국어 키·preload·manifest·씰 참조가 **0건**임을
  전수 grep + 소비자 본문 확인으로 증명하고 보고서에 스윕 결과 첨부.
  (guardian_spirit_rebrand_smoke 등 보류 untracked 파일의 참조는 보류
  목록에 기재만.)
- **대조군 씰 — "삭제됐다"만으로 부족, 보존 3종이 production 경로에서
  계속 동작함을 각각 증명**:
  1. 컷인 우선 입력: 실 입력 라우터 체인 관통으로 부화 컷인 중 입력
     스왈로우 동작.
  2. 클릭 리액션: 실 클릭 경로로 리액션 재생.
  3. L/Shift+L 사이클: 실 키 이벤트로 슬롯 순환(정/역).
  각각 반증 1회(보존 경로를 토글로 끊어 RED 확인 후 원복).
- 헤드리스 로드·경고 스캔 GREEN, 기존 기준선 악화 금지.
- 문서: 정본 §9-4 완료 표기용 소재(삭제 목록·게이트 결과)를 보고서에 정리
  (정본 갱신 자체는 Claude 검수 시 수행).

## 6. 보고 형식

커밋 해시별 요약 / §0 전수 조사 목록 / 씰 원문·반증 / §4 게이트 표면 목록
(유지·제거·변경) / §5 잔존 0건 스윕 결과 / 보류 연동 항목(special 아이콘 등)
/ 미결·발견 사항.
