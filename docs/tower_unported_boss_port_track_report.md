# 미포팅 보스 4종 포팅 트랙 보고서

- 기준 커밋: `4164b043b2c7e1efa04beb81f4787ab04a9e1a5e`
- 작업 브랜치: `codex/tower-unported-boss-port-4164` (로컬 전용, push 없음)
- 금지 경계: `godot/scripts/tower_ascent/**`, `tower_ascent_tuning.gd`,
  `tower_ascent_boss_registry.gd` 대역 매핑 무수정
- 전체 상태: 완료 (4종 구현·독립 커밋·필수 게이트 완료, blocked/unverified 0건)

## 두더지왕

### 1. 커밋과 파리티 조사

- 독립 커밋: `55281df29ed636846e9cd3bb7935d83c714b8aca`
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

### 1. 커밋과 파리티 조사

- 독립 커밋: `f8424d08e75fe9c777e386685cffebb42a912298`
- 원본 실제 호출 경로:
  - 보스 패들 접촉 시 게이지 `+60` 후 15초 쿨다운·게이지 500 조건으로
    거미줄 함정을 한 발 발사한다. 35f 이동 후 Y `695..720`에 300f 동안
    설치되며 접촉 플레이어를 `x0.40`으로 감속한다.
  - 공 상단이 `25px`보다 위이고 위로 진행할 때 게이지 50·25초 쿨다운으로
    거미줄 구조를 발동한다. 발사 15f, 대기 60f, ease-in 제곱 당김 50f,
    홀드 60f, 타격 8f 뒤 속도 18의 하향 공으로 해제한다.
  - 플레이어 4점 획득 시 광폭화를 예약한다. 다음 라운드와 이후 매 라운드에
    70f 붉은 발구르기 후 80/90/100f에 붉은 거미줄 3발을 쏘고 영구 함정으로
    남긴다.
- 수치·상호작용:
  - 일반/광폭화 거미줄은 연막에 파괴되고 대시 접촉에도 제거된다. 30% 황금
    함정은 파괴 48f 뒤 스타포인트를 만든다.
  - 원본 아라크네의 패들 폭/높이 `x1.30` 비율을 Godot 기준 히트박스에 적용해
    `130x52`로 설정했다.
- 파리티 예외:
  - 원본 캐릭터는 고정 비트맵이 아니라 `entities/spider_boss_sprite.py`의
    절차형 자산이다. 검갈색 몸통, 8개 분절 다리, 주황 복부 무늬, 붉은 눈과
    송곳니를 Godot 절차형 렌더러로 이관했다.
  - 원본에 선언됐지만 실제 소비 경로가 없는 공 감속 `x0.70`과 방향 왜곡
    `+-0.15rad`는 GRT-053에 따라 구현하지 않았다.
  - 원본 `sounds/spiderbite.wav`는 Godot 자산에 없어, 기존 런타임의 그물 발사
    `net.wav` 및 거미지뢰 설치·Stage 3 꼬리 타격 피드백 경로로 대응했다.

### 2. 게이트 결과

- 포커스 스모크 + 부정 레그:
  - `stage2_arachne_boss_port_smoke: ok`
  - 두더지왕·기존 간판 회귀와 묶은 재실행:
    `Smoke summary: PASS=3 FAIL=0 TOTAL=3`
  - 15초/25초 쿨다운, 게이지 부족, 잘못된 변형 라우팅, 연막/대시 파괴,
    황금 함정 지연 보상, 구조 해제 속도, 광폭화 다음 라운드 반복을 실행
    검증했다.
- 기존 간판 보스 회귀:
  - `stage2_router_smoke: ok`
- 변경 파일 경고 스캔:
  - `gd_warning_scan: checked 9/9`
  - `Godot warning scan passed with no GDScript warnings.`
- 헤드리스 로드:
  - `[ApplicationQuitCoordinator] graceful headless shutdown complete`
  - `Godot headless load check passed.`
