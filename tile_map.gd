extends TileMap

const CHUNK_SIZE = 32
const RENDER_DISTANCE = 2

const green_block_atlas_pos = Vector2i(2, 0)
const tree_trunk_atlas_pos = Vector2i(0, 0)
const tree_leaf_atlas_pos = Vector2i(1, 0)
const bush_atlas_pos = Vector2i(3, 0)
const boundary_atlas_pos = Vector2i(0, 1)
const stone_atlas_pos = Vector2i(4, 0)  # Nova posição para pedra no atlas
const main_source = 0

enum layers {
	level0 = 0,
	level1 = 1,
	level2 = 2,
	level3 = 3,
	level4 = 4,
	level5 = 5,
	level6 = 6
}

const BASE_TREE_SPACING = 2
const NOISE_THRESHOLD_TREE = 0.1
const NOISE_THRESHOLD_BUSH = 0.5
const NOISE_THRESHOLD_STONE = 0.3  # Threshold para pedras
const BASE_STONE_SPACING = 4  # Pedras mais espaçadas que árvores
const RESPAWN_TIME = 30.0

var noise = FastNoiseLite.new()
var stone_noise = FastNoiseLite.new()  # Noise separado para pedras
var generated_chunks = {}
var tree_registry = {}
var stone_registry = {}  # Registro de pedras
var trees_to_respawn = {}
var stones_to_respawn = {}  # Pedras para respawn
var rendered_chunks = {}  # Chunks que estão visualmente renderizados
var cached_player = null  # Cache do player para evitar buscas repetidas

# Tamanho do tile
var TILE_SIZE = 64  # Atualize se seu TileMap tiver outro tamanho

# Inimigos
# âš ï¸ Substitua este caminho pelo correto da sua cena do inimigo
const ENEMY_SCENE = preload("res://HUD/Enemy.tscn")


var enemies = []

func _ready():
	randomize()
	noise.seed = randi()
	noise.frequency = 0.15
	noise.fractal_octaves = 3
	
	# Configura noise para pedras
	stone_noise.seed = randi()
	stone_noise.frequency = 0.1  # Frequência diferente das árvores
	stone_noise.fractal_octaves = 2
	
	# Verifica se o TileSet está configurado
	if tile_set == null:
		print("❌ ERRO: TileSet não está configurado!")
		return
	else:
		print("✅ TileSet encontrado!")
		print("🔍 Fontes no TileSet: ", tile_set.get_source_count())
		if tile_set.get_source_count() > 0:
			print("🔍 Source 0: ", tile_set.get_source(0))
	
	# Atualiza TILE_SIZE automaticamente
	if tile_set != null:
		TILE_SIZE = tile_set.tile_size.x
		print("🔍 TILE_SIZE: ", TILE_SIZE)
	
	# Adiciona ao grupo tilemap
	add_to_group("tilemap")
	
	# Força geração inicial de alguns chunks ao redor da origem
	print("🗺️ Gerando chunks iniciais...")
	var chunks_gerados = 0
	for cx in range(-1, 2):
		for cy in range(-1, 2):
			var chunk_id = Vector2i(cx, cy)
			print("🔄 Tentando gerar chunk: ", chunk_id)
			generate_chunk_data(chunk_id)  # Gera dados
			render_chunk_visual(chunk_id)  # Renderiza visual
			generated_chunks[chunk_id] = true
			rendered_chunks[chunk_id] = true
			chunks_gerados += 1
			print("📊 Chunks gerados até agora: ", chunks_gerados)
	
	# FORÇA uma vila próxima ao spawn para teste
	print("🏘️ FORÇANDO vila próxima ao spawn...")
	call_deferred("spawn_test_village")
	print("🗺️ Total de chunks iniciais gerados: ", chunks_gerados)
	print("🗺️ Chunks iniciais gerados!")
	
	# Spawna o destino final perto do spawn
	print("🏁 Criando destino final perto do spawn...")
	call_deferred("spawn_final_destination")
	
	# Teste: coloca alguns tiles manualmente para verificar se funciona
	print("🧪 Teste: colocando tiles manuais...")
	for i in range(-5, 6):
		for j in range(-5, 6):
			set_cell(layers.level0, Vector2i(i, j), main_source, green_block_atlas_pos)
	print("🧪 Tiles de teste colocados!")
	
	# Força uma verificação inicial de chunks
	await get_tree().process_frame  # Espera um frame para tudo se inicializar
	print("🔄 Forçando verificação inicial de chunks...")
	_check_chunks()

