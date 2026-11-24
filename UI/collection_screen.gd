extends CanvasLayer
class_name CollectionScreen

## Interface minimalista de aviso de proximidade e tela de coleta de espécimes

signal closed()
signal sample_collected(plant: CollectiblePlant)

@onready var prompt_container: PanelContainer = $PromptContainer
@onready var prompt_label: Label = $PromptContainer/MarginContainer/PromptLabel

@onready var modal_overlay: Control = $ModalOverlay
@onready var title_label: Label = $ModalOverlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HeaderBox/TitleLabel
@onready var rarity_label: Label = $ModalOverlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HeaderBox/RarityLabel
@onready var description_label: Label = $ModalOverlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DescriptionLabel
@onready var harvest_type_label: Label = $ModalOverlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HarvestTypeLabel
@onready var collect_button: Button = $ModalOverlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonsBox/CollectButton
@onready var close_button: Button = $ModalOverlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonsBox/CloseButton

var current_plant: CollectiblePlant = null
var is_modal_open: bool = false

func _ready() -> void:
	hide_prompt()
	close_modal()

	if collect_button:
		collect_button.pressed.connect(_on_collect_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)

func _process(_delta: float) -> void:
	# Atualiza o contador de regeneração em tempo real na janela
	if is_modal_open and current_plant != null:
		if not current_plant.is_harvestable and current_plant.collected:
			var sec: int = int(ceil(current_plant.time_left))
			harvest_type_label.text = "Essência em regeneração: %02ds" % sec
			if current_plant.time_left <= 0.0 or not current_plant.collected:
				_update_modal_content()

## Mostra o aviso na tela (ex: "[E] Analisar / Coletar")
func show_prompt(plant_name: String = "") -> void:
	if is_modal_open:
		prompt_container.visible = false
		return

	if plant_name.is_empty():
		prompt_label.text = "[E] Analisar / Coletar"
	else:
		prompt_label.text = "[E] Analisar: " + plant_name

	prompt_container.visible = true

## Esconde o aviso de proximidade
func hide_prompt() -> void:
	if prompt_container:
		prompt_container.visible = false

## Abre a janela de detalhes para a planta selecionada
func open_modal_for(plant: CollectiblePlant) -> void:
	if plant == null:
		return

	# Plantas colhíveis já colhidas não podem ser inspecionadas
	if plant.is_harvestable and plant.collected:
		return

	current_plant = plant
	is_modal_open = true
	hide_prompt()

	_update_modal_content()

	modal_overlay.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

## Atualiza os textos e estados dos botões do modal
func _update_modal_content() -> void:
	if current_plant == null:
		return

	title_label.text = current_plant.plant_name
	rarity_label.text = "[ %s ]" % current_plant.rarity

	# Cores de raridade
	if current_plant.rarity == "Rara" or current_plant.rarity == "Especial":
		rarity_label.modulate = Color(1.0, 0.82, 0.25) # Dourado
	else:
		rarity_label.modulate = Color(0.75, 0.9, 0.75) # Verde suave

	description_label.text = current_plant.description

	# Verifica capacidade do inventário
	var inventory: Node = get_node_or_null("/root/InventoryManager")
	var can_add: bool = true
	var used_slots: int = 0
	var max_slots: int = 10
	if inventory != null:
		used_slots = inventory.get_used_slots() if inventory.has_method("get_used_slots") else 0
		max_slots = inventory.max_inventory_slots if "max_inventory_slots" in inventory else 10
		if inventory.has_method("can_add_item"):
			can_add = inventory.can_add_item(current_plant.plant_name)

	# Tipo de coleta e estado de regeneração
	if current_plant.is_harvestable:
		harvest_type_label.text = "Tipo de Coleta: Colheita Comum (Harvestable: Sim)"
		harvest_type_label.modulate = Color(0.4, 0.95, 0.5)
		if not can_add:
			collect_button.text = "Inventário cheio (%d/%d)!" % [used_slots, max_slots]
			collect_button.disabled = true
			harvest_type_label.text += "\n[!] Inventário cheio (%d/%d)! Espaço insuficiente." % [used_slots, max_slots]
			harvest_type_label.modulate = Color(1.0, 0.45, 0.25)
		else:
			collect_button.text = "Coletar Amostra"
			collect_button.disabled = false
	else:
		if current_plant.collected:
			var sec: int = int(ceil(current_plant.time_left))
			harvest_type_label.text = "Essência em regeneração: %02ds" % sec
			harvest_type_label.modulate = Color(1.0, 0.65, 0.25)
			collect_button.text = "Em Regeneração..."
			collect_button.disabled = true
		else:
			harvest_type_label.text = "Tipo de Coleta: Extração de Essência (Harvestable: Não - Preservar)"
			harvest_type_label.modulate = Color(0.4, 0.8, 1.0)
			if not can_add:
				collect_button.text = "Inventário cheio (%d/%d)!" % [used_slots, max_slots]
				collect_button.disabled = true
				harvest_type_label.text += "\n[!] Inventário cheio (%d/%d)! Espaço insuficiente." % [used_slots, max_slots]
				harvest_type_label.modulate = Color(1.0, 0.45, 0.25)
			else:
				collect_button.text = "Extrair Essência"
				collect_button.disabled = false

## Fecha a janela de coleta e devolve o controle ao jogador
func close_modal() -> void:
	is_modal_open = false
	if modal_overlay:
		modal_overlay.visible = false
	current_plant = null
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	closed.emit()

func _on_collect_pressed() -> void:
	if current_plant == null or current_plant.collected:
		return

	var plant_to_collect: CollectiblePlant = current_plant

	# Salva no inventário global Autoload
	var inventory: Node = get_node_or_null("/root/InventoryManager")
	if inventory != null and inventory.has_method("add_sample"):
		var added: bool = inventory.add_sample(
			plant_to_collect.plant_name,
			plant_to_collect.rarity,
			plant_to_collect.description,
			plant_to_collect.is_harvestable
		)
		if not added:
			_update_modal_content()
			return

	# Atualização visual da planta de acordo com o tipo
	if plant_to_collect.is_harvestable:
		plant_to_collect.collected = true
		var parent_sprite: Sprite3D = plant_to_collect.get_parent() as Sprite3D
		if parent_sprite != null:
			parent_sprite.visible = false
		plant_to_collect.monitoring = false
		plant_to_collect.monitorable = false
	else:
		# Extração de essência com início de regeneração
		plant_to_collect.collect_essence()

	sample_collected.emit(plant_to_collect)
	hide_prompt()
	close_modal()

func _on_close_pressed() -> void:
	close_modal()

func _unhandled_input(event: InputEvent) -> void:
	if is_modal_open:
		if event.is_action_pressed("ui_cancel"):
			close_modal()
			get_viewport().set_input_as_handled()
