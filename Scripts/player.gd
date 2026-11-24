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
@onready var proximity_detector: Area3D = $ProximityDetector
@onready var collection_screen: CollectionScreen = $CollectionScreen
@onready var inventory_ui: CanvasLayer = $InventoryUI
@onready var crafting_screen: CanvasLayer = $CraftingScreen
@onready var status_hud: StatusHUD = $StatusHUD

# Gravidade padrão do projeto
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

# Variáveis de controle de câmera e balanço
var _camera_initial_y: float = 0.0
var _bob_timer: float = 0.0
var _is_sprinting: bool = false

# Sistema de proximidade e interação
var _nearby_plants: Array[CollectiblePlant] = []
var _current_target_plant: CollectiblePlant = null
var _nearby_lab: Area3D = null

func _ready() -> void:
	add_to_group("player")
	_ensure_input_actions()
	# Captura o cursor do mouse no início do jogo
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if camera:
		_camera_initial_y = camera.position.y

	# Conecta detecção de proximidade com áreas coletáveis
	if proximity_detector:
		proximity_detector.area_entered.connect(_on_proximity_area_entered)
		proximity_detector.area_exited.connect(_on_proximity_area_exited)

## Verifica se qualquer menu ou janela de interface está aberto
func _is_any_ui_open() -> bool:
	if collection_screen != null and collection_screen.is_modal_open:
		return true
	if inventory_ui != null and inventory_ui.is_open:
		return true
	if crafting_screen != null and crafting_screen.is_open:
		return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	# Alternar Inventário na tecla [I]
	if event.is_action_pressed("inventory"):
		# Se a janela de coleta ou laboratório estiver aberta, não abre o inventário por cima
		if (collection_screen != null and collection_screen.is_modal_open) or (crafting_screen != null and crafting_screen.is_open):
			return
		if inventory_ui != null:
			inventory_ui.toggle()
			get_viewport().set_input_as_handled()
			return

	# Se alguma UI estiver aberta, ignora movimentação e giro de câmera
	if _is_any_ui_open():
		return

	# Interagir com [E] (Laboratório ou Planta)
	if event.is_action_pressed("interact"):
		if _nearby_lab != null and is_instance_valid(_nearby_lab):
			if crafting_screen != null:
				crafting_screen.open()
				get_viewport().set_input_as_handled()
				return
		elif _current_target_plant != null and collection_screen != null:
			collection_screen.open_modal_for(_current_target_plant)
			get_viewport().set_input_as_handled()
			return

	# Debug: tecla K aplica 1 de dano
	if event.is_action_pressed("debug_damage"):
		var stats: Node = get_node_or_null("/root/PlayerStats")
		if stats != null:
			stats.take_damage(1)
			print("[Debug] Dano aplicado! Corações: %d" % stats.current_hearts)

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

	# Tecla ESC para liberar ou recapturar o mouse fora de modais
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Clicar na tela quando o mouse estiver visível recaptura o cursor (se a UI não estiver aberta)
	if event is InputEventMouseButton and event.pressed:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE and not _is_any_ui_open():
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			return

	# Hotbar: scroll e clique esquerdo (só com mouse capturado e sem UI aberta)
	if event is InputEventMouseButton and event.pressed and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_selected_hand(-1)
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_selected_hand(1)
			return
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_activate_selected_card()
			return

func _physics_process(delta: float) -> void:
	# Se a janela de coleta ou inventário estiver aberta, desacelera o player até parar
	if _is_any_ui_open():
		if not is_on_floor():
			velocity.y -= gravity * delta
		velocity.x = lerp(velocity.x, 0.0, deceleration * delta)
		velocity.z = lerp(velocity.z, 0.0, deceleration * delta)
		move_and_slide()
		return

	# 1. Aplica a gravidade
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 2. Pulo (com suporte a Salto Duplo)
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = jump_velocity
			_double_jump_available = _has_passive_effect("Double Jump")
		elif _double_jump_available:
			velocity.y = jump_velocity
			_double_jump_available = false

	# 3. Corrida (Sprint) com suporte a Passo Veloz
	_is_sprinting = Input.is_action_pressed("sprint") and is_on_floor()
	var speed_mult: float = 2.0 if _has_passive_effect("Speed 2x faster") else 1.0
	var current_speed: float = (sprint_speed if _is_sprinting else walk_speed) * speed_mult

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

	# 7. Atualiza alvo de proximidade para coleta
	_update_proximity_target()

## Prioriza o alvo mais próximo (Laboratório ou Planta de Campo)
func _update_proximity_target() -> void:
	_nearby_plants = _nearby_plants.filter(func(p): return is_instance_valid(p) and (not p.collected or not p.is_harvestable))

	var closest: CollectiblePlant = null
	var min_dist_sq: float = INF
	var p_pos: Vector3 = global_position

	for plant in _nearby_plants:
		var dist_sq: float = p_pos.distance_squared_to(plant.global_position)
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			closest = plant

	# Se estiver perto do Laboratório, avalia prioridade de proximidade
	if _nearby_lab != null and is_instance_valid(_nearby_lab):
		var lab_dist_sq: float = p_pos.distance_squared_to(_nearby_lab.global_position)
		if min_dist_sq == INF or lab_dist_sq <= min_dist_sq:
			_current_target_plant = null
			if collection_screen and not collection_screen.is_modal_open and not _is_any_ui_open():
				collection_screen.show_prompt("[E] Usar Laboratório")
			return

	if _nearby_plants.is_empty():
		_current_target_plant = null
		if collection_screen and not collection_screen.is_modal_open:
			collection_screen.hide_prompt()
		return

	_current_target_plant = closest

	if collection_screen and not collection_screen.is_modal_open and not _is_any_ui_open():
		if _current_target_plant != null:
			if _current_target_plant.collected and not _current_target_plant.is_harvestable:
				var sec: int = int(ceil(_current_target_plant.time_left))
				collection_screen.show_prompt("%s (Regenerando: %02ds)" % [_current_target_plant.plant_name, sec])
			else:
				collection_screen.show_prompt(_current_target_plant.plant_name)
		else:
			collection_screen.hide_prompt()
	elif collection_screen:
		collection_screen.hide_prompt()

