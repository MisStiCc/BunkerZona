shader_type spatial;
render_mode blend_add, unshaded;
void fragment() {
	EMISSION = vec3(0.0, 0.8, 0.0);
	ALPHA = 1.0;
}
