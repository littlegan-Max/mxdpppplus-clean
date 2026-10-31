extends Node

const Store = preload("res://server/account_store.gd")
const AI_NAMES := ["机灵鬼", "阿蓝", "蘑菇仔", "像素猫", "铁皮人", "咕噜", "小海豹", "星星狐"]

var store: RefCounted
var online: Dictionary = {}        # peer_id -> hwid
var hwid_peer: Dictionary = {}     # hwid -> peer_id
var rooms: Dictionary = {}         # room_id -> room
var battles: Dictionary = {}       # room_id -> battle session
var pending_invites: Dictionary = {}  # hwid -> invite


func _ready() -> void:
    store = Store.new()
    Net.peer_connected.connect(_on_peer_connected)
    Net.peer_disconnected.connect(_on_peer_disconnected)
    Net.msg_received.connect(func(from_id: int, data: Dictionary): on_client_message(from_id, data))
    print("[server] data: ", store.path)


func _on_peer_connected(_id: int) -> void:
    pass


func _on_peer_disconnected(peer: int) -> void:
    var hwid := str(online.get(peer, ""))
    if hwid == "":
        return
    online.erase(peer)
    if str(hwid_peer.get(hwid, 0)) == str(peer):
        hwid_peer.erase(hwid)
    var room := _room_of_hwid(hwid)
    if not room.is_empty():
        _auto_pilot_or_remove(room, peer, hwid)
    _broadcast_friend_updates(hwid)
    _push_rooms()


func _acc(peer: int) -> Dictionary:
    var hwid := str(online.get(peer, ""))
    return store.accounts.get(hwid, {})


func _acc_by_hwid(hwid: String) -> Dictionary:
    return store.accounts.get(hwid, {})


func _account_payload(acc: Dictionary) -> Dictionary:
    return {
        "hwid": str(acc.get("hwid", "")),
        "name": str(acc.get("name", "")),
        "friend_code": str(acc.get("friend_code", "")),
        "avatar": int(acc.get("avatar", 0)),
        "rank": Rank.normalize(acc.get("rank", {})),
    }


func _friends_payload(hwid: String) -> Dictionary:
    var acc := _acc_by_hwid(hwid)
    var friends: Array = []
    for fh in acc.get("friends", []):
        var fa := _acc_by_hwid(str(fh))
        if fa.is_empty():
            continue
        var fr := _room_of_hwid(str(fh))
        friends.append({
            "hwid": str(fh),
            "name": str(fa.get("name", "")),
            "code": str(fa.get("friend_code", "")),
            "avatar": int(fa.get("avatar", 0)),
            "online": hwid_peer.has(str(fh)),
            "room_id": str(fr.get("id", "")),
        })
    var reqs: Array = []
    for rh in acc.get("requests_in", []):
        var ra := _acc_by_hwid(str(rh))
        if ra.is_empty():
            continue
        reqs.append({"hwid": str(rh), "name": str(ra.get("name", "")),
                     "code": str(ra.get("friend_code", ""))})
    return {"friends": friends, "requests": reqs}


func _send(peer: int, data: Dictionary) -> void:
    if peer <= 0 or not online.has(peer):
        return
    Net.send_to_peer(peer, data)


func _err(peer: int, text: String) -> void:
    _send(peer, {"t": "error", "msg": text})


func on_client_message(peer: int, data: Dictionary) -> void:
    var t := str(data.get("t", ""))
    if t == "hello":
        _handle_hello(peer, data)
        return
    if not online.has(peer):
        _err(peer, "尚未登录")
        return
    match t:
        "set_name":
            _handle_set_name(peer, data)
        "friends_list":
            _send_friends(peer)
        "friend_add":
            _handle_friend_add(peer, data)
        "friend_respond":
            _handle_friend_respond(peer, data)
        "rooms_list":
            _send(peer, {"t": "rooms", "rooms": _public_rooms()})
        "room_create":
            _handle_room_create(peer, data)
        "room_join":
            _handle_room_join(peer, data)
        "room_settings":
            _handle_room_settings(peer, data)
        "room_ready":
            _handle_room_ready(peer, data)
        "room_start":
            _handle_room_start(peer)
        "room_kick":
            _handle_room_kick(peer, data)
        "room_leave":
            _handle_room_leave(peer)
        "friend_invite":
            _handle_friend_invite(peer, data)
        "invite_respond":
            _handle_invite_respond(peer, data)
        "battle_choose":
            _handle_battle_choose(peer, data)
        _:
            _err(peer, "未知指令: " + t)


