# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 0. Implementation Boundary with `AGENTS.md`

`CLAUDE.md` is the asset-generation and offline-preparation guide.
`AGENTS.md` is the runtime-integration, performance, and implementation source of truth for Codex/agent work.

When both documents touch the same topic, use this split:
- `CLAUDE.md`: image generation prompts, sheet layout rules, background removal, output paths, naming
- `AGENTS.md`: `pingfighter.py` integration, sprite loader behavior, runtime scaling, caching, lazy-load, hot-path performance

Important:
- Do not assume a large 2K source sheet can be pushed into the hot runtime path without extra review.
- If a sprite class or `pingfighter.py` integration is involved, hand off the final runtime decision to Codex following `AGENTS.md`.
- If there is any conflict about runtime behavior or performance, `AGENTS.md` wins.

## ⚠️ CRITICAL: Gemini MCP 캐릭터 스프라이트 시트 제작 가이드 (Character Sprite Sheet Creation)

**Gemini MCP(`mcp__gemini__gemini-generate-image`)로 보스/캐릭터 스프라이트를 만들 때 반드시 이 규칙을 따를 것. 스테이지9 타우렌 보스 제작 과정에서 확립된 모범 사례임.**

### ⚠️ 작업 분담 (Claude vs Codex)

| 단계 | 담당 | 이유 |
|------|------|------|
| **스프라이트/이미지 제작** | **Claude** | Gemini MCP 프롬프트 설계, 컨셉 반복, 누끼 알고리즘 같은 **창작/생성** 작업이 Claude 강점 |
| **게임 코드에 삽입/연동** | **Codex** | `pingfighter.py`의 보스 렌더 루프, 스킬 분기, 물리 후킹 등 **코드–기존 구조 정합성** 작업은 Codex 강점 |

전형적인 플로우:
1. Claude가 Gemini MCP로 스프라이트 시트/배경 이미지 생성 → `items/`, `backgrounds/`에 누끼 PNG 저장
2. Claude가 `entities/[name]_sprite.py` 같은 **독립 스프라이트 클래스**까지 작성 (렌더/애니메이션 로직)
3. **이후 pingfighter.py 내부에 연동(import + 보스 렌더 교체 + 공격 트리거 연결 등)은 Codex에게 맡김**

이 원칙은 Claude Code의 auto-memory(`~/.claude/projects/d--main-bosspong/memory/feedback_claude_vs_codex.md`, repo 밖)에 저장된 피드백과 일치 — 기획/아이디어/창작은 Claude, 코드–기존 구조 정합성은 Codex. (repo에서 grep 해도 안 나오므로 혼동 주의)

### 1. 스타일 통일 — 기존 보스와 맞추기 (⚠️ 가장 중요)

기존 보스 스프라이트(boss_stage1~8.png)는 모두 **16-bit 레트로 픽셀아트 + 치비 비율**이다. Warcraft 페인터리, 일러스트 스타일, 포토리얼 절대 금지.

| 항목 | 필수 조건 |
|------|----------|
| 아트 스타일 | 16-bit 픽셀아트, SNES/Stardew Valley/Pokemon 느낌 |
| 비율 | 치비/슈퍼데포르메 — 머리 ≈ 전체 키의 40~50% |
| 외곽선 | 두꺼운 검정 픽셀 아웃라인 (thick black pixel outline) |
| 색상 | 플랫한 저채도 팔레트, hard-edged 픽셀 |
| 렌더링 금지 사항 | painterly shading, soft gradient, photorealism, anti-aliased blur |

프롬프트 영문에 반드시 포함: `"16-bit retro pixel art, chibi proportions, thick black pixel outlines, flat limited-saturation palette, clean hard-edged pixels, NO painterly rendering, NO soft shading, NO photorealism"`

### 2. 캐릭터 크기/스케일 — 셀 내 45~55%만 채우기

치비 캐릭터가 셀 전체를 꽉 채우면 게임 내에서 다른 보스 대비 너무 커 보인다.

프롬프트에 반드시 명시 (무기/아이덴티티 문구는 보스별로 교체):
```
Each character fills only about 45-55% of each cell's height.
Keep the character SMALL and COMPACT — do NOT fill the cell.
Leave generous empty white/transparent margin around each sprite.
This is a small chibi boss sprite, NOT a full-body portrait.
```

> ⚠️ 위 블록에 "paddle-wielding" 같은 무기 한정어를 넣지 말 것. 무기는 섹션 4에서 보스별로 명시하고, 이 블록은 크기 규칙만 담당.

기본 타겟 크기 예시 (`TaurenBossSprite`): `width=72, height=80` — 다른 보스와 균형 맞음.

### 3. 얼굴 표정 — "귀엽게" 나오지 않도록

기본 프롬프트로는 **너무 귀여운 얼굴**이 생성되기 쉽다. 다음 키워드로 강제:

- `fierce and cool, NOT cute`
- `serious/determined/intense expression`
- `narrow focused eyes with glowing white pupils`
- `furrowed brow`
- `slight frown showing tusks/fangs`
- `tribal markings or battle scars on face`

단, 명시적으로 폭력/유혈을 연상시키는 단어(`angry`, `scarred`, `blood`, `gore`, `intimidating` 등)는 Gemini content filter에 걸려 **400 INVALID_ARGUMENT** 에러가 남. 대신 `fierce / serious / determined / focused / heroic champion` 같은 우회 표현을 사용 (섹션 9 매핑 표 참조).

> ⚠️ `fierce`와 `warrior`는 단독으로는 필터에 걸리지 않아 **허용 단어**로 취급. 섹션 9에서 이 단어들이 "금지→우회" 표에 잘못 들어가 있었는데, 실제로는 `fierce and cool, NOT cute` / `warrior` 조합이 프로덕션 프롬프트에서 정상 통과했음.

### 4. 무기/아이덴티티 — 명확하게 지정

게임 장르에 맞춰 무기를 **구체적으로** 지정. 기본 프롬프트는 제너릭 무기를 생성함.

예시:
- 핑퐁 게임 보스: `"holding a red ping-pong paddle in his right hand"` (필요시)
- 거대 토템 보스: `"holds a MASSIVE tribal totem pole diagonally across body in both hands — giant wooden staff taller than himself, carved with ancestral faces and runes, decorated with red and yellow feathers and bone charms, leather wraps around grip"`
- 무기 제거 시: `"NO ping-pong paddle anywhere"`, `"NO [unwanted item]"` 명시

무기가 프레임마다 위치가 바뀌면 애니메이션이 어색해짐 → `"weapon stays in same hand position across all frames"` 지시.

### 5. 스프라이트 시트 구성 — 8프레임 4×2 그리드 (걷기/공격/대쉬)

| 용도 | 그리드 | 비율(aspectRatio) | 프레임 수 | 구성 |
|------|--------|-------------------|-----------|------|
| **걷기 사이클** | 4×2 | `16:9` | 8 | row1: (1)좌발 contact (2)좌발 high/우발 rising (3)passing (4)우발 contact / row2: (5)우발 high (6)passing (7)좌발 variant (8)loop transition |
| **공격 애니메이션** | 4×2 | `16:9` | 8 | row1: (1)ready (2)wind-up (3)backswing (4)max charge / row2: (5)swing start (6)impact+motion line (7)follow-through (8)recovery |
| **대쉬/슬라이딩** | 4×2 | `16:9` | 8 | row1: (1)웅크림 준비 (2)발진 푸시오프 (3)풀 슬라이딩 (4)최대 확장+트레일 / row2: (5)슬라이딩 지속+파티클 (6)감속 (7)회복 상승 (8)스탠딩 복귀 |
| **아이템 아이콘** | 단일 | `1:1` | 1 | 중앙 정렬, 32px/64px 기준 |

프롬프트에서 반드시 지시:
```
- Pure flat white background (#FFFFFF) in every cell
- NO grid lines, NO borders, NO dividers, NO labels between cells
- Each cell exactly equal size, character centered
- Character view is exactly front-facing in every frame
- Identical character design/palette/scale across all frames
- Keep foot/baseline position consistent across frames
```

### 5-1. ⚠️ 시트 간 바디 스케일 일관성 (Cross-Sheet Body Scale Lock)

**같은 보스의 걷기/공격/대쉬 시트는 반드시 동일한 바디 스케일을 공유해야 한다.**
이 규칙을 어기면 대쉬/공격 시 캐릭터가 갑자기 커지거나 작아지는 버그가 발생한다.

#### 에셋 생성 규칙 (Gemini MCP 프롬프트)

| 규칙 | 설명 |
|------|------|
| 바디 크기 기준 = 걷기 시트 | 공격/대쉬 시트의 머리·몸통·골반 크기는 걷기 시트와 ±5% 이내 |
| 역동성 표현 방법 | 포즈, 기울기, 팔다리 압축, 머리카락/옷 흔들림, 불꽃/트레일/모션 라인 사용 |
| 금지 | 캐릭터 몸체 자체를 축소/확대하여 속도감 표현 금지 |
| 이펙트 영역 | 이펙트(먼지, 불꽃, 파티클)는 셀 밖으로 확장 가능하되 바디 스케일은 유지 |

프롬프트에 반드시 포함:
```
The character's HEAD, TORSO, and PELVIS must be the SAME SIZE as the walking sheet.
Do NOT shrink the body to show speed — use pose, lean, and motion lines instead.
Effects (dust, flames, trails) may extend outward, but the body itself stays the same scale.
```

#### 스프라이트 클래스 구현 규칙 (entities/[name]_sprite.py)

```python
# ❌ 잘못된 예 - 프레임별 독립 trim + 재스케일 (대쉬가 커짐)
frame = self._trim_to_visible_bounds(frame)  # 대쉬는 세로가 낮아짐
frame = self._scale_to_target(frame)          # → 더 크게 확대됨!

# ✅ 올바른 예 - 걷기 시트 기준 공유 스케일 적용
# 1. 걷기 시트 로드 시 기준 스케일 팩터 계산 후 저장
# 2. 공격/대쉬 시트에 동일한 스케일 팩터 적용
# 3. 이펙트/트레일 영역은 투명 여백으로 남기되 바디는 같은 크기
```

**핵심**: `_trim_to_visible_bounds()` + `_scale_to_target()`을 시트별로 독립 실행하면,
세로가 낮은 대쉬 프레임이 목표 높이까지 더 크게 확대된다.
걷기 시트에서 계산한 스케일 팩터를 공격/대쉬에 그대로 적용해야 한다.

### 5-2. ⚠️ 시트 간 캐릭터 정체성 일관성 (Character Identity Lock Across Sheets)

**Same boss, same character, same identity across all sheets.**

걷기/공격/대쉬 시트는 같은 보스의 **같은 캐릭터**여야 한다. 크기(5-1)만 맞춰도 머리색, 얼굴, 분위기가 달라지면 게임 내에서 다른 캐릭터로 보인다. 스테이지 3 멘헤라걸에서 걷기 시트와 대쉬 시트가 서로 다른 캐릭터처럼 생성된 사례로부터 확립된 규칙이다.

