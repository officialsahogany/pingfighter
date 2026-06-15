# 광장(플라자) 시스템 Godot 포팅 계획 — 디스크하츠 - 링피아

작성 2026-06-13. 조사 기반: 레거시 `downtown/` 전수 분석 + Godot 씬/에셋 컨벤션 조사 +
스테이지 테마 매트릭스 추출 + 외부 에셋 시장 조사 (5갈래 병렬 + 완전성 비평 패스).
이 문서가 광장 포팅의 단일 소스다. 레거시 Python 경로는 참고 전용.

## 0. 핵심 설계 축 (사용자 확정)

1. **스테이지 클리어 후, 클리어한 스테이지 테마의 광장**으로 입장한다.
   레거시의 generic 행성 테마 5종(`PLANET_THEMES`, `stage % 5` 선택)은 버리고,
   스테이지 1~6 문화 테마를 광장 바닥/건물/분위기에 직결한다.
   → **이것은 패리티 포팅이 아니라 신규 디자인이다.** 레거시에 스테이지→문화 테마
   매핑 테이블은 존재하지 않는다 (`downtown/constants.py:437-479` 확인).
2. **링피아 = 가상현실 세계. 사이버펑크 기조는 모든 테마에서 유지(디제틱).**
   바닥 타일은 "VR이 렌더링한 표면"이고, 타일 이음새의 네온 발광 심·데이터
   글리프·홀로 스캔라인은 가상세계의 기저가 비쳐 보이는 것이다.
   → 이미 리포 컨벤션과 일치: 모든 스테이지 필러 베이스가 `*_layered_cyber_*`
   명명이고 CYBER_CYAN `(0,0.90,1.0)` / CYBER_MAGENTA `(1.0,0.12,0.76)` 상수를 공유.
   광장은 이 franchise 시그니처의 연장선.
3. **2-레이어 아트 디렉션 규칙**: 공통 사이버 베이스(불변 시그니처) + 스테이지
   문화 스킨(가변). 네온은 "절제된 인레이"가 기본 — 스테이지 3(아키하바라)만
   베이스가 전면에 드러나는 기준점.

## 0.5 레이아웃 피벗 — 횡스크롤 광장 (2026-06-13 사용자 확정)

탑다운 세로 스크롤(레거시 패리티 구조)을 버리고 **횡스크롤 사이드뷰 거리**로
전환한다. 레퍼런스 무드: 다층 야시장 거리(플랫폼·사다리·패럴랙스 깊이가 있는
횡스크롤 허브 스크린샷, 2026-06-13 제공).

**v1 스코프 권장**: 단층 메인 스트리트(워크라인 1개) + 패럴랙스 3층.
레퍼런스의 다층 플랫폼/사다리 구조는 v2+ 확장(스코프 폭발 방지).

**뷰/맵 계약 (구 §6 렌더러·걷기·카메라 항을 대체)**
- 캔버스 760x750 유지, **카메라 X 스크롤**(smoothing 0.08, lead_x 100 —
  레거시 파라미터의 축 전환). 초기 S4 셸은 맵 가로 ~3040px였으나, Stage 1
  정리 패스(§0.8) 이후 기본 런타임은 **1900px**(약 2.5스크린)로 축소. 스폰
  좌측, EXIT 우측 끝(귀환 포털).
- 워크라인: 지면 y ≈ 640~700 밴드, 좌우 이동(4px/frame-60, `delta*60` 필수),
  v1 점프 없음. 충돌 = 지면 라인 + 건물 출입 존(파사드 앞 X 구간).
- 인터랙션: 건물 파사드 앞 X 구간 + ↑/Space → 다이얼로그 (사이드뷰 타운 표준).
- 패럴랙스 3층: 원경(스테이지 테마 하늘/달/실루엣 — 필러 백플레이트 재활용
  후보) / 중경(거리 뒷벽·뒷줄 구조물) / 근경(워크라인+건물 파사드+소품).
  레이어는 z 상위 단일 트리 안에서 그리기 순서로 — 음수 z 금지(매몰 트랩).

**기존 산출물 영향 분석**
- **건물 7동 키트: 전부 생존, 적합도 상승.** 3/4 정면 파사드 = 사이드뷰 거리
  문법 그 자체. 엠블럼 푯말·emissive 분리·manifest 그대로 유효. S4 전환 당시
  표시 높이는 320~420px 후보였으나, Stage 1 실플레이 정리(§0.8)에서
  **220~300px**로 재조정(소스가 917~1077px라 재생성 불필요 —
  `display_height`/`display_scale` 필드 조정만).
- **S1 바닥 미니셋: 역할 재정의 (폐기 아님).** 탑다운 전제였으므로:
  ①워크 밴드(완만한 탑다운 기울기의 보도 밴드)에 base_01/02·어도·메달리온
  재활용 — 횡스크롤에서도 보도는 약간 위에서 내려다보는 밴드로 그리는 게 표준,
  ②**신규 에셋 타입 "지면 크로스섹션"**(보도 전면 단면) 추가 — 단면에 VR
  데이터 지층(발광 회로 스트라타)을 노출하면 "가상세계 기저" 컨셉이 문자
  그대로 시각화된다(디제틱 강화 기회). 심리스 요구는 X축만으로 완화.
- **S2(스테이지 2~6 바닥 전개): 런타임 슬롯 개방 / 아트 보류** — 지면
  스트립/단면 문법은 스테이지 1에서 확정. 런타임 로더는 스테이지별
  floor/parallax manifest(`plaza_stageN_*_<asset_slug>_v1_manifest.json`)가
  있으면 해당 텍스처를 사용하고, 없거나 import되지 않은 항목은 S1 확정 에셋으로
  fallback한다. 스테이지 2~6 실제 비트맵 생산은 이 슬롯에 꽂는 후속 아트 패스.
- **§6.1 플로우 계약은 전부 생존**: 결과씬 3버튼·콜백 지연 원칙·프리웜 게이트
  스폰·owner 키 신설 금지·스모크 세트 모두 유효. §6.1의 렌더러/걷기/카메라
  항만 본 절이 대체한다. 트랩 체크리스트도 전부 유효 — 패럴랙스 도입으로
  음수 z 트랩과 draw 순서 검증(스크린샷 픽셀 프로브)의 중요도가 오히려 올라감.

**신규 에셋 필요 목록 (스테이지 1 기준, 생산 = Codex)**
1. 지면 스트립 키트: 보도 밴드(기존 타일 재활용 우선 검토) + 전면 단면(VR
   지층) — X축 심리스.
2. 중경 뒷벽: 한옥 담장/뒷골목 실루엣 밴드 — X축 심리스 또는 모듈 조각.
3. 원경: 스테이지 1 하늘/달/먼 산 실루엣 1장 (필러 백플레이트 재활용 검토 먼저).
4. 소품 산점: 등롱 기둥·평상·홀로 사인 등 알파 컷 2~4종 (선택, v1 후반).

## 0.6 S4.5 미감 패스 — 패럴랙스 레이어 아트 디렉션 브리프 (Claude → Codex)

목표: 현재 절차형 placeholder 4개 레이어(구름/달/중경 벽/지면 단면)를 전용
X축 심리스 에셋으로 교체. **기존 `plaza_scene.gd` draw 밴드 좌표에 그대로 드롭
되도록 스펙을 좌표에 고정한다** — 배선 재작업 최소화. 생산 = Codex, 게이트 =
Claude(픽셀 검증 5컷 재캡처). 진행 순서: ①지면 스트립 ②중경 벽 ③원경 하늘·달.

좌표 기준 (현 `plaza_scene.gd` 상수, GAME_SIZE 760x750):
- 보도 밴드 `SIDEWALK_TOP=596`, `SIDEWALK_HEIGHT=92` → 보도면 y596~688.
- 지면 단면(언더그라운드) `UNDERGROUND_TOP=688` → y688~750 (62px).
- 중경 벽 `wall_y=458` h98, parallax 0.48, tile_width 320.
- 구름 y92(parallax0.16)/y152(0.28), 달 center(645,116) parallax0.04.

### ① 지면 스트립 + VR 데이터 지층 단면 (최우선 — 피벗 핵심)

**단일 X축 심리스 스트립 1장으로 통합 제작** (현 "탑다운 타일 재활용 + 얇은 절차
단면" 조합을 대체). 권장 캔버스: 폭 ~1140px(=FLOOR_REPEAT 380 ×3, X심리스),
높이는 보도면+단면 합산 = **y596~750 풀(154px) 또는 그 2x 소스**.
- 상단 절반(보도면, y596~688): 사이버 조선 박석 — S1 base 팔레트(한지 크림/먹남
  줄눈) 유지, 완만한 탑다운 기울기. **X축만 심리스**(세로 반복 불필요라 S1
  토러스 제약보다 쉬움). 어도/메달리온은 현 spec 좌표(medallion x560/1320/
  2080/2840, accent x250/980/1750/2460)에 얹는 별도 알파 컷 유지 — 스트립에
  굽지 말 것.
- 하단 절반(단면, y688~750+): **VR 데이터 지층 노출** — 박석 아래로 발광 회로
  스트라타(시안 #00E5FF 주, 마젠타 #FF1FC2 1줄), 데이터 글리프 층, 홀로 격자가
  지층처럼 수평으로 쌓인 단면. "문화 스킨 아래 가상세계 기저"를 문자 그대로
  보여주는 레이어 — 현 62px 절차 단면이 과소하니 **두께/발광을 키운다**.
- 발광 분리: 단면 회로/글리프는 base와 diff로 emissive 추출 → 런타임 additive +
  플리커(이산시간 해시, S5에서 셰이더화). S1·건물 키트와 동일 철학.
- 배선 메모: 62px가 좁으면 `UNDERGROUND_TOP`을 상향(예: 668)해 단면을 키우는
  레이아웃 조정 1줄 — 워크라인(GROUND_Y 666) 아래 순수 비주얼이라 게임플레이
  무영향. 채택 여부는 배선측 판단.

### ② 중경 한옥 담장/뒷골목 밴드

현 `_draw_midground_wall` 대체. **X축 심리스 밴드 1장**, 캔버스 폭 640/960px급
(tile_width 320 배수), 높이 ~120px(wall_y458 기준 위아래 여유).
- 한옥 토담/기와 담장 + 뒷줄 처마 실루엣 + 등롱 점점. 야경이므로 어둡게
  (실루엣 위주, alpha로 후퇴), 시안 트림 은은하게. parallax 0.48이라 근경 건물과
  속도 차로 깊이를 만든다.
- 근경 건물(파사드)보다 채도/명도 낮게 — 시선 위계 건물 > 중경 유지.

### ③ 원경 하늘·달 레이어

- 하늘: 현 절차 그라데이션 유지 가능(저렴, 무난) 또는 1장 그라데이션 + 별
  텍스처. 사이버 조선 야경 = 먹남(4,8,22)~딥블루.
- **달: 현재 형광 라임색(0.78,0.94,0.73) → 교체.** 사이버 조선엔 한지등 웜톤
  /창백한 백색~크림 달이 맞다(녹색 달은 스테이지4 레드문 계열 연상 — 테마 혼동).
  달 1장 알파 컷(헤일로 포함), center(645,116) parallax0.04 자리.
- **구름: 현재 원/사각 합성(알약형 crude) → X축 심리스 구름 스트립 2밴드.**
  parallax 0.16/0.28 두 레이어, 페인터리 야경 구름, 달빛 받는 가장자리만 옅게.

**S6b-6 아카데미 v1 (Codex, 2026-06-14 완료)**
- 범위는 `스킬 수업 200G` 1차 실거래 + `스킬 교환` v1 stub. 광장은 스킬 소유/장착 상태를 직접 쓰지 않고 `runtime_perk_state.collect_star_points(..., defer_choice_open=true)` 후 `open_next_choice(..., exclude_instant=true, choice_context={"source":"plaza_academy"})`로 기존 character skill/perk 선택 모달을 연다.
- `plaza_academy_transactions.gd`가 거래 규칙을 소유한다. 결제 전 골드/AP/owner/runtime_perk_state/runtime_perk_catalog/기존 선택 모달 활성 여부/실제 학습 후보를 모두 검증하고, 후보가 없거나 모달이 이미 열려 있으면 골드/AP를 건드리지 않는다. 결제는 `plaza_save_store.perform_academy_lesson_payment()`의 validate-then-mutate 경로로 처리한다.
- AP 패턴은 은행/상점/대장간/가챠/링펫스토어와 동일: 메뉴 열기는 무료, **첫 성공 수업 처리**만 AP 1 소모. 수업 성공 시 건물 메뉴를 닫고 runtime perk overlay 입력으로 라우팅하여 plaza 걷기/EXIT/다른 메뉴 입력을 차단한다.
- 의도적 분리: 직접 스킬 교환 UI는 v2. v1의 교환 액션은 no-op stub이며, 슬롯 꽉 참/교환/취소 semantics는 기존 `RuntimePerkState`의 선택/스왑 모달이 계속 소유한다.
- 스모크: `plaza_academy_menu_smoke`(수업 성공→카드 선택 모달, AP/골드 차감, 모달 중 이동 차단, 실패 무소모), `plaza_save_store_smoke`, `plaza_scene_smoke`, 기존 5개 plaza 거래 스모크, `stage_clear_result_plaza_routing_smoke` 통과. `run_warning_scan.ps1` 및 `run_headless_load_check.ps1` 통과.

**S6b-7 선술집 v1 (Codex, 2026-06-14 완료)**
- Godot에 기존 퀘스트 런타임이 아직 없어 v1은 새 배틀 목표 추적을 만들지 않는다.
  선술집은 `의뢰 받기`/`의뢰 보고` 2액션을 제공하고, 현재 스테이지에서 의뢰를 수락한 뒤
  다음 스테이지 클리어 후 광장에 돌아와 보고하면 보상 골드를 받는 **plaza-persistent
  의뢰 장부**로 시작한다. 전투 중 세부 목표(무아이템 클리어, 랠리 수 등)는 v2 quest
  도메인으로 분리한다.
- `plaza_tavern_transactions.gd`가 deterministic stage offer를 소유한다. 저장소는 schema v3로
  `tavern_active_quest`, `tavern_accepted_stages`, `tavern_completed_quests`를 영속화하고,
  같은 스테이지 재수락/활성 의뢰 중복/같은 스테이지 조기 보고를 모두 no-op 처리한다.
- AP 패턴은 다른 실거래 건물과 동일: 메뉴 열기는 무료, **첫 성공 의뢰 수락 또는 보고**만
  AP 1 소모. 실패/no-op(진행 중, 활성 의뢰 없음, AP 부족)는 골드와 AP를 건드리지 않는다.
- 스모크: `plaza_tavern_menu_smoke`(수락→같은 스테이지 보고 차단→다음 스테이지 재진입→보고
  보상 지급), `plaza_save_store_smoke`(의뢰 영속/완료/중복 차단), `plaza_scene_smoke`,
  기존 plaza 거래 스모크, `stage_clear_result_plaza_routing_smoke` 통과.

### 게이트 (Claude)

`tools/plaza_scene_capture.gd` 5컷 재캡처(spawn/buildings a~c/exit) →
①음수z 매몰 회피 유지 ②건물>중경>원경 시선 위계 ③지면 단면 디제틱 가독
④구름/달 톤 정합 ⑤X심리스 이음새 무감지(스크롤 중 팝 없음). placeholder 대비
before/after 비교.

**Codex 구현 결과 (2026-06-13)**:
- 산출물: `plaza_stage1_sidescroll_ground_strip_cyber_joseon_imagegen_v1.png`
  + `ground_strip_emissive_v1`, `midground_wall_cyber_joseon_imagegen_v1`,
  `far_sky_moon_cyber_joseon_imagegen_v1`, side-scroll용
  `accent_neon_cutout`/`medallion_cutout` 4종, manifest
  `plaza_stage1_sidescroll_parallax_layers_cyber_joseon_v1_manifest.json`.
- 배선: 기존 절차 구름/달/중경/VR 단면은 fallback으로 유지하고, 새 PNG가 로드되면
  우선 사용. 지면 스트립 활성 시 기존 사각 포인트 타일 대신 투명 컷아웃을 사용해
  메달리온/accent 사각 패치감을 제거.
- 게이트 입력: `tools/plaza_scene_capture.gd` 5컷 재캡처(`d:/tmp/plaza_s4/`) 완료,
  `d:/tmp/plaza_s45/`에 asset/cutout contact board 보존. 스모크/경고/로드 검증 통과.

**후속 런타임 보정 (2026-06-15)**:
- 중경 담장 텍스처(S1/S2)가 상단 row 0부터 100% 불투명이라 지붕 봉우리가
  `MIDGROUND_WALL_TOP`에서 평평하게 잘린 듯 보이는 이슈를 확인. 자산 재생성 전
  공통 런타임 처리로 `_draw_midground_wall`에 상단 38px 알파 램프를 적용해 하늘에
  안개처럼 섞이게 했다. 향후 S3~S6 중경 에셋은 지붕 위 투명 headroom을 두는 것이
  정석이나, 이 보정은 테마 독립 fallback으로 유지.

## 6.2 S5 런타임 절반 — 발광 동적화 + 입장 다이얼로그 배선 계약 (Claude → Codex)

생산 = Codex 배선, 게이트 = Claude(픽셀 5컷 + 다이얼로그 상태 스모크).
**현황 선확인 (배선 전 필수)**: `_discrete_flicker(seed_text)`
(`plaza_scene.gd:531`)가 **이미** 이산시간 해시 flicker(47Hz 틱 `ticks_msec*0.047`
+ `hash`)이고, 건물 sign/window에 CPU modulate alpha로 적용 중. 즉 S5는 셰이더
신규 도입이 아니라 **기존 CPU flicker의 확장**이 기본값이다.

### A. 발광 동적화 (CPU flicker 확장 — 셰이더는 felt-QA 실패 시에만)

현재 flicker가 닿지 않는 정적 발광 레이어에 확장:
- 지면: `ground_strip_emissive`(현 alpha 0.66 고정), VR strata, accent/medallion
  emissive(0.58/0.48 고정) → flicker 변조 추가.
- **per-instance seed 필수**: 현 `_discrete_flicker`는 seed가 건물 type 문자열
  뿐이라 같은 타입이 lockstep으로 깜빡인다. seed에 위치(world_x)/인덱스를
  섞어 인접 발광이 따로 놀게 한다.
- 변조는 절제: 기존 건물 pulse 진폭(±0.22/±0.12) 수준 유지 — 지면/strata는
  더 약하게(은은한 데이터 흐름感). 깜빡임이 산만하면 진폭부터 줄인다.
- **CPU 우선 이유**: 현 immediate `_draw` modulate 경로라 PSO/머티리얼 0,
  draw_set_transform 트랩 0. 비용도 레이어당 float 1개/frame.
- **셰이더 escalation 조건 (felt-QA에서 modulate flicker가 평평/균일하면만)**:
  셰이더/머티리얼 도입 시 (1) `battle_pso_prewarmer` 컨텍스트 등록 필수
  (첫-draw 히치), (2) `_draw()` 내 `canvas.material` set→draw→restore 패턴
  (별도 RID 셰이더 패스 / IDENTITY 리셋 트랩 회피), (3) 1패스 셰이더로.
  sin 기반 wander 금지(이산시간 해시 유지).

### B. 입장 다이얼로그 본체 (placeholder → 메뉴 셸)

현 `_show_building_dialog`(`plaza_scene.gd:520`)는 "X 준비 중" 2.25s 토스트.
이를 **건물별 메뉴 다이얼로그 셸**로 교체. **스코프 경계 (§8 결정 준수)**:
S5 = 메뉴 **셸**(열기/닫기/타이틀/스텁 액션 리스트/모달 입력 캡처)까지.
실제 거래(골드 차감/AP 소모/아이템 이동)는 **S6 경제/세이브**에서 — S5에선
액션 항목을 비활성 스텁으로 표시("준비 중" 라벨 OK, 단 메뉴 구조는 실제로).
- 7종 메뉴 타이틀/액션 항목(셸 텍스트만, §5 엠블럼 사전과 일치):
  상점=구매/판매, 은행=예금/출금, 가챠=뽑기, 링펫스토어=알 뽑기/링펫,
  대장간=강화, 선술집=퀘스트, 아카데미=스킬 획득/교환.
- **모달 입력 계약**: 메뉴 열린 동안 좌우 걷기/카메라 입력 차단(현
  `handle_plaza_input`에 메뉴-열림 게이트 추가), ESC/닫기로만 빠져나옴.
  EXIT존 상호작용도 메뉴 중엔 무시.
- **owner-key 신설 금지 (우선)**: 다이얼로그 상태(`_active_menu_type`,
  `_menu_open`)는 plaza 모듈 내부 var로. 크로스모듈 읽기가 정말 필요해지면
  그때만 `battle_scene_state.DEFAULT_VALUES` 선언(조용한 no-op 트랩) — S5에선
  불필요할 것.
- 렌더: 기존 immediate `_draw` 스타일 유지(다이얼로그 패널도 `_draw`로),
  새 .tscn 노드 트리 만들지 말 것.
- 한글 라벨: Godot 폰트(굽기 금지). 플레이어 노출 문구이므로 다국어 동기화
  대상 — 메뉴 타이틀/액션 텍스트를 하드코딩 산개시키지 말고 한 곳(테마
  카탈로그 or 전용 dict)에 모아 후속 localization 연결 지점 확보.

### 게이트 (Claude)

- 발광: `tools/plaza_scene_capture.gd` 5컷 + 2틱 간격 추가 캡처로 flicker가
  per-instance로 다르게 변조되는지(동일 타입 lockstep 아님) 확인.
- 다이얼로그: 상태 스모크 — ①7종 각 인터랙션이 해당 메뉴 셸 열기 ②메뉴 중
  걷기/EXIT 입력 차단 ③ESC/닫기 복귀 ④거래 액션은 스텁(상태 변화 0).
  + 윈도우드 1컷으로 메뉴 패널 실렌더 확인.

**Codex 구현 결과 (2026-06-13)**:
- 발광 동적화: shader 신규 도입 없이 기존 `_discrete_flicker(seed)` CPU 경로를
  확장. 건물 seed는 `type:x`, 지면 strip/어도/medallion/accent/fallback VR strata는
  각 world_x 또는 index를 seed에 섞어 per-instance 변조. PSO prewarmer 추가 없음.
- 메뉴 셸: `BUILDING_MENU_SPECS` 단일 dict에 7종 타이틀/설명/action stub을 모으고,
  `plaza_scene.gd` 내부 상태(`_menu_open`, `_active_menu_type`, actions)만 사용.
  owner key 신설 없음. 메뉴 open 중 이동/EXIT/상호작용은 차단, ESC/닫기로 복귀.
- 게이트 입력: `plaza_scene_smoke`에 7종 메뉴 열기, 메뉴 중 이동/EXIT 차단,
  ESC 복귀, 스텁 액션 no-op, per-instance flicker sample 검증 추가.
  `tools/plaza_scene_capture.gd`는 S5용 flicker 2틱 컷과 menu_shop 컷을 추가 저장.
  2틱 diff: changed_pixels 9720, avg_diff 0.0993, max_channel_diff 22.

## 6.3 S6 경제/세이브 — 배선 계약 (Claude → Codex)

**프로젝트 최초의 영속 진행 세이브.** 트랩 밀도 최고 — 전부 선제 차단.
스코프 분할: **S6a = 영속 스토어 + 골드 이관 + AP + 은행(골드 전용)**,
**S6b = 아이템 접촉 거래(상점/가챠/링펫/대장간/아카데미 — 각 런타임 시스템
연결)**. S6a를 먼저 잠근다(순수 골드라 가장 깨끗, 트랩 검증 끝나면 S6b는 채우기).

### 현황 (배선 전 확정)
- 골드는 `runtime_perk_gold` 단 하나, `battle_scene_state.DEFAULT_VALUES:135`
  (배틀 휘발), `paddle_bounce_post_hit_step.gd:54` 획득, `match_reset_controller
  .gd:244`에서 0 리셋. **영속 진행 스토어 0건 — 광장이 최초.**
- 참조 패턴 = `lingpet_affinity_store.gd` (ConfigFile + `SAVE_SCHEMA_VERSION` +
  `.last_good` 백업 + `_recovery_blocked` + load/save summary). 그대로 미러.
- 레거시 AP: BASE 3 / +1 per stage clear / MAX 10 (`downtown/constants.py:380`).

### S6a — 스토어 + 골드 + AP

**1) 영속 스토어 `plaza_save_store.gd` (affinity store 미러)**
- `user://plaza_save.cfg`, schema v1, `.last_good` 백업, recovery_blocked,
  load/save summary. **UTF-8 BOM 트랩**: 첫 섹션이 BOM에 먹히면 조용히 디폴트로
  — raw byte로 BOM strip 후 파싱, BOM 없이 재기록(CLAUDE.md ConfigFile 트랩).
- 보관 키: `plaza_gold`(int), `ap_current`(int), `ap_is_first_stage`(bool).
  은행 예금(`deposit_balance` 등)은 S6b/은행 확장 시 추가.

**2) 골드 이관 (트랩: 이중 카운트)**
- 시점: `ACTION_ENTER_PLAZA`에서 광장 스폰 직전, **리셋 콜백 지연 전에**
  `runtime_perk_gold`를 읽어 `plaza_gold += runtime_perk_gold` 1회 적립.
  (match_reset가 곧 0으로 만들므로 읽기는 그 전에.)
