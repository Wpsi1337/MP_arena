shader_type canvas_item;

uniform float ripple_speed = 2.0; // Speed of the ripple animation
uniform float ripple_amplitude = 0.03; // Strength of the ripple distortion
uniform float ripple_frequency = 2.0; // Frequency of the ripple waves
uniform vec2 label_size = vec2(100.0, 50.0); // Set to Label's approximate size

void fragment() {
    // Normalize UVs based on label size
    vec2 uv = UV * label_size;
    float ripple = sin(uv.x * ripple_frequency + TIME * ripple_speed) * ripple_amplitude;
    uv.y += ripple / label_size.y; // Scale ripple by height
    
    // Sample the texture with normalized UVs
    vec4 color = texture(TEXTURE, uv / label_size);
    // Tint the color to red
    COLOR.rgb = color.rgb * vec3(1.0, 0.0, 0.0);
    COLOR.a = color.a; // Preserve original alpha
}