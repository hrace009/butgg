#!/bin/bash

# Setup variables
GITHUB_LINK="https://raw.githubusercontent.com/mbrother2/butgg/master"
BUTGG_CONF="${HOME}/.butgg/butgg.conf"
DF_BACKUP_DIR="${HOME}/backup"
DF_LOG_FILE="${HOME}/.butgg/butgg.log"
DF_DAY_REMOVE="7"
DF_GDRIVE_ID="None"
DF_EMAIL_USER="None"
DF_EMAIL_PASS="None"
DF_EMAIL_TO="None"
GDRIVE_BASH="${HOME}/bin/gdrive.bash"
GDRIVE_TOKEN="${HOME}/.butgg/token.json"
CRON_BACKUP="${HOME}/bin/cron_backup.bash"
SETUP_FILE="${HOME}/bin/butgg.bash"
CRON_TEMP="${HOME}/.butgg/old_cron"
FIRST_OPTION=$1
SECOND_OPTION=$2

# Date variables
TODAY=`date +"%d_%m_%Y"`

# Color variables
GREEN='\e[32m'
RED='\e[31m'
YELLOW='\e[33m'
REMOVE='\e[0m'

# Change color of words
change_color(){
    case $1 in
         green) echo -e "${GREEN}$2${REMOVE}";;
           red) echo -e "${RED}$2${REMOVE}";;
        yellow) echo -e "${YELLOW}$2${REMOVE}";;
             *) echo "$2";;
    esac
}

# Check MD5 of downloaded file
check_md5sum(){
    curl -o $2 ${GITHUB_LINK}/$1
    ORIGIN_MD5=`curl -s ${GITHUB_LINK}/MD5SUM | grep $1 | awk '{print $1}'`
    LOCAL_MD5=`md5sum $2 | awk '{print $1}'`
    if [ "${ORIGIN_MD5}" == "${LOCAL_MD5}" ]
    then
        show_write_log "Check md5sum for file $1 successful"
    else
        show_write_log "`change_color red [CHECK][FAIL]` Can not verify md5 for file $1. Exit!"
        exit 1
    fi
}

# Check log file
check_log_file(){    
    if [ ! -f ${BUTGG_CONF} ]
    then
        LOG_FILE=${DF_LOG_FILE}        
    else
        LOG_FILE=`cat ${BUTGG_CONF} | grep "^LOG_FILE" | cut -d"=" -f2 | sed 's/"//g' | sed "s/'//g"`
        if [ "${LOG_FILE}" == "" ]
        then
            LOG_FILE=${DF_LOG_FILE}
        fi
    fi
    create_dir .butgg
    create_dir bin
}

# Write log
show_write_log(){
    echo "`date "+[ %d/%m/%Y %H:%M:%S ]"` $1" | tee -a ${LOG_FILE}
}

# Create necessary directory
create_dir(){
    if [ ! -d ${HOME}/$1 ]
    then
        mkdir -p ${HOME}/$1
        if [ ! -d ${HOME}/$1 ]
        then
            echo "Can not create directory ${HOME}/$1. Exit"
            exit 1
        else
            if [ "$1" == ".butgg" ]
            then
                show_write_log "---"
                show_write_log "Creating necessary directory..."
            fi
            show_write_log "Create directory ${HOME}/$1 successful"
        fi
    else
        if [ "$1" == ".butgg" ]
        then
            show_write_log "---"
            show_write_log "Creating necessary directory..."
        fi
        show_write_log "Directory ${HOME}/$1 existed. Skip"
    fi
    echo 1 >> ${HOME}/$1/test.txt
    if [ $? -ne 0 ]
    then
        echo "Can not write to ${HOME}/$1. Exit"
        exit 1
    else
        show_write_log "Check write to ${HOME}/$1 successful"
    fi
    rm -f ${HOME}/$1/test.txt
}

