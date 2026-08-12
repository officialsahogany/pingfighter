# 환격전 광장 2D 지도 승격 계획

상태: R0 자산·렌더러 준비 완료, R1 활성 런타임 브리지 완료, R2-A/P1 구조 후보 GREEN, R2-B candidate runtime GREEN; 프로덕션 미연결·최종 지면/도로 아트 RED
기준일: 2026-08-11

## 목표

현행 환격전 광장의 시드 기반 건물 선택 규칙은 유지하고, 한 줄 횡배치만 2차원 도로·필지 지도 생성으로 교체한다. 같은 시드에서는 같은 지도가 재현되고, 창 크기나 화면 비율이 바뀌어도 지도를 다시 생성하지 않는다.

이번 1차 개편에서 유지할 계약은 다음과 같다.

- `_select_building_types()`의 건물 수·종류·은행 보장·확률 규칙
- `stage_map_seeds[stage_id]`의 생성 및 세이브 보존 의미
- `_building_specs_cache`의 결정적 재사용
- 각 건물 인테리어의 `760 x 750` 좌표와 거래 UI 투영

`_building_specs_cache`의 생성 키에는 `stage_id`, 지도 시드, 고정 월드 크기와 생성 규칙 버전처럼 생성 결과를 바꾸는 값만 넣는다. `map_safe_rect`, 실제 viewport 크기, fit 배율, UI 밴드 크기 등 화면 파생 값은 절대로 넣지 않는다. 기존 `world_width` 인자를 이관 기간에 유지하더라도 호출값은 고정 `2400`이어야 하며 viewport 폭을 전달해서는 안 된다.

새 플레이스루마다 시드를 바꾸는 `run_id:stage_id` 승격은 원작 패리티를 바꾸므로 이번 범위에서 제외한다.

R1에서 한 가지 호환 경계를 의도적으로 앞당겨 승인했다. 바깥 광장의
`MAP_SIZE`는 레거시 `1900 x 750`에서 고정 `2400 x 1500`으로 승격한다.
이는 시드 값이나 세이브 스키마의 마이그레이션이 아니다.
`stage_map_seeds[stage_id]` 값과 건물 종류 선택은 그대로 보존된다. 다만
기존 1축 `_apply_building_positions()`가 `world_width`를 위치 산식에
사용하므로, 업데이트 전에 저장한 같은 시드도 새 버전을 처음 실행할 때
건물 좌표가 한 번 달라진다. 이후에는 캐시 키와 위치 입력이 고정 `2400`을
사용하므로 같은 스테이지·같은 보존 시드는 다시 같은 배치를 재현한다.

이 승격으로 바깥 광장의 수평 길이는 500 단위, 약 26.3% 늘어난다. 출구는
`Rect2(1750, 596, 120, 92)`에서 `Rect2(2250, 596, 120, 92)`로 이동하고,
`GAME_SIZE.x = 760` 기준 카메라 우측 clamp는 `1140`에서 `1640`으로
늘어난다. 이 보행 거리와 카메라 범위 변화는 R1의 의도된 플레이어 체감
변경이다. `1500` 높이는 R2의 고정 map-world 계약을 미리 고정한 값이며,
R1의 플레이어 이동·지면·카메라는 여전히 `GROUND_Y = 666`의 1축
횡스크롤 계약을 사용한다.

실제 Vulkan 프로덕션 경로에서 `StageClearResultPlazaSceneHandler.update →
PlazaScene.update_plaza → PlazaPlayerController.move_player`를 통과하고
`ui_right`를 60Hz로 계속 누른 결과, 직접 위치 이동 없이 출구에 처음
진입한 시점은 533프레임·`8.883s`였다. 레거시 출구 x=1750의 동일 속도
대조군은 408프레임·`6.800s`이므로 125프레임·`2.083s`, 약 30.64%의
실보행 증가다. 이 체감 증가를 R1 `MAP_SIZE` 승격의 일부로 수락한다.

다만 밀도 판정은 R1에서 통과하지 않았다. 정상 선택 규칙의 stage 1 seed
`5`는 `bank + shop` 두 동만 생성하며, 마지막 건물 visual 끝 x≈`1082.72`에서
출구 x=`2250`까지 약 `1167.28` world가 남는다. 플레이어가 마지막 건물을
화면에서 완전히 벗긴 뒤에도 약 `887.3` world·`3.70s` 동안 건물 없는 반복
벽/바닥만 이어지는 Vulkan 캡처가 확인됐다. 따라서 option (a)의 승인은
고정 월드와 보행 계약에 한정한다. 이 희소 판은 최종 미술 승인이 아니라
R2의 미사용 필지 장식 군집·도로 랜드마크가 반드시 해소해야 하는 RED
대조군이다.

## 좌표 계약

### 1. 생성 좌표: `plaza_map_world`

- 고정 크기: `2400 x 1500` 논리 단위
- 생성기, 도로 그래프, 필지, 장식, 충돌, 정렬 앵커는 이 좌표만 사용한다.
- 해상도·창 비율·UI 배율을 생성 시드 입력으로 사용하지 않는다.

### 2. 표시 영역: `map_safe_rect`

`map_safe_rect`는 상수가 아니다. 레이아웃 패스마다 실제 뷰포트와 현재 UI 밴드에서 파생한다.

- 크기 정본: 트리 안에서는 `canvas.get_viewport_rect().size`
- `@tool` 또는 트리 밖 호출: `is_inside_tree()`와 viewport null 가드 후 컨텍스트 크기를 폴백으로 사용
- 정본은 `left/top/right/bottom` inset 목록 또는 실제 UI Control의 최종 rect다. `map_safe_rect`의 위치와 크기는 매 레이아웃 패스에서 이 입력을 빼서 계산하며 파생 숫자를 별도 상수로 저장하지 않는다.
- 2020 x 1246에서 `top=72`, `right=360`, `bottom=120`, `left=0`만 제외하면 `Rect2(0, 72, 1660, 1054)`다. `1588 x 1054`를 의도한다면 `left=72`도 정본 inset 목록에 명시해 `Rect2(72, 72, 1588, 1054)`로 파생해야 한다.
- 가능하면 밴드 상수보다 실제 상단·좌측·우측·하단 UI Control의 최종 rect를 입력으로 사용한다.

Godot의 `canvas_items + expand`에서 2020 x 1246은 고정 논리 캔버스가 아니다. 화면 비율에 따라 논리 뷰포트 자체가 늘어나므로, 크기 변경 시 생성 결과를 폐기하지 않고 아래 투영만 다시 계산한다.

### 3. 투영과 카메라

기본 fit 배율은 다음과 같다.

```text
fit_scale = min(map_safe_rect.width / 2400,
                map_safe_rect.height / 1500)
```

기본 배율에서는 지도를 잘라내지 않고 중앙 정렬한다. 2020 x 1246 기준으로 폭이 먼저 맞으므로 남는 상하 공간은 두루마리·먹 번짐 배경으로 채운다. 창이 더 넓어질 때에도 지도 구도는 유지하고 여백이 늘어나게 한다.

