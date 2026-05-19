shader_type spatial;
render_mode blend_mix, depth_draw_opaque, diffuse_burley, specular_schlick_ggx, cull_back, shadows_disabled;

uniform float quad_size : hint_range(0.0, 20.0) = 8;
uniform float roughness : hint_range(0.0, 1.0);
uniform float specular : hint_range(0.0, 1.0, 0.01);
uniform float metallic : hint_range(0.0, 1.0, 0.01);
uniform float cull_threshold : hint_range(-1.0, 1.0) = 0.0;

void vertex() {
	vec3 v_normal = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	//
	float align = dot(v_normal, vec3(0.0, 0.0, 1.0));
	// align < 0.0, the 0.0 is cull threshold
	float final_scale = (align < cull_threshold) ? 0.0 : quad_size * COLOR.a;

	// 3. Expansion Logic
	int local_id = VERTEX_ID % 4;
	vec2 offset;
	if (local_id == 0)      offset = vec2(-0.5, -0.5);
	else if (local_id == 1) offset = vec2( 0.5, -0.5);
	else if (local_id == 2) offset = vec2( 0.5,  0.5);
	else                    offset = vec2(-0.5,  0.5);

	// 4. Transform the vertex position to View Space
	vec4 v_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	
	// 5. Expand the quad in View Space
	v_pos.xy += offset * final_scale;
	VERTEX = v_pos.xyz;
	
	// POSITION must be set using the projection of our modified View Space position
	POSITION = PROJECTION_MATRIX * v_pos;
}


void fragment() {
	ALBEDO = COLOR.rgb;
	METALLIC = metallic;
	SPECULAR = specular;
	ROUGHNESS = roughness;
}
