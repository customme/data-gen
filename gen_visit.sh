#!/bin/bash
#
# 根据活跃生成访问日志


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source $DIR/common.sh


# 使用时长分布
# 1-60秒 1-3分钟 3-5分钟 5-10分钟 10-20分钟 20-30分钟
DURATION_RATE="search	1-60:460,61-180:265,181-300:150,301-600:70,601-1200:40,1201-1800:15
weather_n	1-60:630,61-180:308,181-300:35,301-600:20,601-1200:6,1201-1800:1
compass_n	1-60:530,61-180:310,181-300:118,301-600:36,601-1200:5,1201-1800:1
qtext_n	1-60:360,61-180:270,181-300:200,301-600:150,601-1200:15,1201-1800:5
sport_n	1-60:400,61-180:280,181-300:180,301-600:120,601-1200:15,1201-1800:5
adv	1-60:510,61-180:210,181-300:180,301-600:70,601-1200:20,1201-1800:10
file	1-60:442,61-180:284,181-300:137,301-600:75,601-1200:45,1201-1800:17
light_n	1-60:550,61-180:320,181-300:98,301-600:20,601-1200:10,1201-1800:2
adv_n	1-60:420,61-180:310,181-300:180,301-600:60,601-1200:20,1201-1800:10
file_n	1-60:442,61-180:284,181-300:187,301-600:45,601-1200:25,1201-1800:17
search_n	1-60:480,61-180:315,181-300:110,301-600:50,601-1200:30,1201-1800:15
recorder_n	1-60:610,61-180:300,181-300:60,301-600:22,601-1200:6,1201-1800:2
shop	1-60:360,61-180:270,181-300:200,301-600:150,601-1200:15,1201-1800:5
recorder	1-60:630,61-180:308,181-300:35,301-600:20,601-1200:6,1201-1800:1
qtext	1-60:515,61-180:333,181-300:85,301-600:55,601-1200:21,1201-1800:1
sport	1-60:420,61-180:318,181-300:135,301-600:85,601-1200:36,1201-1800:6
space	1-60:400,61-180:340,181-300:160,301-600:70,601-1200:25,1201-1800:5
broswer	1-60:420,61-180:360,181-300:120,301-600:60,601-1200:36,1201-1800:4
space_n	1-60:360,61-180:380,181-300:160,301-600:65,601-1200:30,1201-1800:5
broswer_n	1-60:410,61-180:330,181-300:150,301-600:80,601-1200:25,1201-1800:5"


# 初始化
function init()
{
    data_dir=$DATA_DIR/$product_code
    tmp_dir=$TMP_DIR/$product_code
    mkdir -p $data_dir $tmp_dir

    # 时段分布数据文件
    file_hour_rate=$DATA_DIR/hour_rate.$product_code
    # 访问次数分布数据文件
    file_visit_times=$DATA_DIR/visit_times

    # 获取地区ip
    log_fn get_area_ip

    # 获取时段分布
    log_fn get_hour_rate
}

# 获取地区ip
function get_area_ip()
{
    log "Export area ip from database"
    if [[ "$product_code" =~ _n$ ]]; then
        echo "SELECT area, CONCAT(ip_begin, ':', ip_end) FROM ip_native;"
    else
        echo "SELECT area, CONCAT(inet_aton(ip_begin), ':', inet_aton(ip_end)) FROM ip_abroad;"
    fi | exec_meta | awk '{
        if($1 == area){
            ips = ips","$2
        }else{
            if(ips != "") print area,ips
            ips = $2
        }
        area = $1
    }END{
        print area,ips
    }' > $FILE_IP
}

# 获取时段分布
function get_hour_rate()
{
    log "Export hour rate from database"
    echo "SELECT area, GROUP_CONCAT(the_hour, ':', rate) FROM hour_rate WHERE product_code = '$product_code' GROUP BY area;" | exec_meta > $file_hour_rate

    if [[ "$product_code" =~ _n$ ]]; then
        echo "SELECT area FROM product_area WHERE product_code = '$product_code' GROUP BY area;" | exec_meta |
        awk 'BEGIN{OFS="\t"}{
            print $1,hours
        }' hours=`awk '{print $2}' $file_hour_rate` > $file_hour_rate
    fi
}

# 获取活跃次数分布
function get_times_rate()
{
    if [[ ! -s $file_visit_times ]]; then
        echo "SELECT product_code, times, rate FROM times_rate ORDER BY product_code, times;" | exec_meta > $file_visit_times
    fi

    awk -F '\t' '$1 == "'$product_code'" {print $2,$3}' $file_visit_times
}

