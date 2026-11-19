#version 440
// Liquid plasma for the visualizer's "Plasma" style: a warped field of slow waves, pushed by the bass, shaded with
// three colours. Written for this widget. Compile after editing:  /usr/lib/qt6/bin/qsb --qt6 plasma.frag -o plasma.frag.qsb
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float bass;
    float mid;
    float high;
    vec4 colA;
    vec4 colB;
    vec4 colC;
};

void main()
{
    vec2 p = qt_TexCoord0 * vec2(3.2, 2.0);
    float t = time;
    // warp the plane twice, the first time with the mids and the second with the bass
    p += 0.35 * vec2(sin(p.y * 1.7 + t * 0.7), cos(p.x * 1.3 - t * 0.6)) * (0.6 + mid);
    p += (0.25 + 0.5 * bass) * vec2(sin(p.y * 2.3 - t), cos(p.x * 2.1 + t * 0.8));
    float v = sin(p.x * 1.9 + t * 0.5) + sin(p.y * 2.4 - t * 0.4) + sin((p.x + p.y) * 1.5 + t * 0.3)
            + sin(length(p - vec2(1.6, 1.0)) * (3.0 + 2.0 * bass) - t);
    v = 0.5 + 0.25 * v;                       // about 0..1
    vec3 c = v < 0.5 ? mix(colA.rgb, colB.rgb, v * 2.0) : mix(colB.rgb, colC.rgb, (v - 0.5) * 2.0);
    c += high * 0.25 * smoothstep(0.7, 1.0, v);   // sparkle on the treble
    // fade out towards the top so the lyrics above it stay readable, and at the sides
    float edge = smoothstep(0.0, 0.18, qt_TexCoord0.x) * smoothstep(1.0, 0.82, qt_TexCoord0.x);
    float fall = smoothstep(0.0, 0.55, qt_TexCoord0.y);   // y = 0 is the top
    float a = edge * fall * (0.55 + 0.45 * bass);
    fragColor = vec4(c * a, a) * qt_Opacity;
}
