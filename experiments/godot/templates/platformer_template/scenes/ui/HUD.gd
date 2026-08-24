# =============================================================================
# HUD.gd — Heads-Up Display attached to a MarginContainer (CanvasLayer).
# =============================================================================
# Uses full-rect anchors so it fills the viewport regardless of window size.
# Subscribes to GameState and StringManager signals — no polling in _process.
# =============================================================================

extends MarginContainer

@onready var lives_label:    Label  = $VBoxOuter/TopBar/LivesLabel
@onready var score_label:    Label  = $VBoxOuter/TopBar/ScoreLabel
@onready var level_label:    Label  = $VBoxOuter/TopBar/LevelLabel
@onready var lang_button:    Button = $VBoxOuter/TopBar/LangButton
@onready var controls_label: Label  = $VBoxOuter/ControlsLabel

func _ready() -> void:
	GameState.score_changed.connect(_on_score_changed)
	GameState.lives_changed.connect(_on_lives_changed)
	GameState.phase_changed.connect(_on_phase_changed)
	StringManager.language_changed.connect(_on_language_changed)
	lang_button.pressed.connect(_on_lang_pressed)
	_refresh()

func refresh_level() -> void:
	level_label.text = StringManager.t("level_label", {
		value = GameState.current_level + 1
	})

func _on_score_changed(value: int) -> void:
	score_label.text = StringManager.t("score_label", {value = value})

func _on_lives_changed(value: int) -> void:
	lives_label.text = StringManager.t("lives_label", {value = value})

func _on_phase_changed(_p: GameState.Phase) -> void:
	refresh_level()

func _on_lang_pressed() -> void:
	var langs = ["en", "fr"]
	var idx   = langs.find(StringManager.get_language())
	StringManager.set_language(langs[(idx + 1) % langs.size()])

func _on_language_changed(_lang: String) -> void:
	_refresh()

func _refresh() -> void:
	lang_button.text    = StringManager.t("lang_button")
	controls_label.text = StringManager.t("controls")
	_on_score_changed(GameState.score)
	_on_lives_changed(GameState.lives)
	refresh_level()
