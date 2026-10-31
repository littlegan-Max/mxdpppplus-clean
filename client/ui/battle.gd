extends Control

## Battle screen. Works in two modes:
## - online: server-authoritative; sends "battle_choose" and receives turn/reveal.
## - local: runs BattleEngine in-process vs one AI (cheat mode lets AI peek at your card).

var mode := "online"
var you_pid := 0
var engine: BattleEngine = null
var players: Array = []
var legal: Array = []
var costs: Dictionary = {}
var targets: Dictionary = {}
var forced := ""
var silenced := false
var can_borrow := false
var round_no := 1
var turn_time := 10
var turn_deadline := 0.0
var turn_active := false
var submitted := false
var selected_card := ""
var selected_targets: Array = []
var cheat_mode := false
var _local_busy := false
var _card_filter := -1

var round_label: Label
var timer_label: Label
var hint_label: Label
var players_row: HBoxContainer
var log_label: RichTextLabel
var card_grid: GridContainer
var card_scroll: ScrollContainer
var detail_box: VBoxContainer
var play_button: Button
var card_area_panel: PanelContainer
var detail_panel: PanelContainer
var reveal_layer: CanvasLayer = null
var end_layer: CanvasLayer = null
var _card_buttons: Dictionary = {}
var _slot_buttons: Array = []
var _log_lines := 0


func _ready() -> void:
    UIKit.bg(self, "bg_battle.png")
    UIKit.dim(self, 0.25)
    _build_ui()
    mode = App.battle_mode
    _update_log_header()
    if mode == "local":
        engine = App.local_engine
        you_pid = 0
        cheat_mode = App.local_cheat
        turn_time = int(engine.config.get("turn_time", 10))
        _local_begin_round()
    else:
        var start: Dictionary = App.pending_battle_start
        if start.is_empty():
            toast("对局数据缺失")
            return
        you_pid = int(start.get("you_pid", 0))
        cheat_mode = bool(start.get("config", {}).get("cheat_mode", false))
        turn_time = int(start.get("turn_time", 10))
        var st: Dictionary = start.get("state", {})
        players = st.get("players", [])
        round_no = int(start.get("round", 1))
        _apply_turn(_as_turn(start.get("turn", {}), players, round_no, turn_time))
        if not App.battle_turn.is_empty():
            _apply_turn(App.battle_turn)
        _update_log_header()


func _as_turn(payload: Dictionary, p_players: Array, p_round: int, p_time: int) -> Dictionary:
    var out := payload.duplicate(true)
    out["players"] = p_players
    out["round"] = p_round
    out["turn_time"] = p_time
    return out