# OtimizaÃ§Ã£o: Cache para reduzir verificaÃ§Ãµes
var last_chunk_check: Vector2i = Vector2i.ZERO
var chunk_check_timer: float = 0.0
var chunk_check_interval: float = 0.5  # Verifica chunks a cada 0.5s

func _process(delta):
	# OtimizaÃ§Ã£o: Reduz frequÃªncia de verificaÃ§Ã£o de chunks
	chunk_check_timer += delta
	if chunk_check_timer >= chunk_check_interval:
		chunk_check_timer = 0.0
		_check_chunks()
	
	# OtimizaÃ§Ã£o: Apenas se hÃ¡ Ã¡rvores para processar
	if not tree_registry.is_empty():
		_update_tree_effects(delta)
	
	# Atualiza efeitos de pedras
	if not stone_registry.is_empty():
		_update_stone_effects(delta)

	# Respawn de Ã¡rvores (otimizado)
	if not trees_to_respawn.is_empty():
		_process_tree_respawns(delta)
	
	# Respawn de pedras
	if not stones_to_respawn.is_empty():
		_process_stone_respawns(delta)

func _check_chunks():
	var cam = get_viewport().get_camera_2d()
	if not cam:
		print("⚠️ Câmera não encontrada!")
		return
		
	var pt = local_to_map(to_local(cam.global_position))
	var pc = Vector2i(floor(pt.x / CHUNK_SIZE), floor(pt.y / CHUNK_SIZE))
	
	# Sempre gera chunks na primeira vez ou se mudou de posição
	var distance = Vector2(pc).distance_to(Vector2(last_chunk_check))
	if last_chunk_check == Vector2i.ZERO or distance > 0.5:  # Reduzido de 1 para 0.5
		print("🗺️ Verificando chunks ao redor de: ", pc, " (distância: ", distance, ")")
		last_chunk_check = pc
		var chunks_novos = 0
		var chunks_renderizados = 0
		
		# Primeiro, gera os dados dos chunks em uma área maior
		for cx in range(pc.x - RENDER_DISTANCE - 1, pc.x + RENDER_DISTANCE + 2):
			for cy in range(pc.y - RENDER_DISTANCE - 1, pc.y + RENDER_DISTANCE + 2):
				var id = Vector2i(cx, cy)
				if not generated_chunks.has(id):
					generate_chunk_data(id)  # Só gera os dados, não renderiza
					generated_chunks[id] = true
					chunks_novos += 1
		
		# Depois, renderiza apenas os chunks no campo de visão
		for cx in range(pc.x - RENDER_DISTANCE, pc.x + RENDER_DISTANCE + 1):
			for cy in range(pc.y - RENDER_DISTANCE, pc.y + RENDER_DISTANCE + 1):
				var id = Vector2i(cx, cy)
				if not rendered_chunks.has(id):
					render_chunk_visual(id)
					rendered_chunks[id] = true
					chunks_renderizados += 1
		
		# Remove chunks renderizados que estão muito longe
		var chunks_removidos = 0
		var keys_to_remove = []
		for chunk_id in rendered_chunks.keys():
			var chunk_distance = Vector2(chunk_id).distance_to(Vector2(pc))
			if chunk_distance > RENDER_DISTANCE + 1:
				clear_chunk_visual(chunk_id)
				keys_to_remove.append(chunk_id)
				chunks_removidos += 1
		
		for key in keys_to_remove:
			rendered_chunks.erase(key)
		
		if chunks_novos > 0 or chunks_renderizados > 0 or chunks_removidos > 0:
			print("📊 Chunks gerados: ", chunks_novos, " | Renderizados: ", chunks_renderizados, " | Removidos: ", chunks_removidos)

