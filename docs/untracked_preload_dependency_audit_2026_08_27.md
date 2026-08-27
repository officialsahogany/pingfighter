# 미추적 preload 의존 감사 — 2026-08-27

**정본.** 이 파일을 갱신하며 진행한다. 관제탑 직접 실측.

기준 HEAD `8204cdc56` · 미푸시 **1,076** · CI/pre-push **251/251**

---

## 결론 — 지금 푸시하면 원격이 깨진다

로컬은 전부 GREEN 이다. **파일이 로컬에만 있기 때문이다.**
추적 코드만 원격으로 넘어가고 `preload` 대상은 넘어가지 않는다.

| 지표 | 값 |
|---|---|
| 미추적 생산 파일(`scripts`+`shaders`) | **71** |
| 그중 추적 파일이 참조 | **59** |
| 참조 방식 **HARD** (`preload`) | **59** |
| 참조 방식 SOFT (`load`) | **0** |
| 미추적 씰(`tests/*.gd`) | **305** |
| CI/pre-push 등재 씰 중 미추적·부재 | **0** |
| ★**CI 등재 씰이 미추적 생산 파일 참조** | **2** |

★`preload` 는 컴파일 시점 의존이다. 대상이 없으면 **참조하는 추적 파일 자체가
파싱에 실패**한다. `load` 처럼 조용히 null 이 되는 것이 아니라 연쇄로 무너진다.

### 왜 지금까지 안 터졌나

원격이 **1,076 커밋 뒤**에 있다. 문제의 `preload` 를 넣은 커밋들이 아직 원격에
없다. 푸시하는 순간 드러난다.

### 미추적 씰 305건은 원격을 깨지 않는다

CI 가 명시 목록으로 돌기 때문이다. 다만 **305개 씰이 CI 에서 영영 돌지 않는**
커버리지 공백이다. 별건으로 다룬다.

---

## 최우선 — CI 등재 씰이 참조하는 2건

푸시 즉시 원격 CI 가 실패하는 유일한 자리다.

| CI 씰 (추적) | 참조하는 미추적 생산 파일 |
|---|---|
| `smasher_plasma_fx_host_smoke.gd` | `scripts/effects/screen_clip_canvas_material.gd` |
| `smasher_plasma_visual_render_smoke.gd` | `scripts/characters/smasher_plasma_renderer.gd` |

두 파일 모두 **미추적 의존이 없어 자립**한다(관제탑 확인).

---

## 기능 묶음 (59건)

무작위가 아니라 **기능 단위 절반 착지**다. 호출부는 커밋됐고 피호출 파일이
빠졌다. GRT-031 의 기능 규모 변종.

| 묶음 | 미추적 생산 | 관련 미추적 씰 |
|---|---|---|
| 배틀 코디네이터 분해 (`battle_*`) | 15 | 35 |
| 코만도 물자투하 (`commando_supply_drop_*`) | 13 | 13 |
| 액티브 아이템 렌더러 (`active_item_*`) | 7 | 26 |
| 패배 이어하기 (`defeat_continue_*`) | 6 | 7 |
| 전광판 (`scoreboard_*`) | 3 | 5 |
| 스테이지1 풍선 (`stage1_balloon_*`) | 3 | 2 |
| 기타 단독 | 12 | — |

⚠**참조 3건**: `scoreboard_top_mini_digit_atlas_renderer.gd`
⚠**참조 2건**: `player_rain_wetness_fx_host.gd` · `loading_ink_haze_host.gd` ·
`player_sprite_wall_slide.gd`

---

## 진행 원칙

1. **묶음 단위로 한 커밋.** 생산 파일 + 짝 씰 + CI 등재를 함께 넣는다.
   쪼개면 또 절반 착지가 된다.
2. **착지 전 자립 확인.** 그 파일이 preload 하는 것 중 미추적이 없어야 한다.
   있으면 그것부터 올린다(의존 순서).
3. **짝 씰이 통과해야 한다.** 씰이 없거나 RED 면 그 묶음은 보류하고 보고한다.
4. **미완성 WIP 를 억지로 올리지 마라.** 미추적인 데는 이유가 있을 수 있다.
   판단이 서지 않으면 관제탑에 보고한다.

## 재현 명령

```bash
# 미추적 생산 파일
git ls-files --others --exclude-standard -- godot/scripts godot/shaders \
  | grep -E '\.(gd|gdshader)$'

# 추적 파일이 preload 하는 미추적 자원 (HARD)
#   res:// 경로로 변환 후 git grep -F (인덱스만 보므로 추적 파일에서만 찾는다)

# CI 씰이 미추적 자원을 참조하는가
grep -F -f <미추적 res 목록> -l <CI 씰 파일 목록>
```

## 진행 기록

- 2026-08-27 감사 실시. 위 수치 확정.
- (이후 묶음 착지마다 여기에 추가한다)
