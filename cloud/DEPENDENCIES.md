# 依赖选择与运行约束

本功能优先复用标准库及社区现成实现，没有编写密码哈希、验证码生成、JWT 签名、ZIP 解析器或 SMTP 客户端。

| 职责 | 选用与固定版本 | 理由 / 兼容性 |
| --- | --- | --- |
| HTTP、JSON、ZIP、SHA-256 | Go 标准库，项目最低 Go 1.25 | 原生支持所需功能。应用只实现账号流程限制、PRG 格式检查、配额与版本事务。构建 `CGO_ENABLED=0` Linux amd64 静态二进制，避免服务器 glibc 差异 |
| UUID 生成与检查 | `github.com/google/uuid v1.6.0`，哈希固定于 `go.sum` | 复用成熟实现，避免手写 UUID 格式及解析；BSD-3-Clause，纯 Go，兼容本项目编译器 |
| PostgreSQL 驱动 | `github.com/jackc/pgx/v5 v5.11.0`，所有模块哈希固定于 `go.sum` | 官方维护的 PostgreSQL Go 驱动；要求 Go 1.25；使用 context 取消、连接池上限和真实数据库事务。MIT，传递 Go x/* 包为 BSD 类许可 |
| 账号与邮件验证码 | Supabase Auth `v2.197.0`，独立 HTTP 进程 | 复用密码哈希、验证码用途及有效期、邮件模板、刷新令牌轮换、限流、密码恢复。MIT；发布的 Linux amd64 静态二进制；不把它当成兼容性无保证的 Go 内嵌库 |
| 持久化数据库 | PostgreSQL `17.11` 官方 `17-bookworm` 镜像，固定下述摘要 | PostgreSQL 许可；Linux amd64。数据库与认证分别使用独立数据库/角色。`bytea` 暂用于有限容量测试，正式大文件存储迁移对象存储 |
| 测试邮件接收 | Mailpit `v1.31.4` | MIT；Linux amd64 静态二进制；测试 SMTP 与收件箱复用现成实现；只监听回环地址，不转发真实邮件 |

固定发布文件与 SHA-256：

- `auth-v2.197.0-amd64.tar.xz`：`b5c2991d1df760c9b099c1c2395a94bd1c2f83ed58901934921997179dc9f7ea`
- `mailpit-linux-amd64.tar.gz`：`30942c4605c2ca8b9f759b1bb4e3ab6a12bdfdf66e5c94644ec2c75ac41e88e7`
- PostgreSQL 镜像索引：`sha256:639ab7ceb90e13123085b741fb31ef493fba25463002f6da665352e7b534b652`
- 该镜像的 Linux amd64 配置 ID：`sha256:248efd5e58cd743f2a0e0daec8ea4649e5580145ec2a12e2345bc710d4a77201`。离线部署从固定镜像导出，并按此 ID 以 `--pull=never` 运行。

上游依据：[pgx](https://github.com/jackc/pgx/tree/v5.11.0)、[Supabase Auth 发布](https://github.com/supabase/auth/releases/tag/v2.197.0)、[认证许可证](https://github.com/supabase/auth/blob/v2.197.0/LICENSE)、[Mailpit 发布](https://github.com/axllent/mailpit/releases/tag/v1.31.4)、[Mailpit 许可证](https://github.com/axllent/mailpit/blob/v1.31.4/LICENSE)、[PostgreSQL 许可证](https://www.postgresql.org/about/licence/)。Go 模块许可证和运行时许可证随构建产物放入 `licenses/`，不把发布二进制或凭证提交到仓库。

候选与不采用理由：

- 完整自托管 Supabase：复用程度高，但官方整套最低 4 GiB 内存，测试机器只有约 1.8 GiB，因此只部署 Auth 和 PostgreSQL，不部署 Studio、Realtime、Storage 等。
- PocketBase：部署轻量，但其 OTP 面向现有账号登录，默认密码重置/验证采用链接；本需求是注册与重置验证码且只用密码登录，需要额外流程适配。其未到 1.0 的兼容性约束也会增加后续维护成本。
- 自写账号、JWT、SMTP 或验证码框架：标准库和上述认证服务已经覆盖，无需替代实现。
- Redis：本轮无缓存或任务队列需求；账号限流复用 Auth，文件请求限制并发，配额复用数据库事务。
- MinIO / 对象存储：正式容量阶段有价值，首版加入会增加运维和双写失败路径，因此本次只用数据库事务，明确保留迁移工作。

部署前后需持续跟踪依赖安全发布；固定版本和摘要提供可重现性，不代表无需升级。
