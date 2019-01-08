#!/bin/bash
#
# 根据新增和留存率生成活跃


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source $DIR/common.sh


# 留存率数据表
TBL_RETENTION_RATE=retention_rate

# 90日以后取留存天数
# 90~120 120~180 180~360 360~
RAND_DAYS=(30 45 60 120)


# 初始化
function init()
{
    # 统一日期格式
    start_date=`date +%F -d "$start_date"`
    end_date=`date +%F -d "$end_date"`

    data_dir=$DATA_DIR/$product_code
    tmp_dir=$TMP_DIR/$product_code
    mkdir -p $data_dir $tmp_dir

    # 留存率数据文件
    file_retention_rate=$DATA_DIR/retention_rate

    # 获取产品最早新增日期
    min_date=`echo "SELECT MIN(create_date) FROM $TBL_ADD_CNT WHERE product_code = '$product_code';" | exec_meta`

    # 活跃事实表
    tbl_fact_active=fact_active_$product_code
    # 活跃聚合表前缀
    tp_agg_active=${TP_AGG}active_${product_code}_

    export LC_ALL=C
    sep=`echo -e "\t"`
}

# 获取产品留存率
function get_retention_rate()
{
    if [[ ! -s $file_retention_rate ]]; then
        echo "SELECT product_code, rate1, rate2, rate3, rate4, rate5, rate6, rate7, rate14, rate30, rate60, rate0, rate90, rate180, rate360 FROM $TBL_RETENTION_RATE;
        " | exec_meta > $file_retention_rate
    fi

    awk -F '\t' '$1 == "'$product_code'" {
        for(i=2;i<NF;i++){
            printf("%s ",$i)
        }
        printf("%s",$NF)
    }' $file_retention_rate
}

# 随机日期
function rand_days()
{
    if [[ $date_diff -le 90 ]]; then
        range_date $min_date $date60 | sed '$d'
    elif [[ $date_diff -le 120 ]]; then
        range_date $min_date $date60 | sed '$d' | grep -v "$date90" | awk -F '-' '{if(int($3) % 6 > 0) print $0}' | sort -R | head -n ${RAND_DAYS[0]}
        echo $date90
    elif [[ $date_diff -le 180 ]]; then
        range_date $min_date $date60 | sed '$d' | grep -v "$date90" | awk -F '-' '{if(int($3) % 5 > 0) print $0}' | sort -R | head -n ${RAND_DAYS[1]}
        echo $date90
    elif [[ $date_diff -le 360 ]]; then
        range_date $min_date $date60 | sed '$d' | grep -Ev "$date90|$date180" | awk -F '-' '{if(int($3) % 4 > 0) print $0}' | sort -R | head -n ${RAND_DAYS[2]}
        echo $date90
        echo $date180
    else
        range_date $min_date $date60 | sed '$d' | grep -Ev "$date90|$date180|$date360" | awk -F '-' '{if(int($3) % 3 > 0) print $0}' | sort -R | head -n ${RAND_DAYS[3]}
        echo $date90
        echo $date180
        echo $date360
    fi
}

