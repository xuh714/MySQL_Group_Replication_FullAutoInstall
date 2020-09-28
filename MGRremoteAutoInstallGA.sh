#!/bin/bash
# 2020-09-18 MySQL group replication Remote AutoInstall Script version 1.0 (Author : xuh)
# 2019-09-22 version 2.0
#       add: MGR Remote full-automatic installation is supported
. $HOME/.bash_profile >/dev/null 2>&1
export LANG=en_US.UTF-8
unset MAILCHECK
shopt -s expand_aliases
alias cdate='date +"%Y-%m-%d_%H:%M:%S"'

while getopts d:f:i:o:P:t: option
do
    case "$option" in
        d)
            # Specify one or more MySQL instance root@localhost database account passwords
            DBPASSWD=$OPTARG
            ;;        
        f)
            # Specify one or more MySQL instance options files
            OPTFILE=$OPTARG # one or menbers of mgr
            ;;
        i)
            # Specify multiple MySQL instance IP addresses
            IPADDR=$OPTARG # menbers of mgr
            ;;
        o)
            # Specify one or more MySQL instance root os machine account passwords
            OSPASSWD=$OPTARG # one or menbers of mgr
            ;;
        P)
            # Specify one or more MySQL instance TCP/IP ports
            PORT=$OPTARG # one or menbers of mgr
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

if [ -z $DBPASSWD ] || [ -z $OPTFILE ] || [ -z $IPADDR ] || [ -z $OSPASSWD ] || [ -z $PORT ];then
    echo "$(cdate) [ERROR] You must correctly set the options file, machine ipaddrs, database system account password, database port, etc."
    exit 1
