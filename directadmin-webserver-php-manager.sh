#!/bin/bash

# Script kiểm tra và quản lý webserver và PHP trên DirectAdmin
# Yêu cầu chạy với quyền root

# Định nghĩa màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

# Định nghĩa file log
LOG_FILE="/root/directadmin_changes_$(date +%Y%m%d).log"
touch "$LOG_FILE"

# Hàm ghi log
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo -e "${BLUE}Đã ghi log: $1${NC}"
}

# Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Script này cần được chạy với quyền root.${NC}"
    exit 1
fi

# Kiểm tra DirectAdmin đã được cài đặt
if [ ! -d "/usr/local/directadmin" ]; then
    echo -e "${RED}DirectAdmin không được tìm thấy trên hệ thống này!${NC}"
    exit 1
fi

# Kiểm tra CustomBuild đã được cài đặt
if [ ! -d "/usr/local/directadmin/custombuild" ]; then
    echo -e "${RED}CustomBuild không được tìm thấy. Vui lòng cài đặt CustomBuild trước.${NC}"
    exit 1
fi

# Hàm kiểm tra webserver hiện tại
check_webserver() {
    echo -e "${YELLOW}===== Kiểm tra Webserver hiện tại =====${NC}"
    
    # Kiểm tra Apache
    if systemctl is-active --quiet httpd 2>/dev/null || systemctl is-active --quiet apache2 2>/dev/null; then
        APACHE_STATUS="đang chạy"
        if command -v httpd &>/dev/null; then
            APACHE_VERSION=$(httpd -v | grep "Server version" | awk '{print $3}' | cut -d'/' -f2)
        elif command -v apache2 &>/dev/null; then
            APACHE_VERSION=$(apache2 -v | grep "Server version" | awk '{print $3}' | cut -d'/' -f2)
        fi
        echo -e "Apache: ${GREEN}$APACHE_STATUS${NC} (Phiên bản: $APACHE_VERSION)"
    else
        APACHE_STATUS="không chạy hoặc không cài đặt"
        echo -e "Apache: ${RED}$APACHE_STATUS${NC}"
    fi
    
    # Kiểm tra Nginx
    if systemctl is-active --quiet nginx 2>/dev/null; then
        NGINX_STATUS="đang chạy"
        NGINX_VERSION=$(nginx -v 2>&1 | awk '{print $3}' | cut -d'/' -f2)
        echo -e "Nginx: ${GREEN}$NGINX_STATUS${NC} (Phiên bản: $NGINX_VERSION)"
    else
        NGINX_STATUS="không chạy hoặc không cài đặt"
        echo -e "Nginx: ${RED}$NGINX_STATUS${NC}"
    fi
    
    # Kiểm tra OpenLiteSpeed
    if systemctl is-active --quiet openlitespeed 2>/dev/null; then
        OLS_STATUS="đang chạy"
        if [ -f "/usr/local/lsws/VERSION" ]; then
            OLS_VERSION=$(cat /usr/local/lsws/VERSION)
            echo -e "OpenLiteSpeed: ${GREEN}$OLS_STATUS${NC} (Phiên bản: $OLS_VERSION)"
        else
            echo -e "OpenLiteSpeed: ${GREEN}$OLS_STATUS${NC}"
        fi
    else
        OLS_STATUS="không chạy hoặc không cài đặt"
        echo -e "OpenLiteSpeed: ${RED}$OLS_STATUS${NC}"
    fi
    
    # Xác định cấu hình webserver trong CustomBuild
    if [ -f "/usr/local/directadmin/custombuild/options.conf" ]; then
        WEBSERVER_CONFIG=$(grep "^webserver=" /usr/local/directadmin/custombuild/options.conf | cut -d'=' -f2)
        echo -e "Webserver được cấu hình trong CustomBuild: ${GREEN}$WEBSERVER_CONFIG${NC}"
        
        if [[ "$WEBSERVER_CONFIG" == *"nginx"* ]]; then
            NGINX_TYPE=$(grep "^nginx_type=" /usr/local/directadmin/custombuild/options.conf | cut -d'=' -f2)
            if [ -n "$NGINX_TYPE" ]; then
                echo -e "Loại cấu hình Nginx: ${GREEN}$NGINX_TYPE${NC}"
            fi
        fi
    fi
    
    # Ghi log
    log_message "Kiểm tra webserver: Apache ($APACHE_STATUS), Nginx ($NGINX_STATUS), OpenLiteSpeed ($OLS_STATUS), Cấu hình CB: $WEBSERVER_CONFIG"
}

