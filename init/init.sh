#!/bin/bash
#
# 初始化数据


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source $DIR/../common.sh


# 原始数据库名
RAW_DB_NAME=native

# 创建数据库
echo "CREATE DATABASE IF NOT EXISTS $RAW_DB_NAME;" | mysql -u root

# 导入数据
ls $RAW_DB_NAME/*.sql | while read sql_file; do
    mysql -u root $RAW_DB_NAME < $sql_file
done

# 初始化数据
sed -i "s/#RAW_DB_NAME#/$RAW_DB_NAME/g" init.sql
sed -i "s/#META_DB_NAME#/$META_DB_NAME/g" init.sql
sed -i "s/#DW_DB_NAME#/$DW_DB_NAME/g" init.sql
mysql -u root < init.sql
