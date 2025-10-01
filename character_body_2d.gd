extends CharacterBody2D

const TILE_SIZE = 32
const HALF_TILE = TILE_SIZE / 2
const SPEED = 160

# --- VIDA ---
@export var max_health: int = 100
var health: int = max_health
signal health_changed(new_health)

# --- INVENTÁRIO ---
var inventory := {}  # exemplo: { "wood": 5, "apple": 2 }
signal inventory_changed()

# --- MOVIMENTO ---
var target_position: Vector2
var moving: bool = false

func _ready() -> void:
	# Snap inicial para o centro do tile
	target_position = (position - Vector2(HALF_TILE, HALF_TILE)).snapped(Vector2(TILE_SIZE, TILE_SIZE)) + Vector2(HALF_TILE, HALF_TILE)
	position = target_position
	
	if $Camera2D is Camera2D:
		$Camera2D.position = Vector2.ZERO
		$Camera2D.make_current()
	else:
		print("Camera2D não encontrada.")

func _physics_process(delta: float) -> void:
	if moving:
		position = position.move_toward(target_position, SPEED * delta)
		if position.distance_to(target_position) < 1:
			position = target_position
			moving = false
	else:
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

# ======================
#        VIDA
# ======================
func take_damage(amount: int):
	health = max(0, health - amount)
	emit_signal("health_changed", health)
	if health <= 0:
		die()

func heal(amount: int):
	health = min(max_health, health + amount)
	emit_signal("health_changed", health)

func die():
	print("💀 Player morreu")

# ======================
#     INVENTÁRIO
# ======================
func add_item(item_name: String, amount: int = 1):
	if not inventory.has(item_name):
		inventory[item_name] = 0
	inventory[item_name] += amount
	emit_signal("inventory_changed")

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
