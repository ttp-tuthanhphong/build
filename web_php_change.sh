#!/bin/bash

LOG_FILE="/var/log/web_php_change.log"
CB_PATH="/usr/local/directadmin/custombuild"
OPTIONS_CONF="$CB_PATH/options.conf"
DATE=$(date "+%Y-%m-%d %H:%M:%S")

echo "[$DATE] --- Bắt đầu kiểm tra ---" | tee -a "$LOG_FILE"

# Đọc webserver từ options.conf
if [[ -f "$OPTIONS_CONF" ]]; then
    current_webserver=$(grep '^webserver=' "$OPTIONS_CONF" | cut -d= -f2)
    echo "[$DATE] Máy chủ web hiện tại: $current_webserver" | tee -a "$LOG_FILE"

    echo "[$DATE] Các phiên bản PHP đang được sử dụng:" | tee -a "$LOG_FILE"
    for i in {1..4}; do
        php_ver=$(grep "^php${i}_release=" "$OPTIONS_CONF" | cut -d= -f2)
        if [[ -n "$php_ver" ]]; then
            echo "  - PHP${i}: $php_ver" | tee -a "$LOG_FILE"
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

    echo "[$DATE] Cập nhật và build lại..." | tee -a "$LOG_FILE"
    cd $CB_PATH
    ./build update
    ./build php n
    ./build all d

    echo "[$DATE] Đã hoàn tất thay đổi." | tee -a "$LOG_FILE"
else
    echo "[$DATE] Không có thay đổi nào được thực hiện." | tee -a "$LOG_FILE"
fi

echo "[$DATE] --- Kết thúc ---" | tee -a "$LOG_FILE"
