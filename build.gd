extends RefCounted
# Modelos de fantasía oscura hechos con primitivas suaves.

const Sh = preload("res://shaders.gd")

static var _mats: Dictionary = {}


static func mat(c: Color, alpha: float = 1.0) -> StandardMaterial3D:
	var k = c.to_html() + "_" + str(alpha)
	if _mats.has(k):
		return _mats[k]
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.roughness = 0.85
	m.rim_enabled = true
	m.rim = 0.1
	m.rim_tint = 0.4
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 0.35
	_mats[k] = m
	return m


static func metal(c: Color, rough: float = 0.42) -> StandardMaterial3D:
	var k = "m" + c.to_html() + str(rough)
	if _mats.has(k):
		return _mats[k]
	var m = StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.65
	m.roughness = rough
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.2
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


static func prism(parent: Node3D, size: Vector3, m: Material, pos: Vector3) -> MeshInstance3D:
	var p = PrismMesh.new()
	p.size = size
	return _add(parent, p, m, pos)


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


static func horn(parent: Node3D, m: Material, pos: Vector3, side: float, length: float) -> void:
	var h1 = cyl(parent, 0.05, 0.09, length * 0.55, m, pos, 6)
	h1.rotation.z = -side * 1.0
	var h2 = cyl(parent, 0.0, 0.05, length * 0.6, m, pos + Vector3(side * length * 0.42, length * 0.38, 0), 6)
	h2.rotation.z = -side * 0.15


