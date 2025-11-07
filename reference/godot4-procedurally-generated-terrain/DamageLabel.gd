extends Sprite3D

@export var camera: Camera3D
@export var rise_height: float = 1.0
@export var fade_duration: float = 1.0

func _ready():
	# Tweenで上昇＋フェードアウト
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y + rise_height, fade_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	tween.chain().tween_callback(func(): queue_free())

func _process(delta):
	if camera and camera.is_inside_tree():
		look_at(camera.global_transform.origin, Vector3.UP)
