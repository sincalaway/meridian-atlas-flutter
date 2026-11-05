# 经络图谱（Flutter 2D 原型）

一个用于中医经络知识学习的跨平台手机 App 原型。当前采用 **Flutter 3.x + Dart + CustomPainter**，先完成本地数据驱动的 2D 首屏，不依赖第三方动画或状态管理套件。

## 当前原型

- 以矢量轮廓绘制人体正、背面示意图。
- 提供十二正经与任脉、督脉的 14 个经络数据项，可按全部、手经、足经、奇经筛选并多选叠加。
- 支持按穴位中文名、拼音或代码搜索，并可按所属经络筛选结果。
- 按功效筛选：从穴位的 `efficacyTags` 自动汇总标签，可多选（命中任一即显示），可与搜索、经络、收藏筛选叠加。当前数据未录入任何功效标签，界面显示「待录入」提示。
- 穴位可加入本机收藏，收藏列表通过 `shared_preferences` 在应用重启后保留。
- 使用 `AnimationController` + `CustomPainter` 绘制循环流动粒子；可暂停、重置、调速和切换流动方向。
- 经络详情页：单经流动演示（正/背面切换、暂停、反向）、说明与出处、相关穴位列表；点选穴位返回首页并定位。可从「查看经络详情」或穴位卡片进入。
- 穴位示例支持点选并展示名称、拼音、国际代码、定位提示和资料状态。
- 所有数据由 `assets/data/*.json` 本地加载，预留来源字段。

**重要：**人体路线、路径坐标和穴位点位都是界面演示数据，并非完整标准定位；当前不提供穴位功效、诊疗或操作指导。对外发布前需由专业人员按选定版次的《经络腧穴学》《针灸学》等资料逐项核对，并记录书名、版次、页码及审核信息。

## 数据结构

统一坐标系为 `1000 × 1600`，原点在画布左上角；路线点与穴位坐标均为该坐标系中的数值，使用 `view: front | back` 指定人体视图。UI 通过等比缩放和居中留白适配不同尺寸。

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
| `indications` | 经专业审校的学习资料字段；当前仅占位 |
| `efficacyTags` | 功效分类短标签数组（如按教材主治归类），驱动「按功效筛选」；须来自经审校的资料，当前全部为空 |
| `source` | 资料来源、版次和审核状态 |

后续可在穴位记录扩充 `tags`、配伍、注意事项、收藏索引及多语言字段，并通过 `schemaVersion` 支持数据迁移/热更新。

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
