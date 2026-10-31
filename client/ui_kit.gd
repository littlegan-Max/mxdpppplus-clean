class_name UIKit
extends RefCounted

const GOLD := Color("#ffcc4d")
const CYAN := Color("#7cf6c9")
const RED := Color("#ff5a6e")
const BLUE := Color("#5bb8ff")
const WHITE := Color("#f5f1ff")
const GREY := Color("#8f86a8")
const DIM := Color("#b9a8d8")
const DARK := Color("#0b0618")
const PURPLE := Color("#24104a")

static var _theme: Theme = null


static func art(path: String) -> Texture2D:
    return load("res://assets/art/" + path)


static func make_style(path: String, margin: int = 10, content: int = 14) -> StyleBoxTexture:
    var s := StyleBoxTexture.new()
    s.texture = art(path)
    s.texture_margin_left = margin
    s.texture_margin_right = margin
    s.texture_margin_top = margin
    s.texture_margin_bottom = margin
    s.content_margin_left = content
    s.content_margin_right = content
    s.content_margin_top = content * 0.6
    s.content_margin_bottom = content * 0.6
    return s


static func make_theme() -> Theme:
    if _theme != null:
        return _theme
    var t := Theme.new()
    var font := SystemFont.new()
    font.font_names = ["Microsoft YaHei", "Noto Sans CJK SC", "PingFang SC", "Noto Sans", "sans-serif"]
    font.font_weight = 500
    t.default_font = font
    t.default_font_size = 22
    var btn := make_style("btn.png", 8, 16)
    var hover := make_style("btn_hover.png", 8, 16)
    var pressed := make_style("btn_pressed.png", 8, 16)
    var disabled := make_style("btn_disabled.png", 8, 16)
    t.set_stylebox("normal", "Button", btn)
    t.set_stylebox("hover", "Button", hover)
    t.set_stylebox("pressed", "Button", pressed)
    t.set_stylebox("disabled", "Button", disabled)
    t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
    t.set_color("font_color", "Button", WHITE)
    t.set_color("font_hover_color", "Button", Color("#fff3c4"))
    t.set_color("font_pressed_color", "Button", Color("#d8cff0"))
    t.set_color("font_disabled_color", "Button", Color("#7a728c"))
    t.set_font_size("font_size", "Button", 24)
    t.set_stylebox("panel", "PanelContainer", make_style("panel.png", 10, 18))
    t.set_stylebox("panel", "Panel", make_style("panel.png", 10, 18))
    var le := make_style("panel_dark.png", 8, 14)
    t.set_stylebox("normal", "LineEdit", le)
    t.set_stylebox("focus", "LineEdit", make_style("panel_cyan.png", 8, 14))
    t.set_color("font_color", "LineEdit", WHITE)
    t.set_color("font_placeholder_color", "LineEdit", GREY)
    t.set_font_size("font_size", "LineEdit", 24)
    t.set_color("font_color", "Label", WHITE)
    t.set_stylebox("normal", "OptionButton", btn)
    t.set_stylebox("hover", "OptionButton", hover)
    t.set_stylebox("pressed", "OptionButton", pressed)
    t.set_color("font_color", "OptionButton", WHITE)
    t.set_font_size("font_size", "OptionButton", 22)
    t.set_stylebox("normal", "CheckBox", StyleBoxEmpty.new())
    t.set_stylebox("hover", "CheckBox", StyleBoxEmpty.new())
    t.set_stylebox("pressed", "CheckBox", StyleBoxEmpty.new())
    t.set_stylebox("disabled", "CheckBox", StyleBoxEmpty.new())
    t.set_stylebox("focus", "CheckBox", StyleBoxEmpty.new())
    t.set_icon("checked", "CheckBox", art("icons/check_on.png"))
    t.set_icon("unchecked", "CheckBox", art("icons/check_off.png"))
    t.set_constant("h_separation", "CheckBox", 8)
    t.set_color("font_color", "CheckBox", WHITE)
    t.set_font_size("font_size", "CheckBox", 22)
    t.set_color("font_color", "SpinBox", WHITE)
    t.set_font_size("font_size", "SpinBox", 22)
    t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
    t.set_stylebox("panel", "PopupMenu", make_style("panel_dark.png", 8, 12))
    t.set_color("font_color", "PopupMenu", WHITE)
    t.set_font_size("font_size", "PopupMenu", 22)
    _theme = t
    return t


static func bg(parent: Control, path: String = "bg_lobby.png") -> TextureRect:
    var tr := TextureRect.new()
    tr.texture = art(path)
    tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    tr.set_anchors_preset(Control.PRESET_FULL_RECT)
    tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(tr)
    return tr


