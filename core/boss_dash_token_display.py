from __future__ import annotations


def _clamp01(value: float) -> float:
    return max(0.0, min(1.0, value))


def get_boss_dash_token_display_state(
    *,
    gauge: float,
    gauge_cost: float,
    cooldown_until_ms: int,
    cooldown_total_ms: int,
    now_ms: int,
    is_dashing: bool = False,
    dash_stun_timer: int = 0,
) -> dict[str, float | int | bool | str]:
    """Compute boss dash-token HUD state from gauge and cooldown."""
    gauge_cost_value = float(gauge_cost)
    if gauge_cost_value <= 0:
        gauge_progress = 1.0
    else:
        gauge_progress = _clamp01(float(gauge) / gauge_cost_value)

    on_cooldown = cooldown_until_ms > 0 and now_ms < cooldown_until_ms
    if on_cooldown and cooldown_total_ms > 0:
        remaining = max(0, cooldown_until_ms - now_ms)
        cooldown_progress = _clamp01(1.0 - (remaining / float(cooldown_total_ms)))
    elif on_cooldown:
        cooldown_progress = 0.0
    else:
        cooldown_progress = 1.0

    available = int(
        gauge_progress >= 1.0
        and not on_cooldown
        and not is_dashing
        and dash_stun_timer <= 0
    )

    if available:
        charge_progress = 1.0
        count_text = "1/1"
    elif on_cooldown:
        charge_progress = cooldown_progress
        count_text = f"{int(round(cooldown_progress * 100.0))}%"
    elif gauge_progress > 0.0 and gauge_cost_value > 0:
        charge_progress = gauge_progress
        current_gauge = min(max(0.0, float(gauge)), gauge_cost_value)
        count_text = f"{int(current_gauge)}/{int(gauge_cost_value)}"
    elif gauge_progress >= 1.0:
        charge_progress = 1.0
        count_text = "0/1"
    else:
        charge_progress = 0.0
        count_text = "0/1"

    return {
        "available": available,
        "max_tokens": 1,
        "charge_progress": charge_progress,
        "count_text": count_text,
        "on_cooldown": on_cooldown,
        "cooldown_progress": cooldown_progress,
        "gauge_progress": gauge_progress,
    }
