extends RefCounted
# Modelos low-poly: cada modelo es una sola malla con color por vértice (1 draw call).

static var _mat: StandardMaterial3D
static var _cache: Dictionary = {}

const WOOD = Color(0.56, 0.39, 0.22)
const WOOD_D = Color(0.4, 0.27, 0.15)
const STONE = Color(0.58, 0.58, 0.56)
const STONE_D = Color(0.42, 0.42, 0.41)
const METAL = Color(0.46, 0.4, 0.37)
const METAL_D = Color(0.33, 0.24, 0.2)
const LEAF = Color(0.2, 0.42, 0.18)
const LEAF_L = Color(0.3, 0.52, 0.2)

var v = PackedVector3Array()
var n = PackedVector3Array()
var c = PackedColorArray()
var ix = PackedInt32Array()


static func vmat() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.vertex_color_is_srgb = true
		_mat.roughness = 0.92
	return _mat


func add(arr: Array, xf: Transform3D, col: Color) -> void:
	var base = v.size()
	var av: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var an: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var ai: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var nb = xf.basis.inverse().transposed()
	for i in av.size():
		v.append(xf * av[i])
		n.append((nb * an[i]).normalized())
		c.append(col)
	for i in ai.size():
		ix.append(base + ai[i])


func box(size: Vector3, pos: Vector3, col: Color, rot: Vector3 = Vector3.ZERO) -> void:
	var m = BoxMesh.new()
	add(m.get_mesh_arrays(), Transform3D(Basis.from_euler(rot) * Basis.from_scale(size), pos), col)


func cyl(rt: float, rb: float, h: float, pos: Vector3, col: Color, rot: Vector3 = Vector3.ZERO, segs: int = 7) -> void:
	var m = CylinderMesh.new()
	m.top_radius = rt
	m.bottom_radius = rb
	m.height = h
	m.radial_segments = segs
	m.rings = 1
	add(m.get_mesh_arrays(), Transform3D(Basis.from_euler(rot), pos), col)


func sph(r: float, pos: Vector3, col: Color, scl: Vector3 = Vector3.ONE, segs: int = 8) -> void:
	var m = SphereMesh.new()
	m.radius = 1.0
	m.height = 2.0
	m.radial_segments = segs
	m.rings = maxi(3, int(segs / 2.0))
	add(m.get_mesh_arrays(), Transform3D(Basis.from_scale(scl * r), pos), col)


func build() -> ArrayMesh:
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_COLOR] = c
	arr[Mesh.ARRAY_INDEX] = ix
	var am = ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	am.surface_set_material(0, vmat())
	return am


static func tier_col(t: int) -> Color:
	return [WOOD, STONE, METAL][t]


static func tier_dark(t: int) -> Color:
	return [WOOD_D, STONE_D, METAL_D][t]


