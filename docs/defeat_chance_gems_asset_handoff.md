# 패배 화면 자산 핸드오프 (→ Codex)

대상: `docs/defeat_chance_gems_settlement_plan.md` 화면 A(소프트 패배) + HUD 보석
게이지의 **이미지 자산 생성 + 런타임 배선**.

분담(CLAUDE.md §0.1): **미적 방향·프롬프트·팔레트·실루엣·QA 기준 = Claude(이 문서).
실제 생성·알파/누끼·`res://` 로더/캐시/프리웜 배선·인게임 검증 = Codex.** 생성 후
최종 알파/룩 리뷰는 Claude가 한 번 더 본다("does this look right" 패스).

스킬 라우팅: **보석 아이콘 + 포털/프레임/시길 모두 `ui-hud-generation`** (프리미엄
HUD/오버레이 UI 자산). ★item-generation으로 보내지 말 것 — 그 스킬은 "ONLY owns
... items"(SKILL.md:4)이고 모든 아이콘에 `pixel art item icon, 32px/64px, thick
black pixel outline, NO painterly`를 강제(SKILL.md:279)하므로 이번 페인터리 블루
크리스탈과 정반대. (스프라이트 시트 아님 → AutoSprite 의무 비대상, imagegen 가능.)

룩 기준 = 승인된 사용자 목업(LoL/원신 그레이드). 무드는 **다크·블루**(승리 결과창의
시안 팔레트와 구분). 목업 속 생물체(앱솔)는 **무드 레퍼런스일 뿐 — 자산에 재현 금지.**

---

## 0. 배선 현황 — Screen A 프리미엄 / Screen B v1

로직·게이트는 유지한다. Screen A(컨티뉴)는 절차적 placeholder 단계가 끝났고,
현재는 full-screen backdrop, chance-gem PNG, shatter sheet, boss-victory portal
합성을 쓰는 premium 배선이다. Screen B(최종 결산)는 v1 절차식 stat/list 구성을 유지할 수 있다.

| 화면 | 모듈 | 현재 상태 | 남은 우선순위 |
|---|---|---|---|
| A 소프트 패배(컨티뉴) | `godot/scripts/core/defeat_chance_gems_continue_screen.gd` `draw()` | `defeat_continue_backdrop.png`, `chance_gem_full/broken`, `chance_gem_shatter_sheet`, result-prewarmed `boss_victory_sheet` portal 합성 | stage별 live QA, 폰트/텍스트 최종 사인오프 |
| B 찐패배 결산 | `godot/scripts/core/defeat_settlement_screen.gd` `draw()` | 절차식 stat box / 텍스트 섹션 | 낮음 (v1 유지 가능, 일러스트 레이어링은 후속) |

- 둘 다 `extends RefCounted` 즉시-draw 모듈(노드 아님). PNG는 `draw()` 안에서
  `canvas.draw_texture_rect`로 블릿하되, 텍스처 로드/캐시는 모듈 생성·프리웜 시점에 둔다
  (draw에서 lazy 로드 금지 — Hot-Path Lazy 트랩).
- 2026-06-22 Codex 배선: `stage4_ponk_boss_victory.png`,
  `stage5_hongryun_boss_victory.png`, `stage6_tetriser_boss_victory_4x2.png`를
  result-prewarm `boss_victory_sheet`로 연결했다. 세 자산은 1536x768 4x2라서
  `defeat_chance_gems_continue_screen.gd`의 non-square 4x2 source-rect 분기를 그대로 탄다.
- 보석 PNG는 Screen A와 전투 HUD 공유 자산이다. 결산(B)은 보석만 PNG로 받고 나머지는
  절차식을 유지해도 v1 OK.

### 0.1 보석 게이지 소진 방향 정렬 (런타임, Codex)
`defeat_chance_gems_continue_screen.gd` `draw()`의 `for i in range(max_gems)`는 현재
`broken = i >= remaining_gems`라 **오른쪽 칸부터** 깨진다(우→좌). 목업은 **왼쪽부터** 깨짐.
PNG 교체 시 목업에 맞춰 좌→우로 정렬: `var consumed := max_gems - remaining_gems` →
`broken = i < consumed`, `breaking = i == consumed - 1`. (순수 레이아웃 변경, 아트와
독립이나 같은 작업에서 함께. match_flow_driver 회귀 스모크와 무관 — 화면 내부 draw라
별도 시각 QA로만 확인.)

---

## 자산 1 — 기회의 보석 아이콘 (온전/깨짐 2상태, 매칭 페어)

용도: HUD 게이지 + 패배 오버레이 게이지 **공유**. 작게(HUD)도 크게(오버레이)도 또렷해야 함.
- 포맷: 투명 PNG, 정사각 캔버스, **사방 넉넉한 투명 여백**(글로우가 캔버스 가장자리에
  닿지 않게). 고해상(예: 512px+)으로 생성 후 다운스케일.
- 팔레트: 심청~시안 결정(코어 발광 ~#2A6CFF, 림 하이라이트 ~#7FD0FF). 목업의 밝은
  블루 다이아 + 어두운 깨진 보석과 일치.
- 실루엣: 끝으로 선 패싯 마름모/다이아 결정. **온전/깨짐 두 장은 동일 실루엣·동일 스케일**
  (게이지에서 나란히 놓이는 페어).

프롬프트 — 온전(`chance_gem_full`):
> A single magical "chance gem" icon for a premium dark-fantasy game UI. A faceted
> crystalline rhombus/diamond gem standing on its point, deep sapphire-to-cyan blue,
> bright glowing inner core, crisp cool rim light, subtle internal facets catching
> light, faint magical energy. Centered on a fully transparent background, generous
> empty margin on every side, no background, no frame, no text. Clean readable
> silhouette, high detail, game icon art, soft outer glow that does NOT touch the
> canvas edges.

프롬프트 — 깨짐(`chance_gem_broken`):
> The SAME faceted rhombus/diamond gem but BROKEN and depleted: cracked across the
> surface with fracture lines, a chipped corner, inner glow extinguished to a cold
> dark grey-blue, desaturated and lifeless, a couple of small detached shards beside
> it. Identical silhouette and scale to the intact gem (matched pair). Fully
> transparent background, generous margin, no frame, no text. Premium dark-fantasy
> game UI icon.

QA 게이트(Claude 리뷰): 코너 완전 투명 / 알파 bbox 가장자리 비접촉 / 프린지 없음 /
**페어 실루엣·스케일 일치** / HUD 다운스케일 또렷 / 깨짐본이 "꺼진 보석"으로 즉시 읽힘.

---

## 자산 2 — 원형 포털 백드롭 (보스 합성용, 안은 비움)

용도: 패배 오버레이 중앙의 원형 포털. **보스는 런타임에 중앙 합성**(기존 스테이지 보스
시트) → 포털 자산은 "안이 빈 링/백드롭"만.
- 포맷: 투명 PNG(링/프레임 레이어) + 어두운 내부 헤이즈. 정면(front-on), 중앙 정렬.
- 내부는 **어둡고 비어 있음**(생물·인물 금지). 림에 쿨 블루 글로우.

프롬프트(`defeat_portal_ring`):
> A circular ancient stone portal ring frame for a dark-fantasy game "defeat" screen.
> A carved ring of dark stone and weathered metal, cool blue rim light glowing along
> the inner edge, scattered rubble and rock shards around it, faint volumetric haze
> inside the opening. The interior is DARK and EMPTY — do NOT draw any creature,
> character, or figure (a sprite is composited into the center at runtime). Front-on
> view, centered, transparent background outside the ring. Moody, cinematic, premium
> MOBA-grade UI art, deep blue palette.

런타임(Codex): 포털 PNG를 그린 뒤 그 중앙 영역에 **현재 `current_stage`→보스 시트**를
어둡게(디머/실루엣 톤) 합성. 보스 시트는 기존 `godot/assets/sprites/bosses/...` 또는
스테이지 오너 폴더 재사용. 보스 베이크 금지(동적이어야 함).
보스 로스터(Godot 매핑, `defeat_settlement_screen.STAGE_BOSS_NAMES`와 동일):
1=달지 / 2=악어장군 / 3=멘헤라걸 / 4=폰크 / 5=홍련 / 6=테트리서. Python 번호 베끼기
금지(Nemesis 없음). `current_stage`로 인덱싱. (v1은 포털만 PNG로 받고 보스 합성은
후속으로 미뤄도 됨 — 보석 게이지 다음 우선순위.)

QA: 내부가 정말 비어 있고 림 글로우가 읽히는가 / 보스 합성 시 가독성(어둡되 형태 보임).

### 2.1 통합 방향 (Claude — 생성 전 확정)
- **레이아웃 정합 (중요)**: 현 화면 A 패널은 컴팩트(`PANEL_SIZE = 520×410`: 제목/부제/
  게이지/안내/버튼, 포털 자리 없음). 목업처럼 포털을 **부제와 보석 게이지 사이 상단 밴드**에
  prominent하게 넣으려면 **패널 세로를 키우고 포털 밴드를 게이지 위에 삽입**해야 함.
  → 자산 종횡비 + 런타임 패널 높이/요소 y좌표를 함께 결정. **권장: 패널 키워 목업 충실**
  (작은 메달리언으로 갈지 먼저 택1; 작게 가면 포털 종횡비도 그에 맞춰 생성).
- **인터리어 = 투명 홀**: 링/프레임은 불투명 PNG + 림 글로우, **개구부는 투명 알파**
  (헤이즈는 아주 옅게만, 또는 별 레이어). 보스는 런타임에 그 투명 홀 **안/뒤**에 합성.
  개구부 종횡비는 보스 시트(대체로 가로~정사각)를 프레이밍할 수 있게.
- **팔레트 에코**: 포털 림 글로우 = 보석 시안(코어 `#2A6CFF` / 림 `#7FD0FF`)과 동일 톤 →
  포털·보석·패널이 한 세트로 읽히게. 다크블루 무드 유지(승리 시안과 구분).
