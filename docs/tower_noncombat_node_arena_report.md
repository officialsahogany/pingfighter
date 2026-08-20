# 비전투 노드 고유 배경 실행 보고 (진행 중, 2026-08-20)

## 1. 작업 기준과 범위

- 기준 HEAD: `40375e15aeb4515e1f3d60655817fdd58dd106e3`
- S4 착수 전 사용자 지정 최신 기준 `a9522108aa5e9adba871252192ce2f031ff14c15`로
  S1~S3 로컬 커밋 3개를 충돌 없이 리베이스했다.
- 격리 워크트리: `D:\main\bosspong_mugong_icon_wiring`
- 작업 브랜치: `codex/tower-noncombat-node-arena-40375`
- 기존의 따뜻한 워크트리를 재사용했으며 새 워크트리를 만들지 않았다.
- 범위는 비전투 노드 배경뿐이다. NPC 작화는 만들거나 배선하지 않는다.
- 로컬 슬라이스 커밋만 남기며 통합·푸시는 하지 않는다.
- 검증 전 로그 백업:
  `D:\codex_backups\tower_noncombat_node_arena_20260820_140401`
  (`user_logs` 5파일 / 14,637,879바이트, 저장소 `godot/logs` 0파일,
  저장소 루트 `logs` 아래 빈 로그 파일 30개)

## 2. S1 배경 소유 경로 조사

### 결론

노드 모달과 모달을 닫은 뒤의 경로 서브 화면은 서로 다른 배경 소유자를 쓴다.
R4 S2가 추가한 노드별 절차 배경은 `NODE_MODAL`에만 그려지는 마지막
스크린 공간 표면이다. 모달을 닫으면 흐름은 `ROUTE_AIM`으로 바뀌고 그 표면은
제외된다. 그 아래에서 계속 그려지던 `current_stage == 1` 필러 배경이 다시
드러나므로 달지 배경을 벗어나지 못한다.

### 생산 경로 표

| 상태 / 표면 | 현재 배경 소유 경로 | 파일:줄 근거 | S2~S4 작업 귀결 |
|---|---|---|---|
| 공통 전투·경로 서브의 기반 배경 | `BattleSceneDrawer`가 필러 패스를 먼저 그린다 → `BattleScenePillarDrawPass`가 `current_stage`로 스테이지 드로어와 상태를 고른다 → Stage 1 드로어가 `stage1_pillar_background.draw()`를 호출한다. | `godot/scripts/core/battle_scene_drawer.gd:38-48`, `godot/scripts/core/battle_scene_pillar_draw_pass.gd:24-38`, `godot/scripts/core/battle_draw_pillar_context.gd:28,41-43`, `godot/scripts/stages/stage1/stage1_pillar_scene_drawer.gd:69-79`, `godot/scripts/stages/stage1/stage1_pillar_background.gd:126-150` | 전투 스테이지 owner는 건드리지 않는다. 비전투 노드 배경은 이 기반 배경 위, 공·패들 아래에 들어가는 별도 레이어여야 한다. |
| 노드 모달 표시 중 | 마지막 스크린 공간 패스가 `NODE_MODAL`을 선택하고, `TowerAscentFlowRenderer`가 `node_kind`별 절차 배경을 전체 뷰포트에 그린 뒤 업무 패널을 그린다. | `godot/scripts/core/battle_scene_drawer.gd:59-66,289-330`, `godot/scripts/tower_ascent/tower_ascent_screen_space_surface_policy.gd:3-11`, `godot/scripts/tower_ascent/tower_ascent_flow_renderer.gd:146-182,1245-1305` | R4 S2의 소유 범위다. 신규 비트맵의 경로 리터럴을 이 렌더러에 다시 흩뿌리지 않고 S2 단일 해석자를 함께 사용한다. |
| 모달 종료 뒤 경로 서브 (`ROUTE_AIM`) | `_enter_route_aim()`이 모달을 닫고 `PHASE_ROUTE_AIM`으로 전환한다. 정책상 `ROUTE_AIM`은 스크린 공간 표면이 아니어서 R4의 노드 배경이 사라지고 Stage 1 필러 배경이 노출된다. | `godot/scripts/tower_ascent/tower_ascent_flow_map_progress.gd:423-439`, `godot/scripts/tower_ascent/tower_ascent_screen_space_surface_policy.gd:3-11,27-31`, `godot/scripts/core/battle_scene_drawer.gd:310-321` | 현재 노드 `kind`를 유지하는 배경 상태를 flow가 노출하고, 기반 필러와 플레이필드 액터 사이에서 그 배경을 계속 그리도록 S4에서 배선한다. |
| 다음 노드 도착 | 전환 완료 시 `_current_node_id`가 선택 노드로 승격되고, 비전투면 `NODE_MODAL`, 전투면 encounter를 해석해 전투 전환 콜백으로 나간다. | `godot/scripts/tower_ascent/tower_ascent_flow_ending_progress.gd:347-380` | 비전투 도착 확정 시 S2 해석자를 프리웜한다. 전투 encounter 인계 시 비전투 배경 상태를 해제해 새 스테이지 배경이 정상 복귀하게 한다. |

