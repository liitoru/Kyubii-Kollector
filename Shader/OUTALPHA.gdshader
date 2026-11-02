shader_type spatial;
render_mode cull_front, unshaded, blend_mix;

uniform vec4 outline_color : source_color;
uniform float outline_width = 1.0;

uniform sampler2D alpha_texture : source_color, filter_nearest;
uniform float alpha_threshold : hint_range(0.0, 1.0) = 0.01;

void vertex() {
	vec4 clip_position = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 clip_normal = mat3(PROJECTION_MATRIX) * (mat3(MODELVIEW_MATRIX) * NORMAL);

	vec2 offset = normalize(clip_normal.xy) / VIEWPORT_SIZE * clip_position.w * outline_width * 2.0;

	clip_position.xy += offset;

	POSITION = clip_position;
}

void fragment() {
	vec4 tex = texture(alpha_texture, UV);

	float alpha = tex.a * outline_color.a;

	if (alpha < alpha_threshold) {
		discard;
	}

	ALBEDO = outline_color.rgb;
	ALPHA = alpha;
}
