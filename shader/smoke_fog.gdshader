shader_type canvas_item;

uniform sampler2D screen_texture: hint_screen_texture;
uniform sampler2D noise_texture: filter_nearest, repeat_enable;
uniform vec2 speed = vec2(0.5, 0.2);
uniform float wave_strength = 0.1;
uniform float distortion = 0.01;
void vertex() {
	float wave = sin(TIME + VERTEX.x * 0.1);
	VERTEX.y += wave * 2.0;
}
void fragment() {
	vec2 uv = UV + speed * TIME;
	vec2 noise1 = 2.0 * texture(noise_texture, uv).rg - vec2(1.0);
	vec2 noise2 = 2.0 * texture(noise_texture, uv * 2.0 + TIME * 0.1).rg - vec2(1.0);
	vec2 noise = (noise1 * 0.7 + noise2 * 0.3);
	
	COLOR = texture(TEXTURE, UV + noise * wave_strength);
	COLOR *= texture(screen_texture, SCREEN_UV + noise * distortion);
	COLOR.rgb += vec3(max(noise.x, 0.0)) * 0.2;
	COLOR.rgb *= vec3(0.8, 0.9, 1.0);
}