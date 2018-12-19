
# 元数据库配置
META_DB_HOST=192.168.1.11
META_DB_PORT=3306
META_DB_USER=root
META_DB_PASSWD=mysql
META_DB_NAME=ad
META_DB_CHARSET=utf8

# 数据仓库配置
DW_DB_HOST=192.168.1.11
DW_DB_PORT=3306
DW_DB_USER=root
DW_DB_PASSWD=mysql
DW_DB_NAME=ad_dw
DW_DB_CHARSET=utf8

# 数据文件目录
DATA_DIR=/var/ad/data
# 临时文件目录
TMP_DIR=/var/ad/tmp/$(date +%s%N)

# IP数据文件
FILE_IP=$DATA_DIR/ip

# Android ID数据表
TBL_AID=android_ids
# Android ID数据文件
FILE_AID=$DATA_DIR/android_ids
# 新增量数据表
TBL_ADD_CNT=add_count

# 聚合表前缀
TP_AGG=agg_


# 记录日志
function log()
{
    echo "$(date +'%F %T') [ $@ ]"
}

# 在方法执行前后记录日志
function log_fn()
{
    log "Function call begin [ $@ ]"
    $@
    log "Function call end [ $@ ]"
}

# 生成日期序列
function range_date()
{
    local date_begin=`date +%Y%m%d -d "$1"`
    local date_end=`date +%Y%m%d -d "$2"`

    while [[ $date_begin -le $date_end ]]; do
        date +%F -d "$date_begin"
        date_begin=`date +%Y%m%d -d "$date_begin 1 day"`
    done
}

# 生成月份序列
function range_month()
{
    local month_begin=`date +%Y%m -d "${1//-/}01"`
    local month_end=`date +%Y%m -d "${2//-/}01"`

    while [[ $month_begin -le $month_end ]]; do
        date +%Y-%m -d "${month_begin}01"
        month_begin=`date +%Y%m -d "${month_begin}01 1 month"`
    done
}

# 执行元数据库sql
function exec_meta()
{
    local sql="${1:-`cat`}"
    local params="${2:--s -N --local-infile}"

    echo "SET NAMES $META_DB_CHARSET;$sql" | mysql -h$META_DB_HOST -P$META_DB_PORT -u$META_DB_USER -p$META_DB_PASSWD $META_DB_NAME $params
}

# 执行数据仓库sql
function exec_dw()
{
    local sql="${1:-`cat`}"
    local params="${2:--s -N --local-infile}"

    echo "SET NAMES $DW_DB_CHARSET;$sql" | mysql -h$DW_DB_HOST -P$DW_DB_PORT -u$DW_DB_USER -p$DW_DB_PASSWD $DW_DB_NAME $params
}
