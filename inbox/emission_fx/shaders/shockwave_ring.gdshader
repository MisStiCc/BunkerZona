shader_type spatial;
render_mode blend_add, depth_draw_never, unshaded, cull_disabled;
// Ударная волна Выброса: фронт-кольцо по земле + затухающий след внутри.
// ring_pos (0..1) ведёт контроллер: 1.0 = край арены (половина стороны квада).
uniform vec4 ring_col : source_color = vec4(1.0, 0.45, 0.12, 1.0);
uniform vec4 inner_col : source_color = vec4(0.5, 0.07, 0.03, 1.0);
uniform float ring_pos = 0.0;
uniform float ring_width = 0.055;
uniform float intensity = 0.0;
uniform float speed = 1.0;

varying vec2 v_uv;

void vertex() {
	v_uv = UV;
}

void fragment() {
	vec2 c = v_uv - 0.5;
	float ang = atan(c.y, c.x);
	// рябь на фронте: волнистая кромка, дрожит по времени
	float wob = 0.025 * sin(ang * 16.0 + TIME * 7.0 * speed) + 0.012 * sin(ang * 31.0 - TIME * 11.0 * speed);
	float d = length(c) * 2.0 + wob;
	float r = clamp(ring_pos, 0.0, 1.4);
	float band = smoothstep(r - ring_width, r, d) * (1.0 - smoothstep(r, r + ring_width * 0.7, d));
	float inner = clamp(smoothstep(r, 0.0, d) * 0.3 * (0.7 + 0.3 * sin(ang * 6.0 + TIME * 2.0)), 0.0, 1.0);
	vec3 col = ring_col.rgb * band + inner_col.rgb * inner;
	float f = clamp(band + inner, 0.0, 1.0);
	EMISSION = col * intensity;
	ALPHA = f;
}
