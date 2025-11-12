extends CanvasLayer

# Variáveis para elementos UI (criados dinamicamente)
var health_container: HBoxContainer = null
var score_label: Label = null
var inventory_grid: GridContainer = null

var player: Node2D
var heart_texture = preload("res://heart.png")
var inventory_visible: bool = false
var inventory_panel: Panel = null
var last_viewport_size: Vector2 = Vector2.ZERO

# Sistema de partículas
var mouse_particles: CPUParticles2D = null

func _ready():
	# Adiciona ao grupo HUD
	add_to_group("hud")
	
	# Aguarda um frame para garantir que tudo foi inicializado
	await get_tree().process_frame
	
	# Encontra o player
	player = get_tree().get_first_node_in_group("player")
	if player:
		# Conecta sinais do player
		player.health_changed.connect(_on_health_changed)
		player.score_changed.connect(_on_score_changed)
		player.inventory_changed.connect(_on_inventory_changed)
		player.upgrade_completed.connect(_on_upgrade_completed)
		
		# Inicializa UI
		setup_health_display()
		update_score(player.score)
		setup_inventory_panel()
		update_inventory()
	else:
		print("⚠️ Player não encontrado no HUD")
	
	# Conecta sinal de redimensionamento
	get_tree().get_root().size_changed.connect(_on_viewport_size_changed)
	last_viewport_size = get_viewport().get_visible_rect().size
	
	# Setup sistema de partículas do mouse
	setup_mouse_particles()

func _on_viewport_size_changed():
	var new_size = get_viewport().get_visible_rect().size
	if new_size != last_viewport_size:
		print("🖥️ HUD detectou mudança de tamanho: ", last_viewport_size, " -> ", new_size)
		last_viewport_size = new_size
		
		# Reposiciona inventário se estiver visível
		if inventory_visible and inventory_panel:
			position_inventory_at_player()

func reposition_inventory():
	# Função chamada pelo GameManager quando a tela é redimensionada
	if inventory_visible and inventory_panel:
		position_inventory_at_player()
		print("🔄 Inventário reposicionado pelo GameManager")

func is_inventory_visible() -> bool:
	return inventory_visible

func setup_mouse_particles():
	# Cria sistema de partículas que segue o mouse
	mouse_particles = CPUParticles2D.new()
	mouse_particles.name = "MouseParticles"
	mouse_particles.z_index = 999
	
	# Configurações das partículas
	mouse_particles.emitting = false  # Inicia desligado, só emite quando clicar direito
	mouse_particles.amount = 50
	mouse_particles.lifetime = 2.0
	# Removido emission.rate_hz - não é necessário, será controlado por amount e lifetime
	
	# Propriedades visuais
	mouse_particles.texture = null  # Usa partículas simples
	mouse_particles.direction = Vector2(0, -1)
	mouse_particles.initial_velocity_min = 20.0
	mouse_particles.initial_velocity_max = 50.0
	mouse_particles.gravity = Vector2(0, 30)
	mouse_particles.scale_amount_min = 2.0  # Aumentado de 0.5 para 2.0
	mouse_particles.scale_amount_max = 4.0  # Aumentado de 1.5 para 4.0
	
	# Spread das partículas para efeito mais disperso
	mouse_particles.spread = 45.0
	mouse_particles.angular_velocity_min = -180.0
	mouse_particles.angular_velocity_max = 180.0
	
	# Cores (verde e marrom para árvores)
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color.GREEN)
	gradient.add_point(0.5, Color(0.4, 0.2, 0.1))  # Marrom
	gradient.add_point(1.0, Color.TRANSPARENT)
	mouse_particles.color_ramp = gradient
	
	add_child(mouse_particles)
	
	# Atualiza posição das partículas conforme mouse se move
	set_process(true)

func _process(delta):
	# Atualiza posição das partículas para seguir o mouse
	if mouse_particles:
		mouse_particles.position = get_viewport().get_mouse_position()
		
		# Ativa partículas apenas quando o botão esquerdo do mouse está pressionado
		mouse_particles.emitting = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

