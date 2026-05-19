// NOTE: Shader automatically converted from Godot Engine 4.6.1.stable's StandardMaterial3D.

shader_type spatial;
#include "res://godite/runtime/render/shaders/cube/godite_wind.gdshaderinc"
#include "res://godite/runtime/render/shaders/cube/fade_in.gdshaderinc"

render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color;

uniform float roughness : hint_range(0.0, 1.0);
uniform float specular : hint_range(0.0, 1.0, 0.01);
uniform float metallic : hint_range(0.0, 1.0, 0.01);

void vertex() {
	vec4 tree_wind_timer = vec4(TIME) + vec4(NODE_POSITION_WORLD, 1.0);
	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	apply_wind(world_position, MODEL_MATRIX, VERTEX, tree_wind_timer);
}

void fragment() {
	vec2 base_uv = UV;

	ALBEDO = albedo.rgb * COLOR.rgb;

	METALLIC = metallic;
	SPECULAR = specular;
	ROUGHNESS = roughness;

	fade_in(IN_SHADOW_PASS, VERTEX, FRAGCOORD.xy);
}
