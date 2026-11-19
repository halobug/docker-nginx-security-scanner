# Docker Nginx Security Scanner

轻量级 Docker Nginx 安全配置扫描工具，支持自动发现运行中的 Nginx 容器，批量检查潜在安全风险，并生成终端扫描报告。

**只读扫描 · 无需额外依赖 · 不修改配置 · 不重启容器**

## NGINX2Root 安全漏洞

**NGINX2Root** 是由安全研究团队 Xint 披露的一组 Nginx 安全漏洞，涉及 HTTP/2、HTTP/3、DNS Resolver 和邮件代理等功能。在特定条件下，攻击者可能实现远程代码执行，并结合其他漏洞进一步获取宿主机 root 权限。

**相关 CVE 编号：**

- CVE-2026-123007
- CVE-2026-123634
- CVE-2026-123633
- CVE-2026-121810
- CVE-2026-113425

**官方漏洞说明：** [https://nginx2root.com/](https://nginx2root.com/)

**完整技术分析：** [https://xint.io/](https://xint.io/)

本项目提供 Docker 环境下的 Nginx 安全配置批量检查，帮助运维人员快速识别潜在风险。工具仅进行只读配置扫描，不执行漏洞利用，不能替代完整的漏洞检测与安全审计。

---

## 功能特性

- **自动发现**：扫描所有运行中的 Docker 容器，自动识别 Nginx 服务。
- **版本识别**：获取 Nginx 版本、镜像名称及编译模块信息。
- **协议检测**：检查 HTTP/2、HTTP/3、QUIC 是否启用。
- **配置审计**：检查 DNS Resolver、动态反向代理、Mirror、SSI、Mail Proxy 等配置。
- **容器安全**：检查 Docker Privileged 模式及 Docker Socket 挂载。
- **端口检查**：列出 Docker 容器发布的端口。
- **风险分级**：根据检测到的配置特征输出 HIGH、MEDIUM、LOW、UNKNOWN 四种状态。
- **只读运行**：不修改配置、不重启容器、不执行漏洞利用代码。

支持官方 Nginx 镜像以及能够通过 `docker exec` 调用 `nginx` 命令的自定义镜像。

## 检测项目

| 检测项目            | 检测内容                   |
| --------------- | ---------------------- |
| Nginx Version   | Nginx 版本信息             |
| HTTP/2          | 是否启用 HTTP/2            |
| HTTP/3          | 是否启用 HTTP/3 / QUIC     |
| DNS Resolver    | 是否配置 DNS Resolver      |
| Reverse Proxy   | 是否配置反向代理               |
| Dynamic Proxy   | 是否使用变量形式的 `proxy_pass` |
| Mirror / SSI    | 是否配置 Mirror、SSI 功能     |
| Mail Proxy      | 是否检测到邮件代理相关配置          |
| Privileged      | 是否开启 Docker 特权模式       |
| Docker Socket   | 是否挂载 Docker Socket     |
| Published Ports | Docker 发布的端口信息         |

以上检测属于静态配置特征检查，不代表对具体 CVE 的完整验证。

## 环境要求

- Linux
- Docker Engine
- Bash 4.0+
- Docker CLI
- 当前用户具有 Docker 容器检查及执行命令的权限

被扫描容器需要能够通过 `docker exec` 调用 `nginx` 命令。

## 快速开始

### 1. 克隆项目

```
git clone https://github.com/<username>/docker-nginx-security-scanner.git
cd docker-nginx-security-scanner
```

将 `<username>` 替换为实际 GitHub 用户名。

### 2. 执行扫描

```
chmod +x nginx-security-check.sh
./nginx-security-check.sh
```

也可以直接使用 Bash 执行：

```
bash nginx-security-check.sh
```

### 3. 保存扫描报告

```
./nginx-security-check.sh | tee nginx-security-report.txt
```

扫描过程不会主动修改 Docker 容器或 Nginx 配置。

## 输出示例

以下为模拟输出：

```
========================================
 Docker Nginx Security Scanner
========================================
Scan Time: 2026-11-19 09:30:00
Mode: READ ONLY

[LOW] nginx-web
  Image: nginx:1.21.5-alpine
  Version: 1.21.5
  HTTP/2: NO (module: YES)
  HTTP/3: NO (module: NO)
  Resolver: NO | Dynamic Proxy: NO
  Proxy: YES | Mirror/SSI: NO | Mail: NO
  Privileged: false | Docker Socket: NO
  Ports: 80/tcp -> 0.0.0.0:8080
  Reason: No obvious trigger detected

[MEDIUM] nginx-api
  Image: nginx:1.19.6-alpine
  Version: 1.19.6
  HTTP/2: NO (module: YES)
  HTTP/3: NO (module: NO)
  Resolver: YES | Dynamic Proxy: NO
  Proxy: YES | Mirror/SSI: NO | Mail: NO
  Privileged: false | Docker Socket: NO
  Ports: Not published
  Reason: Resolver configured

[HIGH] nginx-gateway
  Image: nginx:1.25.0-alpine
  Version: 1.25.0
  HTTP/2: YES (module: YES)
  HTTP/3: NO (module: NO)
  Resolver: NO | Dynamic Proxy: NO
  Proxy: YES | Mirror/SSI: NO | Mail: NO
  Privileged: false | Docker Socket: NO
  Ports: 443/tcp -> 0.0.0.0:443
  Reason: HTTP/2 enabled

========================================
 Scan Summary
========================================
Total Nginx Containers: 3
HIGH:    1
MEDIUM:  1
LOW:     1
UNKNOWN: 0
========================================
```

## 风险等级说明

| 等级      | 说明                   | 建议    |
| ------- | -------------------- | ----- |
| HIGH    | 发现需要优先核查的潜在危险配置或容器权限 | 优先检查  |
| MEDIUM  | 发现可能相关的功能配置          | 进一步确认 |
| LOW     | 未发现当前规则覆盖的明显危险配置     | 持续关注  |
| UNKNOWN | 无法完成配置检查             | 手动核查  |

**注意：**

- `HIGH` 不代表漏洞一定存在或可以被利用。
- `LOW` 不代表 Nginx 不存在安全漏洞。
- `UNKNOWN` 表示检查未完成，不能作为安全判断依据。
- 检测结果需要结合 Nginx 版本、补丁状态、模块配置及实际网络环境综合判断。

例如，启用 HTTP/2 会触发 HIGH，但仅启用 HTTP/2 并不能证明存在 NGINX2Root 漏洞。

## NGINX2Root 检查说明

本项目可辅助检查 NGINX2Root 相关漏洞可能涉及的部分配置条件。

| 检查方向          | 检测方式                             |
| ------------- | -------------------------------- |
| HTTP/2        | 检查 HTTP/2 是否启用                   |
| HTTP/3 / QUIC | 检查 HTTP/3 是否启用                   |
| DNS Resolver  | 检查 Resolver 及动态代理配置              |
| Mail Proxy    | 检查邮件代理相关配置                       |
| 容器权限          | 检查 Privileged 及 Docker Socket 挂载 |

这些检查只能用于初步识别潜在攻击面，无法完整判断五个 CVE 的受影响版本、全部触发条件或实际可利用性。

本工具不会尝试远程代码执行、容器逃逸或宿主机提权。

## 安全性

本工具采用只读扫描方式：

- 不修改 Nginx 配置文件。
- 不修改 Docker 容器配置。
- 不停止或重启任何容器。
- 不发送漏洞利用请求。
- 不执行提权操作。
- 不安装额外软件。

扫描主要通过以下 Docker 命令读取信息：

```
docker ps
docker inspect
docker exec
docker port
```

Nginx 信息通过以下命令获取：

```
nginx -v
nginx -V
nginx -T
```

其中 `nginx -T` 用于检查并输出 Nginx 配置，可能读取包含敏感信息的配置内容。

请勿公开未经脱敏的完整 Nginx 配置或包含敏感信息的扫描日志。

## 已知限制

1. 仅扫描正在运行的 Docker 容器。
2. 需要容器内可以执行 `nginx` 命令。
3. 部分自定义 Nginx 镜像可能无法识别。
4. 基于配置文本进行检测，复杂配置可能存在误报或漏报。
5. 不进行完整的 Nginx 配置上下文语义分析。
6. 无法确认发行版是否已回移安全补丁。
7. 不验证实际网络可达性或漏洞利用条件。
8. 不检查宿主机 Linux 内核漏洞。
9. 不扫描 Traefik、Apache、Caddy 等其他 Web 服务器。
10. 不保证检测到所有 Nginx 安全漏洞。

## 后续计划

- 增加 Nginx 版本与 CVE 数据库匹配。
- 增加 JSON 格式扫描报告。
- 支持指定容器扫描。
- 支持 Docker Compose 项目过滤。
- 优化 Nginx 配置上下文解析。
- 增加可选的宿主机内核安全检查。
- 支持自动化安全检查。
- 支持更多 Nginx 安全配置规则。

## 免责声明

本项目仅用于合法授权的安全检查与配置审计。

扫描结果仅供安全运维参考，不构成对系统安全性的完整保证。使用者应结合实际部署环境、官方安全公告及补丁信息综合评估风险。
