extends Control

const MAIN_SCENE_PATH := "res://main.tscn"
const MAIN_SCENE_PATH_FALLBACK := "res://reference/godot4-procedurally-generated-terrain/main.tscn"

# 盤面で使うテクスチャもタイトル表示中に読み込んでおく
const PRELOAD_TEXTURES := [
	"res://texture/cell/shield.png",
	"res://texture/cell/sword.png",
	"res://texture/cell/coin.png",
	"res://texture/cell/potion.png",
	"res://texture/cell/bread.png",
	"res://texture/cell/wand.png"
]

var isclicked = false
var interval = 0
var _preload_started = false

func _ready() -> void:
	var bgm := get_node_or_null("/root/BGMManager")
	if bgm and bgm.has_method("play_title"):
		# シーン内の BGM と重複しないよう、共通 BGM マネージャーでループ再生する。
		var local_bgm := get_node_or_null("titlebgm")
		if local_bgm and local_bgm is AudioStreamPlayer:
			local_bgm.stop()
		elif local_bgm and local_bgm is AudioStreamPlayer2D:
			local_bgm.stop()
		bgm.play_title()
	else:
		get_node("titlebgm").play()

	if has_node("VBoxContainer/Button"):
		get_node("VBoxContainer/Button").pressed.connect(_on_button_pressed)
	if has_node("VBoxContainer/SettingsButton"):
		get_node("VBoxContainer/SettingsButton").pressed.connect(_on_settings_pressed)

	# 本編シーンと盤面テクスチャをバックグラウンドで先読みする
	call_deferred("_start_preloading")

func _start_preloading() -> void:
	if _preload_started:
		return
	_preload_started = true
	ResourceLoader.load_threaded_request(MAIN_SCENE_PATH)
	for tex_path in PRELOAD_TEXTURES:
		if ResourceLoader.exists(tex_path):
			ResourceLoader.load_threaded_request(tex_path)

func _on_button_pressed() -> void:
	if isclicked:
		return
	print("pressed")
	if has_node("click"):
		get_node("click").play()
	isclicked = true
	_start_preloading()

func _on_settings_pressed() -> void:
	var settings_manager = get_node_or_null("/root/SettingsManager")
	if settings_manager and settings_manager.has_method("open_settings"):
		settings_manager.open_settings()

func _process(delta: float) -> void:
	if isclicked:
		if interval < 30:
			if has_node("anten"):
				get_node("anten").color.a += 0.03
		elif interval >= 40:
			if has_node("anten"):
				get_node("anten").color.a = 0
			isclicked = false
			interval = 0
			_change_to_main_scene()
			return
		interval += 1

func _change_to_main_scene() -> void:
	# すでに読み込み済みなら即座に、読み込み中なら完了まで待つ
	var status := ResourceLoader.THREAD_LOAD_IN_PROGRESS
	var progress := []
	if _preload_started:
		status = ResourceLoader.load_threaded_get_status(MAIN_SCENE_PATH, progress)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		status = ResourceLoader.load_threaded_get_status(MAIN_SCENE_PATH, progress)
	var next_scene: PackedScene = null
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		next_scene = ResourceLoader.load_threaded_get(MAIN_SCENE_PATH) as PackedScene
	if next_scene == null:
		next_scene = load(MAIN_SCENE_PATH) as PackedScene
	if next_scene == null:
		next_scene = load(MAIN_SCENE_PATH_FALLBACK) as PackedScene
	if next_scene:
		get_tree().change_scene_to_packed(next_scene)
