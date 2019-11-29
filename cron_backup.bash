#!/bin/bash

# Setup variables
BUTGG_CONF="${HOME}/.butgg/butgg.conf"
BUTGG_DEBUG="${HOME}/.butgg/detail.log"
GDRIVE_BIN="${HOME}/bin/gdrive.bash"
DF_BACKUP_DIR="${HOME}/backup"
DF_LOG_FILE="${HOME}/.butgg/butgg.log"
DF_DAY_REMOVE="7"
DF_GDRIVE_ID="None"
DF_EMAIL_USER="None"
DF_EMAIL_PASS="None"
DF_EMAIL_TO="None"
FIRST_OPTION=$1

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

# Show processing and write log
show_write_log(){
    if [ "${FIRST_OPTION}" == "-v" ]
    then
        echo `date "+[ %d/%m/%Y %H:%M:%S ]"` $1
    fi
    echo `date "+[ %d/%m/%Y %H:%M:%S ]"` $1 >> ${LOG_FILE}
}

# Check file type
check_file_type(){
    if [ -d "$1" ]
    then
        FILE_TYPE="directory"
    elif [ -f "$1" ]
    then
        FILE_TYPE="file"
    else
        show_write_log "`change_color red [CHECK][FAIL]` Can not detect file type for $1. Exit"
        exit 1
    fi
}

# Detect OS
detect_os(){
    show_write_log "Checking OS..."
    if [ -f /etc/os-release ]
    then
        OS=`cat /etc/os-release | grep "^NAME=" | cut -d'"' -f2 | awk '{print $1}'`
        show_write_log "OS supported"
    else
        show_write_log "Sorry! We do not support your OS. Exit"
        exit 1
    fi
}

# Write config
check_config(){
    if [ "$3" == "" ]
    then
        VAR=$1
        eval "$VAR"="$2"
        if [ $1 == LOG_FILE ]
        then
            show_write_log "---"
        fi
        show_write_log "`change_color yellow [WARNING]` $1 does not exist. Use default config"
        if [ -f ${BUTGG_CONF} ]
        then
            sed -i "/^$1/d" ${BUTGG_CONF}
        fi
        echo "$1=$2" >> ${BUTGG_CONF}
    else
        VAR=$1
        eval "$VAR"="$3"
        if [ $1 == LOG_FILE ]
        then
            show_write_log "---"
        fi
    fi
}

# Get config
get_config(){
    if [ ! -f ${BUTGG_CONF} ]
    then
        check_config LOG_FILE ${DF_LOG_FILE}
        check_config BACKUP_DIR ${DF_BACKUP_DIR}
        check_config DAY_REMOVE ${DF_DAY_REMOVE}
        check_config GDRIVE_ID ${DF_GDRIVE_ID}
        check_config EMAIL_USER ${DF_EMAIL_USER}
        check_config EMAIL_PASS ${DF_EMAIL_PASS}
        check_config EMAIL_TO ${DF_EMAIL_TO}
    else
        LOG_FILE=`cat ${BUTGG_CONF} | grep "^LOG_FILE"   | cut -d"=" -f2 | sed 's/"//g' | sed "s/'//g"`
        check_config LOG_FILE ${DF_LOG_FILE} ${LOG_FILE}
        BACKUP_DIR=`cat ${BUTGG_CONF} | grep "^BACKUP_DIR" | cut -d"=" -f2 | sed 's/"//g' | sed "s/'//g"`
        check_config BACKUP_DIR ${DF_BACKUP_DIR} ${BACKUP_DIR}         
        DAY_REMOVE=`cat ${BUTGG_CONF} | grep "^DAY_REMOVE" | cut -d"=" -f2 | sed 's/"//g' | sed "s/'//g"`
        check_config DAY_REMOVE ${DF_DAY_REMOVE} ${DAY_REMOVE}
        GDRIVE_ID=`cat ${BUTGG_CONF} | grep "^GDRIVE_ID" | cut -d"=" -f2 | sed 's/"//g' | sed "s/'//g"`
        check_config GDRIVE_ID ${DF_GDRIVE_ID} ${GDRIVE_ID}
        EMAIL_USER=`cat ${BUTGG_CONF} | grep "^EMAIL_USER" | cut -d"=" -f2 | sed 's/"//g' | sed "s/'//g"`
        check_config EMAIL_USER ${DF_EMAIL_USER} ${EMAIL_USER}
        EMAIL_PASS=`cat ${BUTGG_CONF} | grep "^EMAIL_PASS" | cut -d"=" -f2 | sed 's/"//g' | sed "s/'//g"`
        check_config EMAIL_PASS ${DF_EMAIL_PASS} ${EMAIL_PASS}
        EMAIL_TO=`cat ${BUTGG_CONF} | grep "^EMAIL_TO" | cut -d"=" -f2 | sed 's/"//g' | sed "s/'//g"`
        check_config EMAIL_TO ${DF_EMAIL_TO} ${EMAIL_TO}
    fi
}

