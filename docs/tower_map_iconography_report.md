# 탑 지도 아이콘 체계 작업 보고서

## 작업 기준과 격리

- 기준 커밋: `a167cb7169f98a37169b92c825685b6ae42cefcd`
- 격리 워크트리: `D:\main\bosspong_tower_audition_689b`
- 격리 브랜치: `codex/tower-map-iconography-a167`
- 기존 Godot 임포트 캐시: 전환 전후 525개 파일 유지
- 실행 로그·기존 캡처 백업: `D:\codex_backups\tower_map_iconography_20260820_011821`
- 본 트리 통합·푸시: 하지 않음

## 착수 전 소비자 조사

- 정본 `docs/tower_ascent_run_map_plan.md` §3.1은 보스 이름을 숨기되 고유
  아이콘은 항상 공개하도록 확정한다.
- 전체화면 지도와 기존 플레이필드 지도 표면은
  `tower_ascent_flow_renderer.gd`가 함께 소유한다. 지도 입력 소비자는 없고,
  실제 노드 선택은 `ROUTE_AIM`의 공 표적 충돌로만 이루어진다. 따라서 지도
  라벨 자리를 없애도 `get_node_index_at` 계열 히트박스는 존재하지 않는다.
- `ROUTE_AIM` 표적 라벨은 별도 드로 경로이며 이번 변경에서 건드리지 않는다.
- `FLOOR_BOSS_SLOTS`를 직접 센 결과 1~8층의 `status=ported` 실보스 슬롯은
  지시문의 예상 13종이 아니라 현재 코드 기준 14종이다: 달지, 각시탈,
  포도대장, 청린귀, 두더지왕, 아라크네, 환묘 연묘, 테디베어, 엘리스,
  퐁크, 홍련, 테트리서, 아카무 리고, 미노타우로스. shell/new_design 슬롯은
  S2 보스 아이콘 대상에서 제외한다.

## S1. 아이콘 계약과 폴백

- 신규 단일 소유자 `tower_ascent_map_iconography.gd`가 노드 `kind`와 시각용
  `boss_id`를 결정론적 `res://assets/sprites/tower/map_icons/...` 경로로 바꾼다.
- 보스 슬롯의 고유 접미사를 시각용 `boss_id`로 사용한다. 런타임 호환
  `boss_id`, `variant`, `boss_slot_id` 값은 수정하지 않는다.
- 아이콘은 `const preload`하지 않는다. `ResourceLoader.exists` 뒤 런타임
  `ResourceLoader.load`를 사용하며, 성공과 실패를 모두 경로별 캐시에 저장한다.
- 전체화면 지도와 플레이필드 지도 표면은 같은 프레젠테이션 계약을 소비한다.
  자산이 없으면 기존 보스 이름 또는 현지화된 시설 라벨을 그대로 그린다.
- 부정 레그는 영구 미존재 probe 경로를 두 번 조회해 파일시스템 시도가 정확히
  1회인지, 텍스처가 null인지, 기존 글자 폴백이 유지되는지 함께 단언한다.

S1 검증 결과:

| 게이트 | 결과 |
|---|---|
| 신규 씰 단독 배치 | `PASS=1 FAIL=0 TOTAL=1` |
| 지도 생산 경로 집중 배치 5개 | `PASS=5 FAIL=0 TOTAL=5` |
| 배치 종단선 | `All Godot smoke tests passed.` |
| 집중 배치 `SCRIPT ERROR` | 0건 |
| 변경 GDScript 3개 `run_warning_scan.ps1 -Paths` | GREEN, 경고 0건 |
| `run_headless_load_check.ps1` | GREEN, 정상 종료 표식 확인 |
| CI/프리푸시 리터럴 목록 | 각 173개, 차이 0, 신규 씰 각 1회 |
| `git diff --check` | GREEN |

S1 독립 커밋: `51353ff34` (`feat(tower): establish map icon fallback contract`).

## S2 승인 게이트

비전투 5종과 M 지도 아이콘 1종을 기본 내장 IMAGEGEN으로 한 번에 생성했다.
CLI/API 폴백은 사용하지 않았다. 후보는 런타임 경로가 아닌
`docs/art_candidates/tower_map_iconography/`에만 보존한다.

고정 3×2 셀 순서는 다음과 같다.

| 위치 | 후보 의미 | 실루엣 |
|---|---|---|
| 1행 1열 | 상점 | 열린 옻칠 상자와 황동 동전 |
| 1행 2열 | 수련장 | 주사색 띠를 맨 목인장 |
| 1행 3열 | 파계승 | 낡은 발우와 염주 |
| 2행 1열 | 수호의 샘터 | 비취 석조 샘과 솟는 물 |
| 2행 2열 | 휴식 | 접은 종이 차양 아래 모닥불 |
| 2행 3열 | 지도 힌트 | 오르는 점선 경로가 있는 한지 두루마리 |

### 후보 파일과 무결성

| 파일 | 용도 | SHA-256 |
|---|---|---|
| `s2_noncombat_map_hint_candidate_v1_raw_green.png` | IMAGEGEN 원본, 1536×1024 | `47C317469CD4990A7B1739A0C982154AA14A361CD1D61307648E82AA9D3DB844` |
| `s2_noncombat_map_hint_candidate_v1_alpha.png` | `chroma_key.py` 누끼와 제한 수동 포켓 정리 | `91C577BCC26C54191DA8B62E8DC00D10F092101B750FFFE938F040FAA27D6CA9` |
| `s2_noncombat_map_hint_candidate_v1_dark_preview.png` | 어두운 먹색 배경 QA | `4BFE59EA8C449142B2DBF3B2B1DEEACA2822ABFD36F3AFD8A948B9BB81B43E2C` |
| `s2_noncombat_map_hint_candidate_v1_light_preview.png` | 밝은 한지색 배경 QA | `C3F161F782B4749E786588CA878B4DC4403C5C0E46143A01038214C5ECDAFDE9` |
| `s2_noncombat_map_hint_candidate_v1_32px_preview.png` | 실제 32px 3×2 판독판 | `49C0E0ECC9E0F83DFEBF1CF2268502D498615B455138A55B61903399E45144A5` |
| `s2_noncombat_map_hint_candidate_v1_32px_zoom8_preview.png` | 32px 결과의 nearest 8배 육안판 | `E04013D557C352044BE06B2D98A49E417A84235CC1865DD440593D22177087F9` |