# Efeito de pontuação animada
func create_score_effect(score_increase: int):
	var score_effect = Label.new()
	score_effect.text = "+" + str(score_increase)
	score_effect.add_theme_font_size_override("font_size", 24)
	score_effect.add_theme_color_override("font_color", Color.GOLD)
	score_effect.z_index = 1000
	
	# Posiciona próximo ao score label
	if score_label:
		score_effect.position = score_label.position + Vector2(100, 0)
	else:
		score_effect.position = Vector2(200, 50)
	
	add_child(score_effect)
	
	# Animação de flutuação e mudança de cor RGB
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Movimento para cima
	tween.tween_property(score_effect, "position:y", score_effect.position.y - 50, 2.0)
	
	# Fade out
	tween.tween_property(score_effect, "modulate:a", 0.0, 2.0)
	
	# Efeito RGB (mudança de cor)
	var color_tween = create_tween()
	color_tween.set_loops()
	color_tween.tween_method(func(progress: float): change_score_color(score_effect, progress), 0.0, 1.0, 0.5)
	
	# Remove o efeito após 2 segundos
	await tween.finished
	
	# Stop the color tween before freeing the score effect to prevent lambda capture errors
	if color_tween.is_valid():
		color_tween.kill()
	
	score_effect.queue_free()

func change_score_color(score_label: Label, progress: float):
	var hue = progress * 360.0
	var color = Color.from_hsv(hue / 360.0, 1.0, 1.0)
	score_label.add_theme_color_override("font_color", color)

