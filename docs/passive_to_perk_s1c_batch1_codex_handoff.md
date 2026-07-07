# S1c 배치① 코덱스 핸드오프 — 순수 스탯 게터 11종 효과 게이트 전환

기준 문서: `docs/passive_to_perk_conversion_plan.md` (v3 — S0 결정 확정 반영)
§4-A / §7-2 (S1c 소비자 계약 포함).
선행: S1a(휴면 카탈로그 37종) + S1b(`perk_conversion_flags.gd` 기본 OFF,
`perk_conversion_values.gd` 값 테이블/exempt 헬퍼) 완료, 둘 다 적대 리뷰 PASS.
발주: 2026-07-07. Claude 기획 → 사용자 직접 Codex 전달 → Claude 적대 리뷰.

## 합격 조건

1. **플래그 OFF(기본값)에서 게임 규칙 완전 무변화** — 기존 장착 아이템 경로
   그대로.
2. **플래그 ON에서 배치① 11종의 효과가 퍽 경로로 완전 대체** — 아이템 장착
   상태 무시, 퍽 레벨만 읽음.
3. 라이브 기본 상태(OFF)는 이번 배치 후에도 변하지 않는다 — ON은 테스트/디버그
   전용 (라이브 전환 스위치는 S2~S5 릴리즈 묶음에서 켠다).

## 배치① 대상 11종 (전부 비-exempt 일반퍽, 위험도 하)

| perk_id | 효과 | 값 key |
|---|---|---|
| star_detector | 스타포인트 보너스 드랍 | star_bonus_pct |
| dowsing_pendulum | 필드 아이템 끌어당김 범위 | attraction_range |
| chargebag | 벽 반사 게이지 | chargebag_pct |
| battery | 스테이지 전환 게이지 보존 | gauge_preserve_pct |
| gold_digger | 골드 획득량 | gold_bonus_pct |
| lucky_coin | 아이템 더블스폰 확률 | double_spawn_pct |
| fuel_pouch | 최대 게이지 | fuel_bonus_flat |
| bluetooth_ring | 히트 게이지 획득 | gauge_gain_pct |
| knee_pads | 하프대쉬 게이지 | knee_charge_pct |
| bulletproof_hat | 스턴 저항 | stun_resist_pct |
| spiked_helmet | 넉백 저항 | knockback_resist_pct |

(gravitybelt / speedgear는 조작 특성 변경이라 배치③으로 이월 — 이번에 금지.)

## 게이트 의미론 (전 배치 공통 — 이번에 확정 구현)

```
효과 수치 소스:
  flag OFF → 기존 경로 그대로 (장착 아이템 + 롤/폴리시/강화 합성값)
  flag ON  → level := <공용 브릿지>(perk_id)   # 유효레벨 포함, exempt 준수
             level <= 0 → 미장착과 동일한 기본값/비활성  ← 보유 게이트 필수
             level >  0 → PerkConversionValues.get_value(perk_id, key, level)
```

- **완전 대체 의미론**: ON일 때 장착 아이템은 이 11종 효과에 아무 기여도 하지
  않는다. `max(아이템, 퍽)` 합성 금지 — 이중 이득 버그의 근원. (장착 아이템의
  퍽화 보상은 S5 마이그레이션의 몫.)
- **보유 게이트 계약 (§7-2)**: `get_value()`는 레벨 0에도 Lv.1 값을 반환
  (clamp)하므로, 반드시 레벨 > 0 확인 후에만 호출한다.
- **공용 브릿지 1개 신설**: 배치②~⑤가 재사용할 단일 함수 — 예:
  `runtime_perk_state.get_converted_perk_effect_level(perk_id) -> int`
  (내부에서 base 레벨 + 유효레벨 보너스를
  `PerkConversionValues.get_effective_converted_perk_level()`로 합성, exempt
  자동 준수). 11개 게터가 각자 base/bonus를 재조립하지 말 것 — 단일 헬퍼 경로
  규칙.

## 범위 (이번 실행)

1. 위 공용 브릿지 함수 1개 신설.
2. 배치① 11종 각각의 **단일 소스 게터**(예:
   `mythic_item_runtime.get_star_detector_star_bonus_pct()`)에 플래그 분기
   삽입. 게터가 여러 개인 아이템(초 단위/프레임 단위 파생 게터 등)은 원천
   게터 한 곳에만 분기하고 파생은 그 위에 얹는다.