# 生成一天活跃
function gen_active1()
{
    local date1=`date +%F -d "$the_date 1 day ago"`
    local date2=`date +%F -d "$the_date 2 day ago"`
    local date3=`date +%F -d "$the_date 3 day ago"`
    local date4=`date +%F -d "$the_date 4 day ago"`
    local date5=`date +%F -d "$the_date 5 day ago"`
    local date6=`date +%F -d "$the_date 6 day ago"`
    local date7=`date +%F -d "$the_date 7 day ago"`
    local date14=`date +%F -d "$the_date 14 day ago"`
    local date30=`date +%F -d "$the_date 30 day ago"`
    local date60=`date +%F -d "$the_date 60 day ago"`
    local date90=`date +%F -d "$the_date 90 day ago"`
    local date180=`date +%F -d "$the_date 180 day ago"`
    local date360=`date +%F -d "$the_date 360 day ago"`
    log "date1=$date1, date7=$date7, date14=$date14, date30=$date30, date60=$date60, date90=$date90, date180=$date180, date360=$date360"

    local date_diff=`echo "$min_date $the_date" | awk '{
        gsub("-"," ",$1)
        gsub("-"," ",$2)
        date1 = mktime($1" 00 00 00")
        date2 = mktime($2" 00 00 00")
        date_diff = (date2 - date1) / 86400
        print date_diff
    }'`
    log "min_date=$min_date, date_diff=$date_diff"

    # 当天新增
    if [[ -s $data_dir/new.$the_date ]]; then
        cp -f $data_dir/new.$the_date $file_active
    else
        > $file_active
    fi

    if [[ $pre_run -eq 1 ]]; then
        pre_data=`wc -l $file_active | awk '{print $1}'`
    fi

    # 产品留存率
    local retention_rate=(`get_retention_rate`)

    # 次日留存
    if [[ $date_diff -ge 1 && -s $data_dir/new.$date1 ]]; then
        local total=`cat $data_dir/new.$date1 | wc -l`
        local count=`echo ${retention_rate[0]} $total | awk 'BEGIN{
            srand()
        }{
            split($1,arr,"+")
            rnd = int(rand() * (arr[2] + 1))
            cnt = int($2 * (arr[1] + rnd) / 1000 + 0.5)
            print cnt
        }'`
        if [[ $pre_run -eq 1 ]]; then
            pre_data="$pre_data\t$count"
        else
            local rand_count=`echo $total ${retention_rate[0]} $rand0 | awk '{print int($1 * ($2 + $3) / 1000)}'`
            log "keep1=${retention_rate[0]}, total=$total, count=$count, rand_count=$rand_count"
            head -n $rand_count $data_dir/new.$date1 | sort -R | head -n $count >> $file_active
        fi
    else
        if [[ $pre_run -eq 1 ]]; then
            pre_data="$pre_data\t0"
        fi
    fi

    # 2日留存
    if [[ $date_diff -ge 2 && -s $data_dir/new.$date2 ]]; then
        local total=`cat $data_dir/new.$date2 | wc -l`
        local count=`echo ${retention_rate[1]} $total | awk 'BEGIN{
            srand()
        }{
            split($1,arr,"+")
            rnd = int(rand() * (arr[2] + 1))
            cnt = int($2 * (arr[1] + rnd) / 1000 + 0.5)
            print cnt
        }'`
        if [[ $pre_run -eq 1 ]]; then
            pre_data="$pre_data\t$count"
        else
            local rand_count=`echo $total ${retention_rate[1]} $rand0 | awk '{print int($1 * ($2 + $3) / 1000)}'`
            log "keep2=${retention_rate[1]}, total=$total, count=$count, rand_count=$rand_count"
            head -n $rand_count $data_dir/new.$date2 | sort -R | head -n $count >> $file_active
        fi
    else
        if [[ $pre_run -eq 1 ]]; then
            pre_data="$pre_data\t0"
        fi
    fi

    # 3日留存
    if [[ $date_diff -ge 3 && -s $data_dir/new.$date3 ]]; then
        local total=`cat $data_dir/new.$date3 | wc -l`
        local count=`echo ${retention_rate[2]} $total | awk 'BEGIN{
            srand()
        }{
            split($1,arr,"+")
            rnd = int(rand() * (arr[2] + 1))
            cnt = int($2 * (arr[1] + rnd) / 1000 + 0.5)
            print cnt
        }'`
        if [[ $pre_run -eq 1 ]]; then
            pre_data="$pre_data\t$count"
        else
            local rand_count=`echo $total ${retention_rate[2]} $rand0 | awk '{print int($1 * ($2 + $3) / 1000)}'`
            log "keep3=${retention_rate[2]}, total=$total, count=$count, rand_count=$rand_count"
            head -n $rand_count $data_dir/new.$date3 | sort -R | head -n $count >> $file_active
        fi
    else
        if [[ $pre_run -eq 1 ]]; then
            pre_data="$pre_data\t0"
        fi
    fi

    # 4日留存
    if [[ $date_diff -ge 4 && -s $data_dir/new.$date4 ]]; then
        local total=`cat $data_dir/new.$date4 | wc -l`
        local count=`echo ${retention_rate[3]} $total | awk 'BEGIN{
            srand()
        }{
            split($1,arr,"+")
            rnd = int(rand() * (arr[2] + 1))
            cnt = int($2 * (arr[1] + rnd) / 1000 + 0.5)
            print cnt
        }'`
        if [[ $pre_run -eq 1 ]]; then
            pre_data="$pre_data\t$count"
        else
            local rand_count=`echo $total ${retention_rate[3]} $rand0 | awk '{print int($1 * ($2 + $3) / 1000)}'`
            log "keep4=${retention_rate[3]}, total=$total, count=$count, rand_count=$rand_count"
            head -n $rand_count $data_dir/new.$date4 | sort -R | head -n $count >> $file_active
        fi
    else
        if [[ $pre_run -eq 1 ]]; then
            pre_data="$pre_data\t0"
        fi
    fi

    # 5日留存
    if [[ $date_diff -ge 5 && -s $data_dir/new.$date5 ]]; then
        local total=`cat $data_dir/new.$date5 | wc -l`
        local count=`echo ${retention_rate[4]} $total | awk 'BEGIN{
            srand()
        }{
            split($1,arr,"+")
            rnd = int(rand() * (arr[2] + 1))
            cnt = int($2 * (arr[1] + rnd) / 1000 + 0.5)
            print cnt
        }'`
        if [[ $pre_run -eq 1 ]]; then
            pre_data="$pre_data\t$count"
        else
            local rand_count=`echo $total ${retention_rate[4]} $rand0 | awk '{print int($1 * ($2 + $3) / 1000)}'`
            log "keep5=${retention_rate[4]}, total=$total, count=$count, rand_count=$rand_count"
            head -n $rand_count $data_dir/new.$date5 | sort -R | head -n $count >> $file_active
        fi
    else
        if [[ $pre_run -eq 1 ]]; then
            pre_data="$pre_data\t0"
        fi
    fi

    # 6日留存
    if [[ $date_diff -ge 6 && -s $data_dir/new.$date6 ]]; then
        local total=`cat $data_dir/new.$date6 | wc -l`
        local count=`echo ${retention_rate[5]} $total | awk 'BEGIN{
            srand()
        }{
            split($1,arr,"+")
            rnd = int(rand() * (arr[2] + 1))
            cnt = int($2 * (arr[1] + rnd) / 1000 + 0.5)
            print cnt
        }'`
        if [[ $pre_run -eq 1 ]]; then
            pre_data="$pre_data\t$count"
        else
            local rand_count=`echo $total ${retention_rate[5]} $rand0 | awk '{print int($1 * ($2 + $3) / 1000)}'`
            log "keep6=${retention_rate[5]}, total=$total, count=$count, rand_count=$rand_count"
            head -n $rand_count $data_dir/new.$date6 | sort -R | head -n $count >> $file_active
        fi
    else
        if [[ $pre_run -eq 1 ]]; then
            pre_data="$pre_data\t0"
        fi
    fi

    # 7日留存
    if [[ $date_diff -ge 7 && -s $data_dir/new.$date7 ]]; then
        local total=`cat $data_dir/new.$date7 | wc -l`
        local count=`echo ${retention_rate[6]} $total | awk 'BEGIN{
            srand()
        }{
            split($1,arr,"+")
            rnd = int(rand() * (arr[2] + 1))
            cnt = int($2 * (arr[1] + rnd) / 1000 + 0.5)
            print cnt
        }'`
        if [[ $pre_run -eq 1 ]]; then
            pre_data="$pre_data\t$count"
        else
            local rand_count=`echo $total ${retention_rate[6]} $rand0 | awk '{print int($1 * ($2 + $3) / 1000)}'`
            log "keep7=${retention_rate[6]}, total=$total, count=$count, rand_count=$rand_count"
            head -n $rand_count $data_dir/new.$date7 | sort -R | head -n $count >> $file_active
        fi
    else
        if [[ $pre_run -eq 1 ]]; then
            pre_data="$pre_data\t0"
        fi
    fi

    # 8-14日留存
    if [[ $date_diff -ge 8 ]]; then
        local date8=$date14
        if [[ $min_date > $date14 ]]; then
            date8=$min_date
        fi
        range_date $date8 $date7 | sed '$d' | while read the_date1; do
            if [[ -s $data_dir/new.$the_date1 ]]; then
                total=`cat $data_dir/new.$the_date1 | wc -l`
                count=`echo $total ${retention_rate[7]} $rand0 | awk '{print int($1 * ($2 + $3) / 1000)}'`
                awk -F '\t' 'BEGIN{
                    OFS=FS
                }{
                    ok=0
                    if(NR < count) ok=1
                    print ok,$0
                }' count=$count $data_dir/new.$the_date1
            fi
        done > $file_active1

        local total=`cat $file_active1 | wc -l`
        local count=`echo ${retention_rate[7]} $total | awk 'BEGIN{
            srand()
        }{
            split($1,arr,"+")
            rnd = int(rand() * (arr[2] + 1))
            cnt = int($2 * (arr[1] + rnd) / 1000 + 0.5)
            print cnt
        }'`
        if [[ $pre_run -eq 1 ]]; then
            pre_data="$pre_data\t$count"
        else
            local rand_count=`echo $total ${retention_rate[7]} $rand0 | awk '{print int($1 * ($2 + $3) / 1000)}'`
            log "keep14=${retention_rate[7]}, total=$total, count=$count, rand_count=$rand_count"
            awk -F '\t' 'BEGIN{OFS=FS} $1 == 1 {print $2,$3,$4}' $file_active1 | head -n $rand_count | sort -R | head -n $count >> $file_active
        fi
    else
        if [[ $pre_run -eq 1 ]]; then
            pre_data="$pre_data\t0"
        fi
    fi

    # 15-30日留存
    if [[ $date_diff -ge 15 ]]; then
        local date15=$date30
        if [[ $min_date > $date30 ]]; then
            date15=$min_date
        fi
        range_date $date15 $date14 | sed '$d' | while read the_date1; do
            if [[ -s $data_dir/new.$the_date1 ]]; then
                total=`cat $data_dir/new.$the_date1 | wc -l`
                count=`echo $total ${retention_rate[8]} $rand0 | awk '{print int($1 * ($2 + $3) / 1000)}'`
                awk -F '\t' 'BEGIN{
                    OFS=FS
                }{
                    ok=0
                    if(NR < count) ok=1
                    print ok,$0
                }' count=$count $data_dir/new.$the_date1
            fi
        done > $file_active1

        local total=`cat $file_active1 | wc -l`
        local count=`echo ${retention_rate[8]} $total | awk 'BEGIN{
            srand()
        }{
            split($1,arr,"+")
            rnd = int(rand() * (arr[2] + 1))
            cnt = int($2 * (arr[1] + rnd) / 1000 + 0.5)
            print cnt
        }'`
        if [[ $pre_run -eq 1 ]]; then
            pre_data="$pre_data\t$count"
        else
            local rand_count=`echo $total ${retention_rate[8]} $rand0 | awk '{print int($1 * ($2 + $3) / 1000)}'`
            log "keep30=${retention_rate[8]}, total=$total, count=$count, rand_count=$rand_count"
            awk -F '\t' 'BEGIN{OFS=FS} $1 == 1 {print $2,$3,$4}' $file_active1 | head -n $rand_count | sort -R | head -n $count >> $file_active
        fi
    else
        if [[ $pre_run -eq 1 ]]; then
            pre_data="$pre_data\t0"
        fi
    fi

    # 31-60日留存
    if [[ $date_diff -ge 31 ]]; then
        local date31=$date60
        if [[ $min_date > $date60 ]]; then
            date31=$min_date
        fi
        range_date $date31 $date30 | sed '$d' | while read the_date1; do
            if [[ -s $data_dir/new.$the_date1 ]]; then
                total=`cat $data_dir/new.$the_date1 | wc -l`
                count=`echo $total ${retention_rate[9]} $rand0 | awk '{print int($1 * ($2 + $3) / 1000)}'`
                awk -F '\t' 'BEGIN{
                    OFS=FS
                }{
                    ok=0
                    if(NR < count) ok=1
                    print ok,$0
                }' count=$count $data_dir/new.$the_date1
            fi
        done > $file_active1

        local total=`cat $file_active1 | wc -l`
        local count=`echo ${retention_rate[9]} $total | awk 'BEGIN{
            srand()
        }{
            split($1,arr,"+")
            rnd = int(rand() * (arr[2] + 1))
            cnt = int($2 * (arr[1] + rnd) / 1000 + 0.5)
            print cnt
        }'`
        if [[ $pre_run -eq 1 ]]; then
            pre_data="$pre_data\t$count"
        else
            local rand_count=`echo $total ${retention_rate[9]} $rand0 | awk '{print int($1 * ($2 + $3) / 1000)}'`
            log "keep60=${retention_rate[9]}, total=$total, count=$count, rand_count=$rand_count"
            awk -F '\t' 'BEGIN{OFS=FS} $1 == 1 {print $2,$3,$4}' $file_active1 | head -n $rand_count | sort -R | head -n $count >> $file_active
        fi
    else
        if [[ $pre_run -eq 1 ]]; then
            pre_data="$pre_data\t0"
        fi
    fi

    # 60~日留存
    if [[ $date_diff -ge 61 ]]; then
        rand_days | grep -Ev "$date90|$date180|$date360" | while read the_date1; do
            if [[ -s $data_dir/new.$the_date1 ]]; then
                total=`cat $data_dir/new.$the_date1 | wc -l`
                count=`echo $total ${retention_rate[10]} $rand0 | awk '{print int($1 * ($2 + $3) / 1000)}'`
                awk -F '\t' 'BEGIN{
                    OFS=FS
                }{
                    ok=0
                    if(NR < count) ok=1
                    print ok,$0
                }' count=$count $data_dir/new.$the_date1
            fi
        done > $file_active1

        local total=`cat $file_active1 | wc -l`
        local count=`echo ${rate0:-${retention_rate[10]}} $total | awk 'BEGIN{
            srand()
        }{
            split($1,arr,"+")
            rnd = int(rand() * (arr[2] + 1))
            cnt = int($2 * (arr[1] + rnd) / 1000 + 0.5)
            print cnt
        }'`
        if [[ $pre_run -eq 1 ]]; then
            pre_data="$pre_data\t$count"
            echo -e "$prod_name\t${the_date//-/}\t$pre_data" >> $file_prerun
        else
            local rand_count=`echo $total ${retention_rate[10]} $rand0 | awk '{print int($1 * ($2 + $3) / 1000)}'`
            log "keep0=${rate0:-${retention_rate[10]}}, total=$total, count=$count, rand_count=$rand_count"
            awk -F '\t' 'BEGIN{OFS=FS} $1 == 1 {print $2,$3,$4}' $file_active1 | head -n $rand_count | sort -R | head -n $count >> $file_active
        fi
    else
        if [[ $pre_run -eq 1 ]]; then
            pre_data="$pre_data\t0"
            echo -e "$prod_name\t${the_date//-/}\t$pre_data" >> $file_prerun
        fi
    fi

    # 90日留存
    if [[ $date_diff -ge 90 && -s $data_dir/new.$date90 ]]; then
        local total=`cat $data_dir/new.$date90 | wc -l`
        local count=`echo ${retention_rate[11]} $total | awk 'BEGIN{
            srand()
        }{
            split($1,arr,"+")
            rnd = int(rand() * (arr[2] + 1))
            cnt = int($2 * (arr[1] + rnd) / 1000 + 0.5)
            print cnt
        }'`
        if [[ $pre_run -eq 1 ]]; then
            pre_data="$pre_data\t$count"
        else
            local rand_count=`echo $total ${retention_rate[11]} $rand0 | awk '{print int($1 * ($2 + $3) / 1000)}'`
            log "keep90=${retention_rate[11]}, total=$total, count=$count, rand_count=$rand_count"
            head -n $rand_count $data_dir/new.$date90 | sort -R | head -n $count >> $file_active
        fi
    else
        if [[ $pre_run -eq 1 ]]; then
            pre_data="$pre_data\t0"
        fi
    fi

    # 180日留存
    if [[ $date_diff -ge 180 && -s $data_dir/new.$date180 ]]; then
        local total=`cat $data_dir/new.$date180 | wc -l`
        local count=`echo ${retention_rate[12]} $total | awk 'BEGIN{
            srand()
        }{
            split($1,arr,"+")
            rnd = int(rand() * (arr[2] + 1))
            cnt = int($2 * (arr[1] + rnd) / 1000 + 0.5)
            print cnt
        }'`
        if [[ $pre_run -eq 1 ]]; then
            pre_data="$pre_data\t$count"
        else
            local rand_count=`echo $total ${retention_rate[12]} $rand0 | awk '{print int($1 * ($2 + $3) / 1000)}'`
            log "keep180=${retention_rate[12]}, total=$total, count=$count, rand_count=$rand_count"
            head -n $rand_count $data_dir/new.$date180 | sort -R | head -n $count >> $file_active
        fi
    else
        if [[ $pre_run -eq 1 ]]; then
            pre_data="$pre_data\t0"
        fi
    fi

    # 360日留存
    if [[ $date_diff -ge 360 && -s $data_dir/new.$date360 ]]; then
        local total=`cat $data_dir/new.$date360 | wc -l`
        local count=`echo ${retention_rate[13]} $total | awk 'BEGIN{
            srand()
        }{
            split($1,arr,"+")
            rnd = int(rand() * (arr[2] + 1))
            cnt = int($2 * (arr[1] + rnd) / 1000 + 0.5)
            print cnt
        }'`
        if [[ $pre_run -eq 1 ]]; then
            pre_data="$pre_data\t$count"
        else
            local rand_count=`echo $total ${retention_rate[13]} $rand0 | awk '{print int($1 * ($2 + $3) / 1000)}'`
            log "keep360=${retention_rate[13]}, total=$total, count=$count, rand_count=$rand_count"
            head -n $rand_count $data_dir/new.$date360 | sort -R | head -n $count >> $file_active
        fi
    else
        if [[ $pre_run -eq 1 ]]; then
            pre_data="$pre_data\t0"
        fi
    fi
}

