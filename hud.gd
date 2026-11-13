extends CanvasLayer
# Interfaz: necesidades, dinero, reloj, minimapa, botón de acción, joystick y pantalla de título.

const World = preload("res://world.gd")
const Shaders = preload("res://shaders.gd")

const SVG_HEAD := "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24'>"
const ICONS := {
	"hambre": "<circle cx='12' cy='12' r='11' fill='#e8703a'/><path d='M8 5v5a2 2 0 0 0 1.4 1.9V19h1.2v-7.1A2 2 0 0 0 12 10V5h-1v4h-.7V5h-1v4H8.6V5zM15.5 5c-1.4 0-2.3 1.8-2.3 4 0 1.6.6 2.6 1.6 3V19H16V5z' fill='#fff'/>",
	"energia": "<circle cx='12' cy='12' r='11' fill='#f2b61f'/><path d='M13.5 4 7 13.2h4.2L10 20l6.8-9.4h-4.3z' fill='#fff'/>",
	"diversion": "<circle cx='12' cy='12' r='11' fill='#b061d6'/><circle cx='8.6' cy='10' r='1.4' fill='#fff'/><circle cx='15.4' cy='10' r='1.4' fill='#fff'/><path d='M7 13.5a5 5 0 0 0 10 0z' fill='#fff'/>",
	"social": "<circle cx='12' cy='12' r='11' fill='#2f9bd8'/><path d='M6 7.5h12a1.5 1.5 0 0 1 1.5 1.5v5a1.5 1.5 0 0 1-1.5 1.5h-5.2L9 18.8v-3.3H6A1.5 1.5 0 0 1 4.5 14V9A1.5 1.5 0 0 1 6 7.5z' fill='#fff'/>",
	"estrella": "<path d='M12 1.8l3.1 6.6 7.1.9-5.2 5 1.3 7.1L12 17.9 5.7 21.4 7 14.3l-5.2-5 7.1-.9z' fill='#ffd21f' stroke='#5a3c00' stroke-width='1.2'/>",
	"dinero": "<path d='M12 1 20 12 12 23 4 12z' fill='#35d96a' stroke='#fff' stroke-width='1.4'/><path d='M12 1 12 23M4 12h16' stroke='#fff' stroke-width='.8' opacity='.7'/>",
	"reloj": "<circle cx='12' cy='12' r='10' fill='#fff' stroke='#34415a' stroke-width='2'/><path d='M12 6v6l4 2.5' stroke='#34415a' stroke-width='2' fill='none' stroke-linecap='round'/>",
}
const LOGO := "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 200 120' width='200' height='120'><defs><linearGradient id='g' x1='0' y1='0' x2='0' y2='1'><stop offset='0' stop-color='#7dffa0'/><stop offset='1' stop-color='#17b84f'/></linearGradient></defs><g fill='#ffffff' opacity='.92'><rect x='18' y='62' width='26' height='52'/><rect x='48' y='44' width='30' height='70'/><rect x='122' y='52' width='28' height='62'/><rect x='154' y='70' width='28' height='44'/><path d='M80 114V84l20-18 20 18v30z'/></g><g fill='#2a5d9a'><rect x='24' y='70' width='6' height='7'/><rect x='34' y='70' width='6' height='7'/><rect x='24' y='84' width='6' height='7'/><rect x='34' y='84' width='6' height='7'/><rect x='55' y='52' width='6' height='7'/><rect x='66' y='52' width='6' height='7'/><rect x='55' y='66' width='6' height='7'/><rect x='66' y='66' width='6' height='7'/><rect x='55' y='80' width='6' height='7'/><rect x='66' y='80' width='6' height='7'/><rect x='129' y='60' width='6' height='7'/><rect x='139' y='60' width='6' height='7'/><rect x='129' y='74' width='6' height='7'/><rect x='139' y='74' width='6' height='7'/><rect x='161' y='78' width='6' height='7'/><rect x='171' y='78' width='6' height='7'/><rect x='94' y='92' width='12' height='22'/></g><path d='M100 2 118 30 100 58 82 30z' fill='url(#g)' stroke='#fff' stroke-width='3'/><path d='M100 2v56M82 30h36' stroke='#fff' stroke-width='1.2' opacity='.7'/></svg>"

signal action_pressed
signal play_pressed
signal zoom_pressed(dir: float)
signal punch_pressed
signal menu_chosen(id: String)

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
var stars: Array = []
var speed_l: Label
var mission_l: Label
var punch_b: Button
var menu_p: PanelContainer


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
	var dots: Array = []

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
		for dt in dots:
			var dp: Vector3 = dt[0]
			var dc: Color = dt[1]
			var q := Vector2((clampf(dp.x, -156, 156) + 156.0) * sc, (clampf(dp.z, -156, 156) + 156.0) * sc)
			draw_circle(q, 6.0, Color(0, 0, 0, 0.7))
			draw_circle(q, 4.5, dc)
		var p := Vector2((clampf(ppos.x, -156, 156) + 156.0) * sc, (clampf(ppos.z, -156, 156) + 156.0) * sc)
		var f := Vector2(sin(yaw), cos(yaw))
		var r := Vector2(f.y, -f.x)
		draw_colored_polygon(PackedVector2Array([p + f * 9.0, p - f * 5.0 + r * 6.0, p - f * 5.0 - r * 6.0]), Color(1, 1, 1))
		draw_colored_polygon(PackedVector2Array([p + f * 6.5, p - f * 3.5 + r * 4.0, p - f * 3.5 - r * 4.0]), Color(0.15, 0.85, 0.35))
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.5), false, 2.0)