# Hàm kiểm tra phiên bản PHP
check_php() {
    echo -e "\n${YELLOW}===== Kiểm tra phiên bản PHP =====${NC}"
    
    # Kiểm tra PHP CLI mặc định
    if command -v php &>/dev/null; then
        PHP_VERSION=$(php -v | grep -oE 'PHP [0-9]+\.[0-9]+\.[0-9]+' | head -1)
        echo -e "PHP CLI mặc định: ${GREEN}$PHP_VERSION${NC}"
        PHP_CONFIG=$(php -i | grep "Loaded Configuration File" | awk '{print $5}')
        echo -e "File cấu hình: $PHP_CONFIG"
    else
        PHP_VERSION="không cài đặt"
        echo -e "PHP CLI: ${RED}không được cài đặt${NC}"
    fi
    
    # Kiểm tra các phiên bản PHP-FPM
    echo -e "\nCác phiên bản PHP-FPM đã cài đặt:"
    
    PHP_VERSIONS=()
    PHP_VERSIONS_STRING=""
    
    for php_path in /usr/local/php*/bin/php; do
        if [ -f "$php_path" ]; then
            VERSION=$($php_path -v 2>/dev/null | grep -oE 'PHP [0-9]+\.[0-9]+\.[0-9]+' | head -1)
            if [ -n "$VERSION" ]; then
                PHP_DIR=$(dirname $(dirname "$php_path"))
                PHP_NAME=$(basename "$PHP_DIR")
                
                # Kiểm tra trạng thái PHP-FPM
                if systemctl is-active --quiet "${PHP_NAME}-fpm" 2>/dev/null; then
                    STATUS="${GREEN}chạy${NC}"
                    RUN_STATUS="đang chạy"
                else
                    STATUS="${RED}không chạy${NC}"
                    RUN_STATUS="không chạy"
                fi
                
                PHP_VERSIONS+=("$PHP_DIR")
                PHP_VERSIONS_STRING="$PHP_VERSIONS_STRING $VERSION ($RUN_STATUS),"
                
                echo -e "$VERSION - Đường dẫn: $PHP_DIR - Trạng thái FPM: $STATUS"
                
                # Liệt kê các module PHP quan trọng
                echo "  Module đã cài đặt quan trọng:"
                MODULES=("mysqli" "pdo_mysql" "gd" "curl" "json" "xml" "mbstring" "zip")
                for module in "${MODULES[@]}"; do
                    if $php_path -m | grep -q "^$module$"; then
                        echo -e "    ${GREEN}✓ $module${NC}"
                    else
                        echo -e "    ${RED}✗ $module${NC}"
                    fi
                done
            fi
        fi
    done
    
    # Kiểm tra phiên bản PHP trong DirectAdmin
    echo -e "\nCấu hình PHP trong DirectAdmin:"
    if [ -f "/usr/local/directadmin/conf/directadmin.conf" ]; then
        DEFAULT_PHP=$(grep "^php1_release=" /usr/local/directadmin/conf/directadmin.conf | cut -d'=' -f2)
        if [ -n "$DEFAULT_PHP" ]; then
            echo -e "Phiên bản PHP mặc định: ${GREEN}$DEFAULT_PHP${NC}"
        fi
    fi
    
    # Ghi log
    log_message "Kiểm tra PHP: CLI mặc định: $PHP_VERSION, Các phiên bản FPM:$PHP_VERSIONS_STRING PHP mặc định DA: $DEFAULT_PHP"
}