### 누끼와 소형 QA

- `.claude/skills/sprite-generation/chroma_key.py`를 `--key green`으로
  실행했다. 결과 크기는 1536×1024이며 네 모서리 alpha는 모두 0이다.
- 최종 alpha의 캔버스 외곽 nonzero alpha는 0픽셀이고 투명 픽셀 비율은
  0.627855다. 여섯 피사체는 모두 자기 512×512 셀 안에 머문다.
- 최초 누끼에서 발우와 염주가 외부 배경을 닫아 만든 녹색 내부 포켓을
  발견했다. 파계승 셀에만 녹색 우세 수동 마스크를 적용해 5,687픽셀을
  제거했고, 같은 probe의 잔여는 0이다. 비취와 물색이 필요한 샘터 셀은
  수정하지 않았다.
- 실제 32px와 그 nearest 확대판에서 상자, 목인장, 발우, 샘, 모닥불,
  두루마리의 여섯 실루엣이 서로 구분된다. 어두운 배경과 밝은 배경에서
  외곽선과 핵심 색점도 유지된다.
- 글자, 숫자, 물음표, 워터마크는 없다. 지도 후보 안의 탑과 점선은
  글자가 아닌 그림 요소다.

IMAGEGEN 원본의 외곽 녹색은 단일 `#00ff00`이 아니었다. 외곽 RGB 범위는
`[1,242,3]`부터 `[21,252,23]`이고 고유 RGB는 142종이며 정확한
`#00ff00` 픽셀은 0개다. 현 누끼는 성공했지만 이 원본은 수학적으로 평탄한
최종 크로마 소스가 아니므로 **승격 가능 판정을 내리지 않는다**. 승인 뒤
실제 개별 아이콘을 준비할 때 평면 키를 다시 봉인해야 한다.

### 사용한 최종 프롬프트

```text
Use case: stylized-concept
Asset type: a single unified candidate sheet for six small circular tower-map UI icons in the Korean fantasy martial-arts game 환격전
Primary request: Create one coherent 3 columns by 2 rows icon set. Each cell contains exactly one isolated icon, centered and evenly scaled.
Fixed cell order:
- top left: SHOP, represented only by an open dark-lacquer merchant chest with a few bold brass coins
- top center: TRAINING, represented only by a sturdy wooden martial-arts training dummy with a short cinnabar sash
- top right: FALLEN MONK, represented only by a worn monk's begging bowl crossed with a short strand of dark prayer beads
- bottom left: GUARDIAN SPRING, represented only by a carved jade stone spring basin with one strong upward water plume
- bottom center: REST, represented only by a compact campfire under a small folded paper shelter silhouette
- bottom right: MAP HINT, represented only by a rolled hanji map with a simple ascending dotted route; the route is purely pictorial and contains no letters or numbers
Scene/backdrop: perfectly flat solid chroma-key green #00ff00 across the entire canvas and to every edge; no floor plane, no scenery, no gradient, no shadows cast onto the background
Style/medium: one unified Korean mythic martial-arts icon family; bold black ink contours, subtle hanji paper texture inside the objects, dark lacquer, aged brass, jade, and restrained cinnabar accents; crisp hard-edged game UI art with a 16-bit-inspired silhouette, not painterly concept art
Composition/framing: six equal square cells in a precise 3x2 layout, no visible grid lines or dividers; each object fills about 68 percent of its cell and has generous green clearance; every silhouette must remain distinct and readable when reduced to 32px inside a circle
Lighting/mood: quiet ceremonial warmth, restrained highlights contained inside each silhouette
Constraints: same outline weight, camera angle, scale class, material treatment, and value contrast across all six icons; all objects fully inside their cells; no icon overlaps another cell; no glow halo, no aura, no particles, no soft shimmer outside the object
Avoid: any text, letters, Hangul, Chinese characters, numbers, runes, labels, question marks, emblems that resemble writing, watermarks, signatures, logos, borders, frames, cell separators, cyberpunk, neon, science fiction, photorealism, soft background wash, checkerboard, transparent-looking background
```

### 승인 대기 상태

사용자가 외출 중이라는 추가 지시에 따라 여기서 멈춘다. 사용자 승인 전에는
보스 14종 생성, 파일 분할·명명 확정, Godot 런타임 자산 경로 승격,
`.import` 생성, S3 지도 배선, S4 필러 이전, S5 캡처를 진행하지 않는다.
S1 글자 폴백이 살아 있으므로 현 지도 동작은 유지된다.

## S2 조건부 반려 후 v2 재작업 (2026-08-20)

사용자 판정에 따라 S1은 그대로 보존했다. S3 지도 배선, S4 M 힌트 이전,
S5 런타임 캡처는 시작하지 않았다. 보스 14종도 아직 생성하지 않았다.

### 배경 제거 경로 판정

1. **직접 투명 알파 통일 시트: 반려.** built-in IMAGEGEN에 진짜 투명
   배경을 요구했지만 결과는 1536x1024 `RGB`였고 체커보드가 픽셀로 구워져
   있었다. 알파 채널 자체가 없어 반복 생산 경로로 쓸 수 없다.
2. **팔레트 안전 키 + 아이콘별 개별 생성: 현 시점 채택 후보.** 상점·샘터·
   휴식은 마젠타, 수련장·파계승·지도는 녹색으로 뽑았다. 어느 원본도 정확한
   단일 `#ff00ff`/`#00ff00`은 아니었지만 `chroma_key.py`의 border-seeded
   dominance keying으로 여섯 장 모두 자동 처리됐다.
3. **평면 비크로마 + 별도 알파 생성:** 2번 경로가 수동 마스크 없이 통과해
   이번 후보에서는 추가 생성하지 않았다.

개별 생성은 복합 3x2 원본에서 생겼던 발우-염주 사이 폐쇄 포켓을 구조적으로
제거한다. 이번 여섯 장은 수동 마스크/수동 지우개를 한 번도 쓰지 않았고,
clean alpha에서 보이는 키색 잔류 0픽셀, 네 변 nonzero alpha 0픽셀이다.
따라서 보스 14종 확장에는 **아이콘별 생성 + 팔레트와 멀리 떨어진 키를 선택 +
자동 잔류색 게이트**가 가장 안정적인 경로로 판단한다. 배경 원본이 수학적으로
단색이라는 가정은 여전히 금지한다.

