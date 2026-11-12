extends Node3D
# HERRUMBRE — supervivencia en una isla, en primera persona. Un jugador.

const D = preload("res://data.gd")
const M = preload("res://mesh.gd")
const HudScript = preload("res://hud.gd")

const CELL = 2.0
const N = 320
const HALF = 320.0
const CH = 32
const ISLE_R = 300.0
const LAKE = Vector2(70.0, -50.0)
const DAY_LEN = 780.0
const SAVE = "user://herrumbre.json"
const WALLS = ["wall", "doorway", "window"]
const L_TERRAIN = 1
const L_SOLID = 2
const L_BUILD = 4
const L_PICK = 8

var seed_v = 20261112
var hs = PackedFloat32Array()
var rng = RandomNumberGenerator.new()
var noise: FastNoiseLite
var noise2: FastNoiseLite

var player: CharacterBody3D
var head: Node3D
var cam: Camera3D
var vm: MeshInstance3D
var vm_base = Vector3(0.32, -0.44, -0.62)
var torch_light: OmniLight3D
var flash_light: OmniLight3D
var hud
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var water_mat: StandardMaterial3D

var playing = false
var panel_open = false
var test_mode = false
var touch = false
var S = {}
var inv = []
var hot = 0
var nodes = {}
var next_nid = 1
var creatures = []
var pieces = {}
var deps = []
var open_dep = null
var yaw = 0.0
var pitch = 0.0
var vel_y = 0.0
var fall_v = 0.0
var atk_cd = 0.0
var swing_t = 0.0
var build_on = false
var build_kind = "foundation"
var ghost: MeshInstance3D
var ghost_mat: StandardMaterial3D
var ghost_ok = false
var ghost_info = {}
var target = {}
var time_d = 0.32
var sunlight = 1.0
var t_scan = 0.0
var t_save = 0.0
var t_pop = 0.0
var t_regen = 0.0
var step_t = 0.0
var held_cache = "?"
var shapes = {}
var world_root: Node3D
var shot_dir = ""


func _ready() -> void:
	test_mode = OS.has_environment("HR_TEST")
	touch = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	setup_env()
	hud = HudScript.new()
	hud.game = self
	var cl = CanvasLayer.new()
	add_child(cl)
	cl.add_child(hud)
	get_tree().set_auto_accept_quit(false)
	if test_mode:
		run_test()
	else:
		gen_world()
		place_menu_cam()
		hud.show_start(FileAccess.file_exists(SAVE))


# ---------------------------------------------------------------- entorno

func setup_env() -> void:
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sun_angle_max = 12.0
	var sky = Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.65, 0.75)
	env.ambient_light_energy = 0.8
	env.fog_enabled = true
	env.fog_density = 0.0042
	env.fog_sky_affect = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)
	update_sky()


func update_sky() -> void:
	var e = sin((time_d - 0.25) * TAU) + 0.22
	sunlight = clamp(e * 2.2, 0.0, 1.0)
	var dusk = clamp(1.0 - abs(e) * 3.0, 0.0, 1.0)
	sun.rotation = Vector3(-(time_d - 0.25) * TAU, 0.7, 0)
	sun.light_energy = sunlight * 0.9
	sun.light_color = Color(1.0, 0.95, 0.85).lerp(Color(1.0, 0.6, 0.35), dusk)
	sun.visible = sunlight > 0.01
	var top = Color(0.015, 0.02, 0.05).lerp(Color(0.22, 0.45, 0.85), sunlight)
	var hor = Color(0.04, 0.05, 0.09).lerp(Color(0.66, 0.78, 0.9), sunlight).lerp(Color(0.85, 0.5, 0.3), dusk * 0.7)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor
	sky_mat.ground_bottom_color = hor.darkened(0.4)
	env.fog_light_color = hor.darkened(0.25)
	env.ambient_light_color = Color(0.25, 0.3, 0.5).lerp(Color(0.62, 0.66, 0.74), sunlight)
	env.ambient_light_energy = lerp(0.3, 0.5, sunlight)
	if water_mat != null:
		water_mat.albedo_color = Color(0.03, 0.08, 0.14, 0.86).lerp(Color(0.1, 0.4, 0.55, 0.78), sunlight)


func is_night() -> bool:
	return sunlight < 0.2


# ---------------------------------------------------------------- terreno

func gen_heights() -> void:
	noise = FastNoiseLite.new()
	noise.seed = seed_v
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.frequency = 0.0052
	noise2 = FastNoiseLite.new()
	noise2.seed = seed_v + 7
	noise2.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise2.frequency = 0.03
	hs.resize((N + 1) * (N + 1))
	for j in N + 1:
		for i in N + 1:
			var x = i * CELL - HALF
			var z = j * CELL - HALF
			hs[j * (N + 1) + i] = calc_h(x, z)


func calc_h(x: float, z: float) -> float:
	var a = atan2(z, x)
	var d = sqrt(x * x + z * z) / ISLE_R
	d *= 1.0 + 0.11 * sin(a * 3.0 + 1.3) + 0.06 * sin(a * 5.0 + 0.4)
	var m = smoothstep(1.0, 0.55, d)
	var nn = noise.get_noise_2d(x, z) * 0.5 + 0.5
	var hill = pow(nn, 1.7) * 38.0 * smoothstep(0.92, 0.3, d) + noise2.get_noise_2d(x, z) * 0.8
	var h = lerp(-7.0, 1.3 + hill, m)
	var ld = Vector2(x, z).distance_to(LAKE) / 40.0
	if ld < 1.0:
		h = lerp(h, -2.4, smoothstep(1.0, 0.35, ld))
	return h


func hg(i: int, j: int) -> float:
	return hs[clampi(j, 0, N) * (N + 1) + clampi(i, 0, N)]


func get_h(x: float, z: float) -> float:
	var fx = clamp((x + HALF) / CELL, 0.0, N - 0.001)
	var fz = clamp((z + HALF) / CELL, 0.0, N - 0.001)
	var i = int(fx)
	var j = int(fz)
	var tx = fx - i
	var tz = fz - j
	var a = lerp(hg(i, j), hg(i + 1, j), tx)
	var b = lerp(hg(i, j + 1), hg(i + 1, j + 1), tx)
	return lerp(a, b, tz)


func get_ny(x: float, z: float) -> float:
	var hl = get_h(x - 1.5, z)
	var hr = get_h(x + 1.5, z)
	var hd = get_h(x, z - 1.5)
	var hu = get_h(x, z + 1.5)
	return Vector3(hl - hr, 3.0, hd - hu).normalized().y


func is_fresh(x: float, z: float) -> bool:
	return Vector2(x, z).distance_to(LAKE) < 46.0


func tcol(h: float, ny: float, x: float, z: float) -> Color:
	var sand = Color(0.7, 0.62, 0.43)
	if h < -0.6:
		return Color(0.5, 0.52, 0.42)
	var g = Color(0.3, 0.48, 0.2).lerp(Color(0.2, 0.37, 0.15), noise2.get_noise_2d(x * 0.3, z * 0.3) * 0.5 + 0.5)
	if h > 22.0:
		g = g.lerp(Color(0.45, 0.44, 0.4), clamp((h - 22.0) / 8.0, 0.0, 1.0))
	if ny < 0.74:
		g = g.lerp(Color(0.44, 0.42, 0.39), clamp((0.74 - ny) * 6.0, 0.0, 1.0))
	return sand.lerp(g, smoothstep(1.3, 2.7, h))


func build_terrain() -> void:
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	var nch = int(N / float(CH))
	for cz in nch:
		for cx in nch:
			var verts = PackedVector3Array()
			var norms = PackedVector3Array()
			var cols = PackedColorArray()
			var idx = PackedInt32Array()
			for j in CH + 1:
				for i in CH + 1:
					var gi = cx * CH + i
					var gj = cz * CH + j
					var x = gi * CELL - HALF
					var z = gj * CELL - HALF
					var h = hg(gi, gj)
					verts.append(Vector3(x, h, z))
					var nrm = Vector3(hg(gi - 1, gj) - hg(gi + 1, gj), 2.0 * CELL, hg(gi, gj - 1) - hg(gi, gj + 1)).normalized()
					norms.append(nrm)
					cols.append(tcol(h, nrm.y, x, z))
			var faces = PackedVector3Array()
			for j in CH:
				for i in CH:
					var a = j * (CH + 1) + i
					var b = a + 1
					var c = a + CH + 1
					var d = c + 1
					idx.append_array(PackedInt32Array([a, b, c, b, d, c]))
					faces.append_array(PackedVector3Array([verts[a], verts[b], verts[c], verts[b], verts[d], verts[c]]))
			var arr = []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = verts
			arr[Mesh.ARRAY_NORMAL] = norms
			arr[Mesh.ARRAY_COLOR] = cols
			arr[Mesh.ARRAY_INDEX] = idx
			var am = ArrayMesh.new()
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			am.surface_set_material(0, mat)
			var mi = MeshInstance3D.new()
			mi.mesh = am
			var body = StaticBody3D.new()
			body.collision_layer = L_TERRAIN
			body.collision_mask = 0
			var sh = ConcavePolygonShape3D.new()
			sh.set_faces(faces)
			var cs = CollisionShape3D.new()
			cs.shape = sh
			body.add_child(cs)
			body.add_child(mi)
			world_root.add_child(body)
	# agua
	water_mat = StandardMaterial3D.new()
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.albedo_color = Color(0.1, 0.4, 0.55, 0.78)
	water_mat.roughness = 0.3
	water_mat.metallic = 0.0
	water_mat.metallic_specular = 0.25
	var pm = PlaneMesh.new()
	pm.size = Vector2(3000, 3000)
	var w = MeshInstance3D.new()
	w.mesh = pm
	w.material_override = water_mat
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world_root.add_child(w)
	var deep = MeshInstance3D.new()
	deep.mesh = pm
	var dm = StandardMaterial3D.new()
	dm.albedo_color = Color(0.04, 0.12, 0.2)
	deep.material_override = dm
	deep.position.y = -7.5
	world_root.add_child(deep)


# ---------------------------------------------------------------- mundo

func gen_world() -> void:
	if world_root != null:
		world_root.queue_free()
	world_root = Node3D.new()
	add_child(world_root)
	nodes.clear()
	creatures.clear()
	pieces.clear()
	deps.clear()
	next_nid = 1
	rng.seed = seed_v
	gen_heights()
	build_terrain()
	populate()
	make_player()
	ghost = MeshInstance3D.new()
	ghost_mat = StandardMaterial3D.new()
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_mat.albedo_color = Color(0.3, 1.0, 0.4, 0.45)
	ghost_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ghost.material_override = ghost_mat
	ghost.visible = false
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world_root.add_child(ghost)


