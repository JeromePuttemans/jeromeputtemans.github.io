# =============================================================================
# ClickButton.gd — Manual click button
# =============================================================================
# Scale bounce animation on click for tactile feedback.
# Label text is driven by StringManager so it updates on language switch.
# =============================================================================

extends Button

var _base_scale: Vector2
const CLICK_SCALE  = 0.9
const RETURN_SPEED = 10.0

func _ready() -> void:
	_base_scale = scale
	pressed.connect(_on_pressed)
	StringManager.language_changed.connect(_on_language_changed)
	text = StringManager.t("click_button")

func _process(delta: float) -> void:
	scale = scale.lerp(_base_scale, RETURN_SPEED * delta)

func _on_pressed() -> void:
	GameManager.manual_click()
	scale = _base_scale * CLICK_SCALE

func _on_language_changed(_lang: String) -> void:
	text = StringManager.t("click_button")
