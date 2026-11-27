//
//  LiquidGlass.metal
//  Freesla
//
//  Shader de refracción tipo Liquid Glass. SwiftUI lo ejecuta una vez por píxel (`layerEffect`)
//  y le da `layer`, con el que podemos leer el color de OTRO punto de la imagen.
//  Esa es la clave de la refracción: en vez de pintar el píxel (x, y) con su color,
//  lo pintamos con el color de un punto desplazado.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// Distancia con signo a un rectángulo redondeado centrado en el origen:
/// negativa dentro, 0 en el borde, positiva fuera.
static float sdRoundBox(float2 p, float2 halfSize, float radius) {
    float2 q = abs(p) - halfSize + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

/// Color desenfocado alrededor de `pos`: un punto central y dos anillos de 8 muestras.
static half3 blurredSample(SwiftUI::Layer layer, float2 pos, float2 size, float radius) {
    half3 sum = 0;
    float weight = 0;
    for (int ring = 0; ring < 3; ring++) {
        float r = radius * float(ring) * 0.5;
        int count = ring == 0 ? 1 : 8;
        for (int i = 0; i < count; i++) {
            float angle = 6.2831853 * float(i) / float(count) + float(ring) * 0.4;
            float2 q = pos + r * float2(cos(angle), sin(angle));
            q = clamp(q, float2(0.5), size - 0.5); // no leer fuera de la imagen
            sum += layer.sample(q).rgb;
            weight += 1.0;
        }
    }
    return sum / half(weight);
}

/// - size: tamaño en puntos de la vista
/// - cornerRadius: radio de las esquinas inferiores
/// - bevel: ancho (px) de la franja del borde que actúa como lente
/// - strength: cuánto se desplaza la imagen en el canto (px)
/// - dispersion: separación de los canales R/B (aberración cromática), 0...1
/// - blur: radio del desenfoque esmerilado (px)
[[ stitchable ]] half4 liquidGlass(float2 position, SwiftUI::Layer layer, float2 size,
                                   float cornerRadius, float bevel, float strength,
                                   float dispersion, float blur) {
    // La caja se alarga hacia arriba: solo hay borde a los lados y abajo (arriba se funde con el negro).
    const float extra = 400.0;
    float2 halfSize = float2(size.x * 0.5, (size.y + extra) * 0.5);
    float2 center = float2(size.x * 0.5, size.y - halfSize.y);
    float2 p = position - center;

    float depth = -sdRoundBox(p, halfSize, cornerRadius); // distancia al borde, hacia dentro

    // Normal del borde (hacia fuera) = gradiente de la distancia, por diferencias finitas.
    const float e = 1.0;
    float2 n = float2(
        sdRoundBox(p + float2(e, 0), halfSize, cornerRadius) - sdRoundBox(p - float2(e, 0), halfSize, cornerRadius),
        sdRoundBox(p + float2(0, e), halfSize, cornerRadius) - sdRoundBox(p - float2(0, e), halfSize, cornerRadius));
    n = normalize(n + float2(1e-5));

    // 0 en el interior, 1 justo en el canto. El cuadrado hace que la lente "agarre" sobre todo en el borde.
    float t = clamp(1.0 - depth / bevel, 0.0, 1.0);
    float shift = strength * t * t;

    // Leemos de más adentro: así el borde parece curvar la imagen hacia el centro.
    float2 base = position - n * shift;
    float2 red = position - n * shift * (1.0 + dispersion);
    float2 blue = position - n * shift * (1.0 - dispersion);

    half3 color;
    color.r = blurredSample(layer, red, size, blur).r;
    color.g = blurredSample(layer, base, size, blur).g;
    color.b = blurredSample(layer, blue, size, blur).b;

    // Cristal: leve velo claro y un filo muy fino de luz en el canto.
    color = mix(color, half3(1.0), 0.06);
    float rim = smoothstep(2.0, 0.0, depth) * 0.22;
    color += half(rim);

    return half4(color, 1.0);
}
