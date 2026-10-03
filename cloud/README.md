# PRG 云文件测试后端

首版实现邮箱密码账号和私有云文件，尚未接入 Godot 客户端。提供独立网页用于手动验证。所有服务只监听服务器回环地址，通过 SSH 隧道访问；没有修改服务器原有 Caddy 站点。

## 实际能力

- 邮箱与密码注册，注册邮件发送六位验证码，验证后才能用密码登录。
- 验证码只用于注册和重置，不提供验证码登录或 magic-link 入口。
- 重置邮件验证码验证后设置新密码，撤销旧刷新令牌；注册确认和重置都不向客户端返回登录会话。
- 已登录用户上传、列出、下载自己的完整 PRG，包括包内旧版附件；保存历史版本。
- 更新和删除需要 `If-Match: "版本号"`，旧版本提交返回 HTTP 409，不覆盖云端新版本。
- 单文件 20 MiB、每用户 100 MiB（含历史版本）、全测试实例 500 MiB。删除项目会删除全部版本。
- 目前仅接收有 `metadata.json` 和 `stage.json` 的主版本 3 PRG。旧 MessagePack 格式须先在编辑器中另存。
- 测试邮件由 Mailpit 捕获，**不会送到真实邮箱**。验证码有效期 5 分钟，重新发送间隔至少 60 秒。

初始架构为 Go HTTP 接口 + 独立 Supabase Auth + PostgreSQL + Mailpit。为了简单、可回滚且避免文件/数据库双写，测试版将完整 PRG 暂存 PostgreSQL `bytea`，元信息与版本内容在一个事务中提交。这是有限容量的测试实现；正式大容量部署应改为对象存储、不可变版本对象和数据库发布指针，并实现失败上传清理、异机备份与恢复验证。

认证使用 Supabase Auth 接口，不修改它管理的数据结构。密码、验证码、刷新令牌管理均复用认证服务。恢复会话由后端使用后立即清理，用户必须重新用密码登录。已有访问令牌最长有效 15 分钟；不能把刷新令牌撤销等同于所有访问令牌立即失效。网页令牌仅放在内存，刷新网页须重新登录。

## 手动验证（已部署测试实例）

在本机终端保持以下命令运行：

```sh
ssh -N -o ExitOnForwardFailure=yes -L 18080:127.0.0.1:18080 -L 18025:127.0.0.1:18025 ylris
```

打开云文件网页 `http://127.0.0.1:18080` 和测试收件箱 `http://127.0.0.1:18025`。

1. 点击“注册”，填写测试邮箱和至少 10 个字符的密码，点击“发送验证码”。收件箱应出现验证码邮件；填写错误验证码应失败，正确验证码应完成注册。未验证邮箱应不能用密码登录。
2. 用邮箱和密码登录，选择当前编辑器保存的 `.prg` 并填写项目名上传。列表应出现版本 1；下载后在编辑器中自行打开，应保留画布和附件。失败时重点检查文件是否为 JSON 格式主版本 3、是否超过容量上限。
3. 点击“上传新版本”选择修改后的 PRG。应出现版本 2，历史版本仍可下载。两个网页登录同一账号并保持旧列表：一个网页更新后，另一个网页提交旧版本应提示冲突；原有云文件不应被覆盖。
4. 用另一个邮箱注册登录，列表应不包含前一个账号的项目。接口访问他人项目 ID 应返回 404，包括历史版本、更新和删除。
5. 点击“忘记密码”，发送验证码，在收件箱取码并设置新密码。应只提示成功，不自动进入云文件列表；旧密码不能登录，新密码可以登录且原文件仍在。重复使用、过期或注册用途的验证码不应通过重置。
6. 上传过程中断开连接，然后重新登录刷新列表。旧文件应仍可下载，未完成的新项目不应出现。请求超时后先刷新列表确认结果，再决定是否重试；整文件新建尚未实现幂等重试。

若网页打不开，检查 SSH 隧道的端口是否被占用，以及服务器 `systemctl status pg-cloud-api pg-cloud-auth pg-cloud-postgres pg-cloud-mailpit`。邮件没出现时检查 Mailpit 和认证服务状态。尚未执行真实 SMTP 投递、Godot 客户端交互、外部 HTTPS 域名和异机备份恢复验证。

## 本地检查与重现部署

需要 Linux x86_64、Go 1.25+、Python 3 和 Podman。版本、哈希、许可证与候选评估见 [DEPENDENCIES.md](DEPENDENCIES.md)。

