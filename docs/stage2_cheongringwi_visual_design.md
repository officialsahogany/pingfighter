# Stage 2 청린귀 비주얼 계약

> ## ⚠️ 이 문서는 폐기된 smooth_cel 세대를 서술한다
>
> **라이브 정본은 v10 픽셀 가디언이다.** 이 문서의 규격·캐릭터 ID·후처리
> 스크립트는 2026-07-28~29 의 `smooth_cel_16f` 세대를 가리키며, 그 세대는
> 폐기됐다. 현행 런타임으로 읽지 마라.
>
> | | 이 문서(폐기) | **라이브 정본** |
> |---|---|---|
> | 격자 | 4x4 / 16프레임 / 2048x2048 | **4x2 / 8프레임 / 2048x1024** |
> | 경로 | `assets/sprites/stage2/*_smooth_cel_16f.png` | **`assets/sprites/stage2/cheongringwi/*_8f_autosprite_v10_4x2.png`** |
> | 캐릭터 | Cheongringwi Smooth Cel V9 | **Cheongringwi Pixel Guardian V10** (`cmsbj8kfd006u11mdojs33qd0`) |
> | 화풍 | 스무스 셀 (실측 고유색 34,092) | **양자화 픽셀아트 (실측 고유색 213)** |
>
> 폐기 세대는 라이브 코드 참조가 **0건**이고,
> `godot/tests/stage2_boss_idle_sprite_smoke.gd` 가 렌더러에 그 경로가 남지
> 않을 것을 단언한다("rejected smooth-cel sheet paths").
>
> **현행 계약의 정본은 문서가 아니라 매니페스트다** —
> `godot/assets/sprites/stage2/cheongringwi/stage2_cheongringwi_production_manifest.json`
> 이 `columns/rows/frame_count/cell_size/draw_size/center_offset` 와
> attack `impact_frame` 을 잠근다. 아래 본문은 폐기 세대의 이력 기록으로만
> 보존한다.

## 확정 방향

- 스테이지명: `봉인된 용소`
- 보스명: `청린귀 (靑鱗鬼)`
- 정체: 용이 되지 못하고 봉인된 이무기 무장
- 색 체계: 먹색, 청옥색, 탁한 청록, 낡은 황동, 바랜 주홍 인장
- 금지 요소: 열대 정글, 악어 군복, 네온 사이버 장식, 중앙 전투 가독성을 해치는 밀집 장식

## Stage 3 교과서 원칙

Stage 3 멘헤라걸 맵의 소재나 팔레트를 복사하지 않고 구도 원칙만 따른다.

1. 중앙 전투장은 저대비·저밀도로 비워 둔다.
2. 고밀도 장식은 좌우 기둥과 상·하단 모서리에 모은다.
3. 중앙 세로축과 원형 봉인 문양으로 시선을 정돈한다.
4. 배경, 소나무 수호목, 게임 프레임, 잔광을 서로 다른 깊이로 분리한다.
5. 움직이는 장식은 소수의 한지 봉인편·솔잎·옥빛 잔광으로 제한한다.
6. 프레임은 전장을 분명히 감싸되 Godot의 전체 `760x750` 플레이필드를 자르지 않는다.

## 런타임 호환 계약

플레이어 노출명과 미술만 교체하고 아래 내부 ID와 게임플레이 계약은 유지한다.

- `jungle_quake` → `지맥진동`
- `water_cannon` → `용소격류`
- `speed_defense` → `용린호체`
- `stage2_monkey_banana_event`의 로직 ID는 유지하되 표현은 `용소의 장난귀 + 미끄럼 호리병`으로 교체
- 기존 쿨다운, 판정, 이동 배율, 낙석 수, 격류 타이밍, 이벤트 확률은 변경하지 않는다.

## AutoSprite 출처

- 부드러운 셀 애니메이션 3등신 기준 원화: `assets/sprites/stage2/source/stage2_cheongringwi_smooth_cel_3head_anchor_imagegen_v3.png`
- 기준 캐릭터 ID: `cms4qtldz008cxhczaa3hmb6p` (`Cheongringwi Smooth Cel V9`)
- victory 기준 포즈: `cms4r35sp005zj4u8hfvo6ykd`
- defeat 기준 포즈: `cms4r36g60066j4u8vl8zm6se`
- idle: `cms4qyydx003zj4u8o6qfxfom`
- strict-front neutral walk: `cms4t8j1e00h6pt0orrcr4jea`
- attack: `cms4r9yc400czxhczquu3ixlv`
- earth stomp: `cms4r9x2g00aiu2u8ulm21cyw`
- victory: `cms4r9x0900aeu2u8mfctwkst`
- defeat: `cms4ramds00dvxhcz1bd2l6g0`

최종 런타임 시트는 위 AutoSprite 결과만 사용한다. 후처리는
`godot/tools/prepare_stage2_cheongringwi_smooth_cel.py`에서 셀별 동일 변환으로
수행한다. 각 512px 셀을 90%로 축소하고 발 기준선을 `y=454`에 맞추며,
밝은 반투명 매트 가장자리만 제거한다. 동작별 자르기나 프레임별 재배치는
허용하지 않는다.

좌·우 안정 이동은 얼굴과 흉곽을 돌리지 않는 완전 정면 사이드스텝을 쓴다.
두 런타임 경로는 같은 AutoSprite 원본 프레임을 각각 별도 파일로 패킹하며,
실제 좌·우 방향은 보스 좌표 이동으로만 전달한다. 이 방식은 패들을 반대
손으로 뒤집지 않으면서 양눈, 양어깨, 가슴 장식의 정면축을 보존한다.

머리끝부터 턱, 턱부터 골반, 골반부터 발끝을 각각 약 1단위로 보는 3등신을
기준으로 한다. 전투 중 모든 동작의 표시 영역은 `112x112`로 통일한다.
512px 셀의 실제 불투명 실루엣 높이는 약 401px이므로 기본 전투 실루엣은
약 88px이며, Stage 3 멘헤라걸의 화면 점유 높이를 기준으로
맞춘 값이다. 뿔과 꼬리는 등신 계산에서 제외하되 표시 영역 제한에는 포함한다.

미니멀 실루엣은 `청옥 머리·피부`, `먹색 갑주`, `바랜 주홍 띠`,
`원형 옥 패들`의 네 덩어리로 먼저 읽혀야 한다. 비늘 단위 텍스처,
체인메일, 리벳, 반복 금장 문양, 매듭 장식, 조밀한 갑주 분할은 금지한다.
굵은 도트, 계단형 윤곽, 디더링도 금지한다. 외곽선과 곡면은 고해상도
안티앨리어싱이 적용된 2D 셀 애니메이션으로 표현하고, 재질별 명암은
그림자 1단과 하이라이트 1단 이내로 제한한다.

이전 `*_minimal_*` 시트는 비교·롤백용 원본으로만 보존하며 런타임에서
사용하지 않는다.

장난귀 캐릭터 ID는 `cms3g97vn0009wj7secypdr2t`이며 climb 시트는
`cms3gct6e00011fg40nkmsz53`, throw 시트는 `cms3gcphq001mihwej2zqt42b`를 사용한다.
