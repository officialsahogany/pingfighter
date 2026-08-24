# 지시문 A-후속 — 상점 compact 카드 비활성 사유 겹침 P2

- **발행**: 관제탑 2026-08-24. 기준 HEAD `cacc539d5`. CI/pre-push 락스텝 230.
- **워크트리**: 기존 `D:\codex_tmp\bosspong_fb3_shop_d7d5`(브랜치
  `codex/fb3-shop-gating-20260823`, 팁 b7650d582) 위 추가 커밋 권장.
  단 베이스가 낡았으므로(현 HEAD와 다수 커밋 차이) 새 워크트리
  `D:\codex_tmp\bosspong_shop_p2_cacc`로 새로 파도 무방 — 보고에 명시.
- **금지**: 본 트리 직접 편집·푸시·통합. 보고 후 대기.

## 결함 (관제탑 캡처 실측)

상점 compact 카드(106px)에서 비활성 카드의 붉은 사유 문구("금화 150
필요, 30 부족")가 설명 마지막 줄과 겹친다. 원인: 사유는 카드 하단 고정
오프셋(`runtime_perk_overlay_renderer.gd` `rect.end.y - 31.0*compact_scale`,
비compact 42.0)에 그려지는데, 상단 앵커 설명 줄이 compact 높이에서 그
지대까지 내려온다. 레거시 212px 카드에서는 안 닿던 선재 수식이 compact
전환으로 드러난 것.

## 작업

compact 카드에서 비활성 사유가 표시될 때(`not enabled` 경로) 설명 줄
예산을 1줄 축소해 하단 사유 지대를 비운다 — GRT-021 원칙: 잘라 그리지
말고 **통째로 생략**(마지막 줄 부분 클립 금지). 비compact 프로파일과
사유 없는 compact 카드는 무변경.

## 씰

- `build_tower_node_card_text_layout` 레그: compact+사유 있음 →
  description_rows 예산 축소 단언 / compact+사유 없음·비compact →
  기존 예산 불변 음성 레그.
- RED 반증: 축소 제거 시 사유 rect와 마지막 설명 줄 baseline 겹침 검출.
- 픽셀 QA: 기회의 보석 비활성 재현 Vulkan 캡처 — 사유·설명 무겹침.
- 게이트: 포커스드 스모크(`tower_training_screen_layout_smoke` 확장 또는
  형제) → `-Paths` 경고 → 헤드리스 로드 → `git diff --check`.

## 보고

워크트리·커밋 해시·씰 종단선 원문·캡처 경로·미해결.