func _build_ui() -> void:
    var margin := MarginContainer.new()
    margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 22)
    margin.add_theme_constant_override("margin_right", 22)
    margin.add_theme_constant_override("margin_top", 14)
    margin.add_theme_constant_override("margin_bottom", 14)
    add_child(margin)
    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 10)
    margin.add_child(root)

    var top := PanelContainer.new()
    top.add_theme_stylebox_override("panel", UIKit.make_style("panel_dark.png", 8, 12))
    top.custom_minimum_size = Vector2(0, 66)
    root.add_child(top)
    var top_h := HBoxContainer.new()
    top_h.add_theme_constant_override("separation", 18)
    top.add_child(top_h)
    round_label = UIKit.label("第 1 回合", 26, UIKit.GOLD)
    top_h.add_child(round_label)
    var team_a := UIKit.label("A 队", 22, UIKit.CYAN)
    var team_b := UIKit.label("B 队", 22, UIKit.RED)
    top_h.add_child(team_a)
    top_h.add_child(team_b)
    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top_h.add_child(spacer)
    if cheat_mode:
        top_h.add_child(UIKit.label("变态模式：AI 透视你的牌", 18, UIKit.RED))
    timer_label = UIKit.label("⏱ 10.0", 28, UIKit.GOLD)
    timer_label.custom_minimum_size = Vector2(140, 0)
    timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    top_h.add_child(timer_label)
    var leave := UIKit.small_button("退出", 110, 48, 18)
    leave.pressed.connect(_on_leave)
    top_h.add_child(leave)

    players_row = HBoxContainer.new()
    players_row.add_theme_constant_override("separation", 8)
    players_row.custom_minimum_size = Vector2(0, 190)
    root.add_child(players_row)

    var middle := PanelContainer.new()
    middle.custom_minimum_size = Vector2(0, 142)
    middle.add_theme_stylebox_override("panel", UIKit.make_style("panel_dark.png", 8, 10))
    root.add_child(middle)
    var mid_h := HBoxContainer.new()
    mid_h.add_theme_constant_override("separation", 12)
    middle.add_child(mid_h)
    var log_head := VBoxContainer.new()
    log_head.custom_minimum_size = Vector2(232, 0)
    log_head.add_child(UIKit.label("战 况", 22, UIKit.GOLD))
    hint_label = UIKit.label("选择技能 → 选择目标 → 出牌", 15, UIKit.DIM)
    hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    log_head.add_child(hint_label)
    mid_h.add_child(log_head)
    log_label = RichTextLabel.new()
    log_label.bbcode_enabled = true
    log_label.scroll_active = true
    log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
    log_label.add_theme_font_size_override("normal_font_size", 17)
    log_label.add_theme_color_override("default_color", UIKit.DIM)
    mid_h.add_child(log_label)

    var bottom := HBoxContainer.new()
    bottom.add_theme_constant_override("separation", 12)
    bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(bottom)

    card_area_panel = PanelContainer.new()
    card_area_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card_area_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    card_area_panel.add_theme_stylebox_override("panel", UIKit.make_style("panel_dark.png", 8, 8))
    bottom.add_child(card_area_panel)
    var cards_v := VBoxContainer.new()
    cards_v.add_theme_constant_override("separation", 6)
    card_area_panel.add_child(cards_v)
    var filter_h := HBoxContainer.new()
    filter_h.add_theme_constant_override("separation", 10)
    cards_v.add_child(filter_h)
    filter_h.add_child(UIKit.label("技能库", 20, UIKit.GOLD))
    var filter := OptionButton.new()
    filter.add_item("全部")
    filter.add_item("攻击")
    filter.add_item("防御")
    filter.add_item("增益")
    filter.add_item("控制")
    filter.add_item("复活")
    filter.add_item("代码杀")
    filter.add_item("特殊")
    filter.custom_minimum_size = Vector2(150, 44)
    filter.item_selected.connect(func(idx):
        _card_filter = idx - 1
        _build_cards())
    filter_h.add_child(filter)
    var filter_sp := Control.new()
    filter_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    filter_h.add_child(filter_sp)
    filter_h.add_child(UIKit.label("不可用技能灰显；出牌合法性由程序禁止", 15, UIKit.GREY))
    card_scroll = ScrollContainer.new()
    card_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    cards_v.add_child(card_scroll)
    card_grid = GridContainer.new()
    card_grid.columns = 6
    card_grid.add_theme_constant_override("h_separation", 8)
    card_grid.add_theme_constant_override("v_separation", 8)
    card_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card_scroll.add_child(card_grid)

    detail_panel = PanelContainer.new()
    detail_panel.custom_minimum_size = Vector2(540, 0)
    detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    bottom.add_child(detail_panel)
    detail_box = VBoxContainer.new()
    detail_box.add_theme_constant_override("separation", 10)
    detail_panel.add_child(detail_box)
    detail_box.add_child(UIKit.label("技能详情", 20, UIKit.GOLD))
    var detail_scroll := ScrollContainer.new()
    detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    detail_box.add_child(detail_scroll)
    _detail_content = VBoxContainer.new()
    _detail_content.add_theme_constant_override("separation", 8)
    _detail_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    detail_scroll.add_child(_detail_content)
    play_button = UIKit.button("出 牌", 300, 72, 30)
    play_button.pressed.connect(_on_play)
    detail_box.add_child(play_button)

    _build_cards()
    _update_detail()


var _detail_content: VBoxContainer


func _build_cards() -> void:
    if card_grid == null:
        return
    for c in card_grid.get_children():
        c.queue_free()
    _card_buttons.clear()
    var kinds := {
        0: ["attack"], 1: ["defense"], 2: ["buff"], 3: ["control", "dot"],
        4: ["revive"], 5: ["code"], 6: ["special"],
    }
    var allowed: Array = []
    if _card_filter < 0:
        allowed = ["attack", "defense", "buff", "control", "dot", "revive", "code", "special"]
    else:
        allowed = kinds.get(_card_filter, [])
    for id in Cards.all().keys():
        var card := Cards.get_card(str(id))
        if not allowed.has(str(card.get("kind", ""))):
            continue
        var b := _make_card_button(str(id), card)
        card_grid.add_child(b)
        _card_buttons[str(id)] = b
    _refresh_cards()


