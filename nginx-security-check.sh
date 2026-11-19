#!/usr/bin/env bash

# Docker Nginx 安全配置检查
# 只读扫描，不修改容器或 Nginx 配置

set -u

TOTAL=0
HIGH=0
MEDIUM=0
LOW=0
UNKNOWN=0

check_config() {
    local pattern="$1"
    printf '%s\n' "$CONFIG" | grep -Eq "$pattern"
}

check_build() {
    local pattern="$1"
    printf '%s\n' "$BUILD" | grep -Eq "$pattern"
}

scan_container() {
    local id="$1"
    local name image version raw_config
    local h2 h3 resolver dynamic_proxy proxy mail mirror
    local privileged socket ports risk reasons
    local h2_module h3_module

    name=$(docker inspect -f '{{.Name}}' "$id" 2>/dev/null)
    name="${name#/}"

    image=$(docker inspect -f '{{.Config.Image}}' "$id" 2>/dev/null)

    # 判断是否安装 Nginx
    version=$(docker exec "$id" nginx -v 2>&1) || return
    version=$(printf '%s\n' "$version" |
        grep -oE '[0-9]+\.[0-9]+\.[0-9]+' |
        head -1)

    [ -z "$version" ] && return

    TOTAL=$((TOTAL + 1))

    # 获取配置与编译信息
    raw_config=$(docker exec "$id" nginx -T 2>&1)
    config_status=$?

    BUILD=$(docker exec "$id" nginx -V 2>&1)

    if [ "$config_status" -ne 0 ]; then
        UNKNOWN=$((UNKNOWN + 1))

        printf '\n[UNKNOWN] %s\n' "$name"
        printf '  Image: %s\n' "$image"
        printf '  Version: %s\n' "$version"
        printf '  Reason: nginx -T failed\n'
        return
    fi

    # 去除注释行和行尾注释
    CONFIG=$(printf '%s\n' "$raw_config" |
        sed -E 's/[[:space:]]+#.*$//; /^[[:space:]]*#/d')

    h2=NO
    h3=NO
    resolver=NO
    dynamic_proxy=NO
    proxy=NO
    mail=NO
    mirror=NO
    h2_module=NO
    h3_module=NO

    # HTTP/2
    if check_config 'listen[[:space:]]+[^;]*[[:space:]]http2([[:space:];]|$)|^[[:space:]]*http2[[:space:]]+on[[:space:]]*;'; then
        h2=YES
    fi

    # HTTP/3 / QUIC
    if check_config 'listen[[:space:]]+[^;]*[[:space:]]quic([[:space:];]|$)|^[[:space:]]*http3[[:space:]]+on[[:space:]]*;'; then
        h3=YES
    fi

    # DNS Resolver
    if check_config '^[[:space:]]*resolver[[:space:]]+'; then
        resolver=YES
    fi

    # 反向代理
    if check_config '^[[:space:]]*(proxy_pass|fastcgi_pass|grpc_pass|uwsgi_pass|scgi_pass)[[:space:]]+'; then
        proxy=YES
    fi

    # 动态反向代理（含变量）
    if check_config '^[[:space:]]*proxy_pass[[:space:]]+[^;]*\$'; then
        dynamic_proxy=YES
    fi

    # Mirror / SSI
    if check_config '^[[:space:]]*(mirror|ssi)[[:space:]]+'; then
        mirror=YES
    fi

    # Mail 模块配置
    if check_config '^[[:space:]]*mail[[:space:]]*\{|^[[:space:]]*auth_http[[:space:]]+'; then
        mail=YES
    fi

    # 编译模块
    if check_build 'http_v2_module'; then
        h2_module=YES
    fi

    if check_build 'http_v3_module'; then
        h3_module=YES
    fi

    # Docker 权限
    privileged=$(docker inspect -f \
        '{{.HostConfig.Privileged}}' "$id")

    socket=NO
    if docker inspect -f \
        '{{range .Mounts}}{{println .Source}}{{end}}' "$id" |
        grep -Fxq '/var/run/docker.sock'; then
        socket=YES
    fi

    # Docker 端口映射
    ports=$(docker port "$id" 2>/dev/null | tr '\n' ' ')
    [ -z "$ports" ] && ports="Not published"

    # 风险分级
    risk=LOW
    reasons=""

    if [ "$h2" = YES ]; then
        risk=HIGH
        reasons="${reasons}HTTP/2 enabled; "
    fi

    if [ "$h3" = YES ]; then
        risk=HIGH
        reasons="${reasons}HTTP/3 enabled; "
    fi

    if [ "$resolver" = YES ]; then
        if [ "$dynamic_proxy" = YES ]; then
            risk=HIGH
            reasons="${reasons}Resolver with dynamic proxy; "
        else
            [ "$risk" = LOW ] && risk=MEDIUM
            reasons="${reasons}Resolver configured; "
        fi
    fi

    if [ "$mail" = YES ]; then
        [ "$risk" = LOW ] && risk=MEDIUM
        reasons="${reasons}Mail proxy configured; "
    fi

    if [ "$mirror" = YES ]; then
        [ "$risk" = LOW ] && risk=MEDIUM
        reasons="${reasons}Mirror/SSI configured; "
    fi

    if [ "$privileged" = true ]; then
        risk=HIGH
        reasons="${reasons}Privileged container; "
    fi

    if [ "$socket" = YES ]; then
        risk=HIGH
        reasons="${reasons}Docker socket mounted; "
    fi

    [ -z "$reasons" ] && reasons="No obvious trigger detected"

    case "$risk" in
        HIGH) HIGH=$((HIGH + 1)) ;;
        MEDIUM) MEDIUM=$((MEDIUM + 1)) ;;
        LOW) LOW=$((LOW + 1)) ;;
    esac

    printf '\n[%s] %s\n' "$risk" "$name"
    printf '  Image: %s\n' "$image"
    printf '  Version: %s\n' "$version"
    printf '  HTTP/2: %s (module: %s)\n' "$h2" "$h2_module"
    printf '  HTTP/3: %s (module: %s)\n' "$h3" "$h3_module"
    printf '  Resolver: %s | Dynamic Proxy: %s\n' \
        "$resolver" "$dynamic_proxy"
    printf '  Proxy: %s | Mirror/SSI: %s | Mail: %s\n' \
        "$proxy" "$mirror" "$mail"
    printf '  Privileged: %s | Docker Socket: %s\n' \
        "$privileged" "$socket"
    printf '  Ports: %s\n' "$ports"
    printf '  Reason: %s\n' "$reasons"
}

echo "========================================"
echo " Docker Nginx Security Scanner"
echo "========================================"
echo "Scan Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Mode: READ ONLY"

while IFS= read -r id; do
    [ -z "$id" ] && continue
    scan_container "$id"
done < <(docker ps -q)

echo
echo "========================================"
echo " Scan Summary"
echo "========================================"
printf 'Total Nginx Containers: %s\n' "$TOTAL"
printf 'HIGH:    %s\n' "$HIGH"
printf 'MEDIUM:  %s\n' "$MEDIUM"
printf 'LOW:     %s\n' "$LOW"
printf 'UNKNOWN: %s\n' "$UNKNOWN"
echo "========================================"
