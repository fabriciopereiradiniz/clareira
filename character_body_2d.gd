extends CharacterBody2D

const TILE_SIZE = 32
const HALF_TILE = TILE_SIZE / 2.0  # Corrigido: divisão float
const SPEED = 160

# --- VIDA ---
@export var max_health: int = 5  # 5 corações de vida
var health: int = max_health
signal health_changed(new_health)

# --- INVENTÁRIO ---
var inventory := {}  # exemplo: { "wood": 5, "apple": 2 }
signal inventory_changed()

# --- PONTUAÇÃO ---
var score: int = 0
signal score_changed(new_score)

# --- MOVIMENTO ---
var target_position: Vector2
var moving: bool = false

# --- SISTEMA DE ATAQUE ---
@export var attack_range: float = 80.0  # Range aumentado para ataques
@export var area_damage_radius: float = 50.0  # Raio de dano em área
var attack_cooldown: float = 0.0
var attack_cooldown_time: float = 0.1  # Cooldown reduzido para 0.1s (mais responsivo)
var is_attacking: bool = false  # Nova variável para controlar se está atacando
var attack_duration: float = 0.3  # Duração do ataque (tempo de bloqueio de movimento)
var attack_timer: float = 0.0  # Timer para controlar duração do ataque

# --- SISTEMA DE UPGRADES ---
var tree_damage_level: int = 1  # Nível de dano nas árvores (padrão 1)
var tree_damage_base: float = 1.0  # Dano base por nível
signal damage_level_changed(new_level)
signal upgrade_completed(new_level, new_damage)

func _ready() -> void:
	# Adiciona ao grupo player para identificação
	add_to_group("player")
	
	# Cria área de pickup se não existir
	setup_pickup_area()
	
	# Cria emoji de machado acima do player
	create_weapon_indicator()
	
	# Cria sistema de partículas de poder
	create_power_particles()
	
	# Snap inicial para o centro do tile
	target_position = (position - Vector2(HALF_TILE, HALF_TILE)).snapped(Vector2(TILE_SIZE, TILE_SIZE)) + Vector2(HALF_TILE, HALF_TILE)
	position = target_position
	
	# Verifica se deve carregar save
	if get_tree().has_meta("load_save") and get_tree().get_meta("load_save"):
		get_tree().remove_meta("load_save")
		if not load_game():
			print("❌ Falha ao carregar save, iniciando novo jogo")
	
	if $Camera2D is Camera2D:
		$Camera2D.position = Vector2.ZERO
		$Camera2D.make_current()
	else:
		print("Camera2D não encontrada.")

func _physics_process(delta: float) -> void:
	# Se o jogo estiver pausado, não processa movimento
	if get_tree().paused:
		return
		
	# Reduz cooldown de ataque
	if attack_cooldown > 0:
		attack_cooldown -= delta
	
	# Gerencia duração do ataque
	if is_attacking:
		attack_timer -= delta
		# Efeito visual durante o ataque (pisca vermelho)
		modulate = Color.RED if int(attack_timer * 20) % 2 == 0 else Color.WHITE
		if attack_timer <= 0:
			is_attacking = false
			modulate = Color.WHITE  # Restaura cor normal
			# Desativa as partículas quando o ataque termina
			activate_power_particles(false)
			print("⚔️ Ataque finalizado, movimento liberado")
	
	# Auto-save
	_process_auto_save(delta)

	if moving and not is_attacking:  # Só se move se não estiver atacando
		position = position.move_toward(target_position, SPEED * delta)
		if position.distance_to(target_position) < 1:
			position = target_position
			moving = false
	elif not is_attacking:  # Só processa input de movimento se não estiver atacando
		var input_dir = Vector2(
			int(Input.is_action_pressed("pDIREITA")) - int(Input.is_action_pressed("pESQUERDA")),
			int(Input.is_action_pressed("pBAIXO")) - int(Input.is_action_pressed("pCIMA"))
		)

		if input_dir != Vector2.ZERO:
			var next_target = target_position + input_dir * TILE_SIZE
			# Raycast para evitar andar em obstáculos
			var space_state = get_world_2d().direct_space_state
			var ray = PhysicsRayQueryParameters2D.create(position, next_target)
			ray.exclude = [self]
			var result = space_state.intersect_ray(ray)
			if not result:
				target_position = next_target
				moving = true

