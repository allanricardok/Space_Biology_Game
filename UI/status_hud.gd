extends CanvasLayer
class_name StatusHUD

## HUD Compacto de Status do Jogador (Vida, Mana, Velocidade) e Hotbar de Cartas na Mão

@onready var hearts_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HeartsRow/HeartsLabel
@onready var mana_label: Label = $PanelContainer/MarginContainer/VBoxContainer/ManaRow/ManaLabel
@onready var speed_label: Label = $PanelContainer/MarginContainer/VBoxContainer/SpeedRow/SpeedLabel

@onready var hotbar_container: HBoxContainer = $HotbarCenter/HotbarCards
@onready var mana_warning_label: Label = $ManaWarningLabel

var _card_panels: Array[PanelContainer] = []

func _ready() -> void:
	if mana_warning_label:
		mana_warning_label.modulate.a = 0.0

	var stats: Node = get_node_or_null("/root/PlayerStats")
	if stats != null:
		if stats.has_signal("hearts_changed"):
			stats.hearts_changed.connect(_on_hearts_changed)
		if stats.has_signal("mana_changed"):
			stats.mana_changed.connect(_on_mana_changed)
		if stats.has_signal("speed_changed"):
			stats.speed_changed.connect(_on_speed_changed)
		_update_all(stats)

	var inv: Node = get_node_or_null("/root/InventoryManager")
	if inv != null:
		if inv.has_signal("hand_updated"):
			inv.hand_updated.connect(_refresh_hotbar)
		_refresh_hotbar()

func _update_all(stats: Node) -> void:
	_on_hearts_changed(stats.get("current_hearts"), stats.get("max_hearts"))
	_on_mana_changed(stats.get("current_mana"), stats.get("max_mana"), stats.get("effective_max_mana"))
	_on_speed_changed(stats.get("current_speed_level"), stats.get("max_speed_level"))

func _on_hearts_changed(current: int, max_val: int) -> void:
	if not hearts_label:
		return
	var display: String = ""
	for i in range(max_val):
		display += "♥ " if i < current else "♡ "
	hearts_label.text = display.strip_edges()

## Mana: ◆ cheio, ◇ vazio, ✦ bloqueado por passiva
func _on_mana_changed(current: int, max_val: int, effective_max: int = -1) -> void:
	if not mana_label:
		return
	if effective_max < 0:
		effective_max = max_val
	var display: String = ""
	for i in range(max_val):
		if i >= effective_max:
			display += "✦ "   # slot bloqueado por passiva
		elif i < current:
			display += "◆ "
		else:
			display += "◇ "
	mana_label.text = display.strip_edges()

func _on_speed_changed(current: int, max_val: int) -> void:
	if not speed_label:
		return
	var display: String = ""
	for i in range(max_val):
		display += "⚡ " if i < current else "○ "
	speed_label.text = display.strip_edges()

## Reconstrói a Hotbar com até 5 cartas de hand_cards
func _refresh_hotbar() -> void:
	if not hotbar_container:
		return

	for child in hotbar_container.get_children():
		child.queue_free()
	_card_panels.clear()

	var inv: Node = get_node_or_null("/root/InventoryManager")
	var hand: Array = inv.get_hand_cards() if inv != null and inv.has_method("get_hand_cards") else []
	var selected_idx: int = inv.selected_hand_index if inv != null and "selected_hand_index" in inv else 0

	for i in range(hand.size()):
		var card: Dictionary = hand[i]
		var card_panel: PanelContainer = _create_card_panel(card, i == selected_idx)
		hotbar_container.add_child(card_panel)
		_card_panels.append(card_panel)
		card_panel.position.y = -45.0 if i == selected_idx else 0.0

