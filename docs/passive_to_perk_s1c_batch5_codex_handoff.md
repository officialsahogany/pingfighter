# S1c 배치⑤ 코덱스 핸드오프 — 신화퍽 11종 효과 게이트 전환 (S1c 최종)

기준 문서: `docs/passive_to_perk_conversion_plan.md` (v3) §4-B / §7-2 / D5·D6.
선행: S1c 배치①~④ PASS — 일반퍽 26/26 완료. 확립 패턴 재사용.
발주: 2026-07-07. Claude 기획 → 사용자 직접 Codex 전달 → Claude 적대 리뷰.

**이 배치가 S1c의 마지막이다.** 완료 시 치환 대상 37종 전체의 게이트 전환이
완성된다. 신화퍽은 D5 확정대로 **max_level 1 고정옵션 + 유효레벨 수혜 제외
(exempt)**이며, 수치는 S1b `get_mythic_value()` 고정값을 쓴다.

## 합격 조건

1. 플래그 OFF(기본): 게임 규칙 완전 무변화.
2. 플래그 ON: 11종 효과가 퍽 경로로 완전 대체 (활성 자격 = facade 레벨>0,
   수치 = `get_mythic_value` 고정값).
3. **상태머신 무변경 원칙** (배치③④와 동일): 부활·변신·날씨 흡수·소용돌이·
   전기스턴·퍽 선택 플로우의 시퀀스/타이밍/정리 로직은 한 줄도 변경하지
   않는다 — 게이트는 활성 자격과 수치 소스에만.

## 배치⑤ 대상 11종

| perk_id | ON 고정값 | 아이템별 불변식 |
|---|---|---|
| hermes_shoes | 이속 +50% | 순수 스탯 — ①패턴 |
| celestial_armor | 스턴 무시 65% / 게이지 -30 | proc 소모 모델 무변경 |
| ragnarok_hammer | 발동 30% / 스턴 1.0s / 공속 +25% / 게이지 -30 | 전기스턴 패키지(스턴 시트·오버레이·사운드·드리프트) 무변경 |
| poseidon_trident | 쿨 6s / 게이지 -30 / 소용돌이 200px | 공 소유/skip 플래그·반사 규칙 무변경 |
| megingjord | 추가선택 발동 40% | 퍽 선택 플로우(묶음당 2회 상한 등) 무변경 — 자격+확률만 |
| heavenly_cape | 스킬슬롯 +1 / 스킬쿨 -15% | `heavenly_cape_slot_bonus`류 고정 효과 글로벌은 **기존 sync 전담 소유 규칙 유지** (checklist §0.2 — reset 경로에 넣지 말 것). 6구슬 다이얼 HUD 프레임 로직 무변경. 슬롯 수가 render/equip 게이트/overflow 3경로에 동일하게 반영되는 기존 구조를 게이트가 깨지 않는지 확인 |
| transcendent_crown | 전 퍽 유효레벨 +2 | **아래 전용 절 참조 — 이 퍽은 유효레벨 보너스의 소스** |
| odins_eye | 부활 35% | 부활 상태머신·패배 체인 순서(배치④에서 봉인) 무변경. per-실점 롤 모델 유지. 오딘 포팅 잔여(어둠의늪 등)는 별개 트랙 — 건드리지 않음 |
| horn_strawberry_mask | 변신 60초 | 커맨드 리스너의 입력엣지 idempotent 규칙(`player_input_reader_same_frame_edge_smoke` 씰), 변신 finalize 착지 리셋, **1스테이지 1회 used 상태의 3축 분리**(배치④ 윤회와 동일 원칙 — used 기록·리셋·세이브 무변경) 전부 유지 |
| baal_boots | 날씨 흡수 게이지 +400 | 날씨 감지/흡수/라운드 부가효과 상태머신 무변경 — 흡수 자격만 게이트 |
| pandora_legacy | 승리 시 발동 55% / 매직찬스 20% | **자격+발동확률만 게이트.** 3택 보상 풀은 무변경 — 풀 재정의는 S2 확정 사항(D3). ON 테스트에서 기존 아이템 3택이 뜨는 것은 과도기로 허용, 보고서에 명시 |

## 초월자의 관 — 유효레벨 소스 전환 (이번 배치의 핵심)

crown은 유효레벨 보너스를 "받는" 쪽이 아니라 "주는" 쪽이다:

- OFF: 기존 그대로 — 장착 crown 아이템의 롤(+1~2)이
  `item_perk_level_bonus`류 보너스 소스.
- ON: crown **퍽** 레벨>0이면 고정 +2가 보너스 소스. 장착 아이템은 무시
  (완전 대체).
- 게이트 위치는 보너스 재계산/산출 경로 (`recalculate_transcendent_crown_*`
  류) — 소비 측(유효레벨 합성 체인)은 무변경.
- **순환/수혜 규칙 재확인**: 신화퍽 전체는 exempt이므로 crown 보너스가
  신화퍽(자기 자신 포함)의 레벨을 올리지 않아야 한다 — S1b
  `get_effective_converted_perk_level`의 exempt 분기가 이를 보장하는지
  이 배치의 스모크로 명시 봉인.
- **sage_ring 과도기 명시**: sage_ring은 재설계군(비치환)이라 ON에서도
  아이템 경로 그대로다. ON + crown 퍽 + sage_ring 장착이 공존하면 보너스가
  합산되는데, 이는 마이그레이션 전 과도기 스펙으로 **허용** (라이브 전환
  시점에 S5 마이그레이션이 동반되므로 실제 혼재 구간은 짧음). 합산을
  막는 특수 처리를 추가하지 말 것.

## 범위 (이번 실행)

