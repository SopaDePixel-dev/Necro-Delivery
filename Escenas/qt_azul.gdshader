shader_type canvas_item;

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    
    // Si el color azul es dominante (el fondo azul), lo volvemos transparente
    if (color.b > 0.5 && color.r < 0.3 && color.g < 0.3) {
        discard;
    } else {
        COLOR = color;
    }
}
