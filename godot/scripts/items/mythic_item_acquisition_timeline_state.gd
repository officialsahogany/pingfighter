extends RefCounted

const PHASE_BUILDUP := "build"
const PHASE_IGNITE := "ignite"
const PHASE_WHITE_FADE := "white_fade"
const PHASE_REVEAL := "reveal"
const PHASE_ABSORB := "absorb"
const PHASE_IMPACT := "impact"

const BUILDUP_DURATION := 1.2
const IGNITE_DURATION := 0.4
const WHITE_FADE_DURATION := 0.5
const REVEAL_CLICK_DELAY := 0.5
const ABSORB_DURATION := 1.5
const IMPACT_DURATION := 0.5
const LEGEND_AFTER_STOP_DELAY := 1.5

const EVENT_STOP_LEGEND_AFTER := "stop_legend_after"
const EVENT_START_IGNITE := "start_ignite"
const EVENT_ENTER_WHITE_FADE := "enter_white_fade"
const EVENT_ENTER_REVEAL := "enter_reveal"
const EVENT_START_ABSORB := "start_absorb"
const EVENT_START_IMPACT := "start_impact"
const EVENT_COMPLETE := "complete"

var active := false
var phase := PHASE_BUILDUP
var phase_timer := 0.0
var elapsed := 0.0
var legend_after_played := false
var legend_after_stop_timer := 0.0
var absorb_started := false


func begin() -> void:
	active = true
	phase = PHASE_BUILDUP
	phase_timer = 0.0
	elapsed = 0.0
	legend_after_played = false
	legend_after_stop_timer = 0.0
	absorb_started = false


func cancel() -> void:
	active = false
	phase = PHASE_BUILDUP
	phase_timer = 0.0
	elapsed = 0.0
	legend_after_played = false
	legend_after_stop_timer = 0.0
	absorb_started = false


func is_waiting_for_click() -> bool:
	return active and phase == PHASE_REVEAL and phase_timer >= REVEAL_CLICK_DELAY and not absorb_started


func request_absorb() -> String:
	if not is_waiting_for_click():
		return ""
	absorb_started = true
	_set_phase(PHASE_ABSORB)
	if legend_after_played:
		legend_after_stop_timer = LEGEND_AFTER_STOP_DELAY
	return EVENT_START_ABSORB


func advance_clocks(delta: float) -> Array[String]:
	var events: Array[String] = []
	if not active:
		return events
	var dt: float = max(0.0, delta)
	elapsed += dt
	phase_timer += dt
	if legend_after_stop_timer > 0.0:
		legend_after_stop_timer = max(0.0, legend_after_stop_timer - dt)
		if legend_after_stop_timer <= 0.0:
			legend_after_played = false
			events.append(EVENT_STOP_LEGEND_AFTER)
	return events


func finish_phase_step() -> Array[String]:
	var events: Array[String] = []
	if not active:
		return events
	match phase:
		PHASE_BUILDUP:
			if phase_timer >= BUILDUP_DURATION:
				_set_phase(PHASE_IGNITE)
				legend_after_played = true
				events.append(EVENT_START_IGNITE)
		PHASE_IGNITE:
			if phase_timer >= IGNITE_DURATION:
				_set_phase(PHASE_WHITE_FADE)
				events.append(EVENT_ENTER_WHITE_FADE)
		PHASE_WHITE_FADE:
			if phase_timer >= WHITE_FADE_DURATION:
				_set_phase(PHASE_REVEAL)
				events.append(EVENT_ENTER_REVEAL)
		PHASE_ABSORB:
			if phase_timer >= ABSORB_DURATION:
				_set_phase(PHASE_IMPACT)
				events.append(EVENT_START_IMPACT)
		PHASE_IMPACT:
			if phase_timer >= IMPACT_DURATION:
				active = false
				events.append(EVENT_COMPLETE)
	return events


func _set_phase(next_phase: String) -> void:
	phase = next_phase
	phase_timer = 0.0
