# ═════════════════════════════════════════════════════════════
#   CONSTANTES PARTAGÉES - MONDRIAN TETRIS
#   Utilisées par Main.gd et UI.gd
# ═════════════════════════════════════════════════════════════

# ── Grille ──────────────────────────────────────────────────
const CELL_SIZE  := 30   # taille d'une cellule en pixels
const COLS  := 15        # largeur du plateau
const ROWS  := 15        # hauteur du plateau
const BX    := 82        # coin supérieur-gauche du plateau (x)
const BY    := 205       # coin supérieur-gauche du plateau (y)
const GAME_OVER_X := 90  # coin supérieur-gauche du plateau (x)
const GAME_OVER_Y := 30  # coin supérieur-gauche du plateau (y)
const LINE_WIDTH  := 3.0 # épaisseur des lignes de grille

# ── Palette Mondrian ────────────────────────────────────────
const C_RED    := Color("#D30E20")
const C_BLUE   := Color("#1D5FA8")
const C_YELLOW := Color("#F5C518")
const C_BLACK  := Color("#111111")
const C_WHITE  := Color("#F5F3EE")
const C_GREY   := Color("#888888")
const C_BORDERS := C_BLACK

# ── Formes des pièces (coordonnées relatives) ───────────────
const SHAPES : Array = [
	[Vector2i(0,0)], # Little Square
	[Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)], # Medium Square
	[Vector2i(0,0),Vector2i(1,0),Vector2i(2,0), # Big Square
	 Vector2i(0,1),Vector2i(1,1),Vector2i(2,1),
	 Vector2i(0,2),Vector2i(1,2),Vector2i(2,2)],
	[Vector2i(0,0),Vector2i(1,0)],              # Little I
	[Vector2i(0,0),Vector2i(1,0),Vector2i(2,0)], # Big I
]

const PIECE_COLORS : Array = [
	C_YELLOW, C_YELLOW, C_YELLOW,
	C_RED,    C_RED,
	C_BLUE,   C_BLUE,
	C_BLACK,
]

# ── UI Constants ────────────────────────────────────────────
const UI_OFFSET_X := 75
const UI_START_Y := 38
