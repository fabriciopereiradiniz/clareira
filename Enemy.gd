extends CharacterBody2D

@export var SPEED: float = 40  # Reduzido de 80 para 40 (50% mais lento)
@export var HEALTH: int = 50

var target: Node2D = null
var damage_cooldown: float = 0.0
var damage_interval: float = 1.0  # Dano a cada 1 segundo
var last_collision_count: int = 0  # Para detectar novas colisões

func _ready():
	# Procura o player automaticamente
	target = get_tree().get_nodes_in_group("player")[0] if get_tree().has_group("player") else null
	# Adiciona ao grupo de inimigos
	add_to_group("enemies")

func _physics_process(delta):
	if not target:
		return

	# Reduz cooldown de dano
	if damage_cooldown > 0:
		damage_cooldown -= delta

	# Movimento simples em direção ao player
	var dir = (target.global_position - global_position).normalized()
	velocity = dir * SPEED
	move_and_slide()
	
	# Verifica se houve colisão física real
	var collision_count = get_slide_collision_count()
	if collision_count > 0 and damage_cooldown <= 0:
		for i in range(collision_count):
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			if collider == target:
				target.take_damage(0.5)  # Meio coração de dano
				damage_cooldown = damage_interval
				print("👾 Inimigo colidiu fisicamente com o player!")
				break

func take_damage(amount: int):
	HEALTH -= amount
	print("👾 Inimigo perdeu ", amount, " de vida. Vida atual: ", HEALTH)
	if HEALTH <= 0:
		die()

func die():
	print("👾 Inimigo morreu!")
	queue_free()
