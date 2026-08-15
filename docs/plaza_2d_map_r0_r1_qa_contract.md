# 환격전 광장 2D 지도 R0/R1 QA 계약

상태: R0/R1 완료 기록 + R2-A/B/C 후보 GREEN + R3-A 환경 구성 후보 GREEN + R3-B exterior runtime·R3-C lifecycle/prewarm 후보 GREEN; 프로덕션은 R1 유지, R3-D 원자 전환 대기
기준일: 2026-08-11

이 문서는 `plaza_2d_map_promotion_plan.md`의 R0/R1 슬라이스를 검증하는 최소 계약이다. 테스트는 특정 함수명이나 임시 디버그 API보다 관찰 가능한 자산, 노드 상태, 실제 프리웜 진행과 렌더 픽셀을 판정한다. 구현 중 API 이름이 바뀌어도 아래 입력·행동·결과와 역검증은 유지한다.

## 1. 검증 등급

| 등급 | 증거 | 용도 |
|---|---|---|
| S | 정적 파일/매니페스트 검사 | 경로 수, 규격, 해시, import, R0 경계와 R1 활성 route 전환 |
| H | headless 상태 스모크 | 수명, 위임, 색 정본, effective z |
| V | 실제 Vulkan 픽셀 캡처 | 음수-z 매몰, ADD/MIX 차이, 투명 실루엣, 유령 잔존 |

S/H GREEN만으로 보이는 렌더 결과를 승인하지 않는다. 특히 `visible`, texture, material과 스모크 상태가 정상이어도 조상 fill에 완전히 묻힐 수 있으므로 R1 종료에는 V가 필수다.

## 2. R0 게이트 (완료된 비활성 준비 시점의 역사적 씰)

R0-B/C의 "비활성 후보" 조건은 R1 연결 전 스냅샷을 증명하는 역사적 게이트다. R1이 활성화된 현재 프로덕션 경로에 비연결 상태를 다시 요구하거나, R0 inactive 단언을 현재 완료 조건으로 실행하지 않는다. 자산 규격과 위임의 판별력은 R1에서도 그대로 유지한다.

### R0-A — 21장 런타임 자산 전수 검사 (S)

- 매니페스트 7종 각각 `base`, `sign_emissive`, `window_glow_mask` 한 장을 참조해 총 경로가 정확히 21개여야 한다.
- 모든 런타임 PNG는 `512 x 512`, RGBA이고 네 모서리 alpha가 0이어야 한다. 알파 bbox는 캔버스 가장자리에 닿지 않아야 한다.
- base는 승인 1254² 원본에서 결정적으로 다운스케일한 결과여야 하며 provenance와 SHA-256을 기록한다.
- 승인 1254² master가 gitignored `tmp/imagegen/`에만 있는 현재 R0는 workspace-only prep으로 표기한다. 512² 런타임 산출물은 self-contained지만 클린 체크아웃 재생성은 지원하지 않으며, 그 보장을 추가하려면 별도 LFS source-art 승격 게이트가 필요하다.
- sign/window의 보이는 픽셀은 RGB `[255,255,255]`, 강도는 alpha 하나에만 있어야 한다. base 실루엣 밖 마스크 픽셀은 0이어야 한다.
- exterior-connected 4px 경계 크로마 게이트는 21장 모두 통과해야 한다. `exact_ff00ff_pixels`는 진단값으로만 남긴다.
- import는 VRAM 압축과 high-quality를 사용한다. 1254² 원본이 런타임 경로에 남아 있거나 512² 정책을 `size_limit` 설명만으로 대신하면 RED다.
- 매니페스트의 `origin_pivot`, `ground_anchor_chord`, `footprint_polygon` 등 저작 좌표는 1254² source-px 정본을 유지하고, runtime texture 크기는 별도 필드/스케일로 구분한다.

역검증: 한 레이어를 1254² 원본으로 바꾸거나 마스크 한 픽셀을 base 알파 밖에 놓으면 해당 게이트가 RED여야 한다.

### R0-B — R0 시점 비활성 승격 경계 (S/H)

- R0 diff에는 `plaza_scene.gd`와 기존 활성 매니페스트 스위치가 없어야 한다.
- 후보 매니페스트를 독립 로드해 7종 스펙, 색, 강도, source/runtime 크기와 21장 텍스처를 모두 얻을 수 있어야 한다.
- 평상시 광장 진입은 후보 경로를 로드하거나 후보 retained host를 생성하지 않아야 한다. R0 전후 활성 광장 스펙과 캡처가 같아야 한다.

역검증: 후보 목록 중 하나를 현행 active route에 임시 주입하면 비활성 경계 테스트가 RED여야 한다.

### R0-C — R0 시점 후보 프리웜 위임 (H)

- 활성 광장 진입과 분리된 R0 후보 프리웜 진입점을 1회 호출하면 소유 건물 렌더러에 위임되고, 렌더러가 후보 매니페스트 21장의 준비 상태를 실제로 순회해야 한다.
- 자식이 미완료인 동안 부모는 완료를 반환하지 않는다. 마지막 자식이 준비된 뒤에만 완료가 된다.
- 완료 뒤 두 번째 호출은 새 동기 로드 없이 warm 상태를 재사용한다.
- 첫 가시 프레임에서 후보 텍스처의 동기 `load` 또는 GPU 최초 업로드가 발생하지 않아야 한다.

