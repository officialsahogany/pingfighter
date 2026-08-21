# 태허심법 수련 프리뷰 미표시 완료 보고

## 작업 기준

- 기준 본 트리 HEAD: `a8a5c8d45`
- 격리 브랜치: `codex/training-preview-taeheo-a8a5`
- 격리 워크트리: `D:\codex_tmp\bosspong_taeheo_preview_a8a5`
- 본 트리에 통합하거나 푸시하지 않았다.

## 원인 확정

용의자 **가**였다. 행 매핑과 호버 판정은 정상이었지만 태허심법의 투영값만
현재값과 같아졌다.

실제 렌더러 호버 경로인
`RuntimePerkOverlayRenderer._resolve_training_stat_preview()`를 태웠을 때,
stats context의 registry에는 권위 있는 `runtime_perk_state`가 있었지만 공용 신화
런타임의 호환 캐시 `runtime_perk_state_ref`는 아직 비어 있는 카드 오픈 프레임을
재현했다. 수정 전 계측은 다음과 같았다.

- `row_index=3`
- `current_fill_ratio=0.500000`
- `projected_fill_ratio=0.500000`
- `reason=no_visible_increase`

따라서 행 매칭 실패(`row_index=-1`)도, 호버 제외(빈 모델)도 아니었다.
`build_fuel_pouch_gauge_projection()`이 registry로 이미 전달된 권위 상태 대신
신화 런타임의 별도 캐시를 다시 읽어, 태허심법 한 단계의 투영 보너스를 보지
못한 것이 원인이다. 나머지 8종은 이 연료주머니 전용 경로를 타지 않아 보였다.

## 구현

- `runtime_perk_training_stat_preview.gd`가 태허심법을 투영할 때 현재 stats
  context의 `runtime_state`를 공용 연료주머니 투영 헬퍼에 명시적으로 넘긴다.
- `mythic_item_owner_syncer.gd`의 공용 투영 헬퍼는 선택적인 권위 상태를 받을 수
  있다. 값이 없으면 기존처럼 `runtime.runtime_perk_state_ref`를 읽는다.
- 최대 기력 기본값과 연료주머니 보너스 합성은 새 프리뷰 수식으로 복제하지
  않았다. `mythic_item_resource_bonus_runtime.gd`의 실제 합성 경로가 선택적인
  권위 상태를 받도록 확장해 그대로 재사용했다.
- 실제 `sync_fuel_pouch_gauge_max(runtime, owner, constants)` 호출 시에는 새
  override를 넘기지 않는다. 기존 owner 게이지/최대치와 synced cache 갱신 계약은
  그대로다.

수련 숙련도도 실제 적용 경로와 동일하다. 씰은 기본 Lv.5 + 아이템 보너스 Lv.2,
즉 유효 Lv.7의 2.4배를 사용했다. 태허심법 한 단계 `30`이 `72`가 되어 수정 후
실측은 다음과 같았다.

- `row_index=3`
- `current_fill_ratio=0.500000`
- `projected_fill_ratio=0.572000`
- `reason=projected`
- 카드 문구: `최대 기력 72 증가`

투영 뒤 실제로 한 단계를 적용해 표시값과 fill ratio가 동일한 것도 단언했다.

## 씰

개정한 `training_card_stat_preview_smoke.gd`는 `PASS=7`을 고정한다.

1. 수련 source 매핑과 제외 항목
2. 태허심법 실제 렌더러 호버, 비어 있는 호환 캐시 재현, 최대 기력 행 증가
3. 공용 `sync_fuel_pouch_gauge_max` owner/cache 갱신 무손상
4. 태허심법 포함 9종의 예측값과 실제 한 단계 적용값 일치, 그중 비태허 8종
   전부 실행 단언
5. 생산 소비자 최대치 도달 시 증가 0
6. 호버 해제·무호버 비용 0·결정론적 페이드 반복
7. 일반/탑 보상 화면 배선과 시작 카드/노드 모달 비배선

CI와 pre-push의 두 리터럴 목록은 모두 193개이고 내용 차이는 0개다. 개정 씰은
양쪽에 이미 등재되어 있어 목록 수는 늘지 않았다.

## Vulkan 캡처

- Godot 4.6.2, Vulkan Forward Mobile
- GPU: NVIDIA GeForce RTX 5070
- 해상도: 2020x1246
- 태허심법 호버 표시/숨김 구간 변경 픽셀: 437개
- 무호버와 태허심법 숨김 프레임은 파일 SHA-256까지 동일:
  `88E285C77A5A5989B413C6F9492F4BC20C6D809727C8F7CC61450C8EAFE3A92C`
- 표시 프레임 SHA-256:
  `AE78BC30A16D6EF30B412CB085D0CCF8E18D9F75B67FA760B5F3EAA5857BB8CD`
- 표시/숨김 스트립 SHA-256:
  `E133352BC50C2695B5BB2C0B228404843AC055FFDEBECA0D60659D8EFAFFC322`
- 증거 디렉터리:
  `godot/.godot/codex_artifacts/training_preview_taeheo_missing/final/`

`taeheo_hover_visible_2020x1246.png`에서 최대 기력 행의 청록 증가분이 나타나고,
`taeheo_hover_hidden_2020x1246.png`에서는 완전히 사라진다. 정지 두 장과 병합
스트립을 모두 직접 확인했다.

## 검증 결과

- 집중 smoke 5개: `PASS=5 FAIL=0 TOTAL=5`,
  `All Godot smoke tests passed.`, `SCRIPT ERROR` 0건
  - `training_card_stat_preview_smoke`
  - `angel_blessing_gauge_owner_smoke`
  - `mystic_dice_stat_apply_smoke`
  - `physique_training_category_smoke`
  - `runtime_perk_physique_training_runtime_state_refactor_smoke`
- 변경 GDScript 5개 `-Paths` 경고 스캔: 경고 0건
- 헤드리스 로드: `Godot headless load check passed.`
- `git diff --check`: 통과
- CI/pre-push 목록: 각각 193개, 차이 0개

첫 헤드리스 시도는 새 격리 트리에
`NeoDunggeunmoPro.ttf-54949569f4c9c143f532a06bc3661048.fontdata` 캐시가 없어
정식 실패했다. 본 트리와 소스 SHA-256이 같은 것을 확인한 뒤 같은 import 캐시
(SHA-256
`7F8F46EC887D4A420DB0B7D2DA5DF462F9D6D3E14BF632E630789BED3B0CAB0D`)만
격리 `.godot`에 보충했고, 새 로그의 재실행은 통과했다. 실패 로그와 통과 로그를
모두 보존했다.

작업 범위 blocked: 0건. 사용자가 제보한 본 트리에서 직접 마우스로 확인하는
라이브 체감은 지시대로 **unverified 1건**으로 남긴다.

## 커밋

1. `3a2e345fa` `fix(hud): project Taeheo gauge from hover context`
2. `5eb2b8c97` `test(hud): seal Taeheo hover preview`

본 보고서는 별도 문서 커밋으로 닫는다. 통합과 푸시는 하지 않고 대기한다.