# ---------------------------------------------------------------- account
func _handle_hello(peer: int, data: Dictionary) -> void:
    var hwid := str(data.get("hwid", "")).strip_edges()
    if hwid.length() < 8:
        _err(peer, "硬件码无效")
        return
    var old := int(hwid_peer.get(hwid, 0))
    if old != 0 and old != peer:
        _send(old, {"t": "kicked", "msg": "账号在另一处登录"})
        online.erase(old)
    online[peer] = hwid
    hwid_peer[hwid] = peer
    var acc: Dictionary = store.get_or_create(hwid)
    var fp := _friends_payload(hwid)
    _send(peer, {"t": "hello_ok", "account": _account_payload(acc),
                 "friends": fp["friends"], "requests": fp["requests"]})
    _send_pending_invite(peer, hwid)
    _broadcast_friend_updates(hwid)
    _push_rooms()


func _handle_set_name(peer: int, data: Dictionary) -> void:
    var acc := _acc(peer)
    if acc.is_empty():
        return
    var res: Dictionary = store.set_name(str(acc["hwid"]), str(data.get("name", "")))
    if not bool(res.get("ok", false)):
        _err(peer, str(res.get("reason", "改名失败")))
        return
    _send(peer, {"t": "account", "account": _account_payload(res["account"])})
    var room := _room_of_hwid(str(acc["hwid"]))
    if not room.is_empty():
        for m in room["members"]:
            if str(m["hwid"]) == str(acc["hwid"]):
                m["name"] = str(res["account"]["name"])
        _broadcast_room(room)
    _broadcast_friend_updates(str(acc["hwid"]))


func _handle_friend_add(peer: int, data: Dictionary) -> void:
    var acc := _acc(peer)
    if acc.is_empty():
        return
    var code := str(data.get("code", "")).strip_edges()
    var target: Dictionary = store.by_code(code)
    if target.is_empty():
        _err(peer, "好友码不存在")
        return
    var my_hwid := str(acc["hwid"])
    var their_hwid := str(target["hwid"])
    if their_hwid == my_hwid:
        _err(peer, "不能添加自己")
        return
    if acc["friends"].has(their_hwid):
        _err(peer, "你们已经是好友")
        return
    if acc["requests_out"].has(their_hwid):
        _err(peer, "已发送过请求，等待对方同意")
        return
    store.request_friend(my_hwid, their_hwid)
    _send(peer, {"t": "friends", "friends": _friends_payload(my_hwid)["friends"],
                 "requests": _friends_payload(my_hwid)["requests"]})
    var tp := int(hwid_peer.get(their_hwid, 0))
    if tp > 0:
        _send(tp, {"t": "friend_request", "from_hwid": my_hwid,
                   "from_name": str(acc.get("name", "某人")),
                   "from_code": str(acc.get("friend_code", ""))})
        _send_friends(tp)


func _handle_friend_respond(peer: int, data: Dictionary) -> void:
    var acc := _acc(peer)
    if acc.is_empty():
        return
    var other := str(data.get("hwid", ""))
    if not acc["requests_in"].has(other):
        _err(peer, "没有这条好友请求")
        return
    var my_hwid := str(acc["hwid"])
    var oa := _acc_by_hwid(other)
    if oa.is_empty():
        _err(peer, "对方账号不存在")
        return
    if bool(data.get("accept", false)):
        store.add_friend(my_hwid, other)
        _send(peer, {"t": "friends", "friends": _friends_payload(my_hwid)["friends"],
                     "requests": _friends_payload(my_hwid)["requests"]})
        var op := int(hwid_peer.get(other, 0))
        if op > 0:
            _send(op, {"t": "friends", "friends": _friends_payload(other)["friends"],
                       "requests": _friends_payload(other)["requests"]})
        _broadcast_friend_updates(my_hwid)
        _broadcast_friend_updates(other)
    else:
        store.remove_request(my_hwid, other)
        _send_friends(peer)
    _push_rooms()


func _send_friends(peer: int) -> void:
    var acc := _acc(peer)
    if acc.is_empty():
        return
    var fp := _friends_payload(str(acc["hwid"]))
    _send(peer, {"t": "friends", "friends": fp["friends"], "requests": fp["requests"]})


func _broadcast_friend_updates(hwid: String) -> void:
    var acc := _acc_by_hwid(hwid)
    if acc.is_empty():
        return
    var targets: Array = []
    var p := int(hwid_peer.get(hwid, 0))
    if p > 0:
        targets.append(p)
    for fh in acc.get("friends", []):
        var fp := int(hwid_peer.get(str(fh), 0))
        if fp > 0 and not targets.has(fp):
            targets.append(fp)
    for x in targets:
        var xh := str(online.get(int(x), ""))
        if xh == "":
            continue
        var payload := _friends_payload(xh)
        _send(int(x), {"t": "friends", "friends": payload["friends"],
                       "requests": payload["requests"]})