카메라는 기존 `camera_x`를 `Vector2 camera_pan_world + float camera_zoom`으로 승격한다. 월드 생성 결과는 고정하고 pan·zoom·fit·offset만 표시 단계에서 적용한다. 렌더·입력·히트 테스트·미니맵은 하나의 정방향/역방향 투영 함수를 공유해야 한다.

지도용 안개·봉인 셰이더의 클립 좌표는 논리 캔버스 단위와 프레임버퍼 픽셀을 혼용하지 않는다. 비정수 배율과 창 모드에서 별도 검증한다.

## 기하 계약과 건물 아트 계약

지면과 입체 건물 그림에 같은 수학 판정을 강제하지 않는다. 생성기가 사용하는 기하는 엄격한 직교 투영을 따르고, 건물 스프라이트는 승인 은행에서 얻은 회화적 허용 밴드를 따른다. 둘의 접점은 렌더 접지용 `ground_anchor_chord`·`origin_pivot`과, 별도로 아트에 보정한 `footprint_art_reference`에서 파생되는 strict `footprint_polygon`이다.

### A. 엄격 기하 계약

대상은 지면, 도로, 필지, `footprint_polygon`, `origin_pivot`, Y 정렬과 미니맵 좌표다.

- 앙각: `30도`
- 방위각: `45도`
- 직교 기저: 화면 기울기 `+0.5 / -0.5`
- 원근 수렴: 금지. 평행한 월드 선은 화면에서도 평행하고 간격이 일정해야 함
- 입구 접근 방향: 화면 좌하향
- 지면·도로·필지의 네 모서리 및 접합부는 수학 좌표에서 생성

평면 자산은 수학 가이드와 네 모서리 정류를 사용할 수 있다. 승인된 `plaza_hwangyeok_ground_30deg_ortho_candidate_v3_rectified_clean.png`가 기준 지면이며, 기존 `plaza_hwangyeok_bank_3q_map_tone_v2.png`는 약 55~60도 부감 실패 비교 레퍼런스로만 보관한다.

### B. 회화적 건물 아트 계약

건물은 입체 회화이므로 평면 호모그래피로 30도 기하에 강제 정류하지 않는다. 정확한 앙각 숫자 대신 아래 자동 판정 가능한 은행 기준 밴드를 사용한다.

전체 건물에 하나의 호모그래피를 적용하는 것은 금지한다. 다만 기단 상면·기단 측면처럼 의미상 하나의 평면으로 저작된 좁은 영역은, 건물 나머지와 `origin_pivot`·알파 bbox·접지점을 그대로 둔 채 평행선 수렴만 고치는 국소 4점 정류를 허용한다. 이 경우 source/target 대응점, 변경 bbox와 재측정 결과를 sidecar QA에 남긴다.

1. **원근 수렴 없음:** 처마·기단처럼 원래 평행해야 하는 직선군을 후보마다 최소 두 family 저작한다. 각 family의 무방향 선분 각도 span은 `2.6도 이하`여야 하며 곡선 처마는 측정에서 제외한다. Hough 검출은 후보 제안에만 쓰고 정본 좌표는 sidecar QA에 명시한다.
2. **기단 상면 노출 비율:** 의미 좌표 네 점으로 저작한 `plinth_rear_chord`와 `plinth_front_chord`의 법선 투영 간격을 평균 chord 길이로 나눈다. 은행 기준은 rear `[(70,825),(1003,969)]`, front `[(70,870),(1003,1014)]`, `0.047109`; 허용 밴드는 ±15%인 `0.040043..0.054176`이다. 이 지표는 동일한 얕은 공용 기단 계열에만 적용한다.
3. **실루엣 종횡비:** `alpha_bbox_height / alpha_bbox_width`. 은행 기준은 `950 / 1172 = 0.810580`; 허용 밴드는 ±15%인 `0.688993..0.932167`이다.

추가 미술 불변 조건은 다음과 같다.

- 정면은 화면 좌하향으로 읽히고 측면 하나가 자연스럽게 노출될 것
- 주광은 화면 좌상단 고정
- 런타임 회전 금지
- 런타임 수평 반전 금지
- 같은 기능 표식과 3레이어 계약을 유지하되 가짜 문자·중국 궁궐 장식을 사용하지 않을 것

승인 은행은 정확한 30도 아이소 건물이 아니라 위 회화적 밴드의 기준 자산이다. 개별 지붕선의 기울기를 기하 계약 `±0.5`와 직접 비교해 건물을 기각하지 않는다.

## 생성 파이프라인

```text
_select_building_types()          # 현행 규칙 그대로 재사용
        ↓
generate_map_skeleton(seed)       # 지형 골격과 출구/랜드마크 축
        ↓
generate_road_graph()             # 주도로와 제한된 분기
        ↓
generate_building_plots()         # 도로변 후보 필지와 진입 조건
        ↓
assign_buildings_to_plots()       # 큰 건물/강한 제약부터 배정
        ↓
fill_unused_plots()               # 나무·노점·석등·연못·바위 군집
        ↓
build_render_specs()              # 정렬·히트·명패·미니맵 데이터
```

`_apply_building_positions()`는 `apply_building_plots()` 계열의 2D 배정 단계로 대체한다. 종류 선택과 위치 적용의 기존 2단 분리는 유지한다.

### 도로·필지 규칙

- 중앙 환계문/랜드마크에서 출구로 이어지는 주도로를 먼저 확정한다.
- 모든 건물 스프라이트의 입구는 좌하 방향을 향하므로, 건물용 필지는 `approach_side = lower_left`를 만족해야 한다.
- 필지의 좌하측에 도로 또는 짧은 진입 분기가 실제로 연결되어야 한다. 스프라이트 회전으로 잘못된 필지를 보정하지 않는다.
- `plot_class` 제약이 강한 대형·랜드마크·교차로 건물부터 배정한다.
- 배정 우선순위는 `은행 → 가챠 → 아카데미/대장간 → 수호령 상점 → 상점/선술집`이다. 시각적 크기 순서와 필지 제약 우선순위를 같은 값으로 취급하지 않는다.
- 가챠가 선택된 시드에는 `medium_left_access` 필지를 골격 단계에서 최소 하나 예약한다. 맞는 필지가 없다는 이유로 이미 선택된 가챠를 탈락시키면 기존 종류 선택 계약이 깨진다.
- 대장간 필지는 `no_overhead_decor`, `edge_vent` 태그를 가져 굴뚝 위 나무·현수 장식을 금지한다.
- `road_side_clearance` 영역에는 나무, 노점, 바위, 다른 건물, 명패를 배치하지 않는다.
- 도로 그래프 단계에서 필지 경계와 도로 접합부가 실제로 교차·연결되는지 검증한다. 단일 필지 단상 시안의 시각적 접촉을 도로 연결 증거로 대신하지 않는다.
- 진입 도로 폭, 필지 경계, `road_side_clearance` 사이에 틈이나 중첩이 없어야 하며 분기각이 건물 입구를 횡단하지 않아야 한다.
- 사용되지 않은 필지는 밀도와 기능이 있는 장식 군집으로 채운다. 건물이 2개인 시드는 한적한 변두리 장터로, 5개인 시드는 번화한 중심지로 읽혀야 한다.
- R2의 첫 시각 게이트는 stage 1 seed `5`의 `bank + shop` 두 동 판이다. 현재 마지막 건물 뒤 약 `1167.28` world, 화면상 건물 없는 약 `3.70s` 구간을 그대로 남기면 RED다. 도로변 노점·석등·수목·표지·소형 랜드마크 군집으로 빈 필지를 채우고, 전체 2D 지도 fit과 실제 이동/선택 캡처 양쪽에서 결손이 아니라 한적한 장터로 읽혀야 다음 생성 단계로 진행한다.
- 장식 배치는 필러 수만 늘리는 방식이 아니라 도로 가장자리, 수변, 후면 군집처럼 의미 있는 분포 규칙을 사용한다.

