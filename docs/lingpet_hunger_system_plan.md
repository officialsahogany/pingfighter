# 링펫 허기(포만도) 시스템 기획 — 검토 + 정리 (2026-07-03)

문서 성격: 사용자 원안(허기 시스템)에 대한 4-렌즈 검토(밸런스 / 구현·트랩 통합 /
UX·심리 / 네이밍) 결과와 권장 스펙 정리. **핵심 3결정 잠금 완료(2026-07-03,
사용자 확정): D1 = 포만도 / D3 = 먹이 교감 완전 제거 / D4 = 참여율 비례 지급.**
본 문서가 슬라이스 SSOT다(잔여 D-결정은 §8, 해당 슬라이스 착수 전 잠금).
Codex 리뷰(2026-07-03)도 독립적으로 같은 결론에 수렴함 — 분담은 §10.
관련 선행 SSOT:
`docs/lingpet_affinity_per_run_redesign.md`(per-run 계약),
`docs/lingpet_v3_5_feed_slice_plan.md`(현행 먹이 = 교감 소스, 본 기획이 supersede 대상).

---

## 1. 문제 정의 (사용자 원안의 목표)

- (a) 링펫 슬롯은 3개지만 실전에는 계속 키워온 강펫만 나감 → 약펫 사장.
- (b) 링펫 스킬이 OP라 상시 필드 배치 시 난이도가 크게 하락.
- 제안: 활성 중 감소하는 '허기' 게이지(0~100)로 링펫 업타임에 예산을 붙여
  전략적 투입 + 로테이션을 유도.

### 원안 8요소

1. 허기 게이지 0~100, TAB 링펫 탭 교감 바 하단에 표시.
2. lingpet_feed 효과를 교감 경험치 → 허기 회복으로 전환. 먹이 4종 세분화
   (딸기 +20 / 귤 +30 / 오렌지 +50 / 고급사료 +100).
3. 획득 시 허기 100, 활성화 중 천천히 감소.
4. 허기 ≤50 이속 비례 감소, 허기 0 = 이속 0 + 뻗음(무력화).
5. 먹이 없으면 다른 링펫으로 교체 가능.
6. 신규: 링펫 비활성화(쉬게 두기) 토글 — 비활성 중 허기 소모 없음.
7. 신규 패시브 '소식' Lv1~5: 허기 감소 속도 저감.
8. 신규 패시브 아이템 '먹이배낭'(부위: 등): 비활성 펫 허기 자동 회복.

---

## 2. 검토 결론 (4-렌즈 종합)

**채택 권장 — 단, 원안 그대로가 아니라 '스태미나형'으로 내부 재설계 + 목표 1은
별도 양의 인센티브로 분리.**

- 목표 (b) OP 상시배치 완화: **메커니즘 유효.** 활성 시간에 비용을 붙이는 자원
  게이지는 '언제 투입할까'라는 실제 의사결정을 만든다. 구현 지형도 이례적으로
  유리하다(§6 — 드레인 틱/저장/감속 부착점이 전부 기존 초크포인트).
- 목표 (a) 약펫 로테이션 유도: **원안 그대로는 거의 작동하지 않는다.** 허기는
  강펫을 벌줄 뿐 약펫을 매력적으로 만들지 않으므로, 최적해가
  "강펫을 쉬게 뒀다가(6번 토글 + 8번 배낭) 보스전에만 투입"으로 수렴 —
  약펫은 여전히 0분 출전. 로테이션은 §4.9의 양의 인센티브 레버로 풀어야 한다.

### 원안의 3대 자기모순 (수정 없이 배선하면 시스템이 스스로를 상쇄)

1. **토글+배낭 조합이 로테이션 회피를 보조**: 비활성 보존 + 자동 회복이 있으면
   강펫 업타임 관리가 최적해가 되어 목표 (a)가 자멸.
2. **교감 참여율 게이트와 정면 충돌**: 승리/스테이지클리어 +70과 pending 정산이
   라운드 참여율 50% 절벽 게이트(`lingpet_affinity_state.gd:1599`,
   `pet_rounds * 2 >= total_rounds`)를 요구 — 허기 때문에 배틀 중 2~3마리를
   돌리면 어느 펫도 50%를 못 채워 최대 교감 소스가 전량 증발. "로테이션을
   유도한다는 시스템이 로테이션을 처벌"하는 구조.
3. **먹이 경제 딜레마**: 현행 먹이 공급은 필드 스폰(가중치 0.010) + 가챠뿐이고
   샵 판매 미배선 — 기근이면 허기 0 무력화가 플레이어 통제 밖 복권(짜증 요소화),
   반대로 샵 골드 무한 구매를 열면 V3-5가 막았던 익스플로잇이 '무한 업타임'으로
   이주해 목표 (b)가 골드로 우회됨.

### 권장 재설계 골격 — 스태미나형

> 활성 중 감소 + **휴식(교체 아웃) 중 자동 저속 회복(기본 내장)** + 먹이 =
> 즉시 충전 가속제.

- 기근이어도 3마리 순환+휴식으로 런이 굴러감(시스템 벽돌화 방지).
- 먹이를 사재도 드레인이 업타임 상한을 유지(무한구매 익스플로잇 구조 완화).
- 프레이밍도 '방치 죄책감(굶주림)'이 아니라 '투입 예산(컨디션)'으로 읽힘.

---

## 3. 네이밍 결정 (권장)

repo grep 결과 허기/포만/기력/스태미나 계열은 전부 미사용(깨끗한 네임스페이스).
반면 아래 충돌이 실재:

- '딸기' → 뿔딸기 스킬군(딸기장판·딸기먹기·딸기폭탄) + 뿔딸기 가면이 점유. 필드
  스폰 먹이 '딸기'는 변신 아이템 오인 시나리오 성립 → **먹이명에서 제외**.
