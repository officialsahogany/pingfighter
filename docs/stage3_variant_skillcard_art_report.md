# Stage 3 variant boss skill-card art report

## S1 판정

- 기준 HEAD: `93960814b18b13c754cff3d61e344a7663ea54b4`
- 격리 워크트리: `D:\codex_tmp\tower_boss_integration_merge_20260817`
- 브랜치: `codex/stage3-variant-skillcard-art-s1`
- 통합/푸시: 하지 않음

### 1. 아틀라스 판정: 아트 생성 필요

`godot/assets/sprites/stage3/menhera_boss_skill_cards_imagegen_v1.png`를 실제로
열어 확인했다. 선언값은 `SKILLCARD_ATLAS_COLUMNS := 4`이고, 실제 이미지는
`1024x96`, 눈으로 확인한 격자는 `1행 x 4열`, 셀은 `256x96`이다.

네 셀 모두 그림이 있다.

| 인덱스 | 눈으로 확인한 그림 | 현재 색인 |
|---:|---|---|
| 0 | 눈물 방울 | `tear_shower` |
| 1 | 사슬과 하트 자물쇠 | `curse_chest` |
| 2 | 꿰맨 금 간 하트 | `psycho_ball` |
| 3 | 검은 고양이 꼬리 | 미색인 연묘 계열 그림 |

테디베어 4종과 엘리스 3종에 해당하는 셀은 없다. 기존 칸의 색인만 추가하면
서로 다른 스킬에 엉뚱한 그림을 재사용하게 되므로 S2 배선만으로 끝낼 수 없다.
결론은 **S3 아트 후보 7종 생성 필요**다. 승인 전에는 런타임 아틀라스와 색인표를
수정하지 않는다.

### 2. 이력 판정: 회귀가 아니라 미구현

- 아틀라스와 인라인 색인표 최초 도입: `0958adef1a9c9d56bc7763d2b6ad15ba588876a4`
  (`WIP: checkpoint Godot port rewrite`, 2026-05-21)
- 자산 메타데이터 분리: `cdaac1484fbc8daf5259af41f30b11c1ea5b926b`
  (`Extract stage3 boss skill HUD asset metadata`, 2026-06-17)
- 테디베어 변형 도입: `038287f3ec2f44ab19fa8bcecd657cf6bdaf8835`
- 엘리스 변형 도입: `5d4ee1646559107c05daced7a9c8056787e259c0`

최초 인라인 표부터 현재 메타데이터 표까지 `tear_shower`, `curse_chest`,
`psycho_ball` 세 ID만 있었다. 전체 Git 이력에서 Stage 3 HUD 표/렌더러에
`cotton_throw`, `cotton_bomb`, `deadly_hug`, `heart_beam`, `mirror_world`,
`size_shift`, `rabbit_projectile`가 존재했던 커밋은 0건이다. 따라서 이 ID를
지운 커밋은 없다. 변형 포트 두 커밋에서 HUD 자산 계약을 함께 확장하지 않은
**초기 미구현**이다.

### 3. Stage 2, 5, 6, 7, 8 교차 확인

`SKILLCARD_ID_TO_INDEX`, `ID_TO_INDEX`, `skillcard`, `skill_card`를 각각 검색하고,
각 스테이지의 실제 HUD 상태 방출 ID와 렌더러의 경로 선택을 대조했다.

| 스테이지 | 실제 방출과 카드 경로 대응 | 판정 |
|---:|---|---|
| 2 | 청린귀 3종만 대응. 두더지왕 `tunnel_raid`, `spinning_claw`, `friend_moles`와 아라크네 `web_trap`, `web_rescue`, `spider_rage`는 모두 미대응 | Stage 3와 같은 변형 결손 |
| 5 | `hongryun_fireball`, `hongryun_inferno` 모두 대응 | GREEN, 등록된 변형 없음 |
| 6 | `stage6_tetro_drop`, `stage6_guard`, `stage6_wall`, `stage6_super` 모두 대응 | GREEN, 등록된 변형 없음 |
| 7 | `stage7_clone`, `stage7_shuriken`, `stage7_cloud`, `stage7_superspeed` 모두 대응 | GREEN, 등록된 변형 없음 |
| 8 | 상태는 `stage8_earthquake`를 방출하지만 렌더러가 의도적으로 아트를 그리지 않는 Slice 1 얇은 스텁 | 변형 결손은 아니나 카드 아트 미구현 |

