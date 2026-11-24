extends Node

## Autoload / Gerenciador Global de Inventário Biológico
## Cada item coletado ou carta não equipada ocupa 1 espaço individual no inventário.
## Mão de Cartas: array separado com limite de 5 cartas (não ocupam os 10 espaços normais).

signal inventory_updated()
signal sample_collected(sample_data: Dictionary)
signal item_removed(item_data: Dictionary)
signal hand_updated()

## Limites base
const BASE_MAX_SLOTS: int = 10
const MAX_HAND_CARDS: int = 5

@export var max_inventory_slots: int = BASE_MAX_SLOTS

## Lista de itens normais no inventário
var items: Array[Dictionary] = []

## Mão de Cartas equipadas (máximo 5)
var hand_cards: Array[Dictionary] = []

## Índice da carta selecionada na mão (0 a 4)
var selected_hand_index: int = 0:
	set(val):
		selected_hand_index = val
		hand_updated.emit()

var _next_id: int = 1

## ─── Slots Efetivos (Expansão Botânica) ───────────────────────────────────────
func get_effective_max_slots() -> int:
	var expansions: int = 0
	for card in hand_cards:
		if card.get("effect", "") == "Inventory add +10 spaces":
			expansions += 1
	return BASE_MAX_SLOTS + expansions * 10

## ─── Mana Efetiva (passivas na mão reservam 1 slot cada) ─────────────────────
func count_passive_in_hand() -> int:
	var count: int = 0
	for card in hand_cards:
		if card.get("is_passive", false):
			count += 1
	return count

func recalculate_passive_effects() -> void:
	# Slots de inventário
	max_inventory_slots = get_effective_max_slots()
	# Mana efetiva
	var stats: Node = get_node_or_null("/root/PlayerStats")
	if stats != null:
		stats.update_effective_mana(count_passive_in_hand())

## ─── Verificações de espaço ──────────────────────────────────────────────────
func can_add_item(_plant_name: String = "") -> bool:
	return items.size() < max_inventory_slots

func is_full() -> bool:
	return items.size() >= max_inventory_slots

func get_used_slots() -> int:
	return items.size()

## ─── Adiciona Amostra Coletada ───────────────────────────────────────────────
func add_sample(plant_name: String, rarity: String, description: String, is_harvestable: bool) -> bool:
	if is_full():
		print("[Inventário] AVISO: Inventário cheio (%d/%d)!" % [items.size(), max_inventory_slots])
		return false

	var category: String = "Material" if plant_name.to_lower().contains("fern") else "Essência"
	var item_data: Dictionary = {
		"id": _next_id,
		"plant_name": plant_name,
		"rarity": rarity,
		"description": description,
		"is_harvestable": is_harvestable,
		"category": category,
		"collected_at": Time.get_time_string_from_system()
	}
	_next_id += 1
	items.append(item_data)
	sample_collected.emit(item_data)
	inventory_updated.emit()
	print("[Inventário] Item adicionado: '%s' (%s) | %d/%d" % [plant_name, category, items.size(), max_inventory_slots])
	return true

## ─── Adiciona Carta Criada ────────────────────────────────────────────────────
func add_card(card_name: String, effect: String, mana_cost: int, rarity: String = "Mágica", is_passive: bool = false, cooldown: float = 0.0) -> Dictionary:
	var can_equip: bool = hand_cards.size() < MAX_HAND_CARDS

	if not can_equip and is_full():
		print("[Inventário] AVISO: Mão cheia e inventário cheio! '%s' não adicionada." % card_name)
		return {}

	var card_data: Dictionary = {
		"id": _next_id,
		"plant_name": card_name,
		"rarity": rarity,
		"description": "Efeito: %s (Custo de Mana: %d)" % [effect, mana_cost],
		"is_harvestable": false,
		"category": "Carta",
		"effect": effect,
		"mana_cost": mana_cost,
		"is_passive": is_passive,
		"cooldown": cooldown,
		"current_cooldown": 0.0,
		"equipped": can_equip,
		"collected_at": Time.get_time_string_from_system()
	}
	_next_id += 1

	if can_equip:
		hand_cards.append(card_data)
		recalculate_passive_effects()
		hand_updated.emit()
		print("[Inventário] Carta equipada na mão: '%s' (%d/5)" % [card_name, hand_cards.size()])
	else:
		items.append(card_data)
		inventory_updated.emit()
		print("[Inventário] Carta no inventário: '%s' (%d/10)" % [card_name, items.size()])

	sample_collected.emit(card_data)
	return card_data