func _process_tree_respawns(delta):
	var keys_to_remove = []
	var tree_keys = trees_to_respawn.keys()
	for tree_id in tree_keys:
		trees_to_respawn[tree_id]["timer"] -= delta
		if trees_to_respawn[tree_id]["timer"] <= 0:
			place_tree_natural(trees_to_respawn[tree_id]["pos"])
			keys_to_remove.append(tree_id)
			print("🌳 Árvore respawnada:", tree_id)
	
	# Remove árvores respawnadas
	for key in keys_to_remove:
		trees_to_respawn.erase(key)

func _process_stone_respawns(delta):
	var current_time = Time.get_unix_time_from_system()
	var keys_to_remove = []
	
	for stone_id in stones_to_respawn.keys():
		var respawn_data = stones_to_respawn[stone_id]
		if current_time >= respawn_data.respawn_time:
			place_stone(respawn_data.position)
			keys_to_remove.append(stone_id)
			print("🪨 Pedra respawnada: ", stone_id)
	
	# Remove pedras respawnadas
	for key in keys_to_remove:
		stones_to_respawn.erase(key)

func generate_chunk(chunk_id: Vector2i) -> void:
	# Esta função é mantida para compatibilidade, mas agora chama as novas funções
	generate_chunk_data(chunk_id)
	render_chunk_visual(chunk_id)

# Nova função: gera apenas os dados do chunk (árvores, arbustos, etc.)
func generate_chunk_data(chunk_id: Vector2i) -> void:
	print("� Gerando dados do chunk: ", chunk_id)
	var base_x = chunk_id.x * CHUNK_SIZE
	var base_y = chunk_id.y * CHUNK_SIZE
	
	for y in range(CHUNK_SIZE):
		for x in range(CHUNK_SIZE):
			var pos = Vector2i(base_x + x, base_y + y)
			
			# Spawn de árvore/bush
			var dist = Vector2(pos).length()
			if dist > 8.0 and (pos.x % BASE_TREE_SPACING == 0 and pos.y % BASE_TREE_SPACING == 0):
				var v = noise.get_noise_2d(pos.x, pos.y)
				if v > NOISE_THRESHOLD_TREE:
					place_tree_natural(pos)
				elif v > NOISE_THRESHOLD_BUSH:
					place_bush(pos)
			
			# Spawn de pedras (menos frequentes que árvores)
			if dist > 8.0 and (pos.x % BASE_STONE_SPACING == 0 and pos.y % BASE_STONE_SPACING == 0):
				var stone_v = stone_noise.get_noise_2d(pos.x, pos.y)
				if stone_v > NOISE_THRESHOLD_STONE:
					place_stone(pos)

			# Spawn de inimigos (raro para evitar lag)
			if (pos.x % 16 == 0 and pos.y % 16 == 0) and randf() < 0.05:
				spawn_enemy(pos)
			
			# Spawn de vilas/estações de upgrade (chance alta para garantir que apareçam)
			if (pos.x % 24 == 0 and pos.y % 24 == 0) and randf() < 0.4:
				spawn_upgrade_station(pos)

# Nova função: renderiza visualmente apenas o chunk
func render_chunk_visual(chunk_id: Vector2i) -> void:
	print("🎨 Renderizando visual do chunk: ", chunk_id)
	var base_x = chunk_id.x * CHUNK_SIZE
	var base_y = chunk_id.y * CHUNK_SIZE
	
	var tiles_colocados = 0
	for y in range(CHUNK_SIZE):
		for x in range(CHUNK_SIZE):
			var pos = Vector2i(base_x + x, base_y + y)
			# Só coloca o tile visual se não estiver já colocado
			if get_cell_source_id(layers.level0, pos) == -1:
				set_cell(layers.level0, pos, main_source, green_block_atlas_pos)
				tiles_colocados += 1
	
	print("🎨 Tiles renderizados no chunk ", chunk_id, ": ", tiles_colocados)

