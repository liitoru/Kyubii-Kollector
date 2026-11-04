shader_type spatial;
render_mode cull_front, unshaded, blend_mix, depth_draw_never, shadows_disabled;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_width = 1.0;

uniform sampler2D alpha_texture : source_color, filter_nearest, repeat_disable;
uniform float alpha_threshold : hint_range(0.0, 1.0) = 0.01;
uniform float alpha_softness : hint_range(0.001, 0.5) = 0.1;

void vertex() {
	vec4 clip_position = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 view_normal = normalize(mat3(MODELVIEW_MATRIX) * NORMAL);
	vec2 clip_normal = (PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy;

	float len = length(clip_normal);
	vec2 dir = len > 0.0001 ? clip_normal / len : vec2(0.0);

	clip_position.xy += dir * (outline_width * 2.0 / VIEWPORT_SIZE) * clip_position.w;

	POSITION = clip_position;
}

void fragment() {
	float alpha = texture(alpha_texture, UV).a * outline_color.a;
	float smooth_alpha = smoothstep(alpha_threshold, alpha_threshold + alpha_softness, alpha);

	if (smooth_alpha <= 0.001) {
		discard;
	}

	ALBEDO = outline_color.rgb;
	ALPHA = smooth_alpha;
}
