#!/bin/bash

# 定义文本格式
BOLD=$(tput bold)
NORMAL=$(tput sgr0)
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
PINK='\033[1;35m'

# 自定义状态显示函数
show_status() {
    local message="$1"
    local status="$2"
    case $status in
        "error")
            echo -e "${RED}${BOLD}🚫 出错: ${message}${NORMAL}"
            ;;
        "progress")
            echo -e "${YELLOW}${BOLD}🔄 进行中: ${message}${NORMAL}"
            ;;
        "success")
            echo -e "${GREEN}${BOLD}🎉 成功: ${message}${NORMAL}"
            ;;
        *)
            echo -e "${PINK}${BOLD}${message}${NORMAL}"
            ;;
    esac
}

# 确保脚本以 root 用户身份运行
if [[ $EUID -ne 0 ]]; then
   show_status "请以 root 用户权限运行此脚本。" "error"
   exit 1
fi

# 更新并安装必需的软件包
show_status "正在更新并安装依赖..." "progress"
apt update && apt upgrade -y && apt install -y curl wget jq make gcc nano
show_status "依赖安装完成。" "success"

# 安装 Node.js 和 npm
if ! command -v node &> /dev/null; then
    show_status "正在安装 Node.js..." "progress"
    curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
    sudo apt-get install -y nodejs
    show_status "Node.js 安装完成。" "success"
else
    show_status "Node.js 已安装，跳过此步骤。" "success"
fi

# 安装 PM2
if ! command -v pm2 &> /dev/null; then
    show_status "正在安装 PM2..." "progress"
    npm install pm2@latest -g
    show_status "PM2 安装完成。" "success"
else
    show_status "PM2 已安装，跳过此步骤。" "success"
fi

# 安装 Story 节点
show_status "正在安装 Story 节点..." "progress"
wget -q https://story-geth-binaries.s3.us-west-1.amazonaws.com/geth-public/geth-linux-amd64-0.9.3.tar.gz
wget -q https://story-geth-binaries.s3.us-west-1.amazonaws.com/story-public/story-linux-amd64-0.10.1.tar.gz

# 解压缩并配置客户端
tar -xzf geth-linux-amd64-0.9.3.tar.gz -C /usr/local/bin/
tar -xzf story-linux-amd64-0.10.1.tar.gz -C /usr/local/bin/
show_status "Story 节点安装完成。" "success"

# 初始化 Story 节点
show_status "初始化 Story 节点..." "progress"
/usr/local/bin/story init --network iliad
show_status "Story 节点初始化完成。" "success"

# 使用 PM2 启动 Story 客户端（使用 -f 强制启动）
show_status "使用 PM2 启动 Story 客户端..." "progress"
pm2 start /usr/local/bin/story --name story-client -- run -f
show_status "Story 客户端已成功启动。" "success"

# 创建 .env 文件以存储私钥
if [ ! -f "$HOME/.story/.env" ]; then
    read -p "请输入您的私钥（不包括 0x 前缀）: " PRIVATE_KEY
    mkdir -p "$HOME/.story"
    echo "PRIVATE_KEY=${PRIVATE_KEY}" > "$HOME/.story/.env"
    show_status ".env 文件已创建，私钥已保存。" "success"
else
    show_status "已检测到现有的 .env 文件，跳过私钥输入。" "success"
fi

show_status "Story 节点已成功安装和配置！" "success"
