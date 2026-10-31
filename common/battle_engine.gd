class_name BattleEngine
extends RefCounted

## Authoritative rules engine, shared by the offline client and the dedicated server.
## All hp / luck / damage values are integer tenths (10 == 1.0).

const TEAM_A := 0
const TEAM_B := 1

var players: Array = []
var config: Dictionary = {}
var round_no := 1
var choices: Dictionary = {}
var finished := false
var winner_team := -1

var _rng := RandomNumberGenerator.new()


func setup(player_specs: Array, p_config: Dictionary = {}) -> void:
    players.clear()
    choices.clear()
    round_no = 1
    finished = false
    winner_team = -1
    _rng.seed = int(p_config.get("seed", Time.get_ticks_usec()))
    for i in player_specs.size():
        var src: Dictionary = player_specs[i]
        players.append({
            "pid": i,
            "name": str(src.get("name", "玩家%d" % (i + 1))),
            "team": int(src.get("team", i % 2)),
            "seat": i,
            "is_ai": bool(src.get("is_ai", false)),
            "avatar": int(src.get("avatar", i % 8)),
            "hp_t": 10,
            "luck_t": 0,
            "shield": 0,
            "alive": true,
            "death_round": 0,
            "death_cause": "",
            "death_hp_t": 0,
            "death_luck_t": 0,
            "death_shield": 0,
            "history": [],
            "cooldowns": {},
            "uses": {},
            "statuses": [],
            "buffs": [],
            "cost_half": false,
            "shield_casts": 0,
            "silenced_round": 0,
            "forced_round": 0,
            "forced_card": "",
            "revived_until": 0,
            "disconnected": false,
            "last_card": "",
            "last_target": -1,
        })
    config = {
        "friendly_fire": bool(p_config.get("friendly_fire", false)),
        "cheat_mode": bool(p_config.get("cheat_mode", false)),
        "turn_time": int(p_config.get("turn_time", 10)),
        "mode": str(p_config.get("mode", "single")),
    }


func _p(pid: int) -> Dictionary:
    return players[pid]


func is_alive(pid: int) -> bool:
    return pid >= 0 and pid < players.size() and bool(players[pid]["alive"])


func alive_pids() -> Array:
    var out: Array = []
    for pl in players:
        if pl["alive"]:
            out.append(int(pl["pid"]))
    return out


func alive_enemies(pid: int) -> Array:
    var out: Array = []
    var team := int(_p(pid)["team"])
    for pl in players:
        if pl["alive"] and int(pl["team"]) != team:
            out.append(int(pl["pid"]))
    return out


func allies(pid: int) -> Array:
    var out: Array = []
    var team := int(_p(pid)["team"])
    for pl in players:
        if pl["alive"] and int(pl["team"]) == team and int(pl["pid"]) != pid:
            out.append(int(pl["pid"]))
    return out


func dead_pids() -> Array:
    var out: Array = []
    for pl in players:
        if not pl["alive"]:
            out.append(int(pl["pid"]))
    return out


func team_alive(team: int) -> int:
    var n := 0
    for pl in players:
        if pl["alive"] and int(pl["team"]) == team:
            n += 1
    return n


func opponents_for_targeting(pid: int) -> Array:
    var out := alive_enemies(pid)
    if config.get("friendly_fire", false):
        out.append_array(allies(pid))
        out.sort()
    return out


func _has_buff(pl: Dictionary, kind: String) -> bool:
    for b in pl["buffs"]:
        if b.get("type", "") == kind:
            return true
    return false


func _get_buff(pl: Dictionary, kind: String) -> Dictionary:
    for b in pl["buffs"]:
        if b.get("type", "") == kind:
            return b
    return {}


func _add_buff(pl: Dictionary, data: Dictionary) -> void:
    pl["buffs"].append(data)


func _remove_buffs(pl: Dictionary, kind: String) -> bool:
    var removed := false
    var keep: Array = []
    for b in pl["buffs"]:
        if b.get("type", "") == kind:
            removed = true
        else:
            keep.append(b)
    pl["buffs"] = keep
    return removed


func _add_status(pl: Dictionary, data: Dictionary) -> void:
    pl["statuses"].append(data)


func _remove_statuses(pl: Dictionary, kinds: Array) -> bool:
    var removed := false
    var keep: Array = []
    for s in pl["statuses"]:
        if kinds.has(s.get("type", "")):
            removed = true
        else:
            keep.append(s)
    pl["statuses"] = keep
    return removed


func _history_matches(history: Array, seq: Array) -> bool:
    if seq.is_empty():
        return true
    if history.size() < seq.size():
        return false
    var start := history.size() - seq.size()
    for i in seq.size():
        if str(history[start + i]) != str(seq[i]):
            return false
    return true


func _can_borrow(pl: Dictionary) -> bool:
    if bool(pl["alive"]):
        return false
    if str(pl["death_cause"]) == "code":
        return false
    if int(pl["uses"].get("borrow_body", 0)) >= 1:
        return false
    var since: int = round_no - int(pl["death_round"])
    return since >= 0 and since <= 3


func _can_act(pl: Dictionary) -> bool:
    if bool(pl["alive"]):
        return true
    return _can_borrow(pl)


func _uses_left(pl: Dictionary, card: Dictionary) -> int:
    var cap := int(card.get("uses", 0))
    if cap <= 0:
        return 999
    return cap - int(pl["uses"].get(card["id"], 0))


func _cooldown_ok(pl: Dictionary, card: Dictionary) -> bool:
    if card.is_empty():
        return false
    if int(pl["cooldowns"].get(card["id"], 0)) > round_no:
        return false
    var group := str(card.get("cooldown_group", ""))
    if group != "":
        for other in Cards.all().values():
            if str(other.get("cooldown_group", "")) == group:
                if int(pl["cooldowns"].get(other["id"], 0)) > round_no:
                    return false
    return true


func effective_cost(pid: int, card_id: String) -> int:
    var pl := _p(pid)
    var card := Cards.get_card(card_id)
    if card.is_empty():
        return 99999
    var c := int(card["cost_t"])
    match card_id:
        "nuke":
            return mini(40, maxi(0, int(pl["luck_t"])))
        "shield":
            return 40 if int(pl["shield_casts"]) == 0 else 30
        "sweep_earth":
            return 10 * maxi(1, players.size())
        "peach_oath":
            return 10 * players.size()
    if card_id == "cannon" and _has_buff(pl, "rage"):
        c = 20
    if bool(pl["cost_half"]) and not ["nuke", "shield"].has(card_id):
        c = int(round(float(c) * 0.5))
    return maxi(0, c)


func _requirements_ok(pl: Dictionary, card: Dictionary) -> bool:
    var req: Array = card.get("requires", [])
    return _history_matches(pl["history"], req)


func _is_harmful(card: Dictionary) -> bool:
    var kind := str(card.get("kind", ""))
    if kind in ["attack", "dot", "code"]:
        return true
    if kind == "control":
        return str(card.get("id", "")) != "raiden"
    if kind == "special":
        return str(card.get("id", "")) in ["turtle", "god_turtle"]
    return false


func valid_targets(pid: int, card_id: String) -> Array:
    var card := Cards.get_card(card_id)
    if card.is_empty():
        return []
    var t := str(card.get("target", "enemy"))
    if t == "self":
        return [pid]
    if t == "dead":
        return dead_pids()
    if t == "all_enemies":
        return alive_enemies(pid)
    if t == "enemies2":
        return opponents_for_targeting(pid)
    if t == "any":
        return alive_pids()
    if t == "enemy":
        if _is_harmful(card) and not config.get("friendly_fire", false):
            return alive_enemies(pid)
        return alive_pids()
    return []


func _target_allowed(pid: int, card: Dictionary, tid: int) -> bool:
    if tid < 0 or tid >= players.size():
        return false
    var pl := _p(pid)
    var tp := _p(tid)
    var t := str(card.get("target", "enemy"))
    if t == "self":
        return tid == pid
    if t == "dead":
        return not bool(tp["alive"])
    if t == "all_enemies":
        return bool(tp["alive"]) and str(tp["team"]) != str(pl["team"])
    if t == "enemies2":
        return bool(tp["alive"]) and str(tp["team"]) != str(pl["team"])
    if t == "any":
        return bool(tp["alive"])
    if t == "enemy":
        if not bool(tp["alive"]):
            return false
        if _is_harmful(card) and tid == pid:
            return false
        if _is_harmful(card) and not config.get("friendly_fire", false):
            return str(tp["team"]) != str(pl["team"])
        return true
    return false