check_package(){
    which $1 >/dev/null
    if [ $? -ne 0 ]
    then
        show_write_log "Command $1 not found. Trying to install $1..."
        sleep 3
        ${INSTALL_CM} install -y $1
        which $1 >/dev/null
        if [ $? -ne 0 ]
        then
            show_write_log "Can not install $1 package. Please install $1 manually."
            exit 1
        fi
    fi
    show_write_log "Package $1 is installed"
}

# Write config
write_config(){
    if [ "$3" == "" ]
    then
        VAR=$1
        eval "$VAR"="$2"
        if [ -f ${BUTGG_CONF} ]
        then
            sed -i "/^$1/d" ${BUTGG_CONF}
        fi
        echo "$1=$2" >> ${BUTGG_CONF}
    else
        VAR=$1
        eval "$VAR"="$3"
        if [ -f ${BUTGG_CONF} ]
        then
            sed -i "/^$1/d" ${BUTGG_CONF}
        fi
        echo "$1=$3" >> ${BUTGG_CONF}
    fi
}

# Detect OS
detect_os(){
    show_write_log "Checking OS..."
    if [ -f /etc/os-release ]
    then
        OS=`cat /etc/os-release | grep "^NAME=" | cut -d'"' -f2 | awk '{print $1}'`
        if [ "${OS}" == "CentOS" ]
        then
            INSTALL_CM="yum"
        elif [[ "${OS}" == "Ubuntu" ]] || [[ "${OS}" == "Debian" ]]
        then
            INSTALL_CM="apt"
        elif [[ "${OS}" == "openSUSE" ]] || [[ "${OS}" == "SLES" ]]
        then
            INSTALL_CM="zypper"
        else
            show_write_log "Sorry! We do not support your OS. Exit"
            exit 1
        fi
    else
        show_write_log "Sorry! We do not support your OS. Exit"
        exit 1
    fi
    show_write_log "OS supported"
    show_write_log "Checking necessary package..."
    check_package curl
}

# Check network
check_network(){
    show_write_log "Cheking network..."
    curl -sI raw.githubusercontent.com >/dev/null
    if [ $? -eq 0 ]
    then
        show_write_log "Connect Github successful"
    else
        show_write_log "`change_color red [CHECK][FAIL]` Can not connect to Github file, please check your network. Exit"
        exit 1
    fi
}

# Download file from Github
download_file(){
    show_write_log "Downloading gdrive script from github..."
    check_md5sum gdrive.bash "${GDRIVE_BASH}"
    show_write_log "Downloading script cron file from github..."
    check_md5sum cron_backup.bash "${CRON_BACKUP}"
    show_write_log "Downloading setup file from github..."
    check_md5sum butgg.bash "${SETUP_FILE}"
    chmod 755 ${CRON_BACKUP} ${SETUP_FILE} ${GDRIVE_BASH}
}


# Setup gdrive credential
setup_credential(){
    show_write_log "Setting up gdrive credential..."
    echo ""
    if [ "${SECOND_OPTION}" == "credential" ]
    then
        if [ -f ${GDRIVE_TOKEN} ]
        then
            rm -f ${GDRIVE_TOKEN}
        fi
    fi
    ${GDRIVE_BASH} --about
    if [ $? -ne 0 ]
    then
        show_write_log "`change_color yellow [WARNING]` Can not create gdrive credential. Please run \"${GDRIVE_BASH} --about\" to create it after"
        sleep 3
    else
        show_write_log "Setup gdrive credential successful"
    fi
}

