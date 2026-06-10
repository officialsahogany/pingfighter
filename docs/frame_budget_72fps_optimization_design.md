# 144Hz 맞춤형 프레임 — 72 FPS 예산 최적화 설계 (2026-06-10)

목표: 144Hz 모니터에서 Stable Monitor 자동 매핑을 144→48에서 **144→72로 올려도
끊김이 없도록**, 전투 프레임당 메인스레드 비용을 2~3ms 감량한다.
완료 게이트를 통과하기 전에는 Stable Monitor 매핑을 건드리지 않는다.

## 0. 측정된 현재 상태 (BattlePerf, 2026-06-10, RTX 5070 / 144Hz / VSync On / 72캡)

72 FPS 캡의 프레임 예산은 13.89ms. "프레임 더블링"은 2초 윈도우의
`delta=proc max`가 27.78ms(=한 프레임 거름) 이상인 경우.

| 스테이지 | 더블링 윈도우 비율 | draw 스크립트 avg | 비고 |
|---|---|---|---|
| 1 | 11~20% | 4.0~5.0ms | 체감상 "매끄러움"의 기준선 |
| 2 | 33~72% | 4.7~5.5ms | 세션에 따라 변동(바이퍼 제트팩 시 악화) |
| 3 | 79% | ~4.9ms | |
| 4 | 81% | ~5.2ms | |

프레임당 비용 분해(전투 중 전형값): draw 스크립트 4.7~5.5ms + 물리 스크립트
2.2~2.8ms + 엔진측 캔버스 처리(proc_after_draw) 1.3~4.6ms + shell 0.3ms
≈ 10~13ms — 예산 13.89ms에 상시 근접, 스파이크 시 초과.

반복 측정된 감량 대상(stage_hot 평균, 매 프레임):

- `stageN.pillar.hud` / `hud_scene`: **1.05~1.18ms** (이 안에
  `stage1.pillar_ui.total` 0.60~0.76ms 포함 — 전 스테이지 공용)
- `stage1.pillar_ui` 내부: boss_dash 0.16~0.22, skill_orbs 0.13~0.18,
  player_dash 0.10~0.12, gauge_orb 0.08, combo 0.07~0.15
- `draw.scene.playfield` 2.0~2.6ms: actors.total 0.53~0.77,
  **context.build_all 0.38~0.49**, ball 0.2~0.3
- `draw.overlay.character_info`: **열려 있는 동안 avg 6.4ms** (단독 예산 초과급)
- 엔진측: draw calls 262~675 / prims 6.5k~20.5k (스테이지 진입 직후 최악)
- 스파이크: scoreboard result callback 4~5ms,
  `stage_transition_loading.step.8` 12.85ms가 전투 윈도우에 1회 출현(누수 의심)

## 1. 완료 게이트 (이걸 통과해야 144→72 승급)

1. 72캡에서 스테이지 1~4 각각 2분 플레이 시 **더블링 윈도우 < 15%**.
2. 인게임 체감 확인(체감이 진실 — 코드 지표만으로 합격 처리 금지).
3. 시각 회귀 없음: 오브 HUD, 필러 크롬, 캐릭터 정보 패널이 캐싱 전과 동일하게 보임.

측정 방법: `godot/`에 `battle_perf_log.flag` 생성 후 플레이, 로그에서
```powershell
# 스테이지별 더블링 비율
$lines = Get-Content "$env:APPDATA\Godot\app_userdata\pingfighter\logs\godot.log" |
  Where-Object { $_ -match '^\[BattlePerf-Gap\]' }
# stage=N별로 delta=proc=...(max=...) 의 max>20ms 비율 집계 (calls<100 윈도우는 비전투로 제외)
```

## 2. 슬라이스 (레버리지/위험 순)

### S1. 스테이지 필러 HUD 정적 크롬 캐싱 (−0.4~0.7ms, 전 스테이지)
- 대상: `stage2_pillar_scene_drawer.gd` / `stage3_pillar_scene_drawer.gd` 등
  `stageN.pillar.hud` 경로의 **프레임 불변 부분**(백플레이트, 칼라, 프레임 장식).
- 방법: 해상도·레이아웃 키로 1회 렌더 → `ImageTexture` 캐시 → 매 프레임 blit.
  동적 요소(쿨다운 웨지, 카운트 텍스트, 리퀴드, 펄스)는 즉시드로 유지.
