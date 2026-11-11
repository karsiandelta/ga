extends Node3D
# Cielo Roto: RPG de acción 3D. Toda la escena se construye por código.

const Build = preload("res://build.gd")
const Hud = preload("res://hud.gd")
const Sh = preload("res://shaders.gd")
const GRID = 128
const CELL = 5.0
const SAVE_PATH = "user://cieloroto.json"
const CH = [95, 90, 80, 70, 60, 50, 40, 30, 22]
const SMITH = Vector2(8, -6)

var REINOS = {
	"carmesi": {"n": "Carmesí", "c": Color("8a1f1a")},
	"dorado": {"n": "Dorado", "c": Color("a07c22")},
	"azur": {"n": "Azur", "c": Color("1f4f8f")},
}
var CLASES = {
	"guerrero": {"n": "Guerrero", "d": "Espada pesada, mucha vida.", "p": "Caballero juramentado de armadura pesada. Aguanta en primera línea y parte en dos a quien se acerque.", "arma": "Mandoble", "hp": 320, "atk": 22, "def": 8, "range": 3.3, "arc": 2.3, "spd": 8.5, "cd": 0.42, "w": "sword", "ranged": false,
		"s1": {"n": "Torbellino", "t": "aoe", "r": 5.5, "m": 2.2, "cd": 6.0, "far": false},
		"s2": {"n": "Furia", "t": "buff", "k": "furia", "dur": 8.0, "cd": 20.0}},
	"asesino": {"n": "Asesino", "d": "Dagas rápidas y embestida.", "p": "Sombra del reino. Golpea más rápido que nadie, atraviesa a sus enemigos y desaparece.", "arma": "Dagas gemelas", "hp": 240, "atk": 25, "def": 5, "range": 2.8, "arc": 2.0, "spd": 10.0, "cd": 0.28, "w": "dagger", "ranged": false,
		"s1": {"n": "Tajo", "t": "dash", "len": 9.0, "m": 2.6, "cd": 5.0},
		"s2": {"n": "Sigilo", "t": "buff", "k": "crit", "dur": 6.0, "cd": 18.0}},
	"mago": {"n": "Mago", "d": "Proyectiles y meteoros.", "p": "Arcanista del tomo vivo. Castiga a distancia con proyectiles y hace caer meteoros.", "arma": "Báculo arcano", "hp": 200, "atk": 30, "def": 4, "range": 16.0, "arc": 0.0, "spd": 8.0, "cd": 0.5, "w": "staff", "ranged": true,
		"s1": {"n": "Meteoro", "t": "aoe", "r": 6.0, "m": 3.0, "cd": 7.0, "far": true},
		"s2": {"n": "Escudo", "t": "buff", "k": "escudo", "dur": 8.0, "cd": 20.0}},
	"chaman": {"n": "Chamán", "d": "Rayos en cadena y curación.", "p": "Portavoz de los espíritus. Encadena rayos entre enemigos y cura sus propias heridas.", "arma": "Bastón de calavera", "hp": 260, "atk": 21, "def": 6, "range": 13.0, "arc": 0.0, "spd": 8.5, "cd": 0.45, "w": "staff", "ranged": true,
		"s1": {"n": "Rayo", "t": "chain", "m": 2.0, "cd": 6.0},
		"s2": {"n": "Curar", "t": "heal", "cd": 16.0}},
}
var TIPOS = {
	"lobo": {"n": "Huargo", "hp": 0.8, "dmg": 0.8, "spd": 6.5, "range": 2.0, "quad": true, "col": Color("353540"), "s": 0.9, "ghost": false, "boss": false},
	"jabali": {"n": "Jabalí corrupto", "hp": 1.3, "dmg": 1.0, "spd": 5.5, "range": 2.2, "quad": true, "col": Color("4a372c"), "s": 1.15, "ghost": false, "boss": false},
	"bandido": {"n": "Esqueleto", "hp": 1.0, "dmg": 1.1, "spd": 6.0, "range": 2.3, "quad": false, "col": Color("4a4038"), "s": 1.0, "ghost": false, "boss": false},
	"tigre": {"n": "Bestia de ceniza", "hp": 1.4, "dmg": 1.4, "spd": 7.5, "range": 2.4, "quad": true, "col": Color("3a3432"), "s": 1.3, "ghost": false, "boss": false},
	"espectro": {"n": "Espectro", "hp": 1.1, "dmg": 1.2, "spd": 6.2, "range": 2.3, "quad": false, "col": Color("8fd8c8"), "s": 1.0, "ghost": true, "boss": false},
	"jefe": {"n": "Señor de Ceniza", "hp": 30.0, "dmg": 1.6, "spd": 5.2, "range": 4.0, "quad": false, "col": Color("2a1a18"), "s": 2.6, "ghost": false, "boss": true},
}

var S = {}
var running = false
var time = 0.0
var spawn_t = 0.0
var save_t = 0.0

# jugador
var px = 0.0
var pz = 6.0
var pang = PI
var php = 1.0
var pmaxhp = 1
var patk = 1.0
var pdef = 0.0
var atk_t = 0.0
var swing = 0.0
var cd1 = 0.0
var cd2 = 0.0
var pot_t = 0.0
var buff = {"furia": 0.0, "crit": 0.0, "escudo": 0.0}
var mounted = false
var dead_t = 0.0
var moving = false
var combat_t = 0.0
var pg: Node3D
var pm = {}
var ph = {}

# entrada (la rellena el HUD)
var jx = 0.0
var jy = 0.0
var inp_atk = false
var cam_yaw = 0.0
var cam_pitch = 0.5
var cam_dist = 12.0
var cam: Camera3D
var cam_t = Vector3(0, 1.5, 0)

var enemies = []
var stones = []
var items = []
var projs = []
var fx = []
var parts = []
var p_idx = 0
var nums = []
var n_idx = 0
var colliders = []
var boss = null
var telegraph = null
var mark: MeshInstance3D
var bar_mat_r: StandardMaterial3D
var bar_mat_b: StandardMaterial3D
var hud
var hdata = PackedFloat32Array()
var noise_tex: NoiseTexture2D
var hmap_tex: ImageTexture
var grass_mat: ShaderMaterial
var shot_dir = ""
var ash: CPUParticles3D
var preview = null
var preview_light: OmniLight3D
var STYLES = {"guerrero": "knight", "asesino": "rogue", "mago": "mage", "chaman": "shaman"}
const PV = Vector3(3.0, 0.0, 8.0)
var fires = []

var test_mode = false
var test_f = 0


func _ready() -> void:
	randomize()
	build_noise()
	build_height()
	build_env()
	build_terrain()
	build_water()
	build_props()
	build_grass()
	build_village()
	bar_mat_r = bar_material(Color("cf4a40"))
	bar_mat_b = bar_material(Color("63c4a4"))
	pg = Node3D.new()
	add_child(pg)
	for i in range(80):
		var mi = Build.box(self, Vector3(0.2, 0.2, 0.2), Build.flat(Color.WHITE), Vector3.ZERO)
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parts.append({"n": mi, "life": 0.0, "v": Vector3.ZERO})
	for i in range(20):
		var l = Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.font_size = 72
		l.pixel_size = 0.011
		l.outline_size = 16
		l.visible = false
		add_child(l)
		nums.append({"n": l, "life": 0.0})
	cam = Camera3D.new()
	cam.fov = 58.0
	cam.far = 700.0
	cam.near = 0.3
	add_child(cam)
	cam.make_current()
	var layer = CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.game = self
	layer.add_child(hud)
	S = new_state("carmesi", "guerrero")
	test_mode = OS.has_environment("CR_TEST")


func new_state(reino: String, clase: String) -> Dictionary:
	return {"reino": reino, "clase": clase, "lvl": 1, "xp": 0, "gold": 0, "pm": 0, "pots": 5, "wpn": 0, "arm": 0, "dest": 0, "boss": 0}


func save_game() -> void:
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(S))
		f.close()


func load_save():
	if not FileAccess.file_exists(SAVE_PATH):
		return null
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return null
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) != TYPE_DICTIONARY:
		return null
	if not CLASES.has(d.get("clase", "")) or not REINOS.has(d.get("reino", "")):
		return null
	for k in ["lvl", "xp", "gold", "pm", "pots", "wpn", "arm", "dest", "boss"]:
		d[k] = int(d.get(k, 0))
	d["lvl"] = max(1, d["lvl"])
	return d


# ---------- mundo ----------

func build_noise() -> void:
	var n = FastNoiseLite.new()
	n.seed = 3
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.012
	n.fractal_octaves = 4
	noise_tex = NoiseTexture2D.new()
	noise_tex.width = 256
	noise_tex.height = 256
	noise_tex.seamless = true
	noise_tex.generate_mipmaps = true
	noise_tex.noise = n


func build_height() -> void:
	var noise = FastNoiseLite.new()
	noise.seed = 11
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.007
	noise.fractal_octaves = 4
	var n1 = GRID + 1
	hdata.resize(n1 * n1)
	var img = Image.create(n1, n1, false, Image.FORMAT_RH)
	for j in range(n1):
		for i in range(n1):
			var x = -320.0 + i * CELL
			var z = -320.0 + j * CELL
			var d = Vector2(x, z).length()
			var h = noise.get_noise_2d(x, z) * 13.0
			h = max(h, -3.2)
			h *= smoothstep(27.0, 70.0, d)
			h = lerp(1.5, h, smoothstep(16.0, 45.0, Vector2(x, z + 215.0).length()))
			h = lerp(h, -3.2, smoothstep(293.0, 316.0, d))
			hdata[j * n1 + i] = h
			img.set_pixel(i, j, Color(h, 0, 0))
	hmap_tex = ImageTexture.create_from_image(img)