역검증: 부모에서 자식 `prewarm_assets_step()` 위임 한 줄을 제거하면 첫 호출이 `already warm`으로 조용히 통과하지 않고 테스트가 RED여야 한다.

## 3. R1 게이트

R1 활성 범위는 고정 `2400 x 1500` 바깥 map world와 retained 건물/배경 경로다. `plaza_scene.gd`가 월드 호스트의 부착·owner-frame sync·실제 전환 정리를 소유하며, `render_size = plaza_scene.size`와 owner frame당 한 번 샘플한 `ticks_msec`를 넘긴다. 인테리어 및 거래 UI의 `760 x 750` 계약은 변경하지 않는다. 다만 표시 투영은 아직 바깥 셸의 기존 `GAME_SIZE = 760 x 750` 횡스크롤 fit을 쓰는 R1 브리지이며, `map_safe_rect` 지도 fit과 2D 도로·필지 생성은 후속 R2다.

고정 `2400 x 1500`은 단순한 retained 리팩터링 상수가 아니라 레거시
`MAP_SIZE = 1900 x 750`에서 의도적으로 승격한 R1 호환 변경이다. 저장된
`stage_map_seeds[stage_id]` 값은 유지하지만 기존 1축 위치 산식의
`world_width` 입력이 달라지므로 업데이트 경계에서 건물 좌표가 한 번
이동한다. 그 뒤에는 고정 `2400`이 캐시·위치 입력의 정본이므로 같은
스테이지·같은 시드가 같은 배치를 재현해야 한다.

### R1-A — fill 이동과 z-order의 원자성 (H/V)

테스트는 라이브 조건인 광장 루트 `z_index = 1200`을 재현한다.

- 월드 호스트는 루트의 자식이며 `z_index = -1`, `z_as_relative = true`, effective z는 1199여야 한다.
- 불투명 map fill은 월드 호스트가 소유하고, 루트/조상 `_draw()`에는 호스트 rect를 덮는 불투명 fill이 없어야 한다.
- R1 콜사이트는 호스트에 `draw_opaque_fill = true`를 명시하고 루트 fill 제거와 같은 변경으로 착륙시킨다. R0 debug dictionary의 capability bool이나 하드코딩 리터럴은 소유권 증거로 인정하지 않는다.
- 호스트 fill, 지면과 최소 한 건물의 sentinel 레이어가 실제 캡처에 나타나야 한다. 상태값만 확인하지 않는다.
- 호스트 없는 fill 이동 상태와 fill이 남은 호스트 부착 상태는 둘 다 허용하지 않는다. 코드/픽셀 게이트는 두 변경이 함께 있을 때만 GREEN이다.

필수 반증: 후보 코드에서 부모의 기존 불투명 fill만 복원하고 음수-z 자식 발광 sentinel을 켠다. `visible=true`, texture/material 정상이라는 H 단언은 그대로 통과할 수 있지만 V의 sentinel 픽셀 수는 0이 되어 전체 후보 테스트가 반드시 RED여야 한다. 이 RED를 기록하지 않으면 R1 z-order 게이트는 판별력이 입증되지 않은 것이다.

### R1-B — retained fail-closed 수명 (H/V)

각 레그는 먼저 유효한 바깥 광장을 한 프레임 표시해 호스트에 식별 가능한 sentinel 픽셀을 남긴 뒤 다음 상태로 전이한다.

| 레그 | 실제 진입 | 다음 프레임 필수 결과 |
|---|---|---|
| degenerate size | 광장 Control 크기를 `<= 1`로 만들고 실제 draw/sync 진입 | 호스트 inactive/hidden, sentinel 0px |
| 인테리어 진입 | 실제 건물 선택/전환을 거쳐 `_open_interior_view()` 활성 | 바깥 월드 호스트 inactive/hidden, sentinel 0px |
| 광장 이탈/씬 전환 | 실제 exit warp 완료 콜백 또는 상위 scene-handler 해제 경로 | 콜백/`queue_free()`보다 먼저 `clear_transient_canvas_items()`가 호스트를 내리고 sentinel 0px |

구현 불변식은 모든 얼리리턴보다 앞의 fail-closed `set_active(false)`와, 유효 스펙 동기화 말미의 재활성화다. 같은 `_draw()` 안에서 false→true로 토글했다는 사실은 픽셀 증거가 아니므로 별도 sync 상태와 다음 렌더 프레임을 확인한다.

Godot은 `SubViewport`의 최소 가시 크기를 `2 x 2`로 클램프한다. 따라서 degenerate Vulkan 레그는 viewport 크기가 실제로 1이 되었다고 가장하지 않고, 라이브 `PlazaScene.size = Vector2.ONE` 상태에서 루트 `_draw()`의 fail-closed 경로를 통과시킨다. 이 레그에서도 월드 호스트의 sync/active API를 직접 부르지 않는다.

