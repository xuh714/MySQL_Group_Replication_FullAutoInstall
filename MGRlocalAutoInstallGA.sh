#!/bin/bash
# 2020-09-16 MySQL group replication AutoInstall Script version 1.0 (Author : xuh)
# 2019-09-17 version 1.1
#       add: precheck and rollback functions by xuh
# 2019-09-21 version 1.2
#       add: options files config functions by xuh
. $HOME/.bash_profile >/dev/null 2>&1
export LANG=en_US.UTF-8
unset MAILCHECK
shopt -s expand_aliases
alias cdate='date +"%Y-%m-%d_%H:%M:%S"'

while getopts f:p:P:s:t: option
do
    case "$option" in
        f)
            # Specify one or more MySQL instance options files
            OPTFILE=$OPTARG
            ;;
        p)
            # Specify one or more MySQL instance root@localhost account passwords
            PASSWD=$OPTARG
            ;;
        P)
            # Specify multiple MySQL instance TCP/IP ports
            PORT=$OPTARG
            ;;
        s)
            # Do not specify this option if multiple option files are specified, otherwise you must specify the individual MySQL instance suffixes
            SUFFIX=$OPTARG
            ;;
        t)
            # Specifies the label for the MySQL options file backup
            baktag=$OPTARG
            ;;
        \?)
            echo "$(cdate) [Warning] You must specify the necessary options."
            exit 1
            ;;
    esac
done

if [ -z $OPTFILE ] || [ -z $PASSWD ] || [ -z $PORT ] || [ -z $baktag ];then
    echo "$(cdate) [ERROR] You must correctly set the options file, database system account password, database port, etc."
    exit 1