func _input(event):
	# BLOQUEIA TODOS os inputs quando pausado (exceto ESC que é tratado pelo GameManager)
	if get_tree().paused:
		print("🚫 Jogo pausado - input bloqueado")
		return
	
	# Sistema de ESC: APENAS fecha inventário se estiver aberto, senão ignora completamente
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		# Verifica se o inventário está aberto
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("is_inventory_visible") and hud.is_inventory_visible():
			# Se inventário estiver aberto, fecha ele e marca como handled
			print("📦 Fechando inventário com ESC")
			hud.toggle_inventory()
			get_viewport().set_input_as_handled()
			return
		
		# Se inventário não estiver aberto, NÃO faz nada - deixa GameManager processar
		print("🎮 Player: ESC ignorado, GameManager deve processar")
		return
	
	# Toggle do inventário com tecla I (só funciona se não pausado)
	if event is InputEventKey and event.pressed and event.keycode == KEY_I:
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("toggle_inventory"):
			hud.toggle_inventory()
	
	# Tecla T para testar pickup (debug)
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		print("🧪 Testando pickup - criando item de teste")
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("create_ground_item"):
			hud.create_ground_item("wood", 1, global_position + Vector2(50, 0))
	
	# Tecla U para criar Upgrade Station (debug/building)
	if event is InputEventKey and event.pressed and event.keycode == KEY_U:
		place_upgrade_station()
	
	# Tecla F para dar recursos de finalização (debug)
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		print("🎁 CHEAT: Dando recursos para finalizar o jogo!")
		add_item("wood", 100)
		add_item("stone", 50)
		print("✅ Recursos adicionados: 100 wood, 50 stone")
	
	# Sistema de ataque com clique do mouse (agora com bloqueio de movimento)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and attack_cooldown <= 0 and not is_attacking:
		var mouse_pos = get_global_mouse_position()
		var distance_to_mouse = global_position.distance_to(mouse_pos)
		if distance_to_mouse <= attack_range:
			perform_area_attack(mouse_pos)
			attack_cooldown = attack_cooldown_time
			# Ativa o bloqueio de movimento durante o ataque
			is_attacking = true
			attack_timer = attack_duration
			moving = false  # Para o movimento atual
			# Ativa as partículas de poder durante o ataque
			activate_power_particles(true)
			print("⚔️ Atacando! Movimento bloqueado por ", attack_duration, "s")

func perform_area_attack(attack_position: Vector2):
	# Sistema de ataque simples e eficiente
	var tile_map = get_tree().get_first_node_in_group("tilemap")
	if not tile_map:
		return
	
	# Posição central para corte de árvores
	var center_tile_pos = tile_map.local_to_map(tile_map.to_local(attack_position))
	
	# Posições para verificar árvores (só algumas próximas)
	var positions_to_check = [
		center_tile_pos,
		center_tile_pos + Vector2i(1, 0),
		center_tile_pos + Vector2i(-1, 0),
		center_tile_pos + Vector2i(0, 1),
		center_tile_pos + Vector2i(0, -1)
	]
	
	# Corta árvores próximas
	var trees_hit = 0
	for pos in positions_to_check:
		var trees_before = tile_map.tree_registry.size()
		tile_map.chop_tree_at_fast(pos)
		var trees_after = tile_map.tree_registry.size()
		if trees_after < trees_before:
			trees_hit += 1
	
	# Minera pedras próximas
	var stones_hit = 0
	for pos in positions_to_check:
		var stones_before = tile_map.stone_registry.size()
		tile_map.mine_stone_at(pos)
		var stones_after = tile_map.stone_registry.size()
		if stones_after < stones_before:
			stones_hit += 1
	
	# SISTEMA DE INIMIGOS SIMPLES E EFICIENTE
	var enemies_hit = 0
	var enemies = get_tree().get_nodes_in_group("enemies")
	var max_enemies_to_check = min(enemies.size(), 5)  # Máximo 5 inimigos para evitar lag
	
	for i in range(max_enemies_to_check):
		var enemy = enemies[i]
		var distance = attack_position.distance_to(enemy.global_position)
		if distance <= area_damage_radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(25)
				enemies_hit += 1
	
	# Feedback simplificado
	if trees_hit > 0:
		print("🌳 ", trees_hit, " árvore(s) cortada(s)!")
	if enemies_hit > 0:
		print("⚔️ ", enemies_hit, " inimigo(s) atingido(s)!")
	if trees_hit == 0 and enemies_hit == 0:
		print("💨 Nada atingido")

# ======================
#        VIDA
# ======================
func take_damage(amount: float = 0.5):  # Meio coração por padrão
	health = max(0, health - amount)
	emit_signal("health_changed", health)
	print("💔 Player perdeu ", amount, " de vida. Vida atual: ", health)
	if health <= 0:
		die()

func heal(amount: float):
	health = min(max_health, health + amount)
	emit_signal("health_changed", health)

func die():
	print("💀 Player morreu")
	# Restaura vida completa
	health = max_health
	emit_signal("health_changed", health)
	# Reinicia posição
	global_position = Vector2(126, 19)
	target_position = global_position
	moving = false
	print("💖 Player reviveu com vida completa!")

