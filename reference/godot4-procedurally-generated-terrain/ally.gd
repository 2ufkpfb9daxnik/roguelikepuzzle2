class_name Ally
extends UnitBase

# 既存互換用ステート定義
enum State {
	BATTLE_IDLE = UnitState.BATTLE_IDLE,
	BATTLE_MOVE = UnitState.BATTLE_MOVE,
	ATTACK_ALL = UnitState.ATTACK_ALL,
	ATTACK_SINGLE = UnitState.ATTACK_SINGLE,
	DOWN = UnitState.DOWN,
	DEAD = UnitState.DEAD
}

@export var level: int = 1

var character_index: int = -1
var character_name: String = ""
var skill_power: float = 1.0

func _ready() -> void:
	_setup_unit_base()
	assign_battle_idle_anim()
	state = State.BATTLE_IDLE

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	match state:
		State.BATTLE_IDLE:
			_process_battle_idle(delta)
		State.BATTLE_MOVE:
			_process_battle_move(delta)
		State.ATTACK_ALL:
			_process_attack_all(delta)
		State.ATTACK_SINGLE:
			_process_attack_single(delta)
		State.DOWN:
			_process_down(delta)
		State.DEAD:
			pass

	move_and_slide()

func _process(_delta: float) -> void:
	if hp_sprite:
		if hp_camera and hp_camera.is_inside_tree():
			hp_sprite.look_at(hp_camera.global_transform.origin, Vector3.UP)
		else:
			var cam_try = get_viewport().get_camera_3d()
			if cam_try:
				hp_sprite.look_at(cam_try.global_transform.origin, Vector3.UP)

func _process_battle_idle(_delta: float) -> void:
	if not isanim:
		if battle_idle_anim != "":
			play_unit_animation(battle_idle_anim)
		else:
			_play_any_idle_animation()
		isanim = true

func _process_battle_move(_delta: float) -> void:
	if isanim:
		return
	_play_best_anim(["Animation_Running_withSkin"])
	isanim = true

func _process_attack_all(_delta: float) -> void:
	if isanim:
		return
	_play_best_anim(["Animation_Skill_01_withSkin"])
	isanim = true

func _process_attack_single(_delta: float) -> void:
	if isanim:
		return
	_play_best_anim(["Animation_Skill_03_withSkin"])
	isanim = true

func _process_down(delta: float) -> void:
	state_timer += delta
	if state_timer >= 1.0 and state_timer < 2.0:
		if not isanim:
			isanim = true
			_play_best_anim(["Animation_Arise_withSkin"])
	elif state_timer >= 2.0:
		state_timer = 0.0
		isanim = false
		state = State.BATTLE_IDLE

func _play_any_idle_animation() -> void:
	if procedural_animation_enabled or animation_models.is_empty():
		_play_procedural_animation("idle")
		return
	for key in animation_models.keys():
		if "Idle" in key or "Alert" in key or "Dance" in key:
			play_unit_animation(key)
			return
	if animation_models.size() > 0:
		play_unit_animation(animation_models.keys()[0])

func _play_best_anim(preferred_names: Array) -> void:
	if procedural_animation_enabled or animation_models.is_empty():
		_play_procedural_animation(str(preferred_names[0]) if not preferred_names.is_empty() else "idle")
		return
	for anim in preferred_names:
		if animation_models.has(anim):
			play_unit_animation(anim)
			return
	if battle_idle_anim != "" and animation_models.has(battle_idle_anim):
		play_unit_animation(battle_idle_anim)
	elif animation_models.size() > 0:
		play_unit_animation(animation_models.keys()[0])

# 既存コードとの互換メソッド
func receive_damage(amount: int) -> void:
	take_damage(amount)