func can_use(pid: int, card_id: String, target: int = -1, targets: Array = []) -> Dictionary:
    var pl := _p(pid)
    if finished:
        return {"ok": false, "reason": "对局已结束"}
    if not _can_act(pl):
        return {"ok": false, "reason": "当前无法行动"}
    var card := Cards.get_card(card_id)
    if card.is_empty():
        return {"ok": false, "reason": "未知技能"}
    if int(pl["silenced_round"]) == round_no:
        return {"ok": false, "reason": "被鄙视，本回合不能出技能"}
    if round_no == 1 and card_id != "yun":
        return {"ok": false, "reason": "第一回合只能出「运」"}
    if int(pl["forced_round"]) == round_no and card_id != str(pl["forced_card"]):
        return {"ok": false, "reason": "本回合被强制出「%s」" % Cards.get_card(str(pl["forced_card"])).get("name", "")}
    if not _requirements_ok(pl, card):
        return {"ok": false, "reason": "连招未满足"}
    if not _cooldown_ok(pl, card):
        return {"ok": false, "reason": "技能冷却中"}
    if _uses_left(pl, card) <= 0:
        return {"ok": false, "reason": "本局使用次数已用尽"}
    if card.get("multi_only", false) and players.size() < 3:
        return {"ok": false, "reason": "仅限多人模式"}
    if not bool(pl["alive"]) and card_id != "borrow_body":
        return {"ok": false, "reason": "已死亡"}
    var cost := effective_cost(pid, card_id)
    if cost > 0 and int(pl["luck_t"]) < cost:
        return {"ok": false, "reason": "运不足（需要 %s）" % Cards.fmt_t(cost)}
    if card_id == "wine" and dead_pids().is_empty():
        return {"ok": false, "reason": "场上没有死者"}
    if card_id == "undead_return" and dead_pids().is_empty():
        return {"ok": false, "reason": "场上没有死者"}
    if card_id == "wine" and target >= 0 and is_alive(target):
        return {"ok": false, "reason": "酒只能对死者使用"}
    var tlist: Array = targets.duplicate()
    if tlist.is_empty() and target >= 0:
        tlist = [target]
    if str(card.get("target", "enemy")) == "self":
        tlist = [pid]
    elif str(card.get("target", "enemy")) == "all_enemies":
        tlist = valid_targets(pid, card_id)
    elif str(card.get("target", "enemy")) == "enemies2":
        if tlist.is_empty():
            tlist = [target] if target >= 0 else []
        if tlist.size() < 1 or tlist.size() > 2:
            return {"ok": false, "reason": "双镖需选择 1~2 名敌人"}
    if str(card.get("target", "enemy")) in ["enemy", "any", "dead"] and tlist.is_empty():
        return {"ok": false, "reason": "需要选择目标"}
    for tid in tlist:
        if not _target_allowed(pid, card, int(tid)):
            return {"ok": false, "reason": "目标不合法"}
    if _is_harmful(card):
        for tid in tlist:
            for b in pl["buffs"]:
                if b.get("type", "") == "unequal" and int(b.get("source", -1)) == int(tid):
                    return {"ok": false, "reason": "不平等条约：你不能对对方使用有害技能"}
            for b in pl["buffs"]:
                if b.get("type", "") == "undead" and int(b.get("caster", -1)) == int(tid):
                    return {"ok": false, "reason": "亡灵返乡：不能攻击复活你的人"}
    return {"ok": true, "reason": "", "targets": tlist, "cost": cost}


func submit(pid: int, card_id: String, target: int = -1, targets: Array = []) -> Dictionary:
    if pid < 0 or pid >= players.size():
        return {"ok": false, "reason": "无效玩家"}
    if card_id == "":
        if not needs_choice(pid):
            choices[pid] = {"pass": true, "card": "", "target": -1, "targets": []}
            return {"ok": true, "reason": ""}
        return {"ok": false, "reason": "本回合必须出牌"}
    var check := can_use(pid, card_id, target, targets)
    if not bool(check["ok"]):
        return check
    choices[pid] = {
        "pass": false,
        "card": card_id,
        "target": int(check["targets"][0]) if check["targets"].size() > 0 else -1,
        "targets": check["targets"],
        "cost": int(check["cost"]),
    }
    return check


func needs_choice(pid: int) -> bool:
    var pl := _p(pid)
    if not _can_act(pl):
        return false
    if int(pl["silenced_round"]) == round_no:
        return false
    return true


func all_submitted() -> bool:
    for pid in players.size():
        if needs_choice(pid) and not choices.has(pid):
            return false
    return true


func force_pass(pid: int) -> void:
    choices[pid] = {"pass": true, "card": "", "target": -1, "targets": []}


func auto_pass_silenced() -> void:
    for pid in players.size():
        var pl := _p(pid)
        if bool(pl["alive"]) and int(pl["silenced_round"]) == round_no and not choices.has(pid):
            choices[pid] = {"pass": true, "card": "", "target": -1, "targets": []}


func legal_cards(pid: int) -> Array:
    var out: Array = []
    var pl := _p(pid)
    if finished or not _can_act(pl):
        return out
    if int(pl["silenced_round"]) == round_no:
        return out
    if round_no == 1 and bool(pl["alive"]):
        return ["yun"]
    if not bool(pl["alive"]):
        if _can_borrow(pl):
            var bc := Cards.get_card("borrow_body")
            var bcost := effective_cost(pid, "borrow_body")
            if _cooldown_ok(pl, bc) and _uses_left(pl, bc) > 0:
                if bcost <= 0 or int(pl["luck_t"]) >= bcost:
                    return ["borrow_body"]
        return out
    for id in Cards.ids():
        var card := Cards.get_card(id)
        if int(pl["forced_round"]) == round_no and id != str(pl["forced_card"]):
            continue
        if not _cooldown_ok(pl, card):
            continue
        if _uses_left(pl, card) <= 0:
            continue
        if not _requirements_ok(pl, card):
            continue
        if card.get("multi_only", false) and players.size() < 3:
            continue
        var cost := effective_cost(pid, id)
        if cost > 0 and int(pl["luck_t"]) < cost:
            continue
        if id == "shield" and str(card.get("target", "")) != "" and alive_pids().is_empty():
            continue
        if ["wine", "undead_return"].has(id) and dead_pids().is_empty():
            continue
        if id == "raiden" and alive_pids().size() < 2:
            continue
        if id in ["sweep_earth", "double_dart", "turtle", "god_turtle", "duel", "death_note"]:
            if alive_enemies(pid).is_empty():
                continue
        out.append(id)
    return out


func legal_payload(pid: int) -> Dictionary:
    var pl := _p(pid)
    var costs := {}
    var targets := {}
    var legal := legal_cards(pid)
    for id in legal:
        costs[id] = effective_cost(pid, id)
        targets[id] = valid_targets(pid, id)
    return {
        "legal": legal,
        "costs": costs,
        "targets": targets,
        "silenced": int(pl["silenced_round"]) == round_no,
        "forced": str(pl["forced_card"]) if int(pl["forced_round"]) == round_no else "",
        "dead": not bool(pl["alive"]),
        "can_borrow": _can_borrow(pl) if not bool(pl["alive"]) else false,
    }


# ---------------------------------------------------------------- public state
func player_public(pl: Dictionary) -> Dictionary:
    return {
        "pid": int(pl["pid"]),
        "name": str(pl["name"]),
        "team": int(pl["team"]),
        "seat": int(pl["seat"]),
        "is_ai": bool(pl["is_ai"]),
        "avatar": int(pl["avatar"]),
        "hp_t": int(pl["hp_t"]),
        "luck_t": int(pl["luck_t"]),
        "shield": int(pl["shield"]),
        "alive": bool(pl["alive"]),
        "death_round": int(pl["death_round"]),
        "disconnected": bool(pl["disconnected"]),
        "statuses": pl["statuses"].duplicate(true),
        "buffs": pl["buffs"].duplicate(true),
        "cost_half": bool(pl["cost_half"]),
        "cooldowns": pl["cooldowns"].duplicate(true),
        "last_card": str(pl["last_card"]),
        "last_target": int(pl["last_target"]),
    }


func public_state() -> Dictionary:
    var arr: Array = []
    for pl in players:
        arr.append(player_public(pl))
    return {
        "round": round_no,
        "players": arr,
        "finished": finished,
        "winner_team": winner_team,
        "friendly_fire": bool(config.get("friendly_fire", false)),
    }


