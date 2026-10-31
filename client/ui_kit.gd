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
## 七圣召唤风格的配色：深青底、鎏金描边、暖白正文。
const IVORY := Color("#f3e9d2")
const NAVY := Color("#0c1a24")
const TEAL := Color("#12323f")
const FRAME := Color("#c9a45c")
const FRAME_DIM := Color("#7c6437")

static var _theme: Theme = null
static var safe_left := 0.0
## 手机端整体字号倍数（桌面为 1.0）。
static var text_scale := 1.0


static func fs(size: int) -> int:
    return int(round(size * text_scale))


static func px(value: float) -> float:
    return value * text_scale


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


## 深色底 + 描边的圆角卡片，用来替代贴图面板，靠近七圣召唤的牌框质感。
static func flat_style(bg: Color, border: Color = FRAME_DIM, border_w: int = 2,
        radius: int = 12, pad: int = 16) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(border_w)
    s.set_corner_radius_all(radius)
    s.content_margin_left = pad
    s.content_margin_right = pad
    s.content_margin_top = int(pad * 0.7)
    s.content_margin_bottom = int(pad * 0.7)
    s.shadow_size = 8
    s.shadow_color = Color(0, 0, 0, 0.45)
    return s


static func gilded_style(border: Color = FRAME, radius: int = 14) -> StyleBoxFlat:
    var s := flat_style(Color(0.043, 0.098, 0.137, 0.93), border, 2, radius, 16)
    s.shadow_size = 14
    s.shadow_color = Color(0, 0, 0, 0.5)
    return s


static func card_style(accent: Color, radius: int = 12, thick: int = 2,
        bg: Color = Color(0.055, 0.117, 0.157, 0.96)) -> StyleBoxFlat:
    var s := flat_style(bg, accent, thick, radius, 10)
    s.shadow_size = 10
    s.shadow_color = Color(accent.r, accent.g, accent.b, 0.18)
    return s


static func divider(alpha: float = 0.55, h: float = 2.0) -> ColorRect:
    var c := ColorRect.new()
    c.color = Color(FRAME.r, FRAME.g, FRAME.b, alpha)
    c.custom_minimum_size = Vector2(0, h)
    c.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return c


static func make_theme() -> Theme:
    if _theme != null:
        return _theme
    var t := Theme.new()
    var font := SystemFont.new()
    font.font_names = ["Microsoft YaHei", "Noto Sans CJK SC", "PingFang SC", "Noto Sans", "sans-serif"]
    font.font_weight = 500
    t.default_font = font
    t.default_font_size = fs(22)
    var btn := make_style("btn.png", 8, 16)
    var hover := make_style("btn_hover.png", 8, 16)
    var pressed := make_style("btn_pressed.png", 8, 16)
    var disabled := make_style("btn_disabled.png", 8, 16)
    t.set_stylebox("normal", "Button", btn)
    t.set_stylebox("hover", "Button", hover)
    t.set_stylebox("pressed", "Button", pressed)
    t.set_stylebox("disabled", "Button", disabled)
    t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
    t.set_color("font_color", "Button", IVORY)
    t.set_color("font_hover_color", "Button", Color("#fff3c4"))
    t.set_color("font_pressed_color", "Button", Color("#d8cff0"))
    t.set_color("font_disabled_color", "Button", Color("#7a728c"))
    t.set_font_size("font_size", "Button", fs(24))
    t.set_stylebox("panel", "PanelContainer", make_style("panel.png", 10, 18))
    t.set_stylebox("panel", "Panel", make_style("panel.png", 10, 18))
    var le := make_style("panel_dark.png", 8, 14)
    t.set_stylebox("normal", "LineEdit", le)
    t.set_stylebox("focus", "LineEdit", make_style("panel_cyan.png", 8, 14))
    t.set_color("font_color", "LineEdit", IVORY)
    t.set_color("font_placeholder_color", "LineEdit", GREY)
    t.set_font_size("font_size", "LineEdit", fs(24))
    t.set_color("font_color", "Label", IVORY)
    t.set_stylebox("normal", "OptionButton", btn)
    t.set_stylebox("hover", "OptionButton", hover)
    t.set_stylebox("pressed", "OptionButton", pressed)
    t.set_color("font_color", "OptionButton", IVORY)
    t.set_font_size("font_size", "OptionButton", fs(22))
    t.set_stylebox("normal", "CheckBox", StyleBoxEmpty.new())
    t.set_stylebox("hover", "CheckBox", StyleBoxEmpty.new())
    t.set_stylebox("pressed", "CheckBox", StyleBoxEmpty.new())
    t.set_stylebox("disabled", "CheckBox", StyleBoxEmpty.new())
    t.set_stylebox("focus", "CheckBox", StyleBoxEmpty.new())
    t.set_icon("checked", "CheckBox", art("icons/check_on.png"))
    t.set_icon("unchecked", "CheckBox", art("icons/check_off.png"))
    t.set_constant("h_separation", "CheckBox", 8)
    t.set_color("font_color", "CheckBox", IVORY)
    t.set_font_size("font_size", "CheckBox", fs(22))
    t.set_color("font_color", "SpinBox", IVORY)
    t.set_font_size("font_size", "SpinBox", fs(22))
    t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
    t.set_stylebox("panel", "PopupMenu", make_style("panel_dark.png", 8, 12))
    t.set_color("font_color", "PopupMenu", IVORY)
    t.set_font_size("font_size", "PopupMenu", fs(22))
    _theme = t
    return t


