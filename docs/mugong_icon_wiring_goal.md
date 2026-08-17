# 무공 아이콘 신세대 배선 완성 /goal 지시문 (2026-08-18)

- **문제**: 환격전 세대 무공 아이콘(`assets/sprites/perks/*_mugong_icon.png`,
  2026-07-28 제작)이 존재하는데 `runtime_perk_icon_renderer.gd` 정적 맵은
  10종만 신세대를 참조하고 81종이 구세대(`*_perk_icon.png`, 링피아 스타일)로
  남아 있다. 라이브 퍽 선택 카드가 구세대 아이콘을 그린다(사용자 실보고:
  회선철수·칠채순환).
- **목적**: 신세대 에셋이 존재하는 모든 무공의 아이콘 참조를 전 소비자에서
  신세대로 교체한다. **아트 신규 생성 금지** — 배선만.
- **완료 보고**: `docs/mugong_icon_wiring_report.md`. 푸시 금지.

## 1. 작업

1. **에셋 감사**: perk id별로 `*_mugong_icon.png` 존재 여부를 전수 대조.
   존재하는 것만 교체 대상. **미존재 경로 배선 절대 금지** (GRT-004 —
   예약-부재 에셋 per-frame 재스탯 트랩). 신세대가 없는 무공은 구세대 유지
   + 보고서에 "아트 트랙 후보" 목록으로 기재.
2. **소비자 전수 교체**: `runtime_perk_icon_renderer.gd` 맵뿐 아니라
   `_perk_icon` 참조를 가진 모든 소비자를 감사한다 (실측: character_info
   overlay frame/prewarm/core/stats presenter, perk_fusion_overlay_renderer,
   angel_blessing_roll_overlay_host, runtime_perk_debug_picker 등).
   같은 무공이 화면마다 다른 세대로 보이는 상태를 남기지 않는다.
   프리웜 목록도 같은 경로로 갱신(스펙↔로더 동기화).
3. **씰 락스텝**: `runtime_perk_general_icon_static_smoke` 등 아이콘 경로를
   단언하는 씰을 신세대 기준으로 갱신하고, 구세대 경로 주입 RED 반증을 남긴다.
4. **픽셀 QA**: 퍽 선택 카드(교체된 무공 2종 이상 포함)와 TAB 정보창의
   Vulkan 실캡처로 신세대 아이콘 렌더를 육안 확인한다.

## 2. 규율

- 커밋 분리(맵·소비자 교체 / 씰 락스텝), 한국어 제목, 푸시 금지.
- 수치·기능·카피 변경 금지. 아이콘 경로 문자열 교체와 그 검증만.
- 플레이 중 검증 신정책 준수, 검증 전 로그 백업.
- 판정 불가(어느 세대가 정본인지 애매한 개별 케이스)가 나오면 해당 항목만
  구세대 유지 + 보고서 기재.

**완료 선언 조건**: 신세대 존재분 전량 교체 + 소비자 세대 불일치 0 + 씰
락스텝 GREEN + 픽셀 QA GREEN + 보고서 완성.
