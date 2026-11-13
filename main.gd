extends Node3D
# Ciudad Mirasol — bucle principal: jugador, cámara, vecinos, tráfico, día y noche, acciones.

const World = preload("res://world.gd")
const Actors = preload("res://actors.gd")
const Hud = preload("res://hud.gd")
const Shaders = preload("res://shaders.gd")
const MB = preload("res://mb.gd")
const HOUSE_KINDS := ["casaA", "casaB", "piso"]
const LOOT := {"super": [150, 300], "cafe": [80, 160], "muebles": [200, 350], "gym": [100, 200], "gasolinera": [200, 400], "banco": [900, 1600]}
const HOME_UPG := [["alarm", "Alarma y escondite", 400, "Alarma instalada: al entrar en esta casa pierdes las estrellas."], ["rent", "Habitación de alquiler", 700, "Habitación alquilada: +§60 cada día."], ["pool", "Piscina en el jardín", 900, "Piscina construida: la casa vale más y te da +§40 cada día."]]

const NAMES_F := ["Marta", "Lucía", "Carmen", "Sofía", "Elena", "Paula", "Irene", "Nuria", "Alba", "Rocío", "Inés", "Clara", "Vera", "Noa"]
const NAMES_M := ["Hugo", "Dani", "Pablo", "Javi", "Álex", "Mario", "Iván", "Leo", "Rubén", "Óscar", "Luis", "Marcos", "Adrián", "Sergio"]
const PHRASES := ["¡Qué buen día hace hoy!", "¿Has probado la tarta del Café Luna?", "Dicen que van a abrir más tiendas.", "Me encanta pasear por el parque.", "¡Hola, vecino! ¿Qué tal todo?", "El gimnasio Titán está genial.", "Hoy hay mucho tráfico, ¿eh?", "Tu casa amarilla es la más bonita del barrio.", "¿Nos vemos luego en la plaza?", "En Muebles Nido hay sofás muy cómodos.", "Esta ciudad cada día está más animada."]
const DAYS := ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"]
const PRICES := {"sofa": 150, "lampara": 45, "estanteria": 90, "planta": 25, "tele": 220, "alfombra": 60}
const ITEM_NAMES := {"sofa": "el sofá", "lampara": "la lámpara", "estanteria": "la estantería", "planta": "la planta", "tele": "la tele grande", "alfombra": "la alfombra"}
const CORN := [[-1, -1], [1, -1], [1, 1], [-1, 1]]
const MIRROR_X := [1, 0, 3, 2]
const MIRROR_Z := [3, 2, 1, 0]
const SAVE_PATH := "user://ciudad_mirasol.cfg"

var W
var hud
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ShaderMaterial
var sky_ms := -10000
var player: Node3D
var bob: MeshInstance3D
var ppos := Vector3.ZERO
var pyaw := 0.0
var pphase := 0.0
var pwalk := 0.0
var cam_yaw := 0.0
var cam_pitch := 0.5
var cam_dist := 10.0
var cam_snap := true
var inside := ""
var place_name := ""
var return_pos := Vector3.ZERO
var return_yaw := 0.0
var host_name := "tu vecino"
var started := false
var busy := false
var time_h := 9.0
var day := 0
var money := 500
var needs := {"hambre": 80.0, "energia": 85.0, "diversion": 70.0, "social": 60.0}
var owned: Dictionary = {}
var npcs: Array = []
var cars: Array = []
var static_nodes: Array = []
var joy_id := -1
var cam_id := -1
var joy_origin := Vector2.ZERO
var joy_vec := Vector2.ZERO
var cur_action: Dictionary = {}
var save_t := 0.0
var warn_t := 20.0
var title_a := 0.0
var rng := RandomNumberGenerator.new()
var test_cam := false
# --- modo GTA
var driving: Dictionary = {}
var wanted := 0
var evade_t := 0.0
var bust_t := 0.0
var pol_t := 0.0
var pol_near := 1e9
var police: Array = []
var punch_t := 0.0
var crash_cd := 0.0
var mission: Dictionary = {}
var mission_cd := 0.0
var mission_n := 0
var beacon: MeshInstance3D
var m_markers: Array = []
var traffic_t := 0.0
var ai_made := 0
var smoke: CPUParticles3D
# --- casas, coches y atracos
var houses: Dictionary = {}
var house_marks: Dictionary = {}
var pool_nodes: Dictionary = {}
var home_idx := -1
var cur_door := -1
var cur_owned := false
var menu_cb: Callable
var menu_ctx: Dictionary = {}
var rob_cd: Dictionary = {}
var hands: Dictionary = {}
var no_hide_t := 0.0
var my_car: Dictionary = {}
var mycar_data: Dictionary = {}
var shots_dir := ""


func _ready() -> void:
	rng.seed = 4242
	W = World.new()
	W.build(self)
	_setup_env()
	player = Actors.person(W.mat_solid, Color(0.93, 0.74, 0.58), Color(0.98, 0.78, 0.2), Color(0.2, 0.3, 0.55), Color(0.32, 0.2, 0.1), false)
	add_child(player)
	bob = Actors.plumbob()
	bob.position.y = 2.05
	player.add_child(bob)
	ppos = W.spawn
	_spawn_npcs()
	_spawn_cars()
	_spawn_statics()
	hud = Hud.new()
	add_child(hud)
	hud.action_pressed.connect(_do_action)
	hud.punch_pressed.connect(_punch)
	hud.menu_chosen.connect(_on_menu)
	_setup_gta()
	hud.play_pressed.connect(_on_play)
	hud.zoom_pressed.connect(func(dir): cam_dist = clampf(cam_dist + dir * 2.5, 4.5, 26.0))
	for i in W.doors.size():
		if W.doors[i].kind == "hogar":
			home_idx = i
	_load()
	if not houses.has(str(home_idx)):
		houses[str(home_idx)] = {}
	_apply_owned()
	_apply_houses()
	_restore_car()
	_update_time(0.0)
	if OS.get_environment("CM_TEST") != "":
		shots_dir = OS.get_environment("CM_SHOTS")
		_run_test()


func _setup_env() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	sky_mat = Shaders.material(Shaders.SKY, W.noise)
	var sky := Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.07
	env.adjustment_saturation = 0.98
	env.fog_enabled = true
	env.fog_density = 0.0007
	env.fog_sky_affect = 0.25
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.1
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 110.0
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.5
	add_child(sun)
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.3
	cam.far = 1300.0
	add_child(cam)
	cam.make_current()


# ---------------------------------------------------------------- vecinos y tráfico

func _wp(i: int, j: int, k: int) -> Vector3:
	var c := World.block_center(i, j)
	return Vector3(c.x + CORN[k][0] * 23.3, 0.16, c.z + CORN[k][1] * 23.3)


func _wp_next(cur: Array, prev: Array) -> Array:
	var i: int = cur[0]
	var j: int = cur[1]
	var k: int = cur[2]
	var cands: Array = [[i, j, (k + 1) % 4], [i, j, (k + 3) % 4]]
	var ni: int = i + CORN[k][0]
	if ni >= 0 and ni < World.N:
		cands.append([ni, j, MIRROR_X[k]])
	var nj: int = j + CORN[k][1]
	if nj >= 0 and nj < World.N:
		cands.append([i, nj, MIRROR_Z[k]])
	var out: Array = []
	for c in cands:
		if c != prev:
			out.append(c)
	return out[rng.randi() % out.size()]


func _rand_name(female: bool) -> String:
	if female:
		return NAMES_F[rng.randi() % NAMES_F.size()]
	return NAMES_M[rng.randi() % NAMES_M.size()]


func _spawn_npcs() -> void:
	for n in 34:
		var female := rng.randf() < 0.5
		var node := Actors.person(W.mat_solid, Actors.SKINS[rng.randi() % Actors.SKINS.size()], Actors.SHIRTS[rng.randi() % Actors.SHIRTS.size()], Actors.PANTS[rng.randi() % Actors.PANTS.size()], Actors.HAIRS[rng.randi() % Actors.HAIRS.size()], female)
		add_child(node)
		var cur: Array = [rng.randi() % World.N, rng.randi() % World.N, rng.randi() % 4]
		var nxt := _wp_next(cur, [])
		var off := Vector3(rng.randf_range(-0.55, 0.55), 0, rng.randf_range(-0.55, 0.55))
		var a := _wp(cur[0], cur[1], cur[2])
		var b := _wp(nxt[0], nxt[1], nxt[2])
		var d := {"node": node, "name": _rand_name(female), "pos": a.lerp(b, rng.randf()) + off, "prev": cur, "cur": nxt, "off": off, "speed": rng.randf_range(1.2, 1.9), "phase": rng.randf() * TAU, "wait": 0.0, "yaw": 0.0, "idle": false, "amt": 1.0, "down": 0.0}
		npcs.append(d)
	# gente parada en la plaza y el parque
	var spots: Array = []
	var pc := World.block_center(2, 2)
	for k in 5:
		var ang := TAU * k / 5.0 + 0.4
		spots.append([pc + Vector3(cos(ang) * 7.2, 0.16, sin(ang) * 7.2), pc])
	var kc := World.block_center(2, 3)
	spots.append([kc + Vector3(2, 0.16, 6.0), kc + Vector3(-8, 0, -7)])
	spots.append([kc + Vector3(-3, 0.16, 4.2), kc + Vector3(-8, 0, -7)])
	spots.append([kc + Vector3(8.0, 0.16, -8), kc + Vector3(-8, 0, -7)])
	for sp in spots:
		var female := rng.randf() < 0.5
		var node := Actors.random_person(W.mat_solid, rng)
		add_child(node)
		var p: Vector3 = sp[0]
		var look: Vector3 = sp[1]
		var yaw := atan2(look.x - p.x, look.z - p.z)
		node.position = p
		node.rotation.y = yaw
		npcs.append({"node": node, "name": _rand_name(female), "pos": p, "prev": [], "cur": [], "off": Vector3.ZERO, "speed": 0.0, "phase": rng.randf() * TAU, "wait": 0.0, "yaw": yaw, "idle": true, "amt": 0.0, "down": 0.0})


