# PRG v4 文件结构

状态：读写实现已完成；存储往返、损坏拒绝、图片块、旧档导入和加载事务回归已通过。尚未执行发布构建或跨平台验证。v4 是新的文档存储结构，完整数据模型驱动的历史、按需节点和局部物理仍是后续工作。

## 定义与目标

扩展名仍为 `.prg`，新写入版本为 `4.0.0`。v4 不再是 ZIP 文件；核心数据不压缩、不经 JSON 文本解析。它是带目录的原生二进制文档，图片、几何缓存、预览和旧档内容各自独立定位。

复用 Godot 原生 Variant 编解码、FileAccess、HashingContext、Crypto 和 DirAccess。Python 预览工具复用标准库 struct/json/hashlib，以及已有 Cairo/Pango 图片与文字支持。不引入或自行实现通用序列化器、压缩库、数据库、B-tree 或 WAL。候选和不采用理由见 [架构方案](../design/fast-document-architecture.md)。

## 32 字节文件头

全部整数为小端，偏移和长度均按字节计。

| 偏移 | 长度 | 字段 |
| --- | --- | --- |
| 0 | 8 | 固定签名 `PGDOC4\r\n` |
| 8 | 4 | 容器主版本，uint32，当前 4 |
| 12 | 4 | 目录 JSON 长度，uint32 |
| 16 | 8 | 目录开始偏移，uint64 |
| 24 | 8 | 保留字段，uint64，当前必须为 0 |

数据块从偏移 32 开始连续写入。目录位于文件末尾，`目录偏移 + 目录长度 == 文件长度`。目录中各块不得越界或互相重叠；偏移运算使用 64 位整数。

## 小型通用目录

目录为 UTF-8 JSON，最多 4 MiB。JSON 仅用于目录与离线预览，不是正文格式。

```json
{
  "version": 4,
  "codec": "godot-variant-4",
  "real_bits": 32,
  "metadata": {
    "version": "4.0.0",
    "created_at": "...",
    "modified_at": "...",
    "object_count": 975
  },
  "blocks": {
    "records": {"offset": 32, "length": 12345, "kind": "variant", "sha256": "..."},
    "geometry": {"offset": 12377, "length": 456, "kind": "variant", "sha256": "..."},
    "preview": {"offset": 12833, "length": 789, "kind": "json", "sha256": "..."},
    "asset/<content-sha256>": {"offset": 13622, "length": 2048, "kind": "raw", "sha256": "..."},
    "legacy/<original-entry>": {"offset": 15670, "length": 1024, "kind": "raw", "sha256": "..."}
  }
}
```

示例偏移与长度仅示意，不是可用文件。每块记录编码类型、范围和 SHA-256。`real_bits` 区分 Godot 原生向量等类型的单/双精度构建；不匹配时拒绝解码，不能假设未来所有引擎版本无条件兼容。

## 权威 records 块

用 Godot `var_to_bytes` 编码纯数据，`bytes_to_var` 解码；禁止可执行 Object 解码。不能序列化运行时 Object、RID、Callable、Signal 或实例 ID。块内 schema 当前为 1。

```text
document
  schema: 1
  camera: {position, zoom}
  objects: Array，数组顺序就是文档顺序
    id: String，唯一且非空
    type: String，稳定类型名
    transform: {position: Vector2, rotation: float, scale: Vector2}
    properties: Dictionary，原生字符串、数值、颜色、数组等值
    references: Dictionary，属性名 → 稳定对象 ID
    assets: Dictionary，资产属性名 → 内容 SHA-256
```

ID 不重复放在 properties 中。`container`、`topic_parent`、`source`、`target` 等引用与普通属性分开；图片引用与正文分开。读取检查重复 ID、支持的类型、变换数值、引用目标、连线端点、集合成员和分组循环。未知记录结构/schema 不静默降级。

当前支持 text_node、line_edge、legacy_asset、pen_stroke、venn_region。当前舞台/历史仍使用旧快照接口，存储模块在接口处转换；文件内部保存原生值。完整 GraphDocument 与节点生命周期分离尚未实施，不能把该适配层称为已完成整个架构迁移。

## 图片与旧档数据

图片以原始 PNG/JPEG/WebP/SVG 字节存放在 `asset/<SHA-256>` 块。相同字节复用同一块。正文不保存 Base64；从旧档导入的 Base64 在迁移时转为原始字节。

直接调用 ProjectFile.load(v4) 时，图片与 legacy 块返回运行时只读句柄，尚未读取其内容。路径和偏移仅由已校验文件目录构造，不进入持久记录。需要内容时读取并校验对应块。