# 生成活跃
function gen_active()
{
    local file_active1=$TMP_DIR/$product_code/active1

    # 预跑模式
    if [[ $pre_run -eq 1 ]]; then
        file_prerun=$data_dir/pre_data.${start_date}-$end_date
        > $file_prerun
    fi

    range_date $start_date $end_date | while read the_date; do
        # 生成一天活跃
        log "Generate active for day $the_date"
        file_active=$data_dir/active.$the_date
        gen_active1
    done

    # 删除临时文件
    if [[ ! $debug_flag ]]; then
        rm -f $file_active1
    fi
}

# 导入数据
function load_data()
{
    local file_new=$tmp_dir/new
    local file_active=$tmp_dir/active

    # 合并截止开始日期前一天的新增
    local start_date1=`date +%F -d "$start_date"`
    rm -f $file_new
    ls $data_dir/new.201* | sed "/$start_date1/Q" | while read the_file; do
        the_date=${the_file##*.}
        awk 'BEGIN{
            OFS="\t"
        }{
            print $1,"'${the_date//-/}'"
        }' $the_file >> $file_new
    done

    echo "CREATE TABLE IF NOT EXISTS $tbl_fact_active (
      id BIGINT(20),
      channel_code VARCHAR(50),
      area VARCHAR(50),
      active_date INT,
      create_date INT,
      date_diff INT,
      PRIMARY KEY(id, active_date),
      KEY idx_channel_code (channel_code),
      KEY idx_area (area),
      KEY idx_active_date (active_date),
      KEY idx_create_date (create_date),
      KEY idx_date_diff (date_diff)
    ) ENGINE=MyISAM COMMENT='活跃事实表';
    " | exec_dw

    # 如果数据已经生成，先删除
    echo "DELETE FROM $tbl_fact_active WHERE active_date >= $start_date AND active_date <=$end_date;" | exec_dw

    # 禁用索引
    echo "ALTER TABLE $tbl_fact_active DISABLE KEYS;" | exec_dw

    # 按天装载活跃
    range_date $start_date $end_date | while read the_date; do
        the_file=$data_dir/active.$the_date
        log "Load file $the_file"

        # 合并当天新增
        if [[ -s $data_dir/new.$the_date ]]; then
            awk 'BEGIN{
                OFS="\t"
            }{
                print $1,"'${the_date//-/}'"
            }' $data_dir/new.$the_date >> $file_new
        fi

        # 排序
        sort $file_new -o $file_new
        sort $the_file -o $the_file

        # 关联新增得到新增日期
        join -t "$sep" $the_file $file_new > $file_active

        echo "LOAD DATA LOCAL INFILE '$file_active' INTO TABLE $tbl_fact_active (id, channel_code, area, create_date, active_date, date_diff)
          SET active_date = ${the_date//-/}, date_diff = DATEDIFF(${the_date//-/}, create_date);
        " | exec_dw
    done

    # 启用索引
    echo "ALTER TABLE $tbl_fact_active ENABLE KEYS;" | exec_dw

    # 删除临时文件
    if [[ ! $debug_flag ]]; then
        rm -f $file_new $file_active
    fi
}