```sh
cd cloud
go mod verify
go test -race -timeout=60s ./...
go vet ./...
test -z "$(gofmt -l main.go main_test.go)"
mkdir -p /tmp/pg-cloud-runtime
python3 scripts/download_runtime.py /tmp/pg-cloud-runtime
CGO_ENABLED=0 go build -trimpath -o /tmp/pg-cloud-runtime/project-graph-cloud .
python3 scripts/collect_licenses.py /tmp/pg-cloud-runtime
podman pull docker.io/library/postgres@sha256:639ab7ceb90e13123085b741fb31ef493fba25463002f6da665352e7b534b652
QUOTA_TEST=1 python3 scripts/local_e2e.py /tmp/pg-cloud-runtime
```

真实本地端到端检查创建临时数据库和随机测试账号，使用 30 秒验证码验证过期，结束后删除容器、匿名数据卷、进程和临时配置。覆盖注册验证、密码登录、重置、旧刷新令牌撤销、跨用户隔离、完整文件与附件往返、版本冲突、并发提交、非法文件、上传中断、配额、认证服务断开；单元检查覆盖认证超时、取消请求和请求容量释放。运行前须保证 15432、19999、18080、18025、11025 未占用。

服务器需已安装 Podman、Python 3 和 systemd；需要 SSH 管理权限。部署脚本生成秘密并保存于服务器权限受限目录，不提交凭证。运行时由上面的下载脚本验证上游摘要，PostgreSQL 通过镜像摘要固定。离线传输时另外验证传输前后的 SHA-256。

```sh
podman save -o /tmp/pg-cloud-runtime/postgres.tar docker.io/library/postgres@sha256:639ab7ceb90e13123085b741fb31ef493fba25463002f6da665352e7b534b652
gzip -1 -c /tmp/pg-cloud-runtime/postgres.tar > /tmp/pg-cloud-runtime/postgres.tar.gz
python3 scripts/deploy_test.py ylris /tmp/pg-cloud-runtime /tmp/pg-cloud-runtime/postgres.tar.gz
```

服务器工作目录 `/opt/project-graph-cloud`，数据库持久化 Podman 卷 `pg-cloud-postgres`。四个 systemd 服务开机启动；数据库上限 512 MiB，三个原生服务各上限 256 MiB。首次数据库初始化和认证迁移期间服务可能短暂重试。

重部署保留现有配置与数据库。停止测试环境可执行：

```sh
ssh ylris 'systemctl disable --now pg-cloud-api pg-cloud-auth pg-cloud-mailpit pg-cloud-postgres'
```

停止操作保留数据库卷和邮件，不自动删除用户数据。切换真实发信需要修改服务器 `config/auth.env` 的 SMTP 主机、端口、发信地址、用户名和密码，再重启 `pg-cloud-auth`；SMTP 密码不应发到聊天或写入仓库。公开发布前还需要独立域名、HTTPS、代理可信 IP 配置及正式配额和备份策略。

## 接口

所有账号请求使用 JSON；云文件请求使用 `Authorization: Bearer <access_token>`。

| 请求 | 参数 / 行为 |
| --- | --- |
| `POST /v1/auth/signup` | `email`, `password`；发送注册验证码 |
| `POST /v1/auth/confirm` | `email`, `code`；确认注册，不返回登录令牌 |
| `POST /v1/auth/login` | `email`, `password`；返回访问和刷新令牌 |
| `POST /v1/auth/refresh` | `refresh_token`；更新令牌 |
| `POST /v1/auth/recover` | `email`；发送重置验证码，不泄露账号是否存在 |
| `POST /v1/auth/reset` | `email`, `code`, `password`；设置新密码 |
| `POST /v1/auth/logout` | JSON `{}` 和访问令牌；撤销刷新会话 |
| `GET /v1/projects` | 列出自己的项目 |
| `POST /v1/projects` | 原始 PRG 字节，`X-Project-Name` 为 UTF-8 百分号编码项目名 |
| `PUT /v1/projects/{id}/file` | 原始 PRG 字节，`If-Match: "N"` |
| `GET /v1/projects/{id}/file` | 当前 PRG，响应含版本 ETag 和 SHA-256 |
| `GET /v1/projects/{id}/revisions` | 版本列表 |
| `GET /v1/projects/{id}/revisions/{N}/file` | 指定历史版本 |
| `DELETE /v1/projects/{id}` | 删除所有版本，`If-Match: "N"` |