func shape_for(kind: String) -> Array:
	# [shape, offset]
	if shapes.has(kind):
		return shapes[kind]
	var sh
	var off = Vector3.ZERO
	match kind:
		"pine", "oak", "palm":
			sh = CylinderShape3D.new()
			sh.radius = 0.32
			sh.height = 4.0
			off = Vector3(0, 2.0, 0)
		"stone", "iron":
			sh = SphereShape3D.new()
			sh.radius = 0.95
			off = Vector3(0, 0.35, 0)
		"barrel":
			sh = CylinderShape3D.new()
			sh.radius = 0.45
			sh.height = 1.05
			off = Vector3(0, 0.52, 0)
		"crate":
			sh = BoxShape3D.new()
			sh.size = Vector3(1.2, 0.85, 0.8)
			off = Vector3(0, 0.42, 0)
		"ruin":
			sh = BoxShape3D.new()
			sh.size = Vector3(4.0, 1.8, 0.5)
			off = Vector3(0, 0.9, 0)
		_:
			sh = SphereShape3D.new()
			sh.radius = 0.55
			off = Vector3(0, 0.35, 0)
	shapes[kind] = [sh, off]
	return shapes[kind]


func add_node(kind: String, pos: Vector3, scl: float = 1.0, ry: float = 0.0) -> Dictionary:
	var body = StaticBody3D.new()
	var solid = kind in ["pine", "oak", "palm", "stone", "iron", "barrel", "crate", "ruin"]
	body.collision_layer = L_SOLID if solid else L_PICK
	body.collision_mask = 0
	body.position = pos
	body.rotation.y = ry
	var mi = MeshInstance3D.new()
	mi.mesh = M.model(kind)
	mi.scale = Vector3.ONE * scl
	mi.visibility_range_end = 190.0 if solid else 90.0
	body.add_child(mi)
	var sd = shape_for(kind)
	var cs = CollisionShape3D.new()
	cs.shape = sd[0]
	cs.position = sd[1] * scl
	body.add_child(cs)
	var id = next_nid
	next_nid += 1
	body.set_meta("nid", id)
	world_root.add_child(body)
	var hp = {"pine": 110, "oak": 150, "palm": 80, "stone": 140, "iron": 160, "barrel": 30}.get(kind, 1)
	var nd = {"k": kind, "node": body, "pos": pos, "hp": hp, "max": hp, "dead": 0.0, "mi": mi}
	nodes[id] = nd
	return nd


func rand_land(hmin: float, hmax: float, nymin: float = 0.8, tries: int = 30):
	for t in tries:
		var x = rng.randf_range(-HALF + 20, HALF - 20)
		var z = rng.randf_range(-HALF + 20, HALF - 20)
		var h = get_h(x, z)
		if h < hmin or h > hmax:
			continue
		if get_ny(x, z) < nymin:
			continue
		return Vector3(x, h, z)
	return null


func populate() -> void:
	for i in 1100:
		var p = rand_land(1.7, 30.0, 0.8, 1)
		if p == null:
			continue
		if noise.get_noise_2d(p.x * 2.0 + 900.0, p.z * 2.0) < -0.12:
			continue
		var kind = "pine" if (p.y > 9.0 or rng.randf() < 0.35) else "oak"
		add_node(kind, p - Vector3(0, 0.1, 0), rng.randf_range(0.85, 1.35), rng.randf() * TAU)
	for i in 160:
		var p = rand_land(0.95, 2.3, 0.85, 1)
		if p != null:
			add_node("palm", p - Vector3(0, 0.1, 0), rng.randf_range(0.85, 1.2), rng.randf() * TAU)
	for i in 240:
		var p = rand_land(1.2, 40.0, 0.5, 2)
		if p != null:
			add_node("stone", p - Vector3(0, 0.1, 0), rng.randf_range(0.8, 1.3), rng.randf() * TAU)
	for i in 110:
		var p = rand_land(5.0, 40.0, 0.5, 3)
		if p != null:
			add_node("iron", p - Vector3(0, 0.1, 0), rng.randf_range(0.8, 1.2), rng.randf() * TAU)
	for i in 130:
		var p = rand_land(1.5, 25.0, 0.8, 2)
		if p != null:
			add_node("bush", p, rng.randf_range(0.9, 1.2), rng.randf() * TAU)
	for i in 220:
		var p = rand_land(1.3, 20.0, 0.8, 2)
		if p != null:
			add_node("hemp", p, rng.randf_range(0.9, 1.3), rng.randf() * TAU)
	for i in 70:
		var p = rand_land(2.0, 25.0, 0.8, 2)
		if p != null:
			add_node("mushroom", p, 1.0, rng.randf() * TAU)
	for i in 170:
		var p = rand_land(0.6, 20.0, 0.8, 2)
		if p != null:
			add_node("pebble", p, 1.0, rng.randf() * TAU)
	for i in 170:
		var p = rand_land(1.2, 20.0, 0.8, 2)
		if p != null:
			add_node("stick", p, 1.0, rng.randf() * TAU)
	for i in 70:
		var p = rand_land(0.9, 9.0, 0.9, 3)
		if p != null:
			add_node("barrel", p, 1.0, rng.randf() * TAU)
	# campamentos de saqueadores
	for ci in 4:
		var ang = ci * TAU / 4.0 + 0.6
		var cpos = null
		for rr in [130.0, 110.0, 150.0, 90.0, 170.0]:
			var x = cos(ang) * rr
			var z = sin(ang) * rr
			var h = get_h(x, z)
			if h > 2.0 and get_ny(x, z) > 0.85:
				cpos = Vector3(x, h, z)
				break
		if cpos == null:
			continue
		for k in 3:
			var a2 = k * TAU / 3.0 + ci
			var rp = cpos + Vector3(cos(a2) * 7.0, 0, sin(a2) * 7.0)
			rp.y = get_h(rp.x, rp.z) - 0.2
			add_node("ruin", rp, 1.0, a2 + PI / 2)
		for k in 2:
			var cp = cpos + Vector3(k * 2.4 - 1.2, 0, 1.0 - k * 2.0)
			cp.y = get_h(cp.x, cp.z)
			add_node("crate", cp, 1.0, rng.randf() * TAU)
		var fp = add_dep("hoguera", cpos, 0.0, false)
		fp["camp"] = true
		for k in 3:
			var a3 = k * TAU / 3.0 + 1.0
			var sp = cpos + Vector3(cos(a3) * 4.0, 0, sin(a3) * 4.0)
			var cr = spawn_creature("saqueador", sp)
			cr["home"] = cpos
	for kind in D.POP:
		for i in D.POP[kind]:
			var p = rand_land(1.5, 30.0, 0.8, 30)
			if p != null:
				spawn_creature(kind, p)


func find_beach() -> Vector3:
	for i in 400:
		var a = rng.randf() * TAU
		for r in range(280, 100, -4):
			var x = cos(a) * r
			var z = sin(a) * r
			var h = get_h(x, z)
			if h > 0.7 and h < 1.6:
				return Vector3(x, h + 0.2, z)
	return Vector3(0, get_h(0, 0) + 1.0, 0)


# ---------------------------------------------------------------- jugador

func make_player() -> void:
	player = CharacterBody3D.new()
	player.collision_layer = 16
	player.collision_mask = L_TERRAIN | L_SOLID | L_BUILD
	player.floor_max_angle = deg_to_rad(50.0)
	player.floor_snap_length = 0.35
	var cap = CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	var cs = CollisionShape3D.new()
	cs.shape = cap
	cs.position.y = 0.9
	player.add_child(cs)
	head = Node3D.new()
	head.position.y = 1.62
	player.add_child(head)
	cam = Camera3D.new()
	cam.near = 0.06
	cam.far = 900.0
	cam.fov = 74.0
	head.add_child(cam)
	vm = MeshInstance3D.new()
	vm.position = vm_base
	vm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cam.add_child(vm)
	torch_light = OmniLight3D.new()
	torch_light.light_color = Color(1.0, 0.7, 0.4)
	torch_light.omni_range = 16.0
	torch_light.light_energy = 2.2
	torch_light.visible = false
	cam.add_child(torch_light)
	flash_light = OmniLight3D.new()
	flash_light.light_color = Color(1.0, 0.85, 0.5)
	flash_light.omni_range = 12.0
	flash_light.light_energy = 0.0
	flash_light.position = Vector3(0.2, -0.1, -1.0)
	cam.add_child(flash_light)
	world_root.add_child(player)
	cam.current = true


func place_menu_cam() -> void:
	var p = find_beach()
	player.position = p
	yaw = atan2(p.x, p.z)
	head.rotation.y = yaw
	cam.rotation.x = -0.05


func new_state() -> void:
	S = {"hp": 100.0, "food": 90.0, "water": 90.0, "cold": 0.0, "armor": "", "spawn": null, "day": 1, "kills": 0}
	inv = []
	inv.resize(24)
	inv[0] = {"id": "roca", "n": 1}
	inv[1] = {"id": "antorcha", "n": 1}
	hot = 0
	time_d = 0.32


func start_new() -> void:
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	seed_v = int(Time.get_unix_time_from_system()) % 1000000 + 17
	gen_world()
	new_state()
	rng.randomize()
	player.position = find_beach()
	yaw = atan2(player.position.x, player.position.z)
	begin_play()
	hud.toast("Has despertado en la playa. Recoge piedras y palos, tala árboles.")


func continue_game() -> void:
	if not load_game():
		start_new()
		return
	begin_play()


func begin_play() -> void:
	playing = true
	panel_open = false
	build_on = false
	held_cache = "?"
	hud.close_panels()
	capture_mouse(true)


func capture_mouse(on: bool) -> void:
	if touch or test_mode:
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func look(dx: float, dy: float) -> void:
	yaw -= dx
	pitch = clamp(pitch - dy, -1.45, 1.45)


func _unhandled_input(ev) -> void:
	if not playing:
		return
	if ev is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(ev.relative.x * 0.0028, ev.relative.y * 0.0028)
	elif ev is InputEventMouseButton and ev.pressed and not panel_open and not touch:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			capture_mouse(true)
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			hud.atk_just = true
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.physical_keycode:
			KEY_E:
				hud.interact_just = true
			KEY_TAB, KEY_I:
				if panel_open:
					hud.close_panels()
				else:
					hud.open_inv(null)
			KEY_B:
				toggle_build()
			KEY_Q:
				cycle_build(1)
			KEY_ESCAPE:
				if panel_open:
					hud.close_panels()
				else:
					capture_mouse(false)
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
				hot = ev.physical_keycode - KEY_1


