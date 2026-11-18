# 曾的个人博客项目分析、环境配置与运行报告

> 分析时间：2026-11-16（Asia/Shanghai）  
> 分析对象：`D:\codeGo\my-blog` 当前工作树  
> 原则：未修改业务源代码；复用当前机器已有运行时与依赖，优先采用项目原有的本地开发方式。

## 1. 结论摘要

当前项目已经完成本地开发环境配置并正常运行：

- 前端：Vue 3 SPA，已通过 Vite 开发服务器运行在 `http://127.0.0.1/`。
- 后端：Go + Gin REST API，运行在 `http://127.0.0.1:8080`。
- 依赖服务：MySQL 8、Redis 7、Elasticsearch 8.19.6 均由 Docker Compose 运行且健康。
- 数据库：已迁移 11 张业务表；已存在 1 个管理员账号。
- Elasticsearch：`article_index` 已创建，Mapping 正确，当前 0 篇文档。
- 构建与测试：`npm run build` 成功；`go test ./...` 成功。
- 页面验收：首页、搜索、热榜、碎碎念、标签页、404 页均可正常渲染，未发现浏览器控制台错误。
- 接口验收：公开接口、JWT 鉴权接口、管理员接口均返回 HTTP 200 且 `code=0`。

当前项目可以直接使用；真实邮件、QQ 登录、七牛云和高德天气属于可选外部服务，因未提供对应密钥而保持禁用状态，不影响本地核心功能启动。

## 2. 技术栈及版本

### 2.1 后端

| 技术/依赖 | 项目声明版本 | 当前环境/说明 |
|---|---:|---|
| Go | `go 1.26.3` | 已安装 `go1.27.3 windows/amd64`，可正常编译当前模块 |
| Gin | `v1.12.0` | HTTP Web 框架 |
| GORM | `v1.31.2` | ORM |
| MySQL Driver | `v1.6.0` | GORM MySQL 驱动 |
| Elasticsearch Go Client | `v8.19.6` | TypedClient API |
| go-redis | `v6.15.9+incompatible` | Redis 客户端 |
| JWT | `golang-jwt/jwt/v4 v4.5.2` | HS256 双 Token |
| Zap | `v1.28.0` | 结构化日志 |
| lumberjack | `v2.0.0+incompatible` | 日志轮转 |
| cron | `github.com/robfig/cron/v3 v3.0.1` | 定时任务 |
| urfave/cli | `v1.22.17` | 数据库/ES/管理员 CLI |
| base64Captcha | `v1.3.8` | 图形验证码 |
| Qiniu SDK | `v7.27.0` | 七牛云对象存储 |
| gin-contrib/sessions | `v1.1.0` | 邮箱验证码服务端 Session |
| UApi SDK | `v0.1.18` | 热榜与一言外部数据源 |
| Endless | commit `4471340` | 非 Windows 下的平滑重启服务器 |

### 2.2 前端

| 技术/依赖 | 安装版本 |
|---|---:|
| Vue | `3.5.10` |
| Vue Router | `4.4.5` |
| Pinia | `2.2.3` |
| Vite | `5.4.8` |
| TypeScript | `5.4.5` |
| Element Plus | `2.8.4` |
| Axios | `1.7.7` |
| md-editor-v3 | `5.0.2` |
| lucide-vue-next | `0.577.0` |
| Sass | `1.79.4` |
| vue-tsc | `2.1.6` |
| unplugin-auto-import | `0.18.3` |
| unplugin-vue-components | `0.27.4` |

### 2.3 基础设施

| 服务 | 当前版本/镜像 | 当前端口 |
|---|---|---|
| MySQL | `mysql:8.0`，实际 `8.0.46` | 宿主机 `3307` → 容器 `3306` |
| Redis | `redis:7-alpine` | `6379` |
| Elasticsearch | `8.19.6` | `9200` |
| Docker | `29.9.2` | - |
| Docker Compose | `v5.6.1` | - |
| Node.js | `v24.15.0` | - |
| npm | `11.12.1` | - |

## 3. 总体架构

