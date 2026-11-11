extends Control
# HUD táctil (dibujado a mano para admitir varios dedos a la vez) y menús.

var GOLD = Color("b99a5b")
var JADE = Color("63c4a4")
var BLOOD = Color("a8261f")
var PAPER = Color("d9d0bd")
var DIM = Color("8f8676")
var INK = Color("0c0a0b")
var LACQ = Color(0.035, 0.035, 0.045, 0.86)

var game
var font: Font
var joy_idx = -1
var joy_origin = Vector2.ZERO
var cam_idx = -1
var atk_idx = -1
var toasts = []
var banner_h = ""
var banner_p = ""
var banner_t = 0.0
var hurt_t = 0.0
var start_panel: Control
var smith_panel: Control
var sel_reino = "carmesi"
var sel_clase = "guerrero"
var reino_btns = {}
var clase_btns = {}
var saved = null
var lbl_w: Label
var lbl_a: Label
var lbl_p: Label
var lbl_msg: Label
var btn_w: Button
var btn_a: Button
var btn_p: Button
var icons = {}
var title_font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	title_font = font
	if ResourceLoader.exists("res://ui/Cinzel.ttf"):
		var fv = FontVariation.new()
		fv.base_font = load("res://ui/Cinzel.ttf")
		fv.variation_opentype = {"wght": 700}
		title_font = fv
	for k in ["atk", "s1", "s2", "pot", "mnt"]:
		var path = "res://ui/" + k + ".svg"
		if ResourceLoader.exists(path):
			icons[k] = load(path)
	build_start()
	build_smith()


func menu_open() -> bool:
	return start_panel.visible or smith_panel.visible


# ---------- construcción de menús ----------

func sbox(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_content_margin_all(14)
	return s


func mk_label(text: String, sz: int, col: Color) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func mk_button(text: String, sz: int, min_size: Vector2, primary: bool) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", sz)
	var normal = sbox(GOLD if primary else LACQ, GOLD, 2)
	var pressed = sbox(Color("f0d48a") if primary else Color(0.85, 0.7, 0.35, 0.45), GOLD, 3)
	var disabled = sbox(Color(0.2, 0.18, 0.16, 0.7), Color(0.4, 0.36, 0.3), 2)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	var fc = INK if primary else PAPER
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, fc)
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.5, 0.45))
	return b


func full_panel(dim_alpha: float) -> Array:
	var p = Control.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(p)
	var dim = ColorRect.new()
	dim.color = Color(0.07, 0.06, 0.05, dim_alpha)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.add_child(dim)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.add_child(center)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	center.add_child(vb)
	return [p, vb]


func row() -> HBoxContainer:
	var hb = HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 12)
	return hb


func build_start() -> void:
	var r = full_panel(0.55)
	start_panel = r[0]
	var vb = r[1]
	var title = mk_label("CIELO ROTO", 104, GOLD)
	title.add_theme_font_override("font", title_font)
	vb.add_child(title)
	vb.add_child(mk_label("El cielo se ha roto. Piedras malditas caen sobre los reinos y despiertan a los muertos.\nElige reino, empuña tu arma y destrúyelas.", 24, PAPER))
	vb.add_child(mk_label("REINO", 18, DIM))
	var hr = row()
	vb.add_child(hr)
	for k in game.REINOS.keys():
		var b = mk_button(game.REINOS[k]["n"], 26, Vector2(200, 60), false)
		b.toggle_mode = true
		b.add_theme_color_override("font_color", game.REINOS[k]["c"].lightened(0.35))
		b.pressed.connect(_pick_reino.bind(k))
		hr.add_child(b)
		reino_btns[k] = b
	vb.add_child(mk_label("CLASE", 18, DIM))
	var hc = row()
	vb.add_child(hc)
	for k in game.CLASES.keys():
		var b = mk_button(game.CLASES[k]["n"] + "\n" + game.CLASES[k]["d"], 20, Vector2(270, 84), false)
		b.toggle_mode = true
		b.pressed.connect(_pick_clase.bind(k))
		hc.add_child(b)
		clase_btns[k] = b
	var ha = row()
	vb.add_child(ha)
	saved = game.load_save()
	var b_new = mk_button("Entrar al reino", 30, Vector2(340, 72), true)
	b_new.pressed.connect(_on_new)
	ha.add_child(b_new)
	if saved != null:
		b_new.text = "Empezar de nuevo"
		var b_c = mk_button("Continuar: " + game.CLASES[saved["clase"]]["n"] + " nivel " + str(saved["lvl"]), 26, Vector2(380, 72), false)
		b_c.pressed.connect(_on_continue)
		ha.add_child(b_c)
	_sync_picks()


