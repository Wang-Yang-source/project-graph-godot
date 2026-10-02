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

可选品牌资源：`packaging/windows/assets/preview.png` 会复制到应用 assets 目录；准备 `project-graph.ico` 后可启用安装器中的 `SetupIconFile`。

本次构建：Godot Release 导出退出码 0，导出日志无错误或警告；Inno Setup 6.7.3 编译成功，配置变更通过空白格式检查。使用 Godot MCP 的项目信息、设置查询和编辑器脚本类别完成模板安装、导出配置、进程启动与原始配置恢复；安装器由 Wine 执行官方编译器。未执行自动测试、安装器运行、Windows 实机启动或性能测试。
