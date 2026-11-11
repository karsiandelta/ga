extends RefCounted
# Constructores de modelos hechos con primitivas suaves (cápsulas, esferas, conos).

const Sh = preload("res://shaders.gd")

static var _mats: Dictionary = {}


static func mat(c: Color, alpha: float = 1.0) -> StandardMaterial3D:
	var k = c.to_html() + "_" + str(alpha)
	if _mats.has(k):
		return _mats[k]
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.roughness = 0.8
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.5
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 0.6
	_mats[k] = m
	return m


static func glow(c: Color, energy: float = 1.5) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


static func flat(c: Color, alpha: float = 1.0, additive: bool = false) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if alpha < 1.0 or additive:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m


static func _add(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


static func box(parent: Node3D, size: Vector3, m: Material, pos: Vector3) -> MeshInstance3D:
	var b = BoxMesh.new()
	b.size = size
	return _add(parent, b, m, pos)


static func sphere(parent: Node3D, r: float, m: Material, pos: Vector3, segs: int = 14) -> MeshInstance3D:
	var s = SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = max(3, int(segs / 2.0))
	return _add(parent, s, m, pos)


static func capsule(parent: Node3D, r: float, h: float, m: Material, pos: Vector3) -> MeshInstance3D:
	var c = CapsuleMesh.new()
	c.radius = r
	c.height = max(h, r * 2.0)
	c.radial_segments = 12
	c.rings = 4
	return _add(parent, c, m, pos)


static func cyl(parent: Node3D, r_top: float, r_bottom: float, h: float, m: Material, pos: Vector3, sides: int = 12) -> MeshInstance3D:
	var c = CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bottom
	c.height = h
	c.radial_segments = sides
	c.rings = 1
	return _add(parent, c, m, pos)


static func pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var p = Node3D.new()
	p.position = pos
	parent.add_child(p)
	return p


# o: cloth, trim, skin (Color), ghost, hat (bool), weapon ("", "sword", "dagger", "staff"), cape (Color, opcional)
static func humanoid(o: Dictionary) -> Dictionary:
	var a = 1.0
	if o.get("ghost", false):
		a = 0.55
	var root = Node3D.new()
	var body = Node3D.new()
	root.add_child(body)
	var cloth_c: Color = o["cloth"]
	var cloth = mat(cloth_c, a)
	var cloth_d = mat(cloth_c.darkened(0.3), a)
	var trim = mat(o["trim"], a)
	var skin = mat(o.get("skin", Color("e8c39e")), a)
	var dark = mat(Color("2a2420"), a)
	var weapon = o.get("weapon", "")
	# torso y túnica
	var chest = capsule(body, 0.27, 0.8, cloth, Vector3(0, 1.36, 0))
	chest.scale = Vector3(1.25, 1.0, 0.82)
	var robe = cyl(body, 0.3, 0.5, 0.62, cloth_d, Vector3(0, 0.8, 0))
	robe.scale.z = 0.82
	var sash = cyl(body, 0.33, 0.34, 0.12, trim, Vector3(0, 1.06, 0))
	sash.scale.z = 0.82
	box(body, Vector3(0.12, 0.42, 0.04), trim, Vector3(0.12, 0.84, 0.3))
	cyl(body, 0.15, 0.3, 0.14, trim, Vector3(0, 1.72, 0))
	box(body, Vector3(0.1, 0.5, 0.05), trim, Vector3(0, 1.4, 0.23))
	# cabeza
	sphere(body, 0.25, skin, Vector3(0, 1.98, 0))
	var hair = sphere(body, 0.265, dark, Vector3(0, 2.04, -0.05))
	hair.scale = Vector3(1.0, 0.9, 1.0)
	sphere(body, 0.035, dark, Vector3(-0.09, 1.99, 0.225), 6)
	sphere(body, 0.035, dark, Vector3(0.09, 1.99, 0.225), 6)
	if o.get("hat", false):
		cyl(body, 0.0, 0.62, 0.26, mat(Color("c9a45c"), a), Vector3(0, 2.26, 0), 14)
	else:
		sphere(body, 0.1, dark, Vector3(0, 2.32, -0.06), 8)
		cyl(body, 0.05, 0.05, 0.05, trim, Vector3(0, 2.24, -0.06), 8)
	# brazos
	var arm_l = pivot(body, Vector3(-0.43, 1.64, 0))
	var arm_r = pivot(body, Vector3(0.43, 1.64, 0))
	for arm in [arm_l, arm_r]:
		capsule(arm, 0.1, 0.72, cloth, Vector3(0, -0.33, 0))
		cyl(arm, 0.12, 0.13, 0.12, trim, Vector3(0, -0.58, 0))
		sphere(arm, 0.095, skin, Vector3(0, -0.7, 0), 8)
		if weapon == "sword":
			var pad = sphere(arm, 0.18, trim, Vector3(0, 0.02, 0), 10)
			pad.scale = Vector3(1.15, 0.7, 1.15)
	# piernas
	var leg_l = pivot(body, Vector3(-0.17, 0.7, 0))
	var leg_r = pivot(body, Vector3(0.17, 0.7, 0))
	for leg in [leg_l, leg_r]:
		capsule(leg, 0.11, 0.66, dark, Vector3(0, -0.32, 0))
		box(leg, Vector3(0.2, 0.14, 0.34), dark, Vector3(0, -0.63, 0.05))
	# capa
	if o.has("cape"):
		var q = QuadMesh.new()
		q.size = Vector2(0.72, 1.15)
		q.subdivide_width = 3
		q.subdivide_depth = 8
		var cape = _add(body, q, Sh.mat(Sh.CAPE, {"tint": o["cape"]}), Vector3(0, 1.12, -0.25))
		cape.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# arma
	var blade = null
	if weapon != "":
		var w = pivot(arm_r, Vector3(0, -0.7, 0))
		w.rotation.x = PI / 2.0
		blade = StandardMaterial3D.new()
		blade.albedo_color = Color("d8dde2")
		blade.metallic = 0.85
		blade.roughness = 0.25
		blade.emission_enabled = true
		blade.emission = o["trim"]
		blade.emission_energy_multiplier = 0.0
		if weapon == "sword":
			box(w, Vector3(0.1, 1.2, 0.035), blade, Vector3(0, 0.78, 0))
			var tip = cyl(w, 0.0, 0.07, 0.22, blade, Vector3(0, 1.49, 0), 4)
			tip.scale.z = 0.35
			tip.rotation.y = PI / 4.0
			box(w, Vector3(0.36, 0.07, 0.1), trim, Vector3(0, 0.15, 0))
			cyl(w, 0.035, 0.035, 0.3, dark, Vector3(0, 0.0, 0), 8)
			sphere(w, 0.06, trim, Vector3(0, -0.17, 0), 8)
		elif weapon == "dagger":
			for hand in [w, pivot(arm_l, Vector3(0, -0.7, 0))]:
				hand.rotation.x = PI / 2.0
				box(hand, Vector3(0.07, 0.6, 0.03), blade, Vector3(0, 0.42, 0))
				box(hand, Vector3(0.2, 0.05, 0.07), trim, Vector3(0, 0.1, 0))
		else:
			cyl(w, 0.04, 0.05, 2.0, mat(Color("4b3626"), a), Vector3(0, 0.5, 0), 8)
			sphere(w, 0.2, blade, Vector3(0, 1.62, 0), 10)
			var ring = cyl(w, 0.26, 0.26, 0.04, trim, Vector3(0, 1.62, 0), 16)
			ring.rotation.x = PI / 2.0
	return {"root": root, "body": body, "arm_l": arm_l, "arm_r": arm_r, "leg_l": leg_l, "leg_r": leg_r, "blade": blade}


static func anim_h(p: Dictionary, t: float, moving: bool, swing: float) -> void:
	var s = 0.0
	if moving:
		s = sin(t * 11.0) * 0.8
		p["body"].position.y = abs(sin(t * 11.0)) * 0.06
		p["body"].rotation.x = 0.12
	else:
		p["body"].position.y = sin(t * 2.0) * 0.015
		p["body"].rotation.x = 0.0
	p["leg_l"].rotation.x = s
	p["leg_r"].rotation.x = -s
	p["arm_l"].rotation.x = -s * 0.7
	if swing > 0.0:
		p["arm_r"].rotation.x = -2.6 + (1.0 - swing) * 2.4
		p["body"].rotation.y = (swing - 0.5) * 0.9
	else:
		p["arm_r"].rotation.x = s * 0.7
		p["body"].rotation.y = 0.0


# kind: "lobo", "jabali", "tigre", "caballo"
static func quad(col: Color, s: float, kind: String = "") -> Dictionary:
	var root = Node3D.new()
	var m = mat(col)
	var d = mat(col.darkened(0.55))
	var light = mat(col.lightened(0.35))
	var b = capsule(root, 0.33, 1.45, m, Vector3(0, 0.82, 0))
	b.rotation.x = PI / 2.0
	var belly = capsule(root, 0.26, 1.2, light, Vector3(0, 0.72, 0))
	belly.rotation.x = PI / 2.0
	var head = sphere(root, 0.27, m, Vector3(0, 1.0, 0.86), 12)
	head.scale = Vector3(1.0, 0.92, 1.2)
	var snout = capsule(root, 0.12, 0.4, d if kind != "tigre" else light, Vector3(0, 0.92, 1.16))
	snout.rotation.x = PI / 2.0
	sphere(root, 0.04, mat(Color("1c1815")), Vector3(-0.12, 1.08, 1.06), 6)
	sphere(root, 0.04, mat(Color("1c1815")), Vector3(0.12, 1.08, 1.06), 6)
	for k in [-1.0, 1.0]:
		cyl(root, 0.0, 0.08, 0.2, d, Vector3(k * 0.16, 1.28, 0.8), 6)
	var tail = capsule(root, 0.06, 0.7, d, Vector3(0, 0.95, -0.95))
	tail.rotation.x = -0.9
	if kind == "jabali":
		for k in [-1.0, 1.0]:
			var tusk = cyl(root, 0.0, 0.04, 0.22, mat(Color("efe6d2")), Vector3(k * 0.13, 0.95, 1.3), 6)
			tusk.rotation.x = 0.5
		var mane = capsule(root, 0.1, 1.0, d, Vector3(0, 1.14, 0))
		mane.rotation.x = PI / 2.0
	elif kind == "tigre":
		for i in range(5):
			var stripe = cyl(root, 0.335, 0.335, 0.07, mat(Color("1c1815")), Vector3(0, 0.82, -0.5 + i * 0.25), 12)
			stripe.rotation.x = PI / 2.0
	elif kind == "caballo":
		var neck = capsule(root, 0.17, 0.8, m, Vector3(0, 1.2, 0.68))
		neck.rotation.x = 0.7
		head.position = Vector3(0, 1.5, 1.0)
		snout.position = Vector3(0, 1.4, 1.3)
		var hmane = box(root, Vector3(0.06, 0.6, 0.5), d, Vector3(0, 1.4, 0.55))
		hmane.rotation.x = 0.7
		box(root, Vector3(0.72, 0.1, 0.6), mat(Color("a8322a")), Vector3(0, 1.14, 0))
	var legs = []
	for q in [Vector2(-0.2, 0.48), Vector2(0.2, 0.48), Vector2(-0.2, -0.48), Vector2(0.2, -0.48)]:
		var p = pivot(root, Vector3(q.x, 0.62, q.y))
		capsule(p, 0.085, 0.62, m, Vector3(0, -0.3, 0))
		sphere(p, 0.09, d, Vector3(0, -0.57, 0.02), 6)
		legs.append(p)
	root.scale = Vector3.ONE * s
	return {"root": root, "legs": legs}


static func horse() -> Dictionary:
	return quad(Color("6b4a34"), 1.45, "caballo")


static func anim_quad(q: Dictionary, t: float, moving: bool, rate: float) -> void:
	var s = 0.0
	if moving:
		s = sin(t * rate) * 0.7
	var legs = q["legs"]
	legs[0].rotation.x = s
	legs[3].rotation.x = s
	legs[1].rotation.x = -s
	legs[2].rotation.x = -s
