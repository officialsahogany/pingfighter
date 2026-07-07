# S1c 배치④ 코덱스 핸드오프 — 시스템 결합군 3종 효과 게이트 전환

기준 문서: `docs/passive_to_perk_conversion_plan.md` (v3) §4-A / §7-2.
선행: S1c 배치①②③a③b PASS (일반퍽 23/26종). 확립 패턴 재사용:
수치 게터 게이트 + 불리언 효과-활성 게이트(`is_*_effect_active`,
OFF=equipped / ON=facade 레벨>0).
발주: 2026-07-07. Claude 기획 → 사용자 직접 Codex 전달 → Claude 적대 리뷰.

**이 배치가 끝나면 일반퍽 26종 전환이 완성된다.** 3종 모두 라운드/런/세이브
인프라와 결합된 아이템이라, 아래 아이템별 불변식이 이번 핸드오프의 본체다.

## 합격 조건

1. 플래그 OFF(기본): 게임 규칙 완전 무변화.
2. 플래그 ON: 3종 효과가 퍽 경로로 완전 대체.
3. **발동 이후의 시스템 상호작용(라운드 재시작·스테이지 재시작·자동 사용
   실행)은 한 줄도 변경하지 않는다** — 게이트는 "발동 자격" 판정에만 들어간다.

## 배치④ 대상 3종

| perk_id | 효과 | 값 key | 아이템별 불변식 |
|---|---|---|---|
| revival (윤회) | 패배 직전 1회 발동, 스테이지 재시작 | revival_count [1.0] (static, max_level 1) | **used/spent 상태는 활성 게이트와 별개 축** — ON+퍽 보유여도 이미 사용했으면 재발동 불가. used 플래그의 기록·리셋·세이브 연동 경로 무변경 (owned≠equipped≠used 3축 구분) |
| foul_whistle (반칙호루라기) | 라운드 패배 시 확률로 실점 무효 + 라운드 재시작 | negate_chance_pct [3..11] | **라운드 재시작 인프라 무변경** — 재시작 트리거/전파 경로는 그대로, 발동 확률과 활성 자격만 게이트. (round_restart 제네릭 인프라는 휴면 유지 정책 — grep 0건으로 보여도 제거·정리 금지) |
| smartphone (오토파일럿) | 회복/스톱워치/홀리베리어 자동 사용 | smartphone_auto_use_enabled [1.0] (static, max_level 1) | **입력엣지 트랩** — 자동 사용 스캔이 slot key edge 상태를 재작성하지 않아야 한다는 기존 불변식 유지 (`active_item_slot_controller_smartphone_cooldown_smoke.gd` 씰 GREEN 필수). 스캔·자동사용 실행 로직 무변경, 활성 자격만 게이트 |

## 범위 (이번 실행)

1. 3종의 불리언 효과-활성 게이트 신설·전환 (①②③ 패턴).
2. foul_whistle 수치 게터(negate 확률) 게이트 전환. revival/smartphone은
   static — 활성 게이트만 (값 테이블의 [1.0]은 존재 확인용, 수치 소비 없음).
3. 우회 경로 전수 감사: 3종의 장착 직독 소비자 grep (특히 패배 처리 경로의
   윤회/반칙 판정 순서, 스마트폰 자동사용 스캔 진입점), 전환 vs 유지 분류 보고.
4. 스마트폰 쿨다운(`smartphone_cooldown_frames`)류 내부 상태의 리셋 경계는
   기존 그대로 (배치③b D4와 같은 원칙 — 경계 자체를 옮기지 않음).
5. 스모크 신설 + values_smoke fixture 교체 (아래).

## 범위 제외 (하지 말 것)

- 배치⑤(신화퍽 11종)
- 라운드/스테이지 재시작 시퀀스, 패배 처리 순서, 자동 사용 대상 선정 로직의
  변경·리팩터링
- 윤회 used 플래그의 저장 포맷/리셋 시점 변경
- HUD/장비 표시(S3), 획득 경로(S2), 마이그레이션(S5), 라이브 플래그 ON

## 스모크

### 신설: `godot/tests/perk_conversion_gate_batch4_smoke.gd`
- [ ] OFF-parity: 3종 (foul_whistle은 장착+롤 확률, revival/smartphone은
      장착 시 활성)
- [ ] ON Lv1/Lv5: foul_whistle 확률 3%/11%
- [ ] ON 레벨0 / item-only: 3종 비활성 (불리언 게이트 양방향)
- [ ] ON item+perk: 완전 대체 (foul_whistle 고롤 아이템 무시)
- [ ] **윤회 used 독립성**: ON+퍽 보유+이미 사용 → 재발동 불가 / used 리셋
      경계(기존 그대로) 후 → 재발동 가능
- [ ] 실 소비자 레그: 패배 처리 경로의 윤회 발동 자격 판정, 반칙 무효화
      판정 진입, 스마트폰 자동사용 스캔 활성 게이트
- [ ] 플래그 시작/종료 OFF 복원

### 기존 씰 의도적 갱신: `perk_conversion_values_smoke.gd`
일반퍽 26종이 전부 전환되므로 fixture의 foul_whistle을 제거하고 **미전환
신화 아이템으로 교체** (롤 2레인이 있는 celestial_armor 권장) — 무변화
레그를 배치⑤ 완료까지 살아있는 안전망으로 유지. 보고서에 명시.

### 회귀 유지 (필수 씰)
- **`active_item_slot_controller_smartphone_cooldown_smoke.gd` GREEN**
  (입력엣지 불변식)
- revival/foul_whistle/smartphone 관련 기존 포트·런타임 씰 전부 GREEN
- 배치①②③ 씰 + catalog/values 스모크 GREEN
- 헤드리스 로드 체크 + 워닝 스캔

## 반증검증 (필수 — git reset/checkout/stash 금지, in-place 토글 + 즉시 복원)

1. 윤회 ON 분기에서 used 체크를 임시 우회 → "used 독립성" 레그 RED → 복원
2. foul_whistle OFF 분기를 퍽 경로로 강제 → OFF-parity RED → 복원

## 트랩 노트

- 패배 처리 경로에는 부활류 우선순위가 있다 (오딘의 눈[신화·⑤ 대상]이 먼저
  체크되는 체인) — 이번 배치는 윤회의 "자격 판정"만 게이트하고 **체인 순서는
  절대 재배치하지 않는다**. 오딘의 눈 쪽 코드는 읽기만 하고 무변경.
- 스마트폰 자동 사용은 `update_active_items`보다 먼저 도는 스캔 경로가
  있으므로, 게이트 추가 위치가 스캔 진입 "자격"이어야지 스캔 내부의 엣지
  bookkeeping을 건드리는 위치면 안 된다.
- 반칙호루라기 발동 확률 표시(툴팁/디버그)가 있으면 같은 게이트 게터로 수렴.
- 핫패스 딥카피 금지, 신규 owner 키 필요 시 중단·보고, UTF-8 BOM 금지,
  `.agents/skills/` 미러 수동 편집 금지.

## 완료 보고 형식

(1) 변경 파일 + 아이템별 게이트 지점, (2) 우회 경로 감사 결과 (패배 처리
체인에서의 판정 위치 포함), (3) 신설 스모크 결과 원문 + values fixture 교체
내역, (4) 반증검증 2건 RED→GREEN 증적, (5) 스마트폰 입력엣지 씰 GREEN 확인,
(6) OFF 무변화 자가 확인 진술, (7) 이탈/가정.
