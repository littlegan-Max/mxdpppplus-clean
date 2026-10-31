extends SceneTree

var failures := 0
var checks := 0


func _init() -> void:
    print("== mxdpppplus engine tests ==")
    test_card_db()
    test_round1()
    test_equal_damage_cancel()
    test_higher_damage_wins()
    test_zhongfang_block()
    test_new_awaken_reflect()
    test_new_awaken_heart_despise()
    test_new_scatter_space()
    test_new_scatter_time()
    test_shield()
    test_shield_two_required()
    test_despise_silence()
    test_heart_floor()
    test_final_pinch_steals_yun()
    test_turtle()
    test_suicide_turtle()
    test_rewind()
    test_sneak_dot()
    test_wine_revive()
    test_sweep_global_block()
    test_double_dart_single()
    test_prism_k()
    test_combo_requirement()
    test_god_turtle_double()
    test_old_awaken_true()
    test_poison_yun()
    test_suicide_shield()
    test_six_god_true()
    test_duel_shield_clear()
    test_peach_removes_time()
    test_borrow_body()
    test_amulet_discount()
    test_rank_placement()
    test_rank_progress()
    test_ai_memory_context()
    print("== %d checks, %d failures ==" % [checks, failures])
    quit(1 if failures > 0 else 0)


func check(cond: bool, name: String, detail: String = "") -> void:
    checks += 1
    if not cond:
        failures += 1
        print("FAIL: ", name, "  ", detail)
    else:
        print("ok: ", name)


func new_battle(n: int = 2, teams: Array = []) -> BattleEngine:
    var e := BattleEngine.new()
    var specs: Array = []
    for i in n:
        var t := i % 2
        if teams.size() > i:
            t = int(teams[i])
        elif n > 2:
            t = 0 if i < int(ceil(n / 2.0)) else 1
        specs.append({"name": "P%d" % i, "team": t, "avatar": i % 8})
    e.setup(specs, {"friendly_fire": false, "turn_time": 10})
    return e


func round1(e: BattleEngine) -> void:
    for i in e.players.size():
        e.submit(i, "yun")
    e.resolve_round()
    e.advance_round()


func test_card_db() -> void:
    check(Cards.all().size() == 61, "card count == 61", str(Cards.all().size()))
    check(Cards.get_card("new_awaken_zhongfang").cost_t == 10, "new awaken cost 1")
    check(Cards.get_card("new_long_attack_scatter").damage_t == 24, "new scatter 2.4")
    check(Cards.get_card("new_long_attack_scatter").block_by.has("负运"), "new scatter block by negative luck")


func test_round1() -> void:
    var e := new_battle()
    check(e.legal_cards(0) == ["yun"], "round 1 only yun", str(e.legal_cards(0)))
    round1(e)
    check(e.players[0]["luck_t"] == 10 and e.players[1]["luck_t"] == 10, "yun +1 each")


func test_equal_damage_cancel() -> void:
    var e := new_battle()
    round1(e)
    e.players[0]["luck_t"] = 30
    e.players[1]["luck_t"] = 30
    e.submit(0, "kaiser", 1)
    e.submit(1, "kaiser", 0)
    var r := e.resolve_round()
    check(e.players[0]["hp_t"] == 10 and e.players[1]["hp_t"] == 10, "equal damage cancels", str(e.players[0]["hp_t"]))
    check(e.players[0]["luck_t"] == 10 and e.players[1]["luck_t"] == 10, "costs still paid")


func test_higher_damage_wins() -> void:
    var e := new_battle()
    round1(e)
    e.players[0]["luck_t"] = 40
    e.players[1]["luck_t"] = 30
    e.submit(0, "long_attack", 1)
    e.submit(1, "small_dart", 0)
    e.resolve_round()
    check(e.players[1]["hp_t"] == -12, "2.2 only applies", str(e.players[1]["hp_t"]))
    check(e.players[1]["alive"] == false, "target dies")


func test_zhongfang_block() -> void:
    var e := new_battle()
    round1(e)
    e.players[0]["luck_t"] = 30
    e.submit(0, "kaiser", 1)
    e.submit(1, "zhongfang", 0)
    e.resolve_round()
    check(e.players[0]["hp_t"] == 10 and e.players[1]["hp_t"] == 10, "zhongfang blocks")