func _notification(what) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if playing:
			save_game()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		if playing:
			save_game()


func _physics_process(dt: float) -> void:
	if not playing:
		if player != null and not test_mode:
			yaw += dt * 0.05
			head.rotation.y = yaw
		return
	if panel_open:
		return
	time_d += dt / DAY_LEN
	if time_d >= 1.0:
		time_d -= 1.0
		S["day"] += 1
	update_sky()
	move_player(dt)
	update_stats(dt)
	update_creatures(dt)
	update_deps(dt)
	update_held(dt)
	t_scan -= dt
	if t_scan <= 0.0:
		t_scan = 0.1
		scan_target()
		update_ghost()
	handle_actions(dt)
	t_regen -= dt
	if t_regen <= 0.0:
		t_regen = 5.0
		regen_nodes(5.0)
	t_pop -= dt
	if t_pop <= 0.0:
		t_pop = 25.0
		repopulate()
	t_save -= dt
	if t_save <= 0.0:
		t_save = 40.0
		save_game()


func move_player(dt: float) -> void:
	var mv = hud.move_vec
	if not touch and not test_mode:
		var kx = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
		var ky = float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
		if kx != 0.0 or ky != 0.0:
			mv = Vector2(kx, ky).normalized()
		if Input.is_physical_key_pressed(KEY_SPACE):
			hud.jump_just = true
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			hud.atk_held = true
		elif hud.atk_idx == -1:
			hud.atk_held = false
	head.rotation.y = yaw
	cam.rotation.x = pitch
	var fwd = Vector3(-sin(yaw), 0, -cos(yaw))
	var right = Vector3(cos(yaw), 0, -sin(yaw))
	var dir = right * mv.x + fwd * mv.y
	var sp = 5.2
	var in_water = player.position.y < -0.75
	if S["food"] <= 0.0 or S["water"] <= 0.0:
		sp = 3.8
	if in_water:
		sp = 2.6
		var tgt = 1.6 if player.position.y < -1.15 else -0.3
		vel_y = lerp(vel_y, tgt, clamp(dt * 5.0, 0.0, 1.0))
	elif player.is_on_floor():
		if fall_v < -15.0:
			hurt_player((-fall_v - 15.0) * 4.0, false)
		fall_v = 0.0
		vel_y = -1.0
		if hud.jump_just:
			vel_y = 6.2
	else:
		vel_y -= 19.0 * dt
		fall_v = min(fall_v, vel_y)
	hud.jump_just = false
	player.velocity = Vector3(dir.x * sp, vel_y, dir.z * sp)
	player.move_and_slide()
	var p = player.position
	p.x = clamp(p.x, -HALF + 6, HALF - 6)
	p.z = clamp(p.z, -HALF + 6, HALF - 6)
	if p.y < -9.0:
		p.y = get_h(p.x, p.z) + 1.0
	player.position = p
	if dir.length() > 0.1 and player.is_on_floor():
		step_t += dt * 9.0
	vm.position = vm_base + Vector3(0, sin(step_t) * 0.012, 0)


func update_stats(dt: float) -> void:
	S["food"] = max(0.0, S["food"] - dt * 100.0 / 1500.0)
	S["water"] = max(0.0, S["water"] - dt * 100.0 / 1100.0)
	var warm = near_fire(player.position, 9.0)
	var wet = player.position.y < -0.75
	if (is_night() or wet) and not warm:
		var prot = 0.0
		if S["armor"] != "":
			prot = D.ITEMS[S["armor"]]["warm"]
		if held_id() == "antorcha":
			prot = min(1.0, prot + 0.35)
		S["cold"] = min(100.0, S["cold"] + dt * (1.0 - prot) * (1.3 if wet else 0.9))
	else:
		S["cold"] = max(0.0, S["cold"] - dt * (10.0 if warm else 3.0))
	var dmg = 0.0
	if S["food"] <= 0.0:
		dmg += 0.6
	if S["water"] <= 0.0:
		dmg += 0.8
	if S["cold"] >= 100.0:
		dmg += 0.7
	if dmg > 0.0:
		S["hp"] -= dmg * dt
		if S["hp"] <= 0.0:
			die()
	elif S["food"] > 35.0 and S["water"] > 35.0 and S["hp"] < 100.0:
		S["hp"] = min(100.0, S["hp"] + dt * 0.6)


func near_fire(p: Vector3, r: float) -> bool:
	for d in deps:
		if d["k"] == "hoguera" and d["pos"].distance_to(p) < r:
			return true
	return false


func near_station(kind: String) -> bool:
	for d in deps:
		if d["k"] == kind and d["pos"].distance_to(player.position) < 7.0:
			return true
	return false


func hurt_player(dmg: float, armored: bool = true) -> void:
	if armored and S["armor"] != "":
		dmg *= 1.0 - D.ITEMS[S["armor"]]["armor"]
	S["hp"] -= dmg
	hud.hurt_t = 0.5
	if S["hp"] <= 0.0:
		die()


func die() -> void:
	# la mochila se queda donde mueres; conservas la barra rápida
	var bag = []
	for i in range(6, 24):
		if inv[i] != null:
			bag.append(inv[i])
			inv[i] = null
	if bag.size() > 0:
		var bp = player.position
		bp.y = max(get_h(bp.x, bp.z), min(bp.y, get_h(bp.x, bp.z) + 30.0))
		var d = add_dep("mochila", bp, 0.0, false)
		d["items"] = bag
	S["hp"] = 100.0
	S["food"] = 70.0
	S["water"] = 70.0
	S["cold"] = 0.0
	vel_y = 0.0
	fall_v = 0.0
	if S["spawn"] != null:
		player.position = S["spawn"] + Vector3(0, 0.3, 0)
	else:
		player.position = find_beach()
	for c in creatures:
		if c["state"] == "chase":
			c["state"] = "idle"
			c["t"] = 4.0
	hud.banner("HAS MUERTO", "Tu mochila se ha quedado donde caíste.")


# ---------------------------------------------------------------- inventario

func stack_max(id: String) -> int:
	return D.ITEMS[id].get("stack", 200)


func add_item(id: String, cnt: int) -> int:
	var mx = stack_max(id)
	for i in 24:
		if cnt <= 0:
			break
		if inv[i] != null and inv[i]["id"] == id and inv[i]["n"] < mx:
			var a = min(cnt, mx - inv[i]["n"])
			inv[i]["n"] += a
			cnt -= a
	for i in 24:
		if cnt <= 0:
			break
		if inv[i] == null:
			var a = min(cnt, mx)
			inv[i] = {"id": id, "n": a}
			cnt -= a
	return cnt


func give(id: String, cnt: int) -> void:
	var left = add_item(id, cnt)
	if cnt - left > 0:
		hud.toast("+%d %s" % [cnt - left, D.ITEMS[id]["n"]])
	if left > 0:
		hud.toast("Mochila llena")


func count_item(id: String) -> int:
	var t = 0
	for s in inv:
		if s != null and s["id"] == id:
			t += s["n"]
	return t


func take_item(id: String, cnt: int) -> bool:
	if count_item(id) < cnt:
		return false
	for i in range(23, -1, -1):
		if cnt <= 0:
			break
		if inv[i] != null and inv[i]["id"] == id:
			var a = min(cnt, inv[i]["n"])
			inv[i]["n"] -= a
			cnt -= a
			if inv[i]["n"] <= 0:
				inv[i] = null
	return true


func has_cost(cost: Dictionary) -> bool:
	for k in cost:
		if count_item(k) < cost[k]:
			return false
	return true


func pay_cost(cost: Dictionary) -> void:
	for k in cost:
		take_item(k, cost[k])


func cost_text(cost: Dictionary) -> String:
	var parts = []
	for k in cost:
		parts.append("%d %s" % [cost[k], D.ITEMS[k]["n"]])
	return ", ".join(parts)


func can_craft(r: Dictionary) -> bool:
	if r.has("st") and not near_station(r["st"]):
		return false
	return has_cost(r["cost"])


func craft(r: Dictionary) -> void:
	if not can_craft(r):
		return
	pay_cost(r["cost"])
	give(r["id"], r["q"])


func held_id() -> String:
	if inv.size() < 24 or inv[hot] == null:
		return ""
	return inv[hot]["id"]


func use_slot(i: int) -> void:
	# usar desde la mochila: comer, curar, vestir
	if inv[i] == null:
		return
	var id = inv[i]["id"]
	var def = D.ITEMS[id]
	match def["t"]:
		"food":
			S["food"] = min(100.0, S["food"] + def["food"])
			S["water"] = min(100.0, S["water"] + def["water"])
			S["hp"] = clamp(S["hp"] + def["hp"], 1.0, 100.0)
			dec_slot(i)
			hud.toast("Has comido: " + def["n"])
		"med":
			S["hp"] = min(100.0, S["hp"] + def["heal"])
			dec_slot(i)
			hud.toast("Te has vendado")
		"wear":
			var old = S["armor"]
			S["armor"] = id
			inv[i] = null
			if old != "":
				add_item(old, 1)
			hud.toast("Equipado: " + def["n"])


func dec_slot(i: int) -> void:
	inv[i]["n"] -= 1
	if inv[i]["n"] <= 0:
		inv[i] = null


# ---------------------------------------------------------------- acciones