func _make_card_button(id: String, card: Dictionary) -> Button:
    var b := Button.new()
    b.clip_contents = true
    b.custom_minimum_size = Vector2(190, 118)
    b.focus_mode = Control.FOCUS_NONE
    b.add_theme_stylebox_override("normal", UIKit.make_style("card.png", 8, 8))
    b.add_theme_stylebox_override("hover", UIKit.make_style("card_sel.png", 8, 8))
    b.add_theme_stylebox_override("pressed", UIKit.make_style("card_sel.png", 8, 8))
    b.add_theme_stylebox_override("disabled", UIKit.make_style("card_disabled.png", 8, 8))
    b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    b.tooltip_text = "%s\n费用：%s\n%s" % [card.get("name", ""), Cards.cost_label(card), card.get("desc", "")]
    b.pressed.connect(func(): _select_card(id))
    var m := MarginContainer.new()
    m.set_anchors_preset(Control.PRESET_FULL_RECT)
    m.add_theme_constant_override("margin_left", 10)
    m.add_theme_constant_override("margin_right", 8)
    m.add_theme_constant_override("margin_top", 8)
    m.add_theme_constant_override("margin_bottom", 8)
    m.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_child(m)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 2)
    v.mouse_filter = Control.MOUSE_FILTER_IGNORE
    m.add_child(v)
    var name_l := UIKit.label(str(card.get("name", "")), 20, UIKit.WHITE)
    name_l.max_lines_visible = 1
    name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    v.add_child(name_l)
    var cost_h := HBoxContainer.new()
    cost_h.add_theme_constant_override("separation", 3)
    cost_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var luck_icon := UIKit.icon("luck", 18)
    cost_h.add_child(luck_icon)
    var cost_l := UIKit.label(Cards.cost_label(card), 17, UIKit.GOLD)
    cost_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    cost_h.add_child(cost_l)
    if int(card.get("damage_t", 0)) > 0:
        cost_h.add_child(UIKit.label("⚔%s" % Cards.fmt_t(int(card.get("damage_t", 0))), 16, UIKit.RED))
    v.add_child(cost_h)
    var desc_l := UIKit.label(str(card.get("desc", "")), 14, UIKit.DIM)
    desc_l.max_lines_visible = 2
    desc_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    desc_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    desc_l.size_flags_vertical = Control.SIZE_EXPAND_FILL
    v.add_child(desc_l)
    return b


func _refresh_cards() -> void:
    for id in _card_buttons.keys():
        var b: Button = _card_buttons[id]
        var is_legal := legal.has(id) and turn_active and not submitted
        b.disabled = not is_legal
        b.modulate = Color(1.0, 1.0, 1.0) if is_legal else Color(0.55, 0.5, 0.62, 1.0)
        if is_legal:
            if selected_card == id:
                b.add_theme_stylebox_override("normal", UIKit.make_style("card_sel.png", 8, 8))
            else:
                b.add_theme_stylebox_override("normal", UIKit.make_style("card.png", 8, 8))
        if selected_card == id and is_legal:
            b.add_theme_stylebox_override("normal", UIKit.make_style("card_sel.png", 8, 8))