3. **우회 경로 전수 감사 (이 리포의 고전 트랩)**: 각 아이템에 대해 게터를
   거치지 않고 장착 상태·롤값을 직접 읽는 소비자를 grep으로 찾아 보고한다
   (`mythic_item_roll_query` 직접 호출, `is_*_equipped` 직접 게이트, owner
   필드 직접 읽기 등). 발견 시: 게임플레이 수치 소비자는 단일 게터로 수렴
   시키되, **장비 UI/툴팁/장착 비주얼 소비자는 건드리지 않고 목록만 보고**
   (S3/D4 영역).
4. 스모크 신설 + 기존 씰 1곳 의도적 갱신 (아래).

## 범위 제외 (하지 말 것)

- 배치②~⑤ 아이템(수리공망치·뉴럴헬멧·코만도암·부메랑장인·역경·파편·센서·
  소울버스트·무지개장갑·독안개·gravitybelt·speedgear·윤회·반칙호루라기·
  스마트폰·신화 12종)의 게이트 전환
- 획득 경로/상자/상점(S2), 장비 UI·툴팁·외형(S3/D4), 세이브 마이그레이션(S5),
  오퍼 풀 노출(신규 퍽은 계속 휴면), 퍽 슬롯 제한(S7)
- 라이브 코드에서 플래그를 ON으로 켜는 어떤 경로도 추가 금지

## 스모크

### 신설: `godot/tests/perk_conversion_gate_batch1_smoke.gd`
- [ ] **OFF-parity**: 11종 전부, 아이템 장착 픽스처에서 플래그 OFF 결과 ==
      게이트 삽입 전과 동일한 합성값 (롤 픽스처 명시)
- [ ] **ON + 퍽 레벨 n**: 11종 전부 Lv.1과 Lv.5에서 값 테이블 수치 정확 반환
- [ ] **ON + 퍽 레벨 0**: 미장착과 동일한 기본값/비활성 (보유 게이트 봉인 —
      Lv.1 값 누수 없음)
- [ ] **ON + 아이템만 장착(퍽 0)**: 효과 없음 (완전 대체 의미론 봉인)
- [ ] **ON + 유효레벨 보너스**: base 3 + bonus 2 → Lv.5 값 (브릿지의 유효레벨
      합성 검증)
- [ ] 스모크 시작/종료 시 플래그를 OFF로 복원 (S1b 스모크의 static 리셋 관례)

### 기존 씰 의도적 갱신: `perk_conversion_values_smoke.gd`
무변화 레그(`_verify_flag_toggle_does_not_change_existing_runtime`)의 픽스처에
star_detector가 포함되어 있어, 이번 게이트 전환으로 **이 레그는 설계대로
RED가 된다** (봉인이 작동한 것). 처리: star_detector를 그 레그에서 제거하고
신설 게이트 스모크로 이관, **sensor / adversity_armor /
reinforced_boomerang_gauntlet 3종의 OFF/ON parity는 유지** — 이들이 아직
미전환임을 계속 봉인하는 역할. 이 갱신을 보고서에 명시할 것 (무단 삭제 아님).

### 회귀 유지
- `perk_conversion_catalog_smoke.gd` (오퍼 격리) GREEN 유지
- 배치① 아이템들의 기존 포트 스모크(예: `star_detector_port_smoke.gd` 등
  발견되는 것 전부) GREEN 유지 — 이들은 OFF 경로 회귀 증거
- 리포 표준 헤드리스 로드 체크 + 워닝 스캔

## 반증검증 (필수 — git reset/checkout/stash 금지, in-place 토글만 + 즉시 복원)

1. ON 경로에서 레벨>0 보유 게이트를 임시 제거 → "ON+레벨0" 레그가 Lv.1 값
   누수로 RED → 복원
2. 11종 중 1종의 OFF 분기를 임시로 퍽 경로로 강제 → OFF-parity 레그 RED → 복원

## 트랩 노트

- 게터는 핫패스일 수 있다 — 분기에서 딕셔너리 재구성/딥카피 금지, 값 조회는
  이미 O(1).
- 단일 헬퍼 경로: 레벨 산출은 신설 브릿지 함수만. 게터마다 base/bonus 재조립
  금지.
- `owner.set()` 스키마 트랩: 신규 owner 키가 필요해 보이면 중단하고 보고
  (배치①에서는 원칙적으로 불필요).
- UTF-8 BOM 금지, `.agents/skills/` 미러 수동 편집 금지.

## 완료 보고 형식

(1) 변경 파일 + 아이템별 게이트 삽입 지점(게터명) 목록, (2) 우회 경로 감사
결과(발견 목록 + 수렴/보고 구분), (3) 신설 스모크 실행 결과 원문 + 기존 씰
갱신 내역, (4) 반증검증 2건 RED→GREEN 증적, (5) OFF 기본 상태 무변화 자가
확인 진술, (6) 이탈/가정 사항.
