extends CharacterBody2D

# -------------------------
# Параметры движения (экспортируемые)
# -------------------------
## Максимальная скорость движения по X (пиксели/сек)
@export_custom(PROPERTY_HINT_RANGE, "0,1000,1")
var max_speed: float = 500.0

## Ускорение при движении влево/вправо (пиксели/сек²)
@export_custom(PROPERTY_HINT_RANGE, "0,10000,1")
var acceleration: float = 4400.0

## Трение при остановке на земле (пиксели/сек²)
@export_custom(PROPERTY_HINT_RANGE, "0,10000,1")
var friction_stop: float = 2500.0

## Трение при смене направления (тормоз поворота)
@export_custom(PROPERTY_HINT_RANGE, "0,10000,1")
var friction_turn: float = 6000.0

## Воздушное сопротивление (px/s²)
@export_custom(PROPERTY_HINT_RANGE, "0,10000,1")
var air_friction: float = 0.0


# -------------------------
# Прыжок / физика
# -------------------------
## Сила гравитации (положительное — вниз), px/s²
@export_custom(PROPERTY_HINT_RANGE, "0,20000,1")
var gravity: float = 2000.0

## Coyote time — время после схода с края, когда ещё можно прыгнуть (сек)
@export_custom(PROPERTY_HINT_RANGE, "0.0,1.0,0.01")
var coyote_time: float = 0.1

## Jump buffer — сколько секунд раньше можно нажать прыжок (сек)
@export_custom(PROPERTY_HINT_RANGE, "0.0,1.0,0.01")
var jump_buffer: float = 0.1


# -------------------------
# Управление высотой прыжка
# -------------------------
## Максимальное время удержания кнопки прыжка (сек)
@export_custom(PROPERTY_HINT_RANGE, "0.1,1.0,0.01")
var jump_max_hold_time: float = 1.0

## Минимальное время удержания кнопки прыжка (сек)
@export_custom(PROPERTY_HINT_RANGE, "0.01,0.5,0.01")
var jump_min_hold_time: float = 0.5

## Сила прыжка при минимальном удержании (отрицательное — вверх)
@export_custom(PROPERTY_HINT_RANGE, "-2000,1000,1")
var jump_min_force: float = -400.0

## Сила прыжка при максимальном удержании (отрицательное — вверх)
@export_custom(PROPERTY_HINT_RANGE, "-12000,1500,1")
var jump_max_force: float = -1500.0


# -------------------------
# Горизонтальный импульс при старте прыжка
# -------------------------
## Минимальный горизонтальный импульс при старте прыжка (px/s)
@export_custom(PROPERTY_HINT_RANGE, "0,1000,1")
var jump_min_horizontal: float = 0.0

## Максимальный горизонтальный импульс при старте прыжка (px/s)
@export_custom(PROPERTY_HINT_RANGE, "0,2000,1")
var jump_max_horizontal: float = 1000.0

## Время накопления горизонтального импульса прыжка (сек)
@export_custom(PROPERTY_HINT_RANGE, "0.05,1.0,0.01")
var jump_start_hold_time: float = 0.25


# -------------------------
# Опции отладки
# -------------------------
## Принудительно применять значения из скрипта при старте (удобно для теста)
@export
var force_reset_on_start: bool = false


# --- Анимации ---
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

# --- Состояния / движение ---
enum PlayerState { IDLE, WALK, JUMP_START, JUMP, FLY, LAND }
var current_state: PlayerState = PlayerState.IDLE

# первичное хранение скорости — используем velocity.x
var impulse: float = 0.0
var input_direction: int = 0

# таймеры/флаги прыжка
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var input_jump_pressed: bool = false
var input_jump_just_pressed: bool = false
var jump_pending: bool = false
var is_jump_released: bool = true

# Jump_start допы
@export_range(0.0, 1.0, 0.01)
var stored_impulse_lifetime: float = 0.3
var stored_impulse: float = 0.0
var stored_impulse_timer: float = 0.0
var jump_start_timer: float = 0.0
var jump_hold_timer: float = 0.0
var jump_direction: int = 0
var accumulated_impulse: float = 0.0