func _rebuild_players() -> void:
    if players_row == null:
        return
    for c in players_row.get_children():
        c.queue_free()
    _slot_buttons.clear()
    for pl in players:
        var pid := int(pl.get("pid", 0))
        var team := int(pl.get("team", 0))
        var b := Button.new()
        b.clip_contents = true
        b.custom_minimum_size = Vector2(0, 180)
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        b.focus_mode = Control.FOCUS_NONE
        var team_style := "panel_cyan.png" if team == 0 else "panel_red.png"
        var is_targeted := selected_targets.has(pid)
        var style_path := "panel.png" if is_targeted else team_style
        b.add_theme_stylebox_override("normal", UIKit.make_style(style_path, 8, 10))
        b.add_theme_stylebox_override("hover", UIKit.make_style(style_path, 8, 10))
        b.add_theme_stylebox_override("pressed", UIKit.make_style(style_path, 8, 10))
        b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
        if not bool(pl.get("alive", true)):
            b.modulate = Color(0.55, 0.5, 0.6, 0.8)
        b.pressed.connect(func(): _on_player_slot(pid))
        var m := MarginContainer.new()
        m.set_anchors_preset(Control.PRESET_FULL_RECT)
        m.add_theme_constant_override("margin_left", 8)
        m.add_theme_constant_override("margin_right", 8)
        m.add_theme_constant_override("margin_top", 6)
        m.add_theme_constant_override("margin_bottom", 6)
        m.mouse_filter = Control.MOUSE_FILTER_IGNORE
        b.add_child(m)
        var v := VBoxContainer.new()
        v.add_theme_constant_override("separation", 2)
        v.mouse_filter = Control.MOUSE_FILTER_IGNORE
        m.add_child(v)
        var head := HBoxContainer.new()
        head.add_theme_constant_override("separation", 6)
        head.mouse_filter = Control.MOUSE_FILTER_IGNORE
        head.add_child(UIKit.avatar(int(pl.get("avatar", 0)), 58))
        var nm := UIKit.label(str(pl.get("name", "?")), 18, UIKit.WHITE)
        nm.max_lines_visible = 1
        nm.clip_text = true
        nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
        head.add_child(nm)
        if pid == you_pid:
            head.add_child(UIKit.label("你", 16, UIKit.GOLD))
        v.add_child(head)
        var hp_row := HBoxContainer.new()
        hp_row.add_theme_constant_override("separation", 6)
        hp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
        hp_row.add_child(UIKit.icon("heart", 20))
        hp_row.add_child(UIKit.label(Cards.fmt_t(int(pl.get("hp_t", 0))), 20, UIKit.RED))
        hp_row.add_child(UIKit.icon("luck", 20))
        hp_row.add_child(UIKit.label(Cards.fmt_t(int(pl.get("luck_t", 0))), 20, UIKit.GOLD))
        hp_row.add_child(UIKit.icon("shield", 20))
        hp_row.add_child(UIKit.label(str(pl.get("shield", 0)), 20, UIKit.BLUE))
        v.add_child(hp_row)
        var state_l := UIKit.label("", 14, UIKit.DIM)
        state_l.max_lines_visible = 2
        state_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        state_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
        if not bool(pl.get("alive", true)):
            state_l.text = "阵亡"
            state_l.add_theme_color_override("font_color", UIKit.GREY)
        else:
            var bits: Array = []
            var sts: Array = pl.get("statuses", [])
            if not sts.is_empty():
                bits.append("异常 %d" % sts.size())
            if int(pl.get("shield", 0)) > 0:
                bits.append("盾%d" % int(pl.get("shield", 0)))
            if bool(pl.get("cost_half", false)):
                bits.append("葵花")
            if str(pl.get("last_card", "")) != "":
                var lc := Cards.get_card(str(pl.get("last_card", "")))
                bits.append("上回合：" + str(lc.get("name", "")))
            state_l.text = " · ".join(bits)
        v.add_child(state_l)
        if is_targeted:
            var tl := UIKit.label("◈ 当前目标", 14, UIKit.GOLD)
            tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
            v.add_child(tl)
        players_row.add_child(b)
        _slot_buttons.append(b)
    _refresh_cards()


func _apply_turn(payload: Dictionary) -> void:
    if payload.is_empty():
        return
    players = payload.get("players", players)
    legal = payload.get("legal", [])
    costs = _int_dict(payload.get("costs", {}))
    targets = _int_targets(payload.get("targets", {}))
    silenced = bool(payload.get("silenced", false))
    forced = str(payload.get("forced", ""))
    can_borrow = bool(payload.get("can_borrow", false))
    round_no = int(payload.get("round", round_no))
    turn_time = int(payload.get("turn_time", turn_time))
    selected_card = ""
    selected_targets = []
    submitted = false
    turn_active = true
    turn_deadline = Time.get_ticks_msec() + turn_time * 1000
    _append_events(payload.get("events", []), true)
    round_label.text = "第 %d 回合" % round_no
    _hint_for_turn()
    _rebuild_players()
    _build_cards()
    _update_detail()
    if mode == "local":
        pass


func _int_dict(raw: Dictionary) -> Dictionary:
    var out := {}
    for k in raw.keys():
        out[str(k)] = int(raw[k])
    return out


func _int_targets(raw: Dictionary) -> Dictionary:
    var out := {}
    for k in raw.keys():
        var arr: Array = []
        var v = raw[k]
        if v is Array:
            for t in v:
                arr.append(int(t))
        out[str(k)] = arr
    return out


func _hint_for_turn() -> void:
    if silenced:
        hint_label.text = "你被鄙视：本回合空过"
    elif forced != "":
        hint_label.text = "被强制出「%s」" % Cards.get_card(forced).get("name", "")
    elif not bool(_player(you_pid).get("alive", true)):
        hint_label.text = "你已阵亡，观战中"
    elif legal.is_empty():
        hint_label.text = "本回合无合法技能，将空过"
    else:
        hint_label.text = "选择技能 → 选择目标 → 出牌"


func _player(pid: int) -> Dictionary:
    for pl in players:
        if int(pl.get("pid", 0)) == pid:
            return pl
    return {}


