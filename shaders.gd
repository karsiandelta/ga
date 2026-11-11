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
	vec3 grass = mix(vec3(0.07, 0.16, 0.04), vec3(0.16, 0.24, 0.05), n1) * (0.75 + 0.5 * n2);
	vec3 dry = vec3(0.30, 0.24, 0.08) * (0.75 + 0.5 * n2);
	grass = mix(grass, dry, smoothstep(170.0, 270.0, dist) * 0.7);
	vec3 dirt = vec3(0.17, 0.14, 0.11) * (0.8 + 0.25 * n3) * (0.85 + 0.3 * n1);
	vec3 rock = vec3(0.20, 0.19, 0.18) * (0.6 + 0.8 * n2) * (0.8 + 0.4 * n3);
	vec3 sand = vec3(0.42, 0.36, 0.22) * (0.8 + 0.3 * n3);
	float slope = 1.0 - normalize(wn).y;
	vec3 col = mix(grass, rock, smoothstep(0.10, 0.22, slope + (n2 - 0.5) * 0.08));
	float town = 1.0 - smoothstep(21.0, 31.0, dist + (n2 - 0.5) * 9.0);
	float road = 1.0 - smoothstep(2.0, 4.5, abs(wp.x) + (n2 - 0.5) * 2.0);
	road *= step(wp.z, -10.0) * step(-225.0, wp.z);
	float arena = 1.0 - smoothstep(12.0, 20.0, length(wp.xz - vec2(0.0, -215.0)) + (n2 - 0.5) * 6.0);
	col = mix(col, dirt, max(max(town, road), arena) * 0.92);
	col = mix(col, sand, 1.0 - smoothstep(-2.1, -1.3, wp.y + (n3 - 0.5) * 0.4));
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
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
	vec3 base = mix(vec3(0.10, 0.21, 0.05), vec3(0.20, 0.29, 0.07), n1);
	vec3 tip = mix(vec3(0.22, 0.40, 0.08), vec3(0.42, 0.46, 0.12), n1);
	vec3 col = mix(base, tip, hf);
	col = mix(col, vec3(0.42, 0.34, 0.12) * (0.6 + 0.6 * hf), smoothstep(170.0, 270.0, length(wp.xz)) * 0.7);
	ALBEDO = col;
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
	ALBEDO = mix(vec3(0.01, 0.07, 0.10), vec3(0.04, 0.20, 0.22), clamp(w * 2.2, 0.0, 1.0));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALPHA = mix(0.78, 0.97, fres);
	ROUGHNESS = 0.06;
	SPECULAR = 0.9;
	vec3 bump = (VIEW_MATRIX * vec4((n1 - 0.5) * 0.35, 0.0, (n2 - 0.5) * 0.35, 0.0)).xyz;
	NORMAL = normalize(NORMAL + bump);
	EMISSION = vec3(0.5, 0.7, 0.75) * smoothstep(0.34, 0.40, w) * 0.25 + vec3(0.25, 0.4, 0.45) * fres * 0.35;
}
"""

const SKY = """
shader_type sky;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 top = vec3(0.10, 0.26, 0.52);
	vec3 horizon = vec3(0.80, 0.62, 0.42);
	vec3 col = mix(horizon, top, pow(clamp(d.y, 0.0, 1.0), 0.42));
	if (d.y < 0.0) {
		col = mix(horizon, vec3(0.30, 0.36, 0.34), clamp(-d.y * 4.0, 0.0, 1.0));
	}
	float s = max(dot(d, LIGHT0_DIRECTION), 0.0);
	col += LIGHT0_COLOR * (pow(s, 900.0) * 6.0 + pow(s, 14.0) * 0.30);
	if (d.y > 0.01) {
		vec2 uv = d.xz / (d.y + 0.18);
		float c = texture(noise_tex, uv * 0.11).r * 0.65 + texture(noise_tex, uv * 0.37 + vec2(0.3, 0.1)).r * 0.35;
		float m = smoothstep(0.50, 0.70, c) * smoothstep(0.01, 0.22, d.y);
		vec3 lit = mix(vec3(0.95, 0.78, 0.62), vec3(1.0, 0.97, 0.92), clamp(c * 1.2 - 0.3, 0.0, 1.0));
		col = mix(col, lit + LIGHT0_COLOR * s * 0.2, m * 0.92);
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
uniform vec3 tint : source_color = vec3(0.7, 0.2, 0.2);
void vertex() {
	float k = UV.y;
	VERTEX.z -= k * 0.22 + sin(TIME * 4.0 + UV.y * 5.0 + UV.x * 2.0) * 0.07 * k;
	VERTEX.x += sin(TIME * 2.7 + UV.y * 4.0) * 0.03 * k;
}
void fragment() {
	ALBEDO = tint * (0.75 + 0.25 * sin(UV.x * 40.0) * 0.2 + 0.25 * (1.0 - UV.y));
	if (UV.y > 0.9) {
		ALBEDO = vec3(0.70, 0.48, 0.12);
	}
	ROUGHNESS = 0.8;
}
"""
