class_name UiTheme
## The look of every menu: near-black panels with a soft gold border, light
## text and icons, and dark buttons that brighten on hover. Saved as
## resources/ui_theme.tres, the project's default theme, so every menu, window
## and dialog uses it; regenerate it with scripts/tools/build_ui_theme.gd.

const PANEL := Color(0.075, 0.08, 0.1, 0.97)
const BORDER := Color(0.86, 0.72, 0.48, 0.55)
const TEXT := Color(0.93, 0.92, 0.88)
const TEXT_DIM := Color(0.93, 0.92, 0.88, 0.45)
const ACCENT := Color(1.0, 0.85, 0.5)

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func panel_style(bg := PANEL, border := BORDER) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(10)
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 10
	box.set_content_margin_all(6)
	return box


static func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(7)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


static func _build() -> Theme:
	var theme := Theme.new()
	theme.set_stylebox("panel", "PanelContainer", panel_style())
	theme.set_stylebox("panel", "Panel", panel_style())
	# Dialogs (release / delete confirmations): the window's border wraps the
	# title bar too; the content inside has no border of its own.
	var dialog_body := StyleBoxFlat.new()
	dialog_body.bg_color = PANEL
	dialog_body.set_content_margin_all(10)
	theme.set_stylebox("panel", "AcceptDialog", dialog_body)
	for state in ["embedded_border", "embedded_unfocused_border"]:
		var frame := panel_style(PANEL, BORDER)
		frame.expand_margin_left = 8
		frame.expand_margin_right = 8
		frame.expand_margin_bottom = 8
		frame.expand_margin_top = 36  # the title bar
		theme.set_stylebox(state, "Window", frame)
	theme.set_color("title_color", "Window", ACCENT)

	# Buttons: dark, a light border on hover, gold when pressed or toggled on.
	theme.set_stylebox("normal", "Button", _button_style(Color(0.13, 0.14, 0.17), Color(1, 1, 1, 0.08)))
	theme.set_stylebox("hover", "Button", _button_style(Color(0.19, 0.2, 0.24), Color(1, 1, 1, 0.35)))
	theme.set_stylebox("pressed", "Button", _button_style(Color(0.24, 0.21, 0.14), ACCENT))
	theme.set_stylebox("hover_pressed", "Button", _button_style(Color(0.28, 0.24, 0.15), ACCENT))
	theme.set_stylebox("disabled", "Button", _button_style(Color(0.1, 0.1, 0.12), Color(1, 1, 1, 0.04)))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for state in ["font_color", "icon_normal_color"]:
		theme.set_color(state, "Button", TEXT)
	for state in ["font_hover_color", "icon_hover_color", "font_focus_color", "icon_focus_color"]:
		theme.set_color(state, "Button", Color.WHITE)
	for state in ["font_pressed_color", "icon_pressed_color", "font_hover_pressed_color", "icon_hover_pressed_color"]:
		theme.set_color(state, "Button", ACCENT)
	for state in ["font_disabled_color", "icon_disabled_color"]:
		theme.set_color(state, "Button", TEXT_DIM)
	theme.set_constant("h_separation", "Button", 8)

	theme.set_color("font_color", "Label", TEXT)

	# Text fields on the title screen.
	var field := _button_style(Color(0.05, 0.055, 0.07), Color(1, 1, 1, 0.12))
	theme.set_stylebox("normal", "LineEdit", field)
	theme.set_stylebox("focus", "LineEdit", _button_style(Color(0.05, 0.055, 0.07), Color(ACCENT, 0.7)))
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", TEXT_DIM)
	theme.set_color("caret_color", "LineEdit", ACCENT)

	# Tooltips.
	var tip := panel_style(Color(0.05, 0.055, 0.07, 0.97), Color(1, 1, 1, 0.2))
	tip.shadow_size = 4
	theme.set_stylebox("panel", "TooltipPanel", tip)
	theme.set_color("font_color", "TooltipLabel", TEXT)

	# Scroll bars (the breeder's pet list).
	var grabber := _button_style(Color(1, 1, 1, 0.25), Color(0, 0, 0, 0))
	theme.set_stylebox("grabber", "VScrollBar", grabber)
	theme.set_stylebox("grabber_highlight", "VScrollBar", _button_style(Color(1, 1, 1, 0.4), Color(0, 0, 0, 0)))
	theme.set_stylebox("scroll", "VScrollBar", _button_style(Color(1, 1, 1, 0.05), Color(0, 0, 0, 0)))
	return theme