func _select_card(id: String) -> void:
    if not turn_active or submitted:
        return
    if not legal.has(id):
        toast("该技能当前不可用")
        return
    selected_card = id
    selected_targets = []
    var card := Cards.get_card(id)
    var tlist: Array = targets.get(id, [])
    var ttype := str(card.get("target", "enemy"))
    if ttype == "self":
        selected_targets = [you_pid]
    elif ttype == "all_enemies":
        selected_targets = tlist.duplicate()
    elif not tlist.is_empty():
        var first := int(tlist[0])
        if id == "shield" or id == "peach":
            first = you_pid if tlist.has(you_pid) else first
        elif id == "raiden":
            for t in tlist:
                if int(t) != you_pid:
                    first = int(t)
                    break
        selected_targets = [first]
    _rebuild_players()
    _refresh_cards()
    _update_detail()


func _on_player_slot(pid: int) -> void:
    if not turn_active or submitted or selected_card == "":
        return
    var card := Cards.get_card(selected_card)
    var tlist: Array = targets.get(selected_card, [])
    if not tlist.has(pid):
        toast("该目标不合法")
        return
    if str(card.get("target", "")) == "enemies2":
        if selected_targets.has(pid):
            if selected_targets.size() > 1:
                selected_targets.erase(pid)
        else:
            if selected_targets.size() >= 2:
                selected_targets = [selected_targets[1], pid]
            else:
                selected_targets.append(pid)
    else:
        selected_targets = [pid]
    _rebuild_players()
    _update_detail()


func _update_detail() -> void:
    if _detail_content == null:
        return
    for c in _detail_content.get_children():
        c.queue_free()
    if selected_card == "":
        _detail_content.add_child(UIKit.label("从左侧技能库选择一张牌。\n\n合法牌会亮起；费用不足、冷却中、连招未满足的牌会灰显。", 18, UIKit.DIM))
        play_button.disabled = true
        return
    var card := Cards.get_card(selected_card)
    var name_l := UIKit.label(str(card.get("name", "")), 30, UIKit.GOLD)
    _detail_content.add_child(name_l)
    var cost := int(costs.get(selected_card, card.get("cost_t", 0)))
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    row.add_child(UIKit.label("费用 %s" % Cards.fmt_t(cost), 20, UIKit.GOLD))
    if int(card.get("damage_t", 0)) > 0:
        row.add_child(UIKit.label("伤害 %s" % Cards.fmt_t(int(card.get("damage_t", 0))), 20, UIKit.RED))
    if int(card.get("true_t", 0)) > 0:
        row.add_child(UIKit.label("真伤 %s" % Cards.fmt_t(int(card.get("true_t", 0))), 18, UIKit.RED))
    row.add_child(UIKit.label(str(card.get("kind", "")), 18, UIKit.CYAN))
    _detail_content.add_child(row)
    var desc := UIKit.label(str(card.get("desc", "")), 19, UIKit.WHITE)
    desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _detail_content.add_child(desc)
    if str(card.get("note", "")) != "":
        _detail_content.add_child(UIKit.label("备注：" + str(card.get("note", "")), 17, UIKit.DIM))
    var bb: Array = card.get("block_by", [])
    if not bb.is_empty():
        _detail_content.add_child(UIKit.label("可被：" + "、".join(bb), 17, UIKit.CYAN))
    var req: Array = card.get("requires", [])
    if not req.is_empty():
        var names: Array = []
        for rid in req:
            names.append(str(Cards.get_card(str(rid)).get("name", rid)))
        _detail_content.add_child(UIKit.label("连招：" + " → ".join(names), 17, UIKit.DIM))
    if not selected_targets.is_empty():
        var names2: Array = []
        for t in selected_targets:
            names2.append(str(_player(int(t)).get("name", "?")))
        _detail_content.add_child(UIKit.label("目标：" + "、".join(names2), 20, UIKit.GOLD))
    else:
        _detail_content.add_child(UIKit.label("目标：点击上方玩家选择", 18, UIKit.DIM))
    if forced != "":
        _detail_content.add_child(UIKit.label("本回合被强制：%s" % Cards.get_card(forced).get("name", ""), 17, UIKit.RED))
    play_button.disabled = not turn_active or submitted or selected_card == ""


func _on_play() -> void:
    if not turn_active or submitted:
        return
    if selected_card == "":
        toast("先选一张技能")
        return
    var card := Cards.get_card(selected_card)
    var tlist := selected_targets.duplicate()
    var ttype := str(card.get("target", "enemy"))
    if ttype == "all_enemies":
        tlist = targets.get(selected_card, [])
    if ttype == "self":
        tlist = [you_pid]
    if tlist.is_empty() and ttype not in ["self", "all_enemies"]:
        toast("请选择目标")
        return
    if ttype == "multi" and tlist.is_empty():
        toast("请选择目标")
        return
    if mode == "online":
        App.send({"t": "battle_choose", "card": selected_card,
                  "target": int(tlist[0]) if not tlist.is_empty() else -1,
                  "targets": tlist})
        submitted = true
        turn_active = false
        hint_label.text = "已出牌，等待其他玩家…"
        _update_detail()
        _refresh_cards()
    else:
        _local_play(false, tlist)