# 次数占比
function range_times()
{
    get_times_rate | awk 'BEGIN{
        srand()
    }{
        rndpct = int($2 / 10 + 0.5)
        sign = rand()
        if(sign < 0.5) rndpct = - rndpct

        vtimes[$1] = int(total_active * ($2 + rndpct) / 1000 + 0.5)
        sum += vtimes[$1]
    }END{
        size = length(vtimes)
        rnd = int(rand() * size) + 1
        vtimes[rnd] += total_active - sum

        for(i=1;i<=size;i++){
            if(vtimes[i] > 0){
                acc += vtimes[i]
                pacc = acc - vtimes[i]
                print i,pacc + 1","acc
            }
        }
    }' total_active=$total_active
}

# 生成访问次数
function gen_times()
{
    # 当天活跃用户数
    local total_active=`wc -l $file_active | awk '{print $1}'`

    # 按随机数排序
    awk -F '\t' 'BEGIN{
        srand()
        OFS=FS
    }{
        print $0,rand()
    }' $file_active |
    sort -t $'\t' -k 4 > $file_active1

    # 按访问次数占比分配
    rm -f $file_active2
    range_times | while read vtimes range; do
        sed -n "$range p" $file_active1 |
        awk -F '\t' 'BEGIN{
            srand()
            OFS=FS
        }{
            for(i=1;i<=num;i++){
                print $1,$2,$3
            }
        }' num=$vtimes >> $file_active2
    done
}

# 时段占比
function range_hours()
{
    awk 'BEGIN{
        srand()
    }{
        # 初始化city访问次数数组
        if(NR == 1){
            split(cities_times,city_times," ")
            for(i in city_times){
                split(city_times[i],city_arr,":")
                city[city_arr[1]] = city_arr[2]
#                print "step 1",city_arr[1],city_arr[2]
            }
        }

        if(city[$1] > 0){
            # 按时段占比分配
            split($2,hours_rate,",")
            sum = 0
            for(j in hours_rate){
                split(hours_rate[j],hour_rate,":")
#                print "step 2",hour_rate[1],hour_rate[2]

                # 随机浮动10
                sign = rand()
                num = int(rand() * (10 + 1))
                if(sign < 0.5) num = -num

                count[hour_rate[1]] = int(city[$1] * (hour_rate[2] + num) / 10000)
                sum += count[hour_rate[1]]
#                print "step 3",hour_rate[1],count[hour_rate[1]]
            }

            # 多减少加
            r = int(rand() * 24)
            count[r] += city[$1] - sum
#            print "step 4",r,count[r]

            # 输出行号区间
            acc = 0
            pacc = 0
            printf("%s ",$1)
            for(k=0;k<=23;k++){
                if(count[k] > 0){
                    acc += count[k]
                    pacc = acc - count[k]
                    printf("%d:%d,%d ",k, pacc + 1,acc)
                }
            }
            printf("\n")
        }
    }' cities_times="$cities_times" $file_hour_rate
}

# 生成ip
function gen_ip()
{
    awk -F '\t' 'BEGIN{
        srand()
        OFS=FS
    }{
        if(NR == 1){
            split(city_ips,ips_arr,",")
            size = length(ips_arr)
        }

        # 取随机ip段
        i_ips = int(rand() * size + 1)
        ips = ips_arr[i_ips]

        # 从ip段随机取ip
        split(ips,ip_arr,":")
        diff = ip_arr[2] - ip_arr[1]
        ip = ip_arr[1] + int(rand() * (diff + 1))
        ipa = rshift(and(ip, 0xFF000000), 24)"."rshift(and(ip, 0xFF0000), 16)"."rshift(and(ip, 0xFF00), 8)"."and(ip, 0xFF)

        print $1,$2,$3,ipa,rand()
#        print $1,$2,$3,ip,ipa
    }' city_ips="$city_ips"
}

