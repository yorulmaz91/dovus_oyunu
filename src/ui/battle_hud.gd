# =============================================================================
# BattleHud  —  Can barlari, kombo sayaci ve DOKUNMATIK KUME
# NEREYE BAGLI: battle.tscn icindeki "HUD" adli CanvasLayer node'una.
#
# Butun arayuz kodla kuruluyor; boylece editorde tek tek Control node'u
# yerlestirmen gerekmiyor.
#
# NEDEN Button DEGIL de TouchScreenButton:
# Godot'ta Control tabanli Button coklu dokunusu guvenilir desteklemez - ayni
# anda ZIPLA + TEKME basilamaz, ki juggle mekanigi tam olarak bunu ister.
# TouchScreenButton isletim duzeyinde parmak indeksiyle calisir, her parmak
# kendi dugmesini ayri tutar. Bedeli: TouchScreenButton bir Node2D'dir,
# anchor'i yoktur - konumlar _layout() icinde elle hesaplanir.
# =============================================================================
class_name BattleHud
extends CanvasLayer

## Testin dugmeleri bulabilmesi icin hepsi bu gruba girer.
const TOUCH_GROUP := &"dokunmatik_dugme"

## Cap (piksel, 1280x720 tabaninda). Yuru tuslari en cok basilanlar: daha buyuk.
const D_MOVE: int = 150
const D_MAIN: int = 130
## Ekran kenarina birakilan en az pay.
const PAD: float = 24.0

# action bos ise dugme hicbir eylem basmaz, sadece "pressed" sinyali yayar.
#
# "kaydir" = TouchScreenButton.passby_press.
# Godot'ta bu KAPALIYKEN surukleme olaylari HIC islenmez: parmak dugmeden
# disari kaysa bile eylem basili kalir, ancak parmak kalkinca birakilir.
# Bu yuzden iki grup ayrildi:
#   YURU tuslari (< >)  -> ACIK. Bunlar bir yon tusu gibi kullanilir; parmak
#     kayinca yuruyusun takili kalmasi gercek bir hata olurdu, ayrica "<" ile
#     ">" arasinda parmagi kaydirabilmek dogru davranistir.
#   Digerleri          -> KAPALI. Parmak kayarak HAVALANDIR'a girmemeli;
#     yanlislikla havalandirici basmak, kacirilan bir girdiden beterdir.
const TOUCH_SPECS: Array = [
	{"ad": "BtnSol", "eylem": &"move_left", "yazi": "<", "cap": D_MOVE, "kaydir": true},
	{"ad": "BtnSag", "eylem": &"move_right", "yazi": ">", "cap": D_MOVE, "kaydir": true},
	{"ad": "BtnBlok", "eylem": &"block", "yazi": "BLOK", "cap": D_MAIN, "kaydir": false},
	{"ad": "BtnYumruk", "eylem": &"attack_light", "yazi": "YUMRUK", "cap": D_MAIN, "kaydir": false},
	{"ad": "BtnTekme", "eylem": &"attack_kick", "yazi": "TEKME", "cap": D_MAIN, "kaydir": false},
	{"ad": "BtnHavalandir", "eylem": &"attack_heavy", "yazi": "HAVALANDIR", "cap": D_MAIN, "kaydir": false},
	{"ad": "BtnZipla", "eylem": &"jump", "yazi": "ZIPLA", "cap": D_MAIN, "kaydir": false},
	{"ad": "BtnTekrar", "eylem": &"", "yazi": "TEKRAR", "cap": D_MAIN, "kaydir": false},
]

var player: Fighter
var enemy: Fighter

var _p_bar: ProgressBar
var _e_bar: ProgressBar
var _combo: Label
var _state: Label

var _touch_root: Node2D
var _buttons: Dictionary = {}
## Nakavtta gizlenen 7 oyun dugmesi (TEKRAR bunlara dahil DEGIL).
var _game_buttons: Array[TouchScreenButton] = []
var _btn_tekrar: TouchScreenButton


func _ready() -> void:
	layer = 10
	_build()
	_build_touch_controls()
	CombatEvents.fighter_died.connect(_on_fighter_died)


func setup(p: Fighter, e: Fighter) -> void:
	player = p
	enemy = e
	player.health_changed.connect(func(c, m): _p_bar.value = c / m * 100.0)
	enemy.health_changed.connect(func(c, m): _e_bar.value = c / m * 100.0)
	enemy.combo_changed.connect(_on_combo)


## battle.gd bunu dogrudan baglar: TouchScreenButton'in "action" alani
## Input.action_press yoluyla calisir ve _unhandled_input'a olay DUSURMEZ,
## o yuzden TEKRAR icin action degil gercek sinyal kullanilir.
func restart_button() -> TouchScreenButton:
	return _btn_tekrar


func touch_button(button_name: String) -> TouchScreenButton:
	return _buttons.get(button_name)


func _process(_delta: float) -> void:
	# _state yalniz gelistirme derlemesinde KURULUR; yayinda hic yok.
	if _state == null or enemy == null:
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


