class_name Cards
extends RefCounted

## Full card database. Costs and damage are stored in tenths (10 = 1.0)
## to keep every rule value exact (0.2, 0.4, 0.9, 2.4 ...).

const T := 10

static var _cards: Dictionary = {}


static func _add(id: String, name: String, cost_t: int, block_by: Array, kind: String,
        desc: String, extra: Dictionary = {}) -> void:
    var d := {
        "id": id,
        "name": name,
        "cost_t": cost_t,
        "block_by": block_by,
        "kind": kind,
        "desc": desc,
        "note": "",
        "icon": "star",
        "target": "enemy",
        "damage_t": 0,
        "true_t": 0,
        "heal_t": 0,
        "gain_t": 0,
        "shield_require": 0,
        "cooldown": 0,
        "cooldown_group": "",
        "requires": [],
        "uses": 0,
        "multi_only": false,
        "tags": [],
    }
    d.merge(extra, true)
    _cards[id] = d


static func _build() -> void:
    _add("yun", "运", 0, [], "buff", "+1 运", {"target": "self", "icon": "luck", "gain_t": 10})
    _add("zhongfang", "中防", 0, [], "defense", "挡下「可被」列含中防的攻击", {"target": "self", "icon": "block"})
    _add("absorb", "吸", 0, [], "defense", "吸运/吸攻击；吸到的运=对方卡费（有特例）",
            {"target": "self", "icon": "absorb", "cooldown": 1, "cooldown_group": "absorb"})
    _add("small_pinch", "小掐", 0, [], "attack", "无伤害；秒杀乃爆", {"icon": "skull", "tags": ["pinch"]})
    _add("super_pinch", "超掐", 10, ["运"], "attack", "-0.5；秒杀乃爆",
            {"icon": "skull", "damage_t": 5, "tags": ["pinch", "offset_yun"], "note": "运挡为抵消"})
    _add("small_dart", "小镖", 10, ["中防", "吸"], "attack", "-1", {"icon": "dart", "damage_t": 10})
    _add("dragon", "降龙", 0, ["吸"], "attack", "-1；被吸则吸的人+2运",
            {"icon": "dragon", "damage_t": 10, "requires": ["zhongfang"], "note": "0，中防后；被吸+2运"})
    _add("dive", "降飞", 0, ["运", "吸"], "attack", "-1.2；被吸则吸的人+2运",
            {"icon": "dragon", "damage_t": 12, "requires": ["zhongfang"], "note": "0，中防后；运挡后还在"})
    _add("kaiser", "凯撒", 20, ["中防"], "attack", "-1.5", {"icon": "dart", "damage_t": 15})
    _add("explode", "乃爆", 20, ["吸", "小掐", "超掐"], "attack", "-2；被掐秒杀（代码杀）",
            {"icon": "bomb", "damage_t": 20})
    _add("long_attack", "长攻", 30, ["中防"], "attack", "-2.2", {"icon": "sweep", "damage_t": 22})
    _add("long_attack_scatter", "长攻分散", 30, ["中防", "吸"], "attack", "-2.5；中防挡下仍-0.5",
            {"icon": "sweep", "damage_t": 25, "tags": ["old_scatter"], "note": "中防挡-0.5"})
    _add("despise", "鄙视", 30, ["中防", "小镖"], "control", "对方下回合不能出技能，并清空其连招",
            {"icon": "eye", "target": "enemy"})
    _add("soul_steal", "勾魂", 30, ["运"], "control", "勾走对方所有运",
            {"icon": "luck", "target": "enemy"})
    _add("gather_damage", "聚伤", 40, ["运"], "control", "本回合全部伤害聚到选定的一人身上",
            {"icon": "sweep", "target": "any"})
    _add("shield", "盾", 40, [], "buff", "存储1盾；自动挡一次致命伤害，可挡代码杀",
            {"icon": "shield", "target": "any", "shield_cast": true, "note": "首次4运，之后3运"})
    _add("dodge", "闪", 10, [], "defense", "躲避除手枪外一切指向自己的负面技能；躲不了代码杀",
            {"icon": "dodge", "target": "self", "cooldown": 1})
    _add("peach", "桃桃", 10, [], "buff", "+0.5血；或解除偷袭/C4/时间分散（解除则不回血）",
            {"icon": "peach", "target": "any", "heal_t": 5, "cooldown": 1})
    _add("cannon", "意大利炮", 70, [], "attack", "-3（π去小数点）；盾需2个",
            {"icon": "cannon", "damage_t": 30, "shield_require": 2})
    _add("sweep_earth", "横扫大地", 0, ["小镖", "降飞", "乃爆"], "attack", "对所有敌人各-1；费用=人数",
            {"icon": "sweep", "damage_t": 10, "target": "all_enemies", "note": "除小镖皆挡全员"})
    _add("scratch", "刮痧", 0, ["小掐"], "attack", "-0.2", {"icon": "dart", "damage_t": 2})
    _add("wine", "酒", 10, ["刮痧"], "revive", "复活死者，复活后0.4血1运；本回合免疫≤1攻击",
            {"icon": "revive", "target": "dead", "heal_t": 4, "gain_t": 10})
    _add("sneak", "偷袭", 10, ["中防", "桃桃"], "dot", "-0.2/回合，共5回合",
            {"icon": "dot", "target": "enemy", "tags": ["dot"], "note": "可叠加，各自计时"})
    _add("c4", "C4", 20, ["小镖", "桃桃"], "dot", "3回合后-3",
            {"icon": "bomb", "target": "enemy", "tags": ["c4"]})
    _add("headbutt", "脑瓜崩", 30, ["凯撒", "手枪"], "attack", "-1.3", {"icon": "dart", "damage_t": 13})
    _add("super_absorb", "超级吸", 10, [], "defense", "吸到的运 ×2",
            {"icon": "absorb", "target": "self", "cooldown": 1, "cooldown_group": "absorb"})
    _add("turtle", "龟派", 0, [], "special", "将对方技能转化为自己使用",
            {"icon": "turtle", "target": "enemy", "requires": ["zhongfang", "absorb", "yun"]})
    _add("suicide", "自杀", 10, [], "code", "杀死自己（代码杀）", {"icon": "skull", "target": "self"})
    _add("sunflower", "葵花宝典", 50, ["小镖"], "buff", "本局所有技能消耗×50%（盾、战术核弹除外）",
            {"icon": "star", "target": "self", "requires": ["zhongfang", "absorb", "yun", "super_absorb"]})
    _add("sunflower_luck", "向运葵", 0, ["小镖"], "buff", "+1运/回合，共2回合",
            {"icon": "luck", "target": "self", "requires": ["zhongfang", "zhongfang", "absorb", "zhongfang"]})
    _add("six_god", "六神", 50, ["运"], "attack", "-3，其中0.5为真伤",
            {"icon": "nuke", "damage_t": 30, "true_t": 5})
    _add("six_fly", "六飞", 50, ["中防"], "attack", "-3，其中0.5为真伤",
            {"icon": "nuke", "damage_t": 30, "true_t": 5})
    _add("safe_box", "保险箱", 20, [], "buff", "存3运、1桃、1盾，复活后生效",
            {"icon": "shield", "target": "self"})
    _add("prism", "三棱镜", 10, ["中防", "小镖"], "attack", "-(0.4+0.3k)；被挡时运/强化运者-0.2，负运者+0.2",
            {"icon": "prism", "target": "enemy"})
    _add("poison", "毒药", 20, ["运", "小镖"], "attack", "-目标当前血量×80%；运挡仍40%",
            {"icon": "poison", "target": "enemy"})
    _add("pistol", "手枪", 20, ["运", "吸"], "attack", "-1.5，不可被闪",
            {"icon": "gun", "damage_t": 15, "tags": ["no_dodge", "offset_yun"], "note": "运挡为抵消"})
    _add("amulet", "护身符", 10, [], "defense", "本回合免疫所有2~3运技能",
            {"icon": "shield", "target": "self", "cooldown": 1})
    _add("rage", "元首の愤怒", 40, ["战术核弹", "小镖"], "buff", "3回合内意大利炮费用变为2运",
            {"icon": "cannon", "target": "self"})
    _add("nuke", "战术核弹", 0, ["觉醒中防"], "attack", "-2.2；盾需2个",
            {"icon": "nuke", "damage_t": 22, "shield_require": 2, "requires": ["yun", "yun", "yun", "yun"],
             "note": "可变费用0~4；用后运连招清除"})
    _add("peach_core", "桃核", 0, [], "buff", "+0.1血", {"icon": "peach", "target": "self", "heal_t": 1})
    _add("peach_oath", "桃园结义", 0, [], "buff", "自己+0.5/人；费用=人数",
            {"icon": "peach", "target": "self"})
    _add("duel", "决斗", 40, [], "code", "未被防：对方有盾则清空盾，否则代码杀；被防则自受",
            {"icon": "duel", "target": "enemy", "multi_only": true, "uses": 3})
    _add("needle", "定海神针", 40, ["凯撒", "乃爆", "手枪", "脑瓜崩"], "attack", "-1.6，且自己+0.6",
            {"icon": "star", "damage_t": 16, "heal_t": 6, "note": "被防仍加血"})
    _add("rewind", "扭转时空", 30, [], "special", "本回合所有技能不生效",
            {"icon": "clock", "target": "self", "cooldown": 1})
    _add("heart", "比心", 20, ["中防"], "control", "-2运，最低可减至-3运",
            {"icon": "star", "target": "enemy"})
    _add("raiden", "飞雷神", 20, [], "control", "本回合对你的所有攻击转到选定的人身上",
            {"icon": "dodge", "target": "any", "multi_only": true})
    _add("awaken_zhongfang", "觉醒中防", 10, [], "defense", "挡攻击性技能并反弹0.5",
            {"icon": "block", "target": "self"})
    _add("dragon_heaven", "飞龙在天", 0, ["吸"], "attack", "-1.2；可挡所有人的横扫大地",
            {"icon": "dragon", "damage_t": 12, "requires": ["awaken_zhongfang"]})
    _add("strong_yun", "强化运", 10, [], "buff", "+2运；可挡所有攻击；挡超过2次攻击则不得运",
            {"icon": "luck", "target": "self", "gain_t": 20, "note": "只可吸1个"})
    _add("god_turtle", "神之龟派", 0, [], "special", "龟派到的所有技能效果翻倍",
            {"icon": "turtle", "target": "enemy", "requires": ["awaken_zhongfang", "super_absorb", "strong_yun"]})
    _add("unequal", "不平等条约", 50, ["葵花宝典", "小镖"], "control",
            "指定1人无法对你用有害技能；你成功攻击任何人后他-0.1",
            {"icon": "eye", "target": "enemy", "requires": ["yun", "absorb", "zhongfang", "zhongfang"]})
    _add("borrow_body", "借尸还魂", 60, ["鄙视"], "revive",
            "让1人替你死，继承其血/盾；运=你+他-6",
            {"icon": "revive", "target": "any", "uses": 1, "note": "死后3回合内可用；代码杀不可用"})
    _add("double_dart", "双镖", 20, ["中防", "吸"], "attack", "2人各-1；1人-2.1",
            {"icon": "dart", "damage_t": 10, "target": "enemies2", "multi_only": true})
    _add("death_note", "死亡笔记", 60, ["强化运"], "code", "选定一人自杀",
            {"icon": "skull", "target": "enemy", "multi_only": true, "note": "简化实现：自杀分支"})
    _add("purify", "净化", 30, ["桃桃", "盾"], "buff", "解除条约/偷袭/C4，血量=max(当前+0.5,1.3)",
            {"icon": "peach", "target": "self", "cooldown": 2, "note": "使用间隔两回合"})
    _add("final_pinch", "究掐", 20, ["运"], "attack", "-0.9；连招为-1.4；秒杀乃爆；被运挡抢运",
            {"icon": "skull", "damage_t": 9, "tags": ["pinch"], "note": "2；小掐→超掐为连招"})
    _add("undead_return", "亡灵返乡", 40, ["2人同时用"], "revive", "复活死者5回合，保留生前状态与阵营",
            {"icon": "revive", "target": "dead", "note": "复活者不能攻击用亡灵返乡的人"})
    _add("micro_dart", "微镖", 0, ["中防", "吸", "运", "小掐"], "attack", "-1；被吸则使用者+1运",
            {"icon": "dart", "damage_t": 10, "note": "运挡后还在"})
    _add("negative_luck", "负运", 0, ["吸"], "control", "指定对方-1运；可挡降龙/小镖/新长攻分散",
            {"icon": "luck", "target": "enemy", "note": "挡技能后仍生效"})
    _add("new_awaken_zhongfang", "新·觉醒中防", 10, [], "defense",
            "挡中防可挡全部；反弹min(伤害×50%,0.8)；比心→对方-1运；鄙视→对方下回合强制中防",
            {"icon": "block", "target": "self"})
    _add("new_long_attack_scatter", "新·长攻分散", 30, ["中防", "吸", "负运", "闪", "护身符"],
            "attack", "-2.4；被中防→空间分散；被吸→时间分散",
            {"icon": "sweep", "damage_t": 24, "tags": ["new_scatter"]})


static func all() -> Dictionary:
    if _cards.is_empty():
        _build()
    return _cards


static func get_card(id: String) -> Dictionary:
    return all().get(id, {})


static func ids() -> Array:
    var out: Array = all().keys()
    out.sort()
    return out


static func cost_label(card: Dictionary) -> String:
    if card.is_empty():
        return ""
    match card["id"]:
        "shield":
            return "4/3"
        "sweep_earth", "peach_oath":
            return "k"
        "nuke":
            return "0~4"
        "duel":
            return "4·限3"
        "borrow_body":
            return "6·限1"
        "dragon", "dive", "dragon_heaven", "turtle", "god_turtle", "sunflower_luck":
            return "0+"
    var c: int = card["cost_t"]
    if c % 10 == 0:
        return str(c / 10)
    return "%.1f" % (float(c) / 10.0)


static func fmt_t(v: int) -> String:
    var sign := ""
    var n := v
    if n < 0:
        sign = "-"
        n = -n
    if n % 10 == 0:
        return sign + str(n / 10)
    return sign + "%.1f" % (float(n) / 10.0)
