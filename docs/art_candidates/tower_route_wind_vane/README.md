# 경로 풍향계 ImageGen S1 후보 v2/v3/v4

## 승인 상태

- 상태: **v4b 채워지는 띠 승인 및 런타임 승격**, **v4a 굵은 눈금 반려**
- 승인 판정: 2026-08-21 사용자가 실제 `112x36`에서 방향과 세기가 즉시 읽히고,
  무풍도 자연스러우며 나침반 제거, 세기 표시, 좌우 대칭이 모두 해결됐다고 확정했다.
- v3 판정: **2026-08-21 사용자 반려**. 원본의 재질과 팔레트는 좋지만
  `112x36`에서 나침반 장미가 노이즈가 되고, 작은 구슬 셀의 켜짐/꺼짐이 약하며,
  좌우 반전 시 몸체 구성이 어색하다.
- v4 후보 범위: 같은 중앙 대칭 몸체로 만든 `왼쪽/보통`, `무풍`, `오른쪽/보통`
  세 상태와 각 상태의 실제 `112x36` 컷이다. 나침반 장미는 제거했고 구름 문양은
  모서리의 작은 대칭 장식으로만 줄였다.
- v4a 판정: **반려**. 후보 파일은 비교 provenance로만 남고 런타임에는 넣지 않았다.
- v4b 판정: **승인**. `좌/우 x 약/보통/강 = 6개`와 무풍 1개를 동일한
  `112x36` 고정 앵커의 완성 프레임으로 제작해 7셀 아틀라스로 승격했다.
- 무풍 프레임은 향후 표시 가능성을 위해 보존하지만 현행 런타임은 계속 숨긴다.

## 현재 런타임 계약 측정

- 슬롯: `112×36 px`
- 조준 원 반지름: `58 px`
- 조준 원과 풍향계 간격: `14 px`
- 앵커: 플레이어 패들 중심을 기준으로 한 조준 원 오른쪽, 세로 중앙 정렬.
  오른쪽 화면 경계를 넘으면 동일 간격으로 왼쪽에 배치한다.
- 상태: 고요함은 숨김 1개, 표시 상태는 `좌/우 × 약/보통/강 = 6개`다.
- 색 계약: 먹색 바탕, 탁한 비취, 작은 주홍 강조, 노화 황동. 네온은 사용하지 않는다.

## 런타임 승격 계약

- 런타임 PNG:
  `godot/assets/sprites/tower/route_wind_vane_imagegen_v4b_atlas.png`
- 크기와 그리드: `784x36`, RGBA, `(cols, rows, frames) = (7, 1, 7)`,
  셀 `112x36`
- 프레임 순서: `무풍, 좌약, 좌중, 좌강, 우약, 우중, 우강`
- PNG SHA-256:
  `05C7285E4BE8863E7B25C07F5722AF7A88AF503DA7ECC044B45AC2AA56E12B33`
- `.import` SHA-256:
  `E7BE43D736E5CEBC98C536792264D0C8DB31B4B7012D8E85025CE0B752A19CC8`
- import 결과: `CompressedTexture2D`, `compress/mode=0`, mipmap 없음,
  `.ctex` 27,956 bytes
- `.ctex` SHA-256:
  `DCBE764767DADE5149C2CF4C80E88986F9EFA42EB3DD2460E4BB8BE9236A42FF`

세기는 띠 부분을 런타임에서 잘라 늘리지 않는다. 약, 보통, 강을 미리 완성한 셀로
두고 `draw_texture_rect_region()`으로 셀 전체를 고른다. 이 API의 source rect는
픽셀 좌표이므로 `draw_polygon()`의 정규화 UV 함정인 GRT-033을 통과하지 않는다.

좌우도 런타임 반전을 쓰지 않고 별도 셀을 사용한다. 동일 대칭 몸체 계약은 유지하되,
황동 화살 하이라이트와 비취 띠 끝 조명을 뒤집어 조명 방향까지 반전시키지 않기
위해서다. atlas가 없거나 크기가 계약과 다르면 기존 절차 드로 풍향계로 폴백한다.
무풍 숨김은 자산 선택보다 앞선 GRT-043 조기 게이트에 남아 있어 기본 0 드로다.

## 후보 파일과 알파 검사

### v4 실제 크기 비교

- `tower_route_wind_vane_imagegen_v4_actual_comparison_232x108.png`
  - 왼쪽 열은 v4a, 오른쪽 열은 v4b다. 위에서부터 `왼쪽/보통`, `무풍`,
    `오른쪽/보통`이며 각 칸의 자산 자체가 정확히 `112x36`이다.
  - 두 열 사이에는 투명 8 px만 두었다. 확대 합성이나 런타임 자산이 아니다.
  - SHA-256: `BA4809D9700842DC135FCE0EA06D58FDE1E817795370706B7F5B597C259C21F6`

