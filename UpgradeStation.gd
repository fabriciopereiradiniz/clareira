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
	
	# Setup visual sprite (removido - usando emoji agora)
	# var sprite = Sprite2D.new()
	# sprite.texture = create_upgrade_station_texture()
	# add_child(sprite)
	
	# Adiciona emoji de casa gigante
	create_shop_visual()
	
	# Adiciona indicador de direção para o destino final
	create_destination_indicator()
	
	# Connect signals
	body_entered.connect(_on_player_entered)
	body_exited.connect(_on_player_exited)
	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	print("🏠 Upgrade Station created at position: ", global_position)

func create_shop_visual():
	# Casa gigante no centro
	var house_label = Label.new()
	house_label.text = "🏠"
	house_label.add_theme_font_size_override("font_size", 48)  # Casa bem grande
	house_label.position = Vector2(-24, -40)
	house_label.name = "HouseEmoji"
	add_child(house_label)
	
	# Pessoa 1 - à esquerda, andando
	var person1 = Label.new()
	person1.text = "🚶"
	person1.add_theme_font_size_override("font_size", 20)
	person1.position = Vector2(-45, -10)
	person1.name = "Person1"
	add_child(person1)
	
	# Animação de andar para pessoa 1
	var walk_tween1 = create_tween()
	walk_tween1.set_loops()
	walk_tween1.tween_property(person1, "position:x", person1.position.x + 10, 1.5)
	walk_tween1.tween_property(person1, "position:x", person1.position.x, 1.5)
	
	# Pessoa 2 - à direita, andando
	var person2 = Label.new()
	person2.text = "🚶"
	person2.add_theme_font_size_override("font_size", 20)
	person2.position = Vector2(25, -10)
	person2.name = "Person2"
	add_child(person2)
	
	# Animação de andar para pessoa 2 (oposta)
	var walk_tween2 = create_tween()
	walk_tween2.set_loops()
	walk_tween2.tween_property(person2, "position:x", person2.position.x - 10, 1.5)
	walk_tween2.tween_property(person2, "position:x", person2.position.x, 1.5)
	
	# Pessoa 3 - trabalhando com martelo
	var person3 = Label.new()
	person3.text = "🔨"
	person3.add_theme_font_size_override("font_size", 18)
	person3.position = Vector2(-10, 10)
	person3.name = "Person3"
	add_child(person3)
	
	# Animação de trabalho para pessoa 3
	var work_tween = create_tween()
	work_tween.set_loops()
	work_tween.tween_property(person3, "rotation", 0.3, 0.3)
	work_tween.tween_property(person3, "rotation", -0.3, 0.3)
	work_tween.tween_property(person3, "rotation", 0.0, 0.3)
	work_tween.tween_interval(1.0)

func create_destination_indicator():
	# Aguarda um pouco para garantir que o tilemap está pronto
	await get_tree().create_timer(0.5).timeout
	
	# Busca APENAS o destino REAL (ignora o de teste)
	var real_destination = get_tree().root.find_child("FinalDestination_Real", true, false)
	if not real_destination:
		print("⚠️ Destino final REAL ainda não foi criado")
		return
	
	var destination_pos = real_destination.global_position
	
	# Calcula direção do destino
	var direction = (destination_pos - global_position).normalized()
	var angle = direction.angle()
	var distance = global_position.distance_to(destination_pos)
	
	# Cria seta apontando para o destino
	var arrow = Label.new()
	arrow.text = "➤"
	arrow.add_theme_font_size_override("font_size", 32)
	arrow.position = Vector2(-16, -80)
	arrow.rotation = angle
	arrow.name = "DestinationArrow"
	arrow.modulate = Color.GOLD
	add_child(arrow)
	
	# Animação pulsante na seta
	var pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(arrow, "scale", Vector2(1.3, 1.3), 0.8)
	pulse_tween.tween_property(arrow, "scale", Vector2(1.0, 1.0), 0.8)
	
	# Label com distância
	var distance_label = Label.new()
	distance_label.text = "🏆 %.0fm" % (distance / 32.0)  # Converte pixels em "metros" (tiles)
	distance_label.add_theme_font_size_override("font_size", 14)
	distance_label.position = Vector2(-30, -100)
	distance_label.name = "DistanceLabel"
	distance_label.modulate = Color.GOLD
	add_child(distance_label)
	
	print("🧭 Seta de direção criada: ", rad_to_deg(angle), "° | Distância: ", distance / 32.0, " tiles")