#### Canonical Reference = Walking Sheet

이미 `items/[name]_boss_sheet.png`가 존재하면 그것이 **정체성 기준(canonical reference)**이 된다. 공격/대쉬 시트를 만들 때는 반드시 이 파일을 기준으로 다음 요소를 **그대로 유지**해야 한다:

| 고정 요소 (절대 변경 금지) | 예시 |
|---------------------------|------|
| 머리색 (hair color) | pink → pink (magenta로 드리프트 금지) |
| 헤어 스타일 / 실루엣 | 곱슬 웨이브 → 곱슬 웨이브 (직모로 변경 금지) |
| 얼굴 형태 / 인상 | 치비 둥근 얼굴 → 동일 (성숙한 날카로운 얼굴로 변경 금지) |
| 눈 색상 / 형태 / 표정 계열 | 올리브 큰 눈 → 동일 |
| 피부톤 | 밝은 톤 → 동일 |
| 신체 비율 (치비/등신) | 2등신 치비 → 동일 (3등신으로 변경 금지) |
| 의상 디자인 / 실루엣 / 장식 배치 | 핑크 간호사복 + 검정 트림 → 동일 |
| 종족 특성 / 액세서리 / 시그니처 모티프 | 고양이 꼬리, 고양이 발 장갑, 간호사 모자+리본 → 동일 |

#### 바뀌어도 되는 것 (역동성 표현용)

포즈, 기울기, 모션 라인, 이펙트(불꽃/먼지/파티클), 옷/머리카락 흔들림, 트레일 — **이것만** 바뀔 수 있다.

**Do not redesign the boss between walk / attack / dash sheets.**
**Effects may change, pose may change, but the character identity must remain unmistakably the same.**

#### Color Palette Drift 금지

같은 캐릭터인데 시트마다 색감이 달라지는 것을 금지한다:

| ❌ 금지되는 드리프트 | 설명 |
|---------------------|------|
| pink hair → magenta hair | 채도/색상 시프트 |
| pastel tone → saturated tone | 톤 시프트 |
| cute round face → sharp mature face | 인상 시프트 |
| chibi 2-head → semi-realistic 3-head | 등신 시프트 |
| thick outlines → thin outlines | 스타일 시프트 |

#### 작업 절차 (공격/대쉬 시트 생성 전 필수)

1. **기존 걷기 시트 확인**: `items/[name]_boss_sheet.png`를 열어 캐릭터의 고정 요소를 확인
2. **고정 요소 요약 작성**: 프롬프트에 넣을 캐릭터 설명을 걷기 시트 기준으로 정리
3. **프롬프트에 canonical reference 명시**: 아래 블록을 프롬프트에 포함
4. **결과물 검증**: 생성된 시트가 걷기 시트와 같은 캐릭터로 보이는지 확인
5. **불합격 시 재생성**: 다른 캐릭터처럼 보이면 채택하지 말고 재생성

프롬프트에 반드시 포함:
```
Use items/[name]_boss_sheet.png as the canonical visual reference for identity, palette, and design continuity.
This character MUST look like the EXACT SAME person as in the walking sheet.
Do NOT redesign, reinterpret, or modernize the character.
Keep the SAME hair color, hairstyle, face shape, eye color, skin tone, outfit design, and all signature accessories.
If the result looks like a different character, it must be rejected and regenerated.
```

#### 검증 체크리스트 (시트 생성 후)

| # | 확인 항목 | 합격 기준 |
|---|----------|-----------|
| 1 | 머리색 | 걷기 시트와 동일 (채도/색상 드리프트 없음) |
| 2 | 헤어 스타일 | 같은 실루엣 (흔들림은 OK, 형태 변경은 NG) |
| 3 | 얼굴 인상 | 같은 캐릭터로 즉시 인식 가능 |
| 4 | 의상 | 같은 옷, 같은 장식 배치 |
| 5 | 액세서리/모티프 | 모두 존재 (누락 금지) |
| 6 | 전체 분위기 | "같은 사람이 다른 동작을 하고 있다"로 읽힘 |
| 7 | 아트 스타일 | 걷기 시트와 동일한 렌더링 스타일 |

> **If the dash sheet looks like a different character, reject and regenerate.**

### 5-3. 방향 전환(Turn / Facing Transition) 보조 시트 규칙

**This is a turn / facing transition sheet, not a replacement for the main walking sheet.**

turn 시트는 **선택적(optional) 보조 시트**다. walk/attack/dash 같은 필수 시트가 아니라, 캐릭터가 좌↔우 방향을 바꾸는 짧은 순간에만 잠깐 보여주기 위한 런타임 보조 자산이다.

#### 목적 (Purpose)

| 용도 | 설명 |
|------|------|
| 좌 → 우 방향 전환 | 왼쪽으로 이동하다 오른쪽으로 바꿀 때 |
| 우 → 좌 방향 전환 | 오른쪽으로 이동하다 왼쪽으로 바꿀 때 |
| idle/정면 복귀 | 정지 상태에서 정면으로 자연스럽게 돌아올 때 |

**이 시트는 평소 걷기 애니메이션을 대체하지 않는다.**
평상시 이동은 기존 걷기 시트로 처리하고, 방향이 바뀌는 **짧은 순간에만** turn 시트로 잠깐 전환한 뒤 다시 걷기 시트로 복귀하는 게 기본 사용법이다.

#### Canonical Reference = Walking Sheet

- **Use the walking sheet as the canonical identity and body-scale reference.**
- turn 시트도 `items/[name]_boss_sheet.png`를 정체성 기준으로 사용한다.
- **Do not redesign the character between turn frames.**
- **If the turn sheet looks like a different character, reject and regenerate.**
- 섹션 5-2의 고정 요소 8항목(머리색, 헤어스타일, 얼굴, 눈, 피부톤, 비율, 의상, 액세서리)을 모두 그대로 유지해야 한다.

#### 바뀌어도 되는 것 (오직 이것만)

- 몸 방향 (body orientation)
- 시선 방향 (gaze direction)
- 어깨선 / 골반 각도
- 팔/다리/꼬리/리본/옷자락의 앞뒤 겹침

#### 바뀌면 안 되는 것

- 머리색 / 헤어스타일 / 얼굴형
- 비율 / 아트 스타일
- 의상 디자인 / 액세서리 구성
- **단순 이미지 회전 필터로 돌린 것처럼 보이면 안 됨** — 실제로 각 각도에서 다시 그린 재드로잉이어야 함

#### 권장 포맷

| 항목 | 값 |
|------|----|
| 프레임 수 | 13프레임 (7×2 그리드, 마지막 셀은 공백) |
| row1 | `+90°, +75°, +60°, +45°, +30°, +15°, 0°` |
| row2 | `-15°, -30°, -45°, -60°, -75°, -90°`, (빈칸) |
| sign convention | `+90°` = 완전 우측 프로필, `0°` = 정면, `-90°` = 완전 좌측 프로필 |
| aspectRatio | `16:9` |
| imageSize | `2K` |
| 배경 | 순백 `#FFFFFF`, grid/border/divider/label 없음 |
| 바디 스케일 | 걷기 시트와 ±5% 이내 (섹션 5-1 준수) |

#### 인접 프레임 보간성 (Runtime 사용성)

- **Neighboring frames must interpolate cleanly from one body orientation to the next.**
- turn 시트는 런타임에서 **짧은 전환용**으로 재생되기 때문에, 인접 각도 프레임끼리 튀지 않고 부드럽게 이어져야 한다.
- 15도 간격의 부드러운 변화가 기본. 각도가 튀면 전환 순간에 깜빡거리는 느낌이 난다.
- `This sheet is intended for brief runtime direction changes, not for the full walking cycle.`

#### 파일 배치

| 파일 | 경로 |
|------|------|
| turn 시트 (원본) | `items/[name]_boss_turn.jpeg` |
| turn 시트 (누끼) | `items/[name]_boss_turn.png` |

#### 검증 체크리스트

| # | 확인 항목 | 합격 기준 |
|---|----------|-----------|
| 1 | 걷기 시트와 동일 캐릭터로 보이는가 | ✅ |
| 2 | 고정 요소(머리색/헤어/얼굴/의상/액세서리) 모두 유지 | ✅ |
| 3 | 인접 각도 프레임이 부드럽게 이어지는가 | ✅ |
| 4 | 몸 방향/겹침/시선만 변하고 캐릭터는 유지되는가 | ✅ |
| 5 | 단순 회전 필터처럼 보이지 않고 재드로잉으로 읽히는가 | ✅ |
| 6 | 바디 스케일 걷기 시트 ±5% 이내 | ✅ |

> **If the turn sheet looks like a different character, reject and regenerate.**

### 6. 해상도/비율 설정

| 파라미터 | 권장값 | 비고 |
|----------|--------|------|
| `aspectRatio` | `16:9` (4×2 그리드용), `1:1` (2×2 또는 단일) | `4:1` 직접 지원 안 함 |
| `imageSize` | `2K` | 4K는 누끼 처리 느림, 1K는 세부 손실 |
| `style` | `"16-bit retro pixel art, chibi, flat colors, thick outlines"` | 필수 |

### 7. 누끼(배경 제거) 처리 — 2단계 hard-edge 알고리즘 (오프라인 전처리)

**이 섹션은 "오프라인 PNG 생성"용 필수 절차다.** Gemini가 생성한 `items/[name]_sheet.jpeg`를 깨끗한 `items/[name]_sheet.png`로 변환할 때 사용. 런타임 로더(섹션 8)는 이 PNG를 우선 읽고, PNG가 없을 때만 JPEG + 간이 colorkey로 폴백한다. 두 단계를 섞어 쓰지 말 것 — 오프라인에서 halo 깔끔하게 제거한 PNG를 commit하는 게 원칙이다.

**JPEG으로 생성되면 테두리에 압축 아티팩트로 halo 픽셀이 남는다. 단순 colorkey로는 해결 안 됨.** 다음 알고리즘 필수:

