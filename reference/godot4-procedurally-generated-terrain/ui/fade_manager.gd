extends CanvasLayer

@onready var fade_rect = $ColorRect
var is_fading := false

func _ready():
	# 最初は黒
	fade_rect.color = Color(0, 0, 0, 1)
	await fade_in(1.0)

# フェードイン
func fade_in(duration: float = 1.0) -> void:
	if is_fading:
		return
	is_fading = true
	await _fade(1.0, 0.0, duration)
	is_fading = false

# フェードアウト
func fade_out(duration: float = 1.0) -> void:
	if is_fading:
		return
	is_fading = true
	await _fade(0.0, 1.0, duration)
	is_fading = false

# Tween で alpha を変化させる
func _fade(from_alpha: float, to_alpha: float, duration: float):
	fade_rect.color = Color(0, 0, 0, from_alpha)
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", to_alpha, duration)
	await tween.finished
