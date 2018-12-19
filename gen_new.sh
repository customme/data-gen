#!/bin/bash
#
# 根据地区占比生成新增


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source $DIR/common.sh


# 地区占比数据表
TBL_AREA_RATE=area_rate

# 最大ID数据文件
FILE_MAXID=$DATA_DIR/max_id


# 初始化
function init()
{
    # 统一日期格式
    start_date=`date +%F -d "$start_date"`
    end_date=`date +%F -d "$end_date"`

    data_dir=$DATA_DIR/$product_code
    tmp_dir=$TMP_DIR/$product_code
    mkdir -p $data_dir $tmp_dir

    # 新增量数据文件
    file_add_count=$DATA_DIR/add_count.$product_code.$start_date
    # 地区占比数据文件
    file_area_rate=$DATA_DIR/area_rate.$product_code

    # 新增事实表
    tbl_fact_new=fact_new_$product_code
    # 新增聚合表前缀
    tp_agg_new=${TP_AGG}new_${product_code}_
}

# 获取新增量
function get_add_count()
{
    if [[ ! -s $file_add_count ]]; then
        echo "SELECT create_date, channel_code, add_count
        FROM $TBL_ADD_CNT
        WHERE product_code = '$product_code'
        AND add_count > 0
        AND create_date >= '$start_date' AND create_date <= '$end_date'
        ORDER BY create_date;
        " | exec_meta > $file_add_count
    fi

    awk -F '\t' 'BEGIN{OFS=FS} $1 == "'$the_date'" {print $2,$3}' $file_add_count
}

# 获取地区占比
function get_area_rate()
{
    if [[ ! -s $file_city_pct ]]; then
        echo "SELECT area, rate FROM $TBL_AREA_RATE WHERE product_code = '$product_code';" | exec_meta > $file_area_rate
    fi

    cat $file_area_rate
}

# 地区用户量区间
function range_city()
{
    get_area_rate | awk 'BEGIN{
        srand()
    }{
        rndpct = int($2 / 10 + 0.5)
        sign = rand()
        if(sign < 0.5) rndpct = -rndpct

        count = int(total * ($2 + rndpct) / 10000 + 0.5)
        city[++i] = $1" "count
        sum += count
#        print $1,count,sum
    }END{
        size = length(city)
        rnd = int(rand() * size) + 1
        diff = total - sum

        for(i=1;i<=size;i++){
            split(city[i],arr," ")
            if(i == rnd){
                cnt = arr[2] + diff
            }else{
                cnt = arr[2]
            }
            if(cnt > 0){
                acc += cnt
                pacc = acc - cnt
                printf("%s\t%d,%d\n",arr[1],pacc+1,acc)
            }
        }
    }' total=$total_new
}

# 生成一天新增
function gen_new1()
{
    local max_id=0
    if [[ -s $FILE_MAXID ]]; then
        max_id=`cat $FILE_MAXID`
    fi

    # 按渠道新增量分配ID
    get_add_count | awk -F '\t' 'BEGIN{
        OFS=FS
    }{
        for(i=0;i<$2;i++){
            print ++id,$1
        }
    }' id=$max_id > $file_new1

    local total_new=`cat $file_new1 | wc -l`

    # 按地区占比分配地区
    range_city | tee $file_city_rng | while read city range; do
        sed -n "$range p" $file_new1 | awk -F '\t' 'BEGIN{OFS=FS}{print $0,"'$city'"}'
    done > $file_new

    # 更新最大id
    if [[ -s $file_new ]]; then
        log "Current max android id: $max_id"
        tail -n 1 $file_new | cut -f 1 > $FILE_MAXID
        log "Update max android id to `cat $FILE_MAXID`"
    fi
}

# 生成新增
function gen_new()
{
    local file_new1=$tmp_dir/new1
    local file_new2=$tmp_dir/new2
    local file_new3=$tmp_dir/new3
    local file_city_rng=$tmp_dir/city_range

    range_date $start_date $end_date | while read the_date; do
        # 生成一天新增
        log "Generate new for day $the_date"
        file_new=$data_dir/new.$the_date
        gen_new1
    done

    # 删除临时文件
    if [[ ! $debug_flag ]]; then
        rm -f $file_new1 $file_new2 $file_new3 $file_city_rng
    fi
}