호스트는 self-process하지 않는 sync-driven 렌더러다. R1 소유자는 매 rendered frame마다 한 번 `Time.get_ticks_msec()`를 샘플해 명시적 정수 `ticks_msec`로 넘기고, 같은 tick을 배경과 모든 건물 레이어에 전달해야 한다. `render_size`는 엔진 뷰포트 크기가 아니라 `plaza_scene.size`인 루트-local render rect이며, 레거시 `viewport_size` 키나 `get_viewport_rect().size`를 대신 넘기면 RED다. R0는 누락·오타 키 거부와 frozen→advanced tick 전파를 봉인하고, R1은 실제 owner 콜사이트가 프레임마다 동기화되는지를 별도로 단언한다.

필수 반증: 진입 최상단 teardown 또는 clear 경로의 비활성화 한 줄을 제거하면 위 세 레그 중 대응 레그가 이전 sentinel을 남기며 RED여야 한다. 호스트 setter를 직접 부르는 테스트만으로 대체하지 않고, 실제 `plaza_scene.gd` 진입점과 상위 scene-handler를 관통한다.

### R1-C — 레이어 소유권과 ADD 픽셀 (H/V)

- base, sign, window는 각각 독립 CanvasItem이며 sign/window 소유 노드의 material이 ADD를 소유한다.
- immediate `_draw()` 도중 부모 material을 잠깐 교체하는 방식은 허용하지 않는다.
- 같은 frame 구성, 고정 tick과 동일 카메라에서 strength `0` 캡처와 strength `1` 캡처를 짝으로 비교한다. sign/window ROI의 밝기와 픽셀 델타가 증가하고, 마스크 밖 비교 ROI는 변하지 않아야 한다.
- 같은 텍스처·색·strength `1`로 프로덕션 ADD 캡처와 강제 MIX 대조 캡처를 다시 짝으로 비교한다. 사전 고정한 최소 픽셀 차이가 있어야 하며, 어두운 건물 위 sign/window ROI의 ADD 기여가 MIX와 구별되어야 한다.
- 마스크 밖 픽셀과 투명 실루엣 밖은 base-only 캡처와 같아야 한다.

필수 반증: sign/window 자식 material을 MIX로 바꾸면 상태 스모크가 아니라 픽셀 차이 게이트가 RED여야 한다.

### R1-D — 색 정본과 미니맵 (H/V)

- loader가 각 매니페스트의 `sign_glow_color`, `window_glow_color`, 두 strength를 손실 없이 렌더 스펙에 전달한다.
- 미니맵 `marker_color`는 별도 하드코딩 표가 아니라 같은 스펙의 정본 값에서 나온다.
- 7종 건물의 본 지도 window 발광색과 미니맵 마커를 짝지어 RGBA가 일치해야 한다.
- 가챠의 별도 `entrance_anchor`와 display height 위계처럼 색과 무관한 매니페스트 필드도 R1 전환에서 소실되지 않아야 한다.

역검증: 미니맵 한 종류의 하드코딩 색을 되살리면 색 정본 테스트가 RED여야 한다.

### R1-E — 프로덕션 프리웜 승격 (H)

- 결과 화면의 실제 `BUTTON_PLAZA` 클릭은 `ACTION_ENTER_PLAZA`를 생산해야 하며 notice 경로로 빠지지 않아야 한다.
- 실제 광장 전환의 composed readiness는 `plaza_scene.gd` → 월드 호스트 → 건물 렌더러 → loader의 자원 캐시 21장과 GPU 프리웜을 모두 포함한다. 독립 `512 x 512` `SubViewport` 안에서 실제 retained 호스트가 7종 x 3레이어를 모두 in-bounds로 드로우하고, 현재 캐시 `Texture2D` instance ID 21개가 일치하며, `RenderingServer.frame_post_draw`가 최소 2회 flush되기 전에는 완료를 반환하지 않아야 한다.
- composed readiness 미완료 시 광장 진입 콜백은 명시적 `false`를 반환한다. 콜백 scene glue는 이를 성공으로 소비하거나 비우지 않아야 하며, 다음 `BUTTON_PLAZA` 클릭이 같은 진입을 재시도해 readiness 완료 뒤 씬을 생성해야 한다.
- 미완료 클릭은 입력 프레임에서 blocking `ensure_assets_ready()`로 남은 캐시를 드레인하지 않는다. 실제 라이브 클릭은 기존 `prewarm_assets_step()`을 한 번만 전진시키고 즉시 반환해야 하며, 결과 화면의 owner-frame 업데이트가 나머지 자원과 GPU flush를 계속 소유한다. 60Hz 콜드 재현에서 최초 버튼 visible은 69프레임·`1.15s`, 수정 전 클릭은 `622ms`, 수정 후 동일 경로는 `14ms`였다. 벽시계 수치는 성능 증거로만 기록하고 headless CI의 고정 시간 임계로 쓰지 않는다.
- `광장으로` 버튼은 활성 프로덕션 route에서 disabled 톤으로 남지 않아야 한다. readiness가 아직 false이면 콜백과 미정산 보상을 보존한 채 `준비 중입니다` 피드백을 실제 결과 draw 경로에 표시한다. 2020 x 1246 Vulkan notice on/off 대조는 `10,316px` 차이를 보여야 하며, 상태 필드만 켜고 픽셀에 나타나지 않는 구현은 RED다.
- 전환 뒤 첫 가시 프레임은 후보 텍스처를 동기 콜드 로드하지 않아야 한다.