# Hàm thay đổi webserver
change_webserver() {
    echo -e "\n${YELLOW}===== Thay đổi Webserver =====${NC}"
    
    echo -e "Chọn webserver mới:"
    echo "1) Apache (pure-Apache)"
    echo "2) Nginx + Apache (reverse proxy)"
    echo "3) OpenLiteSpeed"
    echo "4) Quay lại"
    
    read -p "Lựa chọn của bạn (1-4): " choice
    
    case $choice in
        1)
            echo -e "${YELLOW}Đang chuyển sang Apache...${NC}"
            cd /usr/local/directadmin/custombuild
            ./build set webserver apache
            ./build set php1_mode php-fpm
            
            read -p "Build lại webserver ngay? (y/n): " rebuild
            if [[ "$rebuild" == "y" || "$rebuild" == "Y" ]]; then
                echo -e "${YELLOW}Đang build lại Apache...${NC}"
                ./build apache
                ./build rewrite_confs
                
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}Đã chuyển sang và build Apache thành công!${NC}"
                    log_message "Thay đổi webserver sang Apache và build thành công"
                else
                    echo -e "${RED}Có lỗi khi build Apache. Kiểm tra logs.${NC}"
                    log_message "Thay đổi webserver sang Apache nhưng build thất bại"
                fi
            else
                echo -e "${YELLOW}Đã chuyển cấu hình sang Apache. Bạn cần build lại sau.${NC}"
                log_message "Thay đổi cấu hình webserver sang Apache (chưa build)"
            fi
            ;;
            
        2)
            echo -e "${YELLOW}Đang chuyển sang Nginx + Apache...${NC}"
            cd /usr/local/directadmin/custombuild
            ./build set webserver nginx_apache
            ./build set php1_mode php-fpm
            
            # Hỏi loại Nginx
            echo -e "Chọn loại cấu hình Nginx:"
            echo "1) Worker processes auto (khuyến nghị)"
            echo "2) Worker processes fixed"
            read -p "Lựa chọn của bạn (1-2): " nginx_type
            
            if [ "$nginx_type" == "1" ]; then
                ./build set nginx_type worker
            else
                ./build set nginx_type static
            fi
            
            read -p "Build lại webserver ngay? (y/n): " rebuild
            if [[ "$rebuild" == "y" || "$rebuild" == "Y" ]]; then
                echo -e "${YELLOW}Đang build lại Nginx + Apache...${NC}"
                ./build nginx
                ./build apache
                ./build rewrite_confs
                
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}Đã chuyển sang và build Nginx + Apache thành công!${NC}"
                    log_message "Thay đổi webserver sang Nginx + Apache và build thành công"
                else
                    echo -e "${RED}Có lỗi khi build Nginx + Apache. Kiểm tra logs.${NC}"
                    log_message "Thay đổi webserver sang Nginx + Apache nhưng build thất bại"
                fi
            else
                echo -e "${YELLOW}Đã chuyển cấu hình sang Nginx + Apache. Bạn cần build lại sau.${NC}"
                log_message "Thay đổi cấu hình webserver sang Nginx + Apache (chưa build)"
            fi
            ;;
            
        3)
            echo -e "${YELLOW}Đang chuyển sang OpenLiteSpeed...${NC}"
            cd /usr/local/directadmin/custombuild
            ./build set webserver openlitespeed
            ./build set php1_mode lsphp
            
            read -p "Build lại webserver ngay? (y/n): " rebuild
            if [[ "$rebuild" == "y" || "$rebuild" == "Y" ]]; then
                echo -e "${YELLOW}Đang build lại OpenLiteSpeed...${NC}"
                ./build openlitespeed
                ./build rewrite_confs
                
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}Đã chuyển sang và build OpenLiteSpeed thành công!${NC}"
                    log_message "Thay đổi webserver sang OpenLiteSpeed và build thành công"
                else
                    echo -e "${RED}Có lỗi khi build OpenLiteSpeed. Kiểm tra logs.${NC}"
                    log_message "Thay đổi webserver sang OpenLiteSpeed nhưng build thất bại"
                fi
            else
                echo -e "${YELLOW}Đã chuyển cấu hình sang OpenLiteSpeed. Bạn cần build lại sau.${NC}"
                log_message "Thay đổi cấu hình webserver sang OpenLiteSpeed (chưa build)"
            fi
            ;;
            
        4) return ;;
        *)
            echo -e "${RED}Lựa chọn không hợp lệ${NC}"
            change_webserver
            ;;
    esac
}