```text
Vue 3 SPA (Element Plus + Pinia)
        │
        │ Axios /api；开发环境由 Vite proxy 转发
        ▼
Gin HTTP Server :8080
        │
        ├── router  路由与权限分组
        ├── api     参数绑定、响应输出
        ├── service 业务逻辑
        ├── model   MySQL / ES / Request / Response
        ├── middleware JWT / Admin / 日志 / 登录记录
        ├── task    定时任务
        └── utils   分页、JWT、上传、邮件、YAML 等
        │
        ├── MySQL：用户、标签、收藏、评论、反馈、图片、日志等关系数据
        ├── Elasticsearch：文章正文、检索、文章统计
        └── Redis：文章浏览量增量、热榜缓存、登录会话、天气缓存
```

### 3.1 后端架构

后端采用典型的四层结构：

1. `router`：声明 REST 路由，并区分公开、登录用户、管理员三组。
2. `api`：Gin Handler，负责参数绑定、校验、调用 Service、输出统一响应。
3. `service`：业务规则、事务、ES/Redis/外部服务编排。
4. `model`：数据库模型、ES 文档与 Mapping、请求和响应 DTO。
5. `middleware`：JWT、管理员权限、请求日志、登录审计。
6. `initialize`：MySQL、Redis、ES、路由、Session、Cron 初始化。
7. `global`：全局单例，包括 Config、Logger、DB、Redis、ESClient、BlackCache。

### 3.2 前端架构

- 单页应用，Vue Router 使用 `createWebHistory`。
- 路由页面全部懒加载，前台与后台共用同一个 SPA。
- Pinia 管理用户、站点配置、布局弹窗、主题、后台标签页等状态。
- Axios 实例统一注入 `x-access-token`，统一处理响应体 `{code,data,msg}`。
- Access Token 保存在内存；Refresh Token 保存在 HttpOnly Cookie。
- 后端刷新 Access Token 时通过 `new-access-token` 响应头返回，Axios 拦截器自动更新。
- 开发环境由 Vite 把 `/api` 和 `/uploads` 代理到 `http://127.0.0.1:8080`。
- Element Plus 组件和图标自动导入；md-editor-v3 用于 Markdown 编辑与预览。

## 4. 目录结构与模块职责

```text
my-blog/
├── docker-compose.dev.yml      MySQL / Redis / Elasticsearch 本地开发容器
├── README.md                   项目说明
├── server/                     Go 后端
│   ├── main.go                 进程入口
│   ├── config.yaml             运行配置（gitignore，含本地密钥）
│   ├── api/                    HTTP Handler
│   ├── config/                 配置结构体
│   ├── core/                   配置、日志、HTTP Server
│   ├── flag/                   CLI 初始化/导入导出/建管理员
│   ├── global/                 全局单例与基础 Model
│   ├── initialize/             MySQL/Redis/ES/路由/Cron 初始化
│   ├── middleware/             JWT、管理员、日志、登录检索
│   ├── model/
│   │   ├── database/           MySQL 模型
│   │   ├── elasticsearch/      ES 文档与 Mapping
│   │   ├── request/            请求 DTO
│   │   ├── response/           响应 DTO
│   │   ├── appTypes/           角色、注册来源、图片类别/存储枚举
│   │   └── other/              分页、热榜、QQ、高德等中间模型
│   ├── router/                 路由注册
│   ├── service/                核心业务逻辑
│   ├── task/                   定时任务
│   ├── utils/                  工具函数
│   │   └── upload/             本地/七牛上传适配器
│   ├── uploads/                本地上传文件目录
│   └── log/                    Zap/业务日志
└── web/                        Vue 前端
    ├── .env                    API 基址与后端代理目标
    ├── vite.config.ts          Vite、代理、自动导入、拆包
    ├── src/api/                类型化 API 封装
    ├── src/assets/             全局主题与变量
    ├── src/components/         公共、表单、布局、页面、组件
    ├── src/router/             前台/后台路由与守卫
    ├── src/stores/             Pinia 状态
    ├── src/utils/request.ts    Axios 拦截器
    └── src/views/
        ├── web/                前台页面
        ├── dashboard/          用户中心与管理员后台
        ├── login/              登录页
        └── error/              404
```

### 4.1 后端模块

