#!/bin/bash

# 定义文本格式
BOLD=$(tput bold)
NORMAL=$(tput sgr0)
SUCCESS_COLOR='\033[1;32m'
WARNING_COLOR='\033[1;33m'
ERROR_COLOR='\033[1;31m'
INFO_COLOR='\033[1;36m'

# 自定义状态显示函数
display_status() {
    local message="$1"
    local status="$2"
    case $status in
        "error")
            echo -e "${ERROR_COLOR}${BOLD}❌ 错误: ${message}${NORMAL}"
            ;;
        "warning")
            echo -e "${WARNING_COLOR}${BOLD}⚠️ 警告: ${message}${NORMAL}"
            ;;
        "success")
            echo -e "${SUCCESS_COLOR}${BOLD}✅ 成功: ${message}${NORMAL}"
            ;;
        "info")
            echo -e "${INFO_COLOR}${BOLD}ℹ️ 信息: ${message}${NORMAL}"
            ;;
        *)
            echo -e "${message}"
            ;;
    esac
}

# 导出验证器密钥
export_validator_key() {
    display_status "正在导出验证器密钥..." "info"
    /usr/local/bin/story validator export
    display_status "验证器密钥导出成功。" "success"
}

# 确保脚本以 root 用户身份运行
if [[ $EUID -ne 0 ]]; then
    display_status "请以 root 用户权限运行此脚本。" "error"
    exit 1
fi

# 安装必要的依赖
setup_prerequisites() {
    display_status "检查并安装所需的系统依赖项..." "info"

    apt update -y && apt upgrade -y
    local dependencies=("curl" "wget" "jq" "make" "gcc" "nano")
    for package in "${dependencies[@]}"; do
        if ! dpkg -l | grep -q "^ii\s\+$package"; then
            display_status "正在安装 $package..." "info"
            apt install -y $package
        else
            display_status "$package 已经安装，跳过。" "success"
        fi
    done
}

# 安装 Node.js 和 npm
install_runtime_env() {
    if ! command -v node &> /dev/null; then
        display_status "正在安装 Node.js..." "info"
        curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
        apt-get install -y nodejs
        display_status "Node.js 安装完成。" "success"
    else
        display_status "Node.js 已安装，跳过此步骤。" "success"
    fi
}

# 安装 PM2
setup_process_manager() {
    if ! command -v pm2 &> /dev/null; then
        display_status "正在安装 PM2..." "info"
        npm install pm2@latest -g
        display_status "PM2 安装完成。" "success"
    else
        display_status "PM2 已安装，跳过此步骤。" "success"
    fi
}

# 安装 Story 节点
deploy_story_node() {
    display_status "开始部署 Story 节点..." "info"
    setup_prerequisites
    install_runtime_env
    setup_process_manager

    local story_geth_url="https://story-geth-binaries.s3.us-west-1.amazonaws.com/geth-public/geth-linux-amd64-0.9.3.tar.gz"
    local story_client_url="https://story-geth-binaries.s3.us-west-1.amazonaws.com/story-public/story-linux-amd64-0.10.1.tar.gz"

    display_status "下载 Story 执行和共识客户端..." "info"
    wget -q $story_geth_url -O geth-linux-amd64.tar.gz
    wget -q $story_client_url -O story-linux-amd64.tar.gz

    if [[ -f "geth-linux-amd64.tar.gz" && -f "story-linux-amd64.tar.gz" ]]; then
        tar -xzf geth-linux-amd64.tar.gz -C /usr/local/bin/
        tar -xzf story-linux-amd64.tar.gz -C /usr/local/bin/
        display_status "Story 节点解压和安装完成。" "success"
    else
        display_status "文件下载失败，请检查网络连接或下载 URL。" "error"
        exit 1
    fi

    /usr/local/bin/story init --network iliad
    display_status "Story 节点初始化完成。" "success"

    pm2 start /usr/local/bin/story --name story-client -- run -f
    display_status "Story 客户端已成功启动。" "success"

    read -n 1 -s -r -p "部署完成！按任意键返回主菜单..."
    main_menu
}

# 验证器设置功能
manage_validator() {
    display_status "进入验证器设置..." "info"
    echo "请选择验证器操作:"
    echo "1. 创建新的验证器"
    echo "2. 质押到现有验证器"
    echo "3. 取消质押"
    echo "4. 导出验证器密钥"
    echo "5. 返回主菜单"
    read -p "请输入选项（1-5）: " OPTION

    case $OPTION in
        1) create_validator ;;
        2) stake_to_validator ;;
        3) unstake_from_validator ;;
        4) export_validator_key ;;
        5) main_menu ;;
        *) display_status "无效选项，请重试。" "error"; manage_validator ;;
    esac
}

# 创建新的验证器
create_validator() {
    read -p "请输入质押金额（以 IP 为单位）: " AMOUNT_TO_STAKE_IN_IP
    AMOUNT_TO_STAKE_IN_WEI=$((AMOUNT_TO_STAKE_IN_IP * 1000000000000000000))
    /usr/local/bin/story validator create --stake ${AMOUNT_TO_STAKE_IN_WEI}
    display_status "新的验证器创建成功。" "success"
}

# 质押到现有验证器
stake_to_validator() {
    read -p "请输入验证器公钥（Base64格式）: " VALIDATOR_PUB_KEY_IN_BASE64
    read -p "请输入质押金额（以 IP 为单位）: " AMOUNT_TO_STAKE_IN_IP
    AMOUNT_TO_STAKE_IN_WEI=$((AMOUNT_TO_STAKE_IN_IP * 1000000000000000000))
    /usr/local/bin/story validator stake --validator-pubkey ${VALIDATOR_PUB_KEY_IN_BASE64} --stake ${AMOUNT_TO_STAKE_IN_WEI}
    display_status "质押成功。" "success"
}

# 取消质押
unstake_from_validator() {
    read -p "请输入验证器公钥（Base64格式）: " VALIDATOR_PUB_KEY_IN_BASE64
    read -p "请输入取消质押金额（以 IP 为单位）: " AMOUNT_TO_UNSTAKE_IN_IP
    AMOUNT_TO_UNSTAKE_IN_WEI=$((AMOUNT_TO_UNSTAKE_IN_IP * 1000000000000000000))
    /usr/local/bin/story validator unstake --validator-pubkey ${VALIDATOR_PUB_KEY_IN_BASE64} --unstake ${AMOUNT_TO_UNSTAKE_IN_WEI}
    display_status "取消质押成功。" "success"
}

# 主菜单
main_menu() {
    while true; do
        clear
        echo "============================Story 节点管理工具============================"
        echo "请选择操作:"
        echo "1. 部署 Story 节点"
        echo "2. 管理验证器"
        echo "3. 查看节点状态"
        echo "4. 退出"
        read -p "请输入选项（1-4）: " OPTION

        case $OPTION in
            1) deploy_story_node ;;
            2) manage_validator ;;
            3) pm2 logs story-client ;;
            4) exit 0 ;;
            *) display_status "无效选项，请重试。" "error" ;;
        esac
    done
}

# 启动主菜单
main_menu
