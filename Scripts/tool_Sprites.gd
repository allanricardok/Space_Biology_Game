@tool
extends EditorScript

const BASE_MATERIAL_PATH := "res://Space_Biology_Game/Scenes/shader-material.tres"

func _run() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if not root:
		push_error("Nenhuma cena aberta no editor!")
		return
	
	var base_mat := load(BASE_MATERIAL_PATH) as ShaderMaterial
	if not base_mat:
		push_error("Não encontrei o ShaderMaterial!")
		return
	
	var count := _process_node(root, base_mat)
	print("Concluído! ", count, " Sprite3D individualizados e atualizados.")

func _process_node(node: Node, base_mat: ShaderMaterial) -> int:
	var updated := 0
	if node is Sprite3D and node.texture != null:
		# Ignora os que já usam o shader de glow para não sobrescrever suas plantas brilhantes
		var current_mat := node.material_override as ShaderMaterial
		if current_mat and current_mat.shader and current_mat.shader.resource_path.ends_with("plant-glow-shader.gdshader"):
			pass
		else:
			# Força uma cópia única do material para este sprite específico
			var unique_mat := base_mat.duplicate() as ShaderMaterial
			unique_mat.set_shader_parameter("albedo_texture", node.texture)
			node.material_override = unique_mat
			updated += 1
		
	for child in node.get_children():
		updated += _process_node(child, base_mat)
	return updated
