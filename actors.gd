extends RefCounted
# Personas y vehículos generados por código.

const MB = preload("res://mb.gd")

const SKINS := [Color(0.98, 0.84, 0.72), Color(0.93, 0.74, 0.58), Color(0.78, 0.58, 0.42), Color(0.55, 0.38, 0.27), Color(0.4, 0.27, 0.2)]
const HAIRS := [Color(0.12, 0.09, 0.07), Color(0.32, 0.2, 0.1), Color(0.6, 0.42, 0.2), Color(0.85, 0.72, 0.4), Color(0.55, 0.15, 0.1), Color(0.75, 0.75, 0.78)]
const SHIRTS := [Color(0.85, 0.25, 0.25), Color(0.2, 0.5, 0.85), Color(0.95, 0.8, 0.25), Color(0.3, 0.7, 0.45), Color(0.95, 0.95, 0.95), Color(0.6, 0.35, 0.75), Color(0.95, 0.55, 0.2), Color(0.25, 0.3, 0.4), Color(0.95, 0.55, 0.7), Color(0.2, 0.65, 0.7)]
const PANTS := [Color(0.2, 0.25, 0.4), Color(0.15, 0.15, 0.18), Color(0.45, 0.38, 0.3), Color(0.3, 0.4, 0.6), Color(0.6, 0.6, 0.62), Color(0.35, 0.2, 0.2)]
const CAR_COLS := [Color(0.8, 0.15, 0.15), Color(0.15, 0.35, 0.75), Color(0.92, 0.92, 0.94), Color(0.15, 0.16, 0.18), Color(0.55, 0.58, 0.62), Color(0.2, 0.55, 0.35), Color(0.95, 0.6, 0.15), Color(0.5, 0.75, 0.9)]


