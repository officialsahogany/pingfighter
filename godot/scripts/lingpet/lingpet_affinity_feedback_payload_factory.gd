extends RefCounted


static func build_point_popup(amount: float) -> Dictionary:
	return {
		"amount": maxf(0.0, amount),
		"age": 0.0,
	}


static func build_draw_popup(popup: Dictionary, popup_seconds: float) -> Dictionary:
	return {
		"amount": float(popup.get("amount", 0.0)),
		"ratio": clampf(float(popup.get("age", 0.0)) / maxf(0.001, popup_seconds), 0.0, 1.0),
	}
