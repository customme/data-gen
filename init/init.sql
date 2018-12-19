CREATE DATABASE IF NOT EXISTS #META_DB_NAME#;
USE #META_DB_NAME#;
DROP TABLE IF EXISTS add_count;
CREATE TABLE add_count (
  id INT(11) NOT NULL AUTO_INCREMENT,
  create_date DATE NOT NULL COMMENT '新增日期',
  channel_code VARCHAR(50) NOT NULL COMMENT '渠道编码',
  product_code VARCHAR(50) NOT NULL COMMENT '产品编码',
  add_count INT NOT NULL DEFAULT 0 COMMENT '新增量',
  PRIMARY KEY (id),
  UNIQUE KEY (create_date, channel_code, product_code)
) COMMENT='新增量';
INSERT INTO add_count (create_date, channel_code, product_code, add_count) 
SELECT stattime, cuscode, proname, adduser FROM #RAW_DB_NAME#.l_all_add;

DROP TABLE IF EXISTS area_rate;
CREATE TABLE area_rate (
  id INT(11) NOT NULL AUTO_INCREMENT,
  product_code VARCHAR(50) NOT NULL COMMENT '产品编码',
  area VARCHAR(32) NOT NULL COMMENT '地区',
  rate SMALLINT(6) NOT NULL DEFAULT 0 COMMENT '占比',
  PRIMARY KEY (id),
  UNIQUE KEY (product_code, area)
) COMMENT='地区占比';
INSERT INTO area_rate (product_code, area, rate) 
SELECT prod_name, city, pct FROM #RAW_DB_NAME#.l_city_pct;

DROP TABLE IF EXISTS retention_rate;
CREATE TABLE retention_rate (
  id INT(11) NOT NULL AUTO_INCREMENT,
  product_code VARCHAR(50) NOT NULL COMMENT '产品编码',
  rate1 VARCHAR(8) COMMENT '次日留存率',
  rate2 VARCHAR(8) COMMENT '第2日留存率',
  rate3 VARCHAR(8) COMMENT '第3日留存率',
  rate4 VARCHAR(8) COMMENT '第4日留存率',
  rate5 VARCHAR(8) COMMENT '第5日留存率',
  rate6 VARCHAR(8) COMMENT '第6日留存率',
  rate7 VARCHAR(8) COMMENT '第7日留存率',
  rate14 VARCHAR(8) COMMENT '8-14日留存率',
  rate30 VARCHAR(8) COMMENT '15-30日留存率',
  rate60 VARCHAR(8) COMMENT '31-60日留存率',
  rate0 VARCHAR(8) COMMENT '60~日留存率',
  rate90 VARCHAR(8) COMMENT '第90日留存率',
  rate180 VARCHAR(8) COMMENT '第180日留存率',
  rate360 VARCHAR(8) COMMENT '第360日留存率',
  PRIMARY KEY (id),
  UNIQUE KEY (product_code)
) COMMENT='留存率';
INSERT INTO retention_rate (product_code, rate1, rate2, rate3, rate4, rate5, rate6, rate7, rate14, rate30, rate60, rate0, rate90, rate180, rate360) 
SELECT prod_name, keep1, keep2, keep3, keep4, keep5, keep6, keep7, keep14, keep30, keep60, keep0, keep90, keep180, keep360 FROM #RAW_DB_NAME#.l_prod_keep;

DROP TABLE IF EXISTS ip_native;
CREATE TABLE ip_native (
  id INT(11) NOT NULL AUTO_INCREMENT,
  ip_begin BIGINT(20) NOT NULL,
  ip_end BIGINT(20) NOT NULL,
  area VARCHAR(30) NOT NULL,
  PRIMARY KEY (id)
) COMMENT='国内IP';
INSERT INTO ip_native (ip_begin, ip_end, area) 
SELECT ip_start, ip_end, city FROM #RAW_DB_NAME#.l_ip_native;

DROP TABLE IF EXISTS ip_abroad;
CREATE TABLE ip_abroad (
  id INT(11) NOT NULL AUTO_INCREMENT,
  ip_begin VARCHAR(30) NOT NULL,
  ip_end VARCHAR(30) NOT NULL,
  area VARCHAR(30) NOT NULL,
  PRIMARY KEY (id)
) COMMENT='国外IP';
INSERT INTO ip_abroad (ip_begin, ip_end, area) 
SELECT ipb, ipe, city FROM #RAW_DB_NAME#.l_ip_abroad;

