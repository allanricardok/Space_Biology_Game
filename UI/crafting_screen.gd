extends CanvasLayer
class_name CraftingScreen

## Menu do Laboratório de Criação de Cartas de Campo (Bancada de 3 Slots)
## Valida receitas combinando 1 Material (Fern) + 2 Essências distintas.

signal opened()
signal closed()
signal card_crafted(card_name: String, recipe_data: Dictionary)

## Tabela de Receitas de Cartas de Campo
const RECIPES: Array[Dictionary] = [
	{
		"essences": ["sol", "solspecial"],
		"card_name": "Salto Duplo",
		"effect": "Double Jump",
		"mana_cost": 1,
		"is_passive": false,
		"cooldown": 0.0
	},
	{
		"essences": ["rose", "rosespecial"],
		"card_name": "Cura Floral",
		"effect": "Heal 1 heart",
		"mana_cost": 3,
		"is_passive": false,
		"cooldown": 10.0
	},
	{
		"essences": ["sol", "yello"],
		"card_name": "Impulso Solar",
		"effect": "Jump 2x higher",
		"mana_cost": 0,
		"is_passive": true,
		"cooldown": 0.0
	},
	{
		"essences": ["tulip", "tulipspecial"],
		"card_name": "Expansão Botânica",
		"effect": "Inventory add +10 spaces",
		"mana_cost": 0,
		"is_passive": true,
		"cooldown": 0.0
	},
	{
		"essences": ["liri", "lirium"],
		"card_name": "Fluxo Arcano",
		"effect": "Instant 3 mana",
		"mana_cost": 1,
		"is_passive": false,
		"cooldown": 10.0
	},
	{
		"essences": ["liri", "lirispecial"],
		"card_name": "Regeneração Rápida",
		"effect": "Mana recovers 2x faster",
		"mana_cost": 2,
		"is_passive": false,
		"cooldown": 10.0
	},
	{
		"essences": ["lirium", "liriumspecial"],
		"card_name": "Segunda Chance",
		"effect": "If all hearts are over, refill half",
		"mana_cost": 0,
		"is_passive": true,
		"cooldown": 0.0
	},
	{
		"essences": ["yello", "yellospecial"],
		"card_name": "Passo Veloz",
		"effect": "Speed 2x faster",
		"mana_cost": 0,
		"is_passive": true,
		"cooldown": 0.0
	}
]

@onready var close_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HeaderBox/CloseButton
@onready var inventory_list: VBoxContainer = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BodyBox/LeftBox/ScrollContainer/InventoryList
@onready var inv_count_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BodyBox/LeftBox/InvCountLabel

@onready var slot1_btn: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BodyBox/RightBox/Slot1_Container/Slot1_Button
@onready var slot2_btn: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BodyBox/RightBox/Slot2_Container/Slot2_Button
@onready var slot3_btn: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BodyBox/RightBox/Slot3_Container/Slot3_Button

@onready var status_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BodyBox/RightBox/StatusLabel
@onready var craft_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BodyBox/RightBox/CraftButton

var is_open: bool = false

# Dados dos 3 slots da bancada (Dictionary do item ou {})
var slot_material: Dictionary = {}
var slot_essence_1: Dictionary = {}
var slot_essence_2: Dictionary = {}

func _ready() -> void:
	visible = false
	is_open = false

	if close_button:
		close_button.pressed.connect(close)
	if craft_button:
		craft_button.pressed.connect(_on_craft_pressed)

	if slot1_btn:
		slot1_btn.pressed.connect(_on_slot1_clicked)
	if slot2_btn:
		slot2_btn.pressed.connect(_on_slot2_clicked)
	if slot3_btn:
		slot3_btn.pressed.connect(_on_slot3_clicked)

func open() -> void:
	is_open = true
	visible = true
	slot_material = {}
	slot_essence_1 = {}
	slot_essence_2 = {}
	_show_status("Selecione 1 Material e 2 Essências distintas.", Color(0.75, 0.85, 0.9))
	_refresh_all()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	opened.emit()