- **이중 카운트 차단**: 이관은 "스테이지 클리어→광장 진입" edge에서 정확히
  1회. 광장 안 머무름/메뉴 토글/재드로우로 재적립 금지 — 1회 소비 플래그 또는
  진입 시점 스냅샷-소비 패턴. 광장 퇴장 후 재진입 경로가 생기면 그땐 이미
  runtime_perk_gold=0이라 자연 방어되지만, 플래그로 명시 방어.
- **스타포인트 트랩 (MEMORY 확정)**: `plaza_gold`는 골드 단위
  (runtime_perk_gold와 동일 단위)다. 결과화면 ★ placeholder(80~200)나
  starpoint(STARPOINT_PER_SKILL_CHOICE=1)를 plaza_gold에 직결 금지 — 단위가
  섞이면 상점 물가가 붕괴한다. 골드 레저는 골드만.

**3) AP(열쇠) 시스템**
- BASE 3 / MAX 10 / 스테이지 클리어 +1. `plaza_save_store`에 persist.
- **재진입 +1 중복 트랩 (레거시 manager.py:441-445 — 포팅 시 수정 대상)**:
  +1은 **진짜 스테이지 전진 1회**에만. 광장 재진입/이어하기(continue)에서
  재지급 금지. `ap_is_first_stage` + "이 스테이지에서 이미 +1 받음" 가드로
  edge를 1회로 묶는다. (레거시는 이걸 틀렸으니 패리티 금지, 의도적 분기.)
- 건물 입장 AP 소모는 S6b(거래 활성화)와 함께 — S6a에선 AP 표시/적립/persist
  까지, 소모는 메뉴 거래가 실제 동작할 때.

**4) owner-key 스키마**
- 이관 읽기 소스 `runtime_perk_gold`는 이미 DEFAULT_VALUES에 있음 — 신설 불요.
- `plaza_gold`/AP는 **영속 스토어 소유**(owner 아님). HUD가 owner 경유로 읽어야
  하면 그때만 DEFAULT_VALUES 선언(조용한 no-op 트랩). 가급적 스토어/plaza
  모듈 직접 읽기로 owner 우회.

### S6b — 아이템 접촉 거래 (후속)
상점 구매/판매·가챠·링펫알·대장간 강화·아카데미 스킬은 각 런타임 시스템
(item runtime checklist / gacha / lingpet egg / 강화 / character skill)과 연결.
S6a 레저가 검증된 뒤 건물별로 stub→실거래 전환. 각 전환은 해당 도메인
체크리스트(`docs/item_runtime_checklist.md` 등) 경유 — 이 문서가 재발명하지 않음.

**S6b-1 은행 v1 (Codex, 2026-06-14 완료)**
- `plaza_save_store.gd` schema v2: `bank_deposit_gold` + stage-keyed
  `bank_interest_claimed_stages` 추가. 기존 v1 파일은 `migrated_v1`로 로드 후
  무BOM v2로 재저장.
- 메뉴 다이얼로그 인테리어에서 은행만 stub 해제: `예금 100G`, `출금 100G`,
  `이자 정산`. 숫자 입력 UI 없이 100G 단위, 부족하면 가능한 만큼 처리.
- AP 패턴: 메뉴를 여는 것만으로는 소모하지 않고, **첫 성공 은행 처리**에서
  AP 1 소모. 같은 메뉴 방문 안의 후속 예금/출금/이자는 추가 AP를 쓰지 않음.
  닫고 다시 열면 새 방문으로 AP 1을 다시 요구. 실패 처리(골드 없음/예금 없음/
  같은 스테이지 이자 재정산)는 AP를 소모하지 않음.
- 이자 v1: 예금 원금의 5%를 `plaza_gold`로 지급, 스테이지당 1회. 원본
  `manager.py`의 복리/5~20% 랜덤 이자율/스테이지 스킵 누적은 후속 은행 확장으로
  남김.
- 스모크: `plaza_save_store_smoke`(은행 원자 거래+이자 1회), `plaza_bank_menu_smoke`
  (실제 메뉴 AP 방문 패턴), 기존 `plaza_scene_smoke`/결과씬 스모크 통과.
- **+Claude 게이트 통과 (2026-06-14)**: 경제 정합성 코드 검증 — ①예금/출금
  양방향 `min` 캡 + `_sanitize_gold` max(0)로 음수 잔액 불가 ②이자 per-stage
  dedup(`_bank_interest_claimed_stages`, 세이브 섹션 영속)·5% floor min1 ③AP
  방문당 1회=씬 `_active_menu_visit_ap_consumed`가 **실제 ap_spent>0일 때만** 세팅
  →no-op 선행 후 성공이 AP 소모(정확), 스토어는 ap<=0에서 no_ap 차단 ④v1→v2
  마이그레이션=bank 섹션 부재 시 0 디폴트 + `migrated_v1` 재저장. 워치(비차단):
  `stage_clear_result_screen_smoke` ObjectDB leak 경고는 S6b-1 이전부터 존재
  (wrapper pass), S6b-1 회귀 아님.

**S6b-2 상점 v1 (Codex, 2026-06-14 완료)**
- 범위는 기존 액티브 아이템 접촉 거래만: `벽돌 구매 80G`, `부메랑 구매 120G`,
  `마지막 아이템 판매`. 패시브/전설/신규 아이템 생성, 장착 해제, 롤/폴리시,
  블랙스미스 강화와 얽히는 항목은 후속 아이템 도메인 슬라이스로 분리.
- `stage_clear_result_screen.gd`가 광장 `configure`에 `_pending_owner`와
  `_pending_registry`를 전달한다. 상점은 `active_item_runtime.grant_item_to_slot`
  / `debug_remove_item_from_slot` 경로만 사용하고, owner 배열을 직접 새로
  해석해 아이템을 만들지 않는다.
- `plaza_shop_transactions.gd`가 상점 거래 규칙을 소유한다. 구매는 골드/AP/런타임
  사전 검증 후 아이템 grant → 지갑 차감, 지갑 실패 시 grant 롤백. 판매는 마지막
  액티브 슬롯 1개를 제거하고 구매가의 50%(미등록 active는 40G fallback)를
  `plaza_gold`에 더한다.
- AP 패턴은 은행과 동일: 메뉴 열기는 무료, **첫 성공 상점 거래**만 AP 1 소모,
  같은 메뉴 방문의 후속 구매/판매는 추가 AP 없음. 골드 부족/슬롯 꽉 참/판매할
  아이템 없음 같은 실패 거래는 AP를 쓰지 않는다.
- 스모크: `plaza_shop_menu_smoke`(실제 `ActiveItemRuntime` owner 슬롯 grant/remove),
  `plaza_save_store_smoke`(상점 지갑 거래), 기존 `plaza_scene_smoke`/은행/결과씬
  라우팅 스모크 통과.
- **+Claude 게이트 통과 (2026-06-14)**: 거래 원자성 코드 검증 — ①구매 순서
  골드체크→AP체크→`grant_item_to_slot(allow_overflow=false)`→지갑 차감→실패 시
  `_rollback_granted_item`; 슬롯 만석은 지갑 차감 전 리턴(AP 무소모) ②지갑 거래
  원자(validate-then-mutate, `changed=false`=부분적용 0)라 롤백 안전 ③판매는
  AP 차단을 **제거 전** 체크(line 84)+sale 지갑은 골드 가산이라 제거 후 실패
  불가→"아이템 소실·골드 0" 차단 ④아이템 런타임 접점 실재(`active_item_runtime.gd:356/371`)·`allow_overflow=false`로 슬롯 캡 존중 ⑤AP 방문당 1회 은행과 동일(`_active_menu_visit_ap_consumed`, `ap_spent>0`만 세팅). v1 단순화(비차단): 미등록 active 판매가 flat 40G(레거시 items.py per-item sell_price와 분기), debug_* facade grant 경로 사용(기본 액티브엔 충분, 패시브/전설 라우팅 비해당).

**S6b-3 대장간 v1 (Codex, 2026-06-14 완료)**
- 범위는 액티브 슬롯 접촉 강화 1차: `마지막 아이템 강화` 1액션. 대상은 owner
  `active_item_slots`의 마지막 유효 아이템이고, 슬롯 dict에
  `enhancement_level` / `enhancement_bonus_pct`를 기록한다. 패시브/전설 장비,
  아이템별 stat-read 보너스 소비, 강화 애니메이션/VFX, 롤옵션 tooltip 동기화는
  후속 아이템 도메인 슬라이스로 분리.
