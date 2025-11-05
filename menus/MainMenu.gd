extends Control

# Menu principal do jogo

@onready var new_game_btn = $MenuContainer/VBoxContainer/ButtonsContainer/NewGameButton
@onready var continue_btn = $MenuContainer/VBoxContainer/ButtonsContainer/ContinueButton
@onready var options_btn = $MenuContainer/VBoxContainer/ButtonsContainer/OptionsButton
@onready var quit_btn = $MenuContainer/VBoxContainer/ButtonsContainer/QuitButton

func _ready():
	# Verifica se existe save para habilitar botão continuar
	var player_scene = preload("res://character_body_2d.tscn")
	var player_instance = player_scene.instantiate()
	continue_btn.disabled = not player_instance.save_exists()
	player_instance.queue_free()
	
	# Conecta botões
	new_game_btn.pressed.connect(_on_new_game_pressed)
	continue_btn.pressed.connect(_on_continue_pressed)
	options_btn.pressed.connect(_on_options_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	
	# Estilo dos botões (alinhamento à esquerda)
	_style_buttons()
	
	# Inicia animações de fundo
	_start_background_animations()

func _start_background_animations():
	# Anima as árvores de fundo para dar sensação de movimento
	var trees = [
		$AnimatedBackground/TreeSprite1,
		$AnimatedBackground/TreeSprite2,
		$AnimatedBackground/TreeSprite3,
		$AnimatedBackground/TreeSprite4
	]
	
	for i in range(trees.size()):
		var tree = trees[i]
		var tween = create_tween()
		tween.set_loops()
		
		# Movimento sutil oscilante
		var start_pos = tree.position
		var end_pos = start_pos + Vector2(randf_range(-10, 10), randf_range(-5, 5))
		
		tween.tween_property(tree, "position", end_pos, randf_range(3.0, 5.0))
		tween.tween_property(tree, "position", start_pos, randf_range(3.0, 5.0))
		
		# Modulate para criar efeito de "respiração"
		var tween2 = create_tween()
		tween2.set_loops()
		var base_alpha = tree.modulate.a
		tween2.tween_property(tree, "modulate:a", base_alpha * 0.7, randf_range(2.0, 4.0))
		tween2.tween_property(tree, "modulate:a", base_alpha, randf_range(2.0, 4.0))

func _style_buttons():
	# Aplica estilo aos títulos
	var title_label = $MenuContainer/VBoxContainer/TitleLabel
	var subtitle_label = $MenuContainer/VBoxContainer/SubtitleLabel
	
	title_label.add_theme_font_size_override("font_size", 64)
	title_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9))
	
	subtitle_label.add_theme_font_size_override("font_size", 20)
	subtitle_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	
	# Estilo dos botões
	var buttons = [new_game_btn, continue_btn, options_btn, quit_btn]
	for button in buttons:
		button.add_theme_font_size_override("font_size", 18)
		
		# Animação de hover
		button.mouse_entered.connect(_on_button_hover.bind(button))
		button.mouse_exited.connect(_on_button_unhover.bind(button))

func _on_button_hover(button: Button):
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.1)
	tween.tween_property(button, "modulate", Color(1.2, 1.2, 1.2), 0.1)

func _on_button_unhover(button: Button):
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_property(button, "modulate", Color.WHITE, 0.1)

func _on_new_game_pressed():
	print("🎮 Iniciando novo jogo...")
	get_tree().change_scene_to_file("res://main.tscn")

func _on_continue_pressed():
	print("📂 Continuando jogo salvo...")
	# Define flag para carregar o save
	get_tree().set_meta("load_save", true)
	get_tree().change_scene_to_file("res://main.tscn")

func _on_options_pressed():
	print("🔧 Abrindo opções...")
	# TODO: Implementar menu de opções

func _on_quit_pressed():
	print("👋 Saindo do jogo...")
	get_tree().quit()