func create_upgrade_station_texture() -> ImageTexture:
	# Mantido para compatibilidade mas não usado mais
	var image = Image.create(32, 32, false, Image.FORMAT_RGB8)
	image.fill(Color.BROWN)
	var texture = ImageTexture.new()
	texture.create_from_image(image)
	return texture

func _on_player_entered(body):
	if body.is_in_group("player"):
		player_in_range = true
		player_ref = body
		show_hover_effect()
		show_upgrade_hint()
		show_click_indicator()
		print("🏠 Player entered upgrade station range")

func _on_player_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
		player_ref = null
		hide_hover_effect()
		hide_upgrade_hint()
		hide_click_indicator()
		print("🏠 Player left upgrade station range")

func _on_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if player_in_range and player_ref:
			open_upgrade_menu()

func _on_mouse_entered():
	# Efeito quando o mouse passa por cima
	if player_in_range:
		var mouse_tween = create_tween()
		mouse_tween.tween_property(self, "modulate", Color(2.0, 1.8, 0.8), 0.2)  # Brilho intenso dourado
		print("🖱️ Mouse sobre a estação de upgrade")

func _on_mouse_exited():
	# Volta ao estado normal quando o mouse sai
	if player_in_range:
		var mouse_tween = create_tween()
		mouse_tween.tween_property(self, "modulate", Color(1.5, 1.3, 0.5), 0.2)  # Volta ao brilho normal
		print("🖱️ Mouse saiu da estação de upgrade")

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
	# Create main "CLICK HERE" label
	var click_label = Label.new()
	click_label.text = "🏪 LOJA ABERTA! 🏪"
	click_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))  # Dourado
	click_label.add_theme_font_size_override("font_size", 18)
	click_label.position = Vector2(-65, -70)
	click_label.name = "ClickHereLabel"
	add_child(click_label)
	
	# Pulsing animation for CLICK HERE
	var pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(click_label, "scale", Vector2(1.2, 1.2), 0.5)
	pulse_tween.tween_property(click_label, "scale", Vector2(1.0, 1.0), 0.5)
	
	# Color animation for CLICK HERE (rainbow effect)
	var color_tween = create_tween()
	color_tween.set_loops()
	color_tween.tween_property(click_label, "modulate", Color(1.0, 0.84, 0.0), 0.5)  # Dourado
	color_tween.tween_property(click_label, "modulate", Color(1.0, 0.5, 0.0), 0.5)   # Laranja
	color_tween.tween_property(click_label, "modulate", Color(1.0, 1.0, 0.0), 0.5)   # Amarelo
	
	# Create floating text hint
	var hint_label = Label.new()
	hint_label.text = "[Botão Esquerdo] Comprar Upgrades"
	hint_label.add_theme_color_override("font_color", Color.YELLOW)
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.position = Vector2(-75, -45)  # Below the SHOP OPEN
	hint_label.name = "UpgradeHint"
	add_child(hint_label)
	
	# Floating animation
	var float_tween = create_tween()
	float_tween.set_loops()
	float_tween.tween_property(hint_label, "position:y", hint_label.position.y - 5, 1.0)
	float_tween.tween_property(hint_label, "position:y", hint_label.position.y, 1.0)

func hide_upgrade_hint():
	var click_label = get_node_or_null("ClickHereLabel")
	if click_label:
		click_label.queue_free()
	
	var hint = get_node_or_null("UpgradeHint")
	if hint:
		hint.queue_free()

func show_click_indicator():
	# Muda a cor da estação para indicar onde clicar
	var color_tween = create_tween()
	color_tween.set_loops()
	color_tween.tween_property(self, "modulate", Color(1.5, 1.3, 0.5), 0.8)  # Amarelo dourado brilhante
	color_tween.tween_property(self, "modulate", Color(1.0, 0.8, 0.3), 0.8)  # Laranja dourado
	
	# Cria setas piscando apontando para a estação
	create_arrow_indicators()
	
	# Cria círculo pulsante ao redor da estação
	create_pulse_circle()

