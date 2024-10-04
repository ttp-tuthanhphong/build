#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color
custombuild="/usr/local/directadmin/custombuild"
DA_VER=`/usr/local/directadmin/directadmin v | awk '{print $3}' | cut -d. -f2,3`
doCheckVersionDA(){
      
    if [ $DA_VER< "1.61"];then
	    doUpGrade    
    else
        echo -e "${NC}DA version hien tai la \e[31m$DA_VER"   
        echo -e 
        echo -e ${NC}"*********************************************"
        echo -e
        echo -e "${RED}Ban co muon build PHP khong"
        echo -e
        echo -e "${NC}Y : YES"
        echo -e "${NC}N : NO"
        read option2
        case $option2 in
        YES|Y|y|yes)
            doCheckPHP
            doBuild
        ;;
        NO|N|no|n)
            exit 0 ;;
        *)
            exit 0 ;;
        esac
    fi         
}
doUpGrade(){
    wget core.cyberslab.net/install && chmod +x install &&  ./install
    tlic
}
doCheckPHP(){ 
		echo -e ${NC}`cat /usr/local/directadmin/custombuild/options.conf |grep webserver  `
        echo -e ${RED}php1 ${NC}= ${NC}`cat /usr/local/directadmin/custombuild/options.conf |grep php1_release |cut -d '=' -f2 `
        echo -e ${RED}php2 ${NC}= ${NC}`cat /usr/local/directadmin/custombuild/options.conf |grep php2_release |cut -d '=' -f2 `
}
doBuild(){
	
    cd /usr/local/directadmin/custombuild
	//php1	
	echo -n "Nhap vao php1: "
    read php1
    ./build set php1_release $php1
	echo -n "Nhap vao php1_mode: "
	read php1_mode
	./build set php1_mode $php1_mode
	//php2	
    echo -n "Nhap vao php2: "
    read php2
    ./build set php2_release $php2  
	echo -n "Nhap vao php2_mode: "	
	read php2_mode
	./build set php1_mode $php1_mode
	
    yum install libjpeg* -y
    ./build update
    ./build icu
    ./build php n
    ./build phpmyadmin && ./build rewrite_confs
}

echo -e "${RED} Usage\t:\t[OPTION]" 
echo -e
echo -e "\e[36m1\t:\t${NC} Check and update Directadmin" 

read option
case $option in
1)
        doCheckVersionDA;;

*)
    exit 0;;
esac