# ---------------------------------------------------------------- round resolution
func resolve_round() -> Dictionary:
    var events: Array = []
    var pre_hp := {}
    var pre_hp_team := {TEAM_A: 0, TEAM_B: 0}
    for pl in players:
        pre_hp[int(pl["pid"])] = int(pl["hp_t"])
        pre_hp_team[int(pl["team"])] += maxi(0, int(pl["hp_t"]))

    auto_pass_silenced()
    var actions := {}
    for pid in choices.keys():
        var cpid := int(pid)
        var ch: Dictionary = choices[pid]
        var pl := _p(cpid)
        var card_id := str(ch.get("card", ""))
        var is_pass := bool(ch.get("pass", true)) or card_id == ""
        if is_pass:
            pl["last_card"] = ""
            pl["last_target"] = -1
            pl["history"] = ["pass"]
            actions[cpid] = {"pid": cpid, "pass": true, "card_id": "", "effective_card_id": "",
                             "card": {}, "effective_card": {}, "target": -1, "targets": [],
                             "cost": 0, "prev_history": [], "stolen": false, "converted": false,
                             "turtle_double": false, "turtle_invalid": false, "suicide_backfire": false}
            continue
        var card := Cards.get_card(card_id)
        var cost := effective_cost(cpid, card_id)
        if cost > 0 and int(pl["luck_t"]) < cost:
            cost = maxi(0, int(pl["luck_t"]))
        pl["luck_t"] = int(pl["luck_t"]) - cost
        pl["uses"][card_id] = int(pl["uses"].get(card_id, 0)) + 1
        if int(card.get("cooldown", 0)) > 0:
            var ready := round_no + int(card["cooldown"]) + 1
            pl["cooldowns"][card_id] = ready
            var group := str(card.get("cooldown_group", ""))
            if group != "":
                for other in Cards.all().values():
                    if str(other.get("cooldown_group", "")) == group:
                        pl["cooldowns"][other["id"]] = ready
        if card_id == "shield":
            pl["shield_casts"] = int(pl["shield_casts"]) + 1
        var prev: Array = pl["history"].duplicate()
        pl["history"].append(card_id)
        if pl["history"].size() > 8:
            pl["history"] = pl["history"].slice(pl["history"].size() - 8)
        var target := int(ch.get("target", -1))
        var tlist: Array = ch.get("targets", []).duplicate()
        if tlist.is_empty() and target >= 0:
            tlist = [target]
        if str(card.get("target", "enemy")) == "self":
            target = cpid
            tlist = [cpid]
        elif str(card.get("target", "enemy")) == "all_enemies":
            tlist = alive_enemies(cpid)
        pl["last_card"] = card_id
        pl["last_target"] = target
        actions[cpid] = {
            "pid": cpid, "pass": false, "card_id": card_id, "card": card,
            "effective_card_id": card_id, "effective_card": card,
            "target": target, "targets": tlist, "cost": cost, "prev_history": prev,
            "stolen": false, "converted": false, "turtle_double": false,
            "turtle_invalid": false, "suicide_backfire": false,
            "self_blocked": false, "off_blocked": false,
        }

    _resolve_turtle(actions, events)

    # 扭转时空: all effects are nullified, costs / combos / cooldowns still applied.
    var rewound := false
    for pid in actions.keys():
        if str(actions[pid]["effective_card_id"]) == "rewind":
            rewound = true
            break
    if rewound:
        for pl in players:
            pl["history"] = []
        events.append({"t": "rewind", "text": "扭转时空：本回合所有技能不生效"})
        _finish_round(actions, events, pre_hp, pre_hp_team, true)
        return _make_result(actions, events, pre_hp)

    var sweep_global := false
    for pid in actions.keys():
        if str(actions[pid]["effective_card_id"]) in ["dive", "explode", "dragon_heaven"]:
            sweep_global = true
    var one_dmg_round := false
    for pid in actions.keys():
        if actions[pid]["pass"]:
            continue
        var ec: Dictionary = actions[pid]["effective_card"]
        if int(ec.get("damage_t", 0)) == 10:
            one_dmg_round = true
        if str(actions[pid]["effective_card_id"]) == "double_dart":
            one_dmg_round = true

    var k_prism := 0
    for pid in actions.keys():
        var cid := str(actions[pid]["card_id"])
        if cid in ["yun", "strong_yun"]:
            k_prism += 1
        elif cid == "negative_luck":
            k_prism -= 1

    # self-target cards can be blocked by an opponent's card (向运葵 / 葵花 / 元首 ...)
    for pid in actions.keys():
        var a: Dictionary = actions[pid]
        if a["pass"]:
            continue
        if str(a["effective_card"].get("target", "")) == "self":
            var card: Dictionary = a["effective_card"]
            if not card.get("block_by", []).is_empty():
                for opid in actions.keys():
                    if int(opid) == int(pid) or actions[opid]["pass"]:
                        continue
                    var oc: Dictionary = actions[opid]["effective_card"]
                    if oc.is_empty():
                        continue
                    if card["block_by"].has(str(oc.get("name", ""))):
                        a["self_blocked"] = true
            if str(a["effective_card_id"]) == "sunflower_luck" and one_dmg_round:
                a["self_blocked"] = true
        if str(a["effective_card"].get("target", "")) == "dead":
            var dead_card: Dictionary = a["effective_card"]
            if not dead_card.get("block_by", []).is_empty():
                for opid in actions.keys():
                    if int(opid) == int(pid) or actions[opid]["pass"]:
                        continue
                    var oc2: Dictionary = actions[opid]["effective_card"]
                    if oc2.is_empty():
                        continue
                    if dead_card["block_by"].has(str(oc2.get("name", ""))):
                        a["off_blocked"] = true
        if str(a["effective_card_id"]) == "undead_return":
            var count := 0
            for opid in actions.keys():
                if str(actions[opid]["effective_card_id"]) == "undead_return":
                    count += 1
            if count >= 2:
                a["off_blocked"] = true

    # damage matrix
    var matrix := {}
    var true_matrix := {}
    for pid in actions.keys():
        var a: Dictionary = actions[pid]
        if a["pass"]:
            continue
        var card: Dictionary = a["effective_card"]
        var tlist := _action_targets(a)
        for tid in tlist:
            var target := int(tid)
            if not is_alive(target):
                continue
            var base := _base_damage(int(pid), target, card, a, k_prism)
            var mul := 2 if a["turtle_double"] else 1
            base *= mul
            var block := _check_block(int(pid), target, card, base, actions, sweep_global, one_dmg_round)
            a["blocks"] = a.get("blocks", {})
            a["blocks"][target] = block
            a["base"] = a.get("base", {})
            a["base"][target] = base
            if base <= 0 and int(card.get("true_t", 0)) <= 0:
                continue
            var dmg := base
            var true_dmg := int(card.get("true_t", 0)) * mul
            var factor := float(block.get("factor", 1.0))
            if block.get("blocked", false):
                dmg = 0
                true_dmg = 0
                if block.get("factor", 1.0) < 1.0:
                    dmg = int(round(float(base) * factor))
                if block.get("true_apply", false):
                    true_dmg = int(card.get("true_t", 0)) * mul
                if block.get("flat_t", 0) > 0:
                    dmg = int(block["flat_t"])
            if str(card.get("id", "")) in ["six_god", "six_fly"] and block.get("blocked", false):
                true_dmg = int(card.get("true_t", 0)) * mul
            matrix[pid] = matrix.get(pid, {})
            matrix[pid][target] = dmg
            true_matrix[pid] = true_matrix.get(pid, {})
            true_matrix[pid][target] = true_dmg

    # damage comparison: same damage cancels, different only the higher stays
    var pids: Array = actions.keys()
    pids.sort()
    for i in pids.size():
        for j in range(i + 1, pids.size()):
            var a := int(pids[i])
            var b := int(pids[j])
            var ab := int(matrix.get(a, {}).get(b, 0)) + int(true_matrix.get(a, {}).get(b, 0))
            var ba := int(matrix.get(b, {}).get(a, 0)) + int(true_matrix.get(b, {}).get(a, 0))
            if ab > 0 and ba > 0:
                if ab == ba:
                    matrix[a][b] = 0
                    true_matrix[a][b] = 0
                    matrix[b][a] = 0
                    true_matrix[b][a] = 0
                    events.append({"t": "compare", "a": a, "b": b, "value_t": ab,
                                   "text": "%s 与 %s 的伤害相同（%s），互相抵消" %
                                           [_p(a)["name"], _p(b)["name"], Cards.fmt_t(ab)]})
                elif ab > ba:
                    matrix[b][a] = 0
                    true_matrix[b][a] = 0
                    events.append({"t": "compare", "a": a, "b": b, "value_t": ab,
                                   "text": "%s 的伤害高于 %s，只有 %s 生效" %
                                           [_p(a)["name"], _p(b)["name"], Cards.fmt_t(ab)]})
                else:
                    matrix[a][b] = 0
                    true_matrix[a][b] = 0
                    events.append({"t": "compare", "a": a, "b": b, "value_t": ba,
                                   "text": "%s 的伤害高于 %s，只有 %s 生效" %
                                           [_p(b)["name"], _p(a)["name"], Cards.fmt_t(ba)]})

    # non-damage effects (luck, status, revive, code kill)
    for pid in pids:
        _apply_effects(int(pid), actions, matrix, true_matrix, events, k_prism)
    _apply_post_effects(actions, events)

    # damage & shields
    for pid in pids:
        _apply_damage_phase(int(pid), actions, matrix, true_matrix, events)

    # 不平等条约 trigger: after user successfully attacked anyone
    for pl in players:
        for b in pl["buffs"]:
            if b.get("type", "") == "unequal":
                var src := int(b.get("source", -1))
                if src >= 0 and src < players.size():
                    var src_pl := _p(src)
                    if bool(src_pl["alive"]) and str(src_pl["last_card"]) != "":
                        var acted := false
                        for pid2 in actions.keys():
                            if int(pid2) == src and not actions[pid2]["pass"]:
                                var mm: Dictionary = matrix.get(src, {})
                                for v in mm.values():
                                    if int(v) > 0:
                                        acted = true
                        if acted:
                            _apply_damage(int(pl["pid"]), 1, 1, "不平等条约", events, src)
                            events.append({"t": "unequal", "pid": int(pl["pid"]), "amount": -1,
                                           "text": "%s 因不平等条约 -0.1 血" % pl["name"]})

    _finish_round(actions, events, pre_hp, pre_hp_team, false)
    return _make_result(actions, events, pre_hp)


func _action_targets(a: Dictionary) -> Array:
    if a.get("pass", false):
        return []
    var card: Dictionary = a["effective_card"]
    var pid := int(a["pid"])
    var t := str(card.get("target", "enemy"))
    if t == "self":
        return [pid]
    if t == "dead":
        return [int(a["target"])] if int(a["target"]) >= 0 else []
    if t == "all_enemies":
        return alive_enemies(pid)
    if t == "enemies2":
        return a["targets"].duplicate()
    if t in ["enemy", "any"]:
        return [int(a["target"])] if int(a["target"]) >= 0 else []
    return []


func _base_damage(pid: int, target: int, card: Dictionary, a: Dictionary, k_prism: int) -> int:
    var id := str(card.get("id", ""))
    match id:
        "poison":
            return int(round(float(maxi(0, int(_p(target)["hp_t"]))) * 0.8))
        "prism":
            return maxi(0, 4 + 3 * k_prism)
        "final_pinch":
            var hist: Array = a.get("prev_history", [])
            return 14 if _history_matches(hist, ["small_pinch", "super_pinch"]) else 9
        "double_dart":
            return 21 if a["targets"].size() <= 1 else 10
        "sweep_earth":
            return 10
    return int(card.get("damage_t", 0))


func _can_dodge(card: Dictionary) -> bool:
    var id := str(card.get("id", ""))
    if id == "pistol" or id == "raiden":
        return false
    if card.get("tags", []).has("no_dodge"):
        return false
    if str(card.get("kind", "")) == "code":
        return id == "duel"
    return str(card.get("kind", "")) in ["attack", "control", "dot", "special"]


