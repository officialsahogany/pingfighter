# S2 슬라이스 B2 코덱스 핸드오프 — 플라자 상점 패시브/전설 재고 제거 (플래그 게이트, 휴면)

기준 문서: `docs/passive_to_perk_conversion_plan.md` (v3) §5-7 / §1-8.
선행: S1+S2a 커밋(`3848b595e`) + S2b(인런 패시브 4경로 제거, PASS·미커밋).
지시: "패시브 아이템을 없앤다" + **"범위를 좁혀서"**(사용자).
발주: 2026-07-07. Claude 기획 → 사용자 직접 Codex 전달 → Claude 적대 리뷰.

## 목표 (좁은 범위)

플라자 상점이 **패시브 + 전설(=신화) 장비를 재고에 올리는 것**을 막는다.
`PerkConversionFlags.is_enabled()`가 true일 때만. **플래그 기본 OFF → 휴면·
라이브 무변화.** 상점은 플래그 ON 시 보장 액티브(링펫 먹이류)만 남는다.

이 슬라이스는 "상점 재설계"가 아니라 "패시브/전설 판매 차단"이다. 액티브
중심 재고 확장은 아래 B2+ 로 명시적으로 분리한다.

## 합격 조건

1. 플래그 OFF: 상점 재고 구성 기존 그대로 (패시브/전설 정상 판매).
2. 플래그 ON: 상점 재고에 패시브·전설 아이템 0건. 보장 액티브(링펫 먹이)만 진열.
3. 크래시 없음 — 빈 풀로 인한 재고 생성 실패/음수 슬롯 없음
   (`build_inventory`가 보장 액티브만으로 정상 반환).

## 범위 (이번 실행)

1. `plaza_shop_stock.gd` — 플래그 ON이면 **패시브 풀 + 전설 풀 모두 empty**:
   - `_build_pool(source_catalog, false)`(패시브) 및
     `_build_pool(source_catalog, true)`(전설) 결과를 플래그 ON에서 빈 배열로.
     `_build_pool` 진입부 게이트 또는 `build_inventory`에서 두 풀을 비우는 방식
     중 더 좁은 쪽. (전설=신화 아이템은 신화퍽으로 이관됐고 등장은 S5 초희귀
     채널이므로 상점 판매 제거가 맞음)
2. 빈 풀에서 `build_inventory`의 랜덤 슬롯 루프가 안전하게 no-op 되는지 확인
   (현재 구조상 `item_name==""` → `_build_shop_item` `{}` → 미append). featured
   할인이 4개 보장 액티브 재고에서 정상 동작하는지 확인.

## 범위 제외 (하지 말 것) — B2+ / 후속

- **액티브 중심 재고 확장**(수류탄·화염병 등 액티브 아이템을 상점에 추가 +
  구매 경로를 `active_item_runtime.grant_item_to_slot`로 배선 + 액티브
  `ACTIVE_BASE_PRICES` 신설) — §5-7 본격 경제, 별도 슬라이스 B2+.
- **가격 정책 변경** — `plaza_shop_pricing.gd`의
  PASSIVE/LEGENDARY_BASE_PRICES는 데이터로 남겨둠(플래그 ON에서 미사용).
  재산정 금지.
- **판매(sell) 경로 변경** — 새 런엔 팔 패시브가 없어 무변경 안전. `gold_bar`는
  애초에 상점 미판매(`is_shop_priced_item` 아님)이고 S2b 필드 제거로 이미
  사라짐 — B2에서 건드리지 말 것.
- 슬라이스 C(플래그 ON), 세이브 마이그레이션(S5), 상점 UI/연출 변경.

## 스모크

### 신설: `godot/tests/perk_conversion_shop_stock_smoke.gd`
- [ ] 플래그 OFF: `build_inventory`(고정 seed) 결과에 패시브/전설 아이템 존재
      (기존 동작)
- [ ] 플래그 ON: 결과에 패시브 0건 + 전설 0건, 보장 액티브(링펫 먹이) 존재,
      크래시 없음
- [ ] 플래그 ON: 반환 재고가 빈 배열이 아님(보장 액티브로 채워짐), featured
      할인 적용이 예외 없이 동작
- [ ] 플래그 시작/종료 OFF 복원

### 회귀 유지
- S1+S2a+S2b 씰 전체(acquisition_removal / gate_batch1~5 / offer_exposure /
  catalog / values) GREEN
- 기존 플라자 상점 관련 씰(plaza_shop_stock / plaza_shop_pricing / plaza_scene
  포트 — 발견되는 것 전부) GREEN, **flag OFF 회귀 증거**
- 헤드리스 로드 체크 + 워닝 스캔

## 반증검증 (필수 — git reset/checkout/stash 금지, in-place 토글 + 즉시 복원)

1. 상점 풀 empty 게이트를 임시 제거 → "ON에서 상점 패시브/전설 0건" 레그
   RED → 복원
2. 플래그 OFF 케이스 어설션이 실제로 패시브를 요구하는지 확인 위해, 풀 empty
   게이트를 flag 무관 항상-empty로 임시 변경 → OFF 케이스 RED → 복원

## 트랩 노트

- `build_inventory`는 seed 인자를 받으므로 스모크는 **고정 seed**로 결정적
  검증(랜덤 의존 최소화). `randi_range` 결정성을 위해 seed!=0 경로 사용.
- 빈 풀에서 `MIN_STOCK_COUNT`(5) 미만이 되는 것은 허용(보장 액티브 4개) —
  음수/크래시가 없으면 OK. 재고 하한을 억지로 채우려 액티브를 급조하지 말 것
  (그건 B2+).
- 전설(신화) 제거를 빼먹지 말 것 — 패시브만 막고 전설을 남기면 상점에서 신화
  아이템(=신화퍽 대상)을 여전히 팔아 플래그 ON에서 죽은 장비가 된다.
- 핫패스 아님(상점 재고는 진입 시 1회 생성). UTF-8 BOM 금지,
  `.agents/skills/` 미러 수동 편집 금지.

## 완료 보고 형식

(1) 변경 파일 + 게이트 지점, (2) 패시브·전설 양쪽 제거 확인, (3) 빈 풀
graceful(크래시 없음, 보장 액티브 잔존) 확인, (4) 신설 스모크 결과 원문,
(5) 반증검증 2건 RED→GREEN 증적, (6) flag OFF 무변화 자가 확인 진술,
(7) B2+(액티브 확장)·판매경로·가격 미처리 명시 + 이탈/가정.
