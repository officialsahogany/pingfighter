# 탑 라이브 4런 피드백 완료 보고 (2026-08-19)

## 1. 판정

- **최종 판정: GREEN**
- `docs/tower_live_feedback_r4_goal.md`의 S0부터 S5까지를 고정 순서로 구현하고
  슬라이스별 독립 로컬 커밋 6개로 남겼다.
- 필수 게이트의 `blocked` / `unverified`는 **0건**이다.
- 기준 `23cf0bea2`에서 격리 워크트리
  `D:\main\bosspong_tower_live_feedback_r4_23cf`를 사용했다. 본 트리의 사용자
  미커밋 WIP에는 `stash`·`checkout`·`reset`·통짜 `git add`를 사용하지 않았다.
- 검증은 열린 사용자 Godot 에디터와 병행했다. 표준 래퍼는
  `-AllowDuringPlay`를 선언하고 자식 프로세스를 `BelowNormal`로 시작했으며,
  사용자 프로세스를 종료하지 않았다.
- 로컬 커밋만 남겼고 푸시하지 않았다.

## 2. 로그와 WIP 백업

- 작업 전 백업:
  `D:\codex_backups\tower_live_feedback_r4_20260819_072913`
  - Godot `user://logs`: 5파일 / 125,359,449바이트
  - `godot/logs`: 15파일 / 15,436바이트
  - 저장소 루트 `logs`: 400파일 / 816,722바이트
  - 전체 백업: 425파일 / 126,341,885바이트
- 겹침 WIP 패치:
  `preexisting_overlap.patch`, SHA-256
  `E652804CE9F4358E2075928AAF31933E2B238FB0D118B4CDA77AA63A3AAEE857`
- 신화 획득 연출 WIP 패치:
  `mythic_cinematic_wip.patch`, SHA-256
  `C56977401C94DD61D0C458A71FDA7646631E0D2D9A83D43FE67B08F8F7FAAA67`
- 백업 매니페스트 SHA-256:
  `CC8D33AEE84DE6A2980B2011CBD94D8F9535C445CBBFA2F7DBF7AC6A76FB91BC`

## 3. 슬라이스와 커밋

| 슬라이스 | 커밋 | 구현 결과 |
|---|---|---|
| S0 절세무공 획득 연출 | `830d49bb9` | 보상 픽이 외부 신화 획득 시네마틱을 감지해 입력을 중앙 모달 라우터로 넘긴다. REVEAL은 0.5초 뒤에만 7언어 안내를 표시하고 클릭 전에는 자동 진행하지 않는다. 액티브 쿨다운 pause/resume과 루프 오디오 정리는 모달 진입·이탈마다 정확히 한 번만 실행된다. |
| S1 경로 서브·보상 종료 | `88f801cb8` | ROUTE_AIM 진입 후 0.35초 동안 입력 edge를 폐기하되 플레이어 이동과 조준 진자는 계속 돈다. 진입마다 조준 위상을 리셋하지 않는다. 보상 픽은 미구매 카드 중 현재 무혼으로 살 수 있는 카드가 0장이면 흡수 종료와 빈 보드 0.60초 뒤 1프레임 지연으로 한 번만 종료한다. 계속하기 버튼은 유지한다. |
| S2 스크린 공간 표면 | `604e509e1` | 보상 픽과 NODE_MODAL을 실제 뷰포트 스크린 공간으로 승격하고 입력·그리기·rect 좌표계를 일치시켰다. NODE_MODAL은 필러와 레터박스까지 덮는 불투명 표면, 노드 종류별 절차 배경, 기존 업무 패널 순서로 그린다. 별도 노드 씬이나 신규 비트맵은 추가하지 않았다. |
| S3 보상 픽 문맥 | `447682a8e` | 기존 퍽 화면과 같은 무공 슬롯 원장·능력치 띠·현판·파티클을 보상 픽에 연결했다. 마우스 호버가 선택을 갱신하고, 퍽 모달을 한 번도 열지 않은 전투에서도 생산 owner/registry 능력치 문맥을 캡처한다. 구매 뒤 슬롯·체질 수련·능력치 캐시가 즉시 무효화된다. |
| S4 지도 이동 연출 | `bc59f72b3` | 2020×1246에서 지도 내용이 비례 확대되도록 절대 상한과 드로우 핫패스 딥카피를 제거했다. 전투 암전, 지도 등장, smoothstep 이동, 도착 소멸, 지도 암전, 비전투 노드 등장 6구간을 단일 결정론 시계로 구현했다. M 지도 개폐 페이드와 진행값 0/0.5/1 QA 주입 경로도 추가했다. |
| S5 각도 게이지 아트 | `8289d011c` | 내장 ImageGen으로 생성한 부채꼴·화살표를 결정론적 후처리 도구와 함께 배선했다. 정규화 UV 회전 쿼드와 MIX 호환 발광을 사용하고, 텍스처가 없을 때만 기존 절차 게이지가 폴백한다. |