### v4a 굵은 눈금 후보, 반려

- 표시 규칙: 방향 쪽의 굵은 직사각 눈금을 중앙에서 바깥쪽 순서로 채운다.
  약은 1칸, 보통은 2칸, 강은 3칸이며 반대쪽 3칸은 꺼진다. 무풍은 6칸이
  모두 꺼지고 중앙의 황동 마름모만 남는다.
- 좌우 상태는 동일한 대칭 패널을 사용하고 중앙 화살과 켜지는 눈금 쪽만 바뀐다.
- `tower_route_wind_vane_imagegen_v4a_ticks_source.png`
  - Codex 내장 ImageGen 편집 모드로 v3를 시각 참조해 만든 3상태 원본이다.
  - 크기: `1199x1312 px`, RGBA
  - 생성기 가장자리의 고립 알파 점은 실제 상태 바깥에만 있으며 아래 알파본에서
    제거했다.
  - SHA-256: `1D9BEF56D22EE03CFEB9A715237AEEB15CA4F57BFEA521D7A940010A76CBF193`
- `tower_route_wind_vane_imagegen_v4a_ticks_alpha.png`
  - 세 상태 픽셀은 보존하고 상태 바깥의 고립 알파 점만 제거한 후보 원본이다.
  - 크기: `1199x1312 px`, RGBA, 알파 bbox `(44,112)-(1155,1170)`
  - 알파 최솟값/최댓값 `0/255`, 네 모서리는 투명하다.
  - SHA-256: `A246D65391C310C47729626AC62FE6978B838D6D1EF0DF8C3C20A47BE4F14D00`
- 실제 `112x36` 컷:
  - `tower_route_wind_vane_imagegen_v4a_ticks_left_112x36.png`, 알파 bbox
    `(2,5)-(110,30)`, SHA-256
    `B34127CAAA4ED7455ED539AEF6006E0926D41287AF0050DB818CE0F88F9AC922`
  - `tower_route_wind_vane_imagegen_v4a_ticks_calm_112x36.png`, 알파 bbox
    `(2,5)-(110,30)`, SHA-256
    `F50D50AEDCED272ECF744C8DE01E6D22BB3A139C68927F742C4203099C66B218`
  - `tower_route_wind_vane_imagegen_v4a_ticks_right_112x36.png`, 알파 bbox
    `(2,6)-(110,30)`, SHA-256
    `A6747FB20523A0A051BB9D9B742E4245C84F1110D6E24B11B1D14811D5421A18`
  - 세 컷을 원배율로 세로 배치한
    `tower_route_wind_vane_imagegen_v4a_ticks_actual_strip_112x108.png`의
    SHA-256은 `67ECA7C4BCBAD4C6BBD9FAEF580B5AD7DA927412D58A1F5AACD16B17F841967E`다.

### v4b 채워지는 띠 후보, 승인 및 승격

- 표시 규칙: 중앙에서 바람 방향으로 비취 띠가 찬다. 약은 방향 반쪽의 1/3,
  보통은 2/3, 강은 끝까지 채운다. 무풍은 띠를 비우고 중앙의 주사 마름모만
  남긴다.
- 좌우 상태는 동일한 대칭 패널을 사용하고 중앙 화살과 충전 방향만 바뀐다.
- `tower_route_wind_vane_imagegen_v4b_band_source.png`
  - Codex 내장 ImageGen 편집 모드로 v3를 시각 참조해 만든 3상태 원본이다.
  - 크기: `883x1782 px`, RGB. 생성기가 중립 체크무늬를 불투명 배경으로
    출력했다.
  - SHA-256: `94B5941A8C02AEF31DF560F1B53E8B56886112A2567DDDEBFCFDF69D64B05F2A`
- `tower_route_wind_vane_imagegen_v4b_band_alpha.png`
  - 저장소 표준 `sprite-generation/remove_bg.py`로 중립 체크무늬만 제거했다.
  - 크기: `883x1782 px`, RGBA, 알파 bbox `(27,346)-(854,1426)`
  - 알파 최솟값/최댓값 `0/255`, 네 모서리는 투명하다.
  - SHA-256: `568ACC69C6767E153AD67C2AA8F6BBC26E313E56D8D353D577CC37456D7A6DE2`
