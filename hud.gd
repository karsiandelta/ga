extends CanvasLayer
# Interfaz: necesidades, dinero, reloj, minimapa, botón de acción, joystick y pantalla de título.

const World = preload("res://world.gd")

signal action_pressed
signal play_pressed
signal zoom_pressed(dir: float)

const NEED_NAMES := {"hambre": "Hambre", "energia": "Energía", "diversion": "Diversión", "social": "Social"}

var root: Control
var money_l: Label
var clock_l: Label
var place_l: Label
var toast_l: Label
var bars: Dictionary = {}
var fills: Dictionary = {}
var action_b: Button
var fade_r: ColorRect
var title: Control
var joy: Joy
var mini: Mini
var game_ui: Control
var toast_t := 0.0


class Joy extends Control:
	var active := false
	var origin := Vector2.ZERO
	var vec := Vector2.ZERO

	func _draw() -> void:
		var c := origin if active else Vector2(170, size.y - 170)
		draw_circle(c, 80, Color(1, 1, 1, 0.2 if active else 0.1))
		draw_arc(c, 80, 0, TAU, 48, Color(1, 1, 1, 0.55), 3.0, true)
		draw_circle(c + vec * 62.0, 34, Color(1, 1, 1, 0.6))


class Mini extends Control:
	var ppos := Vector3.ZERO
	var yaw := 0.0

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.16, 0.17, 0.2, 0.85))
		var sc := size.x / 312.0
		for j in World.N:
			for i in World.N:
				var c := World.block_center(i, j)
				var t: String = World.LAYOUT[j][i]
				var col := Color(0.45, 0.68, 0.4)
				if t == "P":
					col = Color(0.92, 0.82, 0.55)
				elif t == "K":
					col = Color(0.25, 0.6, 0.3)
				elif t == "A":
					col = Color(0.7, 0.68, 0.66)
				elif t == "H":
					col = Color(0.98, 0.85, 0.3)
				elif t != "R":
					col = Color(0.85, 0.45, 0.4)
				draw_rect(Rect2((c.x - 22.0 + 156.0) * sc, (c.z - 22.0 + 156.0) * sc, 44.0 * sc, 44.0 * sc), col)
		var p := Vector2((clampf(ppos.x, -156, 156) + 156.0) * sc, (clampf(ppos.z, -156, 156) + 156.0) * sc)
		var f := Vector2(sin(yaw), cos(yaw))
		var r := Vector2(f.y, -f.x)
		draw_colored_polygon(PackedVector2Array([p + f * 9.0, p - f * 5.0 + r * 6.0, p - f * 5.0 - r * 6.0]), Color(1, 1, 1))
		draw_colored_polygon(PackedVector2Array([p + f * 6.5, p - f * 3.5 + r * 4.0, p - f * 3.5 - r * 4.0]), Color(0.15, 0.85, 0.35))
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.5), false, 2.0)


