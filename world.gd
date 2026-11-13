extends RefCounted
# Genera toda la ciudad y los interiores por código (sin archivos de modelos).

const MB = preload("res://mb.gd")
const Shaders = preload("res://shaders.gd")

const N := 5
const BLOCK := 44.0
const P := 58.0
const X0 := -138.0
const FY := 0.1
# Filas = norte a sur. R casas, A pisos, S súper, C café, F muebles, G gimnasio, P plaza, K parque, H tu casa
# E gasolinera y taller, B banco
const LAYOUT := ["RRARR", "ESCRA", "AFPGR", "RBKRR", "RHRAR"]
const SURNAMES := ["García", "Martínez", "López", "Sánchez", "Romero", "Navarro", "Torres", "Ruiz", "Molina", "Ortega", "Castro", "Vega", "Serrano", "Iglesias", "Cano", "Prieto", "Fuentes", "Blanco"]
const BUILDINGS := ["Alba", "Lucero", "Girasol", "Brisa", "Aurora", "Olivo", "Jazmín", "Coral", "Mirador", "Azahar"]

const C_SIDEWALK := Color(0.63, 0.62, 0.6)
const C_ASPHALT := Color(0.21, 0.21, 0.23)
const C_GRASS := Color(0.36, 0.6, 0.28)
const C_WOOD := Color(0.55, 0.38, 0.22)
const C_BROWN := Color(0.4, 0.28, 0.18)
const C_STONE := Color(0.7, 0.68, 0.64)
const C_DARK := Color(0.16, 0.17, 0.19)
const C_WHITE := Color(0.96, 0.96, 0.94)
const C_HEDGE := Color(0.2, 0.45, 0.22)
const WALLS := [Color(0.95, 0.9, 0.78), Color(0.75, 0.85, 0.92), Color(0.95, 0.8, 0.78), Color(0.8, 0.92, 0.82), Color(0.95, 0.95, 0.93), Color(0.92, 0.72, 0.55), Color(0.85, 0.8, 0.9)]
const ROOFS := [Color(0.7, 0.3, 0.25), Color(0.3, 0.32, 0.36), Color(0.5, 0.33, 0.22), Color(0.3, 0.4, 0.55), Color(0.6, 0.25, 0.2)]
const FLOWERS := [Color(0.95, 0.3, 0.35), Color(0.98, 0.8, 0.2), Color(0.9, 0.5, 0.85), Color(1, 1, 1), Color(0.95, 0.55, 0.2)]

var root: Node3D
var mat_solid: ShaderMaterial
var mat_glow: ShaderMaterial
var mat_water: ShaderMaterial
var noise: ImageTexture
var colliders: Array[Rect2] = []
var buildings: Array = []
var lamps: Array = []
var taller_pos := Vector3.ZERO
var mat_pool: ShaderMaterial
var doors: Array = []
var spots: Array = []
var rooms: Dictionary = {}
var statics: Array = []
var home_items: Dictionary = {}
var spawn := Vector3.ZERO
var rng := RandomNumberGenerator.new()
var _water


static func block_center(i: int, j: int) -> Vector3:
	return Vector3(X0 + i * P + 22.0, 0, X0 + j * P + 22.0)


static func road_pos(k: int) -> float:
	return X0 - 7.0 + k * P


static func ground_y(x: float, z: float) -> float:
	if x > 500.0:
		return FY
	var u := x - X0 + 3.0
	var w := z - X0 + 3.0
	var iu := floorf(u / P)
	var iw := floorf(w / P)
	if iu < 0 or iu >= N or iw < 0 or iw >= N:
		return 0.0
	if u - iu * P <= 50.0 and w - iw * P <= 50.0:
		return 0.16
	return 0.0


static func block_at(x: float, z: float) -> String:
	var u := x - X0 + 7.0
	var w := z - X0 + 7.0
	var iu := int(floorf(u / P))
	var iw := int(floorf(w / P))
	if iu < 0 or iu >= N or iw < 0 or iw >= N:
		return ""
	return LAYOUT[iw][iu]


func add_col(cx: float, cz: float, sx: float, sz: float) -> void:
	colliders.append(Rect2(cx - sx * 0.5, cz - sz * 0.5, sx, sz))


func build(parent: Node) -> void:
	root = Node3D.new()
	parent.add_child(root)
	rng.seed = 20261112
	noise = Shaders.noise_texture()
	mat_solid = Shaders.material(Shaders.WORLD, noise)
	mat_glow = Shaders.material(Shaders.GLASS)
	mat_water = Shaders.material(Shaders.WATER, noise)
	mat_pool = Shaders.material(Shaders.POOL)
	_water = MB.new()
	_ground()
	for j in N:
		for i in N:
			_block(i, j)
	_scenery()
	_water.instance(root, mat_water, false)
	_light_pools()
	_interiors()


