shader_type spatial;
render_mode blend_add, depth_draw_never, unshaded, cull_front;
// Налитие неба багровым: гигантская сфера изнутри, добавка поверх панорамы.
// Террейн/строения перекрывают сферу по глубине — тонировано только небо.
uniform vec4 col_horizon : source_color = vec4(0.85, 0.16, 0.05, 1.0);
uniform vec4 col_zenith : source_color = vec4(0.22, 0.02, 0.03, 1.0);
uniform float intensity = 0.0;
uniform float noise_scale = 0.004;
uniform float speed = 0.3;
uniform float sphere_radius = 600.0;

varying float v_h;
varying vec3 v_wpos;

float hash12(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p){
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
	           mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p){
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++){ v += a * vnoise(p); p *= 2.07; a *= 0.5; }
	return v;
}

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_h = clamp(v_wpos.y / sphere_radius, -1.0, 1.0);
}

void fragment() {
	// медленные клубы багрового, ползущие от горизонта вверх
	float n = fbm(v_wpos.xz * noise_scale + vec2(TIME * speed, -TIME * speed * 0.6));
	float band = smoothstep(-0.08, 0.45, v_h);          // ниже горизонта почти нет
	float grad = mix(1.0, 0.4, clamp(v_h, 0.0, 1.0));   // ярче у горизонта
	vec3 col = mix(col_horizon.rgb, col_zenith.rgb, clamp(v_h, 0.0, 1.0));
	float f = band * grad * (0.6 + 0.4 * n) * intensity;
	EMISSION = col * f;
	ALPHA = clamp(f, 0.0, 1.0);
}