`stage_boss_variant_catalog.gd`에 등록된 변형은 Stage 2와 Stage 3뿐이다. Stage 2의
결손은 이 목표의 Stage 3 후보 승인 범위를 넓히지 않고 별도 후속 항목으로 남긴다.

## S3 후보 제작: 승인 대기

기존 아틀라스를 스타일 참조로 사용해 built-in `image_gen`으로 스킬마다 별도
호출한 후보 7종을 만들었다. 원본은 8:3 가로 구도(대부분 2048x768)이고,
실제 셀 가독성 확인용 256x96 프리뷰를 함께 보존했다.

| 보스 | 스킬 ID | 후보 핵심 상징 | 256x96 육안 판정 |
|---|---|---|---|
| 테디베어 | `cotton_throw` | 날아가는 꿰맨 솜뭉치와 곡선 궤적 | 식별 가능 |
| 테디베어 | `cotton_bomb` | 심지가 붙은 곰 얼굴 솜폭탄과 폭발 고리 | 식별 가능 |
| 테디베어 | `deadly_hug` | 금 간 하트를 조이는 거대한 봉제 팔 | 식별 가능 |
| 테디베어 | `heart_beam` | 봉제 하트 발사기와 수평 광선 | 식별 가능 |
| 엘리스 | `mirror_world` | 금 간 거울 속 역전 통로와 흰 토끼 | 식별 가능 |
| 엘리스 | `size_shift` | 같은 토끼 말의 극소/거대 대비와 왜곡 고리 | 식별 가능 |
| 엘리스 | `rabbit_projectile` | 카드 파편 사이로 발사된 봉제 토끼 | 식별 가능 |

- 비교 시트:
  `images/stage3_variant_skillcard_art_candidates/stage3_variant_skillcard_candidate_v1_contact_sheet.png`
- 원본/프리뷰/프롬프트/해시:
  `images/stage3_variant_skillcard_art_candidates/candidate_manifest.md`
- 런타임 승격: 0건
- `stage3_boss_skill_hud_assets.gd` 수정: 0건
- 아틀라스 수정: 0건
- S4 씰/CI/pre-push 수정: 0건

지시대로 **후보 단계에서 정지**한다. 다음 단계는 사용자 아트 승인 또는 구체적인
재생성 지시다. 승인 전에는 S2 색인 확장, S4 씰, 런타임/Vulkan 검증을 진행하지
않는다.

## rev2 — 정본 기준 후보 B와 4x3 격자 판정

### 0. 후보 A 반려 반영

- 기준 HEAD: `28e9bfdfbfeb42b20055585dd17d385ff276e29a`
- 격리 워크트리:
  `D:\codex_tmp\bosspong_stage3_skillcard_rev2_28e9` (detached)
- 후보 A: 반려 유지. 시각 기준이 아닌 폐기된 `menhera_*` 자산을 사용했다.
- 후보 B 생성 입력: 정본
  `stage3_hwangyeokjeon_boss_skill_cards_imagegen_v1.png` 한 장만 사용했다.
- 정본 실측: `1024x96` RGBA, 1행 4열, 셀 `256x96`, 파일 SHA-256
  `4359e687acfa15348db2f7e72ffdffeca566187ef9ef93f7378fb5118d4cddb9`.

현재 본 트리 WIP에는 정본 PNG가 미추적 상태이고 HUD owner의 경로 변경이 미커밋
상태다. `28e9bfdfb` 자체에는 아직 구자산 경로만 있으므로, 본 트리를 수정하지 않고
정본 PNG의 바이트 사본만 후보 디렉터리에 가져와 기준을 고정했다.

### 1. 후보 B 아트 판정

