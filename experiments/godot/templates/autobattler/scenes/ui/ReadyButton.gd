# =============================================================================
# ReadyButton.gd — "Start Battle" / "Fighting..." toggle button.
# =============================================================================
# Enabled only during PREP phase. Shows feedback if the board is empty.
# =============================================================================

extends Button

@onready var feedback_label: Label = $"../FeedbackLabel"

func _ready() -> void:
	RoundManager.phase_changed.connect(_on_phase_changed)
	StringManager.language_changed.connect(_on_language_changed)
	pressed.connect(_on_pressed)
	_refresh()

func _on_pressed() -> void:
	if RoundManager.board.get_board_units().is_empty():
		feedback_label.text    = StringManager.t("no_board_units")
		feedback_label.visible = true
		return
	feedback_label.visible = false
	RoundManager.start_battle()

func _on_phase_changed(p: RoundManager.Phase) -> void:
	_refresh()

func _on_language_changed(_lang: String) -> void:
	_refresh()

func _refresh() -> void:
	var is_prep = RoundManager.phase == RoundManager.Phase.PREP
	disabled = not is_prep
	text     = StringManager.t("ready_button" if is_prep else "fighting_label")