static func bg(parent: Control, path: String = "bg_lobby.png") -> TextureRect:
    var tr := TextureRect.new()
    tr.texture = art(path)
    tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    tr.set_anchors_preset(Control.PRESET_FULL_RECT)
    if safe_left > 0.0:
        tr.offset_left = -safe_left
    tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(tr)
    return tr


static func dim(parent: Control, alpha: float = 0.55) -> ColorRect:
    var c := ColorRect.new()
    c.color = Color(0.03, 0.02, 0.07, alpha)
    c.set_anchors_preset(Control.PRESET_FULL_RECT)
    if safe_left > 0.0:
        c.offset_left = -safe_left
    c.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(c)
    return c


static func label(text: String, size: int = 22, color: Color = IVORY,
        align: int = HORIZONTAL_ALIGNMENT_LEFT, wrap: bool = false) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", fs(size))
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
    b.add_theme_font_size_override("font_size", fs(size))
    b.focus_mode = Control.FOCUS_NONE
    _hover_lift(b)
    return b


static func _hover_lift(b: Button) -> void:
    b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
    b.mouse_entered.connect(func():
        if b.disabled or b.is_queued_for_deletion():
            return
        b.pivot_offset = b.size * 0.5
        var tw := b.create_tween().set_parallel(true)
        tw.tween_property(b, "scale", Vector2(1.03, 1.03), 0.12).set_trans(Tween.TRANS_SINE)
        tw.tween_property(b, "self_modulate", Color(1.08, 1.08, 1.08), 0.12))
    b.mouse_exited.connect(func():
        if b.is_queued_for_deletion():
            return
        var tw := b.create_tween().set_parallel(true)
        tw.tween_property(b, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE)
        tw.tween_property(b, "self_modulate", Color(1.0, 1.0, 1.0), 0.16))


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
    var d := int(round(px * clampf(text_scale, 1.0, 1.25)))
    tr.custom_minimum_size = Vector2(d, d)
    tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return tr