```python
# d:\main\bosspong\items\[name].jpeg → [name].png 변환
from PIL import Image
import numpy as np
from collections import deque

def remove_sprite_bg(src_jpeg, dst_png):
    img = Image.open(src_jpeg).convert('RGBA')
    arr = np.array(img)
    h, w, _ = arr.shape
    r = arr[:,:,0].astype(np.int16); g = arr[:,:,1].astype(np.int16); b = arr[:,:,2].astype(np.int16)
    lum = (r+g+b)/3.0
    sat = np.maximum(np.maximum(r,g),b) - np.minimum(np.minimum(r,g),b)

    # 1단계: 모든 테두리 픽셀을 시드로 flood fill
    #         (lum >= 200 & sat <= 30 인 픽셀만 배경으로 간주)
    whitish = (lum >= 200) & (sat <= 30)
    visited = np.zeros((h, w), dtype=bool); q = deque()
    for x in range(w):
        for y in (0, h-1):
            if whitish[y, x]: visited[y, x]=True; q.append((y,x))
    for y in range(h):
        for x in (0, w-1):
            if whitish[y, x] and not visited[y, x]: visited[y, x]=True; q.append((y,x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((-1,0),(1,0),(0,-1),(0,1)):
            ny, nx = y+dy, x+dx
            if 0<=ny<h and 0<=nx<w and not visited[ny,nx] and whitish[ny,nx]:
                visited[ny,nx]=True; q.append((ny,nx))
    bg_mask = visited
    arr[bg_mask, 3] = 0

    # 2단계: 2-ring hard halo kill
    #         (bg 인접 1~2픽셀 중 lum >= 150 & sat <= 40 픽셀 완전 투명화)
    def dilate(m, times=1):
        d = m.copy()
        for _ in range(times):
            n = d.copy()
            n[1:,:] |= d[:-1,:]; n[:-1,:] |= d[1:,:]
            n[:,1:] |= d[:,:-1]; n[:,:-1] |= d[:,1:]
            d = n
        return d
    for ring in range(1, 3):
        dil = dilate(bg_mask, ring)
        halo = dil & ~bg_mask & (lum >= 150) & (sat <= 40)
        if halo.any():
            arr[halo, 3] = 0
            bg_mask = bg_mask | halo

    # 3단계: mild halo (약간 유채색 섞인 것) 제거
    edge2 = dilate(bg_mask, 1) & ~bg_mask
    mild = edge2 & (lum >= 180) & (sat <= 60)
    if mild.any(): arr[mild, 3] = 0

    Image.fromarray(arr).save(dst_png, 'PNG', optimize=True)
```

**핵심 원칙:**
- 단순 `colorkey=(255,255,255)` 또는 tolerance만으로는 **외곽선 지저분함** (JPEG halo 남음)
- **flood fill 시작 시드를 테두리 전체 픽셀**로 (간헐적 샘플링 X)
- **hard-kill** 방식이 픽셀아트에 맞음 (알파 페더링은 블러 유발)
- 캐릭터 내부의 밝은 색(뿔, 금장식)은 flood fill로 접근 불가 → 자동 보존됨

### 8. 스프라이트 클래스 통합 — `TaurenBossSprite` 패턴 참조

[entities/tauren_boss_sprite.py](entities/tauren_boss_sprite.py) 구조를 템플릿으로 사용. 이 클래스 내부의 배경 제거 로직은 **런타임 폴백용 간이 처리**(밝은 배경 제거 + halo cleanup)이며, 섹션 7의 오프라인 알고리즘을 대체하는 게 아니라 PNG 미존재 시 JPEG을 겨우 쓸 수 있게 해 주는 안전망일 뿐이다.
- PNG 우선 로드, JPEG는 폴백 (폴백 시 품질 저하 감수)
- `FRAME_INSET` 으로 그리드 선/여백 제외 (값 14 권장)
- `_trim_to_visible_bounds()` 바운딩 박스로 여백 제거
- `_scale_to_target()` target 크기에 비율 유지 스케일
- 걷기 + 공격 분리 관리 (`_frames_right`, `_attack_frames_right`)
- `trigger_attack()` — 공격 1회 재생 후 idle 복귀

### 9. Gemini content filter 회피 전략

400 INVALID_ARGUMENT 에러가 나면 다음 키워드 교체 (실제 필터 경험 기반):
| 금지 (걸린 적 있음) | 우회 |
|---------------------|------|
| battle, weapon | champion, guardian, wielding [구체 도구명] |
| angry, scarred | serious, determined, focused, fierce |
| skull, blood, gore | stylized animal head, ceremonial, tribal |
| intimidating, threatening | imposing, heroic, cool |

> 참고: `fierce`와 `warrior`는 단독 사용 시 필터를 통과함 (프로덕션 검증됨) — 금지어로 취급하지 말 것. 조합에서 문제가 될 때만 `serious`/`champion`으로 교체.

이유를 알 수 없는 에러는 프롬프트를 짧게 축약하거나 분리 생성 후 수동 병합.

### 10. 파일 배치 규약

| 파일 | 경로 | 예시 |
|------|------|------|
| 스프라이트 시트 (원본) | `items/[name]_sheet.jpeg` | `items/tauren_boss_sheet.jpeg` |
| 스프라이트 시트 (누끼) | `items/[name]_sheet.png` | `items/tauren_boss_sheet.png` |
| 공격 애니메이션 | `items/[name]_attack.{jpeg,png}` | `items/tauren_boss_attack.png` |
| 대쉬 애니메이션 | `items/[name]_dash.{jpeg,png}` | `items/honglyeon_boss_dash.png` |
| 배경 이미지 | `backgrounds/stage[N]_*.jpeg` | `backgrounds/stage9_pillar_left.jpeg` |
| 스프라이트 클래스 | `entities/[name]_sprite.py` | `entities/tauren_boss_sprite.py` |

두 버전(JPEG 원본 + PNG 누끼) 모두 보관 → 배경 제거 알고리즘 재실행 가능하도록.

### 11. 스프라이트 시트 제작 프롬프트 템플릿 (Copy-Paste Ready)

**사용법**: `[name]`, `[보스명]`, `[실제 스테이지 번호]` 등 대괄호 부분만 교체하면 즉시 사용 가능.
공통 주의: 실제 스테이지 번호와 코드상 `current_stage`가 다를 수 있으면 둘 다 명기할 것 (섹션 "Stage Order Reference" 참조).

#### 11-1. 걷기 시트 (Walking Sheet)

```
d:\main\bosspong\CLAUDE.md 기준으로 실제 스테이지 [실제 스테이지 번호] [보스명]
(코드상 current_stage == [코드 스테이지 번호]) 걷기 스프라이트 시트를 생성해줘.

목표:
- [캐릭터 설명]
- [손에 든 요소 / 분위기 / 표정]
- 귀여움보다 [원하는 인상] 중심
- 기존 items/[name]_boss_sheet.png가 있으면 디자인 연속성 유지

디자인 고정 요소:
- [의상]
- [헤어]
- [눈색]
- [소품/이펙트]
- thick black pixel outline 유지

사이즈/구성 규칙:
- 8-frame walking sheet, 4x2 grid, aspectRatio 16:9, imageSize 2K
- Pure flat white background (#FFFFFF) in every cell
- NO grid lines, NO borders, NO dividers, NO labels
- Character view is exactly front-facing in every frame
- Keep foot/baseline position consistent across frames
- Identical character design/palette/scale across all frames
- Use the walking sheet as the body-scale reference for this boss
- Body silhouette size must stay consistent across all future attack/dash sheets (±5%)
- Leave generous empty margin around each sprite

걷기 모션 요구:
- 보폭 차이, 체중 이동, 어깨/골반 counter-swing 강조
- 머리카락 / 리본 / 옷자락 / 소품 흔들림을 프레임마다 분명히
- 작은 체형이어도 존재감 있는 보스처럼 보이게

스타일 규칙:
- 16-bit retro pixel art, chibi proportions, thick black pixel outlines
- flat limited-saturation palette, clean hard-edged pixels
- NO painterly rendering, NO soft shading, NO photorealism

출력:
- 먼저 items/[name]_boss_sheet.jpeg로 생성
- 그 다음 CLAUDE.md 섹션 7의 오프라인 누끼 절차로 items/[name]_boss_sheet.png 생성
- 코드 수정은 하지 말고 스프라이트 시트만 생성해줘
```

#### 11-2. 공격 시트 (Attack Sheet)

```
d:\main\bosspong\CLAUDE.md 기준으로 실제 스테이지 [실제 스테이지 번호] [보스명]
(코드상 current_stage == [코드 스테이지 번호]) 공격 스프라이트 시트를 생성해줘.

목표:
- [캐릭터 설명]
- [공격 콘셉트]
- 표정은 fierce / cool / dominant / serious 계열
- 귀여움보다 위압감과 카리스마 중심

디자인 고정 요소:
- [의상]
- [헤어]
- [눈색]
- [무기/불꽃/오라]
- walking sheet와 동일한 body scale 유지

공격 시트 구성 규칙:
- 8-frame attack sheet, 4x2 grid, aspectRatio 16:9, imageSize 2K
- row1: ready, wind-up, backswing, max charge
- row2: swing start, impact with motion line, follow-through, recovery
- Pure flat white background (#FFFFFF) in every cell
- NO grid lines, NO borders, NO dividers, NO labels
- Character view is exactly front-facing in every frame
- Keep foot/baseline position consistent across frames
- Character body scale must match the walking sheet (±5%)
- Effects may grow larger, but the body itself must not become larger or smaller
- Leave generous empty margin around each sprite

공격 모션 요구:
- 준비 → 차징 → 비틀기 → 발사/타격 → 후딜 흐름이 명확해야 함
- 팔 궤적, 상체 회전, 체중 이동, 머리카락/의상 흔들림을 크게 살릴 것
- impact frame은 전진 에너지와 압력이 느껴지게

스타일 규칙:
- 16-bit retro pixel art, chibi proportions, thick black pixel outlines
- flat limited-saturation palette, clean hard-edged pixels
- NO painterly rendering, NO soft shading, NO photorealism

출력:
- 먼저 items/[name]_boss_attack.jpeg로 생성
- 그 다음 CLAUDE.md 섹션 7의 오프라인 누끼 절차로 items/[name]_boss_attack.png 생성
- 코드 수정은 하지 말고 공격 스프라이트 시트만 생성해줘
```

#### 11-3. 대쉬 시트 (Dash Sheet)

```
d:\main\bosspong\CLAUDE.md 기준으로 실제 스테이지 [실제 스테이지 번호] [보스명]
(코드상 current_stage == [코드 스테이지 번호]) 대쉬 스프라이트 시트를 생성해줘.

목표:
- [캐릭터 설명]
- [대쉬 성격: 돌진형 / 슬라이딩형 / 순간이동풍 / 저공 활주형]
- 빠르고 위협적이지만 캐릭터 body scale은 걷기 시트와 동일하게 유지

디자인 고정 요소:
- [의상]
- [헤어]
- [눈색]
- [대쉬 시 파티클/트레일]
- walking sheet와 동일한 head/torso/pelvis scale 유지

대쉬 시트 구성 규칙:
- 8-frame dash sheet, 4x2 grid, aspectRatio 16:9, imageSize 2K
- row1: crouch prep, push-off, low slide, full extension + trail
- row2: sustained slide + particles, deceleration, recovery rise, standing return
- Pure flat white background (#FFFFFF) in every cell
- NO grid lines, NO borders, NO dividers, NO labels
- Character view is exactly front-facing in every frame
- Keep foot/baseline position consistent where possible
- Character body scale must match the walking sheet (±5%)
- Dash should feel faster through pose, lean, trail, motion lines, cloth/hair drag
- Do NOT make the body smaller or larger just to make the dash feel faster
- Leave generous empty margin around each sprite

스타일 규칙:
- 16-bit retro pixel art, chibi proportions, thick black pixel outlines
- flat limited-saturation palette, clean hard-edged pixels
- NO painterly rendering, NO soft shading, NO photorealism

출력:
- 먼저 items/[name]_boss_dash.jpeg로 생성
- 그 다음 CLAUDE.md 섹션 7의 오프라인 누끼 절차로 items/[name]_boss_dash.png 생성
- 코드 수정은 하지 말고 대쉬 스프라이트 시트만 생성해줘
```

