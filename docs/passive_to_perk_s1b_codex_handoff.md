# S1b 코덱스 핸드오프 — 수치 브릿지 헬퍼 + 전환 플래그 (패시브→퍽 개편)

기준 문서: `docs/passive_to_perk_conversion_plan.md` (v2) §3/§4/§7-2/§7-4.
선행 슬라이스: S1a 완료 (`docs/passive_to_perk_s1_codex_handoff.md` — 휴면
카탈로그 37종 + 다국어 + `perk_conversion_catalog_smoke.gd`, 적대 리뷰 PASS).
발주: 2026-07-07. Claude 기획 → Codex 배선 → Claude 적대 리뷰.

## 합격 조건 (최우선)

**S1b 완료 후에도 게임 규칙 변화가 전혀 없어야 한다.** 이번 슬라이스는 데이터
테이블 + 순수 조회 헬퍼 + 기본 OFF 플래그만 추가한다. 어떤 기존 런타임 경로도
새 헬퍼를 소비하지 않는다 (소비 배선은 S1c).

## 범위 (S1b — 이번 실행)

1. **전환 플래그** — 신규 `godot/scripts/characters/perk_conversion_flags.gd`:
   - `is_enabled() -> bool`, 기본값 **false**. 테스트/디버그용
     `debug_set_enabled(value)` 토글 제공 (리포의 debug_set_* 관례).
   - 이번 슬라이스에서 이 플래그를 읽는 라이브 코드는 없어야 정상 —
     S1c+ 소비 예정의 단일 스위치를 미리 세워두는 것.
2. **수치 값 테이블 + 조회 헬퍼** — 신규
   `godot/scripts/characters/perk_conversion_values.gd`:
   - 일반퍽 26종: `{perk_id: {value_key: [Lv1..Lv5 값 배열]}}`. 계획 문서 §4-A
     Lv.1→Lv.5 양끝값 선형 보간(S1a descriptions와 동일 수치). 배열 길이 ==
     해당 퍽 max_level.
   - 신화퍽 11종: `{perk_id: {value_key: 고정값}}` (§4-B).
   - value_key는 기존 롤옵션 key를 재사용
     (`mythic_item_catalog_roll_definitions.gd`의 key — 예:
     `star_bonus_pct`, `trigger_chance_pct`, `invincible_duration_sec`).
     신규 레인(부메랑 넉백/스턴, sensor 토큰 수)은 명명 일관성을 지켜 신설
     (예: `boomerang_knockback_pct`, `boomerang_stun_pct`,
     `auto_dash_token_count`, `auto_dash_cooldown_sec`).
   - API: `get_value(perk_id: String, key: String, level: int) -> float`
     (레벨 범위 밖은 clamp), `get_mythic_value(perk_id, key) -> float`,
     `has_perk(perk_id) -> bool`, `get_value_keys(perk_id) -> Array`.
   - 순수 데이터 조회만 — owner/registry 접근 금지.
3. **유효레벨 exempt 헬퍼** — 기존 유효레벨 체인(현자의 반지/초월자의 관
   아이템이 퍽 유효레벨을 올리는 경로)을 찾아, **기존 함수는 수정하지 말고**
   신규 함수만 추가:
   `get_effective_converted_perk_level(perk_id, base_level, bonus) -> int` —
   카탈로그의 `effective_level_exempt == true`(신화퍽)면 bonus 미적용,
   아니면 기존 체인과 같은 규칙으로 합산 + max 정책 준수(계획 §1 유효레벨
   오버플로우 opt-out 원칙). 위치는 값 헬퍼 또는 기존 유효레벨 소유 모듈 중
   더 자연스러운 쪽 — 단, 기존 소비자 동작 무변경이 원칙.