# Set up config file
setup_config(){
    show_write_log "Setting up config file..."
    echo ""
    read -p " Which directory on your server do you want to upload to Google Drive?(default ${DF_BACKUP_DIR}): " BACKUP_DIR
    read -p " How many days do you want to keep backup on Google Drive?(default ${DF_DAY_REMOVE}): " DAY_REMOVE
    echo ""
    echo "Read more https://github.com/mbrother2/butgg/wiki/Get-Google-folder-ID"
    read -p " Your Google folder ID(default ${DF_GDRIVE_ID}): " GDRIVE_ID
    echo ""
    echo "Read more https://github.com/mbrother2/butgg/wiki/Turn-on-2-Step-Verification-&-create-app's-password-for-Google-email"
    read -p " Do you want to send email if upload error(default no)(y/n): " SEND_EMAIL
    if [ "${SEND_EMAIL}" == "y" ]
    then
        read -p " Your Google email user name: " EMAIL_USER
        read -p " Your Google email password: " EMAIL_PASS
        read -p " Which email will be receive notify?: " EMAIL_TO
    fi
    echo ""
    echo "LOG_FILE=${LOG_FILE}" >> ${BUTGG_CONF}
    write_config BACKUP_DIR "${DF_BACKUP_DIR}" "${BACKUP_DIR}"
    write_config DAY_REMOVE "${DF_DAY_REMOVE}" "${DAY_REMOVE}"
    write_config GDRIVE_ID  "${DF_GDRIVE_ID}"  "${GDRIVE_ID}"
    write_config EMAIL_USER "${DF_EMAIL_USER}" "${EMAIL_USER}"
    write_config EMAIL_PASS "${DF_EMAIL_PASS}" "${EMAIL_PASS}" 
    write_config EMAIL_TO   "${DF_EMAIL_TO}"   "${EMAIL_TO}"
    if [ $? -ne 0 ]
    then
        show_write_log "`change_color red [ERROR]` Can not write config to file ${BUTGG_CONF}. Please check permission of this file. Exit"
        exit 1
    else
        if [ ! -d ${BACKUP_DIR} ]
        then
            show_write_log "`change_color yellow [WARNING]` Directory ${BACKUP_DIR} does not exist! Ensure you will be create it after."
            sleep 3
        fi
        show_write_log "Setup config file successful"
    fi       
}

# Set up cron backup
setup_cron(){
    show_write_log "Setting up cron backup..."
    CHECK_BIN=`echo $PATH | grep -c "${HOME}/bin"`
    if [ ${CHECK_BIN} -eq 0 ]
    then
        echo "PATH=$PATH:$HOME/bin" >> ${HOME}/.profile
        echo "export PATH" >> ${HOME}/.profile
        source ${HOME}/.profile
    fi    
    crontab -l > ${CRON_TEMP}
    CHECK_CRON=`cat ${CRON_TEMP} | grep -c "cron_backup.bash"`
    if [ ${CHECK_CRON} -eq 0 ]
    then
        echo "PATH=$PATH" >> ${CRON_TEMP}
        echo "0 0 * * * bash ${CRON_BACKUP} >/dev/null 2>&1" >> ${CRON_TEMP}
        crontab ${CRON_TEMP}
        if [ $? -ne 0 ]
        then
            show_write_log "Can not setup cronjob to backup! Please check again"
            SHOW_CRON="`change_color yellow [WARNING]` Can not setup cronjob to backup"
        else
            show_write_log "Setup cronjob to backup successful"
            SHOW_CRON="0 0 * * * bash ${CRON_BACKUP} >/dev/null 2>&1"
        fi
    else
        show_write_log "Cron backup existed. Skip"
        SHOW_CRON=`cat ${CRON_TEMP} | grep "cron_backup.bash"`
    fi
    rm -f  ${CRON_TEMP}
}