func _update_npcs(dt: float) -> void:
	for n in npcs:
		var node: Node3D = n.node
		var pos: Vector3 = n.pos
		var near := pos.distance_squared_to(ppos) < 90.0 * 90.0
		if n.down > 0.0:
			n.down -= dt
			node.rotation.x = lerpf(node.rotation.x, -1.45, minf(1.0, dt * 10.0))
			node.position = pos + Vector3(0, 0.22, 0)
			if n.down <= 0.0:
				node.rotation.x = 0.0
				node.position = pos
				if not n.idle:
					n.speed = 3.3
			continue
		if n.idle:
			if near:
				n.phase += dt * 1.5
				Actors.animate(node, n.phase, 0.06)
			if n.wait > 0.0:
				n.wait -= dt
				node.rotation.y = lerp_angle(node.rotation.y, atan2(ppos.x - pos.x, ppos.z - pos.z), minf(1.0, dt * 6.0))
			else:
				node.rotation.y = lerp_angle(node.rotation.y, n.yaw, minf(1.0, dt * 3.0))
			continue
		var moving := false
		if n.wait > 0.0:
			n.wait -= dt
		else:
			var cur: Array = n.cur
			var off: Vector3 = n.off
			var tgt: Vector3 = _wp(cur[0], cur[1], cur[2]) + off
			var dv := tgt - pos
			dv.y = 0.0
			var dist := dv.length()
			if dist < 0.25:
				var nxt := _wp_next(cur, n.prev)
				n.prev = cur
				n.cur = nxt
				if rng.randf() < 0.2:
					n.wait = rng.randf_range(0.6, 2.5)
			else:
				var dir := dv / dist
				if inside == "" and pos.distance_squared_to(ppos) < 0.8 and dir.dot(ppos - pos) > 0.0:
					n.wait = 0.4
				else:
					pos += dir * n.speed * dt
					n.yaw = atan2(dir.x, dir.z)
					moving = true
			pos.y = lerpf(pos.y, World.ground_y(pos.x, pos.z), minf(1.0, dt * 10.0))
			n.pos = pos
		n.amt = lerpf(n.amt, 1.0 if moving else 0.0, minf(1.0, dt * 8.0))
		node.position = pos
		if near:
			if moving:
				n.phase += dt * n.speed * 4.2
			node.rotation.y = lerp_angle(node.rotation.y, n.yaw, minf(1.0, dt * 8.0))
			Actors.animate(node, n.phase, n.amt)


func _right(d: Vector2i) -> Vector3:
	return Vector3(-d.y, 0, d.x)


func _dv(d: Vector2i) -> Vector3:
	return Vector3(d.x, 0, d.y)


func _node_pos(a: Vector2i) -> Vector3:
	return Vector3(World.road_pos(a.x), 0, World.road_pos(a.y))


func _lane_start(a: Vector2i, d: Vector2i) -> Vector3:
	return _node_pos(a) + _right(d) * 2.0 + _dv(d) * 7.5


func _lane_end(b: Vector2i, d: Vector2i) -> Vector3:
	return _node_pos(b) + _right(d) * 2.0 - _dv(d) * 7.5


func _valid(a: Vector2i) -> bool:
	return a.x >= 0 and a.x <= World.N and a.y >= 0 and a.y <= World.N


func _new_car(kind: int, col: Color, p: Vector3, yaw: float, mode: String) -> Dictionary:
	var node := Actors.car(W.mat_solid, W.mat_glow, col, kind)
	add_child(node)
	node.position = p
	node.rotation.y = yaw
	var top := rng.randf_range(15.0, 18.0)
	if kind == 2:
		top = 11.0
	var c := {"node": node, "pos": p, "b": Vector2i.ZERO, "d": Vector2i(0, 1), "pts": [], "speed": 0.0, "max": 6.5 if kind == 2 else rng.randf_range(7.5, 10.0), "yaw": yaw, "stuck": 0.0, "free": 0.0, "len": 5.5 if kind == 2 else 3.0, "mode": mode, "kind": kind, "hp": 100.0, "r": 2.3 if kind == 2 else 1.5, "top": top, "tgt": Vector3.ZERO, "has_tgt": false, "temp": false, "base_top": top, "engine": 0, "armor": 0, "maxhp": 100.0, "mine": false, "col": col}
	cars.append(c)
	return c


func _spawn_ai(min_dist: float) -> bool:
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for tries in 40:
		var a := Vector2i(rng.randi() % (World.N + 1), rng.randi() % (World.N + 1))
		var d: Vector2i = dirs[rng.randi() % 4]
		var b := a + d
		if not _valid(b):
			continue
		var p := _lane_start(a, d).lerp(_lane_end(b, d), rng.randf_range(0.2, 0.8))
		if p.distance_to(ppos) < min_dist:
			continue
		var free := true
		for o in cars:
			var op: Vector3 = o.pos
			if op.distance_to(p) < 16.0:
				free = false
				break
		if not free:
			continue
		ai_made += 1
		var kind := 0
		if ai_made % 9 == 5:
			kind = 2
		elif ai_made % 5 == 3:
			kind = 1
		var col: Color = Actors.CAR_COLS[rng.randi() % Actors.CAR_COLS.size()]
		if kind == 1:
			col = Color(0.98, 0.8, 0.1)
		elif kind == 2:
			col = Color(0.85, 0.25, 0.2)
		var c := _new_car(kind, col, p, atan2(float(d.x), float(d.y)), "ai")
		c.b = b
		c.d = d
		c.pts = [_lane_end(b, d)]
		return true
	return false


func _spawn_cars() -> void:
	for k in 18:
		_spawn_ai(0.0)
	var park: Array = []
	for bl in [[1, 1], [2, 1], [1, 2], [3, 2]]:
		var c := World.block_center(bl[0], bl[1])
		park.append([c + Vector3(17, 0.16, 13), 0.0])
		park.append([c + Vector3(-17, 0.16, 13), 0.0])
	for j in World.N:
		for i in World.N:
			if World.LAYOUT[j][i] == "A":
				park.append([World.block_center(i, j) + Vector3(0, 0.16, 10), PI / 2.0])
	park.append([World.block_center(1, 4) + Vector3(-5.5, 0.16, 17.5), 0.0])
	for pk in park:
		var pp: Vector3 = pk[0]
		var py: float = pk[1]
		_new_car(0, Actors.CAR_COLS[rng.randi() % Actors.CAR_COLS.size()], pp, py, "parked")


func _car_next(c: Dictionary) -> void:
	var b: Vector2i = c.b
	var d: Vector2i = c.d
	var opts: Array = []
	for d2 in [d, Vector2i(-d.y, d.x), Vector2i(d.y, -d.x)]:
		if _valid(b + d2):
			opts.append(d2)
			if d2 == d:
				opts.append(d2)
	var nd: Vector2i = opts[rng.randi() % opts.size()]
	var e := _lane_end(b, d)
	var s := _lane_start(b, nd)
	var pts: Array = []
	if nd == d:
		pts.append(s)
	else:
		var ctrl := e + _dv(d) * (s - e).dot(_dv(d))
		for k in range(1, 7):
			var t := k / 6.0
			pts.append(e.lerp(ctrl, t).lerp(ctrl.lerp(s, t), t))
	var nb := b + nd
	pts.append(_lane_end(nb, nd))
	c.b = nb
	c.d = nd
	c.pts = pts


func _update_cars(dt: float) -> void:
	for c in cars:
		if c.mode != "ai":
			continue
		var pos: Vector3 = c.pos
		var fwd := Vector3(sin(c.yaw), 0, cos(c.yaw))
		var blocked := false
		var reach: float = 5.0 + c.len + c.speed * 0.5
		if c.free <= 0.0:
			for o in cars:
				if is_same(o, c):
					continue
				var dv: Vector3 = o.pos - pos
				var along := dv.dot(fwd)
				if along > 0.5 and along < reach + o.len and absf(dv.x * fwd.z - dv.z * fwd.x) < 2.0:
					blocked = true
					break
		else:
			c.free -= dt
		if not blocked:
			var ped_reach: float = 3.5 + c.len + c.speed * 0.4
			if inside == "" and driving.is_empty():
				var dp := ppos - pos
				var al := dp.dot(fwd)
				if al > 0.0 and al < ped_reach and absf(dp.x * fwd.z - dp.z * fwd.x) < 1.9:
					blocked = true
			if not blocked:
				for n in npcs:
					var dn: Vector3 = n.pos - pos
					if absf(dn.x) > 12.0 or absf(dn.z) > 12.0:
						continue
					var an := dn.dot(fwd)
					if an > 0.0 and an < ped_reach and absf(dn.x * fwd.z - dn.z * fwd.x) < 1.7:
						blocked = true
						break
		if blocked:
			c.speed = maxf(0.0, c.speed - 22.0 * dt)
			c.stuck += dt
			if c.stuck > 6.0:
				c.free = 2.5
				c.stuck = 0.0
		else:
			c.speed = minf(c.max, c.speed + 5.0 * dt)
			c.stuck = 0.0
		var step: float = c.speed * dt
		var pts: Array = c.pts
		while step > 0.0:
			if pts.is_empty():
				_car_next(c)
				pts = c.pts
			var tgt: Vector3 = pts[0]
			var dv2 := tgt - pos
			var dist := dv2.length()
			if dist <= step:
				pos = tgt
				step -= dist
				pts.pop_front()
			else:
				var dir := dv2 / dist
				pos += dir * step
				c.yaw = lerp_angle(c.yaw, atan2(dir.x, dir.z), minf(1.0, dt * 9.0))
				step = 0.0
		c.pos = pos
		var node: Node3D = c.node
		node.position = pos
		node.rotation.y = c.yaw


func _spawn_statics() -> void:
	for s in W.statics:
		var node := Actors.random_person(W.mat_solid, rng)
		node.position = s.pos
		node.rotation.y = s.rot
		add_child(node)
		static_nodes.append(node)


# ---------------------------------------------------------------- día y noche