func ground_h(x: float, z: float) -> float:
	var gx = clamp((x + 320.0) / CELL, 0.0, GRID - 0.001)
	var gz = clamp((z + 320.0) / CELL, 0.0, GRID - 0.001)
	var ix = int(gx)
	var iz = int(gz)
	var tx = gx - ix
	var tz = gz - iz
	var n1 = GRID + 1
	var a = hdata[iz * n1 + ix]
	var b = hdata[iz * n1 + ix + 1]
	var c = hdata[(iz + 1) * n1 + ix]
	var d = hdata[(iz + 1) * n1 + ix + 1]
	return lerp(lerp(a, b, tx), lerp(c, d, tx), tz)


func at(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, ground_h(x, z) + y, z)


func build_env() -> void:
	var env = Environment.new()
	var sky = Sky.new()
	sky.sky_material = Sh.mat(Sh.SKY, {"noise_tex": noise_tex})
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("6c7c9a")
	env.ambient_light_energy = 1.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.3
	env.tonemap_white = 4.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color("3a4550")
	env.fog_density = 0.008
	env.fog_sky_affect = 0.25
	env.fog_aerial_perspective = 0.3
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.92
	env.adjustment_contrast = 1.1
	var we = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon = DirectionalLight3D.new()
	moon.light_color = Color("a9c0e8")
	moon.light_energy = 3.0
	moon.shadow_enabled = true
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	moon.directional_shadow_max_distance = 80.0
	moon.shadow_blur = 1.5
	moon.rotation_degrees = Vector3(-34, 128, 0)
	add_child(moon)
	ash = CPUParticles3D.new()
	ash.amount = 140
	ash.lifetime = 6.0
	ash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ash.emission_box_extents = Vector3(24, 7, 24)
	ash.direction = Vector3(0, -1, 0)
	ash.spread = 35.0
	ash.gravity = Vector3(0.5, -0.35, 0.2)
	ash.initial_velocity_min = 0.2
	ash.initial_velocity_max = 0.8
	ash.scale_amount_min = 0.5
	ash.scale_amount_max = 1.4
	var q = QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	var am = Build.flat(Color("b9b4ac"), 0.7)
	am.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = am
	ash.mesh = q
	ash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ash)


func build_terrain() -> void:
	var n1 = GRID + 1
	var verts = PackedVector3Array()
	var norms = PackedVector3Array()
	var idx = PackedInt32Array()
	verts.resize(n1 * n1)
	norms.resize(n1 * n1)
	for j in range(n1):
		for i in range(n1):
			var k = j * n1 + i
			verts[k] = Vector3(-320.0 + i * CELL, hdata[k], -320.0 + j * CELL)
			var hl = hdata[j * n1 + max(i - 1, 0)]
			var hr = hdata[j * n1 + min(i + 1, GRID)]
			var hu = hdata[max(j - 1, 0) * n1 + i]
			var hd = hdata[min(j + 1, GRID) * n1 + i]
			norms[k] = Vector3(hl - hr, 2.0 * CELL, hu - hd).normalized()
	for j in range(GRID):
		for i in range(GRID):
			var a = j * n1 + i
			var b = a + 1
			var c = a + n1
			var d = c + 1
			idx.append(a)
			idx.append(b)
			idx.append(c)
			idx.append(b)
			idx.append(d)
			idx.append(c)
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = idx
	var am = ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi = MeshInstance3D.new()
	mi.mesh = am
	mi.material_override = Sh.mat(Sh.TERRAIN, {"noise_tex": noise_tex})
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func build_water() -> void:
	var pmesh = PlaneMesh.new()
	pmesh.size = Vector2(3000, 3000)
	var mi = MeshInstance3D.new()
	mi.mesh = pmesh
	mi.material_override = Sh.mat(Sh.WATER, {"noise_tex": noise_tex})
	mi.position = Vector3(0, -2.0, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func build_grass() -> void:
	var verts = PackedVector3Array([Vector3(-0.04, 0, 0), Vector3(0.04, 0, 0), Vector3(-0.027, 0.3, 0), Vector3(0.027, 0.3, 0), Vector3(0, 0.62, 0)])
	var uvs = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(0, 0.5), Vector2(1, 0.5), Vector2(0.5, 1)])
	var idx = PackedInt32Array([0, 1, 2, 1, 3, 2, 2, 3, 4])
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var am = ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	grass_mat = Sh.mat(Sh.GRASS, {"noise_tex": noise_tex, "hmap": hmap_tex, "player_pos": Vector3.ZERO})
	am.surface_set_material(0, grass_mat)
	var count = 30000
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = am
	mm.instance_count = count
	for i in range(count):
		var b = Basis(Vector3.UP, randf() * TAU).scaled(Vector3(randf_range(0.8, 1.5), randf_range(0.5, 1.25), 1.0))
		mm.set_instance_transform(i, Transform3D(b, Vector3(randf_range(-35.0, 35.0), 0, randf_range(-35.0, 35.0))))
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-400, -30, -400), Vector3(800, 90, 800))
	add_child(mmi)


func multimesh(mesh: Mesh, count: int, colors: bool) -> MultiMesh:
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = mesh
	mm.instance_count = count
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	return mm


func build_props() -> void:
	var n = 230
	var trunk_mesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.13
	trunk_mesh.bottom_radius = 0.4
	trunk_mesh.height = 3.6
	trunk_mesh.radial_segments = 7
	trunk_mesh.material = Build.mat(Color("2a211b"))
	var branch_mesh = CylinderMesh.new()
	branch_mesh.top_radius = 0.02
	branch_mesh.bottom_radius = 0.1
	branch_mesh.height = 2.0
	branch_mesh.radial_segments = 5
	branch_mesh.material = Build.mat(Color("2a211b"))
	var top_mesh = SphereMesh.new()
	top_mesh.radius = 1.5
	top_mesh.height = 3.0
	top_mesh.radial_segments = 14
	top_mesh.rings = 8
	top_mesh.material = Sh.mat(Sh.BLOB, {"noise_tex": noise_tex, "sway": 0.12, "bump": 1.1})
	var trunks = multimesh(trunk_mesh, n, false)
	var branches = multimesh(branch_mesh, n * 5, false)
	var tops = multimesh(top_mesh, n * 3, true)
	for i in range(n):
		var x = 0.0
		var z = 0.0
		var ok = false
		while not ok:
			x = randf_range(-290, 290)
			z = randf_range(-290, 290)
			var r = Vector2(x, z).length()
			ok = r > 34.0 and r < 288.0 and ground_h(x, z) > -1.4 and (abs(x) > 7.0 or z > -20.0) and Vector2(x, z + 215.0).length() > 24.0 and Vector2(x + 36.0, z - 4.0).length() > 11.0
		var s = randf_range(0.8, 1.7)
		var gy = ground_h(x, z)
		var lean = Basis(Vector3(1, 0, 0), randf_range(-0.12, 0.12)).rotated(Vector3.UP, randf() * TAU)
		trunks.set_instance_transform(i, Transform3D(lean.scaled(Vector3(s, s, s)), Vector3(x, gy + 1.7 * s, z)))
		var top_p = Vector3(x, gy + 3.3 * s, z)
		for j in range(5):
			var bb = Basis(Vector3(1, 0, 0), randf_range(0.5, 1.2)).rotated(Vector3.UP, j * 1.26 + randf_range(-0.4, 0.4))
			var bl = s * randf_range(0.7, 1.2)
			bb = bb.scaled(Vector3(s, bl, s))
			var base_p = top_p - Vector3(0, randf_range(0.0, 1.2) * s, 0)
			branches.set_instance_transform(i * 5 + j, Transform3D(bb, base_p + bb * Vector3(0, 1.0, 0)))
		var k = randf()
		var bare = k < 0.38
		var c = Color.from_hsv(randf_range(0.27, 0.40), 0.5, randf_range(0.22, 0.34))
		if k > 0.85:
			c = Color.from_hsv(randf_range(0.98, 1.0), 0.85, 0.5)
		elif k > 0.75:
			c = Color.from_hsv(0.08, 0.2, 0.42)
		for j in range(3):
			var off = Vector3(randf_range(-0.9, 0.9), randf_range(-0.4, 0.7), randf_range(-0.9, 0.9)) * s
			if j == 0:
				off = Vector3.ZERO
			var bs = s * (1.0 if j == 0 else randf_range(0.55, 0.8))
			if bare:
				bs = 0.001
			tops.set_instance_transform(i * 3 + j, Transform3D(Basis(Vector3.UP, randf() * TAU).scaled(Vector3(bs, bs * 0.8, bs)), Vector3(x, gy + 3.9 * s, z) + off))
			tops.set_instance_color(i * 3 + j, c * randf_range(0.85, 1.1))
		colliders.append({"x": x, "z": z, "r": 0.5 * s, "stone": false})
	var rn = 90
	var rock_mesh = SphereMesh.new()
	rock_mesh.radius = 1.0
	rock_mesh.height = 2.0
	rock_mesh.radial_segments = 12
	rock_mesh.rings = 7
	rock_mesh.material = Sh.mat(Sh.BLOB, {"noise_tex": noise_tex, "sway": 0.0, "bump": 0.8})
	var rocks = multimesh(rock_mesh, rn, true)
	for i in range(rn):
		var x = 0.0
		var z = 0.0
		while Vector2(x, z).length() < 32.0 or (abs(x) < 6.0 and z < -20.0):
			x = randf_range(-285, 285)
			z = randf_range(-285, 285)
		var s = randf_range(0.6, 2.4)
		var b = Basis(Vector3(1, 0, 0), randf() * 3.0).rotated(Vector3.UP, randf() * 3.0).scaled(Vector3(s, s * 0.75, s))
		rocks.set_instance_transform(i, Transform3D(b, Vector3(x, ground_h(x, z) + s * 0.25, z)))
		var g = randf_range(0.28, 0.4)
		rocks.set_instance_color(i, Color(g, g, g * 1.1))
		if s > 1.1:
			colliders.append({"x": x, "z": z, "r": s * 0.85, "stone": false})
	# ruinas dispersas
	var stone_m = Build.mat(Color("74747c"))
	for i in range(16):
		var a = randf() * TAU
		var d = randf_range(55.0, 260.0)
		var cx = cos(a) * d
		var cz = sin(a) * d
		if ground_h(cx, cz) < -1.0 or (abs(cx) < 10.0 and cz < 0.0):
			continue
		var cnt = 4 + randi() % 4
		for j in range(cnt):
			var pa = j / float(cnt) * TAU
			var x2 = cx + cos(pa) * 5.0
			var z2 = cz + sin(pa) * 5.0
			var h = randf_range(1.0, 5.5)
			var col = Build.cyl(self, 0.42, 0.5, h, stone_m, at(x2, h / 2.0 - 0.2, z2), 10)
			col.rotation.z = randf_range(-0.08, 0.08)
			Build.box(self, Vector3(1.2, 0.3, 1.2), stone_m, at(x2, 0.1, z2))
			if h > 4.0:
				Build.box(self, Vector3(1.1, 0.3, 1.1), stone_m, at(x2, h - 0.1, z2))
			colliders.append({"x": x2, "z": z2, "r": 0.7, "stone": false})
		var fallen = Build.cyl(self, 0.42, 0.42, 3.5, stone_m, at(cx + 1.0, 0.35, cz), 10)
		fallen.rotation = Vector3(PI / 2.0, randf() * 3.0, 0)
	# cementerio al oeste de la aldea
	var grave_m = Build.mat(Color("6c6d75"))
	for i in range(22):
		var gx = -36.0 + (i % 6) * 2.6 - 6.0 + randf_range(-0.4, 0.4)
		var gz = 4.0 + int(i / 6.0) * 3.2 - 5.0 + randf_range(-0.4, 0.4)
		var gp = at(gx, 0.0, gz)
		var gn = Node3D.new()
		gn.position = gp
		gn.rotation = Vector3(randf_range(-0.12, 0.12), PI / 2.0 + randf_range(-0.2, 0.2), randf_range(-0.15, 0.15))
		add_child(gn)
		if i % 3 == 0:
			Build.box(gn, Vector3(0.16, 1.5, 0.14), grave_m, Vector3(0, 0.7, 0))
			Build.box(gn, Vector3(0.7, 0.16, 0.14), grave_m, Vector3(0, 1.05, 0))
		else:
			Build.box(gn, Vector3(0.7, 0.9, 0.16), grave_m, Vector3(0, 0.4, 0))
			var topc = Build.cyl(gn, 0.35, 0.35, 0.16, grave_m, Vector3(0, 0.85, 0), 12)
			topc.rotation.x = PI / 2.0
		Build.box(gn, Vector3(0.8, 0.12, 1.7), Build.mat(Color("15120f")), Vector3(0, 0.02, 0.95))
	for k2 in [-1.0, 1.0]:
		Build.cyl(self, 0.06, 0.08, 2.6, Build.mat(Color("0b0a0c")), at(-36.0 + k2 * 9.0, 1.3, 13.0), 6)
		Build.sphere(self, 0.16, Build.glow(Color("7dffd0"), 3.0), at(-36.0 + k2 * 9.0, 2.7, 13.0), 8)