- '배낭' → 기존 slot_add 아이템 표시명이 정확히 '배낭'
  (`mythic_item_catalog_build_router.gd:159`), 같은 등 슬롯 → **'먹이배낭' 회피**.
- '소식' 단독 → 첫 독해가 消息(뉴스)로 갈 확률 높음 + 기존 패시브 풀의
  4자 시적 한자어 톤(공명 증폭/잔광 유출/순풍 발산/별빛 추적)과 불일치.

### '허기' 단어 판정: **비권장 (방향 반전)**

기획은 "100 = 배부름(양호), 0 = 뻗음"인데 '허기'는 굶주린 상태 그 자체라서
게이지 값과 의미가 반전된다. 마인크래프트 한글판 관례가 바 자체는 어느 정도
구제하지만, **'소식' 패시브 효과문("허기 감소 속도 감소")에서 관례가 붕괴** —
사전 독해(배고픔이 안 풀림 = 나쁨)와 시스템 독해(게이지 소진 느려짐 = 좋음)가
정반대. 다국어에서도 일어 満腹度 / 중어 饱食度가 관례(비반전)라 한국어만 반전
용어가 된다.

### 확정 권장 세트

| 항목 | 1안 (권장) | 차선 |
|---|---|---|
| 게이지명 | **포만도** (UI 라벨 '포만', 검은사막 펫 포만도 선례, EN Satiety / JA 満腹度 / ZH 饱食度) | 기력 (메커닉 밀착, 단 먹이 소재와 간접적) |
| 코드 키 | `lingpet_satiety_*` (hunger로 지으면 코드 안에서 방향 반전 재발) | — |
| 상태어 (0 도달) | **탈진** ('기절'은 전투 CC와 어휘 충돌 → 회피) | — |
| 먹이 4종 | **귤 +20 / 사과 +30 / 멜론 +50 / 특제 사료 +100** (과일 크기 = 티어, 아이콘만으로 위계 가독) | 1차 2종 축소: 귤 +40 / 특제 사료 +100 |
| 패시브 (원안 '소식') | **소식 체질** ('체질'이 小食 독해를 강제, 4자 톤 일치) | 소식가 |
| 등 아이템 (원안 '먹이배낭') | **자동 급식기** (기능 즉독 + 마법기계 세계관 정합) | 간식 파우치 |

'허기' 유지를 고집할 경우의 카피 규율: 동사를 '채우다/바닥나다'로 제한하고
'허기 증가/감소' 표현 전면 금지(소식 효과문 = "허기가 천천히 바닥납니다").
비권장.

---

## 4. 시스템 스펙 (권장안 v1 — 수치는 전부 튜닝 대상 placeholder)

### 4.1 게이지

- per-pet, **run-scope**(store v5 메타 전용 계약 유지 — 런 간 영속 없음).
- 저장: `LingpetAffinityState._pets`에 `satiety: 100.0` 기본값 추가 →
  획득 시 100 / `reset_for_new_run` 초기화 / `export_run_state`·
  `import_run_state` 세이브 왕복이 기존 봉인 위에서 자동 성립.
- owner 미러 키(`lingpet_satiety_pct` 등)는 `BattleSceneState.DEFAULT_VALUES`
  선언 필수 + **정수 양자화 write**(매 틱 float sync 시 surface-key 게이팅과
  stats 캐시가 무력화됨 — §6).

### 4.2 드레인

- **전투 중 + 활성(필드) 컴패니언만**, `egg_runtime.update()` STATE_COMPANION
  분기에서 delta 누적 — `update_lingpet`은 모든 모달 일시정지 브랜치가 스킵하므로
  일시정지/TAB/시네마틱/광장 동결이 공짜(월클록 쿨다운 누수 트랩 구조 면역).
