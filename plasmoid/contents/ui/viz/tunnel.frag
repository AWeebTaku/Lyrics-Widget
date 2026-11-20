#version 440
// "Tunnel" visualizer style: rings and spokes rushing past, the speed set by the mids, the ring brightness by the bass
// and each spoke sector by one of the eight bands. Written for this widget.
// Compile after editing:  /usr/lib/qt6/bin/qsb --qt6 tunnel.frag -o tunnel.frag.qsb
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float bass;
    float mid;
    float high;
    vec4 bandsA;
    vec4 bandsB;
    vec4 colA;
    vec4 colB;
    vec4 colC;
};

float band(int i) { return i < 4 ? bandsA[i] : bandsB[i - 4]; }

void main()
{
    vec2 p = (qt_TexCoord0 - 0.5) * vec2(2.0, 2.0);
    float r = length(p);
    float ang = atan(p.y, p.x);                       // -pi..pi
    float sector = (ang / 6.2831853 + 0.5) * 8.0;
    int s = int(floor(sector)) % 8;
    float depth = 0.35 / max(r, 0.02) + time * (0.5 + 1.5 * mid);
    float rings = smoothstep(0.55, 0.95, 0.5 + 0.5 * sin(depth * 6.0 - bass * 3.0));
    float spokes = smoothstep(0.6, 0.95, 0.5 + 0.5 * sin(ang * 8.0 + time * 0.4));
    float lvl = band(s);
    vec3 c = mix(colA.rgb, colB.rgb, rings) + colC.rgb * spokes * (0.12 + 0.45 * lvl);
    float fade = smoothstep(0.02, 0.5, r) * smoothstep(1.35, 0.7, r);
    float a = fade * (0.35 + 0.65 * max(rings, spokes)) * (0.5 + 0.6 * bass + 0.3 * lvl);
    c = min(c + high * 0.08, vec3(1.0));
    fragColor = vec4(c * min(1.0, a), min(1.0, a)) * qt_Opacity;
}
