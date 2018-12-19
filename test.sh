#!/bin/bash
#
# 测试


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source $DIR/common.sh


# 生成Android ID
sh gen_aid.sh -n 5000000 -lcv


# 生成新增
sh gen_new.sh -g -p adv_n -d 2016-03-02,2016-03-31 -lacv
sh gen_new.sh -g -p recorder_n -d 2016-03-04,2016-03-31 -lacv
sh gen_new.sh -g -p light_n -d 2016-04-01,2016-04-30 -lacv
sh gen_new.sh -g -p compass_n -d 2016-05-04,2016-05-31 -lacv
sh gen_new.sh -g -p file_n -d 2016-06-11,2016-06-30 -lacv
sh gen_new.sh -g -p weather_n -d 2016-08-01,2016-08-31 -lacv
sh gen_new.sh -g -p search_n -d 2017-01-06,2017-01-31 -lacv
sh gen_new.sh -g -p qtext_n -d 2017-08-01,2017-08-31 -lacv
sh gen_new.sh -g -p sport_n -d 2017-08-01,2017-08-31 -lacv
sh gen_new.sh -g -p broswer_n -d 2018-03-05,2018-03-31 -lacv
sh gen_new.sh -g -p space_n -d 2018-04-02,2018-04-30 -lacv


# 生成活跃
sh gen_active.sh -g -p adv_n -d 2016-03-02,2016-03-31 -f 328 -r 80+30 -lacv
sh gen_active.sh -g -p recorder_n -d 2016-03-04,2016-03-31 -f 318 -r 80+30 -lacv
sh gen_active.sh -g -p light_n -d 2016-04-01,2016-04-30 -f 313 -r 80+30 -lacv
sh gen_active.sh -g -p compass_n -d 2016-05-04,2016-05-31 -f 269 -r 80+30 -lacv
sh gen_active.sh -g -p file_n -d 2016-06-11,2016-06-30 -f 284 -r 80+30 -lacv
sh gen_active.sh -g -p weather_n -d 2016-08-01,2016-08-31 -f 299 -r 80+30 -lacv
sh gen_active.sh -g -p search_n -d 2017-01-06,2017-01-31 -f 392 -r 80+30 -lacv
sh gen_active.sh -g -p qtext_n -d 2017-08-01,2017-08-31 -f 284 -r 80+30 -lacv
sh gen_active.sh -g -p sport_n -d 2017-08-01,2017-08-31 -f 271 -r 80+30 -lacv
sh gen_active.sh -g -p broswer_n -d 2018-03-05,2018-03-31 -f 308 -r 80+30 -lacv
sh gen_active.sh -g -p space_n -d 2018-04-02,2018-04-30 -f 304 -r 80+30 -lacv


# 生成访问日志
sh gen_visit.sh -g -p adv_n -d 2016-03-02,2016-03-31 -cv
sh gen_visit.sh -g -p recorder_n -d 2016-03-04,2016-03-31 -cv
sh gen_visit.sh -g -p light_n -d 2016-04-01,2016-04-30 -cv
sh gen_visit.sh -g -p compass_n -d 2016-05-04,2016-05-31 -cv
sh gen_visit.sh -g -p file_n -d 2016-06-11,2016-06-30 -cv
sh gen_visit.sh -g -p weather_n -d 2016-08-01,2016-08-31 -cv
sh gen_visit.sh -g -p search_n -d 2017-01-06,2017-01-31 -cv
sh gen_visit.sh -g -p qtext_n -d 2017-08-01,2017-08-31 -cv
sh gen_visit.sh -g -p sport_n -d 2017-08-01,2017-08-31 -cv
sh gen_visit.sh -g -p broswer_n -d 2018-03-05,2018-03-31 -cv
sh gen_visit.sh -g -p space_n -d 2018-04-02,2018-04-30 -cv


# 生成广告
sh gen_ad.sh -ag -d 2016-03-02,2016-03-31 -slcv
sh gen_ad.sh -ag -d 2016-04-01,2016-04-30 -slc


# 批量生成执行脚本
function batch()
{
    # 新增、活跃、访问
    echo "SELECT product_code, start_date, end_date, rate0, rand0 FROM task;" |
    mysql -uroot ad -s -N | while read product_code start_date end_date rate0 rand0; do
        echo "sh gen_new.sh -g -p $product_code -d $start_date,$end_date -lac"
        echo "sh gen_active.sh -g -p $product_code -d $start_date,$end_date -f $rand0 -r $rate0 -lac"
        echo "sh gen_visit.sh -g -p $product_code -d $start_date,$end_date -c"
    done

    # 广告
    range_month 2016-05 2018-06 | while read the_month; do
        month_begin=${the_month}-01
        month_end=`date +%F -d "$month_begin 1 month 1 day ago"`
        echo "sh gen_ad.sh -ag -d $month_begin,$month_end -slc"
    done
}