회전·반전을 사용하지 않으므로 1차 구현에서는 고정 방향 `footprint_polygon` 또는 그 보수적 AABB로 겹침을 검사한다. 런타임 회전을 도입하는 후속 단계가 생기면 그때 회전 AABB 또는 SAT를 별도 설계한다.

## 건물 매니페스트 계약

각 2D 지도 건물은 최소 다음 정보를 제공한다.

| 필드 | 의미 |
|---|---|
| `origin_pivot` | 아티스트가 명시한 `ground_anchor_chord` 중점. 알파 bbox에서 유도하지 않음 |
| `ground_anchor_chord` | 스프라이트가 지면에 닿는 좌우 저작 현. 30도 rhombus의 변으로 취급하지 않음 |
| `footprint_art_reference` | `alpha >= 128` 하단 기단의 canonical 연속 지지 span과, 별도 수동 저작한 안정적인 전면 모서리 |
| `footprint_polygon` | 위 아트 reference를 strict `±0.5` 기저로 제약 투영한 지면 점유 평행사변형. 매니페스트에는 `origin_pivot` 상대 좌표로 저장 |
| `entrance_anchor` | 좌하향 입구와 도로를 연결할 기준점 |
| `entrance_normal` | 회화 왜곡에서 추론하지 않는 엄격 기하 접근 방향 `[-1, +0.5]` |
| `sort_anchor` | 건물의 Y 정렬 기준점 |
| `label_anchor` | 기단 우측면 바깥 명패 기준점 |
| `plot_class` | 대형, 교차로, 후면 랜드마크 등 필지 요구 등급 |
| `approach_side` | 1차 계약에서는 `lower_left` 고정 |
| `road_side_clearance` | 입구 앞에서 비워 둘 영역 또는 폭 |
| `occlusion_band` | 플레이어/장식이 건물 뒤로 들어갈 때의 가림 전환 구간 |
| `allow_rotation` | `false` 고정 |
| `allow_mirror` | `false` 고정 |
| `sign_glow_color` | 기능 표식의 발광색. 무채색 sign mask에 런타임 적용 |
| `window_glow_color` | 건물별 창·결계 발광색. 은행은 옥빛 |
| `sign_glow_strength` / `window_glow_strength` | 마스크 면적 차이를 보정할 런타임 강도. 기본값 `1.0` |
| `art_metrics` | 평행선 쌍, 기단 상면 chord 네 점, 알파 bbox 종횡비와 판정 결과 |

`label_anchor`와 명패 rect는 건물 `visual_rect`와 별도로 충돌 검사한다. 은행은 입구를 가리지 않는 기단 우측 바깥을 기본 위치로 삼는다.

`origin_pivot`은 스프라이트의 최하단 픽셀이나 알파 bbox 중심이 아니다. 각 건물의 지면 접지 현인 `ground_anchor_chord` 중점을 원본 캔버스에서 수동 저작한다. 은행의 값은 `ground_anchor_chord = [(598, 1090), (1008, 1090)]`, 중점 `[803, 1090]`이다. 이 현은 렌더 배치와 Y-sort 기준일 뿐 footprint 폭·중심·앞꼭짓점이 아니다.

footprint는 chord 폭에서 만들지 않는다. `alpha >= 128`, pivot 상대 y 구간 `[-180,-60]`에서 가장 긴 연속 가시 run을 찾고, 동률은 `최대 픽셀 수 → 가장 작은 y → 가장 작은 x` 순으로 고정한다. 이 run은 기단의 수평 점유폭만 제공한다. 앞꼭짓점은 5px 최하단 tip이 아니라 21px 세로 지지가 확인된 `front_contact_source_pixels`를 별도로 수동 저작한다. 따라서 `origin_pivot`과 footprint front/centroid를 같다고 가정하지 않는다.

지지 span의 x 한계를 `L`, `R`, 별도 앞꼭짓점을 `F=(Fx,Fy)`라 하면 strict 절대 좌표는 다음과 같다.

```text
a = Fx - L
b = R - Fx
rear  = (L + b, Fy - (a + b) / 2)
right = (R,     Fy - b / 2)
front = (Fx,    Fy)
left  = (L,     Fy - a / 2)
```

이 식은 네 변을 정확히 `±0.5`로 유지하면서 footprint x 범위를 실제 기단 지지 span과 일치시킨다. 최종 polygon만 `origin_pivot` 상대 좌표로 직렬화한다.

좌표 단위는 혼용하지 않는다. `origin_pivot`, `ground_anchor_chord`, `footprint_art_reference`, `entrance_anchor`, `label_anchor_source_pixels`는 1254² 원본의 절대 source-px이고, `footprint_polygon`, `sort_anchor`, `label_anchor`, `occlusion_band`는 pivot 상대 source-px이다. `road_side_clearance`만 고정 map-world 단위다. viewport, safe rect, fit 배율은 어느 저작 좌표에도 들어가지 않는다.

### 7종 수동 기하 1차 정본

| 건물 | chord | pivot | entrance | display height | plot class |
|---|---|---|---|---:|---|
| 은행 | `(598,1090)-(1008,1090)` | `(803,1090)` | `(510,1045)` | 360 | `rear_landmark_large` |
| 상점 | `(550,1110)-(890,1110)` | `(720,1110)` | `(500,1065)` | 275 | `standard_market` |
| 가챠 | `(810,1060)-(1050,1060)` | `(930,1060)` | `(210,1015)` | 295 | `medium_left_access` |
| 수호령 상점 | `(835,1100)-(1055,1100)` | `(945,1100)` | `(380,1080)` | 285 | `medium` |
| 대장간 | `(705,1130)-(935,1130)` | `(820,1130)` | `(525,1100)` | 300 | `edge_large` |
| 선술집 | `(705,1110)-(905,1110)` | `(805,1110)` | `(410,1065)` | 260 | `standard_quiet` |
| 아카데미 | `(600,1100)-(1000,1100)` | `(800,1100)` | `(365,1085)` | 315 | `intersection_large` |

