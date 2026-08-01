shader_type canvas_item;

uniform float body_heat_ratio : hint_range(0.0, 1.0) = 0.0;
uniform float white_hot_start_ratio : hint_range(0.0, 1.0) = 0.78;


void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	float heat_mix = smoothstep(0.02, 0.68, body_heat_ratio);
	float white_hot = smoothstep(white_hot_start_ratio, 1.0, body_heat_ratio);
	vec3 red_heat = vec3(1.25, 0.025, 0.008) * (0.58 + luminance * 0.62);
	vec3 white_heat = vec3(1.0, 0.72, 0.28) * (0.68 + luminance * 0.48);
	vec3 heated_body = mix(red_heat, white_heat, white_hot);
	COLOR = vec4(mix(source.rgb, heated_body, heat_mix), source.a * COLOR.a);
}
