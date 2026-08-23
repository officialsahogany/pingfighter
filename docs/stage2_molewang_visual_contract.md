# Stage 2 지굴왕 비주얼 계약

> ## ⚠️ 이 보스는 평소 땅속에 있다. 전신 입상으로 그리지 마라
>
> 원본은 `entities/molewang_boss_sprite.py` 이고 Godot 런타임은 **emerge 값으로
> 가시성을 가른다.** 평소에는 흙 융기만 보이고, 공 타격 시에만 솟아올라
> 발톱으로 후려치고 다시 들어간다.
>
> **다리도 발도 의상도 없다.** 하반신은 항상 땅속이다. 두루마기·부츠·어깨갑주를
> 입힌 서 있는 인간형으로 그리면 존재하지 않는 캐릭터를 만들어내는 것이다.
> (2026-08-22 실제 발생. 계열 게이트를 전부 통과한 전신 입상을 만들었고,
> 사용자가 원본을 지적해서야 발견했다.)

## 원본 계약 — `entities/molewang_boss_sprite.py`

docstring 원문:

> 디그다 스타일 — 평소에는 땅속에 숨어서 땅 울렁거림만 보이고,
> 공 타격 시에만 바닥에서 솟아올라 발톱으로 후려치고 다시 들어감.

| 요소 | 원본 |
|---|---|
| 몸 | 돔형 기둥. `full_body_h = 4.5b`, `body_w = 2.6b` |
| 가시성 | `emerge_amount` 0.0 = 땅속 · 1.0 = 완전 출현 |
| 얼굴 | `emerge > 0.4` 에서만 그려짐 |
| 눈 | **크고 동그란 검은 눈** `(20,15,10)` + 흰 반짝임 |
| 코 | 분홍 타원 `(225,150,145)` |
| 입 | `(100,65,40)` + **큰 흰 이빨** `(250,245,235)` |
| 팔 | `_draw_arms_from_ground` — 땅에서 **따로** 솟는다. 몸에 안 붙어 있다 |
| 평상시 | `_draw_underground_ripple` — 흙 융기 + 균열선. `breath = sin(t*2.0)*2.0` |

## 런타임 가시성 게이트

`godot/scripts/stages/stage2/stage2_variant_boss_renderer.gd`

- `_draw_ground_mound()` 는 **항상** 그린다.
- 이어서 `if emerge <= 0.04: return` — 몸은 그리지 않고 조기 반환한다.
- `emerge` 를 올리는 것은 셋뿐이다. `hit_emerge_timer`(타격 시 0.65초),
  `spinning_claw_active`(emerge=1.0), `tunnel_active`.

`godot/scripts/stages/stage2/stage2_actor_renderer.gd`

- `variant in ["molewang","arachne"]` 이면 **변종 렌더러만** 호출된다.
- 승패 경로를 가진 청린귀 액터 렌더러(`stage2_boss_actor_renderer.gd`)는
  지굴왕에 대해 **호출되지 않는다.** 따라서 지굴왕에는 victory/defeat 렌더링이
  존재하지 않는다. 승패 시트를 배선하려면 경로를 새로 만들어야 한다.

## 팔레트 — 원본이 정본이다

브리프에 실측으로 주어진 색이 곧 원본 팔레트다. 색은 맞고 형태만 틀렸던
사고였으므로 색을 의심하지 마라.

| 용도 | 원본 RGB | hex |
|---|---|---|
| body | (175,135,95) | `#af875f` |
| body_light | (200,165,120) | `#c8a578` |
| body_dark | (140,105,70) | `#8c6946` |
| nose | (225,150,145) | `#e19691` |
| eye_black | (20,15,10) | `#140f0a` |
| tooth | (250,245,235) | `#faf5eb` |
| claw | (240,235,225) | `#f0ebe1` |
| crown_gold | (215,180,55) | `#d7b437` |
| gem_red / green / blue | (205,50,45) / (50,185,70) / (60,95,205) | `#cd322d` / `#32b946` / `#3c5fcd` |
| ground | (110,80,48) | `#6e5030` |

★ 원본 팔레트를 **그대로** 쓰면 청린귀 v10 계열에서 이탈한다. 실측 ΔL\* 19.3
(원본 L\* 42.6 vs 청린귀 23.3). 색상(hue)은 유지하고 **명도만 재구성**하라.
승인된 앵커는 ΔL\* 0.3 / Δ채도 0.6 / ΔP90 6.3 / 암부차 0.7pp 로 통과했다.

## 모션 매핑

| 모션 | 내용 |
|---|---|
| idle | 흙무덤 + 호흡 융기 + 균열선. **몸 없음** |
| attack | 솟아오름 → 발톱 후려치기 → 하강. 몸이 보이는 유일한 상시 모션 |
| walk (굴진) | 흙 융기 이동 + 뒤쪽 흙 자국 (원본 `speed_factor` 트레일) |
| victory / defeat | 원본에 상태 없음. 런타임 경로도 없음 — 신설 대상 |

## ★다른 보스도 원본 소스를 먼저 읽어라

같은 사고를 막기 위해 Stage 2/3 변종 보스의 원본 파일을 미리 적어 둔다.
플레이어 노출명만 보고 생김새를 추정하지 마라.

| 노출명 | variant id | 원본 소스 | 원본 정체 |
|---|---|---|---|
| 지굴왕 | `molewang` | `entities/molewang_boss_sprite.py` | 디그다형 땅속 두더지 |
| 거미각시 | `arachne` | `entities/spider_boss_sprite.py` | 아라크네. 리얼리스틱 절지동물, 4마디 다리, gait cycle |
| 포웅귀 | `teddy_bear` | `entities/teddy_bear_boss_sprite.py` | 다크 리얼리스틱 봉제 곰인형. 구면 음영 + 퍼 질감 |
| 옥토선자 | `alice` | `entities/alice_boss_sprite.py` | **거울 나라의 앨리스.** 파란 드레스 + 흰 에이프런 + 금발 |

★★`옥토선자`(玉兔仙子, Jade Rabbit Sage)의 원본이 **앨리스**라는 점이 특히
위험하다. 이름만 보고 토끼 선인을 그리면 원본과 완전히 다른 결과가 나온다.
리브랜드 의도가 "앨리스 형태 유지 + 명칭만 교체"인지 "토끼로 재설계"인지
**작업 전에 확인**하라. 지굴왕 사고와 정확히 같은 구조의 함정이다.

관련: `docs/stage2_cheongringwi_visual_design.md`(폐기 세대 경고 참조),
`.claude/skills/sprite-generation/SKILL.md`