# Nova função: remove visualmente um chunk para otimização
func clear_chunk_visual(chunk_id: Vector2i) -> void:
	print("🗑️ Removendo visual do chunk: ", chunk_id)
	var base_x = chunk_id.x * CHUNK_SIZE
	var base_y = chunk_id.y * CHUNK_SIZE
	
	var tiles_removidos = 0
	for y in range(CHUNK_SIZE):
		for x in range(CHUNK_SIZE):
			var pos = Vector2i(base_x + x, base_y + y)
			# Remove apenas tiles de grama base, mantém árvores e outros elementos
			if get_cell_atlas_coords(layers.level0, pos) == green_block_atlas_pos:
				erase_cell(layers.level0, pos)
				tiles_removidos += 1
	
	print("🗑️ Tiles removidos do chunk ", chunk_id, ": ", tiles_removidos)

func spawn_enemy(pos: Vector2i):
	var enemy = ENEMY_SCENE.instantiate()
	# map_to_local com centro do tile
	enemy.global_position = to_global(map_to_local(pos))
	get_parent().add_child.call_deferred(enemy)
	enemies.append(enemy)

func spawn_upgrade_station(pos: Vector2i):
	# Carrega a cena da estação de upgrade
	var upgrade_station_scene = preload("res://UpgradeStation.tscn")
	var upgrade_station = upgrade_station_scene.instantiate()
	
	# Posiciona a estação no centro do tile
	upgrade_station.global_position = to_global(map_to_local(pos))
	
	# Adiciona à cena usando call_deferred para evitar erros de timing
	get_parent().add_child.call_deferred(upgrade_station)
	
	print("🏘️ Vila/Estação de upgrade gerada em: ", pos, " (posição mundial: ", upgrade_station.global_position, ")")

func place_tree_natural(pos: Vector2i):
	var tree_id = str(pos) + "_" + str(Time.get_ticks_usec())
	var tiles = []
	var height = randi_range(3, 6)
	var current_pos = pos

	for i in range(height):
		var layer = layers.level1 + i
		var offset = Vector2i(randi() % 2, randi() % 2) * -1 if i > 0 else Vector2i(0, 0)
		current_pos += offset
		set_cell(layer, current_pos, main_source, tree_trunk_atlas_pos)
		tiles.append({ "layer": layer, "pos": current_pos })

	var leaf_layer = min(layers.level1 + height, layers.level6)
	var leaf_radius = randi_range(1, 2)

	for dx in range(-leaf_radius, leaf_radius + 1):
		for dy in range(-leaf_radius, leaf_radius + 1):
			if Vector2(dx, dy).length() <= leaf_radius + randf() * 0.5:
				var leaf_pos = current_pos + Vector2i(dx, dy)
				if get_cell_source_id(leaf_layer, leaf_pos) == -1:
					set_cell(leaf_layer, leaf_pos, main_source, tree_leaf_atlas_pos)
					tiles.append({ "layer": leaf_layer, "pos": leaf_pos })

	var original_positions = []
	for tile in tiles:
		original_positions.append(tile.pos)
	
	tree_registry[tree_id] = {
		"tiles": tiles,
		"hits": 3 + int(Vector2(pos).length() / 50.0),
		"flashing": false,
		"flash_timer": 0.0,
		"shake_timer": 0.0,
		"original_positions": original_positions
	}

func place_bush(pos: Vector2i):
	var h = randi() % 2 + 1
	for i in range(h):
		var l = layers.level1 + i
		if l <= layers.level6:
			set_cell(l, pos, main_source, bush_atlas_pos)

