# 经络图谱（Flutter 2D 原型）

一个用于中医经络知识学习的跨平台手机 App 原型。当前采用 **Flutter 3.x + Dart + CustomPainter**，先完成本地数据驱动的 2D 首屏，不依赖第三方动画或状态管理套件。

## 当前原型

- 写实人体底图（男/女可切换，正面/背面），双指缩放，放大后显示穴名；轻触穴位进入穴位介绍页。
- 提供十二正经与任脉、督脉的 14 个经络数据项，可按全部、手经、足经、奇经筛选并多选叠加。
- 支持按穴位中文名、拼音或代码搜索，并可按所属经络筛选结果。
- 对比模式：任选两条经络，并排或叠加在同一人体上，动画同步；正/背面切换、穴位显示开关、交换两侧；下方属性对照表高亮差异项。入口在首页「经络详情与对比」。
- 按功效筛选：从穴位的 `efficacyTags` 自动汇总标签（当前 287 个），默认显示最常见的 16 个，可展开全部并输入关键字过滤；多选命中任一即显示，可与搜索、经络、收藏筛选叠加。
- 穴位可加入本机收藏，收藏列表通过 `shared_preferences` 在应用重启后保留。
- 使用 `AnimationController` + `CustomPainter` 绘制循环流动粒子；可暂停、重置、调速和切换流动方向。
- 经络详情页：单经流动演示（正/背面切换、暂停、反向）、说明与出处、相关穴位列表；点选穴位返回首页并定位。可从「查看经络详情」或穴位卡片进入。
- 收录 361 个经穴：208 个来自「本草典」开放数据（CC BY-SA 4.0），其余 153 个来自 AcuAtlas 开放数据（CC BY 4.0，英文原文经 AI 辅助译为中文，并已对照英文逐条修订），详见 `assets/data/ATTRIBUTION.md`。点选可查看名称、拼音、国际代码、特定穴分类、定位、功效、主治、注意事项与出处。
- 所有数据由 `assets/data/*.json` 本地加载，预留来源字段。

**重要：**人体底图为 AI 生成的写实示意图；穴位在底图上的位置按骨度分寸由体表标志推算（见 `tool/body_atlas/`），经络线按穴序连接相邻穴位，均为学习示意，并非精确定位。穴位文字资料来自本草典（其功效、主治原注出处为 Deadman《A Manual of Acupuncture》第 2 版）与 AcuAtlas（定位以 WHO 2008 标准为准；中文为译文，可能有术语偏差），仅供学习参考，不提供诊疗或操作指导。对外发布前建议由专业人员按选定版次的《经络腧穴学》《针灸学》核对。

## 数据结构

底图上的穴位位置存于 `assets/data/body_positions.json`（图片像素坐标，按 figure 男/女 分别给出 1 个正中线位置或 2 个双侧位置，并指定 `view`）。`acupoints.json` 中旧的 `coordinate`（1000 × 1600 示意坐标）已不用于绘图。

### 经络 `assets/data/meridians.json`

| 字段 | 用途 |
| --- | --- |
| `id` | 稳定主键，例如 `LU`、`REN` |
| `nameZh`, `pinyin`, `code` | 中文名、拼音、国际经络代码 |
| `color` | 颜色十六进制值 |
| `group` | `hand`、`foot` 或 `extra`，供筛选使用 |
| `yinYang`, `direction` | 阴阳/类别、默认流向元数据 |
| `routes` | 一条或多条路径；每条含 `view` 和 `points: [[x,y], ...]` |
| `summary`, `source` | 说明与出处/审核记录 |

### 穴位 `assets/data/acupoints.json`

| 字段 | 用途 |
| --- | --- |
| `id` | 穴位记录稳定主键 |
| `nameZh`, `pinyin`, `code` | 穴位名、拼音、国际代码 |
| `meridianId` | 所属经络 ID |
| `view`, `coordinate` | 展示面与 `{x, y}` 标准化坐标 |
| `location` | 定位文字 |
| `indications` | 主治条目（学习资料） |
| `efficacyTags` | 功效短标签数组，驱动「按功效筛选」 |
| `specialCategories` | 特定穴分类，如原穴、合穴 |
| `cautions` | 注意事项，如孕妇慎用 |
| `source` | 资料来源、版次和审核状态 |

后续可在穴位记录扩充 `tags`、配伍、注意事项、收藏索引及多语言字段，并通过 `schemaVersion` 支持数据迁移/热更新。

## 数据更新

```bash
python3 tool/import_bencaodian.py   # 重新下载本草典 v1、校验 sha256 并生成 acupoints.json
python3 tool/import_acuatlas.py     # 再用 AcuAtlas + tool/acuatlas_zh.json 译文补全其余 153 穴
```

## 运行

需要本机已安装 Flutter 3.x 和 Dart 3.x。首次运行会拉取 Flutter 依赖（包括用于保存收藏的 `shared_preferences`）：

```bash
bash tool/bootstrap_platforms.sh   # 首次运行：生成 Android/iOS 原生目录并拉取 Flutter 依赖
flutter run
```

初始化脚本会在临时目录生成 Flutter 原生模板，只把 `android/`、`ios/` 复制到当前工程，不覆盖 Dart 源码或项目配置；如平台目录已经存在，脚本会停止以避免覆盖。也可在已有原生目录的项目中直接执行 `flutter pub get` 和 `flutter run`。已用 Flutter 3.24.5 通过 `flutter analyze` 与 `flutter test`（`test/` 下的组件测试），尚未做真机构建验证。首版只依赖 Flutter SDK，无额外 pub package。

## 目录

```text
lib/
  main.dart                         # 首屏与交互
  data/meridian_repository.dart     # JSON 加载
  models/meridian.dart              # 经络、路线、穴位模型
  widgets/acupoint_search_panel.dart # 穴位搜索、筛选与收藏列表
  widgets/meridian_canvas.dart      # 人体/路径/粒子绘制
assets/data/
  meridians.json
  acupoints.json
```