- `api/base.go`：图形验证码、邮箱验证码、QQ 登录 URL。
- `api/user.go`：注册、邮箱/QQ 登录、Token 下发、登出、密码、用户资料、天气、用户管理。
- `api/article.go`：文章详情、搜索、标签、收藏、CRUD、后台列表。
- `api/comment.go`：文章评论树、发表/删除评论、个人评论、后台评论列表。
- `api/feedback.go`：反馈提交、个人反馈、最新反馈、后台回复/删除/列表。
- `api/murmur.go`：碎碎念公开列表与管理员 CRUD。
- `api/image.go`：文件上传、图片元数据分页、删除。
- `api/website.go`：站点信息、Logo、标题、页脚链接、一言。
- `api/config.go`：网站、系统、邮件、QQ、七牛、JWT、高德配置读取/更新。
- `api/hot.go`：聚合热榜。
- `service/*`：对应业务实现，是主要逻辑所在。
- `task`：每小时同步浏览量；每 30 分钟刷新热榜缓存。

### 4.2 前端模块

- `views/web`：首页、文章详情、搜索、热榜、标签、碎碎念、友链。
- `views/dashboard/home`：后台欢迎页。
- `views/dashboard/articles`：文章发布、文章列表、评论管理。
- `views/dashboard/users`：用户列表与冻结/解冻。
- `views/dashboard/images`：图片上传与分类管理。
- `views/dashboard/system`：反馈、登录日志、碎碎念、应用配置。
- `views/dashboard/user-center`：个人资料、收藏、评论、反馈。
- `components/forms`：登录、注册、找回密码、文章表单、反馈回复。
- `components/common`：头像、评论树、用户卡片、认证弹窗。
- `components/layout`：前台导航/页脚、后台菜单/面包屑/标签页。
- `stores/user.ts`：用户信息、Access Token、登录状态。
- `stores/website.ts`：站点配置缓存。
- `stores/tag.ts` / `layout.ts` / `theme.ts`：后台页签、弹窗、主题与折叠状态。

## 5. 核心业务逻辑与执行流程

### 5.1 后端启动流程

```text
main()
  → core.InitConf()          读取 server/config.yaml
  → core.InitLogger()        初始化 Zap + lumberjack
  → initialize.MySQLInit()   建立 GORM/MySQL 连接池
  → initialize.ConnectEs()   建立 Elasticsearch TypedClient
  → initialize.ConnectRedis() 连接 Redis 并 Ping
  → initialize.OtherInit()   解析 Token 有效期、初始化本地黑名单缓存
  → flag.InitFlag()          若带 CLI 参数则执行工具并退出
  → initialize.InitCron()    注册定时任务并启动
  → core.RunServer()         初始化 Gin 路由并监听 0.0.0.0:8080
```

Windows 使用标准 `http.Server`；非 Windows 使用 `endless` 服务器。

### 5.2 注册、登录与鉴权

1. `/api/base/captcha` 生成数字图形验证码，验证码存于 base64Captcha 内存 Store。
2. 发送邮箱验证码前先校验图形验证码；验证码、邮箱、过期时间写入 Cookie Session。
3. 注册时校验 Session 中的邮箱、验证码和过期时间；密码使用 bcrypt 哈希；UUID 唯一。
4. 邮箱登录先校验图形验证码，再按邮箱查询用户并校验 bcrypt 密码。
5. 登录成功生成：
   - Access Token：HS256，包含 UserID、UUID、RoleID，默认 2 小时。
   - Refresh Token：HS256，只含 UserID，默认 30 天，写入 `x-refresh-token` HttpOnly Cookie。
6. 开启多点登录时，Redis 以用户 UUID 为 Key 保存当前 Refresh Token；
   新登录会把旧 Refresh Token 写入 MySQL `jwt_blacklists` 和本地 LRU 黑名单。
7. `JWTAuth` 优先解析 Access Token；过期时使用 Refresh Token 换发新 Access Token，
   并通过 `new-access-token` / `new-access-expires-at` 响应头返回。
8. 管理员接口再经过 `AdminAuth`，要求 `role_id == 2`。
9. 登出删除 Redis 会话并将 Refresh Token 加入黑名单。

### 5.3 文章流程