- 레거시 테이블은 포팅: `MAX_ENHANCEMENT_LEVEL=10`, 비용 100→900G,
  성공률 80%→23%, 보너스 0/10/22/36/52/70/90/115/145/190/260%.
  단, 레거시 `building_interior.py`는 실패 시 패시브/전설 아이템 파괴였으나
  Godot 광장 v1은 **의도적 분기**로 실패해도 아이템을 유지한다. 실패/유지는
  골드만 소모하고 레벨/보너스는 그대로 둔다.
- `plaza_blacksmith_transactions.gd`가 강화 규칙을 소유한다. 사전 검증은
  대상 존재→최대강화→골드→AP 순서, 결제는
  `plaza_save_store.perform_blacksmith_enhancement_payment`에서 validate-then-mutate.
  결제 성공 후에만 클릭당 1회 roll을 굴리고, 성공 시에만 슬롯 dict를 갱신한다.
  실패/no-op(`no_active_item`, `not_enough_gold`, `no_ap`, `max_level`)은 AP를 쓰지 않는다.
- AP 패턴은 은행/상점과 동일: 메뉴 열기는 무료, **첫 성공 강화 시도**만 AP 1 소모,
  같은 메뉴 방문의 후속 강화 시도는 추가 AP 없음. 여기서 "성공 시도"는 결제와
  roll이 실제로 실행된 attempt이며, 결과가 success/maintain/fail 어느 쪽이어도
  골드가 빠졌으면 같은 방문 AP는 이미 소비된 것으로 본다.
- 스모크: `plaza_blacksmith_menu_smoke`(강제 roll로 success/fail/maintain, 실패 시
  아이템 유지, 방문당 AP 1회, 골드 부족/no-item 무소모), `plaza_save_store_smoke`
  (대장간 결제), 기존 `plaza_scene_smoke`/상점/은행/결과씬 라우팅 스모크 통과.
- **+Claude 게이트 통과 (2026-06-14)**: 강화 정합성 코드 검증 — ①**per-click 1회
  roll**(`_roll_once` attempt당 정확히 1번, 루프/프레임 없음 = CLAUDE.md 확률
  트랩 사촌 회피) ②결제(validate-then-mutate, 원자)→roll→성공 시만 `enhancement_level`+1
  & `enhancement_bonus_pct` 기록, maintain/fail은 골드만(레거시 pay-per-attempt
  패리티, 롤백 불요) ③max_level 가드로 10에서 비용 0(maxed 결제 불가)+`mini()` 캡
  ④레이트 테이블 10레벨 전부 합 100, roll [1,100] success/maintain/fail 깔끔 분할
  ⑤AP 방문당 1회 은행/상점과 동일. **의도적 분기 확인**: 실패 시 아이템 파괴
  없음(레거시 building_interior.py 파괴 → v1 플레이어 친화 분기). **후속 워치
  (비차단)**: 슬롯에 기록된 `enhancement_bonus_pct`를 wall/boomerang 런타임 효과가
  실제로 읽어 위력 스케일하는지는 별도 아이템 슬라이스 — 현재는 "기록"까지라
  displayed-stat-without-outcome 갭이 남으면 그때 닫는다(item_runtime_checklist의
  enhancement_bonus_pct 소비 규칙 경유).

**S6b-4 가챠샵 v1 (Codex, 2026-06-14 완료)**
- 범위는 광장 전용 **액티브 아이템 캡슐 가챠** 1차: `액티브 캡슐 뽑기 150G`.
  기존 `ActiveItemCatalog.FIELD_SPAWN_ORDER`의 active 아이템 후보와 `chance`
  weight를 읽고, 지급은 `active_item_runtime.grant_item_to_slot(..., false)`로만
  수행한다. 새 레전더리/미식/패시브 풀을 만들지 않고, stage-clear gacha builder,
  `gacha.py` 메타데이터, Nemesis chest, treasure-hunt, crane spawn/reward 경로는
  **의도적으로 미접촉**한다.
- `plaza_gacha_transactions.gd`가 가챠 규칙을 소유한다. 사전 검증은 골드→AP→
  active item runtime→owner 순서, 이후 후보 1개 선택→슬롯 grant→지갑 결제.
  결제가 실패하면 grant를 `_rollback_granted_item`으로 되돌린다. 슬롯 만석,
  골드 부족, AP 부족, 런타임/owner 없음은 골드/AP/아이템 변화 없이 실패한다.
- AP 패턴은 은행/상점/대장간과 동일: 메뉴 열기는 무료, **첫 성공 뽑기**만 AP 1
  소모, 같은 메뉴 방문의 후속 뽑기는 추가 AP 없음. 실패/no-op은 AP를 쓰지 않는다.
- 스모크: `plaza_gacha_menu_smoke`(강제 보상으로 실제 `ActiveItemRuntime` grant,
  같은 방문 AP 1회, 골드 부족/슬롯 만석 무소모), `plaza_save_store_smoke`
  (가챠 결제), 기존 `plaza_scene_smoke`/은행/상점/대장간/결과씬 라우팅 스모크 통과.
- **+Claude 게이트 통과 (2026-06-14)**: 가챠 도메인 정합성 코드 검증 — ①**보상
  스코프 봉인**=`_is_valid_gacha_item`의 `type=="active"` 필터 + `FIELD_SPAWN_ORDER`
  (실측 전부 active 필드스폰, 레전더리/미식/패시브 0)로 특수 풀 차단, stage-clear
  gacha/gacha.py/treasure-hunt/Nemesis chest/crane 미접촉(체크리스트 백필
  item_runtime_checklist.md:271-279 확인) ②**새 풀 아님**=카탈로그와 동일 weighted
  알고리즘 재사용=기존 필드스폰 분포의 입구 ③weighted 롤 안전(빈 풀→empty_gacha_pool,
  부동소수 엣지→back() 폴백) ④구매 원자(gold→ap→grant allow_overflow=false→결제→실패
  롤백) ⑤AP 방문당 1회 동일. 노트(비결함): pandora_box 뽑기 가능하나 필드스폰과
  동등(다운스트림 on-use 동작 불변, 레전더리 누수 신규 경로 없음).

**S6b-5 링펫스토어 v1 (Codex, 2026-06-14 완료)**
- 범위는 광장 전용 **공명 알 뽑기** 1차: `공명 알 뽑기 250G`.
  링펫을 직접 grant하지 않고 `lingpet_egg_runtime.spawn_plaza_resonance_egg()`로
  기존 **미확인 알 → 공 충돌 → 부화 → 소유/슬롯 반영** 흐름의 입구만 연다.
  pre-hatch owner sync는 `lingpet_id`/`active_lingpet_id`/`current_lingpet_id`를
  빈 값으로 유지해 숨은 링펫 정체성을 노출하지 않는다.
- **V3-3c 링코어 강화 추가 (Codex, 2026-06-14 완료)**: 링펫스토어 액션 1을
  `링코어 강화`로 교체. account-wide `lingpet_affinity_store` tier를 한 단계씩
  구매해 cap 0→5→10→15→20→25→30을 연다. 가격은
  150/300/600/1000/1500/2200G 플레이스홀더(V3-6 income QA에서 재튜닝).
  첫 성공 링펫스토어 거래만 AP 1 소모, 같은 방문 후속 구매는 AP 0.
  실패 시 gold/AP/tier 전부 불변.
- `plaza_lingpet_store_transactions.gd`가 거래 규칙을 소유한다. 사전 검증은
  골드→AP→`lingpet_egg_runtime`→owner→hatch candidate 순서. 런타임 알 스폰 후
  결제 실패 시 `get_save_snapshot()`/`apply_save_snapshot()`로 알 상태를 롤백한다.
  골드 부족, AP 부족, 이미 알 활성, 후보 없음(현재 hatch pool 전부 소유), 런타임/
  owner 없음은 골드/AP/링펫 상태 변화 없이 실패한다.
- 링펫 소유 상태는 plaza가 새로 만들지 않는다. 구매 전 owner의 기존
  `lingpet_owned_pet_ids`/`owned_lingpet_ids`/컬렉션/슬롯을 런타임 collection에
  흡수한 뒤 알만 열고, 실제 `owned_pet_ids` 추가와 battle slot 배정은 기존
  부화 처리(`_mark_current_pet_owned`, `_select_current_pet_slot`)가 맡는다.
- AP 패턴은 은행/상점/대장간/가챠와 동일: 메뉴 열기는 무료, **첫 성공 알 뽑기**만
  AP 1 소모, 같은 메뉴 방문의 후속 거래는 추가 AP 없음. 실패/no-op은 AP를 쓰지
  않는다. `링펫 관리`는 v1 stub로 유지.
- 스모크: `plaza_lingpet_store_menu_smoke`(구매 즉시 알 상태/정체성 비공개/직접
  소유 없음, 중복 알·골드 부족·후보 없음 무소모, 공 충돌 부화 후 기존 런타임
  소유/슬롯 grant 확인), `plaza_save_store_smoke`(링펫 알 결제), 기존
  `plaza_scene_smoke`/은행/상점/대장간/가챠 메뉴 스모크 통과. 대형
  `lingpet_egg_runtime_smoke`는 현재 친밀도/스탯 카드 계열 기존 실패가 남아
  별도 워치로 분리한다(이번 plaza API는 해당 경로 미호출).
- **+Claude 게이트 통과 (2026-06-14)**: 링펫 도메인 정합성 코드 검증 — ①**직접
  지급 없음 확인**=`spawn_plaza_resonance_egg`는 STATE_EGG + hatch 후보 선택만, owned_pet_ids/
  battle_slots 미기록 → 소유/슬롯은 기존 공 충돌 부화 흐름이 담당(설계 결정 준수)
  ②경제 무결=offer→spawn→pay 순서지만 gold/ap는 step1 read-only 체크 후 spawn까지
  무소비라 결제 항상 성공=**"결제 없이 알 스폰" 불가**, 스냅샷 롤백(`get_save_snapshot`이
  `_state`/`hatch_hits` 캡처)은 실질 도달불가한 방어층 ③기존 영속 스토어 미오염=plaza가
  링펫 소유 상태를 새로 안 만들고 `lingpet_egg_runtime` 경유 ④AP 방문당 1회 동일,
  manage는 stub no-op ⑤lingpet_egg_runtime.gd 추가분은 순수 additive(기존 흐름 재사용).
  **⚠ 커밋 위생(차단성 아님, 필수 확인)**: 현 워크트리에 lingpet_egg_runtime.gd
  기준 git diff가 +160/-19 — S6b-5 plaza 블록(+49 additive) 외에 **별개 미커밋
  F7 이동속도/친밀도 피드백 작업**(`_get_current_patrol_speed` 래퍼가 patrol_speed
  읽기를 대체)이 공존하며, **그 작업이 `lingpet_egg_runtime_smoke`의 flight-deck
  fallback 단언을 RED로 만든 주범**(plaza 무관). 메모리의 godot-wip HEAD 유동 상황 —
  S6b-5 커밋 시 이 F7 작업을 휩쓸지 말고 plaza 파일+egg_runtime additive 블록으로
  스코프 한정, F7 flight-deck 회귀는 별도로 수정/커밋.

### 게이트 (Claude)
S6a 스모크: ①스토어 save→load 라운드트립(BOM 포함 파일도 복구) ②골드 이관이
진입 edge 1회만(재드로우/재진입 무적립) ③AP +1이 스테이지 전진 1회만(재진입
무지급) ④스타포인트/★ 단위가 plaza_gold에 안 섞임(골드 단위 불변) ⑤스키마
손상 파일 → last_good 복구. 영속이라 **실제 파일 라운드트립**까지 확인.

## 0.7 S2 첫 테마 — 스테이지 2 정글 유적 패럴랙스 아트 브리프 (Claude → Codex)

S2 런타임 슬롯의 manifest 덮어쓰기 경로를 **첫 실테마로 검증**하는 슬라이스.
생산 = Codex, 게이트 = Claude(5컷 캡처 + X심리스 정량 + 덮어쓰기 실발동 확인).
**S1 제작 문법 그대로 재사용**(무장식 베이스 먼저 X심리스 → 발광 diff 분리 →
하프롤/2x2 QA). 단지 팔레트/모티프만 정글로 리스킨.

### 스코프 (v1 = 패럴랙스 4레이어)
사용자 확정: `ground_strip` + `ground_strip_emissive` + `midground_wall` +
`far_sky`. 탑다운 floor-tile 세트(base_01/02/accent/border/medallion)와 cutout은
**S1 fallback 유지**(사이드뷰에서 주 가시면은 ground_strip이라 v1 우선순위 밖).
**건물 7동은 S1 한옥 그대로** — 정글 바닥 위 한옥은 테마 불일치지만, 건물
테마별 재생성은 별도 대형 슬라이스(6테마×7동)라 v1에서 의도적 보류(알려진 한계).

### manifest 계약 (이 경로/키여야 슬롯이 발동)
- 패럴랙스 manifest: `res://assets/ui/plaza/plaza_stage2_sidescroll_parallax_layers_jungle_relic_v1_manifest.json`
- 스키마는 S1 패럴랙스 manifest와 동일(`assets`[] 각 항목 `{id, res_path, ...}`).
- **id → 로더 키 매핑(PARALLAX_MANIFEST_KEYS)**: `ground`→ground_strip,
  `ground_emissive`→ground_strip_emissive, `midground`→midground_wall,
  `sky`→far_sky. (id가 정확히 이 문자열이어야 덮어쓰기됨.)
- **발동 게이트**: 각 `res_path`는 `texture_resource_exists()` 통과해야(=Godot
  import 완료, .ctex remap 유효) 덮어쓰기. import 안 되면 조용히 S1 fallback —
  반입 시 import pass 필수(Solar Bolt sidecar 누락 사건의 교훈).

### 좌표/사이즈 계약 (S1 확정값 그대로)
- `ground_strip`: **X심리스, 런타임 1140×154**(=FLOOR_REPEAT 380×3). 상단 보도
  밴드(y596~688) + 하단 단면(y688~750). 좌우 엣지 diff **0.00** 필수.
- `ground_strip_emissive`: base와 diff로 추출한 발광 오버레이(런타임 additive +
  flicker). 정글 단면의 데이터-덩굴 발광만 담음.
- `midground_wall`: **X심리스, 960×180**(=tile 320×3), parallax 0.48. 좌우 0.00.
- `far_sky`: ~1520×430 와이드 atlas, parallax 0.04(비타일 — edge delta 허용).

### 정글 유적 아트 디렉션 (§3 매트릭스 기반)
- 팔레트(실측): 딥그린 `(0.045,0.105,0.075)`, 모스 `(0.45,0.58,0.28)`, 흙그늘
  `(0.02,0.05,0.02)`. 네온 액센트 = **민트-시안 `(42,214,214)` ≈ #2AD6D6**.
- 지면(ground_strip 상단): 이끼 낀 석판 + 뿌리/덩굴 침식, 다진 흙 패치, 균열
  암석 파편. S1의 박석→정글 석판으로 대비.
- **단면(ground_strip 하단) = VR 기저의 정글판**: S1은 금/시안 회로 지층이었는데,
  S2는 **민트-시안 "데이터 덩굴/회로 뿌리"** 가 흙 단면을 관통하는 형태. "가상세계
  기저가 비쳐 보임"을 정글 관용구(뿌리=회로)로 표현 — 이게 S1 대비 핵심 대조 테스트.
- 중경(midground_wall): 정글 유적 담장/이끼 낀 석조 + 늘어진 덩굴 실루엣, 어둡게
  후퇴(시선 위계 건물 > 중경 유지), 민트-시안 트림 은은.
- 원경(far_sky): 정글 야경 — 짙은 녹청 하늘 + 안개층, 달은 S1 웜톤 유지하되
  녹빛 안개에 감싸이게. 알약형 구름 금지(S1 교훈).

### 게이트 (Claude)
`tools/plaza_scene_capture.gd`를 **stage 2로** 5컷 캡처 →
①덮어쓰기 실발동 확인(ground/midground/sky가 S1이 아닌 stage2 자산으로 — 스모크
fallback 단언의 반대 케이스) ②X심리스 정량 0.00(ground 1140×154, midground
960×180) ③시선 위계(건물>중경>원경) ④단면 데이터-덩굴 디제틱 가독 ⑤S1 대비
대조(정글이 사이버 조선과 확실히 구분되며 같은 문법으로 읽히는지). placeholder
없이 실자산이라 import pass 후 캡처.

**Codex 구현 결과 (2026-06-14)**:
- `plaza_stage2_sidescroll_parallax_layers_jungle_relic_v1_manifest.json` 반입.
  `assets` id는 계약대로 `ground` / `ground_emissive` / `midground` / `sky`.
- 최종 PNG: ground 1140×154, ground_emissive 1140×154, midground 960×180,
  far_sky 1520×430. 생성 원본 3장(`*_source.png`)도 보존.
- Godot import pass로 PNG 7종 `.png.import` 생성 완료. `plaza_scene_smoke`가
  stage2 prewarm status에서 stage2 ground/midground/sky 실제 로드를 단언.
- QA 정량: ground edge delta 0.00, ground_emissive edge delta 0.00, midground
  edge delta 0.00, emissive alpha coverage 4.094%.