func _ready():
	# Отладка — распечатаем реальные значения, чтобы увидеть, что инспектор реально даёт
	print("[Player] in _ready: max_speed=", max_speed, " acc=", acceleration, " friction_stop=", friction_stop)
	if force_reset_on_start:
		# При необходимости — принудительно применяем "жёсткие" дефолты тут.
		# Используй с осторожностью (полезно при отладке).
		max_speed = 500.0
		acceleration = 4400.0
		friction_stop = 150.0
		friction_turn = 1500.0
		air_friction = 0.0
		print("[Player] force_reset_on_start applied defaults.")
	if not anim_sprite.sprite_frames:
		push_warning("AnimatedSprite2D.sprite_frames не назначен!")
	anim_sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	_read_input()
	_update_timers(delta)
	_apply_gravity(delta)
	_handle_horizontal(delta)
	_handle_jump_logic(delta)
	_update_state()
	# sync impulse with actual velocity.x so other code uses consistent value
	impulse = velocity.x
	move_and_slide()

# --- INPUT ---
func _read_input() -> void:
	input_jump_pressed = Input.is_action_pressed("ui_up")
	input_jump_just_pressed = Input.is_action_just_pressed("ui_up")
	var left = Input.is_action_pressed("ui_left")
	var right = Input.is_action_pressed("ui_right")

	# в штатных состояниях — читаем направление
	if current_state in [PlayerState.JUMP_START, PlayerState.JUMP, PlayerState.FLY, PlayerState.LAND]:
		# во время этих состояний управление горизонталью блокировано (кроме специальных случаев в Jump_start logic)
		input_direction = 0
		return

	input_direction = 0
	if left and not right:
		input_direction = -1
	elif right and not left:
		input_direction = 1

# --- TIMERS ---
func _update_timers(delta: float) -> void:
	coyote_timer = coyote_time if is_on_floor() else max(0.0, coyote_timer - delta)
	jump_buffer_timer = jump_buffer if input_jump_just_pressed else max(0.0, jump_buffer_timer - delta)

# --- GRAVITY & CEILING COLLISION ---
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
		if is_on_ceiling() and velocity.y < 0:
			velocity.y = 0
			_enter_fly()
	else:
		# на земле немного «помогаем» трением, но не затираем accel
		impulse = move_toward(impulse, 0.0, friction_stop * delta)

# --- HORIZONTAL MOVEMENT (улучшенный) ---
func _handle_horizontal(delta: float) -> void:
	# --- Прыжковые состояния ---
	if current_state in [PlayerState.JUMP_START, PlayerState.JUMP, PlayerState.FLY]:
		# В воздухе применяем воздушное трение
		if abs(velocity.x) > 0.0:
			velocity.x = move_toward(velocity.x, 0.0, air_friction * delta)
		return

	# --- LAND (приземление) ---
	if current_state == PlayerState.LAND:
		# замедляем персонажа при приземлении
		if abs(velocity.x) > 0.0:
			velocity.x = move_toward(velocity.x, 0.0, friction_stop * delta)
		return

	# --- На земле (IDLE/WALK) ---
	if input_direction != 0:
		# если смена направления — трение поворота
		if sign(velocity.x) != 0 and sign(velocity.x) != input_direction:
			velocity.x = move_toward(velocity.x, 0.0, friction_turn * delta)
		else:
			# обычное ускорение
			velocity.x += input_direction * acceleration * delta
			velocity.x = clamp(velocity.x, -max_speed, max_speed)

		anim_sprite.flip_h = velocity.x < 0
	else:
		# если нет ввода — обычное трение
		velocity.x = move_toward(velocity.x, 0.0, friction_stop * delta)

	# синхронизация impulse
	impulse = velocity.x


