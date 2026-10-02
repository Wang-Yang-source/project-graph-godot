# macOS 安装包

使用 Godot 4.8.dev6 官方 macOS Release 模板导出 Universal 应用，随后制作
HFS+ / UDZO DMG。Finder 窗口为 720 × 460，包含品牌背景、拖动箭头、
应用图标和 Applications 快捷入口。背景保留可编辑 SVG 和渲染 PNG。

## 复用与依赖

Go 标准库没有 HFS+、UDIF 和 Finder DS_Store 写入功能。采用
[leaanthony/dmg](https://github.com/leaanthony/dmg)，固定提交
`3d3581c3dfa304a59b0a91915229285805b43ff6`，版本和校验值由
`go.mod` / `go.sum` 固定。该库及其 plist 依赖使用 MIT 许可证，
x/sys 使用 BSD-3-Clause；要求 Go 1.24 以上，兼容当前 Linux 的 Go 1.26.8，
不增加应用运行时依赖。复用库提供的文件系统、压缩、图标、Finder 布局及背景
alias 写入，只实现 Project Graph 的布局参数。

候选 create-dmg 和 dmgbuild 依赖 macOS 的 hdiutil，当前 Fedora 主机不能直接
运行；libdmg-hfsplus 需要额外的文件系统工具和 Finder 元数据适配，因此优先
使用可跨平台构建、已包含这些功能的 Go 库。

## 构建

所有 Godot 项目文件、资源、模板及导出操作均通过 Godot MCP。

1. 安装匹配的官方 macOS 模板。官方
   [4.8-dev6 模板包](https://github.com/godotengine/godot-builds/releases/tag/4.8-dev6)
   SHA-256 为
   `b3cff9b3756fbcf2adefb374bdec7f1b7221fd1d17218606ab19be95f0048a06`。
2. 通过 MCP 保存项目配置及导出预设原始内容，临时移除 MCPRuntimeProbe
   自动加载项、清空 editor_plugins，设置 macOS Universal、bundle ID
   `dev.graphif.ProjectGraph`、生产力分类及项目图标，排除开发插件、测试、
   文档和构建产物。导出完成后恢复原始配置。
3. 用匹配编辑器导出 macOS ZIP，解压保留文件权限和符号链接，得到
   `Project Graph.app`。ZIP 导出可在 Linux 执行，原生 DMG 打包交给下面的工具。
4. 在本目录执行 `go mod verify`、`go vet ./...`、`go test ./...`，
   然后 `go build -o /tmp/project-graph-mkdmg .`。
5. 通过 MCP 执行构建器：

   ```sh
   /tmp/project-graph-mkdmg \
     -app "/absolute/path/Project Graph.app" \
     -output "/absolute/path/ProjectGraph-0.1.22-universal.dmg" \
     -background "/absolute/path/packaging/macos/background.png" \
     -icon "/absolute/path/packaging/linux/project-graph.png"
   ```

背景更新后通过 MCP 使用 ImageMagick 将 background.svg 渲染为 background.png，
保持 720 × 460，与 Finder 的图标位置对应。图标中心为 (200, 248) 和
(520, 248)，图标大小为 96。隐藏背景文件和 Finder 元数据由库管理。

未配置 Developer ID 签名或 Apple 公证。macOS 实机安装和 Gatekeeper 行为需在
Mac 上验收；Linux 静态检查不能替代实机运行。

## 本次构建验证

- 官方模板包 SHA-256 与上述固定值一致；Godot macOS Release ZIP 导出退出码 0，
  无导出错误或警告。通过 MCP 恢复项目配置和导出预设。
- DMG 完整性检查通过；应用 Mach-O 包含 x86_64 和 arm64，bundle ID、版本
  0.1.22、生产力分类及品牌图标正确，包含 Godot 的临时签名。
- 从实际 DMG 读取 Applications 链接，目标为 /Applications；读取背景文件，
  与源 PNG 字节一致。使用独立 ds_store 读取器核实窗口、背景 alias、96 像素
  图标和两个图标坐标，背景已目视检查。
- Go 编译、vet、模块校验通过；复用库的 dmg、hfsplus、udif、dsstore 测试通过。
- 产物：dist/ProjectGraph-0.1.22-universal.dmg。SHA-256：
  `6ec9e61482f9ad0e40e7fc0e5074d44f79f66e54002264f4129bbc10ce02a8d1`。

## 手动验收（尚未执行）

1. 在 Mac 双击 DMG。Finder 应显示完整背景，左右分别是 Project Graph 和
   Applications，箭头和安装说明无遮挡。若背景缺失或图标错位，检查 DS_Store、
   背景 alias 和窗口尺寸。
2. 将左侧应用拖至右侧 Applications，再从 Applications 启动。应出现欢迎页，
   能新建、打开和保存 PRG。若启动受阻，检查签名、公证及系统报告的具体原因；
   不应要求用户关闭系统安全功能。
3. 展开包含两个文本方块的分组，从组内空白开始切割其中一个方块，松开后应
   只删除该方块及关联线，分组和另一个方块保留；撤销一次应恢复。失败时检查
   起刀、高亮范围、级联删除和撤销记录。
4. 分别在 Apple Silicon 和 Intel Mac 验证，检查中文、缩放和拖拽。当前默认
   最低版本为 Intel macOS 11、Apple Silicon macOS 13；跨平台运行尚未验证。
