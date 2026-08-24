# =============================================================================
# HUD.gd — CanvasLayer UI: score, lives, wave, language toggle.
# Layout: MarginContainer (FULL_RECT) → VBoxOuter → TopBar / Spacer / BottomBar
# All mouse_filter = PASS so clicks reach the game world.
# =============================================================================
extends MarginContainer

@onready var score_lbl:  Label  = $VBoxOuter/TopBar/ScoreLabel
@onready var hs_lbl:     Label  = $VBoxOuter/TopBar/HSLabel
@onready var lives_lbl:  Label  = $VBoxOuter/TopBar/LivesLabel
@onready var wave_lbl:   Label  = $VBoxOuter/TopBar/WaveLabel
@onready var lang_btn:   Button = $VBoxOuter/TopBar/LangButton
@onready var ctrl_lbl:   Label  = $VBoxOuter/BottomBar/ControlsLabel

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.score_changed.connect(_on_score)
	GameState.lives_changed.connect(_on_lives)
	GameState.wave_changed.connect(_on_wave)
	StringManager.language_changed.connect(func(_l): _refresh())
	lang_btn.pressed.connect(_on_lang)
	_refresh()

func _on_score(v: int) -> void:
	score_lbl.text = StringManager.t("score_label", {value = v})
	hs_lbl.text    = StringManager.t("high_score",  {value = GameState.high_score})

func _on_lives(v: int) -> void:
	lives_lbl.text = StringManager.t("lives_label", {value = v})

func _on_wave(n: int) -> void:
	wave_lbl.text = StringManager.t("wave_label",
		{current = n, total = GameState.total_waves})

func _on_lang() -> void:
	var langs = ["en", "fr"]
	var idx   = langs.find(StringManager.get_language())
	StringManager.set_language(langs[(idx + 1) % langs.size()])

func _refresh() -> void:
	lang_btn.text = StringManager.t("lang_button")
	ctrl_lbl.text = StringManager.t("controls")
	_on_score(GameState.score)
	_on_lives(GameState.lives)
	_on_wave(GameState.wave)
