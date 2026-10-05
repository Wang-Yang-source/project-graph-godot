# 缩放时的小字号字重补偿

日期：2026-10-05。

## 实际改动

按实际屏幕字号调整舞台 Label 与总览标题：18 px 及以上保持原字重，低于 18 px 每 2 px 增加一级同色轮廓透明度。轮廓宽度随源字号调整，上限为 4 个源像素；不修改字体、字形度量、节点尺寸、文档或撤销记录。进入文字编辑时移除显示补偿，退出后恢复。字体完全透明时不会出现轮廓残影。

TextDetail 在字号跨过补偿阈值时更新，重复输出不会触发主题更新。总览标题的两个缓存返回路径也更新补偿。预览纹理里的 Label 按缓存渲染分辨率补偿，缓存版本随此改动更新；已有纹理继续缩小时不会逐帧重新描字，因而不能保证纹理内极小文字持续增强。

master 使用 Canvas2D：字号乘相机缩放，fontWeight 保持节点设置，并以 100 px 参考字形缩放绘制。没有发现根据缩放自动调整字重的逻辑；本次是新增视觉补偿，并非宣称已完全复现 master。

## 复用与工具

复用 Godot Label 的 outline_size/font_outline_color，没有新增依赖或自行绘制字形。未使用 FontVariation 合成加粗，避免已有 MSDF 字腔异常再出现。共享 MSDF 范围为 8，轮廓限制为一半；依据 [Label 文档](https://docs.godotengine.org/en/4.5/classes/class_label.html) 和 [FontVariation 文档](https://docs.godotengine.org/en/4.5/classes/class_fontvariation.html)。

Godot 文件操作仅使用 Godot MCP 脚本读取、修改、创建及编辑器脚本执行工具；普通验证文档通过文本工具处理。未直接读写场景文件，也未通过 computer use 操作编辑器。两个代理分别分析当前文本管线和 master 实现，并审查集成位置；主代理负责修改、测试、合并与安装。

## 已执行验证

用户已授权测试和更新。新增 screen_text_weight_smoke 在 Xvfb OpenGL 与 Vulkan Mobile 的 llvmpipe 渲染下通过：中英文混合文字从 24 px 缩到 8 px 后，透明度覆盖积分约增加 5.8%；正常字号覆盖积分不变，透明字体无残影，同一补偿档位不重复更新主题，Label 尺寸和字体度量保持一致。此数值仅对应测试样本，不代表所有字号与字体。

optical_text_integration_smoke 通过真实 Stage/TextDetail 验证 8/12/24 px 缩放、进入及退出编辑、几何和序列化不变。msdf_glyph_integrity_smoke 通过现有 W 字形检查。以真实文字修改替代空 document_revision 变更的独立预览缓存探针通过：实际编辑重建缓存，另一组缓存继续复用。

现有 canvas_text_detail_smoke 的 6 个可见性断言在本次修改前后均失败；原 independent_preview_cache_smoke 的空变更断言也失败，它要求仅变更 revision 就重建内容相同的纹理，与当前按内容复用的逻辑不同。本次没有修改这些既有可见性/缓存规则。未完成实体 GPU、桌面缩放与用户图的人工视觉验收。

Linux RPM 导出日志无错误，原生发布程序通过 headless 启动检查；导出包内字体/helper 的实际 OpenGL 渲染测试也通过。本机更新至 project-graph-0.1.27-35.local.fc44.x86_64，rpm -V 无差异，启动入口仍指向 /usr/bin/project-graph。安装程序与导出文件 SHA-256 均为 db36d20267703142b41f653f298cb11ffcb112b14901578da2a50dc9cfe29e01。安装包包含当前工作树；原子提交只包含本次改动，预存修改仍留在工作树中。DNF 报告已取消原先待执行的离线系统更新，需要重新安排。

## 手动验证

重启程序，打开截图中的 tutorial-shortcut-keys-3.1.prg，逐步缩小再放大。观察中文小标签、W 和 101：小字号应稍实，放大恢复普通字重；文字位置、换行和框体尺寸应保持稳定。双击文本编辑再退出，应无光标错位或框体跳动。切换深浅主题，并检查分组总览及嵌套预览。

失败时重点检查字腔填死、相邻笔画粘连、缩放阈值闪烁、透明文字残影以及总览标题未随缩放变化；缓存纹理内极小文字仍可能难读，需与实时总览标题区分。
