extends Control

var cheat_check: CheckBox


func _ready() -> void:
    UIKit.bg(self, "bg_room.png")
    UIKit.dim(self, 0.45)
    var center := CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(center)
    var panel := UIKit.panel()
    panel.custom_minimum_size = Vector2(900, 640)
    center.add_child(panel)
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 48)
    margin.add_theme_constant_override("margin_right", 48)
    margin.add_theme_constant_override("margin_top", 36)
    margin.add_theme_constant_override("margin_bottom", 36)
    panel.add_child(margin)
    var v := UIKit.vbox(18)
    margin.add_child(v)
    v.add_child(UIKit.title("单人模式 · 1v1 人机", 44))
    v.add_child(UIKit.label("开局 0 运 1 血；第一回合只能出「运」。\n每回合秘密选一张技能，同时翻开结算；血量 ≤0 即死。", 21, UIKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
    v.add_child(UIKit.label("AI 不靠训练，只用规则启发式：会看血量、费用、连招与可被列。\n它不会作弊，除非你打开下面的变态模式。", 18, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
    var rule_panel := UIKit.panel("panel_dark.png")
    rule_panel.custom_minimum_size = Vector2(0, 150)
    var rv := UIKit.vbox(6)
    rule_panel.add_child(rv)
    rv.add_child(UIKit.label("本局规则摘要", 20, UIKit.GOLD))
    rv.add_child(UIKit.label("• 伤害相同互相抵消，不同只有高者生效\n• 挡/吸/闪/盾/护身符按「可被」列结算\n• 首次盾 4 运，之后 3 运；盾自动挡致命伤", 17, UIKit.DIM))
    v.add_child(rule_panel)
    cheat_check = CheckBox.new()
    cheat_check.text = "变态模式：AI 可以看到你本回合出的牌"
    cheat_check.add_theme_font_size_override("font_size", 22)
    cheat_check.add_theme_color_override("font_color", UIKit.RED)
    v.add_child(cheat_check)
    v.add_child(UIKit.label("AI 只能看你（人类）的牌；单机只有 1 个 AI，所以等于完全透视。", 16, UIKit.GREY))
    var bh := UIKit.hbox(18)
    bh.alignment = BoxContainer.ALIGNMENT_CENTER
    var start := UIKit.button("开始对战", 300, 70, 28)
    start.pressed.connect(func(): App.start_single(cheat_check.button_pressed))
    var back := UIKit.button("返回", 220, 70, 24)
    back.pressed.connect(func(): App.goto("menu"))
    bh.add_child(start)
    bh.add_child(back)
    v.add_child(bh)


func toast(msg: String) -> void:
    UIKit.toast(self, msg)
