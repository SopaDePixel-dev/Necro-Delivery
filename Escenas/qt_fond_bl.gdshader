shader_type canvas_item;

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    
    // Evaluamos la dominancia del canal azul frente a rojo y verde
    float diferencia_azul = color.b - max(color.r, color.g);
    
    // Si el azul domina claramente sobre los otros colores, lo volvemos transparente
    if (diferencia_azul > 0.15) {
        color.a = 0.0;
    } else if (diferencia_azul > 0.05) {
        // Suavizado en los bordes para desvanecer el aura
        color.a *= smoothstep(0.15, 0.05, diferencia_azul);
    }
    
    COLOR = color;
}