- QA 산출물: `d:/tmp/plaza_s2/plaza_s2_layer_stack_preview.png`,
  `plaza_s2_ground_2x_wrap.png`, `plaza_s2_midground_2x_wrap.png`,
  stage2 실화면 캡처 `d:/tmp/plaza_s2_capture/plaza_stage2_*.png`.

**+Claude 게이트 통과 (2026-06-14)**: ①**덮어쓰기 실발동 정량 확정**(경로 프로브:
ground/ground_emissive/midground/far_sky=stage2 jungle_relic, base/accent/
medallion_cutout=stage1 fallback — v1 범위대로) ②X심리스 0.00(3레이어) ③단면
**민트시안 데이터덩굴/회로뿌리 디제틱 가독** 확인(이끼 녹석판+흙단면 관통) ④S1
대비 확실(웜크림 박석+금/시안 회로 ↔ 녹모스 석판+민트 덩굴, 같은 franchise 문법)
⑤건물 S1 한옥 fallback(문서화된 v1 한계). 스코프 plaza만(링펫 미접촉). **결론:
S2 슬롯+manifest 덮어쓰기 경로가 두 번째 실테마에서 검증됨 → S3~6 동일 문법 확장 가능.**

### S3 네온시티 변주 (2026-06-14 착수) — S2 계약 상속 + 도시 델타만

S2 모든 계약 그대로 상속(키 ground/ground_emissive/midground/sky, 사이즈
ground 1140×154 / midground 960×180 / far_sky 1520×430, X심리스 0.00, 베이스
먼저 심리스→발광 diff→texture_resource_exists 게이트→경로 프로브 5컷). 델타만:
- manifest: `res://assets/ui/plaza/plaza_stage3_sidescroll_parallax_layers_neon_city_v1_manifest.json` (slug=`neon_city`).
- **구조적 역전 (S3 고유)**: §3 매트릭스에서 스테이지 3은 "사이버 베이스가 전면에
  드러나는 기준점". S1/S2는 문화스킨70/기저30이었으나 **네온시티는 비율 역전 허용**
  — 도시 자체가 네온이라 데이터 단면이 "비쳐 보이는 기저"가 아니라 **"젖은
  아스팔트에 반사되는 네온" 그 자체로 전면화**. ground_strip 하단 단면은 "기저
  노출 데이터덩굴" 대신 젖은 아스팔트 측면 + 배수구/네온 누수광.
- 캐논 근거: 레거시 `ui/space_map.py:4689` "멘헤라/아키하바라 행성 표면 — 더티
  핑크+보라빛 도시 야경"(세로 네온 사인/간판 글리프). 배틀 내부 멘헤라 파스텔 룸이
  아니라 **옥외 도시 야경**을 따른다.
- 아트(§3): 젖은 아스팔트 + 네온 반사, 점자블록(노랑 텍타일), 맨홀/배수구, 파스텔
  간판 빛 번짐. 팔레트 = 더티핑크+퍼플 야경, 파스텔핑크 `(255,182,193)`, 라벤더
  `(230,190,255)`, 크림슨 `(220,20,60)`, 다크플럼 `(18,12,22)`. far_sky = 세로
  네온 사인/간판 글리프 빽빽한 아키하바라풍 도시 스카이라인(S1/S2 자연 하늘과
  대비 — 도시 실루엣), 달은 네온에 묻혀도 됨. midground = 네온 간판 걸린 뒷골목
  빌딩 실루엣.
- 게이트: stage 3 5컷 → 덮어쓰기 실발동 + X심리스 0.00 + **3테마 대조**(조선석/
  정글모스/도시아스팔트가 한 문법으로 읽히는지) + 네온 전면화가 "기저 노출" 역전을
  의도대로 보여주는지. 건물 S1 한옥 fallback 유지.

## 0.8 Stage 1 정리(consolidation) 패스 (2026-06-14, 실플레이 QA 기반)

사용자 실플레이 QA 4개 이슈. **S3~6 테마 양산 일시 보류** — Stage 1을 실제 플레이
가능 수준으로 먼저 정리(양산 후 고치면 6배 비용). 코드만 vs 자산 필요로 분류.

**① 캐릭터 + 링펫 팔로워 (대부분 배선 — 자산 거의 불요, 2026-06-14 재조사)**
- 현재 플레이어 = `_draw_player`의 시안 placeholder 박스. 실 캐릭터 안 보임.
- 페르소나↔클래스 (character_select_data.gd 확정): 미카=스매셔, 세린=바이퍼,
  레나=코만도, 이오=옵티머스, 코하쿠=발토르.
- **★재조사 결과: 미카/세린/레나 walk 시트가 이미 존재한다.** `{smasher,viper,
  commando}_subculture_{left,right}_walk_sheet.png`(각 640×320), commando는 back도
  있음. 이미 `battle_resources.gd`에 `*_PLAYER_WALK_*_SHEET_PATH`로 등록·전투
  렌더 중(line 145 "subculture walk sprites에서 제작"). → **신규 AutoSprite 사이클
  불필요.** ①은 "걷기 시트 제작"이 아니라 **기존 전투 walk 렌더 경로를 플라자에서
  재사용하는 배선**으로 축소.
  - 배선: 플라자 player를 선택 캐릭터의 left/right walk 시트로 그림(이동 방향별,
    정지 시 idle 프레임). 슬라이스는 전투 player 렌더러 경로 재사용(시트 동일 자산,
    그리드 재발명 금지 — atlas grid authority). 박스 placeholder 대체.
- **이오/코하쿠는 walk 시트 없음** → P2 결정대로 중립 회색 실루엣 placeholder 유지.
  그들의 walk 시트는 **나중에 AutoSprite로**(이건 Claude sprite-generation 도메인,
  지연). 우선 3종으로 ① 닫고 2종은 후속.
- **활성 링펫 팔로워**: `lingpet_companion` 걷기 자산 이미 존재 → 신규 자산 불요,
  플레이어 뒤 trail-follow 배선만(레거시 `bodyguard_follower` 패턴).
- **분담 변화**: ①이 AutoSprite 대작업(Claude)에서 → 배선(Codex/사용자) + Claude
  게이트로 바뀜. 잔여 Claude 자산 = 이오/코하쿠 walk 시트(후속, 소규모).

**② 건물 큼 + 크기 편차 + ②-b 맵 축소 (코드만) — 사용자 추가 지시**
- 현재 BUILDING_LAYOUT display_height 360~400px(캔버스 750의 ~절반)라 압도적.
  게다가 전부 360~400 구간이라 **건물 간 크기 차이가 안 느껴짐**.
- 두 가지 동시: (a) **전체 대역 하향** — 제안 **220~300px**(캐릭터 191px의
  1.15~1.55배, 거리감은 살되 안 압도). (b) **건물마다 크기 편차 확대** — 일률
  축소가 아니라 건물별로 다르게: 예 상점/선술집 ~220, 가챠/링펫 ~250,
  은행 ~280, 대장간/아카데미 ~300 (큰 건물 = 은행/대장간/아카데미 같은
  "무게감 있는" 기능). 편차가 유기적 갭 배치(③)와 맞물려 거리가 자연스러워짐.
  소스 PNG는 917~1077px라 재생성 불요 — display_height 필드 값만 조정.
- **맵 폭 축소**: 현재 MAP_SIZE 3040px(4스크린, 끝까지 ~12.6초). 사용자 요구
  "원본처럼 넓지 않게, 빠르게 건물 도달". 제안 **~1900px(2.5스크린, ~8초)** —
  건물 2~5개 유기 배치에 충분하면서 빠른 도달. 캡처로 미세조정.

**③ 랜덤 스폰 + 유기적 배치 (코드만) — 레거시 규칙 + 사용자 변형**
- 건물 수: 레거시는 3~7개였으나 **사용자 지시 = 2~5개**(맵이 작으니 적게).
  **은행 필수**, 아카데미 50%/상점 40%/가챠 40%, 나머지(대장간/선술집/링펫스토어)
  셔플로 2~5 범위 채움. 스테이지 시드(`seed + stage*1000`)로 스테이지마다 다른
  조합, 같은 스테이지는 안정.
- **유기적 갭 배치 (사용자 지시 — 균일 pivot 금지)**: 현재 고정 pivot
  (360/740/1120/…, 균일 ~380px)을 버리고, 좌→우로 건물 사이 갭을 랜덤
  (min_gap=붙음 허용 ~30~60px ↔ max_gap=뜨문뜨문 ~400px+)으로 시드 생성.
  "붙어있기도 뜨문뜨문 떨어져있기도" 룩. 은행은 스폰(좌측) 근처 우선. 겹침은
  건물 폭 기반 min_gap으로만 방지(완전 분리 강제 X — 살짝 붙는 건 OK/예쁨).
- 현재 Godot은 7동 항상 표시 → 매 방문(스테이지) 2~5 부분집합 + 유기 배치.
  map_seed를 plaza_save_store에 영속(레거시 downtown_map_seed) 검토 — 이어하기
  레이아웃 유지.
- 주의: 맵 폭/건물 수가 줄면 카메라 lead_x(현 100), EXIT존 위치(현 맵 우측 끝),
  interaction_rect 좌표가 새 MAP_SIZE 기준으로 재계산돼야 함(하드코딩 pivot 제거와
  함께 spec 생성을 맵폭 비례로).

**④ 미니맵 (코드 + 소량 자산)**
- 레거시는 탑다운 90/180px 우상단. 사이드뷰 광장이라 **가로 스트립 미니맵**으로
  재설계: 현재 `world_size.x`에 플레이어 위치 점 + 건물 마커 + EXIT 마커를
  매핑한 수평 바.

**실행 순서**: ③+②(코드만, 커플링·랜덤 스폰이 밀도 완화) → ④ 미니맵(코드만) →
① 기존 캐릭터 walk 시트 배선+링펫 팔로워. ①은 재조사로 신규 AutoSprite 자산
사이클이 사라져 코드 배선으로 축소. 전부 끝나면 S3 네온시티 양산 재개.

### 0.8.1 Codex 리뷰 반영 — 구현 계약 확정 (2026-06-14)

Codex 리뷰(P1×3 캐시/테스트/맵연쇄, P2×2 캐릭fallback/거래접근성, Open-Q×2)에
대한 Claude 판정. 배선 전 이 결정대로:

- **[P1 캐시·시드]** `build_building_specs(stage_id, map_seed)`로 시드 인자 추가,
  specs 캐시 키 = `"%d:%d" % [stage_id, map_seed]`. 고정 BUILDING_LAYOUT pivot
  제거, layout은 (map_seed + 맵폭)으로 유기 생성. 시드 출처 = plaza_save_store
  스테이지별 영속 map_seed.
- **[Open-Q2 시드 정책]** **스테이지 시드 고정**(방문마다 랜덤 아님). 첫 그 스테이지
  광장 진입 시 map_seed 1회 롤 → plaza_save_store 영속(레거시 downtown_map_seed
  대응) → 같은 세이브 내 같은 스테이지는 레이아웃 안정, 이어하기 화면 정합.
  세이브별로는 다른 조합(원본 감성).
- **[P1 테스트 분리]** `build_building_specs`에 `full_layout_for_test=false` 인자.
  true = 7동 전부(기존 메뉴 셸 커버리지 스모크 유지). 랜덤 모드(false)는 **별도
  단언**: 2≤count≤5, 은행 포함, 건물 rect가 min_gap 초과로 비중첩(살짝 붙음 허용은
  min_gap 자체로 표현), EXIT 도달 가능(맵 우측 끝 도달).
- **[P1 맵 축소 연쇄]** 하드코딩 3040·2980 전부 제거, `world_size.x` 기반 재계산:
  MAP_SIZE, EXIT_ZONE(우측 끝), 카메라 clamp, 플레이어 clamp,
  `plaza_scene_capture.gd` exit_right, 미니맵 스케일. 맵폭 = ~1900 시작,
  **1900~2100 캡처 튜닝 범위**(5동 최대 + 220~300 크기 + 유기 갭이 빡빡하면 상향).
- **[P2 캐릭 fallback]** 미카/세린/레나 실시트 우선. **이오/코하쿠 = 중립 걷기
  실루엣 placeholder**(현 디버그 시안 박스 아님 — 회색 틴트 실루엣 한 종)로
  시트 나올 때까지. 단계적 롤아웃.
- **[P2 거래 접근성]** 대부분 랜덤 유지(원본 감성) + **보정 1개만**: 활성 퀘스트
  보고가 due(accepted_stage < current_stage)면 **선술집 강제 포함**(단일 슬롯
  소프트락 방지 — 들고 있는 퀘스트 보고처가 사라지면 새 퀘스트도 못 받음).
  아카데미/상점 부재는 "다음 방문" 허용. 첫-광장 상점 튜토리얼 강제는 v1 스킵.
  → 즉 스폰 필수 규칙 = 은행 항상 + (보고 due 시) 선술집.

**구현 결과 (Codex, 2026-06-14)**:
- `plaza_save_store` schema v4에 stage별 `map_seed` 영속을 추가했다. 첫 진입 시 1회
  생성되고, 같은 세이브/같은 스테이지에서는 같은 랜덤 건물 배치가 유지된다.
- `PlazaAssetLoader.build_building_specs(stage_id, map_seed, world_width,
  full_layout_for_test, force_tavern)`로 전환했다. 일반 모드는 2~5동 랜덤, 은행 항상,
  due 퀘스트가 있으면 선술집 강제 포함. 메뉴 스모크는 `full_layout_for_test=true`로
  7동 전체 커버리지를 유지한다.
- Stage 1 런타임 맵폭은 1900px로 축소했고, EXIT/카메라/플레이어 clamp/캡처 위치는
  `world_size.x` 기반으로 갱신했다. 건물 표시 높이는 220~300px 범위로 낮춰 기능별
  크기 편차를 만들었다.
- ④ 미니맵은 새 자산 없이 `plaza_scene.gd` 오버레이 draw로 구현했다. 우상단
  가로 스트립에 현재 카메라 창, 플레이어 점, 이번 seed에서 스폰된 건물 마커,
  EXIT 마커를 `world_size.x`에 매핑한다. 메뉴가 열리면 모달 딤 아래에 남되 패널과
  직접 충돌하지 않는다.
- 캡처 하네스는 `--plaza-map-seed`와 임시 save path를 받아 재현 가능한 Stage 1
  확인 이미지를 만든다. 기준 캡처: `d:/tmp/plaza_s1_compact/`.

**+Claude 게이트 통과 (2026-06-14) — ③+②**: 40시드 불변식 프로브 **ALL PASS** —
count 분포 2:6/3:14/4:12/5:8(전부 2~5, 고른 분산), 매 시드 은행 포함·전 건물
월드 내(0~1900)·중심 간격 40px+(비중첩), `force_tavern=true`→선술집+은행 유지,
`full_layout_for_test=true`→정확히 7동. display_height 실측 shop/tavern 220 /
gacha/lingpet 250 / bank 280 / blacksmith/academy 300(360~400에서 하향+편차 적용).
시드 7·99 캡처: 유기 갭(군집+희소) + 작아진 건물 + EXIT 우측 여백 정상, 7동 압박
소멸. 당시 플레이어 placeholder는 ①에서 해소 예정. 비차단: 300px 건물(blacksmith/academy)이
크기 천장 — felt-QA에서 더 줄이고 싶으면 그때 조정. dirty의 lingpet 파일들은
③+②와 무관한 별도 진행 작업(향후 커밋 시 plaza만 격리).

**+Claude 게이트 통과 (2026-06-14) — ④ 미니맵**: 시드 7 캡처 픽셀 검증 —
스폰 위치=플레이어 점 좌측 끝+카메라 창 좌측, EXIT 위치=점이 우측 끝 EXIT
게이트 마커로 이동+카메라 창 우측, 건물 마커 5개(색상별)는 고정 world 위치 유지.
즉 player dot=위치 추적, camera window=뷰포트 추적, 건물/EXIT 마커=world_size.x
고정 매핑이 정확. 우상단 가로 스트립 가독 양호, 하단 메뉴 패널과 비충돌.

**+Codex 미니맵 품질 업그레이드 (2026-06-15)**: 기존 색상 막대 마커를 건물별
canonical `identity_emblem.id` 기반 badge로 교체. track 위 실제 world 위치 tick은
유지하고, 그 위에 금고/상점상자/가챠캡슐/링펫알/망치모루/의뢰서/책오브 픽토그램을
그린다. 마커가 가까울 때도 badge가 겹치지 않도록 미니맵 내부에서 X 위치를
최소 간격으로 정렬하고 tick→badge 연결선으로 실제 위치성을 보존한다. 실화면 캡처:
`d:/tmp/plaza_minimap_emblems/`, 확대 검증 `minimap_zoom.png`.

