extends Camera2D

@export var target: NodePath : # Сюда укажем игрока
	set(new_value):
		target = new_value
		# Отложенный поиск ноды, чтобы избежать ошибки
		call_deferred("_update_target_node")

@export var use_lerp: bool = false
@export var lerp_speed: float = 2.0

var target_node: Node2D = null

func _update_target_node() -> void:
	if target != null and str(target) != "" and has_node(target):
		target_node = get_node(target)
		global_position = target_node.global_position
		use_lerp = true
	else:
		target_node = null
		# Не выводим предупреждение, если target пустой
		if str(target) != "":
			push_warning("Target node '%s' not found yet!" % target)

		

func _process(delta):
	if not target_node:
		return

	if use_lerp:
		global_position = global_position.lerp(target_node.global_position, lerp_speed * delta)
	else:
		global_position = target_node.global_position


#extends Camera2D
#
#@export var target: NodePath : # Сюда укажем игрока
	#set(new_value):
			#target = new_value
			#target_node = get_node(target)
#@export var use_lerp: bool = false
#@export var lerp_speed: float = 2.0
#
#
#
#var target_node: Node2D
#
#
#func _ready():
	#if target != null:
		#target_node = get_node(target)
		#global_position = target_node.global_position
		#use_lerp = true
#
#func _process(delta):
	#if not target_node:
		#return
#
	#if use_lerp:
		## Плавное следование
		#global_position = global_position.lerp(target_node.global_position, lerp_speed * delta)
	#else:
		## Жёсткое следование
		#global_position = target_node.global_position
	#
