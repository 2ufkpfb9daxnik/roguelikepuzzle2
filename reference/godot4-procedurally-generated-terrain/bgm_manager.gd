extends Node

# ============================================================
# BGM 管理（Autoload: BGMManager）
#  - フィールド / 通常戦闘 / ボス / ラスボス / フィーバー / エンディングを切替
#  - 音源は初回再生時に遅延ロードし、終了時に手動ループする
#  - 音量は SettingsManager の BGM バスで一括制御される
# ============================================================

const TRACKS := {
	"field": "res://sound/field_music.mp3",
	"battle": "res://sound/bgm/gameppoi/RPG_Battle_demo_bpm192.mp3",
	"boss": "res://sound/bgm/bossppoi/maou_bgm_fantasy15.mp3",
	"final_boss": "res://sound/bgm/gameppoi/maou_bgm_fantasy06.mp3",
	"fever": "res://sound/パーティーはハチャメチャ大騒ぎ.ogg",
	"ending": "res://sound/bgm/bgmnokouho/ending.wav",
	"title": "res://sound/music.mp3"
}

const FADE_TIME := 0.28
const SILENT_DB := -40.0

var players: Dictionary = {}
var current_key: String = ""
var _fade_tweens: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in TRACKS.keys():
		var player := AudioStreamPlayer.new()
		player.name = "%sBGM" % str(key).capitalize().replace("_", "")
		player.bus = "BGM" if AudioServer.get_bus_index("BGM") != -1 else "Master"
		player.volume_db = SILENT_DB
		add_child(player)
		player.finished.connect(_on_track_finished.bind(key))
		players[key] = player

func play_field() -> void:
	play("field")

func play_battle(is_boss: bool = false, is_final_boss: bool = false) -> void:
	if is_final_boss:
		play("final_boss")
	elif is_boss:
		play("boss")
	else:
		play("battle")

func play_fever() -> void:
	play("fever")

func play_ending() -> void:
	play("ending")

func play_title() -> void:
	play("title")

func play(key: String) -> void:
	if not players.has(key):
		return
	if current_key == key and players[key].playing:
		return
	var old_key := current_key
	current_key = key
	if old_key != "" and players.has(old_key):
		_fade_out(old_key)
	_fade_in(key)

func stop_all() -> void:
	current_key = ""
	for key in players.keys():
		_fade_out(str(key))

func _fade_in(key: String) -> void:
	var player: AudioStreamPlayer = players[key]
	if player == null:
		return
	if player.stream == null:
		var path := str(TRACKS.get(key, ""))
		if path == "" or not ResourceLoader.exists(path):
			push_warning("BGM not found: %s" % path)
			return
		player.stream = load(path)
	if _fade_tweens.has(key):
		var old_tween: Tween = _fade_tweens[key]
		if old_tween and old_tween.is_valid():
			old_tween.kill()
	player.volume_db = SILENT_DB
	player.play()
	var tween := create_tween()
	tween.tween_property(player, "volume_db", 0.0, FADE_TIME)
	_fade_tweens[key] = tween

func _fade_out(key: String) -> void:
	if not players.has(key):
		return
	var player: AudioStreamPlayer = players[key]
	if player == null or not player.playing:
		return
	if _fade_tweens.has(key):
		var old_tween: Tween = _fade_tweens[key]
		if old_tween and old_tween.is_valid():
			old_tween.kill()
	var tween := create_tween()
	tween.tween_property(player, "volume_db", SILENT_DB, FADE_TIME)
	tween.tween_callback(func():
		if is_instance_valid(player):
			player.stop()
	)
	_fade_tweens[key] = tween

func _on_track_finished(key: String) -> void:
	if current_key != key:
		return
	var player: AudioStreamPlayer = players.get(key, null)
	if player == null or player.stream == null:
		return
	# 手動ループ。AudioStream の loop 設定に依存しない。
	player.seek(0.0)
	player.play()