# ======================
#     INVENTÁRIO
# ======================
func add_item(item_name: String, amount: int = 1):
	if not inventory.has(item_name):
		inventory[item_name] = 0
	inventory[item_name] += amount
	emit_signal("inventory_changed")
	if item_name == "wood":
		score += amount
		emit_signal("score_changed", score)

func remove_item(item_name: String, amount: int = 1) -> bool:
	if inventory.has(item_name) and inventory[item_name] >= amount:
		inventory[item_name] -= amount
		if inventory[item_name] <= 0:
			inventory.erase(item_name)
		emit_signal("inventory_changed")
		return true
	return false

func has_item(item_name: String, amount: int = 1) -> bool:
	return inventory.has(item_name) and inventory[item_name] >= amount

func set_item_count(item_name: String, new_count: int):
	if new_count <= 0:
		inventory.erase(item_name)
	else:
		inventory[item_name] = new_count
	emit_signal("inventory_changed")

func get_item_count(item_name: String) -> int:
	return inventory.get(item_name, 0)

# --- SISTEMA DE UPGRADES ---
func get_tree_damage() -> float:
	return tree_damage_base * tree_damage_level

func upgrade_tree_damage() -> bool:
	var cost_wood = tree_damage_level * 10  # Custo em madeira aumenta por nível
	var cost_stone = tree_damage_level * 5  # Custo em pedra aumenta por nível
	
	print("🔨 Tentando upgrade - Nível atual: ", tree_damage_level, " | Recursos: Wood=", get_item_count("wood"), " Stone=", get_item_count("stone"))
	print("🔨 Custo necessário: Wood=", cost_wood, " Stone=", cost_stone)
	
	if has_item("wood", cost_wood) and has_item("stone", cost_stone):
		remove_item("wood", cost_wood)
		remove_item("stone", cost_stone)
		tree_damage_level += 1
		var new_damage = get_tree_damage()
		emit_signal("damage_level_changed", tree_damage_level)
		emit_signal("upgrade_completed", tree_damage_level, new_damage)
		update_power_particles()  # Atualiza as partículas de poder
		print("✅ Tree damage upgraded to level ", tree_damage_level, " (damage: ", new_damage, ")")
		print("✅ Novo dano: ", new_damage, " | Recursos restantes: Wood=", get_item_count("wood"), " Stone=", get_item_count("stone"))
		return true
	else:
		print("❌ Insufficient resources for upgrade. Need ", cost_wood, " wood and ", cost_stone, " stone")
		print("❌ Has wood? ", has_item("wood", cost_wood), " | Has stone? ", has_item("stone", cost_stone))
		return false

func get_upgrade_cost() -> Array:
	var cost_wood = tree_damage_level * 10
	var cost_stone = tree_damage_level * 5
	return [cost_wood, cost_stone]

func place_upgrade_station():
	# Check if player has required resources to build a station
	var build_cost_wood = 20
	var build_cost_stone = 10
	
	if not has_item("wood", build_cost_wood) or not has_item("stone", build_cost_stone):
		print("❌ Need ", build_cost_wood, " wood and ", build_cost_stone, " stone to build upgrade station")
		return
	
	# Load the upgrade station scene
	var upgrade_station_scene = preload("res://UpgradeStation.tscn")
	var upgrade_station = upgrade_station_scene.instantiate()
	
	# Position it near the player (snap to grid)
	var placement_pos = global_position + Vector2(64, 0)  # Place to the right of player
	placement_pos = placement_pos.snapped(Vector2(TILE_SIZE, TILE_SIZE))
	upgrade_station.global_position = placement_pos
	
	# Add to the current scene
	get_tree().current_scene.add_child(upgrade_station)
	
	# Consume resources
	remove_item("wood", build_cost_wood)
	remove_item("stone", build_cost_stone)
	
	print("🏗️ Upgrade station placed at: ", placement_pos)
	print("💰 Consumed ", build_cost_wood, " wood and ", build_cost_stone, " stone")

func create_weapon_indicator():
	# Emoji de machado flutuando acima do player
	var weapon_label = Label.new()
	weapon_label.text = "🪓"
	weapon_label.add_theme_font_size_override("font_size", 80)
	weapon_label.position = Vector2(-40, -80)
	weapon_label.name = "WeaponIndicator"
	weapon_label.z_index = 10
	add_child(weapon_label)
	
	# Animação de flutuação
	var float_tween = create_tween()
	float_tween.set_loops()
	float_tween.tween_property(weapon_label, "position:y", weapon_label.position.y - 5, 1.0)
	float_tween.tween_property(weapon_label, "position:y", weapon_label.position.y, 1.0)
	
	# Animação de rotação suave
	var rotate_tween = create_tween()
	rotate_tween.set_loops()
	rotate_tween.tween_property(weapon_label, "rotation", 0.2, 1.5)
	rotate_tween.tween_property(weapon_label, "rotation", -0.2, 1.5)

