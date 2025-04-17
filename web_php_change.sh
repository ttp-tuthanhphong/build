#!/bin/bash

# Định nghĩa đường dẫn và biến ngày giờ
LOG_FILE="/var/log/web_php_change.log"
CB_PATH="/usr/local/directadmin/custombuild"
OPTIONS_CONF="$CB_PATH/options.conf"
DATE=$(date "+%Y-%m-%d %H:%M:%S")

# Mã màu ANSI
YELLOW='\033[1;33m'
RESET='\033[0m'

echo "[$DATE] --- Bắt đầu kiểm tra ---" | tee -a "$LOG_FILE"

# Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
    echo "Script cần được chạy với quyền root." | tee -a "$LOG_FILE"
    exit 1
fi

# Kiểm tra tồn tại file cấu hình
if [[ -f "$OPTIONS_CONF" ]]; then
    current_webserver=$(grep '^webserver=' "$OPTIONS_CONF" | cut -d= -f2)
    echo -e "[$DATE] Máy chủ web hiện tại: ${YELLOW}${current_webserver}${RESET}" | tee -a "$LOG_FILE"

    echo "[$DATE] Các phiên bản PHP đang được sử dụng:" | tee -a "$LOG_FILE"
    for i in {1..4}; do
        php_ver=$(grep "^php${i}_release=" "$OPTIONS_CONF" | cut -d= -f2)
        if [[ -n "$php_ver" ]]; then
            echo -e "  - PHP${i}: ${YELLOW}${php_ver}${RESET}" | tee -a "$LOG_FILE"
        fi
    done
else
    echo "Không tìm thấy file options.conf, kiểm tra lại đường dẫn CustomBuild." | tee -a "$LOG_FILE"
    exit 1
fi

# Hỏi người dùng có muốn thay đổi không
read -p "Bạn có muốn thay đổi máy chủ web hoặc phiên bản PHP nào không? (y/n): " change

if [[ "$change" == "y" ]]; then
    read -p "Nhập webserver mới (apache/nginx/openlitespeed) hoặc nhấn Enter để giữ nguyên: " new_webserver
    if [[ -n "$new_webserver" ]]; then
        echo "[$DATE] Thay đổi webserver thành $new_webserver" | tee -a "$LOG_FILE"
        cd $CB_PATH
        ./build set webserver $new_webserver
    fi

    for i in {1..4}; do
        current_php=$(grep "^php${i}_release=" "$OPTIONS_CONF" | cut -d= -f2)
        if [[ -n "$current_php" ]]; then
            read -p "Thay đổi PHP${i} (hiện tại: $current_php)? Nhập phiên bản mới hoặc nhấn Enter để giữ nguyên: " new_php
            if [[ -n "$new_php" ]]; then
                echo "[$DATE] Thay đổi php${i}_release thành $new_php" | tee -a "$LOG_FILE"
                cd $CB_PATH
                ./build set php${i}_release $new_php
            fi
        fi
    done

    cd $CB_PATH
    ./build update

    echo ""
    echo -e "${YELLOW}Chọn hành động build tiếp theo:${RESET}"
    echo "  1. Build lại webserver"
    echo "  2. Build lại PHP"
    echo "  3. Build cả webserver và PHP"
    echo "  4. Không build gì cả"
    read -p "Nhập lựa chọn (1/2/3/4): " build_choice

    case "$build_choice" in
        1)
            echo "[$DATE] Đang build lại webserver..." | tee -a "$LOG_FILE"
            ./build ${new_webserver:-$current_webserver}
            ;;
        2)
            echo "[$DATE] Đang build lại PHP..." | tee -a "$LOG_FILE"
            ./build php n
            ;;
        3)
            echo "[$DATE] Đang build lại webserver và PHP..." | tee -a "$LOG_FILE"
            ./build ${new_webserver:-$current_webserver}
            ./build php n
            ;;
        4)
            echo "[$DATE] Không thực hiện build gì thêm." | tee -a "$LOG_FILE"
            ;;
        *)
            echo "[$DATE] Lựa chọn không hợp lệ. Không thực hiện build." | tee -a "$LOG_FILE"
            ;;
    esac

    echo "[$DATE] Hoàn tất quá trình thay đổi." | tee -a "$LOG_FILE"
else
    echo "[$DATE] Không có thay đổi nào được thực hiện." | tee -a "$LOG_FILE"
fi

echo "[$DATE] --- Kết thúc ---" | tee -a "$LOG_FILE"