# 导入数据
function load_data()
{
    # 创建表
    echo "CREATE TABLE IF NOT EXISTS $tbl_fact_new (
      id BIGINT(20),
      channel_code VARCHAR(50),
      area VARCHAR(50),
      create_date INT,
      PRIMARY KEY(id),
      KEY idx_channel_code (channel_code),
      KEY idx_area (area),
      KEY idx_create_date (create_date)
    ) ENGINE=MyISAM COMMENT='新增事实表';
    " | exec_dw

    # 如果数据已经生成，先删除
    echo "DELETE FROM $tbl_fact_new WHERE create_date >= $start_date AND create_date <=$end_date;" | exec_dw

    # 禁用索引
    echo "ALTER TABLE $tbl_fact_new DISABLE KEYS;" | exec_dw

    # 按天导入
    range_date $start_date $end_date | while read the_date; do
        the_file=$data_dir/new.$the_date
        if [[ -s $the_file ]]; then
            log "Load file $the_file"
            echo "LOAD DATA LOCAL INFILE '$the_file' INTO TABLE $tbl_fact_new (id, channel_code, area) SET create_date = ${the_date//-/};" | exec_dw
        fi
    done

    # 启用索引
    echo "ALTER TABLE $tbl_fact_new ENABLE KEYS;" | exec_dw
}

# 聚合数据
function agg_data()
{
    echo "CREATE TABLE IF NOT EXISTS ${tp_agg_new}l_01 (
      create_date INT,
      fact_count INT,
      PRIMARY KEY(create_date)
    ) ENGINE=MyISAM;
    REPLACE INTO ${tp_agg_new}l_01
    SELECT create_date, COUNT(1)
    FROM $tbl_fact_new
    WHERE create_date >= ${start_date//-/} AND create_date <= ${end_date//-/}
    GROUP BY create_date;

    CREATE TABLE IF NOT EXISTS ${tp_agg_new}l_02 (
      create_date INT,
      channel_code VARCHAR(50),
      fact_count INT,
      PRIMARY KEY(create_date, channel_code)
    ) ENGINE=MyISAM;
    REPLACE INTO ${tp_agg_new}l_02
    SELECT create_date, channel_code, COUNT(1)
    FROM $tbl_fact_new
    WHERE create_date >= ${start_date//-/} AND create_date <= ${end_date//-/}
    GROUP BY create_date, channel_code;

    CREATE TABLE IF NOT EXISTS ${tp_agg_new}l_03 (
      create_date INT,
      area VARCHAR(50),
      fact_count INT,
      PRIMARY KEY(create_date, area)
    ) ENGINE=MyISAM;
    REPLACE INTO ${tp_agg_new}l_03
    SELECT create_date, area, COUNT(1)
    FROM $tbl_fact_new
    WHERE create_date >= ${start_date//-/} AND create_date <= ${end_date//-/}
    GROUP BY create_date, area;

    CREATE TABLE IF NOT EXISTS ${tp_agg_new}l_04 (
      create_date INT,
      channel_code VARCHAR(50),
      area VARCHAR(50),
      fact_count INT,
      PRIMARY KEY(create_date, channel_code, area)
    ) ENGINE=MyISAM;
    REPLACE INTO ${tp_agg_new}l_04
    SELECT create_date, channel_code, area, COUNT(1)
    FROM $tbl_fact_new
    WHERE create_date >= ${start_date//-/} AND create_date <= ${end_date//-/}
    GROUP BY create_date, channel_code, area;
    " | exec_dw
}

# 校验数据
function check_data()
{
    echo "TODO"
}

# 用法
function usage()
{
    echo "Usage: $0 [ -g generate data ] < -p product code > < -d start date[,end date] > [ -l load data ] [ -a aggregate data ] [ -c check data ] [ -v debug mode ]" >&2
}

function main()
{
    if [[ $# -lt 1 ]]; then
        usage
        exit 1
    fi

    while getopts "gp:d:lacv" opt; do
        case "$opt" in
            g)
                gen_flag=1;;
            p)
                product_code="$OPTARG";;
            d)
                args=(${OPTARG//,/ })
                start_date=${args[0]}
                end_date=${args[1]:-$start_date};;
            l)
                load_flag=1;;
            a)
                agg_flag=1;;
            c)
                check_flag=1;;
            v)
                debug_flag=1;;
            ?)
                usage
                exit 1;;
        esac
    done

    if [[ -z "$product_code" || -z "$start_date" ]]; then
        usage
        exit 1
    fi

    # 出错立即退出
    set -e

    # 初始化
    log_fn init

    # 生成新增
    if [[ $gen_flag ]]; then
        log_fn gen_new
    fi

    # 导入数据
    if [[ $load_flag ]]; then
        log_fn load_data
    fi

    # 聚合数据
    if [[ $agg_flag ]]; then
        log_fn agg_data
    fi

    # 校验数据
    if [[ $check_flag ]]; then
        log_fn check_data
    fi
}
main "$@"