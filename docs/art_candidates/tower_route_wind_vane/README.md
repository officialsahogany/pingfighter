# 경로 풍향계 ImageGen S1 후보 v2/v3

## 승인 상태

- 상태: **S1 시각 후보, 미승인**
- 런타임 승격: 금지. 승인 전에는 `godot/assets/` 복사, `.import`/`.ctex` 생성,
  렌더러 연결을 하지 않는다.
- 후보 범위: 먹색 옻칠·비취·주홍·황동의 미술 방향과 화살표/세기 셀의
  작은 크기 가독성을 판단하기 위한 단일 `오른쪽/보통` 상태다.
- 권장 후보: **v3**. v2보다 내부 장식을 줄이고 정확히 `112x36`으로 축소한
  검토본을 함께 두어 실제 슬롯 가독성을 직접 판단할 수 있게 했다.
- 승인 뒤에도 그대로 축소하는 것이 아니라, 아래 6개 표시 상태를 같은 외곽선과
  고정 앵커로 다시 제작하고 실제 112×36 렌더에서 심사해야 한다.

## 현재 런타임 계약 측정

- 슬롯: `112×36 px`
- 조준 원 반지름: `58 px`
- 조준 원과 풍향계 간격: `14 px`
- 앵커: 플레이어 패들 중심을 기준으로 한 조준 원 오른쪽, 세로 중앙 정렬.
  오른쪽 화면 경계를 넘으면 동일 간격으로 왼쪽에 배치한다.
- 상태: 고요함은 숨김 1개, 표시 상태는 `좌/우 × 약/보통/강 = 6개`다.
- 색 계약: 먹색 바탕, 탁한 비취, 작은 주홍 강조, 노화 황동. 네온은 사용하지 않는다.

## 후보 파일과 알파 검사

### v3 권장 후보

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

v3는 오른쪽 화살표, 정확히 3개인 세기 셀, 켜진 셀 2개와 꺼진 셀 1개가
`112x36`에서도 분리된다. 소스 자체에 투명 알파가 있어 별도 배경 제거본은 만들지
않았다.

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
