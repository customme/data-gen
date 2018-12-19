#!/bin/bash
#
# 自动检测任务并执行
# 用法: nohup sh task_controller.sh > task_controller.log 2>&1 &
# SlVWejBIck5vSmJVV21MTwo=


# 自身pid
PID=$$


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source $DIR/common.sh


# 检测时间间隔(60秒)
CHECK_INTERVAL=60

# 任务表
TBL_TASK=task

# 数据文件目录
DATA_DIR=/var/ad/data
# 日志文件目录
LOG_DIR=/var/ad/log


# 创建目录
mkdir -p $DATA_DIR $LOG_DIR

# 记录日志
function log()
{
    echo "$(date +'%F %T.%N') $PID [ $@ ]"
}

# 捕捉kill信号
trap 'log "$0 is killed, pid: $PID, script will exit soon";bye=yes' TERM

# 获取可执行任务
function get_tasks()
{
    echo "SELECT
      a.product_code,
      start_date,
      end_date,
      rate0,
      rand0,
      run_status,
      IF(new_time > 0, 0, 1),
      IF(active_time > 0, 0, 1),
      IF(visit_time > 0, 0, 1)
    FROM $TBL_TASK a
    INNER JOIN (
      SELECT product_code, MIN(start_date) min_date FROM $TBL_TASK WHERE run_status <> 3 GROUP BY product_code 
    ) b
    ON a.product_code = b.product_code
    AND start_date = min_date
    AND run_status <> 3;
    " | exec_meta
}

# 获取新增量
function get_add_count()
{
    echo "SELECT IFNULL(SUM(add_count), 0) FROM $TBL_ADD_CNT WHERE create_date >= '$start_date' AND create_date <= '$end_date' AND product_code = '$product_code';" | exec_meta
}

# 更新任务状态
function update_task()
{
    local updates="$1"
    local filters="$2"
    local sql="UPDATE $TBL_TASK SET $updates WHERE product_code = '$product_code' AND start_date = '$start_date' AND end_date = '$end_date' $filters;"

    log "$sql"
    echo "$sql" | exec_meta
}

# 生成访问
function gen_visit()
{
    # 生成访问
    log "Generate visit"
    sh gen_visit.sh -g -p $product_code -d $start_date,$end_date -cv > $LOG_DIR/${product_code}.${start_date}.visit.log 2> $LOG_DIR/${product_code}.${start_date}.visit.err
    if [[ $? -eq 0 ]]; then
        # 更新访问生成时间
        update_task "visit_time = NOW()"

        # 更新任务状态
        update_task "run_status = 3" "AND visit_time > 0"
    else
        error_msg=`sed "s/\('\|\"\)/\\\\\1/g" $LOG_DIR/${product_code}.${start_date}.visit.err | awk '{printf("%s\\\n",$0)}'`
        update_task "run_status = 4, error_msg = CONCAT(IFNULL(error_msg,''), '\nGenerate visit failed\n', '$error_msg')"
    fi
}

