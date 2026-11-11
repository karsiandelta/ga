extends RefCounted
# Constructores de modelos low-poly hechos con primitivas.

static var _mats: Dictionary = {}


static func mat(c: Color, alpha: float = 1.0) -> StandardMaterial3D:
	var k = c.to_html() + "_" + str(alpha)
	if _mats.has(k):
		return _mats[k]
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.roughness = 0.9
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
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


static func sphere(parent: Node3D, r: float, m: Material, pos: Vector3, segs: int = 12) -> MeshInstance3D:
	var s = SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = max(3, int(segs / 2.0))
	return _add(parent, s, m, pos)


static func cyl(parent: Node3D, r_top: float, r_bottom: float, h: float, m: Material, pos: Vector3, sides: int = 8) -> MeshInstance3D:
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


# o: cloth, trim, skin (Color), ghost, hat (bool), weapon ("", "sword", "dagger", "staff")
static func humanoid(o: Dictionary) -> Dictionary:
	var a = 1.0
	if o.get("ghost", false):
		a = 0.6
	var root = Node3D.new()
	var body = Node3D.new()
	root.add_child(body)
	var cloth = mat(o["cloth"], a)
	var trim = mat(o["trim"], a)
	var skin = mat(o.get("skin", Color("e8c39e")), a)
	var dark = mat(Color("2a2420"), a)
	box(body, Vector3(0.72, 0.8, 0.42), cloth, Vector3(0, 1.32, 0))
	box(body, Vector3(0.76, 0.14, 0.46), trim, Vector3(0, 0.96, 0))
	box(body, Vector3(0.8, 0.34, 0.48), cloth, Vector3(0, 0.76, 0))
	box(body, Vector3(0.9, 0.16, 0.5), trim, Vector3(0, 1.7, 0))
	sphere(body, 0.27, skin, Vector3(0, 2.0, 0))
	if o.get("hat", false):
		cyl(body, 0.0, 0.6, 0.3, trim, Vector3(0, 2.3, 0), 10)
	else:
		box(body, Vector3(0.5, 0.2, 0.5), dark, Vector3(0, 2.2, -0.03))
	var arm_l = pivot(body, Vector3(-0.47, 1.66, 0))
	box(arm_l, Vector3(0.2, 0.72, 0.2), cloth, Vector3(0, -0.36, 0))
	var arm_r = pivot(body, Vector3(0.47, 1.66, 0))
	box(arm_r, Vector3(0.2, 0.72, 0.2), cloth, Vector3(0, -0.36, 0))
	var leg_l = pivot(body, Vector3(-0.19, 0.68, 0))
	box(leg_l, Vector3(0.24, 0.68, 0.24), dark, Vector3(0, -0.34, 0))
	var leg_r = pivot(body, Vector3(0.19, 0.68, 0))
	box(leg_r, Vector3(0.24, 0.68, 0.24), dark, Vector3(0, -0.34, 0))
	var blade = null
	var weapon = o.get("weapon", "")
	if weapon != "":
		var w = pivot(arm_r, Vector3(0, -0.7, 0))
		w.rotation.x = PI / 2.0
		blade = StandardMaterial3D.new()
		blade.albedo_color = Color("d8dde2")
		blade.metallic = 0.7
		blade.roughness = 0.3
		blade.emission_enabled = true
		blade.emission = o["trim"]
		blade.emission_energy_multiplier = 0.0
		if weapon == "sword":
			box(w, Vector3(0.09, 1.35, 0.04), blade, Vector3(0, 0.8, 0))
			box(w, Vector3(0.34, 0.07, 0.1), trim, Vector3(0, 0.12, 0))
		elif weapon == "dagger":
			box(w, Vector3(0.07, 0.7, 0.03), blade, Vector3(0, 0.45, 0))
			var w2 = pivot(arm_l, Vector3(0, -0.7, 0))
			w2.rotation.x = PI / 2.0
			box(w2, Vector3(0.07, 0.7, 0.03), blade, Vector3(0, 0.45, 0))
		else:
			cyl(w, 0.045, 0.045, 1.9, dark, Vector3(0, 0.5, 0), 6)
			sphere(w, 0.2, blade, Vector3(0, 1.55, 0), 6)
	return {"root": root, "body": body, "arm_l": arm_l, "arm_r": arm_r, "leg_l": leg_l, "leg_r": leg_r, "blade": blade}


static func anim_h(p: Dictionary, t: float, moving: bool, swing: float) -> void:
	var s = 0.0
	if moving:
		s = sin(t * 11.0) * 0.8
	p["leg_l"].rotation.x = s
	p["leg_r"].rotation.x = -s
	p["arm_l"].rotation.x = -s * 0.7
	if swing > 0.0:
		p["arm_r"].rotation.x = -2.6 + (1.0 - swing) * 2.4
		p["body"].rotation.y = (swing - 0.5) * 0.7
	else:
		p["arm_r"].rotation.x = s * 0.7
		p["body"].rotation.y = 0.0


static func quad(col: Color, s: float) -> Dictionary:
	var root = Node3D.new()
	var m = mat(col)
	var d = mat(Color("1c1815"))
	box(root, Vector3(0.62, 0.6, 1.3), m, Vector3(0, 0.78, 0))
	box(root, Vector3(0.46, 0.46, 0.5), m, Vector3(0, 0.95, 0.85))
	box(root, Vector3(0.26, 0.22, 0.3), d, Vector3(0, 0.85, 1.2))
	box(root, Vector3(0.1, 0.1, 0.5), m, Vector3(0, 0.95, -0.85))
	box(root, Vector3(0.1, 0.16, 0.08), m, Vector3(-0.15, 1.24, 0.75))
	box(root, Vector3(0.1, 0.16, 0.08), m, Vector3(0.15, 1.24, 0.75))
	var legs = []
	for q in [Vector2(-0.22, 0.45), Vector2(0.22, 0.45), Vector2(-0.22, -0.45), Vector2(0.22, -0.45)]:
		var p = pivot(root, Vector3(q.x, 0.55, q.y))
		box(p, Vector3(0.17, 0.55, 0.17), d, Vector3(0, -0.27, 0))
		legs.append(p)
	root.scale = Vector3.ONE * s
	return {"root": root, "legs": legs}


static func horse() -> Dictionary:
	var q = quad(Color("6b4a34"), 1.45)
	box(q["root"], Vector3(0.3, 0.6, 0.3), mat(Color("6b4a34")), Vector3(0, 1.25, 0.7))
	box(q["root"], Vector3(0.7, 0.1, 0.6), mat(Color("a8322a")), Vector3(0, 1.1, 0))
	return q


static func anim_quad(q: Dictionary, t: float, moving: bool, rate: float) -> void:
	var s = 0.0
	if moving:
		s = sin(t * rate) * 0.7
	var legs = q["legs"]
	legs[0].rotation.x = s
	legs[3].rotation.x = s
	legs[1].rotation.x = -s
	legs[2].rotation.x = -s
