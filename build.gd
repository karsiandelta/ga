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
	m.metallic = 0.45
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


static var _outline: ShaderMaterial = null


# Material de personaje: sombreado plano tipo ilustración y contorno de tinta.
static func cmat(c: Color, alpha: float = 1.0, metallic: float = 0.0) -> StandardMaterial3D:
	var k = "c" + c.to_html() + "_" + str(alpha) + "_" + str(metallic)
	if _mats.has(k):
		return _mats[k]
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.metallic = metallic
	m.roughness = 0.55 if metallic > 0.0 else 0.95
	m.rim_enabled = true
	m.rim = 0.3
	m.rim_tint = 0.3
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 0.35
	else:
		if _outline == null:
			_outline = Sh.mat(Sh.OUTLINE, {})
		m.next_pass = _outline
	_mats[k] = m
	return m


static func zcyl(parent: Node3D, rt: float, rb: float, h: float, m: Material, pos: Vector3, zs: float = 0.86) -> MeshInstance3D:
	var c = cyl(parent, rt, rb, h, m, pos)
	c.scale.z = zs
	return c


static func torus(parent: Node3D, inner: float, outer: float, m: Material, pos: Vector3) -> MeshInstance3D:
	var t = TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 20
	t.ring_segments = 8
	return _add(parent, t, m, pos)


# Paño colgante con el borde inferior rasgado.
static func tatter(parent: Node3D, w: float, h: float, m: Material, pos: Vector3) -> Node3D:
	var n = pivot(parent, pos)
	box(n, Vector3(w, h, 0.03), m, Vector3(0, -h / 2.0, 0))
	for i in range(3):
		var ph = h * (0.38 if i % 2 == 0 else 0.22)
		var p = prism(n, Vector3(w / 3.0, ph, 0.03), m, Vector3(-w / 2.0 + w / 3.0 * (i + 0.5), -h - ph / 2.0, 0))
		p.rotation.z = PI
	return n


static func horn(parent: Node3D, m: Material, pos: Vector3, side: float, length: float) -> void:
	var h1 = cyl(parent, 0.05, 0.09, length * 0.55, m, pos, 6)
	h1.rotation.z = -side * 1.0
	var h2 = cyl(parent, 0.0, 0.05, length * 0.6, m, pos + Vector3(side * length * 0.42, length * 0.38, 0), 6)
	h2.rotation.z = -side * 0.15