# Check infomations before upload to Google Drive
check_info(){
    if [ ! -d "${BACKUP_DIR}" ]
    then       
        show_write_log "`change_color red [CHECK][FAIL]` Directory ${BACKUP_DIR} does not exist. Exit"
        send_error_email "butgg [CHECK][FAIL]" "Directory ${BACKUP_DIR} does not exist"
        exit 1
    fi
    if [ ! -f ${HOME}/.butgg/token.json ]
    then
        show_write_log "`change_color red [CHECK][FAIL]` File ${HOME}/.butgg/token.json does not exist. Exit"
        show_write_log "Please run command: '${GDRIVE_BIN} --about' to create your Google token for gdrive"
        send_error_email "butgg [CHECK][FAIL]" "File ${HOME}/.butgg/token.json does not exist"
        exit 1
    else
        echo "\n" | ${GDRIVE_BIN} --list all root >/dev/null
        if [ $? -ne 0 ]
        then
            echo ""
            show_write_log "`change_color red [CHECK][FAIL]` File ${HOME}/.butgg/token.json exists but can not verify Google token for gdrive. Exit"
            show_write_log "Please run command: 'butgg.bash --setup credential' to recreate your Google token for gdrive"
            send_error_email "butgg [CHECK][FAIL]" "File ${HOME}/.butgg/token.json exists but can not verify Google token for gdrive"
            exit 1
        fi
    fi
}

# Send error email
send_error_email(){
    if [ "${EMAIL_USER}" == "None" ]
    then
        show_write_log "`change_color yellow [WARNING]` Email not config, do not send error email"
    else
        show_write_log "Sending error email..."
        curl -s --url "smtp://smtp.gmail.com:587" --ssl-reqd --mail-from "${EMAIL_USER}" --mail-rcpt "${EMAIL_TO}" --user "${EMAIL_USER}:${EMAIL_PASS}" -T <(echo -e "From: ${EMAIL_USER}\nTo: ${EMAIL_TO}\nSubject: $1\n\n $2")
        if [ $? -ne 0 ]
        then
            echo "" >> ${BUTGG_DEBUG}
            echo `date "+[ %d/%m/%Y %H:%M:%S ]"` "---" >> ${BUTGG_DEBUG}
            curl -v --url "smtp://smtp.gmail.com:587" --ssl-reqd --mail-from "${EMAIL_USER}" --mail-rcpt "${EMAIL_TO}" --user "${EMAIL_USER}:${EMAIL_PASS}" -T <(echo -e "From: ${EMAIL_USER}\nTo: ${EMAIL_TO}\nSubject: $1\n\n $2") --stderr ${BUTGG_DEBUG}_${TODAY}
            cat ${BUTGG_DEBUG}_${TODAY} >> ${BUTGG_DEBUG}
            rm -f ${BUTGG_DEBUG}_${TODAY}
            show_write_log "`change_color red [EMAIL][FAIL]` Can not send error email. See ${BUTGG_DEBUG} for more detail"            
        else
            show_write_log "Send error email successful"
        fi
    fi
}

