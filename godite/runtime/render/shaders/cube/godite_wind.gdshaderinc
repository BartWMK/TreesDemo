uniform bool wind_enabled = true;

// how the wind sin/cos frequencies are scaled for each of the timers ex. vec4(5000, 1500, 500, 5)
global uniform vec4 tree_wind_size;
// how strong is the wind: x - trunk, y - branches, z - leaves/alpha card branches, ex. vec3(5.0, 3, 0.125)
global uniform vec3 tree_wind_power;

void apply_wind(inout vec3 world_pos, in mat4 model_matrix, inout vec3 vertex, vec4 timer) {
	if (wind_enabled) {
	    // 1. CONSTANTS (Tune these for the feel of the field)
	    const float wave_scale = 0.05;    // Larger = smaller waves. Try 0.01 for massive rolling hills of wind.
	    const float wave_speed = 1.4;     // How fast the wave travels across the field.
	    vec2 wind_dir = normalize(vec4(1.0, 0.0, 0.5, 0.0).xz); // Global world direction

	    // 2. SYNTHETIC WEIGHTS (The "Pinning" logic)
	    float synth_height = clamp(vertex.y / max(0.1, tree_wind_size.y), 0.0, 1.0);
	    float synth_leaves = clamp(length(vertex.xz) / max(0.1, tree_wind_size.x), 0.0, 1.0);

	    // 3. THE GLOBAL SWAY (Smooth & Coherent)
	    // We use a single Sine wave based on World X/Z to ensure neighbors move together.
	    float world_phase = (world_pos.x * wind_dir.x + world_pos.z * wind_dir.y) * wave_scale;
	    float global_wave = sin(TIME * wave_speed + world_phase);
	    
	    // Remap sin (-1 to 1) to (0 to 1) for a "leaning" effect rather than "vibrating"
	    float lean_amount = (global_wave * 0.5 + 0.5) * tree_wind_power.x;
	    vec3 sway = vec3(wind_dir.x, 0.0, wind_dir.y) * lean_amount * pow(synth_height, 2.0);

	    // 4. THE LOCAL JITTER (Gentle Leaf Wobble)
	    // We use a much faster, smaller sine for the "flutter" but keep it subtle.
	    float flutter_phase = TIME * 3.0 + dot(world_pos.xz, vec2(0.1));
	    vec3 flutter = vec3(sin(flutter_phase), 0.0, cos(flutter_phase * 0.8)) 
	                   * tree_wind_power.y * synth_leaves * 0.05;

	    // 5. FINAL ASSEMBLY
	    // Multiplying the whole thing by synth_height keeps the trunk base frozen at (0,0,0)
	    world_pos += (sway + flutter) * synth_height;

	    // Convert back to local space for Godot
	    vertex = (inverse(model_matrix) * vec4(world_pos, 1.0)).xyz;
	}
}

// OLD COLOR data based wind

	//if (wind_enabled) {
		//vec3 world_normals = MODEL_NORMAL_MATRIX * NORMAL;
		//
		//vec3 global_wind = (world_position.xyz / tree_wind_size.x) + tree_wind_timer.x;
		//global_wind = vec3(cos(global_wind.x), 0, sin(global_wind.z));
		//global_wind.y = 1.0 + abs(dot(global_wind.x, global_wind.z));
		//
		//vec3 wind_force = (world_position / tree_wind_size.x) + tree_wind_timer.y - global_wind;
		//wind_force = vec3(cos(wind_force.x), 0, sin(wind_force.y));
		//
		//vec3 wind_animate = wind_force * tree_wind_power.x * (VERTEX.y / tree_wind_size.y);
		//float wind_variant = tree_wind_timer.z + (COLOR.y * 10.0);
		//
		//wind_animate.xz += vec2(cos(wind_variant), sin(wind_variant)) * COLOR.z * tree_wind_power.y * 0.1;
		//
		//vec3 wind_flutter = (world_position.xyz / tree_wind_size.w) + tree_wind_timer.w + COLOR.y;
		//wind_animate += abs(world_normals) * sin( dot(wind_flutter, vec3(1)) * tree_wind_size.w ) * COLOR.x * (tree_wind_power.z / tree_wind_size.w);
		//
		//world_position += wind_animate * global_wind.y;
		//VERTEX = (inverse(MODEL_MATRIX) * vec4(world_position, 1.0)).xyz;
	//}