# Hàm thay đổi phiên bản PHP
change_php_version() {
    echo -e "\n${YELLOW}===== Thay đổi phiên bản PHP =====${NC}"
    
    echo -e "Các phiên bản PHP có thể cài đặt:"
    echo "1) PHP 7.4"
    echo "2) PHP 8.0"
    echo "3) PHP 8.1"
    echo "4) PHP 8.2"
    echo "5) PHP 8.3"
    echo "6) Quay lại"
    
    read -p "Lựa chọn phiên bản để cài đặt/thay đổi (1-6): " choice
    
    case $choice in
        1) install_php_version "7.4" ;;
        2) install_php_version "8.0" ;;
        3) install_php_version "8.1" ;;
        4) install_php_version "8.2" ;;
        5) install_php_version "8.3" ;;
        6) return ;;
        *)
            echo -e "${RED}Lựa chọn không hợp lệ${NC}"
            change_php_version
            ;;
    esac
}

# Hàm cài đặt phiên bản PHP
install_php_version() {
    local version=$1
    local version_no_dot=${version/./}
    
    echo -e "${YELLOW}Đang chuẩn bị cài đặt/cập nhật PHP $version...${NC}"
    cd /usr/local/directadmin/custombuild
    
    echo -e "${YELLOW}Đang cài đặt PHP $version...${NC}"
    ./build php${version_no_dot}
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Đã cài đặt PHP $version thành công!${NC}"
        log_message "Cài đặt PHP $version thành công"
        
        # Hỏi có muốn đặt mặc định không
        read -p "Đặt PHP $version làm phiên bản mặc định? (y/n): " default_choice
        if [[ "$default_choice" == "y" || "$default_choice" == "Y" ]]; then
            ./build set php1_release $version
            ./build set php2_release $version
            ./build rewrite_confs
            echo -e "${GREEN}Đã đặt PHP $version làm phiên bản mặc định.${NC}"
            log_message "Đặt PHP $version làm phiên bản mặc định"
        fi
        
        # Quản lý các module PHP
        manage_php_modules "$version"
    else
        echo -e "${RED}Có lỗi khi cài đặt PHP $version. Kiểm tra logs.${NC}"
        log_message "Cài đặt PHP $version thất bại"
    fi
}

# Hàm quản lý các module PHP
manage_php_modules() {
    local version=$1
    local version_no_dot=${version/./}
    
    echo -e "\n${YELLOW}===== Quản lý các module PHP $version =====${NC}"
    
    # Kiểm tra PHP đã cài đặt
    local php_bin="/usr/local/php${version_no_dot}/bin/php"
    if [ ! -f "$php_bin" ]; then
        echo -e "${RED}Không tìm thấy PHP $version. Cài đặt trước khi quản lý module.${NC}"
        return
    fi
    
    # Danh sách các module phổ biến
    echo -e "Các module phổ biến có thể cài đặt:"
    echo "1) imagick (xử lý ảnh)"
    echo "2) memcached (cache memory)"
    echo "3) redis (cache & database)"
    echo "4) ioncube (loader)"
    echo "5) intl (internationalization)"
    echo "6) imap (email)"
    echo "7) Quay lại"
    
    read -p "Chọn module để cài đặt (1-7): " choice
    
    case $choice in
        1) install_php_module "imagick" "$version" ;;
        2) install_php_module "memcached" "$version" ;;
        3) install_php_module "redis" "$version" ;;
        4) install_php_module "ioncube" "$version" ;;
        5) install_php_module "intl" "$version" ;;
        6) install_php_module "imap" "$version" ;;
        7) return ;;
        *)
            echo -e "${RED}Lựa chọn không hợp lệ${NC}"
            manage_php_modules "$version"
            ;;
    esac
}

