# 지시문 W2-수정 — [P1] 이음매를 지우면서 밴드 아트를 세로로 늘려 놓았다 (보고 누락)

- **발행**: 관제탑 2026-08-26. 대상: 브랜치
  `codex/fb7-map-band-seam-20260825`(`02a11cb2d`) 위의 **추가 커밋**.
  amend/rebase 금지. 본 트리 편집·푸시·통합 금지.
- **판정**: **REJECT.** 이음매 블렌드라는 방향과 2패스 구조는 옳다.
  그러나 **밴드 아트와 종이 밑판이 청크마다 다른 배율로 세로로 늘어난다.**
  그리고 그 사실이 **보고에 없다.**
- **통합 정보**: 현재 본 트리 HEAD `45005589e` 와 `git merge-tree` **충돌 0**
  (W5가 같은 파일을 +223 바꿨지만 자동 병합 깨끗). 기준선은 그대로 두어도 된다.

---

## [P1] F1 — 목적지만 늘리고 소스 rect는 그대로 두었다

### 기전 (코드 직독 · 추측 아님)

`tower_ascent_flow_renderer.gd` `build_scroll_background_model`:

```gdscript
var draw_rect := content_rect
if alpha_ramp_world_px > 0.0:
    draw_rect.position.y -= alpha_ramp_world_px
    draw_rect.size.y += alpha_ramp_world_px      # ← 목적지가 커진다
draw_chunks.append({
    ...
    "rect": draw_rect,
    "normalized_source_rect": Rect2(
        Vector2.ZERO,
        Vector2(1.0, chunk_height / tile_size.y)  # ← ★그대로다
    ),
})
```

`_draw_scroll_texture_region`은 `normalized_source_rect`를 `world_target` 전체에
매핑한다(`source_rect = texture_size * normalized_source_size * relative_size`,
`visible_target`에 그린다). 목적지가 `alpha_ramp_world_px`만큼 커졌는데 소스
텍셀 수는 그대로이므로 **같은 픽셀이 더 높은 사각형에 펼쳐진다.**

### 배율 (계산)

```
배율 = (chunk_height + ramp) / chunk_height
ramp = min(MAP_SCROLL_BAND_SEAM_OVERLAP_WORLD_PX * tile_size.y / 320.0,
           chunk_height * 0.5)
```

`MAP_SCROLL_TILE_SIZE.y == 320.0` 기준(ramp = 56):

| chunk_height | ramp | 배율 |
|---|---|---|
| 320 (전체 타일) | 56 | **1.175 (+17.5%)** |
| 160 (행 피치) | 56 | **1.35 (+35%)** |
| 112 이하 (cap이 무는 구간) | h × 0.5 | **1.5 (+50%)** |

⚠**청크마다 배율이 다르다.** 그리고 `draw_chunks.is_empty()` 가드 때문에
**맨 첫 청크만 ramp=0 = 배율 1.0**이다. 즉 같은 밴드 아트가 화면 위치에 따라
1.0 / 1.175 / 1.35 / 1.5로 제각각 늘어난다. 이음매는 지웠지만 **아트 자체가
일그러진다.**

### ⚠종이 밑판도 같이 늘어난다

`_draw_scroll_background_model`의 **두 패스 모두** `tile.get("rect", ...)`
(늘어난 목적지)와 손대지 않은 `normalized_source_rect`를 쓴다.
1패스 `paper_texture`, 2패스 밴드 `texture` 둘 다 해당된다.
종이는 질감이라 덜 티나지만 같은 결함이다.

### 지켜야 할 불변식

> **목적지 픽셀 ÷ 소스 텍셀 비율이 모든 청크에서 동일해야 한다.**
> 겹침을 만들려고 내용을 재스케일하면 안 된다.

### 수리 후보 (택일 · 근거와 함께 보고하라)

- **(a) 소스 rect를 같이 넓힌다.**
  `normalized_source_rect.position.y -= ramp / tile_size.y`,
  `size.y += ramp / tile_size.y`.
  비율은 정확히 보존된다.
  ⚠**position.y가 음수가 되어 텍스처 밖을 가리킨다.**
  `draw_texture_rect_region`이 그 경우를 클램프하는지·랩하는지·아티팩트를
  내는지 **먼저 실측하라.** 클램프면 상단 행이 번지며 페이드인되어 이음매
  블렌드로 읽히므로 결과가 좋다. 실측 없이 채택하지 마라.
- **(b) 목적지를 늘리지 않는다. (가장 안전)**
  `content_rect` 그대로 그리고 상단 `ramp` px에만 알파 램프를 건다.
  겹침이 없으니 크로스페이드가 아니라 페이드인이지만 하드 이음매는 사라지고
  **배율 왜곡이 0이다.** 이음매가 충분히 부드러운지 픽셀로 판정하라.