func hide_click_indicator():
	# Volta a cor normal
	var color_tween = create_tween()
	color_tween.tween_property(self, "modulate", Color.WHITE, 0.3)
	
	# Remove setas
	var arrow_container = get_node_or_null("ArrowIndicators")
	if arrow_container:
		arrow_container.queue_free()
	
	# Remove círculo
	var pulse_circle = get_node_or_null("PulseCircle")
	if pulse_circle:
		pulse_circle.queue_free()

func create_arrow_indicators():
	# Container para as setas
	var arrow_container = Node2D.new()
	arrow_container.name = "ArrowIndicators"
	add_child(arrow_container)
	
	# Cria 4 setas apontando para o centro (cima, baixo, esquerda, direita)
	var arrow_positions = [
		Vector2(0, -50),   # Cima
		Vector2(0, 50),    # Baixo
		Vector2(-50, 0),   # Esquerda
		Vector2(50, 0)     # Direita
	]
	
	var arrow_rotations = [
		PI,      # Cima (aponta para baixo)
		0,       # Baixo (aponta para cima)
		PI/2,    # Esquerda (aponta para direita)
		-PI/2    # Direita (aponta para esquerda)
	]
	
	for i in range(4):
		var arrow = create_arrow()
		arrow.position = arrow_positions[i]
		arrow.rotation = arrow_rotations[i]
		arrow_container.add_child(arrow)
		
		# Animação de pulso para cada seta
		var arrow_tween = create_tween()
		arrow_tween.set_loops()
		arrow_tween.tween_property(arrow, "modulate:a", 1.0, 0.5)
		arrow_tween.tween_property(arrow, "modulate:a", 0.3, 0.5)
		
		# Animação de movimento (aproximando do centro)
		var move_tween = create_tween()
		move_tween.set_loops()
		var target_offset = arrow_positions[i] * 0.7  # Move 30% em direção ao centro
		move_tween.tween_property(arrow, "position", target_offset, 0.8)
		move_tween.tween_property(arrow, "position", arrow_positions[i], 0.8)

func create_arrow():
	# Cria uma seta visual usando Polygon2D
	var arrow = Polygon2D.new()
	var points = PackedVector2Array([
		Vector2(0, -10),   # Ponta
		Vector2(-8, 5),    # Base esquerda
		Vector2(0, 0),     # Centro
		Vector2(8, 5)      # Base direita
	])
	arrow.polygon = points
	arrow.color = Color(1.0, 0.84, 0.0)  # Dourado
	return arrow

