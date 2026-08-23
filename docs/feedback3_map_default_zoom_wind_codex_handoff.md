# 지시문 B — 지도 기본 배율 4노치 아웃 + 바람 체감 상향 (피드백3 4·11항)

- **발행**: 관제탑 2026-08-23. 기준 HEAD `d7d5c5b6b`. CI/pre-push 락스텝 226.
- **격리 워크트리**: `D:\codex_tmp\bosspong_fb3_mapzoom_d7d5` (브랜치
  `codex/fb3-map-zoom-wind-20260823`). 병렬 안전(타 지시문과 파일 교집합
  낮음 — 단 `tower_ascent_tuning.gd`는 여러 지시문이 스치므로 헝크 최소).
- **금지**: 본 트리 직접 편집·푸시·통합. 보고 후 대기.

## 4항 — 기본 배율 = 현행에서 휠 4노치 줌아웃

실측 사실(중요 — '기본 배율'이 두 개다):
- M키 오버레이: base = `minimum_cover_zoom`(뷰포트 파생, 2020x1246에서
  ≈1.393). `TEMP_MAP_CAMERA_ZOOM(2.15)`은 여기서 미사용.
- 노드 확정 후 트래블: base = `maxf(cover≈2.92, 2.15)` × 인트로 배수
  (1.0→1.18 smoothstep 1.0s, TRAVEL 1.6s 동안 1.18 홀드 — "점점 확대"
  아님). 렌더러 600~603행 `maxf(1.0, …)`가 1.0 미만 인트로 배수를 조용히
  삼킨다(no-op 함정).
- 휠 줌아웃 = 나눗셈(`flow_runtime:316~324`, ÷1.18/노치). 4노치 =
  ÷1.18⁴ = ÷1.9388.

작업:
1. `tower_ascent_tuning.gd`에 `TEMP_MAP_DEFAULT_ZOOMOUT_NOTCHES := 4.0` +
   파생 DIVISOR = `pow(TEMP_MAP_WHEEL_ZOOM_STEP_MULTIPLIER, 4)` 신설.
   ⚠GRT-054: 1.9388 리터럴 금지 — STEP에서 파생. ⚠INTRO_END(1.18)는
   WHEEL_STEP·WHEEL_ZOOM_MAX의 별칭 원천이라 **절대 변경 금지**.
2. M키 기본: 렌더러 604~608행 오버레이 base를
   `clampf(minimum_cover_zoom / DIVISOR, minimum_fit_all_zoom, cover)`로.
   기본값이 커버 미만이 되므로 **633~637행 subcover 판정을 수동 줌 전제에서
   '실효 렌더줌 < cover'로 확장**해야 12층 오버뷰+족자 서라운드가 기본
   상태에서도 켜진다(안 하면 배경 노출).
3. 트래블: base 러프 권장안 — `camera_base_multiplier`를 preferred 고정
   대신 `lerp(cover / DIVISOR, preferred, zoom_in_progress)`로, 인트로 배수
   곡선은 그대로. "이동 중에도 점점 확대"는 `transition_fade_state`
   140~149행 TRAVEL 구간에 홀드(1.18) 대신 진행도 러프 대입. 줌 범위가
   0.72→3.45로 커지므로 `CAMERA_ZOOM_IN 1.0s` 연장 여지를 함께 튜닝해
   체감 캡처로 보고.
4. WHEEL_ZOOM_MAX·STEP 불변(지도 아트 해상도 계약 — 줌아웃은 다운스케일
   방향이라 계약 위반 없음; 상한을 올리는 순간 위반).

씰 락스텝(분산 5+3파일 — 한 슬라이스에서):
`tower_map_wheel_zoom_contract_smoke`(51~57·127·154~158 리셋 봉인),
`tower_fullscreen_map_content_scale_smoke`(58~64),
`tower_fullscreen_map_cover_contract_smoke`(63),
`tower_map_scroll_wiring_contract_smoke`(277),
오버레이 렌더 씰(210), `tower_map_camera_tracking_smoke`(223 — 줌아웃
방향은 완화라 안전), `tower_map_walker_zoom_intro_smoke`. ⚠기본 서브커버화로
M키 상시 렌더가 12층 오버뷰(구름 132콜 예약+경로 점)를 그린다 —
GRT-043 관점 프레임 비용 실측(get_render_cache_debug_state) 동반.
⚠수동 줌 오버라이드로 흉내 금지(reset이 지움 — base 경로로만).

## 11항 — 바람 체감 상향

현행: `TEMP_ROUTE_WIND_FLIGHT_FORCE_PER_FRAME := 0.007`(×세기 1~3,
`tower_ascent_tuning.gd:77`). 전체 비행 드리프트 ≈50/100/150px.

작업: 0.014로 상향(2배) 후
`tower_ascent_route_serve_smoke`의 생산 전체-비행 도달성 씰
(`_verify_wind_production_flight_reachability_and_materiality` — 세기
1~3×양방향×양표적 실제 HIT + 무풍 최적각 MISS 역반증)을 돌려 GREEN이면
채택, 도달성 RED면 0.012→0.010 순으로 하향 탐색. 채택값과 세기 3
좌표적 보정각(스윕 로그)을 보고에 명시. 주석의 50/100/150px 추정치도
새 값으로 갱신.

## 게이트·보고

포커스드 스모크(+반전 RED 반증) → `-Paths` 경고 스캔 → 헤드리스 로드 →
`git diff --check` → **줌 체감 캡처 3장**(M키 기본·트래블 시작·트래블 중)
+ 지도 QA `run_tower_map_zoom_cloud_visual_qa.ps1`. 보고=워크트리·커밋
해시·씰 종단선 원문·캡처 경로·채택 바람 수치·미해결.
