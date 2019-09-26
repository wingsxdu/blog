---
title: Linux Mysql 数据库相关操作
author: beihai
type: post
date: 2019-05-30T12:27:40+00:00
url: /?p=1258
hestia_layout_select:
  - sidebar-right
categories:
  - linux
  - mysql
  - 技术向

---
登录并创建数据库：

<pre class="pure-highlightjs"><code class="null">mysql -u username-p
&lt;span>create database databasename;&lt;/span>
use databasename;</code></pre>

修改表字段属性

<pre class="pure-highlightjs"><code class="null">alter table user MODIFY uid VARCHAR(10);</code></pre>

查看表结构

<pre class="pure-highlightjs"><code class="null">desc user;</code></pre>

<img src="https://www.wingsxdu.com/wp-content/uploads/2019/05/mysql-desc-1-1.png" alt="" width="597" height="315" class="alignnone size-full wp-image-1259" />
  
查看建表语句

<pre class="pure-highlightjs"><code class="null">show create table user;
</code></pre>

<img src="https://www.wingsxdu.com/wp-content/uploads/2019/05/mysql-show-1-1.png" alt="" width="1036" height="455" class="alignnone size-full wp-image-1260" />
  
退出Mysql

<pre class="pure-highlightjs"><code class="null">quit;</code></pre>

导出整个数据库

<pre class="pure-highlightjs"><code class="null">mysqldump -u 用户名 -p 数据库名 &gt; 导出的文件名
mysqldump -u root -p test &gt; test.sql
ls//导出到当前目录下</code></pre>

导出某个表

<pre class="pure-highlightjs"><code class="null">mysqldump -u 用户名 -p 数据库名 表名&gt; 导出的文件名
mysqldump -u root -p test user &gt; test_user.sql
ls</code></pre>

导入数据库

<pre class="pure-highlightjs"><code class="null">mysql -u 用户名 -p 密码 数据库名 &lt; 数据库名.sql
mysql -u root -p test &lt; test.sql</code></pre>

&nbsp;