extends RefCounted
# Shaders y texturas procedurales de Ciudad Mirasol.
# El tipo de superficie viaja en el alfa del color de vértice:
# 0.0 césped · 0.1 asfalto · 0.2 enlucido · 0.3 ladrillo · 0.4 tejas · 0.5 madera
# 0.6 baldosa · 0.7 follaje (viento) · 0.8 pintura brillante · 0.9 piel/ropa · 1.0 liso

const WORLD := """
shader_type spatial;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
varying vec3 wpos;
varying vec3 wnrm;
varying float mid;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	mid = COLOR.a;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (mid > 0.65 && mid < 0.75) {
		float amp = clamp((wp.y - 1.2) * 0.2, 0.0, 1.0);
		VERTEX.x += (sin(TIME * 1.5 + wp.x * 0.4 + wp.z * 0.3) * 0.07 + sin(TIME * 3.1 + wp.z * 0.9) * 0.025) * amp;
		VERTEX.z += sin(TIME * 1.2 + wp.x * 0.5) * 0.05 * amp;
	}
	wpos = wp;
	wnrm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 an = abs(wnrm);
	vec2 uv;
	float hcoord;
	if (an.y > an.x && an.y > an.z) { uv = wpos.xz; hcoord = wpos.x; }
	else if (an.x > an.z) { uv = wpos.zy; hcoord = wpos.z; }
	else { uv = wpos.xy; hcoord = wpos.x; }
	float n1 = texture(noise_tex, uv * 0.031).r;
	float n2 = texture(noise_tex, uv * 0.37).r;
	vec3 col = pow(COLOR.rgb, vec3(2.2));
	float rough = 0.88;
	float metal = 0.0;
	float spec = 0.45;
	float bump = 0.0;
	float bscale = 0.37;
	int id = int(floor(mid * 10.0 + 0.5));
	bool top = an.y > 0.7;
	if (id == 0) {
		col *= mix(0.95, 1.4, n1);
		col = mix(col, col * vec3(1.25, 1.12, 0.55), smoothstep(0.56, 0.8, n2) * 0.3);
		col *= 0.9 + 0.2 * texture(noise_tex, uv * 1.7).r;
		rough = 1.0;
		spec = 0.15;
		bump = 1.6;
	} else if (id == 1) {
		col *= 0.8 + 0.4 * n2;
		col = mix(col, col * 0.72, smoothstep(0.55, 0.72, n1) * 0.55);
		col *= 0.92 + 0.16 * texture(noise_tex, uv * 2.3).r;
		rough = 0.8;
		bump = 1.3;
		bscale = 1.1;
	} else if (id == 2) {
		col *= 0.9 + 0.2 * n1;
		col *= 0.96 + 0.08 * n2;
		if (!top) {
			float flr = fract((wpos.y - 0.16) / 3.0);
			col *= 1.0 - 0.2 * (1.0 - smoothstep(0.0, 0.035, min(flr, 1.0 - flr))) * step(wpos.x, 500.0);
			float streak = texture(noise_tex, vec2(hcoord * 0.5, wpos.y * 0.03)).r;
			col *= mix(1.0, 0.86, smoothstep(0.55, 0.8, streak) * smoothstep(6.0, 0.5, wpos.y) * 0.8);
		}
		rough = 0.95;
	} else if (id == 3) {
		if (!top) {
			vec2 b = vec2(hcoord / 0.5, wpos.y / 0.22);
			float row = floor(b.y);
			b.x += mod(row, 2.0) * 0.5;
			vec2 f = fract(b);
			float mortar = 1.0 - step(0.06, f.x) * step(0.14, f.y);
			float v = hash21(vec2(floor(b.x), row));
			col *= 0.78 + 0.4 * v;
			col = mix(col, vec3(0.62, 0.6, 0.56), mortar * 0.75);
		}
		col *= 0.92 + 0.16 * n2;
		rough = 0.95;
	} else if (id == 4) {
		if (an.y > 0.2 && an.y < 0.97) {
			float h = an.z > an.x ? wpos.x : wpos.z;
			float r = wpos.y * 2.4;
			float row = fract(r);
			float cm = fract(h * 2.2 + mod(floor(r), 2.0) * 0.5);
			float v = hash21(vec2(floor(h * 2.2 + mod(floor(r), 2.0) * 0.5), floor(r)));
			col *= 0.62 + 0.42 * row;
			col *= 0.84 + 0.2 * smoothstep(0.0, 0.12, cm) * smoothstep(1.0, 0.88, cm);
			col *= 0.88 + 0.24 * v;
		}
		rough = 0.8;
	} else if (id == 5) {
		float g = texture(noise_tex, uv * vec2(0.09, 1.9)).r;
		col *= 0.78 + 0.44 * g;
		if (top) {
			float pl = fract(uv.y * 3.2);
			float pid = hash21(vec2(floor(uv.y * 3.2), floor(uv.x * 0.45 + hash21(vec2(floor(uv.y * 3.2), 3.0)))));
			col *= 0.88 + 0.24 * pid;
			col *= 1.0 - 0.3 * (1.0 - smoothstep(0.0, 0.035, pl));
		}
		rough = 0.55;
		spec = 0.6;
	} else if (id == 6) {
		if (top) {
			vec2 t = uv / 1.1;
			vec2 f = fract(t);
			float line = 1.0 - step(0.035, f.x) * step(0.035, f.y);
			col *= 0.9 + 0.2 * hash21(floor(t));
			col *= 1.0 - 0.3 * line;
		}
		col *= 0.9 + 0.2 * n2;
		rough = 0.82;
		bump = 0.7;
	} else if (id == 7) {
		float fl = texture(noise_tex, wpos.xz * 0.9 + wpos.y * 0.7).r;
		col *= 0.95 + 0.7 * fl;
		col = mix(col, col * vec3(1.25, 1.2, 0.7), clamp(wnrm.y, 0.0, 1.0) * 0.35);
		rough = 1.0;
		spec = 0.2;
	} else if (id == 8) {
		rough = 0.22;
		metal = 0.45;
		spec = 0.7;
	} else if (id == 9) {
		rough = 0.72;
		col *= 0.97 + 0.06 * n2;
	} else {
		col *= 0.94 + 0.12 * n1;
	}
	if (an.y < 0.5) {
		float base = wpos.x > 500.0 ? 0.1 : 0.16;
		col *= mix(0.68, 1.0, smoothstep(0.0, 1.3, wpos.y - base));
	}
	if (top && bump > 0.0) {
		float e = 0.07;
		float h0 = texture(noise_tex, uv * bscale).r;
		float hx = texture(noise_tex, (uv + vec2(e, 0.0)) * bscale).r;
		float hz = texture(noise_tex, (uv + vec2(0.0, e)) * bscale).r;
		vec3 nw = normalize(vec3((h0 - hx) * bump, 1.0, (h0 - hz) * bump));
		NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	}
	col = mix(vec3(dot(col, vec3(0.299, 0.587, 0.114))), col, 0.8);
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = spec;
	if (id == 9 || id == 7) {
		float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
		EMISSION = col * rim * 0.3;
	}
}
"""

