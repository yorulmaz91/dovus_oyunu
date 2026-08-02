# =============================================================================
# BattleHud  —  Can barlari, kombo sayaci ve DOKUNMATIK TUSLAR
# NEREYE BAGLI: battle.tscn icindeki "HUD" adli CanvasLayer node'una.
#
# Butun arayuz kodla kuruluyor; boylece editorde tek tek Control node'u
# yerlestirmen gerekmiyor. Ekrandaki tuslara FARE ile de basabilirsin.
# =============================================================================
class_name BattleHud
extends CanvasLayer

const TOUCH_BUTTONS := [
	{"label": "YUMRUK\n(J)", "action": &"attack_light", "x": -370.0, "w": 110.0},
	{"label": "TEKME\n(L)", "action": &"attack_kick", "x": -250.0, "w": 110.0},
	{"label": "HAVALANDIR\n(K)", "action": &"attack_heavy", "x": -130.0, "w": 120.0},
]

var player: Fighter
var enemy: Fighter

var _p_bar: ProgressBar
var _e_bar: ProgressBar
var _combo: Label
var _state: Label


func _ready() -> void:
	layer = 10
	_build()


func setup(p: Fighter, e: Fighter) -> void:
	player = p
	enemy = e
	player.health_changed.connect(func(c, m): _p_bar.value = c / m * 100.0)
	enemy.health_changed.connect(func(c, m): _e_bar.value = c / m * 100.0)
	enemy.combo_changed.connect(_on_combo)


func _process(_delta: float) -> void:
	if enemy == null:
		return
	# Juggle sistemini canli izleyebilmen icin sayaclar.
	_state.text = "Dusman durumu: %s    |    Juggle puani: %d / %d" % [
		String(enemy.fsm.current_name),
		enemy.juggle_hits,
		enemy.juggle_rules.max_juggle_hits,
	]


func _on_combo(hits: int) -> void:
	if hits <= 1:
		_combo.text = ""
	else:
		_combo.text = "%d VURUS!" % hits


# -----------------------------------------------------------------------------
func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_p_bar = _make_bar(root, true, "LYRA")
	_e_bar = _make_bar(root, false, "DUSMAN")

	_combo = Label.new()
	_combo.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_combo.offset_left = -200.0
	_combo.offset_right = 200.0
	_combo.offset_top = 110.0
	_combo.offset_bottom = 160.0
	_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo.add_theme_font_size_override("font_size", 34)
	_combo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_combo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_combo)

	_state = Label.new()
	_state.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_state.offset_left = -320.0
	_state.offset_right = 320.0
	_state.offset_top = 74.0
	_state.offset_bottom = 100.0
	_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_state.add_theme_font_size_override("font_size", 15)
	_state.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	_state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_state)

	var hint := Label.new()
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 20.0
	hint.offset_right = 640.0
	hint.offset_top = -104.0
	hint.offset_bottom = -20.0
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.text = "A / D = yuru      W veya BOSLUK = zipla      S = blok\nJ = yumruk      K = HAVALANDIR      L = tekme      R = yeniden basla\nKOMBO: K ile havalandir, W ile zipla, sonra L'ye ust uste bas."
	root.add_child(hint)

	# --- Dokunmatik / fareyle basilabilir tuslar ---
	for spec in TOUCH_BUTTONS:
		var b := Button.new()
		b.text = spec["label"]
		b.focus_mode = Control.FOCUS_NONE
		b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		b.offset_left = spec["x"]
		b.offset_right = spec["x"] + spec["w"]
		b.offset_top = -104.0
		b.offset_bottom = -20.0
		b.add_theme_font_size_override("font_size", 14)
		var action: StringName = spec["action"]
		b.button_down.connect(func(): Input.action_press(action))
		b.button_up.connect(func(): Input.action_release(action))
		root.add_child(b)

	var jump_b := Button.new()
	jump_b.text = "ZIPLA\n(W)"
	jump_b.focus_mode = Control.FOCUS_NONE
	jump_b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	jump_b.offset_left = -130.0
	jump_b.offset_right = -10.0
	jump_b.offset_top = -196.0
	jump_b.offset_bottom = -112.0
	jump_b.add_theme_font_size_override("font_size", 14)
	jump_b.button_down.connect(func(): Input.action_press(&"jump"))
	jump_b.button_up.connect(func(): Input.action_release(&"jump"))
	root.add_child(jump_b)


func _make_bar(root: Control, left: bool, title: String) -> ProgressBar:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_TOP_LEFT if left else Control.PRESET_TOP_RIGHT)
	box.offset_left = 24.0 if left else -444.0
	box.offset_right = 444.0 if left else -24.0
	box.offset_top = 20.0
	box.offset_bottom = 74.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)

	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(lbl)

	var bar := ProgressBar.new()
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0.0, 22.0)
	box.add_child(bar)
	return bar
