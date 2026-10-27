shader_type spatial;
render_mode blend_mix, unshaded;
void fragment() {
	ALBEDO = vec3(0.0, 0.8, 0.0);
	EMISSION = vec3(0.0, 0.1, 0.0);
	ALPHA = 1.0;
}
