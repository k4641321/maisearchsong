# 舞萌查歌（maisearchsong）

面向《舞萌 DX》（国服）的查歌工具，Flutter 编写。界面与交互仿照
[chusearchsong_flutter](https://github.com/k4641321/chusearchsong_flutter)，
依赖包与该仓库保持一致，仅把数据源换成国服
[落雪咖啡屋 maimai 查分器](https://maimai.lxns.net/docs/api/maimai) 的公开接口。

支持 Windows / Android / iOS / macOS / Linux / Web（当前已构建验证 Windows）。

## 数据来源

| 用途 | 接口 |
| --- | --- |
| 曲库（含定数、物量） | `GET /api/v0/maimai/song/list?version=25500&notes=true` |
| 单曲详情 | `GET /api/v0/maimai/song/{id}` |
| 曲目别名 | `GET /api/v0/maimai/alias/list` |
| 收藏品分类 | `GET /api/v0/maimai/collection-genre/list` |
| 称号 / 头像 / 姓名框 / 背景框 | `GET /api/v0/maimai/{trophy,icon,plate,frame}/list` |
| 玩家资料 / Best 50 / 单曲成绩 / Rating 趋势 | `/api/v0/maimai/player/...`（需开发者 Token） |

曲绘、试听音频、收藏品图标取自 `https://assets2.lxns.net/maimai/...`。

线上实测（2026-10）：曲目 1344 首（标准 543 / DX 799 / 宴会 62）、
谱面 5502 个、别名 1067 条、称号 3031 个、头像 1059 个、
姓名框 400 个、背景框 353 个。可随时用下面的自检脚本复核：

```bash
dart run tool/check_api.dart
```

## 功能

- **查歌**：关键词（曲名 / 曲师 / 别名）、分类、版本、定数区间、物量区间、
  谱面类型与难度筛选，多种排序，卡片 / 列表两种视图，分页加载。
- **曲目详情**：曲绘预览、BPM / 曲师 / 分类 / 版本、各难度定数与物量分解、
  别名、谱面预览、收藏标记、试听。
- **收藏夹**：多文件夹、导入导出，本地持久化。
- **成绩**：玩家概览、Best 35 + Best 15、单曲最佳、全部成绩、
  Rating 趋势折线图、吃分建议（收益最大的谱面）。
- **收藏品**：称号 / 头像 / 姓名框 / 背景框检索与详情、达成条件。
- **工具**：单谱 Rating 计算器、容错（可失误数）计算、随机曲目 / 出勤转盘、
  等级与判定表、Rating 颜色对照。
- **外观**：亮 / 暗 / 跟随系统，动态取色（Material You），自定义主题色与字号。

## 目录结构

```
lib/
  core/       api_client（lxns 接口）、app_state（全局状态）、
              settings（本地存储）、rating（Rating 计算）、
              constants（枚举与工具）、palette（配色）、proxy（可选的 sing-box 代理）
  models/     接口模型：Song / SongDifficulty / Notes / Score / Player / Collection ...
  pages/      查歌、曲目详情、收藏夹、成绩、收藏品、工具、设置
  widgets/    通用组件与歌曲卡片
tool/
  check_api.dart   线上接口 + 模型解析自检
```

## 构建

```bash
flutter pub get

# Windows
flutter build windows --release

# Android（需 SDK 与 NDK）
flutter build apk --release
```

Windows 构建产物：`build/windows/x64/runner/Release/maisearchsong.exe`，
整个 `Release` 目录需一并分发。

### Windows 构建注意

`windows/CMakeLists.txt` 里把 `CMAKE_INSTALL_PREFIX` 固定为可执行文件所在目录。
Flutter 模板默认的 `C:/Program Files/<项目名>` 在无管理员权限时会令
`install` 步骤失败。

`audioplayers_windows` 首次构建会用 `nuget` 拉取
`Microsoft.Windows.ImplementationLibrary`。若机器上 NuGet 的
`%LOCALAPPDATA%\NuGet` 或 `%TEMP%\NuGetScratch` 不可写，把 `NUGET_PACKAGES`、
`NUGET_HTTP_CACHE_PATH`、`TMP` 指到可写目录后再构建。

## 说明

成绩相关页面需要开发者 API Token（设置页填写）。
`flutter_singbox_client` 仅提供 Android 原生实现，因此加速线路只在 Android
端可用；其他平台自动跳过并直连，不会抛 `MissingPluginException`。

## 本地存储

设置、收藏夹与曲库缓存优先写入 `flutter_local_db`（LMDB）。存储目录按以下
顺序探测，取第一个真正可写的：

1. 应用支持目录（`path_provider`，Windows 为
   `%APPDATA%\<包名>\<应用名>\WumengSearchSong`）
2. 应用文档目录
3. 可执行文件旁的 `userdata/` 目录
4. 系统临时目录

若数据库无法打开，会自动退化为同目录下的 `maisearchsong.json` 文件后端；
若所有目录都不可写，则退化为纯内存存储（本次运行有效）。这样在任何权限
环境下应用都能启动并保存设置。

`data/` 是 Flutter 的资源目录，请勿删除；运行期数据在 `userdata/`，可以
安全清空以重置应用。

## 测试

```bash
flutter test
```

`test/render_test.dart` 用 `_ref/songlist.json` 的真实曲库快照驱动各页面渲染，
覆盖查歌列表、工具页全部入口、曲目详情、计算器、玩家页空态与收藏品页。

