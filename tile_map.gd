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

var noise = FastNoiseLite.new()
var generated_chunks = {}

# Guarda as árvores por ID
# { "tiles": [ {layer, pos} ], "hits": int, "flashing": bool, "flash_timer": float, "shake_timer": float }
var tree_registry = {}

# Guarda árvores para respawn: tree_id -> { "pos": Vector2i, "timer": float }
var trees_to_respawn = {}
const RESPAWN_TIME = 30.0  # segundos

func _ready():
	randomize()
	noise.seed = randi()
	noise.frequency = 0.15
	noise.fractal_octaves = 3

func _process(delta):
	var cam = get_viewport().get_camera_2d()
	if not cam:
		return
	var pt = local_to_map(to_local(cam.global_position))
	var pc = Vector2i(floor(pt.x / CHUNK_SIZE), floor(pt.y / CHUNK_SIZE))
	for cx in range(pc.x - RENDER_DISTANCE, pc.x + RENDER_DISTANCE + 1):
		for cy in range(pc.y - RENDER_DISTANCE, pc.y + RENDER_DISTANCE + 1):
			var id = Vector2i(cx, cy)
			if not generated_chunks.has(id):
				generate_chunk(id)
				generated_chunks[id] = true

	# Atualiza efeito de piscar e tremer
	_update_tree_effects(delta)
	
	# Atualiza timers de respawn
	for tree_id in trees_to_respawn.keys():
		trees_to_respawn[tree_id]["timer"] -= delta
		if trees_to_respawn[tree_id]["timer"] <= 0:
			# Respawna árvore
			place_tree_natural(trees_to_respawn[tree_id]["pos"])
			trees_to_respawn.erase(tree_id)
			print("🌳 Árvore respawnada:", tree_id)

func generate_chunk(chunk_id: Vector2i) -> void:
	var base_x = chunk_id.x * CHUNK_SIZE
	var base_y = chunk_id.y * CHUNK_SIZE
	for y in range(CHUNK_SIZE):
		for x in range(CHUNK_SIZE):
			var pos = Vector2i(base_x + x, base_y + y)
			set_cell(layers.level0, pos, main_source, green_block_atlas_pos)
			
			var dist = Vector2(pos).distance_to(Vector2.ZERO)
			if dist > 8.0 and (pos.x % BASE_TREE_SPACING == 0 and pos.y % BASE_TREE_SPACING == 0):
				var v = noise.get_noise_2d(pos.x, pos.y)
				if v > NOISE_THRESHOLD_TREE:
					place_tree_natural(pos)
				elif v > NOISE_THRESHOLD_BUSH:
					place_bush(pos)
	place_boundaries_chunk(base_x, base_y)

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

	tree_registry[tree_id] = {
		"tiles": tiles,
		"hits": 3,  # número de hits necessários para derrubar a árvore
		"flashing": false,
		"flash_timer": 0.0,
		"shake_timer": 0.0,
		"original_positions": tiles.map(func(t): return t.pos)  # salvar posições originais pra tremor
	}

func place_bush(pos: Vector2i):
	var h = randi() % 2 + 1
	for i in range(h):
		var l = layers.level1 + i
		if l <= layers.level6:
			set_cell(l, pos, main_source, bush_atlas_pos)

func place_boundaries_chunk(base_x: int, base_y: int):
	var offs = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]
	for y in range(CHUNK_SIZE):
		for x in range(CHUNK_SIZE):
			var spot = Vector2i(base_x + x, base_y + y)
			for o in offs:
				var s2 = spot + o
				if get_cell_source_id(layers.level0, s2) == -1:
					set_cell(layers.level0, s2, main_source, boundary_atlas_pos)

func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var camera = get_viewport().get_camera_2d()
		if not camera:
			print("❌ Camera não encontrada")
			return

		var world_pos = camera.get_global_mouse_position()
		# Ajuste do clique para alinhamento do tile
		var clicked_tile = local_to_map(to_local(world_pos)) + Vector2i(-1, -1)
		print("📍 Tile clicado:", clicked_tile)

		var player_node = get_node_or_null("CharacterBody2D")
		if not player_node:
			print("❌ Player não encontrado")
			return

		var player_tile = local_to_map(to_local(player_node.global_position))
		var distance = Vector2(player_tile).distance_to(Vector2(clicked_tile))
		print("📏 Distância até o player:", distance)

		if distance > 3.0:
			print("⛔ Fora do alcance")
			return

		# Tenta achar árvore no tile clicado
		for tree_id in tree_registry.keys():
			for tile_data in tree_registry[tree_id]["tiles"]:
				if tile_data.pos == clicked_tile:
					# Diminui hit e inicia efeito
					tree_registry[tree_id]["hits"] -= 1
					tree_registry[tree_id]["flashing"] = true
					tree_registry[tree_id]["flash_timer"] = 0.0
					tree_registry[tree_id]["shake_timer"] = 0.3  # duração do tremor em segundos
					print("🌳 Árvore atingida! Hits restantes:", tree_registry[tree_id]["hits"])

					# Se acabar os hits, remove a árvore e agenda respawn
					if tree_registry[tree_id]["hits"] <= 0:
						# Salva posição para respawn
						var original_pos = tree_registry[tree_id]["tiles"][0].pos
						trees_to_respawn[tree_id] = {
							"pos": original_pos,
							"timer": RESPAWN_TIME
						}

						# ---- LOOT ----
						if player_node and player_node.has_method("add_item"):
							var qtd = randi_range(2, 4) # quantidade de madeira
							player_node.add_item("wood", qtd)
							print("🪵 Player recebeu %d madeira(s)" % qtd)

						# Remove tiles
						for t in tree_registry[tree_id]["tiles"]:
							erase_cell(t.layer, t.pos)
						tree_registry.erase(tree_id)
						print("🌲 Árvore derrubada! Será respawnada em 30s")
					return

func _update_tree_effects(delta):
	for tree_id in tree_registry.keys():
		var tree = tree_registry[tree_id]

		if tree["flashing"]:
			tree["flash_timer"] += delta
			# Pisca em branco a cada 0.1s
			var flash_phase = int(tree["flash_timer"] * 10) % 2
			for tile_data in tree["tiles"]:
				if flash_phase == 0:
					set_cell(tile_data.layer, tile_data.pos, main_source, Vector2i(4, 0)) # exemplo de tile branco
				else:
					if tile_data.layer < layers.level6:
						set_cell(tile_data.layer, tile_data.pos, main_source, tree_trunk_atlas_pos)
					else:
						set_cell(tile_data.layer, tile_data.pos, main_source, tree_leaf_atlas_pos)

			if tree["flash_timer"] > 0.5:
				tree["flashing"] = false
				for tile_data in tree["tiles"]:
					if tile_data.layer < layers.level6:
						set_cell(tile_data.layer, tile_data.pos, main_source, tree_trunk_atlas_pos)
					else:
						set_cell(tile_data.layer, tile_data.pos, main_source, tree_leaf_atlas_pos)

		if tree["shake_timer"] > 0:
			tree["shake_timer"] -= delta
			var offset = Vector2i(1 if randf() > 0.5 else -1, 1 if randf() > 0.5 else -1)
			for tile_data in tree["tiles"]:
				set_cell(tile_data.layer, tile_data.pos, main_source, Vector2i(4, 0))
			if tree["shake_timer"] <= 0:
				for tile_data in tree["tiles"]:
					if tile_data.layer < layers.level6:
						set_cell(tile_data.layer, tile_data.pos, main_source, tree_trunk_atlas_pos)
					else:
						set_cell(tile_data.layer, tile_data.pos, main_source, tree_leaf_atlas_pos)