else
    OLD_IFS="$IFS"
    IFS=","
    arroptfile=($OPTFILE)
    arrpasswd=($PASSWD)
    arrport=($PORT)
    arrsuffix=($SUFFIX)
    IFS="$OLD_IFS"
    if [ ${#arroptfile[@]} -eq 1 ] && [ ${#arrsuffix[@]} -ne ${#arrport[@]} ];then
        echo "$(cdate) [ERROR] If a single option file is specified, the number of suffixes and ports in this scenario must be consistent."
        exit 1
    elif [ ${#arroptfile[@]} -gt 1 ] && [ ${#arrsuffix[@]} -ne 0 ];then
        echo "$(cdate) [ERROR] If more than one option file is specified, the suffix must be empty."
        exit 1
    elif [ ${#arroptfile[@]} -gt 1 ] && [ ${#arroptfile[@]} -ne ${#arrport[@]} ];then
        echo "$(cdate) [ERROR] If more than one option file is specified, the number of optfiles and ports in this scenario must be consistent."
        exit 1
    fi
fi

function precheck() {
    for optfile in ${arroptfile[@]}
    do
        test -e $optfile
        if [ $? -ne 0 ];then
            echo "$(cdate) [ERROR] There is a problem in args, please check again."
            exit 1
        fi
    done
    if [ ${#arrpasswd[@]} -eq 1 ];then
        for port in ${arrport[@]}
        do
            ckpstdopt=`mysql -h127.0.0.1 -uroot -p${arrpasswd[0]} -P$port -e"select 1;" 2>/dev/null|awk 'NR>1'`
            if [ ! -n "$ckpstdopt" ];then
            echo "$(cdate) [ERROR] There is a problem in args, please check again."
            exit 1
            fi
        done
    else
        for i in $(seq 0 `expr ${#arrport[@]} - 1`)
        do
            ckpstdopt=`mysql -h127.0.0.1 -uroot -p${arrpasswd[i]} -P${arrport[i]} -e"select 1;" 2>/dev/null|awk 'NR>1'`
            if [ ! -n "$ckpstdopt" ];then
            echo "$(cdate) [ERROR] There is a problem in args, please check again."
            exit 1
            fi
        done
    fi
}

function optionfile_config() {
    for i in $(seq 1 ${#arrport[@]})
    do
        group_seeds=$group_seeds,127.0.0.1:2490$i
    done
    arroption[0]="server_id="
    arroption[1]="report_host=127.0.0.1"
    arroption[2]="disabled_storage_engines=\"MyISAM,BLACKHOLE,FEDERATED,ARCHIVE,MEMORY\""
    arroption[3]="binlog_format=ROW"
    arroption[4]="log_slave_updates=ON"
    arroption[5]="binlog_checksum=NONE"
    arroption[6]="gtid_mode=ON"
    arroption[7]="enforce_gtid_consistency=ON"
    arroption[8]="master_info_repository=TABLE"
    arroption[9]="relay_log_info_repository=TABLE"
    arroption[10]="transaction_write_set_extraction=XXHASH64"
    arroption[11]="lower_case_table_names=1"
    arroption[12]="slave_parallel_type=LOGICAL_CLOCK"
    arroption[13]="slave_parallel_workers=4"
    arroption[14]="slave_preserve_commit_order=1"
    arroption[15]="plugin_load_add='group_replication.so'"
    arroption[16]="group_replication_group_name=\"b8e60503-b210-11ea-88f2-525400458c57\""
    arroption[17]="group_replication_start_on_boot=off"
    arroption[18]="group_replication_local_address="
    arroption[19]="group_replication_group_seeds=\"${group_seeds#*,}\""
    arroption[20]="group_replication_bootstrap_group=off"
    if [ ${#arroptfile[@]} -gt 1 ];then
        for i in $(seq 0 `expr ${#arroptfile[@]} - 1`)
        do
            j=`expr $i + 1`
            cp ${arroptfile[i]} ${arroptfile[i]}.$baktag$j
            for option in ${arroption[@]}
            do
                sed -e "/${option%%=*}/ s/^#*/#/" -i ${arroptfile[i]}
            done
            rownum=`cat -n ${arroptfile[i]}|grep -w "\[mysqld\]"|awk '{print $1}'`
            for k in $(seq `expr ${#arroption[@]} - 1` -1 0)
            do
                if [ "${arroption[k]%=*}" = "server_id" ];then
                    arroption[k]="server_id=$j"
                elif [ "${arroption[k]%=*}" = "group_replication_local_address" ];then
                    arroption[k]="group_replication_local_address=\"127.0.0.1:2490$j\""
                fi
                sed -i "$rownum a ${arroption[k]}" ${arroptfile[i]}
            done
        done
    else
        cp ${arroptfile[0]} ${arroptfile[0]}.$baktag
        for option in ${arroption[@]}
        do
            sed -e "/${option%%=*}/ s/^#*/#/" -i ${arroptfile[0]}
        done
        for i in $(seq 0 `expr ${#arrsuffix[@]} - 1`)
        do
            j=`expr $i + 1`
            rownum=`cat -n ${arroptfile[0]}|grep -w "\[mysqld${arrsuffix[i]}\]"|awk '{print $1}'`
            for k in $(seq `expr ${#arroption[@]} - 1` -1 0)
            do
                if [ "${arroption[k]%=*}" = "group_replication_local_address" ];then
                    arroption[k]="group_replication_local_address=\"127.0.0.1:2490$j\""
                elif [ "${arroption[k]%=*}" = "server_id" ];then
                    arroption[k]="server_id=$j"
                fi
                sed -i "$rownum a ${arroption[k]}" ${arroptfile[0]}
            done
        done
    fi
}

function socket() {
    if [ ${#arrpasswd[@]} -eq 1 ];then
        i=0
        for port in ${arrport[@]}
        do
            arrsocket[$i]=`mysql -h127.0.0.1 -uroot -p${arrpasswd[0]} -P$port -e"show global variables where Variable_name='socket'\G;" 2>/dev/null|tail -1|awk '{print $NF}'`
            let i++
        done
    else
        for i in $(seq 0 `expr ${#arrport[@]} - 1`)
        do
            arrsocket[$i]=`mysql -h127.0.0.1 -uroot -p${arrpasswd[i]} -P${arrport[i]} -e"show global variables where Variable_name='socket'\G;" 2>/dev/null|tail -1|awk '{print $NF}'`
        done
    fi
}

function multi_insts_stop() {
    if [ ${#arrpasswd[@]} -eq 1 ];then
        for socket in ${arrsocket[@]}
        do
            mysqladmin -uroot -p${arrpasswd[0]} -S$socket shutdown >/dev/null 2>&1
            sleep 5
        done
    else
        for i in $(seq 0 `expr ${#arrsocket[@]} - 1`)
        do
            mysqladmin -uroot -p${arrpasswd[i]} -S${arrsocket[i]} shutdown >/dev/null 2>&1
            sleep 5
        done
    fi
}

function multi_insts_start() {
    if [ ${#arroptfile[@]} -eq 1 ];then
        for suffix in ${arrsuffix[@]}
        do
            mysqld --defaults-file=${arroptfile[0]} --defaults-group-suffix=$suffix --daemonize --user=mysql >/dev/null 2>&1
            sleep 5
        done
    else
        for optfile in ${arroptfile[@]}
        do
            mysqld --defaults-file=$optfile --daemonize --user=mysql >/dev/null 2>&1
            sleep 5
        done
    fi
}

function mgr_deploy() {
    if [ ${#arrpasswd[@]} -eq 1 ];then
        for port in ${arrport[@]}
        do
            mysql -h127.0.0.1 -uroot -p${arrpasswd[0]} -P$port >/dev/null 2>&1 <<EOF
set SQL_LOG_BIN=0;
CREATE USER rpl_user@'%' IDENTIFIED BY 'Abcd321#';
GRANT REPLICATION SLAVE ON *.* TO rpl_user@'%';
FLUSH PRIVILEGES;
set SQL_LOG_BIN=1;
CHANGE MASTER TO MASTER_USER='rpl_user', MASTER_PASSWORD='Abcd321#' FOR CHANNEL 'group_replication_recovery';
EOF
        if [ "$port" = "${arrport[0]}" ];then
            mysql -h127.0.0.1 -uroot -p${arrpasswd[0]} -P$port >/dev/null 2>&1 <<EOF
SET GLOBAL group_replication_bootstrap_group=ON;
START GROUP_REPLICATION;
select sleep(3);
SET GLOBAL group_replication_bootstrap_group=OFF;
EOF
        else
            mysql -h127.0.0.1 -uroot -p${arrpasswd[0]} -P$port >/dev/null 2>&1 <<EOF
START GROUP_REPLICATION;
select sleep(3);
EOF
        fi
        done
    else
        for i in $(seq 0 `expr ${#arrport[@]} - 1`)
        do
            mysql -h127.0.0.1 -uroot -p${arrpasswd[i]} -P${arrport[i]} >/dev/null 2>&1 <<EOF
set SQL_LOG_BIN=0;
CREATE USER rpl_user@'%' IDENTIFIED BY 'Abcd321#';
GRANT REPLICATION SLAVE ON *.* TO rpl_user@'%';
FLUSH PRIVILEGES;
set SQL_LOG_BIN=1;
CHANGE MASTER TO MASTER_USER='rpl_user', MASTER_PASSWORD='Abcd321#' FOR CHANNEL 'group_replication_recovery';
EOF
        if [ $i -eq 0 ];then
            mysql -h127.0.0.1 -uroot -p${arrpasswd[i]} -P${arrport[i]} >/dev/null 2>&1 <<EOF
SET GLOBAL group_replication_bootstrap_group=ON;
START GROUP_REPLICATION;
select sleep(3);
SET GLOBAL group_replication_bootstrap_group=OFF;
EOF
        else
            mysql -h127.0.0.1 -uroot -p${arrpasswd[i]} -P${arrport[i]} >/dev/null 2>&1 <<EOF
START GROUP_REPLICATION;
select sleep(3);
EOF
        fi
        done
    fi
}

function switch_mutil_primarys() {
    if [ ${#arrpasswd[@]} -eq 1 ];then
        for i in $(seq `expr ${#arrport[@]} - 1` -1 0)
        do
            mysql -h127.0.0.1 -uroot -p${arrpasswd[0]} -P${arrport[i]} >/dev/null 2>&1 <<EOF
stop group_replication;
select sleep(3);
set global group_replication_single_primary_mode=OFF;
EOF
        done
    else
        for i in $(seq `expr ${#arrport[@]} - 1` -1 0)
        do
            mysql -h127.0.0.1 -uroot -p${arrpasswd[i]} -P${arrport[i]} >/dev/null 2>&1 <<EOF
stop group_replication;
select sleep(3);
set global group_replication_single_primary_mode=OFF;
EOF
        done
    fi
    if [ ${#arrpasswd[@]} -eq 1 ];then
        for port in ${arrport[@]}
        do
        if [ "$port" = "${arrport[0]}" ];then
            mysql -h127.0.0.1 -uroot -p${arrpasswd[0]} -P$port >/dev/null 2>&1 <<EOF
SET GLOBAL group_replication_bootstrap_group=ON;
START GROUP_REPLICATION;
select sleep(3);
SET GLOBAL group_replication_bootstrap_group=OFF;
EOF
        else
            mysql -h127.0.0.1 -uroot -p${arrpasswd[0]} -P$port >/dev/null 2>&1 <<EOF
START GROUP_REPLICATION;
select sleep(3);
EOF
        fi
        done
    else
        for i in $(seq 0 `expr ${#arrport[@]} - 1`)
        do
        if [ $i -eq 0 ];then
            mysql -h127.0.0.1 -uroot -p${arrpasswd[i]} -P${arrport[i]} >/dev/null 2>&1 <<EOF
SET GLOBAL group_replication_bootstrap_group=ON;
START GROUP_REPLICATION;
select sleep(3);
SET GLOBAL group_replication_bootstrap_group=OFF;
EOF
        else
            mysql -h127.0.0.1 -uroot -p${arrpasswd[i]} -P${arrport[i]} >/dev/null 2>&1 <<EOF
START GROUP_REPLICATION;
select sleep(3);
EOF
        fi
        done
    fi
}

function mgr_online_rollback() {
    if [ ${#arrpasswd[@]} -eq 1 ];then
        for i in $(seq `expr ${#arrport[@]} - 1` -1 0)
        do
            mysql -h127.0.0.1 -uroot -p${arrpasswd[0]} -P${arrport[i]} >/dev/null 2>&1 <<EOF
stop group_replication;
select sleep(3);
reset master;
reset slave all;
SET GLOBAL SUPER_READ_ONLY=OFF;
set SQL_LOG_BIN=0;
DROP USER IF EXISTS rpl_user@'%';
set SQL_LOG_BIN=1;
EOF
        done
    else
        for i in $(seq `expr ${#arrport[@]} - 1` -1 0)
        do
            mysql -h127.0.0.1 -uroot -p${arrpasswd[i]} -P${arrport[i]} >/dev/null 2>&1 <<EOF
stop group_replication;
select sleep(3);
reset master;
reset slave all;
SET GLOBAL SUPER_READ_ONLY=OFF;
set SQL_LOG_BIN=0;
DROP USER IF EXISTS rpl_user@'%';
set SQL_LOG_BIN=1;
EOF
        done       
    fi
}

function mgr_offline_rollback() {
    if [ ${#arroptfile[@]} -gt 1 ];then
        for i in $(seq 0 `expr ${#arroptfile[@]} - 1`)
        do
            j=`expr $i + 1`
            if [ -e ${arroptfile[i]} ] && [ -e ${arroptfile[i]}.$baktag$j ];then
                mv ${arroptfile[i]} ${arroptfile[i]}.$(cdate) && mv ${arroptfile[i]}.$baktag$j ${arroptfile[i]}
            fi
        done
    else
        if [ -e ${arroptfile[0]} ] && [ -e ${arroptfile[0]}.$baktag ];then
            mv ${arroptfile[0]} ${arroptfile[0]}.$(cdate) && mv ${arroptfile[0]}.$baktag ${arroptfile[0]}
        fi
    fi
}

function member_state_check() {
    if [ ${#arrpasswd[@]} -eq 1 ];then
        i=0
        for port in ${arrport[@]}
        do
            arrmemberstat[$i]=`mysql -h127.0.0.1 -uroot -p${arrpasswd[0]} -P$port -e"select member_state from performance_schema.replication_group_members where member_id=(select variable_value from performance_schema.global_variables where variable_name='server_uuid')\G;" 2>/dev/null|tail -1|awk '{print $NF}'`
            let i++
        done
    else
        for i in $(seq 0 `expr ${#arrport[@]} - 1`)
        do
            arrmemberstat[$i]=`mysql -h127.0.0.1 -uroot -p${arrpasswd[i]} -P${arrport[i]} -e"select member_state from performance_schema.replication_group_members where member_id=(select variable_value from performance_schema.global_variables where variable_name='server_uuid')\G;" 2>/dev/null|tail -1|awk '{print $NF}'`
        done
    fi
    for i in $(seq 0 `expr ${#arrport[@]} - 1`)
    do
        if [ "${arrmemberstat[i]}" != "ONLINE" ];then
            echo "$(cdate) [ERROR] Replication group member of ${arrport[i]} state is abnormal."
        else
            echo "$(cdate) [Note] Replication group member of ${arrport[i]} state is online."
        fi
    done
}

function main() {
    DEBUG_FLG='McDeBuG'
    my_debug_flg=`echo $*| awk '{print $NF}'`
    if [[ "$my_debug_flg" = "$DEBUG_FLG" ]]; then
        export PS4='+{$LINENO:${FUNCNAME[0]}} '
        set -x
        echo args=$@
    fi
    read -r -p "Welcome to the MySQL group replication Install or Deinstall , please check? [Y/N]" input
    case $input in
        [yY])
            read -r -p "Welcome to Local install, deinstall, precheck, test, or switch multi primarys, please check? [I/D/P/T/S]" input
            case $input in
                [iI])
                    precheck
                    optionfile_config
                    echo "$(cdate) [Note] Fetching each MySQL instance socket file."
                    socket
                    echo "$(cdate) [Note] Stopping MySQL multiple instances."
                    multi_insts_stop
                    echo "$(cdate) [Note] Starting MySQL multiple instances."
                    multi_insts_start
                    echo "$(cdate) [Note] MySQL group replication deploy is beginning."
                    mgr_deploy
                    echo "$(cdate) [Note] MySQL group replication deploy is ended."
                    member_state_check
                    ;;
                [dD])
                    echo "$(cdate) [Note] MySQL group replication rollback is beginning."
                    precheck
                    mgr_online_rollback
                    socket
                    multi_insts_stop
                    mgr_offline_rollback
                    multi_insts_start
                    echo "$(cdate) [Note] MySQL group replication rollback is ended."
                    ;;
                [pP])
                    echo "$(cdate) [Note] MySQL group replication precheck is beginning."
                    precheck
                    echo "$(cdate) [Note] MySQL group replication precheck is ended."
                    ;;
                [tT])
                    precheck
                    echo "$(cdate) [Note] Checking state of MySQL group replication members."
                    member_state_check
                    ;;
                [sS])
                    precheck
                    echo "$(cdate) [Note] MySQL group replication switch to multi primarys mode is beginning."
                    switch_mutil_primarys
                    echo "$(cdate) [Note] MySQL group replication switch to multi primarys mode is ended."                    
                    ;;
                *)
                    echo "$(cdate) [ERROR] Invalid input..."
                    exit 1
                    ;;
            esac
            ;;
        [nN])
            exit 1
            ;;
        *)
            echo "$(cdate) [ERROR] Invalid input..."
            exit 1
            ;;
    esac
}
main $@ 2>&1
#./1.sh -f/etc/my.cnf -pAbcd321# -P33061,33062,33063 -s@scene1,@scene2,@scene3 -tmcbak
#./1.sh -f/mysql/app/my4.cnf,/mysql/app/my5.cnf,/mysql/app/my6.cnf -pAbcd321#,Abcd321#,Abcd321# -P33064,33065,33066 -tmcbak