static func model(name: String) -> ArrayMesh:
	if _cache.has(name):
		return _cache[name]
	var b = new()
	var parts = name.split("_")
	var tier = 0
	if parts.size() > 1 and parts[parts.size() - 1].is_valid_int():
		tier = int(parts[parts.size() - 1])
	var tc = tier_col(tier)
	var td = tier_dark(tier)
	var base = parts[0]
	match base:
		"pine":
			b.cyl(0.16, 0.26, 2.6, Vector3(0, 1.3, 0), WOOD_D)
			b.cyl(0.0, 1.55, 2.3, Vector3(0, 3.0, 0), LEAF)
			b.cyl(0.0, 1.2, 2.0, Vector3(0, 4.1, 0), LEAF_L)
			b.cyl(0.0, 0.85, 1.7, Vector3(0, 5.1, 0), LEAF)
		"oak":
			b.cyl(0.22, 0.34, 2.6, Vector3(0, 1.3, 0), Color(0.36, 0.26, 0.17))
			b.sph(1.7, Vector3(0, 3.6, 0), LEAF_L, Vector3(1, 0.85, 1), 7)
			b.sph(1.2, Vector3(1.1, 3.1, 0.3), LEAF, Vector3.ONE, 7)
			b.sph(1.15, Vector3(-0.9, 3.2, -0.5), Color(0.26, 0.48, 0.2), Vector3.ONE, 7)
			b.sph(1.0, Vector3(0.1, 4.6, 0.2), LEAF, Vector3.ONE, 7)
		"palm":
			var tr = Color(0.52, 0.42, 0.28)
			b.cyl(0.14, 0.2, 1.8, Vector3(0, 0.9, 0), tr, Vector3(0, 0, -0.08))
			b.cyl(0.12, 0.14, 1.8, Vector3(0.2, 2.6, 0), tr, Vector3(0, 0, -0.16))
			b.cyl(0.1, 0.12, 1.6, Vector3(0.52, 4.2, 0), tr, Vector3(0, 0, -0.24))
			for i in 7:
				var a = i * TAU / 7.0
				var d = Vector3(cos(a), 0, sin(a))
				b.box(Vector3(2.4, 0.05, 0.5), Vector3(0.72, 4.75, 0) + d * 1.05, Color(0.25, 0.5, 0.2) if i % 2 == 0 else LEAF_L, Vector3(0, -a, -0.45))
			b.sph(0.14, Vector3(0.7, 4.8, 0.15), Color(0.35, 0.25, 0.12))
		"stone":
			b.sph(1.0, Vector3(0, 0.45, 0), STONE, Vector3(1.25, 0.8, 1.0), 6)
			b.sph(0.7, Vector3(0.85, 0.3, 0.35), STONE_D, Vector3(1, 0.7, 1), 6)
			b.sph(0.6, Vector3(-0.7, 0.28, -0.5), Color(0.52, 0.52, 0.5), Vector3(1, 0.75, 1.1), 6)
		"iron":
			var dk = Color(0.36, 0.33, 0.32)
			b.sph(1.0, Vector3(0, 0.45, 0), dk, Vector3(1.15, 0.85, 1.0), 6)
			b.sph(0.65, Vector3(0.75, 0.3, -0.3), Color(0.3, 0.28, 0.27), Vector3(1, 0.75, 1), 6)
			var sp = Color(0.78, 0.42, 0.2)
			var pts = [Vector3(0.3, 1.0, 0.3), Vector3(-0.6, 0.8, 0.1), Vector3(0.1, 0.75, -0.75), Vector3(0.95, 0.6, 0.2), Vector3(-0.3, 0.7, 0.7), Vector3(0.9, 0.55, -0.6)]
			for p in pts:
				b.sph(0.2, p, sp, Vector3(1, 0.7, 1), 5)
		"bush":
			b.sph(0.6, Vector3(0, 0.42, 0), LEAF_L, Vector3(1, 0.75, 1), 7)
			b.sph(0.45, Vector3(0.45, 0.32, 0.2), LEAF, Vector3(1, 0.8, 1), 6)
			var red = Color(0.85, 0.1, 0.25)
			for i in 9:
				var a = i * 2.4
				b.sph(0.07, Vector3(cos(a) * 0.5, 0.45 + 0.25 * sin(i * 1.7), sin(a) * 0.5), red, Vector3.ONE, 4)
		"hemp":
			for i in 6:
				var a = i * TAU / 6.0
				var p = Vector3(cos(a) * 0.22, 0, sin(a) * 0.22)
				var hh = 1.0 + 0.25 * sin(i * 2.1)
				b.cyl(0.02, 0.03, hh, p + Vector3(0, hh * 0.5, 0), Color(0.4, 0.55, 0.25), Vector3.ZERO, 4)
				b.cyl(0.0, 0.13, 0.4, p + Vector3(0, hh, 0), Color(0.36, 0.56, 0.26), Vector3.ZERO, 5)
		"mushroom":
			var cap = Color(0.75, 0.3, 0.2)
			var pts2 = [Vector3(0, 0, 0), Vector3(0.22, 0, 0.1), Vector3(-0.1, 0, 0.22)]
			for p in pts2:
				b.cyl(0.04, 0.05, 0.22, p + Vector3(0, 0.11, 0), Color(0.92, 0.88, 0.8), Vector3.ZERO, 5)
				b.sph(0.15, p + Vector3(0, 0.25, 0), cap, Vector3(1, 0.55, 1), 6)
		"pebble":
			b.sph(0.22, Vector3(0, 0.1, 0), STONE, Vector3(1, 0.6, 0.8), 5)
			b.sph(0.16, Vector3(0.25, 0.07, 0.1), STONE_D, Vector3(1, 0.6, 1), 5)
		"stick":
			b.cyl(0.035, 0.045, 0.95, Vector3(0, 0.05, 0), WOOD_D, Vector3(0, 0.3, PI / 2), 5)
			b.cyl(0.03, 0.04, 0.8, Vector3(0.1, 0.09, 0.05), WOOD, Vector3(0, -0.9, PI / 2), 5)
		"barrel":
			var ru = Color(0.5, 0.3, 0.2)
			b.cyl(0.42, 0.42, 1.05, Vector3(0, 0.525, 0), ru, Vector3.ZERO, 9)
			b.cyl(0.45, 0.45, 0.07, Vector3(0, 0.2, 0), METAL_D, Vector3.ZERO, 9)
			b.cyl(0.45, 0.45, 0.07, Vector3(0, 0.85, 0), METAL_D, Vector3.ZERO, 9)
			b.cyl(0.36, 0.36, 0.02, Vector3(0, 1.055, 0), Color(0.3, 0.22, 0.18), Vector3.ZERO, 9)
		"crate":
			b.box(Vector3(1.2, 0.75, 0.8), Vector3(0, 0.375, 0), Color(0.35, 0.42, 0.3))
			b.box(Vector3(1.24, 0.1, 0.84), Vector3(0, 0.78, 0), Color(0.27, 0.33, 0.23))
			b.box(Vector3(0.12, 0.8, 0.84), Vector3(-0.4, 0.4, 0), METAL_D)
			b.box(Vector3(0.12, 0.8, 0.84), Vector3(0.4, 0.4, 0), METAL_D)
			b.box(Vector3(0.14, 0.14, 0.05), Vector3(0, 0.6, 0.42), Color(0.85, 0.7, 0.2))
		"ruin":
			b.box(Vector3(4.0, 1.6, 0.5), Vector3(0, 0.8, 0), STONE_D)
			b.box(Vector3(1.4, 1.0, 0.5), Vector3(-1.3, 2.1, 0), STONE)
			b.box(Vector3(0.8, 0.5, 0.5), Vector3(0.2, 1.85, 0), STONE)
			b.box(Vector3(0.7, 0.4, 0.6), Vector3(1.9, 0.2, 0.7), STONE, Vector3(0, 0.5, 0.2))
		"ciervo":
			var tn = Color(0.62, 0.45, 0.28)
			b.sph(1.0, Vector3(0, 1.0, 0), tn, Vector3(0.33, 0.36, 0.75), 8)
			b.cyl(0.11, 0.15, 0.6, Vector3(0, 1.38, 0.62), tn, Vector3(0.6, 0, 0), 6)
			b.sph(0.19, Vector3(0, 1.66, 0.86), tn, Vector3(0.8, 0.85, 1.3), 6)
			b.sph(0.06, Vector3(0, 1.62, 1.1), Color(0.15, 0.1, 0.08), Vector3.ONE, 4)
			b.sph(0.1, Vector3(0, 1.1, -0.75), Color(0.95, 0.93, 0.88), Vector3.ONE, 5)
			for s in [-1.0, 1.0]:
				b.cyl(0.015, 0.025, 0.5, Vector3(s * 0.14, 2.0, 0.8), Color(0.85, 0.8, 0.7), Vector3(0, 0, -s * 0.4), 4)
				b.cyl(0.012, 0.02, 0.25, Vector3(s * 0.26, 2.1, 0.86), Color(0.85, 0.8, 0.7), Vector3(0.5, 0, -s * 0.9), 4)
		"jabali":
			var bc = Color(0.3, 0.22, 0.17)
			b.sph(1.0, Vector3(0, 0.62, 0), bc, Vector3(0.42, 0.42, 0.72), 8)
			b.sph(0.3, Vector3(0, 0.6, 0.72), Color(0.26, 0.19, 0.15), Vector3(0.9, 0.9, 1.25), 6)
			b.cyl(0.09, 0.11, 0.16, Vector3(0, 0.55, 1.08), Color(0.5, 0.35, 0.32), Vector3(PI / 2, 0, 0), 6)
			b.box(Vector3(0.08, 0.22, 0.9), Vector3(0, 1.02, -0.05), Color(0.18, 0.13, 0.1))
			for s in [-1.0, 1.0]:
				b.cyl(0.0, 0.03, 0.16, Vector3(s * 0.14, 0.6, 1.0), Color(0.95, 0.93, 0.85), Vector3(-0.4, 0, s * 0.5), 4)
				b.cyl(0.0, 0.07, 0.14, Vector3(s * 0.17, 0.92, 0.6), bc, Vector3.ZERO, 4)
		"lobo":
			var gr = Color(0.48, 0.48, 0.5)
			b.sph(1.0, Vector3(0, 0.72, 0), gr, Vector3(0.27, 0.3, 0.7), 8)
			b.sph(0.21, Vector3(0, 0.92, 0.72), gr, Vector3(0.9, 0.9, 1.1), 6)
			b.box(Vector3(0.14, 0.12, 0.28), Vector3(0, 0.86, 0.98), Color(0.38, 0.38, 0.4))
			b.sph(0.04, Vector3(0, 0.89, 1.13), Color(0.08, 0.08, 0.08), Vector3.ONE, 4)
			b.cyl(0.04, 0.08, 0.6, Vector3(0, 0.7, -0.9), Color(0.4, 0.4, 0.42), Vector3(-1.0, 0, 0), 5)
			for s in [-1.0, 1.0]:
				b.cyl(0.0, 0.06, 0.16, Vector3(s * 0.11, 1.14, 0.68), Color(0.35, 0.35, 0.37), Vector3.ZERO, 4)
		"oso":
			var br = Color(0.3, 0.2, 0.13)
			b.sph(1.0, Vector3(0, 1.0, 0), br, Vector3(0.6, 0.62, 1.0), 8)
			b.sph(0.52, Vector3(0, 1.3, -0.1), Color(0.27, 0.18, 0.12), Vector3(1, 0.9, 1.2), 7)
			b.sph(0.36, Vector3(0, 1.2, 1.02), br, Vector3(1, 0.95, 1.1), 7)
			b.box(Vector3(0.2, 0.17, 0.28), Vector3(0, 1.12, 1.36), Color(0.45, 0.33, 0.24))
			b.sph(0.05, Vector3(0, 1.16, 1.5), Color(0.06, 0.06, 0.06), Vector3.ONE, 4)
			for s in [-1.0, 1.0]:
				b.sph(0.1, Vector3(s * 0.25, 1.52, 0.95), br, Vector3.ONE, 5)
		"saqueador":
			var cl = Color(0.34, 0.3, 0.24)
			b.box(Vector3(0.52, 0.66, 0.28), Vector3(0, 1.22, 0), cl)
			b.box(Vector3(0.46, 0.2, 0.26), Vector3(0, 0.85, 0), Color(0.22, 0.2, 0.18))
			b.sph(0.2, Vector3(0, 1.74, 0), Color(0.78, 0.6, 0.48), Vector3(0.95, 1.05, 1), 7)
			b.box(Vector3(0.36, 0.14, 0.2), Vector3(0, 1.69, 0.1), Color(0.5, 0.12, 0.1))
			b.sph(0.215, Vector3(0, 1.8, -0.02), Color(0.25, 0.22, 0.2), Vector3(1, 0.8, 1), 7)
			b.box(Vector3(0.56, 0.1, 0.3), Vector3(0, 1.5, 0), METAL_D)
		"leg":
			# pata genérica: pivote arriba. parts[1] = kind
			var kind = parts[1]
			var col = {"ciervo": Color(0.55, 0.4, 0.25), "jabali": Color(0.24, 0.18, 0.14), "lobo": Color(0.42, 0.42, 0.44), "oso": Color(0.26, 0.17, 0.11), "saqueador": Color(0.22, 0.2, 0.18)}[kind]
			var ln = {"ciervo": 0.78, "jabali": 0.42, "lobo": 0.55, "oso": 0.62, "saqueador": 0.88}[kind]
			var rd = {"ciervo": 0.055, "jabali": 0.08, "lobo": 0.06, "oso": 0.16, "saqueador": 0.1}[kind]
			b.cyl(rd, rd * 0.8, ln, Vector3(0, -ln * 0.5, 0), col, Vector3.ZERO, 6)
			if kind == "saqueador":
				b.box(Vector3(0.16, 0.1, 0.28), Vector3(0, -ln + 0.05, 0.06), Color(0.12, 0.1, 0.09))
		"arm":
			b.cyl(0.08, 0.07, 0.62, Vector3(0, -0.31, 0), Color(0.34, 0.3, 0.24), Vector3.ZERO, 6)
			b.sph(0.08, Vector3(0, -0.64, 0), Color(0.78, 0.6, 0.48), Vector3.ONE, 5)
			if parts.size() > 1 and parts[1] == "club":
				b.cyl(0.07, 0.035, 0.8, Vector3(0, -0.64, 0.32), WOOD_D, Vector3(PI / 2, 0, 0), 6)
				b.box(Vector3(0.04, 0.2, 0.04), Vector3(0, -0.64, 0.62), STONE)
		"foundation":
			b.box(Vector3(3, 2.4, 3), Vector3(0, -1.2, 0), tc)
			for i in 3:
				b.box(Vector3(2.96, 0.02, 0.05), Vector3(0, 0.003, -1.0 + i * 1.0), td)
			b.box(Vector3(3.02, 0.14, 3.02), Vector3(0, -0.3, 0), td)
		"wall":
			b.box(Vector3(3, 3, 0.2), Vector3(0, 1.5, 0), tc)
			b.box(Vector3(0.22, 3, 0.26), Vector3(-1.39, 1.5, 0), td)
			b.box(Vector3(0.22, 3, 0.26), Vector3(1.39, 1.5, 0), td)
			b.box(Vector3(3, 0.2, 0.26), Vector3(0, 2.9, 0), td)
			b.box(Vector3(3, 0.16, 0.24), Vector3(0, 1.5, 0), td)
		"doorway":
			b.box(Vector3(0.9, 3, 0.2), Vector3(-1.05, 1.5, 0), tc)
			b.box(Vector3(0.9, 3, 0.2), Vector3(1.05, 1.5, 0), tc)
			b.box(Vector3(1.2, 0.8, 0.2), Vector3(0, 2.6, 0), tc)
			b.box(Vector3(0.12, 2.2, 0.26), Vector3(-0.66, 1.1, 0), td)
			b.box(Vector3(0.12, 2.2, 0.26), Vector3(0.66, 1.1, 0), td)
			b.box(Vector3(1.44, 0.12, 0.26), Vector3(0, 2.26, 0), td)
		"window":
			b.box(Vector3(3, 1.0, 0.2), Vector3(0, 0.5, 0), tc)
			b.box(Vector3(3, 0.8, 0.2), Vector3(0, 2.6, 0), tc)
			b.box(Vector3(0.9, 1.2, 0.2), Vector3(-1.05, 1.6, 0), tc)
			b.box(Vector3(0.9, 1.2, 0.2), Vector3(1.05, 1.6, 0), tc)
			b.box(Vector3(1.3, 0.1, 0.26), Vector3(0, 1.02, 0), td)
		"floor":
			b.box(Vector3(3, 0.2, 3), Vector3(0, -0.1, 0), tc)
			for i in 3:
				b.box(Vector3(2.96, 0.02, 0.05), Vector3(0, 0.003, -1.0 + i * 1.0), td)
		"stairs":
			for i in 8:
				b.box(Vector3(2.7, 0.14, 0.375), Vector3(0, (i + 1) * 0.375 - 0.07, -1.5 + (i + 0.5) * 0.375), tc)
			for s in [-1.0, 1.0]:
				b.box(Vector3(0.12, 0.3, 4.24), Vector3(s * 1.38, 1.38, 0), td, Vector3(-PI / 4, 0, 0))
		"door":
			b.box(Vector3(1.16, 2.16, 0.08), Vector3(0.58, 1.08, 0), tc.lightened(0.12))
			b.box(Vector3(1.16, 0.12, 0.1), Vector3(0.58, 0.5, 0), td)
			b.box(Vector3(1.16, 0.12, 0.1), Vector3(0.58, 1.7, 0), td)
			b.box(Vector3(0.08, 0.16, 0.16), Vector3(1.02, 1.1, 0), Color(0.8, 0.7, 0.3))
		"hoguera":
			for i in 8:
				var a = i * TAU / 8.0
				b.sph(0.14, Vector3(cos(a) * 0.48, 0.08, sin(a) * 0.48), STONE_D if i % 2 == 0 else STONE, Vector3(1, 0.7, 1), 5)
			b.cyl(0.06, 0.07, 0.8, Vector3(0, 0.16, 0), WOOD_D, Vector3(0, 0.4, 1.2), 5)
			b.cyl(0.06, 0.07, 0.8, Vector3(0, 0.16, 0), WOOD, Vector3(0, 2.0, 1.2), 5)
			b.cyl(0.06, 0.07, 0.8, Vector3(0, 0.16, 0), Color(0.2, 0.15, 0.12), Vector3(0, 3.6, 1.2), 5)
		"flame":
			b.cyl(0.0, 0.22, 0.6, Vector3(0, 0.45, 0), Color(1.0, 0.55, 0.1), Vector3.ZERO, 6)
			b.cyl(0.0, 0.13, 0.4, Vector3(0.08, 0.4, 0.05), Color(1.0, 0.85, 0.3), Vector3.ZERO, 5)
		"horno":
			b.cyl(0.5, 0.68, 1.3, Vector3(0, 0.65, 0), STONE_D, Vector3.ZERO, 8)
			b.cyl(0.2, 0.3, 0.6, Vector3(0, 1.6, 0), Color(0.36, 0.36, 0.35), Vector3.ZERO, 7)
			b.box(Vector3(0.42, 0.36, 0.2), Vector3(0, 0.4, 0.58), Color(0.1, 0.08, 0.07))
			b.box(Vector3(0.3, 0.14, 0.22), Vector3(0, 0.34, 0.585), Color(1.0, 0.5, 0.1))
		"cofre":
			b.box(Vector3(1.0, 0.56, 0.6), Vector3(0, 0.28, 0), WOOD)
			b.box(Vector3(1.04, 0.14, 0.64), Vector3(0, 0.62, 0), WOOD_D)
			b.box(Vector3(0.1, 0.72, 0.66), Vector3(-0.36, 0.34, 0), METAL_D)
			b.box(Vector3(0.1, 0.72, 0.66), Vector3(0.36, 0.34, 0), METAL_D)
			b.box(Vector3(0.12, 0.14, 0.05), Vector3(0, 0.5, 0.32), Color(0.85, 0.72, 0.25))
		"saco":
			b.box(Vector3(0.8, 0.14, 1.9), Vector3(0, 0.07, 0), Color(0.28, 0.45, 0.3))
			b.box(Vector3(0.82, 0.05, 0.3), Vector3(0, 0.15, 0.2), Color(0.2, 0.33, 0.22))
			b.box(Vector3(0.6, 0.12, 0.34), Vector3(0, 0.18, -0.72), Color(0.85, 0.82, 0.72))
		"banco":
			b.box(Vector3(1.7, 0.1, 0.85), Vector3(0, 0.9, 0), WOOD)
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					b.box(Vector3(0.1, 0.85, 0.1), Vector3(sx * 0.75, 0.425, sz * 0.33), WOOD_D)
			b.box(Vector3(1.5, 0.06, 0.6), Vector3(0, 0.3, 0), WOOD_D)
			b.box(Vector3(0.3, 0.16, 0.2), Vector3(-0.5, 1.03, 0.1), STONE_D)
			b.box(Vector3(0.5, 0.04, 0.08), Vector3(0.35, 0.97, -0.1), Color(0.75, 0.75, 0.8), Vector3(0, 0.5, 0))
		"mochila":
			b.sph(0.36, Vector3(0, 0.26, 0), Color(0.45, 0.33, 0.2), Vector3(1, 0.75, 0.9), 7)
			b.box(Vector3(0.3, 0.06, 0.5), Vector3(0, 0.5, 0), Color(0.3, 0.2, 0.12))
		"vm":
			_viewmodel(b, name.substr(3))
	var m = b.build()
	_cache[name] = m
	return m