# ---------------------------------------------------------------- rooms
func _new_room_id() -> String:
    for i in 40:
        var rid := str(randi_range(100000, 999999))
        if not rooms.has(rid):
            return rid
    return str(Time.get_ticks_usec()).substr(-6)


func _default_settings() -> Dictionary:
    return {"public": true, "max_players": 6, "ai_fill": false,
            "turn_time": 10, "friendly_fire": false, "cheat_mode": false}


func _handle_room_create(peer: int, data: Dictionary) -> void:
    var acc := _acc(peer)
    if acc.is_empty():
        return
    var old := _room_of_peer(peer)
    if not old.is_empty():
        _remove_member(old, peer, "leave")
    var rid := _new_room_id()
    var settings := _sanitize_settings(data, true, 1)
    var room := {
        "id": rid,
        "host_peer": peer,
        "host_hwid": str(acc["hwid"]),
        "state": "lobby",
        "members": [],
        "ai_count": 0,
    }
    room.merge(settings, true)
    room["members"].append(_member_for(peer, acc, true))
    rooms[rid] = room
    _send(peer, {"t": "room", "room": _room_payload(room)})
    _push_rooms()


func _member_for(peer: int, acc: Dictionary, is_host: bool) -> Dictionary:
    return {
        "peer": peer,
        "hwid": str(acc["hwid"]),
        "name": str(acc.get("name", "")),
        "avatar": int(acc.get("avatar", 0)),
        "ready": false,
        "is_host": is_host,
    }


func _sanitize_settings(data: Dictionary, is_new: bool, member_count: int) -> Dictionary:
    var out := _default_settings()
    out["public"] = bool(data.get("public", out["public"]))
    out["ai_fill"] = bool(data.get("ai_fill", out["ai_fill"]))
    var min_max := 1 if out["ai_fill"] else 2
    var mx := int(data.get("max_players", out["max_players"]))
    mx = clampi(mx, min_max, 8)
    if not is_new:
        mx = maxi(mx, member_count)
    out["max_players"] = mx
    out["turn_time"] = clampi(int(data.get("turn_time", 10)), 3, 60)
    out["friendly_fire"] = bool(data.get("friendly_fire", false))
    out["cheat_mode"] = bool(data.get("cheat_mode", false))
    return out


func _handle_room_join(peer: int, data: Dictionary) -> void:
    var acc := _acc(peer)
    if acc.is_empty():
        return
    var rid := str(data.get("room_id", ""))
    var room: Dictionary = rooms.get(rid, {})
    if room.is_empty():
        _err(peer, "房间不存在")
        return
    if str(room["state"]) != "lobby":
        _err(peer, "对局已开始")
        return
    if room["members"].size() >= int(room["max_players"]):
        _err(peer, "房间已满")
        return
    var old := _room_of_peer(peer)
    if not old.is_empty():
        if str(old["id"]) == rid:
            _send(peer, {"t": "room", "room": _room_payload(room)})
            return
        _remove_member(old, peer, "leave")
    room["members"].append(_member_for(peer, acc, false))
    pending_invites.erase(str(acc["hwid"]))
    _send(peer, {"t": "room", "room": _room_payload(room)})
    _broadcast_room(room)
    _push_rooms()


func _handle_room_settings(peer: int, data: Dictionary) -> void:
    var room := _room_of_peer(peer)
    if room.is_empty():
        return
    if int(room["host_peer"]) != peer:
        _err(peer, "只有房主能修改设置")
        return
    if str(room["state"]) != "lobby":
        _err(peer, "对局进行中不能修改设置")
        return
    var new_settings := _sanitize_settings(data, false, room["members"].size())
    if int(new_settings["max_players"]) < room["members"].size():
        _err(peer, "人数上限不能低于当前成员数")
        return
    room.merge(new_settings, true)
    _broadcast_room(room)
    _push_rooms()


func _handle_room_ready(peer: int, data: Dictionary) -> void:
    var room := _room_of_peer(peer)
    if room.is_empty():
        return
    for m in room["members"]:
        if int(m["peer"]) == peer:
            m["ready"] = bool(data.get("ready", true))
    _broadcast_room(room)