| 건물 | canonical 기단 지지 span | 별도 footprint front |
|---|---|---|
| 은행 | `(69,910)-(1195,910)` | `(998,1100)` |
| 상점 | `(80,930)-(1185,930)` | `(836,1144)` |
| 가챠 | `(39,918)-(1222,918)` | `(1035,1084)` |
| 수호령 상점 | `(24,941)-(1228,941)` | `(1035,1124)` |
| 대장간 | `(123,950)-(1167,950)` | `(906,1159)` |
| 선술집 | `(123,930)-(1210,930)` | `(862,1137)` |
| 아카데미 | `(39,966)-(1208,966)` | `(991,1114)` |

모든 footprint 꼭짓점은 `rear → right → front → left` 순서이며 네 변의 기울기가 정확히 `±0.5`다. footprint의 수평 폭은 강한 알파 실루엣 폭의 `0.894..0.971`이고, 전면 모서리는 강한 알파 최하단에서 `0..19px` 안에 있다. 7종 모든 꼭짓점은 1254² 캔버스 안에 있다. 가챠 입구는 pivot 대비 `(-720,-45)`이므로 footprint 중심 clearance를 금지하고, 좌하 필지 경계에서 입구까지 별도 corridor polygon을 생성한다. 입구 portal 통로만 도로-건물 footprint 중첩을 허용하며 장식 충돌에는 예외를 적용하지 않는다.

`label_anchor`는 명패 중심이 아니라 우측 외곽 stem이다. 명패 rect는 stem에서 우측으로 `half_label_width + 12 world`만큼 이동해 만든 뒤 visual/footprint와 별도로 충돌 검사한다. `occlusion_band`와 넓은 개방 파사드인 상점·선술집 입구 좌표는 실제 지도 배율 합성에서 한 차례 미세 조정할 수 있다.

## 3레이어 자산 계약

모든 레이어는 같은 캔버스 크기, 원점, 피벗, 알파 실루엣 좌표를 사용한다.

1. `base`: 비발광 상태의 건물 본체. 창, 석등, 봉인륜, 결계 문양의 물리 형태는 어둡게 남긴다.
2. `sign_emissive`: 기능 정체성을 나타내는 금고/봉인 표식의 그레이스케일 마스크. 런타임에서 `sign_glow_color`와 강도를 적용한다.
3. `window_glow_mask`: 옥빛 창살, 석등, 기단 결계 문양의 그레이스케일 마스크. 런타임에서 `window_glow_color`와 강도를 적용한다.

`sign_emissive`와 `window_glow_mask`에는 어두운 컬러를 굽지 않는다. 두 레이어 모두 RGB가 동일한 무채색 마스크로 저장해 ADD/MIX 셰이더가 충분한 발광 예산을 갖게 하고, 색은 매니페스트에서 주입한다.

보이는 마스크 픽셀은 RGB `[255,255,255]` 고정이고 강도는 alpha 하나에만 저장한다. base alpha는 승인 원본과 바이트 단위로 같아야 하며, 새 6종은 두 마스크가 0인 픽셀의 base RGB도 원본과 같아야 한다. base 감광은 선형색에서 `source × lerp(1, factor, mask_alpha)`로 수행하고, sign full-mask factor는 은행 승인본 패리티인 `0.60`을 사용한다.

sign은 7종 공통 의식 황금 `#FFC44C`로 묶고, 원거리 구분은 아래 window 색상환이 담당한다.

| 건물 | `window_glow_color` | 역할 |
|---|---|---|
| 은행 | `#4AFFCB` | 옥빛 |
| 상점 | `#B8F15A` | 연두 |
| 가챠 | `#FF61C8` | 캡슐 분홍 |
| 수호령 상점 | `#D28CFF` | 라벤더 |
| 대장간 | `#FF4B2F` | 주홍 |
| 선술집 | `#FFD15A` | 호박금 |
| 아카데미 | `#4D9DFF` | 청람 |

분리는 공용 HSV 임계값이 아니라 `수동 의미 스텐실 × ROI 내부 국소 명도`를 정본으로 한다. 가챠 캡슐은 두 마스크에서 제외하고 황동 외륜·스포크·허브·회전 화살표만 sign에 둔다. 수호령 알, 대장간 불꽃, 아카데미 오브는 sign에서 제외하고 window에 둔다. 수호령은 최종 v6 hybrid를 원본으로 사용하며 전역 despill을 다시 적용하지 않는다.

호버·선택 강조를 전각 전체 `modulate`로 처리하지 않는다. 국소 발광 레이어의 강도 변화와 base 알파에서 파생한 실루엣 아웃라인 발광을 허용 수단으로 사용한다. 아웃라인은 알파 경계만 따라야 하며 페인티드 실루엣 바깥에 사각 강조가 드러나서는 안 된다.

은행 시제품과 나머지 6종의 승인 3레이어 작업 원본은 `tmp/imagegen/plaza_hwangyeok_building_layers_v1/`에 보존한다. 이 경로는 프로덕션 로드 경로가 아니며, 승인 원본 PNG도 덮어쓰지 않았다. 런타임은 `godot/assets/ui/plaza/buildings/hwangyeok/`의 512² 파생 자산 21장을 사용한다. `plaza_hwangyeok_layers_v1_contact_board.png`, `plaza_hwangyeok_geometry_anchor_contact_board.png`, `plaza_hwangyeok_display_scale_palette_qa.png`가 작업 원본 검토 정본이다.

## 런타임 소유권과 이관 경계

- 바깥 광장 셸: `scripts/plaza/plaza_scene.gd`는 월드 호스트 부착, owner-frame 상태 동기화, 화면 전환과 실제 인테리어/이탈 정리를 담당한다. retained 레이어의 구체 드로우는 소유하지 않는다.
- 월드 표시 호스트: `plaza_map_world_host.gd`가 불투명 map fill, 배경 렌더러 호출, retained 건물 자식 수명과 fail-closed 가시성을 소유한다.
- 활성 자산/스펙: `plaza_asset_loader.gd`가 고정 `2400 x 1500` 월드 크기, 환격전 매니페스트 7종, 결정적 건물 스펙과 21장 레이어 프리웜 상태를 소유한다.
- 월드 생성: 새 소형 소유자(예: `plaza_map_generator.gd`)가 골격, 도로, 필지, 장식 스펙을 결정적으로 생성한다.
- 좌표/투영: `plaza_world_geometry.gd`를 2축 정방향·역방향 투영, 카메라 클램프, safe rect 계산의 단일 소유자로 승격한다. 파일이 과도하게 커지면 순수 투영만 `plaza_map_projection.gd`로 분리한다.
- 건물 표시: `plaza_building_renderer.gd`가 base/sign/window 소유 CanvasItem, 레이어별 material, 3레이어 합성, Y 정렬, 호버/선택 발광을 소유한다.
- 미니맵: 현행 1축 투영을 동일한 2D 월드 스펙의 축소 투영으로 교체하되, 월드 생성 로직을 복제하지 않는다.
- 인테리어: `plaza_interior_layout.gd`와 내부 `760 x 750` 계약은 변경하지 않는다.

R1의 실제 소유권 이동은 `docs/godot_port_architecture.md`와 모듈 소유권 원장에 함께 기록한다. R2에서 생성/투영 소유자를 새로 만들 때도 같은 원칙을 적용한다.

