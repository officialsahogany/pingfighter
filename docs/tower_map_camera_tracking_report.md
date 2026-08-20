# 탑 지도 카메라 추적·경로 아트 완료 보고

- 지시문: `docs/tower_map_camera_tracking_goal.md`
- 기준 커밋: `a435f15823322ff299ac67897b7315b057ad6156`
- 작업 브랜치: `codex/tower-map-camera-tracking-a435`
- 작업 워크트리:
  `C:\Users\woduq\.codex\tmp\bosspong_tower_start_card_amend2_0c60`
- 최종 코드 HEAD: `a8675823f472b11eac5d8670baa962dbd5c93271`
- 통합·푸시: 하지 않음
- 판정: **GREEN** (`blocked=0`, `unverified=0`)

## 1. 슬라이스·커밋 매핑

| 슬라이스 | 커밋 | 결과 |
|---|---|---|
| S1 카메라 모델 | `da4d5ab4e` | 2.15배 세로 월드, 현재 노드 추적, 하단·상단 경계 클램프 |
| S2 경로 형태 | `137c09a76` | `map_seed + from/to ID` 결정론 곡선, 연결 관계 불변, 아이콘 끝점 여백 |
| S3 점선 렌더 | `89f6a62ab` | 원 폴리곤 점선, 정적 경로 캐시, 명시적 점·드로 예산 |
| S4 이동 연출 연동 | `9d53024d1` | SD 이동체와 카메라가 같은 물리 틱 곡선 좌표 사용, 정본 문구 정합 |
| S5 씰과 캡처 | `a8675823f` | 전용 씰, CI·프리푸시 락스텝, Vulkan·연속 프레임·라이브 런 하네스 |

보고서만 이 커밋 뒤에 별도 커밋으로 남긴다.

## 2. 구현 계약

### 2.1 카메라

- 실 뷰포트 `2020x1246`에서 세로 월드 배율을 `2.15`로 정했다. 정본의
  “현행보다 2배 이상”을 만족하면서 한 화면에 약 4개 층이 보여 현재 위치와
  바로 앞 경로를 함께 읽을 수 있는 값이다.
- 가로 레인 폭은 실 뷰포트 비례를 유지하고 세로만 확대했다. 큰 화면에서
  내용이 가운데 작은 기둥으로 남는 과거 회귀를 막는다.
- 자유 추적 구간의 초점 Y는 화면 중앙 `0.50`이다. 1층·9층은 노드 아트 크기의
  `0.78`만큼 경계 여백을 포함해 클램프하므로 현재 아이콘이 잘리지 않으며
  월드 바깥 빈 공간도 나오지 않는다.
- 전체화면 rect는 계속 실제 `canvas.get_viewport_rect()`를 우선한다(GRT-044).
  지도·점선·아이콘은 `content_rect` 밖에서 그리지 않아 필러로 새지 않는다
  (GRT-045).

### 2.2 곡선과 결정론

- 지도 생성기의 `from/to` 목록은 수정하지 않는다. 투영 단계에서만 각 간선에
  2차 베지어 제어점과 샘플을 붙인다.
- 곡률은 `map_seed`, `from ID`, `to ID`를 입력으로 하는 로컬 안정 해시에서
  파생한다. 게임플레이 RNG나 연출 RNG를 전진시키지 않는다.
- 곡률 비율은 `0.10~0.24`, 진행축 비대칭은 최대 `0.08`이다. 양 끝은 아이콘
  크기의 `0.68`만큼 비워 선과 노드 초상이 겹치지 않는다.
- 같은 시드의 곡선 서명은 동일하고 다른 시드는 달라지며, 두 경우 모두 연결
  서명은 원본 그래프와 동일함을 씰에서 단언한다.

### 2.3 점선·캐시·교차부

