extends Node
## Tiny message bus so services can raise notifications without knowing about the UI.

signal notify_requested(data: Dictionary)

## data: {title, body, icon, color, image (Texture2D), progress (0..1 or -1), duration}
func notify(data: Dictionary) -> void:
	notify_requested.emit(data)
