shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(0.08, 0.58, 0.82, 0.88);
uniform float roughness : hint_range(0.0, 1.0) = 0.05;
uniform sampler2D texture_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_refraction : filter_linear_mipmap, repeat_enable;
uniform float refraction_strength : hint_range(-1.0, 1.0) = 0.04;
uniform vec3 uv1_scale = vec3(0.15, 0.15, 0.15);
uniform vec2 flow_speed = vec2(0.0, -0.6); // Flows toward the camera

varying vec3 uv1_triplanar_pos;

void vertex() {
    // World triplanar position: prevents stretching and ensures seamless continuity across segments
    vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    uv1_triplanar_pos = world_pos * uv1_scale;
    
    // Animate the triplanar coordinate over time
    uv1_triplanar_pos.z += TIME * flow_speed.y;
    uv1_triplanar_pos.x += TIME * flow_speed.x;
}

void fragment() {
    // Sample seamless triplanar normal for top-facing plane (XZ)
    vec2 tri_uv = uv1_triplanar_pos.xz;
    vec3 normal_sample = texture(texture_normal, tri_uv).rgb;
    
    ALBEDO = albedo.rgb;
    ALPHA = albedo.a;
    ROUGHNESS = roughness;
    SPECULAR = 0.6;
    NORMAL_MAP = normal_sample;
    NORMAL_MAP_DEPTH = 1.2;
    
    // Refraction distortion from the noise map
    vec3 ref_sample = texture(texture_refraction, tri_uv).rgb;
    NORMAL = mix(NORMAL, normal_sample, refraction_strength);
}