func close() -> void:
	is_open = false
	visible = false
	slot_material = {}
	slot_essence_1 = {}
	slot_essence_2 = {}
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	closed.emit()

## Atualiza tanto a lista do inventário quanto os 3 slots e botão de craft
func _refresh_all() -> void:
	_refresh_inventory_list()
	_refresh_slots_display()

## Reconstrói a lista do inventário à esquerda, ocultando itens já colocados na bancada
func _refresh_inventory_list() -> void:
	for child in inventory_list.get_children():
		child.queue_free()

	var inventory: Node = get_node_or_null("/root/InventoryManager")
	var items: Array = inventory.get_items() if inventory != null and inventory.has_method("get_items") else []

	# IDs dos itens que já estão nos slots
	var slotted_ids: Array = []
	if not slot_material.is_empty():
		slotted_ids.append(slot_material.get("id"))
	if not slot_essence_1.is_empty():
		slotted_ids.append(slot_essence_1.get("id"))
	if not slot_essence_2.is_empty():
		slotted_ids.append(slot_essence_2.get("id"))

	# Filtra disponíveis (apenas materiais e essências, excluindo cartas prontas)
	var available_items: Array = []
	for item in items:
		if item.get("category") == "Carta":
			continue
		if not slotted_ids.has(item.get("id")):
			available_items.append(item)

	if inv_count_label:
		inv_count_label.text = "Disponíveis: %d amostras" % available_items.size()

	if available_items.is_empty():
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "Nenhuma amostra disponível.\nColete plantas ou esvazie os slots."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.modulate = Color(0.65, 0.68, 0.72)
		empty_lbl.custom_minimum_size = Vector2(0, 140)
		inventory_list.add_child(empty_lbl)
		return

	# Cria botão para cada item disponível
	for item in available_items:
		var btn: Button = Button.new()
		var p_name: String = item.get("plant_name", "Desconhecido")
		var cat: String = item.get("category", "Essência")
		var rarity: String = item.get("rarity", "Comum")

		btn.text = "[ %s ]  %s  (%s)" % [cat, p_name, rarity]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 32)

		if cat == "Material":
			btn.modulate = Color(0.85, 1.0, 0.85)
		else:
			btn.modulate = Color(0.85, 0.95, 1.0)

		var captured_item: Dictionary = item
		btn.pressed.connect(func(): _on_inventory_item_selected(captured_item))
		inventory_list.add_child(btn)

## Manipula clique em um item do inventário
func _on_inventory_item_selected(item: Dictionary) -> void:
	var cat: String = item.get("category", "Essência")

	if cat == "Material":
		slot_material = item
		_show_status("Material inserido no Slot 1.", Color(0.4, 0.95, 0.5))
	else:
		var p_name: String = item.get("plant_name", "")

		if slot_essence_1.is_empty():
			if not slot_essence_2.is_empty() and slot_essence_2.get("plant_name") == p_name:
				_show_status("As duas essências devem ser de espécies diferentes!", Color(1.0, 0.45, 0.25))
				return
			slot_essence_1 = item
			_show_status("Essência inserida no Slot 2.", Color(0.4, 0.85, 1.0))
		elif slot_essence_2.is_empty():
			if not slot_essence_1.is_empty() and slot_essence_1.get("plant_name") == p_name:
				_show_status("As duas essências devem ser de espécies diferentes!", Color(1.0, 0.45, 0.25))
				return
			slot_essence_2 = item
			_show_status("Essência inserida no Slot 3.", Color(0.4, 0.85, 1.0))
		else:
			if slot_essence_2.get("plant_name") != p_name:
				slot_essence_1 = item
				_show_status("Slot 2 substituído.", Color(0.4, 0.85, 1.0))
			elif slot_essence_1.get("plant_name") != p_name:
				slot_essence_2 = item
				_show_status("Slot 3 substituído.", Color(0.4, 0.85, 1.0))
			else:
				_show_status("As duas essências devem ser de espécies diferentes!", Color(1.0, 0.45, 0.25))
				return

	_refresh_all()

