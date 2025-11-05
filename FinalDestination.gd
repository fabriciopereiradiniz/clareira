extends Node2D

signal game_completed

var detection_area: Area2D = null
var required_wood = 100
var required_stone = 50
var is_completed = false
var check_timer = 0.0

func _ready():
	# Visual da construção
	create_destination_visual()
	
	# Cria área de detecção grande (7x7 tiles = 224x224 pixels se tile = 32)
	create_detection_area()
	
	print("🏁 Destino final criado na posição: ", global_position)
	print("🔍 Área de detecção: 7x7 tiles (grande)")

func create_destination_visual():
	# Base circular (pedestal)
	var base_sprite = Sprite2D.new()
	var base_texture = create_circle_texture(60, Color(0.4, 0.3, 0.2))  # Marrom
	base_sprite.texture = base_texture
	base_sprite.position = Vector2(0, 10)
	add_child(base_sprite)
	
	# Portal/monumento principal
	var portal = Node2D.new()
	portal.name = "Portal"
	add_child(portal)
	
	# Colunas do portal
	for i in range(2):
		var column = ColorRect.new()
		column.size = Vector2(15, 80)
		column.color = Color(0.6, 0.5, 0.4)  # Pedra
		column.position = Vector2(-40 + i * 65, -50)
		portal.add_child(column)
	
	# Topo do portal
	var top = ColorRect.new()
	top.size = Vector2(90, 15)
	top.color = Color(0.6, 0.5, 0.4)
	top.position = Vector2(-45, -65)
	portal.add_child(top)
	
	# Emoji de troféu/objetivo
	var trophy_label = Label.new()
	trophy_label.text = "🏆"
	trophy_label.add_theme_font_size_override("font_size", 48)
	trophy_label.position = Vector2(-24, -45)
	trophy_label.name = "Trophy"
	add_child(trophy_label)
	
	# Efeito de brilho pulsante
	var glow_tween = create_tween()
	glow_tween.set_loops()
	glow_tween.tween_property(trophy_label, "modulate:a", 0.5, 1.5)
	glow_tween.tween_property(trophy_label, "modulate:a", 1.0, 1.5)
	
	# Partículas místicas
	var particles = CPUParticles2D.new()
	particles.name = "MysticParticles"
	particles.emitting = true
	particles.amount = 20
	particles.lifetime = 2.0
	particles.local_coords = false
	particles.position = Vector2(0, -30)
	
	particles.direction = Vector2(0, -1)
	particles.spread = 180
	particles.initial_velocity_min = 10.0
	particles.initial_velocity_max = 30.0
	particles.gravity = Vector2(0, -20)
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color.GOLD)
	gradient.add_point(0.5, Color.CYAN)
	gradient.add_point(1.0, Color.TRANSPARENT)
	particles.color_ramp = gradient
	
	add_child(particles)
	
	# Texto informativo
	create_info_label()

func create_detection_area():
	# Cria uma área de detecção 7x7 tiles (assumindo 32x32 por tile)
	detection_area = Area2D.new()
	detection_area.name = "DetectionArea"
	detection_area.monitoring = true
	detection_area.monitorable = true
	
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(224, 224)  # 7 tiles * 32 pixels = 224
	collision.shape = shape
	
	detection_area.add_child(collision)
	add_child(detection_area)
	
	# Visual da área de detecção (para debug)
	var debug_rect = ColorRect.new()
	debug_rect.size = Vector2(224, 224)
	debug_rect.position = Vector2(-112, -112)  # Centraliza
	debug_rect.color = Color(0, 1, 0, 0.1)  # Verde semi-transparente
	detection_area.add_child(debug_rect)
	
	print("✅ Área de detecção criada: 224x224 pixels (7x7 tiles)")

func create_info_label():
	var info_label = Label.new()
	info_label.name = "InfoLabel"
	info_label.text = "🏆 DESTINO FINAL 🏆\nEntre na área verde para vencer!"
	info_label.add_theme_font_size_override("font_size", 18)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.position = Vector2(-120, 120)
	info_label.size = Vector2(240, 80)
	info_label.modulate = Color.GREEN
	add_child(info_label)

func create_circle_texture(radius: int, color: Color) -> ImageTexture:
	var img = Image.create(radius * 2, radius * 2, false, Image.FORMAT_RGBA8)
	for x in range(radius * 2):
		for y in range(radius * 2):
			var dx = x - radius
			var dy = y - radius
			if dx * dx + dy * dy <= radius * radius:
				img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)

func _process(delta):
	if is_completed:
		return
	
	# Verifica continuamente se o jogador está na área
	check_timer += delta
	if check_timer >= 0.1:  # Verifica a cada 0.1 segundos
		check_timer = 0.0
		check_player_in_area()

