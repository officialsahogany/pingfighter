# S1c 배치② 코덱스 핸드오프 — 액티브 아이템 강화군 4종 효과 게이트 전환

기준 문서: `docs/passive_to_perk_conversion_plan.md` (v3) §4-A / §7-2.
선행: S1a/S1b + **S1c 배치① PASS** (`docs/passive_to_perk_s1c_batch1_codex_handoff.md`
— 공용 브릿지 `runtime_perk_state.get_converted_perk_effect_level()` +
`mythic_item_runtime.get_converted_perk_effect_level()` facade + 게이트 패턴 확립).
발주: 2026-07-07. Claude 기획 → 사용자 직접 Codex 전달 → Claude 적대 리뷰.

## 합격 조건 (배치①과 동일)

1. 플래그 OFF(기본)에서 게임 규칙 완전 무변화.
2. 플래그 ON에서 배치② 4종의 효과가 퍽 경로로 완전 대체 (아이템 장착 무시).
3. 라이브 기본 상태는 OFF 유지.

## 배치② 대상 4종 (전부 비-exempt 일반퍽 — 대상이 액티브 아이템인 강화 퍽)

| perk_id | 효과 | 값 key |
|---|---|---|
| master (수리공망치) | 벽돌 길이 / 액티브 쿨타임 / 벽돌 스폰율 | wall_length_pct, item_cooldown_pct, wall_spawn_bonus_pct |
| neural_helmet (뉴럴헬멧) | AI알약 게이지 절감 / 스폰율 / **방향키 즉시 해제(거동)** | aipill_gauge_reduction, aipill_spawn_bonus_pct |
| commando_arm (코만도암) | 투척 속도 / 폭발 범위 / 연막 지속 / 준비시간 단축 | throw_speed_pct, explosion_range_pct, smoke_duration_pct, prep_reduction_pct |
| reinforced_boomerang_gauntlet (부메랑장인) | 부메랑 5레인 + **메탈 부메랑 변형(거동+시각 상태)** | boomerang_knockback_pct, boomerang_stun_pct, boomerang_launch_speed_pct, boomerang_homing_pct, boomerang_spawn_bonus_pct |

## 게이트 의미론 — 이번 배치의 신규 패턴: 불리언 효과 게이트

수치 게터는 배치① 패턴 그대로:

```
flag OFF → 기존 경로 (장착 + 롤 합성)
flag ON  → level := facade(perk_id); level<=0 → 비활성 / level>0 → get_value(...)
```

**신규**: 이 4종은 수치 외에 **on/off 거동 상태**를 갖는다 — 메탈 부메랑 변형
여부, AI알약 방향키 해제 가능 여부, (해당 시) 코만도암 투척 보조 활성 여부.
이런 상태는 지금까지 `is_*_equipped()`로 게이트되어 왔다. 전환 규칙:

```
효과-활성 게이트 (거동/발사체/판정/발사체 시각 상태):
  flag OFF → is_*_equipped() (기존 그대로)
  flag ON  → facade 레벨 > 0
```

- 아이템별로 단일 `is_*_effect_active()`류 헬퍼 하나에 위 분기를 넣고, 거동
  소비자들은 전부 그 헬퍼로 수렴시킨다 (게터 단일 소스 원칙의 불리언판).
- **장비 UI/장비 패널/스냅샷의 `*_equipped` 노출은 장착 의미 그대로 유지**
  (배치① 선례 — S3 영역). 단, 소비자를 분류해서 보고할 것: 발사체 렌더 /
  거동 게이트 = 효과-활성 헬퍼로 전환, 장비 표시 = 유지.

## 범위 (이번 실행)

1. 4종의 수치 게터 게이트 전환 (배치① 패턴).
2. 불리언 효과-활성 헬퍼 신설 + 거동 소비자 수렴:
   - 부메랑장인: 메탈 부메랑 변형 조건 (발사체 거동·넉백/스턴 강화 볼·인게임
     발사체 렌더·활성 슬롯 아이콘 변형 조건까지 — 아래 트랩 노트 참조)
   - 뉴럴헬멧: 방향키 즉시 해제 거동 게이트
   - 코만도암/수리공망치: 장착 불리언을 거동 게이트로 쓰는 소비자가 있으면 동일 전환
3. **우회 경로 전수 감사** (배치①과 동일 요구): 4종 각각, 게터/효과-활성
   헬퍼를 거치지 않고 장착 상태·롤값을 직접 읽는 소비자를 grep으로 찾아
   전환/유지 분류와 함께 보고. 특히:
   - 스폰 가중치 소비처: `wall_spawn_bonus_pct` / `aipill_spawn_bonus_pct` /
     `boomerang_spawn_bonus_pct`가 필드 스폰 스케줄러/풀에서 어떤 경로로
     읽히는지 (owner 키 경유면 owner_syncer가 게터를 쓰므로 자동 전파 — 확인만)
   - 액티브 쿨타임 소비처: `item_cooldown_pct`가 슬롯 컨트롤러에 닿는 경로
   - 코만도암: 수류탄/조명탄/화염병 속도·폭발, 연막탄 지속, 다이너마이트/
     바나나/비누/부메랑 준비시간 — 투척 헬퍼별 소비 지점 열거
