# Project Graph 历代 Release 更新整理

采集时间：2026-10-03 17:37 UTC。仓库：[graphif/project-graph](https://github.com/graphif/project-graph)。

本文整理采集时 GitHub 上公开可见的全部 Release，以更新要点为主，覆盖各版本的新功能、交互改进、重要修复、兼容性变化及明确披露的未完成事项。它描述上游发布历史，不能用于认定本地 Godot 实验分支已经实现这些功能。

## 阅读范围与整理口径

- 共 **227 条 Release**，发布日期从 **2024-08-31** 至 **2026-10-03**；GitHub 标记为预发布的有 **12 条**，正文完全为空的有 **21 条**。
- 按代际分组，每组以发布日期倒序排列；所有日期采用 GitHub `published_at` 的 UTC 日期，可能与北京时间跨一天。
- 标签名称包含 alpha/beta/rc 的版本按预发布阅读，即使 GitHub 未设置预发布标记。v1.8.0-beta.1 就存在这种差异。
- 逐版摘要以发布正文为依据，合并中英重复、重复提交和无语义合并记录；常规赞助名单、宣传、依赖维护及文档杂项未逐条转录。具体提交与完整细目见每版原始链接。
- 原文由 AI 生成的条目保留来源标记。作者明确写出的“尝试修复”“实验”“仍在开发”均不提升为稳定实现；同版出现撤回提交时，特别说明结果的不确定性。
- v4.0.0 和 v2.0.0 只有图片正文，已读取发布图片后提炼；其他带图但有文字的说明以文字为主，图中额外细节不自行补写。
- Nightly 单独列出，属于滚动更新渠道；空说明或没有变更清单不等于该版本没有代码变化。
- 范围仅包括当前公开 Release，不包含只有 Git tag、已删除的发布或未公开草稿，也不把未发布的 master 提交当作 Release。

## 目录

- [演进要点](#演进要点)
- [4.x](#4x)
- [3.x](#3x)
- [2.x 正式版本](#2x-正式版本)
- [2.x 预发布版本](#2x-预发布版本)
- [1.x 正式版本](#1x-正式版本)
- [1.x 预发布版本](#1x-预发布版本)
- [早期版本与 PyQt](#早期版本与-pyqt)
- [Nightly](#nightly)
- [缺失说明与来源索引](#缺失说明与来源索引)

## 演进要点

以下为对逐版说明的归纳；版本定位依据各版发布内容，并非对源码或运行行为的独立验证。

| 阶段 / 里程碑 | 发布日期（UTC） | 主要变化 |
| --- | --- | --- |
| [PyQt 重写公告](https://github.com/graphif/project-graph/releases/tag/pyqt-2024-10-3) | 2024-10-03 | 宣布以 Tauri、TypeScript 与 Rust 替代 Python/PyQt。 |
| [v1.0.0](https://github.com/graphif/project-graph/releases/tag/v1.0.0) | 2024-11-16 | 完成 Tauri 重写，建立嵌套分组、透明窗口和子树操控等基础。 |
| [v1.1.0](https://github.com/graphif/project-graph/releases/tag/v1.1.0) | 2024-12-26 | Android 构建、保存备份、逻辑计算与工具栏改版。 |
| [v1.3.0](https://github.com/graphif/project-graph/releases/tag/v1.3.0) | 2025-01-24 | 节点手动换行，逻辑引擎加入变量和创建节点。 |
| [v1.7.0](https://github.com/graphif/project-graph/releases/tag/v1.7.0) | 2025-04-23 | 无向边、超边与凸包形态，支持表达多对象关系。 |
| [v2.0.0](https://github.com/graphif/project-graph/releases/tag/v2.0.0) | 2025-08-21 | 多标签页、右键菜单和全新 shadcn/ui 界面。 |
| [v2.5.0](https://github.com/graphif/project-graph/releases/tag/v2.5.0) | 2025-11-22 | 引用块与双链。 |
| [v2.7.0](https://github.com/graphif/project-graph/releases/tag/v2.7.0) | 2025-12-16 | 同向多重边。 |
| [v2.10.0](https://github.com/graphif/project-graph/releases/tag/v2.10.0) | 2026-02-23 | 分组锁定与内部布局保护。 |
| [v2.11.0](https://github.com/graphif/project-graph/releases/tag/v2.11.0) | 2026-03-05 | 图片背景化与背景管理器。 |
| [v2.12.0](https://github.com/graphif/project-graph/releases/tag/v2.12.0) | 2026-04-18 | 孪生节点及相关文件格式更新。 |
| [v3.0.0](https://github.com/graphif/project-graph/releases/tag/v3.0.0) | 2026-05-05 | 扩展插件、自定义节点/右键菜单，AI SDK 与工程缩略图。 |
| [v3.1.0](https://github.com/graphif/project-graph/releases/tag/v3.1.0) | 2026-06-05 | prg:// 深链接、图片压缩及 Linux 运行设置。 |
| [v3.2.0](https://github.com/graphif/project-graph/releases/tag/v3.2.0) | 2026-06-16 | 弧形连线、OCR 与图片操作扩展。 |
| [v4.0.0](https://github.com/graphif/project-graph/releases/tag/v4.0.0) | 2026-07-20 | 标签/子窗口统一、分屏停靠、MCP/Skills、饼状菜单、命令面板与表单 API。 |
| [v4.1.0](https://github.com/graphif/project-graph/releases/tag/v4.1.0) | 2026-07-26 | 早期多人协作。 |
| [v4.2.4](https://github.com/graphif/project-graph/releases/tag/v4.2.4) | 2026-09-06 | CLI 与跨平台文件占用管理，是采集时最新的普通发布。 |

### 升级时应保留的历史边界

- 2.0 Alpha 初期不能直接读取旧工程；后续出现旧文件迁移修复，因此不能把 Alpha 限制套用到所有 2.x。参见 [v2.0.0-alpha.1](https://github.com/graphif/project-graph/releases/tag/v2.0.0-alpha.1)、[v2.0.14](https://github.com/graphif/project-graph/releases/tag/v2.0.14)。
- 2.4 的极大/极小尺度内容可能超出旧版可定位范围；2.8 加入结构版本元数据，2.12 明确触发工程升级。参见 [v2.4.0](https://github.com/graphif/project-graph/releases/tag/v2.4.0)、[v2.8.0](https://github.com/graphif/project-graph/releases/tag/v2.8.0)、[v2.12.0](https://github.com/graphif/project-graph/releases/tag/v2.12.0)。
- 自动保存、吸附对齐、生长自动布局等默认设置曾调整；历史版本的默认行为不能直接视为当前默认值。参见 [v3.0.6](https://github.com/graphif/project-graph/releases/tag/v3.0.6)、[v3.3.0](https://github.com/graphif/project-graph/releases/tag/v3.3.0)。
- 部分快捷操作被移除或转交插件，例如循环空间、引力布局和 okk/err。参见 [v3.0.1](https://github.com/graphif/project-graph/releases/tag/v3.0.1)、[v3.0.3](https://github.com/graphif/project-graph/releases/tag/v3.0.3)。

## 4.x

### v4.2.4 · 2026-09-06

发布日期（UTC）：2026-09-06 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v4.2.4)

- 加入 Project Graph CLI 和跨平台文件占用管理。
- 虚线或无边框的分组不再切换到大标题形态。
- 包含 macOS CI 修复尝试。

### v4.2.3 · 2026-08-10

发布日期（UTC）：2026-08-10 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v4.2.3)

- 协作加入光标同步、Cursor Chat 与附件。
- 修正 Linux 构建、CEF 重复启动崩溃和窗口显示问题。
- 改善连线端点设置、macOS 顶栏双击、浅色边框及设置默认值。原文还记录了撤回 macOS 圆角修复的提交。

### v4.2.2 · 2026-08-05

发布日期（UTC）：2026-08-05 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v4.2.2)

恢复多人协作的可用性。

### v4.2.1 · 2026-08-03

发布日期（UTC）：2026-08-03 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v4.2.1)

将文本节点边框配置更名为 forceHideTextNodeBorder，并校正默认值。

### v4.2.0 · 2026-08-02

发布日期（UTC）：2026-08-02 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v4.2.0)

- 加入 Agent Trace 和节点边框设置。
- 分组折叠/展开结合树布局，涂鸦自动纳入所在分组，树转框可撤销。
- 修复标签切换、快捷键重置刷新及浅色文字。
- 协作入口收进子菜单，代理删除节点时同步清理连线。

### v4.1.1 · 2026-07-26

发布日期（UTC）：2026-07-26 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v4.1.1)

修正 Windows 23H2 及之后版本可能无法取得设备标识的问题。

### v4.1.0 · 2026-07-26

发布日期（UTC）：2026-07-26 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v4.1.0)

- 首次发布多人协作。发布时属于早期功能，需要联系开发者取得邀请码。
- 此要求仅描述该版本当时的情况。

### v4.0.1 · 2026-07-22

发布日期（UTC）：2026-07-22 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v4.0.1)

调整树生长方向的提示箭头，注册 Tauri 剪贴板插件，并修改 CEF 构建缓存策略。

### v4.0.0 · 2026-07-20

发布日期（UTC）：2026-07-20 · 普通发布 · 说明来源：图片说明（已读图提炼） · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v4.0.0)

- 说明为六张发布海报。根据图片：统一标签页与子窗口，支持分屏、浮动及停靠。
- 应用 AI 接入 MCP/Skills，但不支持 OAuth MCP。
- 加入可配置饼状菜单、启动草稿叠加欢迎菜单和 Ctrl+K 命令面板。
- 扩展新增 prg.form 表单 API。

## 3.x

### v3.4.0 · 2026-07-08

发布日期（UTC）：2026-07-08 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v3.4.0)

- 扩展支持自定义主题，加入 Catppuccin 与扩展市场入口。
- 增强无向边形态、分组虚线、树方向提示和 Markdown 渲染。
- AI 工具响应采用 TOON。
- 修正扩展删除残留连线、主题应用及插件快捷键刷新。

### v3.3.0 · 2026-07-05

发布日期（UTC）：2026-07-05 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v3.3.0)

- 补充箭头样式与连线快速创建配置，改善扩展显示清晰度。
- 修正菱形箭头缩进和直线转弧线时状态丢失。
- 实时输入树布局默认关闭。

### v3.2.5 · 2026-07-04

发布日期（UTC）：2026-07-04 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v3.2.5)

- 修正多方向子树间距、框内树布局倾斜及快捷键反向处理。
- 应用切换后保留编辑状态。
- 调整 CUDA 条件和构建特性替换脚本。

### v3.2.4 · 2026-07-02

发布日期（UTC）：2026-07-02 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v3.2.4)

- 菜单栏支持自定义。
- 加入 prg 链接导出、树转单层嵌套框、Tab 探针开关及子树转向快捷键。
- 布局支持简单分组避让和输入时自动布局。
- 删除节点后可选中其父节点。

### v3.2.3 · 2026-06-29

发布日期（UTC）：2026-06-29 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v3.2.3)

- 弧线文字可用 Enter 编辑，树布局为连线文字预留空间。
- 增加准星样式与带边扩散选择。
- 最近文件检索忽略大小写，改善设置兼容性错误提示。

### v3.2.2 · 2026-06-25

发布日期（UTC）：2026-06-25 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v3.2.2)

- 刷新操作同步更新对象引用。
- 修正粘贴图片及生成内容后不能立即选择、拖动的问题。

### v3.2.1 · 2026-06-24

发布日期（UTC）：2026-06-24 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v3.2.1)

- 重构分组层级树，集中修复嵌套、折叠及大标题形态的交互与显示。
- 新增 AI 图片识别、回答写入文本节点、最近文件键盘操作、快捷设置图钉和默认右键弧线。
- 改善文本缩放、编辑区域及各平台启动、图片拖入问题。

### v3.2.0 · 2026-06-16

发布日期（UTC）：2026-06-16 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v3.2.0)

- 引入可拖动曲率和文字位置的弧形连线，并支持直线转换。
- 加入 OCR、已有图片压缩、准星定制和图片自动包框。
- 改善分组创建、图片归属、附件清理后的保存状态及文件解析报错。

### v3.1.0 · 2026-06-05

发布日期（UTC）：2026-06-05 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v3.1.0)

- 加入 prg:// 深链接，可打开工程并定位实体或指定相机位置、缩放。
- 增加图片压缩和黑白转换、Linux 运行设置与 UI 缩放、手写笔支持。
- 完善快捷键匹配和搜索面板键盘操作。

### v3.0.8 · 2026-05-30

发布日期（UTC）：2026-05-30 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v3.0.8)

- Linux 采用 QtWebEngine，完善跨平台构建和图片粘贴。
- 增加备份目录策略、图片导入排序/时间设置、滚轮反向、UI 缩放及空白双击配置。
- Windows 文件复用窗口的相关修复在同一说明中出现撤回，不能视为最终保证。

### v3.0.7 · 2026-05-19

发布日期（UTC）：2026-05-19 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v3.0.7)

缓解自动保存带来的卡顿。

### v3.0.6 · 2026-05-18

发布日期（UTC）：2026-05-18 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v3.0.6)

- 提供选中边框随缩放调粗、编辑边框透明度设置。
- 自动保存和吸附对齐默认关闭。
- 弱化极端缩放时的编辑特效，增加标签栏悬停反馈。

### v3.0.5 · 2026-05-17

发布日期（UTC）：2026-05-17 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v3.0.5)

- 加入账户系统、自定义字体、扩展重载和扩展市场链接，快捷设置整合到个性化页面。
- 修正 macOS 双击工程打开、初次定位误报警及 Markdown 六级标题导出。

### v3.0.4 · 2026-05-14

发布日期（UTC）：2026-05-14 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v3.0.4)

- 简化并降低色盘饱和度，提供悬停预览开关，避免悬停产生大量历史。
- 恢复方向端点快捷键并新增居中端点操作。

### v3.0.3 · 2026-05-13

发布日期（UTC）：2026-05-13 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v3.0.3)

- 支持节点自动命名模板和持续按住反引号自由生长。
- 修正非标准连线子树布局及新建草稿警告。
- 移除 Ctrl+T 的批量反向功能、循环空间和按 G 引力布局，避免冲突或误解。

### v3.0.2 · 2026-05-08

发布日期（UTC）：2026-05-08 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v3.0.2)

- 完善扩展类型包、生成器和发布流程，处理缺失 README。
- 修正 AI 对话停留在思考状态的问题。

### v3.0.1 · 2026-05-06

发布日期（UTC）：2026-05-06 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v3.0.1)

- 移除 okk、err 的内置实现并提示使用插件。
- 修正连线图标、数值滑块过度跳变和类型问题。

### v3.0.0 · 2026-05-05

发布日期（UTC）：2026-05-05 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v3.0.0)

- 确立扩展插件与自定义节点体系，允许定制右键菜单并为命令配置图标、条件。
- AI 框架由 LangChain.js 切换到 AI SDK，加入文本导入和右键 AI 处理。
- 增加工程缩略图、第二备份路径、平行移动，改善连线端点、文字描边、吸附布局及旧文件升级。

### v3.0.0-alpha.1 · 2026-02-10

发布日期（UTC）：2026-02-10 · 预发布 · 说明来源：空说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v3.0.0-alpha.1)

- 发布正文为空，未提供可整理的更新内容。
- 请以原始 Release 页面为准。

## 2.x 正式版本

### v2.12.4 · 2026-04-28

发布日期（UTC）：2026-04-28 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.12.4)

- 初步加入 LaTeX 节点，改善预览与改色。
- 修正自由生长的激光提示不消失，调整代码组织。

### v2.12.3 · 2026-04-26

发布日期（UTC）：2026-04-26 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.12.3)

- 快捷设置支持任意类型配置，加入详情自动填充、Tab 探针连线、扩展工程查看和创建节点大小修正。
- 优化方向键跨分组选中及按键移动后的停止漂移。

### v2.12.2 · 2026-04-22

发布日期（UTC）：2026-04-22 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.12.2)

- 引入可定制、可带修饰键的持续型快捷键，用于移动相机、缩放和移动实体。
- 修正强制换行后边框更新与选择提示。

### v2.12.1 · 2026-04-21

发布日期（UTC）：2026-04-21 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.12.1)