| 보스 | 스킬 ID | rev2 해석 | 256x96 자체 판정 |
|---|---|---|---|
| 테디베어 | `cotton_throw` | 봉제 테디가 솜뭉치를 던지는 장면과 먹빛 궤적 | 읽힘 |
| 테디베어 | `cotton_bomb` | 봉제 구형 껍질이 터지며 솜과 주사 불티가 분출 | 읽힘 |
| 테디베어 | `deadly_hug` | 봉제 팔 사이의 금 간 주사빛 심장 | 읽힘 |
| 테디베어 | `heart_beam` | 봉제 심장에서 나가는 주사빛 세 줄기 | 읽힘 |
| 엘리스 | `mirror_world` | 빅토리아풍 타원 거울 속 뒤집힌 체크 회랑 | 읽힘 |
| 엘리스 | `size_shift` | 같은 서양 흰 토끼의 거대/극소 대비 | 읽힘 |
| 엘리스 | `rabbit_projectile` | 회중시계를 찬 흰 토끼의 고속 돌진 | 읽힘 |

한국식으로 소재를 치환하지 않았다. 테디베어의 봉제 천·솜·팔·심장과 엘리스의
빅토리아풍 거울·흰 토끼·회중시계는 유지하고, 렌더링 언어만 먹빛·비취·주사·황동으로
바꿨다. 네온 마젠타·바이올렛·시안, 글자, 숫자, 로고, 워터마크는 없다.

각 신규 셀에는 정본 네 셀의 채널별 중앙값으로 얻은 공통 상·하 황동/칠기 레일과,
정본 0번에서 픽셀 복사한 모서리 금구·좌우 중앙 장식을 합성했다. 물방울·부적·
소용돌이·끈 소재가 섞이지 않도록 좁은 프레임 마스크만 사용했다. 핵심 한 줄 비교에서
정본 3종과 신규 7종의 프레임 리듬과 억제된 명도는 같은 계열로 보인다. 최종 승인
판단은 사용자에게 남긴다.

### 2. 격자 판정

**4열 x 3행, 11프레임**을 채택한다.

```gdscript
const SKILLCARD_ATLAS_COLS := 4
const SKILLCARD_ATLAS_ROWS := 3
const SKILLCARD_ATLAS_FRAMES := 11
const SKILLCARD_ATLAS_COLUMNS := SKILLCARD_ATLAS_COLS # 기존 소비자 호환 별칭
```

| 인덱스 | 셀 | 내용 |
|---:|---|---|
| 0 | row 0, col 0 | `tear_shower` 기존 픽셀 |
| 1 | row 0, col 1 | `curse_chest` 기존 픽셀 |
| 2 | row 0, col 2 | `psycho_ball` 기존 픽셀 |
| 3 | row 0, col 3 | 기존 미색인 셀 픽셀 |
| 4 | row 1, col 0 | `cotton_throw` |
| 5 | row 1, col 1 | `cotton_bomb` |
| 6 | row 1, col 2 | `deadly_hug` |
| 7 | row 1, col 3 | `heart_beam` |
| 8 | row 2, col 0 | `mirror_world` |
| 9 | row 2, col 1 | `size_shift` |
| 10 | row 2, col 2 | `rabbit_projectile` |
| 11 | row 2, col 3 | 미사용 투명 셀 |

근거는 세 가지다.

1. 기존 선언 열 수 4를 유지하므로 기존 `0..3`의 x 좌표와 첫 행 픽셀을 그대로
   보존할 수 있다.
2. 11프레임을 담는 최소 직사각형이며, 마지막 한 셀만 비운다.
3. `3열 x 4행` 등은 기존 셀의 열 좌표를 바꿔 연묘 색인 무손상 계약을 깨므로
   배제한다.

owner 상수와 2차원 행/열 슬라이싱은 아직 적용하지 않았다. 활성 런타임 아틀라스가
승격 전 1행 상태인데 `ROWS := 3`, `FRAMES := 11`만 먼저 선언하면 owner 계약이
실제 자산과 거짓으로 어긋난다. 따라서 위 선언은 승인 후 후보 아틀라스 승격·ID
배선·renderer 2차원 슬라이스와 같은 헝크에서 적용한다.

### 3. 제출 4종

1. 접촉 시트:
   `images/stage3_variant_skillcard_art_candidates_rev2/stage3_variant_skillcard_candidate_rev2_contact_sheet.png`
2. 핵심 연묘 3종 + 신규 7종 한 줄 비교:
   `images/stage3_variant_skillcard_art_candidates_rev2/stage3_yeonmyo3_plus_variant7_rev2_one_line_comparison.png`
