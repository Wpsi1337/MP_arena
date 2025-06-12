shader_type canvas_item;

uniform sampler2D noise_texture : filter_nearest, repeat_enable;
uniform float sway_speed : hint_range(0.0, 10.0) = 2.0;
uniform float sway_strength : hint_range(0.0, 0.5) = 0.1;
uniform float sway_height : hint_range(0.0, 1.0) = 0.5; // Where sway starts (lower = higher sway)

void vertex() {
	// Use UV.y to apply sway only to upper part of the tile
	float sway_factor = smoothstep(sway_height, 1.0, UV.y);
	
	// Sample noise for variation across tiles
	vec2 noise_uv = UV + vec2(TIME * 0.1, 0.0); // Slow horizontal noise movement
	float noise = texture(noise_texture, noise_uv).r;
	
	// Calculate sway displacement
	float sway = sin(TIME * sway_speed + noise * 2.0) * sway_strength * sway_factor;
	
	// Apply sway to X position
	VERTEX.x += sway;
}

void fragment() {
	// Pass through the tilemap texture
	COLOR = texture(TEXTURE, UV);
}