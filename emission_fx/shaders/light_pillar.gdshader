shader_type spatial;
render_mode blend_add, depth_draw_never, unshaded, cull_disabled;
// Мерцающий столб света Выброса: цилиндр, ярче у земли, полосы-лучи, дрожь.
// seed у каждого столба свой — расставляет контроллер.
uniform vec4 col_low : source_color = vec4(1.0, 0.72, 0.3, 1.0);
uniform vec4 col_high : source_color = vec4(0.85, 0.16, 0.04, 1.0);
uniform float intensity = 0.0;
uniform float seed = 0.0;
uniform float speed = 3.0;

varying vec2 v_uv;

void vertex() {
	v_uv = UV;
}

void fragment() {
	float flick = 0.6 + 0.4 * sin(TIME * speed + seed * 17.0 + sin(TIME * 2.3 + seed) * 2.0);
	float streaks = 0.72 + 0.28 * sin(v_uv.x * TAU * 6.0 + TIME * 1.5 + seed * 9.0);
	float grad = pow(clamp(1.0 - v_uv.y, 0.0, 1.0), 1.7);   // гаснет к вершине
	float f = grad * flick * streaks * intensity;
	vec3 col = mix(col_low.rgb, col_high.rgb, clamp(v_uv.y, 0.0, 1.0));
	ALBEDO = col * f;
	ALPHA = clamp(f * 1.3, 0.0, 1.0);
}
