#version 440
// Film grain over a surface: still noise, light and dark specks. Written for this widget.
// Compile after editing:  /usr/lib/qt6/bin/qsb --qt6 grain.frag -o grain.frag.qsb
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float amount;     // 0..1
    vec2 size;        // px
};
void main()
{
    vec2 p = floor(qt_TexCoord0 * size);
    float n = fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
    float a = abs(n - 0.5) * 2.0 * amount * 0.35;
    vec3 c = n > 0.5 ? vec3(1.0) : vec3(0.0);
    fragColor = vec4(c * a, a) * qt_Opacity;
}