func create_pulse_circle():
	# Cria círculo pulsante ao redor da estação
	var circle = Node2D.new()
	circle.name = "PulseCircle"
	add_child(circle)
	
	# Desenha o círculo usando Line2D
	var line = Line2D.new()
	line.width = 3
	line.default_color = Color(1.0, 0.84, 0.0, 0.8)  # Dourado semi-transparente
	
	# Cria pontos do círculo
	var num_points = 32
	var radius = 40
	for i in range(num_points + 1):
		var angle = (i * 2 * PI) / num_points
		var point = Vector2(cos(angle), sin(angle)) * radius
		line.add_point(point)
	
	circle.add_child(line)
	
	# Animação de pulso (escala)
	var pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(circle, "scale", Vector2(1.3, 1.3), 0.8)
	pulse_tween.tween_property(circle, "scale", Vector2(1.0, 1.0), 0.8)
	
	# Animação de fade
	var fade_tween = create_tween()
	fade_tween.set_loops()
	fade_tween.tween_property(line, "default_color:a", 0.3, 0.8)
	fade_tween.tween_property(line, "default_color:a", 0.8, 0.8)

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
	dialog.title = "🏪 LOJA DE UPGRADES - MACHADO 🪓"
	dialog.size = Vector2(450, 380)
	
	# Center dialog on screen
	var viewport_size = get_viewport().size
	dialog.position = (viewport_size - dialog.size) / 2
	
	# Create content
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	
	# Título da loja
	var shop_title = Label.new()
	shop_title.text = "═══════════════════════════════"
	shop_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	shop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(shop_title)
	
	# Descrição
	var desc_label = Label.new()
	desc_label.text = "Melhore seu machado para causar mais dano!"
	desc_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc_label)
	
	# Separador
	var separator1 = HSeparator.new()
	vbox.add_child(separator1)
	
	# Current stats
	var stats_label = Label.new()
	stats_label.text = "📊 STATUS ATUAL:\nNível: %d | Dano: %.1f" % [current_level, current_damage]
	stats_label.add_theme_color_override("font_color", Color.CYAN)
	stats_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(stats_label)
	
	# Separador
	var separator2 = HSeparator.new()
	vbox.add_child(separator2)
	
	# Next level info
	var next_damage = player_ref.tree_damage_base * (current_level + 1)
	var next_label = Label.new()
	next_label.text = "⬆️ PRÓXIMO UPGRADE:\nNível: %d | Dano: %.1f" % [current_level + 1, next_damage]
	next_label.add_theme_color_override("font_color", Color.GREEN)
	next_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(next_label)
	
	# Separador
	var separator3 = HSeparator.new()
	vbox.add_child(separator3)
	
	# Cost info com ícones
	var cost_title = Label.new()
	cost_title.text = "💰 CUSTO DO UPGRADE:"
	cost_title.add_theme_color_override("font_color", Color.YELLOW)
	cost_title.add_theme_font_size_override("font_size", 12)
	vbox.add_child(cost_title)
	
	var cost_detail = Label.new()
	cost_detail.text = "  🪵 %d Madeira\n  🪨 %d Pedra" % [cost_wood, cost_stone]
	cost_detail.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(cost_detail)
	
	# Current resources
	var wood_count = player_ref.get_item_count("wood")
	var stone_count = player_ref.get_item_count("stone")
	
	var resources_title = Label.new()
	resources_title.text = "🎒 SEUS RECURSOS:"
	resources_title.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	resources_title.add_theme_font_size_override("font_size", 12)
	vbox.add_child(resources_title)
	
	# Color based on availability
	var has_enough = wood_count >= cost_wood and stone_count >= cost_stone
	
	var resources_detail = Label.new()
	resources_detail.text = "  🪵 %d Madeira %s\n  🪨 %d Pedra %s" % [
		wood_count, 
		"✓" if wood_count >= cost_wood else "✗",
		stone_count,
		"✓" if stone_count >= cost_stone else "✗"
	]
	resources_detail.add_theme_color_override("font_color", Color.GREEN if has_enough else Color.ORANGE)
	vbox.add_child(resources_detail)
	
	# Separador
	var separator4 = HSeparator.new()
	vbox.add_child(separator4)
	
	# Upgrade button estilizado
	var upgrade_btn = Button.new()
	if has_enough:
		upgrade_btn.text = "🔨 COMPRAR UPGRADE! 🔨"
		upgrade_btn.add_theme_color_override("font_color", Color.WHITE)
	else:
		upgrade_btn.text = "❌ Recursos Insuficientes"
		upgrade_btn.add_theme_color_override("font_color", Color.DARK_RED)
	
	upgrade_btn.add_theme_font_size_override("font_size", 14)
	upgrade_btn.disabled = not has_enough
	upgrade_btn.pressed.connect(_on_upgrade_pressed.bind(dialog))
	vbox.add_child(upgrade_btn)
	
	# Nota de rodapé
	var footer = Label.new()
	footer.text = "Volte sempre! A loja está sempre aberta."
	footer.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	footer.add_theme_font_size_override("font_size", 9)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(footer)
	
	dialog.add_child(vbox)
	get_tree().current_scene.add_child(dialog)
	dialog.popup_centered()

func _on_upgrade_pressed(dialog: AcceptDialog):
	if player_ref and player_ref.upgrade_tree_damage():
		print("✅ Upgrade bem sucedido!")
		
		# Show success effect and animation
		show_upgrade_success_effect()
		
		# Update HUD if it exists
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("update_inventory"):
			hud.update_inventory()
			print("✅ Inventário atualizado após upgrade")
		
		# Fecha o dialog atual
		dialog.queue_free()
		
		# Espera um pouco e reabre o menu para mostrar novo nível
		await get_tree().create_timer(1.5).timeout
		if player_in_range and player_ref:
			open_upgrade_menu()
	else:
		print("❌ Upgrade falhou - recursos insuficientes ou erro no player")
		
		# Mostra feedback de erro no dialog
		show_insufficient_resources_feedback(dialog)