func sparks(parent: Node3D, pos: Vector3, col: Color, amount: int, radius: float) -> void:
	var cp = CPUParticles3D.new()
	cp.amount = amount
	cp.lifetime = 2.2
	cp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	cp.emission_sphere_radius = radius
	cp.direction = Vector3.UP
	cp.spread = 25.0
	cp.gravity = Vector3(0, 1.4, 0)
	cp.initial_velocity_min = 0.4
	cp.initial_velocity_max = 1.6
	cp.scale_amount_min = 0.5
	cp.scale_amount_max = 1.3
	var q = QuadMesh.new()
	q.size = Vector2(0.14, 0.14)
	var pmat = Build.flat(col, 1.0, true)
	pmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = pmat
	cp.mesh = q
	cp.position = pos
	cp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(cp)


func house(x: float, z: float, w: float, rot: float, kind: int) -> void:
	var stone = Build.mat(Color("5c5c63"))
	var plaster = Build.mat(Color("7a7468"))
	if kind == 2:
		plaster = Build.mat(Color("6a6b73"))
	var timber = Build.mat(Color("211914"))
	var slate = Build.mat(Color("2c3038"))
	var d = w * 0.8
	var g = Node3D.new()
	g.position = at(x, 0.0, z)
	g.rotation.y = rot
	add_child(g)
	var wall_h = 2.8
	if kind >= 1:
		wall_h = 5.0
	Build.box(g, Vector3(w + 0.3, 0.8, d + 0.3), stone, Vector3(0, 0.4, 0))
	Build.box(g, Vector3(w, wall_h, d), plaster, Vector3(0, 0.8 + wall_h / 2.0, 0))
	var top_y = 0.8 + wall_h
	# entramado de madera
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Build.box(g, Vector3(0.24, wall_h, 0.24), timber, Vector3(sx * w * 0.5, 0.8 + wall_h / 2.0, sz * d * 0.5))
	for sz in [-1.0, 1.0]:
		Build.box(g, Vector3(w + 0.2, 0.2, 0.2), timber, Vector3(0, top_y, sz * d * 0.5))
		Build.box(g, Vector3(w + 0.2, 0.18, 0.2), timber, Vector3(0, 0.9, sz * d * 0.5))
		if kind >= 1:
			Build.box(g, Vector3(w + 0.5, 0.22, 0.3), timber, Vector3(0, 3.4, sz * d * 0.5))
	if kind != 2:
		for sx in [-1.0, 1.0]:
			var br = Build.box(g, Vector3(0.14, 2.3, 0.1), timber, Vector3(sx * w * 0.36, top_y - 1.0, d * 0.5 + 0.02))
			br.rotation.z = sx * 0.55
	# puerta y ventanas
	Build.box(g, Vector3(1.2, 2.1, 0.12), Build.mat(Color("1d140f")), Vector3(0, 1.85, d * 0.5 + 0.03))
	Build.box(g, Vector3(1.3, 0.1, 0.16), Build.metal(Color("2a2a2e")), Vector3(0, 2.3, d * 0.5 + 0.05))
	Build.box(g, Vector3(1.3, 0.1, 0.16), Build.metal(Color("2a2a2e")), Vector3(0, 1.4, d * 0.5 + 0.05))
	var win = Build.glow(Color("e07a2a"), 1.6)
	if kind == 2:
		win = Build.glow(Color("8a2a2a"), 2.2)
	var wy = 2.2
	if kind >= 1:
		wy = 4.4
	for sx in [-1.0, 1.0]:
		Build.box(g, Vector3(0.7, 1.0 if kind != 2 else 1.8, 0.06), win, Vector3(sx * w * 0.3, wy, d * 0.5 + 0.02))
		Build.box(g, Vector3(0.8, 0.07, 0.1), timber, Vector3(sx * w * 0.3, wy, d * 0.5 + 0.04))
		Build.box(g, Vector3(0.07, 1.1 if kind != 2 else 1.9, 0.1), timber, Vector3(sx * w * 0.3, wy, d * 0.5 + 0.04))
	# tejado a dos aguas muy inclinado
	var roof_h = w * 0.85
	Build.prism(g, Vector3(w + 0.9, roof_h, d + 0.9), slate, Vector3(0, top_y + roof_h / 2.0, 0))
	Build.box(g, Vector3(0.16, 0.16, d + 1.1), timber, Vector3(0, top_y + roof_h, 0))
	Build.box(g, Vector3(0.5, 0.6, 0.06), win, Vector3(0, top_y + roof_h * 0.32, d * 0.5 + 0.47))
	# chimenea con humo
	Build.box(g, Vector3(0.7, roof_h + 1.0, 0.7), stone, Vector3(-w * 0.3, top_y + roof_h * 0.5, -d * 0.2))
	sparks(g, Vector3(-w * 0.3, top_y + roof_h + 1.2, -d * 0.2), Color("3a3a3e"), 10, 0.3)
	if kind == 2:
		# torre con aguja
		Build.box(g, Vector3(2.4, 9.5, 2.4), plaster, Vector3(w * 0.5 - 0.6, 4.75, d * 0.5 + 0.6))
		Build.box(g, Vector3(2.7, 0.3, 2.7), stone, Vector3(w * 0.5 - 0.6, 9.5, d * 0.5 + 0.6))
		var spire = Build.cyl(g, 0.0, 1.9, 5.0, slate, Vector3(w * 0.5 - 0.6, 12.1, d * 0.5 + 0.6), 4)
		spire.rotation.y = PI / 4.0
		Build.cyl(g, 0.0, 0.08, 1.0, Build.metal(Color("2a2a2e")), Vector3(w * 0.5 - 0.6, 15.0, d * 0.5 + 0.6), 5)
		Build.box(g, Vector3(0.6, 1.6, 0.06), win, Vector3(w * 0.5 - 0.6, 7.6, d * 0.5 + 1.82))
		Build.sphere(g, 0.5, Build.metal(Color("3a332a"), 0.6), Vector3(w * 0.5 - 0.6, 8.6, d * 0.5 + 0.6), 10)
	colliders.append({"x": x, "z": z, "r": w * 0.62, "stone": false})


func brazier(x: float, z: float, h: float, energy: float) -> void:
	var iron = Build.metal(Color("1c1c20"), 0.6)
	Build.cyl(self, 0.07, 0.12, h, iron, at(x, h / 2.0, z), 6)
	Build.cyl(self, 0.42, 0.2, 0.3, iron, at(x, h + 0.15, z), 8)
	Build.cyl(self, 0.0, 0.3, 0.8, Build.glow(Color("ff7a1e"), 4.0), at(x, h + 0.65, z), 6)
	sparks(self, at(x, h + 0.7, z), Color("ffa040"), 14, 0.25)
	var l = OmniLight3D.new()
	l.light_color = Color("ff8a3a")
	l.light_energy = energy
	l.omni_range = 16.0
	l.omni_attenuation = 1.2
	l.position = at(x, h + 1.0, z)
	add_child(l)
	fires.append({"l": l, "e": energy, "p": randf() * 10.0})
	colliders.append({"x": x, "z": z, "r": 0.4, "stone": false})