func check_player_in_area():
	if not detection_area:
		return
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	# Calcula distância do jogador ao centro do destino
	var distance = global_position.distance_to(player.global_position)
	var is_inside = distance <= 112  # Metade de 224 = raio da área
	
	if is_inside:
		print("🎯 Player dentro da área! Distância: ", distance)
		# Completa o jogo automaticamente (só uma vez)
		if not is_completed:
			attempt_completion(player)
	else:
		# Limpa label se estiver longe
		var info_label = get_node_or_null("InfoLabel")
		if info_label and distance > 150:
			info_label.text = "🏆 DESTINO FINAL 🏆\nEntre na área verde!"



func attempt_completion(player):
	if not player:
		return
	
	print("✅✅✅ PLAYER ENTROU NA ÁREA! FINALIZANDO JOGO! ✅✅✅")
	
	# Marca como completo
	is_completed = true
	
	# Esconde o label de info
	var info_label = get_node_or_null("InfoLabel")
	if info_label:
		info_label.visible = false
	
	# Efeito visual de conclusão
	play_completion_effect()
	
	# Emite sinal
	emit_signal("game_completed")
	
	print("🎉 JOGO COMPLETADO!")
	print("🎉 Mostrando diálogo de vitória em 2 segundos...")
	
	# Mostra tela de vitória (chama diretamente após aguardar)
	await get_tree().create_timer(2.0).timeout
	print("🎉 Criando diálogo de vitória agora!")
	show_victory_dialog()

func play_completion_effect():
	# Partículas explosivas
	var particles = get_node_or_null("MysticParticles")
	if particles:
		particles.amount = 100
		particles.initial_velocity_max = 100.0
	
	# Troféu aumenta e gira
	var trophy = get_node_or_null("Trophy")
	if trophy:
		var trophy_tween = create_tween()
		trophy_tween.set_parallel(true)
		trophy_tween.tween_property(trophy, "scale", Vector2(2, 2), 1.0)
		trophy_tween.tween_property(trophy, "rotation", TAU, 1.0)

func show_victory_screen():
	# Aguarda um pouco antes de mostrar o diálogo
	await get_tree().create_timer(2.0).timeout
	show_victory_dialog()

func show_victory_dialog():
	print("🎨 show_victory_dialog() INICIADO!")
	
	# Remove diálogo anterior se existir
	var old_dialog = get_tree().root.get_node_or_null("VictoryDialog")
	if old_dialog:
		print("🗑️ Removendo diálogo antigo")
		old_dialog.queue_free()
	
	print("🎨 Criando CanvasLayer...")
	# Cria canvas layer para UI
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "VictoryDialog"
	canvas_layer.layer = 100
	get_tree().root.add_child(canvas_layer)
	print("✅ CanvasLayer adicionado à árvore!")
	
	# Fundo escuro semi-transparente
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.size = Vector2(1200, 700)
	canvas_layer.add_child(overlay)
	
	# Painel principal
	var victory_panel = Panel.new()
	victory_panel.position = Vector2(300, 150)
	victory_panel.size = Vector2(600, 400)
	canvas_layer.add_child(victory_panel)
	
	# Container vertical para organizar conteúdo
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(50, 30)
	vbox.size = Vector2(500, 340)
	vbox.add_theme_constant_override("separation", 20)
	victory_panel.add_child(vbox)
	
	# Título
	var title_label = Label.new()
	title_label.text = "🎉 PARABÉNS! 🎉"
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)
	
	# Mensagem de vitória
	var message_label = Label.new()
	message_label.text = "Você completou o jogo!\n\nVocê alcançou o destino final!"
	message_label.add_theme_font_size_override("font_size", 22)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(message_label)
	
	# Espaçador
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)
	
	# Container horizontal para botões
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 30)
	vbox.add_child(hbox)
	
	# Botão Reiniciar
	var restart_button = Button.new()
	restart_button.text = "🔄 Reiniciar Jogo"
	restart_button.custom_minimum_size = Vector2(200, 50)
	restart_button.pressed.connect(_on_restart_pressed.bind(canvas_layer))
	hbox.add_child(restart_button)
	
	# Botão Menu Principal
	var menu_button = Button.new()
	menu_button.text = "🏠 Menu Principal"
	menu_button.custom_minimum_size = Vector2(200, 50)
	menu_button.pressed.connect(_on_menu_pressed.bind(canvas_layer))
	hbox.add_child(menu_button)
	
	print("✅ Diálogo de vitória criado!")

func _on_restart_pressed(dialog):
	print("🔄 Reiniciando jogo...")
	dialog.queue_free()
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_menu_pressed(dialog):
	print("🏠 Voltando ao menu principal...")
	dialog.queue_free()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://menus/MainMenu.tscn")