#### 11-4. Codex 연동 요청 (Runtime Integration Hand-off)

```
새 에셋 생성 완료.

생성된 파일:
- items/[name]_boss_sheet.png
- items/[name]_boss_attack.png
- items/[name]_boss_dash.png

이제 AGENTS.md 기준으로 Codex가 런타임 연동을 진행해줘.

요청:
- pingfighter.py에 [보스명] 스프라이트 로더/렌더/트리거 연동
- walk / attack / dash 모두 걷기 시트 기준 body scale 공유
- per-sheet trim-and-rescale 때문에 체감 크기가 달라지지 않게 처리
- 런타임 반복 전처리 최소화
- 필요한 경우 캐시 / lazy-load / 재사용 가능한 frame data 적용
- 공격 모션은 공 타격 타이밍에 맞게
- 대쉬 모션은 실제 대쉬 발동 시점에만 재생
- 적용 후 py -3 -m py_compile로 확인
```

---

## Project Overview
PingFighter (핑파이터) is a Python-based arcade-style table tennis game with boss battles, power-ups, and special abilities. Built with Pygame framework and runs on both Windows and macOS.

## ⚠️ CRITICAL: Stage Order Reference (스테이지 순서 - 절대 헷갈리지 말 것!)
**과거에 스테이지 5와 6의 순서가 바뀌었음! 코드 변수명과 실제 스테이지 번호가 다름!**

| Stage | Boss Name | Theme | Pillar | 코드 내 변수명 (주의!) |
|-------|-----------|-------|--------|----------------------|
| 1 | 풍악보이 | 한국 전통 | pillar_stadium | stage1 |
| 2 | 악어장군 | 정글/늪지 | pillar_jungle | stage2 |
| 3 | 멘헤라걸 | 멘헤라/인형 | pillar_menhera | stage3 |
| 4 | 퐁크 | 사원 | pillar_temple | stage4 |
| **5** | **네메시스** | **해상전투 (Ocean/Battleship)** | pillar_nemesis_ocean | **animated_bg_stage6** (주의!) |
| **6** | **홍련** | **중국/화염 (Chinese Fire)** | (추가 예정) | **animated_bg_stage5** (주의!) |
| 7 | 테트리서 | 테트리스 아레나 (Tetris Arena) | - | stage7 / `game_logic/stage7_tetriser.py`, `stages/stage7_boss.py` |
| 8 | 아카무 리고 | 닌자 도조 (Shadow Dojo, 임시로 stage7_field 재사용) | - | stage8 / `entities/stage8_boss_sprite.py` |

### ⚠️ 매우 중요: 코드 변수명 vs 실제 스테이지
- 코드에서 `stage5`, `animated_bg_stage5`, `Stage5ChineseMarket` = **실제 스테이지 6 홍련**
- 코드에서 `stage6`, `animated_bg_stage6`, `AnimatedBackgroundStage6` = **실제 스테이지 5 네메시스**
- **유저가 "스테이지 5 작업해줘" → 네메시스(해상) 관련 코드 수정**
- **유저가 "스테이지 6 작업해줘" → 홍련(화염) 관련 코드 수정**

### 스테이지 작업 시 주의사항
- **스테이지 5 = 네메시스 (해상전투/바다 테마)** - 전함, 바다, 레이더, 파도
- **스테이지 6 = 홍련 (중국/화염 테마)** - 중국 전통, 불꽃, 등롱

## ⚠️ CRITICAL: 화면 좌표 표준 규격 (Screen Coordinate Standards)
**아이템, 스킬, 투사체, 이펙트 등 모든 좌표 작업 시 반드시 이 규격을 따를 것!**

### ⚠️ 핵심: 게임 물리 영역 = 전체 화면 (0 ~ WIDTH)
**공, 패들, 투사체, 이펙트 등 모든 게임 오브젝트는 0 ~ 760 전체 너비에서 동작한다.**
필러(좌우 80px)는 게임 영역 위에 덮어 그리는 **UI 오버레이**일 뿐, 물리적 경계가 아니다.

```
┌─────────────────────── 760px (WIDTH) ───────────────────────┐
│          게임 물리 영역: 0 ~ 760 (공, 패들, 투사체 전부)       │
│                                                              │
│  ┌─ 필러 ─┐                                    ┌─ 필러 ─┐   │
│  │ 0~79   │      UI 오버레이 (위에 덮어 그림)     │680~759 │   │
│  │ 80px   │      아이템 스폰 중앙: 380px         │ 80px   │   │
│  └────────┘                                    └────────┘   │
│                                                              │
│  공 반사: BALL.left <= 0 → 반사 / BALL.right >= WIDTH → 반사  │
└──────────────────────────────────────────────────────────────┘
```

### 화면 크기 상수 (config/constants.py 참조)
| 상수명 | 값 | 설명 |
|--------|-----|------|
| `WIDTH` / `INTERNAL_WIDTH` | **760px** | **실제 게임 물리 영역 너비 (공/패들/이펙트 모두 이 범위)** |
| `HEIGHT` / `INTERNAL_HEIGHT` | **750px** | 전체 높이 |
| `PILLAR_UI_WIDTH` | **80px** | 좌우 필러 UI 오버레이 각각의 너비 (물리 경계 아님!) |
| `GAME_AREA_OFFSET_X` | **80px** | 필러 너비 (UI 배치용으로만 사용) |
| `GAME_PLAY_WIDTH` | **600px** | 필러 제외 중앙 영역 (UI 배치/아이템 스폰 기준용) |

### ⚠️ 좌표 작업 시 어떤 너비를 써야 하는가?
| 작업 종류 | 사용할 너비 | 범위 | 이유 |
|-----------|-------------|------|------|
| **이펙트/방어막/벽** | `WIDTH` (760) | 0 ~ 760 | 공이 전체 너비에서 움직이므로 |
| **공 반사/패들 이동** | `WIDTH` (760) | 0 ~ 760 | 물리 경계 = 전체 화면 |
| **아이템 스폰 위치** | `GAME_PLAY_WIDTH` (600) | 80 ~ 680 | 필러 뒤에 숨지 않도록 |
| **UI 요소 배치** | `GAME_PLAY_WIDTH` (600) | 80 ~ 680 | 필러와 겹치지 않도록 |
| **보스/패들 중앙 X** | `WIDTH // 2` (380) | - | 전체 화면 기준 중앙 |

```python
# ❌ 잘못된 예 - 이펙트/방어막에 GAME_PLAY_WIDTH 사용
barrier_left = GAME_AREA_OFFSET_X  # 80 → 틀림! 좌측 80px가 비어버림
barrier_width = GAME_PLAY_WIDTH    # 600 → 틀림! 실제 게임 영역보다 좁음

# ✅ 올바른 예 - 이펙트/방어막은 전체 너비 사용
barrier_left = 0       # 화면 시작
barrier_width = WIDTH  # 760 (전체)

# ✅ 올바른 예 - 아이템 스폰은 필러 제외 영역
spawn_x = GAME_AREA_OFFSET_X + random(0, GAME_PLAY_WIDTH)  # 80 ~ 680
```

### 게임 객체 Y 좌표 (매우 중요!)
| 객체 | Y 좌표 | 설명 |
|------|--------|------|
| **보스 패들** | `BOSS_Y = 25` | 화면 상단 25px |
| **보스 히트박스 하단** | `~65px` | BOSS_Y(25) + BOSS_HEIGHT(40) |
| **보스 진영 영역** | `Y = 0 ~ 120` | 보스가 활동하는 상단 영역 |
| **중앙선** | `Y = 375` | HEIGHT / 2 |
| **플레이어 패들** | `Y = 710` | HEIGHT(750) - 40 |
| **플레이어 진영 영역** | `Y = 630 ~ 750` | 플레이어가 활동하는 하단 영역 |

### 진영 구분 기준 (투사체, 아이템 판정용)
| 진영 | Y 좌표 범위 | 판정 기준 |
|------|-------------|-----------|
| 보스 진영 | `Y < 120` | 보스 패들 주변 영역 |
| 중립 지대 | `120 ≤ Y < 630` | 공이 왕복하는 영역 |
| 플레이어 진영 | `Y ≥ 630` | 플레이어 패들 주변 영역 |

## Architecture & Code Structure

### Core Files
- **pingfighter.py** - Main game file (25,829 lines) containing all game logic
- **academy.py** - Academy mode with skill system and training features
- **gacha.py** - Gacha system for item collection
- **opening.py** - Opening cinematic and menu system
- **items.py** - Item definitions and management
- **legendary_items.py** - Legendary item system
- **pixel_font_manager.py** - Font management with pixel art support

### Module Organization
```
bosspong/
├── core/               # Core systems (game state, constants, events)
├── game_logic/         # Game mechanics (physics, collision, AI)
├── game_mechanics/     # Special mechanics (half-dash system)
├── entities/           # Game objects (ball, paddle, boss)
├── ai/                 # AI and boss behavior systems
├── managers/           # Resource and effect managers
├── ui/                 # UI components (menus, HUD, dialogs)
├── rendering/          # Rendering systems
├── item_effects/       # Modular item effect implementations
├── events/             # Stage-specific event systems
├── backgrounds/        # Animated background systems
└── tests/              # Test files for various components
```

## Development Commands

### Running the Game
```bash
# macOS/Linux
python3 pingfighter.py

# Windows
python pingfighter.py
# or use the batch file:
run_game.bat
```

### Testing
```bash
# Test icon loading
python3 test_icons.py

# Test specific features
python3 test_[feature_name].py

# Run all tests with pytest
python -m pytest tests/
```

### Building Executables

#### Windows Build
```bash
# Using PyInstaller spec file
pyinstaller PingFighter_Windows.spec

# Manual build
pyinstaller --onefile --windowed \
  --add-data "items;items" \
  --add-data "sounds;sounds" \
  --add-data "fonts;fonts" \
  --add-data "backgrounds;backgrounds" \
  --icon="ball.ico" \
  pingfighter.py
```

#### macOS Build  
```bash
# Using PyInstaller spec file
pyinstaller PingFighter.spec

# Manual build (note the colon separator for macOS)
pyinstaller --onefile --windowed \
  --add-data "items:items" \
  --add-data "sounds:sounds" \
  --add-data "fonts:fonts" \
  --add-data "backgrounds:backgrounds" \
  --icon="ball.ico" \
  pingfighter.py
```

### Dependencies
```bash
# Install all dependencies
pip install -r requirements.txt

# Core requirements:
# - pygame>=2.5.0
# - numpy>=1.21.0
# - pyinstaller>=5.0.0 (for building)
# - pytest>=7.0.0 (for testing)
```

## Critical Development Guidelines