원본 테두리 RGB 범위와 고유색 수는 다음과 같다. 정확한 키색 픽셀은 여섯 장
모두 0/5016이었다.

| 아이콘 | 키 | border RGB min..max | border 고유 RGB |
|---|---|---|---:|
| 상점 | magenta | `[226,4,207]..[244,36,235]` | 202 |
| 수련장 | green | `[2,240,6]..[21,251,24]` | 131 |
| 파계승 | green | `[2,234,6]..[21,246,25]` | 199 |
| 샘터 | magenta | `[227,3,206]..[245,32,233]` | 215 |
| 휴식 | magenta | `[221,4,221]..[239,36,243]` | 309 |
| 지도 | green | `[1,240,6]..[18,250,22]` | 109 |

### 32px 판정

최종 96x64 실제 축소본의 각 32x32 셀에서 `alpha >= 32`인 픽셀을 분모로
지정 강조색 면적을 측정했다. 모든 아이콘이 요구치 30%를 넘었다.

| 아이콘 | 32px 강조색 | 면적 비율 | 판정 |
|---|---|---:|---|
| 상점 | 강한 황금 | 45.23% | 통과 |
| 수련장 | 주사 | 46.05% | 통과 |
| 파계승 | 자주 | 50.60% | 통과 |
| 샘터 | 비취·청록 | 51.93% | 통과 |
| 휴식 | 주황 | 42.15% | 통과 |
| 지도 | 미색 | 66.37% | 통과 |

32px 확대본의 어두운 배경과 밝은 배경을 모두 육안 검토했다. 상점은 세 개의
큰 금화와 열린 상자로, 수련장은 굵은 양팔과 큰 붉은 천으로, 파계승은 넓은
삿갓·굽은 석장·큰 자주 망토로 서로 분리된다. 샘터·휴식·지도도 각각 청록
수주, 큰 주황 불꽃, 미색 두루마리로 즉시 갈린다. 글자·숫자·물음표·워터마크는
없다.

### v2 후보 파일

후보는 `docs/art_candidates/tower_map_iconography/`에만 있으며 Godot 런타임
자산 경로로 승격하지 않았다. 최종 프롬프트 계열과 재생성 델타는
`s2_v2_prompt_set.md`에 기록했다.

| 파일 | 용도 | SHA-256 |
|---|---|---|
| `s2_v2_shop_raw_magenta.png` | 상점 IMAGEGEN 원본 | `064CAA9CEE90F071FE2498C22F1925C083560F1A99F5B4E76547A120BE62D86A` |
| `s2_v2_shop_alpha.png` | 상점 자동 키 제거 | `C5BAD63866EBEE5B983558FB43CFBCBE8A2D816AE0BDA336CA86812C9F9CB4D1` |
| `s2_v2_training_raw_green.png` | 수련장 IMAGEGEN 원본 | `DDB4401BBE679F03BA0E25F3F766783B122FD174A91C98213E43DC0F71BFADD7` |
| `s2_v2_training_alpha.png` | 수련장 자동 키 제거 | `736DDAB6DB91B198F7CC9A38F07A483D525208C416FBC096713437607BBCD36D` |
| `s2_v2_fallen_monk_raw_green.png` | 파계승 IMAGEGEN 최종 원본 | `6760D84F54BF5759BC03F8DF3E624B002F0D720EDF37C68177FD32296BC57C98` |
| `s2_v2_fallen_monk_alpha.png` | 파계승 자동 키 제거 | `492AABF156044AB2D4B8AB08406A534E0BE6B01430ACB1D8C9D82E3296AC0448` |
| `s2_v2_guardian_spring_raw_magenta.png` | 샘터 IMAGEGEN 원본 | `A5A603489C460E935270FE84CD43D19E158245A0E9EA247B88A897AA77622299` |
| `s2_v2_guardian_spring_alpha.png` | 샘터 자동 키 제거 | `ED4AFB1D35E0E6A989D59DDAAE072F85E16D3482315DFDD797FD2A5B29CFF78F` |
| `s2_v2_rest_raw_magenta.png` | 휴식 IMAGEGEN 최종 원본 | `7406B9C6ADAE9DC234633390936C76633D7AA77E4744F1212244CB14B0E0F1FD` |
| `s2_v2_rest_alpha.png` | 휴식 자동 키 제거 | `80DEC83F244022D4A420B3448D9D9B6F7F2DADA0B7734921A1D06244D99090D6` |
| `s2_v2_map_hint_raw_green.png` | 지도 IMAGEGEN 원본 | `8B3654B218F0DDA0A2F6B100C890243995CC7CD35249AE863E862AF2C669E149` |
| `s2_v2_map_hint_alpha.png` | 지도 자동 키 제거 | `7C5AFC2DE2F194BCC245EBBB3AE8B43B3B5CCDE59BE58ACFE7A83A90D6EFB7E4` |
| `s2_v2_noncombat_map_hint_candidate_alpha_sheet.png` | 3x2 투명 후보 시트 | `9F540B8F20B594869417053251A43F95D948D61DF2F14DDD4A0F38566643952D` |
| `s2_v2_noncombat_map_hint_candidate_dark_preview.png` | 어두운 배경 QA | `62D20455BE2E8B491AC9FA4E49B4ED9251A7612CDB3AF7E5D7DCDEFAA62181E6` |
| `s2_v2_noncombat_map_hint_candidate_light_preview.png` | 밝은 배경 QA | `41BE380952D3FDD5908635DB8251D123D83DBA5C561641B783639A23454F55A6` |
| `s2_v2_noncombat_map_hint_candidate_32px_preview.png` | 실제 32px 3x2 축소본 | `4BCC66275ABBE265D831147F0283F44E0359BB3CA1AE560512E79E775CF38432` |
| `s2_v2_noncombat_map_hint_candidate_32px_zoom8_dark_light_preview.png` | 32px nearest 8배, 암·명 배경 | `58D4B19736349716EAF138AD2AE6A6599861235B2DB565C27C3611F15DED7ED8` |

### 승인 대기 상태

S2 v2는 후보 제시 단계다. 사용자 승인 전에는 보스 14종 생성, 런타임 파일명
확정, Godot 자산 승격, `.import` 생성, S3~S5를 진행하지 않는다. S1의 글자
폴백이 계속 살아 있으므로 지도는 정상 동작한다.