# o: style ("knight", "rogue", "mage", "shaman", "skeleton", "wraith", "lord", "smith"),
#    cloth (color de acento), weapon ("", "sword", "dagger", "staff"), cape (Color, opcional)
static func humanoid(o: Dictionary) -> Dictionary:
	var style: String = o.get("style", "knight")
	var accent: Color = o["cloth"]
	var a = 1.0
	if style == "wraith":
		a = 0.5
	var root = Node3D.new()
	var body = Node3D.new()
	root.add_child(body)
	var steel = metal(Color("565b63"))
	if style == "lord":
		steel = metal(Color("1d1c20"), 0.35)
	var leather = mat(Color("2b211b"), a)
	var cloth = mat(accent, a)
	var dcloth = mat(Color("1b1a20"), a)
	if style == "wraith":
		dcloth = mat(Color("9fd8c8"), a)
	var bone = mat(Color("cfc6ae"))
	var skin = mat(Color("c2a084"))
	var black = mat(Color("0b0a0c"))
	var armored = style == "knight" or style == "lord"
	var robed = style == "mage" or style == "shaman" or style == "wraith"
	var limb = leather
	if armored:
		limb = steel
	elif robed:
		limb = dcloth
	elif style == "skeleton":
		limb = bone

	# --- torso ---
	if style == "skeleton":
		cyl(body, 0.05, 0.05, 0.8, bone, Vector3(0, 1.3, 0), 6)
		for i in range(3):
			var rib = cyl(body, 0.24 - i * 0.025, 0.24 - i * 0.025, 0.05, bone, Vector3(0, 1.52 - i * 0.14, 0.02), 10)
			rib.scale.z = 0.7
		box(body, Vector3(0.4, 0.14, 0.2), bone, Vector3(0, 0.86, 0))
		box(body, Vector3(0.72, 0.07, 0.1), bone, Vector3(0, 1.64, 0))
		box(body, Vector3(0.3, 0.42, 0.03), mat(accent.darkened(0.4)), Vector3(0, 0.66, 0.12))
	else:
		var chest = capsule(body, 0.27, 0.8, steel if armored else (dcloth if robed else leather), Vector3(0, 1.36, 0))
		chest.scale = Vector3(1.28, 1.0, 0.86)
		if armored:
			box(body, Vector3(0.08, 0.5, 0.06), steel, Vector3(0, 1.42, 0.245))
			cyl(body, 0.2, 0.3, 0.14, steel, Vector3(0, 1.72, 0))
			var tas = cyl(body, 0.33, 0.47, 0.42, steel, Vector3(0, 0.86, 0))
			tas.scale.z = 0.86
			box(body, Vector3(0.26, 0.82, 0.03), cloth, Vector3(0, 0.98, 0.3))
			var belt = cyl(body, 0.35, 0.35, 0.09, leather, Vector3(0, 1.06, 0))
			belt.scale.z = 0.86
		elif robed:
			if style == "wraith":
				cyl(body, 0.33, 0.06, 1.35, dcloth, Vector3(0, 0.5, 0))
			else:
				var robe = cyl(body, 0.3, 0.55, 1.06, dcloth, Vector3(0, 0.6, 0))
				robe.scale.z = 0.86
				var hem = cyl(body, 0.535, 0.56, 0.1, cloth, Vector3(0, 0.12, 0))
				hem.scale.z = 0.86
				var sash = cyl(body, 0.33, 0.34, 0.1, cloth, Vector3(0, 1.06, 0))
				sash.scale.z = 0.86
				box(body, Vector3(0.1, 0.6, 0.03), cloth, Vector3(0.1, 0.75, 0.33))
		else:
			var skirt = cyl(body, 0.3, 0.42, 0.4, leather, Vector3(0, 0.88, 0))
			skirt.scale.z = 0.86
			var belt2 = cyl(body, 0.34, 0.34, 0.08, black, Vector3(0, 1.06, 0))
			belt2.scale.z = 0.86
			box(body, Vector3(0.1, 0.1, 0.04), metal(Color("8a7a4a")), Vector3(0, 1.06, 0.3))
			if style == "smith":
				box(body, Vector3(0.44, 0.9, 0.04), mat(Color("4a3526")), Vector3(0, 1.1, 0.27))
			else:
				var strap = box(body, Vector3(0.07, 0.8, 0.04), black, Vector3(0, 1.4, 0.25))
				strap.rotation.z = 0.7

	# --- cabeza ---
	if style == "knight" or style == "lord":
		sphere(body, 0.285, steel, Vector3(0, 1.99, 0))
		box(body, Vector3(0.32, 0.05, 0.08), black, Vector3(0, 2.01, 0.25))
		box(body, Vector3(0.05, 0.3, 0.08), steel, Vector3(0, 1.94, 0.265))
		cyl(body, 0.2, 0.26, 0.18, steel, Vector3(0, 1.8, 0.02))
		if style == "knight":
			box(body, Vector3(0.06, 0.26, 0.56), cloth, Vector3(0, 2.3, -0.06))
		else:
			var ember = glow(Color("ff5a1e"), 5.0)
			sphere(body, 0.05, ember, Vector3(-0.09, 2.01, 0.26), 6)
			sphere(body, 0.05, ember, Vector3(0.09, 2.01, 0.26), 6)
			horn(body, bone, Vector3(-0.3, 2.18, 0), -1.0, 0.9)
			horn(body, bone, Vector3(0.3, 2.18, 0), 1.0, 0.9)
			for i in range(5):
				var an = (i - 2) * 0.5
				cyl(body, 0.0, 0.04, 0.22, steel, Vector3(sin(an) * 0.2, 2.34, cos(an) * 0.12), 4)
	elif style == "skeleton":
		var skull = sphere(body, 0.23, bone, Vector3(0, 1.98, 0))
		skull.scale = Vector3(1.0, 1.05, 1.08)
		box(body, Vector3(0.24, 0.1, 0.2), bone, Vector3(0, 1.77, 0.05))
		sphere(body, 0.065, black, Vector3(-0.09, 2.0, 0.2), 6)
		sphere(body, 0.065, black, Vector3(0.09, 2.0, 0.2), 6)
		var red = glow(Color("ff3a2a"), 4.0)
		sphere(body, 0.022, red, Vector3(-0.09, 2.0, 0.245), 4)
		sphere(body, 0.022, red, Vector3(0.09, 2.0, 0.245), 4)
		var cap = sphere(body, 0.25, metal(Color("3d342c"), 0.8), Vector3(0, 2.07, -0.02))
		cap.scale = Vector3(1.0, 0.6, 1.05)
	elif style == "wraith":
		var hoodw = sphere(body, 0.3, dcloth, Vector3(0, 2.0, -0.03))
		hoodw.scale = Vector3(1.0, 1.1, 1.05)
		sphere(body, 0.2, black, Vector3(0, 1.97, 0.1))
		var eyes = glow(Color("7ffff0"), 6.0)
		sphere(body, 0.035, eyes, Vector3(-0.08, 1.99, 0.27), 6)
		sphere(body, 0.035, eyes, Vector3(0.08, 1.99, 0.27), 6)
	elif style == "shaman":
		sphere(body, 0.24, skin, Vector3(0, 1.98, -0.02))
		var hd = sphere(body, 0.285, dcloth, Vector3(0, 2.02, -0.07))
		hd.scale = Vector3(1.0, 1.0, 1.05)
		var mask = sphere(body, 0.22, bone, Vector3(0, 1.97, 0.1))
		mask.scale = Vector3(0.95, 1.15, 0.8)
		sphere(body, 0.06, black, Vector3(-0.09, 2.0, 0.24), 6)
		sphere(body, 0.06, black, Vector3(0.09, 2.0, 0.24), 6)
		var ge = glow(Color("6affb0"), 4.0)
		sphere(body, 0.02, ge, Vector3(-0.09, 2.0, 0.285), 4)
		sphere(body, 0.02, ge, Vector3(0.09, 2.0, 0.285), 4)
		horn(body, bone, Vector3(-0.24, 2.2, 0), -1.0, 0.7)
		horn(body, bone, Vector3(0.24, 2.2, 0), 1.0, 0.7)
		for i in range(5):
			sphere(body, 0.045, bone, Vector3((i - 2) * 0.1, 1.68 - abs(i - 2) * -0.03, 0.26), 6)
	else:
		sphere(body, 0.24, skin, Vector3(0, 1.98, 0))
		sphere(body, 0.032, black, Vector3(-0.09, 2.0, 0.215), 6)
		sphere(body, 0.032, black, Vector3(0.09, 2.0, 0.215), 6)
		if style == "smith":
			box(body, Vector3(0.3, 0.2, 0.14), mat(Color("2a2420")), Vector3(0, 1.84, 0.14))
		else:
			var hood = sphere(body, 0.29, dcloth, Vector3(0, 2.03, -0.06))
			hood.scale = Vector3(1.0, 1.0, 1.08)
			var tipc = cyl(body, 0.0, 0.2, 0.42, dcloth, Vector3(0, 2.26, -0.2), 8)
			tipc.rotation.x = -0.9
			if style == "rogue":
				box(body, Vector3(0.36, 0.16, 0.12), black, Vector3(0, 1.89, 0.17))
			else:
				var beard = cyl(body, 0.13, 0.0, 0.36, mat(Color("9a968c")), Vector3(0, 1.73, 0.19), 8)
				beard.rotation.x = 0.25

	# --- brazos ---
	var arm_l = pivot(body, Vector3(-0.43, 1.64, 0))
	var arm_r = pivot(body, Vector3(0.43, 1.64, 0))
	var side = -1.0
	for arm in [arm_l, arm_r]:
		if style == "skeleton":
			capsule(arm, 0.045, 0.7, bone, Vector3(0, -0.33, 0))
			sphere(arm, 0.07, bone, Vector3(0, -0.7, 0), 6)
		else:
			capsule(arm, 0.1, 0.72, skin if style == "smith" else limb, Vector3(0, -0.33, 0))
			sphere(arm, 0.095, steel if armored else (bone if style == "wraith" else skin), Vector3(0, -0.7, 0), 8)
			if armored:
				cyl(arm, 0.12, 0.14, 0.26, steel, Vector3(0, -0.52, 0))
				var pad = sphere(arm, 0.2 if style == "knight" else 0.25, steel, Vector3(side * 0.03, 0.04, 0), 10)
				pad.scale = Vector3(1.15, 0.75, 1.15)
				var spike = cyl(arm, 0.0, 0.06, 0.26 if style == "knight" else 0.45, steel, Vector3(side * 0.14, 0.2, 0), 5)
				spike.rotation.z = -side * 0.6
			elif robed:
				cyl(arm, 0.1, 0.17, 0.3, dcloth, Vector3(0, -0.52, 0))
			else:
				cyl(arm, 0.115, 0.115, 0.2, black, Vector3(0, -0.52, 0))
		side = 1.0

	# --- piernas ---
	var leg_l = pivot(body, Vector3(-0.17, 0.7, 0))
	var leg_r = pivot(body, Vector3(0.17, 0.7, 0))
	if style != "wraith":
		for leg in [leg_l, leg_r]:
			if style == "skeleton":
				capsule(leg, 0.05, 0.66, bone, Vector3(0, -0.32, 0))
				box(leg, Vector3(0.12, 0.06, 0.26), bone, Vector3(0, -0.66, 0.05))
			else:
				capsule(leg, 0.11, 0.66, steel if armored else black, Vector3(0, -0.32, 0))
				box(leg, Vector3(0.2, 0.14, 0.34), steel if armored else black, Vector3(0, -0.63, 0.05))
				if armored:
					sphere(leg, 0.1, steel, Vector3(0, -0.28, 0.08), 8)

	# --- capa ---
	if o.has("cape"):
		var q = QuadMesh.new()
		q.size = Vector2(0.78, 1.25)
		q.subdivide_width = 4
		q.subdivide_depth = 8
		var cape = _add(body, q, Sh.mat(Sh.CAPE, {"tint": o["cape"], "ember": 1.0 if style == "lord" else 0.0}), Vector3(0, 1.08, -0.27))
		cape.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# --- arma ---
	var blade = null
	var weapon: String = o.get("weapon", "")
	if style == "wraith":
		weapon = "scythe"
	if weapon != "":
		var w = pivot(arm_r, Vector3(0, -0.7, 0))
		w.rotation.x = PI / 2.0
		blade = StandardMaterial3D.new()
		blade.albedo_color = Color("b9bec6")
		blade.metallic = 0.8
		blade.roughness = 0.3
		blade.emission_enabled = true
		blade.emission = accent.lightened(0.4)
		blade.emission_energy_multiplier = 0.0
		if style == "skeleton":
			blade.albedo_color = Color("5a4636")
			blade.roughness = 0.9
		if style == "lord":
			blade.albedo_color = Color("2a1a14")
			blade.emission = Color("ff5a1e")
			blade.emission_energy_multiplier = 2.5
		if weapon == "sword":
			var big = 1.0
			if armored:
				big = 1.25
			box(w, Vector3(0.11 * big, 1.25 * big, 0.035), blade, Vector3(0, 0.2 + 0.625 * big, 0))
			var tip = cyl(w, 0.0, 0.078 * big, 0.24, blade, Vector3(0, 0.32 + 1.25 * big, 0), 4)
			tip.scale.z = 0.35
			tip.rotation.y = PI / 4.0
			box(w, Vector3(0.44 * big, 0.07, 0.1), black, Vector3(0, 0.16, 0))
			cyl(w, 0.035, 0.035, 0.34, leather, Vector3(0, -0.02, 0), 8)
			sphere(w, 0.065, black, Vector3(0, -0.2, 0), 8)
		elif weapon == "dagger":
			for hand in [w, pivot(arm_l, Vector3(0, -0.7, 0))]:
				hand.rotation.x = PI / 2.0
				box(hand, Vector3(0.07, 0.5, 0.03), blade, Vector3(0, 0.4, 0))
				var dt = cyl(hand, 0.0, 0.05, 0.18, blade, Vector3(0, 0.74, 0), 4)
				dt.scale.z = 0.4
				dt.rotation.y = PI / 4.0
				box(hand, Vector3(0.2, 0.05, 0.07), black, Vector3(0, 0.12, 0))
		elif weapon == "scythe":
			cyl(w, 0.035, 0.04, 2.1, black, Vector3(0, 0.5, 0), 6)
			blade.albedo_color = Color("9fd8c8")
			blade.emission = Color("7ffff0")
			blade.emission_energy_multiplier = 1.2
			var sb = box(w, Vector3(0.7, 0.12, 0.03), blade, Vector3(0.3, 1.5, 0))
			sb.rotation.z = -0.35
		else:
			cyl(w, 0.04, 0.05, 2.0, mat(Color("231a14")), Vector3(0, 0.5, 0), 8)
			if style == "shaman":
				var sk = sphere(w, 0.17, bone, Vector3(0, 1.62, 0), 10)
				sk.scale = Vector3(1.0, 1.1, 1.0)
				sphere(w, 0.05, glow(Color("6affb0"), 4.0), Vector3(0.06, 1.64, 0.13), 6)
				sphere(w, 0.05, glow(Color("6affb0"), 4.0), Vector3(-0.06, 1.64, 0.13), 6)
				blade.albedo_color = Color("6affb0")
				blade.emission = Color("6affb0")
				sphere(w, 0.07, blade, Vector3(0, 1.86, 0), 6)
			else:
				blade.albedo_color = accent.lightened(0.5)
				blade.emission_energy_multiplier = 1.5
				sphere(w, 0.17, blade, Vector3(0, 1.66, 0), 10)
				for i in range(3):
					var claw = cyl(w, 0.0, 0.03, 0.4, black, Vector3(cos(i * 2.1) * 0.17, 1.6, sin(i * 2.1) * 0.17), 5)
					claw.rotation.z = cos(i * 2.1) * 0.35
					claw.rotation.x = -sin(i * 2.1) * 0.35
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
	var d = mat(col.darkened(0.5))
	var bone = mat(Color("cfc6ae"))
	var black = mat(Color("0b0a0c"))
	var b = capsule(root, 0.33, 1.45, m, Vector3(0, 0.82, 0))
	b.rotation.x = PI / 2.0
	var chest = sphere(root, 0.4, m, Vector3(0, 0.9, 0.4), 12)
	chest.scale = Vector3(1.0, 1.0, 1.2)
	var head = sphere(root, 0.27, m, Vector3(0, 1.0, 0.9), 12)
	head.scale = Vector3(1.0, 0.92, 1.25)
	var snout = capsule(root, 0.13, 0.46, d, Vector3(0, 0.9, 1.22))
	snout.rotation.x = PI / 2.0
	var eye_col = Color("ff2a1e")
	if kind == "jabali":
		eye_col = Color("7dff5a")
	elif kind == "tigre":
		eye_col = Color("ff8a1e")
	if kind != "caballo":
		var eye = glow(eye_col, 5.0)
		sphere(root, 0.045, eye, Vector3(-0.13, 1.08, 1.1), 6)
		sphere(root, 0.045, eye, Vector3(0.13, 1.08, 1.1), 6)
		for k in [-1.0, 1.0]:
			var fang = cyl(root, 0.03, 0.0, 0.14, bone, Vector3(k * 0.07, 0.8, 1.4), 5)
			fang.rotation.x = 0.1
	for k in [-1.0, 1.0]:
		cyl(root, 0.0, 0.08, 0.24, d, Vector3(k * 0.16, 1.3, 0.82), 6)
	var tail = capsule(root, 0.06, 0.8, d, Vector3(0, 0.9, -0.98))
	tail.rotation.x = -1.0
	if kind == "lobo":
		for i in range(6):
			var sp = cyl(root, 0.0, 0.07, 0.32 - abs(i - 2) * 0.03, d, Vector3(0, 1.26, 0.6 - i * 0.26), 5)
			sp.rotation.x = -0.4
	elif kind == "jabali":
		for k in [-1.0, 1.0]:
			var tusk = cyl(root, 0.0, 0.055, 0.36, bone, Vector3(k * 0.16, 0.98, 1.36), 6)
			tusk.rotation.x = 0.7
			tusk.rotation.z = -k * 0.3
		var mane = capsule(root, 0.11, 1.1, black, Vector3(0, 1.16, 0.05))
		mane.rotation.x = PI / 2.0
		var sore = glow(Color("7dff5a"), 3.0)
		sphere(root, 0.08, sore, Vector3(0.24, 1.0, -0.2), 6)
		sphere(root, 0.06, sore, Vector3(-0.27, 0.9, 0.2), 6)
		sphere(root, 0.07, sore, Vector3(0.1, 1.12, -0.5), 6)
	elif kind == "tigre":
		var ember = glow(Color("ff6a1e"), 3.5)
		for i in range(5):
			var stripe = cyl(root, 0.338, 0.338, 0.06, ember, Vector3(0, 0.82, -0.5 + i * 0.25), 12)
			stripe.rotation.x = PI / 2.0
		horn(root, bone, Vector3(-0.2, 1.2, 0.85), -1.0, 0.5)
		horn(root, bone, Vector3(0.2, 1.2, 0.85), 1.0, 0.5)
	elif kind == "caballo":
		var neck = capsule(root, 0.17, 0.8, m, Vector3(0, 1.2, 0.68))
		neck.rotation.x = 0.7
		head.position = Vector3(0, 1.5, 1.0)
		snout.position = Vector3(0, 1.4, 1.32)
		var hmane = box(root, Vector3(0.06, 0.6, 0.5), black, Vector3(0, 1.42, 0.55))
		hmane.rotation.x = 0.7
		box(root, Vector3(0.74, 0.1, 0.6), mat(Color("5a1512")), Vector3(0, 1.14, 0))
		box(root, Vector3(0.7, 0.5, 0.04), mat(Color("5a1512")), Vector3(0, 0.9, -0.3))
		var cham = box(root, Vector3(0.2, 0.06, 0.5), metal(Color("565b63")), Vector3(0, 1.62, 1.12))
		cham.rotation.x = 0.3
		sphere(root, 0.04, glow(Color("ff2a1e"), 3.0), Vector3(-0.13, 1.56, 1.14), 6)
		sphere(root, 0.04, glow(Color("ff2a1e"), 3.0), Vector3(0.13, 1.56, 1.14), 6)
	var legs = []
	for q in [Vector2(-0.2, 0.48), Vector2(0.2, 0.48), Vector2(-0.2, -0.48), Vector2(0.2, -0.48)]:
		var p = pivot(root, Vector3(q.x, 0.62, q.y))
		capsule(p, 0.085, 0.62, m, Vector3(0, -0.3, 0))
		sphere(p, 0.09, black, Vector3(0, -0.57, 0.02), 6)
		legs.append(p)
	root.scale = Vector3.ONE * s
	return {"root": root, "legs": legs}


static func horse() -> Dictionary:
	return quad(Color("1b1a1f"), 1.45, "caballo")


static func anim_quad(q: Dictionary, t: float, moving: bool, rate: float) -> void:
	var s = 0.0
	if moving:
		s = sin(t * rate) * 0.7
	var legs = q["legs"]
	legs[0].rotation.x = s
	legs[3].rotation.x = s
	legs[1].rotation.x = -s
	legs[2].rotation.x = -s
