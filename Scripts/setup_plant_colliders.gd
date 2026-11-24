@tool
extends EditorScript

## EditorScript para Godot 4
## Adiciona automaticamente os colisores de coleta (Area3D + CollisionShape3D)
## nas samambaias e flores da cena aberta no editor.
##
## Como rodar:
## 1. Tenha a cena (Test-Scene.tscn) aberta no editor.
## 2. Abra este script no Script Editor da Godot.
## 3. Pressione Ctrl + Shift + X (ou vá no menu: Arquivo -> Executar).
## 4. Pressione Ctrl + S para salvar a cena atualizada!

const COLLECTIBLE_SCRIPT_PATH: String = "res://Space_Biology_Game/Scripts/collectible_plant.gd"
const SPHERE_RADIUS: float = 3.0

var _total_count: int = 0
var _ferns_count: int = 0
var _flowers_count: int = 0
var _special_count: int = 0

func _run() -> void:
	var scene_root: Node = get_scene()
	if scene_root == null and Engine.is_editor_hint():
		scene_root = EditorInterface.get_edited_scene_root()
	
	if scene_root == null:
		printerr("[SetupPlantColliders] ERRO: Nenhuma cena aberta no editor!")
		printerr("Abra a cena Test-Scene.tscn no editor antes de executar este script.")
		return

	var plant_script: Script = load(COLLECTIBLE_SCRIPT_PATH)
	if plant_script == null:
		printerr("[SetupPlantColliders] ERRO: Script não encontrado em: ", COLLECTIBLE_SCRIPT_PATH)
		return

	_total_count = 0
	_ferns_count = 0
	_flowers_count = 0
	_special_count = 0

	print("=========================================================")
	print("[SetupPlantColliders] Iniciando varredura na cena: ", scene_root.name)
	
	_scan_node(scene_root, scene_root, plant_script)
	
	print("---------------------------------------------------------")
	print("[SetupPlantColliders] CONCLUÍDO COM SUCESSO!")
	print(" - Total de plantas processadas: ", _total_count)
	print(" - Samambaias (Ferns - colhíveis): ", _ferns_count)
	print(" - Flores (Flowers - decorativas/não colhíveis): ", _flowers_count)
	print(" - Espécimes Especiais/Raros: ", _special_count)
	print(">>> Pressione Ctrl + S para SALVAR as alterações na cena! <<<")
	print("=========================================================")

## Varre a árvore de nós recursivamente
func _scan_node(current_node: Node, scene_root: Node, plant_script: Script) -> void:
	if current_node is Sprite3D:
		var is_fern: bool = _is_fern(current_node)
		var is_flower: bool = _is_flower(current_node)
		
		if is_fern or is_flower:
			_setup_collect_area(current_node as Sprite3D, scene_root, plant_script, is_fern, is_flower)

	for child in current_node.get_children():
		_scan_node(child, scene_root, plant_script)

## Regra 1: Nome do Sprite3D contém "fern" (case-insensitive) ou parente direto é "ferns"
func _is_fern(sprite: Sprite3D) -> bool:
	if sprite.name.to_lower().contains("fern"):
		return true
	var parent: Node = sprite.get_parent()
	if parent != null and parent.name.to_lower().contains("fern"):
		return true
	return false

## Regra 2: Sprite3D é filho (direto ou indireto) de Node3D cujo nome contém "flower" (case-insensitive)
func _is_flower(sprite: Sprite3D) -> bool:
	var current: Node = sprite.get_parent()
	while current != null:
		if current.name.to_lower().contains("flower"):
			return true
		current = current.get_parent()
	return false

## Configura o nó CollectArea, CollisionShape e o script na planta
func _setup_collect_area(
	sprite: Sprite3D,
	scene_root: Node,
	plant_script: Script,
	is_fern: bool,
	is_flower: bool
) -> void:
	# 1. Evitar duplicação: remove CollectArea anterior se já existir
	var existing: Node = sprite.get_node_or_null("CollectArea")
	if existing != null:
		sprite.remove_child(existing)
		existing.free()

	# 2. Criar nó Area3D
	var area: Area3D = Area3D.new()
	area.name = "CollectArea"
	sprite.add_child(area)
	area.owner = scene_root

	# 3. Criar CollisionShape3D com SphereShape3D (radius = 3.0)
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	col_shape.name = "CollisionShape3D"
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = SPHERE_RADIUS
	col_shape.shape = sphere
	area.add_child(col_shape)
	col_shape.owner = scene_root

	# 4. Adicionar ao grupo "collectible" (persistent = true para salvar no .tscn)
	area.add_to_group("collectible", true)

	# 5. Anexar o script collectible_plant.gd
	area.set_script(plant_script)

	# Preparar variáveis exportadas
	var raw_name: String = sprite.name
	var clean_name: String = _clean_plant_name(raw_name)
	
	# is_harvestable: false se for flor, true se for fern
	var harvestable: bool = true
	if is_flower and not is_fern:
		harvestable = false
	elif is_fern:
		harvestable = true

	# Raridade: Rara se tiver "special" no nome, caso contrário Comum
	var is_special: bool = raw_name.to_lower().contains("special")
	var rarity: String = "Rara" if is_special else "Comum"

	# Atribuir valores
	area.set("plant_name", clean_name)
	area.set("description", "Amostra biológica coletada no planeta.")
	area.set("rarity", rarity)
	area.set("is_harvestable", harvestable)
	area.set("collected", false)

	# Estatísticas
	_total_count += 1
	if is_fern:
		_ferns_count += 1
	if is_flower:
		_flowers_count += 1
	if is_special:
		_special_count += 1

## Limpa o nome removendo números no final e formatando amigavelmente
func _clean_plant_name(raw: String) -> String:
	var regex: RegEx = RegEx.new()
	regex.compile("\\d+$")
	var without_digits: String = regex.sub(raw, "")
	if without_digits.is_empty():
		return raw
	return without_digits.capitalize()