## S2 v2 승인 및 S4 필러 이전 (2026-08-20)

사용자가 S2 v2의 32px 색 분리와 암·명 배경 판독성, 크로마 처리를 승인했다.
이후 후보 제작의 정본은 **아이콘별 개별 생성 + 아이콘 팔레트와 충분히 먼
녹색/마젠타 키 선택 + 자동 잔류색 게이트**다. 이 승인은 제작 방식과 후보
방향에 대한 승인이고 런타임 자산 승격 승인은 아니다.

### S4 소유권과 좌표

M 힌트 소유권을 변환된 `battle_playfield_scene_drawer.gd`에서 공용
`battle_scene_drawer.gd`의 비변환 스크린 패스로 옮겼다. 스테이지별 필러
드로어에 복제하지 않으며, 공용 `battle_view_layout`의 `game_offset`과
`game_size`로 좌측 레터박스를 계산한다.

- 필러가 충분하면 플레이필드 왼쪽에 지도 픽토그램 + `M`을 그린다.
- 필러가 없거나 폭이 부족하면 플레이필드를 덮지 않고 힌트를 숨긴다.
- 760x750 전체를 플레이필드로 유지하며 레거시 80px 인셋은 적용하지 않는다.
- 승인 전 런타임 PNG를 참조하지 않도록 지도 픽토그램은 절차 폴백으로 그린다.
  따라서 `assets/` 이동이나 `.import` 생성 없이 S4가 독립 동작한다.

### S4 검증

| 게이트 | 결과 |
|---|---|
| `tower_ascent_map_hint_smoke.gd` | `PASS=1 FAIL=0 TOTAL=1`, `All Godot smoke tests passed.` |
| touched 6-script warning scan | 경고 0건 |
| headless load | `[ApplicationQuitCoordinator] graceful headless shutdown complete`, 통과 |
| Vulkan 집중 픽셀 QA | 2020x1246, `tower_map_hint_pillar_visual_qa: ok` |
| `git diff --check` | 통과 |

Vulkan 집중 QA는 실제 `BattleSceneDrawer.new()`와 실제
`BattleViewLayout.new()`를 사용했다. 캡처에서 힌트 rect는
`(314.96, 564.356, 127.424, 52.128)`, 플레이필드 rect는
`(459.76, 80, 1100.48, 1086)`이고 교차하지 않는다.

- 캡처:
  `godot/.godot/codex_captures/tower_map_iconography/s4_map_hint_left_pillar_2020x1246.png`

전체 탑 라이브 완주 QA도 추가로 시도했으나 S4 진입 전부터 존재한 워크트리
기준선 API 불일치(`active_item_effect_renderer.gd`, Stage 2 상태 API 등)와
누락 import cache 때문에 중단됐다. S4 집중 렌더·픽셀·헤드리스 게이트와는
분리했으며 로그를
`godot/.godot/codex_logs/tower_audition_live_full_gaksi_29448_20260819192056189.log`
에 보존했다. 본 트리의 동시 편집 파일을 워크트리로 복사하거나 기준선에
혼입하지 않았다.

### 계속 유지하는 승인 경계

S3 지도 배선, 후보 PNG의 `godot/assets/` 승격, `.import` 생성은 하지 않았다.
S1 글자 폴백은 그대로 살아 있다.

## S2 보스 14종 후보 확장 (2026-08-20)

사용자 지시에 따라 `FLOOR_BOSS_SLOTS`의 실보스 14종만 확장했다. `shell`과
`new_design` 임시 슬롯은 제외했다. 모든 결과물은
`docs/art_candidates/tower_map_iconography/`에만 둔 후보이며 런타임 승격
대상이 아니다.

### 정본 제작 경로

S2 v2에서 승인된 **아이콘별 개별 생성 + 팔레트 안전 키 + 자동 잔류색
게이트**를 정본으로 확정했다.

- 분홍 계열을 쓰지 않는 11종은 마젠타 키, 분홍·장미·청보라 계열 3종은
  녹색 키를 썼다.
- 각 원본은 명시한 키로 `chroma_key.py --pad 12`를 실행했다.
- 키 배경이 수학적으로 단일 RGB라고 가정하지 않고 border-seeded dominance
  제거를 사용했다.
- clean alpha에서 보이는 키색 잔류와 네 변 nonzero alpha를 전수 계수했다.
- 수동 지우개나 수동 알파 마스크는 한 번도 사용하지 않았다.

첫 `dalji` 원본의 가는 붓끝에서 마젠타 40픽셀이 검출됐다. 수동 삭제하지
않고 원본을 반려하고 실루엣을 단순화해 재생성했다. 이름을 연상시키는
방사형 갈고리, 발바닥형 네 잎, 사각 나선, 뿔형 V도 각각 반려했다. 최종
프롬프트 계열과 반려 사유는 `s2_boss_prompt_set.md`에 기록했다.

### 32px 암·명 배경 판정

clean alpha를 32x32 셀 안의 30x30 content box에 맞춘 뒤 암·명 배경에서
각각 검사했다. `alpha >= 32`인 픽셀을 분모로 지정 강조색 면적을 측정했으며
14종 모두 요구치 30%를 넘었다.

| 순서 | `boss_id` | 강조색 | 32px 면적 | 판정 |
|---:|---|---|---:|---|
| 1 | `dalji` | 전기 코발트 | 66.45% | 통과 |
| 2 | `gaksital` | 밝은 아주르 | 65.85% | 통과 |
| 3 | `podo` | 극빙 청색 | 76.46% | 통과 |
| 4 | `cheongringwi` | 울트라마린 | 64.77% | 통과 |
| 5 | `molewang` | 옅은 페리윙클 | 72.79% | 통과 |
| 6 | `arachne` | 차가운 연분홍 | 71.54% | 통과 |
| 7 | `yeonmyo` | 산성 황록 | 69.81% | 통과 |
| 8 | `teddy_bear` | 파우더 블루 | 80.32% | 통과 |
| 9 | `alice` | 고채도 장미색 | 71.31% | 통과 |
| 10 | `ponk` | 녹색 차트리우스 | 71.86% | 통과 |
| 11 | `hongryun` | 강청 회색 | 68.95% | 통과 |
| 12 | `tetriser` | 전기 청보라 | 70.21% | 통과 |
| 13 | `akamu_rigo` | 냉은색 | 60.40% | 통과 |
| 14 | `minotaur` | 차가운 백자색 | 57.68% | 통과 |

