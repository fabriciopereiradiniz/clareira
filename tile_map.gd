extends TileMap

const CHUNK_SIZE = 32
const RENDER_DISTANCE = 2

const green_block_atlas_pos = Vector2i(2, 0)
const tree_trunk_atlas_pos = Vector2i(0, 0)
const tree_leaf_atlas_pos = Vector2i(1, 0)
const bush_atlas_pos = Vector2i(3, 0)
const boundary_atlas_pos = Vector2i(0, 1)
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
const RESPAWN_TIME = 30.0

var noise = FastNoiseLite.new()
var generated_chunks = {}
var tree_registry = {}
var trees_to_respawn = {}
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

	# Respawn de Ã¡rvores (otimizado)
	if not trees_to_respawn.is_empty():
		_process_tree_respawns(delta)

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

func chop_tree_at(pos: Vector2i):
	# FunÃ§Ã£o legacy - usa a versÃ£o otimizada
	chop_tree_at_fast(pos)

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
	
	# Dano simples e eficiente - sem busca do player a cada hit
	var damage = 1  # Dano padrão por enquanto
	tree_data.hits -= damage
	
	# Efeitos visuais mínimos
	tree_data.flashing = true
	tree_data.flash_timer = 0.2
	
	if tree_data.hits <= 0:
		remove_tree(tree_id)
	
	if tree_data.hits <= 0:
		remove_tree(tree_id)

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

# ... resto do código permanece igual ...

