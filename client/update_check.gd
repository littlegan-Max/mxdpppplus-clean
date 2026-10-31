extends Node

## 检查更新：优先国内可直连的 GitHub 代理/CDN，最后回退 GitHub 源站。
## version.json 与仓库默认分支同目录，内容形如
## {"version":"1.0.1","url":"https://github.com/.../releases/latest","notes":"..."}

signal checked(result: Dictionary)

const REPO_PATH := "littlegan-Max/mxdpppplus-clean"
const FEEDS := [
    # jsDelivr 国内可直连节点（实测无需梯子；testingcf 对未缓存文件直接回源）
    "https://testingcf.jsdelivr.net/gh/%s@master/version.json" % REPO_PATH,
    "https://fastly.jsdelivr.net/gh/%s@master/version.json" % REPO_PATH,
    "https://cdn.jsdelivr.net/gh/%s@master/version.json" % REPO_PATH,
    # GitHub 实时代理（偶发 DNS 不通，作为备用）
    "https://gh-proxy.com/https://raw.githubusercontent.com/%s/master/version.json" % REPO_PATH,
    # 源站兜底
    "https://raw.githubusercontent.com/%s/master/version.json" % REPO_PATH,
]

var _idx := 0
var _current := ""
var _url := ""
var _busy := false
var _req: HTTPRequest = null


func _ensure_req() -> HTTPRequest:
    if _req == null:
        _req = HTTPRequest.new()
        _req.timeout = 6.0
        add_child(_req)
        _req.request_completed.connect(_on_done)
    return _req


func check(current_version: String) -> void:
    _current = current_version
    _idx = 0
    _busy = true
    _next()


func _next() -> void:
    if not _busy:
        return
    if _idx >= FEEDS.size():
        _busy = false
        checked.emit({"ok": false, "newer": false, "error": "所有更新源都不可达"})
        return
    _url = FEEDS[_idx]
    _idx += 1
    var req := _ensure_req()
    var err := req.request(_url, ["User-Agent: mxdpppplus-update"], HTTPClient.METHOD_GET)
    if err != OK:
        call_deferred("_next")


func _on_done(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    if not _busy:
        return
    if code == 200:
        var d = JSON.parse_string(body.get_string_from_utf8())
        if typeof(d) == TYPE_DICTIONARY:
            var latest := str(d.get("version", ""))
            if latest != "":
                _busy = false
                checked.emit({
                    "ok": true,
                    "latest": latest,
                    "newer": _compare(latest, _current) > 0,
                    "url": str(d.get("url", "")),
                    "download_base": str(d.get("download_base", "")),
                    "notes": str(d.get("notes", "")),
                    "source": _url,
                })
                return
    call_deferred("_next")


static func _compare(a: String, b: String) -> int:
    var pa := a.split(".")
    var pb := b.split(".")
    var n := maxi(pa.size(), pb.size())
    for i in n:
        var va := int(pa[i]) if i < pa.size() else 0
        var vb := int(pb[i]) if i < pb.size() else 0
        if va > vb:
            return 1
        if va < vb:
            return -1
    return 0