func _check_block(att: int, tgt: int, card: Dictionary, base_t: int,
        actions: Dictionary, sweep_global: bool, one_dmg_round: bool) -> Dictionary:
    var r := {
        "blocked": false, "by": "", "absorbed": false, "factor": 1.0,
        "true_apply": false, "flat_t": 0, "skip_effects": true,
        "reflect_t": 0, "reflect_luck": false, "force_zhongfang": false,
        "luck_gain": 0, "luck_to_attacker": 0, "time_k": 0,
        "no_self_effect": false, "steal_luck": false, "block_kind": "",
        "splash_new": false, "splash_old": false, "kill_attacker": false,
        "k_effect": false,
    }
    if not actions.has(tgt) or actions[tgt].get("pass", false):
        return r
    var d_id := str(actions[tgt].get("effective_card_id", ""))
    if d_id == "":
        return r
    var d_card := Cards.get_card(d_id)
    var name := str(d_card.get("name", ""))
    var kind := str(card.get("kind", ""))
    var id := str(card.get("id", ""))
    var cost_t := int(card.get("cost_t", 0))

    if d_id == "dodge" and _can_dodge(card):
        r["blocked"] = true
        r["by"] = d_id
        r["block_kind"] = "dodge"
        r["no_self_effect"] = true
        return r
    if d_id == "wine" and kind in ["attack", "dot"] and base_t + int(card.get("true_t", 0)) <= 10:
        r["blocked"] = true
        r["by"] = d_id
        r["block_kind"] = "wine"
        r["no_self_effect"] = true
        return r
    if d_id == "amulet":
        var eff_cost := effective_cost(att, str(card.get("id", "")))
        if eff_cost in [20, 30]:
            r["blocked"] = true
            r["by"] = d_id
            r["block_kind"] = "amulet"
            r["no_self_effect"] = true
            return r

    # 决斗 dynamic "可被": everything except 运/强化运/超级吸/觉醒中防/小掐
    if id == "duel":
        if d_id in ["turtle", "god_turtle"]:
            r["blocked"] = true
            r["no_self_effect"] = true
            return r
        var excluded := ["yun", "strong_yun", "absorb", "super_absorb",
                         "awaken_zhongfang", "new_awaken_zhongfang", "small_pinch"]
        if not excluded.has(d_id):
            r["blocked"] = true
            r["by"] = d_id
            r["block_kind"] = "duel_block"
            r["no_self_effect"] = d_id == "dodge"
            return r
        return r
    if id == "death_note" and d_id == "strong_yun":
        r["blocked"] = true
        r["by"] = d_id
        return r
    if id == "borrow_body" and d_id == "despise":
        r["blocked"] = true
        r["by"] = d_id
        return r
    if id == "purify" and d_id in ["peach", "shield"]:
        r["blocked"] = true
        r["by"] = d_id
        return r

    if id == "sweep_earth":
        if sweep_global:
            r["blocked"] = true
            r["by"] = "global"
            return r
        if d_id == "small_dart":
            r["blocked"] = true
            r["by"] = d_id
            return r
        return r

    if id == "new_long_attack_scatter":
        if d_id == "zhongfang":
            r["blocked"] = true
            r["by"] = d_id
            r["splash_new"] = true
            return r
        if d_id in ["absorb", "super_absorb"]:
            var gain := 30 * (2 if d_id == "super_absorb" else 1)
            r["blocked"] = true
            r["absorbed"] = true
            r["by"] = d_id
            r["luck_gain"] = gain
            r["time_k"] = int(gain / 10)
            return r
        if d_id == "negative_luck":
            r["blocked"] = true
            r["by"] = d_id
            r["skip_effects"] = true
            return r
    if id == "long_attack_scatter":
        if d_id == "zhongfang":
            r["blocked"] = true
            r["by"] = d_id
            r["flat_t"] = 5
            return r
        if d_id in ["absorb", "super_absorb"]:
            r["blocked"] = true
            r["absorbed"] = true
            r["by"] = d_id
            r["luck_gain"] = 30 * (2 if d_id == "super_absorb" else 1)
            return r

    if d_id == "zhongfang":
        if card.get("block_by", []).has("中防"):
            r["blocked"] = true
            r["by"] = d_id
            return r
        return r

    if d_id == "awaken_zhongfang":
        if kind in ["attack", "dot"]:
            r["blocked"] = true
            r["by"] = d_id
            r["reflect_t"] = 5
            return r
        return r

    if d_id == "new_awaken_zhongfang":
        var blocks: bool = card.get("block_by", []).has("中防") or card.get("block_by", []).has("觉醒中防")
        if id in ["heart", "despise"]:
            blocks = true
        if blocks:
            r["blocked"] = true
            r["by"] = d_id
            if id == "nuke":
                r["reflect_t"] = 0
            elif id == "heart":
                r["reflect_luck"] = true
            elif id == "despise":
                r["force_zhongfang"] = true
            else:
                r["reflect_t"] = mini(int(round(float(base_t) * 0.5)), 8)
            return r
        return r

    if d_id == "strong_yun":
        if kind in ["attack", "dot"]:
            r["blocked"] = true
            r["by"] = d_id
            r["luck_gain"] = 0 if card.get("tags", []).has("offset_yun") else 20
            if id == "final_pinch":
                r["steal_luck"] = true
            return r
        return r

    if d_id in ["absorb", "super_absorb"]:
        if card.get("block_by", []).has("吸") or id in ["yun", "strong_yun"]:
            r["blocked"] = true
            r["absorbed"] = true
            r["by"] = d_id
            var gain := 0
            if id == "yun":
                gain = 10
            elif id == "strong_yun":
                gain = 20
            elif id == "dragon" or id == "dive":
                gain = 20
            elif id == "new_long_attack_scatter":
                gain = 30
            else:
                gain = int(card.get("cost_t", 0))
            if d_id == "super_absorb":
                gain *= 2
            r["luck_gain"] = gain
            if id == "micro_dart":
                r["luck_gain"] = 0
                r["luck_to_attacker"] = 10
            return r
        return r

    if id == "poison" and d_id in ["yun", "strong_yun"]:
        r["blocked"] = true
        r["by"] = d_id
        r["factor"] = 0.4
        return r
    if id in ["six_god", "six_fly"] and d_id in ["yun", "strong_yun", "zhongfang"]:
        r["blocked"] = true
        r["by"] = d_id
        r["true_apply"] = true
        return r

    if d_id == "yun":
        if card.get("block_by", []).has("运"):
            r["blocked"] = true
            r["by"] = d_id
            r["luck_gain"] = 10
            if card.get("tags", []).has("offset_yun"):
                r["luck_gain"] = 0
            if id == "final_pinch":
                r["steal_luck"] = true
            return r
        return r

    if d_id == "negative_luck":
        if id in ["dragon", "small_dart", "new_long_attack_scatter"] or card.get("block_by", []).has("负运"):
            r["blocked"] = true
            r["by"] = d_id
            return r
        return r

    if d_id == "small_pinch":
        if id == "micro_dart":
            r["blocked"] = true
            r["by"] = d_id
            return r
        if id == "explode":
            r["blocked"] = true
            r["by"] = d_id
            r["kill_attacker"] = true
            return r
        return r
    if d_id == "super_pinch" and id == "explode":
        r["blocked"] = true
        r["by"] = d_id
        r["kill_attacker"] = true
        return r

    if card.get("block_by", []).has(name):
        r["blocked"] = true
        r["by"] = d_id
        return r
    return r


func _resolve_turtle(actions: Dictionary, events: Array) -> void:
    var turtles: Array = []
    for pid in actions.keys():
        if actions[pid]["pass"]:
            continue
        if str(actions[pid]["card_id"]) in ["turtle", "god_turtle"]:
            turtles.append(int(pid))
    if turtles.is_empty():
        return
    if turtles.size() >= 2 and players.size() == 2:
        for t in turtles:
            actions[t]["turtle_invalid"] = true
            events.append({"t": "text", "text": "%s 的龟派与对方同时发动，无效" % _p(t)["name"]})
        return
    var victim_counts := {}
    for t in turtles:
        var v := int(actions[t]["target"])
        if v < 0:
            var es := alive_enemies(t)
            if not es.is_empty():
                v = int(es[0])
                actions[t]["target"] = v
        victim_counts[v] = int(victim_counts.get(v, 0)) + 1
    for t in turtles:
        var v := int(actions[t]["target"])
        if int(victim_counts.get(v, 0)) >= 2:
            actions[t]["turtle_invalid"] = true
            events.append({"t": "text", "text": "%s 的龟派遭到多个龟派冲突，无效" % _p(t)["name"]})
    for t in turtles:
        if actions[t]["turtle_invalid"]:
            continue
        var v := int(actions[t]["target"])
        if not actions.has(v) or actions[v]["pass"]:
            continue
        if str(actions[v]["card_id"]) in ["turtle", "god_turtle", "duel"]:
            continue
        if str(actions[v]["card_id"]) == "suicide":
            actions[v]["effective_card_id"] = ""
            actions[v]["stolen"] = true
            actions[t]["suicide_backfire"] = true
            events.append({"t": "text", "text": "%s 龟派了 %s 的自杀，自杀者存活，龟派者代码杀死亡" %
                                   [_p(t)["name"], _p(v)["name"]]})
            continue
        var v_card_id := str(actions[v]["card_id"])
        var v_card := Cards.get_card(v_card_id)
        actions[t]["effective_card_id"] = v_card_id
        actions[t]["effective_card"] = v_card
        actions[t]["converted"] = true
        actions[t]["turtle_double"] = str(actions[t]["card_id"]) == "god_turtle"
        actions[v]["effective_card_id"] = ""
        actions[v]["effective_card"] = {}
        actions[v]["stolen"] = true
        var v_target := int(actions[v]["target"])
        if str(v_card.get("target", "enemy")) == "self":
            actions[t]["target"] = t
            actions[t]["targets"] = [t]
        elif v_target == t:
            actions[t]["target"] = v
            actions[t]["targets"] = [v]
        else:
            actions[t]["target"] = v_target
            actions[t]["targets"] = actions[v]["targets"].duplicate()
        if str(v_card.get("target", "enemy")) == "all_enemies":
            actions[t]["targets"] = alive_enemies(t)
        events.append({"t": "text", "text": "%s 龟派转化了 %s 的「%s」" %
                               [_p(t)["name"], _p(v)["name"], v_card.get("name", v_card_id)]})