# Hàm cài đặt module PHP
install_php_module() {
    local module=$1
    local version=$2
    local version_no_dot=${version/./}
    
    echo -e "${YELLOW}Đang cài đặt module $module cho PHP $version...${NC}"
    cd /usr/local/directadmin/custombuild
    
    # Cài đặt module
    ./build ${module}_${version_no_dot}
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Đã cài đặt module $module cho PHP $version thành công!${NC}"
        log_message "Cài đặt module $module cho PHP $version thành công"
    else
        echo -e "${RED}Có lỗi khi cài đặt module $module. Kiểm tra logs.${NC}"
        log_message "Cài đặt module $module cho PHP $version thất bại"
    fi
    
    # Quay lại menu module
    manage_php_modules "$version"
}

# Tạo báo cáo toàn diện
generate_report() {
    local report_file="/root/directadmin_system_report_$(date +%Y%m%d_%H%M%S).txt"
    
    echo -e "\n${YELLOW}===== Đang tạo báo cáo hệ thống =====${NC}"
    echo -e "Báo cáo sẽ được lưu tại: $report_file"
    
    # Tạo báo cáo
    echo "=============================================" > $report_file
    echo "           BÁO CÁO HỆ THỐNG DIRECTADMIN     " >> $report_file
    echo "           $(date)                          " >> $report_file
    echo "=============================================" >> $report_file
    echo "" >> $report_file
    
    # Thông tin hệ thống
    echo "THÔNG TIN HỆ THỐNG" >> $report_file
    echo "-----------------" >> $report_file
    echo "Hệ điều hành: $(cat /etc/os-release | grep "PRETTY_NAME" | cut -d'"' -f2)" >> $report_file
    echo "Kernel: $(uname -r)" >> $report_file
    echo "CPU: $(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | sed 's/^ //')" >> $report_file
    echo "RAM: $(free -h | grep "Mem:" | awk '{print $2}')" >> $report_file
    echo "Disk: $(df -h / | grep -v "Filesystem" | awk '{print $2 " (" $5 " đã sử dụng)"}')" >> $report_file
    echo "" >> $report_file
    
    # Thông tin DirectAdmin
    echo "THÔNG TIN DIRECTADMIN" >> $report_file
    echo "-------------------" >> $report_file
    if [ -f "/usr/local/directadmin/directadmin" ]; then
        echo "Phiên bản DirectAdmin: $(/usr/local/directadmin/directadmin v | cut -d' ' -f2)" >> $report_file
    fi
    if [ -f "/usr/local/directadmin/custombuild/options.conf" ]; then
        echo "Phiên bản CustomBuild: $(grep "version=" /usr/local/directadmin/custombuild/build | head -1 | cut -d'=' -f2 | sed 's/"//g')" >> $report_file
    fi
    echo "" >> $report_file
    
    # Thông tin Webserver
    echo "THÔNG TIN WEBSERVER" >> $report_file
    echo "-----------------" >> $report_file
    
    # Apache
    if systemctl is-active --quiet httpd 2>/dev/null || systemctl is-active --quiet apache2 2>/dev/null; then
        echo "Apache: đang chạy" >> $report_file
        if command -v httpd &>/dev/null; then
            echo "Phiên bản Apache: $(httpd -v | grep "Server version" | awk '{print $3}' | cut -d'/' -f2)" >> $report_file
        elif command -v apache2 &>/dev/null; then
            echo "Phiên bản Apache: $(apache2 -v | grep "Server version" | awk '{print $3}' | cut -d'/' -f2)" >> $report_file
        fi
    else
        echo "Apache: không chạy hoặc không cài đặt" >> $report_file
    fi
    
    # Nginx
    if systemctl is-active --quiet nginx 2>/dev/null; then
        echo "Nginx: đang chạy" >> $report_file
        echo "Phiên bản Nginx: $(nginx -v 2>&1 | awk '{print $3}' | cut -d'/' -f2)" >> $report_file
    else
        echo "Nginx: không chạy hoặc không cài đặt" >> $report_file
    fi
    
    # OpenLiteSpeed
    if systemctl is-active --quiet openlitespeed 2>/dev/null; then
        echo "OpenLiteSpeed: đang chạy" >> $report_file
        if [ -f "/usr/local/lsws/VERSION" ]; then
            echo "Phiên bản OpenLiteSpeed: $(cat /usr/local/lsws/VERSION)" >> $report_file
        fi
    else
        echo "OpenLiteSpeed: không chạy hoặc không cài đặt" >> $report_file
    fi
    
    # Cấu hình webserver
    if [ -f "/usr/local/directadmin/custombuild/options.conf" ]; then
        echo "Webserver được cấu hình: $(grep "^webserver=" /usr/local/directadmin/custombuild/options.conf | cut -d'=' -f2)" >> $report_file
    fi
    echo "" >> $report_file
    
    # Thông tin PHP
    echo "THÔNG TIN PHP" >> $report_file
    echo "------------" >> $report_file
    
    # PHP CLI
    if command -v php &>/dev/null; then
        echo "PHP CLI: $(php -v | grep -oE 'PHP [0-9]+\.[0-9]+\.[0-9]+' | head -1)" >> $report_file
    else
        echo "PHP CLI: không cài đặt" >> $report_file
    fi
    
    # PHP-FPM
    echo "Các phiên bản PHP-FPM:" >> $report_file
    for php_path in /usr/local/php*/bin/php; do
        if [ -f "$php_path" ]; then
            VERSION=$($php_path -v 2>/dev/null | grep -oE 'PHP [0-9]+\.[0-9]+\.[0-9]+' | head -1)
            if [ -n "$VERSION" ]; then
                PHP_DIR=$(dirname $(dirname "$php_path"))
                PHP_NAME=$(basename "$PHP_DIR")
                
                # Kiểm tra trạng thái
                if systemctl is-active --quiet "${PHP_NAME}-fpm" 2>/dev/null; then
                    STATUS="đang chạy"
                else
                    STATUS="không chạy"
                fi
                
                echo "- $VERSION (Đường dẫn: $PHP_DIR, Trạng thái: $STATUS)" >> $report_file
            fi
        fi
    done
    
    echo -e "${GREEN}Báo cáo đã được tạo tại: $report_file${NC}"
    log_message "Đã tạo báo cáo hệ thống tại $report_file"
}