최종 자동 게이트는 14종 모두 네 변 nonzero alpha 0픽셀, 보이는 키색 잔류
0픽셀이다. 32px 확대본을 육안 검사해 암·명 배경 모두에서 각 실루엣과
강조색을 확인했다. 승인된 비전투 6종까지 합친 20종 충돌판에서도 금·주사·
자주·비취·주황·미색과 보스 강조색이 분리된다. 최종 보스 아이콘에는
글자·숫자·룬·워터마크가 없고, 보스 이름을 직접 연상시키던 후보 실루엣은
최종 시트에서 제외했다.

- 보스 14종 32px 암·명 확대본:
  `docs/art_candidates/tower_map_iconography/s2_boss_candidate_32px_zoom8_dark_light.png`
- 승인 비전투 6종 + 보스 14종 충돌 확인판:
  `docs/art_candidates/tower_map_iconography/s2_all_20_candidate_32px_zoom8_dark_light.png`
- 실제 32px 원본:
  `docs/art_candidates/tower_map_iconography/s2_boss_candidate_32px_dark_light.png`
- 투명 후보 시트:
  `docs/art_candidates/tower_map_iconography/s2_boss_candidate_alpha_sheet.png`

### 최종 후보 무결성

| `boss_id` | 최종 raw SHA-256 | clean alpha SHA-256 |
|---|---|---|
| `dalji` | `311F3F91FD1192C3133136C08F37201C69AA99D667F56A4D6C77A5D7EBFE1BAB` | `134066F4D29A3AC72ABB5DC4B4600E43BB4567C19B46A79E1542E457998BE09C` |
| `gaksital` | `BDD0C2F78083B3662C2D7E80761CA2C14CB95BCFD3F783111FAA1BF1BA8B29CB` | `DB8A250A76291A698416E1058CEAA4013BC594BB07FB4C9B51D9072E4A328E48` |
| `podo` | `FAEA5F675A65C11E74C4AB4E4DAC022276B9DCC61224E8D7794EF85AED0425EF` | `92BC29704D08C9BA2891EB8D1EB82CD115CDB95F22C4D12F7629AC9E5E831EB3` |
| `cheongringwi` | `B70C0FFACFBD41E4198AF4B18CB39A9C4188DD56F757F60DFA01921E9063F241` | `35F9DE1961BB1B408ECF74F9725021599A4BD711DA4992F510979D75F4FADC03` |
| `molewang` | `CE4C20E6BFD688864E49D53FFDAE4472350EAD8C4E22D1FEBE7D1E7C6FA26059` | `5688C1A198C7FF9A8A94DEB6563E9297FD76B69C269B90181B35D25A88D30179` |
| `arachne` | `4B1A3FBC70A87D33D70DB1D3118F5177DFA0E1249D948F2F0F677907B75F9FE6` | `38DBEC5A2C1C1C835DAB9CEF470901DAA912E7EDCCDABFD71714784C32FCD89C` |
| `yeonmyo` | `C1587725E0E4D3EA06108F7FAF4222D9B6A52B94EA9E853950F20D3125B10A08` | `4FEAA2BCEF5BD9213570E268F651DCD8D598061EDEC0D997504EA8049D4476C0` |
| `teddy_bear` | `2C109D8C20A76BFC7D267832D8BBF6903BE142E290A35D42D8D31B1F20EA776D` | `6468355CFE9CB18EEBD81114F30AC143FD95FE0B0326A053C74E27A53CE6CE28` |
| `alice` | `A778DD337C2271E9DA1D1C6C02207CBA7493854DDA91A27E7763A74F9C459381` | `F95ED71D6AF5E746BB7709EF8E639A938FD708AC4A53C3A9020F029C2713BF97` |
| `ponk` | `F2B07C3D86F14011F79AB98D1F1137877CBBD559AD1748B8132E64620EB8F9F1` | `16B18C3E0B1072D6D40B59A81484EFA0A64888C4B84B9E9620B52A9B14B16224` |
| `hongryun` | `105EE8BB78FDAA43B7C90CC1A458B72B73355E63AF0B105A46BA44AE4B5239DA` | `6CF7AEEF6D2164BF83BA0A62CB5E71D351C392CB301985AA72AF36307AEA2CA8` |
| `tetriser` | `DE577795E706F9B4278A1AEADA8726D6BD4AA949C5265528835338F4480E9F3E` | `18D4D158960728569B7B04D877ABF70833D26745496600904227208B71886C8D` |
| `akamu_rigo` | `C2B5EE1B01ED5FDC3DC00368B8B2A698A26196BA4709C203443D3A1CABD6F723` | `54303FE47A6A0D1B3D975E0706211A0592F5D3C7E941F27E1DBD7898DED52311` |
| `minotaur` | `8F0BE93902BB2F5B565991D94D05B6BC0EBDC4CE232E6184B7D2CE5725747868` | `B6E86E0520161F1A59C3EA9D545C7AB5C3AE57394834F85D191E2A1607CD2217` |

| 합성/재현 파일 | SHA-256 |
|---|---|
| `s2_boss_candidate_alpha_sheet.png` | `CB254ECE1CF644618E5B2E2001287A0928E5244DA09BEB2948335DB5719C46B3` |
| `s2_boss_candidate_32px_dark_light.png` | `FDDAE6E4160BC219246D17E8B51CAF48C74DB51FB67AD7AF33C0110232F4CED2` |
| `s2_boss_candidate_32px_zoom8_dark_light.png` | `1812523D330191E891065842A2783CB172CF4698DC44B7D072F1BE11260958D6` |
| `s2_all_20_candidate_32px_dark_light.png` | `E0207934B2A50613767188F8B574E0766CF225D0C282F7953A8E7544781E633C` |
| `s2_all_20_candidate_32px_zoom8_dark_light.png` | `87C240BA0007DABEEE1DDAC0F23D4A3813E2E9436CFAE363978B42BA43FCB8C5` |

### 승인 대기 상태

보스 14종도 후보 제시 단계다. 사용자 승인 전에는 후보 PNG를
`godot/assets/`로 옮기지 않고 `.import`를 만들지 않으며 S3 지도 배선을
시작하지 않는다. S1 글자 폴백과 S4의 절차형 지도 픽토그램이 계속 동작한다.