- 실제 `112x36` 컷:
  - `tower_route_wind_vane_imagegen_v4b_band_left_112x36.png`, 알파 bbox
    `(2,4)-(110,31)`, SHA-256
    `13D1EC841C428CF858AEC463DA221F2B3A66413F35A889F1390C6DA04DEEC600`
  - `tower_route_wind_vane_imagegen_v4b_band_calm_112x36.png`, 알파 bbox
    `(2,4)-(110,31)`, SHA-256
    `E365C59C8337E877E4178AFD52B576F6A9EE6BA46C2A4F9591FFB4AF55791392`
  - `tower_route_wind_vane_imagegen_v4b_band_right_112x36.png`, 알파 bbox
    `(2,4)-(110,31)`, SHA-256
    `96CB318C78DC59359C1520EA3D7BBF758A575E3DCC034ACD3A52560B19DFF6B5`
  - 세 컷을 원배율로 세로 배치한
    `tower_route_wind_vane_imagegen_v4b_band_actual_strip_112x108.png`의
    SHA-256은 `4435BB4D6FAF0F5A9938A253DFD777F4E99E6BBBCDC6F07D4C31DA070E4BDA02`다.

실제 크기 판정에서 v4b의 빈 트랙과 비취 충전 영역, 좌우 화살, 무풍 중앙 표식이
즉시 분리돼 승인됐다. v4a는 반려됐으며 승격 자산에 포함되지 않는다.

### v3 반려 후보

- `tower_route_wind_vane_imagegen_v3_source.png`
  - Codex 내장 ImageGen 편집 모드로 v2를 시각 참조해 다시 생성했다.
  - 크기: `2070x760 px`, RGBA
  - 알파 bbox: `(25,37)-(2038,744)`
  - 알파 최솟값/최댓값: `0/255`; 네 모서리는 투명하다.
  - SHA-256: `CA0CF6FA823411D22C4EC5DB874C091F462617E45293BED76B7E6A951D20B5D6`
- `tower_route_wind_vane_imagegen_v3_preview_112x36.png`
  - v3 알파 bbox를 종횡비 유지 Lanczos로 축소해 투명 `112x36` 캔버스 중앙에 둔
    승인용 실제 슬롯 검토본이다. 런타임 자산은 아니다.
  - 축소된 오브젝트: `103x36 px`; 최종 알파 bbox: `(7,3)-(105,30)`
  - SHA-256: `70DC0B2A084DFF04E35A78BE08F49FEA9458EC04D669AAA46C0151DE70FFD68C`

v3는 원본에서 재질과 팔레트가 좋았으나 실제 `112x36`에서 나침반 장미가 장식
노이즈가 되고 작은 구슬 3개의 켜짐/꺼짐이 충분히 분리되지 않았다. 나침반이 몸체
한쪽을 차지해 단순 좌우 반전도 어색하므로 사용자 판정에 따라 반려했다. 소스 자체에
투명 알파가 있어 별도 배경 제거본은 만들지 않았다.

### v2 비교 후보

- `tower_route_wind_vane_imagegen_v2_source.png`
  - ImageGen 원본: `2206×713 px`
  - 생성기가 중립 체크무늬를 불투명 배경으로 출력했다.
- `tower_route_wind_vane_imagegen_v2_alpha.png`
  - 저장소 표준 `sprite-generation/remove_bg.py`로 체크무늬만 제거한 S1 검토본
  - 크기: `2206×713 px`
  - 알파 범위: `(196, 137) - (2088, 573)`
  - 알파 최솟값/최댓값: `0/255`; 네 모서리는 투명하다.

이 후보는 112×36에 바로 넣는 런타임 산출물이 아니다. 승인되면 세기 셀과 화살표를
고정 모듈로 분리하고, 패널 안쪽 여백을 줄인 동일 비율의 상태별 원본을 만든다.

## v4 최종 프롬프트

두 프롬프트 모두 v3 원본을 Image 1 시각 참조로 넣은 Codex 내장 ImageGen
`precise-object-edit` 모드다.

### v4a 굵은 눈금