const GLASS := """
shader_type spatial;
uniform float night = 0.0;
uniform vec3 sky_col : source_color = vec3(0.6, 0.75, 0.95);
varying float mid;
varying vec3 rnd;

void vertex() {
	mid = COLOR.a;
	rnd = COLOR.rgb;
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	if (mid > 0.75) {
		ALBEDO = vec3(0.85, 0.85, 0.8);
		ROUGHNESS = 0.35;
		EMISSION = vec3(1.0, 0.86, 0.6) * night * 2.8;
	} else {
		float lit = mid > 0.25 ? 1.0 : step(0.4, rnd.r);
		vec3 warm = mix(vec3(1.0, 0.76, 0.42), vec3(0.65, 0.82, 1.0), step(0.82, rnd.g));
		if (mid > 0.25) { warm = vec3(1.0, 0.93, 0.78); }
		float on = lit * night;
		ALBEDO = mix(mix(vec3(0.04, 0.07, 0.12), sky_col, 0.22 + 0.6 * fres), warm, on * 0.6);
		ROUGHNESS = 0.05;
		METALLIC = 0.55 * (1.0 - on);
		SPECULAR = 0.8;
		EMISSION = warm * on * (1.3 + rnd.g * 0.9);
	}
}
"""

const WATER := """
shader_type spatial;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 sky_col : source_color = vec3(0.6, 0.75, 0.95);
varying vec3 wpos;

float height(vec2 uv) {
	return texture(noise_tex, uv * 0.16 + vec2(TIME * 0.021, TIME * 0.013)).r + texture(noise_tex, uv * 0.43 - vec2(TIME * 0.03, 0.0)).r * 0.6;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wpos.xz;
	float e = 0.12;
	float h0 = height(uv);
	float hx = height(uv + vec2(e, 0.0));
	float hz = height(uv + vec2(0.0, e));
	vec3 nw = normalize(vec3((h0 - hx) * 1.5, 1.0, (h0 - hz) * 1.5));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = mix(vec3(0.03, 0.22, 0.32), sky_col, clamp(fres + 0.12, 0.0, 1.0));
	ROUGHNESS = 0.04;
	METALLIC = 0.25;
	SPECULAR = 0.9;
}
"""

