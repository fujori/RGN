extends Camera2D

@export var target: NodePath    # Сюда укажем игрока
@export var use_lerp: bool = false
@export var lerp_speed: float = 2.0



var target_node: Node2D


func _ready():
	if target != null:
		target_node = get_node(target)
		global_position = target_node.global_position
		use_lerp = true

func _process(delta):
	if not target_node:
		return

	if use_lerp:
		# Плавное следование
		global_position = global_position.lerp(target_node.global_position, lerp_speed * delta)
	else:
		# Жёсткое следование
		global_position = target_node.global_position
	