**+Codex 구현/게이트 통과 (2026-06-14) — ① 캐릭터+링펫 팔로워**: 플라자
player 렌더가 선택 캐릭터를 읽어 미카/스매셔, 세린/바이퍼, 레나/코만도는 기존
`*_subculture_idle_sheet.png` + left/right walk sheet(4×2, 8f)를 사용한다. 이오/
옵티머스, 코하쿠/발토르/blacksmith 계열은 시트가 생길 때까지 중립 회색 실루엣
fallback. 결과씬→광장 라우팅은 `selected_character_type`을 명시 전달한다. 활성
링펫은 owner의 `active_lingpet_id`/`current_lingpet_id`/`lingpet_id`와 companion
state를 읽어 `LingpetCatalog`의 `companion_walk` 시트로 플레이어 뒤를 trail-follow.
캡처 하네스는 `--plaza-character`/`--plaza-lingpet` 인자를 지원한다. 스모크:
`plaza_scene_smoke`가 3종 시트 로드, 2종 fallback, 링펫 follower 위치/추적을 단언하고
`stage_clear_result_plaza_routing_smoke`가 결과씬 선택 캐릭터 전달을 단언.
실화면 캡처: `d:/tmp/plaza_s1_player_smasher/`,
`d:/tmp/plaza_s1_player_viper/`, `d:/tmp/plaza_s1_player_soldier/`.

**+Claude 게이트 통과 (2026-06-14) — ①**: 캐릭터별 캡처 픽셀 검증 — 미카(smasher
바이오닉)/세린(viper 보라)/레나(commando 군장) 전부 실 스프라이트 렌더(시안 박스
대체 확인), 이오(optimus) = 중립 회색 실루엣 fallback(디버그 박스/크래시 아님),
링펫 핑크 companion이 player 뒤 trail-follow(smasher·optimus 캡처 확인). 방향별
walk 시트 우측 이동 렌더 정상. 비차단: player 스프라이트가 건물 대비 다소 작게
읽힐 수 있음(필요 시 draw-scale 조정), 이오/코하쿠 실 walk 시트는 후속 AutoSprite
(Claude 도메인, 지연).

**+Codex 표시 스케일 튜닝 (2026-06-15)**: 640×320 sheet의 4×2 프레임(160px)을
창 확대에서 억지로 키우지 않도록 plaza player draw size를 160→148px로 낮춤. 기존
시트/atlas는 변경하지 않고 런타임 표시만 조정. 캡처: `d:/tmp/plaza_player_scale148/`.

**→ Stage 1 정리 코드 4종(①②③④) 전부 게이트 통과 = Stage 1 광장 정리 패스 완료.**
잔여(전부 후속): 이오/코하쿠 walk 시트(소규모 AutoSprite), S2 게이트 끝난
S3~6 테마 양산 재개, 건물 테마별 재생성(6×7), 건물 v2 심화.

## 0.9 건물 진입 워프 디졸브 + 인테리어 씬 (2026-06-15 착수)

사용자 요구: 건물 상호작용 시 ①캐릭터(+링펫)가 ~1초간 제자리에서 빛으로 분해되며
위로 올라가 사라짐 → ②씬이 해당 건물 인테리어로 전환(좌측에 건물별 NPC, 예 상점=
상점주인 + 메뉴 UI) → ③나갔다 광장 복귀 시 빛이 다시 모여 캐릭터+링펫 재생성.
레퍼런스: KOF식 상점 UI(좌측 매니저 캐릭터 + 우측 메뉴/그리드 + 하단 인사 말풍선).
§8 "메뉴 다이얼로그 인테리어" 결정의 **시각 업그레이드** — 여전히 워커블 아님
(정적 NPC), 현재 immediate-mode 메뉴 셸 룩을 NPC 인테리어 씬으로 대체.

### 분담
- **Claude**: 워프 VFX 아트 디렉션(레시피), 인테리어 씬 레이아웃 설계, NPC 7종
  imagegen 브리프, 게이트.
- **Codex**: 워프 VFX 배선, 인테리어 씬 배선, **NPC 7종 imagegen 제작**(사용자 확정),
  스모크.

### A. 워프 디졸브 VFX (~1초, in/out)
- 상호작용 트리거 → 입력 freeze → 캐릭터 스프라이트(+활성 링펫)를 **상향 상승
  빛 입자로 분해** → 페이드아웃 → 인테리어 전환. 복귀 시 역재생(빛 응집→캐릭터/
  링펫 출현).
- **실루엣 게이트 필수** (메모리 `feedback_godot_materialize_silhouette_gate`):
  패딩 스프라이트 위 절차 디졸브는 베이크 알파 점유 마스크로 셀 게이팅 — 빈
  패딩이 반짝이면 안 됨. 분해 중 소스 프레임 고정.
- 재사용 패밀리: `smasher_warp_gate_fx_host`(GPUParticles aura/spark/streak) +
  `lingpet_acquire_cutin`(디졸브/재조립) 패턴. 1회성 인라인 셰이더 금지, 패밀리
  프리셋 공유. 신규 머터리얼은 PSO prewarmer 등록.
- 시간 VFX 트랩(메모리 `feedback_godot_immediate_rotation_tumble`): 1초 효과는
  t0 아니라 mid/late 캡처로 검증, 유계(상승량/입자수 bounded). plaza는 immediate
  `_draw`라 음수 z 금지(상승 빛은 z 상위 단일 트리).
- 링펫 포함: 활성 링펫 있으면 같이 분해/재생성(companion 위치에서 동일 디졸브).

### B. 인테리어 씬 레이아웃
- **풀스크린 오버레이(씬 체인지 아님)** 권장 — 워프아웃이 plaza를 가리고 인테리어
  오버레이를 띄움, 워프인이 역. plaza 모듈 상태 보존, 재진입 비용 0. 현 메뉴 셸
  오버레이의 확장.
- 레이아웃: **좌측 NPC 포트레이트 + 인사 말풍선(하단), 우측 메뉴/거래 패널**(기존
  bank/shop/blacksmith/gacha/lingpet/tavern/academy 트랜잭션 재사용 — 재배선 아니라
  리스킨). v1은 레퍼런스의 탭/아이템 그리드 없이 액션 리스트로(그리드는 v2).
- 모달 입력 계약 유지(인테리어 중 plaza 걷기/EXIT 차단, 닫기/ESC로만 복귀 →
  워프인). 거래 원자성/AP 방문당 1회는 기존 그대로.
- NPC 한글 이름/대사는 Godot 폰트(굽기 금지), 다국어 동기화 대상.

### C. 건물 NPC 7종 imagegen 브리프 (Codex 제작)
- 7종: 상점(상점주인)·은행(은행원)·가챠(가챠 오퍼레이터)·링펫스토어(링펫 사육사)·
  대장간(대장장이)·선술집(선술집 주인)·아카데미(교관). 각 건물 기능/엠블럼과 정체성
  연결(상점=금화/상자, 은행=금고, 대장간=망치·앞치마 …).
- 스타일: 리포 핸드페인티드 아니메 + 링피아 가상세계 사이버 톤. 좌측 배치용 반신/
  전신 포트레이트, 인사 포즈(손 흔들기 등 환영). 마젠타 크로마키 소스→누끼→알파 QA
  (chroma_key.py, remove_bg 금지). 경로 `godot/assets/ui/plaza/interior/`.
- 각 NPC manifest(정체성/포즈/소스/누끼 QA). 사이즈는 좌측 패널 표시 높이 기준
  (인테리어 레이아웃 확정 후 수치 고정).

### 슬라이스 순서 (권장)
1. **B 인테리어 레이아웃** placeholder NPC(회색 실루엣)로 — 씬 전환/모달/거래
   재사용 검증.
2. **A 워프 VFX** in/out — 디졸브 레시피 + freeze + 링펫 포함.
3. **C NPC 7종 imagegen** — 브리프대로 Codex 제작, placeholder 교체.
순서상 B+A로 "경험"을 먼저 닫고 C로 아트 채움. 게이트: 워프 in/out 캡처(mid/late
프레임, 실루엣 게이트·빈패딩 무반짝), 인테리어 NPC+메뉴 렌더, 모달 차단, 거래
원자성 회귀, 복귀 재생성.

### 0.9.1 v1 반영 — 워프 + placeholder 인테리어 (2026-06-15)

- **A 워프 VFX v1 반영**: 건물 상호작용 시 즉시 메뉴를 열지 않고
  `BUILDING_WARP_DURATION = 1.0s` 동안 `enter` 전환을 먼저 재생한다. 플레이어와
  활성 링펫 companion 위치를 고정하고, 반투명 페이드 + 시안/마젠타 상승 광선/링으로
  분해되는 느낌을 만든 뒤 기존 건물 메뉴를 연다. 닫기/ESC는 `return` 전환을 재생해
  빛이 다시 모이는 식으로 복귀한다.
- **입력 계약**: 전환 중 걷기/카메라/EXIT/건물 재상호작용을 모두 차단한다.
  기존 거래 메뉴가 열린 뒤의 AP 방문당 1회, 거래 원자성, ESC 닫기 계약은 그대로 유지.
- **B placeholder 인테리어 반영**: 현재 메뉴 셸을 중앙 작은 카드에서
  레퍼런스식 **좌측 NPC 실루엣 + 하단 말풍선 + 우측 거래 패널** 오버레이로 승격했다.
  NPC는 아직 회색 placeholder이며, 건물 타입별 이름/인사/색상만 다르게 표시한다.
  C 단계에서 Codex imagegen NPC 7종으로 교체.
- **게이트**: `plaza_scene_capture.gd`가
  `plaza_stage1_warp_enter_bank_mid.png`, `plaza_stage1_menu_bank.png`,
  `plaza_stage1_warp_return_bank_mid.png`를 남긴다. `plaza_scene_smoke`는
  enter/return phase, 1초 완료, 메뉴 지연 오픈, 전환 중 이동 차단을 단언한다.

**+Claude 게이트 통과 (2026-06-15) — B+A**: enter_mid 캡처=플레이어 위치 시안 링+
상승 빛, 스프라이트 페이드, 사각 박스 반짝임 없음(실루엣 게이트 OK). menu 캡처=
KOF 인테리어(좌 NPC placeholder "은행원 도우"+인사 말풍선, 우 은행 거래 패널+닫기+
원장) 정확. return_mid=역워프 빛 응집. **링펫 포함 코드 확정**: `_draw_lingpet_follower`가
actor_alpha로 페이드(line 896) + `_draw_building_warp_effect`가 링펫 위치에도 워프
draw(line 1007, `_is_lingpet_companion_visible()` 가드로 비활성 시 유령 워프 없음).
스모크 10/load check/경고 스캔 통과. NPC=의도된 placeholder(C 대기).

### 0.9.2 C 단계 NPC imagegen 브리프 — 치수 확정 (Claude → Codex)
인테리어 레이아웃 실측 후 C 브리프 수치 고정:
- **NPC 패널 = `INTERIOR_NPC_RECT` 244×420 logical px**(좌측, portrait ~0.58 비율,
  위치 (46,126)). 인사 말풍선 = `INTERIOR_SPEECH_RECT` 280×82 @ (40,584).
- **NPC 아트 사이즈**: 244×420 패널에 맞춤. 게임캔버스 render_scale(~1.22x) + 선명도
  고려 **소스 ≥2x(예 512×880 이상)로 제작 후 런타임 다운스케일**(캐릭터 선명도
  교훈: 다운샘플이 선명). portrait 세로 구도.
- 7종: 상점주인/은행원/가챠 오퍼레이터/링펫 사육사/대장장이/선술집 주인/교관.
  핸드페인티드 아니메 + 링피아 사이버, 환영 포즈(손 흔들기 등), 건물 기능/엠블럼
  정체성 결속. 마젠타 크로마키→`chroma_key.py` 누끼(remove_bg 금지)→알파 bbox/
  프린지 QA. 경로 `godot/assets/ui/plaza/interior/`, NPC별 manifest.
- 이름/인사는 현 `INTERIOR_NPC_NAMES`/`INTERIOR_GREETING_LINES` 사용(Godot 폰트,
  다국어 동기화 대상) — 아트 교체 시 placeholder 실루엣→PNG만 스왑.

### 0.9.3 C 단계 반영 — NPC 7종 imagegen 교체 (2026-06-15)

- **산출물**: `godot/assets/ui/plaza/interior/`에 7종 최종 PNG +
  `*_magenta_source.png` 원본 + `.import` sidecar + `plaza_stage1_interior_npc_imagegen_v1_manifest.json`
  + QA JSON 반입.
- **최종 PNG**: 512×880 알파 PNG. 244×420 logical 패널 안에서 런타임 다운스케일.
  `visible_magenta_pixels = 0`, `corner_alpha_max = 0`, 알파 bbox 패널 내부.
- **NPC 매핑**: 상점=모라, 은행=도윤, 가챠=루미, 링펫스토어=링링, 대장간=강철,
  선술집=하랑, 아카데미=서율. 이름/인사는 Godot 폰트 렌더 유지(이미지에 굽지 않음).
- **런타임**: `PlazaAssetLoader.INTERIOR_NPC_TEXTURE_PATHS`에서 PNG-first 로드/프리웜.
  로드 실패 시 기존 회색 실루엣 placeholder fallback. `plaza_scene_smoke`가 7종 파일
  존재, 512×880, 투명 모서리, QA의 마젠타 잔여 0, manifest 존재를 단언.

### 0.9.4 워프 VFX 고퀄 재설계 — 빛기둥(light pillar) (2026-06-15, 사용자 요구)

사용자 피드백: 현 워프(immediate-mode 절차 원/광선 = §0.9.1 v1)가 허접함. **빛기둥
승천** 연출로 격상 — 리포 모듈러 VFX 스택(정적 텍스처 조각 + 셰이더 + GPUParticles +
트윈) 사용. **타이밍/플로우 계약은 유지**(1초, 입력 freeze, 메뉴 지연 오픈, 복귀 시
역재생, 링펫 포함) — **비주얼만 교체**. 생산=Codex, 게이트=Claude.

**아키텍처 = 신규 `plaza_warp_pillar_fx_host.gd` (Node2D), `smasher_warp_gate_fx_host`
구조 클론**: quad+ShaderMaterial(`_core_materials`) + GPUParticles2D(aura/spark/
streak) + Tween(pulse/breath). 현 immediate `_draw_building_warp_effect` 대체. 액터
스크린 위치에 호스트 배치(plaza는 `_world_to_local(actor_world, scale)`; 외부 캔버스
자식이면 FX 호스트 공식 `game_offset+(playfield_pos+shake)*render_scale`). 플레이어+
링펫 각각 기둥(링펫 작게, `_is_lingpet_companion_visible` 가드).

**모듈러 4요소**:
- **텍스처 조각(정적)**: ①세로 빔 그라데이션(밝은 코어→소프트 시안/마젠타 엣지) ②지면
  임팩트 링/디스크 ③래디얼 글로우. VFX 프리미티브라 **베이크 그라데이션 허용**(writhe
  ember처럼) — 더 리치하게 원하면 imagegen. 투명 마진 충분히.
- **셰이더**: **`writhe_ember_material.gd` 패밀리 프리셋 재사용**(유니폼만 빛기둥 시안/
  마젠타로 스왑 — 1회성 인라인 셰이더 금지, 메모리 규칙). 빔 UV 위로 스크롤=에너지 상승
  읽기. 플리커=**이산시간 해시**(sin 금지, 전기/플라즈마 레시피). 액터는 노이즈
  임계 디졸브 마스크 + **실루엣 게이트**(빈 패딩 무반짝). 신규 머터리얼 변형→
  **battle_pso_prewarmer 등록**(첫-draw 히치).
- **GPUParticles2D**: 기둥 따라 상승 모트(위 속도, 페이드, additive) + 진입 시 지면
  버스트(외향). warp_gate aura/spark/streak 클론. **프리웜**.
- **트윈/AnimationPlayer**: erupt(스케일업 ~0.25s)→peak/hold(~0.5s)→collapse(~0.25s)=
  1초. 액터 살짝 상승+디졸브 동기. 강도 엔벨로프(메모리 mythic punch 트랩: phase_timer
  히트스톱 금지, 비주얼 엔벨로프로만). 복귀=역재생(빔 강하→액터 재구성→붕괴).

**트랩 체크리스트(메모리)**: 셰이더 패밀리 재사용 / PSO prewarmer 등록 / 파티클 프리웜 /
이산해시 플리커(sin 금지) / 액터 디졸브 실루엣 게이트 / FX 호스트 world-pos 공식 /
draw_set_transform 트랩(잔여 immediate 있으면) / 1초 시간VFX는 t0 아닌 mid·late 캡처 /
링펫 포함.

**게이트(Claude)**: 5컷 + warp enter/return **mid·late 프레임** 캡처 → ①빛기둥이 빔+
상승에너지+지면링+모트로 읽힘(허접 원/광선 탈피) ②액터 디졸브 실루엣 게이트(빈 패딩
무반짝) ③링펫 기둥 동반 ④1초 엔벨로프(erupt→peak→collapse) ⑤첫-draw 히치 없음(PSO
prewarm) ⑥복귀 역재생. §0.9.1 타이밍/입력/메뉴 계약 회귀 없음.

**Codex 반영 v1 (2026-06-15)**:
- `plaza_warp_pillar_fx_host.gd` 추가. 기존 `_draw_building_warp_effect`의 즉석
  원/광선 드로를 제거하고, `plaza_scene`은 transition actor state만 host에 전달.