### R4 S2와 이번 목표의 경계

R4 보고서의 S2 커밋 `604e509e1`은 NODE_MODAL을 필러·레터박스까지 덮는
불투명 스크린 공간 표면으로 승격하고 노드별 **절차** 배경을 그렸다. 별도
노드 씬이나 비트맵은 추가하지 않았다. 이번 목표는 그 모달을 닫은 뒤에도
같은 장소 배경을 경로 서브 화면에 남기되 공·패들 등 플레이필드 요소는 위에
보이게 하고, 전투 노드로 나갈 때는 스테이지 배경으로 복귀시키는 더 넓은
수명 계약이다.

### 다음 슬라이스 작업 목록

1. S2: 노드 `kind` → 후보 자산 경로를 해석하는 단일 owner를 추가한다.
   런타임 `load`와 존재 검사를 쓰고 성공·미스를 모두 캐시하며, 누락 시 현행
   스테이지 배경으로 폴백한다. 전환 프레임 전 프리웜 API와 측정 지점을 둔다.
2. S3: 상점·수련장·파계승·수호의 샘터 4종 후보를 생성한다. 휴식 노드는
   기존 모닥불 아이콘과 일치하는 야영지 해석을 유지하되, 이번 4종 생성
   범위에는 넣지 않는다. 후보는 승인 전 런타임 경로로 승격하지 않는다.
3. S4: 현재 비전투 노드 배경을 필러 기반 배경 위, 공·패들 아래에 그리고
   `ROUTE_AIM`까지 유지한다. 전투 encounter 인계 시 즉시 해제한다.
4. S5: kind별 서로 다른 해석, 누락 폴백, 모달 종료 뒤 유지, 전투 복귀를
   각각 독립 단언하고 실창 캡처와 라이브 1판으로 닫는다.

## 3. S2 노드별 배경 계약

### 단일 해석 소유자

`godot/scripts/tower_ascent/tower_noncombat_node_background_catalog.gd`를
노드 `kind` 배경의 단일 owner로 추가했다. 비트맵 리터럴은 이 파일에만 있고
렌더러에는 없다. 자산은 `const preload`하지 않으며 명시적 프리웜에서만
`ResourceLoader.exists(path, "Texture2D")` 뒤 `ResourceLoader.load()`한다.
성공과 미스 모두 kind별로 캐시되므로 draw 쪽 `get_cached_resolution()`은
파일시스템을 보지 않는다.

| kind | S2 해석 경로 / 정체성 | 승인 전 결과 |
|---|---|---|
| `shop` | `res://assets/sprites/tower/noncombat/shop_arena_background_imagegen_v1.png` | 자산 없음 → 현행 스테이지 배경 폴백 |
| `training` | `res://assets/sprites/tower/noncombat/training_arena_background_imagegen_v1.png` | 자산 없음 → 현행 스테이지 배경 폴백 |
| `fallen_monk` | `res://assets/sprites/tower/noncombat/fallen_monk_arena_background_imagegen_v1.png` | 자산 없음 → 현행 스테이지 배경 폴백 |
| `guardian_spring` | `res://assets/sprites/tower/noncombat/guardian_spring_arena_background_imagegen_v1.png` | 자산 없음 → 현행 스테이지 배경 폴백 |
| `rest` | `procedural://tower/noncombat/rest_camp` | R4의 모닥불 야영지 절차 배경 유지 |

휴식 노드는 기존 모닥불 아이콘과 R4 절차 배경이 이미 같은 장소 어휘를
제공하므로 다섯 번째 비트맵을 발명하지 않았다. 이는 S3의 **정확히 4종**
생성 계약을 지키면서도 `rest`가 다른 kind와 서로 다른 배경 정체성을 갖게 한다.

### 프리웜과 폴백

