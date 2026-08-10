extends SceneTree

const PlazaCoinTradeFxRuntimeHost := preload("res://scripts/plaza/plaza_coin_trade_fx_runtime_host.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := PlazaCoinTradeFxRuntimeHost.new()
	root.add_child(host)
	await process_frame
	_verify_ready_contract(host)
	_verify_particle_sync(host)
	_verify_burst_and_exit_cleanup(host)
	host.free()
	if _failures.is_empty():
		print("plaza_coin_trade_fx_runtime_host_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_ready_contract(host: PlazaCoinTradeFxRuntimeHost) -> void:
	var status := host.get_status()
	_expect(bool(status.get("particles_ready", false)), "runtime host should create its sparkle particle layer")
	_expect(not bool(status.get("process_enabled", true)), "controller-driven runtime host should keep its own process disabled")
	_expect(bool(status.get("pulse_tween_active", false)), "runtime host should own the looping pulse Tween")
	_expect(bool(status.get("aura_writhe_shader", false)), "runtime host should own the Writhe aura material")
	_expect(bool(status.get("burst_writhe_shader", false)), "runtime host should own the Writhe burst material")
	var particles := host.get_node_or_null("CoinTradeSparkParticles") as GPUParticles2D
	_expect(particles != null, "runtime host should expose one named sparkle particle child")
	if particles != null:
		_expect(particles.amount == 34, "sparkle particle amount should retain the live contract")
		_expect(particles.fixed_fps == 60, "sparkle particles should retain their fixed simulation rate")
		_expect(particles.z_index == 60, "sparkle particles should retain their draw order")


func _verify_particle_sync(host: PlazaCoinTradeFxRuntimeHost) -> void:
	var coin_spec := {
		"id": "shop_strewn_coin_pile",
		"rect": Rect2(Vector2(475.0, 430.0), Vector2(86.0, 50.0)),
	}
	host.sync_particles("shop", false, coin_spec, 0.6, 0.2, 2.0)
	var status := host.get_status()
	_expect(bool(status.get("particle_emitting", false)), "visible shop coin FX should emit particles")
	var particles := host.get_node_or_null("CoinTradeSparkParticles") as GPUParticles2D
	if particles != null:
		_expect(particles.position == Vector2(1036.0, 900.0), "particle sync should retain scaled coin position")
	host.sync_particles("shop", true, coin_spec, 0.6, 0.2, 2.0)
	_expect(not bool(host.get_status().get("particle_emitting", true)), "trade modal should stop coin particles immediately")
	host.sync_particles("bank", false, coin_spec, 0.6, 0.2, 2.0)
	_expect(not bool(host.get_status().get("particle_emitting", true)), "non-shop views should keep coin particles stopped")


func _verify_burst_and_exit_cleanup(host: PlazaCoinTradeFxRuntimeHost) -> void:
	var coin_spec := {
		"id": "shop_strewn_coin_pile",
		"rect": Rect2(Vector2(475.0, 430.0), Vector2(86.0, 50.0)),
	}
	host.play_burst()
	host.sync_particles("shop", false, coin_spec, 0.0, 0.0, 1.0)
	var active_status := host.get_status()
	_expect(float(active_status.get("burst_value", 0.0)) > 0.0, "click burst should seed its Tween envelope")
	_expect(bool(active_status.get("burst_tween_active", false)), "runtime host should own the click burst Tween")
	_expect(host.is_animating("shop", false, true, false, false, 0.0), "active burst should request owner redraw")
	root.remove_child(host)
	var stopped_status := host.get_status()
	_expect(not bool(stopped_status.get("particle_emitting", true)), "tree exit should stop active particles")
	_expect(not bool(stopped_status.get("pulse_tween_active", true)), "tree exit should kill the pulse Tween")
	_expect(not bool(stopped_status.get("burst_tween_active", true)), "tree exit should kill the burst Tween")
	_expect(is_zero_approx(float(stopped_status.get("pulse_value", -1.0))), "tree exit should reset the pulse envelope")
	_expect(is_zero_approx(float(stopped_status.get("burst_value", -1.0))), "tree exit should reset the burst envelope")


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
