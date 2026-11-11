extends RefCounted
# Shaders del juego, escritos como texto para crearlos por código.

static var _cache: Dictionary = {}


static func mat(code: String, params: Dictionary = {}) -> ShaderMaterial:
	var key = code.hash()
	if not _cache.has(key):
		var s = Shader.new()
		s.code = code
		_cache[key] = s
	var m = ShaderMaterial.new()
	m.shader = _cache[key]
	for k in params.keys():
		m.set_shader_parameter(k, params[k])
	return m


const TERRAIN = """
shader_type spatial;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
varying vec3 wp;
varying vec3 wn;
void vertex() {
	wp = VERTEX;
	wn = NORMAL;
}
void fragment() {
	float n1 = texture(noise_tex, wp.xz * 0.02).r;
	float n2 = texture(noise_tex, wp.xz * 0.13).r;
	float n3 = texture(noise_tex, wp.xz * 0.7).r;
	float dist = length(wp.xz);
	vec3 grass = mix(vec3(0.030, 0.050, 0.028), vec3(0.070, 0.078, 0.036), n1) * (0.7 + 0.6 * n2);
	vec3 ash = vec3(0.085, 0.080, 0.078) * (0.7 + 0.6 * n2);
	grass = mix(grass, ash, smoothstep(150.0, 260.0, dist) * 0.85);
	vec3 mud = vec3(0.070, 0.055, 0.045) * (0.75 + 0.5 * n3) * (0.8 + 0.4 * n1);
	float cob = smoothstep(0.35, 0.65, texture(noise_tex, wp.xz * 0.33).r);
	vec3 cobble = mix(vec3(0.045, 0.045, 0.052), vec3(0.078, 0.075, 0.074), cob) * (0.85 + 0.3 * n3) * (0.85 + 0.3 * n1);
	vec3 rock = vec3(0.075, 0.075, 0.085) * (0.6 + 0.8 * n2) * (0.8 + 0.4 * n3);
	vec3 silt = vec3(0.085, 0.075, 0.06) * (0.8 + 0.3 * n3);
	float slope = 1.0 - normalize(wn).y;
	vec3 col = mix(grass, rock, smoothstep(0.10, 0.22, slope + (n2 - 0.5) * 0.08));
	float town = 1.0 - smoothstep(21.0, 31.0, dist + (n2 - 0.5) * 9.0);
	float road = 1.0 - smoothstep(2.0, 4.5, abs(wp.x) + (n2 - 0.5) * 2.0);
	road *= step(wp.z, -10.0) * step(-225.0, wp.z);
	float arena = 1.0 - smoothstep(12.0, 20.0, length(wp.xz - vec2(0.0, -215.0)) + (n2 - 0.5) * 6.0);
	col = mix(col, mud, max(road, arena) * 0.92);
	col = mix(col, cobble, town * 0.95);
	col = mix(col, silt, 1.0 - smoothstep(-2.1, -1.3, wp.y + (n3 - 0.5) * 0.4));
	ALBEDO = col * 2.4;
	ROUGHNESS = mix(0.95, 0.55, town * cob);
	SPECULAR = 0.2;
}
"""

const GRASS = """
shader_type spatial;
render_mode cull_disabled, world_vertex_coords;
uniform vec3 player_pos;
uniform sampler2D hmap : filter_linear, repeat_disable;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
const float TILE = 70.0;
varying float hf;
varying vec3 wp;
void vertex() {
	vec3 ip = MODEL_MATRIX[3].xyz;
	vec2 rel = mod(ip.xz - player_pos.xz + TILE * 0.5, TILE) - TILE * 0.5;
	vec2 wxz = player_pos.xz + rel;
	vec2 huv = ((wxz + 320.0) / 5.0 + 0.5) / 129.0;
	float h = textureLod(hmap, huv, 0.0).r;
	float s = 1.0 - smoothstep(TILE * 0.36, TILE * 0.48, length(rel));
	s *= smoothstep(27.0, 36.0, length(wxz));
	s *= smoothstep(-1.8, -1.1, h);
	s *= smoothstep(14.0, 22.0, length(wxz - vec2(0.0, -215.0)));
	if (wxz.y < -10.0 && wxz.y > -225.0) {
		s *= smoothstep(3.0, 5.5, abs(wxz.x));
	}
	float n = textureLod(noise_tex, wxz * 0.02, 0.0).r;
	s *= 0.55 + n;
	vec3 off = VERTEX - ip;
	hf = UV.y;
	float wind = sin(TIME * 2.2 + wxz.x * 0.35 + wxz.y * 0.27) * 0.14 + sin(TIME * 5.0 + wxz.x * 1.3) * 0.04;
	vec3 p = vec3(wxz.x, h, wxz.y) + off * s;
	p.x += wind * hf * hf * s;
	p.z += wind * 0.6 * hf * hf * s;
	VERTEX = p;
	NORMAL = vec3(0.0, 1.0, 0.0);
	wp = p;
}
void fragment() {
	float n1 = texture(noise_tex, wp.xz * 0.02).r;
	vec3 base = mix(vec3(0.028, 0.046, 0.026), vec3(0.060, 0.068, 0.032), n1);
	vec3 tip = mix(vec3(0.085, 0.115, 0.055), vec3(0.20, 0.185, 0.10), n1);
	vec3 col = mix(base, tip, hf);
	col = mix(col, vec3(0.16, 0.15, 0.14) * (0.4 + 0.8 * hf), smoothstep(150.0, 260.0, length(wp.xz)) * 0.8);
	ALBEDO = col * 2.4;
	ROUGHNESS = 0.85;
	SPECULAR = 0.15;
}
"""

