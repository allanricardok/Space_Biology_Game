extends CanvasLayer
class_name InventoryUI

## Tela de Inventário de Campo (tecla I)
## Exibe as cartas equipadas na mão (0 a 5) e os itens do inventário normal (0 a 10)
## Permite equipar/desequipar cartas e descartar itens.

signal opened()
signal closed()

@onready var panel_container: Control = $CenterContainer
@onready var title_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HeaderBox/TitleLabel
@onready var items_container: VBoxContainer = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/ItemsContainer
@onready var close_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HeaderBox/CloseButton
@onready var total_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/FooterBox/TotalLabel

@onready var tab_inventory: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TabBox/TabInventory
@onready var tab_dictionary: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TabBox/TabDictionary
@onready var dictionary_scroll_container: ScrollContainer = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DictionaryScrollContainer
@onready var dictionary_items_container: VBoxContainer = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DictionaryScrollContainer/DictionaryItemsContainer

var is_open: bool = false
var _status_notice: String = ""
var _current_tab: String = "inventario"  # "inventario" ou "dicionario"

func _ready() -> void:
	visible = false
	is_open = false
	if close_button:
		close_button.pressed.connect(close)
	if tab_inventory:
		tab_inventory.pressed.connect(func(): _switch_tab("inventario"))
	if tab_dictionary:
		tab_dictionary.pressed.connect(func(): _switch_tab("dicionario"))

## Alterna entre aberto e fechado
func toggle() -> void:
	if is_open:
		close()
	else:
		open()

func open() -> void:
	is_open = true
	visible = true
	_status_notice = ""

	# Regra de visibilidade da aba Dicionário (checa a flag OU se o item já está na mochila)
	var inventory: Node = get_node_or_null("/root/InventoryManager")
	var unlocked: bool = false
	if inventory != null:
		unlocked = inventory.dictionary_unlocked
		if not unlocked:
			for item in inventory.get_items():
				if item.get("plant_name", "").to_lower().contains("dicion"):
					unlocked = true
					inventory.set_dictionary_unlocked(true) # Sincroniza e salva a flag
					break

	if tab_dictionary:
		tab_dictionary.visible = unlocked

	if _current_tab == "dicionario" and not unlocked:
		_current_tab = "inventario"

	# Atualiza abas, containers e preenche os dados da aba atual
	_switch_tab(_current_tab)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	opened.emit()

func close() -> void:
	is_open = false
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	closed.emit()

## Alterna entre as abas do inventário
func _switch_tab(tab: String) -> void:
	_current_tab = tab

	var color_active: Color = Color(1.0, 0.88, 0.45)
	var color_inactive: Color = Color(0.7, 0.72, 0.75)
	if tab_inventory:
		tab_inventory.modulate = color_active if tab == "inventario" else color_inactive
	if tab_dictionary:
		tab_dictionary.modulate = color_active if tab == "dicionario" else color_inactive

	if items_container and items_container.get_parent() is ScrollContainer:
		items_container.get_parent().visible = (tab == "inventario")
	elif items_container:
		items_container.visible = (tab == "inventario")

	if dictionary_scroll_container:
		dictionary_scroll_container.visible = (tab == "dicionario")

	if tab == "inventario":
		_refresh_items()
	else:
		_refresh_dictionary()