func _handle_room_start(peer: int) -> void:
    var room := _room_of_peer(peer)
    if room.is_empty():
        return
    if int(room["host_peer"]) != peer:
        _err(peer, "只有房主能开始游戏")
        return
    if str(room["state"]) != "lobby":
        _err(peer, "对局已开始")
        return
    var all_ready := true
    for m in room["members"]:
        if not bool(m["ready"]):
            all_ready = false
    if not all_ready:
        _err(peer, "全员准备后才能开始")
        return
    var humans: int = room["members"].size()
    var total: int = humans
    if bool(room["ai_fill"]):
        total = maxi(2, int(room["max_players"]))
    if total < 2:
        _err(peer, "至少需要 2 名参战者（可开启 AI 自动补全）")
        return
    _start_battle(room, total)


func _start_battle(room: Dictionary, total: int) -> void:
    var humans: Array = room["members"]
    var specs: Array = []
    var human_pids := {}
    var peer_pids := {}
    var ai_pids: Array = []
    for i in humans.size():
        var m: Dictionary = humans[i]
        var team := 0 if i < int(total / 2.0) else 1
        specs.append({"name": str(m["name"]) if str(m["name"]) != "" else "玩家%d" % (i + 1),
                      "team": team, "is_ai": false, "avatar": int(m["avatar"])})
        human_pids[i] = int(m["peer"])
        peer_pids[int(m["peer"])] = i
    var ai_n := total - humans.size()
    for j in ai_n:
        var pid := humans.size() + j
        var team2 := 0 if pid < int(total / 2.0) else 1
        specs.append({"name": AI_NAMES[j % AI_NAMES.size()] + "·机", "team": team2,
                      "is_ai": true, "avatar": (j + 3) % 8})
        ai_pids.append(pid)
    var engine := BattleEngine.new()
    engine.setup(specs, {"friendly_fire": bool(room["friendly_fire"]),
                         "turn_time": int(room["turn_time"]),
                         "cheat_mode": bool(room["cheat_mode"]),
                         "mode": "online", "seed": randi(),
                         "ai_bias": AiMemory.snapshot()})
    var battle := {
        "room_id": str(room["id"]),
        "engine": engine,
        "human_pids": human_pids,
        "peer_pids": peer_pids,
        "ai_pids": ai_pids,
        "autopilot_pids": [],
        "cheat": bool(room["cheat_mode"]),
        "phase": "input",
        "round": 1,
        "token": 0,
        "ended": false,
    }
    battles[str(room["id"])] = battle
    room["state"] = "battle"
    room["ai_count"] = ai_n
    for peer in peer_pids.keys():
        var pid: int = int(peer_pids[peer])
        _send(int(peer), {
            "t": "battle_start",
            "room_id": str(room["id"]),
            "you_pid": pid,
            "state": engine.public_state(),
            "turn": engine.legal_payload(pid),
            "config": engine.config,
            "turn_time": 0 if human_pids.size() <= 1 else int(room["turn_time"]),
            "round": engine.round_no,
            "ai_count": ai_n,
        })
    _begin_turn(battle, [])
    _push_rooms()


func _begin_turn(battle: Dictionary, pre_events: Array) -> void:
    if bool(battle.get("ended", false)):
        return
    var engine: BattleEngine = battle["engine"]
    _absorb_ai_memory(battle)
    battle["phase"] = "input"
    battle["token"] = int(battle["token"]) + 1
    battle["round"] = engine.round_no
    engine.auto_pass_silenced()
    var token := int(battle["token"])
    var rid := str(battle["room_id"])
    var wait := 0 if _active_human_count(battle) <= 1 else int(engine.config.get("turn_time", 10))
    for peer in battle["peer_pids"].keys():
        var pid := int(battle["peer_pids"][peer])
        var payload := engine.legal_payload(pid)
        payload["t"] = "battle_turn"
        payload["round"] = engine.round_no
        payload["players"] = engine.public_state()["players"]
        payload["events"] = pre_events
        payload["turn_time"] = wait
        _send(int(peer), payload)
    if not bool(battle["cheat"]):
        _submit_ai_all(battle, {})
    _submit_autopilot(battle)
    if wait > 0:
        var timer := get_tree().create_timer(float(wait) + 0.15)
        timer.timeout.connect(func(): _on_turn_timeout(rid, battle["round"], token))
    _maybe_resolve(battle)


func _active_human_count(battle: Dictionary) -> int:
    var n := 0
    for peer in battle["peer_pids"].keys():
        if battle["autopilot_pids"].has(int(battle["peer_pids"][peer])):
            continue
        n += 1
    return n


func _absorb_ai_memory(battle: Dictionary) -> void:
    # 把上一回合真人出牌喂给 AI 学习库，并刷新本回合的偏好权重。
    var engine: BattleEngine = battle["engine"]
    var obs := engine.take_observations()
    if obs.is_empty():
        return
    AiMemory.absorb(obs)
    engine.config["ai_bias"] = AiMemory.snapshot()
    battle["learned"] = int(battle.get("learned", 0)) + obs.size()