- AI 使用 LangChain.js。
- 改进引用块与节点宽度，多重边避免重叠。
- 节点内边距、边框、圆角、连线和布局间距按字号调整。
- 增加按视野定创建大小及文件位置快捷键，修正富文本详情、端点和数值越界。

### v2.12.0 · 2026-04-18

发布日期（UTC）：2026-04-18 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.12.0)

- 正式引入孪生节点，可通过右键或 Shift+Y 创建关联副本。
- 修正空分组加载位置并触发工程格式升级。
- 空标题分组不显示顶部区域，处理孪生关系与任务标记的冲突。

### v2.11.14 · 2026-04-17

发布日期（UTC）：2026-04-17 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.11.14)

- 集中修复分组折叠在撤销/重做及多层嵌套中的状态、隐藏和点击穿透。
- 折叠框可显示展开轮廓。
- 扩大相机缩放范围并加入极限重置、缩放读数。
- 引用块内容可被搜索，无修改退出编辑不再标记未保存。

### v2.11.13 · 2026-04-15

发布日期（UTC）：2026-04-15 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.11.13)

- 右键提示读取自定义快捷键，加入三种宽度统一命令。
- 同文件引用块双击直接定位源头。
- 修复备份目录错误，选中网状文本导出按纵坐标排列，并移除全量网状关系导出入口。

### v2.11.12 · 2026-04-13

发布日期（UTC）：2026-04-13 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.11.12)

- 改善编辑/选中辅助提示及菜单快捷键提示。
- 树摘除检查出边，避免无效操作。
- 捐赠页支持表格和刷新，调整图标。

### v2.11.11 · 2026-04-11

发布日期（UTC）：2026-04-11 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.11.11)

- 加入按键序列提示、编辑状态反馈及拖动晃动摘除节点选项。
- 可配置框间连线调粗，减缓字体缩放。
- 修正 Windows 图片导出路径，并改善框选提示及释放反馈。

### v2.11.10 · 2026-04-06

发布日期（UTC）：2026-04-06 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.11.10)

- 增强连线吸附、图片精确端点和非法树结构提示。
- AI 聊天可中止并修正文字复制。
- 改进 SVG 对曲线、URL、换行、字号和详情的导出。
- 增加导出/虚实线快捷键、图片背景缩略图及生长继承颜色选项。

### v2.11.9 · 2026-03-29

发布日期（UTC）：2026-03-29 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.11.9)

- 4K AMD 设备提示可永久关闭，尝试改善 macOS 工程权限请求。
- 中键双击分别配置空白定位和实体 URL 打开行为。

### v2.11.8 · 2026-03-27

发布日期（UTC）：2026-03-27 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.11.8)

