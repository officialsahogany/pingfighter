# Lingpet 밀쿠 2번째 액티브 "우유발사(milk_shot)" 슬라이스 설계서

Status: DESIGN LOCKED (2026-06-20). 단일 소스 = 배선/리뷰 체크리스트.
선례: lumion solar_bolt(2번째 액티브, docs/lingpet_lumion_solar_bolt_slice_plan.md),
gatling_burst(보스 CC 투사체), thunder_orb(레벨 스턴), milk_production(쿨다운 권위화, 막 출시).
관련 메모리: [[project_lingpet_milk_production_levelup]], boss_knockback_port_parity,
Per-Frame Probability Roll Trap, Radial CC Hit Geometry, letterbox cull(CLAUDE.md).

## 0. 확정 설계 (재론 금지)
- 밀쿠가 보스에게 우유 투사체 발사. **한 볼리 = 좌/우 2발(쌍) 동시**, 순차 반복 → 총 N발(N/2 볼리). 보스 향해 일직선 매우 빠름.
- 보스 명중 시 **스턴 + 넉백(권총 기준)**.
- Lv.3+ 30% **메가우유발사 "대신"**(30% 메가/70% 일반, 발동당 1회 롤). 메가=보스 방향 부채꼴 스프레이.
- 밀쿠 획득 = **우유생산 OR 우유발사 택1**(lumion 천둥뇌구↔낙뢰 선례, active_skill_pool 2-candidate unlock).
- 단위 1:1, 권총 넉백 베이스라인 PISTOL_BOSS_KNOCKBACK_POWER=8.0(다이너마이트 104 차용 금지).

## 1. 레벨 표 (Lv1·Lv5 사용자 지정, Lv2~4 선형 보간 확정)

| Lv | 스턴(초) | 넉백(권총배수→power) | 투사체 | 지속(초) | 쿨타임(초) | 메가(30%) |
|----|---------|---------------------|--------|---------|-----------|-----------|
| 1  | 0.5  | ×1.00 → 8.0  | 4 | 0.8  | 30   | — |
| 2  | 0.65 | ×1.25 → 10.0 | 4 | 0.92 | 27.5 | — |
| 3  | 0.75 | ×1.50 → 12.0 | 5 | 1.05 | 25   | 30%·30발·1.0s |
| 4  | 0.85 | ×1.75 → 14.0 | 5 | 1.18 | 22.5 | 30%·40발·1.25s |
| 5  | 1.0  | ×2.00 → 16.0 | 6 | 1.3  | 20   | 30%·50발·1.5s |

catalog `*_by_level`(authoritative cooldown):
```
"stun_duration_seconds_by_level": [0.5, 0.65, 0.75, 0.85, 1.0],
"knockback_power_by_level": [8.0, 10.0, 12.0, 14.0, 16.0],
"projectile_count_by_level": [4, 4, 5, 5, 6],
"fire_duration_seconds_by_level": [0.8, 0.92, 1.05, 1.18, 1.3],
"cooldown_by_level": [30.0, 27.5, 25.0, 22.5, 20.0],
"mega_chance_by_level": [0.0, 0.0, 0.30, 0.30, 0.30],
"mega_shot_count_by_level": [0, 0, 30, 40, 50],
"mega_duration_seconds_by_level": [0.0, 0.0, 1.0, 1.25, 1.5],
```
넉백 frames/decay는 권총값 고정(FRAMES=18, DECAY=0.85), power만 레벨 스케일. 메가 per-hit CC=해당 레벨 일반과 동일.

## 2. 카탈로그 (lingpet_catalog.gd) — milkring 2번째 액티브
- milkring `active_skill_pool`에 milk_shot을 **[1]** 추가(milk_production [0] 유지). maribo/volty/lumion 2-entry 포맷.
  `id:"milkring_milk_shot"`, `runtime_kind:"milk_shot"`, name "우유발사", description(레벨 거동), windup_seconds, 위 `*_by_level`, card/icon path.
- `effect_text` 재작성: "...우유생산 또는 우유발사 중 획득 시 선택된 액티브를 자동 사용합니다. 패시브 효과는 획득 시 공용 풀에서 결정됩니다." (lumion/maribo 패턴)
- 쿨다운 권위화 규칙은 milk_production에서 이미 구현됨(`_apply_active_skill_level` cooldown_by_level skip). milk_shot도 cooldown_by_level 있으니 자동 적용.