文章正文不存 MySQL，主存储是 Elasticsearch 索引 `article_index`：

- 新建：标题去重 → 更新 MySQL 标签计数 → 从 Markdown 提取图片并更新图片类别 → 写入 ES。
- 搜索：在 `title`、`keyword`、`abstract`、`content` 上做多字段匹配；`tags` 作为过滤条件；按 `created_at` 倒序分页。
- 阅读：获取文章时异步将 `article_views` Redis Hash 的对应文章计数 +1。
- 收藏：MySQL `article_likes` 增删，同时用 ES Painless 脚本更新 `likes`。
- 更新：比较旧/新标签与 Markdown 图片，维护 MySQL 标签计数和图片分类，然后更新 ES。
- 删除：读取 ES 文章 → 回退标签计数/图片分类 → 删除该文章评论树 → 删除 ES 文档。
- 统计同步：Cron 每小时把 Redis 浏览量增量写回 ES，成功后清空 `article_views`。

需要注意：MySQL 事务与 ES 写入无法共享同一个事务；若 ES 操作失败，MySQL 可能已经提交，因此不是严格分布式事务。

### 5.4 评论流程

- 评论表使用 `p_id` 自关联形成评论树。
- 查询一级评论后递归加载 `children`。
- 新建/删除评论由 GORM Hook 通过 Painless 脚本更新 ES 文章 `comments` 计数。
- 删除权限：评论作者本人或管理员。
- 删除父评论时递归删除全部子评论。
- 个人评论中心会做父子评论去重。

### 5.5 热榜、天气、一言与外部服务

- 热榜通过 UApi 聚合百度、B站、知乎、抖音、HelloGitHub、IT之家、掘金、CSDN。
- 单平台缓存 Key 为 `hot:<platform>`，有效期 40 分钟；Cron 每 30 分钟预热。
- 高德服务用于 IP 归属地和实时天气；天气结果按 IP Redis 缓存 1 小时。
- 一言开启时请求 UApi，失败回退到 `config.yaml` 的默认句。
- 邮件验证码通过 SMTP；当前配置为空，因此真实发信不可用。
- QQ 登录通过 OAuth code 交换 Access Token 和用户信息；当前未启用。
- 七牛上传由 `System.OssType` 选择；当前为 `local`。

### 5.6 图片与配置

- 上传先校验大小和扩展名白名单，再写入本地 `uploads/image` 或七牛。
- 图片元数据写入 `images`；文章 Markdown 图片和站点 Logo 会更新图片类别。
- 配置管理接口修改内存配置后调用 `SaveYAML()` 写回 `server/config.yaml`。
- `/uploads/*` 由 Gin 静态文件服务暴露；Vite 开发环境代理该前缀。

## 6. 数据库设计

### 6.1 MySQL 表

当前实际存在 11 张表：

| 表 | 作用 | 关键字段/关系 |
|---|---|---|
| `users` | 用户 | `uuid` 唯一、`password` bcrypt、`role_id`、`register`、`freeze` |
| `article_likes` | 文章收藏 | `user_id` → `users.id`；`article_id` 指向 ES 文档 ID |
| `article_tags` | 标签计数 | `tag` 主键、`number` |
| `comments` | 评论树 | `p_id` 自关联；`user_uuid` → `users.uuid` |
| `feedbacks` | 用户反馈 | `user_uuid` → `users.uuid`；`reply` |
| `footer_links` | 页脚链接 | `title` 主键、`link` |
| `friend_links` | 友链 | `logo` → `images.url` |
| `images` | 图片元数据 | `url` 唯一、类别、存储类型 |
| `jwt_blacklists` | Refresh Token 黑名单 | `jwt` 文本 |
| `logins` | 登录审计 | `user_id` → `users.id`、IP、地址、UA 解析结果 |
| `murmurs` | 碎碎念 | `content` |

GORM 统一下划线表名；大多数表包含 `created_at`、`updated_at`、`deleted_at` 并启用软删除；`article_tags` 和 `footer_links` 是少量无软删除的复合主键表。

### 6.2 Elasticsearch 索引

索引名：`article_index`