4. **conversion_source → 퍽 id 매핑 확정** — 값 헬퍼 파일에 상수로:
   - `CONVERSION_SOURCE_TO_PERK` — 치환군 37종. S1a에서 퍽 id == 아이템 id로
     확정했으므로 항등 매핑을 명시적 상수로 고정 (S5 마이그레이션과 툴링의
     단일 소스).
   - `DELETED_ITEM_COMPENSATION` — 삭제군 8종 → 기존 퍽 id 배열 (계획 §7-4):
     `dashholder→[dash_amplification]`, `speedboots→[common_swiftness]`,
     `bulkup→[common_bulk_up]`, `spikeboots→[dash_module_control,
     dash_lightweight]`, `dashgear→[dash_jump, perk_boost_charge]`,
     `cooltime→[item_cooldown_mastery]`, `timer_belt→[common_training]`,
     `slot_add→[item_bag_expansion]`.
   - 재설계군 4종(gold_bar/sage_ring/sacred_laurel/dowsing_goggles)은 매핑에
     넣지 말고 주석으로 `S0 D-결정 대기` 표기.

## 범위 제외 (하지 말 것)

- 실제 패시브 장비 효과를 퍽 효과로 교체 (S1c)
- 필드/상점/상자/판도라 보상 경로 변경 (S2)
- 장비 UI 숨김 (S3), 세이브 마이그레이션 실행 (S5), 퍽 슬롯 제한, D4 외형
- 기존 유효레벨 함수·기존 이펙트 모듈·아이템 카탈로그 수정
- 신규 퍽의 오퍼/보상/상점/필드 노출 (S1a 격리 유지)

## 스모크 (신설: `godot/tests/perk_conversion_values_smoke.gd`)

- [ ] CONVERTED_PERKS 26종 전부 값 테이블 보유, 각 value_key 배열 길이 ==
      max_level, 방향 단조성(증가 레인은 비감소, reverse 레인은 비증가 —
      sensor 토큰 [1,1,2,2,2] 같은 계단 허용)
- [ ] ★4종 endpoint 정합: star_detector [5..25] / adversity_armor 발동
      [20..40]·보호 [5..15] / reinforced_boomerang_gauntlet 넉백 [20..50]·
      스턴 [20..80]·발사속도 [15..50]·유도 [10..50]·스폰 [50..200] /
      sensor 토큰 [1..2]·쿨 [30..15]
- [ ] 신화퍽 11종 고정값 존재 + `get_effective_converted_perk_level`이
      exempt 퍽에 bonus를 무시 (bonus 2를 줘도 레벨 1 유지)
- [ ] 비-exempt 일반퍽은 bonus 합산이 기존 유효레벨 규칙과 일치
- [ ] 플래그 기본값 OFF + debug 토글 왕복 동작
- [ ] flag OFF 상태에서 기존 런타임 무변화의 실증: S1a
      `perk_conversion_catalog_smoke.gd`(오퍼 격리 포함)와 기존 스모크 대표
      2종 이상(예: `localization_coverage_smoke.gd` + 패시브 효과 관련 기존
      스모크 1종) GREEN 유지
- [ ] 리포 표준 헤드리스 로드 체크 + 워닝 스캔 통과

## 반증검증 (필수)

**git reset / checkout / stash 절대 금지 — 미커밋 WIP 보유 리포.**
in-place Edit 토글로만, 즉시 복원:

1. 값 테이블에서 ★1종의 Lv5 endpoint를 틀린 값으로 임시 변경 → endpoint
   레그 RED → 복원
2. exempt 분기 임시 제거(또는 상시 bonus 적용으로 토글) → 신화퍽 exempt 레그
   RED → 복원

## 트랩 노트

- **단일 헬퍼 경로**: 이 값 테이블이 이후 게임플레이·툴팁·프리뷰의 유일한
  수치 소스가 된다. S1a descriptions 텍스트와 수치가 어긋나면 안 됨 —
  어긋남을 발견하면 값 테이블이 아니라 descriptions 쪽 오타를 의심하고
  보고에 명시.
- 퍽 데이터 상수는 순수 리터럴 유지, 핫패스 딥카피 금지 (per-frame 소비는
  S1c 이후 문제지만 API를 read-only 참조 반환으로 설계).
- UTF-8 BOM 금지, `.agents/skills/` 미러 수동 편집 금지.

## 완료 보고 형식

변경/신설 파일 목록 / 스모크 실행 결과 원문 / 반증검증 2건 RED→GREEN 증적 /
계획 문서 대비 이탈 사항(value_key 명명 포함) / "게임 규칙 무변화" 합격 조건
자가 확인 진술.
