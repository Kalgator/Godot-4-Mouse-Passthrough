extends Control
# ──────────────────────────────────────────────────────────────────────────────
# DEMO: Godot Window nodes embedded inside one transparent window + mouse passthrough.
# Made By Kalgator (https://kalgator.com)
#
# gui_embed_subwindows = true → Window nodes are drawn INSIDE the main window as movable boxes
# (native title bar, draggable). The main window is transparent and nearly full-screen; the mouse
# passthrough region = union of the visible boxes' rects, so the GAPS let the click go THROUGH to
# the desktop / other apps.
#
# Control panel: buttons to show/hide each window. Each window's X closes it.
# F8 = passthrough ON/OFF · ESC = quit.
#
# NOTE (Windows): window_set_mouse_passthrough uses SetWindowRgn → it clips BOTH input AND what is
# painted, with EVEN-ODD fill. So the rects are unioned (no holes on overlap) and disjoint groups
# are joined with zero-width bridges into a single polygon. See region_util.gd.
# ──────────────────────────────────────────────────────────────────────────────

const PassthroughRegionScript = preload("res://scripts/region_util.gd")

# true = the main window spans ALL monitors (boxes can be dragged across screens).
# false = primary monitor only. NOTE: with mixed resolutions/DPI the virtual-desktop rectangle
# has dead zones (areas with no real monitor); the per-monitor clamp keeps boxes out of them.
const SPAN_ALL_MONITORS := true

const TITLE_H := 28   # approx. embedded title-bar height (for clamp and rects)

var _wins: Array[Window] = []
var _system_on: bool = true
var _origin: Vector2 = Vector2.ZERO   # primary monitor corner in window coordinates

var _panel: Panel
var _status: Label
var _toggle_btns: Array[Button] = []
var _drag_win: Window = null   # window being dragged (skipped by the clamp so it moves freely)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	get_viewport().gui_embed_subwindows = true
	_configure_main_window()

	_make_window("Window A", Vector2i(120, 120), Vector2i(240, 160), Color(0.20, 0.45, 0.85))
	_make_window("Window B", Vector2i(500, 240), Vector2i(240, 160), Color(0.85, 0.35, 0.25))
	_make_window("Window C", Vector2i(320, 440), Vector2i(280, 180), Color(0.30, 0.70, 0.40))

	_build_control_panel()


func _configure_main_window() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true, 0)
	var w := get_window()
	w.borderless = true
	w.always_on_top = true
	w.transparent_bg = true
	# 1 unit = 1 real pixel (no content scaling) so box rects match the polled mouse / monitor rects.
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	w.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE

	if SPAN_ALL_MONITORS:
		# Bounding box of every monitor (the virtual desktop). minp/maxp = top-left / bottom-right.
		var minp := Vector2i(1 << 30, 1 << 30)
		var maxp := Vector2i(-(1 << 30), -(1 << 30))
		for i in DisplayServer.get_screen_count():
			var p := DisplayServer.screen_get_position(i)
			var s := DisplayServer.screen_get_size(i)
			minp.x = mini(minp.x, p.x); minp.y = mini(minp.y, p.y)
			maxp.x = maxi(maxp.x, p.x + s.x); maxp.y = maxi(maxp.y, p.y + s.y)
		w.position = minp + Vector2i(1, 1)   # -1px per side avoids exclusive fullscreen (black)
		w.size = (maxp - minp) - Vector2i(2, 2)
		# Primary monitor corner in window coords → boxes spawn there (not at the virtual-desktop corner).
		_origin = Vector2(DisplayServer.screen_get_position(DisplayServer.get_primary_screen())) - Vector2(w.position)
	else:
		var pidx := DisplayServer.get_primary_screen()
		w.position = DisplayServer.screen_get_position(pidx) + Vector2i(1, 1)
		w.size = DisplayServer.screen_get_size(pidx) - Vector2i(2, 2)
		_origin = Vector2.ZERO
	w.content_scale_size = w.size


func _make_window(title: String, pos: Vector2i, sz: Vector2i, col: Color) -> Window:
	var win := Window.new()
	win.title = title
	win.position = pos + Vector2i(_origin)
	win.size = sz
	win.unresizable = false
	win.close_requested.connect(win.hide)   # the title-bar X closes (hides) the window
	add_child(win)

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r, col.g, col.b, 0.92)
	panel.add_theme_stylebox_override("panel", sb)
	win.add_child(panel)
	var lbl := Label.new()
	lbl.text = title + "\n(drag the title bar · X closes)"
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(lbl)

	_wins.append(win)
	return win


