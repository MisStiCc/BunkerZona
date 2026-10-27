shader_type spatial;
render_mode blend_mix, unshaded;
void fragment() {
	EMISSION = vec3(1.0, 0.35, 0.1);
	ALPHA = 1.0;
}
