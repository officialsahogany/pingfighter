# 지시문 K — 수련 게이지 눈금 적1+청4 계약 변경 (피드백4 7항)

- **발행**: 관제탑 2026-08-24. 기준 HEAD `bc5890dd1`. CI/pre-push 락스텝 227.
- **격리 워크트리**: `D:\codex_tmp\bosspong_fb4_gaugetick_bc58` (브랜치
  `codex/fb4-gauge-tick-20260824`). 주 파일 `tower_ascent_flow_renderer.gd`
  게이지 구간(3880~4260)·타이밍 씰 — 지시문 I2의 노드아트 구간과 파일은
  같으나 구간이 달라 병렬 가능(통합 시 관제탑이 충돌 해소).
- **금지**: 본 트리 직접 편집·푸시·통합. 보고 후 대기.

## 배경 (구현 결함 아님 — 계약 변경)

현행 "금박 틱 4개"는 지시문 D(`feedback3_training_gauge_art_codex_handoff.md:27~28`,
"세로 틱 1종 … 4곳 재사용")에 **기록된 계약 그대로**다. 사용자가 새 계약을
확정: **붉은 눈금 1개(목표 중심) + 파란 눈금 좌우 2개씩(기존 4개 판정 경계
위치)**. 동반 결함 1건: 틱 폭 9.75px가 기본 럭 회심 셀 6.94px(최소 럭
3.47px)보다 넓어 중앙 3틱이 뭉치고 빨간 회심 셀·금테를 가린다.

## 작업

1. `_draw_training_timing_gauge_bitmap_tick`(:4195)에 modulate 인자 추가
   (포인터의 `marker_modulate` 방식 :4245~4256과 동형) 후:
   - **적 틱 1개** = `target_position`. 기존 틱 자산(적색 밴드 내장)
     원본 그대로 사용.
   - **청 틱 4개** = 기존 4 경계(`great_left_start`/`critical_start`/
     `critical_end`/`great_right_end`).
2. 청 변형 생성(우선안): 기존
   `assets/ui/tower_training_gauge/tower_training_gauge_tick_imagegen_v1.png`의
   적색 밴드 픽셀만 오프라인 색상 회전(적→청, 스크립트 결정적 변환)한
   `..._tick_blue_v1.png` 신규 파일. 금박 기둥부는 불변 유지. ⚠modulate
   단독으로 골드+적 원본을 청색화하면 탁해짐(GRT-047 계열) — 결과가
   탁하면 중단하고 보고(관제탑이 이미지 스킬로 재생성).
3. **폭 상한**: 라이브 회심 셀 픽셀 폭 대비 캡
   (`draw_width = minf(비율폭, critical_cell_px * 0.8)` 수준) 또는 동등
   수단으로, 최소 럭에서도 회심 셀·금테가 가려지지 않게. 럭 8% 상한에서도
   확인.
4. ⚠GRT-018: 틱 x좌표는 전부 상태 모델 선계산값
   (`tower_training_timing_state.gd:140~152`) 소비 — 렌더러측 정책 재계산
   금지. `target_position` 소비도 같은 씰로 확장.
5. ⚠GRT-004: 신규 청 틱 PNG는 자산 착지+`file_exists`/핀 등재와 같은
   슬라이스로만 배선.
6. 프레임(9패치)→틱 드로우 순서 유지: 틱은 프레임의 어두운 트랙
   언더레이(:3895~3896) 위에 있어야 함.
7. `docs/feedback3_training_gauge_art_codex_handoff.md`에 계약 개정 각주
   1줄 추가(적1+청4로 변경, 피드백4 7항).

## 씰

- 레이아웃 헬퍼 추출 후 `tower_training_timing_judgment_smoke`에서 기존
  300px/럭2 계약 트랙 기준: 적 틱 정확 1개 @150px + 청 틱 4개
  @135/147/153/165 단언(기존 경계 상수 재사용, judge_position 락스텝).
- 폭 상한 레그: 최소 럭에서 `draw_width <= 회심 셀 픽셀 폭` 단언
  (`get_training_timing_gauge_asset_contract()`의 runtime_gauge_size 사용).
- RED 반증: 현행 전금박 4틱 레이아웃(또는 폭 캡 제거) 픽스처가 신규
  단언에 실패함을 먼저 확인.
- 자산 핀 락스텝: `TIMING_GAUGE_ASSET_SPECS`(:21~42) sha256/size 핀에 청
  틱 추가. modulate 경로에는 modulate 인자 전달 소스 단언.
- 픽셀 QA: `run_tower_training_timing_visual_qa.ps1` Vulkan 재캡처 —
  적1+청4 판독 + 2% 빨간 회심 셀이 가려지지 않음(D 지시문 :50 게이트).

## 게이트·보고

포커스드 스모크(+RED 반증) → `-Paths` 경고 → 헤드리스 로드 →
`git diff --check` → 캡처(기본 럭·최소 럭·최대 럭 3장). 보고=워크트리·
커밋 해시·씰 종단선 원문·캡처 경로·청 변형 방식(회전/스킬 재생성)·미해결.