## Desenha a aba Dicionário de Cartas com todas as receitas do jogo
func _refresh_dictionary() -> void:
	for child in dictionary_items_container.get_children():
		child.queue_free()

	var inventory: Node = get_node_or_null("/root/InventoryManager")

	if title_label:
		title_label.text = "Dicionário de Cartas (8 receitas)"

	# Título da seção
	var header: Label = Label.new()
	header.text = "📖 DICIONÁRIO DE CARTAS (8 receitas no total)"
	header.modulate = Color(0.85, 0.65, 1.0)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dictionary_items_container.add_child(header)

	var sep: HSeparator = HSeparator.new()
	dictionary_items_container.add_child(sep)

	# Todas as 8 receitas do jogo (mesmas de crafting_screen.gd)
	var recipes: Array[Dictionary] = [
		{"card_name": "Salto Duplo", "effect": "Double Jump", "mana_cost": 1, "is_passive": false, "cooldown": 0.0, "material": "Fern", "essence1": "Sol", "essence2": "SolSpecial"},
		{"card_name": "Cura Floral", "effect": "Heal 1 heart", "mana_cost": 3, "is_passive": false, "cooldown": 10.0, "material": "Fern", "essence1": "Rose", "essence2": "RoseSpecial"},
		{"card_name": "Impulso Solar", "effect": "Jump 2x higher", "mana_cost": 0, "is_passive": true, "cooldown": 0.0, "material": "Fern", "essence1": "Sol", "essence2": "Yello"},
		{"card_name": "Expansão Botânica", "effect": "Inventory add +10 spaces", "mana_cost": 0, "is_passive": true, "cooldown": 0.0, "material": "Fern", "essence1": "Tulip", "essence2": "TulipSpecial"},
		{"card_name": "Fluxo Arcano", "effect": "Instant 3 mana", "mana_cost": 1, "is_passive": false, "cooldown": 10.0, "material": "Fern", "essence1": "Liri", "essence2": "Lirium"},
		{"card_name": "Regeneração Rápida", "effect": "Mana recovers 2x faster", "mana_cost": 2, "is_passive": false, "cooldown": 10.0, "material": "Fern", "essence1": "Liri", "essence2": "Lirispecial"},
		{"card_name": "Segunda Chance", "effect": "If all hearts are over, refill half", "mana_cost": 0, "is_passive": true, "cooldown": 0.0, "material": "Fern", "essence1": "Lirium", "essence2": "Liriumspecial"},
		{"card_name": "Passo Veloz", "effect": "Speed 2x faster", "mana_cost": 0, "is_passive": true, "cooldown": 0.0, "material": "Fern", "essence1": "Yello", "essence2": "Yellospecial"},
	]

	for recipe in recipes:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var card_name: String = recipe["card_name"]
		var effect: String = recipe["effect"]
		var mana_cost: int = recipe["mana_cost"]
		var is_passive: bool = recipe["is_passive"]

		# Tipo da carta
		var type_str: String
		if is_passive:
			type_str = "[Passiva]"
		else:
			type_str = "[Ativa - %d Mana]" % mana_cost

		# Receita
		var recipe_str: String = "%s + %s + %s" % [recipe["material"], recipe["essence1"], recipe["essence2"]]

		# Verifica se já possui
		var owned: bool = false
		if inventory != null and inventory.has_method("has_card_owned"):
			owned = inventory.has_card_owned(card_name)

		var status_tag: String = "[✓ Já Criada]" if owned else "[Não criada]"
		var status_color: Color = Color(0.4, 0.95, 0.5) if owned else Color(0.65, 0.68, 0.72)

		# Nome + Tipo
		var name_lbl: Label = Label.new()
		name_lbl.text = "%s %s" % [card_name, type_str]
		name_lbl.modulate = Color(1.0, 0.88, 0.45)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.custom_minimum_size = Vector2(180, 0)
		row.add_child(name_lbl)

		# Receita
		var recipe_lbl: Label = Label.new()
		recipe_lbl.text = recipe_str
		recipe_lbl.modulate = Color(0.7, 0.85, 1.0)
		recipe_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		recipe_lbl.custom_minimum_size = Vector2(160, 0)
		row.add_child(recipe_lbl)

		# Efeito
		var effect_lbl: Label = Label.new()
		effect_lbl.text = effect
		effect_lbl.modulate = Color(0.9, 0.9, 0.95)
		effect_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		effect_lbl.custom_minimum_size = Vector2(150, 0)
		row.add_child(effect_lbl)

		# Status de posse
		var status_lbl: Label = Label.new()
		status_lbl.text = status_tag
		status_lbl.modulate = status_color
		status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		status_lbl.custom_minimum_size = Vector2(120, 0)
		row.add_child(status_lbl)

		dictionary_items_container.add_child(row)