func _local_begin_round() -> void:
    if engine == null or engine.finished:
        return
    engine.auto_pass_silenced()
    var payload := engine.legal_payload(0)
    payload["players"] = engine.public_state()["players"]
    payload["round"] = engine.round_no
    payload["turn_time"] = int(engine.config.get("turn_time", 10))
    _apply_turn(payload)


func _local_play(auto: bool, tlist: Array = []) -> void:
    if _local_busy or engine == null or engine.finished:
        return
    if not turn_active:
        return
    _local_busy = true
    turn_active = false
    submitted = true
    var manual_card := ""
    if not auto:
        manual_card = selected_card
        var res := engine.submit(0, selected_card, int(tlist[0]) if not tlist.is_empty() else -1, tlist)
        if not bool(res.get("ok", false)):
            toast(str(res.get("reason", "出牌不合法")))
            _local_busy = false
            turn_active = true
            submitted = false
            return
    else:
        if engine.needs_choice(0) and not engine.choices.has(0):
            var c := engine.ai_choose(0, {})
            if bool(c.get("ok", false)):
                engine.submit(0, str(c["card"]), int(c.get("target", -1)), c.get("targets", []))
            else:
                var lg := engine.legal_cards(0)
                if lg.is_empty():
                    engine.submit(0, "")
                else:
                    var ts := engine.valid_targets(0, str(lg[0]))
                    engine.submit(0, str(lg[0]), int(ts[0]) if ts.size() > 0 else -1, ts)
    var peek := {}
    if App.local_cheat and manual_card != "":
        peek = {"card": manual_card, "from": 0, "target": int(tlist[0]) if not tlist.is_empty() else -1}
    if engine.needs_choice(App.local_ai_pid) and not engine.choices.has(App.local_ai_pid):
        var ai := engine.ai_choose(App.local_ai_pid, peek)
        if bool(ai.get("ok", false)):
            engine.submit(App.local_ai_pid, str(ai["card"]), int(ai.get("target", -1)), ai.get("targets", []))
        else:
            var lg2 := engine.legal_cards(App.local_ai_pid)
            if lg2.is_empty():
                engine.submit(App.local_ai_pid, "")
            else:
                var ts2 := engine.valid_targets(App.local_ai_pid, str(lg2[0]))
                engine.submit(App.local_ai_pid, str(lg2[0]), int(ts2[0]) if ts2.size() > 0 else -1, ts2)
    var result := engine.resolve_round()
    _on_reveal(result)
    _local_after_reveal(result)


func _local_after_reveal(result: Dictionary) -> void:
    _local_busy = true
    await get_tree().create_timer(2.4).timeout
    _absorb_local_memory()
    if bool(result.get("finished", false)):
        _local_busy = false
        return
    var adv := engine.advance_round()
    if bool(adv.get("finished", false)):
        _local_busy = false
        return
    _apply_turn_adv(adv)
    _local_busy = false


func _absorb_local_memory() -> void:
    if engine == null:
        return
    var obs := engine.take_observations()
    if obs.is_empty():
        return
    AiMemory.absorb(obs)
    AiMemory.flush()
    engine.config["ai_bias"] = AiMemory.snapshot()


func _apply_turn_adv(adv: Dictionary) -> void:
    var payload := engine.legal_payload(0)
    payload["players"] = adv.get("players", engine.public_state()["players"])
    payload["round"] = adv.get("round", engine.round_no)
    payload["events"] = adv.get("events", [])
    payload["turn_time"] = int(engine.config.get("turn_time", 10))
    _apply_turn(payload)


func _process(_delta: float) -> void:
    if not turn_active:
        if submitted:
            timer_label.text = "已出牌"
        return
    if turn_time <= 0:
        timer_label.text = "⏱ 不限时"
        return
    var left := (turn_deadline - Time.get_ticks_msec()) / 1000.0
    timer_label.text = "⏱ %.1f" % maxf(0.0, left)
    if left <= 0.0:
        timer_label.text = "结算中…"
        if mode == "local" and not _local_busy:
            _local_play(true)


func on_turn(data: Dictionary) -> void:
    _apply_turn(data)