## Clicar em um slot devolve o item para a seleção
func _on_slot1_clicked() -> void:
	if not slot_material.is_empty():
		slot_material = {}
		_show_status("Material removido do Slot 1.", Color(0.8, 0.8, 0.8))
		_refresh_all()

func _on_slot2_clicked() -> void:
	if not slot_essence_1.is_empty():
		slot_essence_1 = {}
		_show_status("Essência removida do Slot 2.", Color(0.8, 0.8, 0.8))
		_refresh_all()

func _on_slot3_clicked() -> void:
	if not slot_essence_2.is_empty():
		slot_essence_2 = {}
		_show_status("Essência removida do Slot 3.", Color(0.8, 0.8, 0.8))
		_refresh_all()

## Atualiza a aparência visual dos 3 botões de slots
func _refresh_slots_display() -> void:
	# Slot 1: Material
	if slot_material.is_empty():
		slot1_btn.text = "[ Slot 1: Material ]\n+ Clique em uma Samambaia (Fern) à esquerda"
		slot1_btn.modulate = Color(0.75, 0.75, 0.75)
	else:
		slot1_btn.text = "✓ Material: %s (%s)\n(Clique para remover)" % [
			slot_material.get("plant_name"),
			slot_material.get("rarity")
		]
		slot1_btn.modulate = Color(0.5, 1.0, 0.6)

	# Slot 2: Essência 1
	if slot_essence_1.is_empty():
		slot2_btn.text = "[ Slot 2: Essência 1 ]\n+ Clique em uma Flor/Essência à esquerda"
		slot2_btn.modulate = Color(0.75, 0.75, 0.75)
	else:
		slot2_btn.text = "✓ Essência 1: %s (%s)\n(Clique para remover)" % [
			slot_essence_1.get("plant_name"),
			slot_essence_1.get("rarity")
		]
		slot2_btn.modulate = Color(0.4, 0.85, 1.0)

	# Slot 3: Essência 2
	if slot_essence_2.is_empty():
		slot3_btn.text = "[ Slot 3: Essência 2 ]\n+ Clique em uma Flor/Essência diferente"
		slot3_btn.modulate = Color(0.75, 0.75, 0.75)
	else:
		slot3_btn.text = "✓ Essência 2: %s (%s)\n(Clique para remover)" % [
			slot_essence_2.get("plant_name"),
			slot_essence_2.get("rarity")
		]
		slot3_btn.modulate = Color(0.4, 0.85, 1.0)

	# Mantém o botão habilitado para permitir clique e feedback
	craft_button.disabled = false
	craft_button.text = "✨ Criar Carta"

	# Pré-visualização se os 3 slots estiverem preenchidos
	if not slot_material.is_empty() and not slot_essence_1.is_empty() and not slot_essence_2.is_empty():
		var norm_e1: String = _normalize_key(slot_essence_1.get("plant_name", ""))
		var norm_e2: String = _normalize_key(slot_essence_2.get("plant_name", ""))
		var recipe: Dictionary = _find_matching_recipe(norm_e1, norm_e2)
		if not recipe.is_empty():
			_show_status("Receita: %s | Efeito: %s (Mana: %d)" % [
				recipe["card_name"],
				recipe["effect"],
				recipe["mana_cost"]
			], Color(1.0, 0.88, 0.35))

			# Aviso se ja possui esta carta
			var inv: Node = get_node_or_null("/root/InventoryManager")
			if inv != null and inv.has_method("has_card_owned"):
				if inv.has_card_owned(recipe["card_name"]):
					_show_status("Aviso: Voce ja possui esta carta!", Color(1.0, 0.6, 0.3))

