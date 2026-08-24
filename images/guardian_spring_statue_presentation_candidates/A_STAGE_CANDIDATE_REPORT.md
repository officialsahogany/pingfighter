# 샘터 석상 씬·캡슐 A단계 후보 보고

상태: **후보 전용, 승인 대기**. 런타임 등록·배선·승격은 0건이다.

## 추천 세트

| 용도 | 추천 후보 | 판정 |
| --- | --- | --- |
| 샘터 배경 | `candidates/guardian_spring_background_A_760x750.png` | 760×750, 영천·운무·조선 정원 감성, 중앙 하단 석상 여백 확보 |
| 바위석상 | `candidates/guardian_spring_statue_A_palm_stele.png` | 장승·신단 돌탑 감성, 얼굴 아래 손바닥 받침이 즉시 판독됨 |
| 호버 발광 | `candidates/guardian_spring_statue_A_glow_overlay.png` | 석상 알파와 완전 일치, 외부 halo 0, 실루엣 내부가 찬 옥백색 코어 |
| 수호령 캡슐 | `candidates/guardian_spring_capsule_B_jade_seed.png` | 투명 중앙창+곡면 하이라이트, 3열 컷인 합성에서 전신 판독 가능 |

추천 조합은 **배경 A + 석상 A + 발광 A + 캡슐 B**다.

## 원문 감성 대비

- 배경 A는 현행 v1의 비취 샘물·석정원·기와 미술 언어를 유지하면서,
  정면 출입문과 수로가 중앙 석상으로 시선을 모은다.
- 석상 A는 단순 분수대가 아니라 온화한 장승형 얼굴과 돌탑 받침을
  결합했다. 손 모양 받침은 클릭 대상의 의미를 장면만으로 전달한다.
- 발광은 평면 사각 halo나 외곽선만 쓰지 않는다. 석상 실루엣 내부를
  옥백색으로 채우고 조각·광맥을 밝히는 별도 레이어다.
- 캡슐 B는 카드 백플레이트 대신 수호령 전신을 감싸는 투명 영기
  용기다. 기존 컷인 3종을 674px 폭의 3열 규격으로 합성해 확인했다.

## 정량 검수

- 배경 A/B 후보 출력: 각각 정확히 `760×750`.
- 석상 A와 발광 A: `1024×1536`, 네 모서리 alpha `0`, 알파 마스크
  SHA-256 `e1c83eebb80e09b40a0e42617765de5b67f0ac5562d73a6d1d7aa58407ba21ef`,
  마스크 완전 일치.
- 호버 검수 합성 강한 밝기 델타 픽셀(`luma >= 32`): `71,308`.
- 캡슐 B: `1086×1448`, 네 모서리 alpha `0`; 중앙 표본에서
  `alpha <= 64` 비율 `0.677022`, 완전 투명 비율 `0.383169`.
- 상세 수치: `review/A_STAGE_QA.json`.

## 검수 산출물

- 전체 후보·원문 감성 대비 시트: `review/01_contact_sheet.png`
- 추천 씬 비호버: `review/02_recommended_scene_normal.png`
- 추천 씬 호버: `review/03_recommended_scene_hover.png`
- 추천 캡슐 3열 합성: `review/04_recommended_capsule_three_up.png`
- 재현 스크립트: `build_candidate_review.py`
- 프롬프트 원문: `IMAGEGEN_PROMPTS.md`

## 거부 후보

| 후보 | 경로 | 거부 사유 |
| --- | --- | --- |
| 배경 B | `candidates/guardian_spring_background_B_760x750.png` | 원문보다 지나치게 어둡고 누각이 우측으로 치우쳐 석상 중심 위계가 약함 |
| 석상 B | `candidates/guardian_spring_statue_B_basin_idol.png` | 분수대 인상이 강하고 손바닥을 올릴 접촉면이 즉시 읽히지 않음 |
| 석상 배경 추출 편집 | `source_raw/statue_A_background_extraction_rejected_checker.png` | 투명 알파 대신 체크 무늬가 픽셀에 구워진 24bpp RGB |
| 캡슐 A | `candidates/guardian_spring_capsule_A_glass_dome_rejected.png` | 투명 중앙창 대신 체크 무늬가 픽셀에 구워져 컷인 합성이 불가 |

## 승인 경계

- 기준 HEAD: `c6038daeb198e74b6cebdf269fb254895ebf1d7a`.
- 격리 워크트리: `D:\codex_tmp\bosspong_spring_art_c603`.
- 후보는 `images/guardian_spring_statue_presentation_candidates/`에만 있다.
- `godot/assets`, `.import`, 자산 카탈로그, 프리웜, 상태기계, 렌더러,
  입력, 테스트, CI/pre-push 목록은 수정하지 않았다.
- B단계 런타임은 추천 조합에 대한 명시적 승인 전까지 시작하지 않는다.
