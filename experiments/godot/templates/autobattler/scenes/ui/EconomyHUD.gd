# =============================================================================
# EconomyHUD.gd — Displays round, gold, HP and the language toggle.
# =============================================================================

extends HBoxContainer

@onready var round_label: Label  = $RoundLabel
@onready var gold_label:  Label  = $GoldLabel
@onready var hp_label:    Label  = $HPLabel
@onready var lang_button: Button = $LangButton

func _ready() -> void:
	RoundManager.gold_changed.connect(_on_gold_changed)
	RoundManager.hp_changed.connect(_on_hp_changed)
	RoundManager.phase_changed.connect(_on_phase_changed)
	StringManager.language_changed.connect(_on_language_changed)
	lang_button.pressed.connect(_on_lang_pressed)
	_refresh()

func _on_gold_changed(value: int) -> void:
	gold_label.text = StringManager.t("gold_label", {value = value})

func _on_hp_changed(value: int) -> void:
	hp_label.text = StringManager.t("hp_label", {value = value})

func _on_phase_changed(_p: RoundManager.Phase) -> void:
	_refresh_round()

func _on_language_changed(_lang: String) -> void:
	_refresh()

func _on_lang_pressed() -> void:
	var langs = ["en", "fr"]
	var idx   = langs.find(StringManager.get_language())
	StringManager.set_language(langs[(idx + 1) % langs.size()])

func _refresh() -> void:
	lang_button.text = StringManager.t("lang_button")
	_refresh_round()
	_on_gold_changed(RoundManager.player_gold)
	_on_hp_changed(RoundManager.player_hp)

func _refresh_round() -> void:
	round_label.text = StringManager.t("round_label", {
		current = RoundManager.current_round,
		total   = ConfigManager.get_int("rounds_total", 8)
	})