역검증: 프로덕션 상위 소유자의 위임만 제거하거나, 캐시 ID를 교체하거나, 미완료 `false` 콜백을 첫 클릭에서 비우면 후보 단독 R0-C는 GREEN으로 남더라도 이 테스트가 RED여야 한다.

### R1-F — `GAME_SIZE` 브리지 확대 선명도 (V)

- 수치 게이트는 현재 프로덕션 투영을 사용한다. 2020 x 1246 창에서 바깥 `GAME_SIZE` fit 배율은 `1246/750 ≈ 1.6613`, 은행의 360 world-unit 표시 높이는 약 598px, 512px 런타임 텍스처 확대율은 약 `1.17x`여야 한다.
- 동일한 2020 x 1246 실제 Vulkan 캡처에서 은행 기와선, 외곽 실루엣, sign/window 마스크 경계의 선명도를 원본/승인 QA 보드와 나란히 검사한다. 흐린 테, 이중 경계, 마스크 번짐이 승인되지 않으면 R1을 완료로 판정하지 않는다.
- `map_safe_rect.width = 1588` 예시에서의 `1588/2400`, 172~238px 표시 높이와 약 2.15배 소스 여유는 R2 목표 대조군일 뿐 R1 통과 근거가 아니다.

역검증: R1 캡처 판정을 238px 축소 보드로 대체하거나 2020 x 1246 캡처를 생략하면 이 게이트는 RED다. 선명도가 실패하면 512² 정책 또는 브리지 투영을 재검토하며, R2 목표 수치를 현재 수치처럼 대입해 통과시키지 않는다.

### R1-G — 고정 map-world 승격과 도달 가능성 (H)

- 라이브 `PlazaScene.get_status()`의 `world_size`는 정확히 `Vector2(2400, 1500)`이어야 한다. `x > 760` 같은 약한 단언은 이 승격의 증거가 아니다.
- `EXIT_ZONE`은 정확히 `Rect2(2250, 596, 120, 92)`이어야 하며, 플레이어의 고정 지면선 `y = 666`이 그 rect 안을 지나 실제 상호작용 위치에 도달할 수 있어야 한다.
- `GAME_SIZE.x = 760`인 현행 1축 카메라의 우측 clamp는 정확히 `2400 - 760 = 1640`이어야 한다. 플레이어를 출구 중심 또는 우측 끝으로 이동했을 때 라이브 상태가 이 clamp에 도달해야 한다.
- 동일한 `stage_id`, 보존 시드, full-layout/강제 선술집 조건으로 `build_hwangyeok_building_specs()`를 반복 호출하면 종류 순서와 위치가 같아야 한다. 시드 재발급이나 viewport 파생 폭이 캐시 키에 들어가면 RED다.
- 레거시 대비 spawn→출구 시작점의 수평 이동 거리는 `1630 → 2130`, 500 단위 늘어난다. 실제 프로덕션 handler/update와 `Input.action_press("ui_right")`, 60Hz `delta = 1/60`, 직접 위치 이동 없음 조건에서 새 출구 첫 진입은 533프레임·`8.883s`, 레거시 x=1750 대조군은 408프레임·`6.800s`여야 한다. 증가분 125프레임·`2.083s`·약 30.64%는 R1에서 승인한 플레이어 체감 변경이다. 세로 이동이나 2축 카메라가 활성화됐다는 뜻은 아니다.
- 위 라이브 게이트는 출구 첫 진입 프레임의 플레이어 x=`2252`, 카메라 x≈`1639.955`, 실제 Enter 입력 뒤 60프레임 exit warp와 콜백까지 관통한다. 상태 setter나 직접 위치 warp로 대체하면 RED다. 정본 계측은 `godot/.tmp/plaza_r1_map_length_vulkan/metrics.json`의 `runtime.actual_new_walk_seconds_60hz`, `runtime.legacy_discrete_walk_seconds_60hz`와 두 `route_samples`다.
- 위 보행 수치 GREEN은 희소 판의 미술 승인을 뜻하지 않는다. 정상 stage 1 seed `5`의 `bank + shop` 두 동 판은 마지막 visual 끝 x≈`1082.72`부터 출구까지 약 `1167.28` world가 남고, 마지막 건물이 화면에서 사라진 뒤 약 `3.70s`가 반복 벽/바닥뿐인 RED 대조군이다. 캡처 정본은 `godot/.tmp/plaza_sparse_seed5/`의 `spawn_left`, `buildings_a..c`, `exit_right`다. R1 고정 월드 승격은 유지하지만, R2는 이 seed의 미사용 필지 장식과 도로 랜드마크를 첫 시각 게이트로 통과해야 한다.