- windowed/Vulkan 픽셀 캡처:
  - `Vulkan 1.4.325 - Forward Mobile - NVIDIA GeForce RTX 5070`
  - `[StageBossVariantVisualQA] variant=arachne evidence=.../arachne.png`
  - `stage_boss_variant_visual_qa: ok`
  - 캡처 육안 검사: 8개 다리의 거미 본체, 일반/붉은/황금 거미줄, 구조선과
    투사체가 760x750 실 렌더에 존재.

### 3. 자산 상태

- 상태: 원본 절차형 자산 이관 완료. 신규 이미지 생성 없음, 수용 대기 없음.
- 런타임: `stage2_variant_boss_renderer.gd`; 고정 비트맵/임포트 의존 없음.
- 프리웜: 절차형 렌더러 `prewarm_assets_step() == true`; 핫패스 이미지
  스캔·슬라이스·동기 로드 없음.

### 4. 상태 구분

- fixed: 변형 등록, 선택/부트 히트박스 배율, 스킬 상태, 접촉/점수/라운드
  호출 경로, HUD, 공 구조 동결·해제, 연막/대시 상호작용, 오디오 라우팅,
  절차형 렌더, 라이프사이클 정리.
- deferred: 탑 통합 담당의 대역 매핑 교체만 의도적으로 비범위.
- blocked: 0건.
- unverified: 0건.

### 5. 통합 인계

- 레지스트리 슬롯 id: `floor_02_arachne`
- 연결할 변형 id: `arachne`
- 통합 호출: 전투 진입 전 `GameSelectionState.set_stage(2, "dalji", false,
  "arachne")` 또는 스테이지 2 선택 후 `set_stage_boss_variant("arachne")`.
- 이 트랙에서는 금지된 탑 레지스트리/대역 매핑을 수정하지 않았다.

## 테디베어

### 1. 커밋과 파리티 조사

- 독립 커밋: `038287f3ec2f44ab19fa8bcecd657cf6bdaf8835`
- 원본 실제 호출 경로:
  - Stage 3 보스 패들 접촉마다 게이지 `+50` 후 같은 접촉 분기에서 네 스킬을
    순서대로 판정한다. 솜뭉치 투척은 게이지 200/15%/10초, 솜뭉치 폭탄은
    150/10%/12초, 죽음의 포옹은 250/20%/15초, 하트 빔은 150/20%/8초다.
  - 하트 빔 주석의 13%·10초가 아니라 실제 조건 `random <= 0.20`과 실제 상수
    480f를 정본으로 이관했다(GRT-053).
- 수치·타이밍:
  - 솜뭉치 투척: 선딜 30f, 3~5발, 속도 `4+-0.5`, 수명 240f, 피격 반경
    22, 피격 시 120f 화이트아웃(첫 30f 완전 백색 구간).
  - 솜뭉치 폭탄: 선딜 30f, 3~5개, 수명 480f, 반경 24. 공 피격 시 초기
    `+-0.4..0.7rad`와 60f 이중 사인 유령 커브, 플레이어 피격 시 120f
    `x0.50` 감속. 광폭화 중 폭발하면 4개 파편(속도 3, 수명 90f)으로 분열.
  - 죽음의 포옹: 보스 하단에서 Y630까지 6px/f 돌진, 폭 350의 하단 영역을
    300f 유지하며 영역 안의 대시 입력만 차단한다.
  - 하트 빔: 속도 9, 크기 12/피격 반경 18. 피격 뒤 72f 동안 0/24/48f에
    60~85px 좌우 교대 넉백 3회.
- 파리티 예외:
  - 원본 정본은 `entities/teddy_bear_boss_sprite.py`의 절차형 폴백과 추적되지
    않은 `.tmp` 후보 시트다. 저장소에 존재하는 정본만 사용해 갈색 봉제 몸체,
    하트 눈/덜렁이는 단추 눈, 터진 솔기 솜, 안전핀, 붕대, 분홍 리본을 Godot
    절차형 렌더러로 이관했다. 신규 이미지 생성은 하지 않았다.
  - 원본에 없는 부동갑주/정화 호환을 위해 하트 빔의 각 넉백을 공용
    `PlayerKnockbackImmunity`의 넉백 전용 게이트에 연결했다. 수치·발동 순서는
    바꾸지 않았다.
  - 죽음의 포옹은 전용 `dash_input_reader`만 막아 좌우 이동과 일반 액션 입력은
    그대로 유지한다.