## S2 보스 14종 v3 재작업 (2026-08-20)

사용자 반려에 따라 기존의 과도한 익명화 판단을 폐기했다. 정본의 뜻은
보스 고유 아이콘을 항상 보이되 이름 글자만 숨기는 것이다. 생물, 무기,
원소, 의상, 소품 모티프를 허용하고 각 보스의 실제 런타임 정체성을 담았다.
금지 범위는 글자, 숫자, 이름을 직접 표기하는 문양, 룬, 워터마크, 로고로
한정했다.

S4 코드는 승인된 `f39ed41c7` 상태에서 한 글자도 바꾸지 않았다. S3, 런타임
자산 승격, `.import` 생성도 하지 않았다. 승인된 비전투 6종은 재생성하지
않고 v2 alpha를 그대로 20종 판에 사용했다.

### 기존 반려 후보 재판정

- 테트리저의 블록 나선은 정체성 모티프가 허용되므로 기존 반려본을 그대로
  v3 최종 후보로 복권했다.
- 아라크네의 방사형 방향은 복권했다. 다만 기존본은 6갈고리라 거미로
  확실하지 않아, 정확히 8개의 굵은 다리를 가진 거미로 재생성했다.
- 미노타우로스의 뿔 방향은 복권했다. 기존본은 32px에서 황소보다 수정
  파편으로 읽혀, 황소 머리, 거대 상아색 뿔, 도끼날 조합으로 재생성했다.
- 테디베어의 발바닥 모티프 자체는 허용된다. 기존본은 파랑 계열을 세 번째로
  늘리고 누더기 장난감 정체성이 약해, 갈색 봉제 곰 얼굴로 재생성했다.
- 폰크의 글리프와 숫자형 후보는 금지 대상이므로 계속 반려했다.

프롬프트 계약, 개별 모티프, 키 선택, 반려 재판정은
`docs/art_candidates/tower_map_iconography/s2_v3_boss_prompt_set.md`에 고정했다.

### 20종 전역 색상군

보드는 같은 색상군 두 종을 이웃하게 배치했다. 넓은 색상군은 정확히
10계열이고 각 계열은 정확히 2종이다. 3종 이상 사용한 계열은 없다.

| 색상군 | 두 아이콘 | 32px 실루엣 차이 |
|---|---|---:|
| 금 | 상점, `ponk` | 46.6% |
| 주사/적 | 수련장, `gaksital` | 39.2% |
| 자주/보라 | 파계승, `tetriser` | 32.8% |
| 비취/녹 | 샘터, `cheongringwi` | 29.1% |
| 주황 | 휴식, `hongryun` | 29.0% |
| 미색 | 지도, `minotaur` | 27.1% |
| 파랑 | `podo`, `alice` | 37.9% |
| 분홍 | `arachne`, `yeonmyo` | 42.6% |
| 갈색 | `molewang`, `teddy_bear` | 42.5% |
| 먹/회색 | `dalji`, `akamu_rigo` | 33.4% |

실루엣 차이는 32px alpha 두 장의 합집합 중 서로 다른 픽셀 비율이다. 보조
하드 게이트는 18% 초과이며 실제 암·명 32px 판의 육안 판독을 주판정으로
삼았다. 최솟값은 지도 두루마리와 미노타우로스 뿔/도끼 쌍의 27.1%다.

### 32px 및 크로마 게이트

`build_s2_v3_boss_candidate_qa.py`를 재현 스크립트로 추가했다. 모든 alpha를
32x32 셀의 30x30 content box에 맞춰 측정했다.

| 게이트 | 결과 |
|---|---|
| 색상군 사용 수 | 10계열 모두 2종, 3종 이상 0계열 |
| 20종 지정 강조색 면적 | 전부 30% 이상, 최솟값 30.36% |
| 보스 14종 지정 강조색 면적 | 전부 30% 이상, 최솟값 31.90% |
| alpha 네 변 nonzero | 20종 전부 0픽셀 |
| 보스 clean alpha의 키색 잔류 | 14종 전부 0픽셀 |
| 같은 계열 쌍의 실루엣 차이 | 전부 18% 초과, 최솟값 27.1% |
| 글자, 숫자, 룬, 워터마크, 로고 | 육안 검사 0건 |
| 종단선 | `QA PASSED: no family count >= 3; edge alpha 0; keyed residue 0; all family areas >= 30%; paired silhouette union difference > 18%` |

초기 v3 달지는 분리된 상모 띠 사이에 녹색 또는 마젠타 포켓이 남아 두 번
반려했고, 모자, 띠, 장구를 하나의 겹친 실루엣으로 재생성했다. 초기 v3
포도대장은 마젠타 잔류 65픽셀, 초기 v3 폰크는 황금 면적 21.96%로 실패했다.
둘 다 수동 지우개 없이 단순한 연결형 실루엣으로 재생성했다. 최종 원본과
alpha에는 키색 잔류가 없다.

검토용 파일:

- 20종 색상군 쌍 우선 32px 암·명 확대본:
  `docs/art_candidates/tower_map_iconography/s2_v3_all_20_family_pairs_32px_zoom8_dark_light.png`
- 같은 판의 실제 32px 원본:
  `docs/art_candidates/tower_map_iconography/s2_v3_all_20_family_pairs_32px_dark_light.png`
- 보스 14종 `FLOOR_BOSS_SLOTS` 순서 32px 암·명 확대본:
  `docs/art_candidates/tower_map_iconography/s2_v3_boss_14_floor_order_32px_zoom8_dark_light.png`
- 보스 14종 실제 32px 원본:
  `docs/art_candidates/tower_map_iconography/s2_v3_boss_14_floor_order_32px_dark_light.png`
- 20종 투명 후보 시트:
  `docs/art_candidates/tower_map_iconography/s2_v3_all_20_family_pairs_alpha_sheet.png`
- 재현 로그: `docs/art_candidates/tower_map_iconography/s2_v3_qa_results.txt`

### v3 최종 후보 무결성

