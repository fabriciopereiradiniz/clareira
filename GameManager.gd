extends Node

# GameManager - Gerencia menus, pausas e sistema de jogo

var is_paused: bool = false
# Removidos preloads de arquivos que não existem
# var pause_menu_scene = preload("res://menus/PauseMenu.tscn")
# var main_menu_scene = preload("res://menus/MainMenu.tscn")
# var options_menu_scene = preload("res://menus/OptionsMenu.tscn")

var current_pause_menu: CanvasLayer = null
var last_viewport_size: Vector2 = Vector2.ZERO
var fps_display_enabled: bool = false
var fps_label: Label = null

func _ready():
	add_to_group("game_manager")
	process_mode = Node.PROCESS_MODE_ALWAYS  # Continua funcionando quando pausado
	print("🎮 GameManager iniciado e adicionado ao grupo 'game_manager'")
	
	# IMPORTANTE: Define o GameManager para processar input primeiro
	process_priority = 10  # Maior prioridade que o player
	
	# Adiciona input global para pausa como backup
	set_process_input(true)
	
	# Conecta sinal de redimensionamento da janela
	get_tree().get_root().size_changed.connect(_on_viewport_size_changed)
	last_viewport_size = get_viewport().get_visible_rect().size
	
	# Setup FPS display
	setup_fps_display()

func _process(_delta):
	# Atualiza FPS se habilitado
	if fps_display_enabled and fps_label:
		fps_label.text = "FPS: " + str(Engine.get_frames_per_second())

func setup_fps_display():
	fps_label = Label.new()
	fps_label.name = "FPSLabel"
	fps_label.position = Vector2(10, 100)
	fps_label.add_theme_font_size_override("font_size", 16)
	fps_label.add_theme_color_override("font_color", Color.YELLOW)
	fps_label.z_index = 1000
	fps_label.visible = fps_display_enabled
	get_tree().current_scene.add_child.call_deferred(fps_label)

func toggle_fps_display():
	fps_display_enabled = !fps_display_enabled
	if fps_label:
		fps_label.visible = fps_display_enabled
	print("🔧 FPS Display: ", "Habilitado" if fps_display_enabled else "Desabilitado")

func _on_viewport_size_changed():
	var new_size = get_viewport().get_visible_rect().size
	if new_size != last_viewport_size:
		print("🖥️ Tamanho da janela mudou de ", last_viewport_size, " para ", new_size)
		last_viewport_size = new_size
		
		# Reposiciona menu de pausa se estiver aberto
		if current_pause_menu and is_paused:
			reposition_pause_menu()
		
		# Reposiciona inventário se estiver aberto
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("reposition_inventory"):
			hud.reposition_inventory()

func reposition_pause_menu():
	if not current_pause_menu:
		return
		
	print("🔄 Reposicionando menu de pausa...")
	
	# Encontra o container posicionado dentro do menu
	var positioned_container = current_pause_menu.get_node_or_null("PositionedContainer")
	if not positioned_container:
		# Busca por qualquer Control que não seja o background
		for child in current_pause_menu.get_children():
			if child is Control and child.name != "Background":
				positioned_container = child
				break
	
	if positioned_container:
		# Recalcula posição centralizada na tela
		var viewport_size = get_viewport().get_visible_rect().size
		var panel_size = Vector2(280, 350)
		positioned_container.position = Vector2(
			(viewport_size.x - panel_size.x) / 2,
			(viewport_size.y - panel_size.y) / 2
		)
		print("🎯 Menu reposicionado para: ", positioned_container.position)

func _input(event):
	# Sistema de pausa global - SEMPRE funciona
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		print("🎮 GameManager detectou ESC - pausando/despausando")
		print("🔍 Estado atual - is_paused: ", is_paused, ", current_pause_menu: ", current_pause_menu)
		toggle_pause_menu()
		get_viewport().set_input_as_handled()  # Marca input como processado

func toggle_pause_menu():
	print("🎮 Toggle pause chamado. Estado atual: ", is_paused)
	if is_paused:
		resume_game()
	else:
		pause_game()

func pause_game():
	if is_paused:
		print("⚠️ Jogo já estava pausado")
		return
		
	print("⏸️ Pausando jogo...")
	is_paused = true
	get_tree().paused = true
	
	# Cria menu de pausa
	print("🔨 Criando menu de pausa...")
	current_pause_menu = create_pause_menu()
	if current_pause_menu:
		print("✅ Menu criado com sucesso")
		get_tree().current_scene.add_child(current_pause_menu)
		print("✅ Menu adicionado à cena")
		
		# CanvasLayer doesn't need move_to_front() since it uses layer property
		print("✅ Menu na camada superior (layer 100)")
	else:
		print("❌ ERRO: Menu não foi criado!")
	
	print("⏸️ Jogo pausado - Menu criado")