```text
Use case: precise-object-edit
Asset type: approval-only compact game HUD wind indicator kit for 환격전.
Input image: Image 1 is the rejected v3 material and palette reference. Preserve only its premium dark lacquer, aged brass, muted jade, and tiny cinnabar material language. Redesign the structure completely for actual 112 x 36 readability.
Primary request: create one vertical three-state presentation strip showing the same central-symmetric horizontal indicator body three times. Top is leftward medium wind, middle is calm, bottom is rightward medium wind. Only the arrow direction and strength activation may change between directional states.
Strength system: use six large chunky rectangular tick blocks, exactly three on each side. Medium wind lights exactly two blocks on the direction side and leaves every other block dark. Calm leaves all six blocks dark and replaces the arrow with one small centered brass diamond. Weak and strong must be naturally expressible later as one or three lit blocks.
Composition: strict front orthographic view, centered symmetric housing, thick clean silhouette, large unmistakable arrow, generous separation between the three states, transparent background. Remove the compass rose entirely. Minimize cloud motifs to tiny symmetric corner accents only.
Style: restrained Korean-fantasy UI chrome, ink-black lacquer, aged brass, muted jade, a tiny cinnabar accent, readable materials without micro-detail.
Constraints: no compass, circular dial, or compass rose; no small orbs; no text, numbers, characters, unrelated icons, logo, watermark, checkerboard, cast shadow, floor plane, neon, cyberpunk circuitry, perspective tilt, clipped edges, or asymmetric body. Prioritize 112 x 36 readability over decoration.
```

### v4b 채워지는 띠

```text
Use case: precise-object-edit
Asset type: approval-only compact game HUD wind indicator kit for 환격전.
Input image: Image 1 is the rejected v3 material and palette reference. Preserve only its premium dark lacquer, aged brass, muted jade, and tiny cinnabar material language. Redesign the structure completely for actual 112 x 36 readability.
Primary request: create one vertical three-state presentation strip showing the same central-symmetric horizontal indicator body three times. Top is leftward medium wind, middle is calm, bottom is rightward medium wind. Only the arrow direction and band fill direction may change between directional states.
Strength system: use one thick recessed horizontal band. For medium wind, fill the band from the center toward the wind direction to about two thirds of that half. Calm leaves the entire band empty and replaces the arrow with one small centered cinnabar diamond. Weak and strong must be naturally expressible later as one third or the full directional half.
Composition: strict front orthographic view, centered symmetric housing, thick clean silhouette, very large unmistakable arrow integrated with the fill direction, generous separation between the three states, transparent background. Remove the compass rose entirely. Minimize cloud motifs to tiny symmetric corner accents only.
Style: restrained Korean-fantasy UI chrome, ink-black lacquer, aged brass, muted jade fill, one cinnabar calm marker, readable materials without micro-detail.
Constraints: no compass, circular dial, or compass rose; no tick cells or small orbs; no text, numbers, characters, unrelated icons, logo, watermark, cast shadow, floor plane, neon, cyberpunk circuitry, perspective tilt, clipped edges, or asymmetric body. Prioritize 112 x 36 readability over decoration.
```

## v3 최종 프롬프트

```text
Use case: precise-object-edit
Asset type: approval-only game HUD chrome candidate for 환격전
Input images: Image 1 is the current wind-vane direction and material-language candidate; preserve its single horizontal panel concept, rightward state, exactly three strength cells, and Korean-fantasy palette, but redesign it for much clearer reduction to a 112 x 36 pixel runtime slot.
Primary request: create one high-quality compact wind-vane HUD panel showing rightward medium wind. Exactly two of three strength cells are lit and the third is dark. The direction arrow points unmistakably right.
Style/medium: premium hand-painted Korean-fantasy game UI chrome, restrained and readable, dark ink-black lacquer body, aged brass rim, muted jade lights, one tiny cinnabar accent.
Composition/framing: strict front orthographic view, single centered horizontal object, approximately 3.1:1 silhouette, generous transparent padding, thick clean outer silhouette, fewer internal ornaments and less micro-detail than Image 1 so it survives 112 x 36 reduction.
Lighting/mood: restrained material highlights, no bloom.
Constraints: genuinely transparent background; exactly one panel; exactly three strength cells; exactly two cells lit; clear right-pointing arrow; no text, numbers, characters, icons unrelated to wind, logo, watermark, checkerboard, drop shadow, floor plane, neon, cyberpunk circuitry, duplicate objects, perspective tilt, or clipped edges. Preserve small-scale readability over decorative complexity.
```

## v2 교정 프롬프트 요약

한복 문양을 직접 복제하지 않는 절제된 한국 판타지/사이버 조선 풍향계로, 먹색 옻칠,
탁한 비취, 노화 황동, 작은 주홍 보석을 사용한다. 오른쪽 화살표와 정확히 세 개의 세기
셀이 있어야 하며 보통 바람은 두 셀만 켠다. 112×36 축소 가독성을 위해 정면 직교,
굵은 외곽선, 글자·숫자·로고·네온·인물·중복 패널 없음, 한 개 오브젝트만 생성한다.
