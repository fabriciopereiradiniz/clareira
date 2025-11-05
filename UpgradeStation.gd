extends Area2D

# Village Upgrade Station - Similar to Minecraft village structures
# Allows players to upgrade their tools and abilities using resources

@export var upgrade_type: String = "tree_damage"  # Type of upgrade this station provides
var player_in_range: bool = false
var player_ref: CharacterBody2D = null

# Visual indicators
var hover_scale_tween: Tween
var original_scale: Vector2

func _ready():
	# Add to upgrade_station group for identification
	add_to_group("upgrade_stations")
	
	# Store original scale for hover effects
	original_scale = scale
	
	# Setup collision for player interaction
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(32, 32)  # Standard tile size
	collision.shape = shape
	add_child(collision)
	
	# Setup visual sprite
	var sprite = Sprite2D.new()
	sprite.texture = create_upgrade_station_texture()
	add_child(sprite)
	
	# Connect signals
	body_entered.connect(_on_player_entered)
	body_exited.connect(_on_player_exited)
	input_event.connect(_on_input_event)
	
	print("🏠 Upgrade Station created at position: ", global_position)

func create_upgrade_station_texture() -> ImageTexture:
	# Create a simple colored rectangle for the upgrade station
	var image = Image.create(32, 32, false, Image.FORMAT_RGB8)
	image.fill(Color.BROWN)  # Brown base for workshop look
	
	# Add some details
	for x in range(8, 24):
		for y in range(8, 24):
			image.set_pixel(x, y, Color.BURLYWOOD)  # Lighter center
	
	# Add tool symbols (simple pixels)
	image.set_pixel(16, 10, Color.GRAY)  # Hammer handle
	image.set_pixel(16, 11, Color.GRAY)
	image.set_pixel(15, 9, Color.DARK_GRAY)  # Hammer head
	image.set_pixel(17, 9, Color.DARK_GRAY)
	
	var texture = ImageTexture.new()
	texture.create_from_image(image)
	return texture

func _on_player_entered(body):
	if body.is_in_group("player"):
		player_in_range = true
		player_ref = body
		show_hover_effect()
		show_upgrade_hint()
		print("🏠 Player entered upgrade station range")

func _on_player_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
		player_ref = null
		hide_hover_effect()
		hide_upgrade_hint()
		print("🏠 Player left upgrade station range")

func _on_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if player_in_range and player_ref:
			open_upgrade_menu()

func show_hover_effect():
	# Scale up slightly to indicate interactability
	if hover_scale_tween:
		hover_scale_tween.kill()
	hover_scale_tween = create_tween()
	hover_scale_tween.tween_property(self, "scale", original_scale * 1.1, 0.2)

func hide_hover_effect():
	# Scale back to normal
	if hover_scale_tween:
		hover_scale_tween.kill()
	hover_scale_tween = create_tween()
	hover_scale_tween.tween_property(self, "scale", original_scale, 0.2)

func show_upgrade_hint():
	# Create floating text hint
	var hint_label = Label.new()
	hint_label.text = "Clique para melhorar ferramentas"
	hint_label.add_theme_color_override("font_color", Color.YELLOW)
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.position = Vector2(-60, -40)  # Above the station
	hint_label.name = "UpgradeHint"
	add_child(hint_label)
	
	# Floating animation
	var float_tween = create_tween()
	float_tween.set_loops()
	float_tween.tween_property(hint_label, "position:y", hint_label.position.y - 5, 1.0)
	float_tween.tween_property(hint_label, "position:y", hint_label.position.y, 1.0)

func hide_upgrade_hint():
	var hint = get_node_or_null("UpgradeHint")
	if hint:
		hint.queue_free()

func open_upgrade_menu():
	if not player_ref:
		return
		
	print("🔨 Opening upgrade menu for tree damage")
	
	# Get current upgrade cost
	var costs = player_ref.get_upgrade_cost()
	var cost_wood = costs[0]
	var cost_stone = costs[1]
	var current_level = player_ref.tree_damage_level
	var current_damage = player_ref.get_tree_damage()
	
	# Create upgrade dialog
	var dialog = AcceptDialog.new()
	dialog.title = "Estação de Upgrade - Dano em Árvores"
	dialog.size = Vector2(400, 300)
	
	# Center dialog on screen
	var viewport_size = get_viewport().size
	dialog.position = (viewport_size - dialog.size) / 2
	
	# Create content
	var vbox = VBoxContainer.new()
	
	# Current stats
	var stats_label = Label.new()
	stats_label.text = "Nível Atual: %d\nDano Atual: %.1f\n" % [current_level, current_damage]
	stats_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(stats_label)
	
	# Next level info
	var next_damage = player_ref.tree_damage_base * (current_level + 1)
	var next_label = Label.new()
	next_label.text = "Próximo Nível: %d\nPróximo Dano: %.1f\n" % [current_level + 1, next_damage]
	next_label.add_theme_color_override("font_color", Color.CYAN)
	vbox.add_child(next_label)
	
	# Cost info
	var cost_label = Label.new()
	cost_label.text = "Custo do Upgrade:\n%d Madeira\n%d Pedra" % [cost_wood, cost_stone]
	cost_label.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(cost_label)
	
	# Current resources
	var wood_count = player_ref.get_item_count("wood")
	var stone_count = player_ref.get_item_count("stone")
	var resources_label = Label.new()
	resources_label.text = "\nRecursos Atuais:\n%d Madeira\n%d Pedra" % [wood_count, stone_count]
	
	# Color based on availability
	var has_enough = wood_count >= cost_wood and stone_count >= cost_stone
	resources_label.add_theme_color_override("font_color", Color.GREEN if has_enough else Color.RED)
	vbox.add_child(resources_label)
	
	# Upgrade button
	var upgrade_btn = Button.new()
	upgrade_btn.text = "Melhorar!" if has_enough else "Recursos Insuficientes"
	upgrade_btn.disabled = not has_enough
	upgrade_btn.pressed.connect(_on_upgrade_pressed.bind(dialog))
	vbox.add_child(upgrade_btn)
	
	dialog.add_child(vbox)
	get_tree().current_scene.add_child(dialog)
	dialog.popup_centered()

func _on_upgrade_pressed(dialog: AcceptDialog):
	if player_ref and player_ref.upgrade_tree_damage():
		dialog.queue_free()
		
		# Show success effect
		show_upgrade_success_effect()
		
		# Update HUD if it exists
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("update_inventory"):
			hud.update_inventory()
	else:
		print("❌ Upgrade failed")

func show_upgrade_success_effect():
	# Create success particles or visual feedback
	var success_label = Label.new()
	success_label.text = "UPGRADE REALIZADO!"
	success_label.add_theme_color_override("font_color", Color.GREEN)
	success_label.add_theme_font_size_override("font_size", 16)
	success_label.position = Vector2(-70, -60)
	add_child(success_label)
	
	# Animate success text
	var success_tween = create_tween()
	success_tween.parallel().tween_property(success_label, "position:y", success_label.position.y - 30, 2.0)
	success_tween.parallel().tween_property(success_label, "modulate:a", 0.0, 2.0)
	success_tween.tween_callback(success_label.queue_free)
	
	print("✅ Upgrade success effect shown")