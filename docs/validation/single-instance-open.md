# 外部打开文档复用标签页

实际改动：启动页先检查已有窗口；后续启动通过本机回环连接转交路径并退出，不加载第二个编辑工作区。主窗口串行复用 `tabs.load_files`，重复文件切回原标签页，保留未保存的文档。明确选择“新建窗口”仍可单独启动。初始化期间收到的请求等待首次文档加载完成。

复用评估：使用 Godot 自带 TCPServer、StreamPeerTCP、PacketPeerStream 和 Crypto。TCP 仅绑定 127.0.0.1；用户数据目录与桌面会话决定实例范围，随机令牌验证请求，端点文件权限为 0600。原生协议封包、连接状态、超时及断开处理已足够，不需要另引 IPC 库。[Godot TCPServer 文档](https://docs.godotengine.org/en/latest/classes/class_tcpserver.html)。

工具类别：Godot MCP 脚本读取、创建、修改、编辑器脚本执行；测试、导出和 Godot 文件的 Git 暂存均通过 MCP。普通文件工具用于文档和桌面入口。

已验证：`single_instance_open_smoke.gd` 原实现失败，修复后通过 X11 跨进程测试；覆盖中文空格路径、多文件、重复打开、未保存节点保留、关闭后重新启动、启动页接管。导出 release 二进制及用户级安装版本通过同一测试；`gio launch` 实际桌面入口请求进入原工作区的新标签页。`single_instance_transport_smoke.gd` 无界面通过，覆盖令牌拒绝、断开、未完成请求超时、无响应接收方超时以及端点和连接清理。

本机交付：导出 `dist/project-graph-single-window.x86_64`，用户级安装到 `~/.local/lib/project-graph/project-graph`；用户级 `dev.graphif.ProjectGraph.desktop` 指向该版本，原 `.prg` 默认应用 ID 保持不变；`~/.local/bin/project-graph` 从系统程序改为该版本。系统 RPM 未覆盖，因为 sudo 需要密码。若之后改回系统安装版本，移除用户级 desktop 覆盖并将该符号链接改回 `/usr/bin/project-graph`。

尚未执行的人工检查：关闭旧版本窗口后，从文件管理器双击两个不同的 `.prg`，应只保留一个编辑窗口、出现两个标签页；重复打开同一文件应激活已有标签，原文档未保存的修改应保留。最小化后再打开文件应恢复已有窗口；若仍出现多个工作区，重点检查启动入口是否仍直接调用旧 `/usr/bin/project-graph`、是否选择了“新建窗口”、已有窗口是否无响应。Wayland 前台激活受桌面策略影响；Windows/macOS 桌面文件关联未验证。