func place_stone(pos: Vector2i):
	# Cria uma pedra com ID único
	var stone_id = "stone_" + str(pos.x) + "_" + str(pos.y)
	
	# Se já existe uma pedra aqui, não cria outra
	if stone_registry.has(stone_id):
		return
	
	var tiles = []
	var base_layer = layers.level0
	
	# Pedras podem ser de 2 a 4 tiles de altura (maiores que árvores em alguns casos)
	var height = randi_range(2, 4)
	
	# Cria uma formação de pedra com múltiplos blocos
	var stone_shape = randi() % 3  # 3 formas diferentes de pedra
	
	match stone_shape:
		0:  # Pedra simples vertical
			for i in range(height):
				var layer = base_layer + i
				if layer <= layers.level6:
					set_cell(layer, pos, main_source, stone_atlas_pos)
					tiles.append({ "layer": layer, "pos": pos })
		
		1:  # Pedra mais larga (2x2)
			for i in range(height):
				var layer = base_layer + i
				if layer <= layers.level6:
					for dx in range(2):
						for dy in range(2):
							var stone_pos = pos + Vector2i(dx, dy)
							set_cell(layer, stone_pos, main_source, stone_atlas_pos)
							tiles.append({ "layer": layer, "pos": stone_pos })
		
		2:  # Pedra em formato de pilha irregular
			for i in range(height):
				var layer = base_layer + i
				if layer <= layers.level6:
					set_cell(layer, pos, main_source, stone_atlas_pos)
					tiles.append({ "layer": layer, "pos": pos })
					
					# Adiciona blocos extras nos níveis mais baixos
					if i < 2:
						var offsets = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
						var random_offset = offsets[randi() % offsets.size()]
						var extra_pos = pos + random_offset
						set_cell(layer, extra_pos, main_source, stone_atlas_pos)
						tiles.append({ "layer": layer, "pos": extra_pos })
	
	# Salva posições originais para efeitos
	var original_positions = []
	for tile in tiles:
		original_positions.append(tile.pos)
	
	# Cria colisão para a pedra
	var collision_body = create_stone_collision(tiles, stone_id)
	
	# Registra a pedra com mais vida que árvores
	stone_registry[stone_id] = {
		"tiles": tiles,
		"hits": 8 + int(Vector2(pos).length() / 30.0),  # 8+ hits (mais que árvores que têm 3+)
		"flashing": false,
		"flash_timer": 0.0,
		"shake_timer": 0.0,
		"original_positions": original_positions,
		"collision_body": collision_body
	}
	
	print("🪨 Pedra criada em ", pos, " com ", stone_registry[stone_id].hits, " de vida e colisão")

func create_stone_collision(tiles: Array, stone_id: String) -> StaticBody2D:
	# Cria um StaticBody2D para colisão da pedra
	var collision_body = StaticBody2D.new()
	collision_body.name = "StoneCollision_" + stone_id
	
	# Encontra o tile base (geralmente o primeiro ou o mais baixo)
	var base_tile = tiles[0]
	var base_pos = base_tile.pos
	
	# Cria shape de colisão baseado nos tiles da pedra
	for tile in tiles:
		# Cria uma colisão para cada tile da pedra
		if tile.layer == layers.level0 or tile.layer == layers.level1:  # Apenas níveis baixos têm colisão sólida
			var collision_shape = CollisionShape2D.new()
			var shape = RectangleShape2D.new()
			shape.size = Vector2(TILE_SIZE * 0.8, TILE_SIZE * 0.8)  # Um pouco menor para permitir passagem próxima
			collision_shape.shape = shape
			
			# Posição relativa ao corpo de colisão
			var tile_world_pos = map_to_local(tile.pos)
			collision_shape.position = tile_world_pos - map_to_local(base_pos)
			
			collision_body.add_child(collision_shape)
	
	# Posiciona o corpo no mundo
	collision_body.position = map_to_local(base_pos)
	
	# Adiciona à cena
	add_child(collision_body)
	
	return collision_body

func _update_tree_effects(delta: float):
	# ULTRA OTIMIZAÃ‡ÃƒO: Simplifica efeitos visuais para evitar lag
	if tree_registry.is_empty():
		return
		
	# Apenas atualiza timers sem efeitos visuais custosos
	var registry_keys = tree_registry.keys()
	for tree_id in registry_keys:
		var tree_data = tree_registry[tree_id]
		
		# Efeito de piscada simplificado
		if tree_data.flashing:
			tree_data.flash_timer -= delta
			if tree_data.flash_timer <= 0:
				tree_data.flashing = false
		
		# Efeito de tremor simplificado (apenas timer)
		if tree_data.shake_timer > 0:
			tree_data.shake_timer -= delta

func _update_stone_effects(delta: float):
	# Atualiza efeitos visuais das pedras (similar às árvores)
	if stone_registry.is_empty():
		return
	
	var registry_keys = stone_registry.keys()
	for stone_id in registry_keys:
		var stone_data = stone_registry[stone_id]
		
		# Efeito de piscada
		if stone_data.flashing:
			stone_data.flash_timer -= delta
			if stone_data.flash_timer <= 0:
				stone_data.flashing = false
		
		# Efeito de tremor
		if stone_data.shake_timer > 0:
			stone_data.shake_timer -= delta