static func person(mat: Material, skin: Color, shirt: Color, pants: Color, hair: Color, female: bool) -> Node3D:
	var root := Node3D.new()
	var style := int(hair.r * 97.0 + shirt.g * 31.0 + pants.b * 13.0) % 3
	var b = MB.new()
	b.m = 0.9
	# cadera, torso y hombros (torso aplanado de delante a atrás)
	b.sphere(Vector3(0, 0.88, 0), Vector3(0.2, 0.14, 0.15), pants, 12, 6)
	b.push_t(Transform3D(Basis().scaled(Vector3(1.0, 1.0, 0.72)), Vector3.ZERO))
	b.cyl(Vector3(0, 0.9, 0), 0.185, 0.235, 0.5, shirt, 14, false)
	b.pop()
	b.sphere(Vector3(0, 1.4, 0), Vector3(0.245, 0.1, 0.155), shirt, 14, 6)
	if female and style != 1:
		b.cyl(Vector3(0, 0.6, 0), 0.27, 0.19, 0.32, shirt.darkened(0.2), 14, false)
	b.cyl(Vector3(0, 1.44, 0), 0.062, 0.058, 0.1, skin, 10, false)
	b.cyl(Vector3(0, 1.44, 0), 0.085, 0.075, 0.035, shirt.lightened(0.25), 10, false)
	# cabeza
	b.sphere(Vector3(0, 1.67, 0), Vector3(0.18, 0.2, 0.185), skin, 16, 10)
	for sx in [-1.0, 1.0]:
		b.sphere(Vector3(sx * 0.178, 1.66, 0.0), Vector3(0.03, 0.045, 0.035), skin.darkened(0.06), 6, 4)
		b.sphere(Vector3(sx * 0.068, 1.69, 0.158), Vector3(0.04, 0.047, 0.02), Color(0.97, 0.97, 0.97), 8, 6)
		b.sphere(Vector3(sx * 0.068, 1.688, 0.172), Vector3(0.021, 0.027, 0.012), Color(0.12, 0.2, 0.3) if style == 0 else Color(0.2, 0.12, 0.06), 8, 6)
		b.box(Vector3(sx * 0.068, 1.745, 0.165), Vector3(0.07, 0.014, 0.015), hair.darkened(0.2))
	b.sphere(Vector3(0, 1.645, 0.185), Vector3(0.024, 0.03, 0.03), skin.darkened(0.05), 6, 4)
	b.box(Vector3(0, 1.585, 0.168), Vector3(0.075, 0.016, 0.02), Color(0.7, 0.28, 0.28))
	# pelo
	b.sphere(Vector3(0, 1.735, -0.03), Vector3(0.195, 0.165, 0.2), hair, 14, 7)
	b.sphere(Vector3(0, 1.82, 0.09), Vector3(0.15, 0.055, 0.09), hair.lightened(0.05), 10, 5)
	if female:
		if style == 2:
			b.sphere(Vector3(0, 1.9, -0.1), Vector3(0.085, 0.085, 0.085), hair, 8, 6)
		else:
			b.sphere(Vector3(0, 1.52, -0.11), Vector3(0.175, 0.27, 0.1), hair, 12, 7)
			for sx in [-1.0, 1.0]:
				b.sphere(Vector3(sx * 0.16, 1.58, -0.02), Vector3(0.05, 0.17, 0.09), hair, 8, 5)
	elif style == 1:
		b.sphere(Vector3(0, 1.84, -0.01), Vector3(0.13, 0.07, 0.15), hair.lightened(0.08), 10, 5)
	b.instance(root, mat)
	var limbs: Array = []
	for s in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(0.1 * s, 0.86, 0)
		root.add_child(leg)
		var lb = MB.new()
		lb.m = 0.9
		var bare := female and style != 1
		lb.cyl(Vector3(0, -0.42, 0), 0.085, 0.105, 0.42, skin if bare else pants, 10, false)
		lb.cyl(Vector3(0, -0.8, 0), 0.07, 0.085, 0.38, skin if bare else pants, 10, false)
		lb.sphere(Vector3(0, -0.8, 0.045), Vector3(0.078, 0.062, 0.15), Color(0.92, 0.92, 0.9) if style == 2 else Color(0.16, 0.13, 0.12), 10, 6)
		lb.box(Vector3(0, -0.865, 0.045), Vector3(0.14, 0.025, 0.28), Color(0.85, 0.85, 0.82))
		lb.instance(leg, mat)
		limbs.append(leg)
	for s in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(0.29 * s, 1.4, 0)
		arm.rotation.z = 0.07 * s
		root.add_child(arm)
		var ab = MB.new()
		ab.m = 0.9
		ab.sphere(Vector3(0, -0.01, 0), Vector3(0.082, 0.082, 0.082), shirt, 10, 6)
		ab.cyl(Vector3(0, -0.27, 0), 0.062, 0.078, 0.27, shirt if style != 0 else skin, 10, false)
		if style == 0:
			ab.cyl(Vector3(0, -0.14, 0), 0.076, 0.08, 0.14, shirt, 10, false)
		ab.cyl(Vector3(0, -0.55, 0), 0.05, 0.06, 0.29, skin, 10, false)
		ab.sphere(Vector3(0, -0.6, 0.005), Vector3(0.058, 0.075, 0.055), skin, 8, 6)
		ab.instance(arm, mat)
		limbs.append(arm)
	root.set_meta("limbs", limbs)
	return root


static func random_person(mat: Material, rng: RandomNumberGenerator) -> Node3D:
	return person(mat, SKINS[rng.randi() % SKINS.size()], SHIRTS[rng.randi() % SHIRTS.size()], PANTS[rng.randi() % PANTS.size()], HAIRS[rng.randi() % HAIRS.size()], rng.randf() < 0.5)


static func animate(root: Node3D, phase: float, amt: float) -> void:
	var limbs: Array = root.get_meta("limbs")
	var s := sin(phase) * amt
	limbs[0].rotation.x = s * 0.75
	limbs[1].rotation.x = -s * 0.75
	limbs[2].rotation.x = -s * 0.55
	limbs[3].rotation.x = s * 0.55