역검증: `MAP_SIZE`를 `1900 x 750`으로 되돌리거나 출구·카메라 clamp를
레거시 값 `1750`/`1140`에 남겨 두면 정확값 단언이 RED여야 한다. 저장된
시드를 새로 발급해 우연히 배치를 고정하는 구현도 이 게이트를 통과할 수
없다.

## 4. 제안 스모크 분리

실제 구현 시 기존 광장 WIP 테스트를 수정하지 않고 아래 신규 씰로 나눈다. 이름은 구현 상황에 맞춰 바꿀 수 있지만 책임을 합치지 않는다.

- `plaza_hwangyeok_runtime_asset_contract_smoke.gd` — R0-A
- `plaza_hwangyeok_inactive_promotion_boundary_smoke.gd` — R0-B 역사적 경계 씰(R1 현재 조건 아님)
- `plaza_building_prewarm_delegation_smoke.gd` — R0-C 역사적 위임 씰
- `plaza_map_world_host_lifecycle_smoke.gd` — R1-B와 effective z 상태
- `plaza_map_world_host_z_pixel_smoke.gd` — R1-A Vulkan 픽셀 및 반증
- `plaza_building_glow_add_pixel_smoke.gd` — R1-C Vulkan ADD/MIX 대조
- `plaza_minimap_palette_source_smoke.gd` — R1-D
- `plaza_building_production_prewarm_smoke.gd` — R1-E
- `stage_clear_result_plaza_prewarm_notice_vulkan_qa.gd` — R1-E 실제 버튼 hover와 미완료 클릭 피드백
- `plaza_scene_capture.gd -- --plaza-view=2020x1246` — R1-F 2020 x 1246 실제 확대 선명도
- `plaza_r1_map_length_vulkan_qa.gd` — R1-G 실제 handler/input 보행·카메라·출구 콜백

픽셀 테스트는 headless 성공으로 대체하지 않는다. 창 모드 Vulkan 캡처가 차단되면 해당 V 게이트는 미검증으로 보고 R1 완료를 선언하지 않는다.

## 5. 완료 판정

- R0 완료 기록: R0-A/B/C GREEN, 역검증 RED, 당시 활성 광장 무변경. R1 이후에는 inactive 조건을 현재 런타임 단언으로 재사용하지 않는다.
- R1 완료: R1-A/B/C/D/E/F/G GREEN, 라이브 `BUTTON_PLAZA` 진입과 미완료 콜백 재시도 GREEN, 콜드 클릭 비블로킹 전환과 실제 `준비 중입니다` Vulkan 피드백 GREEN, 실제 인테리어/이탈 호출자 레그 GREEN, strength `0↔1` 및 ADD↔MIX 쌍 캡처 GREEN, z/fill 역변경 RED, 정확한 `2400 x 1500`/출구/카메라 도달성 GREEN, 8.883s 대 6.800s 실보행 증가 승인, 업데이트 경계의 1회성 보존-시드 좌표 이동 승인, 2020 x 1246 브리지 확대 선명도 승인, focused smoke/headless/warning scan GREEN, 실제 Vulkan 캡처 승인.
- 최종 A-H Vulkan 기록: GPU 프리웜 readback `148,223px`, GPU readiness `34.938ms`, spawn 호출 `8.432ms`, spawn 반환→첫 post-draw `20.758ms`, strength 0↔1 `7,459px`, ADD↔MIX `7,366px`, street sentinel `6,144px`, F/G/H 잔존 sentinel 각각 `0px`, 캡처 8장, failures 0건.
- 이 완료는 retained 런타임 브리지와 고정 월드 호환 승인까지다. 활성 R1 경로의 2동 희소 seed `5` 후반 `3.70s` 공백은 프로덕션 대조군으로 계속 RED다. 후속 R2 후보의 구조 GREEN을 R0/R1 성공, 희소 판 최종 미술 승인 또는 2D 절차 생성의 프로덕션 완료로 표현하지 않는다.

## 6. 후속 R2 candidate-only 검증 기록

이 절은 R0/R1 완료 판정을 바꾸지 않는다. R2 신규 소유자와 테스트는
`plaza_scene.gd` 및 `project.godot`에 연결되지 않은 후보이며, 활성 광장은
계속 R1 retained 브리지와 1축 위치 적용기를 사용한다.

- **R2-A/P1 구조 후보 GREEN:** `plaza_map_projection_r2_qa.gd`와
  `plaza_r2_map_layout_seed5_qa.gd`가 고정 `2400 x 1500` 월드, 파생
  `map_safe_rect`, 순·역투영, 결정적 도로·필지·건물·장식 스펙을 검증한다.
  56개 건물 부분집합 x seed `5/6/7`의 168개 roster가 전체 road topology,
  필지/입구/clearance, 보행 corridor/portal, 라벨과 월드 경계를 통과했고,
  소비 필드 및 geometry 변조 역검증은 RED였다.
- **seed `5` 의미 보드 GREEN, 당시 최종 아트 RED:** 2020 x 1246 Vulkan 후보
  보드는 미사용 필지 5곳의 의미 역할과 상·하부 분포 및 역할 교환 반증을
  판별했다. 다만 코드 드로우 도로·필지 표면과 workspace-only 장식은 구조
  시각화이며, 승인된 최종 지면/도로 아트나 라이브 미술 승격의 증거가 아니다.