func _apply_effects(pid: int, actions: Dictionary, matrix: Dictionary,
        true_matrix: Dictionary, events: Array, k_prism: int) -> void:
    var a: Dictionary = actions[pid]
    if a["pass"]:
        return
    var pl := _p(pid)
    var id := str(a["effective_card_id"])
    if id == "":
        return
    var card: Dictionary = a["effective_card"]
    var targets := _action_targets(a)
    var tgt := -1 if targets.is_empty() else int(targets[0])
    var block: Dictionary = {}
    var blocked := false
    if str(card.get("target", "")) == "self":
        blocked = bool(a.get("self_blocked", false))
    elif str(card.get("target", "")) == "dead":
        blocked = bool(a.get("off_blocked", false))
    elif tgt >= 0:
        block = a.get("blocks", {}).get(tgt, {})
        blocked = bool(block.get("blocked", false))

    if a.get("suicide_backfire", false):
        _kill_code(pid, "龟派反噬", events)
        return

    match id:
        "yun":
            if not blocked:
                var absorber := _find_absorber(pid, actions)
                var gain := 10 * (2 if a["turtle_double"] else 1)
                if absorber >= 0:
                    if str(actions[absorber]["effective_card_id"]) == "super_absorb":
                        gain *= 2
                    _p(absorber)["luck_t"] = int(_p(absorber)["luck_t"]) + gain
                    events.append({"t": "luck", "pid": absorber, "amount": gain,
                                   "text": "%s 的吸运吸走了 %s 的 %s 运" %
                                           [_p(absorber)["name"], pl["name"], Cards.fmt_t(gain)]})
                else:
                    pl["luck_t"] = int(pl["luck_t"]) + gain
                    events.append({"t": "luck", "pid": pid, "amount": gain, "text": "%s +1运" % pl["name"]})
        "strong_yun":
            if not blocked:
                var blocked_count := 0
                for opid in actions.keys():
                    var oa: Dictionary = actions[opid]
                    if oa["pass"]:
                        continue
                    var tb: Dictionary = oa.get("blocks", {}).get(pid, {})
                    if bool(tb.get("blocked", false)) and str(tb.get("by", "")) == "strong_yun":
                        blocked_count += 1
                if blocked_count <= 2:
                    var absorber2 := _find_absorber(pid, actions)
                    var gain2 := 20 * (2 if a["turtle_double"] else 1)
                    if absorber2 >= 0:
                        if str(actions[absorber2]["effective_card_id"]) == "super_absorb":
                            gain2 *= 2
                        _p(absorber2)["luck_t"] = int(_p(absorber2)["luck_t"]) + gain2
                        events.append({"t": "luck", "pid": absorber2, "amount": gain2,
                                       "text": "%s 吸走了 %s 的强化运 %s 运" %
                                               [_p(absorber2)["name"], pl["name"], Cards.fmt_t(gain2)]})
                    else:
                        pl["luck_t"] = int(pl["luck_t"]) + 20 * (2 if a["turtle_double"] else 1)
                        events.append({"t": "luck", "pid": pid, "amount": 20, "text": "%s +2运" % pl["name"]})
                else:
                    events.append({"t": "text", "text": "%s 的强化运挡了超过2次攻击，本回合不得运" % pl["name"]})
        "negative_luck":
            if tgt >= 0 and is_alive(tgt):
                var tp := _p(tgt)
                var nl := 20 if a["turtle_double"] else 10
                tp["luck_t"] = int(tp["luck_t"]) - nl
                events.append({"t": "luck", "pid": tgt, "amount": -nl,
                               "text": "%s 被负运 -%s运" % [tp["name"], Cards.fmt_t(nl)]})
                if blocked and str(block.get("by", "")) in ["absorb", "super_absorb"]:
                    pl["luck_t"] = int(pl["luck_t"]) - 10
                    events.append({"t": "luck", "pid": pid, "amount": -10,
                                   "text": "%s 的负运被吸，自己 -1运" % pl["name"]})
        "soul_steal":
            if not blocked and tgt >= 0 and is_alive(tgt):
                var stolen: int = _p(tgt)["luck_t"]
                _p(tgt)["luck_t"] = 0
                if a["turtle_double"]:
                    stolen *= 2
                pl["luck_t"] = int(pl["luck_t"]) + stolen
                events.append({"t": "steal_luck", "from": tgt, "to": pid, "amount": stolen,
                               "text": "%s 勾走 %s 的全部运（%s）" %
                                       [pl["name"], _p(tgt)["name"], Cards.fmt_t(stolen)]})
        "heart":
            if not blocked and tgt >= 0 and is_alive(tgt):
                var tp := _p(tgt)
                var before := int(tp["luck_t"])
                var after := before - (40 if a["turtle_double"] else 20)
                if after < -30:
                    after = -30 if before > -30 else before
                tp["luck_t"] = after
                events.append({"t": "luck", "pid": tgt, "amount": after - before,
                               "text": "%s 被比心，运变为 %s" % [tp["name"], Cards.fmt_t(after)]})
        "prism":
            if blocked:
                for opid in actions.keys():
                    var ocard := str(actions[opid]["card_id"])
                    if ocard in ["yun", "strong_yun"]:
                        _p(opid)["luck_t"] = int(_p(opid)["luck_t"]) - 2
                        events.append({"t": "luck", "pid": int(opid), "amount": -2,
                                       "text": "%s 因三棱镜被挡 -0.2运" % _p(opid)["name"]})
                    elif ocard == "negative_luck":
                        _p(opid)["luck_t"] = int(_p(opid)["luck_t"]) + 2
                        events.append({"t": "luck", "pid": int(opid), "amount": 2,
                                       "text": "%s 因三棱镜被挡 +0.2运" % _p(opid)["name"]})
        "despise":
            if not blocked and tgt >= 0 and is_alive(tgt):
                var tp := _p(tgt)
                tp["silenced_round"] = round_no + 1
                tp["history"] = []
                events.append({"t": "silence", "pid": tgt,
                               "text": "%s 被鄙视：下回合不能出技能，连招清零" % tp["name"]})
        "shield":
            if not blocked and tgt >= 0 and is_alive(tgt):
                _p(tgt)["shield"] = int(_p(tgt)["shield"]) + 1
                events.append({"t": "shield", "pid": tgt, "amount": 1,
                               "text": "%s 获得 1 盾" % _p(tgt)["name"]})
        "peach":
            if not blocked and tgt >= 0 and is_alive(tgt):
                var removed := _remove_statuses(_p(tgt), ["sneak", "c4", "time"])
                if removed:
                    events.append({"t": "purify", "pid": tgt,
                                   "text": "%s 的偷袭/C4/时间分散被桃桃解除（本回合不回血）" % _p(tgt)["name"]})
                else:
                    var ph := 10 if a["turtle_double"] else 5
                    _p(tgt)["hp_t"] = int(_p(tgt)["hp_t"]) + ph
                    events.append({"t": "heal", "pid": tgt, "amount": ph,
                                   "text": "%s +%s血" % [_p(tgt)["name"], Cards.fmt_t(ph)]})
        "peach_core":
            if not blocked:
                var pc := 2 if a["turtle_double"] else 1
                pl["hp_t"] = int(pl["hp_t"]) + pc
                events.append({"t": "heal", "pid": pid, "amount": pc,
                               "text": "%s +%s血" % [pl["name"], Cards.fmt_t(pc)]})
        "peach_oath":
            if not blocked:
                var heal := 5 * players.size() * (2 if a["turtle_double"] else 1)
                pl["hp_t"] = int(pl["hp_t"]) + heal
                events.append({"t": "heal", "pid": pid, "amount": heal,
                               "text": "%s +%s血（桃园结义）" % [pl["name"], Cards.fmt_t(heal)]})
        "needle":
            if tgt >= 0 and is_alive(tgt) and not blocked:
                var mul := 2 if a["turtle_double"] else 1
                var heal := 6 * mul
                pl["hp_t"] = int(pl["hp_t"]) + heal
                events.append({"t": "heal", "pid": pid, "amount": heal, "text": "%s +%s血" % [pl["name"], Cards.fmt_t(heal)]})
            elif blocked:
                var heal2 := 6 * (2 if a["turtle_double"] else 1)
                pl["hp_t"] = int(pl["hp_t"]) + heal2
                events.append({"t": "heal", "pid": pid, "amount": heal2,
                               "text": "%s 的定海神针被挡，但仍 +%s血" % [pl["name"], Cards.fmt_t(heal2)]})
        "wine":
            if not blocked and tgt >= 0 and not is_alive(tgt):
                var tp := _p(tgt)
                var wine_hp := 8 if a["turtle_double"] else 4
                var wine_luck := 20 if a["turtle_double"] else 10
                _revive(tp, wine_hp, wine_luck, events, "酒")
                events.append({"t": "revive", "pid": tgt,
                               "text": "%s 用酒复活了 %s（0.4血，1运）" % [pl["name"], tp["name"]]})
        "undead_return":
            if not blocked and tgt >= 0 and not is_alive(tgt):
                var tp := _p(tgt)
                var old_hp := int(tp["death_hp_t"])
                var old_luck := int(tp["death_luck_t"])
                var old_shield := int(tp["death_shield"])
                tp["hp_t"] = 10
                tp["luck_t"] = old_luck
                tp["shield"] = old_shield
                tp["alive"] = true
                tp["death_cause"] = ""
                tp["revived_until"] = round_no + 5
                _add_buff(tp, {"type": "undead", "caster": pid, "until": round_no + 5})
                events.append({"t": "revive", "pid": tgt,
                               "text": "%s 的亡灵返乡复活了 %s（5回合）" % [pl["name"], tp["name"]]})
        "borrow_body":
            if not blocked and tgt >= 0 and is_alive(tgt):
                var tp := _p(tgt)
                var inherit_hp := int(tp["hp_t"])
                var inherit_shield := int(tp["shield"])
                var new_luck := int(pl["luck_t"]) + int(tp["luck_t"])
                _kill_direct(tgt, "sacrifice", events)
                pl["hp_t"] = inherit_hp
                pl["shield"] = inherit_shield
                pl["luck_t"] = new_luck
                pl["alive"] = true
                pl["death_cause"] = ""
                tp["hp_t"] = 0
                events.append({"t": "revive", "pid": pid,
                               "text": "%s 用借尸还魂让 %s 替死，继承 %s 血、%s 盾，运=%s" %
                                       [pl["name"], tp["name"], Cards.fmt_t(inherit_hp),
                                        str(inherit_shield), Cards.fmt_t(new_luck)]})
                _on_revive(pl, events)
        "purify":
            if not blocked:
                var removed_unequal := _remove_buffs(pl, "unequal")
                var removed := _remove_statuses(pl, ["sneak", "c4", "time"])
                var before := int(pl["hp_t"])
                var after := maxi(before + 5, 13)
                pl["hp_t"] = after
                events.append({"t": "heal", "pid": pid, "amount": after - before,
                               "text": "%s 使用净化（%s），血量 %s → %s" %
                                       [pl["name"], "解除不平等条约" if removed_unequal else
                                        "解除偷袭/C4" if removed else "无debuff",
                                        Cards.fmt_t(before), Cards.fmt_t(after)]})
        "sunflower":
            if not blocked:
                pl["cost_half"] = true
                events.append({"t": "buff", "pid": pid, "text": "%s 习得葵花宝典：本局技能消耗×50%%" % pl["name"]})
        "sunflower_luck":
            if not blocked:
                _add_buff(pl, {"type": "luck_regen", "remaining": 2,
                               "gain": 20 if a["turtle_double"] else 10})
                events.append({"t": "buff", "pid": pid, "text": "%s 获得向运葵：每回合+1运，共2回合" % pl["name"]})
        "rage":
            if not blocked:
                _add_buff(pl, {"type": "rage", "until": round_no + 3})
                events.append({"t": "buff", "pid": pid, "text": "%s 元首の愤怒：3回合内意大利炮2运" % pl["name"]})
        "safe_box":
            if not blocked:
                _add_buff(pl, {"type": "insurance"})
                events.append({"t": "buff", "pid": pid, "text": "%s 存入保险箱（复活后生效）" % pl["name"]})
        "unequal":
            if not blocked and tgt >= 0 and is_alive(tgt):
                _add_buff(_p(tgt), {"type": "unequal", "source": pid})
                events.append({"t": "buff", "pid": tgt,
                               "text": "%s 被不平等条约：不能对 %s 使用有害技能" % [_p(tgt)["name"], pl["name"]]})
        "sneak":
            if not blocked and tgt >= 0 and is_alive(tgt):
                _add_status(_p(tgt), {"type": "sneak", "tick": 2, "remaining": 5, "source": pid})
                events.append({"t": "dot", "pid": tgt, "text": "%s 中了偷袭（5回合，每回合-0.2）" % _p(tgt)["name"]})
        "c4":
            if not blocked and tgt >= 0 and is_alive(tgt):
                _add_status(_p(tgt), {"type": "c4", "trigger": round_no + 3, "tick": 30, "source": pid})
                events.append({"t": "dot", "pid": tgt, "text": "%s 被安装 C4（3回合后-3）" % _p(tgt)["name"]})
        "suicide":
            if not a.get("suicide_backfire", false):
                _kill_code(pid, "自杀", events)
        "duel":
            if tgt >= 0 and is_alive(tgt):
                if blocked:
                    if not block.get("no_self_effect", false):
                        _duel_effect(pid, pid, events)
                else:
                    _duel_effect(tgt, pid, events)
        "nuke":
            pl["history"] = []
        "death_note":
            if not blocked and tgt >= 0 and is_alive(tgt):
                _kill_code(tgt, "死亡笔记", events)
                events.append({"t": "text", "text": "%s 的死亡笔记指定 %s 自杀" % [pl["name"], _p(tgt)["name"]]})
        "small_pinch", "super_pinch", "final_pinch":
            if tgt >= 0 and is_alive(tgt):
                var target_card := ""
                if actions.has(tgt) and not actions[tgt]["pass"]:
                    target_card = str(actions[tgt]["card_id"])
                if target_card == "explode" and not blocked:
                    _kill_code(tgt, "掐·乃爆", events)
                    events.append({"t": "text", "text": "%s 的%s秒杀了乃爆使用者 %s（代码杀）" %
                                       [pl["name"], card.get("name", ""), _p(tgt)["name"]]})
                if id == "final_pinch" and block.get("steal_luck", false):
                    var gain := 10
                    var target_card2 := str(actions.get(tgt, {}).get("card_id", ""))
                    if target_card2 == "strong_yun":
                        gain = 20
                    _p(tgt)["luck_t"] = int(_p(tgt)["luck_t"]) - gain
                    pl["luck_t"] = int(pl["luck_t"]) + gain
                    events.append({"t": "luck", "pid": pid, "amount": gain,
                                   "text": "%s 的究掐被运挡，抢走 %s 本回合获得的 %s 运" %
                                           [pl["name"], _p(tgt)["name"], Cards.fmt_t(gain)]})