# Cria notificação centralizada na tela
func create_notification(title: String, message: String, color: Color = Color.GOLD):
	var notification_panel = Panel.new()
	notification_panel.name = "UpgradeNotification"
	
	# Estilo do painel
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style_box.border_color = color
	style_box.border_width_left = 3
	style_box.border_width_right = 3
	style_box.border_width_top = 3
	style_box.border_width_bottom = 3
	style_box.corner_radius_top_left = 10
	style_box.corner_radius_top_right = 10
	style_box.corner_radius_bottom_left = 10
	style_box.corner_radius_bottom_right = 10
	notification_panel.add_theme_stylebox_override("panel", style_box)
	
	# Container para o texto
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(20, 15)
	
	# Título
	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", color)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)
	
	# Mensagem
	var message_label = Label.new()
	message_label.text = message
	message_label.add_theme_font_size_override("font_size", 16)
	message_label.add_theme_color_override("font_color", Color.WHITE)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(message_label)
	
	notification_panel.add_child(vbox)
	
	# Tamanho do painel
	notification_panel.custom_minimum_size = Vector2(400, 120)
	notification_panel.size = Vector2(400, 120)
	
	# Posiciona no centro da tela
	var viewport_size = get_viewport().get_visible_rect().size
	notification_panel.position = (viewport_size - notification_panel.size) / 2
	notification_panel.z_index = 2000
	
	add_child(notification_panel)
	
	# Animação de entrada (escala)
	notification_panel.scale = Vector2(0.5, 0.5)
	notification_panel.modulate.a = 0.0
	
	var entry_tween = create_tween()
	entry_tween.set_parallel(true)
	entry_tween.tween_property(notification_panel, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	entry_tween.tween_property(notification_panel, "modulate:a", 1.0, 0.3)
	
	# Espera 3 segundos
	await get_tree().create_timer(3.0).timeout
	
	# Animação de saída
	var exit_tween = create_tween()
	exit_tween.set_parallel(true)
	exit_tween.tween_property(notification_panel, "scale", Vector2(0.5, 0.5), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	exit_tween.tween_property(notification_panel, "modulate:a", 0.0, 0.3)
	
	await exit_tween.finished
	notification_panel.queue_free()

func setup_health_display():
	# Verifica se o player existe e tem vida válida
	if not player or player.max_health <= 0:
		print("⚠️ Player inválido ou sem vida para setup_health_display")
		return
		
	# Cria container para corações se não existir
	if not health_container:
		health_container = HBoxContainer.new()
		health_container.name = "HealthContainer"
		health_container.position = Vector2(10, 10)
		add_child(health_container)
	
	# Limpa corações existentes
	for child in health_container.get_children():
		child.queue_free()
	
	# Aguarda um frame para garantir que os nós foram removidos
	await get_tree().process_frame
	
	# Cria corações baseado na vida máxima
	for i in range(player.max_health):
		var heart = TextureRect.new()
		heart.texture = heart_texture
		heart.custom_minimum_size = Vector2(32, 32)
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		health_container.add_child(heart)

func _on_health_changed(new_health):
	update_health_display(new_health)

func _on_score_changed(new_score):
	update_score(new_score)

func _on_inventory_changed():
	update_inventory()

func _on_upgrade_completed(new_level: int, new_damage: float):
	# Cria notificação de upgrade no HUD
	var title = "🔨 MACHADO MELHORADO! 🔨"
	var message = "Nível: %d | Dano: %.1f" % [new_level, new_damage]
	create_notification(title, message, Color(1.0, 0.84, 0.0))  # Dourado
	print("📢 Notificação de upgrade exibida no HUD")

func update_health_display(new_health = -1):
	# Verifica se o health_container existe
	if not health_container:
		print("⚠️ Health container não existe, criando...")
		await setup_health_display()
		return
	
	# Verifica se o player existe e tem vida válida
	if not player:
		print("⚠️ Player não existe para update_health_display")
		return
	
	# Use the parameter if provided, otherwise use player.health
	var current_health = new_health if new_health >= 0 else player.health
		
	var hearts = health_container.get_children()
	if hearts.size() == 0:
		print("⚠️ Nenhum coração encontrado, recriando...")
		await setup_health_display()
		return
	
	# Atualiza visibilidade dos corações
	for i in range(hearts.size()):
		if i < hearts.size() and hearts[i]:
			hearts[i].modulate = Color.WHITE if i < current_health else Color(0.3, 0.3, 0.3)

func update_score(new_score = -1):
	# Verifica se o score_label existe
	if not score_label:
		score_label = Label.new()
		score_label.position = Vector2(10, 50)
		score_label.add_theme_font_size_override("font_size", 24)
		add_child(score_label)
	
	# Verifica se o player existe
	if not player:
		score_label.text = "Score: 0"
		return
	
	# Calcula aumento de score
	var old_score = 0
	if score_label.text.begins_with("Score: "):
		var score_text = score_label.text.substr(7)  # Remove "Score: "
		old_score = int(score_text)
	
	# Use the parameter if provided, otherwise use player.score
	var current_score = new_score if new_score >= 0 else player.score
	var score_increase = current_score - old_score
	
	score_label.text = "Score: " + str(current_score)
	
	# Cria efeito visual se houve aumento
	if score_increase > 0:
		create_score_effect(score_increase)

func setup_inventory_panel():
	# Cria painel do inventário (inicialmente invisível)
	inventory_panel = Panel.new()
	inventory_panel.name = "InventoryPanel"
	inventory_panel.size = Vector2(400, 300)
	
	# Posição inicial no centro da tela
	var viewport_size = get_viewport().get_visible_rect().size
	inventory_panel.position = Vector2(
		(viewport_size.x - 400) / 2,
		(viewport_size.y - 300) / 2
	)
	inventory_panel.visible = false
	add_child(inventory_panel)
	
	# Fundo do painel
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.2, 0.2, 0.9)
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.6, 0.6, 0.6)
	inventory_panel.add_theme_stylebox_override("panel", style_box)
	
	# Título do inventário
	var title_label = Label.new()
	title_label.text = "INVENTÁRIO (Pressione I para fechar)"
	title_label.position = Vector2(10, 5)
	title_label.add_theme_font_size_override("font_size", 16)
	inventory_panel.add_child(title_label)
	
	# Grid para itens
	inventory_grid = GridContainer.new()
	inventory_grid.name = "InventoryMatrix"
	inventory_grid.columns = 8  # 8 colunas para matriz
	inventory_grid.position = Vector2(10, 30)
	inventory_grid.size = Vector2(380, 260)
	inventory_panel.add_child(inventory_grid)

