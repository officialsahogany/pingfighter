# 탑 지도 워커 진입 줌 완료 보고서

- 판정: **GREEN**
- 기준 커밋: `40375e15a`
- 격리 브랜치: `codex/tower-map-walker-zoom-intro-40375-v3`
- 격리 워크트리: `C:\Users\woduq\.codex\tmp\bosspong_r4_integration_dcf`
- 통합/푸시: 수행하지 않음
- blocked: **0건**
- unverified: **0건**

## 구현 결과

`32e193319`의 지도 카메라 추적을 유지한 채, 지도 등장과 워커 이동 사이에 `MAP_TRANSITION` 내부 구간 `camera_zoom_in`을 삽입했다. 새 페이즈나 카메라 노드는 만들지 않았다.

- 저작 시간: `TEMP_MAP_TRANSITION_CAMERA_ZOOM_IN_SEC := 60.0 / 60.0`
- 실제 물리 시간: 72 Hz에서 정확히 72틱, 1.0초
- 전체 전환 시간: 기존 2.73초에 1.0초를 더한 3.73초, 전환당 `ceil(3.73 * 72) = 269`틱
- 길이 결정 근거: 이번 요청은 기존 추적 위에 진입 구간을 추가하는 작업이므로, `32e193319`에서 확보한 1.60초 이동/추적 구간을 줄이지 않고 1초를 가산했다.
- 줌 배율: 기존 지도 배율 2.15를 시작값으로 유지하고, `smoothstep`으로 `1.0 -> 1.18`을 적용해 최종 유효 배율을 `2.537`로 고정한다.
- 워커: 72틱 줌 동안 정지하고, 줌 종료 뒤 기존 이동 구간에서 출발한다.
- 인계: 마지막 줌 틱, 정확한 구간 경계, 첫 이동 틱을 모두 검사했다. 배율과 카메라 중심은 C0 연속이며, 이동부터는 줌 종료 시점의 워커 중심 고정 추적을 이어 간다.
- 경계: 최하층과 최상층에서 월드 표시 영역을 클램프하고, 다음 목적지 행이 보이는 계약을 유지했다.
- 렌더링: 기존 정적 그래프/경로 캐시는 다시 만들지 않고 카메라 변환만 적용한다. 새 보간 노드가 없으므로 GRT-039 대상도 추가되지 않았다.
- 화면 정책: `camera_zoom_in`을 지도 화면 구간으로 명시해 전투 화면이 끼어드는 역방향 결함도 씰로 차단했다.

정본 `docs/tower_ascent_run_map_plan.md`는 6구간 계약 안의 `2-b` 진입 줌으로 갱신했다. 기존 “새 페이즈를 만들지 않는다”는 계약은 그대로다.

## 슬라이스 커밋

| 슬라이스 | 커밋 | 결과 |
|---|---|---|
| S1 구간 삽입 | `82a66c1b9` `feat(tower): insert map camera intro beat` | 독립 GREEN |
| S2 줌 곡선 | `dce8d1186` `feat(tower): define map intro zoom curve` | 독립 GREEN |
| S3 시점 고정 인계 | `256492d98` `feat(tower): hand intro zoom into walker tracking` | 독립 GREEN |
| S4 씰·캡처 | `0d962595e` `test(tower): seal walker intro zoom` | 독립 GREEN |

각 슬라이스에서 해당 집중 스모크, touched-path 경고 스캔, 헤드리스 로드, `git diff --check`를 통과한 뒤 다음 슬라이스로 진행했다.

## 자동 검증

최종 집중 배치는 아래 4개 생산 경로 씰을 함께 실행했다.

- `tower_map_walker_zoom_intro_smoke.gd`
- `tower_map_camera_tracking_smoke.gd`
- `tower_ascent_map_overlay_render_smoke.gd`
- `tower_node_modal_pointer_smoke.gd`

결과:

```text
Smoke summary: PASS=4 FAIL=0 TOTAL=4
All Godot smoke tests passed.
```

- 전용 신규 씰 `tower_map_walker_zoom_intro_smoke.gd`를 CI와 pre-push 목록에 동시에 등록했다.
- 72틱 정확성, 줌 단조 증가, 시작/종료 배율, 경계 전후 C0 연속, 다음 목적지 가시성, 최하층/최상층 클램프, 정적 캐시 불변, 화면 표면의 정·역방향을 검사한다.
- 신규 씰이 부동소수점 경계에서 73틱이 되는 결함을 먼저 적발해 1마이크로초 경계 허용치로 72틱을 고정했다.
- `.gd` touched-path 경고 스캔(4개 스크립트), 헤드리스 로드, `git diff --check` 모두 통과했다.
- 최종 배치와 Vulkan 실행에서 `SCRIPT ERROR`는 0건이다.