# 运行
function run()
{
    # 新增
    add_count=`get_add_count`
    if [[ $new_status -eq 1 && $add_count -gt 0 ]]; then
        # 检查android id是否够用，如果不够，就先生成android id

        # 随机休眠，避免同时创建锁
        echo $RANDOM | head -c 1 | xargs sleep

        # 检查生成android id的锁是否存在
        while test -f $DATA_DIR/aid.lock; do
            log "Wait for lock ($product_code, $start_date, $end_date)"
            echo $RANDOM | head -c 1 | xargs sleep
        done
        # 创建锁
        log "Create lock ($product_code, $start_date, $end_date)" | tee $DATA_DIR/aid.lock

        # 获取android id个数
        if [[ -f $DATA_DIR/android_id ]]; then
            aid_cnt=`wc -l $DATA_DIR/android_id | awk '{print $1}'`
        else
            aid_cnt=0
        fi

        # 当前分配的最大id
        if [[ -f $DATA_DIR/max_id ]]; then
            max_id=`cat $DATA_DIR/max_id`
        else
            max_id=0
        fi

        # 判断是否够用
        diff=$((max_id + add_count - aid_cnt))
        if [[ $diff -gt 0 ]]; then
            # 生成android id
            log "Generate android id"
            sh gen_aid.sh -n $diff -lcv > $LOG_DIR/${product_code}.${start_date}.aid.log 2> $LOG_DIR/${product_code}.${start_date}.aid.err
            if [[ $? -gt 0 ]]; then
                error_msg=`sed "s/\('\|\"\)/\\\\\1/g" $LOG_DIR/${product_code}.${start_date}.aid.err | awk '{printf("%s\\\n",$0)}'`
                update_task "run_status = 4, error_msg = CONCAT(IFNULL(error_msg,''), '\nGenerate android id failed\n', '$error_msg')"

                # 出错退出
                exit 1
            fi
        fi

        # 生成新增
        log "Generate new"
        sh gen_new.sh -g -p $product_code -d $start_date,$end_date -lacv > $LOG_DIR/${product_code}.${start_date}.new.log 2> $LOG_DIR/${product_code}.${start_date}.new.err
        if [[ $? -eq 0 ]]; then
            # 更新新增生成时间
            update_task "new_time = NOW()"
        else
            error_msg=`sed "s/\('\|\"\)/\\\\\1/g" $LOG_DIR/${product_code}.${start_date}.new.err | awk '{printf("%s\\\n",$0)}'`
            update_task "run_status = 4, error_msg = CONCAT(IFNULL(error_msg,''), '\nGenerate new failed\n', '$error_msg')"

            # 出错退出
            exit 1
        fi

        # 释放锁
        log "Release lock ($product_code, $start_date, $end_date)"
        rm -f $DATA_DIR/aid.lock
    fi

    # 活跃
    if [[ $active_status -eq 1 ]]; then
        # 生成活跃
        log "Generate active"
        sh gen_active.sh -g -p $product_code -d $start_date,$end_date -f $rand0 -r $rate0 -lacv > $LOG_DIR/${product_code}.${start_date}.active.log 2> $LOG_DIR/${product_code}.${start_date}.active.err
        if [[ $? -eq 0 ]]; then
            # 更新活跃生成时间
            update_task "active_time = NOW()"
        else
            error_msg=`sed "s/\('\|\"\)/\\\\\1/g" $LOG_DIR/${product_code}.${start_date}.active.err | awk '{printf("%s\\\n",$0)}'`
            update_task "run_status = 4, error_msg = CONCAT(IFNULL(error_msg,''), '\nGenerate active failed\n', '$error_msg')"

            # 出错退出
            exit 1
        fi
    fi

    # 访问
    if [[ $visit_status -eq 1 ]]; then
        if [[ ! `ps aux | grep "gen_visit\.sh -g -p $product_code -d $start_date,$end_date"` ]]; then
            gen_visit &
        else
            log "Another progress is running: gen_visit.sh -g -p $product_code -d $start_date,$end_date"
        fi
    fi
}

# 检查可执行任务
function check()
{
    get_tasks | while read product_code start_date end_date rate0 rand0 run_status new_status active_status visit_status; do
        if [[ $run_status -eq 1 ]]; then
            any_status=$((new_status + active_status + visit_status))
            if [[ $any_status -eq 0 ]]; then
                log "The task($product_code, $start_date, $end_date) is already done, now to update the task status"
                update_task "run_status = 3"
            else
                log "Run task($product_code, $start_date, $end_date)"
                update_task "run_status = 2"
                run &
            fi
        elif [[ $run_status -eq 2 ]]; then
            log "The task($product_code, $start_date, $end_date, $run_status) is running"
        else
            log "The task($product_code, $start_date, $end_date, $run_status) is not ready yet"
        fi
    done
}

# 优雅退出
function graceful_exit()
{
    if [[ $bye ]]; then
        log "Wait subprocess to complete"
        pst=`pstree $PID`
        while [[ "$pst" != "sh---pstree" ]]; do
            sleep 1
            pst=`pstree $PID`
        done

        log "$0 exit"
        break
    fi
}

# 循环检测
log "$0 start running, pid: $PID"
while :; do
    # 优雅退出
    graceful_exit

    # 删除历史日志文件
    log "Delete history logs"
    arr=(aid new active visit)
    for i in "${arr[@]}"; do
        ls -c $LOG_DIR/*.$i 2> /dev/null | sed '1,30 d' | xargs -r rm -f
    done

    # 检查可执行任务
    log "Check tasks"
    check

    # 优雅退出
    graceful_exit

    # 休眠一段时间
    log "Sleep $CHECK_INTERVAL seconds"
    sleep $CHECK_INTERVAL
done
