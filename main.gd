extends Node3D
# Ciudad Mirasol — bucle principal: jugador, cámara, vecinos, tráfico, día y noche, acciones.

const World = preload("res://world.gd")
const Actors = preload("res://actors.gd")
const Hud = preload("res://hud.gd")
const Shaders = preload("res://shaders.gd")

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
	hud.play_pressed.connect(_on_play)
	hud.zoom_pressed.connect(func(dir): cam_dist = clampf(cam_dist + dir * 2.5, 4.5, 26.0))
	_load()
	_apply_owned()
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
	env.adjustment_contrast = 1.04
	env.adjustment_saturation = 1.06
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
		var d := {"node": node, "name": _rand_name(female), "pos": a.lerp(b, rng.randf()) + off, "prev": cur, "cur": nxt, "off": off, "speed": rng.randf_range(1.2, 1.9), "phase": rng.randf() * TAU, "wait": 0.0, "yaw": 0.0, "idle": false, "amt": 1.0}
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
		npcs.append({"node": node, "name": _rand_name(female), "pos": p, "prev": [], "cur": [], "off": Vector3.ZERO, "speed": 0.0, "phase": rng.randf() * TAU, "wait": 0.0, "yaw": yaw, "idle": true, "amt": 0.0})


func _update_npcs(dt: float) -> void:
	for n in npcs:
		var node: Node3D = n.node
		var pos: Vector3 = n.pos
		var near := pos.distance_squared_to(ppos) < 90.0 * 90.0
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


func _spawn_cars() -> void:
	var used: Dictionary = {}
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var made := 0
	var tries := 0
	while made < 18 and tries < 500:
		tries += 1
		var a := Vector2i(rng.randi() % (World.N + 1), rng.randi() % (World.N + 1))
		var d: Vector2i = dirs[rng.randi() % 4]
		var b := a + d
		var key := "%d,%d,%d,%d" % [a.x, a.y, d.x, d.y]
		if not _valid(b) or used.has(key):
			continue
		used[key] = true
		var kind := 0
		if made % 9 == 4:
			kind = 2
		elif made % 5 == 2:
			kind = 1
		var col: Color = Actors.CAR_COLS[rng.randi() % Actors.CAR_COLS.size()]
		if kind == 1:
			col = Color(0.98, 0.8, 0.1)
		elif kind == 2:
			col = Color(0.85, 0.25, 0.2)
		var node := Actors.car(W.mat_solid, W.mat_glow, col, kind)
		add_child(node)
		var p := _lane_start(a, d).lerp(_lane_end(b, d), rng.randf_range(0.2, 0.8))
		var yaw := atan2(float(d.x), float(d.y))
		node.position = p
		node.rotation.y = yaw
		cars.append({"node": node, "pos": p, "b": b, "d": d, "pts": [_lane_end(b, d)], "speed": 0.0, "max": 6.5 if kind == 2 else rng.randf_range(7.5, 10.0), "yaw": yaw, "stuck": 0.0, "free": 0.0, "len": 5.5 if kind == 2 else 3.0})
		made += 1


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
		var pos: Vector3 = c.pos
		var fwd := Vector3(sin(c.yaw), 0, cos(c.yaw))
		var blocked := false
		var reach: float = 5.0 + c.len + c.speed * 0.5
		if c.free <= 0.0:
			for o in cars:
				if o == c:
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
			if inside == "":
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

func _clock_text() -> String:
	var h := int(time_h)
	var m := int((time_h - h) * 60.0)
	return "%s %02d:%02d" % [DAYS[day], h, m]


func _advance(hours: float) -> void:
	time_h += hours
	while time_h >= 24.0:
		time_h -= 24.0
		day = (day + 1) % 7
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
	var moving := false
	if not busy and jv.length() > 0.12:
		var fwd := -Vector3(sin(cam_yaw), 0, cos(cam_yaw))
		var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
		var mv := right * jv.x - fwd * jv.y
		var speed := 4.8
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
			var sp: Vector3 = s.pos
			var d := Vector2(sp.x - ppos.x, sp.z - ppos.z).length()
			if d < 1.8 and d < bd:
				bd = d
				best = {"type": "spot", "spot": s}
				label = s.label
				if s.id == "hablar" and W.statics[s.who].role == "host":
					label = "Hablar con " + host_name
	else:
		for dr in W.doors:
			var dp: Vector3 = dr.pos
			var d := Vector2(dp.x - ppos.x, dp.z - ppos.z).length()
			if d < 2.4 and d < bd:
				bd = d
				best = {"type": "door", "door": dr}
				label = "Entrar: " + dr.name
		for n in npcs:
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
	if a.type == "door":
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
	hud.toast("Bienvenido a Ciudad Mirasol. Explora, entra en las tiendas y saluda a tus vecinos.")


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
	_update_camera(dt)
	_update_action()
	_update_needs(dt)
	hud.set_needs(needs)
	hud.money_l.text = "§ %d" % money
	hud.clock_l.text = _clock_text()
	hud.place_l.text = _place()
	hud.mini.ppos = return_pos if inside != "" else ppos
	hud.mini.yaw = pyaw
	save_t += dt
	if save_t > 30.0:
		save_t = 0.0
		_save()


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


# ---------------------------------------------------------------- prueba automática

func _frames(n: int) -> void:
	for i in n:
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
		ppos = s.pos
		_update_action()
		if cur_action.is_empty():
			print("CM_FALLO sin acción en ", s.label)
		await _do_spot(s)
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
	await _frames(200)
	await _shot("11_final")
	print("CM_STATS puertas=%d colisiones=%d vecinos=%d coches=%d salas=%d" % [W.doors.size(), W.colliders.size(), npcs.size(), cars.size(), W.rooms.size()])
	print("CM_TEST_OK")
	get_tree().quit()