func resume_game():
	if not is_paused:
		print("⚠️ Jogo já estava despausado")
		return
		
	print("▶️ Despausando jogo...")
	is_paused = false
	get_tree().paused = false
	
	# Remove menu de pausa
	if current_pause_menu:
		print("🗑️ Removendo menu de pausa...")
		current_pause_menu.queue_free()
		current_pause_menu = null
	else:
		print("⚠️ Menu de pausa era null!")
	
	print("▶️ Jogo despausado - Menu removido")

func create_pause_menu() -> CanvasLayer:
	print("🏗️ Iniciando criação do menu de pausa...")
	
	# Create a CanvasLayer for the menu to ensure it appears on top
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "PauseMenuLayer"
	canvas_layer.layer = 100  # High layer to be on top
	canvas_layer.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	var menu = Control.new()
	menu.name = "PauseMenu"
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	canvas_layer.add_child(menu)
	print("🏗️ Menu base criado com CanvasLayer")
	
	# Fundo semi-transparente
	var background = ColorRect.new()
	background.name = "Background"
	background.color = Color(0, 0, 0, 0.8)  # Mais escuro para ser mais visível
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(background)
	print("🏗️ Background adicionado")
	
	# Container centralizado na tela (não baseado no player)
	var positioned_container = Control.new()
	positioned_container.name = "PositionedContainer"
	
	# Centraliza na tela
	var viewport_size = get_viewport().get_visible_rect().size
	var panel_size = Vector2(280, 350)
	positioned_container.position = Vector2(
		(viewport_size.x - panel_size.x) / 2,
		(viewport_size.y - panel_size.y) / 2
	)
	positioned_container.size = panel_size
	menu.add_child(positioned_container)
	print("🏗️ Container posicionado em: ", positioned_container.position)
	
	# Painel de fundo para os botões (melhor centralizado)
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(280, 350)
	panel.size = Vector2(280, 350)
	positioned_container.add_child(panel)
	
	# VBox para conteúdo dentro do painel
	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 12)
	# Centralizar o conteúdo dentro do painel
	content_vbox.position = Vector2(20, 20)
	content_vbox.size = Vector2(240, 310)
	panel.add_child(content_vbox)
	
	# Título PERFEITAMENTE centralizado
	var title = Label.new()
	title.text = "JOGO PAUSADO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.custom_minimum_size = Vector2(240, 50)
	content_vbox.add_child(title)
	
	# Espaçamento
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	content_vbox.add_child(spacer)
	
	# Container para centralizar todos os botões
	var buttons_container = VBoxContainer.new()
	buttons_container.add_theme_constant_override("separation", 8)
	content_vbox.add_child(buttons_container)
	
	# Botão Continuar (PERFEITAMENTE centralizado)
	var resume_btn = Button.new()
	resume_btn.text = "▶ Continuar"
	resume_btn.custom_minimum_size = Vector2(200, 45)
	resume_btn.add_theme_font_size_override("font_size", 16)
	resume_btn.pressed.connect(resume_game)
	# Centralizar o botão
	var resume_center = CenterContainer.new()
	resume_center.add_child(resume_btn)
	buttons_container.add_child(resume_center)
	
	# Botão Opções
	var options_btn = Button.new()
	options_btn.text = "⚙️ Opções"
	options_btn.custom_minimum_size = Vector2(200, 45)
	options_btn.add_theme_font_size_override("font_size", 16)
	options_btn.pressed.connect(show_options)
	var options_center = CenterContainer.new()
	options_center.add_child(options_btn)
	buttons_container.add_child(options_center)
	
	# Botão Menu Principal
	var main_menu_btn = Button.new()
	main_menu_btn.text = "🏠 Menu Principal"
	main_menu_btn.custom_minimum_size = Vector2(200, 45)
	main_menu_btn.add_theme_font_size_override("font_size", 16)
	main_menu_btn.pressed.connect(go_to_main_menu)
	var main_center = CenterContainer.new()
	main_center.add_child(main_menu_btn)
	buttons_container.add_child(main_center)
	
	# Botão Sair
	var quit_btn = Button.new()
	quit_btn.text = "🚪 Sair do Jogo"
	quit_btn.custom_minimum_size = Vector2(200, 45)
	quit_btn.add_theme_font_size_override("font_size", 16)
	quit_btn.pressed.connect(quit_game)
	var quit_center = CenterContainer.new()
	quit_center.add_child(quit_btn)
	buttons_container.add_child(quit_center)
	
	# Foca no botão continuar
	resume_btn.grab_focus()
	
	# Adiciona input handler ao menu para ESC
	menu.gui_input.connect(_on_pause_menu_input)
	
	print("📋 Menu de pausa criado com sucesso")
	return canvas_layer  # Return the CanvasLayer instead of just the menu

func _on_pause_menu_input(event: InputEvent):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		resume_game()

func show_options():
	print("🔧 Abrindo opções...")
	
	# Remove o menu atual
	if current_pause_menu:
		current_pause_menu.queue_free()
		current_pause_menu = null
	
	# Cria menu de opções
	current_pause_menu = create_options_menu()
	get_tree().current_scene.add_child(current_pause_menu)
	# CanvasLayer doesn't need move_to_front() since it uses layer property