- 구성: 프리웜 생성 세로 beam texture + `writhe_ember_material` 2겹 beam sprite
  + `ImpactShockwaveTextureCache` 지면 링 + `ImpactFlareTextureCache` core/glow
  + 상승 `GPUParticles2D` motes/streaks + pulse Tween. 별도 PNG sidecar 없이 기존
  effect cache 패턴으로 텍스처 조각을 런타임 프리웜 생성.
- 플레이어/링펫은 전환 중 alpha와 함께 약간 위로 상승해 빛기둥으로 분해/재구성되는
  느낌을 강화. `plaza_scene_smoke`는 transition 중 modular FX host 활성/actor slot
  전달/종료 후 hide를 단언.

## 1. 레거시 광장 시스템 요약 (포팅 대상 정의)

소스: `downtown/` (manager/renderer/map_generator/building_designs/player/npc 등),
진입 훅 `pingfighter.py:138705` `run_downtown_hub`.

- **구조**: 760x2000px 세로 스크롤 맵 (40px 타일 19x50), 카메라 Y만 스크롤
  (맵 폭 = 화면 폭 760). 스폰 하단 중앙 → EXIT 상단 중앙.
- **진입/퇴장**: 승리 화면에서 플레이어 선택 ("다음 스테이지로" / "광장으로 이동").
  퇴장 = EXIT 타일 / 열쇠(AP) 소진 / 세이브 NPC. 광장 번호 = "클리어한 스테이지".
- **바닥**: 이미지 에셋 0개, 100% 절차 드로잉. 타일별 결정적 해시 변형, 1회 베이크
  + 캐시. 지면/자갈길(cobblestone) 2종.
- **건물**: 13종 전부 절차 드로잉 (`building_designs.py` 4,855줄), 광장당 3~7개
  시드 배치 (은행 스폰 근처 고정, 길 인접 제약, 240px 간격).
  가용 7종: 은행 / 아카데미 / 상점 / 대장간(강화) / 가챠샵 / 아케이드 / 선술집 /
  투기장(AP 2). **카지노 = 게임위 심의로 비활성(포팅 금지)**, 4종(마법상점·펫샵·
  현자·미스터리)은 영업정지 닫힌 소품.
- **플레이어**: 패들 캐릭터 스프라이트 191px, WASD+방향키, 발밑 충돌박스, 8점
  샘플링, 0.5초 스턱 탈출.
- **경제**: 클리어 시 `ingame_gold → downtown_gold` 이관, 세이브 영속. 열쇠(AP)
  기본 3 / 최대 10 / 스테이지당 +1, 건물 입장마다 소모, 세션당 건물 1회 방문.
- **부가**: NPC 9종 + 세이브 NPC, 인장 기반 호위무사, 중앙 공연 스테이지(장식),
  건물별 워커블 인테리어 (`building_interior.py` 22.3k줄, 투기장 21.6k, 포커 7.5k).

포팅 함정 (레거시 분석에서 확정):
- 중첩 블로킹 루프 구조 → Godot은 씬/상태머신으로 재설계 (월클럭 쿨다운 누수 트랩).
- `renderer.py:1898-2330` 라이팅/포스트프로세싱 스택은 **호출되지 않는 데드 코드**
  — 패리티 범위 아님.
- `visited_buildings_this_session`은 타입 키 — 동일 타입 2동이면 락 공유.
- AP 재진입 시 +1 보너스 중복 지급 quirk (manager.py:441-445) — 포팅 시 수정.
- 매 프레임 `pingfighter.downtown_gold` 직접 갱신 → Godot은 스키마 선언된 owner
  필드 or 전용 스토어로 (Owner-Field Schema Trap).

## 2. Godot 현황 (조사 확정 사실)

- **광장류 시스템 0건.** godot/ 내 downtown 흔적은 포팅된 퍽 3종(보물지도/흥정/
  도박꾼)뿐. 계획 문서도 없음(이 문서가 첫 문서).
- **스테이지 클리어 흐름**: 배틀 씬은 6스테이지 내내 씬 체인지 없이 유지.
  `stage_clear_result_screen.gd`가 `stage_clear_result.tscn`을 z=1200 자식
  오버레이로 스폰 → "다음 스테이지" = `battle_scene_match_event_driver.gd`
  `_begin_stage_transition_loading` 인플레이스 전환(로딩 9스텝, 최소 2.2s).
  → **광장 훅 포인트 = `_finish_next_stage` 콜백 심.**
- **씬 컨벤션**: 프로덕션 .tscn 5개뿐, 전부 얇은 셸 + 순수 GDScript immediate
  `_draw()`. **TileMap/TileSet 사용 0건** — 도입하지 않는다. 반복 요소는
  아틀라스 + 하드코딩 spec 테이블(`BUSH_SPECS` 패턴)이 선례.
- **영속 세이브**: 설정류 + 링펫 2종뿐. **진행/골드 영속 스토어는 광장이 최초가
  된다.** 참조 패턴 = `lingpet_affinity_store.gd` (ConfigFile + 스키마 버전 +
  last_good 백업, UTF-8 BOM 트랩 준수).
- **재사용 가능 조각**: 걷기 컨트롤러 없음(링펫 patrol이 최근접), 대화 시스템
  없음(결과씬 클릭 말풍선이 씨앗), `character_live_preview`가 "씬에 서 있는
  캐릭터" 최고 선례.

## 3. 스테이지별 바닥 타일 테마 매트릭스

공통 사이버 시그니처(모든 스테이지): 타일 이음새 네온 헤어라인(스테이지 액센트
색), ~5% 타일에 은은한 데이터 글리프/회로 인레이, VR 기저 노출 컨셉.
팔레트는 전부 해당 스테이지 Godot 스크립트의 실제 Color 상수에서 추출.

| 스테이지 | 테마 | 바닥 컨셉 | 핵심 팔레트 (관측값) | 네온 액센트 |
|---|---|---|---|---|
| 1 달지 | 사이버 조선 | 조선 박석(薄石) 포장 + 한지등 빛 웅덩이, 먹남색 줄눈 | 잉크네이비 (4,8,22), 한지 크림 (255,246,220), 앰버 (0.82,0.60,0.28), 골드 (1.0,0.78,0.38) | 시안+마젠타 헤어라인, 단청 패턴 인레이 |
| 2 악어장군 | 정글 | 이끼 낀 석판 + 뿌리/덩굴 침식, 다진 흙 패치, 균열 암석 파편 | 딥그린 (0.045,0.105,0.075), 모스 (0.45,0.58,0.28), 흙그늘 (0.02,0.05,0.02) | 민트-시안 테크라인 (42,214,214), 데이터 덩굴 |
| 3 멘헤라걸 | 아키하바라 네온 시가 | 젖은 아스팔트 + 네온 반사, 점자블록(노랑), 맨홀/배수구, 파스텔 간판 빛 번짐 | 더티핑크+퍼플 야경(레거시 행성 표면 캐논), 파스텔핑크 (255,182,193), 라벤더 (230,190,255), 크림슨 (220,20,60), 다크플럼 (18,12,22) | 베이스 전면 노출 기준점 — 네온 사인 반사 그 자체 |
| 4 퐁크 | 사이버 사원 | 사원 석판 + 금박 만다라/연꽃 문양 인레이, 보랏빛 밤 그림자, 향초 금빛 모트 | 바이올렛 (0.09,0.075,0.12), 골드 헤일로 (0.94,0.70,0.28), 아이시 시안 (0.64,0.92,1.0), 레드문 (1.0,0.36,0.16) | 시안 홀로 기도륜, 금색 회로 문양 |
| 5 홍련 | 중화 화염 시장 | 짙은 적색 소성 벽돌 + 금 줄눈, 회문(回紋) 보더, 그을음/잔불 스페클, 등롱 빛 웅덩이 | 마룬 (0.12,0.045,0.035), 차이나레드 (220,38,38), 골드 (1.0,0.78,0.22), 엠버 (1.0,0.28,0.10) | 엠버-오렌지 회로 라인, 연꽃/팔괘 메달리온 |
| 6 테트리서 | 아케이드 테트리스 | 칠흑 웰(well) 바닥 + 희미한 시안 그리드, 베벨 석재 블록 보더, 파스텔 테트로미노 "떨어진 조각" 인레이 | VOID (0.005,0.006,0.015), GRID 시안틸 (0.05,0.14,0.20), 스톤 블루그레이 (0.55,0.56,0.68), RING_CYAN (0.05,0.84,1.0), GOLD (1.0,0.68,0.16) | 그리드 자체가 사이버 베이스, 네온레드 (1.0,0.08,0.16) 스트립 |

스테이지 3 캐논 근거: Godot 배틀 내부는 멘헤라 룸(파스텔 의료)이지만, 레거시
`ui/space_map.py:4689-4692`가 스테이지 3 행성 **표면/외부**를 "멘헤라/아키하바라
행성 표면 — 더티 핑크+보라빛 아키하바라 도시 야경"으로 정의 (간판 글리프/세로
네온 사인 포함). 옥외 공간인 광장은 이 외부 캐논을 따른다.

테마 선택은 `stage_id 1..6` 명시 dict로 게이트한다 (레거시 `% 5` 모듈로 금지 —
디버그 스테이지 id 8~12 존재, 7 없음).

## 4. 바닥 타일 제작 파이프라인 (Claude 자체 제작)

바닥 타일은 정적 텍스처 → **Gemini imagegen 레인 (AutoSprite는 애니메이션 시트
전용 규칙이라 해당 없음).** "그려줘" 라우팅 규칙대로 절차 드로잉 대체 금지.

- **논리/비주얼 분리**: 충돌·배치 논리 그리드는 레거시 40px 유지, **비주얼 바닥은
  512px 심리스 타일 텍스처**(논리 타일 여러 개를 덮음) + 액센트 타일 2~3종 +
  광장 중앙 메달리온 플레이트 1장. 페인터리 스타일에서 40px 타일 단위 생성은
  비현실적이고, 리포의 "큰 단일 페인팅 + 아틀라스" 컨벤션과도 정합.
- **프롬프트 규칙**: "seamless tileable texture, top-down, flat lighting(albedo),
  no shadows" 명시 + §3 매트릭스의 문화 모티프/팔레트 + 사이버 시그니처 지시.
- **심리스 검증 루프** (생성 후 매번):
  1. `magick tile.png -roll +256+256 rolled.png` — 이음새를 중앙으로,
  2. 이음새 밴드만 FLUX Kontext / Gemini edit로 인페인트 수정,
  3. `magick -size 2048x2048 tile:tile.png tiled.png` 2x2+ 반복 육안 QA
     (반복 경계가 보이면 불합격).
- **마감**: 필요 시 Real-ESRGAN 게이트(`realesr-animevideov3 -s 2`), lossless
  임포트(컨벤션: compress 0 / mipmaps off / size_limit 0), manifest JSON 동봉.
- **경로/명명**: `godot/assets/ui/plaza/` (비배틀 풀스크린 씬 컨벤션) +
  `plaza_stage1_floor_tile_cyber_joseon_imagegen_v1.png` 식 명명, `_source` /
  `_manifest.json` 형제 파일 규율.
- **파일럿 = 스테이지 1 "사이버 조선 5타일 미니셋"** (2026-06-13 확정 — 단일
  타일에서 격상). 광장 바닥은 한 장 그림이 아니라 "반복되는 바닥 문법"이므로,
  한 테마의 바닥 **시스템**으로 확장 가능한지를 세트 단위로 판정한다.
  **생산 주체 = Codex** (2026-06-13 라우팅 확정: 타일·건물 에셋 생산은 Codex,
  Claude는 아트 디렉션·레시피·프롬프트·수락 판정. Claude vs Codex A/B 경쟁
  비교는 폐기). 인게임 felt QA는 윈도우드 스크린샷 픽셀 검증.

### 4.1 5타일 미니셋 구성 (테마당 5~8타일 운용의 표준 코어)

| 타일 | 역할 | 제약 |
|---|---|---|
| `base_01` | 기본 바닥 (박석/마당) — 최다 반복 | 4x4 무경계 심리스 필수 |
| `base_02` | 변형 바닥 (어둡고 마모) — 반복감 깨기 | base_01과 섞어 깔아도 경계 무감지 |
| `accent_neon` | 사이버 인레이 (회로선/데이터 글리프, VR 기저) | 절제 — 건물보다 튀면 안 됨 |
| `border_dancheong` | 경계/길 타일 (단청·금선, 어도(御道) 콘셉트) | 길 축 방향 연속성 |
| `special_medallion` | 포인트 타일 (중앙 광장/상점 앞/포털, 문장·빛 웅덩이) | 광장당 소수 배치, 비반복 |

세트 공통 제약: **5장이 같은 팔레트·명암·브러시·줄눈 굵기를 유지**해야 한다.
각자 따로 뽑은 5장은 실격.

**제작 문법 — 마더 타일 파생 (Codex 적용 지시, S1 파일럿에서 실증 완료)**:
base_01의 심리스를 먼저 확정하고, 나머지 4종은 "돌 배치·줄눈·외곽 에지 보존"
조건의 Kontext/Gemini edit으로 파생한다. → 세트 일관성(팔레트·명암·브러시·
줄눈)과 크로스 타일러빌리티(섞어 깔기)가 구조적으로 보장되고, 같은 문법을
타 스테이지에 그대로 재사용할 수 있다.

**트랩 (S1 1차 게이트에서 실증, 2026-06-13): 장식 "픽셀 이식" 금지 — 파생은
반드시 현재 마더에서 edit으로.** 다른 마더(돌 배치가 다른 타일)에서 만든
네온/단청 장식 픽셀을 새 마더 위에 합성하면, 줄눈을 따라가야 할 네온이 돌
위를 가로지르는 낙서가 되고 단청 금선 밴드는 떠다니는 꽃 파편으로 해체된다
(accent_neon 발광 점유 0.5%·정렬 붕괴, border 방향성 소실로 리젝된 1차 사례).
마더가 교체되면 장식 파생은 전부 새 마더 입력의 edit으로 다시 뽑아야 한다.

**심리스 루프 (실증 완료)**: 호스티드 모델 직출력은 심리스가 안 된다 —
①생성 ②하프 롤(4분면 스왑)로 이음새를 중앙 십자로 노출 ③"중앙 심 라인만
수리, 외곽 에지 불변" edit ④수리본 자체가 심리스 타일(토러스 동일성, 롤백
불필요) ⑤재롤 + 2x2/4x4 반복판 검증. PIL 스크립트로 자동화 가능
(`d:/tmp/plaza_s1/` 참조). 단, **Kontext 심 수리는 네온/글리프를 지우고 전체를
재도색하는 드리프트가 있다** — 그래서 순서는 반드시 "무장식 베이스를 먼저
심리스로 확정 → 장식을 edit으로 추가"여야 한다 (역순이면 장식이 증발).

**네온 레이어 분리**: accent의 네온은 base와의 픽셀 diff로 **발광 오버레이
레이어를 추출**해 별도 보관한다. 런타임은 base 타일 위에 오버레이를 additive +
플리커 셰이더로 얹으므로, **네온 강도가 텍스처에 구워지지 않고 uniform으로
조절**된다 — 강도 판정이 슬라이더 비교가 됨. 건물 키트(§5.1)와 동일 철학.

**수락 판정 절차 (Claude 게이트)**: ①각 타일 4x4 반복판 ②760폭 광장 바닥
목업에 깔기(혼합 배치: base_01+02 믹스, 길 스트립, 메달리온) ③임시 건물
블록/191px 캐릭터 실루엣 얹어 가독성 확인 ④채점 4축 = 네온 강도 / 반복감 /
세계관 일치 / 건물 받침 역할. 합격 문법으로 스테이지당 5~8타일까지 확장 양산.

**S1 파일럿 중간 산출물 (Claude 생성분, 스타일 레퍼런스/마더 후보로 보존)**:
`d:/tmp/plaza_s1/` — `cand_A.png`(원생성 1024, 네온 절제 90/10), `cand_B.png`
(네온 강함 70/30, 비교용), `claude_base_01.png`(심 수리 완료된 무장식 박석
베이스 — 게임플레이 스케일에서 심 무감지, 1:1 줌에서 미세 밸류 스텝 잔존),
`claude_base_02.png`(마모 변형 파생), `claude_accent_neon.png`(네온 인레이
파생). Codex가 base_01을 마더로 이어받아도 되고 새로 시작해도 된다 — 단
어느 쪽이든 위 문법(베이스 먼저 심리스 → 파생)을 따른다.

## 5. 건물: 외부 에셋 vs 자체 생성 → **자체 생성 확정 권장**

시장 조사 결론 (웹 조사, 출처는 조사 보고서에 보존):

1. **조선/한옥 2D 게임 에셋은 사실상 시장에 없다.** itch.io "korea" 태그 5건 전부
   무관, 한옥은 3D(CGTrader/Unity/UE)뿐. → 어떤 구매 전략을 써도 간판 테마인
   스테이지 1은 결국 생성해야 하고, 그 순간 4테마 혼합 팩의 스타일 정합은 무너짐.
