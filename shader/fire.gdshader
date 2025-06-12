shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_back, unshaded;

// Uniforms for customization
uniform float flame_intensity : hint_range(0.0, 5.0) = 1.5;
uniform float flame_speed : hint_range(0.0, 10.0) = 2.0;
uniform vec3 base_color : source_color = vec3(1.0, 0.3, 0.0); // Orange-red base
uniform vec3 tip_color : source_color = vec3(1.0, 1.0, 0.0); // Yellow tip
uniform float noise_scale : hint_range(0.1, 10.0) = 2.0;
uniform float flame_height : hint_range(0.0, 1.0) = 0.5;
uniform sampler2D noise_texture; // NoiseTexture2D for flame animation

void fragment() {
	// Animate UVs for upward flame movement
	vec2 uv = UV;
	uv.y -= TIME * flame_speed;
	
	// Sample noise texture for flame shape
	vec2 noise_uv = uv * noise_scale;
	float n = texture(noise_texture, noise_uv).r;
	
	// Create flame shape based on UV.y and noise
	float flame = smoothstep(0.0, flame_height, uv.y + n * 0.5);
	
	// Color gradient from base to tip
	vec3 color = mix(tip_color, base_color, flame);
	
	// Apply intensity and transparency
	float alpha = (1.0 - flame) * flame_intensity;
	
	// Output to albedo and emission
	ALBEDO = color;
	ALPHA = alpha;
	EMISSION = color * flame_intensity * (1.0 - flame);
}