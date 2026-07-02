extends RefCounted

const STATE_EGG := "egg"
const STATE_COMPANION := "companion"
const EGG_EFFECT_TEXT_TEMPLATE := "공에 %d회 맞히면 미확인 알이 깨어납니다."


static func resolve(state: String, required_hits: int, current_profile: Object) -> String:
	if state == STATE_EGG:
		return EGG_EFFECT_TEXT_TEMPLATE % maxi(1, required_hits)
	if state == STATE_COMPANION and current_profile != null and current_profile.has_method("get_effect_text"):
		return str(current_profile.get_effect_text())
	return ""
