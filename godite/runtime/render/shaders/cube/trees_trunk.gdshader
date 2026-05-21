shader_type spatial;
#include "res://godite/runtime/render/shaders/cube/godite_wind.gdshaderinc"
#include "res://godite/runtime/render/shaders/cube/fade_out.gdshaderinc"
render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_burley,specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
//uniform sampler2D texture_normal : hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;

varying float view_distance;

void vertex() {
	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec4 tree_wind_timer = vec4(TIME) + vec4(NODE_POSITION_WORLD, 1.0);
	apply_wind(world_position, MODEL_MATRIX, VERTEX, tree_wind_timer);

}


void fragment() {
    vec4 tex = texture(texture_albedo, UV);
      
    ALBEDO = tex.rgb * albedo.rgb;

	fade_out(IN_SHADOW_PASS, VERTEX, FRAGCOORD.xy);
}
