extends Node3D

# 汎用演出呼び出し関数
func show_effect(effect_type:String, world_pos:Vector3) -> void:
	match effect_type:
		"heal":
			_show_heal_effect(world_pos)
		"shield":
			_show_shield_effect(world_pos)
		"fever":
			_show_fever_effect(world_pos)
		"slash_hit":
			_create_slash_hit(world_pos)
		"impact_smash":
			_create_impact_smash(world_pos)
		"magic_burst":
			_create_magic_burst(world_pos)
		"shock_wave":
			_create_shock_wave(world_pos)
		"arrow_storm":
			_create_arrow_storm(world_pos)
		"magic_circle_burst":
			_create_magic_circle_burst(world_pos)

# ===============================
# 各演出
# ===============================
# 🗡 sword: 斬撃
func _create_slash_hit(pos: Vector3):
	var slash = MeshInstance3D.new()
	slash.mesh = QuadMesh.new()
	slash.mesh.size = Vector2(1.8, 0.4) 
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.7, 1.0, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.8, 1.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	slash.material_override = mat
	
	# エフェクトの開始位置と初期回転
	slash.position = pos + Vector3(0.8, 0.5, 0)
	slash.rotation_degrees = Vector3(0, 45, 45)

	get_tree().current_scene.add_child(slash)

	var tween = create_tween()
	
	# 動作時間: 0.5秒
	tween.tween_property(slash, "rotation_degrees:y", -45.0, 0.5).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(slash, "rotation_degrees:z", -45.0, 0.5).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(slash, "position", pos + Vector3(-0.8, 0.5, 0), 0.5).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(slash, "scale", Vector3(1.5, 1.5, 1.5), 0.5).set_ease(Tween.EASE_OUT)
	
	# フェードアウト時間: 1.0秒 (遅延0.5秒 + フェード1.0秒 = 合計1.5秒)
	tween.tween_property(slash.material_override, "albedo_color:a", 0.0, 1.0).set_delay(0.5).set_ease(Tween.EASE_IN) 

	tween.finished.connect(func(): slash.queue_free())


# 🪨 club: 衝撃波
func _create_impact_smash(pos: Vector3):
	var shock = MeshInstance3D.new()
	shock.mesh = SphereMesh.new()
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.4, 0.1, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shock.material_override = mat
	
	shock.scale = Vector3(0.3, 0.1, 0.3)
	shock.position = pos
	get_tree().current_scene.add_child(shock)

	var tween = create_tween()
	
	# 統一時間: 1.5秒
	tween.tween_property(shock, "scale", Vector3(2, 0.5, 2), 1.5)
	tween.parallel().tween_property(shock.material_override, "albedo_color:a", 0.0, 1.5).set_ease(Tween.EASE_OUT)
	
	tween.finished.connect(func(): shock.queue_free())

# 🔮 wand: 光の爆発
func _create_magic_burst(pos: Vector3):
	# 爆発の中心となる大きな球
	var orb = MeshInstance3D.new()
	orb.mesh = SphereMesh.new()
	var mat_orb = StandardMaterial3D.new()
	mat_orb.albedo_color = Color(1.0, 0.9, 0.4, 0.8)
	mat_orb.emission_enabled = true
	mat_orb.emission = Color(1.0, 0.8, 0.3)
	mat_orb.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_orb.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	orb.material_override = mat_orb
	orb.scale = Vector3(0.2, 0.2, 0.2)
	orb.position = pos
	get_tree().current_scene.add_child(orb)

	var tween_orb = create_tween()
	# 統一時間: 1.5秒
	tween_orb.tween_property(orb, "scale", Vector3(1.5, 1.5, 1.5), 1.5).set_ease(Tween.EASE_OUT)
	tween_orb.parallel().tween_property(mat_orb, "albedo_color:a", 0.0, 1.5).set_ease(Tween.EASE_OUT)
	tween_orb.finished.connect(func(): orb.queue_free())

	# 複数の小さな光の破片（パーティクル）を生成
	var num_particles = 10
	for i in range(num_particles):
		var particle = MeshInstance3D.new()
		particle.mesh = SphereMesh.new()
		var mat_particle = StandardMaterial3D.new()
		mat_particle.albedo_color = Color(1.0, 0.9, 0.4, 0.6)
		mat_particle.emission_enabled = true
		mat_particle.emission = Color(1.0, 0.8, 0.3)
		mat_particle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat_particle.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		particle.material_override = mat_particle
		particle.scale = Vector3(0.05, 0.05, 0.05)
		particle.position = pos
		get_tree().current_scene.add_child(particle)

		var tween_particle = create_tween()
		
		# ランダムな方向へ発散
		var dir = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var end_pos = pos + dir * randf_range(1.0, 2.0)
		
		# 統一時間: 1.5秒
		tween_particle.tween_property(particle, "position", end_pos, 1.5).set_ease(Tween.EASE_OUT)
		tween_particle.parallel().tween_property(particle, "scale", Vector3(0.1, 0.1, 0.1), 1.5).set_ease(Tween.EASE_OUT)
		tween_particle.parallel().tween_property(mat_particle, "albedo_color:a", 0.0, 1.5).set_ease(Tween.EASE_IN_OUT)
		
		tween_particle.finished.connect(func(): particle.queue_free())