func test_new_awaken_reflect() -> void:
    var e := new_battle()
    round1(e)
    e.players[0]["luck_t"] = 30
    e.players[1]["luck_t"] = 20
    e.submit(0, "new_long_attack_scatter", 1)
    e.submit(1, "new_awaken_zhongfang", 0)
    var r := e.resolve_round()
    check(e.players[1]["hp_t"] == 10, "new awaken blocks 2.4", str(e.players[1]["hp_t"]))
    check(e.players[0]["hp_t"] == 2, "reflect capped at 0.8", str(e.players[0]["hp_t"]))
    check(e.players[1]["luck_t"] == 10, "new awaken costs 1")


func test_new_awaken_heart_despise() -> void:
    var e := new_battle()
    round1(e)
    e.players[0]["luck_t"] = 30
    e.players[1]["luck_t"] = 20
    e.submit(0, "heart", 1)
    e.submit(1, "new_awaken_zhongfang", 0)
    e.resolve_round()
    check(e.players[0]["luck_t"] == 0, "heart reflected: attacker -1", str(e.players[0]["luck_t"]))
    check(e.players[1]["luck_t"] == 10, "target luck unaffected")
    e.advance_round()
    e.players[0]["luck_t"] = 30
    e.submit(0, "despise", 1)
    e.submit(1, "new_awaken_zhongfang", 0)
    e.resolve_round()
    check(e.players[1]["silenced_round"] == 0, "despise blocked")
    check(e.players[0]["forced_card"] == "zhongfang", "despise reflected to forced zhongfang")


func test_new_scatter_space() -> void:
    var e := new_battle(4, [0, 0, 1, 1])
    round1(e)
    e.players[0]["luck_t"] = 30
    e.players[2]["luck_t"] = 0
    e.submit(0, "new_long_attack_scatter", 2)
    e.submit(1, "zhongfang", 0)
    e.submit(2, "zhongfang", 0)
    e.submit(3, "yun", 0)
    e.resolve_round()
    check(e.players[2]["hp_t"] == 5, "blocked target still -0.5", str(e.players[2]["hp_t"]))
    check(e.players[3]["hp_t"] == 5, "neighbor splash -0.5", str(e.players[3]["hp_t"]))
    check(e.players[0]["hp_t"] == 10, "attacker unaffected")


func test_new_scatter_time() -> void:
    var e := new_battle()
    round1(e)
    e.players[0]["luck_t"] = 30
    e.submit(0, "new_long_attack_scatter", 1)
    e.submit(1, "absorb", 0)
    e.resolve_round()
    check(e.players[1]["hp_t"] == 10, "absorbed no damage")
    check(e.players[1]["luck_t"] == 40, "absorbed 3 luck")
    check(e.players[1]["statuses"].size() > 0, "time dispersion applied", str(e.players[1]["statuses"]))
    e.advance_round()
    check(e.players[1]["hp_t"] == 6, "time dispersion -0.4", str(e.players[1]["hp_t"]))


func test_shield() -> void:
    var e := new_battle()
    round1(e)
    e.players[1]["shield"] = 1
    e.players[0]["luck_t"] = 20
    e.submit(0, "kaiser", 1)
    e.submit(1, "yun", 0)
    e.resolve_round()
    check(e.players[1]["hp_t"] == 10, "shield keeps pre-hit hp", str(e.players[1]["hp_t"]))
    check(e.players[1]["shield"] == 0, "shield consumed")


func test_shield_two_required() -> void:
    var e := new_battle()
    round1(e)
    e.players[1]["shield"] = 1
    e.players[0]["luck_t"] = 70
    e.submit(0, "cannon", 1)
    e.submit(1, "yun", 0)
    e.resolve_round()
    check(e.players[1]["alive"] == false, "1 shield cannot block cannon", str(e.players[1]["hp_t"]))
    check(e.players[1]["shield"] == 1, "shield not consumed")


func test_despise_silence() -> void:
    var e := new_battle()
    round1(e)
    e.players[0]["luck_t"] = 30
    e.submit(0, "despise", 1)
    e.submit(1, "yun", 0)
    e.resolve_round()
    check(e.players[1]["silenced_round"] == 3, "silenced next round", str(e.players[1]["silenced_round"]))
    e.advance_round()
    check(e.legal_cards(1).is_empty(), "no legal cards while silenced")
    check(e.players[1]["history"].is_empty(), "combo cleared")