static func avatar(index: int, px: int = 96) -> TextureRect:
    var tr := TextureRect.new()
    tr.texture = art("avatar_%d.png" % (index % 8))
    tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    var d := int(round(px * clampf(text_scale, 1.0, 1.25)))
    tr.custom_minimum_size = Vector2(d, d)
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
    panel.custom_minimum_size = Vector2(620, 76)
    panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
    panel.position = Vector2(-310, 18)
    panel.modulate.a = 0.0
    var l := label(text, 22, WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
    panel.add_child(l)
    layer.add_child(panel)
    var tw := layer.create_tween().set_parallel(true)
    tw.tween_property(panel, "position:y", 40.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tw.tween_property(panel, "modulate:a", 1.0, 0.2)
    tw.chain().tween_interval(2.2)
    tw.chain().tween_property(panel, "modulate:a", 0.0, 0.4)
    tw.chain().tween_callback(layer.queue_free)


static func confirm(parent: Control, title_text: String, body: String,
        on_yes: Callable, on_no: Callable = Callable()) -> void:
    var layer := CanvasLayer.new()
    layer.layer = 120
    parent.add_child(layer)
    var shade := ColorRect.new()
    shade.color = Color(0.02, 0.01, 0.05, 0.78)
    shade.set_anchors_preset(Control.PRESET_FULL_RECT)
    shade.modulate.a = 0.0
    layer.add_child(shade)
    var p := panel()
    p.theme = make_theme()
    p.add_theme_stylebox_override("panel", gilded_style())
    p.custom_minimum_size = Vector2(660, 360)
    p.set_anchors_preset(Control.PRESET_CENTER)
    p.position = Vector2(-330, -180)
    layer.add_child(p)
    var v := vbox(16)
    p.add_child(v)
    v.add_child(title(title_text, 32))
    v.add_child(divider(0.35, 1.0))
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
    pop_in(p)
    layer.create_tween().tween_property(shade, "modulate:a", 1.0, 0.18)


## 淡入：用于界面切换与列表条目。
static func fade_in(node: Control, dur: float = 0.28, delay: float = 0.0) -> void:
    if node == null or not is_instance_valid(node):
        return
    node.modulate.a = 0.0
    var tw := node.create_tween()
    if delay > 0.0:
        tw.tween_interval(delay)
    tw.tween_property(node, "modulate:a", 1.0, dur).set_trans(Tween.TRANS_SINE)


## 弹入：用于弹窗与结算面板。
static func pop_in(node: Control, dur: float = 0.26) -> void:
    if node == null or not is_instance_valid(node):
        return
    var sz := node.size
    if sz.x <= 0.0 or sz.y <= 0.0:
        sz = node.custom_minimum_size
    node.pivot_offset = sz * 0.5
    node.scale = Vector2(0.92, 0.92)
    node.modulate.a = 0.0
    var tw := node.create_tween().set_parallel(true)
    tw.tween_property(node, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tw.tween_property(node, "modulate:a", 1.0, dur * 0.8)


## 挨打抖动。
static func shake(node: Control, strength: float = 0.055) -> void:
    if node == null or not is_instance_valid(node):
        return
    node.pivot_offset = node.size * 0.5
    var tw := node.create_tween()
    tw.tween_property(node, "rotation", strength, 0.05)
    tw.tween_property(node, "rotation", -strength, 0.07)
    tw.tween_property(node, "rotation", strength * 0.5, 0.06)
    tw.tween_property(node, "rotation", 0.0, 0.05)


## 飘字：伤害/治疗数字。
static func float_text(parent: Control, text: String, anchor: Control, color: Color = RED) -> void:
    if parent == null or anchor == null or not is_instance_valid(parent):
        return
    if not is_instance_valid(anchor):
        return
    var l := label(text, 32, color, HORIZONTAL_ALIGNMENT_CENTER)
    l.add_theme_constant_override("outline_size", 8)
    l.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.05, 0.9))
    var center := parent.get_global_transform().affine_inverse() * anchor.get_global_rect().get_center()
    l.size = Vector2(200, 48)
    l.position = center - Vector2(100, 24)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(l)
    var tw := l.create_tween().set_parallel(true)
    tw.tween_property(l, "position:y", l.position.y - 64, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tw.tween_property(l, "modulate:a", 0.0, 0.85).set_delay(0.3)
    tw.chain().tween_callback(l.queue_free)


static func fmt(v: int) -> String:
    return Cards.fmt_t(v)