### Cross-Platform Path Handling
**ALWAYS use the resource_path() function for file access:**
```python
def resource_path(relative_path):
    """Get absolute path to resource, works for dev and PyInstaller"""
    try:
        base_path = sys._MEIPASS  # PyInstaller temp folder
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    
    relative_path = relative_path.replace('/', os.sep).replace('\\', os.sep)
    return os.path.join(base_path, relative_path)

# Usage example:
font_path = resource_path(os.path.join("fonts", "NanumSquareB.ttf"))
icon_path = resource_path(os.path.join("items", "technical_vest.png"))
```

### Item Icon Management
**Icons MUST be declared globally and assigned to ITEM_TYPES:**
```python
# 1. Declare globally at module level
technical_vest_icon = None

# 2. Use global keyword in initialization
def initialize_icons():
    global technical_vest_icon  # REQUIRED!
    technical_vest_icon = pygame.Surface((32, 32), pygame.SRCALPHA)
    # ... draw icon ...
    
    # 3. Assign to ITEM_TYPES dictionary
    items.ITEM_TYPES["TECHNICAL_VEST"]["icon"] = technical_vest_icon
```

### Korean Text Rendering
**Use pygame.freetype with appropriate fonts:**
```python
import pygame.freetype

# Initialize Korean font
korean_font = pygame.freetype.Font(
    resource_path(os.path.join("fonts", "NanumSquareB.ttf")), 24
)

# Render text
text_surface, text_rect = korean_font.render("한글 텍스트", (255, 255, 255))
```

## Game Systems & Integration Points

### Academy Skill System
State variables that must be reset on game session end:
```python
acceleration_skill_level = 0     # Dash sound restoration
acceleration_height_bonus = 0    # Bustup skill paddle height bonus
rolling_charges = 1              # Basic dash tokens without amplification
rolling_charge_timer = 0         # Dash token charge timer
```

Reset locations (3 places):
1. Game over - around line 20185
2. ESC menu return to main - around line 20965
3. Force quit flag - around line 20506

### Trade Point System
- `trade_point_collected`: Stars collected in current stage (resets per stage)
- `academy.skill_points`: Total skill points available (persists between stages)
- Base reward: 1 point per stage clear

### Event Processing Order (ESC Menu)
**IMPORTANT: Call pygame.event.get() before key state checks to prevent input freezing:**
```python
# Correct order:
for event in pygame.event.get():  # Process events first
    # handle events
keys = pygame.key.get_pressed()    # Then check key states
```

## Adding New Items - Complete Workflow

### Step 1: Create Item Module
Create in `item_effects/[item_name].py`:
```python
class [ItemClassName]:
    def __init__(self):
        self.active = False
        self.duration = 3600  # 60 seconds at 60 FPS
        
    def activate(self, game_state, current_stage):
        # Activation logic
        pass
    
    def update(self, current_stage):
        # Update logic
        pass
    
    def draw_effects(self, screen, **kwargs):
        # Visual effects
        pass

# Singleton instance
[item_name]_instance = None

def get_[item_name]_instance():
    global [item_name]_instance
    if [item_name]_instance is None:
        [item_name]_instance = [ItemClassName]()
    return [item_name]_instance
```

### Step 2: Register in items.py
```python
# Add to ITEM_TYPES array
{
    "name": "[item_name]",
    "color": (R, G, B),
    "effect": "[item_name]",
    "icon": None,
    "chance": 0.01,  # 1% spawn chance
    "duration": 600,
    "unlock_condition": None
}

# Add to unlocked_items
"[item_name]": True
```

### Step 3: Create Icon (REQUIRED)
- Create 32x32 PNG at `items/[item_name].png`
- Required for item to appear in TAB menu

### Step 4: Integrate in pingfighter.py
1. Import module (top of file)
2. Add to item manager UI (line ~14245)
3. Add Korean name (line ~24219)
4. Add item description (line ~24257) - **MUST include detailed effects**
5. Add activation handler (line ~2327)
6. Update get_item_icon() function (line ~14680) - **REQUIRED for icon display**

### Checklist for New Items
- [ ] Create `item_effects/[item_name].py` module
- [ ] Add to `items.py` ITEM_TYPES array
- [ ] Add to `items.py` unlocked_items
- [ ] Create `items/[item_name].png` icon (32x32)
- [ ] Add to item manager UI
- [ ] Update get_item_icon() function **[CRITICAL]**
- [ ] Add Korean name translation
- [ ] Add detailed item description **[CRITICAL]**
- [ ] Add activation handler
- [ ] Add update loop (for active items)
- [ ] Add visual effects rendering (if needed)
- [ ] Update gacha.py (for one-time passive items)
- [ ] Create `test_[item_name].py` test file

### ⚠️ CRITICAL: 패시브 아이템 추가 시 필수 체크리스트
**패시브 아이템이 필드에서 드랍/획득되지 않는 버그 방지를 위해 반드시 아래 모든 항목을 확인할 것!**

| # | 파일 | 위치 | 작업 내용 |
|---|------|------|----------|
| 1 | `items.py` | `ITEM_TYPES` 배열 | 아이템 정의 추가 (`chance`, `body_part` 등) |
| 2 | `items.py` | `unlocked_items` 딕셔너리 | `"[item_name]": True` 추가 **[필수!]** |
| 3 | `items.py` | `[item_name]_obtained` 변수 | 전역 변수 선언 (예: `gold_digger_obtained = False`) |
| 4 | `items.py` | `update_items()` 함수 내 패시브 목록 | 아이템 이름 추가 **[필수! 없으면 액티브로 처리됨]** |
| 5 | `items.py` | `spawn_random_item()` 내 `passive_names` | 아이템 이름 추가 (드랍 가중치 계산용) |
| 6 | `items.py` | `spawn_random_item()` 내 중복 방지 로직 | `if item["name"] == "[item_name]" and [item_name]_obtained...` 추가 |
| 7 | `items.py` | `PASSIVE_DUPLICATE_ALLOWED` 집합 | 중복 파밍 허용 시 추가 |
| 8 | `pingfighter.py` | `store_active_item()` 패시브 필터 목록 | 아이템 이름 추가 (액티브 슬롯 방지) |
| 9 | `pingfighter.py` | `store_passive_item()` 함수 | `elif item_data["name"] == "[item_name]":` 처리 추가 |
| 10 | `pingfighter.py` | `store_passive_item()` 중복 허용 로직 | **중복 허용 아이템은 `skip_append = True` 사용 금지!** ⚠️ |

```python
# items.py - update_items() 내 패시브 목록 (약 2227줄)
if item_name in ["speedboots", "speedgear", ..., "[NEW_ITEM_NAME]"]:

# items.py - spawn_random_item() 내 passive_names (약 2060줄)
passive_names = {
    "speedboots", "speedgear", ..., "[NEW_ITEM_NAME]"
}

# pingfighter.py - store_active_item() 패시브 필터 (약 59683줄)
if item_data["name"] in ["speedboots", ..., "[NEW_ITEM_NAME]"]:
    return
```

### ⚠️ CRITICAL: 중복 획득 허용 아이템의 store_passive_item() 구현 패턴
**PASSIVE_DUPLICATE_ALLOWED에 포함된 아이템은 반드시 아래 패턴을 따를 것!**

```python
# ❌ 잘못된 예 - 중복 획득 시 인벤토리에 추가 안됨
elif item_data["name"] == "gold_digger":
    if not items.gold_digger_obtained:
        items.gold_digger_obtained = True
        # 효과 적용...
    else:
        print("이미 보유 중입니다.")
        skip_append = True  # ❌ 이 줄이 문제! 두 번째 획득 시 인벤토리에 추가 안됨

# ✅ 올바른 예 - 중복 획득 시에도 인벤토리에 정상 추가
elif item_data["name"] == "gold_digger":
    # 첫 획득 시에만 활성화/장착 처리
    if not items.gold_digger_obtained:
        items.gold_digger_obtained = True
        from item_effects.gold_digger import activate_gold_digger, equip_gold_digger
        activate_gold_digger()
        equip_gold_digger()
        print("첫 획득!")
    # 롤 옵션과 인벤토리 추가는 항상 실행 (skip_append 없음!)
    item_data["type"] = "passive"
    ensure_passive_rolls(item_data)
    apply_roll_bonuses_from_item(item_data)
    show_item_obtained_effect(item_data, item_data.get("x"), item_data.get("y"))
    # skip_append = True 절대 사용 금지!
```

**핵심 규칙:**
1. `PASSIVE_DUPLICATE_ALLOWED`에 포함된 아이템은 `skip_append = True` **절대 사용 금지**
2. 첫 획득 시에만 `obtained` 플래그 설정 및 효과 활성화
3. 롤 옵션 적용(`ensure_passive_rolls`, `apply_roll_bonuses_from_item`)은 **매번 실행**
4. 인벤토리 추가는 함수 끝에서 자동으로 처리됨 (skip_append가 False일 때)

### ⚠️ CRITICAL: 전설 아이템 추가 시 필수 체크리스트
**전설 아이템은 패시브 체크리스트 + 아래 추가 항목 모두 확인!**

| # | 파일 | 위치 | 작업 내용 |
|---|------|------|----------|
| 1 | `legendary_items.py` | 클래스 정의 | `class [ItemName](LegendaryItem):` 생성 |
| 2 | `legendary_items.py` | `LEGENDARY_ROLL_OPTIONS` | 롤 옵션 정의 추가 |
| 3 | `legendary_items.py` | `LegendaryItemManager._init_legendary_items()` | 아이템 인스턴스 생성 |
| 4 | `pingfighter.py` | `get_item_icon()` 전설 아이템 목록 | 아이템 이름 추가 **[필수! 없으면 아이콘 ?로 표시]** |
| 5 | `pingfighter.py` | 전설 아이템 획득 플래그 동기화 | `sync_bool()` 호출 추가 |
| 6 | `items.py` | `spawn_random_item()` 내 `legendary_names` | 아이템 이름 추가 (스폰 배율용) |
| 7 | `downtown/constants.py` | `LEGENDARY_ITEM_NAMES` | 아이템 이름 추가 |
| 8 | `downtown/building_interior.py` | 상점 전설 아이템 목록 | 상점 판매용 아이템 추가 |

```python
# pingfighter.py - get_item_icon() 전설 아이템 목록 (약 95453줄)
if item_name in ["hermes_shoes", "ragnarok_hammer", "poseidon_trident",
                 "angel_blessing", "sacred_laurel", "transcendent_crown", "[NEW_LEGENDARY]"]:

# items.py - spawn_random_item() 내 legendary_names (약 2043줄)
legendary_names = {"ragnarok_hammer", "hermes_shoes", ..., "[NEW_LEGENDARY]"}
```

### ⚠️ CRITICAL: 전설 아이템은 중복 획득이 가능해야 함 (skip_append 금지!)
**모든 전설 아이템의 `store_passive_item()` 구현에서 `skip_append = True`를 절대 사용하지 않는다.**
전설 아이템은 롤 옵션 파밍을 위해 중복 획득이 허용되며, 필드/뽑기/상점/보물찾기 등 모든 경로에서 동일하게 적용된다.

