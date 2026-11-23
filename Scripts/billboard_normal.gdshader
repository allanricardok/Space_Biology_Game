shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec4 tint_color : source_color = vec4(1.0);

group_uniforms Billboard;
uniform bool enable_y_billboard = true;
// 0.0 = Y-Billboard puro (em pé) | 0.5 = 50% inclinado | 1.0 = Billboard completo
uniform float x_tilt_factor : hint_range(0.0, 1.0) = 0.5;

void vertex() {
	if (enable_y_billboard) {
		vec3 blended_up = normalize(mix(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[1].xyz, x_tilt_factor));
		vec3 right = normalize(cross(blended_up, INV_VIEW_MATRIX[2].xyz));
		vec3 forward = normalize(cross(right, blended_up));

		mat4 modified_model_view = VIEW_MATRIX * mat4(
			vec4(right, 0.0),
			vec4(blended_up, 0.0),
			vec4(forward, 0.0),
			MODEL_MATRIX[3]
		);
		MODELVIEW_MATRIX = modified_model_view;
		MODELVIEW_MATRIX[0] *= length(MODEL_MATRIX[0].xyz);
		MODELVIEW_MATRIX[1] *= length(MODEL_MATRIX[1].xyz);
		MODELVIEW_MATRIX[2] *= length(MODEL_MATRIX[2].xyz);
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV) * tint_color;
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}