## 3. 디스패처 (lingpet_skill_dispatcher.gd)
- `const SKILL_KIND_MILK_SHOT := "milk_shot"`, `const MILK_SHOT_SKILL_ID := "milkring_milk_shot"`
- SUPPORTED_SKILL_KINDS에 추가, get_skill_kind match 케이스, `is_milk_shot()`, get_exclusive_resource_classes(투사체만 쏘고 ball/pos 미점유 → 빈 케이스).

## 4. 런타임 호스트 (lingpet_skill_runtime_host.gd) — ~14 스위치
const MILK_SHOT_SKILL_PATH + var _milk_shot_skill + `_get_milk_shot_skill()` lazy loader(=_get_wild_roar_skill 패턴).
다음 디스패치 모두에 SKILL_KIND_MILK_SHOT 케이스: reset / update(launch_context 전달) / draw / has_visible_effects(+_for_skill) / is_launch_blocked(active 시 true=bomb_surprise식) / can_arm / launch / get_launch_origin(companion_pos 기준 상향) / trigger_launch_feedback(오디오) / get_snapshot 머지 / _get_skill_for_kind. cast 윈드업 있으면 get_companion_cast_pose_progress.

## 5. 런타임 스킬 (NEW lingpet_milk_shot_skill.gd)
extends RefCounted. 필수: reset/cancel/prewarm/launch(origin,owner,launch_context)->bool/update(delta,owner,registry,launch_context)/draw(canvas,shake)/has_visible_effects/is_active/get_snapshot(`milk_shot_*` 키).
- launch: `active_skill_level`, 레벨값(투사체수·지속·스턴·넉백power·메가확률/수/지속) 추출. **메가 롤 1회**(Lv3+ randf()<mega_chance → 메가, 아니면 일반). per-frame 금지(launch one-shot). test hook `milk_shot_mega_roll`.
- 일반: N/2 볼리, 볼리마다 좌/우 firing point에서 1발씩(vel=(0,-SPEED), 매우 빠름), 볼리 간 delay = fire_duration/(N/2). gatling bullet 구조 재사용.
- 메가: 부채꼴 — 보스 방향 중심 ±half_angle(예 ±40°)로 shot_count발을 duration 동안 분산 발사(JET_SPREAD 패턴, afterglow_leak 참조).
- 투사체 update: `vel*(delta*60)`, 반경 보스히트(boss-center distance, NOT rect), age/letterbox cull(game_offset/render_scale 밴드 포함).
- 보스 히트 시 §7 CC 적용. is_launch_blocked: 발사/메가 진행 중 true.

## 6. 페이로드 팩토리 (NEW lingpet_milk_shot_payload_factory.gd)
`build_projectile(pos, vel, angle)` → {pos,vel,age,angle,...}. `build_mega_fan_angles(base_angle, half_angle, count)` → 각도 배열. `build_boss_stun_status_data(stun_frames, knockback_vel, kb_frames, kb_decay)` → apply_status data dict(gatling build_ak47_stun_status_data 패턴).

## 7. 보스 CC (스턴 + 넉백)
- **스턴**: `status_effect_state.apply_status("boss","stun", stun_seconds*60.0, data, "milkring_milk_shot")`. 반경 히트(boss-center distance ≤ hit_radius, gatling 351-356 패턴). source 유니크.
- **넉백**: 직격이라 paddle-bounce suppress 플래그 **불필요**. 넉백을 **status data에 동봉**(knockback_vel/knockback_frames/knockback_decay_per_frame) = gatling 방식(status_effect_state가 _update_entry_knockback로 boss 적용). OR boss_ai_state.start_paddle_hit_knockback(vel, FRAMES, DECAY, replace_current=true) 직접.
  - knockback_vel = 방향(히트X offset 부호) × power(레벨 [8..16]). frames=18, decay=0.85(권총 고정).
  - 단위 1:1(px/frame), CommandoFirearm 상수 기준, 다이너마이트 차용 금지.