# o: style ("knight", "rogue", "mage", "shaman", "skeleton", "wraith", "lord", "smith"),
#    cloth (color del reino o de acento), weapon ("", "sword", "dagger", "staff"), cape (Color, opcional)
static func humanoid(o: Dictionary) -> Dictionary:
	var style: String = o.get("style", "knight")
	var accent: Color = o["cloth"]
	var a = 1.0
	if style == "wraith":
		a = 0.5
	var root = Node3D.new()
	var body = Node3D.new()
	root.add_child(body)
	var gold = cmat(Color("d1a548"), 1.0, 0.4)
	var steel = cmat(Color("5f6878"), 1.0, 0.4)
	if style == "lord":
		steel = cmat(Color("2c2a33"), 1.0, 0.4)
		gold = cmat(Color("8a3a1a"), 1.0, 0.4)
	var leather = cmat(Color("4a3528"), a)
	var cloth = cmat(accent, a)
	var bone = cmat(Color("c9bfa4"))
	var skin = cmat(Color("e0b594"))
	var black = cmat(Color("15131a"))
	# color principal del traje según la clase
	var main_c = Color("2a2733")
	if style == "knight":
		main_c = Color("7a1f26")
	elif style == "rogue":
		main_c = Color("2b2636")
	elif style == "mage":
		main_c = Color("2c3a8c")
	elif style == "shaman":
		main_c = Color("1f6a5c")
	elif style == "wraith":
		main_c = Color("9fd8c8")
	elif style == "skeleton":
		main_c = Color("5a1512")
	var mainm = cmat(main_c, a)
	var under = cmat(main_c.darkened(0.55), a)
	var armored = style == "knight" or style == "lord"
	var robed = style == "mage" or style == "shaman" or style == "wraith"

	# --- torso ---
	if style == "skeleton":
		cyl(body, 0.05, 0.05, 0.8, bone, Vector3(0, 1.3, 0), 6)
		for i in range(3):
			zcyl(body, 0.24 - i * 0.025, 0.24 - i * 0.025, 0.05, bone, Vector3(0, 1.52 - i * 0.14, 0.02), 0.7)
		box(body, Vector3(0.4, 0.14, 0.2), bone, Vector3(0, 0.86, 0))
		box(body, Vector3(0.72, 0.07, 0.1), bone, Vector3(0, 1.64, 0))
		tatter(body, 0.32, 0.4, mainm, Vector3(0, 0.86, 0.12))
		tatter(body, 0.5, 0.5, mainm, Vector3(0, 1.66, -0.1))
	elif armored:
		var chest = capsule(body, 0.27, 0.8, steel, Vector3(0, 1.36, 0))
		chest.scale = Vector3(1.3, 1.0, 0.9)
		zcyl(body, 0.36, 0.36, 0.06, gold, Vector3(0, 1.2, 0), 0.9)
		var gem = box(body, Vector3(0.16, 0.16, 0.05), gold, Vector3(0, 1.46, 0.25))
		gem.rotation.z = PI / 4.0
		sphere(body, 0.05, glow(accent.lightened(0.4), 2.5), Vector3(0, 1.46, 0.275), 8)
		cyl(body, 0.2, 0.31, 0.16, steel, Vector3(0, 1.72, 0))
		torus(body, 0.27, 0.33, gold, Vector3(0, 1.66, 0))
		zcyl(body, 0.34, 0.5, 0.44, steel, Vector3(0, 0.86, 0))
		zcyl(body, 0.5, 0.51, 0.06, gold, Vector3(0, 0.66, 0))
		zcyl(body, 0.36, 0.36, 0.1, leather, Vector3(0, 1.06, 0))
		box(body, Vector3(0.13, 0.13, 0.05), gold, Vector3(0, 1.06, 0.32))
		tatter(body, 0.3, 0.62, mainm if style == "knight" else cloth, Vector3(0, 1.02, 0.33))
		tatter(body, 0.34, 0.7, mainm if style == "knight" else cloth, Vector3(0, 1.02, -0.33))
		box(body, Vector3(0.16, 0.2, 0.12), leather, Vector3(0.3, 0.98, 0.14))
	elif robed:
		var chest2 = capsule(body, 0.27, 0.8, under, Vector3(0, 1.36, 0))
		chest2.scale = Vector3(1.25, 1.0, 0.86)
		if style == "wraith":
			cyl(body, 0.33, 0.06, 1.35, mainm, Vector3(0, 0.5, 0))
			tatter(body, 0.3, 0.5, mainm, Vector3(-0.2, 0.9, 0.2))
			tatter(body, 0.3, 0.6, mainm, Vector3(0.2, 0.9, -0.2))
		else:
			zcyl(body, 0.3, 0.5, 1.02, under, Vector3(0, 0.6, 0))
			# sobretúnica abierta por delante, con ribete dorado
			for k in [-1.0, 1.0]:
				var pan = tatter(body, 0.36, 0.86, mainm, Vector3(k * 0.26, 1.06, 0.2))
				pan.rotation.y = k * 0.5
				pan.rotation.x = -0.1
				box(pan, Vector3(0.05, 0.86, 0.035), gold, Vector3(-k * 0.16, -0.43, 0.005))
			var backp = tatter(body, 0.7, 0.95, mainm, Vector3(0, 1.06, -0.28))
			backp.rotation.x = 0.12
			zcyl(body, 0.5, 0.52, 0.07, gold, Vector3(0, 0.12, 0))
			zcyl(body, 0.345, 0.35, 0.12, leather, Vector3(0, 1.08, 0))
			box(body, Vector3(0.14, 0.14, 0.05), gold, Vector3(0, 1.08, 0.31))
			box(body, Vector3(0.2, 0.26, 0.1), leather, Vector3(-0.3, 0.94, 0.16))
			box(body, Vector3(0.08, 0.3, 0.03), gold, Vector3(0.14, 0.88, 0.33))
			# manto de hombros
			zcyl(body, 0.2, 0.5, 0.3, mainm, Vector3(0, 1.62, 0), 0.82)
			zcyl(body, 0.5, 0.51, 0.05, gold, Vector3(0, 1.47, 0), 0.82)
			var clasp = box(body, Vector3(0.13, 0.13, 0.05), gold, Vector3(0, 1.56, 0.36))
			clasp.rotation.z = PI / 4.0
			sphere(body, 0.045, glow(Color("7fe0ff") if style == "mage" else Color("7dffb0"), 3.0), Vector3(0, 1.56, 0.39), 8)
			if style == "shaman":
				for i in range(9):
					var fa = (i - 4) * 0.42
					var fe = cyl(body, 0.0, 0.07, 0.5, cloth if i % 2 == 0 else bone, Vector3(sin(fa) * 0.42, 1.68, -cos(fa) * 0.2 - 0.05), 5)
					fe.rotation.z = -sin(fa) * 0.9
					fe.rotation.x = -0.5
				for i in range(5):
					sphere(body, 0.05, bone, Vector3((i - 2) * 0.11, 1.42 - (2 - abs(i - 2)) * 0.04, 0.3), 6)
				sphere(body, 0.1, bone, Vector3(0.32, 0.9, 0.16), 8)
	else:
		var chest3 = capsule(body, 0.26, 0.8, mainm if style == "rogue" else leather, Vector3(0, 1.36, 0))
		chest3.scale = Vector3(1.2, 1.0, 0.84)
		zcyl(body, 0.29, 0.4, 0.38, mainm if style == "rogue" else leather, Vector3(0, 0.88, 0))
		zcyl(body, 0.335, 0.335, 0.09, black, Vector3(0, 1.06, 0))
		box(body, Vector3(0.12, 0.12, 0.05), gold, Vector3(0, 1.06, 0.3))
		if style == "smith":
			box(body, Vector3(0.44, 0.9, 0.04), cmat(Color("5a4030")), Vector3(0, 1.1, 0.27))
		else:
			for k in [-1.0, 1.0]:
				var strap = box(body, Vector3(0.07, 0.86, 0.04), leather, Vector3(0, 1.4, 0.245))
				strap.rotation.z = k * 0.65
			box(body, Vector3(0.1, 0.1, 0.05), gold, Vector3(0, 1.4, 0.27))
			box(body, Vector3(0.16, 0.2, 0.1), leather, Vector3(-0.28, 0.96, 0.15))
			box(body, Vector3(0.14, 0.18, 0.1), leather, Vector3(0.3, 0.96, 0.1))
			tatter(body, 0.26, 0.4, cloth, Vector3(0.12, 1.02, 0.3))
			# bufanda larga
			zcyl(body, 0.24, 0.29, 0.2, cloth, Vector3(0, 1.72, 0.02), 0.95)
			var tail = tatter(body, 0.22, 0.9, cloth, Vector3(-0.16, 1.74, -0.26))
			tail.rotation.x = 0.35
			tail.rotation.z = 0.15

	# --- cabeza (algo más grande, estilo ilustración) ---
	var hd = pivot(body, Vector3(0, 1.74, 0))
	hd.scale = Vector3.ONE * 1.28
	if armored:
		sphere(hd, 0.285, steel, Vector3(0, 0.25, 0))
		box(hd, Vector3(0.34, 0.07, 0.08), black, Vector3(0, 0.27, 0.25))
		var eg = glow(Color("ff5a1e") if style == "lord" else accent.lightened(0.55), 5.0)
		sphere(hd, 0.035, eg, Vector3(-0.085, 0.27, 0.275), 6)
		sphere(hd, 0.035, eg, Vector3(0.085, 0.27, 0.275), 6)
		box(hd, Vector3(0.05, 0.3, 0.08), gold, Vector3(0, 0.2, 0.27))
		torus(hd, 0.255, 0.3, gold, Vector3(0, 0.36, 0))
		cyl(hd, 0.2, 0.26, 0.18, steel, Vector3(0, 0.06, 0.02))
		if style == "knight":
			box(hd, Vector3(0.05, 0.1, 0.5), gold, Vector3(0, 0.54, -0.02))
			var pl = tatter(hd, 0.5, 0.3, cloth, Vector3(0, 0.74, -0.12))
			pl.rotation.y = PI / 2.0
			pl.rotation.z = 0.5
		else:
			horn(hd, bone, Vector3(-0.3, 0.44, 0), -1.0, 0.9)
			horn(hd, bone, Vector3(0.3, 0.44, 0), 1.0, 0.9)
			for i in range(5):
				var an = (i - 2) * 0.5
				cyl(hd, 0.0, 0.04, 0.24, gold, Vector3(sin(an) * 0.2, 0.6, cos(an) * 0.12), 4)
	elif style == "skeleton":
		var skull = sphere(hd, 0.23, bone, Vector3(0, 0.24, 0))
		skull.scale = Vector3(1.0, 1.05, 1.08)
		box(hd, Vector3(0.24, 0.1, 0.2), bone, Vector3(0, 0.03, 0.05))
		sphere(hd, 0.065, black, Vector3(-0.09, 0.26, 0.2), 6)
		sphere(hd, 0.065, black, Vector3(0.09, 0.26, 0.2), 6)
		var red = glow(Color("ff3a2a"), 4.0)
		sphere(hd, 0.025, red, Vector3(-0.09, 0.26, 0.245), 4)
		sphere(hd, 0.025, red, Vector3(0.09, 0.26, 0.245), 4)
		var cap = sphere(hd, 0.25, cmat(Color("5a4a3c"), 1.0, 0.4), Vector3(0, 0.33, -0.02))
		cap.scale = Vector3(1.0, 0.6, 1.05)
	elif style == "wraith":
		var hoodw = sphere(hd, 0.3, mainm, Vector3(0, 0.26, -0.03))
		hoodw.scale = Vector3(1.0, 1.1, 1.05)
		sphere(hd, 0.2, black, Vector3(0, 0.23, 0.1))
		var eyes = glow(Color("7ffff0"), 6.0)
		sphere(hd, 0.035, eyes, Vector3(-0.08, 0.25, 0.27), 6)
		sphere(hd, 0.035, eyes, Vector3(0.08, 0.25, 0.27), 6)
	elif style == "shaman":
		var hs = sphere(hd, 0.29, mainm, Vector3(0, 0.28, -0.07))
		hs.scale = Vector3(1.0, 1.0, 1.05)
		var mask = sphere(hd, 0.22, bone, Vector3(0, 0.23, 0.1))
		mask.scale = Vector3(0.95, 1.15, 0.8)
		sphere(hd, 0.06, black, Vector3(-0.09, 0.26, 0.24), 6)
		sphere(hd, 0.06, black, Vector3(0.09, 0.26, 0.24), 6)
		var ge = glow(Color("6affb0"), 4.0)
		sphere(hd, 0.024, ge, Vector3(-0.09, 0.26, 0.285), 4)
		sphere(hd, 0.024, ge, Vector3(0.09, 0.26, 0.285), 4)
		box(hd, Vector3(0.03, 0.16, 0.02), cmat(Color("a8261f")), Vector3(-0.09, 0.14, 0.26))
		box(hd, Vector3(0.03, 0.16, 0.02), cmat(Color("a8261f")), Vector3(0.09, 0.14, 0.26))
		horn(hd, bone, Vector3(-0.24, 0.46, 0), -1.0, 0.7)
		horn(hd, bone, Vector3(0.24, 0.46, 0), 1.0, 0.7)
		torus(hd, 0.25, 0.3, gold, Vector3(0, 0.4, -0.04))
	elif style == "mage":
		var hm = sphere(hd, 0.31, mainm, Vector3(0, 0.28, -0.05))
		hm.scale = Vector3(1.0, 1.08, 1.1)
		var tipm = cyl(hd, 0.0, 0.22, 0.5, mainm, Vector3(0, 0.56, -0.24), 8)
		tipm.rotation.x = -1.0
		sphere(hd, 0.215, black, Vector3(0, 0.24, 0.1))
		var rim = torus(hd, 0.2, 0.245, gold, Vector3(0, 0.24, 0.2))
		rim.rotation.x = PI / 2.0
		var me = glow(Color("7fe0ff"), 6.0)
		var e1 = sphere(hd, 0.045, me, Vector3(-0.085, 0.26, 0.3), 6)
		e1.scale = Vector3(1.0, 0.6, 0.5)
		var e2 = sphere(hd, 0.045, me, Vector3(0.085, 0.26, 0.3), 6)
		e2.scale = Vector3(1.0, 0.6, 0.5)
		var gemh = box(hd, Vector3(0.09, 0.09, 0.04), gold, Vector3(0, 0.5, 0.26))
		gemh.rotation.z = PI / 4.0
	else:
		sphere(hd, 0.24, skin, Vector3(0, 0.24, 0))
		var eyec = black
		if style == "rogue":
			eyec = glow(Color("ff4a5a"), 2.5)
		sphere(hd, 0.036, eyec, Vector3(-0.09, 0.26, 0.215), 6)
		sphere(hd, 0.036, eyec, Vector3(0.09, 0.26, 0.215), 6)
		if style == "smith":
			box(hd, Vector3(0.3, 0.2, 0.14), cmat(Color("2a2420")), Vector3(0, 0.1, 0.14))
		else:
			var hood = sphere(hd, 0.29, mainm, Vector3(0, 0.29, -0.06))
			hood.scale = Vector3(1.0, 1.0, 1.08)
			var tipc = cyl(hd, 0.0, 0.2, 0.46, mainm, Vector3(0, 0.52, -0.2), 8)
			tipc.rotation.x = -0.9
			box(hd, Vector3(0.36, 0.17, 0.12), black, Vector3(0, 0.15, 0.17))
			var hr = torus(hd, 0.22, 0.255, gold, Vector3(0, 0.3, 0.14))
			hr.rotation.x = PI / 2.0 - 0.25
			hr.scale = Vector3(1.0, 0.4, 1.0)

	# --- brazos ---
	var arm_l = pivot(body, Vector3(-0.45, 1.62, 0))
	var arm_r = pivot(body, Vector3(0.45, 1.62, 0))
	var side = -1.0
	for arm in [arm_l, arm_r]:
		if style == "skeleton":
			capsule(arm, 0.045, 0.7, bone, Vector3(0, -0.33, 0))
			sphere(arm, 0.08, bone, Vector3(0, -0.7, 0), 6)
		elif armored:
			capsule(arm, 0.1, 0.72, steel, Vector3(0, -0.33, 0))
			cyl(arm, 0.12, 0.15, 0.28, steel, Vector3(0, -0.5, 0))
			cyl(arm, 0.155, 0.155, 0.05, gold, Vector3(0, -0.38, 0))
			sphere(arm, 0.12, steel, Vector3(0, -0.72, 0), 8)
			var big = 0.22 if style == "knight" else 0.27
			var pad = sphere(arm, big, steel, Vector3(side * 0.04, 0.05, 0), 10)
			pad.scale = Vector3(1.2, 0.8, 1.2)
			var pad2 = sphere(arm, big * 0.8, steel, Vector3(side * 0.1, -0.1, 0), 10)
			pad2.scale = Vector3(1.1, 0.7, 1.1)
			var prim = torus(arm, big * 0.95, big * 1.15, gold, Vector3(side * 0.04, 0.0, 0))
			prim.scale = Vector3(1.0, 0.8, 1.0)
			var spike = cyl(arm, 0.0, 0.06, 0.28 if style == "knight" else 0.5, gold if style == "knight" else bone, Vector3(side * 0.16, 0.22, 0), 5)
			spike.rotation.z = -side * 0.6
		elif robed:
			capsule(arm, 0.09, 0.6, mainm, Vector3(0, -0.28, 0))
			cyl(arm, 0.1, 0.22, 0.36, mainm, Vector3(0, -0.5, 0))
			cyl(arm, 0.222, 0.228, 0.05, gold, Vector3(0, -0.67, 0))
			sphere(arm, 0.11, bone if style == "wraith" else (black if style == "mage" else skin), Vector3(0, -0.74, 0), 8)
		else:
			capsule(arm, 0.095, 0.72, skin if style == "smith" else mainm, Vector3(0, -0.33, 0))
			cyl(arm, 0.11, 0.125, 0.24, leather, Vector3(0, -0.5, 0))
			cyl(arm, 0.128, 0.128, 0.04, gold, Vector3(0, -0.4, 0))
			sphere(arm, 0.11, black if style == "rogue" else skin, Vector3(0, -0.72, 0), 8)
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
				var lm = steel if armored else black
				capsule(leg, 0.11, 0.66, lm, Vector3(0, -0.32, 0))
				cyl(leg, 0.15, 0.13, 0.26, steel if armored else leather, Vector3(0, -0.5, 0))
				cyl(leg, 0.155, 0.155, 0.045, gold, Vector3(0, -0.38, 0))
				box(leg, Vector3(0.22, 0.14, 0.38), steel if armored else leather, Vector3(0, -0.63, 0.06))
				if armored:
					sphere(leg, 0.1, gold, Vector3(0, -0.26, 0.09), 8)

	# --- capa ---
	if o.has("cape"):
		var q = QuadMesh.new()
		q.size = Vector2(0.86, 1.3)
		q.subdivide_width = 4
		q.subdivide_depth = 8
		var cape = _add(body, q, Sh.mat(Sh.CAPE, {"tint": o["cape"], "ember": 1.0 if style == "lord" else 0.0}), Vector3(0, 1.06, -0.3))
		cape.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# --- accesorio flotante ---
	if style == "mage":
		var tome = pivot(body, Vector3(-0.78, 1.3, 0.34))
		tome.rotation = Vector3(-0.5, 0.5, 0.15)
		box(tome, Vector3(0.34, 0.06, 0.26), cmat(Color("3a1f5a")), Vector3(0, 0, 0))
		box(tome, Vector3(0.3, 0.05, 0.22), bone, Vector3(0, 0.04, 0))
		box(tome, Vector3(0.36, 0.02, 0.03), gold, Vector3(0, -0.02, 0.13))
		sphere(tome, 0.05, glow(Color("7fe0ff"), 4.0), Vector3(0, 0.12, 0), 6)
	elif style == "shaman":
		var sp = pivot(body, Vector3(-0.8, 1.5, 0.3))
		var ss = sphere(sp, 0.13, cmat(Color("7dffb0"), 0.55), Vector3.ZERO, 8)
		ss.scale = Vector3(1.0, 1.1, 1.0)
		sphere(sp, 0.03, glow(Color("eafff2"), 5.0), Vector3(-0.05, 0.02, 0.11), 4)
		sphere(sp, 0.03, glow(Color("eafff2"), 5.0), Vector3(0.05, 0.02, 0.11), 4)
		cyl(sp, 0.1, 0.0, 0.3, cmat(Color("7dffb0"), 0.55), Vector3(0, -0.24, -0.04), 6)

	# --- arma ---
	var blade = null
	var weapon: String = o.get("weapon", "")
	if style == "wraith":
		weapon = "scythe"
	if weapon != "":
		var w = pivot(arm_r, Vector3(0, -0.72, 0))
		w.rotation.x = PI / 2.0
		blade = StandardMaterial3D.new()
		blade.albedo_color = Color("cfd6e2")
		blade.metallic = 0.5
		blade.roughness = 0.35
		blade.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		blade.emission_enabled = true
		blade.emission = accent.lightened(0.4)
		blade.emission_energy_multiplier = 0.0
		blade.next_pass = _outline
		if style == "skeleton":
			blade.albedo_color = Color("7a5a40")
			blade.roughness = 0.9
		if style == "lord":
			blade.albedo_color = Color("2a1a14")
			blade.emission = Color("ff5a1e")
			blade.emission_energy_multiplier = 2.5
		if weapon == "sword":
			var bg = 1.0
			if armored:
				bg = 1.3
			box(w, Vector3(0.12 * bg, 1.25 * bg, 0.04), blade, Vector3(0, 0.2 + 0.625 * bg, 0))
			var tip = cyl(w, 0.0, 0.085 * bg, 0.26, blade, Vector3(0, 0.33 + 1.25 * bg, 0), 4)
			tip.scale.z = 0.35
			tip.rotation.y = PI / 4.0
			box(w, Vector3(0.5 * bg, 0.08, 0.1), gold, Vector3(0, 0.16, 0))
			for k in [-1.0, 1.0]:
				cyl(w, 0.0, 0.05, 0.16, gold, Vector3(k * 0.25 * bg, 0.25, 0), 4)
			cyl(w, 0.04, 0.04, 0.34, leather, Vector3(0, -0.02, 0), 8)
			sphere(w, 0.075, gold, Vector3(0, -0.2, 0), 8)
			sphere(w, 0.045, glow(accent.lightened(0.4), 2.5), Vector3(0, 0.16, 0.05), 6)
		elif weapon == "dagger":
			for hand in [w, pivot(arm_l, Vector3(0, -0.72, 0))]:
				hand.rotation.x = PI / 2.0
				box(hand, Vector3(0.08, 0.5, 0.03), blade, Vector3(0, 0.4, 0))
				var dt = cyl(hand, 0.0, 0.057, 0.2, blade, Vector3(0, 0.75, 0), 4)
				dt.scale.z = 0.4
				dt.rotation.y = PI / 4.0
				box(hand, Vector3(0.22, 0.05, 0.07), gold, Vector3(0, 0.13, 0))
				cyl(hand, 0.03, 0.03, 0.2, leather, Vector3(0, 0.02, 0), 6)
		elif weapon == "scythe":
			cyl(w, 0.035, 0.04, 2.1, black, Vector3(0, 0.5, 0), 6)
			blade.albedo_color = Color("9fd8c8")
			blade.emission = Color("7ffff0")
			blade.emission_energy_multiplier = 1.2
			var sb = box(w, Vector3(0.7, 0.12, 0.03), blade, Vector3(0.3, 1.5, 0))
			sb.rotation.z = -0.35
		else:
			cyl(w, 0.04, 0.05, 2.1, cmat(Color("2e2219")), Vector3(0, 0.5, 0), 8)
			cyl(w, 0.06, 0.06, 0.06, gold, Vector3(0, 1.3, 0), 8)
			cyl(w, 0.06, 0.06, 0.06, gold, Vector3(0, 0.1, 0), 8)
			if style == "shaman":
				var sk = sphere(w, 0.17, bone, Vector3(0, 1.66, 0), 10)
				sk.scale = Vector3(1.0, 1.1, 1.0)
				sphere(w, 0.05, glow(Color("6affb0"), 4.0), Vector3(0.06, 1.68, 0.13), 6)
				sphere(w, 0.05, glow(Color("6affb0"), 4.0), Vector3(-0.06, 1.68, 0.13), 6)
				horn(w, bone, Vector3(-0.14, 1.78, 0), -1.0, 0.45)
				horn(w, bone, Vector3(0.14, 1.78, 0), 1.0, 0.45)
				blade.albedo_color = Color("6affb0")
				blade.emission = Color("6affb0")
				tatter(w, 0.12, 0.3, cloth, Vector3(0.1, 1.45, 0))
				tatter(w, 0.1, 0.4, cmat(Color("a8261f")), Vector3(-0.1, 1.45, 0))
				sphere(w, 0.06, blade, Vector3(0, 1.3, 0.08), 6)
			else:
				blade.albedo_color = Color("9fe8ff")
				blade.emission = Color("7fe0ff")
				blade.emission_energy_multiplier = 2.0
				var orb = sphere(w, 0.15, blade, Vector3(0, 1.84, 0), 10)
				orb.scale = Vector3(0.8, 1.3, 0.8)
				var cres = torus(w, 0.2, 0.26, gold, Vector3(0, 1.8, 0))
				cres.rotation.x = PI / 2.0
				cyl(w, 0.0, 0.05, 0.3, gold, Vector3(0, 2.2, 0), 4)
				for k in [-1.0, 1.0]:
					var wing = cyl(w, 0.0, 0.05, 0.36, gold, Vector3(k * 0.3, 1.86, 0), 4)
					wing.rotation.z = -k * 1.0
				var ban = tatter(w, 0.34, 0.6, cloth, Vector3(0.2, 1.52, 0))
				box(ban, Vector3(0.34, 0.04, 0.04), gold, Vector3(0, 0, 0))
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
	var m = cmat(col)
	var d = cmat(col.darkened(0.5))
	var bone = cmat(Color("e2d8bc"))
	var black = cmat(Color("15131a"))
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
		box(root, Vector3(0.74, 0.1, 0.6), cmat(Color("7a1f26")), Vector3(0, 1.14, 0))
		box(root, Vector3(0.7, 0.5, 0.04), cmat(Color("7a1f26")), Vector3(0, 0.9, -0.3))
		var cham = box(root, Vector3(0.2, 0.06, 0.5), cmat(Color("8a93a3"), 1.0, 0.4), Vector3(0, 1.62, 1.12))
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