func _sync_picks() -> void:
	for k in reino_btns.keys():
		reino_btns[k].set_pressed_no_signal(k == sel_reino)
	for k in clase_btns.keys():
		clase_btns[k].set_pressed_no_signal(k == sel_clase)


func _pick_reino(k: String) -> void:
	sel_reino = k
	_sync_picks()


func _pick_clase(k: String) -> void:
	sel_clase = k
	_sync_picks()


func _on_new() -> void:
	game.begin(game.new_state(sel_reino, sel_clase))


func _on_continue() -> void:
	game.begin(saved)


func show_playing() -> void:
	start_panel.visible = false


func build_smith() -> void:
	var r = full_panel(0.7)
	smith_panel = r[0]
	smith_panel.visible = false
	var vb = r[1]
	var st = mk_label("Forja del herrero", 46, GOLD)
	st.add_theme_font_override("font", title_font)
	vb.add_child(st)
	vb.add_child(mk_label("Cada mejora gasta oro y un fragmento de piedra.\nDesde +4, si falla, la pieza baja un nivel.", 20, DIM))
	lbl_w = mk_label("", 24, PAPER)
	btn_w = mk_button("Mejorar arma", 24, Vector2(300, 60), true)
	btn_w.pressed.connect(_on_up.bind("wpn"))
	lbl_a = mk_label("", 24, PAPER)
	btn_a = mk_button("Mejorar armadura", 24, Vector2(300, 60), true)
	btn_a.pressed.connect(_on_up.bind("arm"))
	lbl_p = mk_label("", 24, PAPER)
	btn_p = mk_button("Comprar poción", 24, Vector2(300, 60), true)
	btn_p.pressed.connect(_on_buy)
	for pair in [[lbl_w, btn_w], [lbl_a, btn_a], [lbl_p, btn_p]]:
		var hb = row()
		pair[0].custom_minimum_size = Vector2(560, 0)
		pair[0].horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		hb.add_child(pair[0])
		hb.add_child(pair[1])
		vb.add_child(hb)
	lbl_msg = mk_label("", 24, JADE)
	lbl_msg.custom_minimum_size = Vector2(0, 34)
	vb.add_child(lbl_msg)
	var hx = row()
	var bx = mk_button("Volver al camino", 26, Vector2(340, 64), false)
	bx.pressed.connect(close_smith)
	hx.add_child(bx)
	vb.add_child(hx)


func refresh_smith() -> void:
	var s = game.S
	var rows = [["wpn", "Arma", lbl_w, btn_w], ["arm", "Armadura", lbl_a, btn_a]]
	for rw in rows:
		var n = int(s[rw[0]])
		if n >= 9:
			rw[2].text = rw[1] + " +9. Nivel máximo."
			rw[3].disabled = true
		else:
			var c = game.up_cost(n)
			rw[2].text = rw[1] + " +" + str(n) + ". Cuesta " + str(c) + " de oro y 1 fragmento. Éxito " + str(game.CH[n]) + " %"
			rw[3].disabled = s["gold"] < c or s["pm"] < 1
	lbl_p.text = "Poción roja: 25 de oro. Tienes " + str(s["pots"]) + ".   Oro: " + str(s["gold"]) + "   Fragmentos: " + str(s["pm"])
	btn_p.disabled = s["gold"] < 25


