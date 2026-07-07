# S2 슬라이스 B 코덱스 핸드오프 — 패시브 아이템 인런 획득 경로 제거 (플래그 게이트, 휴면)

기준 문서: `docs/passive_to_perk_conversion_plan.md` (v3) §5-1~5-5 / §1-8.
선행: S1+S2a 커밋 완료(`3848b595e`, 휴면·플래그 OFF). S2a로 전환 퍽 26종이
플래그 ON 시 오퍼에 노출됨. 지시: "패시브 아이템을 없앤다".
발주: 2026-07-07. Claude 기획 → 사용자 직접 Codex 전달 → Claude 적대 리뷰.

## 목표

플레이어가 **런 중 패시브 아이템을 획득하는 4개 경로**를 제거한다. 단
`PerkConversionFlags.is_enabled()`가 true일 때만 제거되도록 게이트한다.
**플래그 기본 OFF이므로 이번 슬라이스 후에도 라이브 무변화**(휴면). S2a(오퍼
노출) + 슬라이스 B(패시브 제거)가 함께 플래그 뒤에 쌓이면, 슬라이스 C에서
플래그를 켜는 순간 "패시브 사라짐 + 퍽 등장 + 효과 퍽 경로"가 동시 발동한다.

## 합격 조건

1. 플래그 OFF: 4개 경로 모두 기존 그대로 (패시브 정상 배출).
2. 플래그 ON: 아래 4개 경로 어디서도 패시브 아이템이 플레이어에게 도달하지
   않음. 액티브 아이템 배출은 정상 유지.
3. 배출 분포가 깨지지 않음 — 패시브 몫은 **스타포인트로 흡수**(신규 reward
   type 불필요; 스타포인트는 퍽 재화라 "퍽 진행으로 대체"가 자연스러움).

## 대상 4경로 + 게이트 방침

| 경로 | 파일 | 게이트 방침 |
|---|---|---|
| ① 필드 스폰 | `active_item_field_spawn_pool.gd` (`build_spawn_candidates` / 패시브 후보 진입 지점) | 플래그 ON이면 패시브 분류 후보를 스폰 후보에서 제외 → 필드는 액티브 전용. (§5-1 목표 + 오버클럭 보스 아이템의 선행 조건) |
| ② 스테이지클리어 상자 | `stage_clear_reward_resolver.gd` | 플래그 ON이면 `_resolve_normal_box_reward_type` / `_resolve_advanced_box_reward_type`가 REWARD_PASSIVE로 귀결될 때 **스타포인트 보상으로 대체**(normal=SP1, advanced=SP2 권장). 가중치 상수는 건드리지 말고 해석 지점에서 리다이렉트 |
| ③ 판도라 | `pandora_legacy_pool_builder.gd::build_passive_pool` + 선택 빌더 | 플래그 ON이면 패시브 풀 empty. 판도라 3택은 액티브/신화 풀에서만 구성. 선택 빌더가 패시브 empty를 graceful 처리하는지(후보 부족 시 폴백) 확인 |
| ④ 보물탐색 | `treasure_hunt_runtime.gd` (instant_treasure_hunt 결과 테이블) | 플래그 ON이면 "패시브 아이템" 결과(기존 60%)를 스타포인트(또는 액티브)로 리다이렉트. 신화 결과 분기는 유지 |

## 범위 (이번 실행)

1. 위 4경로에 플래그 게이트 삽입. OFF = 원문 경로, ON = 패시브 제거 + 지정
   대체(스타포인트/empty).
2. "패시브 분류" 판정은 기존 판정을 재사용 — 새 분류 로직 신설 금지
   (`pandora_legacy_pool_builder`의 `PASSIVE_ITEM_NAMES` / `type == "passive"`
   같은 기존 판정, reward resolver의 `_get_item_group` == REWARD_PASSIVE 등).
3. 삭제군/재설계군 포함 **모든** 패시브가 대상 — speedboots·dashholder 등
   삭제군, sage_ring·gold_bar 등 재설계군, star_detector 등 치환군 전부.
   (치환군은 S2a로 퍽 오퍼에 있으니 아이템으로는 사라지는 게 맞고, 삭제·
   재설계군은 대응 퍽/재설계 전까지 잠시 효과 소멸 — 계획 §S2 확정 사항)