func _on_proximity_area_entered(area: Area3D) -> void:
	if area.is_in_group("lab"):
		_nearby_lab = area
		return
	var plant: CollectiblePlant = area as CollectiblePlant
	if plant != null and (not plant.collected or not plant.is_harvestable):
		if not _nearby_plants.has(plant):
			_nearby_plants.append(plant)

func _on_proximity_area_exited(area: Area3D) -> void:
	if area.is_in_group("lab"):
		if _nearby_lab == area:
			_nearby_lab = null
		return
	var plant: CollectiblePlant = area as CollectiblePlant
	if plant != null:
		_nearby_plants.erase(plant)

func _handle_head_bob(delta: float, _direction: Vector3) -> void:
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
		"sprint": [KEY_SHIFT],
		"interact": [KEY_E],
		"inventory": [KEY_I],
		"debug_damage": [KEY_K]
	}

	for action_name in bindings.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
			for key_code in bindings[action_name]:
				var event: InputEventKey = InputEventKey.new()
				event.physical_keycode = key_code
				InputMap.action_add_event(action_name, event)

## Alterna a carta selecionada na mão (scroll do mouse)
func _cycle_selected_hand(dir: int) -> void:
	var inv: Node = get_node_or_null("/root/InventoryManager")
	if inv == null:
		return
	var hand: Array = inv.get_hand_cards()
	if hand.is_empty():
		return
	var new_idx: int = (inv.selected_hand_index + dir) % hand.size()
	if new_idx < 0:
		new_idx += hand.size()
	inv.selected_hand_index = new_idx
	if status_hud != null:
		status_hud.update_selection_animation(new_idx)

## Ativa a carta selecionada na mão (clique esquerdo)
func _activate_selected_card() -> void:
	var inv: Node = get_node_or_null("/root/InventoryManager")
	if inv == null:
		return
	var hand: Array = inv.get_hand_cards()
	var idx: int = inv.selected_hand_index
	if idx >= hand.size():
		return
	var card: Dictionary = hand[idx]

	# Carta Passiva: só avisa, não gasta mana e não remove
	if card.get("is_passive", false):
		show_hud_message("Carta Passiva (já ativa na mão)", Color(0.8, 0.9, 1.0))
		return

	# Verifica cooldown
	var cd: float = card.get("current_cooldown", 0.0)
	if cd > 0.0:
		show_hud_message("Em recarga: %.0fs" % cd, Color(0.8, 0.8, 0.5))
		return

	var mana_cost: int = card.get("mana_cost", 0)
	var stats: Node = get_node_or_null("/root/PlayerStats")
	if stats == null:
		return

	if not stats.consume_mana(mana_cost):
		if status_hud != null:
			status_hud.trigger_mana_fail(idx)
		return

	# Aplica efeito da carta ativa
	var effect: String = card.get("effect", "")
	var cooldown: float = card.get("cooldown", 0.0)
	print("[Player] Ativou carta: %s" % card.get("plant_name", ""))

	match effect:
		"Heal 1 heart":
			stats.heal(1)
			show_hud_message("❤ +1 Coração!", Color(1.0, 0.4, 0.5))
		"Instant 3 mana":
			stats.restore_mana(3)
			show_hud_message("◆ +3 Mana!", Color(0.3, 0.85, 1.0))
		"Mana recovers 2x faster":
			stats.activate_fast_regen()
			show_hud_message("⚡ Regeneração Rápida (6s)!", Color(0.5, 1.0, 0.7))
		"Double Jump":
			_enable_double_jump()
			show_hud_message("↑ Salto Duplo!", Color(0.8, 0.6, 1.0))
		_:
			show_hud_message("Carta usada!", Color(1.0, 0.9, 0.5))

	# Aplica cooldown (NÃO remove a carta)
	inv.set_hand_card_cooldown(idx, cooldown)
	hand_updated_notify()

## Chama hand_updated via InventoryManager para atualizar HUD
func hand_updated_notify() -> void:
	var inv: Node = get_node_or_null("/root/InventoryManager")
	if inv != null:
		inv.hand_updated.emit()

## Exibe uma mensagem flutuante na HUD (ou reutiliza o mana_warning_label)
func show_hud_message(msg: String, color: Color = Color.WHITE) -> void:
	if status_hud != null and status_hud.has_method("show_message"):
		status_hud.show_message(msg, color)

## ─── Double Jump ──────────────────────────────────────────────────────────────
var _double_jump_available: bool = false

func _enable_double_jump() -> void:
	_double_jump_available = true

## Verifica se um efeito passivo está na mão atualmente
func _has_passive_effect(effect: String) -> bool:
	var inv: Node = get_node_or_null("/root/InventoryManager")
	if inv == null:
		return false
	return inv.has_passive_in_hand(effect)

## Registra o player no grupo para que PlayerStats possa encontrá-lo
func _ready_group() -> void:
	add_to_group("player")