- 分组碰撞默认禁用。
- 修正浅色主题下详情编辑选区不可辨识的问题。

### v2.11.7 · 2026-03-24

发布日期（UTC）：2026-03-24 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.11.7)

- 图片导入支持 JPG/JPEG/WebP。
- 虚线排除在树识别及树布局之外。
- 修正 macOS 文件拖入位置、Mermaid 导出与重复搜索框，缩短路径节点表面文字并将长内容放入详情。

### v2.11.6 · 2026-03-18

发布日期（UTC）：2026-03-18 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.11.6)

修正取消工程升级时舞台被清空的问题。

### v2.11.5 · 2026-03-14

发布日期（UTC）：2026-03-14 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.11.5)

- AI 工具支持排列选中对象与删除节点，补充调用展示和供应商兼容。
- 紧密堆积期间暂时禁用分组碰撞。

### v2.11.4 · 2026-03-12

发布日期（UTC）：2026-03-12 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.11.4)

- 加入分组碰撞与树生长位置提示。
- 改善多层锁定拖动和宽度调整。
- 隐私模式隐藏图片并替换标签文字，优化 macOS 窗口按钮。

### v2.11.3 · 2026-03-10

发布日期（UTC）：2026-03-10 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.11.3)

- 调整字体缩放的不动点，减少节点位置漂移。
- 增加快捷键重叠说明，准星选择命令由 q 改为 qq。

### v2.11.2 · 2026-03-08

发布日期（UTC）：2026-03-08 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.11.2)

- 补充 AI 工具及对话交互，修正报错后持续加载。
- 修复多层锁定分组被意外拖动。

### v2.11.1 · 2026-03-07

发布日期（UTC）：2026-03-07 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.11.1)

- Markdown 导入自动排成向右的树。
- 顶栏加入明暗主题切换。
- 修正全屏快捷键冲突与 SVG 图片节点遗漏。

### v2.11.0 · 2026-03-05

发布日期（UTC）：2026-03-05 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.11.0)

- 图片可转为不可选中的背景，通过背景管理器解锁。
- 新增准星选中。
- 修正分组移动速度叠加、背景图层顺序，编辑文本时停止相机漂移。

### v2.10.2 · 2026-02-25

发布日期（UTC）：2026-02-25 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.10.2)

- 锁定框增加角落标识，加入可选关闭标签页快捷键。
- 字体大小操作移到更浅的右键菜单层级。

### v2.10.1 · 2026-02-24

发布日期（UTC）：2026-02-24 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.10.1)

补齐锁定分组对深层重命名、撤销及劈砍的保护。

### v2.10.0 · 2026-02-23

发布日期（UTC）：2026-02-23 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.10.0)

- 分组支持锁定/解锁：内部内容禁止编辑移动，整体免于劈砍，阻止外部跳入及相关连线被斩断。
- 提供默认未启用的 Ctrl+L 绑定。
- 修正涂鸦粗细和反向树移动，扩充音效库。

### v2.9.16 · 2026-02-16

发布日期（UTC）：2026-02-16 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.9.16)

- 新增反向树移动配置与印尼语。
- 修正 macOS 舞台粘贴崩溃及繁体转换。

### v2.9.15 · 2026-02-11

发布日期（UTC）：2026-02-11 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.9.15)

修正贝塞尔连线文字的换行显示，并清理未使用特效。

### v2.9.14 · 2026-02-04

发布日期（UTC）：2026-02-04 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.9.14)

屏蔽 Ctrl+R 的默认刷新，增加快捷键冲突检查。

### v2.9.13 · 2026-01-31

发布日期（UTC）：2026-01-31 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.9.13)

- 增加迷你窗口快捷键，调整逻辑节点入口。
- 修正重开时双向连线重叠。
- 重整导入导出，暂时固定中括号缩放绑定以避免按键释放失效。

### v2.9.12 · 2026-01-29

发布日期（UTC）：2026-01-29 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.9.12)

- 欢迎页提供随机技巧，加入舞台颜色分布表及分组背景填充方式。
- 改善生成菜单，修正窗口缩放闪烁和 macOS 中括号持续缩放。

### v2.9.11 · 2026-01-23

发布日期（UTC）：2026-01-23 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.9.11)

Windows 全屏暂用 Ctrl+F11，绕开 F11 与拖动视野、任务栏闪烁的冲突。

### v2.9.10 · 2026-01-22

发布日期（UTC）：2026-01-22 · 普通发布 · 说明来源：提交记录 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.9.10)

- 加入子窗口、全屏快捷键和欢迎语随机选择。
- 可限制方向键选择范围。
- 改善自适应换行边框、macOS 初始滚轮缩放及发布报告生成失败处理。

### v2.9.9 · 2026-01-21

发布日期（UTC）：2026-01-21 · 普通发布 · 说明来源：空说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.9.9)

- 发布正文为空，未提供可整理的更新内容。
- 请以原始 Release 页面为准。

### v2.9.8 · 2026-01-20

发布日期（UTC）：2026-01-20 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.9.8)

- 补充多种狙击镜遮罩。
- 自动命名仅在当前视野寻找序号。
- 修正 Markdown 生成后的悬空连线。

### v2.9.7 · 2026-01-19

发布日期（UTC）：2026-01-19 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.9.7)

- 图片右键支持红蓝通道交换与复制到系统剪贴板。
- 减少通知打扰。

### v2.9.6 · 2026-01-16

发布日期（UTC）：2026-01-16 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.9.6)

- 图片可右键导出，端点可重置到中心。
- 加入子树格式化及生成快捷键键盘图。
- 收紧链式树间距，改善专注模式工具栏透明显示。

### v2.9.5 · 2026-01-14

发布日期（UTC）：2026-01-14 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.9.5)

- 加入右侧快捷设置栏及工程自动升级提示。
- 弱化 AMD 提醒措辞。

### v2.9.4 · 2026-01-07

发布日期（UTC）：2026-01-07 · 普通发布 · 说明来源：空说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.9.4)

- 发布正文为空，未提供可整理的更新内容。
- 请以原始 Release 页面为准。

### v2.9.3 · 2026-01-05

发布日期（UTC）：2026-01-05 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.9.3)

- 新节点创建后可直接编辑，加入粘贴文字阈值与大小配置。
- 最近文件提供嵌套框视图和隐私模式，更新教程链接。

### v2.9.2 · 2026-01-03

发布日期（UTC）：2026-01-03 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.9.2)

恢复实体详情按钮的可见性。

### v2.9.1 · 2026-01-01

发布日期（UTC）：2026-01-01 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.9.1)

- 文本撤销栈为空时可退出编辑。
- 修正方向创建节点需要两次撤销及重开后节点大小归零。
- macOS 窗口圆角、AMD 检测更新，默认避免 Ctrl+滚轮误操作相机。

### v2.9.0 · 2026-01-01

发布日期（UTC）：2026-01-01 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.9.0)

- 快捷键可逐项开关。
- 实验性加入文本节点字号缩放，并改进繁体中文。

### v2.8.0 · 2025-12-25

发布日期（UTC）：2025-12-25 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.8.0)

- 加入虚线和双实线。
- 工程中保存 metadata.msgpack 以记录结构版本。

### v2.7.2 · 2025-12-23

发布日期（UTC）：2025-12-23 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.7.2)

增加最大缩放限制配置，Shift+F 可恢复重置前的视野状态。

### v2.7.1 · 2025-12-17

发布日期（UTC）：2025-12-17 · 普通发布 · 说明来源：空说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.7.1)

- 发布正文为空，未提供可整理的更新内容。
- 请以原始 Release 页面为准。

### v2.7.0 · 2025-12-16

发布日期（UTC）：2025-12-16 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.7.0)

- 允许同方向的重复有向边，服务图片多点标注和逻辑节点复用。
- 当时仍需手动调整端点避免重叠。
- 修正快捷键切主题时画布未换色，版本号可打开官网历史。

### v2.6.8 · 2025-12-11

发布日期（UTC）：2025-12-11 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.6.8)

- 增加大标题透明度和引用块精确端点。
- 修正欢迎页排序、快速重复打开及文本转框漏纳入质点。

### v2.6.7 · 2025-12-10

发布日期（UTC）：2025-12-10 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.6.7)

- 输入框快捷键不再传到舞台。
- 搜索可限定选中对象或其外接矩形范围。

### v2.6.6 · 2025-12-09

发布日期（UTC）：2025-12-09 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.6.6)

可配置分组进入大标题形态的缩放阈值。

### v2.6.5 · 2025-12-08

发布日期（UTC）：2025-12-08 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.6.5)

- 图片可拖拽角落缩放。
- 修正连线反向和文本转引用块后的悬空连线。

### v2.6.4 · 2025-12-07

发布日期（UTC）：2025-12-07 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.6.4)

- 加入 DAG 布局操作、生成进度提示及同名 TXT 自动导入开关。
- 嫁接与摘除适用于非文本节点。

### v2.6.3 · 2025-12-04

发布日期（UTC）：2025-12-04 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.6.3)

- 改善拖拽连线起点的轨迹判断及宏观凸包显示。
- 加入树旋转开关和嫁接/摘除快捷键，无向边可键盘删除。

### v2.6.2 · 2025-12-02

发布日期（UTC）：2025-12-02 · 普通发布 · 说明来源：原文含 AI 自动总结 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.6.2)

- 保存中阻止关闭工程，完善凸包/圆形碰撞检测。
- 增加 DAG 布局及拖线旋转接口开关，调整自动命名说明。

### v2.6.1 · 2025-12-01