func _update_time(dt: float) -> void:
	time_h += dt / 30.0
	if time_h >= 24.0:
		time_h -= 24.0
		day = (day + 1) % 7
		_new_day()
	var f := clampf(sin((time_h - 6.0) / 12.0 * PI), 0.0, 1.0)
	var fs := smoothstep(0.0, 0.35, f)
	var dusk := clampf(1.0 - absf(f - 0.12) / 0.2, 0.0, 1.0) * clampf(f * 25.0, 0.0, 1.0)
	sun.rotation = Vector3(-deg_to_rad(lerpf(14.0, 62.0, f)), deg_to_rad(-50.0 + (time_h - 12.0) * 9.0), 0)
	var day_col := Color(1.0, 0.62, 0.36).lerp(Color(1.0, 0.97, 0.9), clampf(f * 2.5, 0.0, 1.0))
	sun.light_color = Color(0.55, 0.65, 1.0).lerp(day_col, fs)
	sun.light_energy = lerpf(0.32, 0.86, fs)
	env.ambient_light_color = Color(0.26, 0.32, 0.55).lerp(Color(0.6, 0.66, 0.78), fs)
	env.ambient_light_energy = lerpf(1.25, 0.5, fs)
	var top := Color(0.02, 0.03, 0.1).lerp(Color(0.22, 0.47, 0.9), fs)
	var hor := Color(0.07, 0.09, 0.2).lerp(Color(0.68, 0.82, 0.96), fs).lerp(Color(1.0, 0.58, 0.32), dusk * 0.7)
	env.fog_light_color = hor
	var night := 1.0 - fs
	var now := Time.get_ticks_msec()
	if dt == 0.0 or now - sky_ms > 500:
		sky_ms = now
		sky_mat.set_shader_parameter("top_col", top)
		sky_mat.set_shader_parameter("hor_col", hor)
		sky_mat.set_shader_parameter("night", night)
		sky_mat.set_shader_parameter("cloud_t", now * 0.0000035)
		W.mat_glow.set_shader_parameter("sky_col", hor.lerp(top, 0.4))
		W.mat_water.set_shader_parameter("sky_col", hor.lerp(top, 0.5))
	W.mat_glow.set_shader_parameter("night", night)
	W.mat_pool.set_shader_parameter("night", night)

func _clock_text() -> String:
	var h := int(time_h)
	var m := int((time_h - h) * 60.0)
	return "%s %02d:%02d" % [DAYS[day], h, m]


func _advance(hours: float) -> void:
	time_h += hours
	while time_h >= 24.0:
		time_h -= 24.0
		day = (day + 1) % 7
		_new_day()
	var gh := hours
	needs.hambre = maxf(0.0, needs.hambre - 2.0 * gh)
	needs.social = maxf(0.0, needs.social - 1.2 * gh)


# ---------------------------------------------------------------- jugador y cámara

func _collide(p: Vector3, r: float) -> Vector3:
	for rc: Rect2 in W.colliders:
		if p.x < rc.position.x - r or p.x > rc.end.x + r or p.z < rc.position.y - r or p.z > rc.end.y + r:
			continue
		var cx := clampf(p.x, rc.position.x, rc.end.x)
		var cz := clampf(p.z, rc.position.y, rc.end.y)
		var dx := p.x - cx
		var dz := p.z - cz
		var d2 := dx * dx + dz * dz
		if d2 >= r * r:
			continue
		if d2 > 0.000001:
			var d := sqrt(d2)
			p.x += dx / d * (r - d)
			p.z += dz / d * (r - d)
		else:
			var l := p.x - rc.position.x
			var rr := rc.end.x - p.x
			var t := p.z - rc.position.y
			var b := rc.end.y - p.z
			var m := minf(minf(l, rr), minf(t, b))
			if m == l:
				p.x = rc.position.x - r
			elif m == rr:
				p.x = rc.end.x + r
			elif m == t:
				p.z = rc.position.y - r
			else:
				p.z = rc.end.y + r
	return p


func _move_player(dt: float) -> void:
	var jv := joy_vec
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		jv.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		jv.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		jv.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		jv.y += 1.0
	if jv.length() > 1.0:
		jv = jv.normalized()
	if not driving.is_empty():
		_drive(dt, jv)
		return
	var moving := false
	if not busy and jv.length() > 0.12:
		var fwd := -Vector3(sin(cam_yaw), 0, cos(cam_yaw))
		var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
		var mv := right * jv.x - fwd * jv.y
		var speed := 5.6
		if needs.energia < 15.0 or needs.hambre < 15.0:
			speed = 3.0
		var np := ppos + mv * speed * dt
		np = _collide(np, 0.42)
		if inside == "":
			np.x = clampf(np.x, -158.0, 158.0)
			np.z = clampf(np.z, -158.0, 158.0)
		ppos = np
		pyaw = lerp_angle(pyaw, atan2(mv.x, mv.z), minf(1.0, dt * 12.0))
		pphase += dt * speed * 2.6 * jv.length()
		moving = true
	pwalk = lerpf(pwalk, 1.0 if moving else 0.0, minf(1.0, dt * 10.0))
	ppos.y = lerpf(ppos.y, World.ground_y(ppos.x, ppos.z), minf(1.0, dt * 12.0))
	player.position = ppos
	player.rotation.y = pyaw
	Actors.animate(player, pphase, pwalk)
	if punch_t > 0.0:
		punch_t -= dt
		var limbs: Array = player.get_meta("limbs")
		limbs[3].rotation.x = -1.6 * clampf(punch_t / 0.12, 0.0, 1.0)
	bob.rotation.y += dt * 1.6
	bob.position.y = 2.05 + sin(Time.get_ticks_msec() * 0.003) * 0.05


func _update_camera(dt: float) -> void:
	if test_cam:
		return
	var pitch := cam_pitch
	if inside != "":
		pitch = maxf(pitch, 0.62)
	var target := ppos + Vector3(0, 1.5, 0)
	var off := Vector3(sin(cam_yaw) * cos(pitch), sin(pitch), cos(cam_yaw) * cos(pitch)) * cam_dist
	if inside == "":
		var frac := 1.0
		for bl in W.buildings:
			var rc: Rect2 = bl[0]
			var bh: float = bl[1]
			for k in range(1, 11):
				var t := k / 10.0
				if t >= frac:
					break
				var q := target + off * t
				if q.y < bh and rc.has_point(Vector2(q.x, q.z)):
					frac = maxf(0.18, t - 0.1)
					break
		off *= frac
	var want := target + off
	if cam_snap:
		cam.position = want
		cam_snap = false
	else:
		cam.position = cam.position.lerp(want, minf(1.0, dt * 10.0))
	cam.look_at(target, Vector3.UP)


func _unhandled_input(ev: InputEvent) -> void:
	if not started:
		return
	if ev is InputEventScreenTouch:
		if ev.pressed:
			var vs := get_viewport().get_visible_rect().size
			if joy_id == -1 and ev.position.x < vs.x * 0.42 and ev.position.y > vs.y * 0.32:
				joy_id = ev.index
				joy_origin = ev.position
				joy_vec = Vector2.ZERO
				hud.joy.active = true
				hud.joy.origin = joy_origin
			elif cam_id == -1:
				cam_id = ev.index
		else:
			if ev.index == joy_id:
				joy_id = -1
				joy_vec = Vector2.ZERO
				hud.joy.active = false
				hud.joy.vec = Vector2.ZERO
			elif ev.index == cam_id:
				cam_id = -1
	elif ev is InputEventScreenDrag:
		if ev.index == joy_id:
			var v: Vector2 = (ev.position - joy_origin) / 80.0
			if v.length() > 1.0:
				v = v.normalized()
			joy_vec = v
			hud.joy.vec = v
		elif ev.index == cam_id:
			cam_yaw -= ev.relative.x * 0.006
			cam_pitch = clampf(cam_pitch + ev.relative.y * 0.004, 0.12, 1.35)
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = clampf(cam_dist - 1.0, 4.5, 26.0)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = clampf(cam_dist + 1.0, 4.5, 26.0)
	elif ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_E:
		_do_action()


# ---------------------------------------------------------------- acciones

func _update_action() -> void:
	var best: Dictionary = {}
	var bd := 1e9
	var label := ""
	if busy:
		cur_action = {}
		hud.set_action("")
		return
	if inside != "":
		for s in W.spots:
			if s.room != inside:
				continue
			if s.get("own", false) and not cur_owned:
				continue
			if s.id == "hablar" and cur_owned and W.statics[s.who].role == "host":
				continue
			var sp: Vector3 = s.pos
			var d := Vector2(sp.x - ppos.x, sp.z - ppos.z).length()
			if d < 1.8 and d < bd:
				bd = d
				best = {"type": "spot", "spot": s}
				label = s.label
				if s.id == "hablar" and W.statics[s.who].role == "host":
					label = "Hablar con " + host_name
	elif not driving.is_empty():
		if absf(driving.speed) < 5.0:
			best = {"type": "exit"}
			label = "Salir del coche"
			if Vector2(W.taller_pos.x - ppos.x, W.taller_pos.z - ppos.z).length() < 5.0:
				best = {"type": "taller"}
				label = "Abrir el taller"
	else:
		for c in cars:
			if c.mode != "ai" and c.mode != "parked":
				continue
			if absf(c.speed) > 4.5:
				continue
			var cp: Vector3 = c.pos
			var cd: float = Vector2(cp.x - ppos.x, cp.z - ppos.z).length() - c.r
			if cd < 1.7 and cd < bd:
				bd = cd
				best = {"type": "car", "car": c}
				label = "Robar coche" if c.mode == "ai" else "Subir al coche"
		for dr in W.doors:
			var dp: Vector3 = dr.pos
			var d := Vector2(dp.x - ppos.x, dp.z - ppos.z).length()
			if d < 2.4 and d < bd:
				bd = d
				best = {"type": "door", "door": dr}
				label = "Entrar: " + dr.name
		for n in npcs:
			if n.down > 0.0:
				continue
			var np: Vector3 = n.pos
			var d := Vector2(np.x - ppos.x, np.z - ppos.z).length()
			if d < 2.6 and d < bd:
				bd = d
				best = {"type": "npc", "npc": n}
				label = "Hablar con " + n.name
	cur_action = best
	hud.set_action(label)


func _pay(amount: int) -> bool:
	if money < amount:
		hud.toast("No tienes suficiente dinero (§%d)" % amount)
		return false
	money -= amount
	return true


func _add(need: String, v: float) -> void:
	needs[need] = clampf(needs[need] + v, 0.0, 100.0)


