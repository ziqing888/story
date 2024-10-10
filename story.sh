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

# Story 节点安装函数
install_story_node() {
    show_status "正在安装 Story 节点..." "progress"

    # 更新并安装必需的软件包
    apt update && apt upgrade -y && apt install -y curl wget jq make gcc nano

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

    # 下载并安装 Story 节点
    wget -q https://story-geth-binaries.s3.us-west-1.amazonaws.com/geth-public/geth-linux-amd64-0.9.3.tar.gz
    wget -q https://story-geth-binaries.s3.us-west-1.amazonaws.com/story-public/story-linux-amd64-0.10.1.tar.gz

    tar -xzf geth-linux-amd64-0.9.3.tar.gz -C /usr/local/bin/
    tar -xzf story-linux-amd64-0.10.1.tar.gz -C /usr/local/bin/

    # 初始化 Story 节点
    /usr/local/bin/story init --network iliad
    show_status "Story 节点安装和初始化完成。" "success"

    # 使用 PM2 启动 Story 客户端
    pm2 start /usr/local/bin/story --name story-client -- run -f
    show_status "Story 客户端已成功启动。" "success"
}

# 设置验证器的函数
function setup_validator() {
    show_status "设置验证器..." "progress"
    echo "请选择验证器操作:"
    echo "1. 创建新的验证器"
    echo "2. 质押到现有验证器"
    echo "3. 取消质押"
    echo "4. 导出验证器密钥"
    echo "5. 添加操作员"
    echo "6. 移除操作员"
    echo "7. 返回主菜单"
    read -p "请输入选项（1-7）: " OPTION

    case $OPTION in
        1) create_validator ;;
        2) stake_to_validator ;;
        3) unstake_from_validator ;;
        4) export_validator_key ;;
        5) add_operator ;;
        6) remove_operator ;;
        7) main_menu ;;
        *) show_status "无效选项，请重试。" "error"; setup_validator ;;
    esac
}

# 主菜单
function main_menu() {
    clear
    echo "============================Story 节点管理工具============================"
    echo "请选择操作:"
    echo "1. 安装 Story 节点"
    echo "2. 设置验证器"
    echo "3. 检查节点状态"
    echo "4. 退出"
    read -p "请输入选项（1-4）: " OPTION

    case $OPTION in
        1) install_story_node ;;
        2) setup_validator ;;
        3) pm2 logs story-client ;;
        4) exit 0 ;;
        *) show_status "无效选项，请重试。" "error"; main_menu ;;
    esac
}

# 启动主菜单
main_menu