```python
# ❌ 잘못된 예 - 두 번째 획득 시 인벤토리에 추가 안됨
elif item_data["name"] == "legendary_item":
    if not items.legendary_item_obtained:
        items.legendary_item_obtained = True
        # 첫 획득 처리...
    else:
        print("이미 보유 중입니다.")
        skip_append = True  # ❌ 절대 금지!

# ✅ 올바른 예 - 중복 획득 시에도 인벤토리에 정상 추가
elif item_data["name"] == "legendary_item":
    if not items.legendary_item_obtained:
        items.legendary_item_obtained = True
        # 첫 획득: 해금, 애니메이션 트리거 등
        legendary_manager = get_legendary_manager()
        if "legendary_item" not in legendary_manager.unlocked_items:
            legendary_manager.unlocked_items.append("legendary_item")
            legendary_manager.items["legendary_item"].unlocked = True
        trigger_legendary_acquisition(...)
    # 모든 획득(첫/중복 모두): 타입 설정, 롤 옵션, 인벤토리 추가
    item_data["type"] = "legendary"
    ensure_passive_rolls(item_data)
    apply_roll_bonuses_from_item(item_data)
    show_item_obtained_effect(item_data, item_data.get("x"), item_data.get("y"))
    # skip_append 없음 → 함수 끝에서 자동으로 인벤토리에 추가됨
```

**핵심 규칙:**
1. 첫 획득 시에만 `obtained` 플래그 설정 및 전설 매니저 해금
2. `item_data["type"]`, `ensure_passive_rolls`, `apply_roll_bonuses_from_item`은 **매번 실행**
3. `skip_append = True` **절대 사용 금지** (인벤토리 추가는 함수 끝에서 자동 처리)

## ⚠️ CRITICAL: 퍽/스킬 UI 텍스트 변경 시 필수 체크리스트 (모든 렌더링 경로 확인!)

**pingfighter.py에서 퍽 레벨 표시, 이름, 툴팁 등 UI 텍스트를 변경할 때 반드시 아래 모든 경로를 함께 수정해야 합니다.**
**한 곳만 고치면 다른 화면에서 이전 표시가 그대로 남는 버그가 발생합니다!**

### 퍽 레벨/텍스트가 표시되는 모든 UI 경로 (7곳)

| # | 화면 | 함수/위치 | 설명 |
|---|------|----------|------|
| 1 | **퍽 선택 카드** (인게임) | `show_runtime_skill_choices()` | 스타포인트 획득 시 3장 카드 선택 |
| 2 | **스테이지 클리어 선택** | `show_stage_clear_choices()` | 스테이지 클리어 보상 퍽 선택 |
| 3 | **스테이지 클리어 오버레이** | `draw_stage_choice_overlay()` | 클리어 보상 퍽 카드 렌더링 |
| 4 | **퍽 현황 화면** (전체) | `show_perk_status()` 내 `draw_level_gauge()` | ESC→퍽 현황 메뉴 |
| 5 | **TAB 캐릭터정보 퍽 탭** | `draw_character_info_panel()` 내 퍽 그리드 | TAB 키 정보창 |
| 6 | **퍽 현황 툴팁** | `draw_tooltip()` / `draw_skill_tooltip_mini()` | 퍽 아이콘 호버 시 |
| 7 | **승리 화면 퍽 툴팁** | `show_victory_screen()` 내 `hovered_tooltip` | 승리 후 획득 퍽 목록 |

### 수정 작업 시 반드시 확인할 것

```bash
# 1. 레벨 텍스트 렌더링 위치 전수 검색
grep -n 'Lv\.' pingfighter.py | grep -i 'render\|text\|line'

# 2. 툴팁 이름 조합 위치 검색  
grep -n 'name_line\|tooltip_name\|perk_name.*Lv' pingfighter.py

# 3. character_restriction 분기가 있는지 확인
grep -n 'character_restriction' pingfighter.py | grep -v '#\|print\|CLAUDE'
```

### 왜 이런 문제가 발생하는가?
- **같은 데이터(퍽 정보)를 여러 UI 함수가 독립적으로 렌더링**
- 공용 렌더 함수가 아닌 각 화면별로 `f"Lv.{level}"` 등을 직접 조합
- 한 곳을 수정하면 나머지 6곳에서 이전 표시가 그대로 남음
- `get_acquired_skills()` 등 데이터 전달 함수에서 필요한 필드를 누락하면 분기가 동작하지 않음

### 실수 방지 패턴
```python
# ❌ 잘못된 예 - 한 곳만 수정
# show_runtime_skill_choices()만 고치고 끝냄 → 다른 6곳에서 버그

# ✅ 올바른 예 - grep으로 모든 위치를 찾아서 수정
# 1. grep -n '변경할_텍스트' pingfighter.py 로 전수 검색
# 2. 위 7곳 체크리스트 대조
# 3. 데이터 전달 함수(get_acquired_skills 등)에서 필요한 필드가 포함되는지 확인
```

## Common Issues & Solutions

### Icons Show as Empty Circles
**Cause**: Missing global declaration or ITEM_TYPES assignment
**Solution**: 
1. Declare icon as global variable
2. Use `global` keyword in initialization function
3. Assign to `items.ITEM_TYPES[key]["icon"]`

### ⚠️ CRITICAL: 퍽(Perk) 아이콘이 깨져 보임 (글자 하나만 표시됨)
**Cause**: `draw_skill_icon_mini()` 함수에 해당 퍽의 `elif skill_id == "..."` 분기가 없음
**Why**: 이 함수는 2000줄 이상의 하드코딩된 elif 체인으로 각 퍽별 아이콘을 그림. 새 퍽이 추가되면 자동으로 아이콘이 생성되지 않고, `else` 절로 빠져 스킬 이름의 첫 글자만 표시됨.
**Solution**: 새 퍽 추가 시 반드시 `draw_skill_icon_mini()` 함수 내 `else:` 절 **바로 위에** 해당 퍽의 아이콘 렌더링 코드를 추가해야 함.
**Location**: `pingfighter.py` 내 `draw_skill_icon_mini()` 함수 (약 16320~20640줄 부근)

**⚠️ 모든 종류의 퍽이 해당됨! (일반 퍽 + 스킬 해금 퍽 모두)**
- 일반 퍽: `VIPER_EXCLUSIVE_SKILLS` 딕셔너리에 정의된 퍽 (예: `jetpack_enhance`, `kick_enhance`)
- **스킬 해금 퍽**: `unlock_*` 접두사를 가진 퍽 (예: `unlock_magnum_grip`, `unlock_plasma`, `unlock_recovery_skill`, `unlock_cleanse`, `unlock_ghost_shot`, `unlock_nerve_strike`, `unlock_dive_strike`)
- 스킬 해금 퍽은 별도 딕셔너리에 정의되므로 누락하기 쉬움 → **반드시 확인!**

```python
# 새 퍽 아이콘 추가 위치: else 절 바로 위
elif skill_id == "new_perk_id":         # 일반 퍽
    color = icon_color
    lt = lighter
    dk = darker
    # pygame.draw 로 아이콘 그리기...

elif skill_id == "unlock_new_skill":    # 스킬 해금 퍽 (unlock_ 접두사)
    color = icon_color
    lt = lighter
    dk = darker
    # pygame.draw 로 아이콘 그리기...
    # + 마크 (해금 표시) 추가 권장

else:
    # 기본 fallback (여기로 빠지면 아이콘 깨짐!)
    symbol = skill.get("name", "?")[0] ...
```

### ⚠️ 새 퍽 추가 시 필수 체크리스트
| # | 작업 | 설명 |
|---|------|------|
| 1 | `VIPER_EXCLUSIVE_SKILLS` 딕셔너리 | 퍽 정의 추가 (name, max_level, descriptions, detail, icon_color) |
| 2 | `apply_runtime_skill_effect()` 함수 | 레벨업 처리 코드 추가 |
| 3 | **`draw_skill_icon_mini()` 함수** | **elif 분기 추가 [필수! 없으면 아이콘 깨짐]** |
| 4 | 실제 효과 적용 코드 | 게임 로직에 `runtime_skill_levels.get("perk_id", 0)` 반영 |
| 5 | `global` 선언 | 퍽 관련 전역 변수를 사용하는 모든 함수에 `global` 선언 추가 |

### ⚠️ CRITICAL: 퍽 유형 구분 — 일반 퍽 vs 스킬형 퍽 (5구슬 슬롯)
**퍽에는 두 가지 유형이 있으며, 등록 위치와 방식이 완전히 다릅니다.**

#### 1. 일반 퍽 (패시브 강화) — jetpack_enhance, kick_enhance 등
- 정의: `VIPER_EXCLUSIVE_SKILLS`에만 등록
- HUD: `draw_viper_perk_icons()` (구슬 **옆** 작은 아이콘)
- 해금: `runtime_skill_levels` 레벨업으로만 관리
- 쿨타임: 없음
- 예: 제트팩 강화, 킥 강화

#### 2. 스킬형 퍽 (5구슬 슬롯에 장착) — dark_blade 등
**쿨타임이 있고, 발동 조건이 있는 스킬은 5구슬 슬롯 시스템에 등록해야 합니다!**
- 정의: `VIPER_EXCLUSIVE_SKILLS` + `VIPER_SKILL_ICONS_DATA` **양쪽 모두**
- HUD: `draw_viper_skill_icons()` (5구슬 **슬롯**에 표시)
- 해금: `_viper_skill_unlocked` 딕셔너리 + `equip_viper_skill()` 장착
- 쿨타임: `VIPER_SKILL_ICONS_DATA`의 `cooldown` 필드
- 예: 다크 블레이드, 베놈 엣지, EMP 스트라이크

#### 스킬형 퍽 추가 시 필수 체크리스트 (5구슬 슬롯)
| # | 작업 | 설명 |
|---|------|------|
| 1 | `VIPER_EXCLUSIVE_SKILLS` | 퍽 정의 추가 (선택 풀에 등장시키기 위해) |
| 2 | `VIPER_SKILL_ICONS_DATA` | HUD 아이콘 + 툴팁 + 쿨타임 데이터 등록 |
| 3 | `_viper_skill_unlocked` 딕셔너리 (초기값 + reset 함수) | `"skill_name": False` 추가 |
| 4 | `_viper_skill_cooldowns` 딕셔너리 (초기값 + reset 함수) | `"skill_name": 0` 추가 |
| 5 | `_viper_skill_activation_times` + `_viper_skill_was_active` | 각각 항목 추가 |
| 6 | `apply_runtime_skill_effect()` | `unlock_viper_skill()` + `equip_viper_skill()` 호출 |
| 7 | **`draw_skill_icon_mini()` 함수** | **elif 분기 추가 [필수! 없으면 아이콘 깨짐]** |
| 8 | `global` 선언 | 관련 전역 변수를 사용하는 모든 함수에 `global` 선언 추가 |