## Nakavt: oyun dugmeleri gider, TEKRAR gelir.
func _on_fighter_died(_who: Node) -> void:
	for b in _game_buttons:
		# Parmak dugme uzerindeyken gizlenirse eylem "basili" takili kalir ve
		# sahne yeniden yuklendiginde Lyra kendiliginden kosardi. Elle birak.
		if b.action != &"" and Input.is_action_pressed(b.action):
			Input.action_release(b.action)
		b.visible = false
	_btn_tekrar.visible = true


# -----------------------------------------------------------------------------
# DOKUNMATIK KUME
# -----------------------------------------------------------------------------
func _build_touch_controls() -> void:
	_touch_root = Node2D.new()
	_touch_root.name = "Dokunmatik"
	add_child(_touch_root)

	for spec in TOUCH_SPECS:
		var cap: int = spec["cap"]
		var b := TouchScreenButton.new()
		b.name = spec["ad"]
		b.texture_normal = _make_circle(cap, Color(0.78, 0.87, 1.0, 0.26))
		b.texture_pressed = _make_circle(cap, Color(1.0, 0.93, 0.55, 0.72))
		b.passby_press = spec["kaydir"]
		b.action = spec["eylem"]
		b.add_to_group(TOUCH_GROUP)
		_touch_root.add_child(b)

		var l := Label.new()
		l.text = spec["yazi"]
		l.size = Vector2(cap, cap)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 34 if cap >= D_MOVE else 15)
		l.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.92))
		b.add_child(l)

		_buttons[spec["ad"]] = b
		if spec["ad"] == "BtnTekrar":
			_btn_tekrar = b
			b.visible = false
		else:
			_game_buttons.append(b)

	get_viewport().size_changed.connect(_layout)
	_layout()


## TouchScreenButton'in dokunma alani, doku dikdortgenidir ve dokunun SOL UST
## kosesi node konumundadir. Bu yuzden her yere merkezden bakip yariçapi
## cikariyoruz. Yerlesim viewport boyutundan hesaplanir: pencere/ekran
## degisince size_changed bunu yeniden calistirir.
func _layout() -> void:
	if _touch_root == null:
		return
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var r_move: float = float(D_MOVE) * 0.5
	var r_main: float = float(D_MAIN) * 0.5

	# --- SOL KUME: "<" ">" yan yana, BLOK ustlerinde ---
	var sol := Vector2(PAD + r_move, vs.y - PAD - r_move)
	var sag := sol + Vector2(float(D_MOVE) * 1.2, 0.0)
	_place("BtnSol", sol)
	_place("BtnSag", sag)
	_place("BtnBlok", Vector2((sol.x + sag.x) * 0.5, sol.y - r_move - r_main - 20.0))

	# --- SAG KUME: 2x2. Ust sira HAVALANDIR / ZIPLA, alt sira YUMRUK / TEKME.
	var adim: float = float(D_MAIN) * 1.24
	var sx: float = vs.x - PAD - r_main
	var sy: float = vs.y - PAD - r_main
	_place("BtnTekme", Vector2(sx, sy))
	_place("BtnYumruk", Vector2(sx - adim, sy))
	_place("BtnZipla", Vector2(sx, sy - adim))
	_place("BtnHavalandir", Vector2(sx - adim, sy - adim))

	# --- TEKRAR: alt-orta, sadece nakavtta gorunur ---
	_place("BtnTekrar", Vector2(vs.x * 0.5, vs.y - PAD - r_main))


func _place(button_name: String, center: Vector2) -> void:
	var b: TouchScreenButton = _buttons[button_name]
	b.position = center - b.texture_normal.get_size() * 0.5


## Yari saydam yuvarlak yer tutucu - projenin gradient dokusu gelenegi.
func _make_circle(diameter: int, tint: Color) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.74, 1.0])
	grad.colors = PackedColorArray([tint, tint, Color(tint.r, tint.g, tint.b, 0.0)])

	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = diameter
	tex.height = diameter
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex


# -----------------------------------------------------------------------------
# Can barlari / yazilar
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

	# GELISTIRME ETIKETI: "Dusman durumu / Juggle puani" sayaci oyuncuya
	# degil BIZE hitap ediyor. Yayin (release) derlemesinde hic KURULMAZ -
	# gizlenmez, yok. Editorde F5 debug derlemesi oldugu icin gorunmeye
	# devam eder.
	if OS.is_debug_build():
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

	# Ipucu SOL USTE tasindi: alt kenar artik dokunmatik kumenin.
	var hint := Label.new()
	hint.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hint.offset_left = 24.0
	hint.offset_right = 430.0
	hint.offset_top = 106.0
	hint.offset_bottom = 200.0
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.text = "A / D = yuru   W = zipla   S = blok\nJ = yumruk   K = HAVALANDIR   L = tekme   R = yeniden basla\nEkrandaki yuvarlaklara parmakla (veya fareyle) basabilirsin.\nKOMBO: K ile havalandir, W ile zipla, sonra L'ye ust uste bas."
	root.add_child(hint)


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
