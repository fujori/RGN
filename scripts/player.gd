extends CharacterBody2D

# Параметры движения
@export var max_speed: float = 350.0
@export var acceleration: float = 2000.0
@export var friction_stop: float = 1500.0
@export var friction_turn: float = 3500.0
@export var air_friction: float = 0.0

# Параметры прыжка
@export var jump_force: float = -750.0
@export var gravity: float = 2000.0
@export var coyote_time: float = 0.1
@export var jump_buffer: float = 0.1

# Состояния
var impulse: float = 0.0
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

var input_direction: int = 0
var input_jump_pressed: bool = false
var input_jump_just_pressed: bool = false


func _physics_process(delta: float) -> void:
	_read_input()
	_update_timers(delta)
	
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0
	
	_handle_horizontal_movement(delta)
	_handle_jump()
	
	move_and_slide()


func _read_input() -> void:
	var left = Input.is_action_pressed("ui_left")
	var right = Input.is_action_pressed("ui_right")
	
	input_direction = 0
	if left and not right:
		input_direction = -1
	elif right and not left:
		input_direction = 1

	input_jump_pressed = Input.is_action_pressed("ui_up")
	input_jump_just_pressed = Input.is_action_just_pressed("ui_up")


func _update_timers(delta: float) -> void:
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer = max(0.0, coyote_timer - delta)

	if input_jump_just_pressed:
		jump_buffer_timer = jump_buffer
	else:
		jump_buffer_timer = max(0.0, jump_buffer_timer - delta)


func _handle_horizontal_movement(delta: float) -> void:
	if is_on_floor():
		if input_direction != 0:
			if sign(impulse) != 0 and sign(impulse) != input_direction:
				impulse = move_toward(impulse, 0.0, friction_turn * delta)
			else:
				impulse += input_direction * acceleration * delta
				impulse = clamp(impulse, -max_speed, max_speed)
		else:
			impulse = move_toward(impulse, 0.0, friction_stop * delta)
	else:
		# Воздух: только слабое трение, без ускорения
		impulse = move_toward(impulse, 0.0, air_friction * delta)

	velocity.x = impulse


func _handle_jump() -> void:
	var can_jump = is_on_floor() or coyote_timer > 0.0
	if (input_jump_just_pressed or jump_buffer_timer > 0.0) and can_jump:
		velocity.y = jump_force
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