func _label(text: String, pos: Vector3, pix: float, col: Color, billboard: bool = false, rot: float = 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = pix
	l.modulate = col
	l.outline_size = 14
	l.outline_modulate = Color(0, 0, 0, 0.85)
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	l.rotation.y = rot
	root.add_child(l)
	return l


# ---------------------------------------------------------------- suelo y calles

func _ground() -> void:
	var g = MB.new()
	g.m = 0.0
	g.flat(Vector3(0, -0.12, 0), 1600, 1600, Color(0.33, 0.55, 0.26))
	g.m = 0.1
	g.flat(Vector3(0, 0, 0), 298, 298, C_ASPHALT)
	g.m = 0.6
	for s in [-1.0, 1.0]:
		g.box(Vector3(s * 150.5, 0, 0), Vector3(3, 0.15, 304), C_SIDEWALK)
		g.box(Vector3(0, 0, s * 150.5), Vector3(304, 0.15, 3), C_SIDEWALK)
	g.m = 1.0
	var white := Color(0.92, 0.92, 0.9)
	for k in N + 1:
		var r := road_pos(k)
		for s in N:
			var cc := X0 + s * P + 22.0
			for o in [-16.0, -8.0, 0.0, 8.0, 16.0]:
				g.flat(Vector3(r, 0.04, cc + o), 0.25, 4.0, white)
				g.flat(Vector3(cc + o, 0.04, r), 4.0, 0.25, white)
			for e in [-23.5, 23.5]:
				for a in [-3.2, -1.6, 0.0, 1.6, 3.2]:
					g.flat(Vector3(r + a, 0.04, cc + e), 0.9, 2.4, white)
					g.flat(Vector3(cc + e, 0.04, r + a), 2.4, 0.9, white)
	g.instance(root, mat_solid, false)


func _tree(mb, p: Vector3, sc: float, kind: int, collide: bool = true) -> void:
	var g1 := Color(0.2 + rng.randf() * 0.12, 0.5 + rng.randf() * 0.15, 0.2 + rng.randf() * 0.08)
	var g2 := g1.lightened(0.12)
	if kind == 1:
		mb.m = 0.5
		mb.cyl(p, 0.18 * sc, 0.14 * sc, 1.2 * sc, C_BROWN, 8, false)
		mb.m = 0.7
		var dg := g1.darkened(0.25)
		mb.cyl(p + Vector3(0, 1.0, 0) * sc, 1.5 * sc, 0.0, 2.2 * sc, dg, 8, false)
		mb.cyl(p + Vector3(0, 2.3, 0) * sc, 1.15 * sc, 0.0, 1.9 * sc, dg.lightened(0.06), 8, false)
		mb.cyl(p + Vector3(0, 3.5, 0) * sc, 0.8 * sc, 0.0, 1.6 * sc, dg.lightened(0.12), 8, false)
	elif kind == 2:
		mb.m = 0.5
		mb.cyl(p, 0.16 * sc, 0.12 * sc, 1.6 * sc, C_BROWN, 8, false)
		mb.m = 0.7
		mb.sphere(p + Vector3(0, 4.0, 0) * sc, Vector3(1.0, 2.8, 1.0) * sc, g1, 10, 7, 0.2)
	else:
		mb.m = 0.5
		mb.cyl(p, 0.18 * sc, 0.12 * sc, 2.3 * sc, C_BROWN, 8, false)
		mb.m = 0.7
		mb.sphere(p + Vector3(0, 3.4, 0) * sc, Vector3(1.6, 1.4, 1.6) * sc, g1, 10, 7, 0.2)
		mb.sphere(p + Vector3(0.75, 2.8, 0.35) * sc, Vector3(1.05, 0.95, 1.05) * sc, g2, 10, 7, 0.2)
		mb.sphere(p + Vector3(-0.65, 2.9, -0.45) * sc, Vector3(1.1, 1.0, 1.1) * sc, g1.darkened(0.08), 10, 7, 0.2)
	mb.m = 1.0
	if collide:
		add_col(p.x, p.z, 0.5, 0.5)


func _lamp(s, g, p: Vector3) -> void:
	lamps.append(p)
	s.cyl(p, 0.1, 0.06, 4.2, C_DARK, 6, false)
	s.box(p + Vector3(0, 4.25, 0), Vector3(0.55, 0.08, 0.55), C_DARK, true)
	g.sphere(p + Vector3(0, 4.08, 0), Vector3(0.24, 0.22, 0.24), Color.WHITE, 6, 4)


func _bench(s, p: Vector3, rot: float) -> void:
	s.push(p, rot)
	s.m = 0.5
	s.box(Vector3(0, 0.4, 0), Vector3(1.7, 0.07, 0.5), C_WOOD, true)
	s.box(Vector3(0, 0.55, -0.24), Vector3(1.7, 0.45, 0.06), C_WOOD)
	s.m = 1.0
	for sx in [-0.7, 0.7]:
		s.box(Vector3(sx, 0, 0), Vector3(0.08, 0.4, 0.45), C_DARK)
	s.pop()
	if absf(sin(rot)) > 0.5:
		add_col(p.x, p.z, 0.6, 1.7)
	else:
		add_col(p.x, p.z, 1.7, 0.6)


func _flowers(s, p: Vector3, count: int, spread: float) -> void:
	for k in count:
		var q := p + Vector3(rng.randf_range(-spread, spread), 0.12, rng.randf_range(-spread, spread))
		s.sphere(q, Vector3(0.16, 0.14, 0.16), FLOWERS[rng.randi() % FLOWERS.size()], 5, 3)


func _win(s, g, p: Vector3, w: float, h: float, along_x: bool, sgn: float) -> void:
	var wc := Color(rng.randf(), rng.randf(), 0.0)
	g.m = 0.0
	if along_x:
		s.box(Vector3(p.x, p.y - 0.08, p.z + sgn * 0.02), Vector3(w + 0.18, h + 0.16, 0.06), C_WHITE)
		g.box(Vector3(p.x, p.y, p.z + sgn * 0.04), Vector3(w, h, 0.07), wc)
	else:
		s.box(Vector3(p.x + sgn * 0.02, p.y - 0.08, p.z), Vector3(0.06, h + 0.16, w + 0.18), C_WHITE)
		g.box(Vector3(p.x + sgn * 0.04, p.y, p.z), Vector3(0.07, h, w), wc)
	g.m = 1.0


func _block(i: int, j: int) -> void:
	var c := block_center(i, j)
	var t: String = LAYOUT[j][i]
	var s = MB.new()
	var g = MB.new()
	s.m = 0.6
	s.box(Vector3(c.x, 0, c.z), Vector3(50, 0.15, 50), C_SIDEWALK)
	var lot := C_GRASS
	if t == "S" or t == "C" or t == "F" or t == "G" or t == "E" or t == "B":
		lot = Color(0.68, 0.64, 0.57)
	elif t == "P":
		lot = Color(0.76, 0.68, 0.53)
	elif t == "K":
		lot = Color(0.3, 0.56, 0.25)
	elif t == "A":
		lot = Color(0.7, 0.68, 0.64)
	s.m = 0.0 if (t == "R" or t == "H" or t == "K") else 0.6
	s.flat(Vector3(c.x, 0.16, c.z), 44, 44, lot)
	s.m = 1.0
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_lamp(s, g, c + Vector3(sx * 24.5, 0.15, sz * 24.5))
	for o in [-11.0, 11.0]:
		for sd in [-1.0, 1.0]:
			_tree(s, Vector3(c.x + o, 0.15, c.z + sd * 24.4), 0.75, 0)
			_tree(s, Vector3(c.x + sd * 24.4, 0.15, c.z + o), 0.75, 0)
	for sgn in [-1.0, 1.0]:
		var tl := c + Vector3(sgn * 22.4, 0.15, sgn * 24.7)
		s.cyl(tl, 0.09, 0.07, 3.4, C_DARK, 6, false)
		s.box(tl + Vector3(0, 3.4, 0), Vector3(0.38, 1.05, 0.3), C_DARK, true)
		var lights := [Color(0.15, 0.8, 0.3), Color(0.95, 0.7, 0.1), Color(0.9, 0.15, 0.12)]
		for k in 3:
			s.box(tl + Vector3(0, 3.5 + k * 0.31, sgn * 0.16), Vector3(0.2, 0.2, 0.04), lights[k])
		var bin := c + Vector3(sgn * 19.0, 0.15, sgn * 24.6)
		s.cyl(bin, 0.26, 0.3, 0.85, Color(0.2, 0.35, 0.28), 8)
	match t:
		"R":
			_residential(s, g, c, false)
		"H":
			_residential(s, g, c, true)
		"A":
			_apartments(s, g, c)
		"P":
			_plaza(s, g, c)
		"K":
			_park(s, g, c)
		"E":
			_gas(s, g, c)
		_:
			_shop(s, g, c, t)
	s.instance(root, mat_solid)
	g.instance(root, mat_glow, false)


# ---------------------------------------------------------------- casas

func _house(s, g, pos: Vector3, w: float, d: float, floors: int, face: float, wall: Color, roofc: Color, kind: String, hname: String, lot_edge: float) -> void:
	var h := 3.0 * floors
	var y0 := 0.16
	s.m = 0.2
	s.box(Vector3(pos.x, y0, pos.z), Vector3(w, h, d), wall)
	s.m = 0.3
	s.box(Vector3(pos.x, y0, pos.z), Vector3(w + 0.12, 0.5, d + 0.12), Color(0.62, 0.4, 0.32))
	s.m = 0.4
	s.prism(Vector3(pos.x, y0 + h, pos.z), Vector3(w + 0.9, 2.4, d + 0.9), roofc, wall)
	s.m = 0.3
	s.box(Vector3(pos.x + w * 0.28, y0 + h + 0.6, pos.z - d * 0.18), Vector3(0.7, 2.0, 0.7), Color(0.6, 0.35, 0.28))
	s.m = 0.5
	var fz := pos.z + face * d * 0.5
	s.m = 1.0
	s.box(Vector3(pos.x, y0, fz + face * 0.02), Vector3(1.45, 2.32, 0.08), C_WHITE)
	s.m = 0.5
	s.box(Vector3(pos.x, y0, fz + face * 0.05), Vector3(1.15, 2.15, 0.1), Color(0.4, 0.22, 0.14))
	s.m = 1.0
	s.box(Vector3(pos.x + 0.38, y0 + 1.0, fz + face * 0.11), Vector3(0.08, 0.08, 0.06), Color(0.9, 0.75, 0.3))
	s.box(Vector3(pos.x, y0, fz + face * 0.65), Vector3(2.0, 0.12, 1.3), C_STONE)
	s.box(Vector3(pos.x, y0 + 2.5, fz + face * 0.65), Vector3(2.6, 0.12, 1.4), roofc, true)
	for px in [-1.1, 1.1]:
		s.box(Vector3(pos.x + px, y0, fz + face * 1.2), Vector3(0.12, 2.5, 0.12), C_WHITE)
	for fl in floors:
		var yy := y0 + fl * 3.0 + 1.1
		for sx in [-1.0, 1.0]:
			_win(s, g, Vector3(pos.x + sx * w * 0.3, yy, fz), 1.5, 1.3, true, face)
			_win(s, g, Vector3(pos.x + sx * w * 0.3, yy, pos.z - face * d * 0.5), 1.5, 1.3, true, -face)
			_win(s, g, Vector3(pos.x + sx * w * 0.5, yy, pos.z), 1.5, 1.3, false, sx)
		if fl > 0:
			_win(s, g, Vector3(pos.x, yy, fz), 1.2, 1.3, true, face)
	s.m = 0.6
	var path_len := absf(lot_edge - (fz + face * 1.3))
	s.box(Vector3(pos.x, y0, (lot_edge + fz + face * 1.3) * 0.5), Vector3(1.5, 0.03, path_len), C_STONE)
	s.m = 0.7
	for sx in [-1.0, 1.0]:
		s.sphere(Vector3(pos.x + sx * (w * 0.5 - 1.2), y0 + 0.45, fz + face * 0.7), Vector3(0.8, 0.6, 0.6), C_HEDGE.lightened(0.1), 7, 4)
		_flowers(s, Vector3(pos.x + sx * 2.6, y0, fz + face * 2.2), 5, 0.7)
	s.m = 1.0
	s.box(Vector3(pos.x + 1.3, y0, lot_edge - face * 0.6), Vector3(0.1, 1.0, 0.1), C_DARK)
	s.box(Vector3(pos.x + 1.3, y0 + 1.0, lot_edge - face * 0.6), Vector3(0.3, 0.25, 0.45), roofc)
	add_col(pos.x, pos.z, w, d)
	buildings.append([Rect2(pos.x - w * 0.5 - 0.6, pos.z - d * 0.5 - 0.6, w + 1.2, d + 1.2), h + 2.6])
	doors.append({"pos": Vector3(pos.x, 0, fz + face * 1.1), "dir": Vector3(0, 0, face), "kind": kind, "name": hname})


func _residential(s, g, c: Vector3, home: bool) -> void:
	var qi := 0
	for q in [[-11.0, -11.0, -1.0], [11.0, -11.0, -1.0], [-11.0, 11.0, 1.0], [11.0, 11.0, 1.0]]:
		var face: float = q[2]
		var w := rng.randf_range(9.5, 12.0)
		var d := rng.randf_range(7.5, 9.0)
		var floors := 1 + (rng.randi() % 2)
		var pos := Vector3(c.x + q[0], 0, c.z + q[1] - face * 2.0)
		var is_home := home and qi == 2
		var wall: Color = WALLS[rng.randi() % WALLS.size()]
		var roofc: Color = ROOFS[rng.randi() % ROOFS.size()]
		var kind := "casaA" if rng.randf() < 0.5 else "casaB"
		var hname: String = "Casa de los " + SURNAMES[rng.randi() % SURNAMES.size()]
		if is_home:
			wall = Color(0.99, 0.86, 0.38)
			roofc = Color(0.72, 0.27, 0.22)
			kind = "hogar"
			hname = "Casa Mirasol"
			floors = 2
			spawn = Vector3(pos.x, 0, c.z + face * 23.3)
			_label("Casa Mirasol", Vector3(pos.x, 3.35, pos.z + face * (d * 0.5 + 1.45)), 0.008, Color(1, 0.95, 0.6))
		_house(s, g, pos, w, d, floors, face, wall, roofc, kind, hname, c.z + face * 22.0)
		var sgx := signf(q[0])
		_tree(s, Vector3(c.x + q[0] + sgx * 7.0, 0.16, c.z + q[1] + face * 7.5), rng.randf_range(0.75, 1.0), rng.randi() % 3)
		_flowers(s, Vector3(c.x + q[0] - sgx * 6.0, 0.16, c.z + q[1] + face * 8.0), 8, 1.2)
		qi += 1
	s.m = 0.7
	s.box(Vector3(c.x, 0.16, c.z), Vector3(0.7, 1.1, 41), C_HEDGE)
	add_col(c.x, c.z, 0.7, 41)
	s.box(Vector3(c.x, 0.16, c.z), Vector3(41, 1.1, 0.7), C_HEDGE.darkened(0.06))
	add_col(c.x, c.z, 41, 0.7)
	s.m = 1.0


# ---------------------------------------------------------------- pisos

func _apartments(s, g, c: Vector3) -> void:
	var cols := [Color(0.86, 0.82, 0.74), Color(0.76, 0.5, 0.4), Color(0.8, 0.85, 0.88), Color(0.9, 0.76, 0.6), Color(0.7, 0.75, 0.68)]
	for k in 2:
		var bx := c.x + (k * 2 - 1) * 11.0
		var floors := 4 + rng.randi() % 4
		var w := 17.0
		var d := 17.0
		var h := floors * 3.0 + 0.6
		var wall: Color = cols[rng.randi() % cols.size()]
		var bz := c.z - 4.0
		s.m = 0.2
		s.box(Vector3(bx, 0.16, bz), Vector3(w, h, d), wall)
		s.m = 0.3
		s.box(Vector3(bx, 0.16, bz), Vector3(w + 0.16, 3.1, d + 0.16), Color(0.6, 0.38, 0.3))
		s.m = 0.2
		s.box(Vector3(bx, 0.16 + h, bz), Vector3(w + 0.4, 0.5, d + 0.4), wall.darkened(0.18))
		s.m = 1.0
		s.box(Vector3(bx + 3.5, 0.66 + h, bz - 3.0), Vector3(3.2, 2.2, 3.2), Color(0.6, 0.6, 0.62))
		s.cyl(Vector3(bx - 4.0, 0.66 + h, bz + 2.0), 1.2, 1.2, 1.8, Color(0.45, 0.5, 0.55), 10)
		var fz := bz + d * 0.5
		for fl in range(1, floors):
			var yy := 0.16 + fl * 3.0 + 1.0
			for a in [-6.0, -2.0, 2.0, 6.0]:
				_win(s, g, Vector3(bx + a, yy, fz), 1.7, 1.5, true, 1.0)
				_win(s, g, Vector3(bx + a, yy, bz - d * 0.5), 1.7, 1.5, true, -1.0)
				_win(s, g, Vector3(bx + w * 0.5, yy, bz + a), 1.7, 1.5, false, 1.0)
				_win(s, g, Vector3(bx - w * 0.5, yy, bz + a), 1.7, 1.5, false, -1.0)
			s.box(Vector3(bx, 0.16 + fl * 3.0 + 0.1, fz + 0.65), Vector3(w - 2.0, 0.12, 1.3), C_WHITE, true)
			s.box(Vector3(bx, 0.16 + fl * 3.0 + 0.22, fz + 1.27), Vector3(w - 2.0, 0.85, 0.06), C_DARK)
		g.m = 0.5
		g.box(Vector3(bx, 0.16, fz + 0.05), Vector3(2.4, 2.5, 0.1), Color.WHITE)
		g.m = 1.0
		s.box(Vector3(bx, 0.16, fz + 0.02), Vector3(2.8, 2.7, 0.08), C_DARK)
		s.box(Vector3(bx, 2.9, fz + 1.1), Vector3(4.4, 0.2, 2.2), C_DARK, true)
		for a in [-5.5, 5.5]:
			_win(s, g, Vector3(bx + a, 1.1, fz), 3.0, 1.6, true, 1.0)
		var bname: String = "Edificio " + BUILDINGS[rng.randi() % BUILDINGS.size()]
		_label(bname, Vector3(bx, 3.5, fz + 2.22), 0.007, Color(1, 1, 1))
		add_col(bx, bz, w, d)
		buildings.append([Rect2(bx - w * 0.5 - 0.5, bz - d * 0.5 - 0.5, w + 1.0, d + 1.0), h + 1.0])
		doors.append({"pos": Vector3(bx, 0, fz + 1.1), "dir": Vector3(0, 0, 1), "kind": "piso", "name": bname})
	s.m = 0.0
	s.flat(Vector3(c.x, 0.17, c.z + 16.5), 40, 7, C_GRASS)
	s.m = 1.0
	for sx in [-16.0, 0.0, 16.0]:
		_tree(s, Vector3(c.x + sx, 0.17, c.z + 17.0), 0.9, rng.randi() % 3)
	_bench(s, Vector3(c.x - 8, 0.16, c.z + 12.0), 0.0)
	_bench(s, Vector3(c.x + 8, 0.16, c.z + 12.0), 0.0)
	_flowers(s, Vector3(c.x - 8, 0.17, c.z + 17), 10, 2.0)
	_flowers(s, Vector3(c.x + 8, 0.17, c.z + 17), 10, 2.0)


# ---------------------------------------------------------------- tiendas

func _shop(s, g, c: Vector3, t: String) -> void:
	var kind := "super"
	var sname := "Supermercado Sol"
	var accent := Color(0.85, 0.2, 0.2)
	var wallc := Color(0.95, 0.93, 0.88)
	if t == "C":
		kind = "cafe"
		sname = "Café Luna"
		accent = Color(0.5, 0.3, 0.18)
		wallc = Color(0.94, 0.86, 0.7)
	elif t == "F":
		kind = "muebles"
		sname = "Muebles Nido"
		accent = Color(0.2, 0.45, 0.72)
		wallc = Color(0.9, 0.91, 0.93)
	elif t == "G":
		kind = "gym"
		sname = "Gimnasio Titán"
		accent = Color(0.95, 0.55, 0.1)
		wallc = Color(0.34, 0.36, 0.4)
	elif t == "B":
		kind = "banco"
		sname = "Banco Mirasol"
		accent = Color(0.12, 0.3, 0.22)
		wallc = Color(0.84, 0.82, 0.78)
	var w := 32.0
	var d := 22.0
	var h := 6.5
	var bz := c.z - 9.0
	var fz := c.z + 2.0
	s.m = 0.2
	s.box(Vector3(c.x, 0.16, bz), Vector3(w, h, d), wallc)
	s.m = 0.3
	s.box(Vector3(c.x, 0.16, bz), Vector3(w + 0.14, 0.9, d + 0.14), wallc.darkened(0.4))
	s.m = 1.0
	s.box(Vector3(c.x, 0.16 + h, bz), Vector3(w + 0.5, 0.6, d + 0.5), accent)
	s.box(Vector3(c.x - 8, 0.76 + h, bz - 4), Vector3(2.6, 1.2, 2.6), Color(0.62, 0.63, 0.66))
	s.box(Vector3(c.x + 6, 0.76 + h, bz + 2), Vector3(3.5, 1.0, 2.2), Color(0.62, 0.63, 0.66))
	for sx in [-1.0, 1.0]:
		s.box(Vector3(c.x + sx * 9.0, 0.75, fz + 0.02), Vector3(10.5, 3.4, 0.08), C_DARK)
		g.m = 0.5
		g.box(Vector3(c.x + sx * 9.0, 0.9, fz + 0.04), Vector3(10.0, 3.1, 0.1), Color.WHITE)
		_win(s, g, Vector3(c.x + sx * w * 0.5, 2.2, bz), 6.0, 2.0, false, sx)
	s.box(Vector3(c.x, 0.16, fz + 0.02), Vector3(3.1, 3.0, 0.08), C_DARK)
	g.m = 0.5
	g.box(Vector3(c.x, 0.16, fz + 0.05), Vector3(2.6, 2.8, 0.1), Color.WHITE)
	g.m = 1.0
	for k in 16:
		s.box(Vector3(c.x - 15.0 + k * 2.0, 3.95, fz + 1.15), Vector3(2.0, 0.14, 2.3), accent if k % 2 == 0 else C_WHITE, true)
	s.box(Vector3(c.x, 4.5, fz + 0.1), Vector3(17, 1.7, 0.3), accent.darkened(0.15))
	_label(sname, Vector3(c.x, 5.35, fz + 0.27), 0.017, Color(1, 1, 1))
	add_col(c.x, bz, w, d)
	buildings.append([Rect2(c.x - w * 0.5 - 0.5, bz - d * 0.5 - 0.5, w + 1.0, d + 1.0), h + 1.0])
	doors.append({"pos": Vector3(c.x, 0, fz + 1.2), "dir": Vector3(0, 0, 1), "kind": kind, "name": sname})
	for sx in [-1.0, 1.0]:
		s.box(Vector3(c.x + sx * 13.0, 0.16, c.z + 8.0), Vector3(3.0, 0.6, 1.4), C_STONE)
		add_col(c.x + sx * 13.0, c.z + 8.0, 3.0, 1.4)
		s.sphere(Vector3(c.x + sx * 13.0, 1.0, c.z + 8.0), Vector3(1.3, 0.6, 0.6), C_HEDGE.lightened(0.08), 8, 4)
		_flowers(s, Vector3(c.x + sx * 13.0, 0.95, c.z + 8.0), 6, 0.5)
		_tree(s, Vector3(c.x + sx * 18.0, 0.16, c.z + 18.0), 0.95, 0)
		_bench(s, Vector3(c.x + sx * 6.0, 0.16, c.z + 19.0), PI)
	if t == "C":
		for tp in [Vector2(-9, 11), Vector2(-4, 14.5), Vector2(8, 12)]:
			var q := Vector3(c.x + tp.x, 0.16, c.z + tp.y)
			s.cyl(q, 0.06, 0.06, 0.72, C_DARK, 6, false)
			s.cyl(q + Vector3(0, 0.72, 0), 0.6, 0.6, 0.05, C_WHITE, 10)
			s.cyl(q + Vector3(0, 0.77, 0), 0.03, 0.03, 1.6, C_DARK, 5, false)
			s.cyl(q + Vector3(0, 2.2, 0), 1.5, 0.05, 0.5, accent.lightened(0.3), 10)
			for a in [0.0, 2.1, 4.2]:
				var ch := q + Vector3(cos(a), 0, sin(a)) * 1.0
				s.box(ch, Vector3(0.42, 0.45, 0.42), C_WOOD)
			add_col(q.x, q.z, 1.3, 1.3)
	elif t == "S":
		for k in 6:
			s.box(Vector3(c.x + 9.0 + k * 0.55, 0.16, c.z + 4.0), Vector3(0.45, 0.9, 0.9), Color(0.6, 0.62, 0.66))
		add_col(c.x + 10.4, c.z + 4.0, 3.4, 1.0)
	elif t == "F":
		s.box(Vector3(c.x - 10.0, 0.16, c.z + 3.6), Vector3(2.2, 0.45, 0.9), Color(0.8, 0.3, 0.3))
		s.box(Vector3(c.x - 10.0, 0.16, c.z + 3.2), Vector3(2.2, 0.9, 0.25), Color(0.7, 0.25, 0.25))
		add_col(c.x - 10.0, c.z + 3.5, 2.2, 1.0)
	elif t == "G":
		for k in 3:
			s.cyl(Vector3(c.x + 9.0 + k * 1.2, 0.16, c.z + 4.0), 0.05, 0.05, 0.9, C_DARK, 5, false)
		s.box(Vector3(c.x + 10.2, 1.0, c.z + 4.0), Vector3(2.8, 0.06, 0.06), C_DARK)


# ---------------------------------------------------------------- plaza y parque

func _plaza(s, g, c: Vector3) -> void:
	s.m = 0.6
	s.disc(Vector3(c.x, 0.17, c.z), 13.0, Color(0.76, 0.69, 0.56), 28)
	s.disc(Vector3(c.x, 0.175, c.z), 6.2, Color(0.7, 0.6, 0.47), 24)
	s.m = 1.0
	s.cyl(Vector3(c.x, 0.16, c.z), 4.3, 4.3, 0.7, C_STONE, 22)
	_water.disc(Vector3(c.x, 0.88, c.z), 3.8, Color.WHITE, 22)
	s.cyl(Vector3(c.x, 0.86, c.z), 0.55, 0.4, 2.0, C_STONE.lightened(0.1), 10)
	s.cyl(Vector3(c.x, 2.86, c.z), 0.4, 1.6, 0.4, C_STONE, 12)
	_water.disc(Vector3(c.x, 3.28, c.z), 1.45, Color.WHITE, 12)
	s.sphere(Vector3(c.x, 3.7, c.z), Vector3(0.35, 0.45, 0.35), C_STONE.lightened(0.15), 8, 5)
	add_col(c.x, c.z, 7.6, 7.6)
	for k in 8:
		var a := TAU * k / 8.0 + PI / 8.0
		var p := Vector3(c.x + cos(a) * 9.5, 0.16, c.z + sin(a) * 9.5)
		_bench(s, p, atan2(c.x - p.x, c.z - p.z))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_lamp(s, g, Vector3(c.x + sx * 14.0, 0.16, c.z + sz * 14.0))
			var tp := Vector3(c.x + sx * 19.0, 0.16, c.z + sz * 19.0)
			s.box(tp, Vector3(2.4, 0.45, 2.4), C_STONE)
			_tree(s, tp + Vector3(0, 0.4, 0), 1.1, 0, false)
			add_col(tp.x, tp.z, 2.4, 2.4)
			var fb := Vector3(c.x + sx * 6.6, 0.16, c.z + sz * 6.6)
			s.cyl(fb, 1.3, 1.3, 0.3, Color(0.45, 0.32, 0.22), 10)
			_flowers(s, fb + Vector3(0, 0.25, 0), 12, 0.8)
			add_col(fb.x, fb.z, 2.2, 2.2)
	for q in [Vector2(-19, 0), Vector2(19, 0), Vector2(0, -19), Vector2(0, 19)]:
		var tp2 := Vector3(c.x + q.x, 0.16, c.z + q.y)
		s.box(tp2, Vector3(2.4, 0.45, 2.4), C_STONE)
		_tree(s, tp2 + Vector3(0, 0.4, 0), 1.0, 2, false)
		add_col(tp2.x, tp2.z, 2.4, 2.4)
	var kp := Vector3(c.x + 13.5, 0.16, c.z - 14.0)
	s.m = 0.5
	s.box(kp, Vector3(3.6, 2.6, 3.6), Color(0.9, 0.3, 0.28))
	s.m = 1.0
	s.box(kp + Vector3(0, 1.0, 1.82), Vector3(2.6, 1.2, 0.06), C_DARK)
	s.cyl(kp + Vector3(0, 2.6, 0), 3.0, 0.1, 1.3, C_WHITE, 8)
	add_col(kp.x, kp.z, 3.6, 3.6)
	_label("Quiosco", kp + Vector3(0, 2.4, 1.9), 0.006, Color(1, 1, 1))
	_label("Plaza Mayor", Vector3(c.x, 5.0, c.z), 0.012, Color(1, 0.95, 0.75), true)


func _park(s, g, c: Vector3) -> void:
	var pc := Vector3(c.x - 8.0, 0.0, c.z - 7.0)
	s.disc(Vector3(pc.x, 0.17, pc.z), 8.0, Color(0.82, 0.75, 0.55), 22)
	_water.disc(Vector3(pc.x, 0.19, pc.z), 7.0, Color.WHITE, 22)
	add_col(pc.x, pc.z, 10.5, 10.5)
	for k in 7:
		var a := rng.randf() * TAU
		s.sphere(Vector3(pc.x + cos(a) * 7.6, 0.3, pc.z + sin(a) * 7.6), Vector3(0.7, 0.4, 0.6), Color(0.55, 0.55, 0.56), 6, 4)
	var sand := Color(0.85, 0.78, 0.6)
	s.flat(Vector3(c.x, 0.175, c.z + 6.0), 44, 2.4, sand)
	s.flat(Vector3(c.x + 8.0, 0.176, c.z), 2.4, 44, sand)
	var placed := 0
	var tries := 0
	while placed < 24 and tries < 400:
		tries += 1
		var x := rng.randf_range(-20.0, 20.0)
		var z := rng.randf_range(-20.0, 20.0)
		if Vector2(x + 8.0, z + 7.0).length() < 10.5:
			continue
		if absf(z - 6.0) < 2.6 or absf(x - 8.0) < 2.6:
			continue
		if x > 10.0 and z > 9.0:
			continue
		_tree(s, Vector3(c.x + x, 0.16, c.z + z), rng.randf_range(0.8, 1.25), rng.randi() % 3)
		placed += 1
	for bx in [-14.0, -2.0, 15.0]:
		_bench(s, Vector3(c.x + bx, 0.16, c.z + 8.2), PI)
	_bench(s, Vector3(c.x + 6.2, 0.16, c.z - 12.0), PI / 2.0)
	_lamp(s, g, Vector3(c.x + 9.8, 0.16, c.z + 7.8))
	_lamp(s, g, Vector3(c.x - 10.0, 0.16, c.z + 7.8))
	for k in 5:
		_flowers(s, Vector3(c.x + rng.randf_range(-18, 5), 0.16, c.z + rng.randf_range(9, 19)), 9, 1.3)
	# zona infantil
	var pg := Vector3(c.x + 15.5, 0.16, c.z + 15.0)
	s.flat(Vector3(pg.x, 0.18, pg.z), 10, 10, sand)
	for sx in [-1.4, 1.4]:
		s.box(Vector3(pg.x - 2.5 + sx, 0.16, pg.z - 2.5), Vector3(0.12, 2.4, 0.12), Color(0.2, 0.5, 0.8))
	s.box(Vector3(pg.x - 2.5, 2.56, pg.z - 2.5), Vector3(3.0, 0.12, 0.12), Color(0.2, 0.5, 0.8))
	for sx in [-0.6, 0.6]:
		s.box(Vector3(pg.x - 2.5 + sx, 1.0, pg.z - 2.5), Vector3(0.03, 1.56, 0.03), C_DARK)
		s.box(Vector3(pg.x - 2.5 + sx, 0.95, pg.z - 2.5), Vector3(0.5, 0.05, 0.25), Color(0.9, 0.3, 0.3))
	add_col(pg.x - 2.5, pg.z - 2.5, 3.0, 0.4)
	s.box(Vector3(pg.x + 2.5, 0.16, pg.z + 1.0), Vector3(1.3, 1.6, 1.3), Color(0.95, 0.75, 0.2))
	s.push_t(Transform3D(Basis(Vector3(1, 0, 0), -0.5), Vector3(pg.x + 2.5, 1.0, pg.z + 2.9)))
	s.box(Vector3(0, 0, 0), Vector3(0.9, 0.08, 3.4), Color(0.9, 0.25, 0.25), true)
	s.pop()
	add_col(pg.x + 2.5, pg.z + 1.6, 1.4, 3.6)
	_label("Parque del Lucero", Vector3(c.x + 8.0, 4.6, c.z + 6.0), 0.011, Color(0.85, 1, 0.8), true)


func _scenery() -> void:
	var quads: Array = [MB.new(), MB.new(), MB.new(), MB.new()]
	var placed := 0
	while placed < 280:
		var x := rng.randf_range(-360.0, 360.0)
		var z := rng.randf_range(-360.0, 360.0)
		if absf(x) < 160.0 and absf(z) < 160.0:
			continue
		var qi := (0 if x < 0 else 1) + (0 if z < 0 else 2)
		_tree(quads[qi], Vector3(x, -0.12, z), rng.randf_range(1.1, 2.0), rng.randi() % 3, false)
		placed += 1
	for q in quads:
		q.instance(root, mat_solid, false)
	var hills = MB.new()
	hills.m = 0.0
	for k in 16:
		var a := TAU * k / 16.0 + rng.randf() * 0.2
		var dist := rng.randf_range(430.0, 560.0)
		var hc := Color(0.3 + rng.randf() * 0.08, 0.52 + rng.randf() * 0.08, 0.36 + rng.randf() * 0.1)
		hills.sphere(Vector3(cos(a) * dist, -10.0, sin(a) * dist), Vector3(rng.randf_range(110, 170), rng.randf_range(45, 85), rng.randf_range(110, 170)), hc, 12, 6)
	hills.instance(root, mat_solid, false)


# ================================================================ interiores

func _fcol(o: Vector3, x: float, z: float, sx: float, sz: float, rot: float = 0.0) -> void:
	if absf(sin(rot)) > 0.5:
		add_col(o.x + x, o.z + z, sz, sx)
	else:
		add_col(o.x + x, o.z + z, sx, sz)


func _spot(o: Vector3, x: float, z: float, label: String, id: String, kind: String, tag: String = "") -> void:
	spots.append({"pos": o + Vector3(x, 0, z), "label": label, "id": id, "room": kind})
	if tag != "":
		_label(tag, o + Vector3(x, 2.5, z), 0.005, Color(1, 0.95, 0.6), true)


func _static(o: Vector3, x: float, z: float, rot: float, kind: String, role: String, pname: String) -> void:
	statics.append({"pos": o + Vector3(x, FY, z), "rot": rot, "room": kind, "role": role, "name": pname})
	var f := Vector3(sin(rot), 0, cos(rot))
	spots.append({"pos": o + Vector3(x, 0, z) + f * 1.5, "label": "Hablar con " + pname, "id": "hablar", "room": kind, "who": statics.size() - 1})


func _room_begin(kind: String, rname: String, idx: int, w: float, d: float, floorc: Color, wallc: Color, tiles: bool = false) -> Dictionary:
	var o := Vector3(1000.0 + idx * 90.0, 0, 1000.0)
	var sh = MB.new()
	var f = MB.new()
	var g = MB.new()
	sh.push(o)
	f.push(o)
	g.push(o)
	g.m = 0.5
	sh.flat(Vector3(0, -0.15, 0), 80, 70, Color(0.09, 0.09, 0.13))
	sh.m = 0.6 if tiles else 0.5
	sh.box(Vector3(0, -0.1, 0), Vector3(w, 0.2, d), floorc)
	sh.m = 0.2
	if false:
		var tx := int(w / 2.0)
		var tz := int(d / 2.0)
		for a in tx:
			for b in tz:
				if (a + b) % 2 == 0:
					sh.flat(Vector3(-w * 0.5 + 1.0 + a * 2.0, FY + 0.005, -d * 0.5 + 1.0 + b * 2.0), 2.0, 2.0, floorc.darkened(0.12))
	var hh := 3.4
	var hw := w * 0.5
	var hd := d * 0.5
	sh.quad(Vector3(-hw, FY, -hd), Vector3(hw, FY, -hd), Vector3(hw, hh, -hd), Vector3(-hw, hh, -hd), Vector3(0, 0, 1), wallc)
	sh.quad(Vector3(-hw, FY, hd), Vector3(hw, FY, hd), Vector3(hw, hh, hd), Vector3(-hw, hh, hd), Vector3(0, 0, -1), wallc)
	sh.quad(Vector3(-hw, FY, -hd), Vector3(-hw, FY, hd), Vector3(-hw, hh, hd), Vector3(-hw, hh, -hd), Vector3(1, 0, 0), wallc.darkened(0.06))
	sh.quad(Vector3(hw, FY, -hd), Vector3(hw, FY, hd), Vector3(hw, hh, hd), Vector3(hw, hh, -hd), Vector3(-1, 0, 0), wallc.darkened(0.06))
	var bb := wallc.darkened(0.35)
	var e := 0.02
	sh.quad(Vector3(-hw, FY, -hd + e), Vector3(hw, FY, -hd + e), Vector3(hw, 0.4, -hd + e), Vector3(-hw, 0.4, -hd + e), Vector3(0, 0, 1), bb)
	sh.quad(Vector3(-hw + e, FY, -hd), Vector3(-hw + e, FY, hd), Vector3(-hw + e, 0.4, hd), Vector3(-hw + e, 0.4, -hd), Vector3(1, 0, 0), bb)
	sh.quad(Vector3(hw - e, FY, -hd), Vector3(hw - e, FY, hd), Vector3(hw - e, 0.4, hd), Vector3(hw - e, 0.4, -hd), Vector3(-1, 0, 0), bb)
	add_col(o.x, o.z - hd - 0.5, w + 2.0, 1.0)
	add_col(o.x, o.z + hd + 0.5, w + 2.0, 1.0)
	add_col(o.x - hw - 0.5, o.z, 1.0, d + 2.0)
	add_col(o.x + hw + 0.5, o.z, 1.0, d + 2.0)
	sh.m = 1.0
	sh.flat(Vector3(0, FY + 0.012, hd - 0.8), 2.4, 1.3, Color(0.2, 0.55, 0.32))
	rooms[kind] = {"origin": o, "w": w, "d": d, "name": rname, "spawn": o + Vector3(0, 0, hd - 2.0)}
	spots.append({"pos": o + Vector3(0, 0, hd - 0.8), "label": "Salir a la calle", "id": "salir", "room": kind})
	_label("Salida", o + Vector3(0, 1.3, hd - 0.4), 0.006, Color(0.6, 1, 0.7), true)
	return {"o": o, "sh": sh, "f": f, "g": g, "kind": kind}


func _room_end(r: Dictionary) -> void:
	r.sh.pop()
	r.f.pop()
	r.g.pop()
	r.sh.instance(root, mat_solid, false)
	r.f.instance(root, mat_solid)
	r.g.instance(root, mat_glow, false)
	var room: Dictionary = rooms[r.kind]
	var l := OmniLight3D.new()
	l.position = r.o + Vector3(0, 3.2, 0)
	l.omni_range = maxf(room.w, room.d) * 0.95
	l.light_energy = 0.3
	l.light_color = Color(1.0, 0.93, 0.8)
	l.omni_attenuation = 0.6
	root.add_child(l)


func _rcol() -> Color:
	return Color.from_hsv(rng.randf(), rng.randf_range(0.5, 0.85), rng.randf_range(0.7, 0.95))


func _shelf(f, x: float, z: float, rot: float, length: float) -> void:
	f.push(Vector3(x, FY, z), rot)
	f.box(Vector3.ZERO, Vector3(length, 1.95, 0.4), Color(0.85, 0.86, 0.88))
	for side in [-1.0, 1.0]:
		for lvl in 3:
			f.box(Vector3(0, 0.22 + lvl * 0.56, side * 0.38), Vector3(length, 0.05, 0.36), C_WHITE, true)
			var k := 0
			while k * 0.5 < length - 0.3:
				f.box(Vector3(-length * 0.5 + 0.3 + k * 0.5, 0.27 + lvl * 0.56, side * 0.38), Vector3(0.4, rng.randf_range(0.26, 0.42), 0.28), _rcol())
				k += 1
	f.pop()


func _counter(f, x: float, z: float, rot: float, length: float, col: Color) -> void:
	f.push(Vector3(x, FY, z), rot)
	f.box(Vector3.ZERO, Vector3(length, 0.95, 0.8), col)
	f.box(Vector3(0, 0.95, 0), Vector3(length + 0.1, 0.06, 0.9), col.darkened(0.45))
	f.pop()


func _fridge(f, x: float, z: float, rot: float) -> void:
	f.push(Vector3(x, FY, z), rot)
	f.box(Vector3.ZERO, Vector3(1.15, 2.0, 0.8), C_WHITE)
	f.box(Vector3(0, 0.12, 0.41), Vector3(1.0, 1.75, 0.02), Color(0.7, 0.82, 0.9))
	f.box(Vector3(0.4, 0.8, 0.44), Vector3(0.05, 0.6, 0.04), Color(0.5, 0.5, 0.52))
	f.pop()


func _table(f, x: float, z: float, col: Color, r: float = 0.65) -> void:
	f.cyl(Vector3(x, FY, z), 0.3, 0.08, 0.1, C_DARK, 8, false)
	f.cyl(Vector3(x, FY, z), 0.07, 0.07, 0.72, C_DARK, 6, false)
	f.cyl(Vector3(x, FY + 0.72, z), r, r, 0.05, col, 14)


func _chair(f, x: float, z: float, rot: float, col: Color) -> void:
	f.push(Vector3(x, FY, z), rot)
	f.box(Vector3(0, 0.42, 0), Vector3(0.45, 0.06, 0.45), col, true)
	f.box(Vector3(0, 0.48, -0.2), Vector3(0.45, 0.5, 0.06), col)
	for sx in [-0.18, 0.18]:
		for sz in [-0.18, 0.18]:
			f.box(Vector3(sx, 0, sz), Vector3(0.05, 0.42, 0.05), C_DARK)
	f.pop()


func _sofa(f, x: float, z: float, rot: float, col: Color, length: float = 2.3) -> void:
	f.push(Vector3(x, FY, z), rot)
	f.box(Vector3(0, 0.1, 0.05), Vector3(length, 0.35, 0.9), col)
	f.box(Vector3(0, 0.1, -0.38), Vector3(length, 0.85, 0.24), col.darkened(0.12))
	for sx in [-1.0, 1.0]:
		f.box(Vector3(sx * (length * 0.5 - 0.13), 0.1, 0.05), Vector3(0.26, 0.6, 0.9), col.darkened(0.18))
		f.box(Vector3(sx * (length * 0.25 - 0.06), 0.45, 0.1), Vector3(length * 0.5 - 0.32, 0.1, 0.7), col.lightened(0.12))
	f.pop()


func _bed(f, x: float, z: float, rot: float, col: Color) -> void:
	f.push(Vector3(x, FY, z), rot)
	f.box(Vector3.ZERO, Vector3(1.9, 0.35, 2.2), C_WOOD)
	f.box(Vector3(0, 0.35, 0.02), Vector3(1.8, 0.2, 2.1), C_WHITE)
	f.box(Vector3(0, 0.55, 0.35), Vector3(1.84, 0.08, 1.45), col)
	for sx in [-0.45, 0.45]:
		f.box(Vector3(sx, 0.55, -0.75), Vector3(0.7, 0.12, 0.4), C_WHITE)
	f.box(Vector3(0, 0, -1.13), Vector3(1.9, 1.15, 0.1), C_WOOD.darkened(0.15))
	f.pop()


func _tv(f, x: float, z: float, rot: float, size: float) -> void:
	f.push(Vector3(x, FY, z), rot)
	f.box(Vector3.ZERO, Vector3(size + 0.5, 0.45, 0.45), C_WOOD)
	f.box(Vector3(0, 0.5, 0), Vector3(size, size * 0.58, 0.07), Color(0.06, 0.06, 0.07))
	f.box(Vector3(0, 0.54, 0.036), Vector3(size - 0.08, size * 0.58 - 0.08, 0.01), Color(0.2, 0.4, 0.65))
	f.pop()


func _plant(f, x: float, z: float, sc: float = 1.0) -> void:
	var p := Vector3(x, FY, z)
	f.cyl(p, 0.2 * sc, 0.28 * sc, 0.45 * sc, Color(0.75, 0.42, 0.3), 8)
	f.m = 0.7
	f.sphere(p + Vector3(0, 0.95, 0) * sc, Vector3(0.45, 0.55, 0.45) * sc, Color(0.2, 0.55, 0.25), 9, 6, 0.2)
	f.sphere(p + Vector3(0.2, 1.3, 0.1) * sc, Vector3(0.3, 0.35, 0.3) * sc, Color(0.28, 0.62, 0.3), 8, 5, 0.2)
	f.m = 1.0


func _floor_lamp(f, g, x: float, z: float) -> void:
	var p := Vector3(x, FY, z)
	f.cyl(p, 0.2, 0.2, 0.04, C_DARK, 8)
	f.cyl(p, 0.025, 0.025, 1.5, C_DARK, 5, false)
	g.m = 1.0
	g.cyl(p + Vector3(0, 1.45, 0), 0.28, 0.16, 0.36, Color.WHITE, 8)
	g.m = 0.5


func _rug(f, x: float, z: float, sx: float, sz: float, col: Color) -> void:
	f.flat(Vector3(x, FY + 0.015, z), sx, sz, col)
	f.flat(Vector3(x, FY + 0.02, z), sx - 0.5, sz - 0.5, col.lightened(0.25))


func _bookcase(f, x: float, z: float, rot: float, length: float) -> void:
	f.push(Vector3(x, FY, z), rot)
	f.m = 0.5
	f.box(Vector3.ZERO, Vector3(length, 2.0, 0.4), C_WOOD)
	f.m = 1.0
	for lvl in 4:
		f.box(Vector3(0, 0.1 + lvl * 0.47, 0.19), Vector3(length - 0.12, 0.38, 0.03), C_WOOD.darkened(0.4))
		var k := 0
		while k * 0.16 < length - 0.4:
			f.box(Vector3(-length * 0.5 + 0.2 + k * 0.16, 0.1 + lvl * 0.47, 0.2), Vector3(0.12, rng.randf_range(0.24, 0.34), 0.06), _rcol())
			k += 1
	f.pop()


func _kitchen(f, x: float, z: float, rot: float, length: float) -> void:
	f.push(Vector3(x, FY, z), rot)
	f.box(Vector3.ZERO, Vector3(length, 0.9, 0.65), C_WHITE)
	f.box(Vector3(0, 0.9, 0), Vector3(length + 0.05, 0.05, 0.7), Color(0.3, 0.3, 0.33))
	f.box(Vector3(-length * 0.25, 0.95, 0), Vector3(0.6, 0.015, 0.5), Color(0.05, 0.05, 0.06))
	f.box(Vector3(length * 0.25, 0.95, 0), Vector3(0.6, 0.015, 0.45), Color(0.75, 0.77, 0.8))
	f.box(Vector3(0, 1.7, -0.14), Vector3(length, 0.7, 0.36), Color(0.9, 0.9, 0.88), true)
	f.pop()


func _treadmill(f, x: float, z: float, rot: float) -> void:
	f.push(Vector3(x, FY, z), rot)
	f.box(Vector3.ZERO, Vector3(0.85, 0.2, 1.9), C_DARK)
	f.box(Vector3(0, 0.2, -0.1), Vector3(0.62, 0.02, 1.5), Color(0.4, 0.4, 0.42))
	for sx in [-0.38, 0.38]:
		f.box(Vector3(sx, 0.2, 0.8), Vector3(0.06, 1.1, 0.06), Color(0.6, 0.6, 0.63))
	f.box(Vector3(0, 1.25, 0.8), Vector3(0.85, 0.28, 0.12), C_DARK)
	f.box(Vector3(0, 1.3, 0.73), Vector3(0.5, 0.18, 0.02), Color(0.2, 0.7, 0.9))
	f.pop()


func _wbench(f, x: float, z: float, rot: float) -> void:
	f.push(Vector3(x, FY, z), rot)
	f.box(Vector3(0, 0.38, 0.1), Vector3(0.42, 0.1, 1.4), Color(0.75, 0.15, 0.15), true)
	f.box(Vector3(0, 0, 0.6), Vector3(0.3, 0.38, 0.08), C_DARK)
	f.box(Vector3(0, 0, -0.4), Vector3(0.3, 0.38, 0.08), C_DARK)
	for sx in [-0.55, 0.55]:
		f.box(Vector3(sx, 0, -0.5), Vector3(0.07, 1.15, 0.07), Color(0.6, 0.6, 0.63))
	f.push_t(Transform3D(Basis(Vector3(0, 0, 1), PI / 2.0), Vector3(0.95, 1.15, -0.5)))
	f.cyl(Vector3.ZERO, 0.03, 0.03, 1.9, Color(0.7, 0.7, 0.72), 6)
	f.cyl(Vector3(0, 0.08, 0), 0.24, 0.24, 0.1, Color(0.08, 0.08, 0.09), 10)
	f.cyl(Vector3(0, 1.72, 0), 0.24, 0.24, 0.1, Color(0.08, 0.08, 0.09), 10)
	f.pop()
	f.pop()


func _interiors() -> void:
	_int_gas(8)
	_int_banco(9)
	_int_super(0)
	_int_cafe(1)
	_int_muebles(2)
	_int_gym(3)
	_int_hogar(4)
	_int_casa("casaA", 5, 14.0, 10.0, Color(0.72, 0.55, 0.38), Color(0.93, 0.88, 0.78), Color(0.3, 0.5, 0.7), 1.0)
	_int_casa("casaB", 6, 14.0, 10.0, Color(0.6, 0.62, 0.66), Color(0.82, 0.9, 0.86), Color(0.75, 0.35, 0.3), -1.0)
	_int_casa("piso", 7, 12.0, 9.0, Color(0.78, 0.68, 0.5), Color(0.9, 0.86, 0.92), Color(0.5, 0.4, 0.7), 1.0)


func _int_super(idx: int) -> void:
	var r := _room_begin("super", "Supermercado Sol", idx, 22.0, 16.0, Color(0.74, 0.76, 0.78), Color(0.86, 0.87, 0.84), true)
	var o: Vector3 = r.o
	var f = r.f
	for k in 8:
		_fridge(f, -8.75 + k * 2.5, -7.5, 0.0)
	_fcol(o, 0, -7.5, 20.0, 1.0)
	for z in [-4.0, -1.0, 2.0]:
		_shelf(f, -4.5, z, 0.0, 10.0)
		_fcol(o, -4.5, z, 10.0, 1.1)
	for z in [-3.5, 0.0]:
		f.box(Vector3(7.0, FY, z), Vector3(3.0, 0.8, 1.6), C_WOOD)
		for a in 6:
			for b in 3:
				f.sphere(Vector3(5.8 + a * 0.48, FY + 0.9, z - 0.5 + b * 0.5), Vector3(0.2, 0.2, 0.2), [Color(0.9, 0.2, 0.15), Color(0.95, 0.6, 0.1), Color(0.4, 0.75, 0.2), Color(0.95, 0.85, 0.2)][(a + b + int(z)) % 4], 6, 4)
		_fcol(o, 7.0, z, 3.0, 1.6)
	for x in [-5.0, 2.0]:
		_counter(f, x, 5.0, PI / 2.0, 2.6, Color(0.85, 0.2, 0.2))
		f.box(Vector3(x, FY + 1.01, 4.4), Vector3(0.4, 0.3, 0.4), C_DARK)
		_fcol(o, x, 5.0, 0.9, 2.6)
	r.g.box(Vector3(0, 2.0, -7.95), Vector3(18.0, 0.5, 0.05), Color.WHITE)
	_static(o, -6.2, 5.0, PI / 2.0, "super", "cajera", "Lola, la cajera")
	_spot(o, 2.2, -2.5, "Comprar comida  §15", "comida", "super", "Comida")
	_spot(o, 3.6, 5.0, "Trabajar un turno  +§60", "trabajo", "super", "Caja")
	_room_end(r)


func _int_cafe(idx: int) -> void:
	var r := _room_begin("cafe", "Café Luna", idx, 16.0, 12.0, Color(0.5, 0.36, 0.25), Color(0.95, 0.88, 0.74))
	var o: Vector3 = r.o
	var f = r.f
	var wood := Color(0.42, 0.27, 0.17)
	_counter(f, -1.0, -3.6, 0.0, 8.0, wood)
	_fcol(o, -1.0, -3.6, 8.0, 0.9)
	_bookcase(f, -1.0, -5.75, 0.0, 7.0)
	f.box(Vector3(-3.5, FY + 1.01, -3.6), Vector3(0.7, 0.55, 0.5), Color(0.7, 0.72, 0.75))
	f.box(Vector3(1.5, FY + 1.01, -3.6), Vector3(1.2, 0.35, 0.5), Color(0.8, 0.9, 0.95))
	for a in 3:
		f.cyl(Vector3(1.1 + a * 0.4, FY + 1.03, -3.6), 0.15, 0.15, 0.12, [Color(0.95, 0.8, 0.5), Color(0.6, 0.3, 0.2), Color(0.95, 0.6, 0.7)][a], 8)
	for tp in [Vector2(-5, 0.2), Vector2(0, 1.2), Vector2(5, 0.2), Vector2(-4, 3.6), Vector2(4.5, 3.6)]:
		_table(f, tp.x, tp.y, Color(0.9, 0.85, 0.75))
		_chair(f, tp.x - 0.95, tp.y, PI / 2.0, wood.lightened(0.15))
		_chair(f, tp.x + 0.95, tp.y, -PI / 2.0, wood.lightened(0.15))
		_fcol(o, tp.x, tp.y, 2.3, 1.2)
	_plant(f, -7.2, -5.2, 1.2)
	_plant(f, 7.2, -5.2, 1.2)
	_plant(f, 7.2, 5.0)
	_rug(f, 0, 1.2, 4.5, 3.0, Color(0.65, 0.25, 0.2))
	r.g.box(Vector3(5.5, 1.4, -5.97), Vector3(2.4, 1.4, 0.05), Color.WHITE)
	_static(o, -1.0, -4.7, 0.0, "cafe", "barista", "Nico, el barista")
	_spot(o, -3.6, -2.4, "Tomar un café  §5", "cafe", "cafe", "Café")
	_spot(o, 1.6, -2.4, "Pedir tarta  §8", "tarta", "cafe", "Tartas")
	_spot(o, 6.5, -2.6, "Trabajar de camarero  +§50", "trabajo", "cafe", "Empleo")
	_room_end(r)


func _int_muebles(idx: int) -> void:
	var r := _room_begin("muebles", "Muebles Nido", idx, 22.0, 16.0, Color(0.66, 0.58, 0.47), Color(0.82, 0.85, 0.9))
	var o: Vector3 = r.o
	var f = r.f
	_rug(f, -7.0, -4.2, 5.0, 4.0, Color(0.3, 0.45, 0.65))
	_sofa(f, -7.0, -5.2, 0.0, Color(0.85, 0.35, 0.3))
	_fcol(o, -7.0, -5.2, 2.3, 1.0)
	_floor_lamp(f, r.g, -4.6, -5.5)
	_bed(f, 0.0, -6.0, 0.0, Color(0.35, 0.6, 0.55))
	_fcol(o, 0.0, -6.0, 1.9, 2.2)
	_bookcase(f, 6.5, -7.6, 0.0, 3.0)
	_fcol(o, 6.5, -7.6, 3.0, 0.6)
	_plant(f, 9.5, -2.0, 1.3)
	_plant(f, 8.4, -1.4)
	_plant(f, 9.6, -0.6, 0.8)
	_tv(f, 7.5, 3.0, -PI / 2.0, 1.6)
	_fcol(o, 7.5, 3.0, 0.6, 2.1)
	for k in 4:
		_rug(f, -8.0 + k * 0.15, 2.5 + k * 0.1, 2.6, 1.8, [Color(0.7, 0.3, 0.3), Color(0.3, 0.55, 0.4), Color(0.75, 0.6, 0.3), Color(0.4, 0.35, 0.6)][k])
	_sofa(f, -2.0, 1.5, PI, Color(0.3, 0.5, 0.7), 1.2)
	_fcol(o, -2.0, 1.5, 1.2, 1.0)
	_counter(f, 3.0, 5.6, 0.0, 3.0, Color(0.2, 0.45, 0.72))
	_fcol(o, 3.0, 5.6, 3.0, 0.9)
	_static(o, 3.0, 6.6, PI, "muebles", "dependiente", "Marga, la dependienta")
	_spot(o, -7.0, -3.4, "Comprar sofá  §150", "buy:sofa", "muebles", "Sofá §150")
	_spot(o, -4.4, -4.0, "Comprar lámpara  §45", "buy:lampara", "muebles", "Lámpara §45")
	_spot(o, 6.5, -6.0, "Comprar estantería  §90", "buy:estanteria", "muebles", "Estantería §90")
	_spot(o, 8.2, -3.4, "Comprar planta  §25", "buy:planta", "muebles", "Planta §25")
	_spot(o, 5.6, 3.0, "Comprar tele grande  §220", "buy:tele", "muebles", "Tele §220")
	_spot(o, -7.6, 4.6, "Comprar alfombra  §60", "buy:alfombra", "muebles", "Alfombra §60")
	_room_end(r)


func _int_gym(idx: int) -> void:
	var r := _room_begin("gym", "Gimnasio Titán", idx, 18.0, 14.0, Color(0.32, 0.34, 0.38), Color(0.88, 0.88, 0.9))
	var o: Vector3 = r.o
	var f = r.f
	r.g.box(Vector3(0, 0.6, -6.97), Vector3(15.0, 2.3, 0.05), Color.WHITE)
	for x in [-6.0, -3.5, -1.0]:
		_treadmill(f, x, -4.8, PI)
		_fcol(o, x, -4.8, 0.9, 1.9)
	for x in [4.0, 6.5]:
		_wbench(f, x, -3.5, 0.0)
		_fcol(o, x, -3.5, 2.0, 1.6)
	f.box(Vector3(8.5, FY, 2.0), Vector3(0.6, 1.0, 3.0), C_DARK)
	for k in 6:
		f.sphere(Vector3(8.4, FY + 1.1, 0.8 + k * 0.48), Vector3(0.14, 0.14, 0.18), Color(0.1, 0.1, 0.12), 6, 4)
	_fcol(o, 8.5, 2.0, 0.7, 3.0)
	for k in 3:
		f.flat(Vector3(-5.5 + k * 2.6, FY + 0.02, 3.0), 2.2, 4.0, [Color(0.2, 0.55, 0.8), Color(0.85, 0.3, 0.4), Color(0.3, 0.7, 0.45)][k])
	f.cyl(Vector3(3.5, FY, 3.5), 0.5, 0.5, 0.08, C_DARK, 10)
	f.cyl(Vector3(3.5, FY, 3.5), 0.05, 0.05, 2.4, C_DARK, 6, false)
	f.cyl(Vector3(3.5, FY + 0.9, 3.5), 0.32, 0.32, 1.3, Color(0.75, 0.15, 0.15), 10)
	_fcol(o, 3.5, 3.5, 0.9, 0.9)
	_static(o, 0.8, 0.5, 0.0, "gym", "entrenador", "Rafa, el entrenador")
	_spot(o, -3.5, -2.8, "Correr en la cinta", "entrenar", "gym", "Cintas")
	_spot(o, 5.2, -1.6, "Levantar pesas", "pesas", "gym", "Pesas")
	_room_end(r)


func _item(id: String, o: Vector3, builder: Callable) -> void:
	var f = MB.new()
	var g = MB.new()
	f.push(o)
	g.push(o)
	builder.call(f, g)
	var nodes: Array = []
	var a = f.instance(root, mat_solid)
	if a != null:
		nodes.append(a)
	var b = g.instance(root, mat_glow, false)
	if b != null:
		nodes.append(b)
	home_items[id] = nodes


func _int_hogar(idx: int) -> void:
	var r := _room_begin("hogar", "Casa Mirasol", idx, 16.0, 12.0, Color(0.74, 0.58, 0.4), Color(0.98, 0.93, 0.8))
	var o: Vector3 = r.o
	var f = r.f
	_fridge(f, -7.2, -5.5, 0.0)
	_kitchen(f, -4.0, -5.6, 0.0, 5.0)
	_fcol(o, -4.6, -5.6, 6.6, 0.9)
	_bed(f, 5.6, -4.7, 0.0, Color(0.9, 0.6, 0.2))
	_fcol(o, 5.6, -4.7, 1.9, 2.3)
	f.box(Vector3(7.2, FY, -5.5), Vector3(0.6, 0.55, 0.5), C_WOOD)
	_table(f, 2.5, 1.6, C_WOOD.lightened(0.2), 0.8)
	_chair(f, 1.4, 1.6, PI / 2.0, C_WOOD)
	_chair(f, 3.6, 1.6, -PI / 2.0, C_WOOD)
	_fcol(o, 2.5, 1.6, 2.6, 1.3)
	r.g.box(Vector3(1.0, 1.3, -5.97), Vector3(2.6, 1.4, 0.05), Color.WHITE)
	r.sh.box(Vector3(0.6, FY, -1.0), Vector3(0.12, 3.0, 4.0), Color(0.98, 0.93, 0.8).darkened(0.08))
	_fcol(o, 0.6, -1.0, 0.3, 4.0)
	_item("silla_basica", o, func(a, _b): _chair(a, -4.2, 2.0, -PI / 2.0, Color(0.5, 0.5, 0.45)))
	_item("tele_basica", o, func(a, _b): _tv(a, -7.4, 2.0, PI / 2.0, 0.8))
	_item("sofa", o, func(a, _b): _sofa(a, -4.0, 2.0, -PI / 2.0, Color(0.85, 0.35, 0.3)))
	_item("tele", o, func(a, _b): _tv(a, -7.4, 2.0, PI / 2.0, 1.7))
	_item("lampara", o, func(a, b): _floor_lamp(a, b, -7.2, 4.8))
	_item("planta", o, func(a, _b): _plant(a, 7.0, 4.8, 1.3))
	_item("alfombra", o, func(a, _b): _rug(a, -5.6, 2.0, 3.6, 3.0, Color(0.3, 0.55, 0.4)))
	_item("estanteria", o, func(a, _b): _bookcase(a, 7.7, 0.5, -PI / 2.0, 2.6))
	for id in ["sofa", "tele", "lampara", "planta", "alfombra", "estanteria"]:
		for nd in home_items[id]:
			nd.visible = false
	_spot(o, -6.6, -4.0, "Comer algo de la nevera", "nevera", "hogar", "Nevera")
	_spot(o, 3.9, -4.2, "Dormir", "dormir", "hogar", "Cama")
	_spot(o, -5.6, 3.6, "Ver la tele", "tele", "hogar", "Tele")
	_own_spot(o, 3.4, 4.4, "Mejoras de la casa", "mejoras", "hogar", "Mejoras")
	_room_end(r)


func _int_casa(kind: String, idx: int, w: float, d: float, floorc: Color, wallc: Color, sofac: Color, m: float) -> void:
	var r := _room_begin(kind, "Casa", idx, w, d, floorc, wallc)
	var o: Vector3 = r.o
	var f = r.f
	var hw := w * 0.5
	var hd := d * 0.5
	_kitchen(f, m * (hw - 3.2), -hd + 0.4, 0.0, 4.6)
	_fridge(f, m * (hw - 0.75), -hd + 1.6, -m * PI / 2.0)
	_fcol(o, m * (hw - 2.8), -hd + 0.5, 5.6, 1.0)
	_rug(f, -m * 3.0, 0.5, 4.2, 3.2, sofac.lightened(0.3))
	_sofa(f, -m * 3.0, 2.2, PI, sofac)
	_fcol(o, -m * 3.0, 2.2, 2.3, 1.0)
	_tv(f, -m * 3.0, -hd + 0.4, 0.0, 1.4)
	_fcol(o, -m * 3.0, -hd + 0.4, 2.0, 0.6)
	_table(f, m * 2.6, 1.6, C_WOOD.lightened(0.15), 0.75)
	_chair(f, m * 2.6 - 1.05, 1.6, PI / 2.0, C_WOOD)
	_chair(f, m * 2.6 + 1.05, 1.6, -PI / 2.0, C_WOOD)
	_fcol(o, m * 2.6, 1.6, 2.6, 1.3)
	_bookcase(f, -m * (hw - 0.25), 0.0, m * PI / 2.0, 2.4)
	_fcol(o, -m * (hw - 0.3), 0.0, 0.6, 2.4)
	_plant(f, m * (hw - 0.7), hd - 0.8, 1.2)
	_floor_lamp(f, r.g, -m * (hw - 0.8), hd - 0.8)
	r.g.box(Vector3(0, 1.3, -hd + 0.03), Vector3(2.2, 1.3, 0.05), Color.WHITE)
	_static(o, m * 0.6, -0.9, 0.0, kind, "host", "vecino")
	_own_spot(o, m * (hw - 2.3), -hd + 2.3, "Comer algo de la nevera", "nevera", kind)
	_own_spot(o, -m * 3.0, 0.6, "Ver la tele", "tele", kind)
	_own_spot(o, -m * 4.9, 2.9, "Dormir en el sofá", "dormir", kind)
	_own_spot(o, 3.4, hd - 1.6, "Mejoras de la casa", "mejoras", kind)
	_room_end(r)


func _own_spot(o: Vector3, x: float, z: float, label: String, id: String, kind: String, tag: String = "") -> void:
	_spot(o, x, z, label, id, kind, tag)
	spots[spots.size() - 1]["own"] = true


func _light_pools() -> void:
	var v := PackedVector3Array()
	var cl := PackedColorArray()
	var seg := 14
	for lp in lamps:
		var p: Vector3 = lp
		var cen := Vector3(p.x, 0.22, p.z)
		for i in seg:
			var a0 := TAU * float(i) / float(seg)
			var a1 := TAU * float(i + 1) / float(seg)
			v.append(cen)
			v.append(cen + Vector3(cos(a0), 0, sin(a0)) * 8.0)
			v.append(cen + Vector3(cos(a1), 0, sin(a1)) * 8.0)
			cl.append(Color(1, 1, 1))
			cl.append(Color(0, 0, 0))
			cl.append(Color(0, 0, 0))
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_COLOR] = cl
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, mat_pool)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