func test_heart_floor() -> void:
    var e := new_battle()
    round1(e)
    e.players[0]["luck_t"] = 30
    e.players[1]["luck_t"] = -20
    e.submit(0, "heart", 1)
    e.submit(1, "yun", 0)
    e.resolve_round()
    check(e.players[1]["luck_t"] == -20, "heart floor -3 (then yun +1)", str(e.players[1]["luck_t"]))
    check(e.players[1]["hp_t"] == 10, "heart no damage")


func test_final_pinch_steals_yun() -> void:
    var e := new_battle()
    round1(e)
    e.players[0]["luck_t"] = 20
    e.submit(0, "final_pinch", 1)
    e.submit(1, "yun", 0)
    var r := e.resolve_round()
    check(e.players[1]["hp_t"] == 10, "final pinch blocked")
    check(e.players[0]["luck_t"] == 10, "steals yun", str(e.players[0]["luck_t"]))
    check(e.players[1]["luck_t"] == 10, "defender keeps yun? (round1 had 1)", str(e.players[1]["luck_t"]))


func test_turtle() -> void:
    var e := new_battle()
    round1(e)
    e.players[0]["history"] = ["zhongfang", "absorb", "yun"]
    e.players[0]["luck_t"] = 20
    e.players[1]["luck_t"] = 20
    e.submit(0, "turtle", 1)
    e.submit(1, "kaiser", 0)
    e.resolve_round()
    check(e.players[1]["hp_t"] == -5, "turtle converts kaiser", str(e.players[1]["hp_t"]))


func test_suicide_turtle() -> void:
    var e := new_battle()
    round1(e)
    e.players[0]["history"] = ["zhongfang", "absorb", "yun"]
    e.submit(0, "turtle", 1)
    e.submit(1, "suicide", 0)
    e.resolve_round()
    check(e.players[0]["alive"] == false, "turtle user dies")
    check(e.players[1]["alive"] == true, "suicide user survives")


func test_rewind() -> void:
    var e := new_battle()
    round1(e)
    e.players[0]["luck_t"] = 30
    e.players[1]["luck_t"] = 20
    e.submit(0, "rewind", 0)
    e.submit(1, "kaiser", 0)
    e.resolve_round()
    check(e.players[0]["hp_t"] == 10 and e.players[1]["hp_t"] == 10, "rewind nullifies all")
    check(e.players[0]["luck_t"] == 0 and e.players[1]["luck_t"] == 0, "costs still paid")
    check(e.players[0]["history"].is_empty(), "combos reset by rewind")


func test_sneak_dot() -> void:
    var e := new_battle()
    round1(e)
    e.players[0]["luck_t"] = 30
    e.submit(0, "sneak", 1)
    e.submit(1, "yun", 0)
    e.resolve_round()
    check(e.players[1]["statuses"].size() > 0, "sneak applied")
    e.advance_round()
    check(e.players[1]["hp_t"] == 8, "sneak tick -0.2", str(e.players[1]["hp_t"]))


func test_wine_revive() -> void:
    var e := new_battle()
    round1(e)
    e.players[0]["luck_t"] = 30
    e.players[1]["hp_t"] = 0
    e.players[1]["alive"] = false
    e.players[1]["death_round"] = 1
    e.submit(0, "wine", 1)
    e.submit(1, "", -1)
    e.resolve_round()
    check(e.players[1]["alive"] == true, "wine revives")
    check(e.players[1]["hp_t"] == 4, "wine revive 0.4hp", str(e.players[1]["hp_t"]))
    check(e.players[1]["luck_t"] == 10, "wine revive 1 luck")


func test_sweep_global_block() -> void:
    var e := new_battle(4, [0, 0, 1, 1])
    round1(e)
    e.players[0]["luck_t"] = 40
    e.submit(0, "sweep_earth", 0)
    e.submit(1, "yun", 0)
    e.players[2]["history"] = ["zhongfang"]
    e.submit(2, "dive", 0)
    e.submit(3, "yun", 0)
    e.resolve_round()
    check(e.players[2]["hp_t"] == 10 and e.players[3]["hp_t"] == 10, "dive blocks sweep for all")