2. **나머지 테마(정글/네온시티/중화시장)도 구매 가능한 건 죄다 픽셀아트** —
   핸드페인티드 아니메 스타일과 하드 미스매치. 페인터리 계열(Daniel Thomas,
   KR 시리즈)은 서양 판타지/RPG Maker 비율로 역시 부적합.
3. **라이선스 함정이 AI 파이프라인과 충돌**: itch 신형 표준약관의 ML 데이터셋
   금지 조항 → 구매 에셋을 FLUX/Gemini img2img 참조로도 못 씀(격리됨). 단일
   프로젝트 라이선스류도 흔함.
4. **디제틱 요구**: 건물도 "VR에 소환된 구조물"로 홀로 트림/스폰 연출을 입혀야
   하는데, 외부 팩은 이 가공 자유도가 없음.

채택 전략:
- 건물 외관 = 스테이지별 imagegen 생성. **마젠타 크로마키 → 누끼 → 알파 QA**
  기존 파이프라인 그대로 (건물은 타일이 아니라 대형 알파 컷 스프라이트).
- 구역(스테이지 테마)당 **앵커 1장**을 먼저 확정하고 같은 edit 세션/스타일 참조로
  나머지 건물을 파생 — 시트 간 아이덴티티 락과 동일한 규율.
- 모든 건물에 링피아 공통 홀로 시그니처(외곽 네온 트림, 입구 홀로 사인) 적용.
- Kenney CC0는 **레이아웃 블록아웃 플레이스홀더로만** (출시 아트 금지).
- (선택) 참고 보드용 페인터리 팩 1~2개 구매 가능 — 출시 아트/AI 입력 금지 조건.

### 5.1 동적 건물 키트 구조 (2026-06-13 코덱스 리뷰 확정)

원본 광장 건물은 "살아있는" 동적 이미지였다 — 그리고 레거시 구현 자체가 정확히
이 구조였다: `building_designs.py`는 정적 본체를 1회 베이크하고 그 위에 네온
플리커/횃불/연기/파티클 **동적 오버레이를 매 프레임 얹는** 방식. Godot 포팅은
이 아키텍처의 에셋판으로 간다. 건물 1동 = 정적 1장이 아니라 **키트**:

| 파일 | 역할 | 제작 수단 |
|---|---|---|
| `*_building_base.png` | 정적 본체 (지붕/벽/입구 실루엣) | imagegen 정적 컷아웃 (AutoSprite 금지 — 프레임 간 구조 흔들림 리스크만 생김) |
| `*_sign_emissive.png` | 발광 간판/네온 마스크 | imagegen 또는 본체에서 분리 추출 |
| `*_sign_loop_sheet.png` | 간판 깜빡임/마스코트/가챠 캡슐 회전/천막 펄럭임 등 6~12f 루프 | **형태가 실제로 움직일 때만**; 시트로 만들면 리포 규칙상 AutoSprite 경유 |
| `*_window_glow_mask.png` | 창문/입구 빛 마스크 | imagegen 또는 추출 |

- **움직임의 1차 수단은 셰이더/트윈, 시트는 2차.** 네온 점멸·홀로 라인·입구
  포털·창 불빛 펄스는 emissive 마스크 + Godot canvas shader(additive pulse)/
  Tween으로 충분하고 시트가 아예 불필요. 플리커는 sin 금지 — 전기/플라즈마
  셰이더 레시피(이산시간 해시 재샘플 + 47Hz 플리커) 재사용, 셰이더 패밀리
  프리셋 공유(1회성 인라인 복사 금지). 형태 변형이 진짜 필요한 부품(마스코트,
  회전 캡슐, 펄럭이는 천막, 홀로 NPC)만 루프 시트로.
- **건물 식별은 글자보다 공통 그림 엠블럼이 우선이다.** 한글 깨짐 리스크와
  다운스케일 가독성 문제 때문에 imagegen에는 "상점/은행/아카데미" 같은 글자를
  굽지 않는다. 대신 각 기능 건물은 전 스테이지에서 동일한 픽토그램 엠블럼을
  사용한다. 건물 외관은 테마별로 완전히 달라도, 엠블럼만 같으면 플레이어가
  즉시 기능을 인식한다. Godot 폰트 텍스트는 접근 프롬프트/툴팁/선택 UI의
  보조 표기만 담당한다. 텍스트는 플레이어 노출 문구이므로 다국어 동기화 규칙
  적용 + CJK 폰트 폴백 트랩 주의 (명시 Nanum 전환 시 日/中 글리프 드롭).
- 신규 셰이더/머터리얼은 PSO prewarmer 컨텍스트에 등록 (첫-draw 히치 방지).

**키트 manifest 필드 (S3 착수 전 고정 — 7종 양산 시 런타임 배치 안정용).**
`plaza_building_<name>_manifest.json` 필수 필드:

| 필드 | 내용 |
|---|---|
| `asset_id` / `building_type` / `stage_theme` | 식별자 (예: gacha / stage1_cyber_joseon) |
| `layers.base` / `.emissive` / `.glow` | 각 레이어 res:// 경로 |
| `layers.loop` | res:// 경로 + `cols/rows/frame_count/fps` (시트 그리드는 per-asset authority) |
| `origin_pivot` | 발밑 기준점 px (base 좌표계) — 모든 rect/앵커의 원점 |
| `collision_rect` | 보행 충돌 rect (pivot 기준 px) |
| `interaction_rect` | 입장 인터랙션 존 (레거시 컨벤션: 하단 1/3 진입면) |
| `y_sort_anchor` | Y소트 기준선 (보통 pivot.y와 동일, 예외 시 명시) |
| `display_height` | 인게임 표시 높이(180~260 내 지정값) + 원본→표시 스케일 |
| `identity_emblem` | 기능 식별 엠블럼 id/설명/마스크 경로. 전 테마 공통이어야 함 |
| `provenance` / `qa` | 기존 manifest 컨벤션 (source/postprocess/edge_alpha/sha256) |

**공통 엠블럼 사전 (테마가 바뀌어도 동일).**

| 건물 | 기능 | 공통 엠블럼 |
|---|---|---|
| `shop` | 골드를 재화로 아이템 구매/판매 | 금화 + 작은 아이템 상자/보따리 |
| `bank` | 골드 저축/인출 | 금화 더미 + 금고 문 |
| `gacha` | 아이템 뽑기 | 투명 캡슐 + 회전 화살표 |
| `lingpet_store` | 링펫알 뽑기 및 링펫 관련 상점 | 빛나는 알 + 링 모양 궤도 |
| `blacksmith` | 아이템 강화 | 망치 + 모루 + 불꽃 |
| `tavern` | 퀘스트 수락 | 두루마리 의뢰서 + 컵/등롱 |
| `academy` | 액티브 스킬 획득/교환 | 펼친 책 + 스킬 오브 + 교환 화살표 |

엠블럼은 `emblem_panel` 또는 행잉 푯말 위에 얹는다. 외곽 실루엣과 건물 재료는
스테이지 테마마다 달라져야 하지만, 위 엠블럼의 형태 언어는 팔레트/재질만 테마에
맞춰 리스킨하고 도상 자체는 유지한다.

### 5.2 건물 키트 파일럿 (앵커 확정전, 생산 = Codex)

2026-06-13 라우팅 확정: Claude vs Codex A/B 경쟁 비교는 폐기. **Codex가 파일럿
키트 1벌을 제작**하고 Claude가 아트 디렉션·프롬프트 레시피 제공 + 수락 판정
게이트를 맡는다. 파일럿 합격 스타일이 앵커가 되고, 이후 7종 전부 같은
프롬프트/참조/후처리 규칙으로 생산. **최종 세트에 이질 화풍 혼합 금지.**

- **대상 고정**: 스테이지 1 "사이버 조선 상점" 1동 — 한옥 실루엣 + 단청/한지 +
  더 강한 사이버펑크 구조물 레이어 + **상점 공통 그림 엠블럼**. 빈 글자 간판은
  보조 패널로만 허용한다.
- **공통 스펙**: 3/4 front view, 마젠타(또는 투명) 배경, 캐릭터 없음, 그림자
  절제(접지 그림자 정도), 인게임 표시 높이 180~260px 기준(다운스케일 여유를
  위해 원본은 2x 이상으로 제작). 산출물은 §5.1 키트 4종 풀세트.
- **판정은 Godot 목업에서**: 760폭 광장 바닥(S1 파일럿 타일) 위에 얹어 간판
  점멸/입구 빛까지 켠 상태로 — 다운스케일 가독성, 충돌박스, Y-sort 느낌,
  알파 가장자리, 스타일 이질감 확인. 스크린샷 픽셀 검증 필수.
- **판정 기준** ("예쁜가"가 아니라): ①게임 화면에서 읽히는가 ②링피아 사이버
  시그니처가 있는가 ③나머지 7종으로 확장 가능한 문법인가 ④누끼/런타임 처리가
  쉬운가 — **+⑤건물-바닥 궁합**: 건물 네온이 바닥 accent보다 한 단계 밝게
  (시선 위계: 건물 간판 > 메달리온 > 바닥 회로), 바닥 380~512px/repeat
  스케일에서 돌 크기와 건물 디테일 밀도가 한 화면에서 충돌하지 않는가.
  **+⑥엠블럼 판독성**: 텍스트 없이도 240px 표시 높이에서 기능을 알아볼 수 있는가.

### 5.3 사이버 조선 상점 — 아트 디렉션 브리프 (Claude → Codex)

**실루엣 문법 (한옥이 55~65%, 사이버펑크가 35~45%)**
- 단층 한옥 상점: 기와지붕(팔작 또는 맞배, 처마 곡선이 실루엣의 핵심 읽기),
  나무 기둥 2~4개, 전면 개방형 점포(좌판/평상 힌트), 한지 창호 1~2면.
- 사이버 레이어는 "VR에 소환된 구조물" 디제틱: 지붕 용마루 또는 처마 밑선을
  따라 시안 네온 트림 1줄, 얇은 홀로 회로 레일/발광 브래킷/투명 디스플레이
  프레임을 더 적극적으로 사용한다. 마젠타 액센트는 기능 엠블럼 또는 모서리
  1곳에만 묶어 과포화는 피한다. S1 accent 타일보다 건물 쪽이 한 단계 더 밝다.

**팔레트 앵커 (S1 타일·스테이지1 상수와 결속)**
- 기와: 먹남색 계열 `(4,8,22)`~슬레이트 — S1 줄눈과 같은 어둠 패밀리.
- 벽/창호: 한지 크림 `(255,246,220)` — S1 돌 면과 같은 따뜻함 패밀리.
- 기둥/목재: 앰버 `(209,153,71)` 근방.
- 단청: border 타일의 금선 패밀리(회문/연판), 처마 밑에만 절제 적용.
- 네온: CYAN `#00E5FF` / MAGENTA `#FF1FC2` (스테이지1 상수 그대로).

**그림 푯말/엠블럼 스펙 (한글 굽기 금지 — §5.1)**
- 입구 위 또는 처마 아래에 `emblem_panel` 1개 필수. 상점 파일럿의 공통 엠블럼은
  **금화 + 작은 아이템 상자/보따리**다. 이 엠블럼은 이후 정글/네온시티/중화시장
  등 다른 테마 상점에도 동일한 도상으로 반복된다.
- 가로 홀로 패널/세로 행잉 배너는 보조 장식으로만 사용한다. 텍스트 공간을 크게
  비우는 것보다, 240px 표시 높이에서도 읽히는 단순한 그림 푯말을 우선한다.
- 엠블럼 프레임과 지붕 트림만 네온 발광. 엠블럼 내부는 금화/상자 실루엣이
  또렷하게 보이도록 밝기 대비를 확보한다.

**레이어 분리 레시피 (S1 검증 문법의 건물판)**
1. `building_base` 생성: 네온/발광 전부 꺼진(또는 미점등) 상태의 깨끗한 본체.
   마젠타 배경, 접지 그림자만.
2. edit ①: "본체 불변, 엠블럼 패널+지붕 네온 트림만 점등" → base와 diff →
   `sign_emissive`.
3. edit ②: "본체 불변, 한지 창호/입구만 따뜻한 크림-골드 발광" → diff →
   `window_glow_mask`.
   (두 edit을 분리해야 마스크가 깨끗하게 갈라진다 — 한 번에 다 켜고 색상으로
   가르는 것보다 안전.)
4. `sign_loop_sheet`는 v1에서 생략 가능 — 점멸은 emissive + 플리커 셰이더
   (이산시간 해시, sin 금지)로 충분. 형태 변형 부품이 생기면 그때 AutoSprite.
5. 누끼: `chroma_key.py` 사용 (remove_bg.py는 흰색 전용 — 마젠타에 쓰면 조용히
   실패). 알파 bbox 비에지터치 + 마젠타 프린지 0 QA.

**스케일/배치 계약**
- 표시 높이 180~260px(플레이어 191px와 동급~약간 큼), 원본 2x+ 제작.
- manifest 필수 필드(§5.1 표) 전부 기입: origin_pivot(발밑), collision_rect,
  interaction_rect(하단 1/3 진입면), y_sort_anchor, display_height.
- 목업: S1 바닥(base 믹스+어도+메달리온) 위 760폭, 380~512px/repeat 스케일,
  191px 실루엣 동반, 간판 점멸 ON 상태 스크린샷.

## 6. 런타임 통합 설계 (권장안 — 배선은 Codex/사용자 영역)

- **삽입 위치**: 결과 스크롤 단계에 "광장으로" 버튼 추가(레거시처럼 선택적).
  광장 = `plaza.tscn`을 배틀 씬 자식 풀스크린 오버레이로 스폰
  (`stage_clear_result` 선례 그대로, z/프로세스 모드 동일 패턴). 닫으면 기존
  `_begin_stage_transition_loading` 인플레이스 전환으로 복귀.
  → 씬 체인지 방식은 스테이지마다 배틀 재부팅(로딩 최적화 무효화)이라 기각.
  단, 광장 체류 중 유휴 시간에 다음 스테이지 `battle_entry_background_prewarm`
  류 백그라운드 프리웜을 돌리는 보너스는 챙길 것.
- **렌더링**: Control + immediate `_draw()` 렌더러. 바닥 = 심리스 타일
  `draw_texture_rect_region` 루프(가시 영역 컬링), 건물/소품 = spec 테이블 배치
  + Y소트. TileMap 도입하지 않음. 레터박스 필러 크롬은 **해당 스테이지의 기존
  필러 백플레이트 재사용** (추가 아트 0으로 테마 일관성 확보).
- **좌표**: 게임 캔버스 760폭 유지, 맵 760x2000 Y스크롤 (레거시 카메라 모델
  포팅: smoothing 0.08, lead_y 100). 플레이필드 = 풀 760 규칙 준수.
- **로딩**: `plaza_prewarm` 잡 리스트 (`character_select_prewarm.gd` 패턴).
  핫패스 lazy init 금지 — 타일/건물 텍스처는 광장 진입 전 프리웜.
  size_limit 걸리는 대형 시트가 생기면 `load_imported_texture` 필수
  (raw-first 바이패스 트랩).
- **세이브**: 신규 `user://plaza_save.cfg` (스키마 버전 + last_good 백업,
  `lingpet_affinity_store.gd` 패턴). 광장 골드/열쇠/맵 시드 영속.
- **화폐(결정 필요)**: 권장 = 레거시 모델 유지 — 클리어 시 `runtime_perk_gold` →
  `plaza_gold` 이관(전투 내 퍽 골드는 휘발 유지). 스타포인트는 절대 직결 금지
  (STARPOINT_PER_SKILL_CHOICE=1 단위 트랩).
- **걷기**: 신규 plaza_player 모듈 — 속도 4px/frame-60, 발밑 충돌박스, 축분리
  이동, 스턱 탈출. 스프라이트는 캐릭터 셀렉트 라이브 프리뷰 자산 재사용 검토.

### 6.1 S4 광장 셸 — 배선 계약 + 트랩 체크리스트 (Claude → 배선측)

**플로우 계약 (결과씬 버튼 → 광장 → 기존 전환 복귀)**
- 버튼: `stage_clear_result_navigation_action_handler`에 세 번째 액션 추가
  (`BUTTON_PLAZA → ACTION_ENTER_PLAZA`). 기존 두 액션의 콜백 시맨틱은 불변.
- 진입 시퀀스: 보상 지급(기존 `_finish_next_stage` 선두 로직) → 결과 오버레이
  해제 → **plaza.tscn을 배틀 씬 자식으로 스폰** (stage_clear_result 선례:
  z 상위, 프리웜 게이트 스폰) → 광장 퇴장(EXIT 존/ESC 확인) 시
  `_reset_game_after_stage_clear` 콜백 그대로 호출 → 기존
  `_begin_stage_transition_loading` 인플레이스 전환. **광장은 콜백을 "지연"만
  시키고 시맨틱을 바꾸지 않는다.**
