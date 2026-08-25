# 지시문 Q4 — 각시탈 비전초식 "부채던지기" 신설 (피드백5 6항)

- **발행**: 관제탑 2026-08-25. 기준 HEAD `475523dec`. CI/pre-push 락스텝 236.
- **격리 워크트리**: `D:\codex_tmp\bosspong_fanvision_4755` (브랜치
  `codex/fb5-gaksital-fan-vision-20260825`).
- **금지**: 본 트리 직접 편집·푸시·통합. 보고 후 대기.
- **⚠WIP 지뢰**: 본 트리 `stage1_gaksital_fan_throw_skill_state.gd`는
  미커밋 WIP(M) — 워크트리(HEAD)에서 작업하고 공유 모듈 추출 시 이식
  충돌은 통합 시 관제탑이 해소. 해당 파일의 의미 변경 최소화.

## 사용자 확정 스펙

- 각시탈 **클리어 보상** 비전초식 "부채던지기": 각시탈이 던지는 것과
  동일한 부채 투사체를 플레이어가 던짐. 보스 적중 시 **넉백+약한
  스턴**(각시탈 것과 동일 감각). **기력 80 · 쿨타임 5초**.
- 관제탑 밸런스 메모(참고·스펙 변경 아님): 기존 비전 3종은
  달지 120/32s·연묘 200/35s·청린귀 250/50s — 80/5s는 최저가·최단쿨.
  씰 수치는 사용자 확정값 그대로 봉인하되, 라이브 체감 후 조정 여지를
  보고에 1줄 명시.

## 인프라 (관제탑 프로브 실측 — 전부 기존 정본 확장)

1. **획득 경로 = 기존 보스 비전 상자 파이프라인**: 보스 층 클리어 →
   `tower_ascent_chest_context_builder._get_boss_vision_offer_id` →
   CHEST_SECRET_CHOSIK → reserved perk offer → 퍽 선택 모달의
   boss_vision_reserved 레인 → `unlocks_skill`. 현재 stage1은
   **달지 variant만 매핑**되고 각시탈/포도대장은 "" 반환(상자가 조용히
   다운시프트) — 각시탈 매핑 추가가 핵심(양 매핑 사이트+
   `_VISION_SKILL_ID_BY_UNLOCK_ID` 확장).
2. **정의 = common_skill_catalog** 비전 5요소 상수(ID/UNLOCK/COLOR/
   COST 80.0/COOLDOWN 5.0) + 7개 국어 카피(manual_name·perk_
   description) + `vision_chosik:true, boss_id:"gaksital",
   slot_occupancy:"active_orb", exclude_from_perk_fusion` +
   is_common_skill/unlock 체인·쿨감 배열 확장. 캐릭터 5종 config는
   공통 위임이라 자동.
3. **입력**: `vision_modifier` 홀드 + 빈 방향 에지(달지=Up·연묘=Down
   — 부채는 빈 에지 하나 선점, 좌/우 중 택1 후 보고).
4. **투사체 = 각시탈 부채 재사용**: 텍스처
   `boss_fan_projectile_texture`(프리웜 기존)·렌더 레시피(회전 쿼드,
   GRT-033 정규화 UV) 재사용. 모션/페이로드/오디오 상수는 달지 비전
   전례처럼 **공유 stage1 모듈로 추출**해 보스 스킬과 플레이어 비전이
   같은 정본 소비(⚠형제 상수 금지 — 넉백 파리티 규칙). 방향은
   플레이어→보스 미러, 보스 rect 히트 테스트.
5. **보스 CC = 기존 프리미티브**: `status_effect_state.apply_status
   ("boss","stun",frames,{knockback_vel...})` — 밀크샷/박치기 템플릿
   (넉백은 스턴 status에 실어야 함: boss_ai 스턴 분기가 패들 넉백
   채널보다 선행). 스턴 렌더는 각시탈 전용 스턴 시트 포함 기존 팬아웃.
   ⚠스테이지2 상태 면역창은 기존 게이트 그대로.
6. 상태 머신 = `dalji_vision_chosik_state.gd` 템플릿(COST/COOLDOWN
   카탈로그 파생·reset_round/쿨다운 트리오·GRT-060 계약: 양수 초기
   쿨다운·round 보존).

## 씰

- 획득 레그: 각시탈 클리어 상자 → 비전 오퍼 예약 → 퍽 모달 보호
  레인 → 습득 → 스킬 장착, 실 경로 관통. 포도대장/달지 클리어 시
  부채던지기 미제공 음성 레그.
- 발동 레그: 기력 80 차감·쿨 5초 재장전(GRT-060 양수 초기·라운드
  보존 계약 씰 자동 편입 — 카드 payload 발동분류 선언 포함)·투사체
  보스 적중 → 스턴+넉백 status 적용·미적중 소멸.
- 파리티 레그: 공유 모듈 상수 == 보스 측 소비값(형제 상수 부재
  소스 단언).
- 표시: 카드/툴팁 7개 국어·한국어 엠대시 금지. 쿨다운 계약 스모크
  (14보스+비전 자동 발견) GREEN 유지.
- 게이트: 포커스드 스모크(+RED 반증) → `-Paths` 경고 → 헤드리스
  로드 → diff → 발동 Vulkan 캡처 1장(부채 비행+보스 스턴 별).

## 보고

워크트리·커밋 해시·씰 종단선 원문·선택한 입력 에지·캡처 경로·
미해결.