func test_double_dart_single() -> void:
    var e := new_battle()
    round1(e)
    e.players[0]["luck_t"] = 30
    e.players[0]["history"] = []
    var check_use := e.can_use(0, "double_dart", 1, [1])
    check(not check_use["ok"], "double dart illegal in 1v1", str(check_use))
    var e2 := new_battle(4, [0, 0, 1, 1])
    round1(e2)
    e2.players[0]["luck_t"] = 30
    e2.submit(0, "double_dart", 2, [2])
    e2.submit(1, "yun", 0)
    e2.submit(2, "yun", 0)
    e2.submit(3, "yun", 0)
    e2.resolve_round()
    check(e2.players[2]["hp_t"] == -11, "single-target 2.1", str(e2.players[2]["hp_t"]))


func test_prism_k() -> void:
    var e := new_battle()
    round1(e)
    e.players[0]["luck_t"] = 30
    e.players[1]["luck_t"] = 30
    e.submit(0, "prism", 1)
    e.submit(1, "yun", 0)
    e.resolve_round()
    check(e.players[1]["hp_t"] == 3, "prism k=1 damage 0.7", str(e.players[1]["hp_t"]))


func test_combo_requirement() -> void:
    var e := new_battle()
    round1(e)
    check(not e.can_use(0, "dive", 1)["ok"], "dive requires zhongfang")
    e.players[0]["history"] = ["zhongfang"]
    e.players[0]["luck_t"] = 10
    check(e.can_use(0, "dive", 1)["ok"], "dive legal after zhongfang")


func test_god_turtle_double() -> void:
    var e := new_battle()
    round1(e)
    e.players[0]["history"] = ["awaken_zhongfang", "super_absorb", "strong_yun"]
    e.players[1]["luck_t"] = 20
    e.submit(0, "god_turtle", 1)
    e.submit(1, "kaiser", 0)
    e.resolve_round()
    check(e.players[1]["hp_t"] == -20, "god turtle doubles damage", str(e.players[1]["hp_t"]))


func test_old_awaken_true() -> void:
    var e := new_battle()
    round1(e)
    e.players[0]["luck_t"] = 50
    e.players[1]["luck_t"] = 10
    e.submit(0, "six_god", 1)
    e.submit(1, "awaken_zhongfang", 0)
    e.resolve_round()
    check(e.players[1]["hp_t"] == 5, "true 0.5 through old awaken", str(e.players[1]["hp_t"]))
    check(e.players[0]["hp_t"] == 5, "old awaken reflects 0.5", str(e.players[0]["hp_t"]))


func test_poison_yun() -> void:
    var e := new_battle()
    round1(e)
    e.players[0]["luck_t"] = 20
    e.submit(0, "poison", 1)
    e.submit(1, "yun", 0)
    e.resolve_round()
    check(e.players[1]["hp_t"] == 7, "poison blocked by yun still 40%", str(e.players[1]["hp_t"]))


func test_suicide_shield() -> void:
    var e := new_battle()
    round1(e)
    e.players[0]["shield"] = 1
    e.players[0]["luck_t"] = 10
    e.submit(0, "suicide", 0)
    e.submit(1, "yun", 0)
    e.resolve_round()
    check(e.players[0]["alive"] == true, "shield blocks suicide code kill")
    check(e.players[0]["shield"] == 0, "shield consumed by code kill")


func test_six_god_true() -> void:
    var e := new_battle()
    round1(e)
    e.players[0]["luck_t"] = 50
    e.submit(0, "six_god", 1)
    e.submit(1, "yun", 0)
    e.resolve_round()
    check(e.players[1]["hp_t"] == 5, "six god yun block leaves 0.5 true", str(e.players[1]["hp_t"]))


func test_duel_shield_clear() -> void:
    var e := new_battle(4, [0, 0, 1, 1])
    round1(e)
    e.players[0]["luck_t"] = 40
    e.players[2]["shield"] = 1
    e.submit(0, "duel", 2)
    e.submit(1, "yun", 0)
    e.submit(2, "yun", 0)
    e.submit(3, "yun", 0)
    e.resolve_round()
    check(e.players[2]["shield"] == 0, "duel clears shields", str(e.players[2]["shield"]))
    check(e.players[2]["alive"] == true, "duel with shield does not kill")
    check(e.players[0]["alive"] == true, "duel user unharmed")