## 범위 제외 (하지 말 것)

- **슬라이스 B2(플라자 상점 `plaza_shop_stock.gd` 패시브 제거 + §5-7 가격
  재편)** — 별도 슬라이스. 이번엔 상점 안 건드림 (플래그 ON이어도 상점은
  잠시 패시브 진열 잔존 = 알려진 후속 정리 항목, 크래시 아님)
- 슬라이스 C(플래그 ON), 신화퍽 등장 채널(S5), 세이브 마이그레이션(S5)
- 신규 reward type(REWARD_PERK_CHOICE 등 §7-4) — 이번엔 스타포인트 흡수로 대체
- 오버클럭 보스 아이템 사용(§1-9, S7+) — 필드 액티브 전용화는 그 선행일 뿐,
  보스 아이템 로직은 이번 범위 아님
- 가중치 상수 재설계, 상자 UI/연출, 판도라 3택 UI 재설계

## 스모크

### 신설: `godot/tests/perk_conversion_acquisition_removal_smoke.gd`
- [ ] ① 필드: 플래그 OFF → 패시브 후보 존재 / ON → build_spawn_candidates에
      패시브 0건, 액티브 존재
- [ ] ② 상자: normal·advanced 각각, 패시브로 귀결되는 롤값에서 OFF→패시브
      보상 / ON→스타포인트 보상(타입·수량 확인)
- [ ] ③ 판도라: OFF → 패시브 풀 non-empty / ON → 패시브 풀 empty, 3택이
      액티브/신화로 정상 구성(빈 후보 크래시 없음)
- [ ] ④ 보물탐색: 패시브 결과 롤에서 OFF→패시브 / ON→스타포인트(또는 액티브),
      신화 분기는 양쪽 동일
- [ ] 플래그 시작/종료 OFF 복원

### 회귀 유지
- S1+S2a 씰 전체(gate_batch1~5 / offer_exposure / catalog / values) GREEN
- 4경로 관련 기존 씰(field spawn / stage_clear_reward / pandora / treasure
  포트·런타임 스모크 — 발견되는 것 전부) GREEN, **flag OFF 회귀 증거**
- values_smoke 비치환군 봉인(sage_ring+dashgear)은 **그대로 유지** — 이건
  런타임 효과 경로 테스트라 획득 제거와 무관, S5까지 존속
- 헤드리스 로드 체크 + 워닝 스캔

## 반증검증 (필수 — git reset/checkout/stash 금지, in-place 토글 + 즉시 복원)

1. 필드 스폰의 플래그 게이트를 임시 제거 → "ON에서 패시브 후보 0건" 레그
   RED → 복원
2. 상자 패시브→스타포인트 리다이렉트를 임시 제거 → "ON 상자 패시브 롤이
   스타포인트" 레그 RED → 복원

## 트랩 노트

- 판도라 선택 빌더가 패시브 풀 empty일 때 후보 수 부족으로 크래시하거나
  중복 신화를 뽑지 않는지 확인 — empty graceful 처리가 핵심.
- 상자 리다이렉트는 **해석 지점**(reward type 결정)에서만 — grant/결과 UI는
  건드리지 말 것(그건 §7-4/S3 영역). 스타포인트 grant는 이미 존재하는 경로
  재사용.
- 필드 "패시브 분류"가 mythic까지 잘못 제거하지 않도록 — mythic 아이템은
  이번 대상 아님(필드 mythic 스폰은 0.00008로 유지). 패시브(type=="passive")만.
- 핫패스 딥카피 금지, 신규 owner 키 필요 시 중단·보고, UTF-8 BOM 금지,
  `.agents/skills/` 미러 수동 편집 금지.

## 완료 보고 형식

(1) 변경 파일 + 4경로 각 게이트 지점, (2) 패시브 분류 재사용 확인(신설 안 함),
(3) 상자/보물 스타포인트 흡수 방식, (4) 판도라 empty graceful 처리 확인,
(5) 신설 스모크 결과 원문, (6) 반증검증 2건 RED→GREEN 증적, (7) flag OFF
무변화 자가 확인 진술, (8) 상점(B2) 미처리 명시 + 이탈/가정.