func create_options_menu() -> CanvasLayer:
	# Create a CanvasLayer for the options menu
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "OptionsMenuLayer"
	canvas_layer.layer = 100  # High layer to be on top
	canvas_layer.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	var menu = Control.new()
	menu.name = "OptionsMenu"
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	canvas_layer.add_child(menu)
	
	# Fundo semi-transparente
	var background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.8)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(background)
	
	# Container centralizado na tela
	var positioned_container = Control.new()
	positioned_container.name = "PositionedContainer" 
	
	# Centraliza na tela
	var viewport_size = get_viewport().get_visible_rect().size
	var panel_size = Vector2(300, 400)
	positioned_container.position = Vector2(
		(viewport_size.x - panel_size.x) / 2,
		(viewport_size.y - panel_size.y) / 2
	)
	positioned_container.size = panel_size
	menu.add_child(positioned_container)
	
	# Painel de fundo
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(300, 400)
	panel.size = Vector2(300, 400)
	positioned_container.add_child(panel)
	
	# VBox para conteúdo
	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 15)
	content_vbox.position = Vector2(20, 20)
	content_vbox.size = Vector2(260, 360)
	panel.add_child(content_vbox)
	
	# Título
	var title = Label.new()
	title.text = "OPÇÕES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.WHITE)
	content_vbox.add_child(title)
	
	# Slider de Volume Master
	var volume_label = Label.new()
	volume_label.text = "Volume Master"
	volume_label.add_theme_color_override("font_color", Color.WHITE)
	content_vbox.add_child(volume_label)
	
	var volume_slider = HSlider.new()
	volume_slider.min_value = 0
	volume_slider.max_value = 100
	volume_slider.value = 80
	volume_slider.custom_minimum_size = Vector2(220, 30)
	volume_slider.value_changed.connect(_on_volume_changed)
	content_vbox.add_child(volume_slider)
	
	# Checkbox Fullscreen
	var fullscreen_check = CheckBox.new()
	fullscreen_check.text = "Tela Cheia"
	fullscreen_check.add_theme_color_override("font_color", Color.WHITE)
	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	content_vbox.add_child(fullscreen_check)
	
	# Checkbox VSync
	var vsync_check = CheckBox.new()
	vsync_check.text = "VSync"
	vsync_check.add_theme_color_override("font_color", Color.WHITE)
	vsync_check.button_pressed = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	vsync_check.toggled.connect(_on_vsync_toggled)
	content_vbox.add_child(vsync_check)
	
	# Checkbox FPS Display
	var fps_check = CheckBox.new()
	fps_check.text = "Exibir FPS"
	fps_check.add_theme_color_override("font_color", Color.WHITE)
	fps_check.button_pressed = fps_display_enabled
	fps_check.toggled.connect(_on_fps_display_toggled)
	content_vbox.add_child(fps_check)
	
	# Espaçamento
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	content_vbox.add_child(spacer)
	
	# Botão Voltar
	var back_btn = Button.new()
	back_btn.text = "⬅ Voltar"
	back_btn.custom_minimum_size = Vector2(200, 45)
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.pressed.connect(_on_options_back)
	var back_center = CenterContainer.new()
	back_center.add_child(back_btn)
	content_vbox.add_child(back_center)
	
	# Adiciona input handler
	menu.gui_input.connect(_on_options_menu_input)
	
	return canvas_layer  # Return the CanvasLayer instead of just the menu

func _on_volume_changed(value: float):
	# Ajusta o volume master
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value / 100.0))

func _on_fullscreen_toggled(pressed: bool):
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_vsync_toggled(pressed: bool):
	if pressed:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func _on_fps_display_toggled(pressed: bool):
	fps_display_enabled = pressed
	toggle_fps_display()

func _on_options_back():
	print("🔙 Voltando ao menu de pausa...")
	# Remove menu de opções
	if current_pause_menu:
		current_pause_menu.queue_free()
		current_pause_menu = null
	
	# Volta para o menu de pausa
	current_pause_menu = create_pause_menu()
	get_tree().current_scene.add_child(current_pause_menu)
	# CanvasLayer doesn't need move_to_front() since it uses layer property

func _on_options_menu_input(event: InputEvent):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_options_back()

func go_to_main_menu():
	resume_game()  # Despausa antes de trocar de cena
	get_tree().change_scene_to_file("res://menus/MainMenu.tscn")

func quit_game():
	get_tree().quit()

func start_new_game():
	get_tree().change_scene_to_file("res://main.tscn")

func continue_game():
	var player_scene = preload("res://character_body_2d.tscn")
	var player_instance = player_scene.instantiate()
	
	if player_instance.save_exists():
		get_tree().change_scene_to_file("res://main.tscn")
		# O load será chamado pelo player quando a cena carregar
	else:
		print("❌ Nenhum save encontrado!")

func load_game_scene():
	get_tree().change_scene_to_file("res://main.tscn")
