<div align="center">

<img src="res/icon.png" width="128" alt="舞萌查歌" />

# 舞萌查歌 · maisearchsong

**《舞萌 DX》（国服）曲库检索与成绩查询工具**

[![Flutter](https://img.shields.io/badge/Flutter-3.44-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Windows-0078D4?logo=windows&logoColor=white)](#构建)
[![Data](https://img.shields.io/badge/Data-落雪咖啡屋-FF6B6B)](https://maimai.lxns.net/docs/api/maimai)
[![License](https://img.shields.io/badge/License-仅供学习-9E9E9E)](#免责声明)

</div>

> [!IMPORTANT]
> **本项目的代码 100% 由 AI 编写。**
> 从架构设计、接口对接、页面实现到测试与排错，全部由 AI 编程智能体完成，
> 人类只负责提出需求、验收结果和少量方向性决策。
> 因此代码风格可能带有明显的机器痕迹，欢迎阅读、试用与批评，但请勿期待人工级别的打磨。

---

## 目录

- [这是什么](#这是什么)
- [AI 编写说明](#ai-编写说明)
- [数据来源](#数据来源)
- [功能](#功能)
- [界面结构](#界面结构)
- [快速开始](#快速开始)
- [构建](#构建)
- [目录结构](#目录结构)
- [本地存储](#本地存储)
- [测试](#测试)
- [已知限制](#已知限制)
- [致谢](#致谢)
- [免责声明](#免责声明)

---

## 这是什么

一个仿照 [chusearchsong_flutter](https://github.com/k4641321/chusearchsong_flutter)
（中二节奏查歌工具）写的查歌应用，把题材换成了 **舞萌 DX 国服**，
`pubspec.yaml` 里的依赖包与原仓库保持一致。

曲库、谱面定数、物量、别名、收藏品（称号 / 头像 / 姓名框 / 背景框）
以及成绩数据，全部来自 [落雪咖啡屋 maimai 查分器](https://maimai.lxns.net/docs/api/maimai)
的公开接口；曲绘与试听音频取自其资源站。

当前主要面向 **Windows 桌面端**，已实际构建并验证；
其余平台（Android / iOS / macOS / Linux / Web）保留 Flutter 工程骨架，未做验证。

## AI 编写说明

| 项目 | 说明 |
| --- | --- |
| 编写方式 | 由 AI 编程智能体根据需求连续生成、编译、调试 |
| 人类参与 | 提出需求、选择技术方向、验收运行效果 |
| 代码量 | `lib/` 21 个 Dart 文件，约 6700 行；`test/` 1 个测试文件 |
| 依赖 | 30 个运行时依赖 + 1 个开发依赖，与原参考仓库保持一致 |
| 验证 | `flutter test` 通过、Windows Release 实际构建并运行 |

这意味着：

- ✅ 接口调用、状态管理、页面逻辑都是**真实可用**的，不是占位代码；
- ⚠️ 局部可能存在过度抽象、注释冗余或命名不统一；
- ⚠️ 未覆盖的边界情况（异常网络、极端数据）可能仍会暴露问题。

发现问题欢迎提 Issue —— 大概率还能让 AI 再改一版。

## 数据来源

| 用途 | 接口 |
| --- | --- |
| 曲库（含定数、物量） | `GET /api/v0/maimai/song/list?version=25500&notes=true` |
| 单曲详情 | `GET /api/v0/maimai/song/{id}` |
| 曲目别名 | `GET /api/v0/maimai/alias/list` |
| 收藏品分类 | `GET /api/v0/maimai/collection-genre/list` |
| 称号 / 头像 / 姓名框 / 背景框 | `GET /api/v0/maimai/{trophy,icon,plate,frame}/list` |
| 玩家资料 / Best 50 / 单曲成绩 / Rating 趋势 | `/api/v0/maimai/player/...`（需开发者 Token） |

曲绘、试听音频、收藏品图标来自 `https://assets2.lxns.net/maimai/...`。

线上实测（2026-10）：曲目 **1344** 首（标准 543 / DX 799 / 宴会 62）、
谱面 **5502** 个、别名 **1067** 条、称号 **3031** 个、头像 **1059** 个、
姓名框 **400** 个、背景框 **353** 个。可随时用自检脚本复核：

```bash
dart run tool/check_api.dart
```

## 功能

### 🔍 查歌
- 关键词模糊匹配：曲名、曲师、别名、谱师、曲目 ID
- 筛选：难度（BASIC ~ Re:MASTER）、谱面类型（标准 / DX / 宴会）、
  版本、分类、定数区间
- 排序：默认 / 曲名 / 版本 / BPM / 定数，滚动分页加载

### 🎵 曲目详情
- 曲绘预览、BPM / 曲师 / 分类 / 版本
- 各难度定数与 TAP / HOLD / SLIDE / TOUCH / BREAK 物量分解
- 别名展示、试听、收藏、文本分享
- 绑定玩家后直接显示该谱面的个人最佳成绩
- 成绩历史曲线：该谱面历次上传的达成率折线图

### ⭐ 收藏夹
- 多文件夹管理，本地持久化
- JSON 导入 / 导出，可备份也可分享

### 📊 成绩
- 玩家概览、Best 35 + Best 15
- 单曲最佳、全部成绩列表
- 特殊 Best 50：AP50 / FC50 / 随机 50 / 分类 50 / 版本 50
- 所有成绩预览：全谱面成绩 + 总数 / FC / AP / SSS+ 统计，
  支持按定数、达成率、FC 状态、曲名排序与筛选
- 等级完成进度：按标级统计谱面完成度与达成率分布
- 友人对战：两个玩家逐谱面对比胜负，支持胜 / 负 / 平筛选
- Rating 趋势折线图（`fl_chart`）
- 吃分建议：按单谱 Rating 从低到高列出提升空间最大的谱面

### 🏅 收藏品
- 称号 / 头像 / 姓名框 / 背景框检索与详情
- 达成条件展示

### 🧰 工具
- 玩家查询、Rating 趋势、吃分建议
- 特殊 Best 50、所有成绩、等级完成进度、友人对战
- 随机歌曲 / 出勤转盘
- 单谱 Rating 计算器、容错（可失误数）计算
- 等级划分与判定表、Rating 颜色对照

### 🎨 外观
- 亮色 / 暗色 / 跟随系统
- 动态取色（Material You）、自定义品牌主色、字号缩放

## 界面结构

底部四个标签页：**查歌** / **收藏** / **工具** / **设置**。
查歌页为卡片列表，右上角进入排序；筛选条件收在底部弹出面板里。
工具页是各个功能入口的集合，成绩类页面在绑定开发者 Token 后才有数据。

## 快速开始

```bash
git clone https://github.com/<your-name>/maisearchsong.git
cd maisearchsong
flutter pub get
flutter run -d windows
```

成绩相关页面需要在「设置 → 开发者 Token」填入
[落雪咖啡屋](https://maimai.lxns.net) 的开发者 Token；
不填也能正常查歌、看曲库和收藏品。

## 构建

```bash
# Windows（当前主要目标）
flutter build windows --release

# Android（需自备 SDK / NDK，未验证）
flutter build apk --release
```

Windows 产物：

```
build/windows/x64/runner/Release/
├── maisearchsong.exe
├── flutter_windows.dll
├── *_plugin.dll
└── data/
```

**整个 `Release` 目录需一并分发**，只拷 exe 无法运行。

<details>
<summary><b>Windows 构建踩坑记录</b>（点开）</summary>

1. **安装路径**
   `windows/CMakeLists.txt` 里把 `CMAKE_INSTALL_PREFIX` 固定为可执行文件所在目录。
   Flutter 模板默认的 `C:/Program Files/<项目名>` 在无管理员权限时会让 `install` 步骤失败。

2. **NuGet 缓存不可写**
   `audioplayers_windows` 首次构建要用 `nuget` 拉取
   `Microsoft.Windows.ImplementationLibrary`。若 `%LOCALAPPDATA%\NuGet`
   或 `%TEMP%\NuGetScratch` 不可写，把 `NUGET_PACKAGES`、`NUGET_HTTP_CACHE_PATH`、
   `TMP` 指到可写目录后再构建。

3. **应用图标**
   修改 `res/icon.png` 后执行 `dart run flutter_launcher_icons` 重新生成。

</details>

## 目录结构

```
lib/
├── main.dart             应用入口、主题与导航
├── core/
│   ├── api_client.dart   lxns 接口封装
│   ├── app_state.dart    全局状态、筛选条件、排序枚举
│   ├── settings.dart     本地设置、持久化与多级回退存储
│   ├── rating.dart       Rating 与容错计算
│   ├── constants.dart    版本号、枚举、地址常量
│   ├── palette.dart      难度与评级配色
│   └── proxy.dart        可选的 sing-box 加速线路（仅 Android）
├── models/
│   └── models.dart       Song / SongDifficulty / Notes / Score / Player / Collection
├── pages/
│   ├── home_page.dart    底部导航容器
│   ├── search_page.dart  查歌
│   ├── song_info_page.dart 曲目详情
│   ├── favorites_page.dart 收藏夹
│   ├── tools_page.dart     工具入口
│   ├── player_page.dart    玩家成绩与趋势
│   ├── rating_calc_page.dart 计算器与容错
│   ├── random_song_page.dart 随机抽歌 / 转盘
│   ├── collection_page.dart  收藏品
│   └── settings_page.dart    设置
├── widgets/
│   ├── common.dart       通用组件（徽章、图表、空态）
│   └── song_widgets.dart 歌曲卡片与成绩徽章
tool/
└── check_api.dart        线上接口 + 模型解析自检
test/
└── render_test.dart      真实曲库快照驱动的页面渲染测试
```

## 本地存储

设置、收藏夹与曲库缓存优先写入 `flutter_local_db`（LMDB）。
存储目录按以下顺序探测，取第一个真正可写的：

1. 应用支持目录 —— Windows 为 `%APPDATA%\<包名>\<应用名>\WumengSearchSong`
2. 应用文档目录
3. 可执行文件旁的 `userdata/`
4. 系统临时目录

数据库打不开时自动退化为同目录下的 `maisearchsong.json` 文件后端；
所有目录都不可写时退化为纯内存存储（仅本次运行有效）。
这样在任何权限环境下应用都能启动并保存设置。

> `data/` 是 Flutter 资源目录，**请勿删除**；
> 运行期数据在 `userdata/`，可以安全清空以重置应用。

## 测试

```bash
flutter analyze
flutter test
```

`test/render_test.dart` 用真实曲库快照驱动各页面渲染，
覆盖查歌列表、工具页全部入口、曲目详情、计算器、玩家页空态与收藏品页，
能发现空列表、解析失败这类只在真实数据下才暴露的问题。

## 已知限制

- **平台**：仅 Windows 经过实际构建与运行验证。
- **Token**：成绩、B50、Rating 趋势依赖开发者 Token，未填写时相关页面只显示引导。
- **加速线路**：`flutter_singbox_client` 仅有 Android 原生实现，
  其他平台自动跳过并直连，不会抛 `MissingPluginException`。
- **谱面预览**：详情页展示的是物量分解，不渲染谱面图像（参考项目的谱面图接口国服未开放）。
- **依赖**：`pubspec.yaml` 为与参考仓库保持一致，声明了 `webview_flutter`、`marquee`、
  `font_awesome_flutter`、`flutter_map`、`geolocator`、`image` 等包，其中部分当前未使用，
  仅为后续功能预留。

## 致谢

- [chusearchsong_flutter](https://github.com/k4641321/chusearchsong_flutter) —— 界面与功能蓝本
- [落雪咖啡屋](https://maimai.lxns.net) —— 国服数据与资源
- [beerpsi](https://github.com/beerpsi)、[reiwa.f5.si](https://reiwa.f5.si) —— 参考资料
- [SEGA](https://maimai.sega.jp)、[华立](https://wc.wahlap.net) —— 《舞萌 DX》
- [Nearcade](https://nearcade.com) —— 店铺信息

## 免责声明

本项目为**非商业的学习与技术交流项目**，与 SEGA、华立、落雪咖啡屋均无隶属关系。
游戏名称、曲绘、音频等一切素材版权归原权利方所有，本项目仅做数据检索与展示，
不提供任何游戏资源的下载或破解功能。文档与接口如有变更，本项目可能随时失效。

---

<div align="center">

**本项目由 AI 编写 · Made with 🤖 and Flutter**

</div>