| 字段 | 类型 | 说明 |
|---|---|---|
| `created_at` / `updated_at` | `date` | 格式 `yyyy-MM-dd HH:mm:ss` |
| `title` | `text` | 标题全文检索 |
| `keyword` | `keyword` | 标题精确去重 |
| `tags` | `keyword[]` | 标签过滤 |
| `abstract` | `text` | 摘要全文检索 |
| `content` | `text` | Markdown 正文全文检索 |
| `views` / `comments` / `likes` | `integer` | 统计计数 |

当前单节点 ES 使用默认 1 个副本，因此 `_cluster/health` 为 `yellow`，但主分片已激活、索引可读写，这是单节点开发环境的正常状态，不是启动故障。

### 6.3 Redis Key 设计

| Key/结构 | 类型 | 用途 |
|---|---|---|
| `<user UUID>` | String | 当前用户 Refresh Token（多点登录） |
| `article_views` | Hash | 文章 ID → 待同步浏览量增量 |
| `hot:<platform>` | String(JSON) | 各平台热榜缓存 |
| `weather-<ip>` | String | 天气文本缓存 |

## 7. 前后端交互方式

- REST/JSON API，统一前缀 `/api`。
- 统一响应体：

```json
{"code": 0, "data": {}, "msg": "success"}
```

- `code=0` 表示成功，非 0 表示业务失败；前端拦截器自动弹出 `msg`。
- 认证：
  - `x-access-token` 请求头传递 Access Token。
  - `x-refresh-token` HttpOnly Cookie 传递 Refresh Token。
  - Access Token 过期时，响应头 `new-access-token` 自动刷新前端内存 Token。
- 参数形式：
  - 列表/搜索：Query。
  - 普通写操作：JSON。
  - 图片上传：`multipart/form-data`，字段名 `image`。
- 分页参数：`page`、`page_size`，MySQL 与 ES 都有统一分页工具。
- 开发环境同源：
  - `/api` → `http://127.0.0.1:8080/api`
  - `/uploads` → `http://127.0.0.1:8080/uploads`
- 后端未配置 CORS，生产部署应由 Nginx 将前后端放在同一域名下，或显式增加 CORS 策略。

### 7.1 主要接口分组

- `/api/base/*`：验证码、邮件验证码、QQ 登录 URL。
- `/api/user/*`：公开登录注册；登录态资料；管理员用户管理。
- `/api/article/*`：公开详情/搜索/标签；登录收藏；管理员 CRUD。
- `/api/comment/*`：公开评论树；登录发表/删除；管理员列表。
- `/api/feedback/*`：公开最新反馈；登录反馈；管理员回复/删除/列表。
- `/api/murmur/*`：公开列表；管理员发布/删除。
- `/api/image/*`：管理员上传/删除/列表。
- `/api/website/*`：站点信息、页脚、Logo、标题、一言。
- `/api/config/*`：管理员读取/更新配置。
- `/api/hot/all`：聚合热榜。

## 8. 配置说明

后端配置文件：`server/config.yaml`（已被 `.gitignore` 忽略，不应提交）。

| 配置块 | 用途 |
|---|---|
| `mysql` | MySQL 主机、端口、库名、账号、连接池、GORM 日志级别 |
| `redis` | Redis 地址、密码、DB |
| `es` | Elasticsearch URL、账号密码、控制台打印 |
| `system` | 监听地址、端口、Gin 环境、API 前缀、Session 密钥、多点登录、存储类型 |
| `jwt` | Access/Refresh 密钥、有效期、issuer |
| `email` | SMTP 发件配置 |
| `qq` | QQ OAuth AppID/Key/回调 |
| `qiniu` | 七牛 Zone、Bucket、域名、AK/SK |
| `gaode` | 高德 Key 和开关 |
| `captcha` | 图形验证码宽高、长度、干扰参数 |
| `upload` | 上传大小上限、本地存储目录 |
| `website` | 站点标题、标语、备案、社交链接、作者信息 |
| `hot` | 热榜平台列表与开关 |
| `yiyan` | 一言开关与默认句 |
| `zap` | 日志级别、路径、轮转参数 |

前端配置：`web/.env`

```dotenv
VITE_SERVER_URL=http://127.0.0.1:8080
VITE_BASE_API=/api
```