- **R2 환경 아트 게이트 GREEN (2026-08-13):** `prepare_plaza_r2_environment_assets.py`는
  승인 지면 1장, v2 도로 6종, 의미 장식 5종과 대형·소형 필지 포석 패드 2종의 source SHA를 고정하고 정확히
  14개 self-contained runtime PNG를 결정적으로 재생성한다. v1 도로의 방향/기울기
  RED 뒤 엄격한 30도 정사영 가이드를 edit target으로 다시 칠했으며, 6성분
  geometry 대조는 IoU `0.9472..0.9848`, guide coverage `0.9892..0.9993`, art
  spill `0.0070..0.0486`이다. runtime smoke는 매니페스트·PNG SHA·Texture2D·
  VRAM high-quality+mipmap+BPTC/ASTC import, 정확한 1/6/2/5 ID 집합, 후보 격리와
  production 연결·도로/패드 누락·중복 ID·slope·패드 암전 변조 RED를 봉인한다. 패드는 정확한 `+0.5/-0.5` 가이드에서
  대형/소형 IoU `0.9800/0.9652`, 피복 `0.9852/0.9828`, spill `0.0053/0.0182`, 평균 휘도 `85.10/83.82`를 유지해야 한다. 이는 맨땅 `6.7` 위에서
  평균 `31.2`/하위 25% `19.1`인 흑기와 건물이 사라지는 실제 대조를 닫는 자산 세트 보강이다. 2020 x 1246
  Vulkan Mobile A/B/C/D에서 도로 6 ROI는 `11,100..19,656px`, 대형/소형 패드는 `41,491/18,847px`, 장식 5 ROI는 `19,007..37,333px`가 변하고 모든 단계 ROI 밖은 `0px`여야 한다. 이
  14장 세트와 필지 패드는 최종 미술 승인을 받았다. 준비 스크립트 2회 실행의
  runtime PNG aggregate SHA-256은 모두
  `48299339b61096c6a23043620e32455c8d075c191fae4c4c033602081eec49f9`여야 한다.
  결과는 **art GREEN / candidate_only / production_connected=false**다. runtime
  PNG와 import/manifest/QA는 self-contained지만 source master는 workspace-only라
  clean-checkout 재생성을 지원하지 않는다. 그 보장을 추가하려면 source master의
  별도 LFS 승격 게이트가 필요하다.
- **R3 건물 그림자 결정 게이트:** R1 retained 건물의 `Shadow` 자식은 R2 후보
  호스트에 자동 승계되지 않았다. 승인된 필지 패드만으로 접지감이 충분한지 R3
  production 캡처에서 A/B 대조하고, 그림자를 추가한다면 같은 Y-sort/material,
  actor 가림 순서와 scene-transition cleanup 계약까지 함께 검증한다.
- **R2-B navigation/minimap GREEN:** 전신 actor `38 x 32` rect에서
  walkable polygon union을 뺀 미피복 면적이 0이어야 하고, 2px slit은
  occupancy와 swept move 양쪽에서 RED다. 바인딩 뒤 corridor/portal/blocker
  geometry를 바꾸면 layout fingerprint뿐 아니라 geometry digest가 거부해야
  한다. 미니맵은 모든 건물, 서로 다른 Y, 플레이어, 출구와 카메라 rect의
  두 축을 정본 투영과 정확히 대조한다.
- **R2-B retained 후보 호스트 GREEN:** 동기화 입력은 tree mutation 전에
  strict type/finite preflight를 통과하고, 도로 draw record와 중첩 layout은
  caller와 분리해 compile한 뒤 적용한다. 건물과 actor는 같은 Y-sort root의
  actual direct sibling이고 base/sign/window/probe/actor 계층은 모두
  `z_index = 0`, `z_as_relative = true`, `top_level = false`여야 한다. 실제
  계층 변조와 post-sync caller road 변조 역검증을 포함한 focused 상태 게이트는
  GREEN이다. 2020 x 1246 Forward Mobile A/B/C Vulkan 대조에서 A는 건물
  probe `169px`/actor `0px`, B는 actor `169px`/probe `0px`였고, 같은 A 위치의
  actual actor를 `z_index = 1`로 바꾼 C도 actor `169px`/probe `0px`였다.
  A↔B와 A↔C는 각각 `169px` 달랐으며 C의 구조 계약은 `valid = false`,
  `all_direct_z_zero = false`로 RED였다. 정본은
  `godot/.tmp/plaza_r2b_candidate_ysort/`다.
- **R2-B actual visual/material 복원 GREEN:** 실제 Base material은 canonical
  MIX, Sign/Window는 같은 canonical ADD, Probe/Body는 `null`이어야 하며 전
  레이어는 `use_parent_material = false`다. sort root와 building/actor wrapper
  `modulate`, 자식 `self_modulate`는 흰색이고 자식은
  `show_behind_parent = false`다. Base/Sign/Window/Actor/Body는 유효 sync에서
  보이며 Probe는 compiled probe record의 가시성을 따른다. 테스트는 actual
  material binding·공유 blend mode·상속·부모/자식 modulate·show-behind·actor
  visibility를 동시에 변조해 그대로 남긴다. 실제 ID/blend record를 포함한
  status가 먼저 RED여야 하고, 그 tree에 다음 유효 sync를 적용하면 같은
  노드가 canonical material과 visual 상태로 복원돼 GREEN이어야 한다. 이
  보강의 독립 적대 감사 결과는 CRITICAL `0`, HIGH `0`이다.