## Reconstrói a lista visual de itens a partir do Autoload InventoryManager
func _refresh_items() -> void:
	for child in items_container.get_children():
		child.queue_free()

	var inventory: Node = get_node_or_null("/root/InventoryManager")
	var items: Array = inventory.get_items() if inventory != null and inventory.has_method("get_items") else []
	var hand_cards: Array = inventory.get_hand_cards() if inventory != null and inventory.has_method("get_hand_cards") else []
	var used_slots: int = inventory.get_used_slots() if inventory != null and inventory.has_method("get_used_slots") else items.size()
	var max_slots: int = inventory.max_inventory_slots if inventory != null and "max_inventory_slots" in inventory else 10

	if title_label:
		title_label.text = "Inventário (%d / %d espaços)" % [used_slots, max_slots]

	if total_label:
		if _status_notice.is_empty():
			total_label.text = "Mão: %d/5 cartas equipadas | Mochila: %d/%d slots" % [hand_cards.size(), used_slots, max_slots]
			total_label.modulate = Color(1.0, 1.0, 1.0)
		else:
			total_label.text = _status_notice
			total_label.modulate = Color(1.0, 0.45, 0.3)

	# --- SEÇÃO 1: CARTAS NA MÃO ---
	var hand_header: Label = Label.new()
	hand_header.text = "🎴 MÃO DE CARTAS EQUIPADAS (%d / 5):" % hand_cards.size()
	hand_header.modulate = Color(0.85, 0.65, 1.0)
	items_container.add_child(hand_header)

	if hand_cards.is_empty():
		var empty_hand: Label = Label.new()
		empty_hand.text = "   (Nenhuma carta equipada na mão)"
		empty_hand.modulate = Color(0.6, 0.65, 0.7)
		items_container.add_child(empty_hand)
	else:
		var hand_idx: int = 1
		for card in hand_cards:
			var row: HBoxContainer = HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)

			var name_lbl: Label = Label.new()
			var c_name: String = card.get("plant_name", "Carta")
			var effect: String = card.get("effect", "")
			var mana: int = card.get("mana_cost", 0)
			name_lbl.text = "[ %d ] %s | %s (Mana: %d)" % [hand_idx, c_name, effect, mana]
			name_lbl.modulate = Color(1.0, 0.88, 0.45)
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_lbl)

			# Botão / Toggle [x] Na Mão (desequipar para o inventário)
			var unequip_btn: Button = Button.new()
			unequip_btn.text = "[x] Na Mão"
			unequip_btn.modulate = Color(0.5, 1.0, 0.6)
			unequip_btn.custom_minimum_size = Vector2(95, 26)
			var card_id: int = card.get("id", 0)
			unequip_btn.pressed.connect(func(): _toggle_card_equip(card_id, true))
			row.add_child(unequip_btn)

			# Botão Descartar
			var del_btn: Button = Button.new()
			del_btn.text = "🗑 Descartar"
			del_btn.custom_minimum_size = Vector2(85, 26)
			del_btn.pressed.connect(func(): _discard_item(card_id))
			row.add_child(del_btn)

			items_container.add_child(row)
			hand_idx += 1

	var sep: HSeparator = HSeparator.new()
	items_container.add_child(sep)

	# --- SEÇÃO 2: INVENTÁRIO NORMAL / MOCHILA ---
	var inv_header: Label = Label.new()
	inv_header.text = "🎒 MOCHILA / AMOSTRAS (%d / %d):" % [used_slots, max_slots]
	inv_header.modulate = Color(0.7, 0.85, 1.0)
	items_container.add_child(inv_header)

	if items.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "   (Mochila vazia. Colete amostras com [E] no mapa)"
		empty_label.modulate = Color(0.6, 0.65, 0.7)
		empty_label.custom_minimum_size = Vector2(0, 40)
		items_container.add_child(empty_label)
		return

	# Linha para cada item individual da mochila
	var slot_index: int = 1
	for item in items:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		# Slot + Nome do item
		var name_label: Label = Label.new()
		var p_name: String = item.get("plant_name", "Desconhecido")
		var cat: String = item.get("category", "Essência")

		if cat == "Carta":
			var effect: String = item.get("effect", "")
			var mana: int = item.get("mana_cost", 0)
			name_label.text = "[ %d ] 🎴 %s | %s (Mana: %d)" % [slot_index, p_name, effect, mana]
			name_label.modulate = Color(0.9, 0.8, 1.0)
		else:
			name_label.text = "[ %d ]  %s" % [slot_index, p_name]

		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		# Categoria (Material, Essência ou Carta)
		var cat_label: Label = Label.new()
		cat_label.text = "[ %s ]" % cat
		if cat == "Material":
			cat_label.modulate = Color(0.4, 0.95, 0.5)
		elif cat == "Carta":
			cat_label.modulate = Color(0.85, 0.45, 1.0)
		else:
			cat_label.modulate = Color(0.4, 0.8, 1.0)
		row.add_child(cat_label)

		# Raridade
		var rarity_label: Label = Label.new()
		var rarity: String = item.get("rarity", "Comum")
		rarity_label.text = "[ %s ]" % rarity
		if rarity == "Rara" or rarity == "Especial":
			rarity_label.modulate = Color(1.0, 0.82, 0.25)
		elif rarity == "Mágica":
			rarity_label.modulate = Color(0.85, 0.65, 1.0)
		else:
			rarity_label.modulate = Color(0.75, 0.9, 0.75)
		row.add_child(rarity_label)

		# Se for carta no inventário normal, exibe botão [ ] Equipar
		var item_id: int = item.get("id", 0)
		if cat == "Carta":
			var equip_btn: Button = Button.new()
			equip_btn.text = "[ ] Equipar"
			equip_btn.custom_minimum_size = Vector2(95, 26)
			equip_btn.pressed.connect(func(): _toggle_card_equip(item_id, false))
			row.add_child(equip_btn)

		# Botão de Descartar para liberar espaço
		var del_button: Button = Button.new()
		del_button.text = "🗑 Descartar"
		del_button.custom_minimum_size = Vector2(85, 26)
		del_button.pressed.connect(func(): _discard_item(item_id))
		row.add_child(del_button)

		items_container.add_child(row)
		slot_index += 1

## Alterna equipamento de carta entre mão e inventário
func _toggle_card_equip(card_id: int, currently_equipped: bool) -> void:
	var inventory: Node = get_node_or_null("/root/InventoryManager")
	if inventory == null:
		return

	if currently_equipped:
		# Desequipar da mão para a mochila
		if inventory.is_full():
			_status_notice = "Mochila cheia (10/10)! Não é possível desequipar."
		else:
			_status_notice = ""
			inventory.unequip_card_from_hand(card_id)
	else:
		# Equipar da mochila para a mão
		if inventory.get_hand_cards().size() >= 5:
			_status_notice = "Mão cheia (5/5)!"
		else:
			_status_notice = ""
			inventory.equip_card_to_hand(card_id)

	_refresh_items()

func _discard_item(item_id: int) -> void:
	var inventory: Node = get_node_or_null("/root/InventoryManager")
	if inventory != null and inventory.has_method("remove_item_by_id"):
		_status_notice = ""
		inventory.remove_item_by_id(item_id)
		_refresh_items()

func _unhandled_input(event: InputEvent) -> void:
	if is_open:
		if event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel"):
			close()
			get_viewport().set_input_as_handled()