## 4. 구현 계약 세부 확인

### 입력과 모달

- S0 반전 대조군에서 시네마틱 활성 시 입력은 시네마틱 1회, 보상 픽 0회이며,
  시네마틱 비활성 시 보상 픽이 입력을 받는다.
- REVEAL 무장 전에는 안내가 없고, 무장 뒤에는 `클릭해 계속`이 나타난다.
  5초를 더 진행해도 클릭 없이는 REVEAL에 남는다. 실제 공개 입력 진입점의
  클릭 뒤 `absorb → impact → complete`를 확인했다.
- S1 arm 구간은 첫 프레임 눌림과 지속 hold를 모두 버린다. 릴리스 뒤 새
  클릭만 정확히 한 번 발사한다. arm 중 좌우 이동과 조준각 변화는 유지된다.
- 최신 사용자 프레임 리팩터를 물질화한 통합 검증에서는
  `battle_modal_pause_runtime_state`의 오디오 stop 래치를 이탈 시 해제하고,
  `battle_scene_input_controller`의 스크린 공간 표면 정책과
  `request_battle_redraw()` 경로를 함께 보존했다. 이 상태에서 지정 회귀
  16/16이 GREEN이다.

### 표면과 지도

- NODE_MODAL과 보상 픽은 `canvas.get_viewport_rect().size`를 우선 사용한다.
  플레이필드 좌표 변환은 게임 공간 페이즈에만 적용하며, 마우스 이동·클릭·
  터치가 각자의 표면 rect와 같은 좌표계를 읽는다.
- 2020×1246 지도에서 전 노드 동시 가시성을 보존한 채 레인 폭·아이콘·상하
  인셋이 뷰포트에 비례한다. 현재 노드 승격은 이동 시작이 아니라 도착 완료
  시점에 일어난다.
- 이동체는 이미 프리웜된 선택 캐릭터 워킹 시트를 재사용한다. 좌우 방향은
  [0,1] 정규화 UV로 미러링하고 신규 SD 시트는 만들지 않았다.

## 5. TEMP 튜닝 표

| 상수 | 값 |
|---|---:|
| `TEMP_ROUTE_AIM_ENTRY_ARM_SECONDS` | `0.35` |
| `TEMP_REWARD_PICK_EMPTY_BOARD_HOLD_SEC` | `0.60` |
| `TEMP_REWARD_PICK_PANEL_GAP_PX` | `32.0` |
| `TEMP_MAP_TRANSITION_BATTLE_FADE_OUT_SEC` | `0.25` |
| `TEMP_MAP_TRANSITION_MAP_FADE_IN_SEC` | `0.25` |
| `TEMP_MAP_TRANSITION_TRAVEL_SEC` | `1.60` |
| `TEMP_MAP_TRANSITION_ARRIVE_VANISH_SEC` | `0.35` |
| `TEMP_MAP_TRANSITION_MAP_FADE_OUT_SEC` | `0.28` |
| `TEMP_NODE_MODAL_FADE_IN_SEC` | `0.25` |
| `TEMP_MAP_OVERLAY_FADE_SEC` | `0.18` |
| `TEMP_MAP_OUTER_MARGIN_RATIO` | `0.024` |
| `TEMP_MAP_SIDE_GUTTER_RATIO` | `0.130` |
| `TEMP_MAP_LANE_SPAN_RATIO` | `0.290` |
| `TEMP_MAP_ART_SIZE_RATIO` | `0.720` |
| `TEMP_MAP_CONTENT_TOP_RATIO` | `0.1025` |
| `TEMP_MAP_CONTENT_BOTTOM_RATIO` | `0.1925` |
| `TEMP_ROUTE_AIM_GAUGE_PIVOT_RATIO` | `(0.5, 0.875)` |
| `TEMP_ROUTE_AIM_GAUGE_TEXTURE_RADIUS_PX` | `88.0` |
| `TEMP_ROUTE_AIM_ARROW_ORBIT_RATIO` | `0.72` |