func build_village() -> void:
	house(-12, -8, 6, 0.3, 1)
	house(13, 9, 5.5, -0.5, 0)
	house(-10, 12, 5, 0.9, 0)
	house(15, -12, 6.5, -0.2, 2)
	# puerta norte de piedra
	var stone = Build.mat(Color("5c5c63"))
	var iron = Build.metal(Color("1c1c20"), 0.6)
	for x in [-4.5, 4.5]:
		Build.box(self, Vector3(1.6, 7, 1.6), stone, Vector3(x, 3.5, -24))
		Build.box(self, Vector3(2.0, 0.4, 2.0), stone, Vector3(x, 7.1, -24))
		var cap = Build.cyl(self, 0.0, 1.2, 1.6, Build.mat(Color("16181d")), Vector3(x, 8.1, -24), 4)
		cap.rotation.y = PI / 4.0
		colliders.append({"x": x, "z": -24.0, "r": 1.0, "stone": false})
	Build.box(self, Vector3(8.0, 1.0, 1.2), stone, Vector3(0, 6.3, -24))
	for i in range(9):
		Build.cyl(self, 0.0, 0.07, 1.1, iron, Vector3(-3.2 + i * 0.8, 5.3, -24), 5).rotation.x = PI
	var skull = Build.sphere(self, 0.3, Build.mat(Color("cfc6ae")), Vector3(0, 7.1, -23.5), 10)
	skull.scale = Vector3(1.0, 1.1, 1.0)
	brazier(-6.5, -22.5, 2.2, 3.0)
	brazier(6.5, -22.5, 2.2, 3.0)
	brazier(-9.0, 2.0, 2.0, 2.6)
	brazier(4.0, 15.0, 2.0, 2.6)
	# pozo
	Build.cyl(self, 1.3, 1.4, 0.9, stone, Vector3(0, 0.45, -3), 12)
	Build.cyl(self, 1.05, 1.05, 0.92, Build.mat(Color("050607")), Vector3(0, 0.46, -3), 12)
	for k in [-1.0, 1.0]:
		Build.box(self, Vector3(0.16, 2.4, 0.16), Build.mat(Color("120e0c")), Vector3(k * 1.2, 1.6, -3))
	Build.prism(self, Vector3(3.0, 0.9, 1.6), Build.mat(Color("16181d")), Vector3(0, 3.2, -3))
	colliders.append({"x": 0.0, "z": -3.0, "r": 1.5, "stone": false})
	# forja
	Build.box(self, Vector3(1.4, 0.7, 0.7), Build.mat(Color("232224")), Vector3(SMITH.x + 1.6, 0.35, SMITH.y))
	Build.box(self, Vector3(1.8, 0.25, 0.9), Build.metal(Color("1c1c20")), Vector3(SMITH.x + 1.6, 0.82, SMITH.y))
	Build.box(self, Vector3(1.6, 1.0, 1.6), stone, Vector3(SMITH.x - 1.5, 0.5, SMITH.y - 1))
	Build.cyl(self, 0.0, 0.45, 1.0, Build.glow(Color("ff6a1e"), 4.0), Vector3(SMITH.x - 1.5, 1.4, SMITH.y - 1), 6)
	sparks(self, Vector3(SMITH.x - 1.5, 1.6, SMITH.y - 1), Color("ffb060"), 18, 0.3)
	var fl = OmniLight3D.new()
	fl.light_color = Color("ff7a2a")
	fl.light_energy = 3.2
	fl.omni_range = 14.0
	fl.position = Vector3(SMITH.x - 1.2, 2.2, SMITH.y - 0.6)
	add_child(fl)
	fires.append({"l": fl, "e": 3.2, "p": 3.0})
	for k in [-1.0, 1.0]:
		Build.box(self, Vector3(0.2, 3.2, 0.2), Build.mat(Color("120e0c")), Vector3(SMITH.x + k * 2.6, 1.6, SMITH.y - 2.0))
	var aw = Build.box(self, Vector3(6.0, 0.14, 3.2), Build.mat(Color("16181d")), Vector3(SMITH.x, 3.3, SMITH.y - 1.0))
	aw.rotation.x = 0.25
	var npc = Build.humanoid({"style": "smith", "cloth": Color("4a3526"), "weapon": "sword"})
	npc["root"].position = Vector3(SMITH.x, 0, SMITH.y)
	npc["root"].rotation.y = -0.6
	add_child(npc["root"])
	colliders.append({"x": SMITH.x, "z": SMITH.y, "r": 0.7, "stone": false})
	mark = Build.sphere(self, 0.28, Build.glow(Color("d8b25a"), 2.0), Vector3(SMITH.x, 3.0, SMITH.y), 4)
	# farolas del camino al norte
	for i in range(8):
		var lz = -40.0 - i * 24.0
		var lx = 5.5 if i % 2 == 0 else -5.5
		Build.cyl(self, 0.06, 0.1, 3.2, iron, at(lx, 1.6, lz), 6)
		Build.box(self, Vector3(0.9, 0.08, 0.08), iron, at(lx - sign(lx) * 0.4, 3.1, lz))
		Build.box(self, Vector3(0.3, 0.42, 0.3), Build.glow(Color("ff9a3a"), 2.5), at(lx - sign(lx) * 0.8, 2.75, lz))


# ---------- jugador ----------

func build_player() -> void:
	for c in pg.get_children():
		pg.remove_child(c)
		c.queue_free()
	var C = CLASES[S["clase"]]
	var kc: Color = REINOS[S["reino"]]["c"]
	pm = Build.humanoid({"style": STYLES[S["clase"]], "cloth": kc, "weapon": C["w"], "cape": kc.darkened(0.2)})
	pg.add_child(pm["root"])
	ph = Build.horse()
	ph["root"].visible = false
	pg.add_child(ph["root"])
	recalc()
	php = pmaxhp


func recalc() -> void:
	var C = CLASES[S["clase"]]
	pmaxhp = int(C["hp"] + S["lvl"] * 28 + S["arm"] * 40)
	patk = C["atk"] + S["lvl"] * 3 + S["wpn"] * (4 + S["wpn"])
	pdef = C["def"] + S["lvl"] + S["arm"] * (3 + S["arm"])
	if pm.has("blade") and pm["blade"] != null:
		pm["blade"].emission_energy_multiplier = max(1.8 if CLASES[S["clase"]]["w"] == "staff" else 0.0, S["wpn"] / 9.0 * 2.5)
	php = min(php, pmaxhp)


func xp_need(l: int) -> int:
	return int(round(40.0 * pow(l, 1.6)))


func up_cost(n: int) -> int:
	return int(round(60.0 * pow(n + 1, 1.5)))


func begin(state) -> void:
	if state != null:
		S = state
	px = 0.0
	pz = 6.0
	pang = PI
	cam_yaw = 0.0
	cam_t = Vector3(0, 1.5, 6)
	dead_t = 0.0
	if preview != null:
		preview["root"].queue_free()
		preview = null
	if preview_light != null:
		preview_light.visible = false
	build_player()
	while stones.size() < 5:
		spawn_stone()
	if boss == null and S["dest"] >= 3 * (S["boss"] + 1):
		spawn_boss()
	running = true
	hud.show_playing()
	save_game()
	if state == null or S["xp"] == 0 and S["lvl"] == 1:
		hud.banner("Reino " + REINOS[S["reino"]]["n"], "Sigue las columnas de luz y destruye las piedras malditas")


# ---------- entidades ----------

func bar_material(c: Color) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.no_depth_test = true
	return m


func make_bar(parent: Node3D, y: float, w: float, is_stone: bool) -> MeshInstance3D:
	var q = QuadMesh.new()
	q.size = Vector2(1.0, 0.16)
	var mi = MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = bar_mat_b if is_stone else bar_mat_r
	mi.position = Vector3(0, y, 0)
	mi.scale = Vector3(w, 1, 1)
	mi.visible = false
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func spawn_enemy(x: float, z: float, type: String = "", lvl: int = 0, wave: bool = false) -> Dictionary:
	var d = Vector2(x, z).length()
	if lvl <= 0:
		lvl = clampi(int(round(d / 18.0 + randf_range(-1.0, 1.0))), 1, 22)
	if type == "":
		if d < 95.0:
			type = "lobo"
		elif d < 170.0:
			type = "jabali" if randf() < 0.5 else "bandido"
		else:
			type = "tigre" if randf() < 0.5 else "espectro"
	var D = TIPOS[type]
	var sc = float(D["s"])
	var model
	if D["quad"]:
		model = Build.quad(D["col"], sc, type)
	else:
		var opts = {"style": "skeleton", "cloth": Color("5a1512"), "weapon": "sword"}
		if D["boss"]:
			opts = {"style": "lord", "cloth": Color("5a1512"), "weapon": "sword", "cape": Color("1a0a08")}
		elif D["ghost"]:
			opts = {"style": "wraith", "cloth": Color("9fd8c8"), "weapon": ""}
		model = Build.humanoid(opts)
		model["root"].scale = Vector3.ONE * sc
	var g = Node3D.new()
	g.add_child(model["root"])
	g.position = at(x, 0.0, z)
	var bar_y = (1.6 if D["quad"] else 2.7) * sc + 0.2
	var bar_w = 4.0 if D["boss"] else 1.3
	var bar = make_bar(g, bar_y, bar_w, false)
	add_child(g)
	var base = 30.0 + lvl * 22.0
	var hp = round(base * D["hp"])
	var e = {"stone": false, "type": type, "D": D, "lvl": lvl, "model": model, "g": g, "bar": bar, "bar_w": bar_w,
		"x": x, "z": z, "hx": x, "hz": z, "r": 0.6 * sc, "hp": hp, "maxhp": hp, "dmg": (6.0 + lvl * 3.2) * D["dmg"],
		"ang": randf() * TAU, "st": "chase" if wave else "idle", "wt": randf_range(0.0, 3.0), "tx": x, "tz": z,
		"atk_t": randf_range(0.2, 0.8), "wind": 0.0, "hit_t": 0.0, "dead": 0.0, "wave": wave, "slam_t": 5.0,
		"moving": false, "t": randf_range(0.0, 9.0), "boss": D["boss"]}
	enemies.append(e)
	return e