현행 **활성 광장 경로**는 `build_hwangyeok_building_specs()`를 통해 위 색·강도와 동일 `marker_color` 정본을 spec에 싣고 retained renderer/minimap에 전달한다. 기존 `BUILDING_MANIFEST_PATHS`와 immediate `draw()`는 호환/롤백 표면으로만 남고 프로덕션 건물 표시는 이를 사용하지 않는다. 활성 `MAP_SIZE`는 고정 `2400 x 1500`이지만 위치 적용은 아직 기존 1축 `_apply_building_positions()`를 사용하므로, 이 상태를 2D 도로·필지 생성 완료로 표현하지 않는다.

활성 retained 경로에서 base/sign/window는 각각 자체 `CanvasItemMaterial`을 가진 자식 CanvasItem이며, base는 MIX, sign/window는 ADD를 소유한다. immediate-mode `_draw()` 도중 `canvas.material`을 잠깐 바꾸는 방식은 프로덕션 경로에 사용하지 않는다.

## 런타임 승격 슬라이스

기존 광장 씬의 대형 워킹트리 변경과 후보 자산/렌더러 준비를 섞지 않는다. 런타임 승격은 아래 R0 → R1 순서로 진행한다.

### R0 — 비활성 자산·렌더러 준비 (완료)

- 승인된 1254² 작업 원본은 보존하고, 7종 × 3레이어를 실제 런타임 표시 크기에 맞춘 **512 x 512 RGBA PNG 21장**으로 별도 생성한다. 단순 경로 복사나 1254² 그대로의 승격은 R0 통과가 아니다.
- 현재 승인 1254² master는 gitignored `tmp/imagegen/`에 workspace-only로 보존한다. 512² 런타임 산출물은 독립적으로 사용할 수 있지만, 클린 체크아웃에서 prep 스크립트를 재실행할 수 있다고 주장하지 않는다. 재생성 가능한 영구 원본 보관은 별도 승인을 받아 LFS source-art 승격으로 처리한다.
- 512² 런타임 레이어의 피벗·footprint 등 저작 좌표는 1254² source-px 정본을 바꾸지 않는다. 렌더러가 source 크기와 runtime texture 크기의 비율을 명시적으로 적용한다.
- 후보 매니페스트, 색·강도 파싱, 레이어별 소유 `CanvasItem`, ADD 재질과 프리웜 위임을 준비하되 활성 광장 진입 경로에는 연결하지 않는다.
- 현행 `plaza_scene.gd`의 즉시 드로우 경로와 기존 활성 매니페스트는 R0에서 바꾸지 않는다. 따라서 R0는 자산·로더·클린 렌더러 영역에서 독립 검증할 수 있어야 한다.
- R0 게이트는 21장 전수 로드, 512²/알파/마스크 정합, VRAM high-quality import, 자식 렌더러 프리웜 완료 전 부모 완료 금지, 그리고 현행 광장 렌더 결과 무변경이다.

### R1 — 활성 광장에 원자적 연결 (완료)

- 바깥 map world는 해상도와 무관한 고정 `2400 x 1500`을 사용한다. 이는 레거시 `MAP_SIZE = 1900 x 750`을 R1에서 의도적으로 승격한 승인된 경계 변경이다. 과거의 "R1에서는 `MAP_SIZE`를 건드리지 않는다"는 범위 문구는 이 결정으로 대체한다. 각 건물 인테리어와 거래 UI의 `760 x 750` 계약은 이 승격과 분리해 그대로 유지한다.
- 단, R1은 retained 소유권만 먼저 승격한 브리지다. 활성 표시는 아직 바깥 셸의 기존 `GAME_SIZE = 760 x 750` 횡스크롤 fit 배율을 사용하며, R2 목표인 `map_safe_rect → 2400 x 1500` 지도 fit을 사용하지 않는다.
- `plaza_scene.gd`는 `_draw()`의 불투명 전체 화면 fill, 배경/건물 즉시 드로우 호출, 월드 호스트 부착·동기화·정리와 `MAP_SIZE`의 loader 정본 연결에 직접 맞닿는 hunk만 allowlist로 수정한다. `_apply_building_positions()`와 `_camera_x`의 1축 알고리즘, 시드·세이브 스키마, 인테리어의 `760 x 750` 계약과 무관한 WIP는 건드리지 않는다.
- 호스트 상태의 `render_size`는 엔진 뷰포트가 아니라 **광장 루트의 local render rect 크기**, 즉 R1 콜사이트의 `plaza_scene.size`다. `get_viewport_rect().size`를 넣거나 레거시 키 `viewport_size`를 사용하지 않으며, 호스트 local position은 `Vector2.ZERO`로 유지한다.
- 호스트는 `set_process(false)`인 sync-driven 렌더러다. R1 소유자는 매 rendered frame마다 `Time.get_ticks_msec()`를 한 번 샘플하고, 같은 값을 `ticks_msec`로 넘겨 배경과 모든 건물 pulse가 한 프레임 시계를 공유하게 한다. 최초 한 번만 동기화해 tick 스냅샷을 박제하는 구현은 허용하지 않는다.
- 월드 호스트 부착과 `plaza_scene.gd` 루트의 불투명 fill 이동은 **한 변경에서 원자적으로** 수행한다. 호스트만 먼저 붙이면 루트 `_draw()`의 fill에 묻히고, fill만 먼저 옮기면 전환 프레임이 비거나 검게 보일 수 있으므로 둘을 분리 착륙시키지 않는다.
- 월드 호스트는 광장 루트의 상대 자식으로 `z_index = -1`, `z_as_relative = true`를 고정한다. 라이브 광장 루트가 `z_index = 1200`으로 구동될 때 유효 z는 1199다. `z_as_relative = false`로 바꾸거나 절대 `-1`을 사용하는 것은 금지하며, 이 불변식은 스모크에서 직접 단언한다.
- 새 불투명 map fill과 지도 배경은 월드 호스트가 함께 소유한다. 광장 루트나 그 조상에는 월드 호스트를 덮는 불투명 fill이 남아 있지 않아야 한다.
- retained 호스트는 fail-closed로 동기화한다. 매 draw/sync 진입의 모든 얼리리턴보다 앞에서 `set_active(false)`를 호출하고, 유효한 광장 월드 스펙을 동기화한 말미에만 다시 켠다. `clear_transient_canvas_items()`에서도 반드시 내린다.
- 유령 회귀 레그는 최소 `size <= 1`의 degenerate 화면, 실제 건물 진입을 통한 인테리어 활성화, 실제 광장 이탈 콜백/씬 해제 경로를 관통한다. 호스트 API를 직접 호출하는 리프 테스트만으로 대체하지 않으며, draw 자체가 다시 호출되지 않아도 clear 경로가 호스트를 동기적으로 숨겨야 한다.
- 활성 loader가 `sign_glow_color`, `window_glow_color`, 두 strength와 같은 정본의 `marker_color`를 전달하고, 건물 렌더러와 미니맵이 그 값을 함께 소비한다. 프로덕션 프리웜은 `plaza_scene.gd` → 월드 호스트 → 건물 렌더러 → loader로 직접 위임되어 retained 텍스처 21장을 모두 준비한다.
- 결과 화면의 라이브 `BUTTON_PLAZA`는 notice가 아니라 `ACTION_ENTER_PLAZA`로 연결된다. 진입 콜백은 자원 캐시와 GPU 드로우가 모두 끝나지 않았을 때 명시적 `false`를 반환하고, 콜백 소유자는 이를 소비하지 않고 보존해 다음 클릭으로 재시도할 수 있게 한다. 완료된 클릭만 콜백을 비우고 광장 씬을 생성한다.
- 미완료 클릭은 입력 프레임에서 blocking cache drain을 실행하지 않는다. 라이브 콜백은 frame-driven `prewarm_assets_step()`을 한 번만 전진시키고 즉시 반환하며, `광장으로` 버튼은 활성 톤을 유지한 채 실제 결과 draw 경로에 `준비 중입니다`를 표시한다. 콜드 정상 타이밍 재현에서 첫 클릭은 `622ms → 14ms`로 줄었고, 2020 x 1246 Vulkan notice on/off 대조는 `10,316px`가 달랐다. 이 벽시계 수치는 실측 기록이며 CI 고정 시간 임계가 아니다.
- GPU 프리웜은 메인 캔버스의 화면 밖 좌표에 의존하지 않는다. 독립 `512 x 512` `SubViewport` 안에 실제 retained 월드 호스트를 두고 7종 x 3레이어를 모두 viewport 내부에서 드로우한다. 완료 씰은 현재 캐시의 `Texture2D` instance ID 21개, in-bounds/drawn 레이어 21개, `RenderingServer.frame_post_draw` 2회 flush를 함께 요구하며 ID drift가 생기면 readiness를 무효화한다.
- R1의 z-order/ADD 판정은 상태 스모크만으로 끝내지 않는다. 같은 frame 구성의 strength `0` 대 `1`, 프로덕션 ADD 대 강제 MIX를 각각 쌍으로 캡처하고 픽셀 델타를 단언한다. 또한 **부모 즉시 드로우의 불투명 fill을 복원한 채 음수-z 발광 자식을 켜는 역변경**에서 후보 테스트가 반드시 RED가 되는지 확인한다. `visible=true`, texture/material 정상만으로 통과시키지 않는다.
- R0 호스트의 `draw_opaque_fill` capability나 하드코딩된 소유권 bool은 R1 fill 소유권의 증거가 아니다. R1은 `draw_opaque_fill = true` 전달, 루트 fill 제거, 실제 불투명 sentinel 픽셀을 한 게이트에서 함께 확인한다.