# 聚合数据
function agg_data()
{
    # 创建聚合表
    echo "CREATE TABLE IF NOT EXISTS ${tp_agg_active}l_1 (
      active_date INT,
      create_date INT,
      date_diff INT,
      fact_count INT,
      PRIMARY KEY(active_date, create_date)
    ) ENGINE=MyISAM;

    CREATE TABLE IF NOT EXISTS ${tp_agg_active}l_2 (
      active_date INT,
      create_date INT,
      date_diff INT,
      channel_code VARCHAR(50),
      fact_count INT,
      PRIMARY KEY(active_date, create_date, channel_code)
    ) ENGINE=MyISAM;

    CREATE TABLE IF NOT EXISTS ${tp_agg_active}l_3 (
      active_date INT,
      create_date INT,
      date_diff INT,
      area VARCHAR(50),
      fact_count INT,
      PRIMARY KEY(active_date, create_date, area)
    ) ENGINE=MyISAM;

    CREATE TABLE IF NOT EXISTS ${tp_agg_active}l_4 (
      active_date INT,
      create_date INT,
      date_diff INT,
      channel_code VARCHAR(50),
      area VARCHAR(50),
      fact_count INT,
      PRIMARY KEY(active_date, create_date, channel_code, area)
    ) ENGINE=MyISAM;
    " | exec_dw

    # 聚合数据
    local filter="active_date >= ${start_date//-/} AND active_date <= ${end_date//-/}"
    echo "DELETE FROM ${tp_agg_active}l_1 WHERE $filter;
    INSERT INTO ${tp_agg_active}l_1
    SELECT active_date, create_date, date_diff, COUNT(1) FROM $tbl_fact_active WHERE $filter GROUP BY active_date, create_date;

    DELETE FROM ${tp_agg_active}l_2 WHERE $filter;
    INSERT INTO ${tp_agg_active}l_2
    SELECT active_date, create_date, date_diff, channel_code, COUNT(1) FROM $tbl_fact_active WHERE $filter GROUP BY active_date, create_date, channel_code;

    DELETE FROM ${tp_agg_active}l_3 WHERE $filter;
    INSERT INTO ${tp_agg_active}l_3
    SELECT active_date, create_date, date_diff, area, COUNT(1) FROM $tbl_fact_active WHERE $filter GROUP BY active_date, create_date, area;

    DELETE FROM ${tp_agg_active}l_4 WHERE $filter;
    INSERT INTO ${tp_agg_active}l_4
    SELECT active_date, create_date, date_diff, channel_code, area, COUNT(1) FROM $tbl_fact_active WHERE $filter GROUP BY active_date, create_date, channel_code, area;
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
    echo "Usage: $0 [ -g generate data ] < -p product code > < -d start date[,end date] > [ -f floating value ] [ -r specify new rate0 ] [ -t prerun mode ] [ -l load data ] [ -a aggregate data ] [ -c check data ] [ -v debug mode ]" >&2
}

function main()
{
    if [[ $# -lt 1 ]]; then
        usage
        exit 1
    fi

    while getopts "gp:d:f:r:tlacv" opt; do
        case "$opt" in
            g)
                gen_flag=1;;
            p)
                product_code="$OPTARG";;
            d)
                args=(${OPTARG//,/ })
                start_date=${args[0]}
                end_date=${args[1]:-$start_date};;
            f)
                rand0=$OPTARG;;
            r)
                rate0=$OPTARG;;
            t)
                pre_run=1;;
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

    # 生成活跃
    if [[ $gen_flag ]]; then
        log_fn gen_active
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