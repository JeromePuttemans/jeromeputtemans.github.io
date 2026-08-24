# =============================================================================
# BattleLog.gd — Displays battle events as a scrolling text log.
# =============================================================================
# Auto-scrolls to the bottom after each new line via call_deferred so
# the scroll happens after the layout pass (Godot defers size recalculation).
#
# CRITICAL: use free() not queue_free() when removing old labels.
# queue_free() defers deletion to end-of-frame, so get_child_count() does
# not decrease immediately — a while loop on get_child_count() would loop
# forever and freeze Godot. free() removes the node from the tree instantly.
# =============================================================================

extends VBoxContainer

const MAX_LINES = 8

@onready var scroll: ScrollContainer = $ScrollContainer
@onready var vbox:   VBoxContainer   = $ScrollContainer/VBox

func _ready() -> void:
	RoundManager.battle_event.connect(_on_battle_event)
	RoundManager.phase_changed.connect(_on_phase_changed)
	StringManager.language_changed.connect(_on_language_changed)

func _on_phase_changed(p: RoundManager.Phase) -> void:
	if p == RoundManager.Phase.BATTLE:
		_clear()

func _on_battle_event(ev: BattleSimulator.BattleEvent) -> void:
	var text = ""
	match ev.type:
		"attack":
			text = StringManager.t("battle_attack", {
				attacker = ev.attacker,
				target   = ev.target,
				damage   = ev.damage
			})
		"death":
			text = StringManager.t("battle_unit_died", {name = ev.name})
		"result":
			match ev.result:
				"player_win":
					text = StringManager.t("battle_won")
				"enemy_win":
					text = StringManager.t("battle_lost", {damage = ev.player_hp_damage})
				"draw":
					text = StringManager.t("battle_draw")
	if not text.is_empty():
		_append(text)

func _append(text: String) -> void:
	# Remove the oldest label BEFORE adding the new one.
	# We add exactly one label per call so a single if is enough.
	# free() is immediate: get_child_count() decreases right away.
	if vbox.get_child_count() >= MAX_LINES:
		vbox.get_child(0).free()

	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl)

	# Defer the scroll: Godot recalculates layout on the next frame,
	# so reading max_value before that gives a stale result.
	call_deferred("_scroll_to_bottom")

func _scroll_to_bottom() -> void:
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)

func _clear() -> void:
	# free() not queue_free() — same reason as above.
	for child in vbox.get_children():
		child.free()

func _on_language_changed(_lang: String) -> void:
	pass
