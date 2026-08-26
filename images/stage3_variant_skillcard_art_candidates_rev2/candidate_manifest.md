# Stage 3 variant skill-card candidate rev2 manifest

## 기준과 생성 방식

- 기준 HEAD: `28e9bfdfbfeb42b20055585dd17d385ff276e29a`
- 격리 워크트리: `D:\codex_tmp\bosspong_stage3_skillcard_rev2_28e9` (detached)
- 생성 도구: built-in `image_gen`
- 유일한 시각 레퍼런스:
  `reference_only_stage3_hwangyeokjeon_boss_skill_cards_imagegen_v1.png`
- 레퍼런스 역할: 스타일 참조 전용. 기존 셀의 편집 타깃이 아님.
- 레퍼런스 SHA-256:
  `4359e687acfa15348db2f7e72ffdffeca566187ef9ef93f7378fb5118d4cddb9`
- `menhera_boss_skill_cards_imagegen_v1.png`: 생성 입력/시각 레퍼런스 0건

정본은 현재 본 트리 WIP의 미추적 PNG에서 후보 디렉터리로 바이트 복사했다.
격리 HEAD 자체에는 이 PNG가 없으며, 런타임 승격 경로에는 복사하지 않았다.

## 공통 프롬프트

```text
Use case: stylized-concept
Asset type: one horizontal Stage 3 boss skill-card interior for a game UI, final use at 256x96
Input images: Image 1 is the ONLY style reference, not an edit target. Match its restrained ink-black lacquer, jade, cinnabar, aged brass, antique-paper, painterly Korean dark-fantasy rendering language. Do not copy its existing subjects.
Style/medium: richly painted 2D game UI illustration, flat orthographic texture, not a mockup, no perspective, one strong focal symbol, readable when reduced to 256x96
Composition/framing: ultra-wide 8:3 horizontal card composition; keep the focal symbol centered and clear; reserve a quiet dark buffer around all four edges because the exact canonical brass frame will be composited later
Lighting/mood: subdued spiritual glow and deep shadows, never brighter than the reference's brightest jade/cinnabar accents, no bloom
Color palette: ink black and dark lacquer base; restrained jade green and cinnabar red accents; small aged brass highlights; muted cream only where the subject needs it
Constraints: preserve the Western Teddy Bear or Alice-in-Wonderland subject identity; no Korean folklore replacement; no generated border or frame; no text, letters, numbers, logos, watermark, UI label, extra panels, or multiple cards
Avoid: neon magenta, violet, cyan, hot pink, sci-fi neon, borderless full-bleed clutter, modern UI chrome, photorealism
```

## 스킬별 최종 소재 절

| 인덱스 | 스킬 ID | 최종 소재 | raw 생성 파일 |
|---:|---|---|---|
| 4 | `cotton_throw` | 봉제 테디가 솜뭉치를 던지고 먹빛 궤적·억제된 비취 영기가 뒤따름 | `exec-4c705579-a1e5-4a95-823b-cbd18201b35f.png` |
| 5 | `cotton_bomb` | 전신 보스 초상 없이, 봉제 구형 껍질이 터지며 솜과 주사 불티가 나오는 단일 폭탄 | `exec-4edba79a-2d94-49f1-a364-23d906fc4a16.png` |
| 6 | `deadly_hug` | 두 봉제 테디 팔이 금 간 주사빛 심장을 감싸 조임 | `exec-f2a26eed-48ed-4f60-a2d2-a63ece3ca546.png` |
| 7 | `heart_beam` | 봉제 심장에서 수평 주사빛 세 줄기가 발사됨 | `exec-7f3d66e9-a325-493e-bf40-f89645974bc7.png` |
| 8 | `mirror_world` | 한국식 원형 청동경이 아닌 빅토리아풍 타원 거울 속 뒤집힌 체크 회랑 | `exec-e96292cb-e4de-45b7-90f4-691df549a166.png` |
| 9 | `size_shift` | 옥토끼가 아닌 같은 서양 흰 토끼의 거대/극소 대비와 동심 비례 고리 | `exec-674db913-f110-4232-8e20-57b146b7dfa0.png` |
| 10 | `rabbit_projectile` | 부적이나 봉제 인형이 아닌 회중시계를 찬 흰 토끼가 먹빛 궤적으로 돌진 | `exec-d2fd185f-27c4-4d18-acc4-e10bb797d3d2.png` |