### 2. 게이트 결과

- 포커스 스모크 + 부정 레그:
  - `stage3_teddy_bear_boss_port_smoke: ok`
  - 환묘 연묘 사이코볼·저주 입력·Stage 3 맵 회귀와 묶은 재실행:
    `Smoke summary: PASS=4 FAIL=0 TOTAL=4`
  - 잘못된 스테이지/변형, 게이지·쿨다운 차단, 포옹 영역 밖 대시 복원,
    라운드/매치 정리와 4개 HUD 항목을 실행 검증했다.
- 기존 간판 보스 회귀:
  - `stage3_psychoball_parity_smoke: ok`
  - `stage3_curse_control_reverse_smoke: ok`
  - `stage3_map_port_smoke: ok`
- 변경 파일 경고 스캔:
  - `gd_warning_scan: checked 10/10`
  - `Godot warning scan passed with no GDScript warnings.`
- 헤드리스 로드:
  - `[ApplicationQuitCoordinator] graceful headless shutdown complete`
  - `Godot headless load check passed.`
- windowed/Vulkan 픽셀 캡처:
  - `Vulkan 1.4.325 - Forward Mobile - NVIDIA GeForce RTX 5070`
  - `[StageBossVariantVisualQA] variant=teddy_bear evidence=.../teddy_bear.png`
  - `stage_boss_variant_visual_qa: ok`
  - 캡처 육안 검사: 봉제 곰 본체와 특징물, 투척 솜뭉치, 폭탄/파편, 유령
    커브, 하트 빔, 죽음의 포옹 영역이 760x750 실 렌더에 존재.

### 3. 자산 상태

- 상태: 저장소 내 원본 절차형 자산 이관 완료. 신규 이미지 생성 없음,
  수용 대기 없음.
- 런타임: `stage3_variant_boss_renderer.gd`; 추적되지 않은 원본 `.tmp` 후보
  시트 의존 없음.
- 프리웜: 절차형 렌더러 `prewarm_assets_step() == true`; 핫패스 이미지
  스캔·슬라이스·동기 로드 없음.

### 4. 상태 구분

- fixed: 변형 등록, Stage 3 프록시, 접촉 게이지/확률 발동, 네 스킬 상태,
  공/플레이어/대시 소비자, HUD, 오디오 라우팅, 절차형 렌더,
  라운드/매치 정리.
- deferred: 탑 통합 담당의 대역 매핑 교체만 의도적으로 비범위.
- blocked: 0건.
- unverified: 0건.

### 5. 통합 인계

- 레지스트리 슬롯 id: `floor_03_teddy_bear`
- 연결할 변형 id: `teddy_bear`
- 통합 호출: 전투 진입 전 `GameSelectionState.set_stage(3, "dalji", false,
  "teddy_bear")` 또는 스테이지 3 선택 후 `set_stage_boss_variant("teddy_bear")`.
- 이 트랙에서는 금지된 탑 레지스트리/대역 매핑을 수정하지 않았다.

## 엘리스

### 1. 커밋과 파리티 조사

- 독립 커밋: `5d4ee1646559107c05daced7a9c8056787e259c0`
- 원본 실제 호출 경로:
  - Stage 3 보스 패들 접촉마다 게이지 `+50` 후 거울 세계, 사이즈 시프트,
    토끼 투사체 순으로 판정한다.
  - 거울 세계는 게이지 500에서 자동 발동해 전량 소비하고 180f 유지,
    900f 쿨다운이다. 먼저 전량을 소비하므로 같은 접촉의 사이즈 시프트와
    토끼 투사체는 발동하지 않는다.
  - 사이즈 시프트는 게이지 70/12%/600f 쿨다운, 240f 유지이며 거울 세계
    중에는 발동하지 않는다. 발동 직전 공 크기를 보존하고 `x2.0` 또는
    `x0.5`로 바꾼 뒤 정확히 복원한다.
  - 토끼 투사체는 게이지 120/13%/480f 쿨다운, 30f 선딜 뒤 3~4마리를
    발사한다.
