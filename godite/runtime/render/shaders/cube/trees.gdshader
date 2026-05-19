shader_type spatial;
#include "res://godite/runtime/render/shaders/cube/godite_wind.gdshaderinc"
#include "res://godite/runtime/render/shaders/cube/fade_out.gdshaderinc"

render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_burley,specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D texture_normal : hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform float alpha_scissor_threshold = 0.5;
uniform float albedo_compensation = 0.55;
uniform float thickness_decay : hint_range(0.0, 0.1) = 0.02;

varying flat float current_threshold;
varying flat float visibility_factor;

void vertex() {
	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 world_camera = INV_VIEW_MATRIX[3].xyz;
	vec4 tree_wind_timer = vec4(TIME) + vec4(NODE_POSITION_WORLD, 1.0);


	// 1. Get the Camera's World Position
	//vec3 world_camera = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;

	// 2. Get the Camera's Forward Direction in World Space
	// In Godot, the third column of the INV_VIEW_MATRIX is the camera's Z-axis
	vec3 camera_forward = -INV_VIEW_MATRIX[2].xyz;

	// 3. Get the vector from camera to the vertex (using world coordinates)
	vec3 dir_to_obj = world_position - world_camera;

	float view_distance = dot(dir_to_obj, camera_forward);

    visibility_factor = 1.0 / (1.0 + (view_distance * thickness_decay));
    
    current_threshold = alpha_scissor_threshold * visibility_factor;

	apply_wind(world_position, MODEL_MATRIX, VERTEX, tree_wind_timer);
}



void fragment() {
    vec4 tex = texture(texture_albedo, UV);
   
    // 3. COLOR COMPENSATION (The Fix for the Dip)
    // We only want to brighten the pixels that are NEAR the threshold.
    // If we brighten everything, the whole tree looks "glowy".
    vec3 brightened = tex.rgb / max(tex.a, albedo_compensation);
    
    // We mix based on the same factor used for the scissor.
    // This ensures the color logic stays "in sync" with the transparency logic.
    vec3 final_color = mix(brightened, tex.rgb, visibility_factor);
    
    ALBEDO = final_color * albedo.rgb;
    ALPHA = albedo.a * tex.a;
    ALPHA_SCISSOR_THRESHOLD = current_threshold;

	METALLIC = 0.0;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;

	fade_out(IN_SHADOW_PASS, VERTEX, FRAGCOORD.xy);
}