| `boss_id` | 최종 raw SHA-256 | clean alpha SHA-256 |
|---|---|---|
| `dalji` | `210F9C11385E376D99B2BC302696A4E3F199941FBF23067395263DBF0EA9B795` | `D751C2FCA6DEFDEBA20B9BAF91E47E5CE544183EEABD335FD778C91A71708025` |
| `gaksital` | `B639DFAB9FEE315696371A5EEFEEE3F52120C5CC9703D650B4B98AEED9DDEAFB` | `846D4C1F179E7BC3F9D62E56629746C4585321D7DD49E9035E5C8D10BC67CB5F` |
| `podo` | `CDA2F7585C4902F644BA17CB10B2D3544B9D387BACFDBB597E116D000D077351` | `17045B9ECDCECD7054E8EC753C9449B7B35DFE148547199F2542C160AFE352DE` |
| `cheongringwi` | `6B6699E40ACB8675108E4B8EB72E3CFC6F49813FEDD5E4ABCC2A3099465DD392` | `97E32E1B6FB3265290584CF47EDA191CA6A4251C400DE3DAC4F655A7F33A06CA` |
| `molewang` | `B2D6C36B44A26D13FEC06B8A30C45BD0BDB8DADA6238AA956451B5F418FA4BFB` | `DBC4E0E5BD49FF3614C0148D01563BE99A0F4F70F61E176D3BBAB9FFB144A2D2` |
| `arachne` | `E882C400226676612BD8A160F0EF6BCD50BDDBB5B50D2ADA44609346BEB1A676` | `DA161B605339BF93AE23331F9BE051E28E3927CF37B9054ED630BEED9024D3F8` |
| `yeonmyo` | `6676A96EB45E707B20FD7BA03CFC0A2415B002674B4E0A96451908F833940253` | `F473DE12F617B5418B98D6C84BD2BABB18A45673F94F3E323410760706500623` |
| `teddy_bear` | `927D8F13AABB1D278E0CFD84C35F4C3C22036A81B9B99C04A8F1034E05228460` | `6FAAE6734B6D2CFA1992D049E2BA95E61B99496C1C29F203A8D9EA8DE5DDC3A2` |
| `alice` | `9C0D16CC88947B69C21198D9B4BD94C28FCEA3E91327ED0C8A1CBD8DC8D1E147` | `476FAA2F03FCF05D44B8821098FB031E82B6EF7281095ED7D0FA3876ABB53710` |
| `ponk` | `82883998F463A13F5E1DD987E4A8015321203804C6CD9CAD30B2FDACEA9F56FF` | `DF1601258377A65A9A603B1AF47E5A219D2139A340FF189617E4EDED35E40552` |
| `hongryun` | `8FB86DF227ECE1B34C710769BCD0EFFCFF7B9A4A0FACB6C08FC3AD3620FD5289` | `92A2357255627DC08EF2EB89B09FC04BBB3545BD031DEA11353B5E8844998589` |
| `tetriser` | `BF26DD65225CABDDAEC9F387FF0DA07ACEEF325387FEBBF16B4A6A32520BD057` | `C26505BA4504F62DC3000A83D259B7EA2EDD9C2302BA64A69F92ECC3AFB2677A` |
| `akamu_rigo` | `FA49B6DD25BEBA8EDA7B42BC41710AFD5FE543ADA9D3197C4D2920F92CA7948A` | `1AD88AF6AEE72F125D22277E2C9C5C1A18A946392E693B3BCD1D171C03F83A52` |
| `minotaur` | `D183FD524FF98FAAB5B7004AD3B61A3735091AB062DBB54E57438B44633C2D58` | `A0DB46096816CD58CE5ED437721687A4543E0A093DDDF43B8382F21AE4B06618` |

### S2 v3 승인 및 런타임 승격

사용자 승인 뒤 비전투 6종과 실보스 14종, 합계 20종을
`res://assets/sprites/tower/map_icons/`에 승격했다. 런타임 PNG는 모두 RGBA
256x256이며 투명 캔버스 안에서 원본 비율을 유지해 가시 영역을 최대
240x240에 맞췄다. 따라서 가장 긴 축에도 최소 8px의 투명 여백이 남고,
네 외곽선의 nonzero alpha는 0픽셀이다.

명명 규칙은 비전투 노드가 `node_<kind>_imagegen_v1.png`, M 힌트가
`map_hint_imagegen_v1.png`, 보스가 `boss_<boss_id>_imagegen_v1.png`다.

| 분류 | 런타임 파일 | 캔버스 | 가시 영역 상한 |
|---|---|---:|---:|
| 상점 | `node_shop_imagegen_v1.png` | 256x256 | 240x240 |
| 수련장 | `node_training_imagegen_v1.png` | 256x256 | 240x240 |
| 파계승 | `node_fallen_monk_imagegen_v1.png` | 256x256 | 240x240 |
| 샘터 | `node_guardian_spring_imagegen_v1.png` | 256x256 | 240x240 |
| 휴식 | `node_rest_imagegen_v1.png` | 256x256 | 240x240 |
| M 힌트 | `map_hint_imagegen_v1.png` | 256x256 | 240x240 |
| `dalji` | `boss_dalji_imagegen_v1.png` | 256x256 | 240x240 |
| `gaksital` | `boss_gaksital_imagegen_v1.png` | 256x256 | 240x240 |
| `podo` | `boss_podo_imagegen_v1.png` | 256x256 | 240x240 |
| `cheongringwi` | `boss_cheongringwi_imagegen_v1.png` | 256x256 | 240x240 |
| `molewang` | `boss_molewang_imagegen_v1.png` | 256x256 | 240x240 |
| `arachne` | `boss_arachne_imagegen_v1.png` | 256x256 | 240x240 |
| `yeonmyo` | `boss_yeonmyo_imagegen_v1.png` | 256x256 | 240x240 |
| `teddy_bear` | `boss_teddy_bear_imagegen_v1.png` | 256x256 | 240x240 |
| `alice` | `boss_alice_imagegen_v1.png` | 256x256 | 240x240 |
| `ponk` | `boss_ponk_imagegen_v1.png` | 256x256 | 240x240 |
| `hongryun` | `boss_hongryun_imagegen_v1.png` | 256x256 | 240x240 |
| `tetriser` | `boss_tetriser_imagegen_v1.png` | 256x256 | 240x240 |
| `akamu_rigo` | `boss_akamu_rigo_imagegen_v1.png` | 256x256 | 240x240 |
| `minotaur` | `boss_minotaur_imagegen_v1.png` | 256x256 | 240x240 |

