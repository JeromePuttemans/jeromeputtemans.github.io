# =============================================================================
# Bullet.gd — Documentation only. Bullets are pure Dictionaries in BulletPool.
# =============================================================================
# Dictionary schema:
#   active: bool
#   pos:    Vector2   (local to BulletPool — pool sits at Vector2.ZERO in World)
#   vel:    Vector2   (pixels/second)
#   color:  Color
#   radius: float
#   trail:  Array     (Array[Vector2] ring buffer of past local positions)
# =============================================================================
