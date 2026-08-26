shader_type spatial;
render_mode cull_back, unshaded;

uniform sampler2D water_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec2 scroll_speed = vec2(0.0, -0.6);
uniform vec2 uv_scale = vec2(1.0, 3.0);

void fragment() {
    // World space position ensures seamless texture alignment across repeating track segments
    vec2 world_xz = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
    
    // Continuous scrolling UV - inverted sign so water flows downstream toward camera
    vec2 scrolling_uv = (world_xz * uv_scale * 0.1) - (TIME * scroll_speed);
    
    // Sample texture with custom tint
    vec4 tex = texture(water_texture, scrolling_uv);
    
    ALBEDO = tex.rgb * tint_color.rgb;
}