func toggle_inventory():
	if not inventory_panel:
		setup_inventory_panel()
	
	inventory_visible = !inventory_visible
	inventory_panel.visible = inventory_visible
	
	if inventory_visible:
		# Sempre reposiciona o inventário quando aberto para lidar com mudanças de viewport
		print("📦 Abrindo inventário...")
		position_inventory_at_player()
		update_inventory()
		print("📦 Inventário aberto e posicionado")
	else:
		print("📦 Inventário fechado")

func position_inventory_at_player():
	if not player or not inventory_panel:
		print("⚠️ Player ou inventory_panel não encontrado para posicionamento")
		return
	
	var camera = get_viewport().get_camera_2d()
	var viewport_size = get_viewport().get_visible_rect().size
	var screen_center = Vector2.ZERO
	
	if camera:
		# Para CanvasLayer, precisamos usar coordenadas de tela, não do mundo
		# O centro da tela é sempre viewport_size / 2
		screen_center = viewport_size / 2
		print("📹 Usando centro da tela: ", screen_center)
	else:
		# Fallback para centro da tela
		screen_center = viewport_size / 2
		print("🎮 Usando centro da tela (fallback): ", screen_center)
	
	# Centraliza o painel do inventário na tela
	var panel_size = Vector2(400, 300)
	
	# Calcula posição centralizada
	var target_position = screen_center - panel_size / 2
	
	# Garante que o painel não saia dos limites da tela
	target_position.x = max(10, min(target_position.x, viewport_size.x - panel_size.x - 10))
	target_position.y = max(10, min(target_position.y, viewport_size.y - panel_size.y - 10))
	
	inventory_panel.position = target_position
	inventory_panel.size = panel_size
	
	print("📦 Inventário posicionado em: ", target_position, " (viewport: ", viewport_size, ")")

func update_inventory():
	if not player or not inventory_grid:
		return
	
	# Limpa inventário atual
	for child in inventory_grid.get_children():
		child.queue_free()
	
	# Cria slots do inventário (8x4 = 32 slots)
	var max_slots = 32
	var current_slot = 0
	
	# Adiciona itens existentes
	for item_name in player.inventory.keys():
		var item_count = player.inventory[item_name]
		if current_slot >= max_slots:
			break
			
		var slot = create_inventory_slot(item_name, item_count)
		inventory_grid.add_child(slot)
		current_slot += 1
	
	# Preenche slots vazios
	while current_slot < max_slots:
		var empty_slot = create_inventory_slot("", 0)
		inventory_grid.add_child(empty_slot)
		current_slot += 1

func create_inventory_slot(item_name: String, count: int) -> Control:
	var slot = Panel.new()
	slot.custom_minimum_size = Vector2(40, 40)
	
	# Estilo do slot
	var slot_style = StyleBoxFlat.new()
	if item_name != "":
		slot_style.bg_color = Color(0.3, 0.5, 0.3, 0.8)  # Verde para itens
	else:
		slot_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)  # Cinza para vazios
	
	slot_style.border_width_left = 2
	slot_style.border_width_right = 2
	slot_style.border_width_top = 2
	slot_style.border_width_bottom = 2
	slot_style.border_color = Color(0.6, 0.6, 0.6)
	slot.add_theme_stylebox_override("panel", slot_style)
	
	# Armazena dados no slot
	slot.set_meta("item_name", item_name)
	slot.set_meta("item_count", count)
	slot.set_meta("original_size", Vector2(40, 40))
	
	# Botão invisível para capturar cliques
	var button = Button.new()
	button.flat = true
	button.size = Vector2(40, 40)
	button.modulate = Color.TRANSPARENT
	slot.add_child(button)
	
	# Conecta sinais de input para drag & hover
	button.gui_input.connect(_on_item_input.bind(button))
	button.mouse_entered.connect(_on_slot_hover_enter.bind(slot))
	button.mouse_exited.connect(_on_slot_hover_exit.bind(slot))
	
	if item_name != "":
		# Ícone do item (texto por enquanto)
		var icon_label = Label.new()
		if item_name == "wood":
			icon_label.text = "🪵"
		elif item_name == "stone":
			icon_label.text = "🪨"
		else:
			icon_label.text = item_name[0].to_upper()
		
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_label.position = Vector2(5, 5)
		icon_label.size = Vector2(30, 20)
		icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Permite cliques passarem pelo label
		slot.add_child(icon_label)
		
		# Label para contagem
		var count_label = Label.new()
		count_label.text = str(count)
		count_label.add_theme_color_override("font_color", Color.YELLOW)
		count_label.add_theme_font_size_override("font_size", 8)
		count_label.position = Vector2(25, 25)
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(count_label)
	
	return slot