func _sb(col: Color, radius: int = 14, pad: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s


func _label(text: String, size: int, col: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, size: int, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_stylebox_override("normal", _sb(col, 18))
	b.add_theme_stylebox_override("hover", _sb(col.lightened(0.08), 18))
	b.add_theme_stylebox_override("pressed", _sb(col.darkened(0.2), 18))
	b.add_theme_color_override("font_color", Color.WHITE)
	return b


func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	game_ui = Control.new()
	game_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(game_ui)

	joy = Joy.new()
	joy.set_anchors_preset(Control.PRESET_FULL_RECT)
	joy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_ui.add_child(joy)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _sb(Color(0.08, 0.1, 0.14, 0.72)))
	panel.position = Vector2(18, 16)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_ui.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vb)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 22)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(hb)
	money_l = _label("§ 0", 28, Color(0.55, 1.0, 0.6))
	hb.add_child(money_l)
	clock_l = _label("Lun 09:00", 24)
	hb.add_child(clock_l)
	for k in ["hambre", "energia", "diversion", "social"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(row)
		var nl := _label(NEED_NAMES[k], 19)
		nl.custom_minimum_size = Vector2(100, 0)
		row.add_child(nl)
		var pb := ProgressBar.new()
		pb.custom_minimum_size = Vector2(170, 18)
		pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pb.show_percentage = false
		pb.max_value = 100.0
		pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pb.add_theme_stylebox_override("background", _sb(Color(0, 0, 0, 0.5), 8, 0))
		var fill := _sb(Color(0.3, 0.85, 0.4), 8, 0)
		pb.add_theme_stylebox_override("fill", fill)
		row.add_child(pb)
		bars[k] = pb
		fills[k] = fill

	place_l = _label("", 26, Color(1, 0.96, 0.8))
	place_l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	place_l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	place_l.position.y = 14
	place_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_ui.add_child(place_l)

	toast_l = _label("", 23)
	toast_l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_l.custom_minimum_size = Vector2(620, 0)
	toast_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_l.offset_left = -310
	toast_l.offset_right = 310
	toast_l.offset_top = 58
	toast_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_l.add_theme_stylebox_override("normal", _sb(Color(0.05, 0.06, 0.1, 0.78), 16, 14))
	toast_l.visible = false
	game_ui.add_child(toast_l)

	mini = Mini.new()
	mini.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mini.offset_left = -176
	mini.offset_top = 16
	mini.offset_right = -18
	mini.offset_bottom = 174
	mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_ui.add_child(mini)

	action_b = _button("", 26, Color(0.16, 0.6, 0.35, 0.95))
	action_b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	action_b.offset_left = -420
	action_b.offset_top = -150
	action_b.offset_right = -36
	action_b.offset_bottom = -56
	action_b.visible = false
	action_b.pressed.connect(func(): action_pressed.emit())
	game_ui.add_child(action_b)

	var zi := _button("+", 34, Color(0.1, 0.12, 0.16, 0.75))
	zi.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	zi.offset_left = -84
	zi.offset_top = -74
	zi.offset_right = -18
	zi.offset_bottom = -8
	zi.pressed.connect(func(): zoom_pressed.emit(-1.0))
	game_ui.add_child(zi)
	var zo := _button("−", 34, Color(0.1, 0.12, 0.16, 0.75))
	zo.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	zo.offset_left = -84
	zo.offset_top = 4
	zo.offset_right = -18
	zo.offset_bottom = 70
	zo.pressed.connect(func(): zoom_pressed.emit(1.0))
	game_ui.add_child(zo)

	title = Control.new()
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(title)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.05, 0.12, 0.38)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.add_child(shade)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.add_child(cc)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 14)
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_child(tv)
	var t1 := _label("CIUDAD MIRASOL", 92, Color(1, 0.9, 0.4))
	t1.add_theme_constant_override("outline_size", 16)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(t1)
	var t2 := _label("Tu barrio, tus vecinos, tu vida", 30)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(t2)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 30)
	tv.add_child(sp)
	var play := _button("JUGAR", 40, Color(0.16, 0.62, 0.36, 0.96))
	play.custom_minimum_size = Vector2(320, 96)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(func(): play_pressed.emit())
	tv.add_child(play)
	game_ui.visible = false

	fade_r = ColorRect.new()
	fade_r.color = Color(0, 0, 0, 0)
	fade_r.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade_r)


func start_game() -> void:
	title.visible = false
	game_ui.visible = true


func set_needs(d: Dictionary) -> void:
	for k in bars:
		var val: float = d[k]
		bars[k].value = val
		var fill: StyleBoxFlat = fills[k]
		if val > 50.0:
			fill.bg_color = Color(0.3, 0.85, 0.4)
		elif val > 22.0:
			fill.bg_color = Color(0.95, 0.75, 0.2)
		else:
			fill.bg_color = Color(0.92, 0.3, 0.25)


func set_action(text: String) -> void:
	action_b.visible = text != ""
	if text != "":
		action_b.text = text


func toast(text: String) -> void:
	toast_l.text = text
	toast_l.visible = true
	toast_t = 3.6


func fade(to: float, dur: float) -> Signal:
	var tw := create_tween()
	tw.tween_property(fade_r, "color:a", to, dur)
	return tw.finished


func _process(dt: float) -> void:
	if toast_t > 0.0:
		toast_t -= dt
		toast_l.modulate.a = clampf(toast_t / 0.5, 0.0, 1.0)
		if toast_t <= 0.0:
			toast_l.visible = false
	joy.queue_redraw()
	mini.queue_redraw()