- **(c) 겹침 구간을 별도 draw로 분리한다.**
  본체는 `content_rect`에 1:1로 그리고, 겹침 밴드는 소스의 **첫 `ramp` px를
  1:1 배율로** 한 번 더 위로 올려 낮은 알파로 그린다.
  내용이 중복되지만 배율은 보존된다. draw call이 청크당 3회로 는다 —
  **GRT-043 관점에서 예산을 측정해 보고하라.**

⚠어느 쪽이든 **1패스(종이)와 2패스(밴드 아트)에 같은 처리를 적용하라.**
한쪽만 고치면 두 레이어가 어긋난다.

## [P1] F2 — 보고 누락

이 변경은 **아트를 눈에 띄게 일그러뜨리는데 보고 어디에도 없다.**
V3 때 같은 계열(보고되지 않은 시각 부작용)로 반려한 이력이 있다.

앞으로 **아트의 크기·비율·위치를 바꾸는 변경은 의도했든 부작용이든 전부
보고에 명시하라.** 픽셀 QA를 돌렸다면 그 캡처에서 무엇이 달라졌는지도 적어라.

## [P2] F3 — `content_rect`가 죽은 데이터다

`draw_chunks`에 `content_rect`를 넣었는데 **저장소 어디에서도 읽지 않는다**
(`git grep content_rect 02a11cb2d -- 'godot/**'` 결과 이 파일 밖의 무관한
용례만 나온다). 두 draw 패스 모두 `rect`를 쓴다.

수리안 (b)를 택하면 `content_rect`가 곧 `rect`가 되므로 자연히 정리된다.
(a)나 (c)를 택하면 **쓰거나 지워라.** 남겨두면 다음 사람이 "겹침 보정이
되어 있다"고 오해한다.

## 확인된 무결 (재작업 금지)

- **2패스 분리는 옳다.** 종이 밑판을 전부 먼저 깔고 밴드 아트를 나중에 그려야
  뒤 청크의 종이가 앞 청크를 지우지 않는다. 주석도 정확하다.
- **청크당 draw 2회 유지**도 확인했다(`draw_call_count = draw_chunks.size() * 2`).
- **rev2 반려 대상과 구분한 판단이 맞다.** 그때 반려한 것은 그린키 매트
  추출이고, 런타임 정점 알파는 원본 RGB를 키하거나 덮어쓰지 않는다.
  코드 주석의 그 설명은 정확하다.
- `get_map_scroll_band_seam_overlap_world_px()` 접근자 추가는 씰 친화적이다.

## 씰 요구

1. **★배율 불변 씰 (필수)**: 모든 청크에서
   `world_target.size.y / (normalized_source_rect.size.y * texture_size.y)`
   가 **동일**함을 단언하라. 첫 청크(ramp=0)와 이후 청크를 **반드시 함께**
   비교하라 — 그 대조가 이 결함의 직접 반증이다.
2. **RED 반증 (필수)**: 현행 구현(소스 rect 미보정)으로 되돌리면 위 씰이
   RED가 되는지 확인하고 **원상복구**하라.
3. **경계 픽스처**: `chunk_height`가 320 / 160 / 112 이하(cap이 무는 구간)
   세 경우를 각각 덮어라. cap 구간이 최악(+50%)인데 현재 씰이 안 덮는다.
4. **종이 밑판 레그**: 1패스도 같은 배율 불변을 만족하는지 별도로 단언하라.
5. **★픽셀 QA (필수)**: `run_tower_map_band_seam_visual_qa.ps1`로
   **밴드 경계 위아래에서 같은 아트 요소의 세로 크기가 같은지** 눈으로 확인하라.
   캡처를 열어 보고 무엇을 봤는지 보고에 적어라. 자동 씰만으로 서명하지 마라.
6. **이음매 잔존 확인**: 배율을 고친 뒤에도 하드 이음매가 실제로 안 보이는지
   확인하라. 수리안 (b)는 겹침이 없으므로 이 확인이 특히 중요하다.
7. 기존 `tower_map_scroll_wiring_contract_smoke.gd` 레그가 GREEN 유지되는지.

## 게이트·보고

포커스드 스모크(+RED 반증) → `run_warning_scan.ps1 -Paths <touched>` →
`run_headless_load_check.ps1` → `git diff --check` → **픽셀 QA**.

⚠**헤드리스/스모크/스캔 실행 전 `godot/logs`를 통째로 복사하라.**
⚠래퍼는 `-AllowDuringPlay` 선언 + PID/타임스탬프 고유 `--log-file`.
**사용자의 게임·에디터를 절대 종료하지 마라.**

보고: 추가 커밋 해시 · 채택한 수리안과 근거 · **(a)를 택했다면 음수 소스 rect
실측 결과** · 씰 종단선 **원문** · RED 반증 출력 · **픽셀 캡처에서 본 것** ·
draw call 예산 변화 · `content_rect` 처리 · 미해결.
