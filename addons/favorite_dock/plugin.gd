@tool
extends EditorPlugin
var dock : Control = null

func _enter_tree() -> void:
	var packed : PackedScene = load("res://addons/favorite_dock/scene/dock.tscn")
	dock = packed.instantiate()
	add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_BR, dock)



func _exit_tree() -> void:
	if dock:
		remove_control_from_docks(dock)
