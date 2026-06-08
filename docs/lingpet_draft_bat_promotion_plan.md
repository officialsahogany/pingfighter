# Draft Bat 링펫 승격 계획

## 목적

`draft_bat`은 현재 카탈로그에 비활성 콘셉트로만 보관되어 있다. 3번째 정식 링펫으로 승격하려면 알에서 랜덤 부화되는 라이브 후보가 되기 전에 자산, 스탯, 액티브 스킬 런타임, 정보창/스킬카드 표시가 모두 연결되어야 한다.

## 현재 상태

- 카탈로그 ID: `draft_bat`
- 상태: `enabled = false`
- 보유 자산:
  - `res://assets/sprites/lingpet/bat_lingpet_cutin_concept_imagegen_v1.png`
  - `res://assets/sprites/lingpet/bat_lingpet_cutin_concept_imagegen_v1_chromakey.png`
  - `res://assets/sprites/lingpet/bat_lingpet_cutin_concept_imagegen_v1_magenta_source.png`
  - `res://assets/sprites/lingpet/draft_bat_companion_walk.png` 후보 완료
  - `res://assets/sprites/lingpet/draft_bat_companion_strike.png` 후보 완료
  - `res://assets/sprites/lingpet/draft_bat_companion_cast.png` 후보 완료
  - `res://assets/sprites/lingpet/draft_bat_moon_orbit_skillcard_imagegen_v1.png` 후보 완료
  - `res://assets/sprites/lingpet/draft_bat_moon_orbit_skill_icon_imagegen_v1.png` 후보 완료
- 현재 스모크 기준:
  - 비활성 링펫은 부화 후보에 들어가지 않는다.
  - 비활성 링펫은 최종 스프라이트/스킬 자산이 없어도 카탈로그 검증을 통과한다.

## 2026-06-02 진행

- AutoSprite 기준 캐릭터 등록 완료
  - character_id: `cmpwf2hxe007nj17muexwl28h`
  - source: `bat_lingpet_cutin_concept_imagegen_v1.png`
- `companion_walk` 후보 완료
  - accepted spritesheet_id: `cmpwf9zgz009sj17mk9mbol3c`
  - accepted job_id: `wf_87b4e018-98a9-4bc1-892e-96d1545f49c5`
  - rejected spritesheet_id: `cmpwf5dv200131417tem74ua4`
  - rejected job_id: `wf_de5482d7-92df-4cae-9ba4-52b617769078`
  - reject reason: 첫 후보는 정면/측면으로 크게 회전해 전투 동행 시트보다 쇼케이스 회전에 가까웠다.
  - final sheet: `res://assets/sprites/lingpet/draft_bat_companion_walk.png`
  - manifest: `res://assets/sprites/lingpet/draft_bat_companion_walk_manifest.json`
- `companion_strike` 후보 완료
  - back runtime character_id: `cmpwfn3ah004j141712dv9e91`
  - accepted spritesheet_id: `cmpwfp5en0009363x1socppyb`
  - accepted job_id: `wf_1e1acbeb-9932-4fdd-86f2-6a12da6b09ab`
  - rejected spritesheet_id: `cmpwfk1kp003t1417cdzgz2tt`
  - rejected job_id: `wf_8a11c01a-6813-4dfc-affc-7cadb3ecb831`
  - reject reason: 첫 타격 후보는 다시 정면으로 돌아와 후면 동행 시트와 방향성이 맞지 않았다.
  - final sheet: `res://assets/sprites/lingpet/draft_bat_companion_strike.png`
  - manifest: `res://assets/sprites/lingpet/draft_bat_companion_strike_manifest.json`
  - note: `LingpetCompanionSpriteAnimator`의 임팩트 프레임 22에 맞춰 AutoSprite 원본 후반 타격 피크를 결정적으로 재배치했다.
- `companion_cast` 후보 완료
  - back runtime character_id: `cmpwfn3ah004j141712dv9e91`
  - accepted spritesheet_id: `cmpwfy5pa0055122detlemnuq`
  - accepted job_id: `wf_c7445d0d-286a-4fc6-b55e-5e5e3ee6df7f`
  - final sheet: `res://assets/sprites/lingpet/draft_bat_companion_cast.png`
  - manifest: `res://assets/sprites/lingpet/draft_bat_companion_cast_manifest.json`
  - note: AutoSprite 원본은 초반부가 가장 밝아 런타임 시전 진행과 반대로 읽혔다. `LingpetCompanionSpriteAnimator`의 windup 0→24 재생에 맞춰 프레임 순서를 반전해 충전감이 뒤로 갈수록 강해지게 했다.