发布日期（UTC）：2025-12-01 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.6.1)

- 显示保存进行状态和标签加载动画。
- 大标题切换阈值随分组大小调整，图片缩放提供读数。
- 快捷键设置可独立于文档打开。
- 修正相机摩擦崩溃及选中节点右键连线/菜单冲突。

### v2.6.0 · 2025-11-29

发布日期（UTC）：2025-11-29 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.6.0)

- 图片连线可落在任意精确位置，选中内容可导出 PNG。
- 文本生成树时采用适合后续格式化的左右端点。

### v2.5.2 · 2025-11-25

发布日期（UTC）：2025-11-25 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.5.2)

- 备份目录可自定义，数量限额按每个文件独立计算。
- 修正 macOS Control 操作冲突及导出文字弹窗溢出。
- 分组重命名用 Shift+Enter 确认，教程改称功能说明书。

### v2.5.1 · 2025-11-24

发布日期（UTC）：2025-11-24 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.5.1)

- 生长后镜头行为和退出编辑后树布局可配置。
- 加入随机聚焦与停止漂移。
- 节点转框加入角落质点。
- 改善质点宏观详情显示、macOS 按键提示及带详情的文本导出。

### v2.5.0 · 2025-11-22

发布日期（UTC）：2025-11-22 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.5.0)

发布引用块与双链功能。说明主要依赖图片，本条仅提炼原文明确写出的功能名称。

### v2.4.4 · 2025-11-16

发布日期（UTC）：2025-11-16 · 普通发布 · 说明来源：原文含 AI 自动总结 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.4.4)

- 完善引用块创建、自动补全、跳转、刷新和缩放。
- 加入防误删除配置、涂鸦常用色和 PNG 拼图间隔。
- 修正引用识别及逻辑节点输入问题。

### v2.4.3 · 2025-11-11

发布日期（UTC）：2025-11-11 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.4.3)

- 支持设置相机具体位置和缩放。
- 隐私显示加入凯撒移位。
- 修正节点转框详情丢失、浅色快捷键按钮，以及 macOS 输入法回车误退出。

### v2.4.2 · 2025-11-10

发布日期（UTC）：2025-11-10 · 普通发布 · 说明来源：原文含 AI 自动总结 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.4.2)

- 增加 Mermaid 导入。
- 修正拖动中空格误进入编辑，以及退出后框选/点击失效。

### v2.4.1 · 2025-11-09

发布日期（UTC）：2025-11-09 · 普通发布 · 说明来源：原文含 AI 自动总结 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.4.1)

- 支持 macOS Home/End 选择、编辑中生长同级节点、反向狙击镜遮罩。
- 修正跨文件附件复制、缺失图片提示和混合类型树的框标题。
- 鼠标模式入口转到底栏。

### v2.4.0 · 2025-11-08

发布日期（UTC）：2025-11-08 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.4.0)

- 大幅放开缩放范围，极小尺度可到 10^-10。
- 增加框选区域创建框、小窗口适配及 Mermaid 导出。
- 文本生成树/图降为线性复杂度，改进相机速度和同级命名。巨大内容在旧版可能无法完整定位。

### v2.3.1 · 2025-11-03

发布日期（UTC）：2025-11-03 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.3.1)

- 中括号支持持续缩放，历史记录可选择时间优先或内存优先。
- 修正图片反色持久化和 SVG 改色。
- 纯文本生成树/图的复杂度降为 O(N)。

### v2.3.0 · 2025-11-01

发布日期（UTC）：2025-11-01 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.3.0)

- 可用 ww/ss/aa/dd 改变树生长方向，支持连续多方向键盘构建。
- 改善多方向树布局的重叠和偏移。

### v2.2.1 · 2025-10-28

发布日期（UTC）：2025-10-28 · 普通发布 · 说明来源：原文含 AI 自动总结 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.2.1)

修正编辑状态同级生长条件和 UI 快捷键自定义持久化。

### v2.2.0 · 2025-10-26

发布日期（UTC）：2025-10-26 · 普通发布 · 说明来源：原文含 AI 自动总结 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.2.0)

- 文件拖入窗口按区域执行不同操作。
- 加入路径节点中键打开、相对路径跳转及最近文件传送门。
- 支持反向切换标签和同目录新建工程，更新欢迎与引导界面并修正 macOS 路径行为。

### v2.1.2 · 2025-10-25

发布日期（UTC）：2025-10-25 · 普通发布 · 说明来源：原文含 AI 自动总结 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.1.2)

- 树打包时按根节点自动命名，恢复 Markdown 树生成。
- 编辑中可创建同级，拆分/合并保留连线。
- 加入标签切换与直接打开工程路径，最近文件可逐项删除。
- 修正无工程时 UI 快捷键和多工程绑定同步。

### v2.1.1 · 2025-10-19

发布日期（UTC）：2025-10-19 · 普通发布 · 说明来源：原文含 AI 自动总结 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.1.1)

- 扩充同目录新建、递归导入历史工程、全局唤起窗口、音效配置和编辑中 Tab 生长。
- 改善树转框、紧密堆积、右键菜单及曲线。
- 补齐备份和窗口穿透恢复，修复多平台交互问题。

### v2.1.0 · 2025-10-18

发布日期（UTC）：2025-10-18 · 普通发布 · 说明来源：原文含 AI 自动总结 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.1.0)

- 纯文本生成树支持转义换行/缩进，加入 Mermaid UI、编辑中 Tab 子节点和空格拖动配置。
- 扩充音效及逻辑节点颜色区分。
- 改善备份、窗口穿透状态恢复和 Windows 狙击镜缩放。

### v2.0.33 · 2025-10-14

发布日期（UTC）：2025-10-14 · 普通发布 · 说明来源：原文含 AI 自动总结 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.33)

- 最近文件可递归导入目录中的工程并清空记录。
- 增加狙击镜提示，恢复舞台详情渲染限制设置，修复 nx 构建依赖。

### v2.0.32 · 2025-10-12

发布日期（UTC）：2025-10-12 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.32)

- 无向边聚合中心可移动，长文本粘贴采用固定宽度。
- 补回逻辑节点详情和全局快捷键开关。
- 修正宏观跳跃轮廓与 URL 改色。

### v2.0.31 · 2025-10-07

发布日期（UTC）：2025-10-07 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.31)

- 新手文件可联网下载并自动打开。
- 调整赞助内容与无向边命名。

### v2.0.30 · 2025-10-05

发布日期（UTC）：2025-10-05 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.30)

- 支持当前目录快速新建文件，放宽部分布局操作条件。
- 改善树布局、详情面板、拆分提示及右键说明。
- 修正质点曲线，优化框间连线粗度和空劈砍性能。

### v2.0.29 · 2025-10-02

发布日期（UTC）：2025-10-02 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.29)

修正最近文件刷新、macOS 回车检索卡死及 Command+S 导致界面偏移。

### v2.0.28 · 2025-10-01

发布日期（UTC）：2025-10-01 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.28)

- 文本节点可嫁接入树。
- 位置菜单移入设置。
- 暂时隐藏窗口穿透按钮但保留 Alt+2。
- 修正宏观分组标题溢出和保存时视野偏移，当时提醒 macOS 打包可能暂缓。

### v2.0.27 · 2025-09-27

发布日期（UTC）：2025-09-27 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.27)

- 完成自动保存/备份，加入 Alt+2 窗口穿透与标签独立子窗口。
- 合并节点支持自定连接符，保存时历史清理可配置。
- 改善分组跳出、加选反馈和子窗口阴影，修正涂鸦历史记录。

### v2.0.26 · 2025-09-22

发布日期（UTC）：2025-09-22 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.26)

修正复制含连线图后重开导致连线丢失/重叠，以及深层分组粘贴溢出。

### v2.0.25 · 2025-09-21

发布日期（UTC）：2025-09-21 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.25)

- 支持自定义主题和 AI 推理模型。
- 粘贴后不再强制重置视野，改为通知。
- 改善搜索瞭望渲染与 Windows 滚动条。

### v2.0.24 · 2025-09-21

发布日期（UTC）：2025-09-21 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.24)

- 补充背景网格开关、右键自定义颜色，菜单以撤销替换剪切。
- 修正暂停渲染后文本宽度和合并颜色透明度。

### v2.0.23 · 2025-09-20

发布日期（UTC）：2025-09-20 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.23)

- 简化质点为固定碰撞区域，支持中转创建。
- 扩充纯文本生成网图、图片/SVG 导入。
- 修正右键连线冲突与文字粘贴。
- 暂时关闭异常劈砍特效。账户系统被明确标为开发中。

### v2.0.22 · 2025-09-20

发布日期（UTC）：2025-09-20 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.22)

- 加入图片拖入与可直接拖动的质点，改善中转连线和粘贴后定位。
- 恢复闲置暂停渲染，修正详情显示及右键冲突。原文提示拖入位置尚有偏差。

### v2.0.21 · 2025-09-18

发布日期（UTC）：2025-09-18 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.21)

- 窗口操作进入菜单栏，加入窗口置顶。
- 历史文件超过 12 项时提供完整最近文件面板。

### v2.0.20 · 2025-09-17

发布日期（UTC）：2025-09-17 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.20)

- 恢复整数化渲染、颜色面板、详情展示、自动上色和目录生成嵌套框。
- 顶栏可设置自动命名，改善布局提示。

### v2.0.19 · 2025-09-16

发布日期（UTC）：2025-09-16 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.19)

