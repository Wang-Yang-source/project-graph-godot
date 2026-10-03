# Windows 安装包（NSIS）

Project Graph 0.1.21 / Windows x64。Linux 使用 **NSIS 3.11 + Modern UI 2**
直接生成 Windows 安装 EXE，不需要 Wine 或 Inno Setup。复用 NSIS 自带向导、
文件压缩、快捷方式、注册表和卸载功能，不引入皮肤 DLL 或应用运行时依赖。

## 构建

Godot 项目、资源操作和导出必须通过 Godot MCP 执行。现有 Windows Release
导出为 `builds/windows/Project Graph.exe`，PCK 嵌入 EXE；也兼容独立同名 PCK。
安装器默认版本必须与应用版本一致，更新版本时显式传入 `--version`。

```sh
python3 packaging/windows/build_installer.py --version 0.1.21
```

该命令在 Linux x86_64 上下载固定的 Fedora NSIS RPM，验证 SHA-256 后解包至
用户缓存，无需 sudo；需要 Python 3.11+、`rpm2cpio` 和 `cpio`。编译器依赖
glibc、libstdc++、zlib 和 libgcc，当前 Fedora 44 可用；旧发行版可能需要自行提供
兼容的 NSIS 3.11，并使用 `--makensis /path/to/makensis --nsis-dir /path/to/share/nsis`。
工具链固定在 `nsis-toolchain.lock.json`，来源为 Fedora 官方 Koji。
Python 构建脚本仅使用标准库；版本和哈希均已固定，不安装 Python 依赖。

输出：`builds/installer/ProjectGraph-Setup-0.1.21-nsis.exe` 、`.exe.sha256` 和 `.exe.licenses.txt`。
可用 `--export-dir` 指定导出目录、`--output` 指定安装包路径。编译既有导出不会
重新导出 Godot，不代表安装包包含编辑器尚未保存或尚未导出的改动。
不要对嵌入 PCK 的 EXE 使用 strip 或 UPX。尚未配置代码签名。

### Godot 导出

1. 安装匹配的 Godot 4.8.dev6 Windows Desktop 模板，不能复用 4.7.2 模板。
2. 通过 MCP 备份 `project.godot`，导出时临时移除 `autoload/MCPRuntimeProbe`，
   清空开发插件；成功或失败都恢复原始配置，避免发布包引用排除的 addons。
3. 通过 MCP 启动 Godot `--headless --path <项目路径> --export-release
   "Windows Desktop" "<项目路径>/builds/windows/Project Graph.exe"`，保留退出码
   和日志。保持现有 Compatibility 渲染器及 Release 导出配置。
4. 通过 MCP 执行上述 Python 打包命令，供编译器读取导出和品牌图标。

[Godot 官方 4.8-dev6 模板](https://github.com/godotengine/godot-builds/releases/tag/4.8-dev6)
`Godot_v4.8-dev6_export_templates.tpz` SHA-256：
`b3cff9b3756fbcf2adefb374bdec7f1b7221fd1d17218606ab19be95f0048a06`。
Godot 使用 MIT 许可证，模板版本必须与编辑器匹配。

## 安装与迁移

- 当前用户安装至 `%LOCALAPPDATA%\Programs\Project Graph`，无需管理员权限。
- 创建开始菜单入口；桌面快捷方式可选；`.prg` 关联可选且默认启用。
- 注册 Windows“已安装的应用”卸载入口，升级使用已有安装路径。
- 卸载只删除已知程序文件，不递归删除安装目录、用户文档或配置。
  当前用户之前的 `.prg` 默认关联在卸载时恢复；其他程序接管关联后不覆盖。
  Windows 用户选择的默认应用可能仍需在系统设置中确认。
- 检测到旧 Inno 版本时中止并提示先在 Windows 设置中卸载。旧版卸载器可能
  清理安装目录的 assets 子目录，迁移前应将用户文档保存在安装目录之外。
- 使用项目已有品牌 ICO 和标准 MUI2 界面，启用 DPI aware。旧 Inno 的动态明暗
  插画和自定义圆角代码不迁入；现有品牌源稿保留供后续设计使用。

[NSIS 文档](https://nsis.sourceforge.io/Docs/Chapter2.html)支持 Linux 编译 Windows
安装器；[Modern UI 2](https://nsis.sourceforge.io/Docs/Modern%20UI%202/Readme.html)
为官方随附界面。NSIS 核心、标准插件和 MUI2 使用 Zlib 许可证，LZMA 压缩模块
使用 CPL-1.0，详见[官方许可证](https://nsis.sourceforge.io/License)及工具链
`root/usr/share/licenses/mingw-nsis-base/COPYING`。安装器是 Unicode x86 引导程序，
可在 Windows x64 运行；应用仍为 x64，安装时拒绝 x86 系统。

## 手动验收（未执行）

1. 在 WinBoat Windows 中双击 `-nsis.exe`，按向导安装。应无需提权，开始菜单
   能启动程序；选择桌面组件后桌面出现快捷方式。失败检查目录权限、文件被占用
   和安装日志。升级时应沿用原安装目录；要改目录需先卸载。
2. 分别用 100% 和 200% 缩放打开安装器，确认标题、文字、按钮均可读且无裁切。
   失败记录 Windows 版本、DPI 和出错页面。
3. 安装后双击路径含中文和空格的 `.prg` 文档，应打开对应文档；失败检查
   Windows 默认应用选择及 HKCU 文件关联中的带引号命令。
4. 先给 `.prg` 设置其他程序关联，再安装并卸载，应恢复之前的关联；安装后
   另一个程序接管关联，再卸载 Project Graph，应保留新关联。
5. 保存一份文档，退出应用并卸载。程序与快捷方式应移除，文档和用户配置应
   保留；安装目录中自放的文件也应保留。失败检查卸载范围及文件占用。
6. 已装旧 Inno 版本时运行新安装器，应提示先卸载且不修改旧安装。按提示卸载后
   重试应成功，Windows 设置中应仅有一个 Project Graph 卸载入口。

本次通过 Godot MCP 的项目查询与编辑器脚本类别读取项目版本并编译既有导出；
未重新导出 Godot，未运行 Windows 安装器、卸载器、应用或性能测试。

最终 NSIS 编译退出码 0，无警告；7-Zip 归档完整性检查通过。产物
49,960,483 字节，SHA-256：
`8d75d5ccb0c934ec581e90412737897f9cbb3168f2b14d42512aa10d1a52f28c`。
Python 语法、工具链清单、无效版本输入拒绝及 Git 空白检查通过。
工具许可证保留原文于 `NSIS-3.11-COPYING.txt` 并随构建产物输出；NSIS 3.11
未修改源码可从[官方发布页](https://sourceforge.net/projects/nsis/files/NSIS%203/3.11/)取得。
