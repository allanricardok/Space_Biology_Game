extends Control

# Crafting Screen
# Tela de criação/laboratório para visualizar receitas de cartas

@onready var recipe_list_scroll: ScrollContainer
@onready var recipe_vbox: VBoxContainer

# Referência ao InventoryManager
@export var inventory_manager: InventoryManager

func _ready():
	_populate_recipe_list()

func _populate_recipe_list():
	# Limpar lista anterior
	recipe_vbox.clear()
	
# Todas as 8 combinações de cartas do jogo
var card_data = [
	{"name": "Fern", "type": "Passiva", "recipe": ["Fern", "FernP", "Sol", "SolSpecial"], "effect": "Crescimento lento"},
	{"name": "FernP", "type": "Passiva", "recipe": ["FernP", "Sol", "SolSpecial", "Lua"], "effect": "Proteção básica"},
	{"name": "Sol", "type": "Ativa - 1 Mana", "recipe": ["Fern", "FernP", "Sol"], "effect": "Gera luz e calor"},
	{"name": "SolSpecial", "type": "Ativa - 2 Mana", "recipe": ["Sol", "SolSpecial", "Lua"], "effect": "Explosão de energia"},
	{"name": "Lua", "type": "Ativa - 1 Mana", "recipe": ["FernP", "SolSpecial", "Lua"], "effect": "Regeneração noturna"},
	{"name": "Duplo Pulo", "type": "Passiva", "recipe": ["Fern", "Sol", "Lua"], "effect": "Permite pular duas vezes no ar"},
	{"name": "Fogo", "type": "Ativa - 2 Mana", "recipe": ["FernP", "SolSpecial", "Lua"], "effect": "Inflige queimadura aos inimigos"},
	{"name": "Terra", "type": "Passiva", "recipe": ["Fern", "FernP", "Sol"], "effect": "Aumenta defesa física"}
]

for card in card_data:
	var card_container = VBoxContainer.new()
	card_container.size = Vector2(recipe_list_scroll.size.x - 40, 100)
	card_container.vertical_alignment = Control.VERTICAL_ALIGNMENT_START
	
	# Nome e tipo da carta
	var name_label = Label.new()
	name_label.text = "${card['name']} [${card['type']}]"
	name_label.custom_minimum_size = Vector2(recipe_list_scroll.size.x - 60, 0)
	card_container.add_child(name_label)
	
	# Receita necessária
	var recipe_label = Label.new()
	var recipe_text = card['recipe'].join(" + ")
	recipe_label.text = "Receita: ${recipe_text}"
	recipe_label.custom_minimum_size = Vector2(recipe_list_scroll.size.x - 60, 0)
	card_container.add_child(recipe_label)
	
	# Efeito
	var effect_label = Label.new()
	effect_label.text = card['effect']
	effect_label.custom_minimum_size = Vector2(recipe_list_scroll.size.x - 60, 0)
	card_container.add_child(effect_label)
	
	# Status de posse
	var owned_status = Label.new()
	owned_status.text = inventory_manager.has_card_owned(card['name']) and "[✓ Já Criada]" or "[Não criada]"
	owned_status.add_theme_color_override("font_color", Color.GREEN)
	owned_status.custom_minimum_size = Vector2(recipe_list_scroll.size.x - 60, 0)
	card_container.add_child(owned_status)
	
	recipe_vbox.add_child(card_container)

func _process(delta):
	# Verificar se foi pressionada tecla I para fechar
	if Input.is_action_just_pressed("ui_accept"):
		_pass_shortcut()

func _pass_shortcut():
	if Input.get_last_key() == KeyInput.scancode_I or Input.get_last_key() == KeyInput.keycode_I:
		hide()