R1 최종 Vulkan A-H 씰은 실제 GPU 프리웜 readback `148,223px`, GPU readiness `34.938ms`, 씬 spawn 호출 `8.432ms`, spawn 반환부터 첫 post-draw `20.758ms`를 기록했다. strength 0↔1은 `7,459px`, ADD↔MIX는 `7,366px`가 달랐고, 수명 sentinel `6,144px`는 street에서 보인 뒤 degenerate(F)·인테리어(G)·이탈(H)에서 각각 `0px` 남았다. 총 8장 캡처, 실패 0건이다. Godot이 `SubViewport`를 최소 `2 x 2`로 클램프하므로 degenerate V 레그는 라이브 `PlazaScene` 루트의 `_draw()` fail-closed 진입을 사용했으며 호스트 API를 직접 호출하지 않았다.

이 완료 판정은 retained 런타임 브리지에만 적용된다. 후속 R2-A/P1은
`plaza_map_projection.gd`와 `plaza_map_layout_generator.gd`를 프로덕션과
분리한 후보로 구현해 고정 `2400 x 1500` 투영, 결정적 도로·필지·건물·장식
스펙, 전체 도로 topology, 보행 corridor와 상호작용 portal의 구조 게이트를
통과했다. 56개 건물 부분집합과 seed `5/6/7`의 168개 roster, 필드 변조
역검증, seed `5` 2020 x 1246 의미 장식 보드는 GREEN이다. 이는 기존
`_apply_building_positions()`나 활성 광장을 교체한 결과가 아니다.

R2-B는 `plaza_map_navigation.gd`, `plaza_map_minimap_projection_2d.gd`,
`plaza_r2_map_world_candidate_host.gd`와 전용 스모크/Vulkan QA로만 구성된
candidate-only 슬라이스다. 전신 actor rect의 정확한 walkable-union 판정,
바인딩 geometry digest, 모든 건물·플레이어·출구·카메라의 2축 미니맵 투영,
caller와 분리된 compile/validate/apply draw 상태, actual CanvasItem 형제의
Y-sort와 `z_index = 0`, `z_as_relative = true`, `top_level = false` 계약을
검증한다. navigation/minimap 보강, 호스트 focused 상태 게이트와 2020 x 1246
Forward Mobile A/B/C Vulkan Y-sort 대조까지 GREEN이다. 같은 위치에서 A는
건물 probe `169px`/actor `0px`, B와 actual actor `z_index = 1` 반증 C는
actor `169px`/probe `0px`였고 A↔B와 A↔C가 각각 `169px` 달랐다. C의 actual
tree 계약도 `valid = false`, `all_direct_z_zero = false`로 RED였다.
`plaza_scene.gd`와 `project.godot`에는 이 후보 소유자 참조가 없으므로
candidate runtime GREEN을 프로덕션 연결 완료나 R2 완료로 표현하지 않는다.

호스트의 actual visual/material 계약도 상태 리터럴이 아니라 실제 tree에서
봉인했다. Base는 canonical MIX, Sign/Window는 canonical ADD material을 쓰고,
Probe/Body는 local material `null`이며 전 레이어의 `use_parent_material`은
`false`다. sort root와 building/actor wrapper의 `modulate`는 흰색, 자식의
`self_modulate`는 흰색, `show_behind_parent`는 `false`이고 유효 sync는
Base/Sign/Window/Actor/Body를 보이게 하며 Probe 가시성은 compiled record를
따른다. 실제 material·blend·상속·modulate·visibility 변조를 tree에 남긴 채
status가 RED가 된 뒤, 다음 유효 sync가 같은 노드를 정확한 계약으로 복원해
GREEN이 되는 양방향 씰을 통과했다. 이 보강 뒤 독립 감사 결과는
CRITICAL `0`, HIGH `0`이다.