const WATER = """
shader_type spatial;
render_mode blend_mix, cull_back;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float n1 = texture(noise_tex, wp.xz * 0.03 + TIME * vec2(0.010, 0.006)).r;
	float n2 = texture(noise_tex, wp.xz * 0.08 - TIME * vec2(0.012, 0.010)).r;
	float w = n1 * n2;
	ALBEDO = mix(vec3(0.008, 0.024, 0.026), vec3(0.04, 0.10, 0.085), clamp(w * 2.2, 0.0, 1.0));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALPHA = mix(0.78, 0.97, fres);
	ROUGHNESS = 0.06;
	SPECULAR = 0.9;
	vec3 bump = (VIEW_MATRIX * vec4((n1 - 0.5) * 0.35, 0.0, (n2 - 0.5) * 0.35, 0.0)).xyz;
	NORMAL = normalize(NORMAL + bump);
	EMISSION = vec3(0.35, 0.55, 0.5) * smoothstep(0.34, 0.40, w) * 0.10 + vec3(0.10, 0.14, 0.16) * fres * 0.30;
}
"""

const SKY = """
shader_type sky;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 top = vec3(0.030, 0.050, 0.085);
	vec3 horizon = vec3(0.30, 0.13, 0.09);
	vec3 col = mix(horizon, top, pow(clamp(d.y, 0.0, 1.0), 0.33));
	if (d.y < 0.0) {
		col = mix(horizon, vec3(0.03, 0.035, 0.04), clamp(-d.y * 4.0, 0.0, 1.0));
	}
	float s = max(dot(d, LIGHT0_DIRECTION), 0.0);
	vec3 moon = vec3(0.75, 0.85, 1.0);
	col += moon * (smoothstep(0.9990, 0.9994, s) * 3.0 + pow(s, 40.0) * 0.22 + pow(s, 6.0) * 0.05);
	if (d.y > 0.01) {
		vec2 uv = d.xz / (d.y + 0.18);
		float c = texture(noise_tex, uv * 0.11).r * 0.65 + texture(noise_tex, uv * 0.37 + vec2(0.3, 0.1)).r * 0.35;
		float m = smoothstep(0.43, 0.63, c) * smoothstep(0.01, 0.2, d.y);
		vec3 lit = mix(vec3(0.05, 0.058, 0.075), vec3(0.24, 0.26, 0.32), clamp(c * 1.4 - 0.5, 0.0, 1.0));
		lit += moon * pow(s, 8.0) * 0.25;
		lit = mix(lit, vec3(0.16, 0.06, 0.04), (1.0 - smoothstep(0.0, 0.25, d.y)) * 0.6);
		col = mix(col, lit, m * 0.95);
	}
	COLOR = col;
}
"""

# Copas de árbol y rocas: esfera deformada con ruido, color por instancia y balanceo opcional.
const BLOB = """
shader_type spatial;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float sway = 0.0;
uniform float bump = 0.9;
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float n = textureLod(noise_tex, VERTEX.xz * 0.35 + VERTEX.y * 0.27 + wp.xz * 0.05, 0.0).r;
	VERTEX += NORMAL * (n - 0.5) * bump;
	VERTEX.x += sin(TIME * 1.3 + wp.x * 0.2 + wp.z * 0.15) * sway;
	VERTEX.z += cos(TIME * 1.1 + wp.x * 0.17) * sway * 0.6;
}
void fragment() {
	float n = texture(noise_tex, wp.xz * 0.30 + wp.y * 0.21).r;
	float n2 = texture(noise_tex, wp.xz * 1.1 + wp.y * 0.9).r;
	ALBEDO = COLOR.rgb * (0.45 + 0.8 * n) * (0.8 + 0.4 * n2);
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	EMISSION = COLOR.rgb * rim * 0.10 * sway * 8.0;
}
"""

const STONE = """
shader_type spatial;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float hit = 0.0;
varying vec3 lp;
void vertex() {
	lp = VERTEX;
	float n = textureLod(noise_tex, VERTEX.xy * 0.22 + VERTEX.zx * 0.17, 0.0).r;
	VERTEX += NORMAL * (n - 0.5) * 1.1;
}
void fragment() {
	float n = texture(noise_tex, lp.xy * 0.20 + lp.zx * 0.13).r;
	float n2 = texture(noise_tex, lp.yz * 0.9 + lp.x * 0.7).r;
	float veins = 1.0 - smoothstep(0.0, 0.03, abs(n - 0.5));
	float pulse = 0.6 + 0.4 * sin(TIME * 3.0 + lp.y);
	ALBEDO = vec3(0.035, 0.035, 0.045) * (0.5 + n2);
	ROUGHNESS = 0.45;
	SPECULAR = 0.6;
	vec3 glow = vec3(0.08, 1.0, 0.72);
	EMISSION = glow * veins * (2.5 * pulse + hit * 20.0) + glow * hit * 1.5;
}
"""

const CAPE = """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 tint : source_color = vec3(0.4, 0.08, 0.08);
uniform float ember = 0.0;
void vertex() {
	float k = UV.y;
	VERTEX.z -= k * 0.22 + sin(TIME * 4.0 + UV.y * 5.0 + UV.x * 2.0) * 0.07 * k;
	VERTEX.x += sin(TIME * 2.7 + UV.y * 4.0) * 0.03 * k;
}
void fragment() {
	float edge = 0.80 + 0.12 * sin(UV.x * 31.0) + 0.06 * sin(UV.x * 77.0 + 1.3);
	if (UV.y > edge) {
		discard;
	}
	ALBEDO = tint * (0.55 + 0.45 * (1.0 - UV.y)) * (0.9 + 0.1 * sin(UV.x * 60.0));
	ROUGHNESS = 0.9;
	EMISSION = vec3(1.0, 0.32, 0.06) * ember * smoothstep(edge - 0.25, edge, UV.y) * 3.0;
}
"""