1. 11종의 활성 자격 게이트(`is_*_effect_active` 또는 기존 `is_*_active` 직접
   게이트 — 배치④ 판단 기준: 해당 함수가 자격 판정 단일 소스면 직접, owner/
   snapshot 장착 노출과 얽혀 있으면 별도 신설) + 수치 게터의
   `get_mythic_value` 전환.
2. crown 보너스 소스 전환 (위 전용 절).
3. 우회 경로 전수 감사: 11종의 장착 직독 소비자 grep, 전환 vs 유지 분류
   보고. 특히 cape 슬롯 수 3경로, 오딘/뿔딸기의 패배·커맨드 진입점, 바알
   날씨 훅.
4. 스모크 신설 + values_smoke fixture 교체 (아래).

## 범위 제외 (하지 말 것)

- 판도라 3택 풀 재정의(S2/D3), 신화퍽 등장 채널(S5), 세이브 마이그레이션(S5)
- 부활·변신·날씨·소용돌이·전기스턴·퍽선택 상태머신의 리팩터링
- 오딘의 눈 포팅 잔여 트랙(어둠의늪·변신렌더·사운드)
- 삭제군/재설계군 12종 (sage_ring 포함 — 비치환, 아래 fixture로만 사용)
- HUD/장비 표시(S3), 라이브 플래그 ON

## 스모크

### 신설: `godot/tests/perk_conversion_gate_batch5_smoke.gd`
- [ ] OFF-parity: 11종 (장착+롤 픽스처 → 기존 합성값)
- [ ] ON 고정값: 11종 전 레인 `get_mythic_value` 수치 정확
- [ ] ON 레벨0 / item-only: 비활성 / ON item+perk: 완전 대체 (고롤 무시)
- [ ] **exempt 봉인**: ON + crown 퍽 보유 상태에서 다른 신화퍽(예: odins_eye)
      의 유효 레벨이 1 그대로 (crown이 신화퍽을 버프하지 않음), crown 자신도 1
- [ ] **crown 보너스 소스**: ON + crown 퍽 → 일반퍽(예: star_detector base 2)
      유효레벨 = 4 / OFF + crown 아이템 롤 → 기존 보너스 그대로
- [ ] used/1회 상태 독립성: 뿔딸기 1스테이지 1회 상태가 ON 게이트와 분리
      (사용 후 퍽 보유여도 같은 스테이지 재변신 불가)
- [ ] 실 소비자 레그 최소 4개: cape 유효 슬롯 수, 오딘 부활 자격 판정,
      뿔딸기 커맨드 진입 자격, 판도라 발동 자격
- [ ] 플래그 시작/종료 OFF 복원

### 기존 씰 의도적 갱신: `perk_conversion_values_smoke.gd`
celestial_armor fixture 은퇴(배치⑤ 스모크로 이관) → **sage_ring + dashgear
(각 롤 2레인)로 교체**. 레그 의미 재정의: "미전환 안전망"이 아니라
"**비치환군(삭제군/재설계군)은 전환 플래그 ON에도 기존 아이템 경로 그대로**"
— 삭제군/재설계군이 정리되는 S2/S5 슬라이스에서 함께 은퇴할 봉인. 어설션
메시지도 이 의미로 갱신. 보고서에 명시.

### 회귀 유지 (필수 씰)
- `player_input_reader_same_frame_edge_smoke.gd` (뿔딸기 커맨드 리스너 엣지)
- 오딘의 눈 씰 4종(finalize_paddle_land / death_cinematic / revival_penalty /
  chance_gem_floor), heavenly_cape 슬롯 관련 씰, baal/poseidon/ragnarok/
  megingjord/pandora 관련 기존 씰 — 발견되는 것 전부
- 배치①~④ 씰 + catalog/values 스모크 GREEN
- 헤드리스 로드 체크 + 워닝 스캔

## 반증검증 (필수 — git reset/checkout/stash 금지, in-place 토글 + 즉시 복원)

1. exempt 분기를 임시 무력화(crown 보너스가 신화퍽에도 적용되게) →
   exempt 봉인 레그 RED → 복원
2. 11종 중 1종(hermes_shoes 권장)의 OFF 분기를 퍽 경로로 강제 →
   OFF-parity RED → 복원

## 트랩 노트

- cape 고정 효과 글로벌은 `_reset_roll_bonuses_to_default()`류 리셋 경로에
  절대 넣지 말 것 (checklist §0.2 Heavenly Cape 소실 사가) — 게이트 추가가
  기존 sync 전담 소유 구조를 옮기면 안 된다.
- 뿔딸기/오딘의 변신·부활 finalize 시점 처리(착지 리셋, 락 누수 씰)는 기존
  씰이 지키고 있다 — 자격 게이트가 finalize 경로에 새 분기를 만들지 말 것.
- 판도라 발동은 라운드 승리 훅 — 훅 위치/순서 무변경, 자격만.
- 핫패스 딥카피 금지, 신규 owner 키 필요 시 중단·보고, UTF-8 BOM 금지,
  `.agents/skills/` 미러 수동 편집 금지.

## 완료 보고 형식

(1) 변경 파일 + 아이템별 게이트 지점(직접 게이트 vs 별도 신설 선택 사유 포함),
(2) crown 보너스 소스 전환 지점과 exempt 검증 결과, (3) 우회 경로 감사 결과,
(4) 신설 스모크 결과 원문 + values fixture 교체·의미 재정의 내역,
(5) 반증검증 2건 RED→GREEN 증적, (6) OFF 무변화 자가 확인 진술,
(7) 판도라 과도기(기존 3택 유지) 명시, (8) 이탈/가정.