func _submit_ai_all(battle: Dictionary, peek: Dictionary) -> void:
    var engine: BattleEngine = battle["engine"]
    for pid in battle["ai_pids"]:
        if engine.choices.has(int(pid)) or not engine.needs_choice(int(pid)):
            continue
        _submit_ai_one(battle, int(pid), peek)


func _submit_autopilot(battle: Dictionary) -> void:
    var engine: BattleEngine = battle["engine"]
    for pid in battle["autopilot_pids"]:
        if engine.choices.has(int(pid)) or not engine.needs_choice(int(pid)):
            continue
        _submit_ai_one(battle, int(pid), {})


func _submit_ai_one(battle: Dictionary, pid: int, peek: Dictionary) -> void:
    var engine: BattleEngine = battle["engine"]
    var choice := engine.ai_choose(pid, peek)
    if bool(choice.get("ok", false)):
        engine.submit(pid, str(choice["card"]), int(choice.get("target", -1)),
                      choice.get("targets", []))
        return
    if not _fallback_choice(engine, pid):
        engine.force_pass(pid)


func _fallback_choice(engine: BattleEngine, pid: int) -> bool:
    var legal := engine.legal_cards(pid)
    for cid in legal:
        var card := Cards.get_card(str(cid))
        var ts := engine.valid_targets(pid, str(cid))
        if str(card.get("target", "")) == "enemies2" and ts.size() > 2:
            ts = [ts[0]]
        var target := -1 if ts.is_empty() else int(ts[0])
        var res := engine.submit(pid, str(cid), target, ts)
        if bool(res.get("ok", false)):
            return true
    return false


func _handle_battle_choose(peer: int, data: Dictionary) -> void:
    var battle := _battle_for_peer(peer)
    if battle.is_empty():
        _err(peer, "你不在对局中")
        return
    if str(battle["phase"]) != "input":
        _err(peer, "当前不能出牌")
        return
    var pid := int(battle["peer_pids"][peer])
    var engine: BattleEngine = battle["engine"]
    if engine.choices.has(pid):
        _err(peer, "本回合已经出过牌")
        return
    var res := engine.submit(pid, str(data.get("card", "")),
                             int(data.get("target", -1)),
                             data.get("targets", []))
    if not bool(res.get("ok", false)):
        _err(peer, str(res.get("reason", "出牌不合法")))
        return
    _send(peer, {"t": "battle_ack", "round": int(battle["round"])})
    _after_human_submit(battle)


func _after_human_submit(battle: Dictionary) -> void:
    if bool(battle["cheat"]):
        var all_humans := true
        for peer in battle["peer_pids"].keys():
            var pid := int(battle["peer_pids"][peer])
            var engine: BattleEngine = battle["engine"]
            if bool(engine.needs_choice(pid)) and not engine.choices.has(pid):
                all_humans = false
        if all_humans:
            _submit_ai_all(battle, _human_peek(battle))
    _maybe_resolve(battle)


func _human_peek(battle: Dictionary) -> Dictionary:
    var engine: BattleEngine = battle["engine"]
    for pid in battle["human_pids"].keys():
        if battle["autopilot_pids"].has(int(pid)):
            continue
        if engine.choices.has(int(pid)):
            var ch: Dictionary = engine.choices[int(pid)]
            if not bool(ch.get("pass", true)) and str(ch.get("card", "")) != "":
                return {"card": str(ch["card"]), "target": int(ch.get("target", -1)), "from": int(pid)}
    return {}


func _on_turn_timeout(room_id: String, round_no: int, token: int) -> void:
    var battle: Dictionary = battles.get(room_id, {})
    if battle.is_empty() or bool(battle.get("ended", false)):
        return
    if str(battle["phase"]) != "input" or int(battle["round"]) != round_no or int(battle["token"]) != token:
        return
    var engine: BattleEngine = battle["engine"]
    for peer in battle["peer_pids"].keys():
        var pid := int(battle["peer_pids"][peer])
        if battle["autopilot_pids"].has(pid):
            continue
        if not engine.needs_choice(pid) or engine.choices.has(pid):
            continue
        var c := engine.ai_choose(pid, {})
        if bool(c.get("ok", false)):
            engine.submit(pid, str(c["card"]), int(c.get("target", -1)), c.get("targets", []))
        else:
            if not _fallback_choice(engine, pid):
                engine.force_pass(pid)
            _send(int(peer), {"t": "error", "msg": "超时，已自动出牌"})
    if bool(battle["cheat"]):
        _submit_ai_all(battle, _human_peek(battle))
    _submit_autopilot(battle)
    _maybe_resolve(battle)


