# 安装版菜单图标与 PRG 文件缩略图

2026-10-05。用户反馈安装版左上角 Dock 没有图标，文件管理器无法生成 PRG 缩略图。

## 静态排查与实际改动

菜单通过 main.gd 的 FileAccess 读取 lucide SVG 源码，再以 DPITexture.create_from_string 按主题着色。81 个源文件此前采用 texture 导入，导出时只有导入纹理和 .import 映射，不能供 FileAccess 读取源码。已将该目录 SVG 改为 Godot 原生 Keep File 导入，并在四个平台导出预设加入 src/main/icons/lucide/*.svg。编辑器资源依赖索引未发现其他资源直接引用这些 SVG；其他 lucide_light、lucide_mocha 和 sf 目录未修改。复用 Godot ConfigFile、Keep File、FileAccess 和 DPITexture，不增加依赖或图像处理实现。

参考：[Godot FileAccess 文档](https://docs.godotengine.org/en/4.6/classes/class_fileaccess.html)；[实际 dev6 导出源码](https://github.com/godotengine/godot/blob/8898c2b3d/editor/export/editor_export_platform.cpp) 中 importer_type == "keep" 分支直接保存原文件，普通纹理分支保存导入文件。仅增加 include_filter 不能改变纹理导入分支。

系统已安装 project-graph-0.1.25-35.local.fc44.x86_64，但用户级桌面入口覆盖系统入口，实际指向 ~/.local/lib/project-graph/project-graph。该二进制更新时间为 10 月 5 日；系统 /usr/bin/project-graph 与 /usr/libexec/project-graph-thumbnailer 为 10 月 4 日。系统缩略图程序 render() 直接打开 ZIP，没有 PGDOC4 检测与解析，不能处理新保存的 v4 文档。仓库已有 native_preview() 和格式分流实现，应重新打包安装已有预览器；本轮未重复实现解析器，也未修改预览器代码。

## 工具与未执行步骤

使用 Godot MCP 项目信息、脚本读取和修改、日志读取、编辑器脚本进行配置读取和写入、资源依赖读取、Godot 测试和导出；普通终端处理安装配置、Python 检查、RPM 打包安装、GNOME 缩略图验证与文档。未直接读取或写入 .tscn，未使用 computer use。

用户随后明确授权测试和更新。已执行预览器 unittest 15 项、Python 语法检查、Ruff 检查和格式检查；存储回归通过，旧保存实现可复现残留，修复后成功清理并在替换失败时回滚。相关 Godot 文件 git diff --check 通过；未安装 gdformat，未执行其格式检查。Godot 4.8.dev6 release 导出与独立 headless 启动通过。旧用户二进制 PCK 的图标探针失败，新导出及系统安装 PCK 的同一探针通过。

已构建并通过 pkexec/DNF 安装 dist/project-graph-0.1.26-35.local.fc44.x86_64.rpm，只启用本地包，未下载依赖。rpm -V 无差异。安装二进制与构建二进制 SHA-256 均为 3074d9e46866b77945f4916b9b0902b64c36865b412309f96af75cfc59132daa。用户级 .desktop 改为 /usr/bin/project-graph；原 ~/.local/lib/project-graph/project-graph 改为指向系统二进制的符号链接，原入口与二进制备份在 ~/.cache/project-graph/install-backups，后续系统更新不会再被另一份用户二进制覆盖。

GNOME DesktopThumbnailFactory 实际沙箱生成 v4 测试文档的 256×256 预览并写入正常缩略图缓存，MIME 为 application/x-project-graph。离线生成图像已目视检查，中文内容与节点轮廓正常。旧 ZIP 格式由 unittest 覆盖。依据失败缓存 PNG 的 Thumb::URI，仅将 44 个 .prg 的失败标记移到 install-backups/failed-prg-thumbnails，让文件管理器可以重新尝试；未删除其他文件类型缓存或用户文档。系统更新 DNF 输出提示原先安排的离线更新事务失效，需要用户在系统更新界面重新安排。

图标和保存清理分别作独立提交，未混入原有工作区修改。缩略图支持代码本已存在，部署使用当前预览器，没有新增解析器代码。尚未执行用户实际界面操作、其他平台构建及真实清理权限不足故障检查。当前打开的旧进程不会被强制终止，用户须保存并重新打开应用。

## 用户手动验证（尚未执行）

1. 更新安装后，保存并退出已有实例，从当前桌面入口重新打开应用。左上角菜单应显示图标；切换深浅主题和 100%/200% 缩放，图标应完整、颜色适配。失败时检查入口是否仍运行旧二进制，以及安装包是否包含可读取的 SVG 原文件。
2. 保存一个 .prg 文档，复制到新文件名，在文件管理器开启本地缩略图并查看目录。应显示图内容；复制使用新缓存键，避免旧失败缓存干扰。失败时检查 /usr/libexec/project-graph-thumbnailer 是否已包含 PGDOC4 分流、文件 MIME 类型是否正确以及缩略图是否启用。
3. 旧 ZIP 文档仍应生成缩略图；修改 v4 文档再保存应更新内容。损坏文件应回退图标，预览器不能启动编辑器或阻塞文件管理器。