# 生成访问时段 ip
function gen_hours()
{
    # 当天按city访问次数
    local cities_times=`awk -F '\t' '{
        city[$3]++
    }END{
        for(key in city){
            printf("%s:%d ",key,city[key])
        }
    }' $file_active2`

    # 时段分布
    rm -f $file_active4
    range_hours | while read city others; do
        # 随机获取城市100个ip段
        city_ips=`awk 'BEGIN{
            srand()
        } $1 == "'$city'" {
            split($2,arr,",")
            for(i in arr){
                print arr[2],rand()
            }
        }' $FILE_IP |
        sort -k 2 | head -n 100`
        if [[ -z "$city_ips" ]]; then
            echo "WARN: can not find ip for city: $city" >&2
            continue
        fi

        # 生成ip
        sed -n "/\t${city}$/p" $file_active2 | gen_ip > $file_active3

        # 按随机数排序
        sort -k 5 $file_active3 -o $file_active3

        hours_range=($others)
        for((i=0;i<${#hours_range[@]};i++)) do
            hour=${hours_range[$i]%%:*}
            range=${hours_range[$i]#*:}
            sed -n "$range p" $file_active3 |
            awk -F '\t' 'BEGIN{
                srand()
                OFS=FS
            }{
                hour = idx
                minute = int(rand() * 10 * 6)
                second = int(rand() * 10 * 6)

                if(hour < 10) hour = "0"hour
                if(minute < 10) minute = "0"minute
                if(second < 10) second = "0"second

                print $1,$2,$3,$4,"'$the_date' "hour":"minute":"second
            }' idx=$hour >> $file_active4
        done
    done
}

# 生成访问时长
function gen_duration()
{
    local total_visit=`wc -l $file_active4 | awk '{print $1}'`

    echo "$DURATION_RATE" | awk 'BEGIN{
        srand()
    } $1 == "'$product_code'" {
        # 按占比分配
        for(i=2;i<=NF;i++){
            split($i,arr,":")
            atime[arr[1]] = int(total * arr[2] / 1000 + 0.5)
            sum += atime[arr[1]]
        }

        # 多减少加
        size = length(atime)
        rnd = int(rand() * size) + 1
        for(k in atime){
            j++
            if(rnd == j) atime[k] += total - sum
#            print k,atime[k]

            # 生成指定时长范围内的值
            split(k,karr,"-")
            for(x=1;x<=atime[k];x++){
                rtime = int(rand() * (karr[2] - karr[1] + 1))
                ftime = karr[1] + rtime
                print ftime
            }
        }
    }' total=$total_visit > $file_active5

    # 合并文件
    paste $file_active4 $file_active5 > $file_active6
}

# 替换Android ID
function replace_aid()
{
    # 排序
    sort $file_active6 -o $file_active6
    # 对Android ID文件排序
    set +e
    # 检查锁是否存在
    while test -f $DATA_DIR/sort_aid.lock; do
        log "Wait for lock ($product_code, $start_date, $end_date)"
        echo $RANDOM | head -c 1 | xargs sleep
    done
    # 创建锁
    log "Create lock ($product_code, $start_date, $end_date)" | tee $DATA_DIR/sort_aid.lock
    sort -C $FILE_AID || sort $FILE_AID -o $FILE_AID
    # 释放锁
    log "Release lock ($product_code, $start_date, $end_date)"
    rm -f $DATA_DIR/sort_aid.lock
    set -e

    # 关联得到aid
    join -t "$sep" -o 2.2 1.2 1.3 1.4 1.5 1.6 $file_active6 $FILE_AID | sort -t $'\t' -k 5 > $file_visit
}

# 生成一天访问日志
function gen_visit1()
{
    # 生成访问次数
    log "Generate visit times"
    log_fn gen_times

    # 生成访问时段
    log "Generate hours distribution"
    log_fn gen_hours

    # 生成访问时长
    log "Generate visit duration"
    log_fn gen_duration

    # 替换aid
    log "Replace android id with aid"
    log_fn replace_aid
}

# 生成访问日志
function gen_visit()
{
    export LC_ALL=C
    sep=`echo -e "\t"`

    local file_active1=$tmp_dir/active1
    local file_active2=$tmp_dir/active2
    local file_active3=$tmp_dir/active3
    local file_active4=$tmp_dir/active4
    local file_active5=$tmp_dir/active5
    local file_active6=$tmp_dir/active6

    # 逐天生成访问日志
    log "Generate visit log day by day"
    range_date $start_date $end_date | while read the_date; do
        log "Generate visit for day $the_date"
        file_active=$data_dir/active.$the_date
        file_visit=$data_dir/visit.$the_date
        if [[ -s $file_active ]]; then
            log_fn gen_visit1
        else
            log "There is no visit log at $the_date"
        fi
    done

    if [[ ! $debug_flag ]]; then
        # 删除临时文件
        rm -f $file_active1 $file_active2 $file_active3 $file_active4 $file_active5 $file_active6
    fi
}

# 校验数据
function check_data()
{
    echo "TODO"
}

# 用法
function usage()
{
    echo "Usage: $0 [ -g generate data ] < -p product code > < -d start date[,end date] > [ -c check data ] [ -v debug mode ]" >&2
}

function main()
{
    if [[ $# -lt 1 ]]; then
        usage
        exit 1
    fi

    while getopts "gp:d:cv" opt; do
        case "$opt" in
            g)
                gen_flag=1;;
            p)
                product_code="$OPTARG";;
            d)
                args=(${OPTARG//,/ })
                start_date=${args[0]}
                end_date=${args[1]:-$start_date};;
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

    # 初始化
    log_fn init

    # 生成访问日志
    if [[ $gen_flag ]]; then
        log_fn gen_visit
    fi

    # 校验数据
    if [[ $check_flag ]]; then
        log_fn check_data
    fi
}
main "$@"