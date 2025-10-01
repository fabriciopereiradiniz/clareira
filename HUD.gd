extends CanvasLayer

@onready var health_bar = $HealthBar
@onready var inventory_grid = $InventoryGrid

var player_node: CharacterBody2D = null
var inventory_visible: bool = false

# Configuração do grid - 4 linhas, 5 colunas
const GRID_SPACING = 10
const GRID_COLUMNS = 5
const GRID_ROWS = 4
const CELL_SIZE = 80

# Item icons mapping
const ITEM_ICONS = {
	"wood": "res://assets/oak_wood.png",
	# Adicione mais itens conforme necessário
}

# Caminho fixo para o background
const BACKGROUND_PATH = "res://assets/ui/inventory_background.png"

# Caminho para a imagem de fundo dos slots (luz)
const SLOT_BACKGROUND_PATH = "res://assets/light.png"

# Wrapper para centralizar
var wrapper: Control = null
var background: Control = null
var slot_background: TextureRect = null

# Variáveis para arrastar itens
var dragged_item = null
var dragged_item_original_slot = null
var is_dragging = false

func _ready() -> void:
	await get_tree().process_frame

	# Cria wrapper se não existir
	if not wrapper:
		wrapper = Control.new()
		add_child(wrapper)
		# Configura âncoras para centralizar
		wrapper.anchor_left = 0.5
		wrapper.anchor_top = 0.5
		wrapper.anchor_right = 0.5
		wrapper.anchor_bottom = 0.5
		wrapper.offset_left = 0
		wrapper.offset_top = 0
		wrapper.offset_right = 0
		wrapper.offset_bottom = 0
		
		# Carrega a textura de fundo usando o caminho fixo
		var bg_texture = load(BACKGROUND_PATH)
		
		if bg_texture:
			# Cria TextureRect para o fundo
			var texture_bg = TextureRect.new()
			texture_bg.texture = bg_texture
			texture_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			texture_bg.stretch_mode = TextureRect.STRETCH_KEEP
			texture_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			background = texture_bg
			print("Background image loaded successfully from: ", BACKGROUND_PATH)
		else:
			# Fallback para um retângulo colorido
			print("Background image not found at: ", BACKGROUND_PATH, ". Using fallback color.")
			var color_bg = ColorRect.new()
			color_bg.color = Color(0.1, 0.1, 0.1, 0.9)
			background = color_bg
		
		wrapper.add_child(background)
		
		# Adiciona a imagem de fundo dos slots (luz) atrás dos itens
		var light_texture = load(SLOT_BACKGROUND_PATH)
		if light_texture:
			slot_background = TextureRect.new()
			slot_background.texture = light_texture
			slot_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			slot_background.stretch_mode = TextureRect.STRETCH_KEEP
			slot_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			wrapper.add_child(slot_background)
			slot_background.z_index = -1  # Coloca atrás dos slots
			print("Slot background image loaded successfully from: ", SLOT_BACKGROUND_PATH)
		
		# Remove inventory_grid do parent atual e adiciona ao wrapper
		remove_child(inventory_grid)
		wrapper.add_child(inventory_grid)
		
		wrapper.visible = false

	inventory_grid.columns = GRID_COLUMNS
	inventory_grid.add_theme_constant_override("hseparation", GRID_SPACING)
	inventory_grid.add_theme_constant_override("vseparation", GRID_SPACING)

	# Busca Player
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_node = players[0]
		
		# Conecta sinais se existirem
		if player_node.has_signal("health_changed"):
			player_node.health_changed.connect(update_health)
		else:
			print("Player node does not have health_changed signal")
			
		if player_node.has_signal("inventory_changed"):
			player_node.inventory_changed.connect(update_inventory)
		else:
			print("Player node does not have inventory_changed signal")
			
		# Atualiza UI com valores atuais
		if "health" in player_node:
			update_health(player_node.health)
		else:
			print("Player node does not have health property")
			
		update_inventory()
	else:
		print("⚠ Nenhum player encontrado no grupo 'player'!")

	# Health bar fixa
	health_bar.anchor_left = 0
	health_bar.anchor_top = 0
	health_bar.anchor_right = 0
	health_bar.anchor_bottom = 0
	health_bar.position = Vector2(10, 10)

func _input(event):
	if event.is_action_pressed("ui_inventory"):
		toggle_inventory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if inventory_visible:
			inventory_visible = false
			wrapper.visible = false
			get_viewport().set_input_as_handled()
	
	# Handle mouse events for dragging items
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not is_dragging:
			# Check if clicked on an item
			var mouse_pos = get_global_mouse_position()
			for i in range(inventory_grid.get_child_count()):
				var slot = inventory_grid.get_child(i)
				if slot.get_global_rect().has_point(mouse_pos) and slot.has_meta("item"):
					dragged_item = slot.get_meta("item")
					dragged_item_original_slot = i
					is_dragging = true
					slot.remove_meta("item")
					# Hide the original item
					for child in slot.get_children():
						if child is Control:
							child.visible = false
					break
		elif not event.pressed and is_dragging:
			# Drop the item
			var mouse_pos = get_global_mouse_position()
			var target_slot = -1
			
			for i in range(inventory_grid.get_child_count()):
				var slot = inventory_grid.get_child(i)
				if slot.get_global_rect().has_point(mouse_pos):
					target_slot = i
					break
			
			if target_slot != -1 and target_slot != dragged_item_original_slot:
				# Move item to new slot
				move_item(dragged_item_original_slot, target_slot)
			else:
				# Return item to original slot
				return_item_to_original_slot()
			
			dragged_item = null
			dragged_item_original_slot = null
			is_dragging = false
	
	# Update dragged item position
	if is_dragging and dragged_item:
		# You could show a preview of the dragged item at mouse position
		pass