## 연속 프레임 및 라이브 검증

기존 warm import cache를 가진 격리 워크트리에서 Forward Mobile/Vulkan, NVIDIA GeForce RTX 5070으로 실제 창을 1회 실행했다. 그 한 세션에서 5개 층 전환을 연속 통과했다.

```text
[TowerMapCameraTrackingVisualQA] captures=6 overview_frames=7 zoom_frames=13 live_transitions=5 physics_ticks=1345 zoom_ticks=360 max_boundary_scale_delta=0.000103 max_boundary_center_delta_px=0.042
tower_map_camera_tracking_visual_qa: ok
Tower map-camera tracking Vulkan and live traversal QA passed.
```

- 총 물리 틱: `5 * 269 = 1345`
- 줌 물리 틱: `5 * 72 = 360`
- 경계 최대 배율 차: `0.000103` (허용치 `0.0002` 이하)
- 경계 최대 중심 차: `0.042 px` (허용치 `0.25 px` 이하)

캡처 증거:

1. `.godot/codex_captures/tower_map_camera_tracking/map_camera_walker_zoom_full_transition_strip.png`
   - 2020x624, 182,920 bytes
   - SHA-256 `E3E780A700EB180FE095A7E09804714A092004A5D624208777D0F689C5E99B2B`
   - 전투 화면 퇴장부터 지도 등장, 진입 줌, 워커 이동, 지도 퇴장, 전투 화면 도착까지 6구간을 시간순으로 담은 7프레임 스트립
2. `.godot/codex_captures/tower_map_camera_tracking/map_camera_walker_zoom_intro_dense_strip.png`
   - 2020x747, 391,054 bytes
   - SHA-256 `0946FC92C1C425D1DB2335FC853EE81E0E5FC421BF1DD6B33873121044DD9EDE`
   - 줌 0틱부터 72틱까지 매 6틱을 포함한 13프레임 밀집 스트립

두 스트립을 확대 육안 검토했다. 줌 동안 워커가 정지한 채 자연스럽게 확대되고, 경계에서 튀거나 멈추지 않으며, 이동 중 추적과 다음 목적지 가시성이 유지된다. 최초 캡처에서 `camera_zoom_in`이 화면 표면 정책에 빠져 전투 화면이 보이는 문제를 발견했고, 정책과 역방향 씰을 고친 뒤 위 최종 캡처를 다시 생성했다.

실기 픽스처가 출력한 기존 대체 보스 경고(`floor_04_shell_02 uses stand-in stage 4 boss ponk`)는 실행 실패나 `SCRIPT ERROR`가 아니며 이번 카메라 경로의 판정을 막지 않았다.

## 작업 격리와 보존

- 새 콜드 워크트리를 만들지 않았다. 최종 워크트리는 시작 시 이미 2,592개의 import cache 파일을 가진 기존 warm 워크트리였고, 최종 검증 시 2,594개였다.
- 처음 재사용한 warm 워크트리가 다른 동시 작업의 브랜치로 전환된 것을 발견한 즉시 이번 작업의 정확한 변경만 그곳에서 되돌리고, 현재 기존 warm 워크트리로 옮겼다. 다른 작업의 파일이나 커밋은 변경하지 않았다.
- LFS 포인터 상태였던 한미량 걷기 PNG 2개는 이미 검증된 실제 원본과 대응 `.ctex`만 임시 물질화해 Vulkan 검증했다. 이후 추적 PNG는 원래 131-byte LFS 포인터로 복원했고, 최종 작업 트리는 깨끗하다.
- 기존 로그 6개(총 1,569,958 bytes)는 실행 전에 `C:\Users\woduq\.codex\backups\tower_map_walker_zoom_intro_logs_pre_v3_20260820_140941`로 보존했다. manifest SHA-256은 `7D8CBA6E93B52E686F0C9FC9B21768BABB3DF3E461D563C1A3CF002ACBD15BC0`이다.
- 본 트리는 작업 시작 뒤 `a6661dce3`까지 전진했다. 기준점 이후 이번 변경과 같은 경로인 `tower_ascent_tuning.gd`도 바뀌었지만, 본 트리 변경은 시작 카드 타임아웃(124행대), 이번 변경은 카메라 상수(77·97행대)라 줄 단위 겹침이 없다. 통합·리베이스·푸시는 시도하지 않았다.

## 대기 상태

S1~S4 구현, 자동 검증, 연속 프레임 증거, 라이브 1회, 게임 실행 검증을 모두 마쳤다. blocked/unverified는 각각 0건이다. 격리 브랜치에만 보존하고 착지 지시를 기다린다.