3. 256x96 축소 판정 컷:
   `images/stage3_variant_skillcard_art_candidates_rev2/stage3_variant7_rev2_256x96_judgement_strip.png`
4. 확장 아틀라스 + 격자/픽셀 증거:
   `images/stage3_variant_skillcard_art_candidates_rev2/stage3_hwangyeokjeon_boss_skill_cards_candidate_rev2_atlas_4x3_11f.png`,
   `stage3_hwangyeokjeon_boss_skill_cards_candidate_rev2_atlas_grid_proof.png`,
   `stage3_variant_skillcard_candidate_rev2_pixel_preservation.json`

상세 프롬프트·생성 ID·후처리 계약은 같은 디렉터리의
`candidate_manifest.md`에 남겼다.

### 4. 기존 픽셀 보존 증거

- 정본 전체 RGBA SHA-256:
  `983a6fd3271deda9503c4e581b77d95164b141924d8306b999527d3d8efb1ac1`
- 확장 아틀라스 첫 행 RGBA SHA-256: 위와 동일
- 기존 셀 0: before/after
  `620c58fe7666a76f51754f8e1b025f9c72d7ffae51de537cee1c95c730ec76e1`,
  changed pixels `0`
- 기존 셀 1: before/after
  `e50665ed8bfa5a8f4aa9f0987a8aa69ef614a1ec27d502089ba05174b15e2c45`,
  changed pixels `0`
- 기존 셀 2: before/after
  `c6f750d82962dee305f21c42853d6feccc47204a839f7aa67b53c1859d5ea3af`,
  changed pixels `0`
- 기존 셀 3: before/after
  `9cee98ca7819ce213219867facfd7a407d9584b9afc17144d3e0e2d5114ac988`,
  changed pixels `0`

네 셀 모두 `difference_bbox: null`이다. 기존 0·1·2 색인뿐 아니라 3번 미색인
정본 셀까지 픽셀 단위로 보존했다.

### 5. 승인 경계

- 런타임 자산 승격: 0건
- HUD ID 색인 배선: 0건
- owner/renderer/씰/CI/pre-push 변경: 0건
- 커밋/푸시/본 트리 통합: 0건

착수 시 본 트리 HEAD는 사용자 지정값 `28e9bfdfb`였고, 최종 보호 확인 시 본 트리
HEAD는 외부 동시 작업으로 `252d68108`까지 이동했다. 격리 워크트리는 시작 기준
`28e9bfdfb`에 그대로 고정되어 있으며 본 트리 변경에는 손대지 않았다.

후보 B와 격자 판정만 제출하고 사용자 승인 또는 재생성 지시를 기다린다.

## 2026-08-21 후보 B 승인 후 승격·배선·씰

### 1. 승격과 런타임 계약

- 사용자가 후보 B와 `COLS=4`, `ROWS=3`, `FRAMES=11`을 승인한 뒤에만
  승격했다. 아트는 재생성하지 않았다.
- 승격 경로:
  `godot/assets/sprites/stage3/stage3_hwangyeokjeon_boss_skill_cards_imagegen_v1.png`
- owner는 `_COLS := 4`, `_ROWS := 3`, `_FRAMES := 11`, 셀 `256x96`,
  아틀라스 `1024x288`을 명시한다. 기존 `_COLUMNS`는 `_COLS`의 호환 별칭으로
  유지했다.
- renderer는 이미지 치수로 격자를 추론하지 않고, 선언된 상수와
  `row = index / COLS`, `col = index % COLS`로 2차원 소스 사각형을 계산한다.
- 기존 색인은 `tear_shower=0`, `curse_chest=1`, `psycho_ball=2`로 그대로다.
  3번 정본 셀은 미색인으로 남겼다.
- 신규 색인은 `cotton_throw=4`, `cotton_bomb=5`, `deadly_hug=6`,
  `heart_beam=7`, `mirror_world=8`, `size_shift=9`, `rabbit_projectile=10`이다.
- 자산 누락, 미등록 ID, 아틀라스 크기 불일치는 모두 기존 색 사각형
  폴백으로 닫힌다. 폴백을 제거하지 않았다.
- 개명 중인 표시 이름이나 툴팁은 변경하지 않았다. 스킬 ID와 카드 아트만
  배선했다.