func _svg(body: String, scale: float, full: bool = false) -> ImageTexture:
	var img := Image.new()
	var src := body if full else SVG_HEAD + body + "</svg>"
	if img.load_svg_from_string(src, scale) != OK:
		return null
	return ImageTexture.create_from_image(img)


func _icon(id: String, px: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = _svg(ICONS[id], px / 24.0 * 2.0)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(px, px)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


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
	var vig := ColorRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vig.material = Shaders.material(Shaders.VIGNETTE)
	root.add_child(vig)

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
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(hb)
	hb.add_child(_icon("dinero", 28))
	money_l = _label("§ 0", 28, Color(0.55, 1.0, 0.6))
	hb.add_child(money_l)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(14, 0)
	hb.add_child(gap)
	hb.add_child(_icon("reloj", 24))
	clock_l = _label("Lun 09:00", 24)
	hb.add_child(clock_l)
	for k in ["hambre", "energia", "diversion", "social"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(row)
		row.add_child(_icon(k, 26))
		var nl := _label(NEED_NAMES[k], 19)
		nl.custom_minimum_size = Vector2(92, 0)
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

	mission_l = _label("", 24, Color(1.0, 0.88, 0.25))
	mission_l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	mission_l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mission_l.position.y = 50
	mission_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_ui.add_child(mission_l)

	speed_l = _label("", 34)
	speed_l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	speed_l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	speed_l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	speed_l.position.y = -64
	speed_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_l.visible = false
	game_ui.add_child(speed_l)

	var sbox := HBoxContainer.new()
	sbox.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sbox.offset_left = -176
	sbox.offset_top = 180
	sbox.offset_right = -18
	sbox.offset_bottom = 210
	sbox.alignment = BoxContainer.ALIGNMENT_CENTER
	sbox.add_theme_constant_override("separation", 2)
	sbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_ui.add_child(sbox)
	for k in 5:
		var st := _icon("estrella", 28)
		st.modulate = Color(1, 1, 1, 0.16)
		sbox.add_child(st)
		stars.append(st)

	toast_l = _label("", 23)
	toast_l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_l.custom_minimum_size = Vector2(620, 0)
	toast_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_l.offset_left = -310
	toast_l.offset_right = 310
	toast_l.offset_top = 92
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

	punch_b = _button("Golpear", 24, Color(0.75, 0.24, 0.2, 0.95))
	punch_b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	punch_b.offset_left = -200
	punch_b.offset_top = -256
	punch_b.offset_right = -36
	punch_b.offset_bottom = -172
	punch_b.pressed.connect(func(): punch_pressed.emit())
	game_ui.add_child(punch_b)

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
	var lg := TextureRect.new()
	lg.texture = _svg(LOGO, 2.0, true)
	lg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lg.custom_minimum_size = Vector2(300, 180)
	lg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tv.add_child(lg)
	var t1 := _label("CIUDAD MIRASOL", 92, Color(1, 0.9, 0.4))
	t1.add_theme_constant_override("outline_size", 16)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(t1)
	var t2 := _label("Roba, conduce y que no te pillen", 30)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(t2)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 8)
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


func show_menu(title: String, opts: Array) -> void:
	hide_menu()
	menu_p = PanelContainer.new()
	menu_p.add_theme_stylebox_override("panel", _sb(Color(0.07, 0.09, 0.13, 0.95), 20, 22))
	menu_p.set_anchors_preset(Control.PRESET_CENTER)
	menu_p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	menu_p.grow_vertical = Control.GROW_DIRECTION_BOTH
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	menu_p.add_child(vb)
	var tl := _label(title, 27, Color(1, 0.9, 0.45))
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tl)
	for o in opts:
		var b := _button(str(o[0]), 23, Color(0.16, 0.4, 0.68, 0.97))
		b.custom_minimum_size = Vector2(560, 58)
		var id: String = o[1]
		b.pressed.connect(func(): menu_chosen.emit(id))
		vb.add_child(b)
	var cb := _button("Cerrar", 21, Color(0.3, 0.32, 0.36, 0.97))
	cb.custom_minimum_size = Vector2(560, 50)
	cb.pressed.connect(func(): menu_chosen.emit(""))
	vb.add_child(cb)
	root.add_child(menu_p)
	root.move_child(menu_p, fade_r.get_index())


func hide_menu() -> void:
	if menu_p != null and is_instance_valid(menu_p):
		menu_p.queue_free()
	menu_p = null


func set_wanted(n: int) -> void:
	var blink := n > 0 and (Time.get_ticks_msec() / 400) % 2 == 0
	for k in stars.size():
		var st: TextureRect = stars[k]
		if k < n:
			st.modulate = Color(1, 1, 1, 1) if not blink else Color(1.0, 0.75, 0.75, 1)
		else:
			st.modulate = Color(1, 1, 1, 0.16)


func set_drive(on: bool, kmh: int) -> void:
	speed_l.visible = on
	if on:
		speed_l.text = "%d km/h" % kmh


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