func _apply_post_effects(actions: Dictionary, events: Array) -> void:
    # absorbed luck is paid to the defender (吸)
    for opid in actions.keys():
        var oa: Dictionary = actions[opid]
        if oa["pass"]:
            continue
        for tid in _action_targets(oa):
            var tb: Dictionary = oa.get("blocks", {}).get(int(tid), {})
            if bool(tb.get("absorbed", false)) and int(tb.get("luck_gain", 0)) > 0:
                var abs_pid := int(tid)
                if is_alive(abs_pid):
                    _p(abs_pid)["luck_t"] = int(_p(abs_pid)["luck_t"]) + int(tb["luck_gain"])
                    events.append({"t": "luck", "pid": abs_pid, "amount": int(tb["luck_gain"]),
                                   "text": "%s 的%s吸到 %s 运" %
                                           [_p(abs_pid)["name"], _p(abs_pid)["last_card"], Cards.fmt_t(int(tb["luck_gain"]))]})
            if int(tb.get("luck_to_attacker", 0)) > 0:
                _p(int(oa["pid"]))["luck_t"] = int(_p(int(oa["pid"]))["luck_t"]) + int(tb["luck_to_attacker"])
                events.append({"t": "luck", "pid": int(oa["pid"]), "amount": int(tb["luck_to_attacker"]),
                               "text": "%s 的微镖被吸，自己 +1运" % _p(int(oa["pid"]))["name"]})

    # 新·长攻分散 时间分散 (all absorbed players)
    for opid in actions.keys():
        var oa: Dictionary = actions[opid]
        if oa["pass"]:
            continue
        if str(oa["effective_card_id"]) != "new_long_attack_scatter":
            continue
        for tid in _action_targets(oa):
            var tb: Dictionary = oa.get("blocks", {}).get(int(tid), {})
            if bool(tb.get("absorbed", false)) and int(tb.get("time_k", 0)) > 0:
                var kk := int(tb["time_k"])
                var absorbed_pids: Array = []
                for apid in actions.keys():
                    var aaa: Dictionary = actions[apid]
                    if aaa["pass"]:
                        continue
                    for atid in _action_targets(aaa):
                        var atb: Dictionary = aaa.get("blocks", {}).get(int(atid), {})
                        if bool(atb.get("absorbed", false)) and not absorbed_pids.has(int(atid)):
                            absorbed_pids.append(int(atid))
                for atid in absorbed_pids:
                    _add_status(_p(int(atid)), {"type": "time", "tick": 4, "remaining": kk, "source": int(opid)})
                    events.append({"t": "dot", "pid": int(atid),
                                   "text": "%s 被时间分散：每回合-0.4，持续%d回合" % [_p(int(atid))["name"], kk]})

    # 觉醒中防 reflection side effects
    for opid in actions.keys():
        var oa2: Dictionary = actions[opid]
        if oa2["pass"]:
            continue
        for tid in _action_targets(oa2):
            var tb2: Dictionary = oa2.get("blocks", {}).get(int(tid), {})
            if bool(tb2.get("reflect_luck", false)):
                _p(int(oa2["pid"]))["luck_t"] = int(_p(int(oa2["pid"]))["luck_t"]) - 10
                events.append({"t": "luck", "pid": int(oa2["pid"]), "amount": -10,
                               "text": "%s 的比心被反弹，-1运" % _p(int(oa2["pid"]))["name"]})
            if bool(tb2.get("force_zhongfang", false)):
                var ap := _p(int(oa2["pid"]))
                ap["forced_round"] = round_no + 1
                ap["forced_card"] = "zhongfang"
                events.append({"t": "force", "pid": int(oa2["pid"]),
                               "text": "%s 的鄙视被反弹：下回合强制中防" % ap["name"]})
            if bool(tb2.get("kill_attacker", false)):
                _kill_code(int(oa2["pid"]), "掐反制", events)


func _duel_effect(victim: int, owner: int, events: Array) -> void:
    var pl := _p(victim)
    if int(pl["shield"]) > 0:
        var n := int(pl["shield"])
        pl["shield"] = 0
        events.append({"t": "shield_clear", "pid": victim, "amount": n,
                       "text": "%s 的 %d 张盾被决斗清空" % [pl["name"], n]})
    else:
        _kill_code(victim, "决斗", events)
        events.append({"t": "text", "text": "%s 的决斗代码杀 %s" % [_p(owner)["name"], pl["name"]]})