- 광장 테마 = 클리어한 스테이지(`owner.current_stage`), 전환 전 시점이므로
  스테이지 번호 혼동 없음. 테마 dict는 stage_id 1..6 명시 매핑(§3, 모듈로 금지).

**렌더러 계약**
- Control + immediate `_draw()`. 캔버스 760x750, 맵 3040x750,
  카메라 X 스크롤(0..2280), smoothing 0.08 + lead_x 100. 레터박스는
  기존 배틀 캔버스 계약을 유지하고, 광장 자체는 `clip_contents = true`.
- 바닥/지면: **repeat 380 고정**(§S3 판정), 기존 S1 타일을 보도 밴드에
  재활용하고, 전면 단면은 VR 데이터 지층 스트라타로 표시. v1은 accepted
  타일 + 절차 단면으로 시작, 전용 지면 스트립 비트맵은 후속 미감 패스에서 교체.
- 배경: 원경 하늘/달, 중경 담장/뒷골목, 근경 워크라인+건물 파사드 순서로
  draw order 고정. 음수 z 없이 단일 `Control` `_draw()` 안에서 컬링.
- 건물: manifest의 origin_pivot/source_size/layers/identity_emblem을
  **로드 타임에 1회 파싱**해 spec 테이블화. 횡스크롤 v1 런타임은
  거리 X열 배치와 display_height 320~420을 적용하고, 건물은 배경 파사드라
  `collision_rect` 없이 `interaction_rect`만 사용.
- 발광: base 위 emissive를 additive로. 플리커는 이산시간 해시 셰이더(sin 금지,
  전기/플라즈마 레시피 재사용). v1은 셰이더 없이 정적 additive로 시작해도 됨
  — 단 셰이더를 넣는 순간 PSO prewarmer 컨텍스트 등록 필수.

**걷기/충돌 계약**
- 속도 4px/frame-60 — 반드시 `delta * 60` fps_scale 컨벤션(`ball_update_controller`
  동일). v1은 좌우 이동만 허용하고 Y는 단일 지면 라인(GROUND_Y)에 고정.
- 인터랙션: 건물 파사드 앞 X 구간 + Space/Enter/클릭 →
  v1은 "건물명 + 준비 중" 다이얼로그(메뉴 다이얼로그 본체는 S6).

**트랩 체크리스트 (전부 리포 기지 트랩 — 배선 전 1회 정독)**
1. **Hot-Path Lazy Init**: 광장 스폰 전에 타일/건물/emissive 텍스처 프리웜
   (`character_select_prewarm.gd` 잡 리스트 패턴). `_draw` 첫 프레임에 1024px
   PNG 디코드 금지. 결과씬 표시 중 백그라운드 프리웜이 이상적.
2. **Owner-Field Schema**: 광장이 `owner.set()`으로 주고받는 키가 생기면
   `battle_scene_state.DEFAULT_VALUES` 선언 필수 (미선언 = 조용한 no-op).
   v1 권장: owner에 새 키를 만들지 말고 plaza 모듈 내부 상태로 유지.
3. **음수 z / 조상 불투명 풀필**: plaza 오버레이는 z 상위 단일 트리로 —
   배틀 캔버스 위에 음수 z 자식 금지.
4. **draw_set_transform**: `_draw()` 내 사용 시 IDENTITY 리셋 금지 패턴 준수,
   연속회전 텀블 금지(시간 VFX는 유계 진동).
5. **컨피그/카탈로그 딥카피 핫패스**: 건물 manifest/spec을 매 프레임
   `.duplicate(true)` 금지 — 읽기전용 공유 ref.
6. **레터박스 클립**: 플레이필드는 풀 760 — 인트로/오버레이 클립을 80..680으로
   좁히는 레거시 컨벤션 적용 금지.
7. **FX 호스트 좌표**: 외부 캔버스 자식을 쓰게 되면
   `game_offset + pos * render_scale` 공식 (offset만 더하는 실수 금지).
8. **스모크 최소 세트**: ①결과씬 3버튼 라우팅(광장 진입/스킵 모두 기존 리셋
   콜백 의미 보존) ②광장 퇴장 → `_begin_stage_transition_loading` 도달
   ③좌우 이동 + 지면 Y 고정 + X 카메라 전진 ④인터랙션 존 판정
   ⑤테마 dict가 stage 1..6 외 입력에 fallback. 스크린샷/픽셀 검증 1회
   (매몰 트랩 예방).

## 7. 슬라이스 계획

| 슬라이스 | 내용 | 산출물 |
|---|---|---|
| S1 바닥 파일럿 | ✅ **완료 (2026-06-13)** — Codex 5타일 미니셋 + emissive 3종 반입(`godot/assets/ui/plaza/` + manifest), Claude 4축 게이트 2라운드 통과(1차: accent/border 리젝→재작업), **바닥 문법 앵커 락**. 수락 보드 `d:/tmp/plaza_s1/claude_gate2/final_acceptance_board_760.png`. 타일 단독 표시 스케일은 380~512px/repeat 범위, 건물 목업 기준 런타임 기본값은 380px/repeat | 미니셋 5종 + 발광 3종 + 판정 보드 + 레시피 확정 |
| S2 바닥 전개 | 🟡 **런타임 슬롯 완료 + Stage2 패럴랙스 아트 반입 (2026-06-14)** — `plaza_theme_catalog`에 stage2~6 `asset_slug` 확정, `plaza_asset_loader`는 스테이지별 floor/parallax manifest 우선 + 누락/미import 항목 S1 fallback. Stage2 `jungle_relic` v1 패럴랙스 4레이어(ground/ground_emissive/midground/sky)와 manifest 반입, import sidecar 생성. `plaza_scene_smoke`가 stage2 manifest override와 실제 prewarm 로드를 검증. Stage3~6 지면 스트립/중경/원경 비트맵 제작은 후속 아트 패스 | manifest 슬롯 ✅ / Stage2 패럴랙스 ✅ / Stage3~6 미생산 |
| S3 건물 키트 파일럿 | ✅ **완료 (2026-06-13)** — 상점 v2 키트(base+sign_emissive+window_glow+manifest) 게이트 합격, 재제출 목업 floor380 기준 ⑤건물-바닥 궁합 통과 → **건물 문법 앵커 락** (한옥 외관 + 공통 엠블럼 푯말 + 2-edit 발광 분리). **런타임 바닥 repeat 기본 = 380** — 512는 메달리온 주변 돌 이질감이 패치로 드러나고 필드 타일 혼합 불일치가 보여, 메달리온 surround를 base_01 스타일로 재파생하기 전까지 비권장 | 상점 앵커 키트 + 6종 양산 개시 가능 |
| S4 광장 셸 | ✅ **횡스크롤 전환 완료 (2026-06-13)** — `plaza.tscn` 오버레이와 결과씬 3번째 버튼(`BUTTON_PLAZA → ACTION_ENTER_PLAZA`) 플로우는 보존. 렌더러는 패럴랙스 3층 + S1 보도 밴드 + VR 데이터 지층 단면으로 전환, 초기 셸은 맵 3040x750 / X 카메라 / 좌우 이동 + 지면 Y 고정 적용. 건물 7동은 거리 X열 배치와 320~420px 표시 높이로 재스케일, 충돌 없는 배경 파사드 + interaction_rect 방식. 스모크: `plaza_scene_smoke`, `stage_clear_result_plaza_routing_smoke`, 결과 화면 계열 통과. **+Claude 픽셀 검증 통과 (2026-06-13)**: 윈도우드 5컷 캡처(`tools/plaza_scene_capture.gd` → `d:/tmp/plaza_s4/`)로 음수z 매몰 트랩 회피·건물-바닥 궁합 ⑤축·엠블럼+한글 폰트 라벨 동시 판독 확인. **Stage 1 정리 패스(2026-06-14)**에서 런타임 기본 맵폭은 1900px, 건물 표시 높이는 220~300px, 건물 수는 stage map_seed 기반 2~5동 랜덤(은행 항상, due 퀘스트 시 선술집 강제)으로 재조정. 미감 펀치리스트는 S4.5에서 전용 에셋으로 해소 | 걸어다닐 수 있는 횡스크롤 거리 ✅ |
| S4.5 미감 패스 | ✅ **완료 (2026-06-13)** — §0.6 브리프 기준 절차 placeholder 4레이어를 전용 에셋으로 교체: 지면 스트립+VR 단면, 중경 한옥 담장, 원경 하늘/웜톤 달/구름. 기존 S1 medallion/accent는 side-scroll 투명 컷아웃으로 파생해 사각 패치감 제거. 배선은 fallback 유지 + 새 PNG 우선 로드. 5컷 재캡처 완료, `plaza_scene_smoke`/라우팅 스모크/경고 스캔/헤드리스 로드 통과. **+Claude 게이트 통과 (2026-06-13)**: 5컷 픽셀 검증 — 음수z회피·시선위계(건물>중경>원경)·VR단면 디제틱 가독↑·녹색달/알약구름 소멸·**X심리스 정량 0.00**(live ground 1140×154=FLOOR_REPEAT380×3, wall 960×180=tile320×3; far_sky 1520×430은 parallax0.04 비타일 atlas라 edge델타 3.5 무영향) | 룩 잡힌 거리 ✅ |
| S5 건물 양산 / 런타임 절반 | ✅ **완료 (2026-06-13)** — 에셋: 6종 키트(은행·가챠샵·링펫스토어·대장간·선술집·아카데미) + 상점 포함 7동 게이트 합격. 런타임: 기존 `_discrete_flicker` CPU 경로를 지면/strata/cutout/건물 per-instance seed로 확장(shader/PSO 없음), placeholder 토스트를 7종 메뉴 셸로 교체(상점 구매/판매, 은행 예금/출금, 가챠 뽑기, 링펫 알/관리, 대장간 강화, 선술집 퀘스트, 아카데미 스킬 획득/교환). 메뉴 중 이동/EXIT 차단, ESC/닫기 복귀, 거래 action은 S6 전까지 disabled stub. 스모크/캡처/경고/로드 통과. **+Claude 게이트 통과 (2026-06-14)**: 메뉴 셸 픽셀 검증(상점 타이틀/서브/닫기/01구매·02판매 스텁/모달 딤 정상)·per-instance flicker 2틱 diff(건물 셀별 독립 변조, 지면 strip은 전폭 x279~1206 서브임계 잔잔 변조 — 시선위계 사인>지면 정합)·모달 입력 2겹 차단 코드 확인(update_plaza early-return + handle_plaza_input 라우팅) | 기능하는 광장 1차 ✅ |
| S6 경제/세이브 | ✅ **S6a 완료 + S6b-1 은행 v1 + S6b-2 상점 v1 + S6b-3 대장간 v1 + S6b-4 가챠샵 v1 + S6b-5 링펫스토어 v1 + S6b-6 아카데미 v1 + S6b-7 선술집 v1 완료 (2026-06-14)** — S6a: `scripts/plaza/plaza_save_store.gd` 추가(`user://plaza_save.cfg`, schema v1, `.last_good`, BOM strip+무BOM 재저장, recovery_blocked, load/save summary). 결과씬 진행 edge에서 `runtime_perk_gold`를 `plaza_gold`로 1회 이관하고 owner 휘발 골드는 0으로 소비, AP는 BASE 3/MAX 10 기준 스테이지별 1회만 +1 기록. 광장 status가 `plaza_gold`/`ap_current`를 읽음. **S6b-1 은행**: store schema v2(`bank_deposit_gold`, `bank_interest_claimed_stages`), 은행 메뉴 stub 해제(예금/출금 100G, 이자 정산), 첫 성공 은행 처리만 AP 1 소모·같은 메뉴 방문 후속 처리 무소모, 이자 5% 스테이지당 1회. **S6b-2 상점**: `plaza_shop_transactions.gd` 추가, 결과씬→광장 owner/registry 전달, 액티브 아이템 `벽돌 80G`/`부메랑 120G` 구매 + 마지막 액티브 아이템 판매(구매가 50%, fallback 40G), 첫 성공 거래만 AP 1 소모. **S6b-3 대장간**: `plaza_blacksmith_transactions.gd` 추가, 마지막 액티브 아이템 +0~+10 강화 attempt(비용 100→900G, 성공률 80→23%, 실패/유지 시 아이템 유지+골드만 소모), 첫 성공 attempt만 AP 1 소모. **S6b-4 가챠샵**: `plaza_gacha_transactions.gd` 추가, active catalog field-spawn pool weight 기반 액티브 캡슐 뽑기 150G, 실제 `active_item_runtime.grant_item_to_slot(..., false)` 지급, 레전더리/미식/패시브/크레인/스테이지클리어 가챠 풀 미접촉. **S6b-5 링펫스토어**: `plaza_lingpet_store_transactions.gd` 추가, 공명 알 뽑기 250G, 직접 링펫 grant 없이 `lingpet_egg_runtime.spawn_plaza_resonance_egg()`로 미확인 알만 열고 공 충돌 부화 시 기존 런타임이 소유/슬롯 반영. **S6b-6 아카데미**: `plaza_academy_transactions.gd` 추가, `스킬 수업 200G` 성공 시 기존 `RuntimePerkState` 선택 모달을 `exclude_instant=true`로 열고 광장 메뉴/이동/EXIT를 차단, 스킬 교환은 v1 stub. **S6b-7 선술집**: `plaza_tavern_transactions.gd` 추가, `의뢰 받기`/`의뢰 보고` 2액션으로 현재 스테이지 수락→다음 스테이지 클리어 후 보고→보상 골드 지급을 `plaza_save_store` schema v3 영속 장부에 기록. 스모크: `plaza_save_store_smoke`, `plaza_bank_menu_smoke`, `plaza_shop_menu_smoke`, `plaza_blacksmith_menu_smoke`, `plaza_gacha_menu_smoke`, `plaza_lingpet_store_menu_smoke`, `plaza_academy_menu_smoke`, `plaza_tavern_menu_smoke`, `stage_clear_result_plaza_routing_smoke`, `plaza_scene_smoke`, `stage_clear_result_screen_smoke`, `stage_clear_result_navigation_action_handler_smoke` 통과. **후속**: 선술집 v2는 전투 목표 추적형 quest 도메인을 별도 체크리스트로 설계. **+Claude S6a 게이트 통과 (2026-06-14)**: 계약 §6.3 트랩 4종 코드 검증 — ①골드 이중카운트=`_stage_clear_gold_transfer_consumed` 1회 읽기+제로화, `show_from_scoreboard`에서 리셋(새 클리어마다 재이관 허용) ②AP 재진입 중복=**2겹**(결과씬 `_stage_clear_ap_grant_consumed` + 스토어 영속 `_ap_awarded_stages[stage]`), 스토어 층이 세이브 섹션이라 이어하기 재진입도 무지급=레거시 manager.py:441 버그 분기 수정 ③스타포인트 단위=이관이 `runtime_perk_gold`(골드 단위)만 읽음, ★/starpoint 미접촉 ④BOM=load strip+무BOM 재저장+last_good 복구+parse-break 가드 | 영속 진행 ✅ / 7동 실거래 ✅ / quest v2 후속 |
| S7+ | NPC/호위무사/공연 스테이지/워커블 인테리어/투기장 | 후속 확장 |

다음 런타임 우선순위는 선술집 v2 전투 목표 추적 퀘스트 도메인 또는 광장 felt-QA 보강이다.

512px/repeat 백로그: S3 최종 게이트에서 380px/repeat는 통과했지만, 512px/repeat는
`special_medallion` 주변 돌이 사각 패치처럼 드러난다. 512 스케일을 다시 쓰려면
메달리온 surround를 `base_01` 스타일/에지로 재파생하고 필드 타일 혼입을 제거한 뒤
건물-바닥 궁합 목업을 재검증한다.

분담 (2026-06-13 확정): **타일·건물 에셋 생산 = Codex** (생성·후처리·누끼·
repo 반입·배선·스모크) / **Claude = 아트 디렉션·프롬프트 레시피·테마 매트릭스·
수락 판정 게이트·적대 리뷰**. 이 문서의 §3 매트릭스 + §4.1 제작 문법 + §5.1
키트 구조가 Codex 핸드오프의 단일 소스다.

## 8. 결정 목록 — 전부 확정 (2026-06-13)

- 건물 = 정적 imagegen 본체 + 동적 레이어 키트(§5.1), 시점 = 3/4 front view,
  간판 = 그림 엠블럼(전 테마 공통 사전), 앵커 스타일 단일 락 (§5.2).
- **화폐 모델 확정**: 클리어 시 골드 이관(`runtime_perk_gold` → 광장 골드) +
  열쇠(AP) 시스템 유지. 스타포인트 직결 금지 유지.
- **인테리어 1차 확정**: 메뉴 다이얼로그로 시작, 워커블 룸은 후속 확장.
  투기장/미니게임은 별도 대형 프로젝트 — 게임위 등급 제약(카지노 금지,
  도박류 신중) 명시 유지.
- **펫샵 → 링펫스토어 전환 확정**: 키트 제작 완료.
- **광장 입장 확정**: 결과씬 선택 버튼(강제 경유 아님) — 전투 루프 템포 보존.