모든 raw는 `2048x768` RGB다. `cotton_bomb`는 최초 결과가 전신 테디 초상처럼
읽혀 단일 봉제 솜 폭탄으로 한 번 재생성했다.

## 프레임과 축소 처리

`build_rev2_evidence.py`가 다음을 결정적으로 수행한다.

1. raw를 왜곡 없이 `256x96`으로 Lanczos 축소한다(원본과 최종이 모두 8:3).
2. 7px 상·하 레일은 정본 네 셀의 채널별 중앙값으로 공통 프레임 픽셀만 남기고,
   18px 좌·우 레일과 24x15 모서리 금구는 정본 0번에서 픽셀 복사해 합성한다.
3. 넓은 띠를 복사하지 않고 네 셀 공통값을 쓰므로 물방울·부적·소용돌이·끈 소재가
   신규 카드에 섞이지 않는다.
4. 색상 재매핑이나 생성 후 네온 보정은 하지 않는다.

## 확장 격자 계약

```gdscript
const SKILLCARD_ATLAS_COLS := 4
const SKILLCARD_ATLAS_ROWS := 3
const SKILLCARD_ATLAS_FRAMES := 11
const SKILLCARD_ATLAS_COLUMNS := SKILLCARD_ATLAS_COLS # 기존 소비자 호환 별칭
```

- 실제 크기: `1024x288` RGBA
- 셀: `256x96`
- 행 우선 인덱스: 기존 `0..3`은 첫 행에 그대로 복사, 신규 `4..10`, `11`은 미사용
- `4x3` 선택 근거: 기존 열 수 4와 기존 좌표를 유지하면서 11프레임을 담는 최소
  직사각형이다. `3x4`는 기존 열 수와 x 좌표를 바꾸므로 채택하지 않았다.
- 런타임 소유 모듈 선언·행/열 슬라이싱은 승인 후 아틀라스 승격과 같은 헝크에서
  적용해야 한다. 승인 전에는 활성 1행 아틀라스와 계약이 어긋나므로 적용하지 않았다.

## 제출물

- 접촉 시트:
  `stage3_variant_skillcard_candidate_rev2_contact_sheet.png` (`2048x452`)
- 핵심 나란히 비교:
  `stage3_yeonmyo3_plus_variant7_rev2_one_line_comparison.png` (`2560x96`)
- 256x96 축소 판정 스트립:
  `stage3_variant7_rev2_256x96_judgement_strip.png` (`1792x96`)
- 확장 아틀라스:
  `stage3_hwangyeokjeon_boss_skill_cards_candidate_rev2_atlas_4x3_11f.png`
  (`1024x288`)
- 격자 증거:
  `stage3_hwangyeokjeon_boss_skill_cards_candidate_rev2_atlas_grid_proof.png`
- 기존 픽셀 보존 증거:
  `stage3_variant_skillcard_candidate_rev2_pixel_preservation.json`
- 기계 판독 격자 계약:
  `stage3_variant_skillcard_candidate_rev2_atlas_contract.json`

픽셀 보존 결과는 정본 네 셀 모두 `changed_pixels: 0`, `difference_bbox: null`이다.
정본 전체 RGBA 해시와 확장 아틀라스 첫 행 RGBA 해시는 모두
`983a6fd3271deda9503c4e581b77d95164b141924d8306b999527d3d8efb1ac1`이다.

## 승인 경계

후보 디렉터리 밖의 런타임 PNG 승격, ID 색인 배선, 렌더러 행/열 슬라이싱,
S4 씰, CI/pre-push 목록, 커밋, 푸시는 수행하지 않았다.