> 当前 `config.yaml` 中存在本地 JWT 密钥和开发数据库口令，报告中不展开具体值。生产部署应轮换密钥并使用环境变量/密钥管理，不要提交该文件。

## 9. 环境配置与启动方式

### 9.1 当前采用方案

采用“Docker 运行中间件 + 本机 Go/Vite 运行应用”的开发方案：

1. Docker Compose 启动 MySQL、Redis、Elasticsearch。
2. Go 后端直连宿主机映射端口。
3. Vite 开发服务器提供前端，并代理 API。

该方案复用现有工具链，改动最少，便于查看日志与调试。

### 9.2 基础设施启动

```powershell
cd D:\codeGo\my-blog
docker compose -f docker-compose.dev.yml up -d
docker compose -f docker-compose.dev.yml ps
```

当前三个容器均为 `healthy`：

- `my-blog-mysql-dev`
- `my-blog-redis-dev`
- `my-blog-elasticsearch-dev`

### 9.3 首次初始化（当前已完成，无需重复执行）

```powershell
cd D:\codeGo\my-blog\server
go run . -sql       # GORM AutoMigrate
go run . -es        # 创建 article_index；若已存在会询问是否删除，慎用
go run . -admin     # 创建管理员；当前已有管理员，无需重复执行
```

### 9.4 启动后端

```powershell
cd D:\codeGo\my-blog\server
go run .
```

当前后端监听：`0.0.0.0:8080`。

### 9.5 启动前端

```powershell
cd D:\codeGo\my-blog\web
npm install
npm run dev -- --host 0.0.0.0 --port 80
```

当前前端监听：`0.0.0.0:80`。

> 80 端口在 Windows 上可能需要管理员权限；也可使用 `--port 5173`，但需同步调整访问地址。

### 9.6 当前启动命令的实际进程

- 后端进程：`server.exe`，由 `go run .` 生成，监听 8080。
- 前端进程：`node vite.js --host 0.0.0.0 --port 80`，监听 80。
- 中间件：三个 Docker 容器由 Compose 管理。

## 10. 依赖安装情况

本次没有重复安装已经存在的软件或依赖：

- Go `1.27.3` 已存在，满足 `go.mod` 的 `1.26.3` 要求。
- Node.js `24.15.0`、npm `11.12.1` 已存在。
- `web/node_modules` 已安装完整，`npm ls --depth=0` 未报告缺失依赖。
- Docker 镜像 `mysql:8.0`、`redis:7-alpine`、`elasticsearch:8.19.6` 已拉取。
- Go modules 已缓存，`go test ./...` 成功完成。
- 未新增 npm/Go/系统级依赖。

如从空环境重建，核心安装命令为：

```powershell
# Docker Desktop 需已安装并启动
docker pull mysql:8.0
docker pull redis:7-alpine
docker pull docker.elastic.co/elasticsearch/elasticsearch:8.19.6

# 前端
cd D:\codeGo\my-blog\web
npm ci
```

Go 依赖由 `go.mod`/`go.sum` 自动获取：

```powershell
cd D:\codeGo\my-blog\server
go mod download
```

## 11. 本次构建、测试与运行验证

### 11.1 构建与静态检查

| 验证项 | 命令 | 结果 |
|---|---|---|
| Go 全包测试/编译 | `go test ./...` | 通过；除 `utils` 外各包无测试文件 |
| 前端类型检查 + 生产构建 | `npm run build` | 通过；Vite 生成 `dist`，只有 Sass legacy API 弃用警告 |
| 前端生产产物 | `web/dist` | 239 个文件，约 3.1 MB |

### 11.2 服务状态

| 项目 | 验证结果 |
|---|---|
| MySQL | 容器 `healthy`，`8.0.46`，字符集 `utf8mb4` |
| Redis | `PONG`，容器 `healthy`，当前 8 个热榜缓存 Key |
| Elasticsearch | 容器 `healthy`，`article_index` 存在，Mapping 正确 |
| 后端 | `http://127.0.0.1:8080/api/website/info` 返回 HTTP 200，`code=0` |
| 前端 | `http://127.0.0.1/` 返回 HTTP 200 |
| Vite 代理 | `http://127.0.0.1/api/article/tags` 返回 HTTP 200，`code=0` |

