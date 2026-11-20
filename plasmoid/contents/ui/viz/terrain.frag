#version 440
// "Terrain" visualizer style: a skyline of eight peaks on the horizon (one per band) over a grid that rolls towards
// you and lights up with the bass. Written for this widget. Compile after editing:  /usr/lib/qt6/bin/qsb --qt6 terrain.frag -o terrain.frag.qsb
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float bass;
    float mid;
    float high;
    vec4 bandsA;   // bands 0..3
    vec4 bandsB;   // bands 4..7
    vec4 colA;     // sky / glow
    vec4 colB;     // grid
    vec4 colC;     // peaks
};

float band(int i) { return i < 4 ? bandsA[i] : bandsB[i - 4]; }

void main()
{
    vec2 uv = qt_TexCoord0;           // y = 0 at the top
    float horizon = 0.46;
    vec3 col = vec3(0.0);
    float a = 0.0;
    if (uv.y < horizon) {
        // skyline: mirrored eight bands, smoothly interpolated, heights grow with the level
        float x = abs(uv.x - 0.5) * 2.0 * 7.0;
        int i0 = int(floor(x)), i1 = min(i0 + 1, 7);
        float h = mix(band(min(i0, 7)), band(i1), smoothstep(0.0, 1.0, fract(x)));
        float peak = horizon - (0.04 + 0.36 * h);
        float glow = smoothstep(peak - 0.2, peak, uv.y) * (0.25 + 0.4 * bass);
        col = colA.rgb * glow;
        a = glow;
        if (uv.y > peak) {                       // inside the mountain
            col = mix(colC.rgb, colA.rgb, (uv.y - peak) / max(0.001, horizon - peak)) * 0.9;
            a = 0.9;
        }
    } else {
        // ground: project the screen row to a depth, then draw lines along x and z
        float d = 1.0 / (uv.y - horizon + 0.02);
        float gx = (uv.x - 0.5) * d * 2.4;
        float gz = d + time * (1.2 + 2.0 * mid);
        float w = 0.05;                                   // line width in grid units
        float lx = smoothstep(w, 0.0, abs(fract(gx + 0.5) - 0.5));
        float lz = smoothstep(w, 0.0, abs(fract(gz + 0.5) - 0.5));
        float line = max(lx, lz);
        float fade = smoothstep(0.0, 0.5, uv.y - horizon);
        col = colB.rgb * line * (0.5 + 0.9 * bass) * (0.3 + fade);
        a = line * (0.35 + 0.65 * fade) * (1.0 - 0.0);
        col += colA.rgb * 0.15 * (1.0 - fade) * (0.5 + bass);
        a = max(a, 0.12 * (1.0 - fade));
    }
    col += high * 0.15 * colB.rgb * a;
    fragColor = vec4(col * min(1.0, a * 1.4), min(1.0, a)) * qt_Opacity;
}
