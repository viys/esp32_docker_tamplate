#!/bin/bash

# 检查 Docker 是否启动
check_docker() {
    # 尝试获取 Docker 信息，检查 Docker 是否正在运行
    if ! docker info > /dev/null 2>&1; then
        echo -e "\033[31mDocker 服务未启动或未安装，请启动 Docker。\033[0m"
        exit 1
    else
        echo -e "\033[32mDocker 服务正在运行。\033[0m"
    fi
}

# 显示标题
show_header() {
    echo -e "\033[36m===============================\033[0m"
    echo -e "\033[36m        ESP-IDF 开发工具        \033[0m"
    echo -e "\033[36m===============================\033[0m"
}

# 显示菜单
show_menu() {
    show_header
    echo -e "\033[33m请选择要执行的命令：\033[0m"
    echo "1. 创建项目 (create-project)"
    echo "2. 设置目标芯片 (set-target)"
    echo "3. 配置项目 (menuconfig)"
    echo "4. 编译项目 (build)"
    echo "5. 打开容器终端 (bash)"
    echo "6. 启动串口服务器 (esp_rfc2217_server)"
    echo "7. 烧录程序 (flash)"
    echo "8. 串口监视器 (monitor)"
    echo "9. 脚本使用帮助 (help)"
    echo -e "\033[31m0. 退出\033[0m"
}

# 显示帮助
show_help() {
    echo -e "\033[33m\n===============================\n     ESP-IDF 脚本使用帮助     \n===============================\033[0m"
    echo -e "\n1. 创建项目：使用 create-project 创建新的 ESP-IDF 项目。"
    echo -e "2. 设置目标芯片：通过 set-target 设置目标芯片类型（如 esp32s3）。"
    echo -e "3. 配置项目：打开 menuconfig 菜单进行配置。"
    echo -e "4. 编译项目：构建当前目录项目生成固件。"
    echo -e "5. 打开容器终端：进入 docker 中的 ESP-IDF 开发环境。"
    echo -e "6. 启动串口服务器：通过 esp_rfc2217_server 启动网络串口。"
    echo -e "7. 烧录程序：通过 flash 命令将固件烧录。"
    echo -e "8. 串口监视器：连接设备串口输出。"
    echo -e "0. 退出脚本。"
    echo -e "===============================\033[0m"
}

# 检查 esptool 是否存在
ensure_esptool() {
    tool_dir="scripts/esptool-win64"
    if [ ! -d "$tool_dir" ]; then
        echo -e "\033[33m未找到 $tool_dir，正在运行 install_esptool.py 安装...\033[0m"
        if [ -f "scripts/install_esptool.py" ]; then
            python3 scripts/install_esptool.py
            if [ ! -d "$tool_dir" ]; then
                echo -e "\033[31m安装失败，目录仍然不存在：$tool_dir\033[0m"
                return 1
            fi
        else
            echo -e "\033[31m安装脚本未找到：scripts/install_esptool.py\033[0m"
            return 1
        fi
    fi
    return 0
}

# 执行命令逻辑
run_command() {
    case "$1" in
        1)
            read -p "请输入目标项目名称: " proj
            docker-compose run --rm esp-idf idf.py create-project "$proj"
            src="$proj"
            dst="$(dirname "$proj")"
            shopt -s dotglob
            mv "$src"/* "$dst"/
            rm -r "$src"
            exit 0
            ;;
        2)
            read -p "请输入目标芯片名称（如 esp32s3）: " target
            docker-compose run --rm esp-idf idf.py set-target "$target"
            exit 0
            ;;
        3)
            docker-compose run --rm esp-idf idf.py menuconfig
            exit 0
            ;;
        4)
            docker-compose run --rm esp-idf idf.py build
            exit 0
            ;;
        5)
            docker-compose run --rm esp-idf bash
            exit 0
            ;;
        6)
            read -p "请输入目标串口设备名称（如 /dev/ttyUSB0）: " port
            if ensure_esptool; then
                pushd scripts/esptool-win64 > /dev/null
                ./esp_rfc2217_server -v -p 4000 "$port"
                popd > /dev/null
            fi
            exit 0
            ;;
        7)
            docker-compose run --rm esp-idf idf.py --port "rfc2217://host.docker.internal:4000?ign_set_control" flash
            exit 0
            ;;
        8)
            docker-compose run --rm esp-idf idf.py --port "rfc2217://host.docker.internal:4000?ign_set_control" monitor
            exit 0
            ;;
        9)
            show_help
            exit 0
            ;;
        0)
            echo -e "\033[31m退出。\033[0m"
            exit 0
            ;;
        *)
            echo -e "\033[31m无效选择，请重试。\033[0m"
            ;;
    esac
}

# 在脚本开始时检查 Docker 是否启动
check_docker

# 主循环
while true; do
    show_menu
    read -p "请输入数字选择（0-9）: " selection
    if [[ "$selection" =~ ^[0-9]$ ]]; then
        run_command "$selection"
    else
        echo -e "\033[31m无效输入，请输入有效数字（0-9）。\033[0m"
    fi
done
