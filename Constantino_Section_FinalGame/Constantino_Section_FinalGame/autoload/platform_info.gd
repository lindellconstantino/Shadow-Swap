extends Node
## Information about the computer the game is running on (autoload "PlatformInfo").
##
## OS CONCEPT: OS as a Platform
## The game does not talk to the hardware directly. It asks the operating
## system through Godot's OS class (name, CPU, folders, opening other programs).
## The same exported game can therefore run on Windows, Linux or macOS.


func get_platform_name() -> String:
	return OS.get_name()


# "template" is true only inside an exported game, false in the Godot editor.
func is_exported_build() -> bool:
	return OS.has_feature("template")


func get_build_label() -> String:
	return "Exported build" if is_exported_build() else "Godot editor"


func get_summary() -> String:
	var lines: PackedStringArray = []
	lines.append("Operating system: %s %s" % [OS.get_name(), OS.get_version()])
	lines.append("Running from: %s" % get_build_label())
	lines.append("Processor: %s (%d threads)" % [OS.get_processor_name(), OS.get_processor_count()])
	lines.append("Language / locale: %s" % OS.get_locale())
	lines.append("Godot version: %s" % Engine.get_version_info()["string"])
	lines.append("Save folder: %s" % OS.get_user_data_dir())
	return "\n".join(lines)


# Asks the OS to open the save folder in the file explorer (Explorer / Finder / file manager).
func open_save_folder() -> void:
	OS.shell_open(ProjectSettings.globalize_path("user://"))