# Show information
show_info(){
    echo ""
    if [ "${SECOND_OPTION}" == config ]
    then
        show_write_log "+-----"
        show_write_log "| SUCESSFUL! Your information:"
        show_write_log "| Backup dir      : ${BACKUP_DIR}"
        show_write_log "| Keep backup     : ${DAY_REMOVE} days"
        show_write_log "| Google folder ID: ${GDRIVE_ID}"
        show_write_log "| Your email      : ${EMAIL_USER}"
        show_write_log "| Email password  : ${EMAIL_PASS}"
        show_write_log "| Email notify    : ${EMAIL_TO}"
        show_write_log "| Config file     : ${BUTGG_CONF}"
        show_write_log "+-----"
    else
        show_write_log "+-----"
        show_write_log "| SUCESSFUL! Your information:"
        show_write_log "| Backup dir      : ${BACKUP_DIR}"
        show_write_log "| Config file     : ${BUTGG_CONF}"
        show_write_log "| Log file        : ${LOG_FILE}"
        show_write_log "| Keep backup     : ${DAY_REMOVE} days"
        show_write_log "| Google folder ID: ${GDRIVE_ID}"
        show_write_log "| Your email      : ${EMAIL_USER}"
        show_write_log "| Email password  : ${EMAIL_PASS}"
        show_write_log "| Email notify    : ${EMAIL_TO}"
        show_write_log "| butgg.bash file : ${SETUP_FILE}"
        show_write_log "| Cron backup file: ${CRON_BACKUP}"
        show_write_log "| gdrive.bash file: ${GDRIVE_BASH}"
        show_write_log "| Cron backup     : ${SHOW_CRON}"
        show_write_log "| Google token    : ${GDRIVE_TOKEN}"
        show_write_log "+-----"

        echo ""
        if [[ "${OS}" == "Ubuntu" ]] || [[ "${OS}" == "Debian" ]]
        then
            echo "IMPORTANT: Please run command to use butgg: source ${HOME}/.profile "
        fi
        echo "If you get trouble when use butgg.bash please report here:"
        echo "https://github.com/mbrother2/butgg/issues"
    fi
}

_setup(){
    check_log_file
    if [ -z "${SECOND_OPTION}" ]
    then
        detect_os
        check_network
        download_file
        setup_credential
        setup_config
        setup_cron
        show_info
    else
        case ${SECOND_OPTION} in
            config)
                setup_config
                show_info
                ;;
            credential)
                setup_credential
                ;;
            only-build)
                detect_os
                check_network
                ;;
            no-build)
                detect_os
                check_network
                download_file
                setup_credential
                setup_config
                setup_cron
                show_info
                ;;
            no-update)
                detect_os
                check_network
                setup_credential
                setup_config
                setup_cron
                show_info
                ;;
            *)
                show_write_log "`change_color yellow [WARNING]` Not support option ${FIRST_OPTION} ${SECOND_OPTION}"
                _help
                ;;
        esac
    fi
}

_update(){
    check_log_file
    detect_os
    check_network
    download_file
}

_uninstall(){
    check_log_file
    show_write_log "Removing all butgg.bash scripts..."
    rm -f ${GDRIVE_BASH} ${CRON_BACKUP} ${SETUP_FILE}
    if [ $? -ne 0 ]
    then
        show_write_log "Can not remove all butgg.bash scripts. Please check permission of these files"
    else
        show_write_log "Remove all butgg.bash scripts successful"
    fi
    read -p " Do you want remove ${HOME}/.butgg directory?(y/n) " REMOVE_GDRIVE_DIR
    if [[ "${REMOVE_GDRIVE_DIR}" == "y" ]] || [[ "${REMOVE_GDRIVE_DIR}" == "Y" ]]
    then
        rm -rf ${HOME}/.butgg
        if [ $? -ne 0 ]
        then
            show_write_log "Can not remove directory ${HOME}/.butgg. Please check permission of this directory"
        else
            echo "Remove directory ${HOME}/.butgg successful"
        fi
    else
        show_write_log "Skip remove ${HOME}/.butgg directory"
    fi
}

_help(){
    echo "butgg.bash - Backup to Google Drive solution"
    echo ""
    echo "Usage: butgg.bash [options] [command]"
    echo ""
    echo "Options:"
    echo "  --help       show this help message and exit"
    echo "  --setup      setup or reset all scripts & config file"
    echo "    config     only setup config"
    echo "    credential only setup credential"
    echo "    no-update  setup butgg without update script"
    echo "  --update     update to latest version"
    echo "  --uninstall  remove all butgg scripts and .butgg directory"
}

# Main functions
case ${FIRST_OPTION} in
    --help)      _help ;;
    --setup)     _setup ;;
    --update)    _update ;;
    --uninstall) _uninstall ;;
    *)           echo "Not support option ${FIRST_OPTION}"; _help ;;
esac