func on_ack(_data: Dictionary) -> void:
    submitted = true
    turn_active = false
    hint_label.text = "已出牌，等待其他玩家…"
    _update_detail()
    _refresh_cards()


func on_error(msg: String) -> void:
    if mode == "online":
        submitted = false
        turn_active = true
        _update_detail()
        _refresh_cards()
        toast(msg)


func on_players(data: Dictionary) -> void:
    var p: Array = data.get("players", [])
    if not p.is_empty():
        _apply_players_only(p)


func on_reveal(data: Dictionary) -> void:
    _on_reveal(data)


func on_battle_end(data: Dictionary) -> void:
    _show_end(data)


func _on_reveal(result: Dictionary) -> void:
    turn_active = false
    submitted = true
    selected_targets = []
    _refresh_cards()
    _update_detail()
    _apply_players_only(result.get("players", players))
    round_label.text = "第 %d 回合 · 结算" % int(result.get("round", round_no))
    _append_events(result.get("events", []), false)
    _show_reveal_modal(result)
    if bool(result.get("finished", false)):
        var end_data := {"winner_team": int(result.get("winner_team", -1)),
                         "players": result.get("players", players)}
        _show_end(end_data)


func _apply_players_only(p: Array) -> void:
    if p.is_empty():
        return
    players = p
    _rebuild_players()


func _show_reveal_modal(result: Dictionary) -> void:
    if reveal_layer != null and is_instance_valid(reveal_layer):
        reveal_layer.queue_free()
    reveal_layer = CanvasLayer.new()
    reveal_layer.layer = 80
    add_child(reveal_layer)
    var shade := ColorRect.new()
    shade.color = Color(0.02, 0.01, 0.05, 0.55)
    shade.set_anchors_preset(Control.PRESET_FULL_RECT)
    reveal_layer.add_child(shade)
    var p := UIKit.panel()
    p.theme = UIKit.make_theme()
    p.custom_minimum_size = Vector2(1080, 560)
    p.set_anchors_preset(Control.PRESET_CENTER)
    p.position = Vector2(-540, -280)
    reveal_layer.add_child(p)
    var v := UIKit.vbox(10)
    p.add_child(v)
    v.add_child(UIKit.title("第 %d 回合结算" % int(result.get("round", round_no)), 36))
    var choices: Array = result.get("choices", [])
    var ch_h := HBoxContainer.new()
    ch_h.add_theme_constant_override("separation", 8)
    for c in choices:
        var pl := _player(int(c.get("pid", 0)))
        var card_id := str(c.get("effective_card", ""))
        var shown := card_id if card_id != "" else str(c.get("card", ""))
        var nm := "空过" if bool(c.get("pass", false)) or shown == "" else str(Cards.get_card(shown).get("name", shown))
        var chip := UIKit.panel("panel_cyan.png" if int(pl.get("team", 0)) == 0 else "panel_red.png")
        chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var cv := UIKit.vbox(2)
        chip.add_child(cv)
        cv.add_child(UIKit.label(str(pl.get("name", "?")), 16, UIKit.WHITE))
        cv.add_child(UIKit.label(nm, 22, UIKit.GOLD))
        ch_h.add_child(chip)
    v.add_child(ch_h)
    var log := RichTextLabel.new()
    log.bbcode_enabled = true
    log.size_flags_vertical = Control.SIZE_EXPAND_FILL
    log.add_theme_font_size_override("normal_font_size", 18)
    log.add_theme_color_override("default_color", UIKit.WHITE)
    var lines: Array = []
    for e in result.get("events", []):
        lines.append(_color_event(e))
    log.text = "\n".join(lines)
    v.add_child(log)
    var close := UIKit.button("继续", 240, 56, 22)
    close.pressed.connect(func():
        if reveal_layer != null and is_instance_valid(reveal_layer):
            reveal_layer.queue_free())
    v.add_child(close)
    var auto := get_tree().create_timer(2.1)
    auto.timeout.connect(func():
        if reveal_layer != null and is_instance_valid(reveal_layer):
            reveal_layer.queue_free())


func _append_events(events: Array, with_header: bool) -> void:
    if events.is_empty():
        return
    if with_header:
        log_label.append_text("\n[color=#8f86a8]— 第 %d 回合 —[/color]\n" % round_no)
    for e in events:
        log_label.append_text(_color_event(e) + "\n")
    _log_lines += events.size() + 1
    if _log_lines > 200:
        log_label.text = log_label.text.substr(maxi(0, log_label.text.length() - 6000))
    await get_tree().process_frame
    log_label.scroll_to_line(maxi(0, log_label.get_line_count() - 1))


