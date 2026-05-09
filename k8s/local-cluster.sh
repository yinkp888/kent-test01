#!/bin/bash
set -e

NAMESPACE=${NAMESPACE:-argocd}
ARGOCD_PORT=${ARGOCD_PORT:-8080}

usage() {
    echo "Usage: $0 {start|stop|status|restart}"
    echo ""
    echo "  start   启动 Colima、minikube、ArgoCD 端口转发"
    echo "  stop    停止端口转发、minikube、Colima"
    echo "  status  查看所有服务状态"
    echo "  restart 重启所有服务"
    exit 1
}

start_colima() {
    if colima status 2>&1 | grep -q "running"; then
        echo "[OK] Colima 已运行"
    else
        echo "[..] 启动 Colima..."
        colima start --cpu 2 --memory 4 --disk 20
    fi
}

start_minikube() {
    if minikube status 2>/dev/null | grep -q "host: Running"; then
        echo "[OK] minikube 已运行"
    else
        echo "[..] 启动 minikube..."
        minikube start --driver=docker --cpus=2 --memory=2048
    fi
}

start_portforward() {
    if pgrep -f "port-forward.*argocd-server" > /dev/null; then
        echo "[OK] ArgoCD 端口转发已在运行 (localhost:$ARGOCD_PORT)"
    else
        echo "[..] 启动 ArgoCD 端口转发 (localhost:$ARGOCD_PORT -> 443)..."
        nohup kubectl port-forward -n "$NAMESPACE" svc/argocd-server "$ARGOCD_PORT":443 --address 0.0.0.0 &>/tmp/argocd-pf.log &
        sleep 3
        echo "[OK] 端口转发已启动 (PID: $!)"
    fi
}

start() {
    echo "===== 启动所有服务 ====="
    start_colima
    start_minikube
    start_portforward
    echo ""
    echo "所有服务已启动！"
    echo "  ArgoCD: https://localhost:$ARGOCD_PORT"
    echo "  用户名: admin"
    echo "  密码:   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

stop() {
    echo "===== 停止所有服务 ====="
    echo "[..] 停止 ArgoCD 端口转发..."
    pkill -f "port-forward.*argocd-server" 2>/dev/null || true
    echo "[OK] 端口转发已停止"

    if minikube status 2>/dev/null | grep -q "host: Running"; then
        echo "[..] 停止 minikube..."
        minikube stop
        echo "[OK] minikube 已停止"
    else
        echo "[OK] minikube 未运行"
    fi

    if colima status 2>&1 | grep -q "running"; then
        echo "[..] 停止 Colima..."
        colima stop
        echo "[OK] Colima 已停止"
    else
        echo "[OK] Colima 未运行"
    fi

    echo "所有服务已停止"
}

status() {
    echo "===== 服务状态 ====="

    echo -n "Colima:  "
    if colima status 2>&1 | grep -q "running"; then
        echo "Running"
    else
        echo "Stopped"
    fi

    echo -n "minikube: "
    if minikube status 2>/dev/null | grep -q "host: Running"; then
        echo "Running"
        echo "  Nodes:  $(kubectl get nodes -o name 2>/dev/null | wc -l | xargs)"
        echo "  K8s:    $(kubectl version --short 2>/dev/null | grep Server | awk '{print $3}')"
    else
        echo "Stopped"
    fi

    echo -n "ArgoCD: "
    if pgrep -f "port-forward.*argocd-server" > /dev/null; then
        local running=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[*].status.phase}' 2>/dev/null)
        if echo "$running" | grep -q Running; then
            echo "Running"
            echo "  URL:    https://localhost:$ARGOCD_PORT"
        else
            echo "Pod 未就绪: $running"
        fi
    else
        echo "端口转发未启动"
    fi

    echo -n "FastAPI: "
    if kubectl get pods -l app=fastapi-app -o jsonpath='{.items[*].status.phase}' 2>/dev/null | grep -q Running; then
        echo "Running"
        echo "  Endpoints:"
        echo "    GET http://localhost:8000/"
        echo "    GET http://localhost:8000/items/"
        echo "    GET http://localhost:8000/items/{id}"
    else
        echo "N/A"
    fi
}

case "${1:-}" in
    start)   start ;;
    stop)    stop ;;
    restart) stop; sleep 2; start ;;
    status)  status ;;
    *)       usage ;;
esac