func _maybe_resolve(battle: Dictionary) -> void:
    if battle.is_empty() or str(battle["phase"]) != "input":
        return
    var engine: BattleEngine = battle["engine"]
    if not engine.all_submitted():
        return
    battle["phase"] = "resolving"
    var result := engine.resolve_round()
    var rid := str(battle["room_id"])
    for peer in battle["peer_pids"].keys():
        var out := result.duplicate(true)
        out["t"] = "battle_reveal"
        out["room_id"] = rid
        out["turn_time"] = int(engine.config.get("turn_time", 10))
        _send(int(peer), out)
    if bool(result["finished"]):
        _finish_battle(battle, result)
        return
    var token := int(battle["token"])
    var timer := get_tree().create_timer(2.4)
    timer.timeout.connect(func():
        if not battles.has(rid):
            return
        var b: Dictionary = battles[rid]
        if str(b["phase"]) != "resolving" or int(b["token"]) != token or bool(b.get("ended", false)):
            return
        var adv := engine.advance_round()
        if bool(adv["finished"]) or int(engine.winner_team) >= 0:
            var end := {"finished": true, "winner_team": engine.winner_team,
                        "players": engine.public_state()["players"], "events": adv["events"],
                        "round": engine.round_no}
            _finish_battle(b, end)
        else:
            _begin_turn(b, adv["events"]))


func _apply_ranks(battle: Dictionary, result: Dictionary) -> void:
    # 段位只统计真人 PvP：至少 2 名真人参战，人机/单机对局不计。
    var humans: Dictionary = battle["human_pids"]
    var winner := int(result.get("winner_team", -1))
    if winner < 0 or humans.size() < 2:
        return
    var engine: BattleEngine = battle["engine"]
    var changed := false
    for pid in humans.keys():
        var peer := int(humans[pid])
        var hwid := str(online.get(peer, ""))
        if hwid == "":
            continue
        var acc := _acc_by_hwid(hwid)
        if acc.is_empty():
            continue
        var win := int(engine.players[int(pid)]["team"]) == winner
        var res := Rank.apply_result(acc.get("rank", {}), win)
        acc["rank"] = res["rank"]
        changed = true
        _send(peer, {"t": "rank", "rank": res["rank"], "delta": str(res["delta"]),
                     "label": Rank.label(res["rank"]), "placed_now": bool(res["placed_now"])})
    if changed:
        store.save()


func _finish_battle(battle: Dictionary, result: Dictionary) -> void:
    if bool(battle.get("ended", false)):
        return
    battle["ended"] = true
    battle["phase"] = "ended"
    var rid := str(battle["room_id"])
    _absorb_ai_memory(battle)
    AiMemory.flush()
    for peer in battle["peer_pids"].keys():
        _send(int(peer), {"t": "battle_end", "room_id": rid,
                          "winner_team": int(result.get("winner_team", -1)),
                          "players": result.get("players", []),
                          "events": result.get("events", [])})
    _apply_ranks(battle, result)
    var timer := get_tree().create_timer(4.0)
    timer.timeout.connect(func():
        if not battles.has(rid):
            return
        battles.erase(rid)
        var room: Dictionary = rooms.get(rid, {})
        if room.is_empty():
            return
        room["state"] = "lobby"
        room["ai_count"] = 0
        for m in room["members"]:
            m["ready"] = false
        _broadcast_room(room)
        _push_rooms())


# ---------------------------------------------------------------- battle/room helpers
func _battle_for_peer(peer: int) -> Dictionary:
    for rid in battles.keys():
        var b: Dictionary = battles[rid]
        if b["peer_pids"].has(peer):
            return b
    return {}


func _room_of_peer(peer: int) -> Dictionary:
    for rid in rooms.keys():
        var room: Dictionary = rooms[rid]
        for m in room["members"]:
            if int(m["peer"]) == peer:
                return room
    return {}


func _room_of_hwid(hwid: String) -> Dictionary:
    for rid in rooms.keys():
        var room: Dictionary = rooms[rid]
        for m in room["members"]:
            if str(m["hwid"]) == hwid:
                return room
    return {}


func _room_payload(room: Dictionary) -> Dictionary:
    var out := {}
    for k in ["id", "host_peer", "host_hwid", "public", "max_players", "ai_fill",
              "turn_time", "friendly_fire", "cheat_mode", "state", "ai_count"]:
        out[k] = room.get(k)
    out["members"] = []
    for m in room["members"]:
        var mm: Dictionary = m.duplicate(true)
        mm["is_host"] = int(m["peer"]) == int(room["host_peer"])
        out["members"].append(mm)
    out["host_name"] = ""
    var ha := _acc_by_hwid(str(room["host_hwid"]))
    if not ha.is_empty():
        out["host_name"] = str(ha.get("name", ""))
    return out