func spawn_stone() -> void:
	var x = 0.0
	var z = 0.0
	var d = 0.0
	var tries = 0
	while tries < 30:
		tries += 1
		var a = randf() * TAU
		d = randf_range(45.0, 255.0)
		x = cos(a) * d
		z = sin(a) * d
		var ok = Vector2(x - px, z - pz).length() > 30.0 and ground_h(x, z) > -1.0
		for s in stones:
			if Vector2(s["x"] - x, s["z"] - z).length() < 50.0:
				ok = false
		if ok:
			break
	var lvl = clampi(int(round(d / 18.0)), 2, 22)
	var g = Node3D.new()
	g.position = at(x, 0.0, z)
	add_child(g)
	var rock = Sh.mat(Sh.STONE, {"noise_tex": noise_tex, "hit": 0.0})
	var core = Build.sphere(g, 1.5, rock, Vector3(0, 1.7, 0), 24)
	core.scale.y = 1.4
	var crystal = Build.glow(Color("1cd0a8"), 2.2)
	for i in range(6):
		var a2 = i / 6.0 * TAU
		var sh = Build.cyl(g, 0.0, 0.28, randf_range(0.8, 1.6), crystal, Vector3(cos(a2) * 2.1, 0.4, sin(a2) * 2.1), 5)
		sh.rotation = Vector3(randf_range(-0.5, 0.5), randf() * 3.0, randf_range(-0.5, 0.5))
	sparks(g, Vector3(0, 1.5, 0), Color("7ff0d0"), 30, 2.6)
	var beam_mat = Build.flat(Color("63e0c0"), 0.2, true)
	beam_mat.set("disable_fog", true)
	var beam = Build.cyl(g, 0.5, 1.3, 60.0, beam_mat, Vector3(0, 30, 0), 10)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bar = make_bar(g, 4.8, 2.6, true)
	var hp = round((30.0 + lvl * 22.0) * 8.0)
	stones.append({"stone": true, "x": x, "z": z, "r": 1.7, "lvl": lvl, "hp": hp, "maxhp": hp, "g": g, "core": core,
		"bar": bar, "bar_w": 2.6, "waves": 0, "hit_t": 0.0, "dead": 0.0, "rock": rock, "boss": false})
	colliders.append({"x": x, "z": z, "r": 1.7, "stone": true})


func spawn_wave(s: Dictionary) -> void:
	var n = 4 + randi() % 3
	for i in range(n):
		var a = randf() * TAU
		var r = randf_range(4.0, 7.0)
		var t = "espectro" if randf() < 0.6 else ""
		spawn_enemy(s["x"] + cos(a) * r, s["z"] + sin(a) * r, t, s["lvl"], true)
	burst(Vector3(s["x"], 2, s["z"]), Color("63e0c0"), 16)
	hud.toast("La piedra llama a sus guardianes", "bad")


func spawn_boss() -> void:
	boss = spawn_enemy(0.0, -215.0, "jefe", 8 + S["boss"] * 5, false)
	hud.banner("El Señor de Ceniza despierta", "Cruza la puerta roja y sigue al norte")


# ---------- efectos ----------

func burst(pos: Vector3, col: Color, n: int) -> void:
	for i in range(n):
		p_idx = (p_idx + 1) % parts.size()
		var p = parts[p_idx]
		p["n"].material_override.albedo_color = col
		p["n"].position = pos + Vector3(0, ground_h(pos.x, pos.z), 0)
		p["n"].visible = true
		p["life"] = randf_range(0.35, 0.7)
		var a = randf() * TAU
		var s = randf_range(2.0, 7.0)
		p["v"] = Vector3(cos(a) * s, randf_range(3.0, 8.0), sin(a) * s)


func add_fx(node: Node3D, m: StandardMaterial3D, life: float, grow: float) -> void:
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.append({"n": node, "mat": m, "life": life, "max": life, "r": grow, "a": m.albedo_color.a})


func ring_fx(x: float, z: float, r: float, col: Color, life: float) -> void:
	var t = TorusMesh.new()
	t.inner_radius = 0.84
	t.outer_radius = 1.0
	t.rings = 32
	t.ring_segments = 4
	var m = Build.flat(col, 0.9)
	var mi = MeshInstance3D.new()
	mi.mesh = t
	mi.material_override = m
	mi.position = at(x, 0.15, z)
	mi.scale = Vector3(1, 0.3, 1)
	add_child(mi)
	add_fx(mi, m, life, r)


func slash_fx(arc: float, rng: float) -> void:
	var im = ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(13):
		var a = -arc / 2.0 + arc * i / 12.0
		im.surface_add_vertex(Vector3(sin(a) * rng * 0.74, 0, cos(a) * rng * 0.74))
		im.surface_add_vertex(Vector3(sin(a) * rng, 0, cos(a) * rng))
	im.surface_end()
	var m = Build.flat(Color("fff2c8"), 0.5)
	var mi = MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = m
	mi.position = Vector3(0, 1.1, 0)
	pg.add_child(mi)
	add_fx(mi, m, 0.16, 0.0)


func line_fx(pts: Array, col: Color) -> void:
	for i in range(pts.size() - 1):
		var a = pts[i] + Vector3(0, ground_h(pts[i].x, pts[i].z), 0)
		var b = pts[i + 1] + Vector3(0, ground_h(pts[i + 1].x, pts[i + 1].z), 0)
		var d = b - a
		var l = d.length()
		if l < 0.01:
			continue
		var m = Build.flat(col, 0.95)
		var mi = Build.box(self, Vector3(0.14, 0.14, l), m, (a + b) / 2.0)
		mi.rotation.y = atan2(d.x, d.z)
		add_fx(mi, m, 0.22, 0.0)


func dmg_num(pos: Vector3, txt: String, kind: String = "") -> void:
	n_idx = (n_idx + 1) % nums.size()
	var e = nums[n_idx]
	var l = e["n"]
	l.text = txt
	var c = Color("efe6d2")
	l.font_size = 72
	if kind == "crit":
		c = Color("f0c040")
		l.font_size = 100
	elif kind == "me":
		c = Color("ff5a4a")
	elif kind == "heal":
		c = Color("63e0c0")
	l.modulate = c
	l.outline_modulate = Color(0, 0, 0, 1)
	l.position = pos + Vector3(randf_range(-0.4, 0.4), ground_h(pos.x, pos.z), 0)
	l.visible = true
	e["life"] = 0.8


func drop(x: float, z: float, type: String, val: int) -> void:
	var a = randf() * TAU
	var r = randf_range(0.3, 1.8)
	x += cos(a) * r
	z += sin(a) * r
	var n: MeshInstance3D
	if type == "gold":
		n = Build.cyl(self, 0.22, 0.22, 0.06, Build.glow(Color("f0c040"), 0.8), at(x, 0.5, z), 10)
		n.rotation.x = PI / 2.0
	elif type == "pot":
		n = Build.sphere(self, 0.24, Build.glow(Color("cf4a40"), 0.6), at(x, 0.5, z), 8)
	else:
		n = Build.sphere(self, 0.3, Build.glow(Color("63e0c0"), 2.5), at(x, 0.5, z), 4)
	items.append({"n": n, "x": x, "z": z, "type": type, "val": val, "t": 0.0})


# ---------- combate ----------

func targets() -> Array:
	return enemies + stones


func nearest(x: float, z: float, max_d: float):
	var best = null
	var bd = max_d
	for t in targets():
		if t["dead"] > 0.0:
			continue
		var d = Vector2(t["x"] - x, t["z"] - z).length() - t["r"]
		if d < bd:
			bd = d
			best = t
	return best


func hit(t: Dictionary, mult: float) -> void:
	if t["dead"] > 0.0:
		return
	var d = patk * randf_range(0.85, 1.15) * mult
	if buff["furia"] > 0.0:
		d *= 1.4
	var crit = buff["crit"] > 0.0 or randf() < 0.1
	if crit:
		d *= 2.0
	d = round(d)
	t["hp"] -= d
	t["hit_t"] = 0.12
	t["bar"].visible = true
	var y = 4.0
	if not t["stone"]:
		y = 2.2 * float(t["D"]["s"])
	dmg_num(Vector3(t["x"], y, t["z"]), str(int(d)), "crit" if crit else "")
	burst(Vector3(t["x"], 2.0 if t["stone"] else 1.2, t["z"]), Color("63e0c0") if t["stone"] else Color("ffe0a0"), 7 if crit else 3)
	combat_t = 4.0
	if t["stone"]:
		var q = t["hp"] / t["maxhp"]
		if (q < 0.7 and t["waves"] < 1) or (q < 0.4 and t["waves"] < 2) or (q < 0.15 and t["waves"] < 3):
			t["waves"] += 1
			spawn_wave(t)
	elif t["st"] == "idle" or t["st"] == "back":
		t["st"] = "chase"
	if t["hp"] <= 0.0:
		kill(t)
	else:
		t["bar"].scale.x = t["bar_w"] * max(0.02, t["hp"] / t["maxhp"])