## ─── Equipa Carta da mochila → mão ──────────────────────────────────────────
func equip_card_to_hand(item_id: int) -> bool:
	if hand_cards.size() >= MAX_HAND_CARDS:
		return false

	for i in range(items.size()):
		if items[i].get("id") == item_id and items[i].get("category") == "Carta":
			var card: Dictionary = items[i]
			items.remove_at(i)
			card["equipped"] = true
			hand_cards.append(card)
			recalculate_passive_effects()
			inventory_updated.emit()
			hand_updated.emit()
			return true

	return false

## ─── Desequipa Carta da mão → mochila ───────────────────────────────────────
func unequip_card_from_hand(item_id: int) -> bool:
	if is_full():
		return false

	for i in range(hand_cards.size()):
		if hand_cards[i].get("id") == item_id:
			var card: Dictionary = hand_cards[i]
			hand_cards.remove_at(i)
			card["equipped"] = false
			items.append(card)
			if selected_hand_index >= hand_cards.size() and hand_cards.size() > 0:
				selected_hand_index = hand_cards.size() - 1
			recalculate_passive_effects()
			hand_updated.emit()
			inventory_updated.emit()
			return true

	return false

## ─── Remove item por ID (mochila ou mão) ────────────────────────────────────
func remove_item_by_id(item_id: int) -> bool:
	for i in range(items.size()):
		if items[i].get("id") == item_id:
			var removed: Dictionary = items[i]
			items.remove_at(i)
			item_removed.emit(removed)
			inventory_updated.emit()
			return true

	for i in range(hand_cards.size()):
		if hand_cards[i].get("id") == item_id:
			var removed_card: Dictionary = hand_cards[i]
			hand_cards.remove_at(i)
			if selected_hand_index >= hand_cards.size() and hand_cards.size() > 0:
				selected_hand_index = hand_cards.size() - 1
			item_removed.emit(removed_card)
			recalculate_passive_effects()
			hand_updated.emit()
			return true

	return false

## ─── Remove primeira carta com efeito específico da mão (ex: Segunda Chance) ─
func remove_hand_card_by_effect(effect: String) -> bool:
	for i in range(hand_cards.size()):
		if hand_cards[i].get("effect", "") == effect:
			var removed: Dictionary = hand_cards[i]
			hand_cards.remove_at(i)
			if selected_hand_index >= hand_cards.size() and hand_cards.size() > 0:
				selected_hand_index = hand_cards.size() - 1
			item_removed.emit(removed)
			recalculate_passive_effects()
			hand_updated.emit()
			return true
	return false

## ─── Verifica se carta passiva com efeito X está na mão ─────────────────────
func has_passive_in_hand(effect: String) -> bool:
	for card in hand_cards:
		if card.get("is_passive", false) and card.get("effect", "") == effect:
			return true
	return false

## ─── Atualiza cooldown das cartas ativas da mão (chamado em _process) ────────
func tick_cooldowns(delta: float) -> void:
	var updated: bool = false
	for i in range(hand_cards.size()):
		if hand_cards[i].get("current_cooldown", 0.0) > 0.0:
			hand_cards[i]["current_cooldown"] = max(0.0, hand_cards[i]["current_cooldown"] - delta)
			updated = true
	if updated:
		hand_updated.emit()

## ─── Acessa um dado de carta na mão por índice ───────────────────────────────
func set_hand_card_cooldown(idx: int, value: float) -> void:
	if idx >= 0 and idx < hand_cards.size():
		hand_cards[idx]["current_cooldown"] = value

## ─── Getters ─────────────────────────────────────────────────────────────────
func get_items() -> Array[Dictionary]:
	return items

func get_hand_cards() -> Array[Dictionary]:
	return hand_cards

func get_total_count() -> int:
	return items.size()