### 11.3 数据库状态

- 11 张表全部存在。
- 当前有 1 个管理员账号，`role_id=2`，可正常通过鉴权读取管理员接口。
- 文章、评论、反馈、标签、图片等业务表目前为空。
- GORM 迁移日志显示“数据库表结构迁移成功”。
- ES 初始化日志显示“Elasticsearch 索引初始化成功”。

### 11.4 接口抽查

以下接口均返回 HTTP 200、`code=0`：

- `/api/website/info`
- `/api/website/footerLink`
- `/api/murmur/all`
- `/api/feedback/new`
- `/api/article/tags`
- `/api/article/search?page=1&page_size=10`
- `/api/hot/all`
- `/api/base/captcha`
- JWT 鉴权后的 `/api/user/info`
- 管理员权限下的 `/api/user/list`
- 管理员权限下的 `/api/article/list`
- 管理员权限下的 `/api/comment/list`

未认证访问 `/api/user/info` 返回“登录已过期，请重新登录”，说明 JWT 拦截器按预期工作。

### 11.5 页面验收

浏览器实际打开并检查：

- 首页：正常渲染站点 Logo、一言、热榜入口和空文章列表。
- 搜索页：查询框、分页和“暂无数据”状态正常。
- 热榜页：8 个平台数据正常展示。
- 碎碎念页：空状态和站点页脚正常。
- 标签页：空状态和标签统计正常。
- 404 页：正常显示错误页和返回首页入口。

浏览器控制台未捕获 error/warning。

## 12. 已知限制与后续建议

1. **ES 集群为 yellow**：单节点 + 1 副本导致副本无法分配；主分片正常。若希望本地显示 green，可把索引副本数设为 0，但不建议直接修改生产索引。
2. **外部服务未配置**：SMTP、QQ OAuth、七牛、高德均未提供真实凭据；对应的真实发信、QQ 登录、云存储、天气功能尚未做端到端验证。
3. **开发进程无守护**：当前 Go 与 Vite 为交互式进程，终端退出或机器重启后需要重新执行启动命令；生产环境应使用 systemd、Windows 服务、容器或进程管理器。
4. **CORS 依赖同源代理**：前端通过 Vite/Nginx 同源代理访问后端；如果前后端部署到不同域名，需要增加 CORS 配置。
5. **SQL 导出脚本存在环境耦合**：`server/flag/sql_export.go` 中硬编码了 `docker exec mysql`，与当前容器名 `my-blog-mysql-dev` 不一致，执行 `-sql-export` 前需要调整。
6. **自动化测试覆盖很低**：目前只有 `server/utils/random_test.go`，核心业务缺少单元/集成/E2E 测试。
7. **敏感配置**：`server/config.yaml` 已被 gitignore，但本地仍保存真实密钥；部署前必须轮换并迁移到安全配置注入方式。
8. **当前业务数据为空**：文章列表显示“暂无数据”属于数据库/ES 无内容，不是页面或接口故障。

## 13. 访问地址

- 前台首页：<http://127.0.0.1/>
- 登录页：<http://127.0.0.1/login>
- 后台入口：<http://127.0.0.1/dashboard>
- 后端健康/站点信息：<http://127.0.0.1:8080/api/website/info>
- 热榜接口：<http://127.0.0.1:8080/api/hot/all>
- MySQL：`127.0.0.1:3307`
- Redis：`127.0.0.1:6379`
- Elasticsearch：<http://127.0.0.1:9200>

## 14. 本次文件变更说明

- 未修改任何业务源代码、路由、模型或配置文件。
- 新建本报告：`PROJECT_ANALYSIS_REPORT.md`。
- `npm run build` 重建了 `web/dist` 生产产物（构建产物，已被 gitignore）。
- `web/auto-imports.d.ts` 和 `web/components.d.ts` 是 Vite 插件生成的声明文件；当前工作树中已有修改痕迹。
- `docker-compose.dev.yml`、`server/config.yaml`、`server/run.out.log`、`server/run.err.log` 属于当前环境文件/运行日志；其中 `config.yaml` 被 gitignore，日志为未跟踪文件。