else
    OLD_IFS="$IFS"
    IFS=","
    arrdbpasswd=($DBPASSWD)    
    arroptfile=($OPTFILE)
    arripaddr=($IPADDR)    
    arrospasswd=($OSPASSWD)
    arrport=($PORT)
    IFS="$OLD_IFS"

    if [ ${#arrdbpasswd[@]} -ne ${#arroptfile[@]} ] || [ ${#arrdbpasswd[@]} -ne ${#arrospasswd[@]} ] || [ ${#arrdbpasswd[@]} -ne ${#arrport[@]} ] || [ ${#arroptfile[@]} -ne ${#arrospasswd[@]} ] || [ ${#arroptfile[@]} -ne ${#arrport[@]} ] || [ ${#arrospasswd[@]} -ne ${#arrport[@]} ];then
        echo "$(cdate) [ERROR] The configuration of options files, dbpwds, ospwds, and dbports must be consistent."
        exit 1
    fi
fi

function precheck() {
    if [ ${#arrport[@]} -eq 1 ];then
        for ipaddr in ${arripaddr[@]}
        do
            stdopt=$(sshpass -p${arrospasswd[0]} ssh root@$ipaddr 2>/dev/null <<EOF
test -e ${arroptfile[0]} && echo "presence" || echo "absence"
EOF
)
        if [ -z $stdopt ] || [ "$stdopt" != "presence"  ];then
            echo "$(cdate) [ERROR] There is a problem in args of option file, please check again."
            exit 1
        fi
            stdopt=$(sshpass -p${arrospasswd[0]} ssh root@$ipaddr 2>/dev/null <<EOF
mysql -h127.0.0.1 -uroot -p${arrdbpasswd[0]} -P${arrport[0]} -e"select 1;" 2>/dev/null|awk 'NR>1'
EOF
)
        if [ -z $stdopt ] || [ $stdopt -ne 1 ];then
        echo "$(cdate) [ERROR] There is a problem in args of dbpassword or dbport, please check again."
        exit 1
        fi
        done
    else
        for i in $(seq 0 `expr ${#arripaddr[@]} - 1`)
        do
            stdopt=$(sshpass -p${arrospasswd[i]} ssh root@${arripaddr[i]} 2>/dev/null <<EOF
test -e ${arroptfile[i]} && echo "presence" || echo "absence"
EOF
)
        if [ -z $stdopt ] || [ "$stdopt" != "presence" ];then
            echo "$(cdate) [ERROR] There is a problem in args of option file, please check again."
            exit 1
        fi
            stdopt=$(sshpass -p${arrospasswd[i]} ssh root@${arripaddr[i]} 2>/dev/null <<EOF
mysql -h127.0.0.1 -uroot -p${arrdbpasswd[i]} -P${arrport[i]} -e"select 1;" 2>/dev/null|awk 'NR>1'
EOF
)
        if [ -z $stdopt ] || [ $stdopt -ne 1 ];then
        echo "$(cdate) [ERROR] There is a problem in args of dbpassword or dbport, please check again."
        exit 1
        fi
        done
    fi
}

function optionfile_config() {
    for i in $(seq 0 `expr ${#arripaddr[@]} - 1`)
    do
        group_seeds=$group_seeds,${arripaddr[i]}:33061
    done
    arroption[19]="server_id="
    arroption[18]="disabled_storage_engines="
    arroption[17]="binlog_format=ROW"
    arroption[16]="log_slave_updates=ON"
    arroption[15]="binlog_checksum=NONE"
    arroption[14]="gtid_mode=ON"
    arroption[13]="enforce_gtid_consistency=ON"
    arroption[12]="master_info_repository=TABLE"
    arroption[11]="relay_log_info_repository=TABLE"
    arroption[10]="transaction_write_set_extraction=XXHASH64"
    arroption[9]="lower_case_table_names=1"
    arroption[8]="slave_parallel_type=LOGICAL_CLOCK"
    arroption[7]="slave_parallel_workers=4"
    arroption[6]="slave_preserve_commit_order=1"
    arroption[5]="plugin_load_add="
    arroption[4]="group_replication_group_name="
    arroption[3]="group_replication_start_on_boot=off"
    arroption[2]="group_replication_local_address="
    arroption[1]="group_replication_group_seeds="
    arroption[0]="group_replication_bootstrap_group=off"
    if [ ${#arroptfile[@]} -gt 1 ];then
        for i in $(seq 0 `expr ${#arroptfile[@]} - 1`)
        do
            j=`expr $i + 1`
            rownum=$(sshpass -p${arrospasswd[i]} ssh root@${arripaddr[i]} /bin/bash <<EOF
cat -n ${arroptfile[i]}|grep -w "\[mysqld\]"|awk '{print \$1}'
EOF
)
            sshpass -p${arrospasswd[i]} ssh root@${arripaddr[i]} /bin/bash <<EOF
cp ${arroptfile[i]} ${arroptfile[i]}.$baktag
for option in ${arroption[@]}
do
    sed -e "/\${option%%=*}/ s/^#*/#/" -i ${arroptfile[i]}
    if [ "\${option%=*}" = "server_id" ];then
        option="server_id=$j"
    elif [ "\${option%=*}" = "disabled_storage_engines" ];then
        option="disabled_storage_engines=\"MyISAM,BLACKHOLE,FEDERATED,ARCHIVE,MEMORY\""
    elif [ "\${option%=*}" = "plugin_load_add" ];then
        option="plugin_load_add='group_replication.so'"
    elif [ "\${option%=*}" = "group_replication_group_name" ];then
        option="group_replication_group_name=\"b8e60503-b210-11ea-88f2-525400458c57\""
    elif [ "\${option%=*}" = "group_replication_local_address" ];then
        option="group_replication_local_address=\"${arripaddr[i]}:33061\""
    elif [ "\${option%=*}" = "group_replication_group_seeds" ];then
        option="group_replication_group_seeds=\"${group_seeds#*,}\""
    fi
    sed -i "$rownum a \$option" ${arroptfile[i]}
done
EOF
        done
    else
        for i in $(seq 0 `expr ${#arripaddr[@]} - 1`)
        do
            j=`expr $i + 1`
            rownum=$(sshpass -p${arrospasswd[0]} ssh root@${arripaddr[i]} /bin/bash <<EOF
cat -n ${arroptfile[0]}|grep -w "\[mysqld\]"|awk '{print \$1}'
EOF
)
            sshpass -p${arrospasswd[0]} ssh root@${arripaddr[i]} /bin/bash <<EOF
cp ${arroptfile[0]} ${arroptfile[0]}.$baktag
for option in ${arroption[@]}
do
    sed -e "/\${option%%=*}/ s/^#*/#/" -i ${arroptfile[0]}
    if [ "\${option%=*}" = "server_id" ];then
        option="server_id=$j"
    elif [ "\${option%=*}" = "disabled_storage_engines" ];then
        option="disabled_storage_engines=\"MyISAM,BLACKHOLE,FEDERATED,ARCHIVE,MEMORY\""
    elif [ "\${option%=*}" = "plugin_load_add" ];then
        option="plugin_load_add='group_replication.so'"
    elif [ "\${option%=*}" = "group_replication_group_name" ];then
        option="group_replication_group_name=\"b8e60503-b210-11ea-88f2-525400458c57\""
    elif [ "\${option%=*}" = "group_replication_local_address" ];then
        option="group_replication_local_address=\"${arripaddr[i]}:33061\""
    elif [ "\${option%=*}" = "group_replication_group_seeds" ];then
        option="group_replication_group_seeds=\"${group_seeds#*,}\""
    fi
    sed -i "$rownum a \$option" ${arroptfile[0]}

done
EOF
        done
    fi
}

function socket() {
    if [ ${#arrport[@]} -eq 1 ];then
        i=0
        for ipaddr in ${arripaddr[@]}
        do
            arrsocket[$i]=$(sshpass -p${arrospasswd[0]} ssh root@$ipaddr 2>/dev/null <<EOF
mysql -h127.0.0.1 -uroot -p${arrdbpasswd[0]} -P${arrport[0]} -e"select variable_value from performance_schema.global_variables where variable_name='socket';" 2>/dev/null|tail -1
EOF
)
        let i++
        done

    else
        for i in $(seq 0 `expr ${#arripaddr[@]} - 1`)
        do
            arrsocket[$i]=$(sshpass -p${arrospasswd[i]} ssh root@${arripaddr[i]} 2>/dev/null <<EOF
mysql -h127.0.0.1 -uroot -p${arrdbpasswd[i]} -P${arrport[i]} -e"select variable_value from performance_schema.global_variables where variable_name='socket';" 2>/dev/null|tail -1
EOF
)
        done
    fi
}

function multi_insts_stop() {
    if [ ${#arrport[@]} -eq 1 ];then
        for i in $(seq 0 `expr ${#arrsocket[@]} - 1`)
        do
            sshpass -p${arrospasswd[0]} ssh root@${arripaddr[i]} 2>/dev/null <<EOF
mysqladmin -uroot -p${arrdbpasswd[0]} -S${arrsocket[i]} shutdown 2>/dev/null
sleep 5
EOF
        done
    else
        for i in $(seq 0 `expr ${#arrsocket[@]} - 1`)
        do
            sshpass -p${arrospasswd[i]} ssh root@${arripaddr[i]} 2>/dev/null <<EOF
mysqladmin -uroot -p${arrdbpasswd[i]} -S${arrsocket[i]} shutdown 2>/dev/null
sleep 5
EOF
        done
    fi
}

function multi_insts_start() {
    if [ ${#arrport[@]} -eq 1 ];then
        for ipaddr in ${arripaddr[@]}
        do
            sshpass -p${arrospasswd[0]} ssh root@$ipaddr 2>/dev/null <<EOF
mysqld --defaults-file=${arroptfile[0]} --daemonize --user=mysql 2>/dev/null
sleep 5
EOF
        done
    else
        for i in $(seq 0 `expr ${#arripaddr[@]} - 1`)
        do
            sshpass -p${arrospasswd[i]} ssh root@${arripaddr[i]} 2>/dev/null <<EOF
mysqld --defaults-file=${arroptfile[i]} --daemonize --user=mysql 2>/dev/null
sleep 5
EOF
        done
    fi
}

function mgr_deploy() {
    if [ ${#arrport[@]} -eq 1 ];then
        for ipaddr in ${arripaddr[@]}
        do
            sshpass -p${arrospasswd[0]} ssh root@$ipaddr 2>/dev/null <<EOF
mysql -h127.0.0.1 -uroot -p${arrdbpasswd[0]} -P${arrport[0]} >/dev/null 2>&1 <<eof
set SQL_LOG_BIN=0;
CREATE USER rpl_user@'%' IDENTIFIED BY 'Abcd321#';
GRANT REPLICATION SLAVE ON *.* TO rpl_user@'%';
FLUSH PRIVILEGES;
set SQL_LOG_BIN=1;
CHANGE MASTER TO MASTER_USER='rpl_user', MASTER_PASSWORD='Abcd321#' FOR CHANNEL 'group_replication_recovery';
eof
EOF
        if [ "$ipaddr" = "${arripaddr[0]}" ];then
            sshpass -p${arrospasswd[0]} ssh root@$ipaddr 2>/dev/null <<EOF
mysql -h127.0.0.1 -uroot -p${arrdbpasswd[0]} -P${arrport[0]} >/dev/null 2>&1 <<eof
SET GLOBAL group_replication_bootstrap_group=ON;
START GROUP_REPLICATION;
select sleep(3);
SET GLOBAL group_replication_bootstrap_group=OFF;
eof
EOF
        else
            sshpass -p${arrospasswd[0]} ssh root@$ipaddr 2>/dev/null <<EOF
mysql -h127.0.0.1 -uroot -p${arrdbpasswd[0]} -P${arrport[0]} >/dev/null 2>&1 <<eof
START GROUP_REPLICATION;
select sleep(3);
eof
EOF
        fi
        done
    else
        for i in $(seq 0 `expr ${#arripaddr[@]} - 1`)
        do
            sshpass -p${arrospasswd[i]} ssh root@${arripaddr[i]} 2>/dev/null <<EOF
mysql -h127.0.0.1 -uroot -p${arrdbpasswd[i]} -P${arrport[i]} >/dev/null 2>&1 <<eof
set SQL_LOG_BIN=0;
CREATE USER rpl_user@'%' IDENTIFIED BY 'Abcd321#';
GRANT REPLICATION SLAVE ON *.* TO rpl_user@'%';
FLUSH PRIVILEGES;
set SQL_LOG_BIN=1;
CHANGE MASTER TO MASTER_USER='rpl_user', MASTER_PASSWORD='Abcd321#' FOR CHANNEL 'group_replication_recovery';
eof
EOF
        if [ $i -eq 0 ];then
            sshpass -p${arrospasswd[i]} ssh root@${arripaddr[i]} 2>/dev/null <<EOF
mysql -h127.0.0.1 -uroot -p${arrdbpasswd[i]} -P${arrport[i]} >/dev/null 2>&1 <<eof
SET GLOBAL group_replication_bootstrap_group=ON;
START GROUP_REPLICATION;
select sleep(3);
SET GLOBAL group_replication_bootstrap_group=OFF;
eof
EOF
        else
            sshpass -p${arrospasswd[i]} ssh root@${arripaddr[i]} 2>/dev/null <<EOF
mysql -h127.0.0.1 -uroot -p${arrdbpasswd[i]} -P${arrport[i]} >/dev/null 2>&1 <<eof
START GROUP_REPLICATION;
select sleep(3);
eof
EOF
        fi
        done
    fi
}

function switch_mutil_primarys() {
    if [ ${#arrdbpasswd[@]} -eq 1 ];then
        for i in $(seq `expr ${#arripaddr[@]} - 1` -1 0)
        do
            sshpass -p${arrospasswd[0]} ssh root@${arripaddr[i]} 2>/dev/null <<EOF
mysql -h127.0.0.1 -uroot -p${arrdbpasswd[0]} -P${arrport[0]} >/dev/null 2>&1 <<eof
stop group_replication;
select sleep(3);
set global group_replication_single_primary_mode=OFF;
eof
EOF
        done
    else
        for i in $(seq `expr ${#arripaddr[@]} - 1` -1 0)
        do
            sshpass -p${arrospasswd[i]} ssh root@${arripaddr[i]} 2>/dev/null <<EOF
mysql -h127.0.0.1 -uroot -p${arrdbpasswd[i]} -P${arrport[i]} >/dev/null 2>&1 <<eof
stop group_replication;
select sleep(3);
set global group_replication_single_primary_mode=OFF;
eof
EOF
        done
    fi
    if [ ${#arrdbpasswd[@]} -eq 1 ];then
        for ipaddr in ${arripaddr[@]}
        do
        if [ "$ipaddr" = "${arripaddr[0]}" ];then
            sshpass -p${arrospasswd[0]} ssh root@$ipaddr 2>/dev/null <<EOF
mysql -h127.0.0.1 -uroot -p${arrdbpasswd[0]} -P${arrport[0]} >/dev/null 2>&1 <<eof
SET GLOBAL group_replication_bootstrap_group=ON;
START GROUP_REPLICATION;
select sleep(3);
SET GLOBAL group_replication_bootstrap_group=OFF;
eof
EOF
        else
            sshpass -p${arrospasswd[0]} ssh root@$ipaddr 2>/dev/null <<EOF
mysql -h127.0.0.1 -uroot -p${arrdbpasswd[0]} -P${arrport[0]} >/dev/null 2>&1 <<eof
START GROUP_REPLICATION;
select sleep(3);
eof
EOF
        fi
        done
    else
        for i in $(seq 0 `expr ${#arripaddr[@]} - 1`)
        do
        if [ $i -eq 0 ];then
            sshpass -p${arrospasswd[i]} ssh root@${arripaddr[i]} 2>/dev/null <<EOF
mysql -h127.0.0.1 -uroot -p${arrdbpasswd[i]} -P${arrport[i]} >/dev/null 2>&1 <<eof
SET GLOBAL group_replication_bootstrap_group=ON;
START GROUP_REPLICATION;
select sleep(3);
SET GLOBAL group_replication_bootstrap_group=OFF;
eof
EOF
        else
            sshpass -p${arrospasswd[i]} ssh root@${arripaddr[i]} 2>/dev/null <<EOF
mysql -h127.0.0.1 -uroot -p${arrdbpasswd[i]} -P${arrport[i]} >/dev/null 2>&1 <<eof
START GROUP_REPLICATION;
select sleep(3);
eof
EOF
        fi
        done
    fi
}

function mgr_online_rollback() {
    if [ ${#arrport[@]} -eq 1 ];then
        for i in $(seq `expr ${#arripaddr[@]} - 1` -1 0)
        do
            sshpass -p${arrospasswd[0]} ssh root@${arripaddr[i]} 2>/dev/null <<EOF
mysql -h127.0.0.1 -uroot -p${arrdbpasswd[0]} -P${arrport[0]} >/dev/null 2>&1 <<eof
stop group_replication;
select sleep(3);
eof
mysql -h127.0.0.1 -uroot -p${arrdbpasswd[0]} -P${arrport[0]} >/dev/null 2>&1 <<eof
reset master;
reset slave all;
SET GLOBAL SUPER_READ_ONLY=OFF;
set SQL_LOG_BIN=0;
DROP USER IF EXISTS rpl_user@'%';
set SQL_LOG_BIN=1;
eof
EOF
        done
    else
        for i in $(seq `expr ${#arripaddr[@]} - 1` -1 0)
        do
            sshpass -p${arrospasswd[i]} ssh root@${arripaddr[i]} 2>/dev/null <<EOF
mysql -h127.0.0.1 -uroot -p${arrdbpasswd[i]} -P${arrport[i]} >/dev/null 2>&1 <<eof
stop group_replication;
select sleep(3);
eof
mysql -h127.0.0.1 -uroot -p${arrdbpasswd[i]} -P${arrport[i]} >/dev/null 2>&1 <<eof
reset master;
reset slave all;
SET GLOBAL SUPER_READ_ONLY=OFF;
set SQL_LOG_BIN=0;
DROP USER IF EXISTS rpl_user@'%';
set SQL_LOG_BIN=1;
eof
EOF
        done       
    fi
}

function mgr_offline_rollback() {
    if [ ${#arroptfile[@]} -gt 1 ];then
        for i in $(seq 0 `expr ${#arroptfile[@]} - 1`)
        do
            sshpass -p${arrospasswd[i]} ssh root@${arripaddr[i]} 2>/dev/null <<EOF
if [ -e ${arroptfile[i]} ] && [ -e ${arroptfile[i]}.$baktag ];then
    mv ${arroptfile[i]} ${arroptfile[i]}.$(cdate) && mv ${arroptfile[i]}.$baktag ${arroptfile[i]}
fi
EOF
        done
    else
        for i in $(seq 0 `expr ${#arripaddr[@]} - 1`)
        do
            sshpass -p${arrospasswd[0]} ssh root@${arripaddr[i]} 2>/dev/null <<EOF
if [ -e ${arroptfile[0]} ] && [ -e ${arroptfile[0]}.$baktag ];then
    mv ${arroptfile[0]} ${arroptfile[0]}.$(cdate) && mv ${arroptfile[0]}.$baktag ${arroptfile[0]}
fi
EOF
        done
    fi
}

function member_state_check() {
    if [ ${#arrport[@]} -eq 1 ];then
        i=0
        for ipaddr in ${arripaddr[@]}
        do
            arrmemberstat[$i]=$(sshpass -p${arrospasswd[0]} ssh root@$ipaddr 2>/dev/null <<EOF
mysql -h127.0.0.1 -uroot -p${arrdbpasswd[0]} -P${arrport[0]} -e"select member_state from performance_schema.replication_group_members where member_id=(select variable_value from performance_schema.global_variables where variable_name='server_uuid');" 2>/dev/null|tail -1
EOF
)
        let i++
        done
    else
        for i in $(seq 0 `expr ${#arripaddr[@]} - 1`)
        do
            arrmemberstat[$i]=$(sshpass -p${arrospasswd[i]} ssh root@${arripaddr[i]} 2>/dev/null <<EOF
mysql -h127.0.0.1 -uroot -p${arrdbpasswd[i]} -P${arrport[i]} -e"select member_state from performance_schema.replication_group_members where member_id=(select variable_value from performance_schema.global_variables where variable_name='server_uuid');" 2>/dev/null|tail -1
EOF
)
        done
    fi
    for i in $(seq 0 `expr ${#arripaddr[@]} - 1`)
    do
        if [ "${arrmemberstat[i]}" != "ONLINE" ];then
            echo "$(cdate) [ERROR] Replication group member of ${arripaddr[i]} state is abnormal."
        else
            echo "$(cdate) [Note] Replication group member of ${arripaddr[i]} state is online."
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
            read -r -p "Welcome to Remote install, deinstall, precheck, test, or switch multi primarys, please check? [I/D/P/T/S]" input
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
                    member_state_check            
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
#./1.sh -dAbcd321# -f/etc/my.cnf -i192.168.239.57,192.168.239.58,192.168.239.59 -ohzmcdba -P3306 -tmcbak McDeBuG
#./1.sh -dAbcd321#,Abcd321#,Abcd321# -f/etc/my.cnf,/etc/my.cnf,/etc/my.cnf -i192.168.239.57,192.168.239.58,192.168.239.59 -ohzmcdba,hzmcdba,hzmcdba -P3306,3306,3306 -tmcbak McDeBuG
