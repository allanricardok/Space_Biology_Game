extends Area3D
class_name CollectiblePlant

## Propriedades da Amostra Biológica
@export_group("Identificação da Amostra")
@export var plant_name: String = ""
@export_multiline var description: String = "Amostra biológica coletada no planeta."
@export_enum("Comum", "Incomum", "Rara", "Lendária") var rarity: String = "Comum"
@export var unlocks_dictionary: bool = false

@export_group("Mecânicas de Campo")
@export var is_harvestable: bool = true
@export var collected: bool = false
@export var respawn_time: float = 30.0

## Variáveis internas de recarga e feedback visual
var time_left: float = 0.0
var _original_modulate: Color = Color.WHITE
var _particles: GPUParticles3D = null

@onready var parent_sprite: Sprite3D = get_parent() as Sprite3D

signal collected_state_changed(is_collected: bool)
signal respawned()

func _ready() -> void:
	if parent_sprite != null:
		_original_modulate = parent_sprite.modulate

	# Cria partículas de essência caso seja uma planta de essência (não-colhível)
	if not is_harvestable:
		_setup_essence_particles()

func _process(delta: float) -> void:
	# Contagem regressiva de recarga para essências coletadas
	if not is_harvestable and collected:
		if time_left > 0.0:
			time_left -= delta
			if time_left <= 0.0:
				reset_cooldown()

## Configura as partículas de esporos/essência flutuante sem texturas externas
func _setup_essence_particles() -> void:
	_particles = get_node_or_null("EssenceParticles") as GPUParticles3D
	if _particles != null:
		_particles.emitting = not collected
		return

	_particles = GPUParticles3D.new()
	_particles.name = "EssenceParticles"

	# Material de processo das partículas
	var process_mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_mat.emission_sphere_radius = 0.8
	process_mat.direction = Vector3(0, 1, 0)
	process_mat.spread = 35.0
	process_mat.initial_velocity_min = 0.15
	process_mat.initial_velocity_max = 0.4
	process_mat.gravity = Vector3(0, 0.06, 0) # Leve flutuação ascendente
	process_mat.scale_min = 0.03
	process_mat.scale_max = 0.07

	# Cor mágica (dourado se for rara/especial, azul/ciano para comum)
	if rarity == "Rara" or rarity == "Especial":
		process_mat.color = Color(1.0, 0.85, 0.35, 0.85)
	else:
		process_mat.color = Color(0.45, 0.85, 1.0, 0.8)

	_particles.process_material = process_mat

	# QuadMesh com material Unshaded e Billboard habilitado
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)

	var mesh_mat: StandardMaterial3D = StandardMaterial3D.new()
	mesh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh_mat.vertex_color_use_as_albedo = true
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = mesh_mat

	_particles.draw_pass_1 = quad
	_particles.amount = 18
	_particles.lifetime = 2.2
	_particles.randomness = 0.4
	_particles.visibility_aabb = AABB(Vector3(-1.2, -0.6, -1.2), Vector3(2.4, 2.6, 2.4))
	_particles.emitting = not collected

	add_child(_particles)

## Extrai a essência da planta iniciando a contagem de regeneração
func collect_essence() -> void:
	collected = true
	time_left = respawn_time

	if _particles != null:
		_particles.emitting = false

	if parent_sprite != null:
		parent_sprite.modulate = _original_modulate * Color(0.45, 0.45, 0.45, 1.0)

	collected_state_changed.emit(true)

	# Se essa amostra desbloqueia o dicionário de cartas, ativa a flag no inventário
	if unlocks_dictionary:
		var inv: Node = get_node_or_null("/root/InventoryManager")
		if inv != null and inv.has_method("set_dictionary_unlocked"):
			inv.set_dictionary_unlocked(true)

## Restaura o estado da planta após o cooldown
func reset_cooldown() -> void:
	collected = false
	time_left = 0.0

	if _particles != null:
		_particles.emitting = true

	if parent_sprite != null:
		parent_sprite.modulate = _original_modulate

	collected_state_changed.emit(false)
	respawned.emit()
