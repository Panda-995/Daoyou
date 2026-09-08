# 万界道友双架构 Compose 部署

源项目：[ChurchTao/Daoyou](https://github.com/ChurchTao/Daoyou)。镜像构建源码与工作流：[Panda-995/Daoyou](https://github.com/Panda-995/Daoyou)，沿用 GPL-3.0 许可证。

镜像：

- `ghcr.io/panda-995/daoyou-app:latest`：Bun API、实时战斗与后台任务。
- `ghcr.io/panda-995/daoyou-web:latest`：React 网页及同源 Nginx 代理，支持 WebSocket 和流式响应。

两者均支持 `linux/amd64` 和 `linux/arm64`，Docker 自动选择架构。

## 部署

把 `compose.yaml` 与 `.env` 放在同一目录。从仓库下载时，将 `docker/compose.env.example` 复制为 `.env`，为密码与密钥生成独立的随机值，例如 `openssl rand -hex 32`。数据库、Redis 和 NATS 密码使用十六进制字符串，避免连接串转义问题。

先修改 `.env`：

1. `SITE_URL`：实际浏览器访问地址，例如 `http://192.168.1.10:8081` 或反向代理后的 `https://game.example.com`，不带路径或尾斜杠。仅在本机浏览器访问时使用 `localhost`。网页和 API 共用此地址。
2. `DEEPSEEK_API_KEY` 或 `ALIBABA_API_KEY`：游戏 AI 功能需要至少一个有效模型密钥。保持未使用的密钥为空。玩家也可按上游功能使用自己的 BYOK 配置。
3. `SMTP_HOST`、`SMTP_PORT`、`SMTP_SECURE`、`SMTP_USER`、`SMTP_PASS`、`MAIL_FROM`：注册验证邮件与邮件验证码所需。服务能在未填写 SMTP 时启动，但邮箱注册登录无法完整使用；部署不会关闭邮箱验证。

```sh
docker compose pull
docker compose up -d
docker compose ps -a
```

默认访问 `http://服务器IP:8081`。没有预设管理员或默认账号，使用页面的注册/登录流程。`ADMIN_EMAILS` 可指定管理员邮箱；账号管理操作另需 `ADMIN_USER_IDS`，按上游权限约定设置，白名单不会自动创建账号。

如使用 HTTPS 反向代理，将目标指向宿主机 `8081` 端口，启用 WebSocket 转发，并让 `SITE_URL` 对应外部 HTTPS 地址。修改 `.env` 后执行 `docker compose up -d` 使配置生效。

## 初始化和数据

Compose 包含 PostgreSQL 17、Redis 7.4、NATS 2.11 JetStream、一次性迁移服务、Bun 应用、Nginx 网页。仅网页端口对宿主机开放。

迁移服务复用上游 Drizzle SQL 文件，分别维护 `drizzle.__drizzle_auth_migrations` 与 `drizzle.__drizzle_migrations`；先完成迁移再启动应用。`migrate` 显示 `Exited (0)` 是正常状态。不执行 schema push、数据库 reset 或绕过迁移历史。

PostgreSQL、Redis AOF、NATS JetStream 都使用 Docker 命名卷。普通重启和 `docker compose down` 保留数据。`docker compose down -v` 会删除这些数据卷，请勿用于日常更新。

## 更新与排查

本分支修正了上游初始迁移 `0000_cute_apocalypse.sql` 的执行顺序：将 `item_library_item_id_unique` 唯一索引移到引用它的外键之前。SQL 语句本身和最终表结构保持一致；已应用的迁移不会重跑。这解决了新数据库初始化时报“no unique constraint matching given keys”的问题。

更新前备份数据库，并按需要备份 Redis 和 NATS 数据卷：

```sh
docker compose exec -T db pg_dump -U daoyou daoyou > daoyou-backup.sql
docker compose pull
docker compose up -d
docker compose logs --tail=100 migrate app
```

如固定了版本，将 `.env` 中 `IMAGE_TAG` 改为所需的 `sha-<12位提交号>` 或 `latest` 后更新。镜像回退不会自动回退数据库迁移。

健康接口是 `/api/health-check`，检查 Redis、NATS 和消息基础设施。迁移失败时先查看 `docker compose logs migrate`，不要删除数据卷跳过问题。

## 构建验证范围

GitHub Actions 在原生 amd64、arm64 runner 上分别执行 `bun run build:server` 和 `bun run build:client`，均包含上游 TypeScript 检查，并保留独立的在线战斗 Worker 构建产物。随后启动完整 Compose、检查首页/登录页面/健康接口、确认两套迁移记录，并再次运行迁移确认可重复执行，最后才发布镜像和双架构清单。

本次为容器部署工作，没有修改游戏引擎或业务逻辑，没有新增后端/数据库单元测试，也没有运行全量单元测试或全量 lint。真实 SMTP 邮件、付费模型调用与完整游戏对局不在这些启动检查之内。

发布使用 GitHub Actions 自带的 `GITHUB_TOKEN`，个人令牌不进入仓库、镜像、Compose 或部署包。