当前加载器仍创建全图节点，所以它在后台准备阶段读取本图全部需要的图片字节，在替换舞台前发现截断或校验错误；图片解码及纹理创建仍沿用当前节点生命周期。没有声称已实现离屏图片/节点完全不创建。legacy 保留块在打开时不读取，保存时才复制。

保存同一路径时先读入需要复制的旧块，再替换原文件，并将保留内容句柄重新绑定到新目录偏移，避免后续保存引用失效位置。

## 可丢弃 geometry 与 preview

geometry 保存对象/分组世界矩形、布局版本、字体 fingerprint，并绑定 records 块 SHA-256。字体/版本/记录摘要不匹配、缓存损坏、矩形缺失或数值无效时放弃缓存，回到现有计算路径。有效缓存用于加载计划，跳过初开全图文字尺寸和分组边界的重复准备；实际节点的初始化仍存在。

preview 是派生的 JSON 显示投影，供现有离线缩略图工具读取。它不参与正文恢复，不能被编辑后反写成文档。图片投影只含资产 ID 和尺寸，没有 Base64；预览器按需读标准图片块，不实现 Godot Variant 解码器，也不启动 Godot。

预览投影最多包含前 5000 个对象、每段文字前 512 字符、画笔前 2000 个点；完整正文不截断。预览器限制单个读取块 16 MiB、图片累计 64 MiB，超限图片用占位表示；投影自身超限时可能没有离线预览。这些限制不影响正文打开。多层级位图概览属于后续显示架构工作。

## 保存与兼容

新保存默认写 v4。读取时用签名识别 v4；旧 ZIP v3 JSON 和 v2 MessagePack 导入继续保留。打开旧文件不重写它；用户明确保存到原路径会迁移该路径，另存为则保留源文档。旧应用不能读取 v4。

写入同目录随机临时文件，检查每次写入结果，完成正文/资产/目录与文件头，flush 并处理写入错误后关闭，再读回目录和正文块摘要，避免未报告的缓冲写入失败直接替换原文件。替换之前将当前文件移动为 `<path>.previous`，新文件替换失败时尝试恢复。失败信息包含无法恢复时的文件位置。`.previous` 保留最后一份恢复副本，后续成功保存会轮换。

该协议尚未经过目标平台和故障注入验证，不承诺跨平台掉电安全。导出/安装的旧版本应用与缩略图工具不会因为源码修改而自动更新。

当前格式资源上限：文件 4 GiB、目录 4 MiB、记录/几何/预览块各 128 MiB、单个原始块 256 MiB、对象 100000。它们是解码与资源保护限额，不是追求小体积；需要更大文档时应升级分块策略，而非绕过限额。

## 实现文件

- `src/project_file.gd`：格式入口、旧 ZIP 导入、后台资产准备。
- `src/storage/project_document.gd`：纯数据 schema、校验、快照与预览适配。
- `src/storage/project_binary_store.gd`：头部、目录、块读写及恢复替换。
- `src/storage/project_blob.gd`：延迟原始块读取与校验。
- Stage、ProjectLoadPlan、StageObjectRegistry、LegacyAsset：几何缓存、保留块重绑定、原始图片恢复与历史适配。
- `packaging/linux/project-graph-thumbnailer.py`：v4 预览投影读取。

所有 Godot 文件通过 Godot MCP 脚本读取/创建/修改类别处理；新目录通过 MCP 编辑器脚本的 DirAccess 文件操作创建。未读取或修改场景文本，未修改第三方目录；经用户授权，通过 MCP 启动 headless 本地测试。

## 验证状态

已编写 `tests/project_v4_storage_smoke.gd`，覆盖原生值与变换、稳定引用、图片去重/原始字节、保留内容延迟读取、同路径重存、恢复副本、旧 v3 只读导入、重复 ID/悬空引用/容器循环、截断目录与正文校验。旧 master 导入测试已改为按需读取保留块后逐字节比较。

Python 回归新增 v4 预览无需正文解码、输出尺寸、损坏校验与目录截断用例。上述用例、625 对象旧档导入/编辑撤销/保存重开、加载事务及 Python Ruff 检查已通过。加载响应测试的相机中心断言在改动前基线也失败，属于现有居中规则与测试不一致；尚未完成实际性能对比和发布构建验证。

用户手动验证：打开旧教程，另存为一个新 `.prg`，关闭再打开；文字、位置、连线、分组和图片应保留，刚打开不应标为未保存；编辑并撤销，再保存并重开，结果应一致；第二次保存后同目录应有 `.previous`，原旧教程应未改写。更新后的文件管理器缩略图工具应能显示新文档。失败时重点检查不能打开、缺图/断线、几何错位、撤销丢失或同路径第二次保存失败。加载快慢应比较同一文件内容的 v3/v4，并区分首次导入与再次打开。
