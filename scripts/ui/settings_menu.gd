extends VBoxContainer
## Settings of the main menu (scenes/ui/settings_menu.tscn): Settings → Volume.
## The sliders change the "Master" (everything) and "Music" volumes; they are saved at once.
## Buttons and sliders are connected in the scene (Node > Signals).

signal back_pressed

@onready var _settings_panel: VBoxContainer = %SettingsPanel
@onready var _volume_panel: VBoxContainer = %VolumePanel
@onready var _master_slider: HSlider = %MasterSlider
@onready var _music_slider: HSlider = %MusicSlider


## Shows the first page (Settings).
func open() -> void:
	visible = true
	_show(_settings_panel)


func _show(panel: Control) -> void:
	_settings_panel.visible = panel == _settings_panel
	_volume_panel.visible = panel == _volume_panel
	if panel == _volume_panel:
		_master_slider.set_value_no_signal(Settings.get_volume("Master") * 100.0)
		_music_slider.set_value_no_signal(Settings.get_volume("Music") * 100.0)
		_update_labels()
		_master_slider.grab_focus.call_deferred()
	else:
		%VolumeButton.grab_focus.call_deferred()


func _update_labels() -> void:
	%MasterValue.text = "%d%%" % roundi(_master_slider.value)
	%MusicValue.text = "%d%%" % roundi(_music_slider.value)


func _on_volume_button_pressed() -> void:
	_show(_volume_panel)


func _on_settings_back_pressed() -> void:
	back_pressed.emit()


func _on_volume_back_pressed() -> void:
	_show(_settings_panel)


func _on_master_slider_value_changed(value: float) -> void:
	Settings.set_volume("Master", value / 100.0)
	_update_labels()


func _on_music_slider_value_changed(value: float) -> void:
	Settings.set_volume("Music", value / 100.0)
	_update_labels()