# ⚒ axe: 地面に波動（スイングに変更）
func _create_shock_wave(pos: Vector3):
	var swing_arc = MeshInstance3D.new()
	var mesh = PlaneMesh.new()
	mesh.size = Vector2(8, 2)
	swing_arc.mesh = mesh

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.9, 1.0, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	swing_arc.material_override = mat

	swing_arc.position = pos + Vector3(0, 1.5, 0)
	swing_arc.rotate_y(deg_to_rad(90))
	swing_arc.rotate_z(deg_to_rad(-45))

	get_tree().current_scene.add_child(swing_arc)

	var tween = create_tween()
	# 統一時間: 1.5秒
	tween.tween_property(swing_arc, "rotation_degrees:y", -90.0, 1.5).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(swing_arc.material_override, "albedo_color:a", 0.0, 1.5).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(swing_arc, "scale", Vector3(1.2, 1.2, 1.2), 1.5).set_ease(Tween.EASE_OUT)
	
	tween.finished.connect(func(): swing_arc.queue_free())

# 🏹 arrow: 矢の雨
func _create_arrow_storm(pos: Vector3):
	var num_particles = 8
	# 矢がすべて落ちて消えるまでの総時間を1.5秒にするための計算
	var base_animation_duration = 0.4  # 落下 0.3秒 + フェード 0.1秒
	var max_delay = 1.5 - base_animation_duration # 1.1秒
	var delay_per_arrow = max_delay / float(num_particles - 1) # 1.1 / 7 ≒ 0.157

	for i in range(num_particles):
		var arrow = MeshInstance3D.new()
		arrow.mesh = CylinderMesh.new()
		arrow.scale = Vector3(0.05, 0.5, 0.05)
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.6, 0.5, 0.4, 1.0)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		arrow.material_override = mat
		
		arrow.position = pos + Vector3(randf_range(-2, 2), 3 + randf(), randf_range(-2, 2))
		get_tree().current_scene.add_child(arrow)
		
		var arrow_mat = arrow.material_override.duplicate(true)
		arrow.material_override = arrow_mat

		var tween = create_tween()
		
		# 落下 (0.3秒) + 遅延 (最大1.1秒)
		tween.tween_property(arrow, "position:y", pos.y, 0.3).set_delay(float(i) * delay_per_arrow)
		
		# フェードアウト (0.1秒)
		tween.tween_property(arrow_mat, "albedo_color:a", 0.0, 0.1)
		
		tween.finished.connect(func(): arrow.queue_free())

