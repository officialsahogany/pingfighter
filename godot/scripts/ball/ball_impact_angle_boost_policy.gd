extends RefCounted

const STRAIGHT_IMPACT_BOOST_MULT := 2.0

func get_multiplier(_velocity: Vector2) -> float:
	return STRAIGHT_IMPACT_BOOST_MULT
