#!/bin/bash

# 定义文本格式
BOLD=$(tput bold)
NORMAL=$(tput sgr0)
SUCCESS_COLOR='\033[1;32m'
WARNING_COLOR='\033[1;33m'
ERROR_COLOR='\033[1;31m'
INFO_COLOR='\033[1;36m'
INIT_COLOR='\033[1;35m'

# 自定义状态显示函数
show_status() {
    local message="$1"
    local status="$2"
    case $status in
        "error")
            echo -e "${ERROR_COLOR}${BOLD}🚫 出错: ${message}${NORMAL}"
            ;;
        "progress")
            echo -e "${WARNING_COLOR}${BOLD}🔄 进行中: ${message}${NORMAL}"
            ;;
        "success")
            echo -e "${SUCCESS_COLOR}${BOLD}🎉 成功: ${message}${NORMAL}"
            ;;
        "initializing")
            echo -e "${INIT_COLOR}${BOLD}⚙️ 初始化: ${message}${NORMAL}"
            ;;
        *)
            echo -e "${INIT_COLOR}${BOLD}${message}${NORMAL}"
            ;;
    esac
}

# 检查首次安装的函数
initialize_first_install() {
    if [ ! -f "/usr/local/bin/story" ]; then
        show_status "正在进行首次安装初始化..." "initializing"
        setup_prerequisites
        install_runtime_env
        setup_process_manager
        show_status "首次安装配置完成。" "success"
    else
        show_status "已检测到已安装的环境，跳过首次配置。" "success"
    fi
}

# 确保脚本以 root 用户身份运行
if [[ $EUID -ne 0 ]]; then
    show_status "请以 root 用户权限运行此脚本。" "error"
    exit 1
fi

# 安装必要的依赖
setup_prerequisites() {
    show_status "检查并安装所需的系统依赖项..." "progress"

    apt update -y && apt upgrade -y
    local dependencies=("curl" "wget" "jq" "make" "gcc" "nano")
    for package in "${dependencies[@]}"; do
        if ! dpkg -l | grep -q "^ii\s\+$package"; then
            show_status "正在安装 $package..." "progress"
            apt install -y $package
        else
            show_status "$package 已经安装，跳过。" "success"
        fi
    done
}

# 安装 Node.js 和 npm
install_runtime_env() {
    if ! command -v node &> /dev/null; then
        show_status "正在安装 Node.js..." "progress"
        curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
        sudo apt-get install -y nodejs
        show_status "Node.js 安装完成。" "success"
    else
        show_status "Node.js 已安装，跳过此步骤。" "success"
    fi
}

# 安装 PM2
setup_process_manager() {
    if ! command -v pm2 &> /dev/null; then
        show_status "正在安装 PM2..." "progress"
        npm install pm2@latest -g
        show_status "PM2 安装完成。" "success"
    else
        show_status "PM2 已安装，跳过此步骤。" "success"
    fi
}

# 安装 Story 节点
deploy_story_node() {
    show_status "开始部署 Story 节点..." "initializing"
    initialize_first_install

    local story_geth_url="https://story-geth-binaries.s3.us-west-1.amazonaws.com/geth-public/geth-linux-amd64-0.9.3.tar.gz"
    local story_client_url="https://story-geth-binaries.s3.us-west-1.amazonaws.com/story-public/story-linux-amd64-0.10.1.tar.gz"

    show_status "下载 Story 执行和共识客户端..." "progress"
    wget -q $story_geth_url -O geth-linux-amd64.tar.gz
    wget -q $story_client_url -O story-linux-amd64.tar.gz

    if [[ -f "geth-linux-amd64.tar.gz" && -f "story-linux-amd64.tar.gz" ]]; then
        tar -xzf geth-linux-amd64.tar.gz -C /usr/local/bin/
        tar -xzf story-linux-amd64.tar.gz -C /usr/local/bin/
        show_status "Story 节点解压和安装完成。" "success"
    else
        show_status "文件下载失败，请检查网络连接或下载 URL。" "error"
        exit 1
    fi

    /usr/local/bin/story init --network iliad
    show_status "Story 节点初始化完成。" "success"

    pm2 start /usr/local/bin/story --name story-client -- run -f
    show_status "Story 客户端已成功启动。" "success"

    read -n 1 -s -r -p "部署完成！按任意键返回主菜单..."
    main_menu
}

# 验证器设置功能
manage_validator() {
    show_status "进入验证器设置..." "progress"
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
        *) show_status "无效选项，请重试。" "error"; manage_validator ;;
    esac
}

# 创建新的验证器
create_validator() {
    read -p "请输入质押金额（以 IP 为单位）: " AMOUNT_TO_STAKE_IN_IP
    AMOUNT_TO_STAKE_IN_WEI=$((AMOUNT_TO_STAKE_IN_IP * 1000000000000000000))
    /usr/local/bin/story validator create --stake ${AMOUNT_TO_STAKE_IN_WEI}
    show_status "新的验证器创建成功。" "success"
}

# 导出验证器密钥
export_validator_key() {
    show_status "正在导出验证器密钥..." "progress"
    /usr/local/bin/story validator export
    show_status "验证器密钥导出成功。" "success"
}

# 主菜单
main_menu() {
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
        *) show_status "无效选项，请重试。" "error"; main_menu ;;
    esac
}

# 启动主菜单
main_menu