# 🪄 magicCircle: 魔法陣＋光柱
func _create_magic_circle_burst(pos: Vector3):
	# 魔法陣
	var circle = MeshInstance3D.new()
	circle.mesh = CylinderMesh.new()
	circle.mesh.height = 0.05
	circle.scale = Vector3(0.1, 0.05, 0.1)
	
	var mat_circle = StandardMaterial3D.new()
	mat_circle.albedo_color = Color(0.3, 0.6, 1.0, 0.6)
	mat_circle.emission_enabled = true
	mat_circle.emission = Color(0.3, 0.8, 1.0)
	mat_circle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	circle.material_override = mat_circle
	circle.position = pos
	get_tree().current_scene.add_child(circle)

	# 光柱
	var beam = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.height = 5
	cyl.top_radius = 0.3
	cyl.bottom_radius = 0.3
	beam.mesh = cyl
	
	var mat_beam = StandardMaterial3D.new()
	mat_beam.albedo_color = Color(0.5, 0.8, 1.0, 0.3)
	mat_beam.emission_enabled = true
	mat_beam.emission = Color(0.5, 0.8, 1.0)
	mat_beam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.material_override = mat_beam
	beam.position = pos + Vector3(0, 2.5, 0)
	get_tree().current_scene.add_child(beam)

	var tween = create_tween()
	# 統一時間: 1.5秒
	tween.tween_property(circle, "scale", Vector3(1.5, 0.05, 1.5), 1.5)
	tween.parallel().tween_property(mat_circle, "albedo_color:a", 0.0, 1.5)
	tween.parallel().tween_property(mat_beam, "albedo_color:a", 0.0, 1.5)
	
	tween.finished.connect(func():
		circle.queue_free()
		beam.queue_free()
	)
# ✅ 回復エフェクト
func _show_heal_effect(world_pos:Vector3) -> void:
	# --- 2. 光のパーティクル (追加) ---
	var num_particles = 10
	var particle_color = Color(0.8, 1.0, 0.8, 1.0) # 明るい緑
	var particle_duration = 1.0 # パーティクルの動きは1.0秒

	for i in range(num_particles):
		var particle = MeshInstance3D.new()
		particle.mesh = SphereMesh.new()
		
		var mat_particle = StandardMaterial3D.new()
		mat_particle.albedo_color = particle_color
		mat_particle.emission_enabled = true
		mat_particle.emission = particle_color * 0.5
		mat_particle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat_particle.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		particle.material_override = mat_particle
		
		# 初期スケールとランダムな初期位置 (キャラクターの中心付近)
		particle.scale = Vector3(0.05, 0.05, 0.05)
		var start_pos = world_pos + Vector3(randf_range(-0.3, 0.3), randf_range(0.5, 1.5), randf_range(-0.3, 0.3))
		particle.position = start_pos
		get_tree().current_scene.add_child(particle)
		
		var tween_particle = create_tween()
		
		# 動きのアニメーション
		var end_pos = start_pos + Vector3(randf_range(-0.5, 0.5), 1.0, randf_range(-0.5, 0.5))
		
		# 上昇とスケール拡大 (1.0秒)
		tween_particle.tween_property(particle, "position:y", end_pos.y, particle_duration)
		tween_particle.parallel().tween_property(particle, "scale", Vector3(0.15, 0.15, 0.15), particle_duration * 0.5)
		
		# フェードアウト (0.5秒)
		tween_particle.tween_property(mat_particle, "albedo_color:a", 0.0, 0.5).set_delay(particle_duration - 0.5)
		
		tween_particle.finished.connect(func(): particle.queue_free())


# ✅ シールドエフェクト
func _show_shield_effect(world_pos:Vector3) -> void:
	var shield = MeshInstance3D.new()
	shield.mesh = SphereMesh.new()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.7, 1.0, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shield.material_override = mat
	shield.scale = Vector3(1, 1, 1)
	shield.position = world_pos
	get_tree().current_scene.add_child(shield)

	var tween = create_tween()
	tween.tween_property(shield, "scale", Vector3(1.5, 1.5, 1.5), 0.6)
	tween.tween_property(shield, "modulate:a", 0.0, 0.6)
	tween.finished.connect(func(): shield.queue_free())

# ✅ フィーバーエフェクト
func _show_fever_effect(world_pos:Vector3) -> void:
	var fever = MeshInstance3D.new()
	fever.mesh = SphereMesh.new()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.0, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.2)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fever.material_override = mat
	fever.scale = Vector3(0.5, 0.5, 0.5)
	fever.position = world_pos
	get_tree().current_scene.add_child(fever)

	var tween = create_tween()
	tween.tween_property(fever, "scale", Vector3(2, 2, 2), 1.2)
	tween.tween_property(fever, "modulate:a", 0.0, 1.2)
	tween.finished.connect(func(): fever.queue_free())