- **크로마키**: 녹색 `#00ff00`(다크스톤+블루글로우라 안전), `chroma_key.py` green 경로.
- **v1 분리 OK**: 포털 링만 먼저 PNG로 받고 보스 합성은 후속으로 미뤄도 됨(개구부 투명이면
  빈 포털도 자연스러움). 보스 합성 시 어둡게/실루엣 톤 + 개구부 클립.

### 2.2 shipped v1 (2026-06-19) — 접근 변경 기록
실제 구현은 투명-링이 아니라 **풀스크린 불투명 백드롭**으로 감:
`godot/assets/sprites/hud/defeat_continue_backdrop.png`(16:9, 동굴+포털+반사바닥 통째),
`defeat_chance_gems_continue_screen.gd`가 작은 카드 모달 → **전체 화면 패배 씬**으로 전환
(`_draw_scene_backdrop` `_cover_texture_rect` cover-fit + 상/하/측 가독성 스크림, `_scaled_y/_font`
뷰높이 스케일). 레이아웃: 상단 시길(절차적)+타이틀, 중앙 밝은 포털 코어 **비움**(보스 자리),
하단 보석 게이지+문구+확인. **포털 내부=밝은 미스트**(브리프 "dark interior" 대체) → 보스
합성 시 어두운 실루엣이 밝은 안개 위에 강하게 read. 다음 자연 후속 = `current_stage` 보스
시트를 포털 코어에 어둡게 합성(개구부 클립). Claude 룩/통합 리뷰 APPROVE(아트+cover/scrim/
center-reserve), full-res 인게임 캡처로 텍스트 가독성·보석 크기 최종 사인오프 잔여.

