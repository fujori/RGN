extends CharacterBody2D

# -------------------------
# Параметры движения
# -------------------------
## Максимальная скорость по X (пикс/сек)
@export_custom(PROPERTY_HINT_RANGE, "0,200000,1")
var max_speed: float = 2000.0

## Ускорение по земле (пикс/сек²)
@export_custom(PROPERTY_HINT_RANGE, "0,200000,1")
var acceleration_ground: float = 10000.0

## Ускорение в воздухе (пикс/сек²)
@export_custom(PROPERTY_HINT_RANGE, "0,20000,1")
var acceleration_air: float = 3000.0

## Трение при остановке на земле
@export_custom(PROPERTY_HINT_RANGE, "0,20000,1")
var friction_stop: float = 5500.0

## Трение при смене направления (земля)
@export_custom(PROPERTY_HINT_RANGE, "0,100000,1")
var friction_turn: float = 50000.0

## Воздушное сопротивление
@export_custom(PROPERTY_HINT_RANGE, "0,20000,1")
var air_friction: float = 500.0


# -------------------------
# Прыжок
# -------------------------
## Сила гравитации (px/s²)
@export_custom(PROPERTY_HINT_RANGE, "0,20000,1")
var gravity: float = 18000.0

## Сила прыжка (px/s) — отрицательная (вверх)
@export_custom(PROPERTY_HINT_RANGE, "-20000,0,1")
var jump_force: float = -6000.0

## "Coyote time"
@export_custom(PROPERTY_HINT_RANGE, "0.0,0.5,0.01")
var coyote_time: float = 0.1

## Jump buffer
@export_custom(PROPERTY_HINT_RANGE, "0.0,0.5,0.01")
var jump_buffer: float = 0.1


# -------------------------
# Управление высотой прыжка
# -------------------------
## Минимальная сила при раннем отпускании
@export_custom(PROPERTY_HINT_RANGE, "-20000,0,1")
var short_jump_force: float = -600.0


# -------------------------
# Debug
# -------------------------
@export var force_reset_on_start: bool = false

# --- Анимации ---
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

# --- Состояния ---
enum PlayerState { IDLE, WALK, JUMP_START, JUMP, FLY, LAND }
var current_state: PlayerState = PlayerState.IDLE

# Input
var input_direction: int = 0
var input_jump_pressed: bool = false
var input_jump_just_pressed: bool = false

# Timers
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var is_jump_held: bool = false



func _physics_process(delta: float) -> void:
	_read_input()
	_update_timers(delta)
	_apply_gravity(delta)
	_handle_horizontal(delta)
	_handle_jump_logic()
	_update_state()
	_update_speed_scale()
	move_and_slide()




func init_player(_name: String, _position: Vector2) -> void:
	self.name = _name
	global_position = _position

# --- INPUT ---
func _read_input() -> void:
	input_jump_pressed = Input.is_action_pressed("ui_up")
	input_jump_just_pressed = Input.is_action_just_pressed("ui_up")
	is_jump_held = input_jump_pressed

	var left = Input.is_action_pressed("ui_left")
	var right = Input.is_action_pressed("ui_right")

	input_direction = 0
	if left and not right:
		input_direction = -1
	elif right and not left:
		input_direction = 1


# --- TIMERS ---
func _update_timers(delta: float) -> void:
	coyote_timer = coyote_time if is_on_floor() else max(0.0, coyote_timer - delta)
	jump_buffer_timer = jump_buffer if input_jump_just_pressed else max(0.0, jump_buffer_timer - delta)


# --- GRAVITY ---
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta


# --- HORIZONTAL ---
#func _handle_horizontal(delta: float) -> void:
	#if input_direction != 0:
		#if is_on_floor() and sign(velocity.x) != 0 and sign(velocity.x) != input_direction:
			## трение при смене направления
			#velocity.x = move_toward(velocity.x, 0.0, friction_turn * delta)
		#else:
			## ускорение в сторону ввода
			#var accel = acceleration_ground if is_on_floor() else acceleration_air
			#velocity.x = move_toward(velocity.x, input_direction * max_speed, accel * delta)
		#anim_sprite.flip_h = input_direction < 0
	#else:
		## нет ввода — обычное трение
		#var fric = friction_stop if is_on_floor() else air_friction
		#velocity.x = move_toward(velocity.x, 0.0, fric * delta)