# --- JUMP LOGIC (без изменений логики накопления, но с использованием velocity.x как источника) ---
func _handle_jump_logic(delta: float) -> void:
	var can_jump = is_on_floor() or coyote_timer > 0.0

	# --- Начало прыжка ---
	if input_jump_just_pressed and can_jump and not jump_pending:
		jump_pending = true
		is_jump_released = false
		jump_hold_timer = 0.0
		jump_start_timer = 0.0

		# сохранили импульс от ходьбы
		stored_impulse = velocity.x
		stored_impulse_timer = stored_impulse_lifetime

		# сбросили накопленный
		accumulated_impulse = 0.0
		jump_direction = 0

		# полностью останавливаем персонажа визуально
		velocity.x = 0.0
		impulse = 0.0
		_set_state(PlayerState.JUMP_START)

	# --- Jump_start логика ---
	if current_state == PlayerState.JUMP_START:
		jump_start_timer += delta
		if input_jump_pressed:
			jump_hold_timer += delta

		# сохраняем направление при нажатии
		var left = Input.is_action_pressed("ui_left")
		var right = Input.is_action_pressed("ui_right")

		var new_dir = 0
		if left and not right:
			new_dir = -1
		elif right and not left:
			new_dir = 1

		if new_dir == 0:
			accumulated_impulse = 0.0
			jump_direction = 0
		elif new_dir != jump_direction:
			accumulated_impulse = 0.0
			jump_direction = new_dir
			anim_sprite.flip_h = jump_direction < 0

		# накапливаем горизонтальный импульс, но **не изменяем velocity.x**
		if jump_direction != 0:
			var h_ratio = clamp(jump_start_timer / jump_start_hold_time, 0.0, 1.0)
			accumulated_impulse = lerp(jump_min_horizontal, jump_max_horizontal, h_ratio)

	# --- Отпускание кнопки прыжка ---
	if not input_jump_pressed and jump_pending and current_state == PlayerState.JUMP_START:
		is_jump_released = true

		# вертикальный импульс
		var t = clamp(jump_hold_timer, jump_min_hold_time, jump_max_hold_time)
		var v_ratio = (t - jump_min_hold_time) / (jump_max_hold_time - jump_min_hold_time)
		var jump_force = lerp(jump_min_force, jump_max_force, v_ratio)
		velocity.y = jump_force

		# горизонтальный итоговый импульс
		var final_horizontal: float = 0.0
		if stored_impulse_timer > 0.0 and sign(stored_impulse) == jump_direction and jump_direction != 0:
			final_horizontal += abs(stored_impulse)
		if jump_direction != 0:
			final_horizontal += accumulated_impulse

		# применяем импульс только при старте прыжка
		if jump_direction != 0:
			velocity.x = jump_direction * final_horizontal
		else:
			velocity.x = stored_impulse

		impulse = velocity.x
		_enter_jump()

	# --- таймер stored_impulse ---
	if stored_impulse_timer > 0.0:
		stored_impulse_timer = max(0.0, stored_impulse_timer - delta)
	else:
		stored_impulse = 0.0


# --- STATE MACHINE & HELPERS ---
func _update_state() -> void:
	match current_state:
		PlayerState.IDLE, PlayerState.WALK:
			if not is_on_floor():
				_enter_fly()
			elif abs(impulse) > 0.1 or input_direction != 0:
				_set_state(PlayerState.WALK) # персонаж двигается → WALK
			else:
				_set_state(PlayerState.IDLE) # персонаж стоит → IDLE
		PlayerState.FLY:
			if is_on_floor():
				_set_state(PlayerState.LAND)
		PlayerState.LAND:
			pass

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

func _enter_jump() -> void:
	_set_state(PlayerState.JUMP)

func _enter_fly() -> void:
	_set_state(PlayerState.FLY)
	jump_pending = false
	is_jump_released = true

func _on_animation_finished() -> void:
	match current_state:
		PlayerState.JUMP_START:
			if is_jump_released:
				_enter_jump()
		PlayerState.JUMP:
			_enter_fly()
		PlayerState.LAND:
			# после Land сразу в Walk если зажата кнопка, иначе в Idle
			if input_direction != 0:
				_set_state(PlayerState.WALK)
			elif abs(impulse) > 0.1:
				_set_state(PlayerState.WALK)
			else:
				_set_state(PlayerState.IDLE)