# Sistema de Drag and Drop
var dragging_item: Control = null
var drag_preview: Control = null

func _on_item_input(event: InputEvent, item_button: Button):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			start_drag(item_button)
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			stop_drag(event.global_position)

func start_drag(item_button: Button):
	var item_name = item_button.get_meta("item_name", "")
	var item_count = item_button.get_meta("item_count", 0)
	
	# Verificações de segurança antes de iniciar drag
	if item_name == "" or item_name == null:
		print("⚠️ Não é possível arrastar item sem nome válido")
		return
	
	if item_count <= 0:
		print("⚠️ Não é possível arrastar item com quantidade inválida: ", item_count)
		return
	
	print("🎯 Iniciando drag do item: ", item_name, " (quantidade: ", item_count, ")")
	
	dragging_item = item_button
	
	# Cria preview visual do item sendo arrastado
	drag_preview = Label.new()
	# Corrige o erro de capitalize verificando se item_name é válido
	var display_name = ""
	if item_name and item_name != "":
		display_name = item_name.capitalize()
	else:
		display_name = "Item"
	drag_preview.text = display_name + " (" + str(item_count) + ")"
	drag_preview.add_theme_color_override("font_color", Color.YELLOW)
	drag_preview.add_theme_font_size_override("font_size", 12)
	drag_preview.z_index = 1000
	
	# Posiciona o preview próximo ao mouse inicialmente
	var mouse_pos = get_viewport().get_mouse_position()
	drag_preview.position = mouse_pos + Vector2(5, -10)
	
	add_child(drag_preview)  # Adiciona ao HUD diretamente
	
	# Conecta mouse motion para seguir cursor
	set_process_input(true)

func stop_drag(drop_position: Vector2):
	if not dragging_item or not drag_preview:
		return
	
	var item_name = dragging_item.get_meta("item_name", "")
	var item_count = dragging_item.get_meta("item_count", 0)
	
	# Verificação de segurança - garante que temos dados válidos
	if item_name == "" or item_name == null:
		print("⚠️ Item name inválido durante drag - cancelando operação")
		cleanup_drag()
		return
	
	if item_count <= 0:
		print("⚠️ Item count inválido durante drag - cancelando operação")
		cleanup_drag()
		return
	
	print("🎯 Parando drag do item: ", item_name, " (", item_count, ") na posição: ", drop_position)
	
	# Verifica se foi dropado dentro do inventário
	var inventory_rect = Rect2(inventory_panel.global_position, inventory_panel.size)
	
	if inventory_rect.has_point(drop_position):
		# Dropado dentro do inventário - verifica se é em outro slot
		var target_slot = find_slot_at_position(drop_position)
		if target_slot and target_slot != dragging_item:
			handle_slot_swap(dragging_item, target_slot)
		else:
			print("📦 Item voltou para o mesmo slot")
	else:
		# Item foi dropado fora do inventário - joga no chão próximo ao player
		drop_item_near_player(item_name, item_count)
		
		# Remove o item do inventário do player
		if player and player.has_method("remove_item"):
			player.remove_item(item_name, item_count)
			update_inventory()
			print("📦 Item ", item_name, " removido do inventário e jogado no chão")
	
	# Limpa o drag
	cleanup_drag()