## Cria o painel estilizado de uma carta (110x150)
func _create_card_panel(card: Dictionary, is_selected: bool) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(110, 150)

	var is_passive: bool = card.get("is_passive", false)
	var cd: float = card.get("current_cooldown", 0.0)
	var on_cooldown: bool = cd > 0.0

	var sb: StyleBoxFlat = StyleBoxFlat.new()
	# Passivas: fundo verde-escuro; em cooldown: fundo acinzentado
	if is_passive:
		sb.bg_color = Color(0.05, 0.14, 0.08, 0.95)
	elif on_cooldown:
		sb.bg_color = Color(0.12, 0.12, 0.14, 0.95)
	else:
		sb.bg_color = Color(0.1, 0.12, 0.16, 0.95)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.shadow_size = 8
	sb.shadow_color = Color(0, 0, 0, 0.45)

	if is_selected:
		sb.border_color = Color(1.0, 0.85, 0.35, 1.0)
	elif is_passive:
		sb.border_color = Color(0.3, 0.75, 0.4, 0.9)
	elif on_cooldown:
		sb.border_color = Color(0.4, 0.4, 0.45, 0.8)
	else:
		sb.border_color = Color(0.3, 0.45, 0.55, 0.8)

	panel.add_theme_stylebox_override("panel", sb)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	# Topo: Mana ou ícone passiva / cooldown
	var top_box: HBoxContainer = HBoxContainer.new()
	var top_lbl: Label = Label.new()
	top_lbl.add_theme_font_size_override("font_size", 12)
	top_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if on_cooldown:
		top_lbl.text = "⏳ %.0fs" % cd
		top_lbl.modulate = Color(0.8, 0.8, 0.5)
	elif is_passive:
		top_lbl.text = "🌿 Passiva"
		top_lbl.modulate = Color(0.4, 0.95, 0.5)
	else:
		var mana_cost: int = card.get("mana_cost", 0)
		top_lbl.text = "◆ %d" % mana_cost
		top_lbl.modulate = Color(0.3, 0.85, 1.0)

	top_box.add_child(top_lbl)

	var icon_lbl: Label = Label.new()
	icon_lbl.text = "🌿" if is_passive else "🎴"
	top_box.add_child(icon_lbl)
	vbox.add_child(top_box)

	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	# Nome da Carta
	var name_lbl: Label = Label.new()
	name_lbl.text = card.get("plant_name", "Carta")
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.modulate = Color(1.0, 0.9, 0.5) if is_selected else Color(0.9, 0.92, 0.95)
	name_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(name_lbl)

	# Efeito
	var effect_lbl: Label = Label.new()
	effect_lbl.text = card.get("effect", "")
	effect_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_lbl.add_theme_font_size_override("font_size", 10)
	effect_lbl.modulate = Color(0.6, 0.9, 0.6) if is_passive else Color(0.7, 0.85, 0.9)
	vbox.add_child(effect_lbl)

	# Overlay de cooldown escurecido
	if on_cooldown:
		var overlay: ColorRect = ColorRect.new()
		overlay.color = Color(0, 0, 0, 0.45)
		overlay.anchor_right = 1.0
		overlay.anchor_bottom = 1.0
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(overlay)

	return panel

## Atualiza suavemente a posição vertical da carta selecionada vs não selecionadas
func update_selection_animation(new_idx: int) -> void:
	for i in range(_card_panels.size()):
		var panel: PanelContainer = _card_panels[i]
		if not is_instance_valid(panel):
			continue

		var is_selected: bool = (i == new_idx)
		var target_y: float = -45.0 if is_selected else 0.0

		var sb: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		if sb:
			sb.border_color = Color(1.0, 0.85, 0.35, 1.0) if is_selected else Color(0.3, 0.45, 0.55, 0.8)

		var tw: Tween = create_tween()
		tw.tween_property(panel, "position:y", target_y, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Aviso de mana insuficiente + tremor na carta
func trigger_mana_fail(card_index: int) -> void:
	show_message("Mana insuficiente!", Color(1.0, 0.35, 0.35))

	if card_index >= 0 and card_index < _card_panels.size():
		var panel: PanelContainer = _card_panels[card_index]
		if is_instance_valid(panel):
			var tw_shake: Tween = create_tween()
			var orig_x: float = panel.position.x
			tw_shake.tween_property(panel, "position:x", orig_x - 8.0, 0.03)
			tw_shake.tween_property(panel, "position:x", orig_x + 8.0, 0.03)
			tw_shake.tween_property(panel, "position:x", orig_x - 5.0, 0.03)
			tw_shake.tween_property(panel, "position:x", orig_x + 5.0, 0.03)
			tw_shake.tween_property(panel, "position:x", orig_x, 0.03)

## Exibe qualquer mensagem flutuante central
func show_message(msg: String, color: Color = Color.WHITE) -> void:
	if not mana_warning_label:
		return
	mana_warning_label.text = msg
	mana_warning_label.modulate = Color(color.r, color.g, color.b, 1.0)
	var tw: Tween = create_tween()
	tw.tween_property(mana_warning_label, "modulate:a", 1.0, 0.08)
	tw.tween_interval(0.8)
	tw.tween_property(mana_warning_label, "modulate:a", 0.0, 0.3)