func _apply_damage_phase(pid: int, actions: Dictionary, matrix: Dictionary,
        true_matrix: Dictionary, events: Array) -> void:
    var a: Dictionary = actions[pid]
    if a["pass"]:
        return
    var pl := _p(pid)
    var card: Dictionary = a["effective_card"]
    if card.is_empty():
        return
    if str(card.get("target", "")) == "self":
        return
    if str(card.get("target", "")) == "dead":
        return
    var targets := _action_targets(a)
    for tid in targets:
        var tgt := int(tid)
        if not is_alive(tgt):
            continue
        var block: Dictionary = a.get("blocks", {}).get(tgt, {})
        var dmg := int(matrix.get(pid, {}).get(tgt, 0))
        var true_dmg := int(true_matrix.get(pid, {}).get(tgt, 0))
        if dmg > 0 or true_dmg > 0:
            var total := dmg + true_dmg
            var final_target := _redirect_target(tgt, pid, actions)
            if final_target < 0 or not is_alive(final_target):
                final_target = tgt
            var require := int(card.get("shield_require", 0))
            if require <= 0:
                require = 1
            _apply_damage(final_target, total, require, str(card.get("name", "")), events, pid)
        # splash from 新·长攻分散 / 旧长攻分散 when blocked by 中防
        if bool(block.get("splash_new", false)) or bool(block.get("splash_old", false)):
            if bool(block.get("splash_new", false)):
                _splash_new(pid, tgt, actions, events)
            else:
                _apply_damage(tgt, 5, 1, "长攻分散", events, pid)
        if int(block.get("reflect_t", 0)) > 0 and is_alive(pid):
            _apply_damage(pid, int(block["reflect_t"]), 1, "觉醒中防反弹", events, tgt)


func _find_absorber(pid: int, actions: Dictionary) -> int:
    for opid in actions.keys():
        var oid := int(opid)
        if oid == pid or actions[opid].get("pass", true):
            continue
        var eid := str(actions[opid].get("effective_card_id", ""))
        if eid in ["absorb", "super_absorb"]:
            return oid
    return -1


func _redirect_target(victim: int, att: int, actions: Dictionary) -> int:
    # 聚伤: all damage gathers on one target this round
    for pid in actions.keys():
        var a: Dictionary = actions[pid]
        if a["pass"]:
            continue
        if str(a["effective_card_id"]) == "gather_damage":
            var gt := int(a["target"])
            if gt >= 0 and is_alive(gt):
                var gb: Dictionary = a.get("blocks", {}).get(gt, {})
                if not bool(gb.get("blocked", false)):
                    return gt
    # 飞雷神: attacks against the caster are redirected
    if actions.has(victim):
        var va: Dictionary = actions[victim]
        if not va["pass"] and str(va["effective_card_id"]) == "raiden":
            var rt := int(va["target"])
            if rt >= 0 and rt != victim and is_alive(rt):
                return rt
    return victim


func _splash_new(att: int, tgt: int, actions: Dictionary, events: Array) -> void:
    var att_pl := _p(att)
    var att_team := int(att_pl["team"])
    var targets: Array = [tgt]
    if tgt - 1 >= 0:
        targets.append(tgt - 1)
    if tgt + 1 < players.size():
        targets.append(tgt + 1)
    for sid in targets:
        var sid_i := int(sid)
        if not is_alive(sid_i):
            continue
        var spl := _p(sid_i)
        if sid_i != tgt and int(spl["team"]) == att_team:
            continue
        if sid_i == att:
            continue
        var blocked := false
        if sid_i != tgt and actions.has(sid_i) and not actions[sid_i]["pass"]:
            var dc := str(actions[sid_i]["effective_card_id"])
            if dc in ["zhongfang", "dodge"]:
                blocked = true
        if blocked:
            events.append({"t": "text", "text": "%s 用%s挡下了空间分散的溅射" %
                                   [spl["name"], Cards.get_card(str(actions[sid_i]["effective_card_id"])).get("name", "")]})
            continue
        _apply_damage(sid_i, 5, 1, "空间分散", events, att)
        events.append({"t": "splash", "pid": sid_i, "amount": 5,
                       "text": "空间分散：%s -0.5血" % spl["name"]})


func _apply_damage(pid: int, amount_t: int, shield_require: int, source: String,
        events: Array, from_pid: int = -1) -> void:
    if amount_t <= 0 or not is_alive(pid):
        return
    var pl := _p(pid)
    var lethal := int(pl["hp_t"]) - amount_t <= 0
    if lethal:
        var need := maxi(1, shield_require)
        if int(pl["shield"]) >= need:
            pl["shield"] = int(pl["shield"]) - need
            events.append({"t": "shield_block", "pid": pid, "amount": need,
                           "text": "%s 消耗 %d 盾挡下 %s（保留受击前血量 %s）" %
                                   [pl["name"], need, source, Cards.fmt_t(int(pl["hp_t"]))]})
            return
    pl["hp_t"] = int(pl["hp_t"]) - amount_t
    events.append({"t": "damage", "pid": pid, "from": from_pid, "amount": -amount_t,
                   "text": "%s 受 %s 伤害 -%s（血量 %s）" %
                           [pl["name"], source, Cards.fmt_t(amount_t), Cards.fmt_t(int(pl["hp_t"]))]})
    if int(pl["hp_t"]) <= 0:
        _die(pid, "damage", events)


func _kill_code(pid: int, source: String, events: Array) -> void:
    if not is_alive(pid):
        return
    var pl := _p(pid)
    if int(pl["shield"]) >= 1:
        pl["shield"] = int(pl["shield"]) - 1
        events.append({"t": "shield_block", "pid": pid, "amount": 1,
                       "text": "%s 消耗 1 盾挡下代码杀（%s）" % [pl["name"], source]})
        return
    _die(pid, "code", events)
    events.append({"t": "death", "pid": pid, "cause": "code",
                   "text": "%s 被代码杀（%s）死亡" % [pl["name"], source]})


func _kill_direct(pid: int, cause: String, events: Array) -> void:
    if not is_alive(pid):
        return
    _die(pid, cause, events)
    events.append({"t": "death", "pid": pid, "cause": cause,
                   "text": "%s 死亡（%s）" % [_p(pid)["name"], cause]})


func _die(pid: int, cause: String, events: Array) -> void:
    var pl := _p(pid)
    if not bool(pl["alive"]):
        return
    pl["alive"] = false
    pl["death_round"] = round_no
    pl["death_cause"] = cause
    pl["death_hp_t"] = int(pl["hp_t"])
    pl["death_luck_t"] = int(pl["luck_t"])
    pl["death_shield"] = int(pl["shield"])
    pl["hp_t"] = mini(0, int(pl["hp_t"]))
    events.append({"t": "died", "pid": pid, "cause": cause,
                   "text": "%s 阵亡（%s）" % [pl["name"], "代码杀" if cause == "code" else "伤害"]})


func _revive(pl: Dictionary, hp_t: int, luck_t: int, events: Array, source: String) -> void:
    pl["alive"] = true
    pl["death_cause"] = ""
    pl["hp_t"] = hp_t
    pl["luck_t"] = luck_t
    _on_revive(pl, events)


func _on_revive(pl: Dictionary, events: Array) -> void:
    var insurance := _get_buff(pl, "insurance")
    if not insurance.is_empty():
        _remove_buffs(pl, "insurance")
        pl["luck_t"] = int(pl["luck_t"]) + 30
        pl["shield"] = int(pl["shield"]) + 1
        pl["hp_t"] = int(pl["hp_t"]) + 5
        events.append({"t": "text", "text": "%s 的保险箱生效：+3运，+1盾，+0.5血" % pl["name"]})


func _finish_round(actions: Dictionary, events: Array, pre_hp: Dictionary,
        pre_hp_team: Dictionary, skip_winner: bool) -> void:
    # undead expiration is handled at round start
    if skip_winner:
        return
    var a_alive := team_alive(TEAM_A)
    var b_alive := team_alive(TEAM_B)
    if a_alive == 0 and b_alive == 0:
        var da := _damage_dealt_by_team(actions, TEAM_A)
        var db := _damage_dealt_by_team(actions, TEAM_B)
        if da > db:
            winner_team = TEAM_A
        elif db > da:
            winner_team = TEAM_B
        elif int(pre_hp_team[TEAM_A]) >= int(pre_hp_team[TEAM_B]):
            winner_team = TEAM_A
        else:
            winner_team = TEAM_B
        finished = true
        events.append({"t": "winner", "team": winner_team,
                       "text": "双方同时全灭：按本回合伤害判定 %s 队获胜（无平局）" % ("A" if winner_team == 0 else "B")})
    elif a_alive == 0:
        winner_team = TEAM_B
        finished = true
        events.append({"t": "winner", "team": winner_team, "text": "B 队获胜"})
    elif b_alive == 0:
        winner_team = TEAM_A
        finished = true
        events.append({"t": "winner", "team": winner_team, "text": "A 队获胜"})


func _damage_dealt_by_team(actions: Dictionary, team: int) -> int:
    var total := 0
    for pid in actions.keys():
        if int(_p(int(pid))["team"]) != team:
            continue
        var a: Dictionary = actions[pid]
        if a["pass"]:
            continue
        for v in a.get("base", {}).values():
            total += int(v)
    return total