# ---------------------------------------------------------------- gasolinera y taller

func _gas(s, g, c: Vector3) -> void:
	var red := Color(0.8, 0.14, 0.12)
	var white := Color(0.93, 0.93, 0.91)
	# tienda
	var sp := Vector3(c.x - 9.0, 0.16, c.z - 12.0)
	s.m = 0.2
	s.box(sp, Vector3(16, 4.2, 9), white)
	s.m = 0.3
	s.box(sp, Vector3(16.14, 0.8, 9.14), Color(0.45, 0.3, 0.26))
	s.m = 1.0
	s.box(sp + Vector3(0, 4.2, 0), Vector3(16.5, 0.5, 9.5), red)
	var fz := sp.z + 4.5
	for sx in [-1.0, 1.0]:
		s.box(Vector3(sp.x + sx * 4.6, 0.8, fz + 0.02), Vector3(5.6, 2.5, 0.08), C_DARK)
		g.m = 0.5
		g.box(Vector3(sp.x + sx * 4.6, 0.92, fz + 0.04), Vector3(5.2, 2.2, 0.1), Color.WHITE)
	s.box(Vector3(sp.x, 0.16, fz + 0.02), Vector3(2.5, 2.9, 0.08), C_DARK)
	g.box(Vector3(sp.x, 0.16, fz + 0.05), Vector3(2.1, 2.7, 0.1), Color.WHITE)
	g.m = 1.0
	_label("Tienda 24 h", Vector3(sp.x, 3.75, fz + 0.12), 0.009, Color(1, 1, 1))
	add_col(sp.x, sp.z, 16, 9)
	buildings.append([Rect2(sp.x - 8.5, sp.z - 5.0, 17, 10), 5.5])
	doors.append({"pos": Vector3(sp.x, 0, fz + 1.2), "dir": Vector3(0, 0, 1), "kind": "gasolinera", "name": "Tienda de la gasolinera"})
	# taller
	var tp := Vector3(c.x + 12.0, 0.16, c.z - 12.0)
	s.m = 0.3
	s.box(tp, Vector3(13, 5.0, 10), Color(0.5, 0.52, 0.56))
	s.m = 1.0
	s.box(tp + Vector3(0, 5.0, 0), Vector3(13.4, 0.4, 10.4), Color(0.95, 0.75, 0.1))
	for sx in [-1.0, 1.0]:
		s.box(Vector3(tp.x + sx * 3.1, 0.16, tp.z + 5.03), Vector3(5.2, 3.6, 0.08), Color(0.08, 0.08, 0.1))
		for k in 5:
			s.box(Vector3(tp.x + sx * 3.1, 0.5 + k * 0.7, tp.z + 5.07), Vector3(5.2, 0.06, 0.04), Color(0.3, 0.3, 0.33))
	_label("TALLER", Vector3(tp.x, 4.45, tp.z + 5.1), 0.014, Color(1, 0.9, 0.3))
	add_col(tp.x, tp.z, 13, 10)
	buildings.append([Rect2(tp.x - 7.0, tp.z - 5.5, 14, 11), 6.0])
	taller_pos = Vector3(tp.x, 0, tp.z + 9.5)
	s.flat(Vector3(tp.x, 0.175, tp.z + 9.5), 7.0, 5.0, Color(0.95, 0.78, 0.1))
	s.flat(Vector3(tp.x, 0.18, tp.z + 9.5), 6.4, 4.4, Color(0.3, 0.3, 0.32))
	_label("Mejoras y reparación", Vector3(tp.x, 2.6, tp.z + 9.5), 0.007, Color(1, 0.9, 0.3), true)
	# marquesina y surtidores
	var cp := Vector3(c.x - 4.0, 0.16, c.z + 10.0)
	s.box(cp + Vector3(0, 5.0, 0), Vector3(24, 0.7, 11), white, true)
	s.box(cp + Vector3(0, 5.05, 5.52), Vector3(24, 0.6, 0.06), red)
	s.box(cp + Vector3(0, 5.05, -5.52), Vector3(24, 0.6, 0.06), red)
	for k in 6:
		g.box(cp + Vector3(-10.0 + k * 4.0, 4.93, 0), Vector3(1.6, 0.06, 0.8), Color.WHITE)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var pl := cp + Vector3(sx * 10.5, 0, sz * 4.0)
			s.box(pl, Vector3(0.5, 5.0, 0.5), Color(0.8, 0.8, 0.82))
			add_col(pl.x, pl.z, 0.5, 0.5)
		var isl := cp + Vector3(sx * 5.0, 0, 0)
		s.box(isl, Vector3(1.4, 0.22, 5.0), C_STONE)
		for pz in [-1.3, 1.3]:
			s.box(isl + Vector3(0, 0.22, pz), Vector3(0.9, 1.7, 0.6), red)
			s.box(isl + Vector3(0, 1.25, pz + 0.31), Vector3(0.6, 0.4, 0.03), Color(0.1, 0.12, 0.15))
			s.box(isl + Vector3(0, 1.25, pz - 0.31), Vector3(0.6, 0.4, 0.03), Color(0.1, 0.12, 0.15))
			s.box(isl + Vector3(0, 1.92, pz), Vector3(1.0, 0.16, 0.7), white)
		add_col(isl.x, isl.z, 1.4, 5.0)
	_label("Gasolinera Ruta 7", cp + Vector3(0, 5.37, 5.57), 0.013, Color(1, 1, 1))
	var pole := Vector3(c.x + 19.5, 0.16, c.z + 19.5)
	s.box(pole, Vector3(0.4, 7.0, 0.4), Color(0.8, 0.8, 0.82))
	s.box(pole + Vector3(0, 4.6, 0), Vector3(3.0, 2.6, 0.5), red, true)
	_label("RUTA 7", pole + Vector3(0, 6.3, 0.27), 0.011, Color(1, 1, 1))
	_label("Sin plomo 1,48", pole + Vector3(0, 5.4, 0.27), 0.006, Color(1, 0.95, 0.6))
	add_col(pole.x, pole.z, 0.6, 0.6)
	for sx in [-18.0, 6.0]:
		_tree(s, Vector3(c.x + sx, 0.16, c.z + 20.0), 0.9, 0)


