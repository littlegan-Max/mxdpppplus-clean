class_name Rank
extends RefCounted

## 段位规则（参考王者荣耀 / 英雄联盟的星数 + 勇者积分模型，按本游戏的队伍对战简化）。
## 只统计真人 PvP 对局；前 5 场为定级赛，之后按 胜=+星 / 负=-星 推进。
## 服务端权威计算，客户端只负责展示。

const TIERS := ["青铜", "白银", "黄金", "铂金", "钻石", "星耀", "王者"]
const DIVS := ["III", "II", "I"]
const STARS_PER_DIV := 3
const PLACEMENT_GAMES := 5
const PTS_FULL := 100
const WIN_PTS := 15
const LOSS_PTS := 6


static func default_rank() -> Dictionary:
    return {
        "tier": 0,
        "div": 0,
        "stars": 0,
        "pts": 0,
        "games": 0,
        "wins": 0,
        "best_tier": 0,
        "placed": false,
        "streak": 0,
    }


static func normalize(r: Dictionary) -> Dictionary:
    var out := default_rank()
    if typeof(r) != TYPE_DICTIONARY:
        return out
    for k in out.keys():
        out[k] = r.get(k, out[k])
    out["tier"] = clampi(int(out["tier"]), 0, TIERS.size() - 1)
    out["div"] = clampi(int(out["div"]), 0, DIVS.size() - 1)
    out["stars"] = maxi(0, int(out["stars"]))
    out["pts"] = clampi(int(out["pts"]), 0, PTS_FULL)
    out["games"] = maxi(0, int(out["games"]))
    out["wins"] = clampi(int(out["wins"]), 0, int(out["games"]))
    out["best_tier"] = clampi(int(out["best_tier"]), 0, TIERS.size() - 1)
    out["streak"] = int(out["streak"])
    return out


static func label(r: Dictionary) -> String:
    var d := normalize(r)
    var tier := int(d["tier"])
    if tier == TIERS.size() - 1:
        return "王者 %d 星" % int(d["stars"])
    return "%s %s · %d 星" % [TIERS[tier], DIVS[int(d["div"])], int(d["stars"])]


static func win_rate_text(r: Dictionary) -> String:
    var d := normalize(r)
    if int(d["games"]) <= 0:
        return "胜率 —"
    return "胜率 %.0f%%（%d/%d）" % [float(d["wins"]) / float(d["games"]) * 100.0,
                                  int(d["wins"]), int(d["games"])]


static func _add_stars(r: Dictionary, n: int) -> void:
    for i in n:
        if int(r["tier"]) >= TIERS.size() - 1:
            r["tier"] = TIERS.size() - 1
            r["div"] = 0
            r["stars"] = int(r["stars"]) + 1
            continue
        r["stars"] = int(r["stars"]) + 1
        if int(r["stars"]) >= STARS_PER_DIV:
            r["stars"] = 0
            if int(r["div"]) < DIVS.size() - 1:
                r["div"] = int(r["div"]) + 1
            else:
                r["tier"] = int(r["tier"]) + 1
                r["div"] = 0


static func _remove_stars(r: Dictionary, n: int) -> void:
    var protected := false
    for i in n:
        if int(r["tier"]) >= TIERS.size() - 1:
            if int(r["stars"]) > 0:
                r["stars"] = int(r["stars"]) - 1
            else:
                r["tier"] = TIERS.size() - 2
                r["div"] = DIVS.size() - 1
                r["stars"] = STARS_PER_DIV - 1
            continue
        if int(r["stars"]) > 0:
            r["stars"] = int(r["stars"]) - 1
        elif int(r["div"]) > 0:
            r["div"] = int(r["div"]) - 1
            r["stars"] = STARS_PER_DIV - 1
        elif int(r["tier"]) > 0:
            r["tier"] = int(r["tier"]) - 1
            r["div"] = DIVS.size() - 1
            r["stars"] = STARS_PER_DIV - 1
        else:
            # 青铜 III 已是最低，掉星保护：不降段，仅扣勇者积分。
            r["pts"] = maxi(0, int(r["pts"]) - 25)
            protected = true
    if protected:
        return
    r["best_tier"] = maxi(int(r["best_tier"]), int(r["tier"]))


static func _place(r: Dictionary) -> void:
    var wins := int(r["wins"])
    match wins:
        5:
            r["tier"] = 2
            r["div"] = 1
            r["stars"] = 1
        4:
            r["tier"] = 2
            r["div"] = 0
            r["stars"] = 2
        3:
            r["tier"] = 1
            r["div"] = 2
            r["stars"] = 1
        2:
            r["tier"] = 1
            r["div"] = 0
            r["stars"] = 1
        _:
            r["tier"] = 0
            r["div"] = 1
            r["stars"] = 0
    r["placed"] = true
    r["best_tier"] = maxi(int(r["best_tier"]), int(r["tier"]))
    r["pts"] = 0


## win: 本场是否获胜（仅 PvP 调用）。返回 {"rank", "delta", "placed_now"}。
static func apply_result(rank: Dictionary, win: bool) -> Dictionary:
    var r := normalize(rank)
    r["games"] = int(r["games"]) + 1
    if win:
        r["wins"] = int(r["wins"]) + 1
        r["streak"] = maxi(1, int(r["streak"]) + 1)
    else:
        r["streak"] = mini(-1, int(r["streak"]) - 1)
    var placed_now := false
    var delta := ""
    if int(r["games"]) < PLACEMENT_GAMES:
        r["pts"] = mini(PTS_FULL, int(r["pts"]) + (20 if win else 10))
        delta = "定级赛 %d/%d" % [int(r["games"]), PLACEMENT_GAMES]
    elif int(r["games"]) == PLACEMENT_GAMES and not bool(r["placed"]):
        r["pts"] = mini(PTS_FULL, int(r["pts"]) + (20 if win else 10))
        _place(r)
        placed_now = true
        delta = "定级完成 · %s" % label(r)
    else:
        var bonus := 0
        if win:
            r["pts"] = int(r["pts"]) + WIN_PTS
            if int(r["pts"]) >= PTS_FULL:
                r["pts"] = 0
                bonus = 1
            _add_stars(r, 1 + bonus)
            delta = "+%d 星" % (1 + bonus)
            if bonus > 0:
                delta += "（勇者积分满，额外 +1）"
        else:
            r["pts"] = mini(PTS_FULL, int(r["pts"]) + LOSS_PTS)
            _remove_stars(r, 1)
            delta = "-1 星"
        if int(r["tier"]) > int(r["best_tier"]):
            r["best_tier"] = int(r["tier"])
    r["best_tier"] = maxi(int(r["best_tier"]), int(r["tier"]))
    return {"rank": r, "delta": delta, "placed_now": placed_now}