func _color_event(e: Dictionary) -> String:
    var txt := str(e.get("text", ""))
    var t := str(e.get("t", ""))
    var col := "#b9a8d8"
    match t:
        "damage": col = "#ff5a6e"
        "heal": col = "#7cf6c9"
        "luck", "steal_luck": col = "#ffcc4d"
        "shield", "shield_block", "shield_clear": col = "#5bb8ff"
        "death", "died": col = "#ff5a6e"
        "revive": col = "#7cf6c9"
        "silence", "force": col = "#ff9ab5"
        "compare", "block": col = "#b9a8ff"
        "rewind": col = "#5bb8ff"
        "winner": col = "#ffcc4d"
    return "[color=%s]%s[/color]" % [col, txt]


func _update_log_header() -> void:
    log_label.append_text("[color=#8f86a8]对局开始：开局 0 运 1 血；第一回合只能出「运」。[/color]\n")


func _on_leave() -> void:
    UIKit.confirm(self, "离开对局", "确定离开当前对局？联机模式下离开后角色将由 AI 接管。",
        func():
            if mode == "online":
                App.leave_to_menu()
            else:
                App.local_engine = null
                App.goto("menu"))


func _show_end(data: Dictionary) -> void:
    if end_layer != null and is_instance_valid(end_layer):
        end_layer.queue_free()
    if reveal_layer != null and is_instance_valid(reveal_layer):
        reveal_layer.queue_free()
    end_layer = CanvasLayer.new()
    end_layer.layer = 90
    add_child(end_layer)
    var shade := ColorRect.new()
    shade.color = Color(0.02, 0.01, 0.05, 0.82)
    shade.set_anchors_preset(Control.PRESET_FULL_RECT)
    end_layer.add_child(shade)
    var p := UIKit.panel()
    p.theme = UIKit.make_theme()
    p.custom_minimum_size = Vector2(760, 480)
    p.set_anchors_preset(Control.PRESET_CENTER)
    p.position = Vector2(-380, -240)
    end_layer.add_child(p)
    var v := UIKit.vbox(16)
    p.add_child(v)
    var winner := int(data.get("winner_team", -1))
    var title_text := "A 队胜利" if winner == 0 else ("B 队胜利" if winner == 1 else "对局结束")
    v.add_child(UIKit.title(title_text, 52, UIKit.GOLD))
    var my_team := 0
    var pl := _player(you_pid)
    if not pl.is_empty():
        my_team = int(pl.get("team", 0))
    if winner == my_team:
        v.add_child(UIKit.label("你所在的队伍获胜", 26, UIKit.CYAN, HORIZONTAL_ALIGNMENT_CENTER))
    else:
        v.add_child(UIKit.label("你所在的队伍失败", 26, UIKit.RED, HORIZONTAL_ALIGNMENT_CENTER))
    var grid := GridContainer.new()
    grid.columns = 4
    grid.add_theme_constant_override("h_separation", 12)
    grid.add_theme_constant_override("v_separation", 8)
    for pp in data.get("players", players):
        var chip := UIKit.panel("panel_cyan.png" if int(pp.get("team", 0)) == 0 else "panel_red.png")
        var cv := UIKit.vbox(2)
        chip.add_child(cv)
        cv.add_child(UIKit.label(str(pp.get("name", "?")), 16, UIKit.WHITE))
        cv.add_child(UIKit.label("血 %s · 运 %s · 盾 %d" %
            [Cards.fmt_t(int(pp.get("hp_t", 0))), Cards.fmt_t(int(pp.get("luck_t", 0))), int(pp.get("shield", 0))], 15, UIKit.DIM))
        grid.add_child(chip)
    v.add_child(grid)
    var h := HBoxContainer.new()
    h.alignment = BoxContainer.ALIGNMENT_CENTER
    h.add_theme_constant_override("separation", 16)
    if mode == "local":
        var again := UIKit.button("再来一局", 220, 62)
        again.pressed.connect(func(): App.start_single(App.local_cheat))
        h.add_child(again)
        var menu := UIKit.button("返回主菜单", 220, 62)
        menu.pressed.connect(func(): App.local_engine = null; App.goto("menu"))
        h.add_child(menu)
    else:
        var back := UIKit.button("返回房间", 220, 62)
        back.pressed.connect(func():
            if not App.room.is_empty():
                App.goto("room")
            else:
                App.goto("lobby"))
        h.add_child(back)
        var menu2 := UIKit.button("离开房间", 220, 62)
        menu2.pressed.connect(func(): App.leave_to_menu())
        h.add_child(menu2)
    v.add_child(h)


func toast(msg: String) -> void:
    UIKit.toast(self, msg)