신규 수치는 감사 정본의 표를 그대로 사용했다. 목록 밖 수치 발명은 없다.

## 6. ImageGen 아트와 재현성

- 사용 도구: 내장 ImageGen. 사용자 지시에 따라 별도 승인 대기 없이 사용했다.
- 부채꼴 생성 지시의 핵심은 투명 배경, 어두운 전투 위 가독성, 금빛·진사
  한국 판타지 나침반 문양, 글자·사각 프레임 없음, 하단 중앙 피벗이었다.
- 화살표 생성 지시의 핵심은 투명 배경, 중앙 피벗, 가늘고 선명한 금빛·진사
  방향 침, 글자·외곽 프레임 없음이었다.
- 원본은 추적 제외 경로에 보존했다.
  - `images/ui/hud/route_aim_gauge_fan_imagegen_v1_source.png`, SHA-256
    `64F032465C1A73A1F363CD452B2F6E4FA49B9F271363D71459BB8A5697C0285B`
  - `images/ui/hud/route_aim_gauge_arrow_imagegen_v1_source.png`, SHA-256
    `8F1E96FF55AC622D699C95361D6DE968B28E9BC1639037BE41D40BDB86B6C829`
- 재현 도구:
  `godot/tools/prepare_tower_route_aim_gauge_art.py`
  - 256×192 부채꼴의 목표 피벗 `(128,168)`과 128×128 화살표 중심 `(64,64)`을
    결정론적으로 맞춘다.
  - 화살표 MIX 발광은 반경 3.0, 알파 0.10으로 오프라인 합성한다.
  - 별도 출력 디렉터리에서 재실행한 결과 최종 두 파일의 SHA-256이 모두
    커밋 파일과 일치했다.
- 최종 런타임 파일:
  - `route_aim_gauge_fan_imagegen_v1.png`: RGBA 256×192, SHA-256
    `BF3D0B2FB95A1F979AD1ADCF5C4C42E7707FAA65FD953D50F28A029F865F97D2`
  - `route_aim_gauge_arrow_imagegen_v1.png`: RGBA 128×128, SHA-256
    `641C7EE222AE9CE9868129083ECF69EBB0F8F455C9034D1480DA9A6C9A30DA26`
- 두 임포트 모두 `compress/mode=0`, `vram_texture=false`, mipmap 없음,
  `fix_alpha_border=true`, `size_limit=0`이다.

## 7. 렌더 증거