### 2. `.import` / `.ctex` 직접 증거

- 커밋 대상 `.import` 사이드카가 존재하며, remap은
  `res://.godot/imported/stage3_hwangyeokjeon_boss_skill_cards_imagegen_v1.png-820727dbe64ad548a3f0cb8af333a29d.ctex`
  를 가리킨다.
- 라이브 본 트리 `.godot`을 쓰지 않고, 같은 `res://assets/...` 상대 경로를
  가진 최소 격리 에디터 프로젝트에서 물질화했다.
- 신규 `.ctex`: 323,362 bytes, SHA-256
  `ae254430b846383a98aa0e99fca9df7a46f054d902a4555fde957cb0dfced286`.
- Godot `ResourceLoader` 직접 로드: `CompressedTexture2D`, `(1024, 288)` GREEN.
  헤드리스 로드만을 증거로 삼지 않았다.

### 3. 씰과 반증

- `stage3_boss_skillcard_atlas_contract_smoke.gd`는 고정 ID 목록을 따로 복사하지
  않는다. `StageBossVariantCatalog.VARIANTS`의 ported Stage 3 항목을 순회하고,
  실제 `Stage3BossVariantSkillState.update()` / `get_hud_context()`가 방출한 ID를
  모아 색인 범위를 단언한다.
- 씰은 격자, 정본 경로, 기존 0·1·2 색인, 미색인 3번, 모든 런타임 ID,
  2차원 소스 사각형, `.import`/`CompressedTexture2D`, 첫 행 decoded RGBA SHA-256,
  Stage 2 형제 owner 무손상을 함께 검증한다.
- 실제 owner에서 `cotton_throw`를 임시로 삭제하면
  `missing:cotton_throw`로 씰이 RED가 되었다. 복구 후 다시 GREEN이다.
- 신규 씰을 `.github/workflows/godot-ci.yml`과
  `godot/tools/run_pre_push_checks.ps1` 두 리터럴 목록에 같은 순서로 등재했고,
  `tools/verify_agent_harness.ps1` GREEN을 확인했다.

### 4. 검증 결과

- 집중 스모크: Stage 2 Molewang, Stage 2 Arachne, Stage 3 transform, 신규
  atlas 씰 `PASS=4 FAIL=0`, `All Godot smoke tests passed.`
- touched-file 경고 스캔: 4 scripts, 경고 0, GREEN.
- headless load: graceful shutdown 종단선 GREEN. 단, 이것을 아틀 증거로 삼지
  않았다.
- 2020x1246 Vulkan 실화소 캡처: 연묘 3종, 테디베어 4종, 엘리스 3종,
  누락-ID 폴백 모두 픽셀 판정 GREEN. 캡처는
  `godot/.godot/codex_captures/stage3_skillcards/`에 보존됐다.
- 승천탑 `main.tscn` 실제 전투 전이로 테디베어와 엘리스에 진입했고,
  각각의 3840x2160 캡처에 정확한 4종/3종 카드가 최종 레일에 나타났다.
  다만 전체 랫퍼는 범위 밖 베이스라인 오류(`energy_ball_renderer.draw`
  인자 수, overdrive trail 인자 수, `vision_modifier` InputMap)로 RED이다.
  이 RED를 전체 통과로 표현하지 않는다.
- full pre-push는 범위 밖 기존 테스트 불일치(`PerkConversionFlags`, stat
  attribution 인자 수, Commando 오디오 상수)로 경고 스캔 중 RED였다.
  이 파일들은 본 작업 diff에 없다.
- 전역 리소스-로더 씰은 다른 기존 PNG 17종의 `.import` 누락으로
  RED였다. 이번 승격 PNG의 사이드카와 `.ctex` 직접 로드는 GREEN이다.

### 5. 보호 경계

- 격리 워크트리: `D:\codex_tmp\bosspong_stage3_skillcard_rev2_28e9`
- 기준 HEAD: `28e9bfdfbfeb42b20055585dd17d385ff276e29a` detached
- 본 트리 변경, 승격, 통합: 0건
- 커밋, 푸시: 0건

승격·배선·씰 구현은 격리 워크트리에서 완료했고, 보고 후 다음 지시를
기다린다.
