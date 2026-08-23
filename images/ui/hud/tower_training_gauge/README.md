# 수련 타이밍 게이지 아트 후보 v1

피드백3 9항의 **1단계 아트 생성만** 수행한 후보 세트다. 기준 커밋은
`d7d5c5b6b90b8f1102b8eafe0f24ba1b2b0cf64b`, 브랜치는
`codex/fb3-gauge-art-20260823`이다. 사용자 승인 전이므로 `godot/` 배치,
리소스 프리웜, 렌더러 배선은 하지 않았다.

## 승인 후보

| 부품 | 원본 | 알파 준비본 | 잘라낸 후보 | 후보 크기 | 예상 런타임 크기 |
|---|---|---|---|---:|---:|
| 트랙 프레임 | `tower_training_gauge_frame_imagegen_v1_source.png` | `tower_training_gauge_frame_imagegen_v1_alpha.png` | `tower_training_gauge_frame_imagegen_v1.png` | 1593x156 | 357x29 |
| 경계 틱 | `tower_training_gauge_tick_imagegen_v1_source.png` | `tower_training_gauge_tick_imagegen_v1_alpha.png` | `tower_training_gauge_tick_imagegen_v1.png` | 123x517 | 약 8x41 |
| 중심추 | `tower_training_gauge_pointer_imagegen_v2_source.png` | `tower_training_gauge_pointer_imagegen_v2_alpha.png` | `tower_training_gauge_pointer_imagegen_v2.png` | 218x918 | 약 12x43 |

세 부품을 실제 357x29 게이지에 4배 확대 합성한 검수 이미지는
`tower_training_gauge_imagegen_v1_review.png`다. 파랑 GREAT 구간, 2% 빨강
CRITICAL 구간, 경계 틱 4개, 중립 중심추를 어두운 수련장 바탕과 밝은 한지
바탕 양쪽에서 확인한다.

## 알파 및 앵커

- 세 후보 모두 RGBA이며 네 모서리 알파가 0이다.
- 프레임 후보 알파 bbox: `(12, 12, 1581, 144)`.
- 프레임의 닫힌 내부 투명 창: `(163, 60, 1427, 105)`, 54,846px.
- 357x29에 맞추면 내부 창은 약 `(36.5, 11.2)-(319.8, 19.5)`로 투영된다.
- 현행 347px 트랙의 2% CRITICAL 폭은 약 6.94px이며 검수 합성에서 프레임
  안쪽으로 읽힌다.
- 틱 후보 알파 bbox: `(16, 16, 107, 501)`.
- 중심추 후보 알파 bbox: `(16, 16, 202, 902)`.
- 프레임 생성본은 이미 알파를 가졌지만 알파 1짜리 넓은 평면 잔여가 있어
  알파 1 이하를 0으로 정리했다. 틱과 중심추는 생성기가 구운 중성 체크무늬
  RGB를 `.claude/skills/sprite-generation/remove_bg.py`로 제거했다.
- 최종 후보의 완전 투명 픽셀 RGB도 0으로 정리해 필터링 시 평면 헤일로가
  스며들지 않게 했다.

프레임은 목표보다 4배 이상 큰 소스다. 고정 357x29에서는 전체를 맞춰 그릴
수 있고, 가변 폭이 필요하면 좌우 장식 캡을 고정하고 조용한 중앙 레일 구간
약 `x=594..992`만 수평 반복 또는 슬라이스-스트레치하는 방향이 안전하다.
정확한 9패치 마진은 사용자 승인 뒤 실제 Godot 배선 캡처로 확정한다.

## 런타임 계약

- 빨강/파랑 판정 구간 fill은 비트맵에 굽지 않았다. 상태 모델 경계값을
  소비하는 현행 절차 드로우가 계속 소유한다.
- 그리기 순서는 판정 구간 fill, 프레임, 틱 4개, 중심추다.
- 중심추는 밝은 중립 황동이므로 런타임 `modulate`로 CRITICAL/GREAT 색을
  반영한다.
- 승인 뒤의 배선은 `godot/assets/ui/tower_training_gauge/`에 별도 승격하며,
  미로드 시 현행 절차 드로우 폴백을 유지해야 한다.

## 거부 후보 보존

`rejected/`에는 생성 손실 방지를 위해 다음 원본/후보를 보존한다.

- 첫 틱: 장창 형태와 넓은 광원 헤일로로 거부.
- 첫 중심추: 장창/무기 형태로 거부.
- 중심추 v1: 배경 제거는 통과했으나 넓은 방패형 판이 소형 포인터로 읽히지
  않아 거부.

정확한 생성 프롬프트와 각 반복의 판정은 `PROMPTS.md`에 있다.

## 승인 게이트

이 세 부품은 아직 후보이며 사용자 승인 전에는 배선하지 않는다. 승인 시
트랙 프레임, 틱, 중심추를 각각 승인하거나 재생성을 지시할 수 있다.