static func plumbob() -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.emission_enabled = true
	m.emission = Color(0.2, 1.0, 0.35)
	m.emission_energy_multiplier = 1.2
	m.roughness = 0.2
	var b = MB.new()
	var g := Color(0.3, 0.95, 0.4)
	b.cyl(Vector3(0, 0.2, 0), 0.13, 0.0, 0.2, g, 6, false)
	b.push_t(Transform3D(Basis(Vector3(1, 0, 0), PI), Vector3(0, 0.2, 0)))
	b.cyl(Vector3.ZERO, 0.13, 0.0, 0.2, g, 6, false)
	b.pop()
	var mi := MeshInstance3D.new()
	mi.mesh = b.build(m)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _wheel(b, x: float, z: float, r: float, side: float) -> void:
	# side = +1 rueda derecha (tapa hacia +x), -1 izquierda
	var rot := -PI / 2.0 if side > 0.0 else PI / 2.0
	b.push_t(Transform3D(Basis(Vector3(0, 0, 1), rot), Vector3(x - side * 0.26, r, z)))
	var pm: float = b.m
	b.m = 1.0
	b.cyl(Vector3.ZERO, r, r, 0.26, Color(0.07, 0.07, 0.08), 14)
	b.m = 0.8
	b.cyl(Vector3(0, 0.26, 0), r * 0.6, r * 0.5, 0.025, Color(0.75, 0.77, 0.8), 10)
	b.pop()
	b.m = pm


