uniform float fade_from_distance;
uniform float fade_to_distance;

void fade_out(in bool in_shadow_pass, in vec3 vertex, in vec2 fragcoord)
{
	if (!in_shadow_pass)
	{
		// Distance Fade: Pixel Dither
		float fade_distance = length(vertex);

		// Use interleaved gradient noise, which is fast but still looks good.
		const vec3 magic = vec3(0.06711056, 0.00583715, 52.9829189);
		float fade = clamp(smoothstep(fade_to_distance, fade_from_distance, fade_distance), 0.0, 1.0);
		// Use a hard cap to prevent a few stray pixels from remaining when past the fade-out distance.
		if (fade < 0.001 || fade < fract(magic.z * fract(dot(fragcoord, magic.xy)))) {
			discard;
		}
	}
}