# Run upload to Google Drive
run_upload(){
    show_write_log "Start upload to Google Drive..."
    if [ "${GDRIVE_ID}" == "None" ]
    then
        CHECK_BACKUP_DIR=`${GDRIVE_BIN} --list dir root | grep -c "${TODAY}"`
    else
        show_write_log "Checking Google folder ID..."
        CHECK_GDRIVE_ID=`${GDRIVE_BIN} --info trashed "${GDRIVE_ID}"`
        if [ $? -ne 0 ]
        then
            show_write_log "`change_color yellow [CHECK][FAIL]` Can not find Google folder ID ${GDRIVE_ID} . Exit"
            send_error_email "butgg [CHECK][FAIL]" "Can not find Google folder ID ${GDRIVE_ID}"
            exit 1
        elif [ "${CHECK_GDRIVE_ID}" == "true" ]
        then
            show_write_log "`change_color yellow [CHECK][FAIL]` Folder ID ${GDRIVE_ID} has been deleted to trash. Exit"
            send_error_email "butgg [CHECK][FAIL]" "Folder ID ${GDRIVE_ID} has been deleted to trash"
            exit 1
        else
            show_write_log "Check Google folder ID successful"
        fi
        CHECK_BACKUP_DIR=`${GDRIVE_BIN} --list dir "${GDRIVE_ID}" | grep -c "${TODAY}"`
    fi   
    if [ ${CHECK_BACKUP_DIR} -eq 0 ]
    then
        show_write_log "Directory ${TODAY} does not exist. Creating..."
        if [ "${GDRIVE_ID}" == "None" ]
        then
            ID_DIR=`${GDRIVE_BIN} --mkdir ${TODAY}`
        else
            ID_DIR=`${GDRIVE_BIN} --mkdir ${TODAY} ${GDRIVE_ID}`
        fi
    else
        show_write_log "Directory ${TODAY} existed. Skipping..."
        if [ "${GDRIVE_ID}" == "None" ]
        then
            ID_DIR=`${GDRIVE_BIN} --list dir root | grep "${TODAY}"| awk '{print $1}'`
        else
            ID_DIR=`${GDRIVE_BIN} --list dir ${GDRIVE_ID} | grep "${TODAY}" | awk '{print $1}'`
        fi
    fi
    if [ ${#ID_DIR} -ne 33 ]
    then
        show_write_log "`change_color red [CREATE][FAIL]` Can not create directory ${TODAY}"
        send_error_email "butgg [CREATE][FAIL]" "Can not create directory ${TODAY}"
        exit 1
    elif [ ${CHECK_BACKUP_DIR} -eq 0 ]
    then
        show_write_log "`change_color green [CREATE]` Created directory ${TODAY} with ID ${ID_DIR}"
    else
        :
    fi
    BACKUP_DIR=`realpath ${BACKUP_DIR}`
    cd ${BACKUP_DIR}
    IFS=$'\n'
    for i in $(ls -1 "${BACKUP_DIR}")
    do
        check_file_type "${BACKUP_DIR}/$i"            
        show_write_log "Uploading ${FILE_TYPE} ${BACKUP_DIR}/$i to directory ${TODAY}..."                
        UPLOAD_FILE=`${GDRIVE_BIN} --upload "$i" "${ID_DIR}"`
        if [[ "${UPLOAD_FILE}" == *"Error"* ]] || [[ "${UPLOAD_FILE}" == *"Fail"* ]]
        then
            show_write_log "`change_color red [UPLOAD][FAIL]` Can not upload backup file! ${UPLOAD_FILE}. Exit"
            send_error_email "butgg [UPLOAD][FAIL]" "Can not upload backup file! ${UPLOAD_FILE}"
            exit
        else
            show_write_log "`change_color green [UPLOAD]` Uploaded ${FILE_TYPE} ${BACKUP_DIR}/$i to directory ${TODAY}"
        fi
    done
    show_write_log "Finish! All files and directories in ${BACKUP_DIR} are uploaded to Google Drive in directory ${TODAY}"
}

remove_old_dir(){
    OLD_BACKUP_DAY=`date +%d_%m_%Y -d "-${DAY_REMOVE} day"`
    if [ "${GDRIVE_ID}" == "None" ]
    then
        OLD_BACKUP_ID=`${GDRIVE_BIN} --list dir root | grep "${OLD_BACKUP_DAY}" | awk '{print $1}'`
    else
        OLD_BACKUP_ID=`${GDRIVE_BIN} --list dir ${GDRIVE_ID} | grep "${OLD_BACKUP_DAY}" | awk '{print $1}'`
    fi
    if [ "${OLD_BACKUP_ID}" != "" ]
    then
        ${GDRIVE_BIN} --delete ${OLD_BACKUP_ID} >/dev/null
        if [ "${GDRIVE_ID}" == "None" ]
        then
            OLD_BACKUP_ID=`${GDRIVE_BIN} --list dir root | grep "${OLD_BACKUP_DAY}" | awk '{print $1}'`
        else
            OLD_BACKUP_ID=`${GDRIVE_BIN} --list dir ${GDRIVE_ID} | grep "${OLD_BACKUP_DAY}" | awk '{print $1}'`
        fi
        if [ "${OLD_BACKUP_ID}" == "" ]
        then
            show_write_log "`change_color green [REMOVE]` Removed directory ${OLD_BACKUP_DAY}"
        else
            show_write_log "`change_color red [REMOVE][FAIL]` Directory ${OLD_BACKUP_DAY} exists but can not remove!"
            send_error_email "butgg [REMOVE][FAIL]" "Directory ${OLD_BACKUP_DAY} exists but can not remove!"
        fi
    else
        show_write_log "Directory ${OLD_BACKUP_DAY} does not exist. Nothing need remove!"
    fi
}

# Main functions
get_config
detect_os
check_info
run_upload
remove_old_dir