func _broadcast_room(room: Dictionary) -> void:
    for m in room["members"]:
        _send(int(m["peer"]), {"t": "room", "room": _room_payload(room)})


func _public_rooms() -> Array:
    var out: Array = []
    for rid in rooms.keys():
        var room: Dictionary = rooms[rid]
        if str(room["state"]) != "lobby":
            continue
        if not bool(room["public"]):
            continue
        var host_name := ""
        var ha := _acc_by_hwid(str(room["host_hwid"]))
        if not ha.is_empty():
            host_name = str(ha.get("name", ""))
        out.append({
            "id": str(room["id"]),
            "host_name": host_name,
            "count": room["members"].size(),
            "max_players": int(room["max_players"]),
            "ai_fill": bool(room["ai_fill"]),
            "turn_time": int(room["turn_time"]),
            "friendly_fire": bool(room["friendly_fire"]),
            "cheat_mode": bool(room["cheat_mode"]),
            "state": str(room["state"]),
            "public": bool(room["public"]),
        })
    out.sort_custom(func(a, b): return str(a["id"]) < str(b["id"]))
    return out


func _push_rooms() -> void:
    for peer in online.keys():
        _send(int(peer), {"t": "rooms", "rooms": _public_rooms()})


func _handle_room_kick(peer: int, data: Dictionary) -> void:
    var room := _room_of_peer(peer)
    if room.is_empty():
        return
    if int(room["host_peer"]) != peer:
        _err(peer, "只有房主能踢人")
        return
    var target := int(data.get("peer", 0))
    if target == peer:
        _err(peer, "不能踢自己")
        return
    _remove_member(room, target, "kick")
    _push_rooms()


func _handle_room_leave(peer: int) -> void:
    var room := _room_of_peer(peer)
    if room.is_empty():
        _send(peer, {"t": "room_left"})
        return
    _remove_member(room, peer, "leave")
    _push_rooms()


func _remove_member(room: Dictionary, peer: int, reason: String) -> void:
    var idx := -1
    for i in room["members"].size():
        if int(room["members"][i]["peer"]) == peer:
            idx = i
            break
    if idx < 0:
        return
    var m: Dictionary = room["members"][idx]
    var hwid := str(m["hwid"])
    room["members"].remove_at(idx)
    var battle: Dictionary = battles.get(str(room["id"]), {})
    if not battle.is_empty() and not bool(battle.get("ended", false)):
        _auto_pilot_hwid(battle, hwid)
    if reason == "kick":
        _send(peer, {"t": "kicked"})
    else:
        _send(peer, {"t": "room_left"})
    if room["members"].is_empty():
        _close_room(room, battle)
        return
    if int(room["host_peer"]) == peer:
        room["host_peer"] = int(room["members"][0]["peer"])
        room["host_hwid"] = str(room["members"][0]["hwid"])
        for mm in room["members"]:
            mm["is_host"] = int(mm["peer"]) == int(room["host_peer"])
    _broadcast_room(room)
    if not battle.is_empty():
        _broadcast_reveal_state(battle)


func _close_room(room: Dictionary, battle: Dictionary) -> void:
    var rid := str(room["id"])
    for m in room["members"]:
        _send(int(m["peer"]), {"t": "room_closed"})
    rooms.erase(rid)
    if not battle.is_empty():
        battles.erase(rid)
    for hwid in pending_invites.keys():
        var inv: Dictionary = pending_invites[hwid]
        if str(inv.get("room_id", "")) == rid:
            pending_invites.erase(hwid)
    _push_rooms()


func _auto_pilot_or_remove(room: Dictionary, peer: int, hwid: String) -> void:
    var battle: Dictionary = battles.get(str(room["id"]), {})
    if not battle.is_empty() and not bool(battle.get("ended", false)):
        _auto_pilot_hwid(battle, hwid)
    _remove_member(room, peer, "disconnect")


func _auto_pilot_hwid(battle: Dictionary, hwid: String) -> void:
    var engine: BattleEngine = battle["engine"]
    for pid in battle["human_pids"].keys():
        var peer := int(battle["human_pids"][pid])
        var acc := _acc(peer)
        if str(acc.get("hwid", "")) == hwid or (acc.is_empty() and not online.has(peer)):
            if not battle["autopilot_pids"].has(int(pid)):
                battle["autopilot_pids"].append(int(pid))
            battle["peer_pids"].erase(peer)
            battle["human_pids"].erase(pid)
            engine.players[int(pid)]["disconnected"] = true
            engine.players[int(pid)]["is_ai"] = true
            return