static func dim(parent: Control, alpha: float = 0.55) -> ColorRect:
    var c := ColorRect.new()
    c.color = Color(0.03, 0.02, 0.07, alpha)
    c.set_anchors_preset(Control.PRESET_FULL_RECT)
    c.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(c)
    return c


static func label(text: String, size: int = 22, color: Color = WHITE,
        align: int = HORIZONTAL_ALIGNMENT_LEFT, wrap: bool = false) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.horizontal_alignment = align
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
    return l


static func title(text: String, size: int = 54, color: Color = GOLD) -> Label:
    var l := label(text, size, color, HORIZONTAL_ALIGNMENT_CENTER)
    l.add_theme_constant_override("outline_size", 8)
    l.add_theme_color_override("font_outline_color", Color("#1a0b30"))
    return l


static func button(text: String, w: float = 240, h: float = 64, size: int = 24) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(w, h)
    b.add_theme_font_size_override("font_size", size)
    b.focus_mode = Control.FOCUS_NONE
    return b


static func small_button(text: String, w: float = 150, h: float = 48, size: int = 20) -> Button:
    return button(text, w, h, size)


static func panel(path: String = "panel.png") -> PanelContainer:
    var p := PanelContainer.new()
    var s := make_style(path, 10, 18)
    p.add_theme_stylebox_override("panel", s)
    return p


static func icon(name: String, px: int = 32) -> TextureRect:
    var tr := TextureRect.new()
    tr.texture = art("icons/%s.png" % name)
    tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    tr.custom_minimum_size = Vector2(px, px)
    tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return tr


static func avatar(index: int, px: int = 96) -> TextureRect:
    var tr := TextureRect.new()
    tr.texture = art("avatar_%d.png" % (index % 8))
    tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    tr.custom_minimum_size = Vector2(px, px)
    tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return tr


static func spacer(x: float = 0, y: float = 0) -> Control:
    var c := Control.new()
    c.custom_minimum_size = Vector2(x, y)
    return c


static func hbox(sep: int = 12) -> HBoxContainer:
    var b := HBoxContainer.new()
    b.add_theme_constant_override("separation", sep)
    return b


static func vbox(sep: int = 12) -> VBoxContainer:
    var b := VBoxContainer.new()
    b.add_theme_constant_override("separation", sep)
    return b


static func toast(parent: Control, text: String) -> void:
    if parent == null or not is_instance_valid(parent):
        return
    var layer := CanvasLayer.new()
    layer.layer = 100
    parent.add_child(layer)
    var panel := panel("panel_red.png")
    panel.theme = make_theme()
    panel.custom_minimum_size = Vector2(560, 70)
    panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
    panel.position = Vector2(-280, 40)
    var l := label(text, 22, WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
    panel.add_child(l)
    layer.add_child(panel)
    var tw := layer.create_tween()
    tw.tween_interval(2.4)
    tw.tween_property(panel, "modulate:a", 0.0, 0.4)
    tw.tween_callback(layer.queue_free)


static func confirm(parent: Control, title_text: String, body: String,
        on_yes: Callable, on_no: Callable = Callable()) -> void:
    var layer := CanvasLayer.new()
    layer.layer = 120
    parent.add_child(layer)
    var shade := ColorRect.new()
    shade.color = Color(0.02, 0.01, 0.05, 0.75)
    shade.set_anchors_preset(Control.PRESET_FULL_RECT)
    layer.add_child(shade)
    var p := panel()
    p.theme = make_theme()
    p.custom_minimum_size = Vector2(620, 300)
    p.set_anchors_preset(Control.PRESET_CENTER)
    p.position = Vector2(-310, -150)
    layer.add_child(p)
    var v := vbox(16)
    p.add_child(v)
    v.add_child(label(title_text, 32, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
    v.add_child(label(body, 22, WHITE, HORIZONTAL_ALIGNMENT_CENTER, true))
    var h := hbox(20)
    h.alignment = BoxContainer.ALIGNMENT_CENTER
    var yes := button("确定", 200, 60)
    var no := button("取消", 200, 60)
    h.add_child(yes)
    h.add_child(no)
    v.add_child(h)
    yes.pressed.connect(func():
        layer.queue_free()
        if on_yes.is_valid():
            on_yes.call())
    no.pressed.connect(func():
        layer.queue_free()
        if on_no.is_valid():
            on_no.call())


static func fmt(v: int) -> String:
    return Cards.fmt_t(v)