DROP TABLE IF EXISTS hour_rate;
CREATE TABLE hour_rate (
  id INT(11) NOT NULL AUTO_INCREMENT,
  product_code VARCHAR(50) NOT NULL COMMENT '产品编码',
  area VARCHAR(32) NOT NULL COMMENT '地区',
  the_hour TINYINT(4) NOT NULL COMMENT '小时',
  rate SMALLINT(6) NOT NULL DEFAULT 0 COMMENT '占比',
  PRIMARY KEY (id),
  UNIQUE KEY (product_code, area, the_hour)
) COMMENT='活跃时段分布';
INSERT INTO hour_rate (product_code, area, the_hour, rate) 
SELECT proname, city, hour, rate FROM #RAW_DB_NAME#.l_hour_rand;

DROP TABLE IF EXISTS product_area;
CREATE TABLE product_area (
  product_code VARCHAR(50) NOT NULL COMMENT '产品编码',
  area VARCHAR(32) NOT NULL COMMENT '地区',
  UNIQUE KEY (product_code, area)
) COMMENT='产品地区';
INSERT INTO product_area (product_code, area) 
SELECT proname, city FROM #RAW_DB_NAME#.l_pro_city;

DROP TABLE IF EXISTS times_rate;
CREATE TABLE times_rate (
  id INT(11) NOT NULL AUTO_INCREMENT,
  product_code VARCHAR(50) NOT NULL COMMENT '产品编码',
  times SMALLINT(6) NOT NULL COMMENT '活跃次数',
  rate SMALLINT(6) NOT NULL COMMENT '占比',
  PRIMARY KEY (id),
  UNIQUE KEY (product_code, times)
) COMMENT='访问次数分布';
INSERT INTO times_rate (product_code, times, rate) 
SELECT proname, cnt, rate FROM #RAW_DB_NAME#.l_daycnt_rand;

DROP TABLE IF EXISTS ad_income;
CREATE TABLE ad_income (
  id INT(11) NOT NULL AUTO_INCREMENT,
  create_date DATE NOT NULL COMMENT '新增日期',
  advertiser VARCHAR(50) COMMENT '广告主',
  ad_code VARCHAR(50) COMMENT '广告',
  area VARCHAR(32) COMMENT '地区',
  add_count INT(11) NOT NULL DEFAULT 0 COMMENT '激活量',
  show_count INT(11) NOT NULL DEFAULT 0 COMMENT '展示量',
  click_count INT(11) NOT NULL DEFAULT 0 COMMENT '点击量',
  ad_type VARCHAR(20) NOT NULL COMMENT '广告类型 CPA,CPS,CPM,CPC',
  cps_amount DOUBLE(11,2) COMMENT 'CPS金额',
  PRIMARY KEY (id),
  UNIQUE KEY (create_date, advertiser, ad_code, ad_type)
) COMMENT='广告收入';
INSERT INTO ad_income (create_date, advertiser, ad_code, area, add_count, show_count, click_count, ad_type, cps_amount) 
SELECT stattime, adver, advname, city, adduser, shows, clicks, atype, cps FROM #RAW_DB_NAME#.l_all_income;

DROP TABLE IF EXISTS product_rate;
CREATE TABLE product_rate (
  id INT(11) NOT NULL AUTO_INCREMENT,
  the_month VARCHAR(7) NOT NULL COMMENT '月份',
  rate VARCHAR(255) NOT NULL COMMENT '产品占比',
  PRIMARY KEY (id),
  UNIQUE KEY (the_month)
) COMMENT='广告产品占比';
INSERT INTO product_rate (the_month, rate) 
SELECT month, pct FROM #RAW_DB_NAME#.l_all_income_pct;