- 무효화 키: view_size / game_offset / render_scale 변경, 스테이지 전환.
- 캐시 생성은 prewarm 단계에서 — **핫패스 첫-프레임 생성 금지**(레이지 init 트랩).

### S2. 공용 오브 HUD 정적 레이어 캐싱 (−0.2~0.35ms, 전 스테이지)
- 대상: `godot/scripts/hud/stage1_pillar_ui_renderer.gd`와 그 하위
  (pillar_dash_orb / status_orb / liquid / orb drawer 체인).
- 방법: 오브별 정적 링/글로우/프레임 레이어를 (크기, 상태버킷) 키로 캐시.
  웨지·텍스트·리퀴드 파면만 즉시드로.
- 주의: 플라즈마 셰이더 패스(대쉬 오브 내부)는 이미 셰이더라 GPU 비용 —
  건드리지 않는다. 대상은 CPU 즉시드로 벡터 호출(arc/polygon)뿐.

### S3. context.build_all 재구성 감축 (−0.2~0.3ms)
- 매 프레임 dict 재조립(0.38~0.49ms)을 dirty-flag/재사용으로 전환.
- 주의: 공유 dict 재사용은 소유권이 명확할 때만. 모듈이 dict를 들고 가는
  경로(스냅샷 저장)가 있으면 그 키만 복사 유지.

### S4. 프리미티브 감축 @72캡 (엔진측 proc_after_draw 감소)
- arcs/ellipse/sector의 세그먼트 수를 `FPS_CAP_EFFECT_SCALE` 게이트로 추가 감축.
- 트랩: 희소 파티클에는 stride 데시메이션 금지(깜빡임 — 기존 메모리 규칙).
  세그먼트 감축은 폐곡선/호에만.

### S5. 캐릭터 정보(TAB) 패널 캐싱 (열림 중 6.4ms → 목표 <2ms)
- 대상: `character_info_overlay_frame_presenter.gd` 경로.
- 패널 백플레이트/장식 1회 굽기 + 스탯 텍스트는 값 변경 시에만 재렌더.
- 전투 중 열어두는 패널이라 더블링 체감에 직결.

### S6. 스파이크 격리
- scoreboard result callback 4~5ms: 점수 일시정지 내라 우선순위 낮음. 분할 검토만.
- `stage_transition_loading.step.8`이 전투 윈도우에서 12.85ms로 1회 측정됨 —
  전환 로딩 단계가 전투 프레임으로 새는 경로인지 확인, 새면 로딩 화면 안으로 가둔다.

## 3. 완료 후: Stable Monitor 144→72 승급 절차

CLAUDE.md "Godot High-Refresh Pacing Trap"의 이동-함께 목록을 그대로 따른다:
`_get_stable_monitor_refresh_rate()`(battle_view_layout.gd) 144→72 매핑,
`pause_menu_overlay.gd` 미러 상수/권장설정 경로,
`language_settings_data.gd` 권장 문구,
`render_fps_cap_settings_smoke.gd` 기본/마이그레이션 assert,
CLAUDE.md 문서 갱신, 디스플레이 설정 스키마 마이그레이션 검토.
physics tick 동기(72) 동작 확인 — 터널링 리스크 문단 참고.
`project.godot` 부트스트랩 캡(48)은 건드리지 않는다.

## 4. 작업 방식

슬라이스 단위로 진행: 구현 → 헤드리스 파스/스모크 → 사용자 인게임 시각 QA +
BattlePerf 재측정 → 다음 슬라이스. 한 슬라이스에서 시각 회귀가 나오면 그
슬라이스만 롤백한다. (연출 계열 대작업 분담 규칙과 동일: 트랩 브리프 포함,
적대적 리뷰는 슬라이스 머지 전.)

## 5. 트랩 브리프 (반복 실패 패턴)

- 핫패스 레이지 init 금지 — 캐시 텍스처 생성은 prewarm/로딩 프레임에서.
- 캐시 무효화 키에 render_scale 누락 시 창 크기 변경에서 흐릿해짐
  (fx_host world-pos 공식 메모리와 동족).
- `draw_set_transform` + IDENTITY 리셋 패턴 금지.
- 좁은 px에서의 텍스트 캐싱은 폰트 fallback/CJK 경로 주의(명시 Nanum CJK 드롭 트랩).
- 측정은 코드 지표가 아니라 더블링%와 인게임 체감으로 판정.
