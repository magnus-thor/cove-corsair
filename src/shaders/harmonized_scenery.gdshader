shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_toon, specular_toon;

// ── Albedo & Roughness Unification ───────────────────────────────────────────
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_albedo_texture = true;
uniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float roughness_override : hint_range(0.0, 1.0) = 0.85;
uniform float specular_limit : hint_range(0.0, 0.5) = 0.06;
uniform float painterly_posterize : hint_range(0.0, 1.0) = 0.22;

// ── Stepped Cel / Toon Lighting ──────────────────────────────────────────────
uniform vec3 shadow_tint : source_color = vec3(0.35, 0.40, 0.55);
uniform float shadow_threshold : hint_range(-0.5, 0.5) = -0.05;
uniform float midtone_threshold : hint_range(0.1, 0.9) = 0.42;
uniform float highlight_threshold : hint_range(0.5, 1.0) = 0.85;
uniform float cel_feather : hint_range(0.01, 0.08) = 0.03;
uniform float rim_strength : hint_range(0.0, 0.5) = 0.16;

// ── Foliage Wind Sway ────────────────────────────────────────────────────────
uniform bool enable_wind = false;
uniform float wind_speed : hint_range(0.1, 10.0) = 2.2;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.18;

// ── Distance Atmospheric Horizon Blending ────────────────────────────────────
uniform vec4 fog_color : source_color = vec4(0.48, 0.76, 0.94, 1.0);
uniform float fog_start : hint_range(10.0, 150.0) = 55.0;
uniform float fog_end : hint_range(40.0, 250.0) = 160.0;
uniform float fog_horizon_mix : hint_range(0.0, 1.0) = 0.70;

varying float v_view_dist;
varying float v_world_y;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_y = world_pos.y;

	if (enable_wind) {
		float height_mask = max(0.0, VERTEX.y);
		float phase = TIME * wind_speed + (world_pos.x * 0.45) + (world_pos.z * 0.45);
		float sway_x = sin(phase) * wind_strength * height_mask * 0.28;
		float sway_z = cos(phase * 0.85) * wind_strength * height_mask * 0.20;
		VERTEX.x += sway_x;
		VERTEX.z += sway_z;
	}

	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	v_view_dist = max(0.0, -view_pos.z);
}

void fragment() {
	vec4 tex_col = vec4(1.0);
	if (use_albedo_texture) {
		tex_col = texture(albedo_texture, UV);
	}
	vec3 base_albedo = tex_col.rgb * albedo_tint.rgb * COLOR.rgb;

	// Subtle painterly color unification to soften photogrammetric Meshy texture noise toward Kenney flat art
	vec3 quantized_albedo = floor(base_albedo * 12.0 + 0.5) / 12.0;
	base_albedo = mix(base_albedo, quantized_albedo, painterly_posterize);

	// Vertical grounding gradient: subtle warm AO near waterline (Y = 0), brighter toward canopy
	float vertical_grad = clamp(0.88 + clamp(v_world_y * 0.04, 0.0, 0.18), 0.85, 1.06);
	base_albedo *= vertical_grad;

	// Smoothly blend albedo toward horizon fog_color over view-space distance (-VERTEX.z)
	float fog_factor = smoothstep(fog_start, fog_end, v_view_dist) * fog_horizon_mix;
	ALBEDO = mix(base_albedo, fog_color.rgb, clamp(fog_factor, 0.0, 1.0));
	ROUGHNESS = roughness_override;
	METALLIC = 0.0;
	SPECULAR = specular_limit;
}

void light() {
	float ndotl = dot(NORMAL, LIGHT);

	// 3-band quantized cel shading with smoothstep feathering (0.03) to prevent pixel flicker
	float band_mid = smoothstep(shadow_threshold - cel_feather, shadow_threshold + cel_feather, ndotl);
	float band_high = smoothstep(midtone_threshold - cel_feather, midtone_threshold + cel_feather, ndotl);

	// Shadow (cool ambient fill) -> Midtone -> Sunlit Highlight stylized ramp
	vec3 lit_ramp = mix(shadow_tint, vec3(0.80, 0.79, 0.76), band_mid);
	lit_ramp = mix(lit_ramp, vec3(1.16, 1.12, 1.04), band_high);

	// Crisp stylized rim highlight on sunlit silhouettes
	float fresnel = 1.0 - max(0.0, dot(NORMAL, VIEW));
	float rim_step = smoothstep(0.62 - cel_feather, 0.62 + cel_feather, fresnel) * band_mid;
	lit_ramp += vec3(0.95, 0.92, 0.82) * (rim_step * rim_strength);

	// IMPORTANT: Do NOT multiply by ALBEDO here; Godot 4 spatial shaders automatically multiply DIFFUSE_LIGHT * ALBEDO
	vec3 light_energy_norm = max(LIGHT_COLOR / 3.14159265, vec3(0.90));
	DIFFUSE_LIGHT = max(DIFFUSE_LIGHT, lit_ramp * light_energy_norm * ATTENUATION);

	// Clamp and attenuate specular highlights to eliminate harsh plastic noise on photogrammetric Meshy models
	vec3 half_vec = normalize(VIEW + LIGHT);
	float ndoth = max(0.0, dot(NORMAL, half_vec));
	float spec_band = smoothstep(highlight_threshold - cel_feather, highlight_threshold + cel_feather, pow(ndoth, 20.0));
	SPECULAR_LIGHT += light_energy_norm * ATTENUATION * spec_band * specular_limit * 0.20;
}