- 경로 선택이 확정되는 `_resolve_route_target()`에서 선택한 비전투 kind를
  프리웜한 뒤에만 `PHASE_MAP_TRANSITION`으로 전환한다.
- `MAP_TRANSITION` 또는 `NODE_MODAL` 스냅샷 복원도 선택/현재 노드 kind를
  먼저 다시 프리웜한다.
- S2는 승인 전 아트 0장이다. 4개 예약 경로는 모두 실제로 없으며 네 경로가
  각각 현행 스테이지 배경 폴백을 반환하는 부정 레그를 실행했다.
- 첫 미스 프리웜 측정값은 반복 실행에서 최대 **57µs**였다. 같은 kind의 두
  번째 호출은 `cache_hit=true`, `cold_prewarm_usec=0`이고 파일시스템 probe는
  경로당 정확히 1회였다.

### S2 검증

| 게이트 | 결과 |
|---|---|
| 신규 계약 + 기존 탑 회귀 2종 | `PASS=3 FAIL=0 TOTAL=3`, `All Godot smoke tests passed.` |
| 수정 GDScript 경고 검사 | `scanning 5 scripts`, `checked 5/5`, 경고 0 |
| 헤드리스 로드 | `[ApplicationQuitCoordinator] graceful headless shutdown complete`, `Godot headless load check passed.` |
| 하네스 검증 | `interactive-play validation guard verification: ok`, `agent harness verification: ok` |
| `git diff --check` | exit 0 |

재사용 워크트리의 기존 import 캐시에는 탑 게이지/아이콘 `.ctex` 일부가 빠져
첫 씰과 첫 3종 회귀 실행이 각각 의존 리소스 RED였다. 본 트리와 원본 PNG
SHA-256이 같은 항목만 확인한 뒤 본 트리 캐시에서 누락 출력 29개를 복사했고,
복사 전후 캐시 SHA-256을 일치 확인했다. 본 트리 임포터나 두 번째 `--import`는
실행하지 않았으며 최종 재실행은 위 표처럼 GREEN이다.

## 4. S3 승인 배경 승격

### 생성 방식과 포맷

- 생성기: Codex 내장 `imagegen` (`stylized-concept`), 후보마다 독립 1회 생성
- 구도 참고: `stage3_landing_zoom_background_imagegen_v1.png`
  (중앙이 비고 테두리에 정보가 모이는 1:1 아레나 구도만 참고)
- 마감·원근 참고: `stage4_landing_zoom_background_imagegen_v1.png`
- 색상·소재 참고: 각 노드의 기존 256x256 맵 아이콘
- 기존 랜딩 배경과 동일하게 모든 승인본은 **1254x1254, RGB 불투명 PNG,
  1x1 단일 이미지**다.
- 2026-08-20 사용자 승인 뒤 원본 픽셀을 바꾸지 않고 S2 예약 경로인
  `godot/assets/sprites/tower/noncombat/`로 승격했다.

| kind | 런타임 파일명 | 크기 | 격자 | 주조색 / 장소 해석 | 바이트 | SHA-256 |
|---|---|---:|---:|---|---:|---|
| `shop` | `shop_arena_background_imagegen_v1.png` | 1254x1254 | 1x1 | 금·황동 / 비어 있는 산중 상점·보물고 뜰 | 2,658,906 | `cc3b6ea8791d1b111ebcf92018b955eb344d56e4f920c9e8f60cde3d88e1c71e` |
| `training` | `training_arena_background_imagegen_v1.png` | 1254x1254 | 1x1 | 주사·목재 / 비어 있는 산중 수련장 | 2,886,028 | `13e401ebfff6e48fc0958e6a769cc93a492158ce3b94d049177097defb2921c9` |
| `fallen_monk` | `fallen_monk_arena_background_imagegen_v1.png` | 1254x1254 | 1x1 | 먹·탁한 자색 / 버려진 산중 암자 뜰 | 2,881,093 | `0930ae348ccd4a6693919b2047c2cd1a2d45da506e6505227de77356fe8dd9e3` |
| `guardian_spring` | `guardian_spring_arena_background_imagegen_v1.png` | 1254x1254 | 1x1 | 옥·담청 / 숨은 수호 샘터 뜰 | 3,173,311 | `17d42d5275792b3136ff9480f3c5860f9e417e5a9fc05db6af5621c9e8b759dd` |

### 에디터 소유 import