4. 스모크 신설 + 기존 씰 의도적 갱신 (아래).

## 범위 제외 (하지 말 것)

- 배치③(역경·파편·센서·소울버스트·무지개장갑·독안개·gravitybelt·speedgear)
  ④(윤회·반칙호루라기·스마트폰) ⑤(신화 12종)의 게이트 전환
- **sensor / adversity_armor의 values_smoke parity 레그는 유지** (배치③ 안전망)
- 획득 경로/상자/상점(S2), 장비 패널·TAB 장비 표시(S3), 세이브 마이그레이션(S5),
  오퍼 노출, 라이브 플래그 ON
- 부메랑 액티브 아이템 자체의 로직 리팩터링 (게이트 전환만)

## 스모크

### 신설: `godot/tests/perk_conversion_gate_batch2_smoke.gd`
- [ ] OFF-parity: 4종 전부, 장착+롤 픽스처에서 게이트 전 결과와 동일
- [ ] ON Lv1/Lv5: 전 값 레인 테이블 수치 정확
- [ ] ON 레벨 0 / ON item-only: 비활성 (수치 + **불리언 효과 게이트 양쪽** —
      item-only일 때 메탈 변형·방향키 해제도 꺼져야 함)
- [ ] ON item+perk: 완전 대체 (고롤 아이템 값이 아닌 테이블 값)
- [ ] **불리언 게이트 양방향**: ON+퍽만 보유 → 메탈 부메랑 변형 활성·방향키
      해제 활성 / OFF+장착 → 기존대로 활성
- [ ] 실 파생 소비자 레그 최소 각 1개: 투척 헬퍼 수치 적용, 스폰 가중치,
      쿨타임 적용, 부메랑 발사/귀환 경로의 메탈 분기
- [ ] 플래그 시작/종료 OFF 복원

### 기존 씰 의도적 갱신: `perk_conversion_values_smoke.gd`
parity fixture에서 **reinforced_boomerang_gauntlet 제거** → 신설 배치② 스모크로
이관. **sensor / adversity_armor 2종은 유지** (미전환 봉인). 보고서에 명시.

### 회귀 유지
- 배치① 씰(`perk_conversion_gate_batch1_smoke.gd`) + catalog/values 스모크 GREEN
- 4종 관련 기존 포트/아이템 스모크 (부메랑·AI알약·벽돌·투척류·코만도암 계열 —
  발견되는 것 전부) GREEN — OFF 경로 회귀 증거
- 헤드리스 로드 체크 + 워닝 스캔

## 반증검증 (필수 — git reset/checkout/stash 금지, in-place 토글 + 즉시 복원)

1. 불리언 효과 게이트 1곳(메탈 부메랑)의 ON 분기를 임시로 `is_equipped`로
   되돌림 → "ON+퍽만 보유 → 메탈 활성" 레그 RED → 복원
2. 4종 중 1종의 OFF 분기를 퍽 경로로 강제 → OFF-parity RED → 복원

## 트랩 노트

- **상태 의존 아이콘 변형 3점 세트** (item_runtime_checklist §0.2 부메랑 항목):
  메탈 부메랑은 (1) 획득 시점 아이콘 선택, (2) 장착 변경 시 핫스왑,
  (3) 아이덴티티 키 스케일 캐시의 3점이 함께 묶인 패턴이다. Godot 포트에서
  이 3점이 어디에 구현돼 있는지 먼저 찾고, 변형 **조건**만 효과-활성 헬퍼로
  바꿔라 — 스왑/캐시 메커니즘 자체는 건드리지 않는다. 캐시가 name-key면
  ON/OFF 토글로 아이콘이 안 바뀌는 잠복 버그가 있는지 확인만 하고 보고
  (수정은 범위 밖, 단 발견 시 명시).
- **뉴럴헬멧 프레임 타이밍 트랩** (checklist §0.2): 레거시에서 스폰 배율/
  방향키 해제가 module-global 재설정 윈도우에 물려 간헐 실패한 전례가 있다.
  Godot 소비 경로가 per-frame 게터 직독인지 확인하고, owner 키 캐시 경유면
  sync 타이밍에 ON 전환값이 늦게 반영되는 창이 없는지 점검.
- 투척류 소비처는 넓다 — grep은 `commando_arm` 상수/게터명 기준으로 하되,
  개별 투척 헬퍼(`active_item_throw_*`) 안에 하드코딩 우회가 없는지 본다.
- 핫패스 딥카피 금지, 신규 owner 키 필요 시 중단·보고, UTF-8 BOM 금지,
  `.agents/skills/` 미러 수동 편집 금지.

## 완료 보고 형식

(1) 변경 파일 + 아이템별 게이트 지점(수치 게터/불리언 헬퍼) 목록,
(2) 우회 경로 감사 결과 (전환 vs 유지 분류, 스폰 가중치·쿨타임·투척 헬퍼
소비 지점 열거), (3) 신설 스모크 결과 원문 + values_smoke 갱신 내역,
(4) 반증검증 2건 RED→GREEN 증적, (5) OFF 무변화 자가 확인 진술,
(6) 아이콘 3점 세트 소재 파악 결과 + 잠복 버그 발견 시 명시, (7) 이탈/가정.