func _do_action() -> void:
	if busy or not started or cur_action.is_empty():
		return
	var a := cur_action
	if a.type == "car":
		_enter_car(a.car)
		return
	if a.type == "exit":
		_exit_car()
		return
	if a.type == "taller":
		_taller_menu()
		return
	if a.type == "door":
		var didx: int = W.doors.find(a.door)
		var mine := houses.has(str(didx))
		var alarm: bool = mine and houses[str(didx)].get("alarm", false)
		if wanted > 0 and pol_near < 30.0 and not alarm:
			hud.toast("¡La policía te está viendo! Aléjate antes de esconderte.")
			return
		if HOUSE_KINDS.has(a.door.kind) and not mine:
			menu_ctx = {"door": a.door, "idx": didx}
			_menu("%s — en venta" % a.door.name, [["Visitar a los vecinos", "visit"], ["Comprar por §%d" % _house_price(didx), "buy"]], _on_house_menu)
			return
		_enter(a.door)
	elif a.type == "npc":
		var n: Dictionary = a.npc
		n.wait = 4.0
		n.yaw = atan2(ppos.x - n.pos.x, ppos.z - n.pos.z)
		pyaw = atan2(n.pos.x - ppos.x, n.pos.z - ppos.z)
		_add("social", 12.0)
		hud.toast("%s: «%s»" % [n.name, PHRASES[rng.randi() % PHRASES.size()]])
	elif a.type == "spot":
		_do_spot(a.spot)
	_save()


func _do_spot(s: Dictionary) -> void:
	var id: String = s.id
	if id == "salir":
		_exit()
	elif id == "comida":
		if _pay(15):
			_add("hambre", 45.0)
			hud.toast("Has comprado comida rica.  Hambre +45")
	elif id == "cafe":
		if _pay(5):
			_add("energia", 22.0)
			hud.toast("Un café recién hecho.  Energía +22")
	elif id == "tarta":
		if _pay(8):
			_add("hambre", 22.0)
			_add("diversion", 8.0)
			hud.toast("¡Qué tarta más buena!  Hambre +22")
	elif id == "trabajo":
		if needs.energia < 20.0:
			hud.toast("Estás demasiado cansado para trabajar.")
			return
		var pay := 60 if inside == "super" else 50
		await _timed(2.0)
		money += pay
		_add("energia", -18.0)
		_add("diversion", -8.0)
		hud.toast("Turno terminado.  Has ganado §%d" % pay)
	elif id == "entrenar" or id == "pesas":
		if needs.energia < 15.0:
			hud.toast("Estás agotado. Descansa antes de entrenar.")
			return
		await _timed(0.75)
		_add("diversion", 22.0)
		_add("energia", -14.0)
		_add("hambre", -6.0)
		hud.toast("¡Buen entrenamiento!  Diversión +22")
	elif id == "nevera":
		_add("hambre", 30.0)
		hud.toast("Te has hecho un bocadillo.  Hambre +30")
	elif id == "dormir":
		await _timed(8.0)
		needs.energia = 100.0
		hud.toast("Has dormido de maravilla.  Energía al máximo")
	elif id == "tele":
		await _timed(1.0)
		var gain := 40.0 if owned.has("tele") else 22.0
		_add("diversion", gain)
		hud.toast("Has visto tu serie favorita.  Diversión +%d" % int(gain))
	elif id == "snack":
		if _pay(6):
			_add("hambre", 18.0)
			hud.toast("Un bocadillo de gasolinera.  Hambre +18")
	elif id == "mejoras":
		_home_menu()
		return
	elif id == "hablar" and W.statics[s.who].role != "host" and W.statics[s.who].role != "guard":
		menu_ctx = {"who": s.who, "room": s.room}
		_menu(W.statics[s.who].name, [["Charlar un rato", "talk"], ["¡Esto es un atraco!", "rob"]], _on_staff_menu)
		return
	elif id == "hablar":
		var st: Dictionary = W.statics[s.who]
		var who: String = host_name if st.role == "host" else st.name
		_add("social", 14.0)
		hud.toast("%s: «%s»" % [who, PHRASES[rng.randi() % PHRASES.size()]])
	elif id.begins_with("buy:"):
		var item := id.substr(4)
		if owned.has(item):
			hud.toast("Ya tienes %s en casa." % ITEM_NAMES[item])
		elif _pay(PRICES[item]):
			owned[item] = true
			_apply_owned()
			hud.toast("¡Comprado! Verás %s en Casa Mirasol." % ITEM_NAMES[item])
	_save()


func _timed(hours: float) -> void:
	busy = true
	await hud.fade(1.0, 0.3)
	_advance(hours)
	_update_time(0.0)
	await get_tree().create_timer(0.35).timeout
	await hud.fade(0.0, 0.3)
	busy = false


func _apply_owned() -> void:
	for id in PRICES:
		for nd in W.home_items[id]:
			nd.visible = owned.has(id)
	for nd in W.home_items["silla_basica"]:
		nd.visible = not owned.has("sofa")
	for nd in W.home_items["tele_basica"]:
		nd.visible = not owned.has("tele")


func _enter(door: Dictionary) -> void:
	busy = true
	await hud.fade(1.0, 0.25)
	_goto_room(door)
	await hud.fade(0.0, 0.25)
	busy = false


func _goto_room(door: Dictionary) -> void:
	var dp: Vector3 = door.pos
	var dd: Vector3 = door.dir
	inside = door.kind
	place_name = door.name
	cur_door = W.doors.find(door)
	if inside == "hogar":
		cur_door = home_idx
	cur_owned = houses.has(str(cur_door))
	for i in W.statics.size():
		if W.statics[i].room == inside and W.statics[i].role == "host":
			static_nodes[i].visible = not cur_owned
	if cur_owned:
		place_name = "Casa Mirasol" if inside == "hogar" else "Tu casa"
		if wanted > 0 and houses[str(cur_door)].get("alarm", false):
			wanted = 0
			evade_t = 0.0
			no_hide_t = 0.0
			_clear_police()
			hud.toast("Estás a salvo en casa: la policía te ha perdido la pista.")
	return_pos = dp + dd * 0.4
	return_yaw = atan2(dd.x, dd.z)
	var dname: String = door.name
	if dname.begins_with("Casa de los "):
		host_name = "los " + dname.substr(12)
	elif inside == "piso":
		host_name = "tu vecina del " + str(1 + absi(int(dp.x)) % 6) + "º"
	ppos = W.rooms[inside].spawn
	pyaw = PI
	cam_yaw = 0.0
	cam_pitch = 0.85
	cam_dist = 11.0
	cam_snap = true


func _exit() -> void:
	busy = true
	await hud.fade(1.0, 0.25)
	inside = ""
	ppos = return_pos
	pyaw = return_yaw
	cam_yaw = return_yaw
	cam_pitch = 0.45
	cam_dist = 10.0
	cam_snap = true
	await hud.fade(0.0, 0.25)
	busy = false


func _place() -> String:
	if inside != "":
		return place_name
	var t := World.block_at(ppos.x, ppos.z)
	match t:
		"P":
			return "Plaza Mayor"
		"K":
			return "Parque del Lucero"
		"H":
			return "Tu barrio"
		"R":
			return "Barrio residencial"
		"A":
			return "Bloques de pisos"
		"":
			return "Afueras"
	return "Zona comercial"


func _update_needs(dt: float) -> void:
	var gh := dt / 30.0
	_add("hambre", -4.0 * gh)
	_add("energia", -3.4 * gh)
	_add("diversion", -3.0 * gh)
	_add("social", -2.4 * gh)
	warn_t -= dt
	if warn_t <= 0.0:
		warn_t = 45.0
		if needs.hambre < 20.0:
			hud.toast("Tienes hambre: come algo en casa, en el súper o en el café.")
		elif needs.energia < 20.0:
			hud.toast("Estás cansado: ve a dormir a Casa Mirasol.")
		elif needs.social < 20.0:
			hud.toast("Te sientes solo: habla con algún vecino.")
		elif needs.diversion < 20.0:
			hud.toast("Te aburres: ve al gimnasio o mira la tele.")


func _on_play() -> void:
	started = true
	cam_snap = true
	hud.start_game()
	hud.toast("Bienvenido a Ciudad Mirasol. Roba un coche, busca los puntos de MISIÓN y que no te pille la policía.")


func _process(dt: float) -> void:
	dt = minf(dt, 0.1)
	if not started:
		title_a += dt * 0.12
		var pc := World.block_center(2, 2)
		if not test_cam:
			cam.position = pc + Vector3(sin(title_a) * 75.0, 34.0, cos(title_a) * 75.0)
			cam.look_at(pc + Vector3(0, 4, 0), Vector3.UP)
		_update_time(0.0)
		_update_npcs(dt)
		_update_cars(dt)
		player.position = ppos
		return
	_update_time(dt)
	_move_player(dt)
	if inside == "":
		_update_npcs(dt)
		_update_cars(dt)
	crash_cd = maxf(0.0, crash_cd - dt)
	no_hide_t = maxf(0.0, no_hide_t - dt)
	for rk in rob_cd.keys():
		rob_cd[rk] = maxf(0.0, rob_cd[rk] - dt)
	for who in hands.keys():
		hands[who] -= dt
		var hl: Array = static_nodes[who].get_meta("limbs")
		var up := -2.9 if hands[who] > 0.0 else 0.0
		hl[2].rotation.x = up
		hl[3].rotation.x = up
		if hands[who] <= 0.0:
			hands.erase(who)
	_update_police(dt)
	_update_mission(dt)
	_tick_traffic(dt)
	_update_camera(dt)
	_update_action()
	_update_needs(dt)
	hud.set_needs(needs)
	hud.set_wanted(wanted)
	var in_car := not driving.is_empty()
	hud.set_drive(in_car, int(absf(driving.speed) * 5.0) if in_car else 0)
	hud.punch_b.visible = not in_car and inside == ""
	var dots: Array = []
	if mission.is_empty():
		for mp in m_markers:
			dots.append([mp, Color(0.4, 0.95, 1.0)])
	elif mission.type != "huida":
		dots.append([mission.pts[mission.stage], Color(1.0, 0.85, 0.1)])
	for hk in houses:
		var hd: Vector3 = W.doors[int(hk)].pos
		dots.append([hd, Color(0.3, 1.0, 0.45)])
	dots.append([W.taller_pos, Color(1.0, 0.6, 0.1)])
	for pc2 in police:
		dots.append([pc2.pos, Color(0.25, 0.45, 1.0) if (Time.get_ticks_msec() / 300) % 2 == 0 else Color(1.0, 0.2, 0.2)])
	hud.mini.dots = dots
	hud.money_l.text = "§ %d" % money
	hud.clock_l.text = _clock_text()
	hud.place_l.text = _place()
	hud.mini.ppos = return_pos if inside != "" else ppos
	hud.mini.yaw = pyaw
	save_t += dt
	if save_t > 30.0:
		save_t = 0.0
		_save()