func test_peach_removes_time() -> void:
    var e := new_battle()
    round1(e)
    e.players[0]["luck_t"] = 30
    e.submit(0, "new_long_attack_scatter", 1)
    e.submit(1, "absorb", 0)
    e.resolve_round()
    check(e.players[1]["statuses"].size() > 0, "time status exists")
    e.advance_round()
    e.players[0]["luck_t"] = 10
    e.submit(0, "yun", 0)
    e.submit(1, "peach", 1)
    e.resolve_round()
    check(e.players[1]["statuses"].is_empty(), "peach removes time dispersion")


func test_borrow_body() -> void:
    var e := new_battle()
    round1(e)
    e.players[1]["hp_t"] = 0
    e.players[1]["alive"] = false
    e.players[1]["death_round"] = 1
    e.players[1]["death_cause"] = "damage"
    e.players[1]["luck_t"] = 60
    e.players[0]["luck_t"] = 10
    var c := e.can_use(1, "borrow_body", 0)
    check(bool(c.get("ok", false)), "dead player can borrow within 3 rounds", str(c))
    e.submit(0, "yun", 0)
    e.submit(1, "borrow_body", 0)
    e.resolve_round()
    check(e.players[1]["alive"] == true, "borrow user revived")
    check(e.players[1]["hp_t"] == 10, "borrow inherits target hp", str(e.players[1]["hp_t"]))
    check(e.players[0]["alive"] == false, "borrow target dies")


func test_amulet_discount() -> void:
    var e := new_battle()
    round1(e)
    e.players[0]["luck_t"] = 30
    e.players[0]["cost_half"] = true
    e.players[1]["luck_t"] = 10
    e.submit(0, "kaiser", 1)
    e.submit(1, "amulet", 0)
    e.resolve_round()
    check(e.players[1]["hp_t"] == -5, "1-cost kaiser not blocked by 2~3 amulet", str(e.players[1]["hp_t"]))


func test_rank_placement() -> void:
    var r := Rank.default_rank()
    check(Rank.label(r) == "青铜 III · 0 星", "default rank label", Rank.label(r))
    for i in 5:
        r = Rank.apply_result(r, true)["rank"]
    check(int(r["games"]) == 5 and int(r["wins"]) == 5, "placement 5 wins counted")
    check(bool(r["placed"]), "placed after 5 games")
    check(Rank.label(r) == "黄金 II · 1 星", "5 wins places at gold II", Rank.label(r))
    check(Rank.win_rate_text(r) == "胜率 100%（5/5）", "win rate text", Rank.win_rate_text(r))


func test_rank_progress() -> void:
    var r := Rank.default_rank()
    r["games"] = 5
    r["wins"] = 2
    r["placed"] = true
    r["tier"] = 0
    r["div"] = 0
    r["stars"] = 1
    var win := Rank.apply_result(r, true)
    check(int(win["rank"]["stars"]) == 2, "win adds a star", str(win["rank"]["stars"]))
    var loss1 := Rank.apply_result(win["rank"], false)
    check(int(loss1["rank"]["stars"]) == 1, "loss removes a star", str(loss1["rank"]["stars"]))
    var loss2 := Rank.apply_result(loss1["rank"], false)
    check(int(loss2["rank"]["stars"]) == 0, "second loss empties stars", str(loss2["rank"]["stars"]))
    var floor_loss := Rank.apply_result(loss2["rank"], false)
    check(int(floor_loss["rank"]["tier"]) == 0 and int(floor_loss["rank"]["div"]) == 0,
          "bronze III 0 star protected", Rank.label(floor_loss["rank"]))


func test_ai_memory_context() -> void:
    check(AiMemory.context_key(10, 0, 1) == "early|ok|poor", "ctx early/poor",
          AiMemory.context_key(10, 0, 1))
    check(AiMemory.context_key(3, 80, 9) == "late|low|rich", "ctx late/low/rich",
          AiMemory.context_key(3, 80, 9))
    check(AiMemory.context_key(8, 40, 5) == "mid|ok|mid", "ctx mid",
          AiMemory.context_key(8, 40, 5))