func _on_up(k: String) -> void:
	var res = game.mejorar(k)
	lbl_msg.text = res[0]
	lbl_msg.add_theme_color_override("font_color", JADE if res[1] == "good" else BLOOD)
	refresh_smith()


func _on_buy() -> void:
	if game.buy_potion():
		lbl_msg.text = "Poción comprada."
		lbl_msg.add_theme_color_override("font_color", JADE)
	refresh_smith()


func open_smith() -> void:
	lbl_msg.text = ""
	refresh_smith()
	smith_panel.visible = true
	release_all()


func close_smith() -> void:
	smith_panel.visible = false


func release_all() -> void:
	joy_idx = -1
	cam_idx = -1
	atk_idx = -1
	game.jx = 0.0
	game.jy = 0.0
	game.inp_atk = false


# ---------- avisos ----------

func toast(msg: String, kind: String) -> void:
	toasts.append({"t": msg, "k": kind, "life": 2.6})
	while toasts.size() > 3:
		toasts.remove_at(0)


func banner(h: String, p: String) -> void:
	banner_h = h
	banner_p = p
	banner_t = 3.4


func flash_hurt() -> void:
	hurt_t = 0.25


# ---------- entrada táctil ----------

func btns() -> Dictionary:
	var w = size.x
	var h = size.y
	return {
		"atk": [Vector2(w - 130, h - 125), 80.0],
		"s1": [Vector2(w - 285, h - 95), 56.0],
		"s2": [Vector2(w - 255, h - 235), 56.0],
		"pot": [Vector2(w - 110, h - 280), 46.0],
		"mnt": [Vector2(w - 110, h - 390), 40.0],
	}


func smith_rect() -> Rect2:
	return Rect2(size.x / 2.0 - 190.0, size.y - 120.0, 380.0, 76.0)


func _input(ev) -> void:
	if game == null or not game.running or menu_open():
		return
	if ev is InputEventScreenTouch:
		if ev.pressed:
			_down(ev.index, ev.position)
		else:
			_up(ev.index)
	elif ev is InputEventScreenDrag:
		_drag(ev.index, ev.position, ev.relative)


func _down(idx: int, pos: Vector2) -> void:
	var b = btns()
	for k in b.keys():
		if pos.distance_to(b[k][0]) <= b[k][1] + 8.0:
			if k == "atk":
				atk_idx = idx
				game.inp_atk = true
			elif k == "s1":
				game.skill(1)
			elif k == "s2":
				game.skill(2)
			elif k == "pot":
				game.potion()
			else:
				game.toggle_mount()
			return
	if game.near_smith() and smith_rect().has_point(pos):
		open_smith()
		return
	if pos.x < size.x * 0.42 and joy_idx == -1:
		joy_idx = idx
		joy_origin = pos
	elif cam_idx == -1:
		cam_idx = idx


func _drag(idx: int, pos: Vector2, rel: Vector2) -> void:
	if idx == joy_idx:
		var v = (pos - joy_origin).limit_length(70.0) / 70.0
		game.jx = v.x
		game.jy = -v.y
	elif idx == cam_idx:
		game.cam_yaw -= rel.x * 0.006
		game.cam_pitch = clamp(game.cam_pitch + rel.y * 0.004, 0.22, 1.1)


func _up(idx: int) -> void:
	if idx == joy_idx:
		joy_idx = -1
		game.jx = 0.0
		game.jy = 0.0
	if idx == cam_idx:
		cam_idx = -1
	if idx == atk_idx:
		atk_idx = -1
		game.inp_atk = false


# ---------- dibujo ----------

func _process(delta: float) -> void:
	banner_t = max(0.0, banner_t - delta)
	hurt_t = max(0.0, hurt_t - delta)
	for i in range(toasts.size() - 1, -1, -1):
		toasts[i]["life"] -= delta
		if toasts[i]["life"] <= 0.0:
			toasts.remove_at(i)
	queue_redraw()