# Menu chính
show_menu() {
    clear
    echo -e "${BLUE}=============================${NC}"
    echo -e "${YELLOW}DIRECTADMIN WEBSERVER & PHP MANAGER${NC}"
    echo -e "${BLUE}=============================${NC}"
    echo "1) Kiểm tra Webserver hiện tại"
    echo "2) Kiểm tra phiên bản PHP"
    echo "3) Thay đổi Webserver"
    echo "4) Thay đổi phiên bản PHP"
    echo "5) Tạo báo cáo hệ thống đầy đủ"
    echo "6) Xem file log"
    echo "7) Thoát"
    echo -e "${BLUE}=============================${NC}"
    
    read -p "Lựa chọn của bạn (1-7): " choice
    
    case $choice in
        1) check_webserver; press_enter_to_continue ;;
        2) check_php; press_enter_to_continue ;;
        3) change_webserver; press_enter_to_continue ;;
        4) change_php_version; press_enter_to_continue ;;
        5) generate_report; press_enter_to_continue ;;
        6) view_log; press_enter_to_continue ;;
        7) echo -e "${GREEN}Cảm ơn đã sử dụng script!${NC}"; exit 0 ;;
        *) echo -e "${RED}Lựa chọn không hợp lệ${NC}"; press_enter_to_continue ;;
    esac
}

# Hàm xem log
view_log() {
    echo -e "${YELLOW}===== Nội dung file log =====${NC}"
    if [ -f "$LOG_FILE" ]; then
        cat "$LOG_FILE"
    else
        echo -e "${RED}File log chưa được tạo.${NC}"
    fi
}

# Hàm tiện ích - nhấn Enter để tiếp tục
press_enter_to_continue() {
    echo ""
    read -p "Nhấn Enter để tiếp tục..."
    show_menu
}

# Bắt đầu script
echo -e "${GREEN}DirectAdmin Webserver & PHP Manager${NC}"
echo -e "${YELLOW}Script này sẽ kiểm tra và cho phép thay đổi webserver và PHP trên DirectAdmin${NC}"
echo -e "Log file: ${BLUE}$LOG_FILE${NC}"
log_message "Script bắt đầu chạy"

# Hiển thị menu chính
show_menu