func _handle_horizontal(delta: float) -> void:
	if input_direction != 0:
		if is_on_floor():
			# На земле обычная логика с трением при смене направления
			if sign(velocity.x) != 0 and sign(velocity.x) != input_direction:
				velocity.x = move_toward(velocity.x, 0.0, friction_turn * delta)
			else:
				var accel = acceleration_ground
				velocity.x = move_toward(velocity.x, input_direction * max_speed, accel * delta)
		else:
			# В воздухе (FLY)
			if current_state == PlayerState.FLY and sign(velocity.x) != 0 and sign(velocity.x) != input_direction:
				# Инвертируем импульс
				velocity.x = -velocity.x
			# Накопление ускорения в сторону ввода
			var accel = acceleration_air
			velocity.x = move_toward(velocity.x, input_direction * max_speed, accel * delta)

		anim_sprite.flip_h = input_direction < 0
	else:
		# Нет ввода — трение/воздушное сопротивление
		var fric = friction_stop if is_on_floor() else air_friction
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)



# --- JUMP ---
func _handle_jump_logic() -> void:
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = jump_force
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		_set_state(PlayerState.JUMP_START)

	# короткий прыжок
	if not is_jump_held and velocity.y < 0:
		velocity.y = max(velocity.y, short_jump_force)


# --- STATE ---
func _update_state() -> void:
	match current_state:
		PlayerState.IDLE, PlayerState.WALK:
			if not is_on_floor():
				_set_state(PlayerState.FLY)
			elif abs(velocity.x) < 5 and input_direction == 0:
				_set_state(PlayerState.IDLE)
			else:
				_set_state(PlayerState.WALK)

		PlayerState.JUMP_START, PlayerState.JUMP:
			if velocity.y >= 0:
				_set_state(PlayerState.FLY)

		PlayerState.FLY:
			if is_on_floor():
				_set_state(PlayerState.LAND)

		PlayerState.LAND:
			if anim_sprite.animation == "Land" and not anim_sprite.is_playing():
				if abs(velocity.x) > 5 or input_direction != 0:
					_set_state(PlayerState.WALK)
				else:
					_set_state(PlayerState.IDLE)


func _update_speed_scale():
	match current_state:
		PlayerState.LAND:
			anim_sprite.speed_scale = 5.0
		_:
			anim_sprite.speed_scale = max(1.0, abs(velocity.length() / 400.0))


# --- STATE CHANGER ---
func _set_state(new_state: PlayerState) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	match current_state:
		PlayerState.IDLE:
			anim_sprite.play("Idle")
		PlayerState.WALK:
			anim_sprite.play("Walk")
		PlayerState.JUMP_START:
			anim_sprite.play("Jump_start")
		PlayerState.JUMP:
			anim_sprite.play("Jump")
		PlayerState.FLY:
			anim_sprite.play("Fly")
		PlayerState.LAND:
			anim_sprite.play("Land")
			
#func _set_state(new_state: PlayerState) -> void:
	#if current_state == new_state:
		#return
	#current_state = new_state
#
	## Если anim_sprite не найден, ничего не делаем
	#if not anim_sprite:
		#printerr("AnimatedSprite2D not found, setting default animation 'Idle'")
		#return
#
	#var anim_name : String 
	#match current_state:
		#PlayerState.IDLE: anim_name = "Idle"
		#PlayerState.WALK: anim_name = "Walk"
		#PlayerState.JUMP_START: anim_name = "Jump_start"
		#PlayerState.JUMP: anim_name = "Jump"
		#PlayerState.FLY: anim_name = "Fly"
		#PlayerState.LAND: anim_name = "Land"
		#_: "Idle"
#
	#if anim_sprite.sprite_frames.has_animation(anim_name):
		#anim_sprite.play(anim_name)
	#elif anim_sprite.sprite_frames.has_animation("Idle"):
		#anim_sprite.play("Idle")
	#else:
		#printerr("Neither animation '%s' nor 'Idle' found" % anim_name)