- 수치·타이밍:
  - 거울 세계: 760x750 플레이필드만 X축 반전하며 필러와 필러 HUD는
    반전하지 않는다. 시작/종료 30f 시각 페이드 비율과 거울 테두리·균열을
    별도 상태로 노출한다.
  - 사이즈 시프트: 기존 중심을 유지하는 공의 충돌 크기와 렌더 반경을 같은
    owner 값으로 배율 변경한다. 물리 업데이트, 효과 충돌, 서브 배치,
    플레이필드 렌더가 모두 그 값을 소비한다.
  - 토끼: 목표까지 120~180f 거리 기반 속도(최소 `3.5x0.8`), `+-18deg`
    분산, 프레임당 0.02 약유도, 수명 300f, 피격 반경 20. 플레이어 접촉 시
    패들에 120f 부착되고 1.5px/f로 왕복하며 30f마다 이동 방향으로 속도 8
    넉백을 준다. 연막은 비행/부착 토끼를 제거하고 대시는 부착 토끼를 즉시
    제거해 마리당 10개 파티클을 만든다.
- 파리티 예외:
  - 원본 정본은 `entities/alice_boss_sprite.py`의 절차형 캐릭터다. 금발 장발,
    왕청색 5패널 드레스, 흰 앞치마, 청색 리본, 손거울 정체성을 Godot
    절차형 렌더러로 이관했고 신규 이미지 생성은 하지 않았다.
  - 원본의 `sounds/clue.wav`는 저장소와 Godot 자산에 없다. 거울 세계만 기존
    Stage 3 마법 단발음 `dollcurse.wav`로 명시적으로 대체했다. 사이즈 시프트의
    `gravityaccel.wav`, 토끼의 `smallboyshoot.wav`/`smallboyhit.wav`는 원본
    파일을 그대로 라우팅했다.
  - 원본은 렌더 완료 화면 복사본을 알파 합성해 첫/마지막 30f를 교차
    페이드한다. Godot 포트는 핫패스 렌더타깃 복사를 추가하지 않고 활성
    기간의 플레이필드 변환을 즉시 반전하며 같은 30f 비율을 테두리·균열
    페이드에 사용한다. 플레이필드/필러 경계와 180f 조작 혼란은 동일하다.
  - 원본의 `player_fire_knockback_vel` 누적은 공용 `player_movement_state`의
    넉백 소비자로 옮기고 정화/부동갑주 공용 게이트를 적용했다.

### 2. 게이트 결과

- 포커스 스모크 + 부정 레그:
  - `stage3_alice_boss_port_smoke: ok`
  - 테디베어·환묘 연묘 사이코볼·저주 입력·Stage 3 맵 회귀와 묶은 재실행:
    `Smoke summary: PASS=5 FAIL=0 TOTAL=5`
  - 잘못된 스테이지 등록/접촉 차단, 거울 전량 소비와 동일 접촉 배타성,
    180f/900f 시계, 플레이필드 전용 변환, 공 크기 owner→물리/서브 소비와
    240f/라운드 복원, 토끼 선딜·개수·연막·대시·30f 넉백을 실행 검증했다.
- 기존 간판/직전 보스 회귀:
  - `stage3_teddy_bear_boss_port_smoke: ok`
  - `stage3_psychoball_parity_smoke: ok`
  - `stage3_curse_control_reverse_smoke: ok`
  - `stage3_map_port_smoke: ok`
- 변경 파일 경고 스캔:
  - `gd_warning_scan: checked 14/14`
  - `Godot warning scan passed with no GDScript warnings.`