| 캡처 | 판정 | 크기 | SHA-256 |
|---|---|---:|---|
| `.tmp/mythic_perk_acquisition_cinematic/mythic_perk_reveal_prearm.png` | GREEN. 무장 전 설명은 보이지만 계속 안내는 없다. | 760×750 | `CB3883DB10C659C4F39213E5E32F9C5B9CF48C4C06959562637CE19C85859C82` |
| `.tmp/mythic_perk_acquisition_cinematic/mythic_perk_reveal_armed.png` | GREEN. 같은 REVEAL에 `클릭해 계속`이 추가된다. | 760×750 | `AC679C5E843D66B7D2470F63D9F84CB89E70D72385EC7AD1E9624C45E27B56F5` |
| `godot/.godot/codex_captures/tower_reward_pick/four_card_reward_pick.png` | GREEN. 전체화면 보상 픽에 4카드·무공 슬롯 원장·능력치 띠·계속하기가 겹침 없이 보인다. | 2020×1246 | `8F2CC37953AD2BE64DFEBE117769AFE645074877498A1E757266DF20B4A7A3A5` |
| `godot/.godot/codex_captures/tower_ascent_phase_c/guardian_spring.png` | GREEN. 노드 절차 배경과 업무 패널이 필러·레터박스까지 덮고 전투 HUD가 남지 않는다. | 2020×1246 | `CA8F812EF515D666CD671E0B8197948743C1CB3CA46F42F131898D0529B6D35B` |
| `godot/.godot/codex_captures/tower_map_overlay/map_overlay_human_realm.png` | GREEN. 전 노드와 현재 위치가 실 뷰포트 비율로 확대되어 동시에 보인다. | 2020×1246 | `1D44EA9983118C8EADD92DE8013D460E51DA30677E7CECC355BC605E39C835B5` |
| `godot/.godot/codex_captures/tower_map_overlay/map_transition_progress_000.png` | GREEN. 전투 표면 암전 시작 구간이다. | 2020×1246 | `356DD6280B2C6D4567A8ADDF441F0356DD43BFBCE7A099CCD7F6FFE97EB2B64A` |
| `godot/.godot/codex_captures/tower_map_overlay/map_transition_progress_050.png` | GREEN. 이동 중간에 워킹 시트 이동체와 선택 간선이 보인다. | 2020×1246 | `3E19C15ED9708594A8791ED7682394630096A1C7A7DD382192A2DBDE1C0A0734` |
| `godot/.godot/codex_captures/tower_map_overlay/map_transition_progress_100.png` | GREEN. 도착 소멸과 다음 표면 인계 직전 상태다. | 2020×1246 | `CBD0B63457E5DE6698850E88BA5A0EC5CE019AA2B7B6020721B7F2B33A818C2B` |
| `godot/.godot/codex_captures/tower_route_serve_owner_meta/route_aim_angle_gauge.png` | GREEN. 어두운 스테이지에서 신규 게이지·캐릭터·표적이 함께 보인다. 강한 금빛 픽셀 342개다. | 3072×1670 | `86A9213E48970ED99D46E14837708251C5F9FE3FCB88155A25EAC1C147B1877A` |
| `godot/.godot/codex_captures/tower_route_serve_owner_meta/route_aim_angle_gauge_bright.png` | GREEN. 밝은 스테이지에서도 신규 게이지가 분리되어 보인다. 강한 금빛 픽셀 340개다. | 3072×1670 | `D7F00DAE0198971219634DF9C19E74CCE3B8DD3DC4E87AAD35B13F760F64E4F0` |
| `godot/.godot/codex_captures/tower_boss_integration/floor_02_molewang_battle_entry.png` | GREEN. 표준 탑 실행기의 실제 라우터가 선택 슬롯을 청린귀 스테이지 2 변형으로 배선했다. | 3072×1670 | `14F791232ED1453FB97590BB11DD8231421C22493575D8ED065E35F564B34E01` |

각 Vulkan 러너는 실제 렌더 종단선과 캡처 수를 확인했다. 게이지 러너는
어두운·밝은 배경 모두 최소 120개보다 강한 금빛 픽셀이 많음을 확인했고,
실제 플레이어 이동·서브·상단 벽 반사도 같은 생산 owner 경로로 통과했다.

## 8. 최종 검증 종단선

| 게이트 | 결과 |
|---|---|
| R4 지정 회귀 16종 | `PASS=16 FAIL=0 TOTAL=16`, `All Godot smoke tests passed.` |
| S0 비헤드리스 Forward+ | `mythic_perk_acquisition_cinematic_smoke: ok`, `SCRIPT ERROR` 0, 로그 SHA-256 `0A87790D936D3BC241EB3C44F6712AC8297431E4815733736003095F58F9529D` |
| 수정 GDScript 경고 검사 | `scanning 38 scripts`, `checked 38/38`, 경고 0 |
| 헤드리스 로드 | `[ApplicationQuitCoordinator] graceful headless shutdown complete`, `Godot headless load check passed.` |
| S5 결정론 재생성 | 부채꼴·화살표 SHA-256 2/2 일치 |
| 표준 탑 실행기 | `run_tower_mode.ps1 -ReplayBossSlot floor_02_molewang`, `tower_ascent_boss_entry_visual_qa: ok`, `Tower mode live replay passed` |
| 플래그 OFF·역레그 | 지정 회귀의 레거시 결과화면, 기존 DASH 기준선, 노드 3종 OFF 경로가 모두 GREEN |
| 최종 `git diff --check` | 커밋 범위와 최신 WIP 호환 병합 경로 모두 exit 0 |