func find_slot_at_position(pos: Vector2) -> Control:
	# Busca qual slot está na posição do drop
	for child in inventory_grid.get_children():
		if child is Control:
			var slot_rect = Rect2(child.global_position, child.size)
			if slot_rect.has_point(pos):
				return child
	return null

func handle_slot_swap(source_slot: Control, target_slot: Control):
	if not source_slot or not target_slot:
		print("⚠️ Slot inválido para troca")
		return
		
	var source_item = source_slot.get_meta("item_name", "")
	var source_count = source_slot.get_meta("item_count", 0)
	var target_item = target_slot.get_meta("item_name", "")
	var target_count = target_slot.get_meta("item_count", 0)
	
	print("🔄 Tentando trocar slots: ", source_item, "(", source_count, ") <-> ", target_item, "(", target_count, ")")
	
	# Caso 1: Slot alvo vazio - move o item
	if target_item == "" or target_item == null:
		print("📦 Movendo item para slot vazio")
		# Remove do slot de origem
		source_slot.set_meta("item_name", "")
		source_slot.set_meta("item_count", 0)
		source_slot.text = ""
		
		# Adiciona ao slot de destino
		target_slot.set_meta("item_name", source_item)
		target_slot.set_meta("item_count", source_count)
		update_slot_display(target_slot)
		
		print("✅ Item movido com sucesso")
		return
		
	# Caso 2: Ambos os slots têm o mesmo item - combina quantidades
	if target_item == source_item:
		var total_count = source_count + target_count
		print("📦 Combinando itens: ", source_item, " total: ", total_count)
		
		# Remove do slot de origem
		source_slot.set_meta("item_name", "")
		source_slot.set_meta("item_count", 0)
		source_slot.text = ""
		
		# Atualiza slot de destino com total
		target_slot.set_meta("item_count", total_count)
		update_slot_display(target_slot)
		
		# Atualiza inventário do player
		if player and player.has_method("set_item_count"):
			player.set_item_count(source_item, total_count)
		
		print("✅ Itens combinados com sucesso")
		return
		
	# Caso 3: Slots têm itens diferentes - troca posições
	print("📦 Trocando posições entre itens diferentes")
	
	# Troca os metadados
	source_slot.set_meta("item_name", target_item)
	source_slot.set_meta("item_count", target_count)
	target_slot.set_meta("item_name", source_item)
	target_slot.set_meta("item_count", source_count)
	
	# Atualiza displays
	update_slot_display(source_slot)
	update_slot_display(target_slot)
	
	print("✅ Troca de posições realizada com sucesso")

# Nova função para atualizar apenas o display de um slot
func update_slot_display(slot: Control):
	if not slot:
		return
		
	var item_name = slot.get_meta("item_name", "")
	var item_count = slot.get_meta("item_count", 0)
	
	if item_name == "" or item_count <= 0:
		slot.text = ""
		return
	
	var display_name = get_item_display_name(item_name)
	slot.text = display_name + "\n" + str(item_count)

# Função para converter nome do item para display
func get_item_display_name(item_name: String) -> String:
	if item_name == "":
		return ""
	match item_name:
		"wood":
			return "Madeira"
		"stone":
			return "Pedra"
		"apple":
			return "Maçã"
		"bread":
			return "Pão"
		_:
			return item_name.capitalize()

# Efeitos de hover nos slots
func _on_slot_hover_enter(slot: Control):
	if slot.has_meta("item_name") and slot.get_meta("item_name") != "":
		# Efeito de aumento
		var tween = create_tween()
		tween.tween_property(slot, "scale", Vector2(1.1, 1.1), 0.1)
		
		# Efeito de brilho
		var style = slot.get_theme_stylebox("panel").duplicate()
		style.border_color = Color.GOLD
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		slot.add_theme_stylebox_override("panel", style)