- 恢复专注模式。
- 搜索覆盖详情，详情面板默认靠右并可拖动。
- 修正文本与详情互换造成崩溃，富文本转出时采用 Markdown 源码。

### v2.0.18 · 2025-09-15

发布日期（UTC）：2025-09-15 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.18)

- 全选显示实体与关系数量。
- 增加迁移提示、紧密堆积和涂鸦上色。
- 改善 macOS 直线涂鸦及节点搜索，但该版仍未支持详情检索。

### v2.0.17 · 2025-09-13

发布日期（UTC）：2025-09-13 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.17)

- 增加文本字符挤出、圆形凸包、色相旋转和 AI 创建节点工具。
- 优化树生长方向判断。
- 实验性提供孪生文本节点。
- 修正搜索输入、按键误移动及拖动历史频繁记录。

### v2.0.16 · 2025-09-11

发布日期（UTC）：2025-09-11 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.16)

加入可调半径的潜行/狙击镜模式，面向透明窗口使用场景。

### v2.0.15 · 2025-09-10

发布日期（UTC）：2025-09-10 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.15)

- 改善空格拖动，临时防止连续粘贴重叠。
- 调整暗色主题强调色，拆分可指定分隔符，合并后自动选中结果。

### v2.0.14 · 2025-09-08

发布日期（UTC）：2025-09-08 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.14)

修正较早工程向 2.0 迁移报错、创建节点误输入，以及 macOS 字体宽度。

### v2.0.13 · 2025-09-07

发布日期（UTC）：2025-09-07 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.13)

- 图片可快捷反色，AI 面板支持 Agent。
- 保存自动清理历史。
- 改善附件与失效路径提示、键盘进入编辑。
- macOS M3 涂鸦修复仍待用户确认。

### v2.0.12 · 2025-09-06

发布日期（UTC）：2025-09-06 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.12)

- 加入快捷键重置，减少模式/主题切换误触。
- 修正键盘编辑多输入字符、主题即时切换、分组复制漏内容与漏连线。
- 粘贴位置向下偏移。

### v2.0.11 · 2025-09-04

发布日期（UTC）：2025-09-04 · 普通发布 · 说明来源：空说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.11)

- 发布正文为空，未提供可整理的更新内容。
- 请以原始 Release 页面为准。

### v2.0.10 · 2025-09-03

发布日期（UTC）：2025-09-03 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.10)

- 大体修正历史记录满后撤销出现内容重叠。
- 原文仍建议该版本历史上限控制在约 20 条，因记录开销随历史长度平方增长。

### v2.0.9 · 2025-09-02

发布日期（UTC）：2025-09-02 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.9)

- 修正空劈砍写入历史及加载后撤销清空舞台。
- 同时披露历史满后内容重叠、保存未清历史等未解决问题，并提醒加载可能变慢。

### v2.0.8 · 2025-08-31

发布日期（UTC）：2025-08-31 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.8)

- 恢复 Ctrl+E 把文本作为文件路径或网页地址打开，加入右键入口。
- 标签管理器当时尚未完成。

### v2.0.7 · 2025-08-30

发布日期（UTC）：2025-08-30 · 普通发布 · 说明来源：空说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.7)

- 发布正文为空，未提供可整理的更新内容。
- 请以原始 Release 页面为准。

### v2.0.6 · 2025-08-28

发布日期（UTC）：2025-08-28 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.6)

- 增加纯文本生成树的界面入口和右键点击连线开关。
- 改善改色交互，缩短涂鸦删除特效。

### v2.0.5 · 2025-08-28

发布日期（UTC）：2025-08-28 · 普通发布 · 说明来源：空说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.5)

- 发布正文为空，未提供可整理的更新内容。
- 请以原始 Release 页面为准。

### v2.0.4 · 2025-08-25

发布日期（UTC）：2025-08-25 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.4)

- 修正粘贴图片红蓝通道颠倒。
- 附件可清理未使用图片，增加统一错误处理。

### v2.0.3 · 2025-08-24

发布日期（UTC）：2025-08-24 · 普通发布 · 说明来源：空说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.3)

- 发布正文为空，未提供可整理的更新内容。
- 请以原始 Release 页面为准。

### v2.0.2 · 2025-08-23

发布日期（UTC）：2025-08-23 · 普通发布 · 说明来源：空说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.2)

- 发布正文为空，未提供可整理的更新内容。
- 请以原始 Release 页面为准。

### v2.0.1 · 2025-08-21

发布日期（UTC）：2025-08-21 · 普通发布 · 说明来源：空说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.1)

- 发布正文为空，未提供可整理的更新内容。
- 请以原始 Release 页面为准。

### v2.0.0 · 2025-08-21

发布日期（UTC）：2025-08-21 · 普通发布 · 说明来源：图片说明（已读图提炼） · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.0)

说明仅有发布海报，图中强调多标签页、右键菜单和采用 shadcn/ui 的新界面，没有逐项修复清单。

## 2.x 预发布版本

### v2.0.0-rc.6 · 2025-08-21

发布日期（UTC）：2025-08-21 · 预发布 · 说明来源：空说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.0-rc.6)

- 发布正文为空，未提供可整理的更新内容。
- 请以原始 Release 页面为准。

### v2.0.0-rc.5 · 2025-08-17

发布日期（UTC）：2025-08-17 · 预发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.0-rc.5)

候选版加入透明窗口、命令行使用及设置/节点搜索。

### v2.0.0-rc.4 · 2025-08-17

发布日期（UTC）：2025-08-17 · 预发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.0-rc.4)

修正 Windows 无法打开 .prg 的问题。

### v2.0.0-rc.3 · 2025-08-16

发布日期（UTC）：2025-08-16 · 预发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.0-rc.3)

候选版补充多源无向边、欢迎页最近文件和深蓝主题，修正文字模糊。

### v2.0.0-rc.2 · 2025-08-12

发布日期（UTC）：2025-08-12 · 预发布 · 说明来源：空说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.0-rc.2)

- 发布正文为空，未提供可整理的更新内容。
- 请以原始 Release 页面为准。

### v2.0.0-rc.1 · 2025-08-09

发布日期（UTC）：2025-08-09 · 预发布 · 说明来源：空说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.0-rc.1)

- 发布正文为空，未提供可整理的更新内容。
- 请以原始 Release 页面为准。

### v2.0.0-beta.2 · 2025-08-06

发布日期（UTC）：2025-08-06 · 预发布 · 说明来源：空说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.0-beta.2)

- 发布正文为空，未提供可整理的更新内容。
- 请以原始 Release 页面为准。

### v2.0.0-beta.1 · 2025-08-04

发布日期（UTC）：2025-08-04 · 预发布 · 说明来源：空说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.0-beta.1)

- 发布正文为空，未提供可整理的更新内容。
- 请以原始 Release 页面为准。

### v2.0.0-alpha.2 · 2025-07-24

发布日期（UTC）：2025-07-24 · 预发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.0-alpha.2)

- 文本渲染结果按需缓存。
- 缩放时复用接近尺度的位图缓存，相关策略可配置。

### v2.0.0-alpha.1 · 2025-07-22

发布日期（UTC）：2025-07-22 · 预发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v2.0.0-alpha.1)

- 重写版首次加入多标签页。
- 当时只能使用少量菜单，键盘相关功能失效。
- 旧 JSON/MsgPack 工程不能直接打开，迁移工具被列为后续工作。

## 1.x 正式版本

### v1.8.1 · 2025-06-16

发布日期（UTC）：2025-06-16 · 普通发布 · 说明来源：空说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.8.1)

- 发布正文为空，未提供可整理的更新内容。
- 请以原始 Release 页面为准。

### v1.7.11 · 2025-05-31

发布日期（UTC）：2025-05-31 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.7.11)

- 保存窗口状态，紧密堆积留出间隙。
- 修正 macOS 输入法确认、编辑中复制粘贴和 PNG 下载。prg 导出当时仍在开发。

### v1.7.10 · 2025-05-17

发布日期（UTC）：2025-05-17 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.7.10)

- macOS 将大部分 Ctrl 操作转为 Command，Control 可模拟连线/劈砍。
- 更新插件 API。
- SVG 支持改色及复制，但复制仍有已知问题。

### v1.7.9 · 2025-05-12

发布日期（UTC）：2025-05-12 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.7.9)

- 本地目录可生成嵌套框，增加扩散选择、搜索结果全选和文本边框开关。
- 改善原生标题栏与 macOS 快捷键，尝试修正触摸屏问题。

### v1.7.8 · 2025-05-08

发布日期（UTC）：2025-05-08 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.7.8)

- 设置分组可折叠，增加递归/非递归紧密堆积、手动树布局及生长自动布局开关。
- 涂鸦可点击改色和混色，加入延迟复制逻辑节点。

### v1.7.7 · 2025-05-05

发布日期（UTC）：2025-05-05 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.7.7)

- 设置截图粘贴尺寸上限，连线端点随拖拽轨迹自动选择。
- 修正 AppImage 音效和反转连线变形。

### v1.7.6 · 2025-05-04

发布日期（UTC）：2025-05-04 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.7.6)

- 重整最近文件、搜索与关于面板：支持清空记录、目录批量导入 JSON、搜索高亮和自动焦点。
- 修正更新检查，优化教程布局。

### v1.7.5 · 2025-05-02

发布日期（UTC）：2025-05-02 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.7.5)

- 紧急修正新文件缺备份目录时自动保存崩溃。
- 草稿默认备份到应用缓存中的 drafts-backup。

### v1.7.4 · 2025-04-30

