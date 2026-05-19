shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

//#include "res://godite/runtime/render/shaders/cube/godite_wind.gdshaderinc"
#include "res://godite/runtime/render/shaders/cube/fade_in.gdshaderinc"

uniform sampler2D impostor_atlas : source_color, hint_default_black, filter_nearest_mipmap_anisotropic;
uniform sampler2D impostor_normal_atlas : hint_normal, filter_nearest_mipmap_anisotropic;

uniform float grid_size;
uniform vec3 aabb_center;

uniform float alpha_scissor_threshold : hint_range(0.0, 0.8);

varying vec2 oct_uv;
varying mat3 v_world_to_view_rot;

// Converts 3D direction to 2D Octahedral UV
vec2 get_octahedral_uv(vec3 dir) {
    dir /= (abs(dir.x) + abs(dir.y) + abs(dir.z));
    if (dir.y < 0.0) {
        return (1.0 - abs(dir.zx)) * sign(dir.xz);
    }
    return dir.xz;
}



void vertex() {
    // 1. Capture the exact rotation from World to View
	// Pass model_matrix to fragment; with multimeshinstance, MODEL_MATRIX is not
	// the same as in vertex(...), but the transform of the node!; not the instance.
	// To proper render in MMI case, need to manually pass the instance MODEL_MATRIX
	// here from vertex(...)
    v_world_to_view_rot = mat3(VIEW_MATRIX) * mat3(MODEL_MATRIX);
	
    // SPHERICAL BILLBOARDING
    float scale_x = length(MODEL_MATRIX[0].xyz);
    float scale_y = length(MODEL_MATRIX[1].xyz);
    float scale_z = length(MODEL_MATRIX[2].xyz);
	
    // Instead of using the raw MODEL_MATRIX translation, calculate the world position of the AABB center.
	// this is needed for proper grounding at the correct handle (bottom trunk of tree for example)
    vec4 world_center = MODEL_MATRIX * vec4(aabb_center, 1.0);
	//world_center = MODEL_MATRIX * vec4(0.0,0.0,0.0, 1.0);
	
	// Transform the model's "Up" vector into VIEW SPACE; This captures the X/Z tilt relative to the camera's eye
    vec3 view_up = normalize(mat3(VIEW_MATRIX) * mat3(MODEL_MATRIX) * vec3(0.0, 1.0, 0.0));
    
    // 4. Reconstruct the billboard in View Space; In viewspace, "Forward" is always (0, 0, 1)
    const vec3 view_forward = vec3(0.0, 0.0, 1.0);
    vec3 view_right = normalize(cross(view_up, view_forward));
    
    // Re-calculate up to ensure perfect orthogonality in view space
    view_up = cross(view_forward, view_right);

    // 5. Build the final ModelView Matrix
    // This is now purely in View Space, so it cannot "thin out"
    mat4 view_model_matrix = mat4(
        vec4(view_right * scale_x, 0.0),
        vec4(view_up * scale_y, 0.0),
        vec4(view_forward * scale_z, 0.0),
        vec4(0.0, 0.0, 0.0, 1.0)
    );

    // 6. Set the position (the 4th column)
    view_model_matrix[3].xyz = (VIEW_MATRIX * world_center).xyz;

    MODELVIEW_MATRIX = view_model_matrix;

    // PASS DIRECTION TO FRAGMENT
    vec3 world_view_dir = normalize(NODE_POSITION_WORLD - CAMERA_POSITION_WORLD);
    mat3 inv_model = mat3(inverse(MODEL_MATRIX));
    vec3 v_local_view_dir = normalize(inv_model * world_view_dir);

	// View distance to allow scissor correction over distance
	vec3 camera_forward = -INV_VIEW_MATRIX[2].xyz;
	vec3 world_camera = INV_VIEW_MATRIX[3].xyz;

	// Get the vector from camera to the vertex (using world coordinates)
	//float view_distance = dot(world_center.xyz - world_camera, camera_forward);
	// note: not longer scissor adjusting like in 3d foilage shader

    oct_uv = get_octahedral_uv(v_local_view_dir) * 0.5 + 0.5;

}


void fragment() {
    
    vec2 grid_pos = oct_uv * (grid_size - 1.0);
    vec2 tile_low = floor(grid_pos);
    vec2 tile_high = ceil(grid_pos);
    vec2 weight = fract(grid_pos);
    
    // Albedo Sampling
    vec2 uv00 = (tile_low + UV) / grid_size;
    vec2 uv10 = (vec2(tile_high.x, tile_low.y) + UV) / grid_size;
    vec2 uv01 = (vec2(tile_low.x, tile_high.y) + UV) / grid_size;
    vec2 uv11 = (tile_high + UV) / grid_size;

    vec4 tex00 = texture(impostor_atlas, uv00);
    vec4 tex10 = texture(impostor_atlas, uv10);
    vec4 tex01 = texture(impostor_atlas, uv01);
    vec4 tex11 = texture(impostor_atlas, uv11);
    
    // Cross-fading the tile samples
    vec4 tex_x_low = mix(tex00, tex10, weight.x);
    vec4 tex_x_high = mix(tex01, tex11, weight.x);
    vec4 albedo = mix(tex_x_low, tex_x_high, weight.y);
    
	// Normal sampling
	vec4 texn00 = texture(impostor_normal_atlas, uv00);
	vec4 texn10 = texture(impostor_normal_atlas, uv10);
	vec4 texn01 = texture(impostor_normal_atlas, uv01);
	vec4 texn11 = texture(impostor_normal_atlas, uv11);

	vec4 tex_nx_low = mix(texn00, texn10, weight.x);
	vec4 tex_nx_high = mix(texn01, texn11, weight.x);
	vec3 n_sample = mix(tex_nx_low, tex_nx_high, weight.y).xyz;

	// Normal decode 
	vec3 world_normal = normalize(n_sample.rgb * 2.0 - 1.0);	

	// NOTE: this wont work in MultiMeshInstance3D: (see comment in vertex shader)
	//       vec3 v_normal = mat3(VIEW_MATRIX) * mat3(MODEL_MATRIX) * w_normal;
	// This does work:
	NORMAL = v_world_to_view_rot * world_normal;

    ALBEDO = albedo.rgb;
    ALPHA = albedo.a;
    ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;

	METALLIC = 0.0;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;

	BACKLIGHT = vec3(0.1,0.1,0.1);

	fade_in(IN_SHADOW_PASS, VERTEX, FRAGCOORD.xy);
}
