shader_type canvas_item;

uniform float u_t    : hint_range(0.0, 10000.0) = 0.0;
uniform float u_glow : hint_range(0.1, 3.0)     = 1.0;
uniform float u_n    : hint_range(3.0, 20.0)    = 12.0;
uniform vec2  u_res  = vec2(512.0, 512.0);
uniform vec2  u_mouse = vec2(0.0, 0.0);   // espace [-1..1, -1..1]

const float GS = 0.18;

float sdC(vec2 p, float r) {
    return length(p) - r;
}

float ld(vec2 p, vec2 a, vec2 b) {
    vec2 ba = b - a;
    vec2 pa = p - a;
    return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

float glow_fn(float d, float s) {
    return s / (d * d + 0.0006);
}

vec2 snap(vec2 v) {
    return floor(v / GS + 0.5) * GS;
}

void fragment() {
    vec2 uv = FRAGCOORD.xy / u_res;
    uv.y    = 1.0 - uv.y;

    float aspect = u_res.x / u_res.y;
    vec2 p   = (uv * 2.0 - 1.0) * vec2(aspect, 1.0);
    vec2 hub = u_mouse * vec2(aspect, 1.0);

    vec3  col   = vec3(0.0);
    float pulse = 0.5 + 0.5 * sin(u_t * 0.8);

    // ── Grille de points ──────────────────────────────────────────────────────
    vec2 gp = mod(p + GS * 0.5, GS) - GS * 0.5;
    col += vec3(0.26) * (1.0 - smoothstep(0.0, 0.003, sdC(gp, 0.007)));

    // ── Branches (boucle de taille fixe max=20) ───────────────────────────────
    for (int i = 0; i < 20; i++) {
        if (float(i) >= u_n) { break; }
        float fi = float(i);

        float a     = fi / u_n * 6.2832 + sin(fi * 2.399) * 0.22;
        float steps = 2.0 + floor(mod(fi * 1.7, 3.0));
        vec2  raw   = u_mouse + vec2(cos(a), sin(a)) * steps * GS;
        vec2  s     = snap(raw);
        if (length(s - snap(u_mouse)) < 0.01) {
            s += snap(vec2(cos(a), sin(a)) * GS);
        }
        vec2 t = s * vec2(aspect, 1.0);

        // Ligne hub → nœud
        float li = ld(p, hub, t) - 0.0025;
        col += vec3(0.90) * (1.0 - smoothstep(0.0, 0.003, li));
        col += vec3(0.40, 0.52, 0.95) * glow_fn(max(li, 0.0), 0.000045 * u_glow);

        // Nœud terminal
        float ni = sdC(p - t, 0.026 + 0.003 * sin(u_t * 1.5 + fi));
        col += vec3(1.0) * (1.0 - smoothstep(0.0, 0.004, ni));
        col += vec3(0.45, 0.62, 1.0) * glow_fn(max(ni + 0.01, 0.0),
                    0.00007 * u_glow * (0.8 + 0.2 * pulse));
    }

    // ── Hub central ──────────────────────────────────────────────────────────
    float c = sdC(p - hub, 0.036 + 0.003 * pulse);
    col += vec3(1.0) * (1.0 - smoothstep(0.0, 0.005, c));
    col += vec3(0.38, 0.55, 1.0) * glow_fn(max(c + 0.005, 0.0),
                0.00025 * u_glow * (0.85 + 0.15 * pulse));

    COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