다만 이 correctness GREEN은 navigation steady-state 성능 승인이 아니다.
현재 `move_actor()`는 60Hz 후보 보행의 매 호출 시작에서 전체 corridor/portal/
blocker를 문자열로 다시 직렬화해 SHA-256 geometry digest를 검증하고,
occupancy는 전신 rect 피복을 위해 `Geometry2D.clip_polygons()`를 호출한다.
프로덕션 원자적 활성화 전 MEDIUM 게이트로 실제 owner tick의 대표·최밀도
지도에서 steady p95를 측정하고, geometry를 bind 시 한 번 검증·compile한
immutable owner와 할당 없는 fast path로 옮긴 뒤 동일 2px slit·mutation
역검증과 이동 결과를 유지해야 한다. 측정·최적화 전에는 후보를 60Hz/상시
프로덕션 이동 경로에 연결하지 않는다. 이는 setup-time 전체 스캔을 per-frame
경로로 옮기지 말라는 [GRT-032](godot_runtime_traps.md#grt-032)의 같은 계열
계약이다.

R2-C의 actor 승격은 플레이어 단독 항목을 연결하는 작업이 아니다. 현재 후보
호스트의 단수 `_actor_item`은 candidate proof 전용이며, 라이브 광장의
`_lingpet_follower_pos`도 아직 `GROUND_Y` 목표를 향해 단순 `lerp`한다. 원자적
활성화에서는 플레이어와 수호령 wrapper를 같은 Y-sort root의 direct sibling으로
두고, 각자의 foot/sort anchor와 실제 레이어가 같은 zero-z/relative/material
계약을 통과해야 한다. 수호령 follow target과 이동도 컴파일된 2D walkable/
blocker geometry를 소비해야 하며, 장애물을 가로지르는 직선 보간이나 플레이어
Y로의 무조건 snap을 허용하지 않는다. [GRT-013](godot_runtime_traps.md#grt-013)에
따라 ground/patrol 수호령의 scripted recall·teleport 목적지는 전신 actor가
컴파일된 walkable union 위에 놓이는 유효 지점으로 투영한다. cross-lane recall은
목적지 lane에 맞춰 X와 Y를 모두 바꿀 수 있다. 순간 teleport는 출발·도착점이
모두 유효해야 하고, 보간·추적 이동은 모든 중간 표본이 walkable union 안이며
blocker 밖이어야 한다. 따라서 1D 규칙의 `현재 Y 유지/X만 변경`이나 플레이어 Y
직접 복사는 2D 정본이 아니다. flight 수호령만 walkable 지면에 구속되지 않는
자유 Y 이동을 유지한다. 이는 원본 수식을 새 좌표계에 그대로 옮기지 않는
[GRT-052](godot_runtime_traps.md#grt-052)와 호출 경로까지 판정하는
[GRT-053](godot_runtime_traps.md#grt-053)의 같은 포팅 원칙이다. 실제 플레이어와
수호령 각각이 건물 sort anchor 앞뒤를 지날 때 픽셀 가림 순서가 뒤집히는 대조,
naive X-only 목적지가 corridor 밖/blocker 안인 cross-lane fixture에서 유효한
목적지 lane으로 Y가 바뀌는 ground 대조, flight 자유 Y 대조, portal·scene
transition cleanup을 모두 실경로로 봉인하기 전에는 R2-C actor 승격을 GREEN으로
판정하지 않는다.

`plaza_map_layout_generator.gd`는 현재 2,745줄이지만 순수 생성기이며 즉시 분할
대상은 아니다. 다만 `skeleton`/`plots`/`assignment`/`decor` RNG가 이미 독립
페이즈 경계를 이루므로, 각 페이즈에 두 번째 소비자나 독립 변경 주기가 생기는
시점에는 소형 owner로 분리한다. 분할은 같은 `(stage_id, map_seed)`에 대해 페이즈
RNG salt, canonical fingerprint, 168-roster 산출물과 모든 RED counterproof를
byte-stable하게 보존해야 하며, 줄 수만 줄이기 위한 함수 이동은 하지 않는다.

현재 후보 보드의 코드 드로우 도로·필지 표면과 workspace-only 의미 장식은
구조·역할 판독용이다. 승인된 최종 지면/도로 아트 및 라이브 이동·선택·진입
승격은 RED로 남아 있으며, 후보 GREEN을 최종 미술 승인으로 대체하지 않는다.

R1의 `MAP_SIZE` 승격은 별도 호환 판정으로 수락됐다. 저장된
`stage_map_seeds`를 다시 발급하지 않지만, 위치 산식의 폭 입력이
`1900 → 2400`으로 바뀌므로 업데이트 경계에서 한 번 좌표가 이동한다.
정확한 활성 계약은 `world_size = Vector2(2400, 1500)`,
`EXIT_ZONE = Rect2(2250, 596, 120, 92)`, 카메라 우측 clamp `1640`이다.
같은 시드로 새 고정 폭의 스펙을 반복 생성하면 이후 좌표는 동일해야 한다.

세부 QA 레그와 반증 절차는 `docs/plaza_2d_map_r0_r1_qa_contract.md`를 따른다.

## 자산 크기·프리웜 정책

- 1254 x 1254 승인 원본과 소스 레이어는 작업 원본으로 보관한다.
- R1 활성 런타임 PNG 21장은 512 x 512로 물리 다운스케일되어 있다. 현재 브리지의 2020 x 1246 창에서는 바깥 `GAME_SIZE` fit 배율이 `1246/750 ≈ 1.6613`이고, 은행의 360 world-unit 표시 높이는 약 598px가 되어 512px 텍스처를 약 `1.17x` 확대한다. 따라서 R1에는 2020 x 1246 실제 Vulkan 선명도 게이트가 필요하며, 이 상태를 2.15배 소스 여유라고 표현하지 않는다.
- 최대 표시 높이 약 238px와 512/238 ≈ 2.15배 소스 여유는 R2의 예시 `map_safe_rect.width = 1588`, `1588/2400` 지도 fit이 활성화된 뒤의 목표치다. R1 브리지의 현행 표시 크기와 혼용하지 않는다.
- 대형 또는 진입 시 프리웜되는 텍스처는 VRAM 압축과 high-quality import를 사용한다.
- 새 3/4 부감 텍스처 7종의 세 레이어는 활성 환격전 매니페스트와 건물 전용 프리웜 집합에 모두 등재한다.
- 경로 등재만으로 완료로 보지 않는다. 광장 프리웜 소유자는 3레이어 건물 렌더러의 `prewarm_assets_step()`에 실제로 위임하고, 자식이 끝날 때까지 완료를 반환하지 않아야 한다. 자식 위임을 제거하면 첫 호출이 곧바로 `already warm`으로 읽히는 역검증 스모크를 둔다.
- 프리웜 완료 전에는 전환 프레임에서 동기 콜드 로드를 허용하지 않는다.
- 절차 배경의 낙관·간판은 실제 판독 가능한 한자/한글 또는 문자 없는 추상 문양만 사용한다.

## 검증 게이트

### 결정성·생성

- 같은 `stage_id` 시드 → 건물 종류, 도로, 필지, 장식까지 바이트 수준으로 같은 생성 스펙
- 다른 시드 → 규칙 안에서 다른 2D 지도
- 건물 2개와 5개 극단 시드 모두 자연스러운 밀도
- 은행 필수, 기존 조건부 선술집/퀘스트 규칙 보존
- 필지·건물·명패 겹침 없음
- 모든 입구가 좌하측 도로에 연결되고 `road_side_clearance`가 비어 있음
- 필지 경계와 도로 접합부에 틈·중첩·단절이 없고, 진입 분기가 입구 clearance를 관통하지 않음

### 표시·입력

- 화면 비율과 창 크기 변경 시 생성 횟수 증가 없음
- fit/offset만 재계산되고 월드 좌표는 불변
- 마우스·키보드·게임패드의 선택, 포커스, 진입이 2D 좌표에서 일치
- 2축 pan·zoom과 카메라 클램프
- 미니맵 마커와 본 지도 위치 일치
- 비정수 배율에서 안개·봉인 셰이더 클립 누출 없음
- **R2 production MEDIUM 성능 게이트:** [GRT-032](godot_runtime_traps.md#grt-032)에 따라 실제 owner tick에서 대표 seed와 최밀도 seed의 비충돌 보행·벽 slide·portal 접근을 충분히 반복해 `move_actor()` steady p95를 기록한다. bind-time immutable compiled geometry와 fast occupancy 경로로 매 tick 전체 문자열/SHA 재계산을 제거하고, `Geometry2D` clip 호출·할당을 hot path에서 제거하거나 측정된 예산 안으로 제한하기 전에는 활성 경로에 연결하지 않는다.
- **R2-C 플레이어·수호령 공동 actor 게이트:** 플레이어와 수호령을 같은 Y-sort root의 direct sibling으로 두고 actual layer까지 같은 zero-z/relative 계약을 검증한다. 현재 `GROUND_Y`+직선 `lerp` 팔로워를 2D navigation owner로 교체한다. [GRT-013](godot_runtime_traps.md#grt-013)의 2D 전치는 ground/patrol의 Y 고정이 아니라 목적지 전신과 보간 전 구간이 compiled walkable union 안·blocker 밖이라는 계약이다. cross-lane recall은 목적지 lane의 Y로 바뀔 수 있고 flight만 지면 집합 밖 자유 Y를 허용한다. naive X-only가 corridor 밖이 되는 fixture, actual 픽셀 가림, portal/cleanup을 실경로로 봉인한다.

### 자산·렌더

- 세 레이어의 캔버스, 피벗, 알파 좌표가 정확히 일치
- sign/window가 모두 RGB 동일 그레이스케일 마스크이고, 최소 ADD 발광 휘도 예산을 충족
- `origin_pivot`이 알파 bbox가 아니라 저작된 `ground_anchor_chord` 중점과 일치
- 지면·도로·필지 기저는 정확히 `+0.5 / -0.5`, 건물은 별도 회화적 아트 밴드 통과
- 각 `footprint_art_reference`의 기단 span이 원본에서 독립 재계산한 `alpha >= 128` canonical 연속 run과 일치
- 별도 footprint front가 `alpha >= 128`, 21px 세로 지지, 9x9 국소 지지율 40% 이상을 만족하고 강한 알파 최하단에서 20px 이내
- 파생 polygon의 절대 x 범위가 기단 span에서 2px 이내, 강한 알파 bbox 폭 대비 `0.89..1.00`, 전 꼭짓점이 1254² 내부
- 이전 slope-only centered polygon 7종이 새 아트 정합 게이트에서 전부 RED가 되는 역검증 유지
- 건물 평행선 family 각도 span `2.6도 이하`, 기단 상면 노출 비율 `0.040043..0.054176`, 실루엣 종횡비 `0.688993..0.932167`
- base 단독에서 기능과 실루엣이 읽힘
- sign/window 레이어 단독에서 불필요한 지붕·벽 누출 없음
- 밝은/어두운 QA 배경에서 검은 테, 자홍색 잔류, 사각 modulate 없음
- 크로마 정본 게이트는 `alpha < 16` 외부 영역을 캔버스 가장자리에서 flood-fill한 뒤 4px 팽창하고, 그 밴드에 닿은 visible near-magenta 8-connected component 전체가 0인지 검사한다. `exact_ff00ff_pixels`와 전체 near-magenta 수는 진단값일 뿐 실패 조건이 아니다.
- 가챠 분홍 lit preview에는 source-chroma 게이트를 적용하지 않는다.
- **R1 브리지 게이트:** 실제 2020 x 1246 Vulkan 캡처에서 약 598px 높이로 확대되는 은행의 기와선, 간판/창 마스크 경계와 실루엣 선명도를 확인한다. 512² 원본의 약 1.17x 확대가 허용 가능한지 시각 승인하기 전에는 R1 렌더 게이트를 완료로 판정하지 않는다.
- **R2 목표 게이트:** 실제 `map_safe_rect.width / 2400` 배율에서 7종 위계와 색 분리를 확인한다. 예시 `left=72`, `right=360` 기준은 `1588/2400`이고 표시 높이는 172~238px, 원거리 절반 배율은 86~119px다. 이 수치는 현재 R1 브리지의 표시 크기가 아니다. 아카데미 source alpha 면적이 은행보다 크더라도 display height 315/360으로 은행이 랜드마크 1위를 유지한다.
- 지붕 위 국소 식별물 추가 여부는 오프라인 축소 보드가 아니라 실제 Godot MIX 경로의 Vulkan 캡처에서만 결정한다.
- 실제 Godot 렌더러의 기본·호버·선택·진입 전환 캡처
- 새 텍스처의 프리웜과 import 설정 확인

### 회귀

- 기존 세이브의 `stage_map_seeds` 재현
- 광장 재입장 시 동일 지도
- 은행, 상점, 선술집, 아카데미, 가챠 등 내부 진입과 복귀
- 인테리어 `760 x 750` 렌더·거래 UI 무변경
- focused smoke, headless load, warning scan, 최종 Vulkan 캡처

## 단계별 착수 순서

1. 이 문서로 좌표·카메라·필지·레이어 계약을 고정한다.
2. 승인 은행 1종을 같은 좌표의 3레이어로 분리하고 정적 합성 QA를 통과시킨다.
3. 은행 1종만 새 지도 톤 지면 위에 올려 앙각·광원·명패·입구 여백을 재검한다.
4. 통과 후 나머지 6종을 동일 계약으로 제작한다.
5. **완료:** R0로 512² 런타임 자산 21장, 비활성 매니페스트/로더, 소유 CanvasItem 렌더러와 위임 프리웜을 준비하고 독립 QA를 통과시킨다.
6. **완료:** R1에서 불투명 fill 이동과 월드 호스트 부착을 원자적으로 적용하고, fail-closed 수명·z-order·발광색·미니맵·프리웜을 활성 경로에 연결했다. 레거시 `1900 x 750`에서 `2400 x 1500`으로의 `MAP_SIZE` 승격과 업데이트 경계의 1회성 보존-시드 좌표 이동도 의도된 호환 변경으로 승인했다.
7. **candidate-only 완료:** 결정적 도로·필지·장식 생성기, full-map 투영, 2D navigation/minimap/Y-sort 호스트는 focused·반증·2020 x 1246 Vulkan 게이트가 GREEN이다. 프로덕션 경로는 계속 R1 브리지다.
8. 최종 지면·도로 아트를 승인하고, 기존 R1 활성 경로를 원자적으로 교체한 뒤 극단 시드·비율·입력·인테리어 회귀와 실제 프로덕션 Vulkan 캡처를 완료한다.

은행 3레이어 게이트 또는 수정된 지면 앙각 게이트가 실패하면 3단계에서 멈추며, 나머지 6종을 선제 제작하지 않는다.