func show_insufficient_resources_feedback(dialog: AcceptDialog):
	# Adiciona feedback visual de recursos insuficientes
	var error_label = Label.new()
	error_label.text = "❌ Recursos Insuficientes!"
	error_label.add_theme_color_override("font_color", Color.RED)
	error_label.add_theme_font_size_override("font_size", 14)
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Adiciona ao dialog
	dialog.add_child(error_label)
	
	# Anima o texto de erro
	var error_tween = create_tween()
	error_tween.set_loops(3)
	error_tween.tween_property(error_label, "modulate:a", 0.3, 0.3)
	error_tween.tween_property(error_label, "modulate:a", 1.0, 0.3)

func show_upgrade_success_effect():
	var new_damage = player_ref.get_tree_damage() if player_ref else 0
	var new_level = player_ref.tree_damage_level if player_ref else 0
	
	# Animação de brilho na estação (não se destrói mais)
	var flash_tween = create_tween()
	flash_tween.set_loops(3)
	flash_tween.tween_property(self, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.2)
	flash_tween.tween_property(self, "modulate", Color(1.5, 1.3, 0.5), 0.2)  # Volta ao brilho dourado normal
	
	# Partículas de sucesso
	create_success_particles()
	
	# Mensagem principal de upgrade
	var success_label = Label.new()
	success_label.text = "✨ UPGRADE COMPLETO! ✨"
	success_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))  # Dourado
	success_label.add_theme_font_size_override("font_size", 20)
	success_label.position = Vector2(-90, -80)
	success_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	success_label.z_index = 1000
	get_tree().current_scene.add_child(success_label)
	
	# Informação de nível
	var level_label = Label.new()
	level_label.text = "Nível do Machado: %d" % new_level
	level_label.add_theme_color_override("font_color", Color.CYAN)
	level_label.add_theme_font_size_override("font_size", 16)
	level_label.position = Vector2(-70, -55)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.z_index = 1000
	get_tree().current_scene.add_child(level_label)
	
	# Informação de dano
	var damage_label = Label.new()
	damage_label.text = "Novo Dano: %.1f" % new_damage
	damage_label.add_theme_color_override("font_color", Color.GREEN)
	damage_label.add_theme_font_size_override("font_size", 16)
	damage_label.position = Vector2(-55, -35)
	damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	damage_label.z_index = 1000
	get_tree().current_scene.add_child(damage_label)
	
	# Converte posições locais para globais
	success_label.global_position = global_position + success_label.position
	level_label.global_position = global_position + level_label.position
	damage_label.global_position = global_position + damage_label.position
	
	# Animação dos textos
	var success_tween = create_tween()
	success_tween.set_parallel(true)
	success_tween.tween_property(success_label, "position:y", success_label.position.y - 40, 2.5)
	success_tween.tween_property(success_label, "modulate:a", 0.0, 2.5)
	
	var level_tween = create_tween()
	level_tween.set_parallel(true)
	level_tween.tween_property(level_label, "position:y", level_label.position.y - 35, 2.5)
	level_tween.tween_property(level_label, "modulate:a", 0.0, 2.5)
	
	var damage_tween = create_tween()
	damage_tween.set_parallel(true)
	damage_tween.tween_property(damage_label, "position:y", damage_label.position.y - 30, 2.5)
	damage_tween.tween_property(damage_label, "modulate:a", 0.0, 2.5)
	
	# Remove os labels após animação
	await success_tween.finished
	success_label.queue_free()
	level_label.queue_free()
	damage_label.queue_free()
	
	print("✅ Upgrade success effect shown - Nível: ", new_level, " | Novo dano: ", new_damage)

func create_success_particles():
	# Cria partículas de celebração
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 30
	particles.lifetime = 1.5
	particles.explosiveness = 0.8
	
	# Configurações visuais
	particles.direction = Vector2(0, -1)
	particles.spread = 180
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 100.0
	particles.gravity = Vector2(0, 98)
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	
	# Cores douradas e brilhantes
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 0.84, 0.0))  # Dourado
	gradient.add_point(0.3, Color(1.0, 1.0, 0.0))   # Amarelo
	gradient.add_point(0.6, Color(0.0, 1.0, 0.5))   # Verde claro
	gradient.add_point(1.0, Color.TRANSPARENT)
	particles.color_ramp = gradient
	
	add_child(particles)
	
	# Remove as partículas após o efeito
	await get_tree().create_timer(2.0).timeout
	particles.queue_free()