열려 있는 본 트리 에디터 PID 42120에는 접근하지 않았다. 동일 상대경로를
가진 최소 임시 프로젝트를 별도 숨김 에디터로 열어 임포트했고, 원본 SHA-256
20개 일치와 동일한 임포트 설정 블록 1종을 확인한 뒤 각 PNG의 `.import`,
그 사이드카가 직접 가리키는 `.ctex`와 `.md5`만 격리 워크트리 캐시에 선별
복사했다. 격리 워크트리에서 `.import` 20개와 참조 `.ctex` 20개가 모두
나타날 때까지 폴링했다. 설정은 lossless(`compress/mode=0`), mipmap 없음,
크기 제한 없음, `vram_texture=false`다. 헤드리스 `--import`는 실행하지 않았다.

S2 승격 커밋: `0af02b8a9` (`art(tower): promote approved map icons`).

## S3. 지도 아이콘 배선

S1에서 `tower_ascent_flow_renderer.gd`의 전체화면 지도와 플레이필드 지도 두
경로가 이미 공용 `build_map_icon_presentation(node)` 계약을 소비하도록 배선돼
있었다. S2 런타임 자산 승격으로 그 잠복 분기가 활성화됐으므로 렌더러를 다시
수정하지 않았다. 두 경로 모두 텍스처가 있으면 아이콘을 그리고
`fallback_label`이 빈 문자열이 되어 이름 글자를 그리지 않는다. 텍스처가
없을 때만 S1의 기존 글자 폴백을 그린다.

`FLOOR_BOSS_SLOTS`를 현재 코드에서 직접 순회해 `status=ported` 14종 전부가
서로 다른 `boss_<boss_id>_imagegen_v1.png`를 로드하고, 원래 보스 이름을 빈
표시 문자열로 바꾸는 것을 씰로 고정했다. `shell`과 `new_design` 슬롯은 S2
대상에서 명시적으로 제외됐으므로 고유 자산을 가장하지 않고 글자 폴백을
유지한다. 경로 서브 `ROUTE_AIM` 표적 라벨은 범위 밖이라 변경하지 않았다.

### GRT-022 소비자 감사와 상단 모서리 반증

`godot/scripts`와 `godot/scenes` 전역에서 `get_node_index_at`을 검색한 결과
생산 코드 소비자는 0개였다. M 지도 입력은 M과 ESC로 열고 닫는 읽기 전용
모달이며, 실제 경로 선택은 `ROUTE_AIM` 공과 표적의 충돌 소유권에 남아 있다.
따라서 지도 라벨 제거가 바꿀 포인터 노드 히트박스는 현재 없다.

회귀 씰은 이후 소비자가 생기는 것도 막도록 `res://scripts`의 모든 `.gd`를
재귀 검사한다. 동시에 반증은 지도 노드 반지름 8px, 중심 `(240, 180)`에서
좌상단 대각선 방향으로 7.75px 떨어진 점을 사용했다. 이 점은 정본 원에는
들어가고 중심을 `(4, 4)`만큼 민 가짜 원에는 들어가지 않는다. 반면 중심점은
두 원에 모두 들어가므로 중심점 검사가 실제 밀림을 놓치는 것도 함께
증명했다.

S3 커밋: `31ba4481d` (`feat(tower): activate map icon presentation`).

## S5. 씰과 2020x1246 캡처

| 게이트 | 결과 |
|---|---|
| 아이콘 계약 집중 씰 | `PASS=1 FAIL=0 TOTAL=1`, `All Godot smoke tests passed.` |
| 계약 + 지도 렌더 + 지도 입력 + M 힌트 | `PASS=4 FAIL=0 TOTAL=4`, `All Godot smoke tests passed.` |
| 변경 GDScript 2개 경고 검사 | 경고 0건 |
| 헤드리스 로드 | `[ApplicationQuitCoordinator] graceful headless shutdown complete`, 통과 |
| 전체 지도 Vulkan QA | Forward Mobile Vulkan, 2020x1246, 통과 |
| 누락 아이콘 Vulkan QA | Forward Mobile Vulkan, 2020x1246, 글자 폴백 확인 |
| M 힌트 Vulkan 픽셀 QA | 2020x1246, 플레이필드와 교차 0, 통과 |
| `git diff --check` | 통과 |

Vulkan 출력은 실제 `BattleSceneDrawer`, `TowerAscentFlowOwner`,
`TowerAscentFlowRenderer` 생산 경로를 사용했다. 전체 지도에서 승격 아이콘이
노드마다 나타나고, 실보스 이름은 사라지며, 상태 글자와 자산 없는 임시 슬롯의
폴백 글자만 남는 것을 육안 확인했다. 확대본은 전체 지도에서 실제로 그려진
보스 아이콘 셀을 잘라 nearest 8배로 확대한 것이다.

| 캡처 | 크기 | SHA-256 |
|---|---:|---|
| `godot/.godot/codex_captures/tower_map_overlay/map_overlay_human_realm.png` | 2020x1246 | `11CD8230D34C3D20AD8BB992ABF1B587C2A0642F8143AF9B3D15D3BB88794575` |
| `godot/.godot/codex_captures/tower_map_overlay/map_overlay_boss_icon_zoom8.png` | 실제 지도 셀의 8배 확대 | `5AA05F646E384492F1BC7B824E77C27CA20B9B745E951A29952AB658EE8E8C1B` |
| `godot/.godot/codex_captures/tower_map_overlay/map_overlay_missing_icon_fallback.png` | 2020x1246 | `426E3D525B6668E4B8BFFF7221F32EE045751A013C4BF7BAA6B80A1B907825CC` |
| `godot/.godot/codex_captures/tower_map_iconography/s4_map_hint_left_pillar_2020x1246.png` | 2020x1246 | `562FC0EF05F4D97117EA9AF29B77FF6E935A22CDE1F731CC23181B08022D5993` |

### 후속 과제

환묘 연묘 아이콘은 20종 중 유일하게 애니풍 인물 얼굴이라 현재 문장 어법에서
벗어난다. 테디베어처럼 굵고 단순한 형태로 재작업하는 것이 좋다. 사용자
지시대로 이번 승격본은 그대로 두었으며 이 항목은 후속 기록일 뿐 현재 자산을
변경하거나 다시 생성하지 않았다.
