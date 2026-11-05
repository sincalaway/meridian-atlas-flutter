#!/usr/bin/env python3
"""用 AcuAtlas 开放数据补全本草典未收录的穴位，追加到 assets/data/acupoints.json。

数据来源：AcuAtlas，https://acupointatlas.com/atlas ，许可 CC BY 4.0。
原文为英文；tool/acuatlas_zh.json 是本项目的中文译文（AI 辅助翻译，2026-11-06 已对照英文逐条修订），
同样以 CC BY 4.0 提供，并注明改动。

用法（须在 import_bencaodian.py 之后运行）：
    python3 tool/import_bencaodian.py
    python3 tool/import_acuatlas.py              # 联网下载并校验 sha256
    python3 tool/import_acuatlas.py local.json   # 使用已下载的文件
"""
import hashlib
import json
import pathlib
import sys
import urllib.request

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from import_bencaodian import MERIDIANS, OUT, PREFIX, point_on_route  # noqa: E402

URL = "https://acupointatlas.com/data/acupoints.json"
SHA256 = "b86ed0331549828ff0e4f6f7eb38b01e9cdcd1b2f566731e7002fadb3a887b06"
TRANSLATION = pathlib.Path(__file__).resolve().parent / "acuatlas_zh.json"

# AcuAtlas 前缀 -> import_bencaodian.PREFIX 的键
ALIAS = {"TE": "SJ", "LV": "LR", "CV": "REN", "GV": "DU"}
ORDER = list(PREFIX)


def load_raw():
    if len(sys.argv) > 1:
        data = pathlib.Path(sys.argv[1]).read_bytes()
    else:
        req = urllib.request.Request(URL, headers={"User-Agent": "meridian-atlas-import"})
        with urllib.request.urlopen(req, timeout=60) as resp:
            data = resp.read()
    digest = hashlib.sha256(data).hexdigest()
    if digest != SHA256:
        sys.exit(f"sha256 不匹配：{digest}，AcuAtlas 数据可能已更新，请人工核对后更新 SHA256 与译文")
    return json.loads(data)["points"]


def order_key(point):
    code = point["code"]
    who = code.rstrip("0123456789")
    number = int(code[len(who):])
    back = {"TE": "SJ", "LR": "LR", "CV": "REN", "GV": "DU"}.get(who, who)
    return (ORDER.index(back), number)


def main():
    raw = load_raw()
    zh = json.loads(TRANSLATION.read_text())
    meridians = {m["id"]: m for m in json.loads(MERIDIANS.read_text())}
    current = [p for p in json.loads(OUT.read_text()) if "AcuAtlas" not in p.get("source", "")]
    have = {p["code"] for p in current}
    added = 0
    for item in raw:
        prefix, number = item["id"].split("-")
        meridian_id, who, total = PREFIX[ALIAS.get(prefix, prefix)]
        number = int(number)
        code = f"{who}{number}"
        if code in have:
            continue
        tr = zh.get(item["id"])
        if tr is None:
            sys.exit(f"缺少译文：{item['id']}")
        route = meridians[meridian_id]["routes"][0]
        x, y = point_on_route(route, (number - 1) / max(total - 1, 1))
        current.append({
            "id": code,
            "nameZh": item["hanzi"],
            "pinyin": item["name"],
            "code": code,
            "meridianId": meridian_id,
            "view": route["view"],
            "coordinate": {"x": x, "y": y},
            "location": tr["location"],
            "indications": tr["indications"],
            "efficacyTags": tr["tags"],
            "specialCategories": tr["categories"],
            "cautions": tr["cautions"],
            "source": (
                "AcuAtlas 开放数据（acupointatlas.com，CC BY 4.0），英文原文由本项目译为中文（AI 辅助翻译，2026-11-06 对照英文逐条修订）；"
                "AcuAtlas 定位以 WHO《西太平洋地区标准针灸穴位定位》（2008）为准。"
                "图上位置为按穴序沿示意路径排布，非真实定位。"
            ),
        })
        added += 1
    current.sort(key=order_key)
    OUT.write_text(json.dumps(current, ensure_ascii=False, indent=2) + "\n")
    print(f"追加 {added} 个穴位，共 {len(current)} 个 -> {OUT.name}")


if __name__ == "__main__":
    main()