发布日期（UTC）：2025-04-30 · 普通发布 · 说明来源：原文含 AI 自动总结 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.7.4)

- 拇指滚轮可调窗口透明度及笔触粗度。
- 备份可限数量。
- 改善斩断连线的反馈。

### v1.7.3 · 2025-04-28

发布日期（UTC）：2025-04-28 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.7.3)

- 修正键盘树生长间隔不断扩大及新节点未进入所在框。
- 新增粘贴 SVG 代码创建节点。
- 改善周围创建间距、坐标标注和选中颜色。
- macOS 删除默认 Backspace，并修正粘贴后的按键残留。

### v1.7.2 · 2025-04-27

发布日期（UTC）：2025-04-27 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.7.2)

- 最近文件支持字符串筛选及打开所在目录。
- 方向键选择可自定义，新增相机回原点和框缩略标题配置。
- 实验性用鼠标侧键重置视野。

### v1.7.1 · 2025-04-24

发布日期（UTC）：2025-04-24 · 普通发布 · 说明来源：原文含 AI 自动总结 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.7.1)

- 因自动保存/备份与进度风险，Windows CLI 当时暂时停用。
- 树生长时镜头自动跟随，涂鸦更平滑，并消除启动白闪。

### v1.7.0 · 2025-04-23

发布日期（UTC）：2025-04-23 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.7.0)

- 正式加入无向边/多源超边，可编辑文字、调整中心、切换箭头与凸包形态。
- 改善复制、劈砍与涂鸦模式交互，节点输入扩大时外层框同步适配。
- 极小视野减少详情渲染。

### v1.6.4 · 2025-04-22

发布日期（UTC）：2025-04-22 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.6.4)

- 紧急修正输入框焦点调用问题。
- 框内右键连线中创建的质点可正确归入分组。

### v1.6.3 · 2025-04-22

发布日期（UTC）：2025-04-22 · 普通发布 · 说明来源：原文含 AI 自动总结 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.6.3)

- 测试发布无向边/超边，支持文字、中心点、箭头和凸包。
- 任意实体详情首行可作外部路径。
- 加入内容/详情交换和侧滚轮配置，改善相机平滑、颜色持久化及报错复制。

### v1.6.2 · 2025-04-20

发布日期（UTC）：2025-04-20 · 普通发布 · 说明来源：原文含 AI 自动总结 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.6.2)

- 紧急修正教程打开报错与连线遗漏。
- macOS 触摸板缩放可按鼠标位置并设灵敏度。
- 包含账户/API 相关开发记录，但插件与多源无向边仍被标为开发中。

### v1.6.1 · 2025-04-20

发布日期（UTC）：2025-04-20 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.6.1)

- 增加横纵紧密堆积、方向键加选和相机翻页移动。
- 移除 Shift 快速移动避免输入法冲突。
- 改善亮色关闭按钮、连线反向与 CR 曲线删除。脚本系统仍在开发。

### v1.6.0 · 2025-04-15

发布日期（UTC）：2025-04-15 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.6.0)

- 连线支持入口/出口位置控制，文本可统一宽度。
- 改善 macOS Command 键和触摸板。
- 全选统计对象数量，最近文件增加删除与隐私模式。
- 设置页面浮动化，完善拖入追加内容的提示。

### v1.5.2 · 2025-04-11

发布日期（UTC）：2025-04-11 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.5.2)

- 图片可由系统直接打开。
- 增加滚轮/Alt 滚轮配置和拖动刷新。
- 保存同步最近文件，改用对话框重命名。
- 修正涂鸦误拖连线和空内容 PNG 导出，调整导出边距与快捷键分类。

### v1.5.1 · 2025-04-08

发布日期（UTC）：2025-04-08 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.5.1)

- 增加轴向直线涂鸦、Shift 快移及相机手刹/脚刹，完善菜单说明、目录式新建和按住 Z 临时劈砍。
- 修正特效开关、多线撤销和空 Markdown 输入。CR 曲线等仍属于开发内容。

### v1.5.0 · 2025-04-06

发布日期（UTC）：2025-04-06 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.5.0)

- 采用更紧凑的迷你窗口和分类工具栏。
- 涂鸦支持角度旋转，搜索覆盖多类实体详情。
- 节点支持换行策略继承及合并，增加 Linux 定时渲染模式。
- 取消内置 MiSans 字体，构建改用 Turborepo。

### v1.4.41 · 2025-04-02

发布日期（UTC）：2025-04-02 · 普通发布 · 说明来源：原文含 AI 自动总结 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.41)

发布标题：Release v1.4.41

- 涂鸦增加颜色标识与粗度快捷键。
- 新增鼠标位置创建节点、kei 拆分。
- 修正缩放时自环消失。

### v1.4.40 · 2025-04-01

发布日期（UTC）：2025-04-01 · 普通发布 · 说明来源：原文含 AI 自动总结 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.40)

发布标题：Release v1.4.40

- 提供常用面板快捷键和涂鸦调色。
- 粘贴文本可手动调宽，ttt 在自动/手动尺寸策略间切换，仍属实验性。
- 改善最近文件配色。

### v1.4.39 · 2025-03-31

发布日期（UTC）：2025-03-31 · 普通发布 · 说明来源：原文含 AI 自动总结 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.39)

发布标题：Release v1.4.39

- 恢复自由节点生长并新增网状文本导入。
- 修正莫兰迪菜单文字与图片命名，改进打开工程/数据目录及跨文件复制文档。

### v1.4.38 · 2025-03-31

发布日期（UTC）：2025-03-31 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.38)

发布标题：Release v1.4.38

- 工具栏加入涂鸦、选择移动、连线劈砍三种左键模式及快捷切换。
- Shift 支持直线绘制，涂鸦模式禁用双击建节点。

### v1.4.37 · 2025-03-29

发布日期（UTC）：2025-03-29 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.37)

发布标题：Release v1.4.37

- 窗口透明度可快捷调整，记住文本生成缩进设置。
- 优化节点/框编辑输入区，允许区外释放文本选择，改色后保留选中。
- 完善 Markdown 和术语文档。

### v1.4.36 · 2025-03-27

发布日期（UTC）：2025-03-27 · 普通发布 · 说明来源：原文含 AI 自动总结 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.36)

发布标题：Release v1.4.36

- 深度生长默认改用 Tab，改善平板双击及 iPad 网页尺寸调整。
- 修正关闭退出与网页版多余面板显示。

### v1.4.35 · 2025-03-27

发布日期（UTC）：2025-03-27 · 普通发布 · 说明来源：原文含 AI 自动总结 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.35)

发布标题：Release v1.4.35

- 新装默认启用标签放大，换行默认 Shift+Enter，演示模式更名专注模式。
- 修正背景透明度、macOS 窗口按钮并调整图标与角落关闭交互。

### v1.4.34 · 2025-03-26

发布日期（UTC）：2025-03-26 · 普通发布 · 说明来源：原文含 AI 自动总结 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.34)

发布标题：Release v1.4.34

- 逻辑节点增加多分隔符、内容搜索和按 UUID 获取位置。
- 修正 PNG 预览溢出与导出透明设置。

### v1.4.33 · 2025-03-23

发布日期（UTC）：2025-03-23 · 普通发布 · 说明来源：原文含 AI 自动总结 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.33)

发布标题：Release v1.4.33

- 初步加入 PNG 导出和导出缩放，扩展对齐/连线/改色快捷操作及逻辑节点位置控制。
- 修正非文本对象类型、PNG 拼接、主题启动、macOS 滚轮和长路径布局。PNG 当时仍有已知问题。

### v1.4.32 · 2025-03-21

发布日期（UTC）：2025-03-21 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.32)

发布标题：Release v1.4.32

- 扩充任务打勾、主题、专注模式、透明度及坐标整数化的序列快捷键。
- 可用 Alt+右键调笔粗，涂鸦改为圆角接头。
- 恢复向右/下树布局。

### v1.4.31 · 2025-03-19

发布日期（UTC）：2025-03-19 · 普通发布 · 说明来源：原文含 AI 自动总结 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.31)

发布标题：Release v1.4.31

- 新增 UUID、位置和按颜色删除等逻辑操作，图片可批量缩放。
- 极小视野可禁文字渲染。
- 改善 macOS 输入识别、选中边框和涂鸦删除反馈。另一种大标题方案尚未开放。

### v1.4.30 · 2025-03-17

发布日期（UTC）：2025-03-17 · 普通发布 · 说明来源：原文含 AI 自动总结 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.30)

发布标题：Release v1.4.30

- 自动生成更新日志。
- 修正涂鸦重开颜色、节点转框外部连线状态、导出框内连线和图片复制。

### v1.4.29 · 2025-03-16

发布日期（UTC）：2025-03-16 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.29)

发布标题：Release v1.4.29

- 涂鸦粘连移动改为扩散选择。
- 逻辑节点支持鼠标位置、对象存在和日期运算。
- 删除连线可清理孤立质点。
- 修正嵌套复制/SVG 填充及数值设置，移除周围创建自动连线与保存黑闪。

### v1.4.28 · 2025-03-13

发布日期（UTC）：2025-03-13 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.28)

发布标题：Release v1.4.28

- 窗口卷起改为迷你模式。
- 涂鸦可自定/自动填色并减少折点，加入树方向翻转、父色继承、全局替换和实验性网格吸附。
- 生长快捷键可定制，修正选中 SVG 导出漏框内容。

### v1.4.27 · 2025-03-10

发布日期（UTC）：2025-03-10 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.27)

发布标题：Release v1.4.27

