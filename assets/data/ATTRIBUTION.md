# 数据来源与许可

`acupoints.json` 由 `tool/import_bencaodian.py` 从「本草典」开放数据 v1 生成：

- 来源：本草典编辑部 / Bencaodian Editorial，https://bencaodian.org/zh/about/data/
- 原始文件：https://bencaodian.org/data/v1/acupoints.json（sha256 d78f34e8f1b70e31325aed26b77bc1a6a4a908a0e5b2f4fc60d371866da9016c，208 个穴位）
- 许可：CC BY-SA 4.0（https://creativecommons.org/licenses/by-sa/4.0/deed.zh-hans）
- 本项目所做改动：字段重命名与精简；穴位代码改为 WHO 写法（如 ST-36 → ST36，REN-12 → CV12）；功效（actions）中文写入 `efficacyTags`，主治（indications）中文写入 `indications`；新增按穴序沿本项目示意路径排布的 `coordinate`。

其余 153 个穴位由 `tool/import_acuatlas.py` 从 AcuAtlas 开放数据补全：

- 来源：AcuAtlas，https://acupointatlas.com/atlas
- 原始文件：https://acupointatlas.com/data/acupoints.json（sha256 b86ed0331549828ff0e4f6f7eb38b01e9cdcd1b2f566731e7002fadb3a887b06，361 个穴位，只取本草典未收录的 153 个）
- 许可：CC BY 4.0（https://creativecommons.org/licenses/by/4.0/deed.zh-hans）
- 本项目所做改动：定位、特定穴分类、功效（actions）、主治（indications + secondaryIndications）、注意事项由英文译为中文（AI 辅助翻译，2026-11-06 已对照英文原文逐条修订，存于 `tool/acuatlas_zh.json`；中医术语仍建议由专业人员按教材复核），功效拆为 `efficacyTags`；未采用其坐标、针刺深度与灸法字段；新增按穴序沿本项目示意路径排布的 `coordinate`。AcuAtlas 的定位以 WHO《西太平洋地区标准针灸穴位定位》（2008）为准。

合并后的 `acupoints.json` 以 CC BY-SA 4.0 分发（CC BY 4.0 内容可纳入 CC BY-SA 作品），其中 AcuAtlas 部分仍须保留上述署名。App 源代码的许可与此数据文件分开。

本草典标注的功效与主治原始出处为 Deadman《A Manual of Acupuncture》第 2 版（source_key: deadman_manual_2e）。

图上穴位坐标为示意，不代表真实体表定位；全部内容仅供学习参考，不作诊疗依据。
