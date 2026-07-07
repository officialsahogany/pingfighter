# S2 슬라이스 A 코덱스 핸드오프 — 전환 퍽 오퍼 노출 (플래그 게이트, 휴면)

기준 문서: `docs/passive_to_perk_conversion_plan.md` (v3) §5 / §1-8 / D1·D5.
선행: S1 전체 완료 (S1a 휴면 카탈로그 + S1b 값브릿지/플래그 + S1c 게이트 37/37,
전부 미커밋, 플래그 기본 OFF). 지시: "패시브 아이템을 없애고 퍽을 켠다".
발주: 2026-07-07. Claude 기획 → 사용자 직접 Codex 전달 → Claude 적대 리뷰.

## 목표

전환된 **일반 퍽 26종**을 퍽 선택 오퍼 풀에 노출한다. 단, `PerkConversionFlags.
is_enabled()`가 true일 때만 등장하도록 게이트한다. **플래그 기본 OFF이므로
이번 슬라이스 후에도 라이브 게임 규칙은 무변화**(휴면). 효과 게이트(S1c)와
오퍼 노출이 같은 플래그로 묶여 있어, 나중에 플래그를 켜는 순간 "선택지 등장 +
효과 퍽 경로"가 동시에 발동한다.

## 합격 조건

1. 플래그 OFF: 전환 퍽은 어떤 오퍼에도 등장하지 않음 (기존 격리 유지).
2. 플래그 ON: 일반 전환 퍽 26종이 일반 퍽 선택지에 등장, 선택 가능, 중복
   선택 시 레벨업(D: 중복=레벨업), max_level 준수.
3. **신화퍽 11종은 일반 오퍼에서 제외** — 초희귀 등장 채널(§5-4, guaranteed
   상자/보물탐색)은 S5. 이번엔 일반 선택지에 절대 넣지 않음.
4. character_restriction 준수 — `venom_mist_gauntlet`(viper 전용)은 바이퍼
   에게만 등장.

## 범위 (이번 실행)

1. `runtime_perk_catalog.gd` `get_choices()` / `_append_pool_choices()` 경로에
   전환 퍽 풀 주입:
   - `PerkConversionFlags.is_enabled()`가 true일 때만 `CONVERTED_PERKS`(26종)를
     후보에 추가. `CONVERTED_MYTHIC_PERKS`(11종)는 제외.
   - 기존 풀(COMMON/캐릭터)과 동일한 선택 메커니즘을 타게 함: character_restriction
     필터, 중복 dedup, max_level 도달 퍽 제외, 슬롯 예산 로직에 간섭하지 않음
     (unlock_* 5구슬 예산은 별개 — 건드리지 말 것).
2. `apply_choice()` 경로가 전환 퍽 id를 정상 처리하는지 확인·배선:
   - 선택 시 `runtime_skill_levels[perk_id]` 증가, max_level 클램프,
     레벨별 descriptions 반영. (전환 퍽은 이미 `get_perk_data`로 조회 가능 —
     apply_choice가 unknown id로 거부하지 않는지 확인. 거부하면 최소 배선.)
3. 삭제군 8종의 대응 퍽(dash_amplification, common_swiftness, common_bulk_up,
   dash_module_control, dash_lightweight, dash_jump, perk_boost_charge,
   item_cooldown_mastery, common_training, item_bag_expansion)은 **이미 기존
   오퍼 풀에 있음** — 추가 노출 불필요. 건드리지 말 것.

## 범위 제외 (하지 말 것)

- 슬라이스 B(패시브 아이템 획득 경로 제거), 슬라이스 C(플래그 ON)
- 신화퍽 일반 오퍼 노출, 신화퍽 등장 채널(S5)
- 퍽 슬롯 제한(D1=6, S7) — 이번엔 슬롯 상한 로직 미적용, 기존 오퍼 흐름 그대로
- 획득 경로/상자/상점 변경(슬라이스 B), 장비 UI(S3), 마이그레이션(S5)
- 재설계군 4종(gold_bar/sage_ring/sacred_laurel/dowsing_goggles) 관련 퍽
  (대응 퍽 미존재, D-결정 대기 — 오퍼에 넣지 말 것)

## 스모크

### 신설: `godot/tests/perk_conversion_offer_exposure_smoke.gd`
- [ ] 플래그 OFF: 대표 캐릭터(smasher/viper/soldier/commando)에서 `get_choices()`
      결과에 전환 퍽 26종 0건 (기존 격리 유지)
- [ ] 플래그 ON: 반복 호출 누적 시 26종이 등장 가능 (풀 멤버십 결정적 검사
      선호 — 확률 롤 의존 최소화)
- [ ] 플래그 ON: 신화퍽 11종은 일반 `get_choices()`에 0건
- [ ] 플래그 ON: `venom_mist_gauntlet`은 viper에서만 등장, 비-viper 0건
- [ ] apply_choice: 전환 퍽 선택 → 레벨 1, 재선택 → 레벨 2 … max_level에서 상한,
      max 도달 후 오퍼 후보에서 제외
- [ ] 플래그 시작/종료 OFF 복원

### 기존 씰 갱신
- `perk_conversion_catalog_smoke.gd`의 오퍼 격리 어설션을 **flag-OFF 전제로
  명시** (현재는 무조건 격리를 검사 — flag ON에서 등장하는 신동작과 충돌하지
  않도록 OFF 케이스로 한정). 보고서에 명시.

### 회귀 유지
- S1c 게이트 씰(batch1~5) + values/catalog 스모크 GREEN
- 기존 퍽 선택/오퍼 관련 씰 (발견되는 것 전부) GREEN — flag OFF 회귀 증거
- 헤드리스 로드 체크 + 워닝 스캔

## 반증검증 (필수 — git reset/checkout/stash 금지, in-place 토글 + 즉시 복원)

1. 전환 퍽 풀 주입의 flag 게이트를 임시 제거(무조건 노출) → flag-OFF 격리
   레그 RED → 복원
2. 신화퍽 제외 필터를 임시 제거 → "신화퍽 일반 오퍼 0건" 레그 RED → 복원

## 트랩 노트

- 전환 퍽 id = 아이템 id (star_detector 등). 오퍼/apply/HUD 경로에서 id 충돌·
  별칭 문제 없는지 확인 (퍽/아이템 딕셔너리는 네임스페이스 분리 — S1a 확인).
- `_append_pool_choices`가 딕셔너리 딥카피를 반복하면 오퍼 생성이 핫패스는
  아니지만, 전환 풀 추가로 후보 수가 늘어난다 — 기존 패턴 유지, 새 딥카피
  루프 신설 금지.
- 오퍼 노출은 이번 슬라이스의 유일한 변화 — 효과/획득/UI는 후속 슬라이스.
- UTF-8 BOM 금지, `.agents/skills/` 미러 수동 편집 금지.

## 완료 보고 형식

(1) 변경 파일 + 오퍼 주입 지점, (2) apply_choice 전환 퍽 처리 확인 결과
(기존 동작 vs 신규 배선), (3) 신설 스모크 결과 원문 + 격리 씰 갱신 내역,
(4) 반증검증 2건 RED→GREEN 증적, (5) flag OFF 무변화 자가 확인 진술,
(6) 이탈/가정.