- 점은 `draw_line` 반복이 아니라 캐시된 10각 원 폴리곤으로 그린다(GRT-055).
- 최종 간격은 아트 크기의 `0.32`, 외곽 반지름은 `0.072`, 금색 중심 반지름은
  `0.030`이다. 첫 캡처에서 교차점이 뭉친 것을 RED로 판정한 뒤 간격을 넓히고
  진사 외곽을 키워 위 경로가 아래 경로를 끊는 브리지 판독성을 확보했다.
- 고정 시드 인간계 지도는 32간선·424점·최대 848 폴리곤 호출이다. 실제 한
  화면에는 약 4개 층만 들어오며 화면 밖 점은 호출 전에 제외된다.
- 곡선 샘플·등간격 점·원 폴리곤은 그래프/뷰포트 정적 캐시에 들어간다. 현재
  노드 변경과 전환 진척은 캐시를 재생성하지 않는다.

### 2.4 이동 연출

- 이동체 위치는 캐시된 곡선의 누적 길이를 따라 샘플한다. SD 캐릭터가 점선을
  직선으로 가로지르지 않는다.
- 카메라 초점은 그 이동체의 같은 `world_position`을 소비한다. 두 값의 시계는
  기존 `TowerAscentTransitionFadeState.travel_progress`뿐이며 물리 틱 소유권을
  새로 만들지 않았다.
- 새 카메라 호스트 노드를 만들지 않았으므로 GRT-039의 생성 프레임 보간 유령
  경로가 없다.
- 정본 §3.1의 2구간 문구를 “전체화면 지도 등장”에서 “확대·추적 지도 등장”으로
  맞췄다. 전체화면 **표면** 계약은 유지되고 전도 공개만 폐지된 상태다.

## 3. 소비자 감사

- M 지도는 열람 전용이며 노드/간선 클릭 판정 소비자가 없다.
- 경로 확정 입력은 전투 씬 `ROUTE_AIM`의 실제 서브 공과 물리 표적이 계속
  소유한다. 지도 곡선·노드 원·아이콘 rect는 입력 좌표로 사용되지 않는다.
- 따라서 이번 곡선 이동으로 그린 자리와 클릭 자리가 갈리는 GRT-022 경로는
  존재하지 않는다. 노드 원 상단 모서리를 소비하는 별도 hit-test도 검색 결과
  0건이다.

## 4. 검증 증거

### 4.1 자동 게이트

- 최종 집중 배치 11종: `PASS=11 FAIL=0 TOTAL=11`
  - `tower_map_camera_tracking_smoke`
  - `tower_ascent_map_overlay_render_smoke`
  - `tower_ascent_map_overlay_input_smoke`
  - `tower_ascent_map_hint_smoke`
  - `tower_ascent_12_floor_map_smoke`
  - `tower_ascent_map_generator_smoke`
  - `tower_ascent_data_driven_renderer_smoke`
  - `tower_ascent_two_phase_graph_smoke`
  - `tower_ascent_route_serve_smoke`
  - `tower_route_serve_wind_target_smoke`
  - `tower_map_iconography_contract_smoke`
- 필수 종단선: `All Godot smoke tests passed.`
- 전용 씰은 `.github/workflows/godot-ci.yml`과
  `godot/tools/run_pre_push_checks.ps1`에 동시에 등재했다.
- 변경 GDScript 경고 스캔: `8/8`, 경고 0.
- 헤드리스 로드: `Godot headless load check passed.`
- `git diff --check a435f1582..HEAD`: PASS.
- 검증은 플레이 중 허용 래퍼의 BelowNormal 우선순위·고유 로그 계약으로
  실행했으며 사용자 게임/에디터를 종료하지 않았다.

### 4.2 Vulkan·픽셀 증거

생산 `BattleSceneDrawer` 경로, Forward Mobile Vulkan, `2020x1246`에서 생성했다.
산출물은 격리 워크트리의 비추적 `.godot/codex_captures/` 아래에 있다.