- 加入官方音效一键配置。
- macOS 滚轮暂时恢复，但触摸板适配仍未完全解决。

### v1.4.26 · 2025-03-08

发布日期（UTC）：2025-03-08 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.26)

发布标题：Release v1.4.26

- 长框标题可撑宽框体，对齐工具常驻，改善宏观大框选择。
- 修正逻辑数值精度，避免大框之间连线过粗。

### v1.4.25 · 2025-03-05

发布日期（UTC）：2025-03-05 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.25)

发布标题：Release v1.4.25

- 阻止外框跳入内框形成循环，保存不再清历史。
- 加入 iframe 嵌入及 SVG 导出配置，框间连线可调粗。
- 文本拖入改为提示而非建节点。

### v1.4.24 · 2025-03-01

发布日期（UTC）：2025-03-01 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.24)

发布标题：Release v1.4.24

- 加入深度/广度键盘生长。
- 修正搜索无结果时报错及小屏设置栏溢出。

### v1.4.23 · 2025-02-27

发布日期（UTC）：2025-02-27 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.23)

发布标题：Release v1.4.23

- 拦截刷新快捷键防止内容丢失。
- 加入框与文本转换、窗口透明快捷操作。
- 改善跳入布局和移出窗口停止拖动。
- macOS 默认用 Command，并开放复制粘贴绑定。

### v1.4.22 · 2025-02-26

发布日期（UTC）：2025-02-26 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.22)

发布标题：Release v1.4.22

- Ctrl 拖线可移接目标，中键双击按选中内容重置视野。
- 加入树转嵌套框，修正 macOS 框标题编辑并调整色卡形状。

### v1.4.21 · 2025-02-25

发布日期（UTC）：2025-02-25 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.21)

发布标题：Release v1.4.21

- 周围新建保持所在分组，标签可排序并展示节点颜色。
- 调整大标题遮盖和根节点布局，限制逻辑变量名称。

### v1.4.20 · 2025-02-24

发布日期（UTC）：2025-02-24 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.20)

发布标题：Release v1.4.20

- 修正涂鸦保存变短、框复制漏连线及文本编辑漏历史。
- 完善路径/Markdown 链接识别、图片缩放和详情编辑。
- 提高涂鸦显示优先级，弱化拖线特效并突出未保存状态。

### v1.4.19 · 2025-02-23

发布日期（UTC）：2025-02-23 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.19)

发布标题：Release v1.4.19

- 中键双击行为可配置，恢复删除按钮，新增内容复杂度统计。
- 完善鼠标越界后的劈砍、移动及框选结束处理。

### v1.4.18 · 2025-02-22

发布日期（UTC）：2025-02-22 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.18)

发布标题：Release v1.4.18

- 方向键移动时可让镜头跟随，标签面板可快捷收放。
- 改善 URL 显示和触摸板识别。
- 实验性支持手工解包 XMind 导入及树转嵌套框。

### v1.4.17 · 2025-02-20

发布日期（UTC）：2025-02-20 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.17)

发布标题：Release v1.4.17

- 搜索忽略大小写，粘贴/周围创建正确进入分组。
- 非文本实体可键盘移动，补充演示快捷键。
- 修正删除、标题溢出及更新提示，改善主题和按钮音效。

### v1.4.16 · 2025-02-19

发布日期（UTC）：2025-02-19 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.16)

发布标题：Release v1.4.16

- 加入向右树布局及路径节点资源打开。
- 集中修复分组嵌套与跨层移动。
- 改善标签定位、选择、删除、创建惯性及 SVG 图片导出，增加灰蓝绿主题。

### v1.4.15 · 2025-02-17

发布日期（UTC）：2025-02-17 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.15)

发布标题：Release v1.4.15

- 加入矩阵/紧凑排列、创建自动上色和演示模式。
- 视野重置留白可配置，闲置可暂停渲染。
- 说明部分性能优化效果有限。

### v1.4.14 · 2025-02-16

发布日期（UTC）：2025-02-16 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.14)

发布标题：Release v1.4.14

- 详情编辑支持 Esc/Ctrl+Enter 退出和失焦保存，修正切换对象编辑。
- 改善空框漂移、删除粒子数量、指针及切割特效。

### v1.4.13 · 2025-02-14

发布日期（UTC）：2025-02-14 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.13)

发布标题：Release v1.4.13

- 吸附对齐适用于各类实体，增加点击加选/矩形加选/交叉选。
- 色库自动排序、备份集中存放。
- 修正嵌套、失效钉选工程和 SVG 图片遗漏。

### v1.4.12 · 2025-02-13

发布日期（UTC）：2025-02-13 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.12)

发布标题：Release v1.4.12

- 可配置横向滚轮，连线文字支持换行。
- 修正透明度、自动选中及 Android 编译，弱化创建特效。

### v1.4.11 · 2025-02-12

发布日期（UTC）：2025-02-12 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.11)

发布标题：Release v1.4.11

- 传送门加入跨工程预览，支持窗口卷起固定、色库管理和隐私快捷操作。
- 坐标轴可固定边缘。
- 关闭支持放弃保存，移除容易误触的中键吸附移动。

### v1.4.10 · 2025-02-10

发布日期（UTC）：2025-02-10 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.10)

发布标题：Release v1.4.10

- 完善纯键盘选中、Esc 取消、周围创建及复制关系。
- 增加键盘跳跃与传送门节点。
- 滚轮配置扩展，修正自环删除及默认下载弹窗。

### v1.4.9 · 2025-02-08

发布日期（UTC）：2025-02-08 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.9)

发布标题：Release v1.4.9

- 节点文字/单张图片可复制到系统剪贴板。
- 滚轮行为与详情编辑器可定制。
- 改善框选和跳跃反馈。传送门仅有跳转测试，仍在开发。

### v1.4.8 · 2025-02-07

发布日期（UTC）：2025-02-07 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.8)

发布标题：Release v1.4.8

- 工具栏可钉住，标签放大可配置。
- 新装默认隐藏调试信息。
- 修正原生标题栏残余面板并拦截 Ctrl+P 打印。

### v1.4.7 · 2025-02-06

发布日期（UTC）：2025-02-06 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.7)

发布标题：Release v1.4.7

- 所有舞台对象包括连线均可加入标签。
- 标签按位置排序并提供透视/瞭望。
- 缩小时减少文字绘制，调整框标题顺序和关于页外链。

### v1.4.6 · 2025-02-06

发布日期（UTC）：2025-02-06 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.6)

发布标题：Release v1.4.6

- 修正提示遮挡、按钮指针、下拉收放及截图快捷键引起持续移动。
- 增加 Pause 相机刹车。

### v1.4.5 · 2025-02-05

发布日期（UTC）：2025-02-05 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.5)

发布标题：Release v1.4.5

修正框内双击创建的节点脱离分组，补充菜单帮助说明。

### v1.4.4 · 2025-02-05

发布日期（UTC）：2025-02-05 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.4)

发布标题：Release v1.4.4

按框选方向分别采用完全覆盖或相交选择，策略可定制。

### v1.4.3 · 2025-02-05

发布日期（UTC）：2025-02-05 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.3)

发布标题：Release v1.4.3

- 提供新手教程。
- 修正详情编辑失焦，键盘缩放以屏幕中心为基准并可定制。
- 更新过程显示进度。

### v1.4.2 · 2025-02-04

发布日期（UTC）：2025-02-04 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.2)

发布标题：Release v1.4.2

- 编辑进入时是否全选和触发按键可设置。
- 修正编辑及换行快捷键。

### v1.4.1 · 2025-02-03

发布日期（UTC）：2025-02-03 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.1)

发布标题：Release v1.4.1

- 详情宽度可调整。
- 修正工具栏遮挡、删注释后图标残留，颜色收集逻辑跳过空内容。

### v1.4.0 · 2025-02-02

发布日期（UTC）：2025-02-02 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.4.0)

发布标题：Release v1.4.0

连线支持改色，实体详情展示字号和行数上限可设置。

### v1.3.3 · 2025-02-01

发布日期（UTC）：2025-02-01 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.3.3)

发布标题：Release v1.3.3

- 增加文本转框快捷操作。
- 拦截浏览器搜索等默认输入框。
- 修正教程重复、隐藏详情按钮误触与详情编辑期间相机锁定。

### v1.3.2 · 2025-01-31

发布日期（UTC）：2025-01-31 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.3.2)

发布标题：Release v1.3.2

- 加入浅色/马卡龙主题和所见即所得详情编辑。
- AI 改用 DeepSeek，生长绑定可定制。
- 修正文本导出顺序与特效开关，移除卡顿毛玻璃。
- 网页版自动备份关闭。

### v1.3.1 · 2025-01-26

发布日期（UTC）：2025-01-26 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.3.1)

发布标题：Release v1.3.1

- 可配置分组填充颜色。
- 修正嵌套复制、对话框窗口移动及质点曲线消失。
- 空白拖线可自动建节点。

### v1.3.0 · 2025-01-24

发布日期（UTC）：2025-01-24 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.3.0)

发布标题：Release v1.3.0

- 完成手动换行与可定制编辑键。
- 逻辑引擎加入变量、面板和创建节点。
- 中心对齐、特效开关及 Android 加载改善。用框表达循环当时只是后续设想。

### v1.2.9 · 2025-01-22

发布日期（UTC）：2025-01-22 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.2.9)

发布标题：Release v1.2.9

- 逻辑节点加入随机数、统计量及对数/指数/反三角函数。
- SVG 坐标保留一位小数减少体积，改善报错和文档更新说明。