static func _viewmodel(b, kind: String) -> void:
	var hd = Vector3(0, 0.25, 0)
	match kind:
		"roca":
			b.sph(0.075, Vector3(0, 0.14, 0), STONE_D, Vector3(1, 0.8, 1.25), 6)
		"hacha_piedra", "hacha_hierro":
			var hc = STONE_D if kind == "hacha_piedra" else Color(0.75, 0.77, 0.82)
			b.cyl(0.018, 0.022, 0.55, hd, WOOD, Vector3.ZERO, 5)
			b.box(Vector3(0.035, 0.12, 0.17), Vector3(0, 0.46, -0.08), hc)
			b.box(Vector3(0.02, 0.15, 0.04), Vector3(0, 0.46, -0.17), hc.lightened(0.2))
		"pico_piedra", "pico_hierro":
			var pc = STONE_D if kind == "pico_piedra" else Color(0.75, 0.77, 0.82)
			b.cyl(0.018, 0.022, 0.55, hd, WOOD, Vector3.ZERO, 5)
			b.box(Vector3(0.035, 0.045, 0.4), Vector3(0, 0.5, 0), pc)
			b.cyl(0.0, 0.025, 0.1, Vector3(0, 0.5, -0.24), pc, Vector3(-PI / 2, 0, 0), 4)
			b.cyl(0.0, 0.025, 0.1, Vector3(0, 0.5, 0.24), pc, Vector3(PI / 2, 0, 0), 4)
		"lanza":
			b.cyl(0.016, 0.016, 1.5, Vector3(0, 0.1, -0.35), WOOD, Vector3(PI / 2, 0, 0), 5)
			b.cyl(0.0, 0.035, 0.2, Vector3(0, 0.1, -1.2), STONE, Vector3(-PI / 2, 0, 0), 4)
		"machete":
			b.cyl(0.02, 0.022, 0.16, Vector3(0, 0.08, 0), WOOD_D, Vector3.ZERO, 5)
			b.box(Vector3(0.012, 0.5, 0.06), Vector3(0, 0.42, -0.01), Color(0.8, 0.82, 0.86))
			b.box(Vector3(0.03, 0.02, 0.1), Vector3(0, 0.17, 0), METAL_D)
		"arco":
			b.box(Vector3(0.025, 0.36, 0.03), Vector3(0, 0.1, -0.3), WOOD_D)
			b.box(Vector3(0.022, 0.34, 0.028), Vector3(0, 0.42, -0.24), WOOD, Vector3(0.4, 0, 0))
			b.box(Vector3(0.022, 0.34, 0.028), Vector3(0, -0.22, -0.24), WOOD, Vector3(-0.4, 0, 0))
			b.box(Vector3(0.005, 0.95, 0.005), Vector3(0, 0.1, -0.17), Color(0.9, 0.9, 0.85))
		"escopeta":
			b.cyl(0.022, 0.022, 0.62, Vector3(0, 0.12, -0.45), Color(0.2, 0.2, 0.22), Vector3(PI / 2, 0, 0), 6)
			b.cyl(0.022, 0.022, 0.62, Vector3(0.045, 0.12, -0.45), Color(0.2, 0.2, 0.22), Vector3(PI / 2, 0, 0), 6)
			b.box(Vector3(0.09, 0.07, 0.3), Vector3(0.022, 0.1, -0.08), METAL_D)
			b.box(Vector3(0.06, 0.1, 0.3), Vector3(0.022, 0.05, 0.14), WOOD_D, Vector3(-0.25, 0, 0))
		"martillo":
			b.cyl(0.018, 0.022, 0.5, hd, WOOD, Vector3.ZERO, 5)
			b.box(Vector3(0.07, 0.07, 0.17), Vector3(0, 0.47, 0), STONE_D)
		"antorcha":
			b.cyl(0.022, 0.02, 0.5, hd, WOOD_D, Vector3.ZERO, 5)
			b.sph(0.055, Vector3(0, 0.52, 0), Color(0.25, 0.2, 0.15), Vector3.ONE, 5)
			b.cyl(0.0, 0.06, 0.2, Vector3(0, 0.64, 0), Color(1.0, 0.6, 0.12), Vector3.ZERO, 5)
		_:
			b.box(Vector3(0.1, 0.09, 0.1), Vector3(0, 0.16, 0), Color(0.6, 0.5, 0.36))