func chop_tree_at(pos: Vector2i):
	# FunÃ§Ã£o legacy - usa a versÃ£o otimizada
	chop_tree_at_fast(pos)

func mine_stone_at(pos: Vector2i):
	# Tenta minerar uma pedra na posição clicada
	if not stone_registry or stone_registry.is_empty():
		return
	
	# Busca direta
	for stone_id in stone_registry.keys():
		var stone_data = stone_registry[stone_id]
		if not stone_data or not stone_data.has("tiles"):
			continue
		
		# Verifica se algum tile da pedra está na posição
		for tile_info in stone_data.tiles:
			if tile_info.pos == pos:
				hit_stone(stone_id)
				return

func chop_tree_at_fast(pos: Vector2i):
	# OTIMIZAÇÃO: Busca rápida e eficiente
	if not tree_registry or tree_registry.is_empty():
		return
	
	# Busca direta sem logs desnecessários
	for tree_id in tree_registry.keys():
		var tree_data = tree_registry[tree_id]
		if not tree_data or not tree_data.has("tiles"):
			continue
			
		# Verifica se algum tile da árvore está na posição
		for tile_info in tree_data.tiles:
			if tile_info.pos == pos:
				hit_tree(tree_id)
				return  # Early exit após encontrar

func hit_tree(tree_id: String):
	if not tree_registry.has(tree_id):
		return
	
	var tree_data = tree_registry[tree_id]
	
	# Garante que o player está cacheado
	if not cached_player or not is_instance_valid(cached_player):
		cached_player = get_tree().get_first_node_in_group("player")
	
	# Obtém o dano do player baseado no nível de upgrade
	var damage = 1  # Dano padrão
	if cached_player and cached_player.has_method("get_tree_damage"):
		damage = cached_player.get_tree_damage()
		print("🪓 Dano aplicado à árvore: ", damage, " (Nível: ", cached_player.tree_damage_level, ")")
	
	tree_data.hits -= damage
	
	# Efeitos visuais mínimos
	tree_data.flashing = true
	tree_data.flash_timer = 0.2
	
	if tree_data.hits <= 0:
		remove_tree(tree_id)

func hit_stone(stone_id: String):
	if not stone_registry.has(stone_id):
		return
	
	var stone_data = stone_registry[stone_id]
	
	# Garante que o player está cacheado
	if not cached_player or not is_instance_valid(cached_player):
		cached_player = get_tree().get_first_node_in_group("player")
	
	# Obtém o dano do player baseado no nível de upgrade
	var damage = 1  # Dano padrão
	if cached_player and cached_player.has_method("get_tree_damage"):
		damage = cached_player.get_tree_damage()
		print("⛏️ Dano aplicado à pedra: ", damage, " (Nível: ", cached_player.tree_damage_level, ")")
	
	stone_data.hits -= damage
	
	# Efeitos visuais
	stone_data.flashing = true
	stone_data.flash_timer = 0.2
	
	if stone_data.hits <= 0:
		remove_stone(stone_id)

func remove_stone(stone_id: String):
	if not stone_registry.has(stone_id):
		return
	
	var stone_data = stone_registry[stone_id]
	
	# Cache do player
	if not cached_player or not is_instance_valid(cached_player):
		cached_player = get_tree().get_first_node_in_group("player")
	
	# Dá pedra ao player (menos que madeira - 1 a 2 pedras por pedra quebrada)
	if cached_player and cached_player.has_method("add_item"):
		var stone_amount = randi_range(1, 2)  # 1-2 pedras (menos que árvores que dão 2-5 madeiras)
		cached_player.add_item("stone", stone_amount)
		print("🪨 Player coletou ", stone_amount, " pedras")
	
	# Remove todos os tiles da pedra
	for tile_info in stone_data.tiles:
		erase_cell(tile_info.layer, tile_info.pos)
	
	# Remove o corpo de colisão
	if stone_data.has("collision_body") and is_instance_valid(stone_data.collision_body):
		stone_data.collision_body.queue_free()
		print("🪨 Colisão da pedra removida")
	
	# Registra para respawn
	stones_to_respawn[stone_id] = {
		"position": stone_data.tiles[0].pos,
		"respawn_time": Time.get_unix_time_from_system() + RESPAWN_TIME
	}
	
	# Remove do registro
	stone_registry.erase(stone_id)
	print("🪨 Pedra removida: ", stone_id)