func _on_slot_hover_exit(slot: Control):
	# Volta ao tamanho normal
	var tween = create_tween()
	tween.tween_property(slot, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Volta cor normal da borda
	var style = slot.get_theme_stylebox("panel").duplicate()
	style.border_color = Color(0.6, 0.6, 0.6)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	slot.add_theme_stylebox_override("panel", style)

func drop_item_near_player(item_name: String, count: int):
	# Verificações de segurança
	if item_name == "" or item_name == null:
		print("⚠️ Nome do item inválido para drop: ", item_name)
		return
	
	if count <= 0:
		print("⚠️ Quantidade inválida para drop: ", count)
		return
	
	if not player:
		print("⚠️ Player não encontrado para drop de item")
		return
	
	print("🎁 Iniciando drop do item: ", item_name, " (quantidade: ", count, ")")
	
	# Calcula posição próxima ao player mas não muito perto para evitar pickup automático
	var player_pos = player.global_position
	var drop_distance = 80.0  # Distância segura do player
	
	# Adiciona um offset aleatório para evitar sobreposição
	var angle = randf() * TAU  # Ângulo aleatório
	var offset = Vector2(cos(angle), sin(angle)) * drop_distance
	var drop_position = player_pos + offset
	
	print("🎁 Dropando item próximo ao player: ", player_pos, " -> ", drop_position)
	
	# Cria um item no chão
	create_ground_item(item_name, count, drop_position)

func create_ground_item(item_name: String, count: int, world_position: Vector2):
	# Cria um nó para representar o item no chão
	var ground_item = Area2D.new()
	ground_item.name = "GroundItem_" + item_name
	ground_item.position = world_position
	ground_item.add_to_group("ground_items")
	ground_item.input_pickable = true  # Habilita detecção de cliques
	
	# Sprite visual do item
	var sprite = ColorRect.new()
	sprite.size = Vector2(20, 20)  # Aumentado para ser mais visível
	sprite.position = Vector2(-10, -10)  # Centraliza o sprite
	
	# Define cor baseada no tipo de item
	if item_name == "wood":
		sprite.color = Color.GREEN
	elif item_name == "stone":
		sprite.color = Color.GRAY
	else:
		sprite.color = Color.YELLOW
	
	ground_item.add_child(sprite)
	
	# Efeito de flutuação
	var hover_tween = create_tween()
	hover_tween.set_loops()
	hover_tween.tween_property(sprite, "position:y", sprite.position.y - 5, 1.0)
	hover_tween.tween_property(sprite, "position:y", sprite.position.y, 1.0)
	
	# Efeito de rotação suave
	var rotation_tween = create_tween()
	rotation_tween.set_loops()
	rotation_tween.tween_property(sprite, "rotation", PI * 2, 3.0)
	
	# Label com nome do item
	var label = Label.new()
	label.text = item_name + " (" + str(count) + ")"
	label.position = Vector2(-25, -35)
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color.WHITE)
	ground_item.add_child(label)
	
	# Label com dica de coleta
	var hint_label = Label.new()
	hint_label.text = "[Clique Esquerdo]"
	hint_label.position = Vector2(-40, -50)
	hint_label.add_theme_font_size_override("font_size", 8)
	hint_label.add_theme_color_override("font_color", Color.YELLOW)
	ground_item.add_child(hint_label)
	
	# Collision para detecção (menor que o visual para evitar pickup acidental)
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(24, 24)  # Um pouco maior que o sprite para facilitar pickup
	collision.shape = shape
	ground_item.add_child(collision)
	
	# Armazena dados do item
	ground_item.set_meta("item_name", item_name)
	ground_item.set_meta("item_count", count)
	ground_item.set_meta("drop_time", Time.get_unix_time_from_system())  # Timestamp do drop
	
	# Conecta área de entrada para pickup (requer proximidade)
	ground_item.area_entered.connect(_on_ground_item_area_pickup.bind(ground_item))
	ground_item.body_entered.connect(_on_ground_item_pickup.bind(ground_item))
	
	# Conecta evento de clique do mouse para coleta
	ground_item.input_event.connect(_on_ground_item_clicked.bind(ground_item))
	
	# Adiciona à cena principal
	get_tree().current_scene.add_child(ground_item)
	
	print("🎁 Item criado no chão: ", item_name, " em ", world_position)

