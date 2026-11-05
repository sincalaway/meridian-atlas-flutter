#!/usr/bin/env python3
"""从本草典开放数据导入穴位，生成 assets/data/acupoints.json。

数据来源：本草典编辑部 / Bencaodian Editorial，https://bencaodian.org/zh/about/data/
许可：CC BY-SA 4.0。生成的 assets/data/acupoints.json 也按 CC BY-SA 4.0 分发。

用法：
    python3 tool/import_bencaodian.py            # 联网下载 v1 并校验 sha256
    python3 tool/import_bencaodian.py local.json # 使用已下载的文件（同样校验）

坐标说明：本草典不提供坐标。本脚本按穴序把穴位均匀排布在本项目
meridians.json 中该经第一条示意路径上，仅为示意，不代表真实体表定位。
"""
import hashlib
import json
import math
import pathlib
import sys
import urllib.request

URL = "https://bencaodian.org/data/v1/acupoints.json"
SHA256 = "d78f34e8f1b70e31325aed26b77bc1a6a4a908a0e5b2f4fc60d371866da9016c"
ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/data/acupoints.json"
MERIDIANS = ROOT / "assets/data/meridians.json"

# 本草典 code 前缀 -> (本项目 meridianId, WHO 代码前缀, 该经标准穴数)
PREFIX = {
    "LU": ("LU", "LU", 11), "LI": ("LI", "LI", 20), "ST": ("ST", "ST", 45),
    "SP": ("SP", "SP", 21), "HT": ("HT", "HT", 9), "SI": ("SI", "SI", 19),
    "BL": ("BL", "BL", 67), "KI": ("KI", "KI", 27), "PC": ("PC", "PC", 9),
    "SJ": ("SJ", "TE", 23), "GB": ("GB", "GB", 44), "LR": ("LV", "LR", 14),
    "REN": ("REN", "CV", 24), "DU": ("DU", "GV", 28),
}

SOURCE_NOTE = {
    "deadman_manual_2e": "Deadman《A Manual of Acupuncture》第 2 版",
}

# 本草典未收录、继续保留的演示记录
KEEP_DEMO = {"CV12", "GV20"}


def load_raw():
    if len(sys.argv) > 1:
        data = pathlib.Path(sys.argv[1]).read_bytes()
    else:
        with urllib.request.urlopen(URL, timeout=60) as resp:
            data = resp.read()
    digest = hashlib.sha256(data).hexdigest()
    if digest != SHA256:
        sys.exit(f"sha256 不匹配：{digest}，数据版本可能已变化，请人工核对后更新 SHA256")
    return json.loads(data)


def point_on_route(route, fraction):
    pts = route["points"]
    segs = [math.dist(pts[i], pts[i + 1]) for i in range(len(pts) - 1)]
    target = sum(segs) * fraction
    for i, length in enumerate(segs):
        if target <= length or i == len(segs) - 1:
            t = 0 if length == 0 else min(target / length, 1)
            x = pts[i][0] + (pts[i + 1][0] - pts[i][0]) * t
            y = pts[i][1] + (pts[i + 1][1] - pts[i][1]) * t
            return round(x, 1), round(y, 1)
        target -= length
    return pts[-1]


def main():
    raw = load_raw()
    meridians = {m["id"]: m for m in json.loads(MERIDIANS.read_text())}
    previous = json.loads(OUT.read_text()) if OUT.exists() else []
    out = []
    for item in raw:
        prefix, number = item["code"].split("-")
        meridian_id, who, total = PREFIX[prefix]
        number = int(number)
        route = meridians[meridian_id]["routes"][0]
        x, y = point_on_route(route, (number - 1) / max(total - 1, 1))
        source_keys = sorted({a.get("source_key", "") for a in item["actions"] + item["indications"]} - {""})
        cited = "、".join(SOURCE_NOTE.get(k, k) for k in source_keys)
        reviewed = item.get("verification", {})
        out.append({
            "id": f"{who}{number}",
            "nameZh": item["name_zh"],
            "pinyin": (lambda s: s[:1] + s[1:].lower())(item["name_pinyin"].replace(" ", "")),
            "code": f"{who}{number}",
            "meridianId": meridian_id,
            "view": route["view"],
            "coordinate": {"x": x, "y": y},
            "location": item["location"]["zh"],
            "indications": [i["zh"] for i in item["indications"]],
            "efficacyTags": [a["zh"] for a in item["actions"]],
            "specialCategories": item.get("special_categories", []),
            "cautions": item.get("cautions_zh") or "",
            "source": (
                f"本草典开放数据 v1（本草典编辑部 / Bencaodian Editorial，CC BY-SA 4.0）；"
                f"功效与主治原注出处：{cited or '未标注'}；"
                f"编辑审校：{reviewed.get('last_reviewed', '未知')}。"
                "图上位置为按穴序沿示意路径排布，非真实定位。"
            ),
            "_order": (list(PREFIX).index(prefix), number),
        })
    for demo in previous:
        if demo["code"] in KEEP_DEMO and demo["code"] not in {p["code"] for p in out}:
            demo = dict(demo)
            demo["_order"] = (99, 0)
            out.append(demo)
    out.sort(key=lambda p: p["_order"])
    for p in out:
        p.pop("_order")
    OUT.write_text(json.dumps(out, ensure_ascii=False, indent=2) + "\n")
    print(f"写入 {len(out)} 个穴位 -> {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