func create_power_particles():
	# Sistema de partículas que aumenta com o nível
	var particles = CPUParticles2D.new()
	particles.name = "PowerParticles"
	particles.emitting = false  # Começa desligado, só ativa durante ataque
	particles.amount = 5  # Começa com poucas partículas
	particles.lifetime = 0.8
	particles.one_shot = false  # Permite ativar/desativar
	particles.local_coords = true
	particles.position = Vector2(0, -20)  # Acima do player
	
	# Configurações visuais
	particles.direction = Vector2(0, -1)
	particles.spread = 45
	particles.initial_velocity_min = 20.0
	particles.initial_velocity_max = 40.0
	particles.gravity = Vector2(0, -10)  # Partículas sobem
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	
	# Cores baseadas no poder
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color.GOLD)
	gradient.add_point(0.5, Color.ORANGE)
	gradient.add_point(1.0, Color.TRANSPARENT)
	particles.color_ramp = gradient
	
	add_child(particles)
	
	# Atualiza partículas baseado no nível inicial
	update_power_particles()

func activate_power_particles(active: bool):
	# Ativa ou desativa as partículas de poder
	var particles = get_node_or_null("PowerParticles")
	if particles:
		particles.emitting = active
		if active:
			print("✨ Partículas de poder ATIVADAS")
		else:
			print("✨ Partículas de poder DESATIVADAS")

func update_power_particles():
	# Atualiza quantidade de partículas baseado no nível de dano
	var particles = get_node_or_null("PowerParticles")
	if particles:
		# Mais partículas = mais poder
		particles.amount = 5 + (tree_damage_level - 1) * 5  # 5, 10, 15, 20, 25...
		particles.initial_velocity_max = 40.0 + (tree_damage_level - 1) * 10.0
		
		# Muda cores conforme nível aumenta
		var gradient = Gradient.new()
		if tree_damage_level <= 2:
			# Níveis baixos: dourado/laranja
			gradient.add_point(0.0, Color.GOLD)
			gradient.add_point(0.5, Color.ORANGE)
		elif tree_damage_level <= 4:
			# Níveis médios: laranja/vermelho
			gradient.add_point(0.0, Color.ORANGE)
			gradient.add_point(0.5, Color.RED)
		else:
			# Níveis altos: vermelho/roxo (poder máximo)
			gradient.add_point(0.0, Color.RED)
			gradient.add_point(0.5, Color.PURPLE)
		gradient.add_point(1.0, Color.TRANSPARENT)
		particles.color_ramp = gradient
		
		print("✨ Partículas de poder atualizadas: Nível ", tree_damage_level, " | Partículas: ", particles.amount)

func setup_pickup_area():
	# Cria uma área para coletar itens automaticamente
	var pickup_area = Area2D.new()
	pickup_area.name = "PickupArea"
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 50.0  # Raio de coleta
	collision.shape = shape
	pickup_area.add_child(collision)
	
	add_child(pickup_area)

# ======================
#    SISTEMA DE SAVE
# ======================
var auto_save_timer: float = 0.0
var auto_save_interval: float = 30.0  # Salva a cada 30 segundos (menos frequente)

func _process_auto_save(delta: float):
	auto_save_timer += delta
	if auto_save_timer >= auto_save_interval:
		auto_save_timer = 0.0
		save_game()

func save_game():
	var save_data = {
		"player_position": global_position,
		"player_health": health,
		"player_max_health": max_health,
		"inventory": inventory,
		"score": score,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	var save_file = FileAccess.open("user://savegame.dat", FileAccess.WRITE)
	if save_file:
		save_file.store_string(JSON.stringify(save_data))
		save_file.close()
		print("💾 Jogo salvo automaticamente!")

func load_game() -> bool:
	var save_file = FileAccess.open("user://savegame.dat", FileAccess.READ)
	if not save_file:
		return false
	
	var save_text = save_file.get_as_text()
	save_file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(save_text)
	if parse_result != OK:
		return false
	
	var save_data = json.data
	
	# Restaura dados do player
	global_position = Vector2(save_data.player_position.x, save_data.player_position.y)
	target_position = global_position
	health = save_data.player_health
	max_health = save_data.player_max_health
	inventory = save_data.inventory
	score = save_data.score
	
	# Emite sinais para atualizar UI
	emit_signal("health_changed", health)
	emit_signal("inventory_changed")
	emit_signal("score_changed", score)
	
	print("💾 Jogo carregado com sucesso!")
	return true

func save_exists() -> bool:
	return FileAccess.file_exists("user://savegame.dat")