func remove_tree(tree_id: String):
	if not tree_registry.has(tree_id):
		return
	
	var tree_data = tree_registry[tree_id]
	
	# Cache do player simples
	if not cached_player or not is_instance_valid(cached_player):
		cached_player = get_tree().get_first_node_in_group("player")
	
	# Dá madeira ao player
	if cached_player and cached_player.has_method("add_item"):
		var wood_amount = randi_range(2, 5)  # 2-5 madeiras por árvore
		cached_player.add_item("wood", wood_amount)
	
	# Remove todos os tiles da Ã¡rvore
	for tile_info in tree_data.tiles:
		set_cell(tile_info.layer, tile_info.pos, -1)
	
	# Programa respawn
	var respawn_pos = tree_data.tiles[0].pos if tree_data.tiles.size() > 0 else Vector2i.ZERO
	trees_to_respawn[tree_id] = {
		"pos": respawn_pos,
		"timer": RESPAWN_TIME
	}
	
	tree_registry.erase(tree_id)
	print("🌳 Árvore removida:", tree_id)

func spawn_test_village():
	print("🏘️ Criando vila de teste próxima ao spawn...")
	# Posição próxima ao spawn (5 tiles para a direita)
	var test_pos = Vector2i(5, 0)
	spawn_upgrade_station(test_pos)
	print("✅ Vila de teste criada em: ", test_pos)

func spawn_final_destination():
	print("🏁 Criando destinos finais...")
	
	# Carrega a cena do destino final
	var final_destination_scene = load("res://FinalDestination.tscn")
	if not final_destination_scene:
		print("❌ ERRO: Não foi possível carregar FinalDestination.tscn")
		return
	
	# 1. DESTINO DE TESTE - Próximo ao spawn
	var test_destination = final_destination_scene.instantiate()
	test_destination.name = "FinalDestination_Test"
	var test_tile_pos = Vector2i(0, 3)
	var test_world_pos = map_to_local(test_tile_pos)
	test_destination.global_position = test_world_pos
	add_child(test_destination)
	test_destination.game_completed.connect(_on_game_completed)
	print("✅ Destino TESTE criado em: ", test_world_pos)
	
	# 2. DESTINO REAL - 15.000 pixels de distância em direção aleatória
	var real_destination = final_destination_scene.instantiate()
	real_destination.name = "FinalDestination_Real"
	
	# Gera ângulo aleatório (0 a 360 graus)
	var random_angle = randf() * TAU  # TAU = 2*PI = 360 graus em radianos
	var distance = 15000.0
	
	# Calcula posição usando trigonometria
	var offset = Vector2(cos(random_angle), sin(random_angle)) * distance
	var real_world_pos = Vector2.ZERO + offset  # Spawn está em (0,0)
	
	real_destination.global_position = real_world_pos
	add_child(real_destination)
	real_destination.game_completed.connect(_on_game_completed)
	
	print("✅ Destino REAL criado a 15km de distância!")
	print("   Posição: ", real_world_pos)
	print("   Direção: ", rad_to_deg(random_angle), " graus")
	print("   Distância do spawn: ", Vector2.ZERO.distance_to(real_world_pos), " pixels")
	
	# Salva a posição do destino real para as lojas usarem
	set_meta("real_destination_pos", real_world_pos)
	
	await get_tree().process_frame
	print("✅ Ambos os destinos confirmados na árvore!")

func _on_game_completed():
	print("🎉 JOGO COMPLETADO! Parabéns ao jogador!")
	# Aqui você pode adicionar mais lógica de conclusão do jogo
	# Como salvar estatísticas, desbloquear conquistas, etc.

# ... resto do código permanece igual ...