const SKY := """
shader_type sky;
uniform vec3 top_col : source_color = vec3(0.2, 0.45, 0.9);
uniform vec3 hor_col : source_color = vec3(0.7, 0.82, 0.95);
uniform float night = 0.0;
uniform float cloud_t = 0.0;
uniform sampler2D noise_tex : repeat_enable, filter_linear;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

void sky() {
	vec3 d = EYEDIR;
	float y = clamp(d.y, 0.0, 1.0);
	vec3 col = mix(hor_col, top_col, pow(y, 0.55));
	if (d.y < 0.0) {
		col = mix(hor_col, hor_col * 0.55, clamp(-d.y * 3.0, 0.0, 1.0));
	}
	if (LIGHT0_ENABLED) {
		float sd = dot(d, LIGHT0_DIRECTION);
		col += LIGHT0_COLOR * smoothstep(0.9990, 0.9994, sd) * mix(3.0, 1.2, night);
		col += LIGHT0_COLOR * pow(max(sd, 0.0), 48.0) * 0.3 * (1.0 - night * 0.7);
	}
	if (night > 0.02 && d.y > 0.0) {
		float s = hash31(floor(d * 190.0));
		col += vec3(step(0.9965, s)) * night * (0.5 + 0.5 * hash31(floor(d * 190.0) + 7.0)) * smoothstep(0.0, 0.2, d.y);
	}
	if (d.y > 0.015) {
		vec2 cuv = d.xz / (d.y + 0.18) * 0.11 + vec2(cloud_t, cloud_t * 0.4);
		float c = texture(noise_tex, cuv).r * 0.65 + texture(noise_tex, cuv * 2.9 + 0.3).r * 0.35;
		float m = smoothstep(0.5, 0.72, c) * smoothstep(0.015, 0.22, d.y);
		float shade = smoothstep(0.5, 0.85, c);
		vec3 cc = mix(mix(vec3(1.0), hor_col, 0.45), vec3(0.82, 0.84, 0.9), shade * 0.5) * mix(1.0, 0.16, night);
		col = mix(col, cc, m * 0.9);
	}
	COLOR = col;
}
"""

const POOL := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform float night = 0.0;
void fragment() {
	float a = COLOR.r;
	ALBEDO = vec3(1.0, 0.8, 0.48) * a * a * night * 0.5;
}
"""

const VIGNETTE := """
shader_type canvas_item;
void fragment() {
	vec2 p = UV - 0.5;
	float v = smoothstep(0.42, 0.95, length(p * vec2(1.0, 0.85)) * 1.25);
	COLOR = vec4(0.02, 0.03, 0.06, v * 0.42);
}
"""


static func noise_texture() -> ImageTexture:
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.seed = 7
	fn.frequency = 0.022
	fn.fractal_type = FastNoiseLite.FRACTAL_FBM
	fn.fractal_octaves = 4
	var img := fn.get_seamless_image(256, 256)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func material(code: String, noise: Texture2D = null) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	if noise != null:
		m.set_shader_parameter("noise_tex", noise)
	return m
