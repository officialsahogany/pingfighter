# 스프라이트 소켓 합성 계약 (Socket Composition Contract)

2026-07-21 슬라이스 1 랜딩. 퍽/장비/수호령 외형 조합을 AutoSprite 시트
재생성 없이 런타임 합성으로 해결하기 위한 아키텍처의 첫 슬라이스.

## 배경 — 왜 이 계약이 필요한가

퍽 획득이 외형을 바꾸는 시스템(신속퍽 발광, 장신구, 수호령 탑승 등)을
시트로 굽으면 조합 수가 2^N으로 폭발한다. 표준 해법은 **합성**:
베이스 몸체 1벌 + 조합 요소 N개를 런타임에 레이어링하면 에셋은 N개만
필요하다. AutoSprite의 역할은 "베이스 몸체 identity 생성기"로 한정하고,
조합 외형은 아래 3개 레인이 담당한다.

| 레인 | 예 | 에셋 비용 | 소유 모듈 |
|---|---|---|---|
| A. 부착물 오버레이 | 장신구, 모자 | 파츠 PNG 1장 | `player_customization_overlay_renderer.gd` (슬라이스 2에서 소켓 승격 예정) |
| B. 셰이더/VFX | 발광, 오라, 트레일 | 캐릭터 아트 0장 | `player_socket_glow_renderer.gd` (파일럿) |
| C. 별도 엔티티 | 수호령 탑승 | 수호령 본체 + 탑승 포즈 1벌 | 슬라이스 3 (링펫 컴패니언 인프라 재사용) |

실루엣 자체가 바뀌는 변신급 외형(의상 전체 교체·체형 변화)은 합성 대상이
아니다 — 기존 변신 아이템 패턴대로 전용 시트를 유지하고, 퍽 비주얼 기획은
부착물/글로우 클래스로 설계하는 것이 규칙이다.

## 소켓 계약

**소켓 = 시트 셀-로컬 픽셀 좌표의 명명된 앵커** (`foot_l`, `foot_r`, ...).
프레임마다 실측 저작되므로 합성 레이어가 몸의 바운스/체중이동을 프레임
단위로 따라간다.

- 데이터 소유: `godot/scripts/characters/player_sprite_socket_catalog.gd`
  (모션 → 방향 → 프레임 → {socket_id: Vector2}).
- 좌표계: 저작 시트의 셀 공간(스매셔 = 160×160). 화면 매핑은
  `dest_rect.position + local / cell_size * dest_rect.size` — 몸체 draw와
  같은 rect를 쓰므로 셰이크/스케일을 자동 상속한다.
- 방향 해석: 정확 일치 → `any` → 반대 방향 미러. 미러 시 x 반전 **및**
  `_l`/`_r` id 스왑(소켓 id는 항상 화면 기준 좌/우를 가리킨다).
- fail-closed: 미저작 캐릭터/모션은 빈 dict — 소비자는 추측 위치에 그리지
  말고 스킵한다.
- 셀-기준 가드: 저작 셀 크기와 다른 시트(레거시 250×120 strip, 344×384
  공격 시트)가 funnel로 들어오면 글로우를 스킵한다. 시트 교체(환격전
  리스타일 등) 시 좌표를 손으로 고치지 말고 저작 도구를 재실행할 것.

## 저작 도구

`tools/author_player_sprite_sockets.py` (Python + PIL):

- 알파 분석 반자동 추출: 하단 밴드에서 **컬럼 두께 필터**
  (`MIN_COLUMN_THICKNESS`)로 보드 본체만 잡는다. 얇은 바닥
  스플래시/에너지 위스프 스트로크를 두께로 배제하는 것이 핵심 —
  퍼센타일 트림만으로는 스플래시가 좌우 극값을 오염시킨다.
- 산출물: 프레임별 JSON + 마커 오버레이 QA PNG + GDScript const 블록.
  QA PNG를 확대해 마커가 보드 본체 모서리에 앉았는지 확인한 뒤 카탈로그에
  붙여넣는다.
- 공격 시트는 좌/우가 독립 파일이므로 미러 가정 없이 양쪽을 각각 저작한다.

## 파일럿 배선 (모듈제어 퍽 → 옥빛 도깨비불 발광)

`dash_module_control`(모듈제어) 보유 시 미카 호버보드 양끝 하단에 옥빛
도깨비불 글로우(환격전 무협 톤). 배선 체인:

1. `battle_scene_state.gd` — `player_socket_debug_overlay_enabled` 선언
   (owner 스키마).
2. `battle_draw_playfield_scene_context.gd` — owner의
   `runtime_perk_levels`에서 레벨을 **스칼라로 투영**
   (`player_socket_glow_perk_level`). 렌더러가 퍽 dict나 display
   projection을 직접 만지지 않게 하는 것이 규칙.
3. `battle_draw_actor_context.gd` — 두 키 pass-through.
4. `stage1_player_sprite_renderer.gd`의
   `_draw_texture_with_customization_overlays` funnel —
   글로우(몸 아래) / 디버그 마커(최상단) 호출. 이 funnel이 모든 소켓
   소비자의 단일 진입점이다.
5. `player_socket_glow_renderer.gd` — 커맨드 빌드(`build_draw_commands`,
   스모크 검증면)와 캔버스 실행 분리. **가산 블렌드**
   (`CanvasItemMaterial.BLEND_MODE_ADD`, 림 셰이더와 같은
   swap-and-restore 패턴) + 5레이어 폴오프. 일반 알파 블렌드 원판은
   어두운 디스크로 읽혀 리젝됨. 레벨 오버플로우(Lv.6+)는 리포 정책대로
   계속 스케일(sanity 상한 9).

주의(QA): 가산 블렌드 콘텐츠를 투명-bg 캡처 후 외부 도구에서 알파 합성으로
프리뷰하면 실제보다 어둡게 왜곡된다. 픽셀 QA는 불투명 배경을 프로브 안에서
그린 캡처로 판정할 것 (스모크가 이 방식).

## 씰

`godot/tests/player_socket_glow_smoke.gd` — CI/pre-push focused 락스텝 등재.

- 카탈로그 수학(매핑·미러 id 스왑·`any` 폴백·독립 공격 데이터·클램프·fail-closed)
- 글로우 게이트/레이어 형태/레벨 스케일/셀-기준 가드/디버그 마커 게이트
- 실 owner 투영(divergent 케이스) + actor context pass-through + 스키마 선언
- funnel 통합: SubViewport 프로브에서 실 `draw()` 관통 + 스파이 캡처
  (headless), 가산 글로우 휘도 diff 픽셀 레그(windowed)
- 반증검증 완료: funnel 호출 제거 토글 → 스파이 레그 RED / 투영 상수화
  토글 → 투영 레그 RED (2026-07-21, in-place Edit 토글로 수행)

## 다음 슬라이스

- 슬라이스 2: `player_customization_overlay_renderer`를 고정 `dest_offset`
  → 소켓 기반 배치로 승격, 장신구 파츠 1종 퍽 연동.
- 슬라이스 3: 수호령 탑승 — 탑승 포즈 베이스 1벌(AutoSprite) + 별도
  엔티티 합성, "탑승 × 임의 퍽" 자동 성립 검증.
- 환격전 리스타일 시트 랜딩 시: 저작 도구 재실행으로 소켓 데이터만 갱신
  (계약·배선 무변경).
- 라이브 QA: 인게임에서 모듈제어 퍽 획득 → walk/dash/idle/attack 전환 중
  글로우 연속성, `player_socket_debug_overlay_enabled` 토글로 소켓 마커
  확인.