func _int_gas(idx: int) -> void:
	var r := _room_begin("gasolinera", "Tienda de la gasolinera", idx, 12.0, 9.0, Color(0.72, 0.74, 0.76), Color(0.88, 0.88, 0.85), true)
	var o: Vector3 = r.o
	var f = r.f
	for k in 4:
		_fridge(f, -4.4 + k * 1.25, -4.0, 0.0)
	_fcol(o, -2.5, -4.0, 5.2, 1.0)
	_shelf(f, -2.5, -0.8, 0.0, 5.0)
	_fcol(o, -2.5, -0.8, 5.0, 1.1)
	_shelf(f, -2.5, 1.9, 0.0, 5.0)
	_fcol(o, -2.5, 1.9, 5.0, 1.1)
	_counter(f, 3.6, -1.4, PI / 2.0, 3.2, Color(0.8, 0.14, 0.12))
	f.box(Vector3(3.6, FY + 1.01, -2.2), Vector3(0.42, 0.3, 0.42), C_DARK)
	_fcol(o, 3.6, -1.4, 0.9, 3.2)
	_plant(f, 5.2, 3.6)
	r.g.box(Vector3(2.5, 2.0, -4.47), Vector3(4.0, 0.5, 0.05), Color.WHITE)
	_static(o, 4.9, -1.4, -PI / 2.0, "gasolinera", "cajero", "Toño, el de la gasolinera")
	_spot(o, -2.5, 0.55, "Comprar un bocadillo  §6", "snack", "gasolinera", "Snacks")
	_room_end(r)


