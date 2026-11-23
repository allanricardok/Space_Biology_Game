extends CharacterBody3D
class_name Player

## Configurações de Movimentação
@export_group("Movimentação")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.5
@export var jump_velocity: float = 4.8
@export var acceleration: float = 10.0
@export var deceleration: float = 12.0
@export var air_control: float = 3.0

## Configurações de Câmera
@export_group("Câmera")
@export var mouse_sensitivity: float = 0.0025
@export var min_pitch: float = -89.0
@export var max_pitch: float = 89.0

## Head Bobbing (Balanço da cabeça para imersão)
@export_group("Head Bobbing")
@export var enable_bob: bool = true
@export var bob_frequency: float = 2.4
@export var bob_amplitude: float = 0.05

# Referências de nós
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

# Gravidade padrão do projeto
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

# Variáveis de controle de câmera e balanço
var _camera_initial_y: float = 0.0
var _bob_timer: float = 0.0
var _is_sprinting: bool = false

func _ready() -> void:
	_ensure_input_actions()
	# Captura o cursor do mouse no início do jogo
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if camera:
		_camera_initial_y = camera.position.y

func _unhandled_input(event: InputEvent) -> void:
	# Controle da rotação da câmera com o mouse
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Giro horizontal (corpo todo gira no eixo Y)
		rotate_y(-event.relative.x * mouse_sensitivity)
		# Giro vertical (apenas a cabeça inclina no eixo X)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(
			head.rotation.x,
			deg_to_rad(min_pitch),
			deg_to_rad(max_pitch)
		)

	# Tecla ESC para liberar ou recapturar o mouse durante o teste
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Clicar na tela quando o mouse estiver visível recaptura o cursor
	if event is InputEventMouseButton and event.pressed:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	# 1. Aplica a gravidade
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 2. Pulo
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# 3. Corrida (Sprint)
	_is_sprinting = Input.is_action_pressed("sprint") and is_on_floor()
	var current_speed: float = sprint_speed if _is_sprinting else walk_speed

	# 4. Vetor de entrada (WASD / Setas)
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	# Direção no espaço global baseada na orientação do player
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# 5. Aceleração / Desaceleração suave
	var target_vel_x: float = direction.x * current_speed
	var target_vel_z: float = direction.z * current_speed
	var accel_rate: float

	if is_on_floor():
		accel_rate = acceleration if direction.length() > 0.0 else deceleration
	else:
		accel_rate = air_control

	velocity.x = lerp(velocity.x, target_vel_x, accel_rate * delta)
	velocity.z = lerp(velocity.z, target_vel_z, accel_rate * delta)

	move_and_slide()

	# 6. Efeito de Head Bobbing (sensação física de passo)
	_handle_head_bob(delta, direction)

func _handle_head_bob(delta: float, direction: Vector3) -> void:
	if not enable_bob or not camera:
		return

	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()

	if is_on_floor() and horizontal_speed > 0.5:
		var speed_mult: float = 1.4 if _is_sprinting else 1.0
		_bob_timer += delta * bob_frequency * speed_mult
		var bob_offset: float = sin(_bob_timer * TAU) * bob_amplitude
		camera.position.y = lerp(camera.position.y, _camera_initial_y + bob_offset, 15.0 * delta)
	else:
		# Retorna suavemente ao centro quando parado ou no ar
		camera.position.y = lerp(camera.position.y, _camera_initial_y, 10.0 * delta)
		_bob_timer = 0.0

## Garante que as ações de entrada existam no projeto, prevenindo erros se não estiverem configuradas
func _ensure_input_actions() -> void:
	var bindings: Dictionary = {
		"move_forward": [KEY_W, KEY_UP],
		"move_backward": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE],
		"sprint": [KEY_SHIFT]
	}

	for action_name in bindings.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
			for key_code in bindings[action_name]:
				var event: InputEventKey = InputEventKey.new()
				event.physical_keycode = key_code
				InputMap.action_add_event(action_name, event)