func ray(from: Vector3, to: Vector3, mask: int) -> Dictionary:
	var q = PhysicsRayQueryParameters3D.create(from, to, mask, [player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q)


func update_held(dt: float) -> void:
	var id = held_id()
	var show = id if not build_on else "martillo"
	if show != held_cache:
		held_cache = show
		if show == "":
			vm.mesh = null
		else:
			vm.mesh = M.model("vm_" + show)
	torch_light.visible = id == "antorcha"
	if swing_t > 0.0:
		swing_t = max(0.0, swing_t - dt * 3.2)
		var k = sin((1.0 - swing_t) * PI)
		vm.rotation = Vector3(-k * 1.2, k * 0.25, -0.1)
	else:
		vm.rotation = Vector3(0, 0, -0.1)
	if flash_light.light_energy > 0.0:
		flash_light.light_energy = max(0.0, flash_light.light_energy - dt * 40.0)
	atk_cd = max(0.0, atk_cd - dt)


func handle_actions(_dt: float) -> void:
	var just = hud.atk_just
	hud.atk_just = false
	if hud.interact_just:
		hud.interact_just = false
		do_interact()
	if atk_cd > 0.0:
		return
	if build_on:
		if just:
			place_piece()
			atk_cd = 0.3
		return
	var id = held_id()
	var def = D.FISTS if id == "" else D.ITEMS[id]
	match def["t"]:
		"tool":
			if just or hud.atk_held:
				swing_t = 1.0
				atk_cd = def["cd"]
				do_melee(def)
		"bow":
			if just or hud.atk_held:
				if take_item("flecha", 1):
					swing_t = 0.6
					atk_cd = def["cd"]
					shoot(def["dmg"], 75.0, 0.0, 1)
				elif just:
					hud.toast("No tienes flechas")
		"gun":
			if just or hud.atk_held:
				if take_item("cartucho", 1):
					atk_cd = def["cd"]
					swing_t = 0.5
					flash_light.light_energy = 6.0
					shoot(def["dmg"], 32.0, 0.055, 7)
					alert_raiders(70.0)
				elif just:
					hud.toast("No tienes cartuchos")
		"hammer":
			if just:
				atk_cd = 0.4
				swing_t = 1.0
				upgrade_target()
		"food", "med", "wear":
			if just:
				atk_cd = 0.5
				use_slot(hot)
		"deploy":
			if just:
				atk_cd = 0.4
				place_deploy(id)


func cam_dir() -> Vector3:
	return -cam.global_transform.basis.z


func creature_on_ray(from: Vector3, dir: Vector3, maxd: float, fat: float = 0.0):
	var best = null
	var bt = 1e9
	for c in creatures:
		if c["state"] == "dead":
			continue
		var def = D.CREATURES[c["k"]]
		var ctr = c["pos"] + Vector3(0, def["h"] * 0.55, 0)
		var t = (ctr - from).dot(dir)
		if t < 0.0 or t > maxd + def["r"]:
			continue
		var dd = ctr.distance_to(from + dir * t)
		if dd < def["r"] + fat and t < bt:
			bt = t
			best = c
	return best


func do_melee(def: Dictionary) -> void:
	var from = cam.global_position
	var dir = cam_dir()
	var rg = def.get("range", 2.7)
	var hit = ray(from, from + dir * rg, L_TERRAIN | L_SOLID | L_BUILD)
	var dist = rg
	if hit.size() > 0:
		dist = from.distance_to(hit["position"])
	var c = creature_on_ray(from, dir, dist, 0.15)
	if c != null:
		damage_creature(c, def["dmg"])
		return
	if hit.size() == 0:
		return
	var col = hit["collider"]
	if col.has_meta("nid"):
		hit_node(col.get_meta("nid"), def)


func shoot(dmg: float, rg: float, spread: float, pellets: int) -> void:
	var from = cam.global_position
	var hit_any = false
	for i in pellets:
		var dir = cam_dir()
		if spread > 0.0:
			dir = (dir + Vector3(randf_range(-spread, spread), randf_range(-spread, spread), randf_range(-spread, spread))).normalized()
		var hit = ray(from, from + dir * rg, L_TERRAIN | L_SOLID | L_BUILD)
		var dist = rg
		if hit.size() > 0:
			dist = from.distance_to(hit["position"])
		var c = creature_on_ray(from, dir, dist, 0.2)
		if c != null:
			damage_creature(c, dmg)
			hit_any = true
		elif hit.size() > 0 and hit["collider"].has_meta("nid"):
			var nd = nodes[hit["collider"].get_meta("nid")]
			if nd["k"] == "barrel":
				hit_node(hit["collider"].get_meta("nid"), {"dmg": dmg, "tree": 0, "rock": 0})
	if hit_any:
		hud.hit_t = 0.25


func hit_node(id: int, def: Dictionary) -> void:
	var nd = nodes[id]
	if nd["dead"] > 0.0:
		return
	var k = nd["k"]
	var mi = nd["mi"]
	match k:
		"pine", "oak", "palm":
			var pw = def["tree"]
			if pw <= 0:
				return
			nd["hp"] -= pw
			give("madera", max(1, int(round(pw * 0.6))))
			shake(mi)
			if nd["hp"] <= 0:
				give("madera", 6)
				deplete(nd, 420.0)
		"stone":
			var pw = def["rock"]
			if pw <= 0:
				return
			nd["hp"] -= pw
			give("piedra", max(1, int(round(pw * 0.55))))
			shake(mi)
			if nd["hp"] <= 0:
				give("piedra", 5)
				deplete(nd, 500.0)
		"iron":
			var pw = def["rock"]
			if pw < 10:
				hud.toast("Necesitas un pico para la mena de hierro")
				return
			nd["hp"] -= pw
			give("mena", max(1, int(round(pw * 0.3))))
			if randf() < 0.4:
				give("piedra", 2)
			shake(mi)
			if nd["hp"] <= 0:
				give("mena", 4)
				deplete(nd, 600.0)
		"barrel":
			nd["hp"] -= def.get("dmg", 5)
			shake(mi)
			if nd["hp"] <= 0:
				give("chatarra", randi_range(3, 7))
				if randf() < 0.6:
					give("tela", randi_range(1, 3))
				if randf() < 0.25:
					give("hierro", randi_range(1, 3))
				deplete(nd, 700.0)


func shake(mi: Node3D) -> void:
	var tw = create_tween()
	tw.tween_property(mi, "rotation:z", 0.05, 0.05)
	tw.tween_property(mi, "rotation:z", -0.04, 0.07)
	tw.tween_property(mi, "rotation:z", 0.0, 0.07)


func deplete(nd: Dictionary, t: float) -> void:
	nd["dead"] = t
	nd["node"].visible = false
	nd["node"].process_mode = Node.PROCESS_MODE_DISABLED


func regen_nodes(dt: float) -> void:
	for id in nodes:
		var nd = nodes[id]
		if nd["dead"] > 0.0:
			nd["dead"] -= dt
			if nd["dead"] <= 0.0:
				if nd["pos"].distance_to(player.position) < 45.0:
					nd["dead"] = 20.0
				else:
					nd["dead"] = 0.0
					nd["hp"] = nd["max"]
					nd["node"].visible = true
					nd["node"].process_mode = Node.PROCESS_MODE_INHERIT


func scan_target() -> void:
	target = {}
	if build_on:
		return
	var from = cam.global_position
	var dir = cam_dir()
	var hit = ray(from, from + dir * 3.6, L_TERRAIN | L_SOLID | L_BUILD | L_PICK)
	if hit.size() > 0:
		var col = hit["collider"]
		if col.has_meta("nid"):
			var id = col.get_meta("nid")
			var k = nodes[id]["k"]
			var lbl = {"bush": "Recoger bayas", "hemp": "Recoger fibra", "mushroom": "Recoger seta", "pebble": "Coger piedra", "stick": "Coger palo", "crate": "Abrir caja"}.get(k, "")
			if lbl != "":
				target = {"t": "node", "id": id, "label": lbl}
				return
		elif col.has_meta("dep"):
			var d = col.get_meta("dep")
			target = {"t": "dep", "d": d, "label": dep_label(d)}
			return
		elif col.has_meta("pk"):
			var key = col.get_meta("pk")
			if pieces.has(key):
				var pc = pieces[key]
				if pc["k"] == "doorway" and pc.get("door", false):
					target = {"t": "door", "key": key, "label": "Cerrar puerta" if pc.get("open", false) else "Abrir puerta"}
				if held_id() == "martillo":
					target = {"t": "piece", "key": key, "label": "Demoler"}
				if target.size() > 0:
					return
	# agua
	if dir.y < -0.05:
		var t = -from.y / dir.y
		if t > 0.0 and t < 3.4:
			var wp = from + dir * t
			if get_h(wp.x, wp.z) < -0.05:
				target = {"t": "water", "fresh": is_fresh(wp.x, wp.z), "label": "Beber" if is_fresh(wp.x, wp.z) else "Agua salada"}


func do_interact() -> void:
	if build_on:
		cycle_build(1)
		return
	if target.size() == 0:
		return
	match target["t"]:
		"node":
			var nd = nodes[target["id"]]
			if nd["dead"] > 0.0:
				return
			match nd["k"]:
				"bush":
					give("bayas", randi_range(3, 5))
					deplete(nd, 300.0)
				"hemp":
					give("fibra", randi_range(4, 7))
					deplete(nd, 300.0)
				"mushroom":
					give("seta", randi_range(1, 3))
					deplete(nd, 400.0)
				"pebble":
					give("piedra", randi_range(3, 5))
					deplete(nd, 400.0)
				"stick":
					give("madera", randi_range(4, 6))
					deplete(nd, 400.0)
				"crate":
					give("chatarra", randi_range(6, 12))
					give("tela", randi_range(2, 5))
					var extra = ["venda", "flecha", "cartucho", "hierro", "carne_asada"][randi() % 5]
					give(extra, randi_range(2, 5))
					deplete(nd, 900.0)
		"dep":
			use_dep(target["d"])
		"door":
			var pc = pieces[target["key"]]
			pc["open"] = not pc.get("open", false)
			apply_door(pc)
		"piece":
			demolish(target["key"])
		"water":
			if target["fresh"]:
				S["water"] = min(100.0, S["water"] + 30.0)
				hud.toast("Bebes agua del lago")
			else:
				hud.toast("El agua del mar no se puede beber. Busca el lago del interior.")
	t_scan = 0.0


# ---------------------------------------------------------------- criaturas

func spawn_creature(kind: String, pos: Vector3) -> Dictionary:
	var root = Node3D.new()
	var body = MeshInstance3D.new()
	body.mesh = M.model(kind)
	root.add_child(body)
	var def = D.CREATURES[kind]
	var legs = []
	var lm = M.model("leg_" + kind)
	if kind == "saqueador":
		for s in [-1.0, 1.0]:
			var l = MeshInstance3D.new()
			l.mesh = lm
			l.position = Vector3(s * 0.14, def["leg"], 0)
			root.add_child(l)
			legs.append(l)
		for s in [-1.0, 1.0]:
			var a = MeshInstance3D.new()
			a.mesh = M.model("arm_club" if s > 0 else "arm")
			a.position = Vector3(s * 0.34, 1.5, 0)
			root.add_child(a)
			legs.append(a)
	else:
		var bw = {"ciervo": 0.18, "jabali": 0.24, "lobo": 0.16, "oso": 0.36}[kind]
		var bl = {"ciervo": 0.5, "jabali": 0.45, "lobo": 0.48, "oso": 0.65}[kind]
		for sz in [1.0, -1.0]:
			for sx in [-1.0, 1.0]:
				var l = MeshInstance3D.new()
				l.mesh = lm
				l.position = Vector3(sx * bw, def["leg"], sz * bl)
				root.add_child(l)
				legs.append(l)
	root.position = pos
	body.visibility_range_end = 170.0
	world_root.add_child(root)
	var c = {"k": kind, "node": root, "legs": legs, "pos": pos, "yaw": rng.randf() * TAU, "hp": float(def["hp"]),
		"state": "idle", "t": rng.randf_range(1.0, 5.0), "tgt": pos, "cd": 0.0, "home": pos, "walk": 0.0, "angry": false}
	creatures.append(c)
	return c


func alert_raiders(r: float) -> void:
	for c in creatures:
		if c["k"] == "saqueador" and c["state"] != "dead" and c["pos"].distance_to(player.position) < r:
			c["state"] = "chase"


func damage_creature(c: Dictionary, dmg: float) -> void:
	if c["state"] == "dead":
		return
	c["hp"] -= dmg
	hud.hit_t = 0.25
	var def = D.CREATURES[c["k"]]
	if c["hp"] <= 0.0:
		c["state"] = "dead"
		c["t"] = 7.0
		var tw = create_tween()
		tw.tween_property(c["node"], "rotation:z", PI / 2, 0.35)
		for k in def["loot"]:
			give(k, def["loot"][k])
		if c["k"] == "saqueador":
			var ex = ["flecha", "venda", "cartucho", "carne_asada"][randi() % 4]
			give(ex, randi_range(1, 3))
		S["kills"] += 1
		return
	if def["mode"] == "flee":
		c["state"] = "flee"
		c["t"] = 8.0
	else:
		c["state"] = "chase"
		c["angry"] = true
	# la manada reacciona
	if c["k"] in ["lobo", "saqueador", "jabali"]:
		for o in creatures:
			if o["k"] == c["k"] and o["state"] != "dead" and o["pos"].distance_to(c["pos"]) < 18.0:
				o["state"] = "chase"


func update_creatures(dt: float) -> void:
	var pp = player.position
	var i = creatures.size() - 1
	while i >= 0:
		var c = creatures[i]
		i -= 1
		if c["state"] == "dead":
			c["t"] -= dt
			if c["t"] <= 0.0:
				c["node"].queue_free()
				creatures.erase(c)
			continue
		var def = D.CREATURES[c["k"]]
		var to_p = Vector3(pp.x - c["pos"].x, 0, pp.z - c["pos"].z)
		var dist = to_p.length()
		if dist > 140.0:
			continue
		c["cd"] = max(0.0, c["cd"] - dt)
		var dir = Vector3.ZERO
		var sp = 0.0
		match c["state"]:
			"idle":
				c["t"] -= dt
				if c["t"] <= 0.0:
					var a = randf() * TAU
					var base = c["home"] if c["k"] == "saqueador" else c["pos"]
					c["tgt"] = base + Vector3(cos(a), 0, sin(a)) * randf_range(4.0, 14.0)
					c["state"] = "wander"
					c["t"] = 9.0
			"wander":
				var tv = Vector3(c["tgt"].x - c["pos"].x, 0, c["tgt"].z - c["pos"].z)
				c["t"] -= dt
				if tv.length() < 0.7 or c["t"] <= 0.0:
					c["state"] = "idle"
					c["t"] = randf_range(2.0, 7.0)
				else:
					dir = tv.normalized()
					sp = def["sp"] * 0.3
			"flee":
				c["t"] -= dt
				if dist > 0.01:
					dir = -to_p / dist
				sp = def["sp"]
				if c["t"] <= 0.0 and dist > 30.0:
					c["state"] = "idle"
					c["t"] = 3.0
			"chase":
				var reach = def["r"] + 1.0
				if dist > 0.01 and dist > reach * 0.8:
					dir = to_p / dist
					sp = def["sp"]
				if dist < reach and abs(pp.y - c["pos"].y) < 2.3 and c["cd"] <= 0.0:
					c["cd"] = 1.3
					c["walk"] += 2.0
					hurt_player(def["dmg"])
				if dist > 55.0:
					c["state"] = "idle"
					c["t"] = 2.0
					c["angry"] = false
		if c["state"] == "idle" or c["state"] == "wander":
			if def["mode"] == "hostile":
				var sight = def["sight"] * (1.25 if is_night() else 1.0)
				if dist < sight and abs(pp.y - c["pos"].y) < 8.0:
					c["state"] = "chase"
			elif def["mode"] == "flee" and dist < def["sight"]:
				c["state"] = "flee"
				c["t"] = 6.0
		if sp > 0.0:
			var np = c["pos"] + dir * sp * dt
			var nh = get_h(np.x, np.z)
			var blocked = nh < 0.25
			if not blocked and dist < 45.0 and pieces.size() > 0:
				var from = c["pos"] + Vector3(0, 0.6, 0)
				var hit = ray(from, from + dir * (def["r"] + 0.5), L_BUILD)
				if hit.size() > 0:
					blocked = true
					if c["state"] == "chase" and c["k"] in ["saqueador", "oso"] and c["cd"] <= 0.0 and hit["collider"].has_meta("pk"):
						c["cd"] = 1.4
						damage_piece(hit["collider"].get_meta("pk"), def["dmg"])
			if blocked:
				if c["state"] == "wander":
					c["state"] = "idle"
					c["t"] = 1.0
				elif c["state"] == "flee":
					c["pos"] += Vector3(-dir.z, 0, dir.x) * sp * dt
					c["pos"].y = get_h(c["pos"].x, c["pos"].z)
				sp = 0.0
			else:
				np.y = nh
				c["pos"] = np
				c["yaw"] = lerp_angle(c["yaw"], atan2(dir.x, dir.z), clamp(dt * 8.0, 0.0, 1.0))
		elif c["state"] == "chase" and dist > 0.01:
			c["yaw"] = lerp_angle(c["yaw"], atan2(to_p.x, to_p.z), clamp(dt * 8.0, 0.0, 1.0))
		var nd = c["node"]
		nd.position = c["pos"]
		nd.rotation.y = c["yaw"]
		if sp > 0.0:
			c["walk"] += dt * sp * 2.6
		var sw = sin(c["walk"]) * (0.7 if sp > 0.0 else 0.0)
		var legs = c["legs"]
		for li in legs.size():
			legs[li].rotation.x = sw if (li % 2 == 0) else -sw
		if c["k"] == "saqueador" and c["cd"] > 0.9:
			legs[3].rotation.x = -2.0


func repopulate() -> void:
	var counts = {}
	for c in creatures:
		if c["state"] != "dead":
			counts[c["k"]] = counts.get(c["k"], 0) + 1
	for kind in D.POP:
		if counts.get(kind, 0) < D.POP[kind]:
			for t in 10:
				var p = rand_land(1.5, 30.0, 0.8, 5)
				if p != null and p.distance_to(player.position) > 80.0:
					spawn_creature(kind, p)
					break
	if counts.get("saqueador", 0) < 12 and is_night():
		for d in deps:
			if d.get("camp", false) and d["pos"].distance_to(player.position) > 70.0:
				var near = 0
				for c in creatures:
					if c["k"] == "saqueador" and c["home"].distance_to(d["pos"]) < 2.0 and c["state"] != "dead":
						near += 1
				if near < 3:
					var cr = spawn_creature("saqueador", d["pos"] + Vector3(3, 0, 0))
					cr["home"] = d["pos"]
					break


# ---------------------------------------------------------------- objetos colocables

func add_dep(kind: String, pos: Vector3, ry: float, by_player: bool = true) -> Dictionary:
	var body = StaticBody3D.new()
	body.collision_layer = L_PICK if kind in ["saco", "hoguera", "mochila"] else L_SOLID
	body.collision_mask = 0
	body.position = pos
	body.rotation.y = ry
	var mi = MeshInstance3D.new()
	mi.mesh = M.model(kind)
	body.add_child(mi)
	var sh = BoxShape3D.new()
	sh.size = {"hoguera": Vector3(1.1, 0.5, 1.1), "horno": Vector3(1.2, 1.6, 1.2), "cofre": Vector3(1.0, 0.7, 0.6),
		"saco": Vector3(0.8, 0.25, 1.9), "banco": Vector3(1.7, 0.95, 0.85), "mochila": Vector3(0.8, 0.6, 0.8)}[kind]
	var cs = CollisionShape3D.new()
	cs.shape = sh
	cs.position.y = sh.size.y * 0.5
	body.add_child(cs)
	var d = {"k": kind, "pos": pos, "yaw": ry, "node": body, "items": [], "pin": 0, "pout": 0, "pt": 0.0, "own": by_player}
	if kind == "cofre":
		d["items"].resize(12)
	if kind == "hoguera":
		var fl = MeshInstance3D.new()
		fl.mesh = M.model("flame")
		var fm = StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.vertex_color_use_as_albedo = true
		fl.material_override = fm
		fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(fl)
		var li = OmniLight3D.new()
		li.light_color = Color(1.0, 0.6, 0.3)
		li.omni_range = 11.0
		li.light_energy = 2.0
		li.position.y = 0.8
		li.distance_fade_enabled = true
		li.distance_fade_begin = 60.0
		li.distance_fade_length = 15.0
		body.add_child(li)
		d["flame"] = fl
	body.set_meta("dep", d)
	world_root.add_child(body)
	deps.append(d)
	return d


func dep_label(d: Dictionary) -> String:
	match d["k"]:
		"hoguera":
			if d["pout"] > 0:
				return "Recoger carne asada (%d)" % d["pout"]
			if d["pin"] > 0:
				return "Asando… (%d)" % d["pin"]
			return "Asar carne"
		"horno":
			if d["pout"] > 0:
				return "Recoger hierro (%d)" % d["pout"]
			if d["pin"] > 0:
				return "Fundiendo… (%d)" % d["pin"]
			return "Fundir mena"
		"cofre":
			return "Abrir cofre"
		"saco":
			return "Fijar punto de reaparición"
		"banco":
			return "Usar banco de trabajo"
		"mochila":
			return "Recuperar mochila"
	return ""


func use_dep(d: Dictionary) -> void:
	match d["k"]:
		"hoguera", "horno":
			var src = "carne_cruda" if d["k"] == "hoguera" else "mena"
			var dst = "carne_asada" if d["k"] == "hoguera" else "hierro"
			if d["pout"] > 0:
				give(dst, d["pout"])
				d["pout"] = 0
			var have = min(count_item(src), 30)
			if d["k"] == "horno" and have > 0:
				var wood = count_item("madera")
				have = min(have, wood * 2)
				if have == 0:
					hud.toast("El horno necesita madera como combustible")
					return
				take_item("madera", int(ceil(have / 2.0)))
			if have > 0:
				take_item(src, have)
				d["pin"] += have
				hud.toast("Has puesto %d de %s" % [have, D.ITEMS[src]["n"]])
			elif d["pin"] == 0:
				hud.toast("No tienes %s" % D.ITEMS[src]["n"].to_lower())
		"cofre":
			hud.open_inv(d)
		"saco":
			S["spawn"] = d["pos"]
			hud.toast("Reaparecerás aquí")
		"banco":
			hud.open_inv(null)
		"mochila":
			for it in d["items"]:
				if it != null:
					give(it["id"], it["n"])
			remove_dep(d)


func remove_dep(d: Dictionary) -> void:
	d["node"].queue_free()
	deps.erase(d)


func update_deps(dt: float) -> void:
	for d in deps:
		if d["pin"] > 0:
			d["pt"] += dt
			var need = 5.0 if d["k"] == "hoguera" else 4.0
			if d["pt"] >= need:
				d["pt"] = 0.0
				d["pin"] -= 1
				d["pout"] += 1
		if d.has("flame"):
			d["flame"].scale.y = 0.9 + 0.2 * sin(Time.get_ticks_msec() * 0.012 + d["pos"].x)


func place_deploy(id: String) -> void:
	var from = cam.global_position
	var hit = ray(from, from + cam_dir() * 5.0, L_TERRAIN | L_BUILD | L_SOLID)
	if hit.size() == 0 or hit["normal"].y < 0.7:
		hud.toast("Apunta al suelo, más cerca")
		return
	var p = hit["position"]
	if p.y < 0.1:
		hud.toast("No se puede colocar en el agua")
		return
	take_item(id, 1)
	add_dep(id, p, yaw + PI)
	hud.toast("Colocado: " + D.ITEMS[id]["n"])


# ---------------------------------------------------------------- construcción

func toggle_build() -> void:
	build_on = not build_on
	ghost.visible = false
	t_scan = 0.0
	if build_on:
		hud.toast("Modo construcción: elige pieza y pulsa Colocar")


func cycle_build(d: int) -> void:
	var i = D.BUILD_ORDER.find(build_kind)
	build_kind = D.BUILD_ORDER[(i + d + D.BUILD_ORDER.size()) % D.BUILD_ORDER.size()]
	t_scan = 0.0


func pkey(pre: String, p: Vector3) -> String:
	return "%s_%d_%d_%d" % [pre, roundi(p.x * 2.0), roundi(p.y * 2.0), roundi(p.z * 2.0)]


func surface_y(cx: int, cz: int, py: float):
	var best = null
	var bd = 1.7
	for key in pieces:
		var pc = pieces[key]
		if (pc["k"] == "foundation" or pc["k"] == "floor") and pc["cx"] == cx and pc["cz"] == cz:
			var dd = abs(pc["pos"].y - py)
			if dd < bd:
				bd = dd
				best = pc["pos"].y
	return best


func solid_near(p: Vector3, r: float) -> bool:
	for id in nodes:
		var nd = nodes[id]
		if nd["dead"] <= 0.0 and nd["node"].collision_layer == L_SOLID:
			if abs(nd["pos"].x - p.x) < r and abs(nd["pos"].z - p.z) < r:
				return true
	return false


func update_ghost() -> void:
	ghost_ok = false
	ghost_info = {}
	if not build_on:
		var id = held_id()
		ghost.visible = false
		if id != "" and D.ITEMS[id]["t"] == "deploy":
			var hit0 = ray(cam.global_position, cam.global_position + cam_dir() * 5.0, L_TERRAIN | L_BUILD | L_SOLID)
			if hit0.size() > 0 and hit0["normal"].y >= 0.7:
				ghost.mesh = M.model(id)
				ghost.position = hit0["position"]
				ghost.rotation = Vector3(0, yaw + PI, 0)
				ghost_mat.albedo_color = Color(0.3, 1.0, 0.4, 0.45)
				ghost.visible = true
		return
	var from = cam.global_position
	var dir = cam_dir()
	var flat = Vector3(dir.x, 0, dir.z)
	if flat.length() < 0.01:
		flat = Vector3(-sin(yaw), 0, -cos(yaw))
	flat = flat.normalized()
	var hit = ray(from, from + dir * 6.5, L_TERRAIN | L_BUILD)
	var has_hit = hit.size() > 0
	var p = player.position + flat * 2.6
	if has_hit:
		p = hit["position"]
	var info = {"k": build_kind, "rot": 0}
	var ok = false
	match build_kind:
		"foundation":
			var q = p + flat * 0.25
			var cx = roundi(q.x / 3.0)
			var cz = roundi(q.z / 3.0)
			var ctr = Vector3(cx * 3.0, 0, cz * 3.0)
			var hmin = 1e9
			var hmax = -1e9
			for o in [Vector2(0, 0), Vector2(-1.5, -1.5), Vector2(1.5, -1.5), Vector2(-1.5, 1.5), Vector2(1.5, 1.5)]:
				var hh = get_h(ctr.x + o.x, ctr.z + o.y)
				hmin = min(hmin, hh)
				hmax = max(hmax, hh)
			var y = hmax + 0.3
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nk = "F_%d_%d" % [cx + o.x, cz + o.y]
				if pieces.has(nk):
					y = pieces[nk]["pos"].y
					break
			ctr.y = y
			info["pos"] = ctr
			info["cx"] = cx
			info["cz"] = cz
			info["key"] = "F_%d_%d" % [cx, cz]
			ok = not pieces.has(info["key"]) and hmin > 0.3 and y - hmin < 2.3 and hmax < y + 0.5 and not solid_near(ctr, 2.3)
		"wall", "doorway", "window":
			var done = false
			if has_hit and hit["collider"].has_meta("pk") and pieces.has(hit["collider"].get_meta("pk")):
				var hp = pieces[hit["collider"].get_meta("pk")]
				if hp["k"] in WALLS and p.y > hp["pos"].y + 1.6:
					info["pos"] = hp["pos"] + Vector3(0, 3, 0)
					info["rot"] = hp["rot"]
					done = true
			if not done:
				var cx = roundi(p.x / 3.0)
				var cz = roundi(p.z / 3.0)
				var sy = surface_y(cx, cz, p.y)
				var d = Vector3(p.x - cx * 3.0, 0, p.z - cz * 3.0)
				if sy == null:
					cx = roundi(player.position.x / 3.0)
					cz = roundi(player.position.z / 3.0)
					sy = surface_y(cx, cz, player.position.y)
					d = flat
				if sy != null:
					var rot = 0
					if abs(d.x) > abs(d.z):
						rot = 1 if d.x > 0 else 3
					else:
						rot = 0 if d.z > 0 else 2
					var off = [Vector3(0, 0, 1.5), Vector3(1.5, 0, 0), Vector3(0, 0, -1.5), Vector3(-1.5, 0, 0)][rot]
					info["pos"] = Vector3(cx * 3.0, sy, cz * 3.0) + off
					info["rot"] = rot
					done = true
			if done:
				info["key"] = pkey("W", info["pos"])
				ok = not pieces.has(info["key"])
		"floor":
			var q = p - flat * 0.3 if has_hit else p
			var cx = roundi(q.x / 3.0)
			var cz = roundi(q.z / 3.0)
			var ctr = Vector3(cx * 3.0, 0, cz * 3.0)
			var best = null
			var bd = 3.3
			for key in pieces:
				var pc = pieces[key]
				var cand = null
				if pc["k"] in WALLS:
					if abs(pc["pos"].x - ctr.x) + abs(pc["pos"].z - ctr.z) < 1.6:
						cand = pc["pos"].y + 3.0
				elif pc["k"] == "floor":
					if abs(pc["cx"] - cx) + abs(pc["cz"] - cz) == 1:
						cand = pc["pos"].y
				if cand != null:
					var dd = abs(cand - (q.y + 0.4))
					if dd < bd:
						bd = dd
						best = cand
			if best != null:
				ctr.y = best
				info["pos"] = ctr
				info["cx"] = cx
				info["cz"] = cz
				info["key"] = "L_%d_%d_%d" % [cx, roundi(best * 2.0), cz]
				ok = not pieces.has(info["key"])
		"stairs":
			var cx = roundi(p.x / 3.0)
			var cz = roundi(p.z / 3.0)
			var sy = surface_y(cx, cz, p.y)
			if sy != null:
				info["pos"] = Vector3(cx * 3.0, sy, cz * 3.0)
				info["cx"] = cx
				info["cz"] = cz
				info["rot"] = posmod(roundi(atan2(flat.x, flat.z) / (PI / 2)), 4)
				info["key"] = "S_%d_%d_%d" % [cx, roundi(sy * 2.0), cz]
				ok = not pieces.has(info["key"])
		"door":
			if has_hit and hit["collider"].has_meta("pk") and pieces.has(hit["collider"].get_meta("pk")):
				var hp = pieces[hit["collider"].get_meta("pk")]
				if hp["k"] == "doorway" and not hp.get("door", false):
					info["pos"] = hp["pos"] + Vector3(0, 0, 0)
					info["rot"] = hp["rot"]
					info["key"] = hit["collider"].get_meta("pk")
					ok = true
	if not info.has("pos"):
		ghost.visible = false
		return
	var enough = has_cost(D.BUILD[build_kind]["cost"])
	ghost.mesh = M.model(build_kind + "_0")
	ghost.position = info["pos"]
	ghost.rotation = Vector3(0, piece_ry(build_kind, info["rot"]), 0)
	if build_kind == "door":
		ghost.position = info["pos"] + Basis(Vector3.UP, ghost.rotation.y) * Vector3(-0.58, 0.02, 0)
	ghost_mat.albedo_color = Color(0.3, 1.0, 0.4, 0.45) if (ok and enough) else Color(1.0, 0.25, 0.2, 0.45)
	ghost.visible = true
	ghost_ok = ok
	ghost_info = info


func piece_ry(kind: String, rot: int) -> float:
	if kind == "stairs":
		return rot * PI / 2
	if kind in WALLS or kind == "door":
		return PI / 2 if rot % 2 == 1 else 0.0
	return 0.0


func place_piece() -> void:
	t_scan = 0.0
	update_ghost()
	if not ghost_info.has("pos"):
		hud.toast("Apunta a un cimiento o al suelo")
		return
	if not ghost_ok:
		hud.toast("No se puede colocar ahí")
		return
	var cost = D.BUILD[build_kind]["cost"]
	if not has_cost(cost):
		hud.toast("Te falta: " + cost_text(cost))
		return
	pay_cost(cost)
	if build_kind == "door":
		var pc = pieces[ghost_info["key"]]
		pc["door"] = true
		pc["open"] = false
		rebuild_piece(ghost_info["key"])
	else:
		var pc = {"k": build_kind, "pos": ghost_info["pos"], "rot": ghost_info["rot"], "tier": 0, "hp": D.TIER_HP[0],
			"cx": ghost_info.get("cx", 0), "cz": ghost_info.get("cz", 0)}
		make_piece(ghost_info["key"], pc)
		if build_kind == "foundation":
			var pp = player.position
			if abs(pp.x - pc["pos"].x) < 1.85 and abs(pp.z - pc["pos"].z) < 1.85 and pp.y < pc["pos"].y:
				player.position.y = pc["pos"].y + 0.1
	update_ghost()


func piece_boxes(kind: String) -> Array:
	match kind:
		"foundation":
			return [[Vector3(3, 2.4, 3), Vector3(0, -1.2, 0)]]
		"wall":
			return [[Vector3(3, 3, 0.2), Vector3(0, 1.5, 0)]]
		"doorway":
			return [[Vector3(0.9, 3, 0.2), Vector3(-1.05, 1.5, 0)], [Vector3(0.9, 3, 0.2), Vector3(1.05, 1.5, 0)], [Vector3(1.2, 0.8, 0.2), Vector3(0, 2.6, 0)]]
		"window":
			return [[Vector3(3, 1.0, 0.2), Vector3(0, 0.5, 0)], [Vector3(3, 0.8, 0.2), Vector3(0, 2.6, 0)], [Vector3(0.9, 1.2, 0.2), Vector3(-1.05, 1.6, 0)], [Vector3(0.9, 1.2, 0.2), Vector3(1.05, 1.6, 0)]]
		"floor":
			return [[Vector3(3, 0.2, 3), Vector3(0, -0.1, 0)]]
	return []


func make_piece(key: String, pc: Dictionary) -> void:
	var body = StaticBody3D.new()
	body.collision_layer = L_BUILD
	body.collision_mask = 0
	body.position = pc["pos"]
	body.rotation.y = piece_ry(pc["k"], pc["rot"])
	var mi = MeshInstance3D.new()
	mi.mesh = M.model("%s_%d" % [pc["k"], pc["tier"]])
	body.add_child(mi)
	for bx in piece_boxes(pc["k"]):
		var sh = BoxShape3D.new()
		sh.size = bx[0]
		var cs = CollisionShape3D.new()
		cs.shape = sh
		cs.position = bx[1]
		body.add_child(cs)
	if pc["k"] == "stairs":
		var sh = BoxShape3D.new()
		sh.size = Vector3(2.8, 0.2, 4.243)
		var cs = CollisionShape3D.new()
		cs.shape = sh
		cs.position = Vector3(0, 1.38, 0)
		cs.rotation.x = -PI / 4
		body.add_child(cs)
	body.set_meta("pk", key)
	if pc["k"] == "doorway" and pc.get("door", false):
		var hinge = AnimatableBody3D.new()
		hinge.sync_to_physics = false
		hinge.collision_layer = L_BUILD
		hinge.collision_mask = 0
		hinge.position = Vector3(-0.58, 0.02, 0)
		var dm = MeshInstance3D.new()
		dm.mesh = M.model("door_%d" % pc["tier"])
		hinge.add_child(dm)
		var dsh = BoxShape3D.new()
		dsh.size = Vector3(1.16, 2.16, 0.1)
		var dcs = CollisionShape3D.new()
		dcs.shape = dsh
		dcs.position = Vector3(0.58, 1.08, 0)
		hinge.add_child(dcs)
		hinge.set_meta("pk", key)
		body.add_child(hinge)
		pc["hinge"] = hinge
	world_root.add_child(body)
	pc["node"] = body
	pieces[key] = pc
	apply_door(pc)


func apply_door(pc: Dictionary) -> void:
	if pc.has("hinge") and is_instance_valid(pc["hinge"]):
		pc["hinge"].rotation.y = -1.5 if pc.get("open", false) else 0.0


func rebuild_piece(key: String) -> void:
	var pc = pieces[key]
	pc["node"].queue_free()
	pc.erase("hinge")
	make_piece(key, pc)


func upgrade_target() -> void:
	var from = cam.global_position
	var hit = ray(from, from + cam_dir() * 4.0, L_BUILD)
	if hit.size() == 0 or not hit["collider"].has_meta("pk"):
		hud.toast("Golpea una pieza de tu base para mejorarla")
		return
	var key = hit["collider"].get_meta("pk")
	var pc = pieces[key]
	if pc["hp"] < D.TIER_HP[pc["tier"]]:
		if take_item(D.TIER_NAME[pc["tier"]], 3):
			pc["hp"] = D.TIER_HP[pc["tier"]]
			hud.toast("Pieza reparada")
		else:
			hud.toast("Reparar cuesta 3 de " + D.TIER_NAME[pc["tier"]])
		return
	if pc["tier"] >= 2:
		hud.toast("Ya es de hierro")
		return
	var cost = D.TIER_COST[pc["tier"] + 1]
	if not has_cost(cost):
		hud.toast("Mejorar cuesta: " + cost_text(cost))
		return
	pay_cost(cost)
	pc["tier"] += 1
	pc["hp"] = D.TIER_HP[pc["tier"]]
	rebuild_piece(key)
	hud.toast("Mejorado a " + D.TIER_NAME[pc["tier"]])


func demolish(key: String) -> void:
	if not pieces.has(key):
		return
	var pc = pieces[key]
	give("madera", 6)
	pc["node"].queue_free()
	pieces.erase(key)


func damage_piece(key: String, dmg: float) -> void:
	if not pieces.has(key):
		return
	var pc = pieces[key]
	pc["hp"] -= dmg
	if pc["hp"] <= 0:
		pc["node"].queue_free()
		pieces.erase(key)
		hud.toast("¡Han destrozado parte de tu base!")


# ---------------------------------------------------------------- guardado

func v3a(v: Vector3) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]


