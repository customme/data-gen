#!/bin/bash
#
# 随机生成不重复的Android ID


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source $DIR/common.sh


# 初始化
function init()
{
    # 创建目录
    mkdir -p $DATA_DIR $TMP_DIR

    # 增量Android ID数据文件
    file_aid=${FILE_AID}.incr
}

# 随机生成Android ID
# num 个数
# 例如生成100个: rand_aid 100
function rand_aid()
{
    echo "$@" | awk 'BEGIN{
        srand()

        # 初始化字符数组
        for(i=0;i<=9;i++){
            x[i]=i
        }
        x[10]="a"
        x[11]="b"
        x[12]="c"
        x[13]="d"
        x[14]="e"
        x[15]="f"
        size=length(x)
    }{
        num=$1
        for(i=0;i<num;i++){
            # 生成首位字符
            a = int(rand() * (size - 1)) + 1
            str = x[a]

            # 按比例随机15或16位(6%为15位)
            c = int(rand() * 100)
            if(c < 6){
                digit = 15
            }else{
                digit = 16
            }

            # 生成其余字符
            for(j=1;j<digit;j++){
                b = int(rand() * size)
                str = str""x[b]
            }
            print str
        }
    }'
}

# 一、随机生成Android ID和连续ID
# 生成规则:
# 1、随机字符由[0-9][a-f]组成
# 2、字符串首位字符由[1-9][a-f]组成
# 3、字符串长度为16位占94%，15位占6%
# 4、id为连续正整数
function gen_aid()
{
    local file_aid1=$TMP_DIR/android_ids1
    local file_aid2=$TMP_DIR/android_ids2
    local file_aid3=$TMP_DIR/android_ids3

    # 生成新Android ID
    log "Generate new android id $gen_num begin"
    rand_aid $gen_num > $file_aid1
    log "Generate new android id $gen_num end"

    local max_id=0
    if [[ -s $FILE_AID ]]; then
        # 排序
        sort -u $file_aid1 -o $file_aid1
        sort -k 2 $FILE_AID > $file_aid2
        # 去重
        join -v 1 -2 2 $file_aid1 $file_aid2 > $file_aid3

        # 获取最大id
        max_id=`awk '{print $1}' $FILE_AID | sort -n | tail -n 1`
    else
        sort -u $file_aid1 > $file_aid3
    fi

    local count=`wc -l $file_aid3 | awk '{print $1}'`
    # 循环生成直到满足指定个数gen_num为止
    while [[ $count -lt $gen_num ]]; do
        log "Generated duplicate android id, regenerate new android id"
        rand_aid $((gen_num - count)) > $file_aid1

        cat $file_aid3 >> $file_aid2

        sort -u $file_aid1 -o $file_aid1
        sort -u $file_aid2 -o $file_aid2

        join -v 1 -2 2 $file_aid1 $file_aid2 >> $file_aid3
        count=`wc -l $file_aid3 | awk '{print $1}'`
    done

    # 打乱顺序
    # 生成连续id
    log "Disrupt the order and generate sequential id"
    awk 'BEGIN{
        srand()
    }{
        printf("%s\t%s\n",$1,int(rand() * count * 2))
    }' count=$gen_num $file_aid3 |
    sort -k 2 |
    awk 'BEGIN{
        OFS="\t"
    }{
        print NR + id,$1
    }' id=$max_id > $file_aid

    # 合并aid
    cat $file_aid >> $FILE_AID

    # 排序android id
    log "Sort android id"
    sort $FILE_AID -o $FILE_AID

    # 非debug模式删除临时文件
    if [[ ! $debug_flag ]]; then
        rm -f $file_aid1 $file_aid2 $file_aid3
    fi
}

# 导入数据
function load_data()
{
    log "Load Android ID into table: $TBL_AID"
    echo "CREATE TABLE IF NOT EXISTS $TBL_AID (
      id BIGINT,
      aid VARCHAR(16)
    );
    LOAD DATA LOCAL INFILE '$file_aid' INTO TABLE $TBL_AID;
    " | exec_meta
}

# 校验数据
function check_data()
{
    if [[ $gen_num -gt 0 ]]; then
        log "Check incremental data"
        # 个数是否一致
        local count=`wc -l $file_aid | awk '{print $1}'`
        if [[ $gen_num -ne $count ]]; then
            log "ERROR: Android ID number does not match"
        fi
        # ID是否重复
        local id_cnt=`awk '{print $1}' $file_aid | sort -u | wc -l`
        if [[ $gen_num -ne $id_cnt ]]; then
            log "ERROR: duplicate ID found"
        fi
        # Android ID是否重复
        local aid_cnt=`awk '{print $2}' $file_aid | sort -u | wc -l`
        if [[ $gen_num -ne $aid_cnt ]]; then
            log "ERROR: duplicate Android ID found"
        fi
    fi

    log "Check all data"
    local count=`wc -l $FILE_AID | awk '{print $1}'`
    local id_cnt=`awk '{print $1}' $FILE_AID | sort -u | wc -l`
    if [[ $count -ne $id_cnt ]]; then
        log "ERROR: duplicate ID found"
    fi
    local aid_cnt=`awk '{print $2}' $FILE_AID | sort -u | wc -l`
    if [[ $count -ne $aid_cnt ]]; then
        log "ERROR: duplicate Android ID found"
    fi
}

# 用法
function usage()
{
    echo "Usage: $0 [ -n the number to generate ] [ -l load data ] [ -c check data ] [ -v debug mode ]" >&2
}

function main()
{
    if [[ $# -lt 1 ]]; then
        usage
        exit 1
    fi

    while getopts "n:lcv" opt; do
        case "$opt" in
            n)
                gen_num=$OPTARG;;
            l)
                load_flag=1;;
            c)
                check_flag=1;;
            v)
                debug_flag=1;;
            ?)
                usage
                exit 1;;
        esac
    done

    # 出错立即退出
    set -e

    # 初始化
    log_fn init

    # 生成Android ID
    if [[ $gen_num -gt 0 ]]; then
        log_fn gen_aid
    fi

    # 导入数据
    if [[ $load_flag ]]; then
        log_fn load_data
    fi

    # 校验数据
    if [[ $check_flag ]]; then
        log_fn check_data
    fi
}
main "$@"