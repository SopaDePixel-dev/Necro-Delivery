shader_type canvas_item;

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    
    float brillo = max(color.r, max(color.g, color.b));
    
    if (brillo < 0.25) {
        color.a = 0.0;
    }
    
    COLOR = color;
}