shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec4 tint_color : source_color = vec4(1.0);

group_uniforms Billboard;
uniform bool enable_y_billboard = true;
// 0.0 = Y-Billboard puro (em pé) | 0.5 = 50% inclinado | 1.0 = Billboard completo
uniform float x_tilt_factor : hint_range(0.0, 1.0) = 0.5;

group_uniforms Bioluminescencia;
uniform vec4 glow_color : source_color = vec4(0.1, 0.8, 1.0, 1.0);
uniform float emission_energy : hint_range(0.0, 10.0) = 3.5;

// Controle da borda brilhante
uniform float rim_thickness : hint_range(0.0, 0.05) = 0.008;
uniform float rim_intensity : hint_range(0.0, 2.0) = 1.0;

// Controle dos traços/veias aleatórios e movimento
uniform float veins_scale = 8.0;
uniform float veins_threshold : hint_range(0.0, 1.0) = 0.82;
uniform float veins_intensity : hint_range(0.0, 2.0) = 1.2;
uniform float veins_flow_speed = 0.35;
uniform float pulse_speed = 1.5;

varying float world_seed;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	world_seed = (MODEL_MATRIX[3].x * 1.37 + MODEL_MATRIX[3].z * 2.93);

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

	// 1. Detecção de borda interna
	float a_up    = texture(albedo_texture, UV + vec2(0.0, rim_thickness)).a;
	float a_down  = texture(albedo_texture, UV - vec2(0.0, rim_thickness)).a;
	float a_left  = texture(albedo_texture, UV - vec2(rim_thickness, 0.0)).a;
	float a_right = texture(albedo_texture, UV + vec2(rim_thickness, 0.0)).a;
	float min_neighbor_alpha = min(min(a_up, a_down), min(a_left, a_right));
	float rim_mask = clamp((tex.a - min_neighbor_alpha) * 2.0, 0.0, 1.0) * rim_intensity;

	// 2. Traços/Veias com fluxo orgânico e dessincronizado
	vec2 uv_scaled = UV * vec2(veins_scale, veins_scale * 0.45);
	float t = (TIME + world_seed) * veins_flow_speed;
	
	float warp = noise(uv_scaled * 1.5 + vec2(t * 0.4, -t * 0.7));
	vec2 flow_offset = vec2(sin(t * 0.5) * 0.3, -t);
	float n = noise(uv_scaled + flow_offset + vec2(warp * 1.8, -warp * 0.8));
	
	float ridge = 1.0 - abs(n * 2.0 - 1.0);
	float veins_mask = smoothstep(veins_threshold, 0.98, ridge) * veins_intensity;

	// 3. Pulsação dessincronizada e saída final
	float pulse = 0.85 + 0.15 * sin((TIME + world_seed) * pulse_speed + UV.y * 5.0);
	float total_glow = clamp(rim_mask + veins_mask, 0.0, 1.0);

	EMISSION = glow_color.rgb * total_glow * emission_energy * pulse;
}