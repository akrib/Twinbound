shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec4 base_color : source_color;
uniform float time_offset = 0.0;
uniform float alpha_multiplier : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float t = TIME + time_offset;

	float h = UV.y;
	float alpha = smoothstep(0.05, 0.25, h) * smoothstep(1.0, 0.7, h);

	float pulse = 0.6 + 0.4 * sin(t * 2.0);

	vec3 col = base_color.rgb * (0.9 + pulse * 0.3);

	ALBEDO = col;
	EMISSION = col * (1.5 + pulse);
	ALPHA = alpha * alpha_multiplier;
}