### ⚠️ CRITICAL: HUD 5구슬 아이콘 렌더링은 두 함수를 거친다!
**HUD 구슬 아이콘이 비어 보이는 버그의 가장 흔한 원인입니다.**

5구슬 HUD 렌더링 파이프라인:
```
장착 목록 (_viper_equipped_skills)
  → VIPER_SKILL_ICONS_DATA에서 매칭
    → _draw_skill_icon_symbol()로 심볼 렌더링   ← 여기가 두 번째 관문!
      → (폴백) draw_skill_icon_mini()
```

| 함수 | 역할 | 위치 |
|------|------|------|
| `draw_skill_icon_mini()` | 퍽 선택 UI, TAB 정보창 등 범용 아이콘 | `def draw_skill_icon_mini` 검색 |
| `_draw_skill_icon_symbol()` | **HUD 5구슬 전용** 고퀄리티 심볼 | `def _draw_skill_icon_symbol` 검색 |

**draw_skill_icon_mini()에만 분기를 추가하면 HUD 구슬은 여전히 빈 원!**
`_draw_skill_icon_symbol()`에도 elif 분기를 추가하거나, 현재 else 폴백(`draw_skill_icon_mini()` 호출)이 동작하는지 반드시 확인해야 합니다.

현재 `_draw_skill_icon_symbol()`의 else 블록에는 `draw_skill_icon_mini()`로 폴백하는 안전장치가 있습니다.
따라서 `draw_skill_icon_mini()`에 분기만 추가하면 HUD에서도 최소한 아이콘이 표시됩니다.
더 고퀄리티를 원하면 `_draw_skill_icon_symbol()`에도 전용 분기를 추가하면 됩니다.

**툴팁이 안 뜨는 경우 체크포인트:**
- `VIPER_SKILL_ICONS_DATA`에 스킬 데이터가 있는지 (name, korean, cost, description 등)
- `_viper_skill_icon_rects`에 해당 스킬의 rect가 매 프레임 갱신되는지
- `is_viper_skill_unlocked()`가 True를 반환하는지 (hover 판정 시 사용)

```python
# apply_runtime_skill_effect() 내부 - 스킬형 퍽 해금+장착 패턴
if choice_id == "new_skill_perk":
    unlock_viper_skill("new_skill_perk")
    equip_result = equip_viper_skill("new_skill_perk")
    if not equip_result:
        removed = _show_viper_skill_swap_dialog("new_skill_perk")
        swap_viper_skill(removed, "new_skill_perk")
    runtime_skill_levels["new_skill_perk"] = 1
    return True
```

#### 일반 퍽의 HUD 아이콘 표시 (게이지 구슬 옆)
```python
# draw_viper_perk_icons() 내부에 추가 (하드코딩 방식)
_new_perk_lv = get_runtime_skill_level("new_perk_id")
if _new_perk_lv > 0:
    viper_perks.append({
        "name": "new_perk_id",
        "color": (R, G, B),
        "cost": 0,
        "symbol": "XX",
        "always_active": True,
    })
```

### ⚠️ 스킬 해금 퍽(unlock_*) 추가 시 추가 체크리스트
| # | 작업 | 설명 |
|---|------|------|
| 1 | 스킬 해금 퍽 딕셔너리 | `"unlock_[skill_name]"` 키로 퍽 정의 추가 |
| 2 | **`draw_skill_icon_mini()` 함수** | **`elif skill_id == "unlock_[skill_name]":` 분기 추가 [필수!]** |
| 3 | `apply_runtime_skill_effect()` 내 해금 처리 | `smasher_skill_unlocked` 등 해금 플래그 설정 |
| 4 | 런타임 스킬 딕셔너리 매핑 | `"unlock_[skill_name]": "[skill_name]"` 매핑 추가 |

### Korean Text Shows as Boxes
**Cause**: Wrong font or encoding
**Solution**: Use pygame.freetype with NanumSquare fonts and UTF-8 encoding

### File Not Found on Windows
**Cause**: Hardcoded paths or wrong separators
**Solution**: Always use `resource_path()` and `os.path.join()`

### Passive Items Not Saving
**Cause**: Duplicate code in store_passive_item() function
**Solution**: Let the function end handle list addition automatically

### 중복 획득 허용 아이템이 두 번째부터 인벤토리에 안 보임
**Cause**: `PASSIVE_DUPLICATE_ALLOWED`에 포함된 아이템인데 `store_passive_item()`에서 `skip_append = True` 사용
**Solution**:
1. 해당 아이템이 `PASSIVE_DUPLICATE_ALLOWED`에 포함되어 있는지 확인
2. 포함되어 있다면 `else:` 블록에서 `skip_append = True` 제거
3. 첫 획득 시에만 `obtained` 플래그와 효과 활성화, 롤 옵션/인벤토리 추가는 매번 실행되도록 수정

### Active Items in Wrong Slot
**Cause**: Passive items not filtered in store_active_item()
**Solution**: Add passive item names to filter list

## Testing Strategy

### Pre-Release Testing
1. Run `python3 test_icons.py` - verify all icons load
2. Test Korean text rendering
3. Verify all paths use resource_path()
4. Test item effects and interactions
5. Check boss AI behaviors
6. Verify academy skill system

### Platform-Specific Testing
**Windows:**
- Test on Windows 10 and 11
- Check for DLL dependencies
- Verify antivirus compatibility

**macOS:**
- Test on Intel and Apple Silicon
- Check Gatekeeper compatibility
- Verify retina display support

## Current Development Status

### Active Branch: feature/refactor-ui
The project is currently undergoing UI refactoring with extensive changes to:
- UI management systems
- Font configuration
- Item systems
- Academy features
- Rendering optimizations

### Recent Updates (2025-08-31)
- Fixed item icon display bugs
- Resolved cross-platform font path issues
- Enhanced Windows compatibility
- Improved academy skill system integration
- Added trade point system
- **CRITICAL: Fixed legendary item (Ragnarok Hammer) animation system**
  - Field-spawned items now properly initialize animation
  - Item management window animations work correctly
  - Duplicate prevention functioning across all acquisition paths

## Performance Considerations

- Icons are cached on initialization for performance
- Fonts are loaded once and reused
- Use SRCALPHA for transparent surfaces
- Collision detection uses optimized rect-based checks
- Consider modular architecture refactoring for maintainability

### Boss Sprite Runtime Hand-off

For boss sprite work, treat large sprite sheets as source assets, not automatic runtime-ready assets.

- Claude owns prompt quality, sheet layout, naming, output paths, and offline asset preparation.
- Codex owns `pingfighter.py` integration, sprite loader behavior, runtime scaling, caching, lazy-load, and hot-path performance.
- Use the walking sheet as the shared body-scale reference for walk / attack / dash.
- Do not rely on per-sheet trim-and-rescale behavior if it changes apparent body size.
- Effects, trails, flames, and transparent margins may extend outward, but the body itself should keep the same scale.
- Avoid repeated runtime preprocessing when cached frame data or offline preparation can solve the problem.

## ⚠️ CRITICAL: 그래픽/디자인 작업 가이드라인 (Graphics & Effects Performance)

### 현재 렌더링 파이프라인
- **창모드**: `pygame.SCALED` + GPU 텍스처 2배 업스케일 (1488×918 → 2976×1836)
  - CPU 스케일링(`pygame.transform.scale()`) 완전 제거됨
  - GPU가 최종 화면 업스케일링 처리 → 내장 그래픽으로도 충분
- **전체모드**: 여전히 CPU 소프트웨어 스케일링 사용
  - DWM 우회로 충분히 빠름, 필요시 나중에 SCALED 적용 가능

### ✅ 자유롭게 해도 되는 것 (성능 영향 없음)
| 작업 | 이유 |
|------|------|
| 파티클/이펙트 수 늘리기 | gfxdraw 직접 렌더링이라 추가 비용 매우 작음 |
| 색상/알파 다양하게 사용 | gfxdraw는 색상 변경에 추가 비용 없음 |
| 배경 디테일 추가 | 캐싱된 배경 위에 그리는 것이므로 자유로움 |
| 새 이펙트 추가 | gfxdraw 또는 Surface 풀 패턴을 따르면 문제 없음 |
| 스킬 이펙트 고퀄리티 업그레이드 | 병목이 스케일링 파이프라인이었으므로 컨텐츠 퀄리티는 자유 |

### ❌ 여전히 주의해야 할 것 (CPU + pygame이 처리하는 영역)
| 패턴 | 왜 문제? | 해결책 |
|------|----------|--------|
| `pygame.Surface((...), SRCALPHA)` 루프 안에서 생성 | 매 프레임 메모리 할당 → 가장 큰 성능 킬러 | Surface 풀 사용 또는 gfxdraw 직접 렌더링 |
| `pygame.transform.rotate/scale` 매 프레임 호출 | CPU 연산 무거움 | 결과를 캐시하여 재사용 |
| `pygame.draw` 호출 수천 번 | draw 자체는 가벼워도 양이 많으면 느려짐 | 적절한 수로 제한 또는 배치 처리 |
| 전체화면 크기 `Surface.fill()` 남발 | 760×750 × 4바이트 = 2.3MB 매번 클리어 | 필요한 영역만 부분 클리어 |
| 투명 블렌딩(SRCALPHA) 남발 | 알파 블렌딩은 CPU 부담 큼 | 불필요한 투명 Surface 최소화 |

### 이펙트 작업 시 올바른 패턴
```python
# ❌ 잘못된 예 - 매 프레임 Surface 생성 + 회전
def update_particle(self):
    surf = pygame.Surface((20, 20), pygame.SRCALPHA)  # ❌ 매 프레임 새 Surface
    surf = pygame.transform.rotate(surf, self.angle)   # ❌ 매 프레임 회전
    screen.blit(surf, self.pos)

# ✅ 올바른 예 - gfxdraw 직접 렌더링
def update_particle(self):
    pygame.gfxdraw.filled_circle(screen, int(self.x), int(self.y), 
                                  self.radius, self.color)  # ✅ 직접 렌더링

# ✅ 올바른 예 - Surface 풀 + 캐싱된 회전
class ParticlePool:
    def __init__(self):
        self.cached_surfaces = {}  # 각도별 캐시
    
    def get_rotated(self, base_surf, angle):
        key = int(angle) % 360
        if key not in self.cached_surfaces:
            self.cached_surfaces[key] = pygame.transform.rotate(base_surf, key)
        return self.cached_surfaces[key]
```

### 한줄 요약
> **새 이펙트를 만들 때 `pygame.Surface()` 대신 gfxdraw로 직접 그리거나 Surface 풀을 쓰면 퀄리티를 올려도 프레임드랍 없음. 파티클마다 new Surface + transform.rotate만 안 하면 됨.**

## Legendary Item System (전설 아이템)

### Legendary Item Passive Classification (전설 아이템 패시브 분류)
**CRITICAL**: All legendary items MUST be classified as passive items to prevent them from being added to active item slots.

1. **In store_active_item()** - Add all legendary items to passive filter:
   ```python
   # 패시브 아이템들은 엑티브 슬롯에 추가하지 않음
   if item_data["name"] in [..., "ragnarok_hammer", "hermes_shoes", "poseidon_trident"]:
       return
   ```

