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

# 导出验证器密钥
export_validator_key() {
    show_status "正在导出验证器密钥..." "progress"
    /usr/local/bin/story validator export
    show_status "验证器密钥导出成功。" "success"
}

# 其他函数定义
# 确保首次安装的函数、依赖项安装、Node.js安装、PM2安装等都在此处定义

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

# 主菜单定义
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