- `tower_map_camera_tracking/map_camera_floor01_lower.png`
  - 1층 현재 아이콘 완전 가시, 하단 빈 공간 0.
- `tower_map_camera_tracking/map_camera_floor05_middle.png`
  - 5층 세로 중앙, 위·아래 그래프가 모두 크롭됨.
- `tower_map_camera_tracking/map_camera_floor09_upper.png`
  - 9층과 지붕 완전 가시, 상단 빈 공간 0.
- `tower_map_camera_tracking/map_camera_curve_crossing_zoom4.png`
  - 4배 최근접 확대에서 금색 중심과 진사 외곽이 분리되고 두 진행 방향이 읽힘.
- `tower_map_camera_tracking/map_camera_six_beat_tracking_strip.png`
  - 4→5층 자유 추적 구간의 전투 암전 → 지도 등장 → SD 곡선 이동 → 도착
    소멸 → 지도 암전 → 도착 전투 표면을 3x2 연속 스트립으로 기록.

Vulkan 래퍼 종단선:

```text
[TowerMapCameraTrackingVisualQA] captures=5 live_transitions=5 physics_ticks=820
tower_map_camera_tracking_visual_qa: ok
Tower map-camera tracking Vulkan and live traversal QA passed.
```

### 4.3 라이브 1판 범위

- 별도 실제 창에서 같은 생성 그래프를 유지한 채 5개 층 이동을 연속 실행했다.
- 각 `MAP_TRANSITION`은 QA 진척 주입이 아니라 `update_selective(1/60)`을 실제
  물리 프레임마다 호출해 총 820틱으로 진행했다.
- 렌더는 생산 `BattleSceneDrawer`를 통과했고 모든 틱에서 이동체 카메라 초점이
  `content_rect` 안에 있음을 단언했다.
- 카메라 체감만 격리하기 위해 전투 도착은 즉시 클리어로 처리하고 같은 런의
  다음 경로로 복귀했다. 지도/전환/노드 상태는 새 그래프를 재생성하지 않았다.
- 실시간 창과 6구간 스트립을 함께 검수했으며 급점프, 아이콘 이탈, 경계 빈 공간,
  점선 재생성 끊김은 관측되지 않았다.

## 5. 작업 안전·잔여 상태

- 기존 따뜻한 워크트리를 재사용했고 새 10GB 콜드 워크트리를 만들지 않았다.
- 착수 전 기준 로그 11파일·586,803바이트를
  `C:\Users\woduq\.codex\backups\tower_map_camera_tracking_logs_pre_20260820`
  에 보존했다.
- 실행 중인 본 트리 Godot의 캐시를 건드리지 않았다. 격리 워크트리에 없던
  한미량 워킹 시트 2개는 동일 상대 경로의 소형 임시 Godot 프로젝트에서
  커밋 원본을 임포트하고 SHA-256 일치 후 격리 캐시에만 복사했다.
- 본 트리는 보고 시점 `09e2160e3`, dirty 3,635건이며 이 작업으로 통합·스테이징·
  정리하지 않았다. 격리 브랜치 작업 트리는 보고서 작성 전 clean이었다.
- 실수로 잘못 쓴 집중 인자가 한 차례 전체 스모크를 시작해 60초 후 종료됐고,
  다른 액티브 아이템 WIP의 기존 RED가 보였다. 이 실행은 본 작업 게이트로
  채택하지 않았으며, 올바른 `-Tests` 집중 배치로 위 11종 종단선을 다시
  확보했다.

## 6. 완료 판정

- S1~S5 구현: 완료
- 슬라이스별 독립 커밋: 5/5
- 결정론·연결 불변·경계·캐시 씰: GREEN
- 실제 Vulkan/픽셀/연속 프레임: GREEN
- 카메라 범위 라이브 1판: GREEN
- 필수 게이트 `blocked`: 0
- 필수 게이트 `unverified`: 0
- 푸시·본 트리 통합: 하지 않음, 사용자 승인 대기