2. **In store_passive_item()** - Ensure proper handling:
   ```python
   elif item_data["name"] == "poseidon_trident":
       items.poseidon_trident_obtained = True
       item_data["type"] = "legendary"  # Set type for animation
       passive_item_list.append(item_data)  # Add to passive list
       # Activate legendary manager
       legendary_manager = get_legendary_manager()
       if legendary_manager:
           trident = legendary_manager.get_item("poseidon_trident")
           if trident:
               trident.activate()
   ```

### ⚠️ CRITICAL: 전설 아이템 연마 퍽 + 강화 버프 적용 필수
**모든 전설 아이템의 롤 옵션 프로퍼티는 반드시 연마 퍽과 강화 버프를 모두 적용해야 합니다!**

#### 1. 클래스에 enhancement_bonus_pct 속성 추가
```python
class NewLegendaryItem(LegendaryItem):
    def __init__(self):
        super().__init__(...)
        # ... 기타 속성들 ...
        self.enhancement_bonus_pct = 0  # 강화 버프 보너스 (장착 시 동기화) ← 필수!
```

#### 2. 롤 옵션 프로퍼티에서 enhancement_bonus_pct 전달
```python
@property
def some_stat(self) -> float:
    """스탯 설명 (롤 옵션 적용, 연마 스킬 + 강화 보너스 포함)"""
    return get_legendary_roll_value(
        "new_legendary_item",
        "stat_key",
        apply_polish=True,  # 연마 퍽 적용
        enhancement_bonus_pct=self.enhancement_bonus_pct  # 강화 버프 적용 ← 필수!
    )
```

#### 3. sync_equipped_passive_effects()에 동기화 코드 추가
```python
# pingfighter.py - sync_equipped_passive_effects() 내부
# 장착 시 동기화
if legend_name == "new_legendary_item":
    item = next((i for i in equipped_items if i.get("name") == "new_legendary_item"), None)
    if item:
        legendary = legendary_manager.get_item("new_legendary_item")
        if legendary:
            legendary.enhancement_bonus_pct = item.get("enhancement_bonus_pct", 0)

# 장착 해제 시 초기화
elif legend_name == "new_legendary_item":
    legendary = legendary_manager.get_item("new_legendary_item")
    if legendary:
        legendary.enhancement_bonus_pct = 0
```

#### 현재 적용된 전설 아이템 목록
| 아이템 | 롤 옵션 | 연마 퍽 | 강화 버프 |
|--------|---------|---------|-----------|
| 오딘의 눈 | revival_chance | ✅ | ✅ |
| 포세이돈의 삼지창 | wave_power | ✅ | ✅ |
| 헤르메스의 신발 | speed_bonus | ✅ | ✅ |
| 라그나로크 해머 | trigger_chance | ✅ | ✅ |
| 신성 월계수 | leaf_count | ✅ | ✅ |
| 천사의 가호 | buff_level | ✅ | ✅ |
| 초월자의 관 | skill_bonus | ✅ | ✅ |

### Key Implementation Details
Legendary items like Ragnarok Hammer require special handling for animations:

1. **Animation Initialization**: When spawning in field (items.py:spawn_random_item):
   ```python
   # DO NOT call activate_item() - this applies effects immediately
   # Instead, only initialize the instance for animation:
   if selected_item["name"] == "ragnarok_hammer":
       legendary_manager = get_legendary_manager()
       if legendary_manager:
           hammer = legendary_manager.get_item("ragnarok_hammer")
           if not hammer:
               legendary_manager._init_legendary_items()  # Init only, no activation
   ```

2. **Drawing Animated Items** (items.py:draw_items):
   ```python
   if item_name == "ragnarok_hammer":
       legendary_manager = get_legendary_manager()
       if legendary_manager:
           hammer = legendary_manager.get_item("ragnarok_hammer")
           if hammer:
               hammer.update(0.016)  # Update animation (60fps)
               hammer.draw_icon(screen, x, y, size)  # Draw with animation
   ```

3. **Duplicate Prevention**: 
   - Check `ragnarok_hammer_obtained` flag in:
     - items.py:spawn_random_item (field spawning)
     - pingfighter.py:show_item_management_menu (item selection)
     - gacha.py:init_gacha (gacha system)

4. **Type Setting for Animation** (pingfighter.py:store_passive_item):
   ```python
   if item_data["name"] == "ragnarok_hammer":
       item_data["type"] = "legendary"  # CRITICAL for animation in UI
   ```

### Common Issues with Legendary Items
- **Animation not playing**: Check if instance is initialized before drawing
- **Effects applying before pickup**: Don't call activate_item() on spawn
- **Duplicate items appearing**: Ensure global flag is properly set and checked
- **UI not animating**: Set item["type"] = "legendary" when storing
- **Added to active slot by mistake**: Add to passive filter list in store_active_item()
- **Effects not working in game**: Must integrate legendary_manager.update() and effect calls in game loop

### Legendary Item Effect Integration (전설 아이템 효과 통합)
**CRITICAL**: Legendary item effects need to be integrated into the game loop to work properly.

**Note**: As of current implementation, legendary item effects (especially Poseidon's Trident) are NOT fully integrated into the main game loop. The water wave effects and dash wave mechanics require manual integration in pingfighter.py's physics update sections.

**Required Integration Points**:
1. Ball physics update - Apply trajectory influence
2. Dash mechanics - Trigger dash wave on player dash
3. Rendering loop - Draw water wave effects
4. Update loop - Call legendary_manager.update(dt)

### Effect Reset Rules (효과 초기화 규칙)
**IMPORTANT**: Legendary item effects are temporary and must be reset when:

1. **Game Over** - Player loses the game
2. **Return to Main Menu** - Player exits to main menu via ESC
3. **Force Quit** - Game is forcefully terminated

**Reset Implementation**:
```python
# Reset legendary item effects (3 locations in pingfighter.py)
# 1. Game over - around line 20185
# 2. ESC menu return to main - around line 20965  
# 3. Force quit flag - around line 20506

# Example reset code:
if hasattr(legendary_manager, 'reset_all_items'):
    legendary_manager.reset_all_items()  # Deactivate all legendary effects
    
# Also reset obtained flags if items should be re-obtainable:
ragnarok_hammer_obtained = False  # Optional: allow re-obtaining
hermes_shoes_obtained = False     # Optional: allow re-obtaining
```

**Note**: The `obtained` flag can be kept as True if you want to prevent re-obtaining the same legendary item in the same session, or reset to False if items should be obtainable again.

## Git Workflow & Automatic Commits

### ⚠️ CRITICAL: 매 프롬프트 완수 시 자동 커밋 필수!
**IMPORTANT**: 사용자의 프롬프트(요청)를 완수할 때마다 반드시 Git에 커밋한다.

#### 커밋 규칙
1. **매 프롬프트 완수 시** → 즉시 커밋 (예외 없음!)
2. 커밋 메시지는 한글로 작성 가능
3. 커밋 후 자동 push

#### Quick Git Commands
```bash
# Regular commit (for each completed task)
git add -A && git commit -m "[Type]: [작업 내용 설명]" && git push

# Commit Types:
# Feat: 새 기능 추가
# Fix: 버그 수정
# Refactor: 코드 리팩토링
# Docs: 문서 수정
# Style: 코드 스타일 변경
# Debug: 디버그 코드 추가

# Checkmate commit (for important checkpoints)
--checkmate MM.DD-N  # Automatically creates: git commit -m "🏁 Checkmate MM.DD-N: [description]"

# Examples:
--checkmate 09.02-5  # Creates "🏁 Checkmate 09.02-5: 작업 체크포인트"
```

#### When to Commit (언제 커밋하나?)
- **프롬프트 완수 시** (가장 중요!)
- After fixing any bug
- After implementing new feature
- After completing requested changes
- After significant code modifications
- At the end of each work session
- When user uses --checkmate command

### ⚠️ CRITICAL: 안전한 Git 롤백 규칙 (Safe Rollback Rules)
**절대로 `git reset --hard`를 미커밋 상태에서 실행하지 않는다!**

#### 롤백이 필요할 때 반드시 따라야 할 순서:

```bash
# 1단계: 현재 작업 상태 저장 (필수!)
git stash -u -m "롤백 전 백업 $(date +%Y%m%d_%H%M%S)"
# 또는
git add -A && git commit -m "WIP: 롤백 전 임시 저장"

# 2단계: 롤백 실행
git reset --hard [커밋해시]

# 3단계: (필요시) 저장했던 작업 복원
git stash pop
```

#### 안전한 롤백 방법들:

| 상황 | 안전한 명령어 | 설명 |
|------|--------------|------|
| 특정 파일만 되돌리기 | `git checkout [커밋] -- [파일]` | 다른 파일에 영향 없음 |
| 테스트용 롤백 | `git checkout -b test-branch [커밋]` | 새 브랜치에서 안전하게 테스트 |
| 전체 롤백 (안전) | `git stash -u` → `git reset --hard` | 작업 내용 보존 |
| 커밋 취소 (기록 유지) | `git revert [커밋]` | 히스토리 보존하면서 취소 |

#### ❌ 절대 하지 말 것:
```bash
# 미커밋 변경사항이 있는 상태에서 직접 reset --hard 금지!
git reset --hard [커밋]  # ❌ 위험! 작업 손실 가능

# 반드시 먼저 stash 또는 commit 후 실행
git stash -u && git reset --hard [커밋]  # ✅ 안전
```

#### 롤백 후 문제 발생 시 복구 방법:
```bash
# stash로 저장한 경우
git stash list          # 저장된 stash 목록 확인
git stash pop           # 가장 최근 stash 복원

# 커밋으로 저장한 경우
git reflog              # 이전 커밋 히스토리 확인
git checkout [커밋해시] # 원하는 상태로 이동

# 백업 폴더가 있는 경우
# 'd:\백업\0130\main\bosspong' 등에서 파일 복사
```

#### 모듈 버전 불일치 방지:
- `pingfighter.py`와 모듈 파일들(`start_menu.py`, `items.py` 등)은 항상 **함께 커밋**
- 롤백 시 **모든 관련 파일이 같은 버전**인지 확인
- 문제 발생 시 백업 폴더에서 동기화된 버전 복사

### Git Repository Info
- **Remote**: https://github.com/officialsahogany/pingfighter.git
- **Current Branch**: feature/refactor-ui
- **GitHub Token**: Use Classic PAT for authentication

## Notes for Future Development

When modifying this codebase:
1. **ALWAYS** test on both Windows and macOS
2. **NEVER** hardcode paths - use resource_path()
3. **MAINTAIN** backward compatibility with save files
4. **PRESERVE** the monolithic architecture until full modularization
5. **DOCUMENT** any new item effects in detail
6. **TEST** with PyInstaller builds before release
7. **ENSURE** legendary item animations work in all contexts (field, UI, gacha)
8. **COMMIT** changes to Git after each completed task