DROP TABLE IF EXISTS task;
CREATE TABLE task (
  product_code VARCHAR(50) NOT NULL COMMENT '产品编码',
  start_date DATE NOT NULL COMMENT '开始日期',
  end_date DATE NOT NULL COMMENT '结束日期',
  rate0 VARCHAR(8) COMMENT '60~日留存率',
  rand0 SMALLINT(11) COMMENT '浮动值',
  run_status TINYINT(4) NOT NULL DEFAULT '0' COMMENT '运行状态 0:初始化 1:可运行 2:正在运行 3:运行成功 4:运行失败',
  pre_run TINYINT(1) DEFAULT '0' COMMENT '预跑模式 0:否 1:是',
  new_time DATETIME,
  active_time DATETIME,
  visit_time DATETIME,
  error_msg text COMMENT '错误消息',
  UNIQUE KEY (product_code, start_date)
) COMMENT='任务';
INSERT INTO task (product_code, start_date, end_date, rate0, rand0) 
SELECT prod_id, start_date, end_date, keep0, rand0 FROM #RAW_DB_NAME#.t_prod_run WHERE rand0 > 0;


CREATE DATABASE IF NOT EXISTS #DW_DB_NAME#;
USE #DW_DB_NAME#;
DROP TABLE IF EXISTS dim_product;
CREATE TABLE dim_product (
  id INT(11) NOT NULL AUTO_INCREMENT,
  product_code VARCHAR(50) NOT NULL COMMENT '产品编码',
  product_name VARCHAR(50) NOT NULL COMMENT '产品名称',
  PRIMARY KEY (id),
  UNIQUE KEY (product_code)
) COMMENT='产品';
INSERT INTO dim_product (product_code, product_name) 
SELECT appcode, appname FROM #RAW_DB_NAME#.l_app;

DROP TABLE IF EXISTS dim_channel;
CREATE TABLE dim_channel (
  id INT(11) NOT NULL AUTO_INCREMENT,
  channel_code VARCHAR(50) NOT NULL COMMENT '渠道编码',
  channel_name VARCHAR(50) COMMENT '渠道名称',
  PRIMARY KEY (id),
  UNIQUE KEY (channel_code)
) COMMENT='渠道';
INSERT INTO dim_channel (channel_code, channel_name) 
SELECT cuscode, cusname FROM #RAW_DB_NAME#.l_cus;

DROP TABLE IF EXISTS dim_advertiser;
CREATE TABLE dim_advertiser (
  id INT(11) NOT NULL AUTO_INCREMENT,
  advertiser_code VARCHAR(50) COMMENT '广告主编码',
  advertiser_name VARCHAR(50) COMMENT '广告主名称',
  PRIMARY KEY (id),
  UNIQUE KEY (advertiser_code)
) COMMENT='广告主';
INSERT INTO dim_advertiser (advertiser_code, advertiser_name) 
SELECT advercode, advername FROM #RAW_DB_NAME#.l_adver;

DROP TABLE IF EXISTS dim_ad;
CREATE TABLE dim_ad (
  id INT(11) NOT NULL AUTO_INCREMENT,
  ad_code VARCHAR(50) COMMENT '广告编码',
  ad_name VARCHAR(50) COMMENT '广告名称',
  PRIMARY KEY (id),
  UNIQUE KEY (ad_code)
) COMMENT='广告';
INSERT INTO dim_ad (ad_code, ad_name) 
SELECT advcode, advname FROM #RAW_DB_NAME#.l_adv;


-- 更新
UPDATE dim_product SET product_code = 'browser' WHERE product_code = 'broswer';
UPDATE dim_product SET product_code = 'browser_n' WHERE product_code = 'broswer_n';

UPDATE #META_DB_NAME#.add_count a INNER JOIN dim_product b ON a.product_code = b.product_name SET a.product_code = b.product_code;
UPDATE #META_DB_NAME#.area_rate a INNER JOIN dim_product b ON a.product_code = b.product_name SET a.product_code = b.product_code;
UPDATE #META_DB_NAME#.retention_rate a INNER JOIN dim_product b ON a.product_code = b.product_name SET a.product_code = b.product_code;
UPDATE #META_DB_NAME#.hour_rate a INNER JOIN dim_product b ON a.product_code = b.product_name SET a.product_code = b.product_code;
UPDATE #META_DB_NAME#.product_area a INNER JOIN dim_product b ON a.product_code = b.product_name SET a.product_code = b.product_code;
UPDATE #META_DB_NAME#.times_rate a INNER JOIN dim_product b ON a.product_code = b.product_name SET a.product_code = b.product_code;

UPDATE dim_product SET product_name = 'LDANBrowser' WHERE product_code = 'browser';