func _on_ground_item_pickup(ground_item: Area2D, body):
	if body.is_in_group("player"):
		pickup_ground_item(ground_item)

func _on_ground_item_area_pickup(ground_item: Area2D, area):
	if area.is_in_group("player"):
		pickup_ground_item(ground_item)

func _on_ground_item_clicked(viewport, event, shape_idx, ground_item: Area2D):
	# Coleta o item ao clicar com o botão esquerdo do mouse
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Verifica se o player está próximo o suficiente para coletar
		if player:
			var distance = player.global_position.distance_to(ground_item.global_position)
			if distance < 150:  # Distância máxima para coletar (150 pixels)
				pickup_ground_item(ground_item)
			else:
				# Mostra mensagem de feedback quando muito longe
				var feedback_label = Label.new()
				feedback_label.text = "Muito longe!"
				feedback_label.add_theme_font_size_override("font_size", 12)
				feedback_label.add_theme_color_override("font_color", Color.RED)
				feedback_label.position = ground_item.position - Vector2(30, 50)
				feedback_label.z_index = 1000
				get_tree().current_scene.add_child(feedback_label)
				
				var feedback_tween = create_tween()
				feedback_tween.set_parallel(true)
				feedback_tween.tween_property(feedback_label, "position:y", feedback_label.position.y - 20, 0.5)
				feedback_tween.tween_property(feedback_label, "modulate:a", 0.0, 0.5)
				feedback_tween.tween_callback(feedback_label.queue_free)
				
				print("📦 Item muito longe para coletar (distância: %.1f)" % distance)

func pickup_ground_item(ground_item: Area2D):
	# Verifica se o item ainda é válido
	if not is_instance_valid(ground_item):
		print("⚠️ Item no chão não é válido")
		return
	
	# Adiciona um pequeno delay para evitar pickup imediato após drop
	if ground_item.has_meta("drop_time"):
		var drop_time = ground_item.get_meta("drop_time")
		if Time.get_unix_time_from_system() - drop_time < 0.5:  # Reduzido para 0.5 segundos
			print("⏰ Item ainda em cooldown de pickup")
			return
	
	# Verifica se tem os metadados necessários
	if not ground_item.has_meta("item_name") or not ground_item.has_meta("item_count"):
		print("⚠️ Item no chão sem metadados corretos")
		return
	
	var item_name = ground_item.get_meta("item_name")
	var item_count = ground_item.get_meta("item_count")
	
	# Adiciona o item de volta ao inventário
	if player and player.has_method("add_item"):
		player.add_item(item_name, item_count)
		print("✅ Player coletou: ", item_name, " x", item_count, " do chão")
		
		# Cria efeito visual de coleta
		var pickup_label = Label.new()
		pickup_label.text = "+" + str(item_count) + " " + item_name
		pickup_label.add_theme_font_size_override("font_size", 16)
		pickup_label.add_theme_color_override("font_color", Color.GREEN)
		pickup_label.position = ground_item.position - Vector2(30, 50)
		pickup_label.z_index = 1000
		get_tree().current_scene.add_child(pickup_label)
		
		# Anima o texto de coleta
		var pickup_tween = create_tween()
		pickup_tween.set_parallel(true)
		pickup_tween.tween_property(pickup_label, "position:y", pickup_label.position.y - 30, 1.0)
		pickup_tween.tween_property(pickup_label, "modulate:a", 0.0, 1.0)
		pickup_tween.tween_callback(pickup_label.queue_free)
		
		# Remove o item do chão
		ground_item.queue_free()
		
		# Atualiza o inventário visual
		update_inventory()
	else:
		print("⚠️ Player não encontrado ou não tem método add_item")

func cleanup_drag():
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null
	
	dragging_item = null
	set_process_input(false)

func _input(event):
	# Atualiza posição do preview durante drag
	if dragging_item and drag_preview and event is InputEventMouseMotion:
		# Posiciona o preview próximo ao cursor do mouse (usa posição do viewport)
		drag_preview.position = get_viewport().get_mouse_position() + Vector2(5, -10)