func _broadcast_reveal_state(battle: Dictionary) -> void:
    var engine: BattleEngine = battle["engine"]
    var state := engine.public_state()
    for peer in battle["peer_pids"].keys():
        _send(int(peer), {"t": "battle_players", "room_id": str(battle["room_id"]),
                          "players": state["players"], "round": engine.round_no,
                          "finished": engine.finished, "winner_team": engine.winner_team})


# ---------------------------------------------------------------- invites
func _handle_friend_invite(peer: int, data: Dictionary) -> void:
    var acc := _acc(peer)
    if acc.is_empty():
        return
    var target_hwid := str(data.get("hwid", ""))
    if not acc["friends"].has(target_hwid):
        _err(peer, "只能邀请好友")
        return
    var target := _acc_by_hwid(target_hwid)
    if target.is_empty():
        _err(peer, "好友账号不存在")
        return
    var room := _room_of_peer(peer)
    if room.is_empty():
        room = _create_inviter_room(peer, acc)
    elif int(room["host_peer"]) != peer:
        if str(room["state"]) != "lobby":
            _err(peer, "对局进行中不能邀请")
            return
        _remove_member(room, peer, "leave")
        room = _create_inviter_room(peer, acc)
    else:
        if str(room["state"]) != "lobby":
            _err(peer, "对局进行中不能邀请")
            return
        if room["members"].size() >= int(room["max_players"]):
            _err(peer, "房间已满")
            return
    var inv := {
        "room_id": str(room["id"]),
        "from_hwid": str(acc["hwid"]),
        "from_name": str(acc.get("name", "")),
        "created": Time.get_ticks_msec(),
    }
    pending_invites[target_hwid] = inv
    var tp := int(hwid_peer.get(target_hwid, 0))
    if tp > 0:
        _send(tp, {"t": "invite", "room_id": str(room["id"]),
                   "from_name": str(acc.get("name", "")), "from_hwid": str(acc["hwid"])})
    _push_rooms()


func _create_inviter_room(peer: int, acc: Dictionary) -> Dictionary:
    var rid := _new_room_id()
    var room := {
        "id": rid, "host_peer": peer, "host_hwid": str(acc["hwid"]),
        "state": "lobby", "members": [], "ai_count": 0,
    }
    room.merge(_default_settings(), true)
    room["members"].append(_member_for(peer, acc, true))
    rooms[rid] = room
    _send(peer, {"t": "room", "room": _room_payload(room)})
    return room


func target_hwid_to_peer(hwid: String) -> int:
    return int(hwid_peer.get(hwid, 0))


func _send_pending_invite(peer: int, hwid: String) -> void:
    var inv: Dictionary = pending_invites.get(hwid, {})
    if inv.is_empty():
        return
    if Time.get_ticks_msec() - int(inv.get("created", 0)) > 600000:
        pending_invites.erase(hwid)
        return
    _send(peer, {"t": "invite", "room_id": str(inv["room_id"]),
                 "from_name": str(inv["from_name"]), "from_hwid": str(inv["from_hwid"])})


func _handle_invite_respond(peer: int, data: Dictionary) -> void:
    var acc := _acc(peer)
    if acc.is_empty():
        return
    var hwid := str(acc["hwid"])
    var inv: Dictionary = pending_invites.get(hwid, {})
    if inv.is_empty():
        _err(peer, "邀请已失效")
        return
    if not bool(data.get("accept", false)):
        pending_invites.erase(hwid)
        _send(peer, {"t": "error", "msg": "已拒绝邀请"})
        return
    var rid := str(inv["room_id"])
    var room: Dictionary = rooms.get(rid, {})
    if room.is_empty():
        pending_invites.erase(hwid)
        _err(peer, "房间已不存在")
        return
    if str(room["state"]) != "lobby":
        _err(peer, "对局已开始")
        return
    if room["members"].size() >= int(room["max_players"]):
        _err(peer, "房间已满")
        return
    var old := _room_of_peer(peer)
    if not old.is_empty() and str(old["id"]) != rid:
        _remove_member(old, peer, "leave")
    if not room["members"].any(func(m): return int(m["peer"]) == peer):
        room["members"].append(_member_for(peer, acc, false))
    pending_invites.erase(hwid)
    _send(peer, {"t": "room", "room": _room_payload(room)})
    _broadcast_room(room)
    _push_rooms()


# ---------------------------------------------------------------- serialization guard
func _send_room_event(peer: int, room: Dictionary) -> void:
    _send(peer, {"t": "room", "room": _room_payload(room)})
