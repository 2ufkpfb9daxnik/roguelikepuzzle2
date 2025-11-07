extends CharacterBody3D

# ==============================
# 状態定義
# ==============================
enum State {
	BATTLE_IDLE,
	ATTACK_PREPARE,
	ATTACK_ALL,
	ATTACK_SINGLE,
	DOWN,
	DEAD
}

var state: State = State.BATTLE_IDLE
var type: int = 0
var attack: int = 10
var hp: int = 100
var max_hp: int = 100

# ==============================
# アニメーション関連
# ==============================
var animation_models: Dictionary = {}  # anim_name -> path
var current_visual_model_root: Node3D = null
var animation_player: AnimationPlayer = null
var current_animation_name: String = ""
var isanim = false

# ==============================
# 初期化
# ==============================
func _ready():
	state = State.BATTLE_IDLE
	_play_battle_idle()

# spawn_enemy / battle_scene から渡される
func set_animation_model_paths(model_paths: Dictionary):
	animation_models = model_paths

# ==============================
# 戦闘処理更新
# ==============================
func _physics_process(delta):
	match state:
		State.BATTLE_IDLE:
			_process_battle_idle(delta)
		State.ATTACK_PREPARE:
			_process_attack_prepare(delta)
		State.ATTACK_ALL:
			_process_attack_all(delta)
		State.ATTACK_SINGLE:
			_process_attack_single(delta)
		State.DOWN:
			pass
		State.DEAD:
			pass

# ==============================
# 状態ごとの処理
# ==============================
func _process_battle_idle(delta):
	if not isanim:
		isanim = true
		_play_battle_idle()

func _process_attack_prepare(delta):
	if animation_player and not animation_player.is_playing():
		if randi() % 2 == 0:
			state = State.ATTACK_ALL
			_play_animation("Animation_Skill_01_withSkin")
		else:
			state = State.ATTACK_SINGLE
			_play_animation("Animation_Skill_03_withSkin")

func _process_attack_all(delta):
	if animation_player and not animation_player.is_playing():
		state = State.BATTLE_IDLE
		isanim = false

func _process_attack_single(delta):
	if animation_player and not animation_player.is_playing():
		state = State.BATTLE_IDLE
		isanim = false

# ==============================
# 状態遷移
# ==============================
func start_attack():
	state = State.ATTACK_PREPARE
	_play_animation("Animation_Boxing_Practice_withSkin")

func receive_damage(amount: int):
	hp -= amount
	if hp <= 0:
		hp = 0
		state = State.DEAD
		_play_death_animation()
	else:
		state = State.DOWN
		_play_hit_animation()

# ==============================
# アニメーション再生関連
# ==============================
func _play_battle_idle():
	# バトルアイドル候補を自動検出
	var idle_candidates = []
	for key in animation_models.keys():
		if "Idle" in key or "Alert" in key or "Dance" in key:
			idle_candidates.append(key)
	if idle_candidates.size() > 0:
		var chosen = idle_candidates.pick_random()
		_play_animation(chosen)
	else:
		# fallback
		if animation_models.size() > 0:
			_play_animation(animation_models.keys()[0])

func _play_hit_animation():
	for anim in animation_models.keys():
		if "BeHit" in anim or "Hit" in anim:
			_play_animation(anim)
			return

func _play_death_animation():
	for anim in animation_models.keys():
		if "Dead" in anim or "Death" in anim:
			_play_animation(anim)
			return

# ==============================
# 汎用アニメーション再生関数
# ==============================
func _play_animation(anim_name: String):
	if not animation_models.has(anim_name):
		push_warning("❌ Animation not found in dictionary: " + anim_name)
		return

	# 既存モデル削除
	if current_visual_model_root:
		for child in current_visual_model_root.get_children():
			child.queue_free()
		await get_tree().process_frame
	else:
		current_visual_model_root = Node3D.new()
		current_visual_model_root.name = "VisualModelRoot"
		add_child(current_visual_model_root)

	var model_path = animation_models[anim_name]
	if not ResourceLoader.exists(model_path):
		push_warning("❌ GLB not found: " + model_path)
		return

	var scene_res = load(model_path)
	if not scene_res or not (scene_res is PackedScene):
		push_warning("❌ Failed to load GLB: " + model_path)
		return

	var inst = scene_res.instantiate()
	current_visual_model_root.add_child(inst)

	animation_player = inst.get_node_or_null("AnimationPlayer")
	if not animation_player:
		animation_player = inst.find_child("AnimationPlayer", true, false)
	if not animation_player:
		push_warning("❌ No AnimationPlayer found for " + anim_name)
		return

	var play_name = anim_name
	var anims = animation_player.get_animation_list()
	if not (anim_name in anims) and anims.size() > 0:
		play_name = anims[0]

	animation_player.play(play_name)
	var anim_res = animation_player.get_animation(play_name)
	if anim_res:
		anim_res.loop = true

	current_animation_name = play_name
