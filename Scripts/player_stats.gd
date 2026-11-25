extends Node

## Autoload Global / Gerenciador de Status do Jogador (Vida, Mana, Velocidade)

signal hearts_changed(current: int, max_val: int)
signal mana_changed(current: int, max_val: int, effective_max: int)
signal speed_changed(current: int, max_val: int)

## 1. Vida (Hearts)
@export var max_hearts: int = 5
var current_hearts: int = 5:
	set(value):
		current_hearts = clamp(value, 0, max_hearts)
		hearts_changed.emit(current_hearts, max_hearts)
		var inv: Node = get_node_or_null("/root/InventoryManager")
		if inv != null and inv.has_method("save_game"):
			inv.save_game()

## 2. Velocidade (Speed Icons: padrão 3 de 5)
@export var max_speed_level: int = 5
var current_speed_level: int = 3:
	set(value):
		current_speed_level = clamp(value, 0, max_speed_level)
		speed_changed.emit(current_speed_level, max_speed_level)

## 3. Mana e Regeneração Automática
@export var max_mana: int = 5
var effective_max_mana: int = 5   ## max_mana - passivas na mão
var current_mana: int = 5:
	set(value):
		current_mana = clamp(value, 0, effective_max_mana)
		mana_changed.emit(current_mana, max_mana, effective_max_mana)

## Regen normal: 3.0s / regen acelerada: 1.5s por 6.0s
const MANA_REGEN_NORMAL: float = 3.0
const MANA_REGEN_FAST: float = 1.5
var _mana_regen_timer: float = 0.0
var _fast_regen_timer: float = 0.0   ## segundos restantes de Regeneração Rápida

func _ready() -> void:
	effective_max_mana = max_mana
# Verificar passivas carregadas no InventoryManager
	var inv: Node = get_node_or_null("/root/InventoryManager")
	if inv != null and inv.has_method("get_hand_cards"):
		var p_count: int = 0
		for card in inv.get_hand_cards():
			if card.has("is_passive") and card["is_passive"] == true:
				p_count += 1
		effective_max_mana = max(0, max_mana - p_count)
		current_mana = min(current_mana, effective_max_mana)
		mana_changed.emit(current_mana, max_mana, effective_max_mana)

func _process(delta: float) -> void:
	# Tick cooldown das cartas de mão
	var inv: Node = get_node_or_null("/root/InventoryManager")
	if inv != null and inv.has_method("tick_cooldowns"):
		inv.tick_cooldowns(delta)

	# Regeneração de mana
	if _fast_regen_timer > 0.0:
		_fast_regen_timer -= delta
		_regen_tick(delta, MANA_REGEN_FAST)
	else:
		_regen_tick(delta, MANA_REGEN_NORMAL)

func _regen_tick(delta: float, interval: float) -> void:
	if current_mana < effective_max_mana:
		_mana_regen_timer += delta
		if _mana_regen_timer >= interval:
			_mana_regen_timer = 0.0
			current_mana += 1
			print("[PlayerStats] +1 Mana (%d/%d)" % [current_mana, effective_max_mana])
	else:
		_mana_regen_timer = 0.0

## Recalcula mana efetiva com base em quantas passivas estão na mão
func update_effective_mana(passive_count: int) -> void:
	effective_max_mana = max(0, max_mana - passive_count)
	current_mana = min(current_mana, effective_max_mana)
	mana_changed.emit(current_mana, max_mana, effective_max_mana)

## Consome mana (retorna true se teve mana suficiente)
func consume_mana(amount: int = 1) -> bool:
	if current_mana >= amount:
		current_mana -= amount
		return true
	return false

## Restaura mana diretamente (limitado ao efetivo)
func restore_mana(amount: int = 1) -> void:
	current_mana = min(current_mana + amount, effective_max_mana)

## Ativa Regeneração Rápida por 6s
func activate_fast_regen() -> void:
	_fast_regen_timer = 6.0
	_mana_regen_timer = 0.0
	print("[PlayerStats] Regeneração Rápida ativada (6s)!")

## Altera nível de velocidade
func set_speed_level(level: int) -> void:
	current_speed_level = level

## Dano com verificação de Segunda Chance
func take_damage(amount: int = 1) -> void:
	if current_hearts - amount <= 0:
		# Verifica Segunda Chance na mão
		var inv: Node = get_node_or_null("/root/InventoryManager")
		if inv != null and inv.has_method("has_passive_in_hand") and inv.has_passive_in_hand("If all hearts are over, refill half"):
			# Encontra a carta de Segunda Chance e verifica cooldown
			var hand: Array = inv.get_hand_cards() if inv.has_method("get_hand_cards") else []
			var sc_index: int = -1
			for i in range(hand.size()):
				if hand[i].get("is_passive", false) and hand[i].get("effect", "") == "If all hearts are over, refill half":
					if hand[i].get("current_cooldown", 0.0) > 0.0:
						# Está em cooldown: não ativa, segue dano normal
						current_hearts -= amount
						return
					sc_index = i
					break

			if sc_index >= 0:
				current_hearts = 2  # Preenche 2 corações
				inv.set_hand_card_cooldown(sc_index, 30.0)  # Cooldown de 30s
				print("[PlayerStats] Segunda Chance ativada! Corações restaurados para 2. Cooldown: 30s.")
				# Aviso na HUD
				var player: Node = get_tree().get_first_node_in_group("player")
				if player != null and player.has_method("show_hud_message"):
					player.show_hud_message("Segunda Chance ativada!", Color(1.0, 0.85, 0.3))
				return
	current_hearts -= amount

func heal(amount: int = 1) -> void:
	current_hearts = min(current_hearts + amount, max_hearts)
