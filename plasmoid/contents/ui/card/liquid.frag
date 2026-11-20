#version 440
// Liquid glass surface: the cover art seen through a lens that follows the pointer, with a thin bright rim and a
// soft highlight. Written for this widget. Compile after editing:  /usr/lib/qt6/bin/qsb --qt6 liquid.frag -o liquid.frag.qsb
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float aspect;     // width / height
    float dim;        // 0..1 how much to darken
    vec2 pointer;     // 0..1, where the lens is
    float radius;     // corner radius as a share of the height
    float lens;       // 0..1 strength of the lens
};
layout(binding = 1) uniform sampler2D src;

void main()
{
    vec2 uv = qt_TexCoord0;
    vec2 d = (uv - pointer) * vec2(aspect, 1.0);
    float k = exp(-dot(d, d) * 9.0) * lens;
    vec2 uv2 = uv - (uv - pointer) * k * 0.22;
    uv2 += 0.004 * vec2(sin(uv.y * 14.0 + time), cos(uv.x * 11.0 - time * 0.8));   // a slow ripple
    vec3 c = texture(src, clamp(uv2, 0.0, 1.0)).rgb;
    c = mix(c, c * c * 1.1, 0.25) * (1.0 - dim);
    // rim: brighter towards the edges, strongest on the side facing the pointer
    vec2 e = abs(uv - 0.5) * 2.0;
    float edge = pow(max(e.x, e.y), 6.0);
    float facing = 0.5 + 0.5 * dot(normalize(uv - 0.5 + 0.0001), normalize(pointer - 0.5 + 0.0001));
    c += vec3(1.0) * edge * (0.18 + 0.25 * facing);
    c += vec3(1.0) * 0.35 * exp(-dot(d, d) * 40.0) * lens;     // highlight under the pointer
    fragColor = vec4(c, 1.0) * qt_Opacity;
}