# ---------------------------------------------------------------- modo GTA

func _setup_gta() -> void:
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(1.0, 0.85, 0.1, 0.38)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cm := CylinderMesh.new()
	cm.top_radius = 2.6
	cm.bottom_radius = 2.6
	cm.height = 16.0
	cm.radial_segments = 20
	cm.cap_top = false
	cm.cap_bottom = false
	cm.material = bm
	beacon = MeshInstance3D.new()
	beacon.mesh = cm
	beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beacon.visible = false
	add_child(beacon)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = Color(0.3, 0.9, 1.0, 0.45)
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mk := CylinderMesh.new()
	mk.top_radius = 1.5
	mk.bottom_radius = 1.5
	mk.height = 2.4
	mk.radial_segments = 18
	mk.cap_top = false
	mk.cap_bottom = false
	mk.material = mm
	var pts: Array = [World.block_center(2, 2) + Vector3(-6, 0, 16), World.block_center(1, 1) + Vector3(-6, 0, 13), W.spawn + Vector3(5, 0, 0)]
	for p in pts:
		var q: Vector3 = p
		var mi := MeshInstance3D.new()
		mi.mesh = mk
		mi.position = q + Vector3(0, 1.3, 0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		W._label("MISIÓN", q + Vector3(0, 3.3, 0), 0.01, Color(0.5, 0.95, 1.0), true)
		m_markers.append(q)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(0.2, 0.2, 0.22, 0.55)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var sph := SphereMesh.new()
	sph.radius = 0.3
	sph.height = 0.6
	sph.radial_segments = 8
	sph.rings = 4
	sph.material = sm
	smoke = CPUParticles3D.new()
	smoke.mesh = sph
	smoke.amount = 20
	smoke.lifetime = 1.3
	smoke.local_coords = false
	smoke.direction = Vector3.UP
	smoke.spread = 25.0
	smoke.gravity = Vector3(0, 1.2, 0)
	smoke.initial_velocity_min = 1.0
	smoke.initial_velocity_max = 2.2
	smoke.scale_amount_min = 0.6
	smoke.scale_amount_max = 1.8
	smoke.emitting = false
	add_child(smoke)


func _crime(cap: int) -> void:
	if wanted < cap:
		wanted += 1
		if wanted == 1:
			hud.toast("¡Te busca la policía! Huye lejos o escóndete en un edificio.")
	evade_t = 0.0


func _knock(n: Dictionary, t: float) -> void:
	n.down = t
	n.wait = 0.0


func _punch() -> void:
	if busy or not started or inside != "" or not driving.is_empty() or punch_t > 0.0:
		return
	punch_t = 0.35
	var f := Vector3(sin(pyaw), 0, cos(pyaw))
	for n in npcs:
		if n.down > 0.0:
			continue
		var dn: Vector3 = n.pos - ppos
		dn.y = 0.0
		var d := dn.length()
		if d < 1.9 and (d < 0.6 or dn.dot(f) / d > 0.2):
			_knock(n, 5.0)
			var loot := rng.randi_range(5, 30)
			money += loot
			hud.toast("¡Zas! %s suelta §%d" % [n.name, loot])
			_crime(2)
			break


func _eject_driver(c: Dictionary) -> void:
	if npcs.size() >= 60:
		return
	var cpos: Vector3 = c.pos
	var yaw: float = c.yaw
	var female := rng.randf() < 0.5
	var node := Actors.random_person(W.mat_solid, rng)
	add_child(node)
	var p := cpos - Vector3(cos(yaw), 0, -sin(yaw)) * 2.3
	var i := clampi(int(floor((p.x - World.X0 + 7.0) / World.P)), 0, World.N - 1)
	var j := clampi(int(floor((p.z - World.X0 + 7.0) / World.P)), 0, World.N - 1)
	var bk := 0
	var bd := 1e18
	for k in 4:
		var dd := _wp(i, j, k).distance_squared_to(p)
		if dd < bd:
			bd = dd
			bk = k
	node.position = p
	npcs.append({"node": node, "name": _rand_name(female), "pos": p, "prev": [], "cur": [i, j, bk], "off": Vector3.ZERO, "speed": 3.3, "phase": 0.0, "wait": 0.0, "yaw": yaw, "idle": false, "amt": 1.0, "down": 0.0})


func _enter_car(c: Dictionary) -> void:
	if c.mode == "ai":
		_eject_driver(c)
		_crime(2)
		c.temp = true
		hud.toast("¡Coche robado!")
	c.mode = "player"
	c.pts = []
	driving = c
	player.visible = false
	cam_dist = 9.0
	cam_pitch = 0.3
	if float(c.hp) <= 0.0:
		hud.toast("Este coche está destrozado. Busca otro.")


func _exit_car() -> void:
	if driving.is_empty():
		return
	var c := driving
	var cpos: Vector3 = c.pos
	var yaw: float = c.yaw
	c.mode = "parked"
	c.speed = 0.0
	var node: Node3D = c.node
	node.rotation.z = 0.0
	driving = {}
	ppos = _collide(cpos + Vector3(cos(yaw), 0, -sin(yaw)) * (float(c.r) + 0.8), 0.42)
	pyaw = yaw
	player.visible = true
	smoke.emitting = false
	cam_dist = 10.0
	cam_pitch = 0.45


func _crash(c: Dictionary, impact: float) -> void:
	crash_cd = 0.4
	var was: float = c.hp
	c.hp = maxf(0.0, was - impact * 1.5)
	if was > 0.0 and float(c.hp) <= 0.0 and is_same(c, driving):
		hud.toast("El coche está destrozado. ¡Sal y busca otro!")


func _drive(dt: float, jv: Vector2) -> void:
	var c := driving
	var top: float = c.top
	var sp: float = c.speed
	var r: float = c.r
	var yaw: float = c.yaw
	var thr := -jv.y
	if busy or float(c.hp) <= 0.0:
		thr = 0.0
		sp = move_toward(sp, 0.0, 12.0 * dt)
	if thr > 0.1:
		if sp < 0.0:
			sp += 20.0 * thr * dt
		else:
			sp += 9.5 * (1.0 + 0.15 * float(c.engine)) * thr * dt * (1.0 - 0.55 * sp / top)
	elif thr < -0.1:
		if sp > 0.5:
			sp += 22.0 * thr * dt
		else:
			sp += 6.0 * thr * dt
	else:
		sp = move_toward(sp, 0.0, 3.5 * dt)
	sp = clampf(sp, -6.0, top)
	var grip := clampf(absf(sp) / 4.0, 0.0, 1.0)
	var steer := jv.x * 2.2 * grip * (1.0 - 0.45 * clampf(absf(sp) / top, 0.0, 1.0)) * signf(sp)
	yaw -= steer * dt
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var cpos: Vector3 = c.pos
	var np := cpos + fwd * sp * dt
	var cp := _collide(np, r)
	cp.x = clampf(cp.x, -158.0, 158.0)
	cp.z = clampf(cp.z, -158.0, 158.0)
	var push := cp - np
	push.y = 0.0
	if push.length() > 0.0008:
		var head := clampf(push.normalized().dot(-fwd * signf(sp)), 0.0, 1.0)
		if head > 0.45 and absf(sp) > 6.0 and crash_cd <= 0.0:
			_crash(c, absf(sp))
		sp *= 1.0 - head * minf(1.0, dt * 14.0)
	for o in cars:
		if is_same(o, c):
			continue
		var dv: Vector3 = cp - o.pos
		dv.y = 0.0
		var rr: float = r + o.r - 0.3
		var d := dv.length()
		if d < rr and d > 0.01:
			var out := dv / d * (rr - d)
			if o.mode == "parked":
				cp += out * 0.5
				o.pos = _collide(o.pos - out * 0.5, o.r)
				var on: Node3D = o.node
				on.position = o.pos
			else:
				cp += out
			var rel := absf(sp)
			if rel > 5.0 and crash_cd <= 0.0:
				_crash(c, rel * 0.8)
				if o.mode == "police":
					_crime(4)
				elif o.mode == "ai":
					o.speed = 0.0
			sp *= 1.0 - minf(1.0, dt * 8.0)
	if absf(sp) > 3.5:
		for n in npcs:
			if n.down > 0.0:
				continue
			var dn: Vector3 = n.pos - cp
			if absf(dn.x) > 3.2 or absf(dn.z) > 3.2:
				continue
			dn.y = 0.0
			if dn.length() < r + 0.3:
				_knock(n, 6.0)
				_crime(3)
				sp *= 0.85
	cp.y = lerpf(cpos.y, World.ground_y(cp.x, cp.z), minf(1.0, dt * 12.0))
	c.pos = cp
	c.speed = sp
	c.yaw = yaw
	var node: Node3D = c.node
	node.position = cp
	node.rotation.y = yaw
	node.rotation.z = lerpf(node.rotation.z, steer * absf(sp) * 0.004, minf(1.0, dt * 8.0))
	ppos = cp
	pyaw = yaw
	player.position = cp
	if cam_id == -1:
		cam_yaw = lerp_angle(cam_yaw, yaw + PI, minf(1.0, dt * 3.2))
	smoke.emitting = float(c.hp) < 35.0
	smoke.position = cp + fwd * 1.7 + Vector3(0, 0.9, 0)


func _clear_police() -> void:
	for c in police:
		var node: Node3D = c.node
		node.queue_free()
		for k in cars.size():
			if is_same(cars[k], c):
				cars.remove_at(k)
				break
	police.clear()
	pol_near = 1e9


func _spawn_police() -> void:
	var best := Vector2i(0, 0)
	var found := false
	for tries in 40:
		var a := Vector2i(rng.randi() % (World.N + 1), rng.randi() % (World.N + 1))
		var d := _node_pos(a).distance_to(ppos)
		if d > 55.0 and d < 125.0:
			best = a
			found = true
			break
	if not found:
		var far := -1.0
		for i in World.N + 1:
			for j in World.N + 1:
				var d2 := _node_pos(Vector2i(i, j)).distance_to(ppos)
				if d2 > far:
					far = d2
					best = Vector2i(i, j)
	var p := _node_pos(best)
	var c := _new_car(3, Color(0.95, 0.95, 0.97), p, atan2(ppos.x - p.x, ppos.z - p.z), "police")
	police.append(c)


func _police_step(c: Dictionary, dt: float) -> float:
	var pos: Vector3 = c.pos
	var to := ppos - pos
	to.y = 0.0
	var dist := to.length()
	var yaw: float = c.yaw
	if float(c.free) > 0.0:
		c.free -= dt
		yaw += 1.3 * dt
		var fb := Vector3(sin(yaw), 0, cos(yaw))
		pos = _collide(pos - fb * 4.0 * dt, 1.5)
		c.speed = 0.0
	else:
		var goal := ppos
		if dist >= 26.0:
			var tg: Vector3 = c.tgt
			if not c.has_tgt or Vector2(tg.x - pos.x, tg.z - pos.z).length() < 5.0:
				var ni := clampi(roundi((pos.x - World.road_pos(0)) / World.P), 0, World.N)
				var nj := clampi(roundi((pos.z - World.road_pos(0)) / World.P), 0, World.N)
				var here := Vector2i(ni, nj)
				var hp := _node_pos(here)
				if Vector2(hp.x - pos.x, hp.z - pos.z).length() > 6.0:
					tg = hp
				else:
					var bestd := 1e18
					var steps: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
					for d2 in steps:
						var nb := here + d2
						if not _valid(nb):
							continue
						var npos := _node_pos(nb)
						var dd := npos.distance_squared_to(ppos)
						if dd < bestd:
							bestd = dd
							tg = npos
				c.tgt = tg
				c.has_tgt = true
			goal = tg
		else:
			c.has_tgt = false
		var des := atan2(goal.x - pos.x, goal.z - pos.z)
		var dy := wrapf(des - yaw, -PI, PI)
		yaw += clampf(dy, -2.8 * dt, 2.8 * dt)
		var top := 11.5 + wanted * 1.0
		var tsp := top * (1.0 - 0.65 * clampf(absf(dy) / 1.2, 0.0, 1.0))
		if dist < 6.5:
			tsp = 1.5 if dist > 3.6 else 0.0
		var sp: float = move_toward(c.speed, tsp, 9.0 * dt)
		var fwd := Vector3(sin(yaw), 0, cos(yaw))
		var np2 := _collide(pos + fwd * sp * dt, 1.5)
		for o in cars:
			if is_same(o, c):
				continue
			var dv: Vector3 = np2 - o.pos
			dv.y = 0.0
			var rr: float = 1.2 + o.r
			var dl := dv.length()
			if dl < rr and dl > 0.01:
				np2 += dv / dl * (rr - dl)
				if is_same(o, driving) and sp > 6.0 and crash_cd <= 0.0:
					_crash(o, sp * 0.5)
					o.speed *= 0.7
				sp = minf(sp, 3.0)
		var moved := Vector2(np2.x - pos.x, np2.z - pos.z).length()
		if tsp > 3.0 and moved < 1.0 * dt:
			c.stuck += dt
		else:
			c.stuck = 0.0
		if float(c.stuck) > 1.2:
			c.stuck = 0.0
			c.free = 1.0
		pos = np2
		c.speed = sp
	pos.y = lerpf(pos.y, World.ground_y(pos.x, pos.z), minf(1.0, dt * 10.0))
	c.pos = pos
	c.yaw = yaw
	var node: Node3D = c.node
	node.position = pos
	node.rotation.y = yaw
	return dist


func _update_police(dt: float) -> void:
	if wanted <= 0:
		if not police.is_empty():
			_clear_police()
		bust_t = 0.0
		return
	if inside != "":
		pol_near = 1e9
		if no_hide_t <= 0.0:
			evade_t += dt
	else:
		var counts: Array[int] = [0, 1, 2, 2, 3, 4]
		pol_t -= dt
		if police.size() < counts[wanted] and pol_t <= 0.0:
			pol_t = 2.5
			_spawn_police()
		var near := 1e9
		var blink := (Time.get_ticks_msec() / 220) % 2 == 0
		for c in police:
			near = minf(near, _police_step(c, dt))
			var bar: Array = c.node.get_meta("bar")
			bar[0].visible = blink
			bar[1].visible = not blink
		pol_near = near
		if near > 55.0:
			evade_t += dt
		else:
			evade_t = 0.0
		var slow := driving.is_empty() or absf(driving.speed) < 3.0
		if near < 5.2 and slow and not busy:
			bust_t += dt
		else:
			bust_t = maxf(0.0, bust_t - dt * 0.5)
		if bust_t > (1.0 if driving.is_empty() else 2.2):
			_busted()
			return
	if evade_t > 10.0:
		wanted = 0
		evade_t = 0.0
		_clear_police()
		hud.toast("Has despistado a la policía.")


func _busted() -> void:
	if busy:
		return
	busy = true
	bust_t = 0.0
	var fine := mini(money, 80 + wanted * 40)
	await hud.fade(1.0, 0.4)
	money -= fine
	wanted = 0
	evade_t = 0.0
	_clear_police()
	if not driving.is_empty():
		_exit_car()
	if not mission.is_empty():
		mission = {}
		beacon.visible = false
		mission_cd = 8.0
	inside = ""
	ppos = W.spawn
	pyaw = 0.0
	cam_yaw = 0.0
	cam_snap = true
	await hud.fade(0.0, 0.4)
	busy = false
	hud.toast("DETENIDO. La policía te ha puesto una multa de §%d." % fine)


func _tick_traffic(dt: float) -> void:
	traffic_t -= dt
	if traffic_t > 0.0 or inside != "":
		return
	traffic_t = 3.0
	var ai := 0
	var k := cars.size() - 1
	while k >= 0:
		var c: Dictionary = cars[k]
		if c.mode == "ai":
			ai += 1
		elif c.mode == "parked" and c.temp and not c.mine:
			var cp: Vector3 = c.pos
			if cp.distance_to(ppos) > 140.0:
				var node: Node3D = c.node
				node.queue_free()
				cars.remove_at(k)
		k -= 1
	if ai < 16:
		_spawn_ai(90.0)


func _road_point(from: Vector3, min_d: float) -> Vector3:
	var p := Vector3.ZERO
	for tries in 40:
		var k := rng.randi() % (World.N + 1)
		var s := rng.randi() % World.N
		var along := World.X0 + s * World.P + 22.0
		if rng.randf() < 0.5:
			p = Vector3(World.road_pos(k), 0, along)
		else:
			p = Vector3(along, 0, World.road_pos(k))
		if p.distance_to(from) > min_d:
			break
	return p


func _mission_start() -> void:
	var kind := mission_n % 3
	mission_n += 1
	if kind == 0:
		var t := _road_point(ppos, 90.0)
		var d := t.distance_to(ppos)
		mission = {"type": "reparto", "title": "Reparto exprés", "stage": 0, "pts": [t], "t": d / 6.0 + 30.0, "reward": 80 + int(d * 0.6), "hints": ["Lleva el paquete al punto amarillo antes de que acabe el tiempo."]}
	elif kind == 1:
		var p1 := _road_point(ppos, 60.0)
		var p2 := _road_point(p1, 100.0)
		var d := p1.distance_to(ppos) + p2.distance_to(p1)
		mission = {"type": "taxi", "title": "Carrera de taxi", "stage": 0, "pts": [p1, p2], "t": d / 6.0 + 45.0, "reward": 120 + int(d * 0.5), "hints": ["Recoge al cliente en el punto amarillo.", "Cliente a bordo: llévalo a su destino."]}
	else:
		wanted = maxi(wanted, 3)
		evade_t = 0.0
		mission = {"type": "huida", "title": "La gran huida", "stage": 0, "pts": [], "t": 150.0, "reward": 250, "hints": ["Tienes 3 estrellas: despista a la policía o escóndete en un edificio."]}
	hud.toast("MISIÓN: %s. %s" % [mission.title, mission.hints[0]])


func _mission_end(ok: bool) -> void:
	if ok:
		var rw: int = mission.reward
		money += rw
		_add("diversion", 25.0)
		hud.toast("¡MISIÓN SUPERADA!  +§%d" % rw)
	else:
		hud.toast("Misión fallida. Vuelve a un punto de MISIÓN para intentarlo otra vez.")
	mission = {}
	mission_cd = 6.0
	beacon.visible = false
	hud.mission_l.text = ""


func _update_mission(dt: float) -> void:
	if mission.is_empty():
		hud.mission_l.text = ""
		mission_cd -= dt
		if mission_cd > 0.0 or inside != "" or busy:
			return
		for mp in m_markers:
			var q: Vector3 = mp
			if Vector2(q.x - ppos.x, q.z - ppos.z).length() < (3.6 if not driving.is_empty() else 2.4):
				_mission_start()
				break
		return
	mission.t -= dt
	var secs := int(maxf(0.0, mission.t))
	if float(mission.t) <= 0.0:
		_mission_end(false)
		return
	if mission.type == "huida":
		hud.mission_l.text = "%s · %d:%02d" % [mission.title, secs / 60, secs % 60]
		if wanted == 0:
			_mission_end(true)
		return
	var tgt: Vector3 = mission.pts[mission.stage]
	beacon.visible = true
	beacon.position = tgt + Vector3(0, 8.0, 0)
	var dist := Vector2(tgt.x - ppos.x, tgt.z - ppos.z).length()
	hud.mission_l.text = "%s · %d m · %d:%02d" % [mission.title, int(dist), secs / 60, secs % 60]
	if inside == "" and dist < 5.5:
		mission.stage += 1
		if int(mission.stage) >= mission.pts.size():
			_mission_end(true)
		else:
			hud.toast(mission.hints[mission.stage])


# ---------------------------------------------------------------- menús, casas, taller y atracos

func _menu(title: String, opts: Array, cb: Callable) -> void:
	busy = true
	menu_cb = cb
	hud.show_menu(title, opts)


func _on_menu(id: String) -> void:
	busy = false
	hud.hide_menu()
	if id != "" and menu_cb.is_valid():
		menu_cb.call(id)


func _house_price(idx: int) -> int:
	if W.doors[idx].kind == "piso":
		return 1300 + (idx % 4) * 100
	return 2400 + (idx * 137 % 9) * 150


func _on_house_menu(id: String) -> void:
	var door: Dictionary = menu_ctx.door
	var idx: int = menu_ctx.idx
	if id == "visit":
		_enter(door)
	elif id == "buy":
		var price := _house_price(idx)
		if _pay(price):
			houses[str(idx)] = {}
			_apply_houses()
			hud.toast("¡Has comprado esta casa por §%d! Entra para mejorarla." % price)
			_save()


func _apply_houses() -> void:
	for hk in houses:
		var door: Dictionary = W.doors[int(hk)]
		var dp: Vector3 = door.pos
		var dd: Vector3 = door.dir
		if not house_marks.has(hk):
			house_marks[hk] = W._label("TU CASA", dp + Vector3(0, 4.3, 0), 0.008, Color(0.45, 1.0, 0.55), true)
		if houses[hk].get("pool", false) and not pool_nodes.has(hk) and door.kind != "piso":
			var b = MB.new()
			var wb = MB.new()
			var pp := dp + Vector3(4.6, 0.16, dd.z * 3.4)
			b.m = 0.6
			b.box(pp, Vector3(5.0, 0.2, 3.4), Color(0.85, 0.84, 0.8))
			wb.flat(pp + Vector3(0, 0.22, 0), 4.2, 2.6, Color.WHITE)
			b.m = 1.0
			b.box(pp + Vector3(2.9, 0, 0), Vector3(0.5, 0.35, 1.6), Color(0.95, 0.4, 0.3))
			var holder := Node3D.new()
			add_child(holder)
			b.instance(holder, W.mat_solid)
			wb.instance(holder, W.mat_water, false)
			W.add_col(pp.x, pp.z, 5.0, 3.4)
			pool_nodes[hk] = holder


func _home_menu() -> void:
	var h: Dictionary = houses[str(cur_door)]
	var opts: Array = []
	for u in HOME_UPG:
		if h.get(u[0], false):
			opts.append(["%s — ya la tienes" % u[1], u[0]])
		else:
			opts.append(["%s — §%d" % [u[1], u[2]], u[0]])
	_menu("Mejoras de la casa", opts, _on_home_upg)


func _on_home_upg(id: String) -> void:
	var h: Dictionary = houses[str(cur_door)]
	for u in HOME_UPG:
		if u[0] != id:
			continue
		if h.get(id, false):
			hud.toast("Esa mejora ya está hecha.")
		elif id == "pool" and W.doors[cur_door].kind == "piso":
			hud.toast("Un piso no tiene jardín para la piscina.")
		elif _pay(u[2]):
			h[id] = true
			_apply_houses()
			hud.toast(u[3])
			_save()


func _new_day() -> void:
	var inc := 0
	for hk in houses:
		if houses[hk].get("rent", false):
			inc += 60
		if houses[hk].get("pool", false):
			inc += 40
	if inc > 0:
		money += inc
		if hud != null:
			hud.toast("Ingresos de tus casas: +§%d" % inc)


func _on_staff_menu(id: String) -> void:
	var who: int = menu_ctx.who
	var room: String = menu_ctx.room
	var st: Dictionary = W.statics[who]
	if id == "talk":
		_add("social", 14.0)
		hud.toast("%s: «%s»" % [st.name, PHRASES[rng.randi() % PHRASES.size()]])
		return
	if float(rob_cd.get(room, 0.0)) > 0.0:
		hud.toast("%s: «¡Ya me han robado hoy, la caja está vacía!»" % st.name)
		return
	var rg: Array = LOOT[room]
	var loot := rng.randi_range(rg[0], rg[1])
	money += loot
	rob_cd[room] = 300.0
	var stars := 2
	if room == "banco":
		stars = 4
	elif room == "gasolinera":
		stars = 3
	wanted = maxi(wanted, stars)
	evade_t = 0.0
	no_hide_t = 45.0
	hands[who] = 8.0
	hud.toast("¡ATRACO! Te llevas §%d. ¡Sal corriendo, que viene la policía!" % loot)
	_save()


func _repaint(c: Dictionary, col: Color) -> void:
	var old: Node3D = c.node
	var node := Actors.car(W.mat_solid, W.mat_glow, col, c.kind)
	add_child(node)
	node.position = old.position
	node.rotation = old.rotation
	old.queue_free()
	c.node = node
	c.col = col


func _claim(c: Dictionary) -> void:
	for o in cars:
		o.mine = false
	c.mine = true
	c.temp = false
	my_car = c


func _tune(c: Dictionary) -> void:
	c.top = float(c.base_top) * (1.0 + 0.12 * float(c.engine))
	c.maxhp = 100.0 + 60.0 * float(c.armor)


func _taller_menu() -> void:
	var c := driving
	var eng := "Motor al máximo" if int(c.engine) >= 3 else "Motor nivel %d — §300" % (int(c.engine) + 1)
	var arm := "Blindaje al máximo" if int(c.armor) >= 3 else "Blindaje nivel %d — §250" % (int(c.armor) + 1)
	_menu("Taller Ruta 7", [["Reparar el coche — §40", "fix"], [eng, "engine"], [arm, "armor"], ["Pintura nueva — §60", "paint"], ["Salir del coche", "exit"]], _on_taller)


func _on_taller(id: String) -> void:
	if driving.is_empty():
		return
	var c := driving
	if id == "exit":
		_exit_car()
	elif id == "fix":
		if float(c.hp) >= float(c.maxhp):
			hud.toast("El coche ya está como nuevo.")
		elif _pay(40):
			c.hp = c.maxhp
			hud.toast("Coche reparado.")
	elif id == "engine":
		if int(c.engine) >= 3:
			hud.toast("El motor ya está al máximo.")
		elif _pay(300):
			c.engine += 1
			_tune(c)
			_claim(c)
			hud.toast("Motor mejorado: más velocidad y aceleración. Este es ahora tu coche.")
	elif id == "armor":
		if int(c.armor) >= 3:
			hud.toast("El blindaje ya está al máximo.")
		elif _pay(250):
			c.armor += 1
			_tune(c)
			c.hp = c.maxhp
			_claim(c)
			hud.toast("Blindaje mejorado: aguanta más golpes. Este es ahora tu coche.")
	elif id == "paint":
		if _pay(60):
			_repaint(c, Color.from_hsv(rng.randf(), 0.78, 0.82))
			_claim(c)
			hud.toast("Pintura nueva. Este es ahora tu coche.")
	_save()


func _restore_car() -> void:
	if mycar_data.is_empty():
		return
	var best: Dictionary = {}
	for c in cars:
		if c.mode == "parked" and (best.is_empty() or c.pos.distance_to(W.spawn) < best.pos.distance_to(W.spawn)):
			best = c
	if best.is_empty():
		return
	best.engine = clampi(int(mycar_data.get("engine", 0)), 0, 3)
	best.armor = clampi(int(mycar_data.get("armor", 0)), 0, 3)
	_tune(best)
	best.hp = best.maxhp
	var col = mycar_data.get("col", best.col)
	if col is Color:
		_repaint(best, col)
	_claim(best)


# ---------------------------------------------------------------- guardado

func _save() -> void:
	if shots_dir != "" or OS.get_environment("CM_TEST") != "":
		return
	var cf := ConfigFile.new()
	cf.set_value("g", "money", money)
	cf.set_value("g", "needs", needs)
	cf.set_value("g", "owned", owned)
	cf.set_value("g", "time", time_h)
	cf.set_value("g", "day", day)
	cf.set_value("g", "houses", houses)
	if not my_car.is_empty():
		cf.set_value("g", "mycar", {"col": my_car.col, "engine": my_car.engine, "armor": my_car.armor})
	cf.save(SAVE_PATH)


func _load() -> void:
	if OS.get_environment("CM_TEST") != "":
		return
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	money = int(cf.get_value("g", "money", money))
	var nd = cf.get_value("g", "needs", needs)
	if nd is Dictionary:
		for k in needs:
			if nd.has(k):
				needs[k] = float(nd[k])
	var ow = cf.get_value("g", "owned", {})
	if ow is Dictionary:
		owned = ow
	time_h = float(cf.get_value("g", "time", time_h))
	day = int(cf.get_value("g", "day", day))
	var hs = cf.get_value("g", "houses", {})
	if hs is Dictionary:
		for hk in hs:
			if int(hk) >= 0 and int(hk) < W.doors.size() and hs[hk] is Dictionary:
				houses[str(hk)] = hs[hk]
	var mc = cf.get_value("g", "mycar", {})
	if mc is Dictionary:
		mycar_data = mc


# ---------------------------------------------------------------- prueba automática

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _tick(i: int) -> void:
	if shots_dir != "" and i % 8 != 0:
		_process(1.0 / 30.0)
	else:
		await get_tree().process_frame


func _shot(sname: String) -> void:
	if shots_dir == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots_dir + "/" + sname + ".png")