### v1.2.8 · 2025-01-21

发布日期（UTC）：2025-01-21 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.2.8)

发布标题：Release v1.2.8

- 初步支持多行节点及全选。
- 逻辑节点可显示帧率、按颜色收集名称/详情。
- 修正幂运算和 AI 菜单。多行相关导出仍需完善。

### v1.2.7 · 2025-01-19

发布日期（UTC）：2025-01-19 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.2.7)

发布标题：Release v1.2.7

- 逻辑可慢速执行并展示顺序，修正按纵坐标执行和自环文字。
- 详情展示限行，Tab 单次按键生长可调整方向或直接接线。

### v1.2.6 · 2025-01-17

发布日期（UTC）：2025-01-17 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.2.6)

发布标题：Release v1.2.6

- 单次 Tab 生长更平滑，加入批量反向连线、颜色面板及 Alt+F4。
- 修正 SVG 文字色、打开时草稿处理和异或逻辑。
- 官网提供英文及捐赠页。

### v1.2.5 · 2025-01-13

发布日期（UTC）：2025-01-13 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.2.5)

发布标题：Release v1.2.5

修正白色主题下质点及连线的配色细节。

### v1.2.4 · 2025-01-12

发布日期（UTC）：2025-01-12 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.2.4)

发布标题：Release v1.2.4

- 说明仅提示发布构建可能失败、无附件时联系开发者。
- 没有具体功能更新内容。

### v1.2.3 · 2025-01-12

发布日期（UTC）：2025-01-12 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.2.3)

发布标题：Release v1.2.3

加入 CLI 使用模式。

### v1.2.2 · 2025-01-09

发布日期（UTC）：2025-01-09 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.2.2)

发布标题：Release v1.2.2

修正论文白主题编辑文字不可见，以及报错关闭按钮被工具栏挡住。

### v1.2.1 · 2025-01-07

发布日期（UTC）：2025-01-07 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.2.1)

发布标题：Release v1.2.1

- 实验性循环空间、快捷键/碰撞/右键拖动配置和吸附对齐。
- 增加逻辑运算边、颜色管理、宏观框标题、图片拖入/缩放及 Markdown 树导入。
- 允许选中删除连线。

### v1.2.0 · 2025-01-07

发布日期（UTC）：2025-01-07 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.2.0)

发布标题：Release v1.2.0

- 自动构建失败的发布，作者指向 v1.2.1。
- 不作为可用功能版本描述。

### v1.1.0 · 2024-12-26

发布日期（UTC）：2024-12-26 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.1.0)

发布标题：Release v1.1.0

- 增加 Android 自动构建但交互适配未完成。
- AI 更换 Qwen，重设计工具栏。
- 增加命令行打开、自动保存/备份、逻辑计算与相机鼠标中心缩放，质点连线可隐藏箭头。

### v1.0.0 · 2024-11-16

发布日期（UTC）：2024-11-16 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.0.0)

发布标题：Release v1.0.0

- 完成 PyQt 到 Tauri 的重写。
- 作者报告启动与帧率改善。
- 加入启动钉选、路径打开、自动保存开关、透明窗口、拖线旋转子树、嵌套分组和质点。旧碰撞挤压未移植，图片/AI/分组等仍需完善。

## 1.x 预发布版本

### v1.8.0-beta.1 · 2025-06-16

发布日期（UTC）：2025-06-16 · 预发布 · 说明来源：空说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v1.8.0-beta.1)

发布标题：v1.8.0

- 发布正文为空，未提供可整理的更新内容。
- 请以原始 Release 页面为准。

## 早期版本与 PyQt

### v0.5.0 · 2024-11-09

发布日期（UTC）：2024-11-09 · 普通发布 · 说明来源：空说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v0.5.0)

发布标题：Release v0.5.0

- 发布正文为空，未提供可整理的更新内容。
- 请以原始 Release 页面为准。

### v0.4.0 · 2024-10-09

发布日期（UTC）：2024-10-09 · 普通发布 · 说明来源：空说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v0.4.0)

发布标题：Release v0.4.0

- 发布正文为空，未提供可整理的更新内容。
- 请以原始 Release 页面为准。

### v0.3.0 · 2024-10-05

发布日期（UTC）：2024-10-05 · 普通发布 · 说明来源：空说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v0.3.0)

- 发布正文为空，未提供可整理的更新内容。
- 请以原始 Release 页面为准。

### v0.1.0 · 2024-10-03

发布日期（UTC）：2024-10-03 · 普通发布 · 说明来源：空说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v0.1.0)

- 发布正文为空，未提供可整理的更新内容。
- 请以原始 Release 页面为准。

### pyqt-2024-10-3 · 2024-10-03

发布日期（UTC）：2024-10-03 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/pyqt-2024-10-3)

发布标题：最后的PyQt5版本

- 宣布由 PyQt5/Python 转向 Tauri、TypeScript 与 Rust。
- 原文预计体积和性能改善，属于重写计划而非已测得结果。

### v0.0.0 · 2024-08-31

发布日期（UTC）：2024-08-31 · 普通发布 · 说明来源：作者说明 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/v0.0.0)

发布标题：远古版本

- 保留用于体验的早期 Windows 程序，尚无节点旋转。
- 发布者提示应从 README 获取新版本，帮助视频仍沿用旧项目名。

## Nightly

### nightly · 2026-10-03

发布日期（UTC）：2026-10-03 · 滚动预发布 · 说明来源：未列出变更 · [原始 Release](https://github.com/graphif/project-graph/releases/tag/nightly)

- 滚动预发布通道。
- 本次采集时说明未列出变更，不能据此判定与稳定版没有差异。

## 缺失说明与来源索引

### 正文为空的版本

下列版本均已在正文逐版收录，但 GitHub 没有发布文字说明。本文未根据相邻版本猜测更新。

| 版本 | 发布日期（UTC） | 原始页面 |
| --- | --- | --- |
| v3.0.0-alpha.1 | 2026-02-10 | [Release](https://github.com/graphif/project-graph/releases/tag/v3.0.0-alpha.1) |
| v2.9.9 | 2026-01-21 | [Release](https://github.com/graphif/project-graph/releases/tag/v2.9.9) |
| v2.9.4 | 2026-01-07 | [Release](https://github.com/graphif/project-graph/releases/tag/v2.9.4) |
| v2.7.1 | 2025-12-17 | [Release](https://github.com/graphif/project-graph/releases/tag/v2.7.1) |
| v2.0.11 | 2025-09-04 | [Release](https://github.com/graphif/project-graph/releases/tag/v2.0.11) |
| v2.0.7 | 2025-08-30 | [Release](https://github.com/graphif/project-graph/releases/tag/v2.0.7) |
| v2.0.5 | 2025-08-28 | [Release](https://github.com/graphif/project-graph/releases/tag/v2.0.5) |
| v2.0.3 | 2025-08-24 | [Release](https://github.com/graphif/project-graph/releases/tag/v2.0.3) |
| v2.0.2 | 2025-08-23 | [Release](https://github.com/graphif/project-graph/releases/tag/v2.0.2) |
| v2.0.1 | 2025-08-21 | [Release](https://github.com/graphif/project-graph/releases/tag/v2.0.1) |
| v2.0.0-rc.6 | 2025-08-21 | [Release](https://github.com/graphif/project-graph/releases/tag/v2.0.0-rc.6) |
| v2.0.0-rc.2 | 2025-08-12 | [Release](https://github.com/graphif/project-graph/releases/tag/v2.0.0-rc.2) |
| v2.0.0-rc.1 | 2025-08-09 | [Release](https://github.com/graphif/project-graph/releases/tag/v2.0.0-rc.1) |
| v2.0.0-beta.2 | 2025-08-06 | [Release](https://github.com/graphif/project-graph/releases/tag/v2.0.0-beta.2) |
| v2.0.0-beta.1 | 2025-08-04 | [Release](https://github.com/graphif/project-graph/releases/tag/v2.0.0-beta.1) |
| v1.8.1 | 2025-06-16 | [Release](https://github.com/graphif/project-graph/releases/tag/v1.8.1) |
| v1.8.0-beta.1 | 2025-06-16 | [Release](https://github.com/graphif/project-graph/releases/tag/v1.8.0-beta.1) |
| v0.5.0 | 2024-11-09 | [Release](https://github.com/graphif/project-graph/releases/tag/v0.5.0) |
| v0.4.0 | 2024-10-09 | [Release](https://github.com/graphif/project-graph/releases/tag/v0.4.0) |
| v0.3.0 | 2024-10-05 | [Release](https://github.com/graphif/project-graph/releases/tag/v0.3.0) |
| v0.1.0 | 2024-10-03 | [Release](https://github.com/graphif/project-graph/releases/tag/v0.1.0) |

### 数据来源

- [GitHub Releases 总入口](https://github.com/graphif/project-graph/releases)。
- 分页采集 GitHub 官方 REST API，每页 100 条，三页分别返回 100、100、27 条：[第 1 页](https://api.github.com/repos/graphif/project-graph/releases?per_page=100&page=1)、[第 2 页](https://api.github.com/repos/graphif/project-graph/releases?per_page=100&page=2)、[第 3 页](https://api.github.com/repos/graphif/project-graph/releases?per_page=100&page=3)。
- 每个版本均附官方 Release 链接，日期、预发布标记与说明来源取自返回数据；没有引用第三方版本介绍。
- 4.0.0 六张图片与 2.0.0 海报可从对应 Release 页面查看。本文件只保存提炼内容，不将远程图片复制进仓库。