## Normaliza nomes para comparação de receitas (sem números, pontuação ou maiúsculas)
func _normalize_key(raw_name: String) -> String:
	var s: String = raw_name.to_lower().replace(" ", "").replace("_", "").replace("-", "")
	var regex: RegEx = RegEx.new()
	regex.compile("\\d+$")
	s = regex.sub(s, "")

	if s.contains("special") or s.contains("especial"):
		if s.contains("sol") or s.contains("sun"):
			return "solspecial"
		elif s.contains("rose") or s.contains("rosa"):
			return "rosespecial"
		elif s.contains("yello") or s.contains("amarel"):
			return "yellospecial"
		elif s.contains("tulip"):
			return "tulipspecial"
		elif s.contains("lirium"):
			return "liriumspecial"
		elif s.contains("liri"):
			return "lirispecial"
	else:
		if s.contains("sol") or s.contains("sun"):
			return "sol"
		elif s.contains("rose") or s.contains("rosa"):
			return "rose"
		elif s.contains("yello") or s.contains("amarel"):
			return "yello"
		elif s.contains("tulip"):
			return "tulip"
		elif s.contains("lirium"):
			return "lirium"
		elif s.contains("liri"):
			return "liri"

	return s

## Busca na tabela de receitas
func _find_matching_recipe(e1: String, e2: String) -> Dictionary:
	for r in RECIPES:
		var r_ess: Array = r["essences"]
		if (e1 == r_ess[0] and e2 == r_ess[1]) or (e1 == r_ess[1] and e2 == r_ess[0]):
			return r
	return {}

## Executa a síntese da carta
func _on_craft_pressed() -> void:
	# 1. Se faltar algum dos 3 slots
	if slot_material.is_empty() or slot_essence_1.is_empty() or slot_essence_2.is_empty():
		_show_status("Selecione 1 material e 2 essências!", Color(1.0, 0.45, 0.25))
		return

	# Validação do Material
	var norm_mat: String = _normalize_key(slot_material.get("plant_name", ""))
	if not norm_mat.contains("fern"):
		_show_status("O Material deve ser uma Samambaia (Fern)!", Color(1.0, 0.45, 0.25))
		return

	# 2. Normaliza e busca a receita
	var norm_e1: String = _normalize_key(slot_essence_1.get("plant_name", ""))
	var norm_e2: String = _normalize_key(slot_essence_2.get("plant_name", ""))

	var recipe: Dictionary = _find_matching_recipe(norm_e1, norm_e2)

	# Se a combinação não estiver na lista: mostra mensagem e NÃO consome
	if recipe.is_empty():
		_show_status("Combinação não é possível!", Color(1.0, 0.35, 0.3))
		return

	# 3. Combinação válida:
	var inventory: Node = get_node_or_null("/root/InventoryManager")
	if inventory == null:
		return

	# Consome 1 unidade de cada um dos 3 itens selecionados
	inventory.remove_item_by_id(slot_material.get("id"))
	inventory.remove_item_by_id(slot_essence_1.get("id"))
	inventory.remove_item_by_id(slot_essence_2.get("id"))

	# Adiciona a Carta criada como item no inventário
	var card_name: String = recipe["card_name"]
	var effect: String = recipe["effect"]
	var mana_cost: int = recipe["mana_cost"]

	inventory.add_card(card_name, effect, mana_cost, "Mágica", recipe.get("is_passive", false), recipe.get("cooldown", 0.0))

	# Limpa os 3 slots da bancada
	slot_material = {}
	slot_essence_1 = {}
	slot_essence_2 = {}

	# Feedback de sucesso
	_show_status("Carta criada: %s!" % card_name, Color(0.4, 1.0, 0.5))
	card_crafted.emit(card_name, recipe)

	_refresh_all()

func _show_status(msg: String, color: Color) -> void:
	if status_label:
		status_label.text = msg
		status_label.modulate = color

func _unhandled_input(event: InputEvent) -> void:
	if is_open:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
			close()
			get_viewport().set_input_as_handled()
