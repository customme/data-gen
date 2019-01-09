#!/bin/bash
#
# 根据产品占比分配广告激活量、展示量、点击量
# 从访问日志生成广告展示日志、点击日志、激活日志


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source $DIR/common.sh


# 广告收入表
TBL_AD_INCOME=ad_income
# 广告产品占比表
TBL_PRODUCT_RATE=product_rate
# 广告统计表
TBL_FACT_AD=fact_ad
# 活跃广告统计表
TBL_ACTIVE_AD=fact_active_ad

# 广告所包含产品
PRODS="adv_n,broswer_n,compass_n,file_n,light_n,qtext_n,recorder_n,search_n,space_n,sport_n,weather_n"


# 初始化
function init()
{
    mkdir -p $TMP_DIR

    # 广告收入数据文件
    file_ad_income=$DATA_DIR/ad_income.${start_date//-/}-${end_date//-/}
    # 广告产品占比数据文件
    file_product_rate=$DATA_DIR/product_rate.${start_date//-/}-${end_date//-/}
    # 广告量数据文件
    file_ad_count=$DATA_DIR/ad_count.${start_date//-/}-${end_date//-/}
    # 广告统计数据文件
    file_ad_stat=$DATA_DIR/ad_stat.${start_date//-/}-${end_date//-/}
    # 活跃广告统计数据文件
    file_active_ad=$DATA_DIR/active_ad.${start_date//-/}-${end_date//-/}

    # 获取广告收入
    get_ad_income

    # 获取广告产品占比
    get_product_rate
}

# 获取广告收入
function get_ad_income()
{
    if [[ ! -s $file_ad_income ]]; then
        log "Export ad income to file: $file_ad_income"
        echo "SELECT create_date, advertiser, ad_code, add_count, show_count, click_count, IF(area > '', area, NULL)
        FROM $TBL_AD_INCOME
        WHERE create_date >= '$start_date' AND create_date <= '$end_date';
        " | exec_meta > $file_ad_income
    fi
}

# 获取广告产品占比
function get_product_rate()
{
    if [[ ! -s $file_product_rate ]]; then
        log "Export ad product rate to file: $file_product_rate"
        echo "SELECT the_month, rate FROM $TBL_PRODUCT_RATE WHERE the_month >= '${start_date%-*}' AND the_month <= '${end_date%-*}';
        " | exec_meta > $file_product_rate
    fi
}

# 从数据库统计活跃占比
function stat_active()
{
    echo "SELECT product_code, user_count FROM fact_active_all WHERE active_date = ${the_date//-/};" | exec_dw |
    awk -F '\t' 'BEGIN{
        split("'$prods'",prod_arr,",")
    }{
        prod[$1]=$2
    }END{
        for(i=1;i<=length(prod_arr);i++){
            active_cnt = prod[prod_arr[i]]
            if(active_cnt > 0){
                print active_cnt
            }else{
                print 0
            }
        }
    }' | awk '{
        active_cnt[++i]=$1
        sum += $1
    }END{
        if(sum > 0){
            size = length(active_cnt)
            for(i=1;i<size;i++){
                printf("%s,",active_cnt[i] / sum)
            }
            printf("%s",active_cnt[size] / sum)
        }
    }'
}

# 从文件统计活跃占比
function stat_active()
{
    local arr_prod=(${prods//,/ })
    for product_code in ${arr_prod[@]}; do
        file_active=$DATA_DIR/$product_code/active.$the_date
        if [[ -s $file_active ]]; then
            wc -l $file_active | awk '{print $1}'
        else
            echo 0
        fi
    done | awk '{
        active_cnt[++i]=$1
        sum += $1
    }END{
        if(sum > 0){
            size = length(active_cnt)
            for(i=1;i<size;i++){
                printf("%s,",active_cnt[i] / sum)
            }
            printf("%s",active_cnt[size] / sum)
        }
    }'
}

# 分配广告激活量、展示量、点击量
function allot_ad()
{
    > $file_ad_count

    range_date $start_date $end_date | while read the_date; do
        # 广告产品占比
        the_month=${the_date:0:7}
        the_rate=`awk -F '\t' '$1 == "'$the_month'" {print $2}' $file_product_rate`
        # 如果没有指定占比，就用活跃占比
        if [[ -z "$the_rate" ]]; then
            log "Use active rate"
            prods="$PRODS"
            ad_rate=`stat_active`
        else
            log "Use preset rate"
            prods=`echo "$the_rate" | awk 'BEGIN{RS="[:,]"} NR % 2 == 1' | tr '\n' ',' | sed 's/,$//'`
            ad_rate=`echo "$the_rate" | awk 'BEGIN{RS="[:,]"} NR % 2 == 0 {printf("%s,",$1 / 100)}' | sed 's/,$//'`
        fi
        if [[ -z "$ad_rate" ]]; then
            log "WARN: invalid products rate" >&2
            continue
        fi
        log "Products rate: $prods $ad_rate"

        # 开始分配
        awk -F '\t' 'BEGIN{
            OFS=FS
            srand()

            split("'$prods'",arr_prod,",")
            split("'$ad_rate'",arr_pct,",")
        } $1 == "'$the_date'" {
            sum = 0
            sum1 = 0
            sum2 = 0
            for(i in arr_pct){
                arr_cnt[i] = int(arr_pct[i] * $4 + 0.5)
                sum += arr_cnt[i]
                arr_cnt1[i] = int(arr_pct[i] * $5 + 0.5)
                sum1 += arr_cnt1[i]
                arr_cnt2[i] = int(arr_pct[i] * $6 + 0.5)
                sum2 += arr_cnt2[i]
            }
            # 多减少加
            diff = $4 - sum
            for(i in arr_cnt){
                if(arr_cnt[i] > 0 && arr_cnt[i] + diff > 0){
                    arr_cnt[i] += diff
                    break
                }
            }
            diff1 = $5 -sum1
            for(i in arr_cnt1){
                if(arr_cnt1[i] > 0 && arr_cnt1[i] + diff1 > 0){
                    arr_cnt1[i] += diff1
                    break
                }
            }
            diff2 = $6 -sum2
            for(i in arr_cnt2){
                if(arr_cnt2[i] > 0 && arr_cnt2[i] + diff2 > 0){
                    arr_cnt2[i] += diff2
                    break
                }
            }
            # 最终激活量
            for(i in arr_cnt){
                if(arr_cnt1[i] > 0){
                    print $1,arr_prod[i],$2,$3,arr_cnt1[i],arr_cnt2[i],arr_cnt[i],$7
                }
            }
        }' $file_ad_income >> $file_ad_count
    done
}

# 生成一天的广告展示、点击、激活
function gen_ad1(){
    log "Get visit log"
    sed '/ 23:55/,$d' $file_visit | sort -t $'\t' -k 1,1 -u > $file_visit1

    # 补充访问日志
    log "Add visit log"
    local visit_count=`wc -l $file_visit1 | awk '{print $1}'`
    local max_count=`awk '$1 == "'$the_date'" && $2 == "'$product_code'" {print $5}' $file_ad_count | sort -nr | head -n 1`
    local diff_count=`expr $max_count - $visit_count`
    if [[ $diff_count -gt 0 ]]; then
        log "Add visit log $diff_count"
        cp -f $file_visit1 $file_visit2
        local mom_count=`expr $diff_count / $visit_count`
        local mod_count=`expr $diff_count % $visit_count`
        for i in `seq $mom_count`; do
            cat $file_visit1 >> $file_visit2
        done
        if [[ $mod_count -gt 0 ]]; then
            sort -R $file_visit1 | head -n $mod_count >> $file_visit2
        fi
    else
        mv -f $file_visit1 $file_visit2
    fi

    log "Generate show click install log"
    oIFS=$IFS
    IFS=`echo -e "\t"`
    awk -F '\t' '$1 == "'$the_date'" && $2 == "'$product_code'"' $file_ad_count |
    while read the_date product_code advertiser ad_code show_cnt click_cnt install_cnt area; do
        if [[ "$area" != "NULL" ]]; then
            # 随机取一个地区
            area=`echo "$area" | awk -F ',' 'BEGIN{
                srand()
            }{
                rnd = int(rand() * NF + 1)
                print $rnd
            }'`
            # 随机获取地区100个ip段
            area_ips=`awk 'BEGIN{
                srand()
            } $1 == "'$area'" {
                split($2,arr,",")
                for(i in arr){
                    print arr[2],rand()
                }
            }' $FILE_IP |
            sort -k 2 | head -n 100 | awk '{printf("%s,",$1)}' | sed 's/,$//'`
            if [[ -z "$area_ips" ]]; then
                echo "WARN: can not find ip for area: $area {$the_date, $product_code, $advertiser, $ad_code}" >&2
            fi
        fi

        # 生成展示（展示时间 = 访问时间 + 60 ~ 180s）
        log "Generate show log"
        sort -R $file_visit2 | head -n $show_cnt | awk -F '\t' 'BEGIN{
            OFS=FS
            srand()
        }{
            if(NR == 1 && area != "NULL"){
                split(area_ips,ips_arr,",")
                size = length(ips_arr)
            }

            gsub(/-|:/," ",$5)
            time1 = mktime($5)
            time2 = time1 + int(rand() * (180 - 60 + 1) + 60)
            show_time = strftime("%Y-%m-%d %H:%M:%S",time2)

            # 替换地区 ip
            the_area = $3
            the_ip = $4
            if(area != "NULL" && $3 != area){
                # 取随机ip段
                i_ips = int(rand() * size + 1)
                ips = ips_arr[i_ips]

                # 从ip段随机取ip
                split(ips,ip_arr,":")
                diff = ip_arr[2] - ip_arr[1]
                ip = ip_arr[1] + int(rand() * (diff + 1))
                ipa = rshift(and(ip, 0xFF000000), 24)"."rshift(and(ip, 0xFF0000), 16)"."rshift(and(ip, 0xFF00), 8)"."and(ip, 0xFF)

                the_area = area
                the_ip = ipa
            }

            print $1,$2,the_area,the_ip,show_time,"'$advertiser'","'$ad_code'"
        }' area="$area" area_ips="$area_ips" > $file_show1

        # 生成点击（点击时间 = 展示时间 + 1 ~ 60s）
        log "Generate click log"
        sort -R $file_show1 | head -n $click_cnt | awk -F '\t' 'BEGIN{
            OFS=FS
            srand()
        }{
            gsub(/-|:/," ",$5)
            time1 = mktime($5)
            time2 = time1 + int(rand() * 60 + 1)
            click_time = strftime("%Y-%m-%d %H:%M:%S",time2)

            print $1,$2,$3,$4,click_time,"'$advertiser'","'$ad_code'"
        }' > $file_click1

        # 生成激活（激活时间 = 点击时间 + 1 ~ 60s）
        log "Generate install log"
        sort -R $file_click1 | head -n $install_cnt | awk -F '\t' 'BEGIN{
            OFS=FS
            srand()
        }{
            gsub(/-|:/," ",$5)
            time1 = mktime($5)
            time2 = time1 + int(rand() * 60 + 1)
            install_time = strftime("%Y-%m-%d %H:%M:%S",time2)

            print $1,$2,$3,$4,install_time,"'$advertiser'","'$ad_code'"
        }' >> $file_install

        cat $file_show1 >> $file_show
        cat $file_click1 >> $file_click
    done
    IFS=$oIFS

    # 按展示/点击/激活时间排序
    log "Sort by show time"
    sort -t $'\t' -k 5 $file_show -o $file_show
    log "Sort by click time"
    sort -t $'\t' -k 5 $file_click -o $file_click
    log "Sort by install time"
    sort -t $'\t' -k 5 $file_install -o $file_install
}

# 生成广告展示、点击、激活
function gen_ad(){
    file_visit1=$TMP_DIR/visit1
    file_visit2=$TMP_DIR/visit2
    file_show1=$TMP_DIR/show1
    file_click1=$TMP_DIR/click1

    range_date $start_date $end_date | while read the_date; do
        log "Gen ad for date: $the_date"

        the_month=${the_date:0:7}
        the_pct=`awk -F '\t' '$1 == "'$the_month'" {print $2}' $file_product_rate`
        if [[ -z "$the_pct" ]]; then
            arr_prod=(${PRODS//,/ })
        else
            prods=`echo "$the_pct" | awk 'BEGIN{RS="[:,]"} NR % 2 == 1' | tr '\n' ',' | sed 's/,$//'`
            arr_prod=(${prods//,/ })
        fi
        arr_prod=(${arr_prod[@]})

        for product_code in ${arr_prod[@]}; do
            if [[ `grep "^$the_date" $file_ad_count | grep "$product_code"` ]]; then
                file_visit=$DATA_DIR/$product_code/visit.$the_date
                if [[ -s $file_visit ]]; then
                    log "Gen ad for product: $product_code"
                    file_show=$DATA_DIR/$product_code/show.$the_date
                    file_click=$DATA_DIR/$product_code/click.$the_date
                    file_install=$DATA_DIR/$product_code/install.$the_date
                    rm -f $file_show $file_click $file_install
                    gen_ad1
                else
                    log "ERROR: There is no visit log for date: $the_date, product: $product_code" >&2
                    continue
                fi
            else
                log "WARN: There is no allocation for date: $the_date, product: $product_code" >&2
                continue
            fi
        done
    done

    # 删除临时文件
    if [[ ! $debug_flag ]]; then
        rm -f $file_visit1 $file_visit2 $file_show1 $file_click1
    fi
}

# 统计
function stat_ad()
{
    range_date $start_date $end_date | while read the_date; do
        the_month=${the_date:0:7}
        the_pct=`awk -F '\t' '$1 == "'$the_month'" {print $2}' $file_product_rate`
        if [[ -z "$the_pct" ]]; then
            arr_prod=(${PRODS//,/ })
        else
            prods=`echo "$the_pct" | awk 'BEGIN{RS="[:,]"} NR % 2 == 1' | tr '\n' ',' | sed 's/,$//'`
            arr_prod=(${prods//,/ })
        fi

        for product_code in ${arr_prod[@]}; do
            file_show=$DATA_DIR/$product_code/show.$the_date
            file_click=$DATA_DIR/$product_code/click.$the_date
            file_install=$DATA_DIR/$product_code/install.$the_date

            if [[ -s $file_show ]]; then
                awk -F '\t' 'BEGIN{
                    OFS=FS
                    stat_date = "'$the_date'"
                    gsub("-","",stat_date)
                } ARGIND == 1 {
                    sum1[$2"\t"$3"\t"$6"\t"$7] ++
                } ARGIND == 2 {
                    sum2[$2"\t"$3"\t"$6"\t"$7] ++
                } ARGIND == 3 {
                    sum3[$2"\t"$3"\t"$6"\t"$7] ++
                } END {
                    for(k in sum1){
                        print stat_date,"'$product_code'",k,sum1[k],sum2[k],sum3[k]
                    }
                }' $file_show $file_click $file_install
            fi
        done
    done > $file_ad_stat

    # 活跃广告
    # 活跃
    local file_active1=$TMP_DIR/active1
    range_date $start_date $end_date | while read the_date; do
        find $DATA_DIR -type d -nowarn -mindepth 1 | while read the_path; do
            product_code=`basename $the_path`
            file_active=$DATA_DIR/$product_code/active.$the_date
            if [[ -s $file_active ]]; then
                awk -F '\t' 'BEGIN{
                    OFS=FS
                }{
                    count[$2"$"$3]++
                }END{
                    for(key in count){
                        print "'${the_date//-/}'$'$product_code'$"key,count[key]
                    }
                }' $file_active
            fi
        done
    done > $file_active1

    # 广告
    local file_ad1=$TMP_DIR/ad1
    awk -F '\t' 'BEGIN{
        OFS=FS
    }{
        show_cnt[$1"$"$2"$"$3"$"$4] += $7
        click_cnt[$1"$"$2"$"$3"$"$4] += $8
        install_cnt[$1"$"$2"$"$3"$"$4] += $9
    }END{
        for(key in show_cnt){
            print key,show_cnt[key],click_cnt[key],install_cnt[key]
        }
    }' $file_ad_stat > $file_ad1

    # 排序
    export LC_ALL=C
    sep=`echo -e "\t"`
    sort $file_active1 -o $file_active1
    sort $file_ad1 -o $file_ad1
    # 关联
    join -t "$sep" $file_active1 $file_ad1 | sed 's/\$/\t/g' > $file_active_ad
}

# 导入数据
function load_data()
{
    # 广告
    echo "CREATE TABLE IF NOT EXISTS $TBL_FACT_AD (
      stat_date INT,
      product_code VARCHAR(20),
      channel_code VARCHAR(64),
      area VARCHAR(64),
      advertiser VARCHAR(50),
      ad_code VARCHAR(50),
      show_cnt INT,
      click_cnt INT,
      install_cnt INT,
      KEY idx_stat_date (stat_date),
      KEY idx_product_code (product_code),
      KEY idx_channel_code (channel_code),
      KEY idx_area (area),
      KEY idx_advertiser (advertiser),
      KEY idx_ad_code (ad_code)
    ) ENGINE=MyISAM COMMENT='广告展示点击激活';

    DELETE FROM $TBL_FACT_AD WHERE stat_date >= ${start_date//-/} AND stat_date <= ${end_date//-/};
    ALTER TABLE $TBL_FACT_AD DISABLE KEYS;
    LOAD DATA LOCAL INFILE '$file_ad_stat' INTO TABLE $TBL_FACT_AD;
    ALTER TABLE $TBL_FACT_AD ENABLE KEYS;
    " | exec_dw

    # 活跃广告
    echo "CREATE TABLE IF NOT EXISTS $TBL_ACTIVE_AD (
      stat_date INT,
      product_code VARCHAR(20),
      channel_code VARCHAR(64),
      area VARCHAR(64),
      active_cnt INT,
      show_cnt INT,
      click_cnt INT,
      install_cnt INT,
      KEY idx_stat_date (stat_date),
      KEY idx_product_code (product_code),
      KEY idx_channel_code (channel_code),
      KEY idx_area (area)
    ) ENGINE=MyISAM COMMENT='活跃广告展示点击激活';

    DELETE FROM $TBL_ACTIVE_AD WHERE stat_date >= ${start_date//-/} AND stat_date <= ${end_date//-/};
    ALTER TABLE $TBL_ACTIVE_AD DISABLE KEYS;
    LOAD DATA LOCAL INFILE '$file_active_ad' INTO TABLE $TBL_ACTIVE_AD;
    ALTER TABLE $TBL_ACTIVE_AD ENABLE KEYS;
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
    echo "Usage: $0 [ -a allot ad ] [ -g generate data ] < -d start date[,end date] > [ -s stat data ] [ -l load data ] [ -c check data ] [ -v debug mode ]" >&2
}

function main()
{
    if [[ $# -lt 1 ]]; then
        usage
        exit 1
    fi

    while getopts "agd:slcv" opt; do
        case "$opt" in
            a)
                allot_flag=1;;
            g)
                gen_flag=1;;
            d)
                args=(${OPTARG//,/ })
                start_date=${args[0]}
                end_date=${args[1]:-$start_date};;
            s)
                stat_flag=1;;
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

    # 分配广告激活量、展示量、点击量
    if [[ $allot_flag ]]; then
        log_fn allot_ad
    fi

    # 生成广告展示日志、点击日志、激活日志
    if [[ $gen_flag ]]; then
        log_fn gen_ad
    fi

    # 统计
    if [[ $stat_flag ]]; then
        log_fn stat_ad
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