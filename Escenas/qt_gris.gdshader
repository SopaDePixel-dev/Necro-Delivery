shader_type canvas_item;

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    
    // Distancia del color actual respecto al gris puro (0.502, 0.502, 0.502)
    vec3 gris_objetivo = vec3(0.502, 0.502, 0.502);
    float distancia = distance(color.rgb, gris_objetivo);
    
    // Si la distancia es muy corta (el color es muy parecido al gris), se vuelve transparente
    if (distancia < 0.15) {
        color.a = 0.0;
    } else if (distancia < 0.25) {
        // Desvanece los píxeles intermedios del borde
        color.a *= smoothstep(0.15, 0.25, distancia);
    }
    
    COLOR = color;
}