func txt(pos: Vector2, s: String, sz: int, col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string(font, pos + Vector2(1, 2), s, align, width, sz, Color(0, 0, 0, 0.85 * col.a))
	draw_string(font, pos, s, align, width, sz, col)


func ctxt(cx: float, y: float, s: String, sz: int, col: Color) -> void:
	txt(Vector2(cx - 450.0, y), s, sz, col, HORIZONTAL_ALIGNMENT_CENTER, 900.0)


func round_btn(key: String, c: Vector2, r: float, label: String, border: Color, bg: Color, frac: float, sz: int) -> void:
	draw_circle(c, r, bg)
	var has_icon = icons.has(key) and icons[key] != null
	if has_icon:
		var isz = r * 1.05
		draw_texture_rect(icons[key], Rect2(c.x - isz / 2.0, c.y - isz * 0.68, isz, isz), false, PAPER)
	if frac > 0.97:
		draw_circle(c, r, Color(0, 0, 0, 0.6))
	elif frac > 0.03:
		var pts = PackedVector2Array()
		pts.append(c)
		var steps = max(3, int(frac * 32.0))
		for i in range(steps + 1):
			var a = -PI / 2.0 + frac * TAU * i / steps
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, Color(0, 0, 0, 0.6))
	draw_arc(c, r, 0.0, TAU, 48, border, 3.0, true)
	if has_icon:
		txt(Vector2(c.x - r, c.y + r * 0.62), label, int(sz * 0.72), PAPER, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0)
	else:
		txt(Vector2(c.x - r, c.y + sz * 0.35), label, sz, PAPER, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0)


func _draw() -> void:
	if game == null or not game.running:
		return
	var w = size.x
	var h = size.y
	var s = game.S
	var C = game.CLASES[s["clase"]]
	if hurt_t > 0.0:
		draw_rect(Rect2(0, 0, w, h), Color(0.8, 0.2, 0.18, hurt_t * 1.2))
	# estado
	draw_rect(Rect2(40, 24, 360, 118), LACQ)
	draw_rect(Rect2(40, 24, 360, 118), Color(GOLD.r, GOLD.g, GOLD.b, 0.5), false, 2.0)
	txt(Vector2(54, 54), C["n"] + " del Reino " + game.REINOS[s["reino"]]["n"], 22, GOLD)
	txt(Vector2(54, 54), "Nv " + str(s["lvl"]), 22, PAPER, HORIZONTAL_ALIGNMENT_RIGHT, 332.0)
	draw_rect(Rect2(54, 64, 332, 22), Color(0, 0, 0, 0.6))
	var hp_k = clamp(game.php / float(game.pmaxhp), 0.0, 1.0)
	draw_rect(Rect2(54, 64, 332.0 * hp_k, 22), BLOOD)
	txt(Vector2(54, 81), str(int(ceil(game.php))) + " / " + str(game.pmaxhp), 16, PAPER, HORIZONTAL_ALIGNMENT_CENTER, 332.0)
	draw_rect(Rect2(54, 90, 332, 7), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(54, 90, 332.0 * clamp(s["xp"] / float(game.xp_need(s["lvl"])), 0.0, 1.0), 7), JADE)
	txt(Vector2(54, 128), "Oro " + str(s["gold"]), 20, GOLD)
	txt(Vector2(200, 128), "Fragmentos " + str(s["pm"]), 20, JADE)
	# minimapa
	var mc = Vector2(w - 130.0, 110.0)
	var mr = 84.0
	var k = mr / 300.0
	draw_circle(mc, mr, LACQ)
	draw_arc(mc, mr, 0.0, TAU, 48, Color(GOLD.r, GOLD.g, GOLD.b, 0.5), 2.0, true)
	draw_circle(mc, 24.0 * k + 3.0, Color(PAPER.r, PAPER.g, PAPER.b, 0.3))
	for st in game.stones:
		if st["dead"] <= 0.0:
			draw_circle(mc + Vector2(st["x"], st["z"]) * k, 5.0, Color("63e0c0"))
	if game.boss != null:
		draw_circle(mc + Vector2(game.boss["x"], game.boss["z"]) * k, 7.0, BLOOD)
	var pp = mc + Vector2(game.px, game.pz) * k
	var dir = Vector2(sin(game.pang), cos(game.pang))
	var perp = Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([pp + dir * 10.0, pp - dir * 6.0 + perp * 6.0, pp - dir * 6.0 - perp * 6.0]), Color.WHITE)
	var need = 3 * (int(s["boss"]) + 1)
	var goal = "Piedras " + str(min(int(s["dest"]), need)) + "/" + str(need) + " para el jefe"
	if game.boss != null:
		goal = "El jefe espera al norte"
	txt(Vector2(w - 330.0, 222.0), goal, 20, PAPER, HORIZONTAL_ALIGNMENT_RIGHT, 290.0)
	# palanca
	var base = Vector2(180.0, h - 180.0)
	if joy_idx != -1:
		base = joy_origin
	draw_circle(base, 84.0, Color(0, 0, 0, 0.25))
	draw_arc(base, 84.0, 0.0, TAU, 48, Color(GOLD.r, GOLD.g, GOLD.b, 0.5), 2.0, true)
	var knob = base + Vector2(game.jx, -game.jy) * 70.0
	draw_circle(knob, 34.0, LACQ)
	draw_arc(knob, 34.0, 0.0, TAU, 32, GOLD, 3.0, true)
	# botones
	var b = btns()
	round_btn("mnt", b["mnt"][0], b["mnt"][1], "Montura", GOLD, Color(0.85, 0.7, 0.35, 0.45) if game.mounted else LACQ, 0.0, 16)
	round_btn("pot", b["pot"][0], b["pot"][1], "Poción ×" + str(s["pots"]), GOLD, LACQ, game.pot_t / 4.0, 16)
	round_btn("s2", b["s2"][0], b["s2"][1], C["s2"]["n"], JADE, LACQ, game.cd2 / C["s2"]["cd"], 20)
	round_btn("s1", b["s1"][0], b["s1"][1], C["s1"]["n"], JADE, LACQ, game.cd1 / C["s1"]["cd"], 20)
	round_btn("atk", b["atk"][0], b["atk"][1], "Atacar", BLOOD, Color(0.32, 0.06, 0.05, 0.88), 0.0, 26)
	if game.near_smith():
		var sr = smith_rect()
		draw_rect(sr, GOLD)
		draw_string(font, Vector2(sr.position.x, sr.position.y + 48.0), "Hablar con el herrero", HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 28, INK)
	# avisos
	var ty = 170.0
	for t in toasts:
		var a = clamp(t["life"] / 0.5, 0.0, 1.0)
		var col = GOLD
		if t["k"] == "good":
			col = JADE
		elif t["k"] == "bad":
			col = BLOOD
		draw_rect(Rect2(w / 2.0 - 300.0, ty, 600.0, 38.0), Color(LACQ.r, LACQ.g, LACQ.b, 0.8 * a))
		draw_rect(Rect2(w / 2.0 - 300.0, ty, 5.0, 38.0), Color(col.r, col.g, col.b, a))
		txt(Vector2(w / 2.0 - 290.0, ty + 27.0), t["t"], 20, Color(PAPER.r, PAPER.g, PAPER.b, a), HORIZONTAL_ALIGNMENT_CENTER, 580.0)
		ty += 44.0
	if banner_t > 0.0:
		var ba = clamp(banner_t / 0.7, 0.0, 1.0)
		var bc = Color(GOLD.r, GOLD.g, GOLD.b, ba)
		draw_string(title_font, Vector2(w / 2.0 - 598.0, h * 0.36 + 3.0), banner_h, HORIZONTAL_ALIGNMENT_CENTER, 1200.0, 58, Color(0, 0, 0, 0.9 * ba))
		draw_string(title_font, Vector2(w / 2.0 - 600.0, h * 0.36), banner_h, HORIZONTAL_ALIGNMENT_CENTER, 1200.0, 58, bc)
		ctxt(w / 2.0, h * 0.36 + 44.0, banner_p, 26, Color(PAPER.r, PAPER.g, PAPER.b, ba))
