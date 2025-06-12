shader_type canvas_item;

uniform float pixel_size : hint_range(1, 64) = 16.0;
uniform vec2 resolution = vec2(1920.0, 1080.0);
uniform vec2 mouse_uv = vec2(0.5, 0.5);
uniform float lens_radius : hint_range(0.0, 1.0) = 0.2;
uniform float feather : hint_range(0.0, 1.0) = 0.05;
uniform float warp_strength = 0.0;

void fragment() {
    vec2 pixelated_uv = floor(UV * resolution / pixel_size) * pixel_size / resolution;

    float dist = distance(UV, mouse_uv);
    float blend = smoothstep(lens_radius - feather, lens_radius, dist);

    vec2 warped_uv = UV;

    if (warp_strength > 0.0) {
        vec2 dir = mouse_uv - UV;
        float dist = length(dir);
        vec2 dir_norm = normalize(dir);

        float pull_strength = pow(1.0 - blend, 3.0) * 0.05 * warp_strength;
        float angle = 6.2831 * (1.0 - dist) * 5.0 * warp_strength;

        vec2 rotated_dir = vec2(
            dir_norm.x * cos(angle) - dir_norm.y * sin(angle),
            dir_norm.x * sin(angle) + dir_norm.y * cos(angle)
        );

        warped_uv += rotated_dir * pull_strength;
    }

    // Chromatic aberration (color distortion)
    float chroma_strength = pow(1.0 - blend, 3.0) * 0.01 * warp_strength;
    vec2 chroma_offset_r = vec2(chroma_strength, 0.0);
    vec2 chroma_offset_g = vec2(-chroma_strength * 0.5, chroma_strength * 0.5);
    vec2 chroma_offset_b = vec2(-chroma_strength, 0.0);

    float r = texture(TEXTURE, warped_uv + chroma_offset_r).r;
    float g = texture(TEXTURE, warped_uv + chroma_offset_g).g;
    float b = texture(TEXTURE, warped_uv + chroma_offset_b).b;

    vec4 color_chroma = vec4(r, g, b, 1.0);

    vec4 pix = texture(TEXTURE, pixelated_uv);

    // Mix pixelated and warped + chroma color by blend
    COLOR = mix(pix, color_chroma, blend);
}