func kill(t: Dictionary) -> void:
	t["dead"] = 0.35
	t["bar"].visible = false
	var x = t["x"]
	var z = t["z"]
	var lvl = int(t["lvl"])
	if t["stone"]:
		burst(Vector3(x, 2, z), Color("63e0c0"), 30)
		ring_fx(x, z, 9.0, Color("63e0c0"), 0.5)
		var n = 1 + (1 if randf() < 0.5 else 0)
		for i in range(n):
			drop(x, z, "pm", 1)
		for i in range(5):
			drop(x, z, "gold", int(round(randf_range(8.0, 16.0) * lvl)))
		if randf() < 0.6:
			drop(x, z, "pot", 1)
		gain_xp(int(round((8.0 + lvl * 5.0) * 6.0)))
		S["dest"] += 1
		hud.toast("Piedra destruida", "good")
		for i in range(colliders.size()):
			var c = colliders[i]
			if c["stone"] and c["x"] == x and c["z"] == z:
				colliders.remove_at(i)
				break
		if boss == null and S["dest"] >= 3 * (S["boss"] + 1):
			spawn_boss()
		get_tree().create_timer(15.0).timeout.connect(spawn_stone)
		save_game()
	else:
		gain_xp(int(round((8.0 + lvl * 5.0) * t["D"]["hp"])))
		var mult = 12.0 if t["boss"] else 1.0
		drop(x, z, "gold", int(round(randf_range(3.0, 7.0) * lvl * mult)))
		if randf() < 0.12:
			drop(x, z, "pot", 1)
		if randf() < 0.06:
			drop(x, z, "pm", 1)
		if t["boss"]:
			for i in range(5):
				drop(x, z, "pm", 1)
			for i in range(8):
				drop(x, z, "gold", int(round(randf_range(20.0, 40.0) * lvl)))
			S["boss"] += 1
			boss = null
			clear_telegraph()
			hud.banner("Victoria", "El Señor de Ceniza ha caído. Volverá más fuerte.")
			save_game()


func clear_telegraph() -> void:
	if telegraph != null:
		telegraph["n"].queue_free()
		telegraph = null


func gain_xp(n: int) -> void:
	S["xp"] += n
	var up = false
	while S["xp"] >= xp_need(S["lvl"]):
		S["xp"] -= xp_need(S["lvl"])
		S["lvl"] += 1
		up = true
	if up:
		recalc()
		php = pmaxhp
		burst(Vector3(px, 1.5, pz), Color("d8b25a"), 26)
		ring_fx(px, pz, 5.0, Color("d8b25a"), 0.6)
		hud.toast("Nivel " + str(S["lvl"]) + ". Vida y ataque aumentan.", "good")
		save_game()


func hurt(d: float) -> void:
	if dead_t > 0.0 or not running:
		return
	if buff["escudo"] > 0.0:
		d *= 0.5
	d = max(1.0, round(d - pdef * 0.5))
	php -= d
	combat_t = 4.0
	dmg_num(Vector3(px, 2.6, pz), "-" + str(int(d)), "me")
	hud.flash_hurt()
	if php <= 0.0:
		php = 0.0
		dead_t = 2.2
		var lost = int(round(S["gold"] * 0.1))
		S["gold"] -= lost
		set_mount(false)
		var msg = "Despiertas en la aldea"
		if lost > 0:
			msg += " con " + str(lost) + " de oro menos"
		hud.banner("Has caído", msg)


func set_mount(v: bool) -> void:
	mounted = v
	if ph.has("root"):
		ph["root"].visible = v
	if pm.has("root"):
		pm["root"].position.y = 1.05 if v else 0.0


func toggle_mount() -> void:
	if dead_t <= 0.0 and running:
		set_mount(not mounted)


func face(t: Dictionary) -> void:
	pang = atan2(t["x"] - px, t["z"] - pz)


func attack() -> void:
	if atk_t > 0.0 or dead_t > 0.0:
		return
	if mounted:
		set_mount(false)
	var C = CLASES[S["clase"]]
	atk_t = C["cd"] * (0.7 if buff["furia"] > 0.0 else 1.0)
	swing = 1.0
	if C["ranged"]:
		var t = nearest(px, pz, C["range"])
		if t != null:
			face(t)
		shoot(t, 1.0, Color("ff9a4a") if S["clase"] == "mago" else Color("8ad8ff"))
	else:
		var t = nearest(px, pz, C["range"] * 1.8)
		if t != null:
			face(t)
		slash_fx(C["arc"], C["range"])
		for e in targets():
			if e["dead"] > 0.0:
				continue
			var dx = e["x"] - px
			var dz = e["z"] - pz
			var d = Vector2(dx, dz).length()
			if d < C["range"] + e["r"] and (d < 1.2 + e["r"] or abs(wrapf(atan2(dx, dz) - pang, -PI, PI)) < C["arc"] / 2.0):
				hit(e, 1.0)


func shoot(t, mult: float, col: Color) -> void:
	var n = Build.sphere(self, 0.28, Build.glow(col, 4.0), at(px, 1.5, pz), 8)
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	projs.append({"n": n, "x": px, "z": pz, "dx": sin(pang), "dz": cos(pang), "t": t, "mult": mult, "life": 1.3, "col": col})


func skill(n: int) -> void:
	if not running or dead_t > 0.0:
		return
	var C = CLASES[S["clase"]]
	var s = C["s1"] if n == 1 else C["s2"]
	if n == 1:
		if cd1 > 0.0:
			return
		cd1 = s["cd"]
	else:
		if cd2 > 0.0:
			return
		cd2 = s["cd"]
	if mounted:
		set_mount(false)
	swing = 1.0
	var kind = s["t"]
	if kind == "aoe":
		var cx = px
		var cz = pz
		var col = Color("fff2c8")
		if s["far"]:
			col = Color("ff7a3a")
			var t = nearest(px, pz, 18.0)
			if t != null:
				cx = t["x"]
				cz = t["z"]
				face(t)
			else:
				cx += sin(pang) * 8.0
				cz += cos(pang) * 8.0
		ring_fx(cx, cz, s["r"], col, 0.4)
		burst(Vector3(cx, 1, cz), col, 22)
		for e in targets():
			if e["dead"] <= 0.0 and Vector2(e["x"] - cx, e["z"] - cz).length() < s["r"] + e["r"]:
				hit(e, s["m"])
	elif kind == "dash":
		var sx = px
		var sz = pz
		var done = []
		for i in range(1, 9):
			var nx = sx + sin(pang) * s["len"] * i / 8.0
			var nz = sz + cos(pang) * s["len"] * i / 8.0
			for e in targets():
				if e["dead"] <= 0.0 and not done.has(e["g"].get_instance_id()) and Vector2(e["x"] - nx, e["z"] - nz).length() < 2.4 + e["r"]:
					done.append(e["g"].get_instance_id())
					hit(e, s["m"])
			px = nx
			pz = nz
		collide_player()
		line_fx([Vector3(sx, 1.2, sz), Vector3(px, 1.2, pz)], Color.WHITE)
		burst(Vector3(px, 1, pz), Color("cfd8ff"), 12)
	elif kind == "chain":
		var fxp = px
		var fzp = pz
		var pts = [Vector3(px, 1.6, pz)]
		var done = []
		for i in range(6):
			var b = null
			var bd = 14.0 if i == 0 else 9.0
			for e in targets():
				if e["dead"] > 0.0 or done.has(e["g"].get_instance_id()):
					continue
				var d = Vector2(e["x"] - fxp, e["z"] - fzp).length()
				if d < bd:
					bd = d
					b = e
			if b == null:
				break
			done.append(b["g"].get_instance_id())
			pts.append(Vector3(b["x"], 1.4, b["z"]))
			fxp = b["x"]
			fzp = b["z"]
			if i == 0:
				face(b)
			hit(b, s["m"])
		if pts.size() > 1:
			line_fx(pts, Color("9ae6ff"))
		else:
			hud.toast("Ningún enemigo al alcance", "")
	elif kind == "buff":
		buff[s["k"]] = s["dur"]
		if s["k"] == "furia":
			ring_fx(px, pz, 3.0, Color("cf4a40"), 0.5)
			hud.toast("Furia: más daño y velocidad de ataque", "good")
		elif s["k"] == "crit":
			ring_fx(px, pz, 3.0, Color("8a7aff"), 0.5)
			hud.toast("Sigilo: todos tus golpes son críticos", "good")
		else:
			ring_fx(px, pz, 3.0, Color("63c4a4"), 0.5)
			hud.toast("Escudo: recibes la mitad de daño", "good")
	elif kind == "heal":
		var h = round(pmaxhp * 0.4)
		php = min(pmaxhp, php + h)
		dmg_num(Vector3(px, 2.6, pz), "+" + str(int(h)), "heal")
		ring_fx(px, pz, 3.0, Color("63c4a4"), 0.5)
		burst(Vector3(px, 1, pz), Color("63c4a4"), 14)


func potion() -> void:
	if not running or dead_t > 0.0 or pot_t > 0.0:
		return
	if S["pots"] < 1:
		hud.toast("No te quedan pociones. El herrero las vende.", "bad")
		return
	if php >= pmaxhp:
		hud.toast("Ya tienes la vida al máximo", "")
		return
	S["pots"] -= 1
	pot_t = 4.0
	var h = round(pmaxhp * 0.4)
	php = min(pmaxhp, php + h)
	dmg_num(Vector3(px, 2.6, pz), "+" + str(int(h)), "heal")
	burst(Vector3(px, 1.2, pz), Color("cf4a40"), 10)


func collide_player() -> void:
	for c in colliders:
		var dx = px - c["x"]
		var dz = pz - c["z"]
		var rr = c["r"] + 0.5
		if abs(dx) > rr or abs(dz) > rr:
			continue
		var d = sqrt(dx * dx + dz * dz)
		if d < rr and d > 0.001:
			px = c["x"] + dx / d * rr
			pz = c["z"] + dz / d * rr
	var dd = sqrt(px * px + pz * pz)
	if dd > 292.0:
		px *= 292.0 / dd
		pz *= 292.0 / dd


# ---------- herrero ----------

func near_smith() -> bool:
	return Vector2(px - SMITH.x, pz - SMITH.y).length() < 5.5