- 초기값: **0.25/초** (풀바 100 ≈ 활성 6.7분 ≈ 배틀 약 2판 — "한 판은 마음껏,
  두 판째부터 선택"). 밴드 0.2~0.5/초에서 V3-6 튜닝과 함께 확정.
- 목표 가동률: 단일 펫 무급식 = 런 활성 전투시간의 ~25-30%, 3마리 순환 시
  ~75-90% — "로테이션하면 이득, 한 마리 고집하면 공백"을 만드는 수치 지점.
- sortie/free_flight 펫: hidden(오프스크린) 구간 **포함** 드레인(지상/비행
  등가화). 미포함 시 비행 펫 실효 드레인 절반. **확정(D7, 2026-07-03)** —
  Slice 1 구현이 이미 활성 펫 무조건 드레인이라 구조상 일치.

### 4.3 휴식 회복 (스태미나형 핵심)

- 교체 아웃(비활성 슬롯) 펫은 **기본 내장 저속 회복: 드레인의 1/3**
  (0.25/초 드레인 기준 ≈ 0.083/초). 먹이배낭 없이 제공.
- 이로써 "L키 교체 = 사실상의 휴식"이 성립 — 원안 6번(비활성화 토글)의 목표
  80%를 신규 상태머신 없이 커버 (토글 자체는 §7 Slice 5 보류).

### 4.4 감속 곡선 + 탈진

- 포만도 >50: 배율 1.0. **50→10 구간: 1.0→0.6 선형. 10~1: 0.6 고정.**
  0에서만 정지. 하한 0.6 이유: (a) 애니 walk/idle 임계 0.01 대비 안전
  (제자리걸음/플리커 밴드 방지), (b) 방어 인터셉트가 "느리지만 기능하는" 수준
  유지(방어율 saga 재발 방지 — 진짜 페널티는 감속이 아니라 탈진 하나로 집중).
- 부착점: 지상 = `lingpet_debug_stat_override_state.get_patrol_speed` 단일
  리졸버에 배율 곱(patrol_speed 읽기 6개소가 전부 여기로 수렴, F7 선례 패턴).
  비행 = `motion_state.update()`에 satiety speed scale 인자 신설로 SORTIE_* /
  free_flight velocity에 동일 배율(velocity를 깎아야 플랩 애니 동기) —
  **D7 확정(velocity 배율, 출현율 페널티안 폐기)**. 인자명은 D1 규약대로
  satiety 계열(hunger 금지).
- **탈진(0 도달)**: 즉시 KO가 아니라 **1.5~2초 텔레그래프**(비틀→주저앉음) 후
  KO — 마지막 교체/급식 기회를 주어 "갑자기"를 "내가 늦었다"로 귀속.
  KO = 신규 단일 술어 `is_companion_exhausted()` 하나를 **5개 소비처에 일괄
  배선**: body hit(`_resolve_companion_ball_hit`) / 선제타격(strike anticipator)
  / 스킬 arm 게이트 / 수비 인터셉트 / 클릭 교감 지급. 기존
  `suppresses_companion_body_hit`는 skill_id 디스패치라 재사용 불가 — 파킹≠비활성
  트랩 직격 지점. KO 포즈: 지상 = 레인 Y 파킹 + 잠듦(Zzz) 연출, 비행 = 가시
  위치 강하 후 파킹(플랩 하한 0.12 때문에 비율 조작만으로는 뻗은 모습 표현 불가
  — 전용 연출 필요). 연출 프레이밍은 '아사'가 아니라 '지쳐서 잠듦'.
- 탈진 펫으로의 전환: **허용하되 탈진 상태 그대로 투입**(선택지를 막기보다
  결과를 보여주는 쪽이 부당함이 적음). 먹이면 기상 전용 연출(벌떡 일어나기) —
  "탈진 → 급식 → 부활"이 이 시스템 최대의 감정 보상 모먼트.
- **기상(해제) 규칙(D12 확정, 2026-07-03)**: 탈진은 포만도가 **기상 임계 10**
  이상이 될 때만 해제 — "포만도 > 0 즉시 해제"는 금지(벤치 1틱 왕복 핑퐁으로
  텔레그래프 기능 윈도우를 무한 farming 가능 + D10 무력화). KO 중에는 활성
  펫도 휴식 속도(드레인 1/3)로 회복("잠들어 쉬는 중") → 임계 도달 시 자동
  기상(~2분). 먹이는 즉시 기상 가속제. 1펫 로스터의 영구 KO 데드락도 이
  규칙으로 해소.

### 4.5 먹이 전환 (V3-5 supersede — 원자적 개정 필수)

- 현행: `feed_lingpet` → 그릇 연출 → SOURCE_FEED 친밀도 +35, 3중 캡
  (런 3회 / 링코어 clamp / 칩 면제) + 봉인 스모크 2본. **이 계약 전체가 '먹이 =
  교감'을 전제로 봉인되어 있어 부분 수정 불가** — 코드 + 스모크 재작성 + 문서
  supersede + 다국어 동기(기존 설명문 "친밀도를 35 올립니다" 교체)를 한 슬라이스에.
- 전환 후: 먹이 = 포만도 회복. `feed_amount`가 전 구간 죽은 배관(facade가
  item_data를 버리고 GAIN_TABLE 고정 35 사용)이라 catalog → facade →
  `feed_lingpet` 인자 → feed_controller pending → 완료 지급까지 amount 스레딩
  신설. `_get_blocked_reason`은 만복(full) 차단으로 교체.
- 새 캡: 런 3회 캡 폐기(스태미나 모델에서 시스템을 벽돌화함) → **배틀당 급식
  2회 캡**으로 재정의. Alchemy 리사이클 퍽 × 먹이 무한화 상호작용 감사 동봉.
- 교감 소스 이동: SOURCE_FEED(+35×3) **완전 제거 확정(D3, 2026-07-03)** —
  수입 공백의 보전 여부는 V3-6 수치 튜닝에서 별도 결정.
- 공급 경로: **플라자 샵 확정 판매를 시스템 전제조건으로 승격**(기존 잔여
  백로그였던 '먹이 샵판매'가 필수 의존이 됨). 가격 곡선이 새 경제 캡.
- 슬롯 예산: 먹이 사용을 전 슬롯 공유 7초 쿨다운에서 면제(자체 짧은 쿨다운만)
  검토 — 급식이 전투 아이템 사용권까지 잠그면 이중 처벌.
- 티어 구성: **D6 확정 = 1차 2종** — 기본 **귤**(포만도 +40, 흔함·필드/샵 확정
  판매), 고급 **특제 사료**(포만도 +100, 희귀·샵/보상). +40 = 약 2.7분 활성
  ("응급 처치"), +100 = 풀 충전. 4종(사과 +30 / 멜론 +50)은 Slice 4 이후 순수
  ADD로 확장(치즈 3종 선례 = 단일 effect id + 파라미터화 빌더로 선형 비용).
  구체 이름을 지금 잠가 4종 확장 시 리네이밍 다국어 처닝을 방지.
- **KO×먹이 정합(무료 시너지)**: D12 `set_satiety` 기상 로직이 이미 배선돼
  있어(포만도 ≥10에서 exhausted 클리어), 먹이가 `add_satiety`만 호출하면 KO 펫
  급식 = 즉시 기상이 자동 성립. 귤(+40)/특제(+100) 둘 다 0에서 임계 10을 넘겨
  기상 — Slice 4는 신규 기상 로직 불필요, "탈진→급식→벌떡 기상" 연출만 얹으면 됨.

### 4.6 '소식 체질' 패시브

- 효과: `satiety_drain_reduction_pct_by_level := [10, 17, 24, 31, 38]` (%).
- **Slice 1 리뷰 이월 의무 2건 (2026-07-03, 소식 체질 슬라이스에서 해소)**:
  (a) `_get_satiety_drain_multiplier`(egg_runtime)가 현재 슬롯 0 패시브만
  읽음 — 2번째 패시브 슬롯에 소식 체질이 앉으면 감면이 무음 no-op
  (Second-Slot Parity 트랩의 패시브 판). 카탈로그 편입 시
  `get_passive_skills` 양슬롯 순회 + 감면 합산(하한 0.4 클램프 유지)으로
  교체하고 슬롯 2 배치 스모크를 동봉할 것.
  (b) `lingpet_affinity_state.gd`의 `SATIETY_DRAIN_REDUCTION_PCT_BY_LEVEL`
  상수 + `get_satiety_drain_reduction_pct_for_level` 헬퍼는 현재 소비자 0 —
  카탈로그 엔트리의 `*_by_level` 배열이 단일 소스가 되는 순간 드리프트 위험
  중복이 되므로, 카탈로그 편입 시 이 사본을 제거하거나 카탈로그가 이 상수를
  참조하게 단일화할 것 (per-level 상수 ad hoc 재타이핑 금지 규칙).
- **부화 정체성 풀 균등 편입 비권장**: 편입 시 전투 패시브 확률 1/5→1/6 희석 +
  '소식 체질만 뽑힌 펫'(2번째 해금 전 유일 패시브)은 전투 가치 0의 순수 꽝 부화
  — 약펫 사장을 풀려는 시스템이 새 꽝을 제조. 권장: 2차 해금 후보 전용 또는
  부화 스탯 롤 축('포만도 효율 ±15%')으로 이동 — D5 결정.
- 감면 상한: 소식 체질 + 자동 급식기 + 먹이를 전부 합쳐도 시스템을 상쇄하지
  못하게 **합산(곱연산) 감면 ≤ 40~60%** 상한을 스펙에 명시.

### 4.7 '자동 급식기' (부위: 등)

- 효과: 휴식(비활성) 펫의 자동 회복 속도 2배, **단 급식기 회복 상한 70**
  (배낭만으로 '보스전 풀충전 강펫'을 못 만들게).
- 기본 휴식 회복(§4.3)이 내장되므로 존재 이유가 축소 — 삭제도 유효 옵션.
  등(belt2) 슬롯은 배낭(slot_add)/충전가방/헤븐리케이프와 경쟁하는 프리미엄
  슬롯이라 순수 유지비 감면 아이템은 기회비용상 사장되거나(실패) 시스템을
  무력화(실패)하기 쉬움 — D8 결정.

### 4.8 비활성화(휴식) 토글 — 1차 보류

- L키 교체가 목표의 80%를 커버하므로 Slice 5로 보류. 도입 시:
  `lingpet_none_owner_sync_state`의 자동 재입양 루프(auto-present 리그에서 매 틱
  활성 슬롯 펫을 되살림)를 rest 플래그가 이기는지 스모크 필수 — 이기지 못하면
  "껐는데 다시 나온다" 무음 버그. UX = TAB 활성 슬롯 탭 재클릭 = 휴식, 재투입은
  기존 0.62s 전환 VFX를 '링코드 소환' 문법으로 리스킨(세계관: 링코드 = 소환키).
  미세 토글링 악용 방어: 투입 고정비용(포만도 -5) 또는 재투입 쿨다운 중 택일.

### 4.9 로테이션 양의 인센티브 (목표 (a)의 실제 해결 레버)

- (a) 참여율 50% 절벽 게이트 → **비례 지급**(`rounds_committed / total_rounds
  × 70`)으로 교체 — **확정(D4, 2026-07-03)**. 로테이션 처벌 제거; 절벽 유지 시
  최적해가 '1마리 몰빵'으로 회귀하기 때문에 포만도 도입의 선행 결정이었음.
- (b) **신선 투입 보너스(rested bonus)**: 포만도 80+ 펫이 교체 투입되면 첫
  30초 게이지 획득 +30% 류 — 약펫이 '열화 강펫'이 아니라 '지금 이 순간의
  최선'이 되는 순간을 만든다.

### 4.10 온보딩 가드

- 주니어 리그(첫 펫 + 미카 튜토리얼 구간): 드레인 면제 또는 50% 감면.
  허기 시스템은 펫 2마리 이상(로테이션이 실제로 가능한 시점)부터 의미가
  생기므로, 1마리 구간에서 켜면 첫 펫 경험이 '얻자마자 굶는 짐'이 됨.

---

## 5. UI 스펙

### TAB 캐릭터정보창 링펫 탭

- **스탯 행 추가 금지** — 능력치 탭 7행이 560x360 프록시 예산을 정확히 채운
  상태(Stats-Panel Row Budget 트랩: 오버플로우 행은 조용히 드랍).
- 대신 **교감 밴드 확장**: `AFFINITY_BAND_HEIGHT` 34→~50, `draw_affinity_status`
  하단에 두 번째 미터(8px, ≤50 황색 / ≤20 적색). 봉인: 해금 밴드 42px 게이트
  통과 assert + 픽셀 QA. 해당 프레젠터는 미커밋 오로라 WIP 위에 겹치므로 주의.

### 인게임 가시성 (부당함 귀속 방지 — 3층 구조)

1. 상시: `LingpetRailCard`에 교감 바와 동일 문법의 얇은 포만도 스트립 1줄.
2. 임계 경고: 50 진입 시 펫 머리 위 땀방울 팝 1회 + 카드 황색, 25에서 펄스 +
   전용 SFX 1회, 10에서 적색 + "링펫이 지쳤어요" 토스트 1회. 감속 자체가 이미
   diegetic 신호이므로 증폭만.
3. 탈진 텔레그래프(§4.4) — 마지막 개입 기회.

TAB 전용 표시는 금지 수준으로 비권장: 포만도가 전투 결과(이속·무력화)를 바꾸는데
가시성이 모달 전용이면 "게임이 갑자기 내 펫을 껐다"로 귀속됨(소울라이크 에스트
잔량이 상시 HUD인 이유와 동일 요건).

Slice 2 소비자 주의(2026-07-03 Slice 1 리뷰 노트): owner 키
`lingpet_satiety_pct`의 DEFAULT/비컴패니언 값이 0이라 "펫 없음"과
"포만도 0(탈진)"이 같은 값이다. UI는 가급적 런타임 스냅샷(`satiety_pct`)을
읽고, owner 키를 읽는 경우 companion 유무를 별도 키로 게이트할 것. 탈진
게임플레이 판정은 owner 키가 아니라 런타임 술어(`is_companion_exhausted`,
Slice 3)만 사용한다.

---

## 6. 밟는 기존 트랩 매핑 (배선 시 체크리스트)

| 트랩 (CLAUDE.md / godot_runtime_traps.md) | 본 기획의 접점 | 대응 |
|---|---|---|
| Stats-Panel Row Budget | TAB 포만도 바 | 스탯 행 대신 교감 밴드 확장 (§5) |
| Companion Walk/Idle Ratio (treadmill) | 감속 → 애니 임계 0.01 | 감속 하한 0.6 + 0에서만 스냅 정지 (§4.4) |
| Incapacitation Body-Hit (파킹≠비활성) | 탈진 KO | 신규 펫-컨디션 술어 1개 → 5소비처 일괄 배선 (§4.4) |
| Teleport/Reposition Y (지상 펫 레인 유지) | KO 파킹 포즈 | 비기본 패들높이 스모크 의무 |
| update_lingpet 일시정지 스킵 | 드레인 클록 | delta 누적으로 동결 공짜 — wall-clock 금지 (§4.2) |
| Owner-Field Schema (silent no-op) | owner 미러 키 | DEFAULT_VALUES 선언 + divergent 케이스 스모크 (§4.1) |
| Lazy Applied-Key / stats 캐시 해시 | 매 틱 float sync | 정수 양자화 write (§4.1) |
| 레일카드 append_entry = 풀 스냅샷 빌드 | 인게임 스트립 | 기존 스냅샷 필드에 편승, 신규 빌드 경로 금지 |
| Per-Frame Probability Roll | 해당 없음(드레인은 결정적) | — |
| 반증검증 = in-place 토글만 | lingpet/ 대부분 + 프레젠터가 미커밋 WIP | git reset/stash 절대 금지, 슬라이스별 헌크 분리 커밋 |

구현이 싼 이유(검증됨): 드레인 틱 자리(`egg_runtime.update` STATE_COMPANION),
저장 위치(`_pets` dict + export/import 왕복), 감속 부착점(get_patrol_speed 단일
리졸버), 전투 중 교체(L키 / Shift+L / TAB 슬롯 탭, per-pet 스킬 쿨다운 보존까지
봉인 완료)가 전부 기존 초크포인트라 신규 인프라가 거의 불필요.

---

## 7. 슬라이스 분해 (권장 순서 — 각 슬라이스 독립 출하 가능)

- **Slice 0 — 결정 잠금** (코드 0줄): ✅ 핵심 3결정(D1/D3/D4) 잠금 완료
  (2026-07-03). 잔여 D-결정은 해당 슬라이스 착수 전 잠금(§8).
> **커밋 상태(2026-07-03)**: Slice 1+3a+3b 코어 = **`2ae19366a`** ("Wire
> lingpet satiety system core", 8파일 +725, 사티에티-전용 헌크분리 커밋 —
> battle_scene_state/egg_runtime의 무관 WIP(sand_prison/star_coil/dwarf_magic
> 키 + egg-roll required_hits 리팩터)는 의도적으로 미스테이징 유지). **주의**:
> Slice 3a의 스킬 arm-gate 파일 2개(lingpet_companion_skill_controller.gd,
> lingpet_companion_skill_update_context_builder.gd)는 그 이전 체크포인트
> **`e8e141e7c`**("checkpoint lingpet module cluster")에 "bare rolling egg"
> 작업과 함께 이미 섞여 커밋됨 — 사티에티 배선은 두 커밋에 걸침.

- **Slice 1 — 포만도 상태 코어**: ✅ **완료(2026-07-03, Codex 배선 + Claude
  적대 리뷰 APPROVE, 커밋 2ae19366a)** — `_pets` satiety(드레인 0.25/초, 휴식 회복
  1/3, sanitize 양방향) + `_advance_satiety` STATE_COMPANION delta 틱 +
  owner pair 정수 양자화/게이트 write + `lingpet_satiety_state_smoke` 4상
  (드레인 OUTCOME / pause 동결 / 왕복 / divergent owner) + RED 반증검증
  (DEFAULT_VALUES 임시 제거). 스모크는 리뷰에서 독립 재실행 GREEN. 이월 의무
  3건은 §4.6/§5에 기록. TAB 관찰 표시는 Slice 2로 이동.
- **Slice 2 — TAB 포만도 바**: 교감 밴드 확장 (§5). 42px 게이트 assert + 픽셀 QA.
- **Slice 3a — 감속 + 탈진 게이트**: ✅ **완료(2026-07-03, Codex 배선 + Claude
  적대 리뷰 APPROVE, 미커밋)** — 곡선(>50=1.0, 50→10 선형 1.0→0.6, <10=0.6,
  `get_satiety_speed_multiplier_for_value`) + 텔레그래프 1.75s
  (`advance_satiety_exhaustion`) + 5소비처 게이트(body hit / 방어율 0.0 /
  선제타격 / 스킬 arm `companion_exhausted` / 클릭 교감 지급 차단, 리액션 유지)
  + D7 전 sortie 페이즈·patrol·free_flight velocity 배율 + D9 주니어
  `is_auto_present_league` 면제(드레인은 관찰 유지). 스모크 5본 리뷰 독립
  재실행 GREEN + body-hit 게이트 반증검증(리뷰어 직접 in-place RED→원복
  GREEN). 미드캐스트 윈드업은 KO가 끊지 않음(신규 arm만 차단 — 액티브 페이즈
  억제 금지 원칙 정합).
- **Slice 3b — 잔여 (리뷰 발견분, Codex 후속)**: ✅ **코드/스모크 완료 + Claude
  적대 리뷰 APPROVE (2026-07-03, 미커밋). 실제 픽셀 QA는 미수행(라이브 QA 대기).**
  1. **D12 기상 임계 배선 완료**: "기상 임계 10 이상"으로 교체
     (`set_satiety` 해제 조건 + `is_satiety_exhausted` 가드) + KO 중 활성 펫도
     휴식 속도(드레인 1/3)로 회복 → 자동 기상(~2분). 드레인↔회복 전환은
     `advance_satiety(active_resting=is_companion_exhausted)` 인자로 처리 —
     활성 KO 펫은 rest 브랜치로만 회복, 벤치 rest 루프에서 active_pet은 skip돼
     이중 회복 없음(리뷰 확인). 스모크: 포만도 5에서 여전히 KO / 임계 도달 자동
     기상 / 벤치 1틱 왕복(핑퐁)이 KO를 못 푸는 것. **리뷰어 반증검증: 임계를
     999로 올리면 자동 기상 단언 RED → 원복 GREEN.**
  2. **sortie/free_flight KO 가시 파킹 완료**: KO 시 hidden/offscreen 상태를
     화면 안 휴식 지점으로 끌어내려 `exhausted_park`에 파킹(`motion_visible=true`
     강제 + entry 텔레포트 후 park target으로 스텝). 스모크: hidden 중 KO →
     visible + playfield 내부 좌표 + zero speed scale. **리뷰어 반증검증: sortie
     park 브랜치를 끄면 visible/park/좌표 단언 RED → 원복 GREEN.**
  3. **텔레그래프/KO 렌더 소비 배선 완료**: `satiety_exhaustion_ratio`로 warning
     wobble/ring, `companion_exhausted`로 낮아진 잠듦(scale.y*0.76)/Z 마커.
     **봉인 방식 주의**: headless dummy renderer가 SubViewport texture를 null로
     반환해 자동 픽셀 스모크 불가 → 현재 봉인은 렌더러/draw-context **소스 문자열
     존재 검사**(`_draw_satiety_exhaustion_telegraph` / `_draw_exhausted_sleep_marker`
     / `dest_rect.size.y *= 0.76`)뿐. 이는 "함수가 호출된다/시각 결과가 맞다"를
     증명하지 못하는 약한 봉인이므로, **실제 화면 픽셀 QA가 라이브 QA 게이트로
     남아 있음**(리뷰에서 미수행). 소스 검사 봉인은 함수명 리네이밍 시 조용히
     깨질 수 있으니 렌더 리팩터 시 주의.
- **Slice 4 — 먹이 전환 (원자적)**: ✅ **완료(2026-07-03, Codex 배선 + Claude
  적대 리뷰 APPROVE, 미커밋)** — `lingpet_feed` = 귤(+40, 필드+샵),
  `lingpet_special_feed` = 특제 사료(+100, 샵+보상, reward_only). 공유 effect id
  `lingpet_feed` + `feed_amount` per-item 스레딩(catalog→facade→feed_lingpet→
  controller pending→완료 `add_satiety`), SOURCE_FEED 완전 제거, 배틀당 완료
  급식 2회 캡(리셋=affinity 배틀 경계 공유, round reset 아님), 만복(satiety==MAX)
  차단, `no_global_cooldown`으로 전 슬롯 7초 쿨다운 면제, KO 급식 즉시 기상
  (D12 set_satiety 자동), V3-5/V3-4 문서 supersede + 다국어 6벌(EN/ZH/JA/ES/
  PT_BR/RU) + item_runtime_checklist 감사. **리뷰 검증**: 스모크 10본 독립 재실행
  GREEN(feed_affinity/feed_active_item/satiety_state/chip/plaza_shop_stock/
  localization/korean_names/field_spawn/stage_clear ×2), 배틀 2-cap 반증검증
  리뷰어 직접 재현(999→배틀캡+alchemy 우회방지 5단언 RED→원복 GREEN), 6개 언어
  ×2아이템 커버 확인, feed=add_satiety·SOURCE_FEED 잔재 0. **Codex가 RED로
  보고한 `lingpet_egg_runtime_smoke`("shove the egg too far")는 리뷰어 3/3 GREEN
  재현 불가** — Codex 중간 상태/stale import로 추정, 현 워킹트리는 통과. 4종
  세분화(사과 +30 / 멜론 +50)는 Slice 4 이후 순수 ADD.
- **Slice 5 — 명시적 보류**: 비활성화 토글(§4.8) / 자동 급식기(§4.7) /
  rested bonus·참여율 비례화(§4.9 — 단 D4 결정 자체는 Slice 0에서 선행).

---

## 8. 결정 대기 목록 (Slice 0에서 잠글 것)

| # | 결정 | 권장 |
|---|---|---|
| D1 | 게이지명 | **확정(2026-07-03)**: 포만도 — 라벨 '포만', 상태어 '탈진', 코드 키 satiety |
| D2 | 스코프 | run-scope (store v5 계약 유지, 런 시작 100) |
| D3 | 먹이의 교감 기능 | **확정(2026-07-03)**: 완전 제거 — 먹이 = 포만도 전용. 교감 수입 공백 보전 여부는 V3-6 수치 튜닝에서 결정 |
| D4 | 참여율 50% 절벽 게이트 | **확정(2026-07-03)**: 비례 지급으로 교체 (`rounds_committed / total_rounds × 70`) |
| D5 | 소식 체질의 부화 풀 편입 | 부화 정체성 풀 제외 (2차 해금 후보 전용 or 스탯 롤 축) |
| D6 | 먹이 티어 수 | **확정(2026-07-03)**: **1차 2종** — 기본 = **귤**(포만도 +40, 흔함·필드/샵), 고급 = **특제 사료**(포만도 +100, 희귀·샵/보상). 근거: Slice 4는 "먹이=교감→포만도" 전환+V3-5 supersede 정합 작업이라 티어 표면을 좁게. 4종(사과 +30 / 멜론 +50 삽입)은 Slice 4 이후 소식 체질/경제 튜닝과 함께 순수 ADD로 확장(구체 이름 유지 → 리네이밍 다국어 처닝 방지) |
| D7 | 비행 펫 번역 | **확정(2026-07-03)**: SORTIE/free_flight velocity 배율 + hidden 구간 드레인 포함. 근거: 포만도 감속 = '이동 컨디션'이므로 비행 펫도 실제 속도/도착 타이밍/플랩 리듬이 함께 느려져야 지상과 같은 규칙으로 읽힘. 출현율 페널티안은 체감이 "안 나옴/숨음"이라 인과가 덜 직관적 + 디버깅 흐림 → 폐기 |
| D8 | 자동 급식기 | 축소 유지(휴식 회복 2배, 상한 70) vs 삭제 |
| D9 | 주니어 리그 | 드레인 면제 vs 50% 감면 |
| D10 | 탈진 펫 전환 | 허용 + 탈진 상태 투입 (차단보다 부당함 적음) |
| D11 | 로스터 확장 | MAX_OWNED=3(소유=전투슬롯, 벤치 없음) 유지 전제 — 로테이션이 성공할수록 확장 요구 커짐, 스코프 선긋기 |
| D12 | 탈진 기상(해제) 조건 | **확정(2026-07-03)**: 기상 임계 10 + KO 중 활성 펫도 휴식 속도(드레인 1/3)로 회복 → 약 2분 후 자동 기상. 근거: 즉시 해제(포만도>0)는 L키 핑퐁으로 텔레그래프 기능 윈도우 무한 farming + D10 무력화; 자동 기상은 1펫 로스터 데드락 해소 + '지쳐서 잠듦' 프레이밍 정합. 먹이는 즉시 기상 가속제 |

---

## 9. 코드/문서 앵커 (조사 검증 완료)

- 로스터: `godot/scripts/lingpet/lingpet_collection_state.gd` —
  `MAX_BATTLE_SLOTS := 3`, `MAX_OWNED := MAX_BATTLE_SLOTS`(:5-6), 벤치 없음,
  4번째 획득 = overflow release/replace 강제.
- 전투 중 교체(이미 완비): `battle_scene_input_controller.gd:12`
  `LINGPET_CYCLE_KEY := KEY_L`(Shift+L 역방향) → `cycle_lingpet_slot`;
  TAB 슬롯 탭 → `switch_lingpet_slot`; per-pet 스킬 쿨다운 보존 =
  `lingpet_companion_skill_persistence.gd`.
- 참여율 게이트: `lingpet_affinity_state.gd:1593-1599`
  (`pet_rounds * 2 >= total_rounds`), 소비처 :830/:1007/:1020.
- 드레인 틱 자리: `lingpet_egg_runtime.gd` update(:269) STATE_COMPANION 분기,
  `battle_frame_flow_controller.gd:81` update_lingpet(모달 스킵 = 동결 공짜).
- 저장: `lingpet_affinity_state.gd` `_pets` / `reset_for_new_run`(:181) /
  `export_run_state`(:192) / `import_run_state`(:207).
- 감속 부착점: `lingpet_current_profile.gd get_stat`(:73, patrol_speed 분기) +
  `lingpet_debug_stat_override_state.get_patrol_speed` 리졸버(6개소 수렴);
  비행 = `lingpet_companion_motion_state.gd` SORTIE_* 상수.
- 먹이 현행: `lingpet_feed_controller.gd`, `feed_lingpet`(:2670),
  V3-5 SSOT = `docs/lingpet_v3_5_feed_slice_plan.md`(3중 캡 + 봉인 스모크 2본).
- 패시브 풀: `lingpet_catalog.gd:73` COMMON_PASSIVE_SKILL_POOL(5엔트리,
  `*_by_level` 배열) + `_roll_hatch_passive_id` 자동 편입.
- TAB UI: `character_info_overlay_lingpet_presenter.gd` AFFINITY_BAND_HEIGHT /
  `draw_affinity_status`(:358) / 해금 밴드 42px 게이트(:259) — 미커밋 오로라
  WIP와 동일 파일.
- 이름 충돌: `mythic_item_catalog_build_router.gd:159` "배낭"(slot_add, belt2);
  뿔딸기 스킬군(딸기장판/딸기먹기/딸기폭탄).

---

## 10. Codex 핸드오프 노트 (배선 분담)

분담: 기획·디렉션·적대 리뷰·픽셀 QA = Claude / 배선 구현 = Codex
(repo 선례: 라호세트 모래감옥, 오딘의 눈 magnum_grip 락 누수, 광장 포팅).
Codex는 2026-07-03 자체 리뷰에서 이 문서의 결론(포만도 개명, 스태미나형,
토글/급식기 보류, 감속 하한 0.6, 참여율 비례화, 소식 2차 해금행)에 독립
수렴했으므로 이 문서 §4~§8을 그대로 작업 지시서로 사용한다.

### 작업 범위와 순서

- **1차 지시 = Slice 1(포만도 상태 코어) 단독.** §7의 스모크 4본(드레인
  OUTCOME / pause 동결 / export-import 왕복 / divergent owner) + 반증검증
  (DEFAULT_VALUES 선언 임시 제거 → 스키마 스모크 RED) 의무 포함. Slice 1
  리뷰 통과 후 3 → 4 순서로 진행. 각 슬라이스는 독립 출하 단위.
- **Slice 2(TAB 포만도 바)는 주의 대상**:
  `character_info_overlay_lingpet_presenter.gd`가 미커밋 '링펫 회전 오로라'
  WIP와 같은 파일이다. Codex에 지시할 경우 "오로라 WIP 헌크를 건드리지 말 것 +
  교감 밴드 확장 헌크만 추가"를 명시하고, 헌크가 엉키면 Claude가 직접 처리.
- **Slice 5(휴식 토글 / 자동 급식기 / rested bonus)는 보류 — 지시 금지.**
  D4(참여율 비례화)만은 Slice 1과 병행 가능(교감 정산 경로 독립).

### repo 특수 규칙 (핸드오프 시 필수 전달)

- 반증검증은 **in-place Edit 토글 / 임시 패치 / 픽스처만**. `git reset` /
  `checkout` / `stash` 절대 금지 — 더티 워킹트리에 미커밋 WIP 다수.
- 슬라이스별 헌크 분리 커밋. 커밋 실행은 사용자/Claude 승인 후.
- owner 키는 `BattleSceneState.DEFAULT_VALUES` 선언 + divergent(≠100) 스모크
  + **정수 양자화 write**(float 매 틱 sync = 캐시/게이팅 무력화, §6).
- 탈진 = 신규 술어 `is_companion_exhausted()` 1개 → 5소비처(body hit /
  선제타격 / 스킬 arm / 수비 인터셉트 / 클릭 교감) 일괄 배선. 기존
  `suppresses_companion_body_hit` 재사용 금지(skill_id 디스패치라 부적합).
- KO 파킹은 지상 펫 레인 Y 유지 + **비기본 패들높이** 스모크 의무. 스모크의
  볼 스텝은 `ball_vel * delta * 60`.
- 드레인 클록은 `update_lingpet` delta 누적만 — wall-clock
  (`Time.get_ticks_msec`) 금지(모달 일시정지 누수).
- Slice 4는 V3-5 supersede 원자 커밋: 코드 + 기존 스모크 2본 재작성 +
  `docs/lingpet_v3_5_feed_slice_plan.md` supersede 표기 + 다국어 동기
  (기존 "친밀도를 35 올립니다" 설명문 교체, 귤/특제 사료 표시명) +
  상점/보상 경로 + 전역 쿨다운 면제 + Alchemy 리사이클 × 먹이 상호작용 감사 동봉.

### Slice 4 지시 (먹이 전환 — D6 확정 1차 2종, V3-5 supersede 원자 커밋)

Slice 1+3a+3b 커밋(`2ae19366a`) 후 다음 지시. **한 커밋에 원자적으로**:

- **효과 전환**: `feed_lingpet` → SOURCE_FEED 친밀도 지급 **제거**, 대신
  `add_satiety(pet_id, amount)` 호출. `feed_amount`가 전 구간 죽은 배관(facade가
  item_data를 버리고 GAIN_TABLE 고정 35 사용)이라 **amount 스레딩 신설**:
  catalog → facade(item_data 활성화) → `feed_lingpet` 인자 → feed_controller
  pending 필드 → 완료 지급.
- **2종 아이템(D6)**: 기본 = 기존 `lingpet_feed` 재사용(포만도 **+40**, 표시명
  '귤'로 전환 — 필드 스폰 + **플라자 샵 확정 판매**), 고급 = 신규 아이템 1개
  (포만도 **+100**, 표시명 '특제 사료' — 샵/보상). 그릇(bowl) 연출·상태 재사용.
- **캡 재정의**: 런 3회 캡(`MAX_FEED_USES_PER_RUN`) **폐기** → **배틀당 급식
  2회 캡**. `_get_blocked_reason`을 `max_feed_uses`/`max_feed_level` → **만복
  (satiety == MAX) 차단**으로 교체. Alchemy 리사이클 퍽 × 먹이 무한화 감사 동봉.
- **KO×먹이(무료 시너지)**: D12 `set_satiety` 기상 로직이 이미 배선돼 있어 급식
  = 즉시 기상이 자동 성립(귤/특제 둘 다 0→임계 10 초과). 신규 기상 로직 불필요
  — "탈진→급식→벌떡 기상" 연출만 추가.
- **supersede 세트(같은 커밋)**: `docs/lingpet_v3_5_feed_slice_plan.md` §0
  '재론 금지' 결정을 supersede 표기 + 봉인 스모크 2본
  (`lingpet_feed_affinity_smoke` / `lingpet_feed_active_item_smoke`) 재작성
  (새 봉인: 만복 시 차단 / 연출 중 스왑 시 pending 귀속 / KO 급식 즉시 기상 /
  배틀당 2회 캡) + 다국어(기존 "친밀도를 35 올립니다" → "포만도를 N 회복합니다",
  귤/특제 사료 신규 표시명·설명 = EN/JA/ZH 포함) + item_runtime_checklist 감사.
- **먹이 슬롯 예산**: 급식을 전 슬롯 공유 7초 쿨다운에서 면제(자체 짧은 쿨다운만)
  검토 — 급식이 전투 아이템 사용권까지 잠그면 이중 처벌(§4.5).
- **주의**: SOURCE_FEED 제거로 교감 수입 곡선 변경(D3) — V3-6 튜닝 전제이므로
  본 커밋은 "먹이 교감 소스 제거"만, 교감 수치 보전은 건드리지 않음.

### 수치 초기값 (전부 튜닝 레버 — §4 근거)

드레인 0.25/초(활성 전투 중만) / 휴식 회복 = 드레인의 1/3 / 감속 = 포만도
50→10에서 1.0→0.6 선형, 하한 0.6, 0에서만 정지 / 탈진 텔레그래프 1.75초 /
KO 기상 임계 10 / **먹이 2종: 귤 +40, 특제 사료 +100, 배틀당 급식 2회 캡** /
소식 체질 `satiety_drain_reduction_pct_by_level := [10, 17, 24, 31, 38]`,
합산 감면 상한 ≤ 40~60%.

### 완료 게이트 (슬라이스 공통)

스모크 GREEN + 반증검증 로그(무엇을 토글해 RED를 확인했는지) + Claude 적대
리뷰 APPROVE + (UI 슬라이스) 픽셀 QA + 관련 문서/다국어 동기.
