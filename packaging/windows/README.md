# Windows 安装包

当前发布版本为 0.1.21，目标为 Windows x64。复用 Godot 官方 Windows Desktop Release 模板和已有 Inno Setup 安装器，不引入新的运行时库。Release 模板关闭调试开销；保留项目现有 Compatibility 渲染器，未做未经测量的渲染器切换。脚本使用现有二进制导出模式，PCK 嵌入 EXE，并排除测试、开发插件、文档和构建目录。安装器压缩只影响安装过程，不对安装后的程序施加运行时压缩。

## 构建

所有 Godot 文件操作和导出进程必须通过 Godot MCP 执行，不直接编辑项目配置或场景。

1. 安装匹配的 Godot 4.8.dev6 Windows Desktop 模板，不能复用 4.7.2 模板。
2. 通过 MCP 备份 `project.godot` 原始内容；仅在磁盘上的导出配置中临时移除 `autoload/MCPRuntimeProbe`，清空 `editor_plugins/enabled`。导出后无论成功或失败都恢复原始内容，避免发布包引用已排除的 addons。
3. 通过 MCP 启动 Godot `--headless --path <项目路径> --export-release "Windows Desktop" "<项目路径>/builds/windows/Project Graph.exe"`，保存输出和退出码。不要运行导出程序或测试，除非用户另行授权。
4. 使用 Inno Setup 6.7.3 编译 `ProjectGraph.iss`：`ISCC.exe /DAppVersion=0.1.21 packaging/windows/ProjectGraph.iss`。Linux 构建机可用 Wine 执行编译器。
5. 产物为 `builds/installer/ProjectGraph-Setup-0.1.21.exe`。版本更新时同步 Godot 项目版本、EXE 元数据和安装器参数。不要对嵌入 PCK 的 EXE 使用 strip 或 UPX。

工具固定来源及 SHA-256：

- [Godot 4.8-dev6 官方模板](https://github.com/godotengine/godot-builds/releases/tag/4.8-dev6)，`Godot_v4.8-dev6_export_templates.tpz`：`b3cff9b3756fbcf2adefb374bdec7f1b7221fd1d17218606ab19be95f0048a06`。Godot 使用 MIT 许可证，模板必须与编辑器版本匹配。
- [Inno Setup 6.7.3](https://github.com/jrsoftware/issrc/releases/tag/is-6_7_3)，`innosetup-6.7.3.exe`：`9c73c3bae7ed48d44112a0f48e66742c00090bdb5bef71d9d3c056c66e97b732`。随包许可证允许商业使用和分发；编译器仅用于打包，不增加应用运行时依赖。

安装器创建开始菜单快捷方式，可选桌面快捷方式，并注册当前用户的 `.prg` 文件关联。限定 x64 兼容系统，普通用户即可安装。未配置代码签名。

## 手动验收（尚未执行）

1. 在 Windows x64 上双击安装包，按向导安装并选择桌面快捷方式。应完成安装，开始菜单和桌面入口均可启动程序；失败时检查安装路径、权限和 EXE 是否完整。
2. 打开包含大量节点和嵌套容器的文档，连续拖拽、缩放和编辑文本。应保持响应、正常显示字体与图标；失败时关注首次启动日志、资源缺失、显卡驱动以及卡顿发生的具体操作。本次未测量 Windows 性能。
3. 双击路径含中文和空格的 `.prg` 文件，应直接打开对应文档。失败时检查当前用户文件关联及带引号的启动参数。
4. 保存后关闭、重新打开文档，内容应保留。卸载后快捷方式应移除，用户文档应保留；失败时检查卸载清理范围。

品牌资源位于 `packaging/windows/assets`：`wizard-light.svg` 和 `wizard-dark.svg`
是可编辑源稿，通过 MCP 使用 ImageMagick 生成同名 PNG；`brand-mark.png` 和
`project-graph.ico` 从项目现有图标生成。欢迎页和完成页使用高分辨率的紫色节点
插画，其他页面显示品牌图标。`preview.png` 仍为可选应用资源。

本次构建：Godot Release 导出退出码 0，导出日志无错误或警告；Inno Setup 6.7.3 编译成功，配置变更通过空白格式检查。使用 Godot MCP 的项目信息、设置查询和编辑器脚本类别完成模板安装、导出配置、进程启动与原始配置恢复；安装器由 Wine 执行官方编译器。未执行自动测试、安装器运行、Windows 实机启动或性能测试。

## 2026-10-03 圆角安装器交付

复用 [Inno Setup 内置 Windows 11 风格和动态明暗模式](https://jrsoftware.org/ishelp/topic_setup_wizardstyle.htm)，
不引入皮肤 DLL 或额外运行时。Pascal 标准语言没有窗口圆角功能；使用
[Windows DWM 圆角 API](https://learn.microsoft.com/en-us/windows/win32/api/dwmapi/ne-dwmapi-dwm_window_corner_preference)
设置 Windows 11 原生圆角，旧系统使用 GDI 圆角区域回退。安装与卸载窗口都应用
该设置。GDI 区域成功设置后归 Windows 管理，失败时释放。系统在最大化、远程
桌面等情况下是否呈现 DWM 圆角，以实机表现为准。

从当前工作区重新导出 0.1.21，不包含未保存的编辑器内容。保持版本不变，增加
日期后缀区分旧产物：

```sh
ISCC.exe /DAppVersion=0.1.21 /DBuildSuffix=-20261003 packaging/windows/ProjectGraph.iss
```

产物：`builds/installer/ProjectGraph-Setup-0.1.21-20261003.exe`，51,903,273 字节。
SHA-256：`9e7686453c9a6c90fe778247267b995a75e3a81962ec3b5bd713ceeacc6ec11b`。
Godot Release 导出及 Inno 编译退出码均为 0。导出期间临时禁用 shader baker、
开发插件及 MCP 自动加载，设置应用品牌图标；随后恢复原有项目配置与预设。
Godot 文件及品牌资源由 MCP 的项目查询和编辑器脚本类别处理。

未运行自动测试、安装器或 Windows 应用。除上面的安装、文件关联与卸载验收外，
请在 Windows 10/11 分别双击安装包，检查欢迎页插画、四角、标题栏关闭按钮，
切换页面并完成安装；再运行卸载程序检查圆角及按钮。分别切换系统明暗主题后
重新打开安装包，检查文字可读性；在 100% 和 200% 缩放下检查插画清晰度、
按钮和页面是否被裁切。失败时优先记录系统版本、DPI、主题、出错页面，检查
窗口区域与 DWM 回退行为。未配置代码签名。