func _int_banco(idx: int) -> void:
	var r := _room_begin("banco", "Banco Mirasol", idx, 18.0, 12.0, Color(0.78, 0.76, 0.72), Color(0.9, 0.89, 0.85), true)
	var o: Vector3 = r.o
	var f = r.f
	var green := Color(0.12, 0.3, 0.22)
	_counter(f, 0.0, -2.4, 0.0, 13.0, green)
	_fcol(o, 0.0, -2.4, 13.0, 0.9)
	for k in 4:
		r.g.box(Vector3(-4.8 + k * 3.2, FY + 1.05, -2.4), Vector3(2.6, 1.0, 0.05), Color.WHITE)
		f.box(Vector3(-6.4 + k * 3.2, FY + 1.0, -2.4), Vector3(0.1, 1.1, 0.5), C_DARK)
	f.box(Vector3(6.4, FY + 1.0, -2.4), Vector3(0.1, 1.1, 0.5), C_DARK)
	# cámara acorazada
	f.box(Vector3(0, FY, -5.9), Vector3(4.0, 3.0, 0.2), Color(0.42, 0.44, 0.48))
	f.push_t(Transform3D(Basis(Vector3(1, 0, 0), PI / 2.0), Vector3(0, FY + 1.5, -5.78)))
	f.m = 0.8
	f.cyl(Vector3.ZERO, 1.25, 1.25, 0.14, Color(0.62, 0.64, 0.68), 20)
	f.cyl(Vector3(0, 0.14, 0), 0.3, 0.3, 0.1, Color(0.8, 0.7, 0.3), 12)
	f.m = 1.0
	f.pop()
	f.box(Vector3(0, FY + 1.46, -5.6), Vector3(1.5, 0.08, 0.06), Color(0.8, 0.7, 0.3))
	f.box(Vector3(0, FY + 0.75, -5.6), Vector3(0.08, 1.5, 0.06), Color(0.8, 0.7, 0.3))
	_rug(f, 0.0, 2.2, 6.0, 3.6, green)
	_sofa(f, -7.2, 2.6, PI / 2.0, Color(0.3, 0.32, 0.36))
	_fcol(o, -7.2, 2.6, 1.0, 2.3)
	_plant(f, -8.0, 5.0, 1.3)
	_plant(f, 8.0, 5.0, 1.3)
	_plant(f, 8.0, -1.0, 1.1)
	for x in [-3.0, 3.0]:
		f.cyl(Vector3(x, FY, 0.4), 0.2, 0.2, 0.04, C_DARK, 8)
		f.cyl(Vector3(x, FY, 0.4), 0.03, 0.03, 0.95, Color(0.8, 0.7, 0.3), 6, false)
	f.box(Vector3(0, FY + 0.88, 0.4), Vector3(6.0, 0.06, 0.04), Color(0.6, 0.1, 0.1))
	_static(o, 0.0, -3.5, 0.0, "banco", "banquero", "Pilar, la cajera del banco")
	_static(o, 7.4, 3.0, -PI / 2.0, "banco", "guard", "Paco, el guardia")
	_room_end(r)