func mejorar(k: String) -> Array:
	var n = int(S[k])
	if n >= 9:
		return ["Ya está al máximo.", "bad"]
	var c = up_cost(n)
	if S["gold"] < c or S["pm"] < 1:
		return ["Te falta oro o fragmentos.", "bad"]
	S["gold"] -= c
	S["pm"] -= 1
	var nm = "El arma" if k == "wpn" else "La armadura"
	var res
	if randf() * 100.0 < CH[n]:
		S[k] = n + 1
		res = [nm + " sube a +" + str(S[k]) + ".", "good"]
	elif n >= 4:
		S[k] = n - 1
		res = ["La forja falla. " + nm + " baja a +" + str(S[k]) + ".", "bad"]
	else:
		res = ["La forja falla. Pierdes el oro y el fragmento.", "bad"]
	recalc()
	save_game()
	return res


func buy_potion() -> bool:
	if S["gold"] < 25:
		return false
	S["gold"] -= 25
	S["pots"] += 1
	save_game()
	return true


# ---------- bucle ----------

func _process(delta: float) -> void:
	var dt = min(delta, 0.05)
	time += dt
	if test_mode:
		run_test()
	if running and not hud.menu_open():
		upd_player(dt)
		upd_enemies(dt)
		upd_world(dt)
		save_t += dt
		if save_t > 15.0:
			save_t = 0.0
			save_game()
	upd_cam(dt)
	ash.position = cam_t + Vector3(0, 6, 0)
	for f in fires:
		f["l"].light_energy = f["e"] * (0.82 + 0.18 * sin(time * 9.0 + f["p"]) * sin(time * 5.3 + f["p"] * 2.0))
	grass_mat.set_shader_parameter("player_pos", Vector3(cam_t.x, 0, cam_t.z))


func upd_player(dt: float) -> void:
	if dead_t > 0.0:
		dead_t -= dt
		pm["root"].rotation.x = -min(1.5, (2.2 - dead_t) * 4.0)
		if dead_t <= 0.0:
			dead_t = 0.0
			px = 0.0
			pz = 6.0
			php = pmaxhp
			pm["root"].rotation.x = 0.0
			for e in enemies:
				if not e["boss"] and e["st"] == "chase":
					e["st"] = "back"
			save_game()
		pg.position = at(px, 0.0, pz)
		return
	var m = Vector2(jx, jy).length()
	moving = m > 0.15
	var C = CLASES[S["clase"]]
	if moving:
		var fwd = Vector2(-sin(cam_yaw), -cos(cam_yaw))
		var right = Vector2(cos(cam_yaw), -sin(cam_yaw))
		var mv = (fwd * jy + right * jx).normalized()
		var sp = C["spd"] * min(1.0, m)
		if mounted:
			sp *= 1.75
		elif atk_t > 0.0:
			sp *= 0.6
		px += mv.x * sp * dt
		pz += mv.y * sp * dt
		if swing <= 0.0:
			pang += wrapf(atan2(mv.x, mv.y) - pang, -PI, PI) * min(1.0, dt * 14.0)
		collide_player()
	atk_t -= dt
	swing = max(0.0, swing - dt * 5.0)
	cd1 = max(0.0, cd1 - dt)
	cd2 = max(0.0, cd2 - dt)
	pot_t = max(0.0, pot_t - dt)
	combat_t -= dt
	for k in buff.keys():
		if buff[k] > 0.0:
			buff[k] -= dt
	if inp_atk:
		attack()
	var in_town = Vector2(px, pz).length() < 24.0
	if php < pmaxhp:
		var rate = 0.0
		if in_town:
			rate = 0.08
		elif combat_t <= 0.0:
			rate = 0.012
		php = min(pmaxhp, php + pmaxhp * rate * dt)
	pg.position = at(px, 0.0, pz)
	pg.rotation.y = pang
	Build.anim_h(pm, time, moving and not mounted, swing)
	if mounted:
		pm["leg_l"].rotation.z = -0.5
		pm["leg_r"].rotation.z = 0.5
		Build.anim_quad(ph, time, moving, 14.0)
	else:
		pm["leg_l"].rotation.z = 0.0
		pm["leg_r"].rotation.z = 0.0


func upd_enemies(dt: float) -> void:
	var p_safe = Vector2(px, pz).length() < 24.0
	for i in range(enemies.size() - 1, -1, -1):
		var e = enemies[i]
		if e["dead"] > 0.0:
			e["dead"] -= dt
			e["g"].scale = Vector3.ONE * max(0.01, e["dead"] / 0.35)
			if e["dead"] <= 0.0:
				e["g"].queue_free()
				enemies.remove_at(i)
			continue
		var dx = px - e["x"]
		var dz = pz - e["z"]
		var d = sqrt(dx * dx + dz * dz)
		e["t"] += dt
		e["moving"] = false
		if not e["boss"] and not e["wave"] and d > 115.0:
			e["g"].queue_free()
			enemies.remove_at(i)
			continue
		var D = e["D"]
		var go = false
		var tx = 0.0
		var tz = 0.0
		var sp = float(D["spd"])
		if e["st"] == "idle":
			if dead_t <= 0.0 and d < (26.0 if e["boss"] else 14.0) and not p_safe:
				e["st"] = "chase"
			else:
				e["wt"] -= dt
				if e["wt"] <= 0.0:
					e["wt"] = randf_range(2.0, 5.0)
					e["tx"] = e["hx"] + randf_range(-7.0, 7.0)
					e["tz"] = e["hz"] + randf_range(-7.0, 7.0)
				if Vector2(e["tx"] - e["x"], e["tz"] - e["z"]).length() > 0.6:
					go = true
					tx = e["tx"]
					tz = e["tz"]
					sp *= 0.35
		elif e["st"] == "back":
			go = true
			tx = e["hx"]
			tz = e["hz"]
			if Vector2(tx - e["x"], tz - e["z"]).length() < 2.0:
				e["st"] = "idle"
				e["hp"] = e["maxhp"]
				e["bar"].visible = false
				go = false
		else:
			var leash = 70.0 if e["boss"] else 45.0
			if dead_t > 0.0 or p_safe or (not e["wave"] and Vector2(e["x"] - e["hx"], e["z"] - e["hz"]).length() > leash):
				e["st"] = "back"
			else:
				e["ang"] = atan2(dx, dz)
				if e["wind"] > 0.0:
					e["wind"] -= dt
					if e["wind"] <= 0.0 and d < D["range"] + e["r"] + 1.0:
						hurt(e["dmg"] * randf_range(0.85, 1.15))
				elif e["boss"] and telegraph != null:
					pass
				elif d < D["range"] + e["r"]:
					e["atk_t"] -= dt
					if e["atk_t"] <= 0.0:
						e["atk_t"] = randf_range(1.1, 1.6)
						e["wind"] = 0.35
				else:
					go = true
					tx = px
					tz = pz
				if e["boss"]:
					e["slam_t"] -= dt
					if e["slam_t"] <= 0.0 and d < 13.0 and telegraph == null:
						e["slam_t"] = randf_range(6.0, 8.0)
						var tm = Build.flat(Color("cf4a40"), 0.35)
						var tn = Build.cyl(self, 1.0, 1.0, 0.06, tm, at(e["x"], 0.12, e["z"]), 32)
						tn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
						telegraph = {"n": tn, "t": 1.3, "x": e["x"], "z": e["z"], "r": 8.0, "dmg": e["dmg"] * 2.5}
		if go:
			var mx = tx - e["x"]
			var mz = tz - e["z"]
			var l = sqrt(mx * mx + mz * mz)
			if l > 0.05:
				e["x"] += mx / l * sp * dt
				e["z"] += mz / l * sp * dt
				e["ang"] = atan2(mx, mz)
				e["moving"] = true
		for j in range(i - 1, -1, -1):
			var o = enemies[j]
			if o["dead"] > 0.0:
				continue
			var sx = e["x"] - o["x"]
			var sz = e["z"] - o["z"]
			var rr = e["r"] + o["r"]
			if abs(sx) > rr or abs(sz) > rr:
				continue
			var sd = sqrt(sx * sx + sz * sz)
			if sd < rr and sd > 0.001:
				var push = (rr - sd) / 2.0
				e["x"] += sx / sd * push
				e["z"] += sz / sd * push
				o["x"] -= sx / sd * push
				o["z"] -= sz / sd * push
		e["hit_t"] = max(0.0, e["hit_t"] - dt)
		var gy = 0.0
		if D["ghost"]:
			gy = 0.25 + sin(e["t"] * 3.0) * 0.12
		e["g"].position = at(e["x"], gy, e["z"])
		e["g"].rotation.y = e["ang"]
		e["model"]["root"].scale = Vector3.ONE * (float(D["s"]) * (1.15 if e["hit_t"] > 0.0 else 1.0))
		if D["quad"]:
			Build.anim_quad(e["model"], e["t"], e["moving"], 13.0)
			e["model"]["root"].position.z = 0.5 if e["wind"] > 0.0 else 0.0
		else:
			Build.anim_h(e["model"], e["t"], e["moving"], e["wind"] / 0.35 if e["wind"] > 0.0 else 0.0)
	if telegraph != null:
		telegraph["t"] -= dt
		var k = 1.0 - telegraph["t"] / 1.3
		var sc = max(0.1, k * telegraph["r"])
		telegraph["n"].scale = Vector3(sc, 1, sc)
		if telegraph["t"] <= 0.0:
			var tx2 = telegraph["x"]
			var tz2 = telegraph["z"]
			var tr = telegraph["r"]
			var td = telegraph["dmg"]
			clear_telegraph()
			burst(Vector3(tx2, 0.5, tz2), Color("ff5a2a"), 30)
			ring_fx(tx2, tz2, tr, Color("ff5a2a"), 0.4)
			if Vector2(px - tx2, pz - tz2).length() < tr:
				hurt(td)
	spawn_t -= dt
	if spawn_t <= 0.0:
		spawn_t = 0.7
		var near = 0
		for e in enemies:
			if not e["boss"] and Vector2(e["x"] - px, e["z"] - pz).length() < 75.0:
				near += 1
		if near < 16 and enemies.size() < 46:
			var a = randf() * TAU
			var r = randf_range(40.0, 62.0)
			var x = px + cos(a) * r
			var z = pz + sin(a) * r
			var d0 = Vector2(x, z).length()
			if d0 > 36.0 and d0 < 288.0:
				var n = 1 + randi() % 3
				var e0 = spawn_enemy(x, z)
				for i in range(1, n):
					spawn_enemy(x + randf_range(-4.0, 4.0), z + randf_range(-4.0, 4.0), e0["type"], e0["lvl"])


