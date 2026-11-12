extends RefCounted
# Constructor de mallas: junta muchas piezas (cajas, cilindros, esferas...) en una
# sola malla con color por vértice, para que la ciudad se dibuje con pocas llamadas.

var v := PackedVector3Array()
var n := PackedVector3Array()
var c := PackedColorArray()
var xf := Transform3D.IDENTITY
var m := 1.0  # tipo de superficie (va en el alfa del color)
var _stack: Array = []


func push(p: Vector3, rot: float = 0.0) -> void:
	_stack.append(xf)
	xf = xf * Transform3D(Basis(Vector3.UP, rot), p)


func push_t(t: Transform3D) -> void:
	_stack.append(xf)
	xf = xf * t


func pop() -> void:
	xf = _stack.pop_back()


func tri(a: Vector3, b: Vector3, d: Vector3, na: Vector3, nb: Vector3, nd: Vector3, col: Color) -> void:
	a = xf * a
	b = xf * b
	d = xf * d
	na = xf.basis * na
	nb = xf.basis * nb
	nd = xf.basis * nd
	var g := (b - a).cross(d - a)
	if g.dot(na + nb + nd) > 0.0:
		var t := b
		b = d
		d = t
		var tn := nb
		nb = nd
		nd = tn
	col.a = m
	v.append(a)
	v.append(b)
	v.append(d)
	n.append(na)
	n.append(nb)
	n.append(nd)
	c.append(col)
	c.append(col)
	c.append(col)


func quad(a: Vector3, b: Vector3, d: Vector3, e: Vector3, nn: Vector3, col: Color) -> void:
	tri(a, b, d, nn, nn, nn, col)
	tri(a, d, e, nn, nn, nn, col)


# Caja apoyada en p (p = centro de la base).
func box(p: Vector3, s: Vector3, col: Color, bottom: bool = false) -> void:
	var x0 := p.x - s.x * 0.5
	var x1 := p.x + s.x * 0.5
	var y0 := p.y
	var y1 := p.y + s.y
	var z0 := p.z - s.z * 0.5
	var z1 := p.z + s.z * 0.5
	quad(Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3(0, 0, 1), col)
	quad(Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(0, 0, -1), col)
	quad(Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(1, 0, 0), col)
	quad(Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), Vector3(-1, 0, 0), col)
	quad(Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x0, y1, z0), Vector3(0, 1, 0), col)
	if bottom:
		quad(Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1), Vector3(0, -1, 0), col)


# Rectángulo plano mirando hacia arriba.
func flat(p: Vector3, sx: float, sz: float, col: Color) -> void:
	var hx := sx * 0.5
	var hz := sz * 0.5
	quad(Vector3(p.x - hx, p.y, p.z + hz), Vector3(p.x + hx, p.y, p.z + hz), Vector3(p.x + hx, p.y, p.z - hz), Vector3(p.x - hx, p.y, p.z - hz), Vector3(0, 1, 0), col)


# Tejado a dos aguas, cumbrera a lo largo de X. p = centro de la base.
func prism(p: Vector3, s: Vector3, col: Color, gable: Color) -> void:
	var x0 := p.x - s.x * 0.5
	var x1 := p.x + s.x * 0.5
	var z0 := p.z - s.z * 0.5
	var z1 := p.z + s.z * 0.5
	var y0 := p.y
	var y1 := p.y + s.y
	var a := Vector3(x0, y0, z0)
	var b := Vector3(x1, y0, z0)
	var d := Vector3(x1, y0, z1)
	var e := Vector3(x0, y0, z1)
	var r0 := Vector3(x0, y1, p.z)
	var r1 := Vector3(x1, y1, p.z)
	quad(e, d, r1, r0, Vector3(0, s.z * 0.5, s.y).normalized(), col)
	quad(b, a, r0, r1, Vector3(0, s.z * 0.5, -s.y).normalized(), col)
	tri(a, e, r0, Vector3(-1, 0, 0), Vector3(-1, 0, 0), Vector3(-1, 0, 0), gable)
	tri(d, b, r1, Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 0), gable)


# Cilindro / cono vertical. p = centro de la base.
func cyl(p: Vector3, r0: float, r1: float, h: float, col: Color, seg: int = 8, cap: bool = true) -> void:
	var slope := (r0 - r1) / maxf(h, 0.001)
	for i in seg:
		var a0 := TAU * float(i) / float(seg)
		var a1 := TAU * float(i + 1) / float(seg)
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var n0 := Vector3(d0.x, slope, d0.z).normalized()
		var n1 := Vector3(d1.x, slope, d1.z).normalized()
		var b0 := p + d0 * r0
		var b1 := p + d1 * r0
		var t0 := p + d0 * r1 + Vector3(0, h, 0)
		var t1 := p + d1 * r1 + Vector3(0, h, 0)
		tri(b0, b1, t1, n0, n1, n1, col)
		if r1 > 0.001:
			tri(b0, t1, t0, n0, n1, n0, col)
			if cap:
				tri(p + Vector3(0, h, 0), t0, t1, Vector3.UP, Vector3.UP, Vector3.UP, col)


func disc(p: Vector3, r: float, col: Color, seg: int = 16) -> void:
	for i in seg:
		var a0 := TAU * float(i) / float(seg)
		var a1 := TAU * float(i + 1) / float(seg)
		tri(p, p + Vector3(cos(a0), 0, sin(a0)) * r, p + Vector3(cos(a1), 0, sin(a1)) * r, Vector3.UP, Vector3.UP, Vector3.UP, col)


# Esfera / elipsoide. p = centro.
static func _lump(d: Vector3, k: float) -> float:
	return 1.0 + k * (sin(d.x * 5.3 + d.y * 3.1) * sin(d.z * 4.7 - d.y * 2.3) + 0.5 * sin(d.x * 9.1 + d.z * 7.7))


func sphere(p: Vector3, r: Vector3, col: Color, seg: int = 8, rings: int = 5, lump: float = 0.0) -> void:
	for j in rings:
		var p0 := PI * float(j) / float(rings)
		var p1 := PI * float(j + 1) / float(rings)
		for i in seg:
			var a0 := TAU * float(i) / float(seg)
			var a1 := TAU * float(i + 1) / float(seg)
			var d00 := Vector3(sin(p0) * cos(a0), cos(p0), sin(p0) * sin(a0))
			var d01 := Vector3(sin(p0) * cos(a1), cos(p0), sin(p0) * sin(a1))
			var d10 := Vector3(sin(p1) * cos(a0), cos(p1), sin(p1) * sin(a0))
			var d11 := Vector3(sin(p1) * cos(a1), cos(p1), sin(p1) * sin(a1))
			var q00 := p + d00 * r
			var q01 := p + d01 * r
			var q10 := p + d10 * r
			var q11 := p + d11 * r
			if lump > 0.0:
				q00 = p + d00 * r * _lump(d00, lump)
				q01 = p + d01 * r * _lump(d01, lump)
				q10 = p + d10 * r * _lump(d10, lump)
				q11 = p + d11 * r * _lump(d11, lump)
			if j > 0:
				tri(q00, q01, q11, d00, d01, d11, col)
			if j < rings - 1:
				tri(q00, q11, q10, d00, d11, d10, col)


func build(mat: Material) -> ArrayMesh:
	if v.is_empty():
		return null
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_COLOR] = c
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, mat)
	return m


func instance(parent: Node, mat: Material, shadows: bool = true) -> MeshInstance3D:
	var m := build(mat)
	if m == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi
