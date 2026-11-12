extends Control
# HUD táctil dibujado a mano (admite varios dedos a la vez) y paneles de mochila/fabricación.

const D = preload("res://data.gd")

const RUST = Color(0.82, 0.42, 0.2)
const PAPER = Color(0.93, 0.9, 0.82)
const DIM = Color(0.7, 0.68, 0.62)
const INK = Color(0.06, 0.055, 0.05, 0.72)

var game
var font: Font
var move_vec = Vector2.ZERO
var jump_just = false
var atk_just = false
var atk_held = false
var interact_just = false
var joy_idx = -1
var joy_origin = Vector2.ZERO
var joy_pos = Vector2.ZERO
var cam_idx = -1
var atk_idx = -1
var hurt_t = 0.0
var hit_t = 0.0
var toasts = []
var banner_h = ""
var banner_p = ""
var banner_t = 0.0

var start_panel: Control
var start_msg: Label
var btn_cont: Button
var inv_panel: Panel
var inv_btns = []
var chest_btns = []
var chest_lbl: Label
var inv_lbl: Label
var info_lbl: Label
var btn_use: Button
var btn_drop: Button
var craft_btns = []
var chest = null
var sel = -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	build_start()
	build_inv()


func _process(dt: float) -> void:
	hurt_t = max(0.0, hurt_t - dt)
	hit_t = max(0.0, hit_t - dt)
	banner_t = max(0.0, banner_t - dt)
	for t in toasts:
		t["t"] -= dt
	while toasts.size() > 0 and toasts[0]["t"] <= 0.0:
		toasts.pop_front()
	queue_redraw()


func toast(text: String) -> void:
	# junta "+3 Madera" repetidos
	if text.begins_with("+") and toasts.size() > 0:
		var last = toasts[toasts.size() - 1]
		var a = text.split(" ", true, 1)
		var b = last["s"].split(" ", true, 1)
		if b.size() == 2 and a.size() == 2 and last["s"].begins_with("+") and a[1] == b[1]:
			last["s"] = "+%d %s" % [int(a[0]) + int(b[0]), a[1]]
			last["t"] = 2.6
			return
	toasts.append({"s": text, "t": 3.2})
	if toasts.size() > 6:
		toasts.pop_front()


func banner(h: String, p: String) -> void:
	banner_h = h
	banner_p = p
	banner_t = 4.0


# ---------------------------------------------------------------- táctil

func circles() -> Dictionary:
	var w = size.x
	var h = size.y
	return {
		"atk": [Vector2(w - 125, h - 150), 66.0],
		"jump": [Vector2(w - 268, h - 92), 44.0],
		"use": [Vector2(w - 250, h - 232), 48.0],
		"build": [Vector2(w - 92, h - 300), 40.0],
	}


func hot_rect(i: int) -> Rect2:
	var x0 = size.x * 0.5 - 3 * 72.0
	return Rect2(x0 + i * 72.0, size.y - 76.0, 66.0, 66.0)


func chip_rect(i: int) -> Rect2:
	var n = D.BUILD_ORDER.size()
	var x0 = size.x * 0.5 - n * 59.0
	return Rect2(x0 + i * 118.0, size.y - 142.0, 112.0, 56.0)


func inv_rect() -> Rect2:
	return Rect2(size.x - 176, 14, 160, 54)


func _input(ev) -> void:
	if game == null or not game.playing or game.panel_open:
		return
	if ev is InputEventScreenTouch:
		if ev.pressed:
			touch_down(ev.index, ev.position)
		else:
			touch_up(ev.index)
	elif ev is InputEventScreenDrag:
		if ev.index == joy_idx:
			joy_pos = ev.position
			var d = (ev.position - joy_origin) / 75.0
			if d.length() > 1.0:
				d = d.normalized()
			move_vec = Vector2(d.x, -d.y)
		elif ev.index == cam_idx or ev.index == atk_idx:
			game.look(ev.relative.x * 0.0045, ev.relative.y * 0.0045)


func touch_down(idx: int, p: Vector2) -> void:
	var cs = circles()
	for k in cs:
		if p.distance_to(cs[k][0]) <= cs[k][1] + 8.0:
			match k:
				"atk":
					atk_idx = idx
					atk_held = true
					atk_just = true
				"jump":
					jump_just = true
				"use":
					interact_just = true
				"build":
					game.toggle_build()
			return
	if inv_rect().has_point(p):
		open_inv(null)
		return
	for i in 6:
		if hot_rect(i).grow(3).has_point(p):
			game.hot = i
			return
	if game.build_on:
		for i in D.BUILD_ORDER.size():
			if chip_rect(i).has_point(p):
				game.build_kind = D.BUILD_ORDER[i]
				game.t_scan = 0.0
				return
	if p.x < size.x * 0.42 and joy_idx == -1:
		joy_idx = idx
		joy_origin = p
		joy_pos = p
	elif cam_idx == -1:
		cam_idx = idx


func touch_up(idx: int) -> void:
	if idx == joy_idx:
		joy_idx = -1
		move_vec = Vector2.ZERO
	if idx == cam_idx:
		cam_idx = -1
	if idx == atk_idx:
		atk_idx = -1
		atk_held = false


func reset_touch() -> void:
	joy_idx = -1
	cam_idx = -1
	atk_idx = -1
	atk_held = false
	move_vec = Vector2.ZERO


# ---------------------------------------------------------------- dibujo

func txt(pos: Vector2, s: String, sz: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, w: float = -1.0) -> void:
	draw_string(font, pos + Vector2(1, 1), s, align, w, sz, Color(0, 0, 0, col.a * 0.7))
	draw_string(font, pos, s, align, w, sz, col)


func bar(pos: Vector2, v: float, col: Color, label: String) -> void:
	draw_rect(Rect2(pos, Vector2(230, 18)), INK)
	draw_rect(Rect2(pos + Vector2(2, 2), Vector2(226 * clamp(v / 100.0, 0.0, 1.0), 14)), col)
	txt(pos + Vector2(8, 14), label, 13, PAPER)


func short_name(s: String) -> String:
	var i = s.find(" ")
	if i > 0:
		return s.substr(0, i) + "\n" + s.substr(i + 1)
	return s


func _draw() -> void:
	if game == null or not game.playing or game.panel_open:
		return
	var w = size.x
	var h = size.y
	var S = game.S
	if hurt_t > 0.0:
		draw_rect(Rect2(0, 0, w, h), Color(0.8, 0.05, 0.02, hurt_t * 0.5))
	if S["cold"] > 55.0:
		draw_rect(Rect2(0, 0, w, h), Color(0.4, 0.7, 1.0, (S["cold"] - 55.0) / 45.0 * 0.22))
	if game.player.position.y < -1.3:
		draw_rect(Rect2(0, 0, w, h), Color(0.05, 0.3, 0.45, 0.3))
	# estado
	bar(Vector2(18, 16), S["hp"], Color(0.78, 0.2, 0.16), "Vida %d" % int(ceil(S["hp"])))
	bar(Vector2(18, 38), S["food"], Color(0.85, 0.55, 0.15), "Hambre")
	bar(Vector2(18, 60), S["water"], Color(0.2, 0.55, 0.85), "Sed")
	if S["cold"] > 1.0:
		bar(Vector2(18, 82), S["cold"], Color(0.55, 0.8, 0.95), "Frío")
	if S["armor"] != "":
		txt(Vector2(18, 122), D.ITEMS[S["armor"]]["n"], 13, DIM)
	var hr = int(game.time_d * 24.0)
	var mn = int(fmod(game.time_d * 24.0, 1.0) * 60.0)
	txt(Vector2(w * 0.5 - 150, 30), "Día %d · %02d:%02d%s" % [S["day"], hr, mn, "  ·  Noche" if game.is_night() else ""], 17, PAPER, HORIZONTAL_ALIGNMENT_CENTER, 300)
	# mira
	var c = Vector2(w * 0.5, h * 0.5)
	draw_circle(c, 3.0, Color(1, 1, 1, 0.85))
	draw_arc(c, 9.0, 0, TAU, 20, Color(0, 0, 0, 0.35), 1.5)
	if hit_t > 0.0:
		for a in [PI / 4, 3 * PI / 4, 5 * PI / 4, 7 * PI / 4]:
			var d = Vector2(cos(a), sin(a))
			draw_line(c + d * 10.0, c + d * 19.0, Color(1, 0.3, 0.2, hit_t * 4.0), 3.0)
	var label = ""
	if game.build_on:
		var bd = D.BUILD[game.build_kind]
		label = "%s — %s" % [bd["n"], game.cost_text(bd["cost"])]
	elif game.target.size() > 0:
		label = game.target["label"]
	if label != "":
		txt(Vector2(w * 0.5 - 250, h * 0.5 + 52), label, 19, PAPER, HORIZONTAL_ALIGNMENT_CENTER, 500)
	# avisos
	var ty = h * 0.34
	for t in toasts:
		txt(Vector2(22, ty), t["s"], 17, Color(PAPER.r, PAPER.g, PAPER.b, clamp(t["t"], 0.0, 1.0)))
		ty += 24
	if banner_t > 0.0:
		var a = clamp(banner_t, 0.0, 1.0)
		draw_rect(Rect2(0, h * 0.28, w, 110), Color(0, 0, 0, 0.55 * a))
		txt(Vector2(0, h * 0.28 + 52), banner_h, 40, Color(RUST.r, RUST.g, RUST.b, a), HORIZONTAL_ALIGNMENT_CENTER, w)
		txt(Vector2(0, h * 0.28 + 88), banner_p, 18, Color(PAPER.r, PAPER.g, PAPER.b, a), HORIZONTAL_ALIGNMENT_CENTER, w)
	# barra rápida
	for i in 6:
		var r = hot_rect(i)
		draw_rect(r, INK)
		var it = game.inv[i]
		if it != null:
			var def = D.ITEMS[it["id"]]
			draw_rect(Rect2(r.position + Vector2(5, 5), Vector2(56, 8)), def["c"])
			var nm = short_name(def["n"]).split("\n")
			txt(r.position + Vector2(5, 30), nm[0].substr(0, 8), 13, PAPER)
			if nm.size() > 1:
				txt(r.position + Vector2(5, 45), nm[1].substr(0, 8), 12, DIM)
			if it["n"] > 1:
				txt(r.position + Vector2(5, 61), "×%d" % it["n"], 12, PAPER)
		draw_rect(r, RUST if i == game.hot else Color(1, 1, 1, 0.25), false, 3.0 if i == game.hot else 1.0)
	# construcción
	if game.build_on:
		for i in D.BUILD_ORDER.size():
			var k = D.BUILD_ORDER[i]
			var r = chip_rect(i)
			draw_rect(r, Color(0.3, 0.16, 0.08, 0.85) if k == game.build_kind else INK)
			draw_rect(r, RUST if k == game.build_kind else Color(1, 1, 1, 0.25), false, 2.0)
			txt(r.position + Vector2(0, 24), D.BUILD[k]["n"], 15, PAPER, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
			txt(r.position + Vector2(0, 44), game.cost_text(D.BUILD[k]["cost"]), 11, DIM, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	# botones
	var ir = inv_rect()
	draw_rect(ir, INK)
	draw_rect(ir, Color(1, 1, 1, 0.3), false, 1.5)
	txt(ir.position + Vector2(0, 34), "MOCHILA", 17, PAPER, HORIZONTAL_ALIGNMENT_CENTER, ir.size.x)
	var cs = circles()
	var names = {"atk": "COLOCAR" if game.build_on else "USAR", "jump": "SALTO", "use": "PIEZA" if game.build_on else "COGER", "build": "OBRA"}
	var held = game.held_id()
	if not game.build_on and held != "":
		var t = D.ITEMS[held]["t"]
		names["atk"] = {"tool": "GOLPE", "bow": "TIRAR", "gun": "FUEGO", "food": "COMER", "med": "CURAR", "wear": "VESTIR", "deploy": "PONER", "hammer": "MEJORAR"}.get(t, "USAR")
	elif not game.build_on:
		names["atk"] = "GOLPE"
	for k in cs:
		var on = (k == "atk" and atk_held) or (k == "build" and game.build_on) or (k == "use" and game.target.size() > 0)
		draw_circle(cs[k][0], cs[k][1], Color(0.45, 0.22, 0.1, 0.6) if on else Color(0.05, 0.05, 0.05, 0.42))
		draw_arc(cs[k][0], cs[k][1], 0, TAU, 40, RUST if on else Color(1, 1, 1, 0.4), 2.5)
		txt(cs[k][0] + Vector2(-cs[k][1], 6), names[k], 15 if k == "atk" else 12, PAPER, HORIZONTAL_ALIGNMENT_CENTER, cs[k][1] * 2.0)
	# palanca
	if joy_idx != -1:
		draw_circle(joy_origin, 75.0, Color(0, 0, 0, 0.25))
		draw_arc(joy_origin, 75.0, 0, TAU, 40, Color(1, 1, 1, 0.35), 2.0)
		var kp = joy_origin + (joy_pos - joy_origin).limit_length(75.0)
		draw_circle(kp, 30.0, Color(1, 1, 1, 0.4))
	elif game.touch or game.test_mode:
		var jo = Vector2(150, h - 150)
		draw_arc(jo, 75.0, 0, TAU, 40, Color(1, 1, 1, 0.2), 2.0)
		draw_circle(jo, 28.0, Color(1, 1, 1, 0.15))


# ---------------------------------------------------------------- paneles

func sbox(col: Color, border: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = border
	sb.set_border_width_all(2 if border.a > 0.0 else 0)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(6)
	return sb


func mk_btn(text: String, pos: Vector2, sz: Vector2, parent: Control, fs: int = 17) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	b.custom_minimum_size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_stylebox_override("normal", sbox(Color(0.14, 0.13, 0.12, 0.95), Color(1, 1, 1, 0.12)))
	b.add_theme_stylebox_override("hover", sbox(Color(0.2, 0.18, 0.16, 0.95), Color(1, 1, 1, 0.2)))
	b.add_theme_stylebox_override("pressed", sbox(Color(0.4, 0.2, 0.1, 0.95), RUST))
	b.add_theme_stylebox_override("disabled", sbox(Color(0.09, 0.09, 0.09, 0.9)))
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.44, 0.42))
	parent.add_child(b)
	return b


func mk_lbl(text: String, pos: Vector2, fs: int, col: Color, parent: Control) -> Label:
	var l = Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func build_start() -> void:
	start_panel = Control.new()
	start_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(start_panel)
	var shade = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.38)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	start_panel.add_child(shade)
	var box = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	start_panel.add_child(box)
	var t = Label.new()
	t.text = "HERRUMBRE"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 84)
	t.add_theme_color_override("font_color", RUST)
	t.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	t.add_theme_constant_override("outline_size", 10)
	box.add_child(t)
	start_msg = Label.new()
	start_msg.text = "Sobrevive en la isla. Recoge, fabrica, construye."
	start_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_msg.add_theme_font_size_override("font_size", 21)
	start_msg.add_theme_color_override("font_color", PAPER)
	box.add_child(start_msg)
	var sp = Control.new()
	sp.custom_minimum_size = Vector2(10, 22)
	box.add_child(sp)
	btn_cont = mk_btn("Continuar", Vector2.ZERO, Vector2(360, 64), box, 22)
	btn_cont.pressed.connect(func(): _start(true))
	var bn = mk_btn("Nueva partida", Vector2.ZERO, Vector2(360, 64), box, 22)
	bn.pressed.connect(func(): _start(false))
	start_panel.visible = false


func show_start(has_save: bool) -> void:
	start_panel.visible = true
	btn_cont.visible = has_save
	start_msg.text = "Sobrevive en la isla. Recoge, fabrica, construye."


func _start(cont: bool) -> void:
	start_msg.text = "Generando la isla…"
	await get_tree().process_frame
	await get_tree().process_frame
	if cont:
		game.continue_game()
	else:
		game.start_new()


func build_inv() -> void:
	inv_panel = Panel.new()
	inv_panel.add_theme_stylebox_override("panel", sbox(Color(0.07, 0.065, 0.06, 0.96), Color(0.82, 0.42, 0.2, 0.6)))
	inv_panel.size = Vector2(1190, 660)
	inv_panel.set_anchors_preset(Control.PRESET_CENTER)
	inv_panel.offset_left = -595
	inv_panel.offset_top = -330
	inv_panel.offset_right = 595
	inv_panel.offset_bottom = 330
	add_child(inv_panel)
	var xb = mk_btn("✕", Vector2(1190 - 72, 10), Vector2(60, 50), inv_panel, 24)
	xb.text = "X"
	xb.pressed.connect(close_panels)
	chest_lbl = mk_lbl("COFRE — toca para mover", Vector2(24, 14), 17, RUST, inv_panel)
	for i in 12:
		var b = mk_btn("", Vector2(24 + (i % 6) * 90.0, 44 + int(i / 6.0) * 84.0), Vector2(86, 80), inv_panel, 13)
		b.pressed.connect(slot_pressed.bind("chest", i))
		chest_btns.append(b)
	inv_lbl = mk_lbl("MOCHILA — la primera fila es la barra rápida", Vector2(24, 14), 17, RUST, inv_panel)
	for i in 24:
		var b = mk_btn("", Vector2.ZERO, Vector2(86, 80), inv_panel, 13)
		b.pressed.connect(slot_pressed.bind("inv", i))
		inv_btns.append(b)
	info_lbl = mk_lbl("", Vector2(590, 18), 16, PAPER, inv_panel)
	info_lbl.size = Vector2(500, 60)
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn_use = mk_btn("Usar", Vector2(590, 84), Vector2(160, 52), inv_panel)
	btn_use.pressed.connect(func():
		if sel >= 0:
			game.use_slot(sel)
			if game.inv[sel] == null:
				sel = -1
			refresh())
	btn_drop = mk_btn("Tirar", Vector2(762, 84), Vector2(160, 52), inv_panel)
	btn_drop.pressed.connect(func():
		if sel >= 0:
			game.inv[sel] = null
			sel = -1
			refresh())
	mk_lbl("FABRICAR", Vector2(590, 150), 17, RUST, inv_panel)
	var sc = ScrollContainer.new()
	sc.position = Vector2(590, 180)
	sc.size = Vector2(580, 462)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inv_panel.add_child(sc)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(vb)
	for r in D.RECIPES:
		var b = mk_btn("", Vector2.ZERO, Vector2(560, 50), vb, 15)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func():
			game.craft(r)
			refresh())
		craft_btns.append(b)
	inv_panel.visible = false


func open_inv(dep) -> void:
	chest = dep
	sel = -1
	reset_touch()
	game.panel_open = true
	game.capture_mouse(false)
	inv_panel.visible = true
	refresh()


func close_panels() -> void:
	inv_panel.visible = false
	start_panel.visible = false
	chest = null
	if game != null:
		game.panel_open = false
		if game.playing:
			game.capture_mouse(true)


func slot_text(it) -> String:
	if it == null:
		return ""
	var s = short_name(D.ITEMS[it["id"]]["n"])
	if it["n"] > 1:
		s += "\n×%d" % it["n"]
	return s


func refresh() -> void:
	var has_chest = chest != null
	chest_lbl.visible = has_chest
	var y0 = 44.0
	if has_chest:
		y0 = 44.0 + 2 * 84.0 + 40.0
	inv_lbl.position = Vector2(24, y0 - 30.0)
	for i in 12:
		chest_btns[i].visible = has_chest
		if has_chest:
			var it = chest["items"][i]
			chest_btns[i].text = slot_text(it)
			chest_btns[i].add_theme_color_override("font_color", PAPER if it == null else D.ITEMS[it["id"]]["c"].lightened(0.45))
	for i in 24:
		var b = inv_btns[i]
		var row = int(i / 6.0)
		b.position = Vector2(24 + (i % 6) * 90.0, y0 + row * 84.0 + (0.0 if row == 0 else 10.0))
		var it = game.inv[i]
		b.text = slot_text(it)
		b.add_theme_color_override("font_color", PAPER if it == null else D.ITEMS[it["id"]]["c"].lightened(0.45))
		var border = RUST if i == sel else (Color(0.82, 0.42, 0.2, 0.35) if row == 0 else Color(1, 1, 1, 0.12))
		b.add_theme_stylebox_override("normal", sbox(Color(0.2, 0.12, 0.08, 0.95) if i == sel else Color(0.14, 0.13, 0.12, 0.95), border))
	var usable = false
	if sel >= 0 and game.inv[sel] != null:
		var def = D.ITEMS[game.inv[sel]["id"]]
		usable = def["t"] in ["food", "med", "wear"]
		var hint = {"res": "Material.", "tool": "Herramienta: ponla en la barra rápida para usarla.", "bow": "Necesita flechas. Ponlo en la barra rápida.",
			"gun": "Necesita cartuchos. Ponla en la barra rápida.", "food": "Comida.", "med": "Cura 35 de vida.", "wear": "Protege del daño y del frío.",
			"deploy": "Ponlo en la barra rápida y colócalo en el suelo.", "hammer": "Mejora, repara o derriba piezas de tu base."}[def["t"]]
		info_lbl.text = "%s\n%s  Toca otra casilla para moverlo." % [def["n"], hint]
	elif has_chest:
		info_lbl.text = "Toca un objeto para pasarlo entre la mochila y el cofre."
	else:
		info_lbl.text = "Toca un objeto para seleccionarlo y otra casilla para moverlo."
	btn_use.disabled = not usable
	btn_drop.disabled = sel < 0
	for i in D.RECIPES.size():
		var r = D.RECIPES[i]
		var q = "" if r["q"] == 1 else " ×%d" % r["q"]
		var st = "   [banco de trabajo]" if r.has("st") else ""
		craft_btns[i].text = "  %s%s  —  %s%s" % [D.ITEMS[r["id"]]["n"], q, game.cost_text(r["cost"]), st]
		craft_btns[i].disabled = not game.can_craft(r)


func put_into(arr: Array, it: Dictionary) -> bool:
	var mx = game.stack_max(it["id"])
	for i in arr.size():
		if arr[i] != null and arr[i]["id"] == it["id"] and arr[i]["n"] + it["n"] <= mx:
			arr[i]["n"] += it["n"]
			return true
	for i in arr.size():
		if arr[i] == null:
			arr[i] = it
			return true
	return false


func slot_pressed(where: String, i: int) -> void:
	if chest != null:
		if where == "inv" and game.inv[i] != null:
			if put_into(chest["items"], game.inv[i]):
				game.inv[i] = null
		elif where == "chest" and chest["items"][i] != null:
			if put_into(game.inv, chest["items"][i]):
				chest["items"][i] = null
	else:
		if sel == -1:
			if game.inv[i] != null:
				sel = i
		elif sel == i:
			sel = -1
		else:
			var a = game.inv[sel]
			game.inv[sel] = game.inv[i]
			game.inv[i] = a
			sel = -1
	refresh()