- 헤드리스 로드:
  - `[ApplicationQuitCoordinator] graceful headless shutdown complete`
  - `Godot headless load check passed.`
- windowed/Vulkan 픽셀 캡처:
  - `Vulkan 1.4.325 - Forward Mobile - NVIDIA GeForce RTX 5070`
  - `[StageBossVariantVisualQA] variant=alice evidence=.../alice.png`
  - `stage_boss_variant_visual_qa: ok`
  - 첫 캡처에서 상단 머리 클리핑을 발견해 전신 앵커를 아래로 조정하고
    재캡처했다. 최종 760x750 캡처에서 금발·청색 드레스·앞치마·리본·손거울,
    토끼 3마리와 부착 토끼 2마리, 사이즈 시프트 링, 파티클, 거울 테두리와
    균열을 육안 확인했다.

### 3. 자산 상태

- 상태: 저장소 내 원본 절차형 자산 이관 완료. 신규 이미지 생성 없음,
  수용 대기 없음.
- 런타임: `stage3_variant_boss_renderer.gd`; 고정 비트맵/외부 생성물 의존 없음.
- 프리웜: 절차형 렌더러 `prewarm_assets_step() == true`; 핫패스 이미지
  스캔·슬라이스·동기 로드·렌더타깃 생성 없음.

### 4. 상태 구분

- fixed: 변형 등록, Stage 3 프록시, 접촉 게이지/순차 발동, 거울 플레이필드
  변환, 동적 공 충돌·렌더·서브 소비자와 복원, 토끼 비행·부착·연막·대시·넉백,
  HUD, 오디오 라우팅, 절차형 렌더, 라운드/매치 정리.
- deferred: 탑 통합 담당의 대역 매핑 교체만 의도적으로 비범위.
- blocked: 0건.
- unverified: 0건.

### 5. 통합 인계

- 레지스트리 슬롯 id: `floor_03_alice`
- 연결할 변형 id: `alice`
- 통합 호출: 전투 진입 전 `GameSelectionState.set_stage(3, "dalji", false,
  "alice")` 또는 스테이지 3 선택 후 `set_stage_boss_variant("alice")`.
- 이 트랙에서는 금지된 탑 레지스트리/대역 매핑을 수정하지 않았다.

## 최종 인계 감사

- 기준부터 보스별 독립 커밋 순서:
  1. `55281df29ed636846e9cd3bb7935d83c714b8aca` — 두더지왕
  2. `f8424d08e75fe9c777e386685cffebb42a912298` — 아라크네
  3. `038287f3ec2f44ab19fa8bcecd657cf6bdaf8835` — 테디베어
  4. `5d4ee1646559107c05daced7a9c8056787e259c0` — 엘리스
- 최종 공통 게이트:
  - 4종 집중 스모크 + Stage 2 라우터 + Teddy/환묘 연묘 역방향 회귀:
    `Smoke summary: PASS=8 FAIL=0 TOTAL=8`
  - 변경 GDScript 경고 스캔: `checked 14/14`, 무경고
  - 헤드리스 로드: graceful shutdown 및 PASS
  - 네 보스 모두 Forward Mobile/Vulkan RTX 5070 실창 캡처 및 육안 검사 완료
  - `git diff --check` PASS
- 금지 경계 감사:
  - `godot/scripts/tower_ascent/**` 변경 0건
  - `tower_ascent_boss_registry.gd` SHA-256:
    `F4A5564ED54699F891F425AA57D9D2FDD3C354590416CB71C34AF285926E6E29`
  - `tower_ascent_tuning.gd` SHA-256:
    `1027846CCC26FF3745E9F448557F530A505F98B8E0610825056FEFD3EB6A9268`
- 외부 상태: 로컬 커밋만 생성, push 0건.
- 최종 상태 구분: fixed 4종, deferred는 별도 통합 담당의 대역 매핑 교체만,
  blocked 0건, unverified 0건.