func _look(pos: Vector3, target: Vector3) -> void:
	test_cam = true
	cam.position = pos
	cam.look_at(target, Vector3.UP)


func _tp(p: Vector3, yaw: float, pitch: float, dist: float) -> void:
	test_cam = false
	inside = ""
	ppos = p
	cam_yaw = yaw
	cam_pitch = pitch
	cam_dist = dist
	cam_snap = true


func _run_test() -> void:
	await _frames(10)
	await _shot("00_titulo")
	_on_play()
	await _frames(20)
	await _shot("01_casa")
	_tp(World.block_center(2, 2) + Vector3(3, 0, 16), 0.35, 0.08, 3.6)
	pyaw = 0.2
	await _frames(6)
	await _shot("01b_personaje")
	_tp(Vector3(World.road_pos(2) + 2.0, 0, World.block_center(0, 3).z + 6.0), 0.9, 0.16, 7.0)
	await _frames(6)
	await _shot("01c_coches")
	_look(Vector3(0, 150, 215), Vector3(0, 0, 20))
	await _frames(4)
	await _shot("02_ciudad")
	var pc := World.block_center(2, 2)
	_tp(pc + Vector3(0, 0, 15), 0.3, 0.35, 14.0)
	await _frames(6)
	await _shot("03_plaza")
	_tp(World.block_center(1, 1) + Vector3(2, 0, 12), 0.25, 0.3, 16.0)
	await _frames(6)
	await _shot("04_super")
	_tp(World.block_center(2, 1) + Vector3(-3, 0, 13), -0.4, 0.3, 13.0)
	await _frames(6)
	await _shot("05_cafe")
	_tp(World.block_center(2, 0) + Vector3(0, 0, 24.5), 0.2, 0.2, 20.0)
	await _frames(6)
	await _shot("06_pisos")
	_tp(World.block_center(2, 3) + Vector3(8, 0, 6), 0.9, 0.4, 14.0)
	await _frames(6)
	await _shot("07_parque")
	_tp(Vector3(World.road_pos(2) + 5.5, 0, World.block_center(0, 3).z), 0.1, 0.3, 12.0)
	await _frames(6)
	await _shot("08_calle")
	time_h = 22.0
	_tp(pc + Vector3(0, 0, 15), 0.3, 0.35, 14.0)
	await _frames(6)
	await _shot("09_noche")
	_look(Vector3(60, 60, 150), Vector3(0, 0, 0))
	await _frames(4)
	await _shot("10_noche_ciudad")
	time_h = 11.0
	test_cam = false
	for kind in W.rooms:
		_goto_room({"pos": W.spawn, "dir": Vector3(0, 0, 1), "kind": kind, "name": W.rooms[kind].name})
		await _frames(6)
		await _shot("int_" + kind)
	owned = {"sofa": true, "tele": true, "lampara": true, "planta": true, "alfombra": true, "estanteria": true}
	_apply_owned()
	_goto_room({"pos": W.spawn, "dir": Vector3(0, 0, 1), "kind": "hogar", "name": "Casa Mirasol"})
	await _frames(6)
	await _shot("int_hogar_amueblado")
	# acciones dentro de las salas
	for s in W.spots:
		if s.id == "salir":
			continue
		inside = s.room
		cur_owned = s.get("own", false)
		cur_door = home_idx
		ppos = s.pos
		_update_action()
		if cur_action.is_empty():
			print("CM_FALLO sin acción en ", s.label)
		await _do_spot(s)
		if busy and hud.menu_p != null:
			_on_menu("talk" if s.id == "hablar" else "")
	cur_owned = false
	# paseo con colisiones y entrada por una puerta real
	_tp(W.spawn, 0.0, 0.45, 10.0)
	await _frames(3)
	for step in 240:
		joy_vec = Vector2(sin(step * 0.07), -0.8)
		await get_tree().process_frame
	joy_vec = Vector2.ZERO
	var dr: Dictionary = W.doors[0]
	ppos = dr.pos
	_update_action()
	if cur_action.is_empty() or cur_action.type != "door":
		print("CM_FALLO puerta sin acción")
	await _enter(dr)
	await _frames(3)
	await _exit()
	await _frames(60)
	await _shot("11_final")
	# --- modo GTA
	mission = {}
	time_h = 10.0
	needs.energia = 90.0
	needs.hambre = 90.0
	mission_cd = 999.0
	_tp(W.spawn, 0.0, 0.45, 10.0)
	var pk: Dictionary = {}
	for c in cars:
		if c.mode == "parked" and (pk.is_empty() or c.pos.distance_to(ppos) < pk.pos.distance_to(ppos)):
			pk = c
	ppos = pk.pos + Vector3(0, 0, 2.6)
	_update_action()
	if cur_action.is_empty() or cur_action.type != "car":
		print("CM_FALLO coche aparcado sin acción")
	_enter_car(pk)
	for step in 200:
		joy_vec = Vector2(1.0 if step > 22 and step < 62 else 0.0, -1.0)
		await _tick(step)
	await _shot("12_conduciendo")
	print("CM_INFO conducir pos=", ppos, " vel=", driving.speed, " hp=", driving.hp)
	if ppos.distance_to(pk.pos) > 0.1 or ppos.distance_to(W.spawn) < 8.0:
		print("CM_FALLO el coche no se ha movido")
	_crime(5)
	_crime(5)
	_crime(5)
	var reached := -1
	for step in 900:
		joy_vec = Vector2(0.0, 0.2)
		await _tick(step)
		if pol_near < 16.0:
			reached = step
			break
	print("CM_INFO policia_llega_frame=", reached, " patrullas=", police.size(), " estrellas=", wanted)
	if reached < 0:
		print("CM_FALLO la policía no llega")
	await _frames(20)
	await _shot("13_persecucion")
	joy_vec = Vector2.ZERO
	for step in 400:
		await _tick(step)
		if wanted == 0:
			break
	if wanted != 0:
		print("CM_FALLO no te detienen")
	await _frames(40)
	for k in 3:
		mission_cd = 0.0
		ppos = m_markers[0]
		await _frames(2)
		if mission.is_empty():
			print("CM_FALLO la misión no empieza")
			break
		print("CM_INFO mision=", mission.title, " recompensa=", mission.reward)
		if mission.type == "huida":
			await _frames(30)
			await _shot("14_huida")
			wanted = 0
		else:
			await _shot("14_mision_" + mission.type)
			while not mission.is_empty():
				ppos = mission.pts[mission.stage]
				await _frames(2)
		await _frames(3)
		if not mission.is_empty():
			print("CM_FALLO la misión no termina")
		_clear_police()
		wanted = 0
	mission_cd = 999.0
	var victim: Dictionary = npcs[0]
	ppos = victim.pos + Vector3(0.9, 0, 0)
	pyaw = -PI / 2.0
	var m0 := money
	_punch()
	await _frames(30)
	await _shot("15_golpe")
	if money == m0 or victim.down <= 0.0:
		print("CM_FALLO el golpe no funciona")
	wanted = 0
	_clear_police()
	var ai_car: Dictionary = {}
	for c in cars:
		if c.mode == "ai":
			ai_car = c
			break
	ai_car.speed = 0.0
	ppos = ai_car.pos + Vector3(2.4, 0, 0)
	_update_action()
	if cur_action.is_empty() or cur_action.type != "car":
		print("CM_FALLO coche con conductor sin acción")
	_enter_car(ai_car)
	for step in 120:
		joy_vec = Vector2(0.0, -1.0)
		await _tick(step)
	joy_vec = Vector2.ZERO
	driving.speed = 0.0
	_update_action()
	_do_action()
	if not driving.is_empty():
		print("CM_FALLO no se puede salir del coche")
	await _frames(20)
	# --- casas, taller y atracos
	wanted = 0
	_clear_police()
	money = 20000
	var hidx := -1
	for i in W.doors.size():
		if HOUSE_KINDS.has(W.doors[i].kind) and W.doors[i].kind != "piso":
			hidx = i
			break
	inside = ""
	ppos = W.doors[hidx].pos
	_update_action()
	_do_action()
	if hud.menu_p == null:
		print("CM_FALLO no sale el menú de compra")
	await _frames(3)
	await _shot("16_menu_casa")
	_on_menu("buy")
	if not houses.has(str(hidx)):
		print("CM_FALLO no se compra la casa")
	_goto_room(W.doors[hidx])
	if not cur_owned:
		print("CM_FALLO la casa comprada no es tuya")
	_home_menu()
	_on_menu("alarm")
	_home_menu()
	_on_menu("rent")
	_home_menu()
	_on_menu("pool")
	var m1 := money
	_new_day()
	if money != m1 + 100 or not pool_nodes.has(str(hidx)):
		print("CM_FALLO mejoras de casa")
	wanted = 3
	_goto_room(W.doors[hidx])
	if wanted != 0:
		print("CM_FALLO la alarma no quita estrellas")
	await _exit()
	_tp(W.doors[hidx].pos + Vector3(3, 0, 6), 0.5, 0.4, 13.0)
	await _frames(6)
	await _shot("17_mi_casa")
	for room in LOOT:
		var who := -1
		for i in W.statics.size():
			if W.statics[i].room == room and W.statics[i].role != "guard":
				who = i
		wanted = 0
		var m2 := money
		menu_ctx = {"who": who, "room": room}
		_on_staff_menu("rob")
		if money <= m2 or wanted < 2:
			print("CM_FALLO atraco en ", room)
		print("CM_INFO atraco ", room, " botín=", money - m2, " estrellas=", wanted)
	_goto_room({"pos": W.spawn, "dir": Vector3(0, 0, 1), "kind": "banco", "name": "Banco Mirasol"})
	ppos = W.rooms["banco"].origin + Vector3(0, 0, -0.8)
	await _frames(8)
	await _shot("18_atraco_banco")
	inside = ""
	wanted = 0
	_clear_police()
	hands.clear()
	var tc: Dictionary = {}
	for c in cars:
		if c.mode == "parked":
			tc = c
			break
	tc.pos = W.taller_pos
	_enter_car(tc)
	await _frames(3)
	_update_action()
	if cur_action.is_empty() or cur_action.type != "taller":
		print("CM_FALLO el taller no responde")
	_do_action()
	await _frames(3)
	await _shot("19_taller_menu")
	_on_menu("engine")
	_taller_menu()
	_on_menu("armor")
	_taller_menu()
	_on_menu("paint")
	if int(tc.engine) != 1 or int(tc.armor) != 1 or not tc.mine or float(tc.top) <= float(tc.base_top):
		print("CM_FALLO mejoras de coche")
	cam_yaw = 2.4
	cam_pitch = 0.3
	cam_dist = 13.0
	cam_snap = true
	await _frames(8)
	await _shot("20_gasolinera")
	_exit_car()
	print("CM_STATS puertas=%d colisiones=%d vecinos=%d coches=%d salas=%d" % [W.doors.size(), W.colliders.size(), npcs.size(), cars.size(), W.rooms.size()])
	print("CM_TEST_OK")
	get_tree().quit()
