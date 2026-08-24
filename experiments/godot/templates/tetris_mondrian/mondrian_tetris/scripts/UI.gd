extends Node2D

# ═════════════════════════════════════════════════════════════
#   MONDRIAN TETRIS  —  inspiré de Piet Mondrian
#   Godot 4.x  |  Node2D  |  dessin entièrement via _draw()
# ═════════════════════════════════════════════════════════════

# ── Board Properties (set from Main.gd) ─────────────────────────────────────
@export var board_offset_x: int = 0
@export var board_offset_y: int = 0
@export var board_cols: int = 0
@export var board_rows: int = 0
@export var board_cell_size: int = 0

# ── UI State ────────────────────────────────────────────────────────────────
var score: int = 0
var level: int = 0
var lines: int = 0
var next_type: int = 0
var next_color: Color
var is_over: bool = false

# ── Références aux constantes partagées ─────────────────────
const Constants := preload("res://scripts/Constants.gd")

# ── Initialisation ──────────────────────────────────────────────────────────
func _ready() -> void:
	pass

# ── Signal Handlers ─────────────────────────────────────────────────────────
func _on_score_changed(new_score: int) -> void:
	score = new_score
	queue_redraw()

func _on_level_changed(new_level: int) -> void:
	level = new_level
	queue_redraw()

func _on_lines_changed(new_lines: int) -> void:
	lines = new_lines
	queue_redraw()

func _on_next_piece_changed(new_type: int, new_color: Color) -> void:
	next_type = new_type
	next_color = new_color
	queue_redraw()

func _on_game_over_changed(new_is_over: bool) -> void:
	is_over = new_is_over
	queue_redraw()

# ── Rendu principal ─────────────────────────────────────────────────────────
func _draw() -> void:
	_draw_ui()
	if is_over:
		_draw_gameover()

# ── Interface utilisateur ───────────────────────────────────────────────────
func _draw_ui() -> void:
	var f  := ThemeDB.fallback_font
	var rx := board_offset_x + board_cols * board_cell_size + Constants.UI_OFFSET_X

	# Score
	draw_string(f, Vector2(rx, Constants.UI_START_Y),     "SCORE",     HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Constants.C_BLACK)
	draw_string(f, Vector2(rx, Constants.UI_START_Y + 24), str(score),  HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Constants.C_BLACK)

	# Niveau
	draw_string(f, Vector2(rx, Constants.UI_START_Y + 64), "NIVEAU",    HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Constants.C_BLACK)
	draw_string(f, Vector2(rx, Constants.UI_START_Y + 88), str(level),  HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Constants.C_BLACK)

	# Lignes
	draw_string(f, Vector2(rx, Constants.UI_START_Y + 127), "LIGNES",    HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Constants.C_BLACK)
	draw_string(f, Vector2(rx, Constants.UI_START_Y + 151), str(lines),  HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Constants.C_BLACK)

	# Pièce suivante
	draw_string(f, Vector2(rx, Constants.UI_START_Y + 190), "SUIVANT",   HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Constants.C_BLACK)
	var ps := 22
	var px := rx
	var py := Constants.UI_START_Y + 200
	for v : Vector2i in Constants.SHAPES[next_type]:
		draw_rect(Rect2(px + v.x * ps, py + v.y * ps, ps, ps), next_color)
		draw_rect(Rect2(px + v.x * ps, py + v.y * ps, ps, ps), next_color, false, 2)

	# Contrôles
	var cy := Constants.UI_START_Y + 302
	draw_string(f, Vector2(rx - 5, cy),      "< >  Déplacer",   HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Constants.C_BLACK)
	draw_string(f, Vector2(rx - 5, cy + 20), "^      Rotation",  HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Constants.C_BLACK)
	draw_string(f, Vector2(rx - 5, cy + 40), "v      Descendre", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Constants.C_BLACK)
	draw_string(f, Vector2(rx - 5, cy + 60), "Espace  Drop",     HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Constants.C_BLACK)
	draw_string(f, Vector2(rx - 5, cy + 80), "R       Rejouer",  HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Constants.C_BLACK)

# ── Écran Game Over ─────────────────────────────────────────────────────────
func _draw_gameover() -> void:
	draw_rect(Rect2(Constants.GAME_OVER_X, Constants.GAME_OVER_Y, board_cols * board_cell_size, board_rows * board_cell_size), Color(0, 0, 0, 0.80))
	var f  := ThemeDB.fallback_font
	var cy := Constants.GAME_OVER_Y + board_rows * board_cell_size * 0.5

	draw_string(f, Vector2(Constants.GAME_OVER_X + 22, cy - 12), "Un nouveau Mondrian !",   HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Constants.C_RED)
	draw_string(f, Vector2(Constants.GAME_OVER_X + 28, cy + 28), "Score : " + str(score),   HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Constants.C_YELLOW)
	draw_string(f, Vector2(Constants.GAME_OVER_X + 18, cy + 60), "Entrée / R pour recréer", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Constants.C_WHITE)
