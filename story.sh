#!/bin/bash

# 确保脚本以 root 用户身份运行
if [[ $EUID -ne 0 ]]; then
   echo "请以 root 用户权限运行此脚本。"
   exit 1
fi

# 更新并安装必需的软件包
apt update && apt upgrade -y
apt install -y curl wget jq make gcc nano

# 安装 Node.js 和 npm
if ! command -v node &> /dev/null; then
    echo "正在安装 Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# 安装 PM2
if ! command -v pm2 &> /dev/null; then
    echo "正在安装 PM2..."
    npm install pm2@latest -g
fi

# 安装 Story 节点
echo "正在安装 Story 节点..."
wget -q https://story-geth-binaries.s3.us-west-1.amazonaws.com/geth-public/geth-linux-amd64-0.9.3.tar.gz
wget -q https://story-geth-binaries.s3.us-west-1.amazonaws.com/story-public/story-linux-amd64-0.10.1.tar.gz

# 解压缩并配置客户端
tar -xzf geth-linux-amd64-0.9.3.tar.gz -C /usr/local/bin/
tar -xzf story-linux-amd64-0.10.1.tar.gz -C /usr/local/bin/

# 初始化 Story 节点
/usr/local/bin/story init --network iliad

# 使用 PM2 启动 Story 客户端
pm2 start /usr/local/bin/story --name story-client -- run

# 创建 .env 文件以存储私钥
if [ ! -f "$HOME/.story/.env" ]; then
    read -p "请输入您的私钥（不包括 0x 前缀）: " PRIVATE_KEY
    echo "PRIVATE_KEY=${PRIVATE_KEY}" > "$HOME/.story/.env"
fi

echo "Story 节点已成功安装和配置！"
