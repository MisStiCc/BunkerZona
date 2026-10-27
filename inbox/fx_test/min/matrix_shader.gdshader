shader_type spatial;
render_mode blend_mix, unshaded;
uniform float v = 0.8;
uniform float a = 0.0;
void fragment() {
	ALBEDO = vec3(0.0, 0.001, 0.0) * a;
	EMISSION = vec3(0.0, 1.0, 0.0) * v;
	ALPHA = 1.0;
}