- **프로덕션 활성화 MEDIUM 성능 게이트:** 현재 `move_actor()` 시작의
  `_is_valid_navigation_state()`는 매 60Hz 후보 호출마다 corridor/portal/blocker
  전체를 문자열로 재구성해 SHA-256 geometry digest를 다시 계산한다. 실제
  occupancy의 전신 rect 피복 판정은 `Geometry2D.clip_polygons()`도 호출한다.
  실제 owner tick에서 대표 seed와 최밀도 seed의 비충돌 보행, 벽 slide,
  portal 접근을 반복해 steady p95를 기록하고, bind-time 검증 뒤 외부에서
  변조할 수 없는 compiled owner와 allocation-free fast path를 적용해야 한다.
  최적화 뒤에도 2px slit, post-bind geometry mutation RED와 기존 이동 결과가
  같아야 한다. 이 측정·최적화는 candidate correctness GREEN과 별개이며
  완료 전 production 콜사이트 연결은 RED다. setup-time 스캔을 per-frame으로
  옮기지 않는 [GRT-032](godot_runtime_traps.md#grt-032)를 같은 gate에 적용한다.
- **R2-C 수호령 actor 게이트:** 후보 호스트의 단수 actor GREEN은 플레이어만
  증명한다. 프로덕션에서는 플레이어와 수호령 wrapper가 같은 Y-sort root의
  direct sibling이고, actual body/sprite 레이어까지 zero-z, relative,
  non-top-level 계약을 공유해야 한다. 현재 라이브의 `GROUND_Y` follow target과
  직선 `lerp`를 2D navigation으로 교체해 수호령 몸체가 walkable union 밖이나
  blocker 안을 통과하지 않게 한다. [GRT-013](godot_runtime_traps.md#grt-013)의
  2D 불변식은 ground/patrol의 Y 고정이 아니라 전신 목적지를 compiled walkable
  union 위의 유효 지점으로 투영하는 것이다. cross-lane recall은 목적지 lane의
  Y로 바뀔 수 있다. 순간 teleport는 양 끝점, 보간·추적은 모든 중간 표본이
  walkable 안·blocker 밖이어야 하며, flight만 지면 집합 밖 자유 Y를 유지한다.
  naive X-only 목적지가 corridor 밖 또는 blocker 안인 fixture에서 ground 목적지
  Y가 유효 lane으로 바뀌는 대조와 flight 자유 Y 대조, 플레이어·수호령 각각의
  건물 앞/뒤 픽셀 가림 반전, portal 접근과 interior/exit cleanup을 실제 owner
  경로로 통과하기 전 production actor 승격은 RED다. 1D 수식을 좌표계에 그대로
  이식하지 않는 [GRT-052](godot_runtime_traps.md#grt-052)/
  [GRT-053](godot_runtime_traps.md#grt-053) 포팅 판정도 이 gate에 적용한다.
- **R2-C 후보 씰 상태 (2026-08-12):** 수호령 direct sibling·zero-z 계약,
  자기 발 anchor 투영, 건물 앞/뒤 픽셀 가림 반전(창모드 Vulkan D/E/F 169px
  완전 반전과 z=1 반증), 컴파일드 로코모션 무터널링, cross-lane recall 투영과
  naive X-only RED fixture, flight 면제 실재성, stale-request 숨김과
  fail-closed 거부는 후보 레벨에서 GREEN이다. 남은 RED는 production 실경로
  레그(portal 접근·interior/exit cleanup·실 owner cadence p95 재측정)뿐이며
  R3 활성화 게이트로 이월한다.
- **생성기 분할 기록:** 현재 2,745줄 순수 생성기는 기능 결함으로 판정하지
  않는다. 향후 `skeleton`/`plots`/`assignment`/`decor` 페이즈를 소형 owner로
  분리할 때는 독립 RNG salt, canonical fingerprint, 168-roster 결과와 기존
  mutation RED를 그대로 보존해야 하며, 줄 수만 줄이는 분할은 승인 근거가 아니다.

따라서 R2-B/R2-C와 환경 아트는 각각 **candidate runtime GREEN / art GREEN**으로
기록한다. 프로덕션 owner 콜사이트의 원자 연결과 실제 이동·진입·cleanup 게이트가
끝나기 전에는 `2D 광장 활성화`, `R2 production GREEN`, `R2 완료`를 선언하지 않는다.

## 7. R3-B candidate-only exterior runtime QA 기록

- focused `plaza_r3b_exterior_runtime_smoke.gd`는 GRT-040 완주 게이트 `4 legs / 1533 assertions`를 요구한다. 실 retained tree, 2축 runtime/minimap, portal+fail-closed, owner cadence+source isolation 중 하나라도 조기 중단되거나 leg별 최소 assertion을 못 채우면 최종 `ok`가 금지된다.
- 플레이어·수호령은 실제 texture를 가진 같은 Y-sort root의 direct sibling이다. 건물은 Base/Sign/Window를 유지하되 `Shadow` 자식은 0개이고, actor `ContactShadow`만 정확히 2개다. actual material·z·top-level·상속·modulate·visibility 변조를 남긴 채 다음 정상 sync가 같은 노드를 canonical 상태로 복원해야 한다.
- R3 중앙 hub는 edge corridor manifest에 이미 union member로 들어 있으므로 navigation adapter가 다시 append하면 RED다. 별도 hub provenance manifest와 union record의 ID·edge metadata·polygon이 정확히 1:1이어야 하고, portal-only 전신 배치는 `include_portals=true`에서만 통과해야 한다.
- 실 owner cadence 측정은 새 프로세스 3회, seed `4`와 최밀도 seed `12`, 각 warmup `120` + steady `600` samples로 고정한다. 측정 p95는 seed 4 `1277/1228/1214us`, seed 12 `1311/1287/1227us`이며 모든 회차가 `2000us` 상한 안이다. bind 후 source road와 ground draw를 변조해도 720/720 tick 결과가 유효해야 한다.
- 2020 x 1246 RTX 5070 Vulkan Forward Mobile A-H는 플레이어 앞/뒤 `5534px`, z 반증 `4877px`, 수호령 앞/뒤 `3386px`, z 반증 `2759px`, 카메라·미니맵 XY `2088px` 변화를 기록한다. 정확히 8 PNG와 failures 0 metrics가 있어야 종단 `ok`를 허용한다.
- R2-B/R2-C 회귀 5종, 변경 8 GDScript 정확 인덱스 warning scan, 격리 headless load와 scoped diff check는 GREEN이다. 격리 full warning scan은 R3-B 밖 기존 `lingpet_guardian_enhance_cutin_overlay_host.gd`가 cold checkout에서 관련 `.ctex`를 찾지 못해 중단됐으며, R3-B 변경 파일 warning 0을 대체하지도 전체 스캔 GREEN으로 오기하지도 않는다.
- 신규 owner는 `candidate_only=true`, `production_connected=false`이며 `plaza_scene.gd`, `project.godot`, `scenes/` 참조는 0건이다. 따라서 이 기록은 **R3-B candidate runtime GREEN**이고, R3-D 원자 전환 전에는 production 활성화 완료로 승격하지 않는다.

## 8. R3-C candidate-only lifecycle/prewarm QA 기록

- focused `plaza_r3c_lifecycle_prewarm_smoke.gd`는 GRT-040 `6 legs / 880 assertions`를 요구한다. cold prewarm, counterproof, 5회 왕복, 재진입 결정성, 실제 cadence, teardown isolation 중 하나라도 조기 중단되거나 leg별 최소 assertion을 못 채우면 `ok`가 금지된다.
- 독립 파생한 resource/GPU 경로는 lifecycle snapshot과 정확히 같아야 한다. catalog 25키, 건물 21레이어, actor 4장, seed 파생 환경·인테리어 집합을 실제로 순회하고, 모든 visible texture를 in-bounds `SubViewport`에 제출한 뒤 real `frame_post_draw` 2회를 통과해야 한다. 위임 자원 1개 제거, `runtime_bind` step 제거, GPU flush 1회, GPU path/identity 제거, duplicate completion은 각각 RED다.
- interior 진입은 runtime을 숨겨 유지하고 동일 instance로 복귀한다. 저장 return 위치가 compiled full-body navigation에서 유효하지 않으면 fail-closed이며, scene teardown은 runtime을 완전히 해체한다. 5회 왕복 전후 scene-owned node/material RID/texture identity/audio player 수는 같고, teardown 후 네 카운터는 모두 0이어야 한다.
- 새 Vulkan 프로세스 seed `4/12` × 3회는 각 `4 legs / 784 assertions`다. cold `6.293..7.767s`, warm `1.507..1.535s`, R3 activation `28..62us`, whole frame `1.900..2.568ms`, owner cadence p95 `519..697us`; warm≤cold와 p95<2ms를 모두 통과했다. stride-4 changed sample은 seed 4/12 `107,555/107,552`이며 같은 seed SHA는 3회 동일, 다른 seed SHA는 서로 다르다.
- 종료 verbose 분류는 실제 retained Node/Resource/양수 refcount/`Resources still in use`를 즉시 RED로 한다. 이번 6회에는 그런 retained 객체가 0건이고, Godot의 generic zero-ref disposal notice만 2회·총 4건 별도 계수됐다. 이는 scene-owned leak 0 계약과 분리해 기록하며 숨기지 않는다.
- 회귀 6종, headless load, 전수 warning scan `3610/3610`, production 참조 0을 통과했다. 따라서 이 기록은 **R3-C candidate lifecycle GREEN**이고 `production_connected=false`; R3-D 전에는 R1 폴백과 라이브 route를 바꾸지 않는다.