본 트리 에디터가 열린 상태를 보존하고 본 트리 `.godot`에는 접근하지 않았다.
격리 워크트리 전용 GUI 에디터를 BelowNormal 우선순위로 기동했으며
`--headless`와 `--import`는 사용하지 않았다. 네 `.png.import`와 그 안에
기록된 네 `.godot/imported/*.ctex`가 모두 생길 때까지 폴링한 뒤 진행했다.
사이드카는 Stage 3/4 랜딩 배경과 같은 Lossless(`compress/mode=0`), mipmap
없음 설정이다. 격리 에디터의 전체 스캔이 만든 범위 밖 미추적 `.uid`/`.import`
151개는 대상 8파일을 제외하고 정리했다.

### S3 검증

| 게이트 | 결과 |
|---|---|
| 승인 텍스처 실로드 + 누락 폴백/음수 캐시 | 4종 모두 1254x1254 `Texture2D`, 주입한 미스는 `missing_asset`과 현행 스테이지 배경 폴백, 반복 미스 probe 1회 |
| 첫 프리웜 측정 | 반복 실행 관측 최댓값 **45,365µs**, 캐시 적중은 0µs |
| 신규 계약 + 기존 탑 회귀 2종 | `PASS=3 FAIL=0 TOTAL=3`, `All Godot smoke tests passed.` |
| 수정 GDScript 경고 검사 | `scanning 2 scripts`, `checked 2/2`, 경고 0 |
| 헤드리스 로드 | `[ApplicationQuitCoordinator] graceful headless shutdown complete`, `Godot headless load check passed.` |
| 하네스 검증 | `interactive-play validation guard verification: ok`, `agent harness verification: ok` |

### 최종 생성 프롬프트 계약

네 프롬프트는 공통으로 `stylized-concept`, 정사각형 불투명 2D 게임 환경
배경, 중앙 약 55%의 저대비 빈 전투 공간, 정보와 밝은 강조는 가장자리,
한지 위 먹선과 절제된 광물 안료·옻칠·황동·옥·주사 재질을 지정했다.
인물·NPC·캐릭터·생물·보스·공·패들·문자·숫자·표지판·워터마크·UI 테두리와
사이버펑크·네온·홀로그램·회로·SF·현대 전자기기는 전부 금지했다. Stage 3
참고 이미지는 구도만 사용하고 그 이미지의 사슬·하트·스크린·네온은 복제하지
않도록 명시했다. 아이콘은 팔레트와 소재 어휘에만 쓰며 중앙 대형 문양으로
복제하지 않도록 했다.

노드별 최종 장면 지시는 다음과 같다.

- `shop`: 검은 옻칠 목재, 접은 비단, 황동 장식, 등롱, 동전 쟁반, 상자와
  처마를 외곽에 둔 무인 산중 상점·보물고 뜰.
- `training`: 글자 없는 주사색 천, 목제 거치대·연습목·항아리·돌계단·처마를
  외곽에 둔 무인 산중 도장. 중앙에는 무기나 연습목을 두지 않는다.
- `fallen_monk`: 자색 황혼의 폐암자, 깨진 기와·낮은 담·꺼진 석등·향로·
  비문 없는 찢어진 자색 천을 외곽에 둔다. 유혈·공포가 아닌 장중한 비애다.
- `guardian_spring`: 옥빛 석조 수로·샘·이끼·노송·연잎·제기 장식을 외곽에
  두고 중앙은 얕은 물광만 있는 평평한 옥석 뜰로 비운다.

네 후보 모두 육안으로 인물/NPC가 없고 중앙 오버레이 공간이 비어 있으며,
문자·워터마크·네온/SF 요소가 없음을 확인했다. NPC 작화는 생성하거나
배선하지 않았다.

### 승인 결과

사용자가 네 후보 모두 중앙 여백, 아이콘과 1:1인 금·주사·자주·비취 색,
인물·문자·네온 부재, 스테이지 랜딩 배경 어법을 확인하고 승인했다. 승인본
4개만 승격했으며 NPC 작화는 생성하거나 배선하지 않았다.

## 5. S4 모달 종료 뒤 유지와 전투 복귀

### 상태 수명 계약

`tower_ascent_flow_state.gd`가 모달 종류와 별도로
`retained_noncombat_background_kind`를 소유한다.

1. 비전투 노드 도착 시 해당 kind를 retained 상태로 설정한다.
2. 업무 모달을 닫아 `ROUTE_AIM`으로 갈 때는 해제하지 않는다.
3. 다음 목적지가 비전투면 현재 장소를 출발 전환까지 유지하고 새 자산을
   프리웜한다.