func _make_result(actions: Dictionary, events: Array, pre_hp: Dictionary) -> Dictionary:
    var choice_arr: Array = []
    for pid in actions.keys():
        var a: Dictionary = actions[pid]
        var cards_blk := {}
        for k in a.get("blocks", {}).keys():
            var b: Dictionary = a["blocks"][k]
            cards_blk[str(k)] = {
                "blocked": bool(b.get("blocked", false)),
                "by": str(b.get("by", "")),
                "absorbed": bool(b.get("absorbed", false)),
                "reflect_t": int(b.get("reflect_t", 0)),
            }
        choice_arr.append({
            "pid": int(pid),
            "card": str(a.get("card_id", "")),
            "effective_card": str(a.get("effective_card_id", "")),
            "target": int(a.get("target", -1)),
            "targets": a.get("targets", []).duplicate(),
            "pass": bool(a.get("pass", true)),
            "blocked": cards_blk,
            "stolen": bool(a.get("stolen", false)),
            "converted": bool(a.get("converted", false)),
        })
    choice_arr.sort_custom(func(x, y): return int(x["pid"]) < int(y["pid"]))
    return {
        "round": round_no,
        "events": events,
        "choices": choice_arr,
        "players": public_state()["players"],
        "finished": finished,
        "winner_team": winner_team,
        "pre_hp": pre_hp,
    }


# ---------------------------------------------------------------- next round
func advance_round() -> Dictionary:
    var events: Array = []
    choices.clear()
    if finished:
        return {"round": round_no, "events": events, "finished": true}
    round_no += 1
    for pl in players:
        if not pl["alive"]:
            continue
        if int(pl["revived_until"]) > 0 and round_no > int(pl["revived_until"]):
            _die(int(pl["pid"]), "undead_end", events)
            events.append({"t": "death", "pid": int(pl["pid"]),
                           "text": "%s 的亡灵返乡到期，再次死亡" % pl["name"]})
            continue
        var keep: Array = []
        for s in pl["statuses"]:
            var typ := str(s.get("type", ""))
            if typ == "sneak":
                _apply_damage(int(pl["pid"]), int(s.get("tick", 2)), 1, "偷袭", events)
                s["remaining"] = int(s.get("remaining", 0)) - 1
                if int(s["remaining"]) > 0:
                    keep.append(s)
            elif typ == "c4":
                if round_no >= int(s.get("trigger", 0)):
                    _apply_damage(int(pl["pid"]), int(s.get("tick", 30)), 1, "C4", events)
                else:
                    keep.append(s)
            elif typ == "time":
                _apply_damage(int(pl["pid"]), int(s.get("tick", 4)), 1, "时间分散", events)
                s["remaining"] = int(s.get("remaining", 0)) - 1
                if int(s["remaining"]) > 0:
                    keep.append(s)
            else:
                keep.append(s)
        pl["statuses"] = keep
        var keep_b: Array = []
        for b in pl["buffs"]:
            var typ2 := str(b.get("type", ""))
            if typ2 == "luck_regen":
                if int(b.get("remaining", 0)) > 0:
                    pl["luck_t"] = int(pl["luck_t"]) + int(b.get("gain", 10))
                    b["remaining"] = int(b["remaining"]) - 1
                    events.append({"t": "luck", "pid": int(pl["pid"]), "amount": int(b.get("gain", 10)),
                                   "text": "%s 的向运葵 +1运" % pl["name"]})
                if int(b.get("remaining", 0)) > 0:
                    keep_b.append(b)
            elif typ2 == "rage":
                if round_no <= int(b.get("until", 0)):
                    keep_b.append(b)
            elif typ2 == "undead":
                if round_no <= int(b.get("until", 0)):
                    keep_b.append(b)
            else:
                keep_b.append(b)
        pl["buffs"] = keep_b
    var a_alive := team_alive(TEAM_A)
    var b_alive := team_alive(TEAM_B)
    if a_alive == 0 and b_alive == 0:
        winner_team = TEAM_A
        finished = true
    elif a_alive == 0:
        winner_team = TEAM_B
        finished = true
    elif b_alive == 0:
        winner_team = TEAM_A
        finished = true
    if finished:
        events.append({"t": "winner", "team": winner_team,
                       "text": "%s 队获胜" % ("A" if winner_team == 0 else "B")})
    return {"round": round_no, "events": events, "finished": finished,
            "winner_team": winner_team, "players": public_state()["players"]}


# ---------------------------------------------------------------- AI
func ai_choose(pid: int, peek: Dictionary = {}) -> Dictionary:
    var pl := _p(pid)
    var legal := legal_cards(pid)
    if legal.is_empty():
        return {"ok": false, "card": "", "reason": "无合法牌"}
    var pids := alive_pids()
    var enemies := alive_enemies(pid)
    var best_id := ""
    var best_score := -999999.0
    for id in legal:
        var card := Cards.get_card(id)
        if card.is_empty():
            continue
        var tlist := valid_targets(pid, id)
        if tlist.is_empty() and str(card.get("target", "enemy")) != "all_enemies":
            continue
        var target := -1
        if not tlist.is_empty():
            target = int(tlist[0])
            for tid in tlist:
                var tp := _p(int(tid))
                if str(card.get("target", "")) == "dead":
                    target = int(tid)
                    break
                if tlist.size() > 0 and str(tp["team"]) != str(pl["team"]):
                    if target < 0 or int(_p(target)["hp_t"]) > int(tp["hp_t"]):
                        target = int(tid)
        var score := _ai_score(pid, id, card, target, peek)
        if score > best_score:
            best_score = score
            best_id = id
    if best_id == "":
        return {"ok": false, "card": "", "reason": "无可用决策"}
    var card2 := Cards.get_card(best_id)
    var tlist2 := valid_targets(pid, best_id)
    var target2 := -1
    var targets2: Array = []
    if str(card2.get("target", "")) == "all_enemies":
        targets2 = tlist2
    elif str(card2.get("target", "")) == "enemies2":
        var es := opponents_for_targeting(pid)
        es.sort_custom(func(x, y): return int(_p(int(x))["hp_t"]) < int(_p(int(y))["hp_t"]))
        if es.size() >= 2 and _rng.randf() < 0.5:
            targets2 = [es[0], es[1]]
        else:
            targets2 = [es[0]]
        target2 = int(targets2[0])
    elif not tlist2.is_empty():
        target2 = int(tlist2[0])
        if str(card2.get("target", "")) == "dead":
            for d in dead_pids():
                target2 = int(d)
                break
        elif str(card2.get("target", "")) in ["enemy", "any"]:
            var e2 := opponents_for_targeting(pid)
            if not e2.is_empty():
                e2.sort_custom(func(x, y): return int(_p(int(x))["hp_t"]) < int(_p(int(y))["hp_t"]))
                target2 = int(e2[0])
            if str(card2.get("target", "")) == "any" and best_id in ["shield", "peach"]:
                target2 = pid
    var check := can_use(pid, best_id, target2, targets2)
    if not bool(check["ok"]):
        return {"ok": false, "card": "", "reason": str(check["reason"])}
    return {"ok": true, "card": best_id, "target": target2, "targets": check["targets"]}


func _ai_score(pid: int, id: String, card: Dictionary, target: int, peek: Dictionary) -> float:
    var pl := _p(pid)
    var score := _rng.randf_range(0.0, 3.0)
    var kind := str(card.get("kind", ""))
    var hp := int(pl["hp_t"])
    if round_no == 1:
        return 100.0 if id == "yun" else 0.0
    if kind == "attack" or id == "final_pinch":
        var dmg := int(card.get("damage_t", 0))
        if id == "final_pinch":
            dmg = 14 if _history_matches(pl["history"], ["small_pinch", "super_pinch"]) else 9
        if target >= 0:
            var tgt := _p(target)
            score += dmg * 3.0
            if int(tgt["hp_t"]) <= dmg:
                score += 40.0
            if int(tgt["shield"]) > 0:
                score -= 10.0
            if int(tgt["hp_t"]) <= 10:
                score += 15.0
        if id in ["explode", "final_pinch", "super_pinch", "small_pinch", "poison", "six_god", "six_fly"]:
            score += 8.0
    elif kind == "defense":
        score += 20.0 if hp <= 10 else 8.0
        if id == "absorb":
            score += 12.0
        if id == "dodge":
            score += 14.0
        if id == "awaken_zhongfang" or id == "new_awaken_zhongfang":
            score += 10.0
    elif kind == "buff":
        if id == "shield":
            score += 26.0 if int(pl["shield"]) == 0 else 10.0
        elif id == "peach":
            score += 18.0 if hp <= 15 else 6.0
        elif id == "sunflower_luck":
            score += 30.0
        elif id == "sunflower":
            score += 24.0
        elif id == "strong_yun":
            score += 16.0
        elif id == "yun":
            score += 8.0
        else:
            score += 10.0
    elif kind == "control":
        if id == "despise":
            score += 28.0
        elif id == "heart" or id == "negative_luck":
            score += 12.0
        elif id == "soul_steal":
            if target >= 0:
                score += mini(40.0, float(_p(target)["luck_t"]) * 2.0)
        else:
            score += 8.0
    elif kind == "revive":
        score += 30.0 if not dead_pids().is_empty() else 0.0
    elif kind == "code":
        score += 35.0
    elif kind == "dot":
        score += 14.0
    elif kind == "special":
        score += 18.0
    # combo finisher bias
    var req: Array = card.get("requires", [])
    if not req.is_empty() and _history_matches(pl["history"], req):
        score += 45.0
    # cheat peek: counter the known card
    if not peek.is_empty():
        var peek_id := str(peek.get("card", ""))
        var peek_card := Cards.get_card(peek_id)
        if not peek_card.is_empty():
            var peek_dmg := int(peek_card.get("damage_t", 0))
            if id == "zhongfang" and peek_card.get("block_by", []).has("中防"):
                score += 60.0
            if id in ["absorb", "super_absorb"] and peek_card.get("block_by", []).has("吸"):
                score += 60.0
            if id == "dodge" and _can_dodge(peek_card):
                score += 55.0
            if id in ["awaken_zhongfang", "new_awaken_zhongfang"] and peek_card.get("block_by", []).has("中防"):
                score += 55.0
            if kind == "attack" and peek_dmg > 0 and target >= 0:
                if int(_p(target)["hp_t"]) <= peek_dmg:
                    score += 20.0
    return score