func upd_world(dt: float) -> void:
	for i in range(stones.size() - 1, -1, -1):
		var s = stones[i]
		if s["dead"] > 0.0:
			s["dead"] -= dt
			s["g"].scale = Vector3.ONE * max(0.01, s["dead"] / 0.35)
			if s["dead"] <= 0.0:
				s["g"].queue_free()
				stones.remove_at(i)
			continue
		s["hit_t"] = max(0.0, s["hit_t"] - dt)
		s["core"].rotation.y += dt * 0.3
		s["core"].scale = Vector3(1.0 + s["hit_t"], 1.4 + s["hit_t"], 1.0 + s["hit_t"])
		s["rock"].set_shader_parameter("hit", s["hit_t"])
	for i in range(projs.size() - 1, -1, -1):
		var p = projs[i]
		p["life"] -= dt
		var t = p["t"]
		if t != null and t["dead"] <= 0.0:
			var v = Vector2(t["x"] - p["x"], t["z"] - p["z"])
			if v.length() > 0.01:
				v = v.normalized()
				p["dx"] = v.x
				p["dz"] = v.y
		p["x"] += p["dx"] * 30.0 * dt
		p["z"] += p["dz"] * 30.0 * dt
		p["n"].position = at(p["x"], 1.5, p["z"])
		var h = null
		var all = targets()
		for e in all:
			if e["dead"] <= 0.0 and Vector2(e["x"] - p["x"], e["z"] - p["z"]).length() < e["r"] + 0.6:
				h = e
				break
		if h != null:
			hit(h, p["mult"])
			for e in all:
				if not is_same(e, h) and e["dead"] <= 0.0 and Vector2(e["x"] - p["x"], e["z"] - p["z"]).length() < 2.4 + e["r"]:
					hit(e, p["mult"] * 0.5)
			burst(Vector3(p["x"], 1.5, p["z"]), p["col"], 6)
		if h != null or p["life"] <= 0.0:
			p["n"].queue_free()
			projs.remove_at(i)
	for i in range(items.size() - 1, -1, -1):
		var it = items[i]
		it["t"] += dt
		var dx = px - it["x"]
		var dz = pz - it["z"]
		var d = sqrt(dx * dx + dz * dz)
		var alive = dead_t <= 0.0
		if d < 6.0 and d > 0.01 and it["t"] > 0.4 and alive:
			it["x"] += dx / d * 14.0 * dt
			it["z"] += dz / d * 14.0 * dt
		it["n"].position = at(it["x"], 0.5 + sin(it["t"] * 4.0) * 0.12, it["z"])
		it["n"].rotation.y += dt * 3.0
		if d < 1.4 and it["t"] > 0.4 and alive:
			if it["type"] == "gold":
				S["gold"] += it["val"]
				dmg_num(Vector3(px, 2.9, pz), "+" + str(it["val"]) + " oro", "crit")
			elif it["type"] == "pot":
				S["pots"] += 1
				hud.toast("Poción roja", "good")
			else:
				S["pm"] += 1
				hud.toast("Fragmento de piedra. Llévalo al herrero.", "good")
			it["n"].queue_free()
			items.remove_at(i)
		elif it["t"] > 70.0:
			it["n"].queue_free()
			items.remove_at(i)
	for i in range(fx.size() - 1, -1, -1):
		var f = fx[i]
		f["life"] -= dt
		var k = max(0.0, f["life"] / f["max"])
		var c = f["mat"].albedo_color
		f["mat"].albedo_color = Color(c.r, c.g, c.b, f["a"] * k)
		if f["r"] > 0.0:
			var sc = 1.0 + (1.0 - k) * (f["r"] - 1.0)
			f["n"].scale = Vector3(sc, 0.3, sc)
		if f["life"] <= 0.0:
			f["n"].queue_free()
			fx.remove_at(i)
	for p in parts:
		if p["life"] <= 0.0:
			continue
		p["life"] -= dt
		p["v"].y -= 20.0 * dt
		p["n"].position += p["v"] * dt
		p["n"].rotation.x += dt * 8.0
		if p["life"] <= 0.0 or p["n"].position.y < ground_h(p["n"].position.x, p["n"].position.z):
			p["life"] = 0.0
			p["n"].visible = false
	for e in nums:
		if e["life"] <= 0.0:
			continue
		e["life"] -= dt
		var l = e["n"]
		l.position.y += dt * 2.4
		var a = clamp(e["life"] / 0.5, 0.0, 1.0)
		l.modulate.a = a
		l.outline_modulate = Color(0, 0, 0, a)
		if e["life"] <= 0.0:
			l.visible = false
	mark.position.y = 3.1 + sin(time * 2.5) * 0.15
	mark.rotation.y += dt * 2.0


func upd_cam(dt: float) -> void:
	if not running:
		cam.position = PV + Vector3(-1.6 + sin(time * 0.3) * 0.15, 1.75, 5.0)
		cam.look_at(PV + Vector3(-1.75, 1.3, 0), Vector3.UP)
		if preview != null:
			Build.anim_h(preview, time, false, 0.0)
			preview["root"].rotation.y = sin(time * 0.6) * 0.4 - 0.15
		return
	var k = min(1.0, dt * 10.0)
	cam_t.x += (px - cam_t.x) * k
	cam_t.z += (pz - cam_t.z) * k
	cam_t.y += (ground_h(px, pz) + (2.4 if mounted else 1.6) - cam_t.y) * k
	var cp = cos(cam_pitch)
	cam.position = cam_t + Vector3(sin(cam_yaw) * cp * cam_dist, sin(cam_pitch) * cam_dist, cos(cam_yaw) * cp * cam_dist)
	cam.position.y = max(cam.position.y, ground_h(cam.position.x, cam.position.z) + 1.2)
	cam.look_at(cam_t, Vector3.UP)


# ---------- prueba automática (solo en la compilación) ----------

func run_test() -> void:
	test_f += 1
	var f = test_f
	if f == 1:
		shot_dir = OS.get_environment("CR_SHOTS")
	if OS.has_environment("CR_MENU"):
		var mc = OS.get_environment("CR_TEST")
		if f == 2 and CLASES.has(mc):
			hud._pick_clase(mc)
			hud._pick_reino(OS.get_environment("CR_MENU"))
		if f == 12 and shot_dir != "":
			shot("menu_" + mc)
		if f == 20:
			print("CR_TEST_OK menu ", mc)
			get_tree().quit()
		return
	if shot_dir != "" and f in [1, 30, 120, 175, 260, 300, 350, 420]:
		shot("f" + str(f))
	if f == 2:
		var cl = OS.get_environment("CR_TEST")
		if not CLASES.has(cl):
			cl = "guerrero"
		begin(new_state("azur", cl))
		S["gold"] = 50000
		S["pm"] = 40
	if f < 3:
		return
	var tgt = null
	var bd = 9999.0
	for s in stones:
		var d = Vector2(s["x"] - px, s["z"] - pz).length()
		if s["dead"] <= 0.0 and d < bd:
			bd = d
			tgt = s
	if boss != null:
		tgt = boss
		bd = Vector2(boss["x"] - px, boss["z"] - pz).length()
	if tgt != null and bd > 2.5:
		var v = Vector2(tgt["x"] - px, tgt["z"] - pz).normalized()
		jx = v.x
		jy = -v.y
	else:
		jx = 0.0
		jy = 0.0
	inp_atk = true
	if f % 45 == 0:
		skill(1)
	if f % 100 == 0:
		skill(2)
	if f % 130 == 0:
		potion()
	if f == 60 or f == 75:
		toggle_mount()
	if f == 90:
		for i in range(14):
			mejorar("wpn")
			mejorar("arm")
		buy_potion()
	if f == 150 and stones.size() > 0:
		var s0 = stones[0]
		px = s0["x"] + 2.6
		pz = s0["z"]
		s0["hp"] = s0["maxhp"] * 0.72
	if f == 250 and stones.size() > 0:
		for s in stones:
			if s["dead"] <= 0.0:
				s["hp"] = min(s["hp"], 5.0)
	if f == 330:
		if boss == null:
			spawn_boss()
		px = boss["x"]
		pz = boss["z"] + 5.0
	if f == 520 and boss != null:
		boss["hp"] = 1.0
	if f == 580:
		hurt(9999999.0)
	if f == 680:
		hud.open_smith()
	if f == 690:
		hud.close_smith()
	if f == 720:
		var back = load_save()
		print("CR_TEST_OK clase=", S["clase"], " nivel=", S["lvl"], " piedras=", S["dest"], " jefes=", S["boss"], " guardado=", back != null)
		get_tree().quit()


func shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	if img != null:
		img.save_png(shot_dir + "/" + shot_name + ".png")


func set_preview(reino: String, clase: String) -> void:
	if running:
		return
	if preview != null:
		preview["root"].queue_free()
	var kc: Color = REINOS[reino]["c"]
	preview = Build.humanoid({"style": STYLES[clase], "cloth": kc, "weapon": CLASES[clase]["w"], "cape": kc.darkened(0.2)})
	preview["root"].position = PV
	add_child(preview["root"])
	if preview_light == null:
		preview_light = OmniLight3D.new()
		preview_light.light_color = Color("ffe2c0")
		preview_light.light_energy = 3.5
		preview_light.omni_range = 9.0
		preview_light.position = PV + Vector3(-1.8, 2.8, 3.0)
		add_child(preview_light)