4. 다음 목적지가 전투면 `_resolve_route_target()`이
   `PHASE_MAP_TRANSITION`을 설정하기 전에 retained 상태를 해제한다.
5. 전투 인계 `_finish_vertical_slice()`와 전체 reset도 다시 해제한다.
6. 스냅샷에는 additive 필드로 보존하며 NODE_MODAL/MAP_TRANSITION 복원 시
   그래프의 실제 kind와 대조하고 필요한 자산을 다시 프리웜한다.

따라서 모달 종료는 배경 수명의 종료점이 아니며, 전투 목적지 선택이 명시적인
종료점이다. 렌더러가 phase 이름이나 기본 `guardian_spring` 값을 보고 장소를
추측하지 않는다.

### 렌더 순서와 폴백

- `NODE_MODAL`은 기존 불투명 스크린 공간 표면에서 동일한 캐시 모델을 먼저
  그리고 업무 패널을 그린다.
- `ROUTE_AIM`은 `BattleSceneDrawer`의 스테이지 필러 장면 뒤, 맵 힌트와
  변환된 플레이필드 앞에서 retained 배경을 그린다. 따라서 배경은 달지 장면을
  덮지만 공·패들·경로 조작 UI는 그 위에 남는다.
- 1254x1254 승인 픽셀을 다시 가공하지 않고 Stage landing과 같은 center-cover
  crop으로 현재 viewport에 투영한다.
- bitmap 해석이 미스이거나 텍스처가 없으면 배경 모델은 빈 값이다. 별도
  절차 배경을 덧칠하지 않으므로 아래의 현행 스테이지 배경이 그대로 폴백된다.
- 렌더러와 `BattleSceneDrawer`에는 네 자산 경로 리터럴이 없다.

### 휴식 노드 판단

휴식 노드는 새 후보가 필요하지 않다고 판단했다. 기존 R4의 절차식 모닥불
야영지는 맵의 모닥불 아이콘과 장소 의미가 일치하고, 네 승인 bitmap과 다른
고유 정체성을 이미 가지며, 파일 로드 없이 즉시 준비된다. S4는 그 동일한
절차 모델을 NODE_MODAL과 모달 종료 뒤 ROUTE_AIM 양쪽에서 재사용한다. 다섯
번째 bitmap을 추가하지 않아 지시된 정확히 4종 생성 범위와 GRT-003도 지킨다.

### S4 검증

| 게이트 | 결과 |
|---|---|
| 핵심 생산 전이 | 수호의 샘터 `NODE_MODAL` → 모달 종료 `ROUTE_AIM`에서 동일 bitmap 모델 유지 → 전투 목적지 선택 전 첫 MAP_TRANSITION 프레임보다 먼저 해제 → 전투 인계 후 빈 상태 |
| 스냅샷 | retained `guardian_spring` 저장·복원과 2020x1246 cover 모델 실생성 |
| S1 폴백 부정 레그 | `missing_asset` 해석은 빈 교체 모델을 반환해 stage owner를 노출 |
| 신규 씰 + 줌/모달/5종 노드/보스 회귀 | `PASS=13 FAIL=0 TOTAL=13`, `All Godot smoke tests passed.` |
| 수정 GDScript 경고 검사 | `scanning 8 scripts`, `checked 8/8`, 경고 0 |
| 헤드리스 로드 | `[ApplicationQuitCoordinator] graceful headless shutdown complete`, `Godot headless load check passed.` |
| 하네스 검증 | `interactive-play validation guard verification: ok`, `agent harness verification: ok` |

S4 요청 범위에서는 S5의 Vulkan 2020x1246 4종 캡처와 라이브 1판을 실행하지
않았다. 이는 다음 검증 슬라이스로 남는다.

## 6. 진행 상태

| 슬라이스 | 상태 | 비고 |
|---|---|---|
| S1 배경 소유 경로 조사 | 완료 | 위 생산 경로 표로 소유 경계와 결함 원인을 특정했다. |
| S2 노드별 배경 계약 | 완료 | 단일 owner, 성공·미스 캐시, 프리웜, 승인 전 폴백을 씰했다. |
| S3 배경 생성 | 승인·승격 완료 | 4종 PNG와 editor-owned `.import`를 예약 런타임 경로에 배치했다. |
| S4 배선과 전환 | 완료 | 모달 종료 뒤 유지와 전투 선택 즉시 복귀를 생산 전이로 씰했다. |
| S5 씰과 캡처 | 대기 | Vulkan 4종/전투 복귀 캡처와 파계승 라이브 1판은 아직 실행하지 않았다. |