# kind: 0 coche, 1 taxi, 2 autobús, 3 policía. El frente mira a +z.
static func car(mat: Material, glow: Material, col: Color, kind: int) -> Node3D:
	var root := Node3D.new()
	var b = MB.new()
	var g = MB.new()
	var glass := Color(0.05, 0.08, 0.12)
	b.m = 0.8
	if kind == 2:
		var bl := 9.0
		var bw := 2.4
		b.box(Vector3(0, 0.35, 0), Vector3(bw, 2.5, bl), col, true)
		b.box(Vector3(0, 2.85, 0), Vector3(bw - 0.2, 0.12, bl - 0.4), Color(0.9, 0.9, 0.9))
		for s in [-1.0, 1.0]:
			b.box(Vector3(s * (bw * 0.5 + 0.01), 1.5, -0.2), Vector3(0.04, 0.9, bl - 1.6), glass)
			for z in [-3.0, 3.0]:
				_wheel(b, s * bw * 0.5, z, 0.45, s)
		b.box(Vector3(0, 1.4, bl * 0.5 + 0.01), Vector3(bw - 0.3, 1.1, 0.04), glass)
		b.box(Vector3(0, 1.5, -bl * 0.5 - 0.01), Vector3(bw - 0.5, 0.8, 0.04), glass)
		b.box(Vector3(-0.8, 0.6, -bl * 0.5 - 0.02), Vector3(0.3, 0.2, 0.04), Color(0.85, 0.1, 0.1))
		b.box(Vector3(0.8, 0.6, -bl * 0.5 - 0.02), Vector3(0.3, 0.2, 0.04), Color(0.85, 0.1, 0.1))
		g.box(Vector3(-0.8, 0.6, bl * 0.5 + 0.02), Vector3(0.35, 0.22, 0.05), Color.WHITE)
		g.box(Vector3(0.8, 0.6, bl * 0.5 + 0.02), Vector3(0.35, 0.22, 0.05), Color.WHITE)
	else:
		var w := 1.84
		var hw := w * 0.5
		# perfil lateral (z, y), de atrás hacia delante pasando por el techo
		var prof: Array[Vector2] = [Vector2(-2.12, 0.3), Vector2(-2.15, 0.62), Vector2(-2.02, 0.86), Vector2(-1.42, 0.92), Vector2(-0.98, 1.36), Vector2(0.28, 1.38), Vector2(0.92, 0.96), Vector2(1.86, 0.84), Vector2(2.12, 0.66), Vector2(2.14, 0.3)]
		var n := prof.size()
		var wd: Array[float] = []
		for i in n:
			wd.append(hw - 0.15 if (i == 4 or i == 5) else hw)
		for i in n:
			var j := (i + 1) % n
			var p0 := prof[i]
			var p1 := prof[j]
			var e := p1 - p0
			var nn := Vector3(0, e.x, -e.y).normalized()
			var cc := col
			if i == 3 or i == 5:
				cc = glass
			elif i == n - 1:
				cc = Color(0.07, 0.07, 0.08)
			b.quad(Vector3(-wd[i], p0.y, p0.x), Vector3(wd[i], p0.y, p0.x), Vector3(wd[j], p1.y, p1.x), Vector3(-wd[j], p1.y, p1.x), nn, cc)
		for sx in [-1.0, 1.0]:
			var sn := Vector3(sx, 0, 0)
			var cen := Vector3(sx * hw, 0.62, 0.0)
			for i in n:
				var j := (i + 1) % n
				b.tri(cen, Vector3(sx * wd[i], prof[i].y, prof[i].x), Vector3(sx * wd[j], prof[j].y, prof[j].x), sn, sn, sn, col)
			# ventanillas
			var xl: float = sx * (hw - 0.012)
			var xh: float = sx * (hw - 0.118)
			b.quad(Vector3(xl, 0.98, -0.92), Vector3(xl, 0.98, -0.2), Vector3(xh, 1.3, -0.2), Vector3(xh, 1.3, -0.74), sn, glass)
			b.quad(Vector3(xl, 0.98, -0.1), Vector3(xl, 0.98, 0.76), Vector3(xh, 1.3, 0.3), Vector3(xh, 1.3, -0.1), sn, glass)
			b.box(Vector3(sx * (hw + 0.09), 0.98, 0.66), Vector3(0.16, 0.1, 0.09), col)
			b.box(Vector3(sx * hw, 0.72, -0.5), Vector3(0.03, 0.03, 0.14), Color(0.75, 0.77, 0.8))
			b.box(Vector3(sx * hw, 0.72, 0.36), Vector3(0.03, 0.03, 0.14), Color(0.75, 0.77, 0.8))
			_wheel(b, sx * hw, 1.32, 0.34, sx)
			_wheel(b, sx * hw, -1.32, 0.34, sx)
			b.m = 1.0
			b.box(Vector3(sx * 0.62, 0.62, -2.15), Vector3(0.38, 0.13, 0.05), Color(0.85, 0.08, 0.08))
			b.m = 0.8
			g.box(Vector3(sx * 0.62, 0.6, 2.11), Vector3(0.4, 0.14, 0.07), Color.WHITE)
		b.m = 1.0
		b.box(Vector3(0, 0.26, 2.12), Vector3(w - 0.04, 0.22, 0.14), Color(0.12, 0.12, 0.14))
		b.box(Vector3(0, 0.26, -2.13), Vector3(w - 0.04, 0.22, 0.14), Color(0.12, 0.12, 0.14))
		b.box(Vector3(0, 0.5, 2.14), Vector3(0.8, 0.12, 0.04), Color(0.05, 0.05, 0.06))
		b.box(Vector3(0, 0.46, -2.16), Vector3(0.5, 0.12, 0.03), Color(0.92, 0.92, 0.9))
		b.m = 0.8
		if kind == 1:
			b.box(Vector3(0, 1.38, -0.35), Vector3(0.6, 0.18, 0.25), Color(0.1, 0.1, 0.1))
		if kind == 3:
			for sx in [-1.0, 1.0]:
				b.box(Vector3(sx * (hw + 0.005), 0.42, -0.2), Vector3(0.03, 0.32, 1.9), Color(0.06, 0.07, 0.1))
			b.box(Vector3(0, 1.38, -0.35), Vector3(1.3, 0.08, 0.34), Color(0.1, 0.1, 0.12))
	b.instance(root, mat)
	g.instance(root, glow, false)
	if kind == 3:
		var bar: Array = []
		for sx in [-1.0, 1.0]:
			var lm := StandardMaterial3D.new()
			lm.albedo_color = Color(1.0, 0.1, 0.1) if sx < 0.0 else Color(0.1, 0.3, 1.0)
			lm.emission_enabled = true
			lm.emission = lm.albedo_color
			lm.emission_energy_multiplier = 3.0
			var bx := BoxMesh.new()
			bx.size = Vector3(0.52, 0.17, 0.28)
			bx.material = lm
			var li := MeshInstance3D.new()
			li.mesh = bx
			li.position = Vector3(sx * 0.32, 1.54, -0.35)
			li.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(li)
			bar.append(li)
		root.set_meta("bar", bar)
	return root