func a3v(a) -> Vector3:
	return Vector3(a[0], a[1], a[2])


func save_game() -> void:
	if not playing or test_mode and shot_dir != "":
		return
	var pcs = []
	for key in pieces:
		var pc = pieces[key]
		pcs.append({"key": key, "k": pc["k"], "pos": v3a(pc["pos"]), "rot": pc["rot"], "tier": pc["tier"], "hp": pc["hp"],
			"cx": pc["cx"], "cz": pc["cz"], "door": pc.get("door", false), "open": pc.get("open", false)})
	var dps = []
	for d in deps:
		if d.get("camp", false):
			continue
		dps.append({"k": d["k"], "pos": v3a(d["pos"]), "yaw": d["yaw"], "items": d["items"], "pin": d["pin"], "pout": d["pout"]})
	var data = {"v": 1, "seed": seed_v, "S": S.duplicate(), "inv": inv, "hot": hot, "time": time_d,
		"pos": v3a(player.position), "yaw": yaw, "pieces": pcs, "deps": dps}
	if S["spawn"] != null:
		data["S"]["spawn"] = v3a(S["spawn"])
	var f = FileAccess.open(SAVE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))
		f.close()


func fix_slots(arr, size: int) -> Array:
	var out = []
	out.resize(size)
	for i in min(size, arr.size()):
		var s = arr[i]
		if s != null and D.ITEMS.has(s["id"]):
			out[i] = {"id": s["id"], "n": int(s["n"])}
	return out


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE):
		return false
	var f = FileAccess.open(SAVE, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY or not data.has("seed"):
		return false
	seed_v = int(data["seed"])
	gen_world()
	new_state()
	for k in data["S"]:
		S[k] = data["S"][k]
	S["day"] = int(S["day"])
	S["kills"] = int(S["kills"])
	if S["spawn"] != null:
		S["spawn"] = a3v(S["spawn"])
	inv = fix_slots(data["inv"], 24)
	hot = int(data["hot"])
	time_d = data["time"]
	player.position = a3v(data["pos"]) + Vector3(0, 0.2, 0)
	yaw = data["yaw"]
	for pd in data["pieces"]:
		var pc = {"k": pd["k"], "pos": a3v(pd["pos"]), "rot": int(pd["rot"]), "tier": int(pd["tier"]), "hp": pd["hp"],
			"cx": int(pd["cx"]), "cz": int(pd["cz"]), "door": pd["door"], "open": pd["open"]}
		make_piece(pd["key"], pc)
	for dd in data["deps"]:
		var d = add_dep(dd["k"], a3v(dd["pos"]), dd["yaw"])
		if dd["k"] == "cofre":
			d["items"] = fix_slots(dd["items"], 12)
		else:
			d["items"] = fix_slots(dd["items"], dd["items"].size())
		d["pin"] = int(dd["pin"])
		d["pout"] = int(dd["pout"])
	rng.randomize()
	return true


# ---------------------------------------------------------------- prueba automática

func shot(name: String) -> void:
	if shot_dir == "":
		return
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	img.save_png(shot_dir + "/" + name + ".png")
	print("captura ", name)


func wait_f(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func run_test() -> void:
	shot_dir = OS.get_environment("HR_SHOTS") if OS.has_environment("HR_SHOTS") else ""
	var t0 = Time.get_ticks_msec()
	seed_v = 4242
	gen_world()
	print("mundo generado en ", Time.get_ticks_msec() - t0, " ms; nodos=", nodes.size(), " criaturas=", creatures.size())
	place_menu_cam()
	hud.show_start(false)
	await wait_f(5)
	await shot("01_menu")
	new_state()
	rng.seed = 99
	player.position = find_beach()
	yaw = atan2(player.position.x, player.position.z)
	begin_play()
	await wait_f(40)
	assert(player.is_on_floor(), "el jugador no toca el suelo")
	await shot("02_playa")
	yaw += PI
	pitch = -0.1
	await wait_f(3)
	await shot("02b_mar")
	yaw -= PI
	pitch = 0.0
	# caminar hacia el interior
	hud.move_vec = Vector2(0, 1)
	await wait_f(240)
	hud.move_vec = Vector2.ZERO
	var moved = player.position.distance_to(find_beach())
	print("jugador en ", player.position, " h=", get_h(player.position.x, player.position.z))
	await shot("03_interior")
	# talar el árbol más cercano
	var tree = null
	var bd = 1e9
	for id in nodes:
		var nd = nodes[id]
		if nd["k"] in ["pine", "oak"] and nd["pos"].distance_to(player.position) < bd:
			bd = nd["pos"].distance_to(player.position)
			tree = nd
	var tp = tree["pos"]
	var off = Vector3(1.5, 0, 0)
	player.position = tp + off + Vector3(0, 0.5, 0)
	yaw = atan2(off.x, off.z)
	pitch = 0.0
	await wait_f(20)
	hud.atk_held = true
	await wait_f(200)
	hud.atk_held = false
	print("madera tras talar: ", count_item("madera"))
	assert(count_item("madera") > 0, "talar no da madera")
	await shot("04_talando")
	# fabricar
	add_item("madera", 400)
	add_item("piedra", 200)
	add_item("fibra", 60)
	add_item("hierro", 60)
	add_item("chatarra", 60)
	for r in D.RECIPES:
		if not r.has("st"):
			craft(r)
	assert(count_item("hacha_piedra") == 1 and count_item("banco") == 1, "fabricar falla")
	hud.open_inv(null)
	await wait_f(5)
	await shot("05_mochila")
	hud.close_panels()
	# construir una caseta en terreno llano
	var flatp = null
	for i in 4000:
		var p = rand_land(2.0, 8.0, 0.985, 1)
		if p != null and p.distance_to(Vector3(LAKE.x, p.y, LAKE.y)) > 60.0 and not solid_near(p, 14.0):
			flatp = p
			break
	if flatp == null:
		flatp = rand_land(2.0, 12.0, 0.95, 500)
	player.position = flatp + Vector3(0, 0.5, 0)
	await wait_f(30)
	build_on = true
	var cx0 = roundi(player.position.x / 3.0) + 1
	var cz0 = roundi(player.position.z / 3.0) + 1
	var placed = 0
	for dz in 2:
		for dx in 2:
			var ctr = Vector3((cx0 + dx) * 3.0, 0, (cz0 + dz) * 3.0)
			placed += int(await test_place("foundation", ctr + Vector3(0, get_h(ctr.x, ctr.z), 0), ctr + Vector3(-4, get_h(ctr.x, ctr.z) + 2.0, -4)))
	print("cimientos: ", placed)
	assert(placed == 4, "no se pudieron colocar los cimientos")
	var fy = pieces["F_%d_%d" % [cx0, cz0]]["pos"].y
	var mid = Vector3((cx0 + 0.5) * 3.0, fy, (cz0 + 0.5) * 3.0)
	player.position = mid + Vector3(0, 0.2, 0)
	await wait_f(20)
	assert(abs(player.position.y - fy) < 0.3, "el jugador no se apoya en el cimiento")
	var walls = 0
	var edges = [[0, 0, Vector3(0, 0, -1.4), "wall"], [1, 0, Vector3(0, 0, -1.4), "window"], [1, 0, Vector3(1.4, 0, 0), "wall"], [1, 1, Vector3(1.4, 0, 0), "wall"],
		[1, 1, Vector3(0, 0, 1.4), "wall"], [0, 1, Vector3(0, 0, 1.4), "doorway"], [0, 1, Vector3(-1.4, 0, 0), "wall"], [0, 0, Vector3(-1.4, 0, 0), "wall"]]
	for e in edges:
		var ctr = Vector3((cx0 + e[0]) * 3.0, fy, (cz0 + e[1]) * 3.0)
		walls += int(await test_place(e[3], ctr + e[2], mid + Vector3(0, 1.82, 0)))
	print("muros: ", walls)
	assert(walls == 8, "no se pudieron colocar los muros")
	var dw = null
	for key in pieces:
		if pieces[key]["k"] == "doorway":
			dw = pieces[key]
	assert(await test_place("door", dw["pos"] + Vector3(0.9, 1.5, 0), mid + Vector3(0, 1.82, 0)), "no se colocó la puerta")
	var fl = 0
	for dz in 2:
		for dx in 2:
			if dx == 0 and dz == 0:
				continue
			var ctr = Vector3((cx0 + dx) * 3.0, fy + 3.0, (cz0 + dz) * 3.0)
			var aim = ctr
			if dx == 1 and dz == 1:
				aim = Vector3(ctr.x + 1.45, fy + 2.4, ctr.z)
			elif dx == 1:
				aim = Vector3(ctr.x + 1.45, fy + 2.4, ctr.z)
			else:
				aim = Vector3(ctr.x - 1.45, fy + 2.4, ctr.z)
			fl += int(await test_place("floor", aim, mid + Vector3(0, 1.82, 0)))
	print("suelos: ", fl)
	assert(fl == 3, "no se pudieron colocar los suelos del techo")
	var c00 = Vector3(cx0 * 3.0, fy, cz0 * 3.0)
	build_kind = "stairs"
	player.position = c00 + Vector3(0.3, 0.2, 2.4)
	yaw = 0.0
	pitch = -0.9
	await wait_f(12)
	hud.atk_just = true
	await wait_f(12)
	var st = 0
	for key in pieces:
		if pieces[key]["k"] == "stairs":
			st += 1
			print("escalera rot=", pieces[key]["rot"])
	assert(st == 1, "no se colocó la escalera")
	build_on = false
	ghost.visible = false
	# subir la escalera andando
	var sk = ""
	for key in pieces:
		if pieces[key]["k"] == "stairs":
			sk = key
	var sdir = Basis(Vector3.UP, pieces[sk]["rot"] * PI / 2) * Vector3(0, 0, 1)
	player.position = c00 - sdir * 1.2 + Vector3(0, 0.3, 0)
	yaw = atan2(-sdir.x, -sdir.z)
	pitch = 0.0
	await wait_f(10)
	hud.move_vec = Vector2(0, 1)
	var maxy = 0.0
	for i in 90:
		await get_tree().physics_frame
		maxy = max(maxy, player.position.y - fy)
	hud.move_vec = Vector2.ZERO
	print("altura tras escalera: ", maxy)
	assert(maxy > 2.5, "no se puede subir la escalera")
	# mejorar y objetos colocables
	hot = 2
	inv[2] = {"id": "martillo", "n": 1}
	player.position = mid + Vector3(0, 0.2, 0)
	yaw = 0.0
	pitch = 0.0
	await wait_f(10)
	hud.atk_just = true
	await wait_f(40)
	var up = 0
	for key in pieces:
		if pieces[key]["tier"] == 1:
			up += 1
	assert(up == 1, "mejorar a piedra falla")
	var di = 0
	for it in ["hoguera", "cofre", "banco"]:
		take_item(it, 99)
		inv[3] = {"id": it, "n": 1}
		hot = 3
		yaw = [-0.785, 2.356, 3.927][di]
		pitch = -1.0
		await wait_f(8)
		hud.atk_just = true
		await wait_f(30)
		di += 1
	var own = 0
	for d in deps:
		if d["own"]:
			own += 1
	print("colocables: ", own)
	assert(own == 3, "colocar objetos falla")
	assert(near_station("banco"), "banco no detectado")
	add_item("madera", 200)
	add_item("piedra", 100)
	for r in D.RECIPES:
		if r.has("st"):
			craft(r)
	assert(count_item("escopeta") == 1, "recetas de banco fallan")
	# asar carne
	add_item("carne_cruda", 2)
	for d in deps:
		if d["k"] == "hoguera" and d["own"]:
			use_dep(d)
			for i in 12:
				update_deps(1.0)
			assert(d["pout"] == 2, "la hoguera no asa")
			use_dep(d)
	assert(count_item("carne_asada") == 2, "no se recoge la carne")
	player.position = mid + Vector3(-6.5, 1.5, 6.5)
	yaw = atan2(-6.5, 6.5)
	pitch = -0.12
	await wait_f(30)
	await shot("06_base")
	# combate
	var wolf = spawn_creature("lobo", player.position + Vector3(-0.707, 0, 0.707) * 7.0)
	wolf["pos"].y = get_h(wolf["pos"].x, wolf["pos"].z)
	inv[4] = {"id": "escopeta", "n": 1}
	add_item("cartucho", 12)
	hot = 4
	yaw = atan2(0.707, -0.707)
	pitch = -0.15
	var hp0 = S["hp"]
	await wait_f(15)
	await shot("07_lobo")
	hud.atk_held = true
	for i in 600:
		var to_w = wolf["pos"] + Vector3(0, 0.5, 0) - cam.global_position
		yaw = atan2(-to_w.x, -to_w.z)
		pitch = asin(clamp(to_w.normalized().y, -1.0, 1.0))
		await get_tree().physics_frame
		if wolf["state"] == "dead":
			break
	hud.atk_held = false
	print("lobo: ", wolf["state"], " vida jugador ", hp0, " -> ", S["hp"], " cuero=", count_item("cuero"))
	assert(wolf["state"] == "dead", "no se pudo matar al lobo")
	# noche
	time_d = 0.02
	inv[5] = {"id": "antorcha", "n": 1}
	hot = 5
	player.position = mid + Vector3(-5, 1.0, 5)
	yaw = atan2(-5.0, 5.0)
	pitch = -0.05
	await wait_f(30)
	await shot("08_noche")
	# muerte y reaparición
	add_item("piedra", 5)
	S["hp"] = 1.0
	hurt_player(50.0)
	await wait_f(5)
	assert(S["hp"] == 100.0, "reaparición falla")
	var bags = 0
	for d in deps:
		if d["k"] == "mochila":
			bags += 1
	assert(bags == 1, "la mochila no se queda al morir")
	# guardar y cargar
	shot_dir = ""
	var np = pieces.size()
	var nd2 = 0
	for d in deps:
		if not d.get("camp", false):
			nd2 += 1
	save_game()
	var ok = load_game()
	var nd3 = 0
	for d in deps:
		if not d.get("camp", false):
			nd3 += 1
	print("guardado: piezas ", np, " -> ", pieces.size(), " colocables ", nd2, " -> ", nd3)
	assert(ok and pieces.size() == np and nd3 == nd2, "guardar/cargar falla")
	begin_play()
	await wait_f(30)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("HR_TEST_OK piezas=", np, " movido=", snappedf(moved, 0.1), " dia=", S["day"])
	get_tree().quit()


func test_place(kind: String, aim: Vector3, from_pos: Vector3) -> bool:
	build_kind = kind
	var before = pieces.size()
	var doors = 0
	for key in pieces:
		if pieces[key].get("door", false):
			doors += 1
	player.position = from_pos - Vector3(0, 1.62, 0)
	player.velocity = Vector3.ZERO
	vel_y = 0.0
	var to = aim - from_pos
	yaw = atan2(-to.x, -to.z)
	pitch = asin(clamp(to.normalized().y, -1.0, 1.0))
	head.rotation.y = yaw
	cam.rotation.x = pitch
	player.force_update_transform()
	head.force_update_transform()
	cam.force_update_transform()
	place_piece()
	await get_tree().physics_frame
	var doors2 = 0
	for key in pieces:
		if pieces[key].get("door", false):
			doors2 += 1
	return pieces.size() > before or doors2 > doors