func _build_control_panel() -> void:
	_panel = Panel.new()
	_panel.position = Vector2(40, 40) + _origin
	_panel.size = Vector2(480, 132)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.10, 0.12, 0.97)
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.25)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 10; vb.offset_top = 8; vb.offset_right = -10; vb.offset_bottom = -8
	vb.add_theme_constant_override("separation", 6)
	_panel.add_child(vb)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 12)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(_status)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	vb.add_child(row)
	for i in _wins.size():
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = true
		b.pressed.connect(_on_toggle.bind(i))
		row.add_child(b)
		_toggle_btns.append(b)


func _on_toggle(i: int) -> void:
	if i < _wins.size() and is_instance_valid(_wins[i]):
		_wins[i].visible = not _wins[i].visible


func _process(_dt: float) -> void:
	# PER-MONITOR clamp: each box stays inside the monitor under its center (not the whole virtual
	# desktop), so it can't get lost in dead zones. The box you DRAG is skipped (moves freely) and
	# snaps into its monitor on release.
	var ws := get_window().size
	var win_os := Vector2(get_window().position)
	for win in _wins:
		if not is_instance_valid(win) or win == _drag_win:
			continue
		var center := win_os + Vector2(win.position) + Vector2(win.size) * 0.5
		var mr := _monitor_rect_for(center)     # monitor under the window center (screen coords)
		var ml := mr.position - win_os          # to window coords
		win.position.x = int(clampf(win.position.x, ml.x, maxf(ml.x, ml.x + mr.size.x - win.size.x)))
		win.position.y = int(clampf(win.position.y, ml.y + TITLE_H, maxf(ml.y + TITLE_H, ml.y + mr.size.y - win.size.y)))

	# Passthrough region = union of visible windows + the control panel.
	if not _system_on:
		PassthroughRegionScript.apply_none(0)
	else:
		var rects: Array = []
		for win in _wins:
			if is_instance_valid(win) and win.visible:
				rects.append(Rect2(Vector2(win.get_position_with_decorations()), Vector2(win.get_size_with_decorations())))
		rects.append(Rect2(_panel.position, _panel.size))   # the control panel is always clickable
		PassthroughRegionScript.apply(rects, 0)

	# Status + button texts.
	if _status:
		_status.text = "Passthrough DEMO · window %s · monitors: %d\nF8 = passthrough %s · drag the title bar · click a gap = desktop" % [
			str(ws), DisplayServer.get_screen_count(), "ON" if _system_on else "OFF"]
	for i in _toggle_btns.size():
		var vis: bool = is_instance_valid(_wins[i]) and _wins[i].visible
		_toggle_btns[i].button_pressed = vis
		_toggle_btns[i].text = "%s: %s" % [_wins[i].title if is_instance_valid(_wins[i]) else "—", "shown" if vis else "hidden"]


# Rect (screen coords) of the monitor that contains the point, or the nearest one (dead zones).
func _monitor_rect_for(screen_pt: Vector2) -> Rect2:
	var best := Rect2()
	var best_d := INF
	for i in DisplayServer.get_screen_count():
		var r := Rect2(Vector2(DisplayServer.screen_get_position(i)), Vector2(DisplayServer.screen_get_size(i)))
		if r.has_point(screen_pt):
			return r
		var c := Vector2(clampf(screen_pt.x, r.position.x, r.end.x), clampf(screen_pt.y, r.position.y, r.end.y))
		var d := c.distance_squared_to(screen_pt)
		if d < best_d:
			best_d = d
			best = r
	return best


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F8:
			_system_on = not _system_on
		elif event.keycode == KEY_ESCAPE:
			get_tree().quit()
		return

	# Track which window is being dragged so the clamp skips it (free movement, snaps on release).
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var local := Vector2(DisplayServer.mouse_get_position()) - Vector2(get_window().position)
			_drag_win = null
			for i in range(_wins.size() - 1, -1, -1):
				var w := _wins[i]
				if is_instance_valid(w) and w.visible:
					# Any click on the window (title bar or body) marks it as "dragging".
					var outer := Rect2(Vector2(w.position) - Vector2(0, TITLE_H), Vector2(w.size.x, w.size.y + TITLE_H))
					if outer.has_point(local):
						_drag_win = w
						break
		else:
			_drag_win = null