---

## 자산 3 — 나침반-별 시길 (상단 장식)

- **기존 로고/인트로 시길 자산이 있으면 재사용**(로고 인트로 모티프와 일관). Codex가
  먼저 리포에서 기존 시길/로고 자산을 grep으로 확인.
- 없을 때만 생성(`defeat_sigil`): 4각 별 + 가는 방사선, 페일 실버-블루, 다크판타지
  필리그리, 투명 배경, 텍스트 없음.

## 자산 4 — 디바이더 + 확인 버튼 (대부분 기존 재사용/절차적)

- 보석 게이지 양옆 마름모 디바이더(◇──◈──◇): 단순 도형이므로 **절차적 draw 권장**
  (PNG 불필요). HUD 컨벤션.
- `확인` 버튼: **기존 메뉴 버튼 스타일 재사용**(main_menu/일관 버튼 프레임). 신규 생성
  말 것. 라벨만 `확인`.

---

## 출력 경로 / 배선 기대치 (Codex 소유)

- 경로: `stage_clear_result` 자산과 같은 컨벤션 폴더에(예: `godot/assets/ui/...` 또는
  HUD 자산 폴더). 논리 이름: `chance_gem_full.png`, `chance_gem_broken.png`,
  `defeat_portal_ring.png`, (`defeat_sigil.png` 필요 시).
- **PNG-first 로더 + 캐시.** 절차적 폴백이 신규 PNG를 우회하지 않게 검증
  (CLAUDE.md icon precedence).
- **프리웜(이산)**: 패배 확정 시점 / 스코어 result-texture 프리웜 큐에 보석·포털·시길
  텍스처를 올림. **draw에서 lazy 로드 금지**(Hot-Path Lazy Init 트랩).
- 보석 텍스처는 HUD 게이지(`chance_gems_count` 읽기)와 오버레이가 **같은 캐시** 공유.
- 음수 z 백드롭으로 깔면 조상 불투명 풀필 트랩 → 윈도우드 픽셀 검증
  (CLAUDE.md Negative-Z / load_texture raw bypass).

## 최종 사인오프

1. Codex: 생성 → 알파/누끼 → 경로 커밋 → 로더/캐시/프리웜 배선 → 인게임 픽셀 QA.
2. Claude: 알파-코너/bbox/프린지, 페어 일치, 다크-블루 무드 일관, 다운스케일 가독성
   최종 리뷰.
3. 코드 배선(보석 상태/리졸버/오버레이 로직)은 본 핸드오프 범위 밖 — 플랜 문서 S1~S5.
