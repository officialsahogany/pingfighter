extends RefCounted

const Stage3CurseChestState := preload("res://scripts/stages/stage3/stage3_curse_chest_state.gd")
const Stage3PsychoballState := preload("res://scripts/stages/stage3/stage3_psychoball_state.gd")
const Stage3TailWhipState := preload("res://scripts/stages/stage3/stage3_tail_whip_state.gd")
const Stage3TearShowerState := preload("res://scripts/stages/stage3/stage3_tear_shower_state.gd")

## Coordinates Stage 3's two deliberately different reset policies. This
## owner holds no frame state or RNG; it only preserves reset fanout order.

var _tear_shower_state: Object
var _curse_chest_state: Object
var _psychoball_state: Object
var _tail_whip_state: Object
var _kuromi_eating_state: Object
var _kuromi_awakening_state: Object
var _prism_burst_state: Object
var _starpoint_state: Object


func _init(
	tear_shower_state: Object,
	curse_chest_state: Object,
	psychoball_state: Object,
	tail_whip_state: Object,
	kuromi_eating_state: Object,
	kuromi_awakening_state: Object,
	prism_burst_state: Object,
	starpoint_state: Object
) -> void:
	_tear_shower_state = tear_shower_state
	_curse_chest_state = curse_chest_state
	_psychoball_state = psychoball_state
	_tail_whip_state = tail_whip_state
	_kuromi_eating_state = kuromi_eating_state
	_kuromi_awakening_state = kuromi_awakening_state
	_prism_burst_state = prism_burst_state
	_starpoint_state = starpoint_state


func reset_full(host: Object) -> void:
	host.boss_special_gauge = 0.0
	host.boss_special_ready = false
	host.boss_red_intensity = 0.0
	host.psycho_cooldown = Stage3PsychoballState.COOLDOWN_SEC
	host.tears_cooldown = Stage3TearShowerState.COOLDOWN_SEC
	host.curse_cooldown = Stage3CurseChestState.COOLDOWN_SEC
	host.status = "charging"
	_reset_round_effects()
	host.tail_whip_cooldown = Stage3TailWhipState.INITIAL_COOLDOWN_SEC
	_kuromi_awakening_state.reset()


func reset_round(host: Object, red_target: float) -> void:
	host.boss_special_gauge = 0.0
	host.boss_special_ready = false
	host.boss_red_intensity = red_target
	_reset_round_effects()
	_tail_whip_state.roll_cooldown()


func _reset_round_effects() -> void:
	_tear_shower_state.reset_effects()
	_curse_chest_state.reset_effects()
	_psychoball_state.reset_effects()
	_tail_whip_state.reset_effects()
	_kuromi_eating_state.reset()
	_kuromi_awakening_state.reset_round_effects()
	_prism_burst_state.reset()
	_starpoint_state.clear()