## 8. 자산 (imagegen) — Claude
- 카드 `milkring_milk_shot_skillcard_imagegen_v1.png` 1720×541, 아이콘 `milkring_milk_shot_skill_icon_imagegen_v1.png` 1254×1254. **둘 다 불투명 검정 배경**(링펫 스킬 카드/아이콘 컨벤션 — 치즈/아이템 아이콘의 투명과 다름). 밀쿠 + 우유 발사/대포 모티프.
- 투사체/메가 VFX: 절차적(draw_circle/line, 흰 우유 방울/줄기) — 시트 불필요.

## 9. HUD / 툴팁
catalog 등록만으로 rail_card/character_info 자동 배선(card/icon path + companion_skill_description/cooldown). 별도 작업 없음(확인만). 쿨다운은 권위화로 [30..20] 자동 표시.

## 10. 스모크 의무 (OUTCOME 중심)
- dispatcher/catalog/asset: is_milk_shot, get_skill_kind, 카드/아이콘 로드.
- 레벨 정확값: get_active_skill(milkring, "milkring_milk_shot", lvl) → cooldown [30,27.5,25,22.5,20] + no-double-tax(reduction_pct==0) + stun/knockback_power/count/duration by_level.
- 보스 히트 OUTCOME: 일반 발사가 보스 명중 시 apply_status("boss","stun",frames) 호출 + 스턴 frames=레벨 정확 + knockback_vel>0 & power=레벨값. 반경 밖이면 미발동(엣지 반증).
- 메가 per-opportunity: Lv3 force_roll 성공→메가(shot_count=30), 실패→일반. 런치당 1회(같은 발사 내 재트리거 안 됨).
- 투사체 쌍: 한 볼리=2발(좌/우), 총 N발.
- 획득 unlock: milkring Lv.1 = milk_production OR milk_shot 2-candidate(lumion 패턴), invalidate cache.
- warning_scan + headless.

## 11. 트랩
- 반경 CC(boss-center distance, NOT rect). 시각 원이 보스 rect에 닿아도 center 밖이면 스턴 금지.
- 스턴 초→frames(×60). gatling=raw frames, thunder=timer; 우리는 apply_status에 full frames.
- 직격 넉백은 suppress 플래그 무관(그건 paddle-bounce 전용). status data 동봉 or start_paddle_hit_knockback 직접.
- 단위 1:1, 권총 8.0 기준, 다이너마이트 104 금지. replace_current=true(약→강 교체).
- 메가 롤 launch() 1회만(update per-frame 금지=컴파운딩).
- letterbox cull: 투사체 draw cull에 레터박스 밴드(game_offset.x/render_scale ±) 포함, 0..WIDTH만 하면 필드 가장자리서 팝.
- 쿨다운 2중감소: cooldown_by_level 있으면 전역세금 skip(이미 구현). milk_shot도 동일.
- 1-entry→2-entry 전환: milkring이 1펫 pool에서 2-candidate로 바뀜. resolve_single_unlock(size1) → set_unlock_choice_candidates+choose(size2) 경로. reconcile 후 _invalidate_current_loadout_cache 필수.
- 아이콘 **불투명 검정 bg**(투명 아님). 카드도 검정 bg.
- pool[0] 폴백: get_active_skill(milkring,"")=pool[0]=milk_production. milk_shot 렌더는 명시 id/snapshot.companion_skill_id로.
- prewarm: 투사체 텍스처 없으면 절차적이라 무관, 있으면 prewarm.
- 호스트 ~14 스위치 누락 시 조용한 미동작 — 전 디스패치 케이스 추가 확인.

## 12. 슬라이스 분할
- S1 디스패처 등록 + 카탈로그 milk_shot 엔트리(레벨배열) + effect_text + 스모크(dispatcher/catalog/레벨값).
- S2 런타임 skill + payload factory(일반 쌍 발사 + 투사체 motion/cull) + 호스트 배선 + 스모크(발사/카운트).
- S3 보스 CC(스턴+넉백 apply_status, 반경히트, 권총 power 레벨) + 스모크(보스 히트 OUTCOME).
- S4 메가우유발사(부채꼴, 30% 롤 per-opportunity) + 스모크.
- S5 획득 unlock(2-candidate, lumion 패턴) + invalidate + 스모크.
- S6 카드/아이콘 imagegen(검정bg) + 절차적 VFX 폴리시 + HUD 확인.
- S7 적대리뷰 + warning/headless/스모크 최종.