- `월영 궤도` 스킬카드/아이콘 후보 완료
  - source: built-in `image_gen`
  - generated source: `C:\Users\woduq\.codex\generated_images\019e78bc-6d10-77a1-90ba-1b30fea38e85\ig_0bbd173426fa99ae016a1ea5472e5c819a84beb2c284a0f37f.png`
  - skill card: `res://assets/sprites/lingpet/draft_bat_moon_orbit_skillcard_imagegen_v1.png`
  - skill card manifest: `res://assets/sprites/lingpet/draft_bat_moon_orbit_skillcard_imagegen_v1_manifest.json`
  - skill icon: `res://assets/sprites/lingpet/draft_bat_moon_orbit_skill_icon_imagegen_v1.png`
  - skill icon manifest: `res://assets/sprites/lingpet/draft_bat_moon_orbit_skill_icon_imagegen_v1_manifest.json`
  - note: built-in 이미지 생성 결과가 16:9에 가까워 그대로는 스킬 레일 비율과 맞지 않았다. 스킬카드는 마리보 카드와 같은 `1720x541` 비율로 리컴포즈했고, 아이콘은 같은 원본에서 초승달 궤도 중심으로 정사각 크롭했다.

## 승격 전 필수 자산

정식 링펫으로 켜려면 `lingpet_catalog.gd`의 필수 visual 키를 모두 채워야 한다.

- `egg`: 공용 미확인 알을 재사용할 수 있음
- `egg_crack_1`: 공용 미확인 알 금 1단계 재사용 가능
- `egg_crack_2`: 공용 미확인 알 금 2단계 재사용 가능
- `companion_walk`: 전투 중 기본 이동 시트
- `companion_strike`: 공 타격 시트
- `companion_cast`: 액티브 스킬 준비/발동 시트
- `cutin_art`: 획득 컷인 전신 원화
- `cutin_anim`: 데이터 조각 복원 컷인용 Live2D 시트
- `cutin_dismiss_anim`: 클릭 후 퇴장 액션 시트
- `click_reaction_anim`: 전투 중 링펫 클릭 반응 시트

## 추천 역할

`draft_bat`은 방어형 마리보, 돌진형 달벳과 겹치지 않게 **기동/교란형 링펫**으로 잡는 편이 좋다.

- 이동 스타일: 공중 자유비행 또는 짧은 순간이동 섞인 순찰
- 전투 정체성: 공을 직접 막기보다는 상대 진영에 짧은 교란을 만든다.
- 방어율: 낮게 유지해서 패들 역할을 빼앗지 않는다.
- 게이지 획득량: 모든 링펫 공통 기본값 `40`

## 1차 스탯 초안

아래 값은 활성화 전 테스트용 초안이다.

- 이동 속도: `3.60` 표시 기준 (`216px/s`)
- 몸집 크기: `84x52px`
- 게이지 획득량: `40`
- 액티브 쿨타임: `35초`
- 방어율: `10%`

## 액티브 스킬 초안

### 월영 궤도

박쥐 링펫이 상대 진영 쪽으로 보랏빛 초승달 궤도를 날린다. 궤도는 상대 진영 벽에 닿으면 짧게 퍼지며, 범위 안에 있는 상대 보스의 이동 반응을 약화시킨다.

- 런타임 종류 후보: `moon_orbit`
- 효과: 상대 보스 이동 속도 또는 추적 반응을 짧게 감소
- 지속시간: `4초`
- 쿨타임: `35초`
- 장점: 마리보의 물웅덩이와 다르게 직접 둔화 장판이 아니라 예측/반응 방해 계열로 차별화 가능

## 구현 순서

1. 이름 확정
   - 한국어 표시명과 스킬명을 먼저 정한다.
2. 자산 제작
   - companion 이동/타격/시전 시트
   - 컷인 애니/퇴장/클릭 반응 시트
   - 스킬카드/정보창 아이콘
3. 스킬 모듈 추가
   - `lingpet_moon_orbit_skill.gd` 같은 전용 런타임 모듈 생성
   - `lingpet_skill_dispatcher.gd`에 `moon_orbit` 등록
   - `lingpet_skill_runtime_host.gd`에 update/draw/prewarm/launch 연결
4. 카탈로그 활성화
   - `draft_bat`의 `enabled`를 제거하거나 `true`로 전환
   - 스탯/visuals/active_skill/effect_text 채우기
5. 검증
   - `lingpet_egg_runtime_smoke`
   - `lingpet_debug_picker_smoke`
   - `lingpet_rail_card_shared_smoke`
   - `character_info_live_stats_smoke`
   - warning scan / headless load check

## 주의점

- 활성화 전에는 `validate_catalog(true)`가 반드시 통과해야 한다.
- 활성 링펫의 `active_skill.runtime_kind`는 반드시 `LingpetSkillDispatcher.is_supported_kind()`에서 true여야 한다.
- 전투 중 동행은 1마리만 가능하고, 링펫 슬롯은 최대 3마리까지 저장된다.
- 숫자키는 액티브 아이템 슬롯 확장을 위해 사용하지 않는다. 링펫 교체는 현재 `L` / `Shift+L` 방향을 유지한다.
