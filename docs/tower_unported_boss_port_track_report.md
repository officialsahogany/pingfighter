# 미포팅 보스 4종 포팅 트랙 보고서

- 기준 커밋: `4164b043b2c7e1efa04beb81f4787ab04a9e1a5e`
- 작업 브랜치: `codex/tower-unported-boss-port-4164` (로컬 전용, push 없음)
- 금지 경계: `godot/scripts/tower_ascent/**`, `tower_ascent_tuning.gd`,
  `tower_ascent_boss_registry.gd` 대역 매핑 무수정
- 전체 상태: 진행 중 (두더지왕 완료, 다음 보스 미착수)

## 두더지왕

### 1. 커밋과 파리티 조사

- 독립 커밋: 이 섹션과 두더지왕 구현을 함께 담은 커밋. 최종 인계 감사에서
  실제 커밋 해시로 치환한다.
- 원본 실제 호출 경로:
  - 보스 패들 접촉부에서 게이지 `+60` 후, 땅굴습격 중이 아니고 20초
    쿨다운이 끝났으며 게이지가 60 이상이면 회전발톱을 즉시 발동한다.
  - 일반 업데이트부에서 8초 쿨다운·게이지 500·회전발톱 비활성 조건을
    만족하면 땅굴습격을 발동한다.
  - 플레이어 4점 획득 시 친구두더지를 예약하고 다음 라운드부터 정확히
    2라운드 동안 90프레임 간격으로 황금 두더지를 생성한다.
- 수치·타이밍:
  - 땅굴습격: 경고 30f, 가시 10개/4f 간격, 타격 40f, 귀환 60f,
    근거리 `<100px` 넉백 14 + 스턴 60f, 외곽 `<160px` 넉백 7.
  - 회전발톱: 게이지 60, 쿨다운 20초, 이펙트 30f, 공의 좌우 입사에
    반대되는 스와이프 방향.
  - 친구두더지: 반지름 18, 상승/유지/하강 12f/60f/12f, 접촉 시 Y 반사와
    X `-1.5..1.5`, 황금 개체 스타포인트 생성.
- 파리티 예외:
  - 원본 캐릭터는 비트맵 시트가 아니라 `entities/molewang_boss_sprite.py`의
    절차형 자산이다. 동일한 갈색 몸체·분홍 코·왕관·지면 융기·발톱·가시
    어휘를 Godot 절차형 렌더러로 이관했다.
  - GRT-052에 따라 원본 프레임 중심 좌표를 복사하지 않고, 원본 지면선의
    패들 하단 대비 `+18px` 절대 간격을 Godot 실시간 히트박스 하단에
    앵커링했다. 땅굴 이동은 시각 상태만 움직이며 실제 패들 충돌 위치는
    바꾸지 않는다.
  - GRT-009 관련 신규 예측식은 추가하지 않았고 현행 Godot 보스 AI를 그대로
    사용한다.

### 2. 게이트 결과

- 포커스 스모크 + 부정 레그:
  - `stage2_molewang_boss_port_smoke: ok`
  - 기존 간판 회귀와 묶은 최종 재실행: `Smoke summary: PASS=2 FAIL=0 TOTAL=2`
  - 잘못된 스테이지/미등록 변형은 각각 `yeonmyo`/`cheongringwi`로 닫히며,
    친구두더지는 2라운드 후 비활성화됨을 실행 검증했다.
- 기존 간판 보스 회귀:
  - `stage2_router_smoke: ok`
  - `Smoke summary: PASS=1 FAIL=0 TOTAL=1`
- 변경 파일 경고 스캔:
  - `gd_warning_scan: checked 16/16`
  - `Godot warning scan passed with no GDScript warnings.`
- 헤드리스 로드:
  - `[ApplicationQuitCoordinator] graceful headless shutdown complete`
  - `Godot headless load check passed.`
- 실 스테이지 라우트:
  - `GameSelectionState -> battle_scene_selection_startup_lifecycle ->`
    `gameplay_stage_module_catalog -> stage2_boss_variant_skill_state ->`
    `stage2_actor_renderer` 관통을 포커스 스모크에서 실행 검증했다.
- windowed/Vulkan 픽셀 캡처:
  - `Vulkan 1.4.325 - Forward Mobile - NVIDIA GeForce RTX 5070`
  - `[StageBossVariantVisualQA] variant=molewang evidence=.../molewang.png`
  - `stage_boss_variant_visual_qa: ok`
  - 캡처 육안 검사: 왕관/몸체/지면선, 10개 땅굴 가시, 회전발톱, 황금
    친구두더지 2개가 760x750 실 렌더에 존재.

검증 환경 준비 중 기준 작업트리에 없던 생성 임포트 캐시는 원본 에디터 캐시와
SHA-256 일치 확인 후 격리 작업트리에만 복사했다. 첫 시도에서 드러난 누락 캐시는
보완 후 같은 필수 게이트를 재실행해 GREEN을 얻었으며, 원본 에디터 캐시는
수정하지 않았다.

### 3. 자산 상태

- 상태: 원본 절차형 자산 이관 완료. 신규 이미지 생성 없음, 수용 대기 없음.
- 런타임: `stage2_variant_boss_renderer.gd`; 고정 비트맵/임포트 의존 없음.
- 프리웜: 절차형 렌더러 `prewarm_assets_step() == true`; 핫패스 이미지
  스캔·슬라이스·동기 로드 없음.

### 4. 상태 구분

- fixed: 변형 등록, 선택/부트 전달, 스킬 상태, 접촉/점수/라운드 호출 경로,
  HUD, AI 이동 잠금, 오디오 라우팅, 절차형 렌더, 라이프사이클 정리.
- deferred: 탑 통합 담당의 대역 매핑 교체만 의도적으로 비범위.
- blocked: 0건.
- unverified: 0건.

### 5. 통합 인계

- 레지스트리 슬롯 id: `floor_02_molewang`
- 연결할 변형 id: `molewang`
- 통합 호출: 전투 진입 전 `GameSelectionState.set_stage(2, "dalji", false,
  "molewang")` 또는 스테이지 2 선택 후 `set_stage_boss_variant("molewang")`.
- 이 트랙에서는 금지된 탑 레지스트리/대역 매핑을 수정하지 않았다.

## 아라크네

- 상태: 미착수.

## 테디베어

- 상태: 미착수.

## 엘리스

- 상태: 미착수.
