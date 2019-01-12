#!/bin/bash
#
# 导出原始数据


MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_PASSWD=mysql
MYSQL_DB=bostar
MYSQL_CHARSET=utf8

TABLES="l_adv
l_adver
l_all_add
l_all_income
l_all_income_pct
l_app
l_city_pct
l_cus
l_daycnt_rand
l_hour_rand
l_ip_abroad
l_ip_native
l_pro_city
l_prod_keep
t_city
t_prod_adv_run
t_prod_run"

TMP_DIR=/tmp/$(date +%s%N)
mkdir -p $TMP_DIR


# 执行sql
function exec_sql()
{
    local sql="${1:-`cat`}"
    local params="${2:--s -N --local-infile}"

    echo "SET NAMES $MYSQL_CHARSET;$sql" | mysql -h$MYSQL_HOST -P$MYSQL_PORT -u$MYSQL_USER -p$MYSQL_PASSWD $MYSQL_DB $params
}

# 统计表行数
function count_table()
{
    echo "$TABLES" | while read table; do
        echo "SELECT '$table', COUNT(1) FROM $table;"
    done | exec_sql
}

# 导出表
function dump_table()
{
    cd $TMP_DIR
    echo "$TABLES" | while read table; do
        mysqldump -h$MYSQL_HOST -P$MYSQL_PORT -u$MYSQL_USER -p$MYSQL_PASSWD $MYSQL_DB $table > $table.sql
    done

    # 压缩
    tar -zcf ${MYSQL_DB}.tar.gz *.sql
}

# 用法
function usage()
{
    echo "Usage: $0 [ -c count table ] [ -d dump table ]"
}

function main()
{
    if [[ $# -lt 1 ]]; then
        usage
        exit 1
    fi

    while getopts "cd" opt; do
        case "$opt" in
            c)
                count_flag=$OPTARG;;
            d)
                dump_flag=1;;
            ?)
                usage
                exit 1;;
        esac
    done

    # 统计表行数
    [[ $count_flag ]] && count_table

    # 导出表
    [[ $dump_flag ]] && dump_table
}
main "$@"