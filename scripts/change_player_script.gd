extends Node

@export var script_a: Script   # player.gd
@export var script_b: Script   # player_free.gd
@export var camera_node: Node

var player_node: Node = null
var using_script_a: bool = true

func _ready():
	player_node = get_parent().get_node_or_null("Player")
	if not player_node:
		push_warning("Player node not found as sibling!")

# Создаём публичный метод, который можно вызвать через сигнал
func switch_script():
	_switch_script()

func _switch_script():
	if not player_node:
		return

	var parent = get_parent()
	if not parent:
		return

	# Сохраняем позицию и имя
	var _pos = player_node.global_position
	var _name = "Player"  # всегда Player

	# Выбираем новый скрипт
	var new_script: Script = script_b if using_script_a else script_a
	using_script_a = !using_script_a

	# Удаляем старого игрока
	parent.remove_child(player_node)
	player_node.free()
	player_node = null

	# Загружаем сцену и создаём нового игрока
	var scene_res = load("res://scenes/main_scenes/player.tscn")
	var new_player = scene_res.instantiate()

	# Добавляем в сцену до присвоения скрипта
	parent.add_child(new_player)

	# Присваиваем имя и позицию
	new_player.name = _name
	new_player.global_position = _pos

	# Присваиваем скрипт
	new_player.set_script(new_script)

	# Инициализируем anim_sprite
	if new_player.has_node("AnimatedSprite2D"):
		new_player.anim_sprite = new_player.get_node("AnimatedSprite2D")

	# Сохраняем ссылку
	player_node = new_player

	# Привязываем камеру
	if camera_node:
		camera_node.target = get_path_to(player_node)


#
#extends Node
#
#@export var script_a: Script   # player.gd
#@export var script_b: Script   # player_free.gd
#@export var camera_node: Node
#
#var player_node: Node = null
#var using_script_a: bool = true
#
#func _ready():
	#player_node = get_parent().get_node_or_null("Player")
	#if not player_node:
		#push_warning("Player node not found as sibling!")
#
#func _process(_delta):
	#if Input.is_action_just_pressed("ui_accept"):  # пробел
		#_switch_script()
#
#func _switch_script():
	#if not player_node:
		#return
#
	#var parent = get_parent()
	#if not parent:
		#return
#
	## Сохраняем позицию и имя
	#var _pos = player_node.global_position
	#var _name = "Player"  # всегда Player
#
	## Выбираем новый скрипт
	#var new_script: Script = script_b if using_script_a else script_a
	#using_script_a = !using_script_a
#
	## Удаляем старого игрока
	#parent.remove_child(player_node)
	#player_node.free()
#
	#player_node = null
#
	## Загружаем сцену и создаём нового игрока
	#var scene_res = load("res://scenes/main_scenes/player.tscn")
	#var new_player = scene_res.instantiate()
#
	## Добавляем в сцену до присвоения скрипта
	#parent.add_child(new_player)
#
	## Присваиваем имя и позицию
	#new_player.name = _name
	#new_player.global_position = _pos
#
	## Присваиваем скрипт
	#new_player.set_script(new_script)
#
	## Инициализируем anim_sprite
	#if new_player.has_node("AnimatedSprite2D"):
		#new_player.anim_sprite = new_player.get_node("AnimatedSprite2D")
#
	## Сохраняем ссылку
	#player_node = new_player
#
	## Привязываем камеру
	#if camera_node:
		#camera_node.target = get_path_to(player_node)