지정 회귀 16종은 다음과 같다.

1. `tower_boss_routing_smoke`
2. `tower_node_modal_pointer_smoke`
3. `tower_ascent_vertical_slice_smoke`
4. `tower_battle_muhon_hud_smoke`
5. `default_dash_token_baseline_smoke`
6. `tower_ascent_route_serve_smoke`
7. `tower_ascent_map_overlay_render_smoke`
8. `tower_reward_pick_smoke`
9. `battle_scene_modal_overlap_input_smoke`
10. `battle_reward_modal_input_router_owner_smoke`
11. `mythic_perk_acquisition_cinematic_smoke`
12. `active_item_cooldown_modal_pause_smoke`
13. `tower_ascent_chest_contract_smoke`
14. `tower_ascent_training_node_smoke`
15. `tower_ascent_fallen_monk_node_smoke`
16. `tower_ascent_guardian_spring_node_smoke`

### 라이브 성능 근거

- 감사에 사용된 실제 탑 런 로그:
  `D:\main\bosspong\godot\.godot\codex_logs\tower_mode_live_33524_20260818144144710.log`
- 크기 4,515,906바이트, SHA-256
  `3177D5E0EC858AD3A1C5C49ED1A5AE86A08B6E68F0243D6C123ED23E47D5155F`.
- 안정 구간의 `physics.frame.gate.tower_ascent_flow`는 예를 들어
  1562행 `avg=380.4us max=531us n=145`, 1568행 `avg=383.3us`,
  1574행 `avg=388.6us`, 1586행 `avg=394.9us`, 1592행 `avg=392.8us`로
  요구된 300µs대다.
- R4 최종 트리에서는 같은 표준 실행기의 자동 보스 재현 경로를 다시 실행해
  실제 전투 진입을 GREEN으로 확인했다. S4는 지도 드로우의 중복 딥카피를
  제거하므로 이 기준선보다 비용을 늘리는 새 핫패스를 추가하지 않는다.

## 9. 검증 중 분리한 환경 문제

- 깨끗한 격리 체크아웃은 현재 본 트리 WIP가 참조하는 비추적 원화와
  `.godot/imported` 캐시를 소유하지 않아 최초 실창 실행에서 리소스 로드 RED가
  발생했다. 로그가 지목한 파일만 본 트리의 같은 상대 경로에서 복사하고
  SHA-256 동치를 확인했다. 소스 코드 수정이나 본 트리 임포터 이중 실행은
  하지 않았다.
- 첫 보스 재현은 같은 캐시 누락 때문에 `ok` 뒤 serious-error 분류가 RED였고,
  정확한 누락 파일만 물질화한 최종 실행은 serious error 0, exit 0으로 GREEN이다.
- 성공한 windowed QA 말미의 `ObjectDB instances leaked at exit`는 이 저장소의
  기존 QA 종료 baseline이며 serious-error 분류 대상이 아니다.
- 이 환경 분리는 최종 구현의 `blocked` 또는 `unverified`가 아니다. 최종 검증은
  현재 사용자 WIP와 같은 물질화 상태에서 수행됐다.

## 10. 상태 분류

- **fixed**: 절세무공 REVEAL 클릭 영구 정지, 모달 중 반복 루프 오디오 stop,
  ROUTE_AIM 진입 클릭 누출, 고정 조준 위상, 구매 가능 카드 0장인데 남는 보상
  픽, 플레이필드에 갇힌 보상·노드 표면, 노드 배경에 남는 전투 HUD, 보상 픽
  슬롯·능력치 문맥 누락, 고해상도 지도 내용 축소, 즉시 이동과 조기 현재 노드
  승격, 절차 게이지의 낮은 시인성
- **deferred**: 호버 예상치 프리뷰, 노드 kind별 전용 비트맵, 지도 이동 전용 SD
  시트, 10·11층 배경 통일, 페이드 오너 범용 승격. 모두 지시문 §4의 명시적
  비범위이며 이번 완료의 미구현 항목이 아니다.
- **blocked**: 0건
- **unverified**: 0건