func toggle_inventory():
	inventory_visible = !inventory_visible
	wrapper.visible = inventory_visible
	
	if inventory_visible:
		center_inventory_grid()
		# Atualiza o inventário quando abre para garantir conteúdo fresco
		update_inventory()
		
	# Debug para verificar se a função está sendo chamada
	print("Inventory toggled. Visible: ", inventory_visible)

func update_health(value: int) -> void:
	if health_bar:
		health_bar.value = value

func update_inventory() -> void:
	if not player_node or not wrapper:
		print("Cannot update inventory: player_node or wrapper is null")
		return

	# Limpa células antigas
	for child in inventory_grid.get_children():
		child.queue_free()

	# Cria slots vazios (4x5 grid)
	for i in range(GRID_ROWS * GRID_COLUMNS):
		var slot = PanelContainer.new()
		slot.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
		slot.size = Vector2(CELL_SIZE, CELL_SIZE)
		
		# Create a simple style for the panel
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.2, 0.2, 0.5)  # Semi-transparent
		style.border_color = Color(0.8, 0.8, 0.8)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		slot.add_theme_stylebox_override("panel", style)
		
		inventory_grid.add_child(slot)

	# Verifica se o player tem inventário
	var inventory = {}
	if "inventory" in player_node:
		inventory = player_node.inventory
	else:
		print("Player does not have inventory property")
		return

	# Preenche os slots com itens
	var slot_index = 0
	for item in inventory.keys():
		if slot_index >= GRID_ROWS * GRID_COLUMNS:
			break
			
		var amount = inventory[item]
		var slot = inventory_grid.get_child(slot_index)
		
		# Container para o conteúdo do slot
		var slot_content = Control.new()
		slot_content.size = slot.size
		slot.add_child(slot_content)
		
		# Adiciona o ícone do item se disponível
		if item in ITEM_ICONS:
			var icon_texture = load(ITEM_ICONS[item])
			if icon_texture:
				var icon = TextureRect.new()
				icon.texture = icon_texture
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				icon.size = Vector2(CELL_SIZE - 16, CELL_SIZE - 16)
				icon.position = Vector2(8, 8)
				slot_content.add_child(icon)
		
		# Adiciona a quantidade no canto inferior direito
		var quantity_label = Label.new()
		quantity_label.text = "x" + str(amount)
		quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		quantity_label.add_theme_color_override("font_color", Color(1, 1, 1))
		quantity_label.add_theme_font_size_override("font_size", 14)
		
		# Fundo semi-transparente para a quantidade
		var amount_bg = ColorRect.new()
		amount_bg.color = Color(0, 0, 0, 0.7)
		amount_bg.size = Vector2(30, 20)
		amount_bg.position = Vector2(CELL_SIZE - 32, CELL_SIZE - 22)
		slot_content.add_child(amount_bg)
		
		# Posiciona a quantidade
		quantity_label.position = Vector2(CELL_SIZE - 30, CELL_SIZE - 20)
		quantity_label.size = Vector2(25, 15)
		slot_content.add_child(quantity_label)
		
		# Store item data in slot metadata
		slot.set_meta("item", {"name": item, "amount": amount})
		
		slot_index += 1

	center_inventory_grid()

func center_inventory_grid():
	if not wrapper or not inventory_grid:
		return

	# Calculate grid size
	var grid_width = GRID_COLUMNS * CELL_SIZE + (GRID_COLUMNS - 1) * GRID_SPACING
	var grid_height = GRID_ROWS * CELL_SIZE + (GRID_ROWS - 1) * GRID_SPACING

	# Set inventory grid size
	inventory_grid.size = Vector2(grid_width, grid_height)
	
	# Position the inventory grid in the center of the background
	if background:
		inventory_grid.position = (background.size - inventory_grid.size) * 0.5
	
	# Position the slot background behind the inventory grid
	if slot_background:
		slot_background.size = inventory_grid.size
		slot_background.position = inventory_grid.position
	
	# Center the wrapper in the viewport
	var viewport_size = get_viewport().get_visible_rect().size
	wrapper.position = (viewport_size - background.size) * 0.5
	
	# Debug para verificar posições
	print("Viewport size: ", viewport_size)
	print("Background size: ", background.size)
	print("Inventory grid size: ", inventory_grid.size)
	print("Inventory grid position: ", inventory_grid.position)
	print("Wrapper position: ", wrapper.position)

func move_item(from_slot, to_slot):
	# Implement your item movement logic here
	print("Moving item from slot ", from_slot, " to slot ", to_slot)
	
	# Update the UI to reflect the move
	update_inventory()

func return_item_to_original_slot():
	# Implement logic to return item to its original slot
	print("Returning item to original slot")
	
	# Update the UI to reflect the return
	update_inventory()
