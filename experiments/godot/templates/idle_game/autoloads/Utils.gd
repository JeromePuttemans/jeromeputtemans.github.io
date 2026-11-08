# =============================================================================
# Utils.gd — Autoload (Singleton)
# =============================================================================
# Global utility functions accessible from any script.
# =============================================================================

extends Node

## Formats a large number using human-readable suffixes (K, M, B...).
## Idle games reach astronomical values quickly — raw floats become unreadable.
## Beyond trillions, scientific notation is used as a fallback.
static func format_number(n: float) -> String:
	if n < 1_000:
		return "%.1f" % n
	elif n < 1_000_000:
		return "%.2fK" % (n / 1_000.0)
	elif n < 1_000_000_000:
		return "%.2fM" % (n / 1_000_000.0)
	elif n < 1_000_000_000_000:
		return "%.2fB" % (n / 1_000_000_000.0)
	else:
		return "%.2e" % n
