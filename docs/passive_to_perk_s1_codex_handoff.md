# S1a 코덱스 핸드오프 — 퍽 카탈로그 이관 (패시브→퍽 개편)

기준 문서: `docs/passive_to_perk_conversion_plan.md` (v2) — 특히 §3 수치 규칙,
§4-A/4-B 분류표, §7-2/7-3. 이 핸드오프는 §8 S1의 첫 서브슬라이스(S1a)다.
발주: 2026-07-07, Claude 기획 → Codex 배선 → Claude 적대 리뷰 순서.

## 목표

**게임 규칙 무변화(휴면 배선).** 신규 퍽 데이터를 정의하고 다국어 키를 등록하되,
어떤 라이브 오퍼 풀에도 노출되지 않아야 한다. 무결성 스모크로 봉인한다.

## 범위 (S1a — 이번 실행)

1. `godot/scripts/characters/runtime_perk_catalog.gd`에 신규 상수 2개 추가:
   - `CONVERTED_PERKS` — 일반퍽 26종 (계획 문서 §4-A 표 전체)
   - `CONVERTED_MYTHIC_PERKS` — 신화퍽 11종 (§4-B 표 전체)
   - **기존 COMMON_PERKS / 캐릭터 풀에 합치지 말 것** (오퍼 풀 노출 금지가 이번
     슬라이스의 핵심 게이트)
2. 퍽 id = 기존 아이템 id 그대로 사용 (`star_detector`, `adversity_armor`,
   `sensor`, ..., `odins_eye`). 이유: 세이브 마이그레이션 매핑과 아이콘 재사용
   단순화. 퍽/아이템 딕셔너리는 네임스페이스가 분리되어 충돌 없음.
3. 필드 스키마는 기존 퍽과 동일(name, max_level, descriptions{1..N}, detail,
   icon_color, tree) + 신규 필드:
   - 신화퍽 공통: `"rarity": "mythic"`, `"max_level": 1`,
     `"effective_level_exempt": true` (D5 — 유효레벨 보너스 수혜 금지 플래그)
   - 전체 공통: `"conversion_source": "<item_id>"` (마이그레이션/디버그 추적)
   - `venom_mist_gauntlet`: `"character_restriction": "viper"`, tree는 viper
4. 수치: §4-A의 Lv.1→Lv.5 양끝값을 선형 보간(정수 단위 반올림). ★ 4종
   (star_detector / adversity_armor / reinforced_boomerang_gauntlet / sensor)은
   표의 확정 수치 그대로. 신화퍽은 §4-B 고정 수치 1레벨 서술.
5. icon_color: `mythic_item_catalog_build_router.gd`의 해당 아이템 `color`를
   그대로 복사.
6. descriptions / detail 한국어 문구는 기존 COMMON_PERKS 문체(레벨별 숫자
   명시형 한 줄 + detail 한 문장)를 미러.
7. 다국어: `LanguageSettings.localize_perk_data()` 경로 —
   `language_settings_data.gd`의 언어별 퍽 name/summary 맵에 37종 전부 등록.
   지원 언어 전체를 기존 항목과 같은 구조로 채운다. 번역 톤은 기존 항목 미러
   (네이티브 검수는 후속 패스).
8. 오퍼 풀 차단: 신규 퍽은 `get_choices()` / `_append_pool_choices()` /
   instant 경로 어디에도 등장 금지. `get_debug_perk_entries()` 등 디버그 열람
   경로에는 포함 허용.
9. `get_all_perk_data()` / `get_perk_data()`는 신규 퍽을 조회 가능해야 한다
   (S1b+ 슬라이스와 툴링이 사용).

## 범위 제외 (하지 말 것)

- 효과 게이트 전환(S1c), 획득 경로/상자/상점(S2), UI(S3), 세이브 마이그레이션,
  신화퍽 등장 채널(S5)
- `mythic_item_catalog*` 아이템 카탈로그 수정·삭제 금지 (아이템은 이번
  슬라이스 동안 기존 그대로 동작해야 함)
- 4-C 삭제군 8종 / 4-D 재설계군 4종의 퍽 신설 금지 (S0 D-결정 대기).
  예외: `speedgear`(보정제어)는 4-A 소속이므로 포함.

## 스모크 (신설: `godot/tests/perk_conversion_catalog_smoke.gd`)

- [ ] 37종 id 전부 `get_perk_data()` 조회 가능, descriptions 1..max_level 완비
- [ ] 신화퍽 11종: `max_level == 1`, `rarity == "mythic"`,
      `effective_level_exempt == true`
- [ ] 다국어: 지원 언어 각각에서 `localize_perk_data()`가 비어 있지 않은
      name/summary를 반환
- [ ] 오퍼 풀 차단: 대표 캐릭터 2종 이상에서 `get_choices()` 결과에 신규 id
      0건 (풀 멤버십을 직접 검사하는 결정적 방식 선호)
- [ ] 기존 스모크 전체 GREEN 유지 + 리포 표준 헤드리스 로드 체크 통과

## 반증검증 (필수)

**git reset / checkout / stash 절대 금지 — 이 리포는 미커밋 WIP를 대량 보유한다.**
in-place Edit 토글로만 수행하고 즉시 복원한다:

1. 언어 키 1개 임시 제거 → 다국어 레그 RED 확인 → 복원
2. 신규 퍽 1종을 COMMON_PERKS에 임시 병합 → 오퍼 풀 차단 레그 RED 확인 → 복원

## 트랩 노트 (리포 표준 규칙)

- 문구 수정 = 다국어 동기화. grep 0건을 "번역 없음"의 증거로 쓰지 말 것.
- 수치를 소비하는 코드는 이번 슬라이스에 없어야 정상 (데이터만). 소비 헬퍼가
  필요해지면 중단하고 보고 — 그건 S1b 범위다.
- 파일 저장 시 UTF-8 BOM 금지 (PowerShell `Out-File` 기본 인코딩 주의).
- `.agents/skills/` 미러 수동 편집 금지.

## 완료 보고 형식

변경 파일 목록 / 신설·수정 스모크 실행 결과 원문 / 반증검증 2건 각각의
RED→GREEN 증적 / 계획 문서 표 대비 이탈 사항(있다면 사유 포함).
