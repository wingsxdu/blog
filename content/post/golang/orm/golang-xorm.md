---
title: Go ORM引擎之 xorm
author: beihai
type: post
date: 2019-05-19T06:37:51+00:00
hestia_layout_select:
  - sidebar-right
  - sidebar-right
  - sidebar-right
  - sidebar-right
tags: [
    "golang",
    "orm",
]
categories: [
    "golang",
]

---
##### 1.1 orm 引擎简介

<span>ORM 即Object-Relationl Mapping，它的作用是在关系型数据库和对象之间作一个映射，这样，我们在具体的操作数据库的时候，就不需要再去和复杂的SQL语句打交道，只要像平时操作对象一样操作它 。ORM 引擎简化了实际开发中的对数据库的操作，当然也会降低一定的效率。</span>
  
xorm 与 gorm 是 Go 语言中的重量级 orm 引擎，本篇文章介绍 xorm 的一些简单使用。
  
安装：<span>go get github.com/go-xorm/xorm</span>

##### 1.2 Xorm 使用

###### 创建数据结构体

新建子 package models，新建文件user.go，插入代码

<pre class="pure-highlightjs"><code class="null">package models
type User struct {
    Uid       string `json:"uid" xorm:"not null comment('用户id') INT"`
    Name      string `json:"Name" xorm:"comment('用户名') VARCHAR(25)"`
    Salt      string `json:"salt" xorm:"comment('随机盐') VARCHAR(64)"`
    Key       string `json:"key" xorm:"comment('密码') VARCHAR(64)"`
}</code></pre>

###### 初始化引擎

<pre class="pure-highlightjs"><code class="null">package xorm_mysql
import (
    "test/base"
    "test/debug"
    "test/models"
    "fmt"
    "github.com/go-xorm/xorm"
)
func Client() *xorm.Engine {
    engine,err := xorm.NewEngine("mysql", ""root:mima@tcp(127.0.0.1:3306)/test?charset=utf8mb4)
    debug.CheckErr(err)
    engine.SetConnMaxLifetime(base.MysqlMaxLifetime)
    engine.SetMaxOpenConns(base.MysqlMaxOpenConn)
    engine.SetMaxIdleConns(base.MysqlMaxIdleConn)
    engine.ShowSQL(false)
    err = engine.Ping()
    debug.CheckErr(err)
    return engine
}</code></pre>

###### base.go 属性配置

<pre class="pure-highlightjs"><code class="null">package base
const (
    MysqlMaxLifetime = 10*60*1000
    MysqlMaxOpenConn = 50
    MysqlMaxIdleConn = 1000
)
</code></pre>

###### 插入数据

<pre class="pure-highlightjs"><code class="null">func InsertMsg(t interface{}) bool {
    engine := Client()
    if engine == nil {
        fmt.Println("mysql连接失败")
        return false
    }
    _,err := engine.Insert(t)
    if err != nil {
        fmt.Println("数据插入失败",err)
        return false
    }
    return true
}</code></pre>

###### 查存在询单条数据是否存在

<pre class="pure-highlightjs"><code class="null">func FindUsr(uid string) models.User {
    var user models.User
    engine := Client()
    if engine == nil {
        fmt.Println("mysql连接失败")
        return user//nil
    }
    _, err := engine.Where("uid=?", uid).Get(&user)
    debug.CheckErr(err)
    return user
}</code></pre>

###### 删除数据，affected 为删除数据条数

<pre class="pure-highlightjs"><code class="null">func DeleteUsr(uid string) bool {
    var user models.User
    engine := Client()
    if engine == nil {
        fmt.Println("mysql连接失败")
        return false
    }
    affected, err := engine.Id(uid).Delete(&user)
    debug.CheckErr(err)
    if affected == 0{
        return false
    } else {
        return true
    }
}</code></pre>

###### 确认数据是否存在

<pre class="pure-highlightjs"><code class="null">func HasUsr(uid string) bool {
    engine := Client()
    has, err := engine.Exist(&models.User{
        Uid: uid,
    })
    debug.CheckErr(err)
    return has
}</code></pre>

###### 执行 sql 语句

<pre class="pure-highlightjs"><code class="null">func GetList(sql string) []map[string][]byte  {
    engine := Client()
    if engine == nil {
        fmt.Println("mysql连接失败")
        return nil
    }
    results,err := engine.Query(sql)
    if err != nil {
        fmt.Println(err)
        return nil
    }
    return results
}</code></pre>

##### 1.3使用示例

可见简化了很多操作，但是如果对要求极高， Go语言中尽量少用映射

<pre class="pure-highlightjs"><code class="null">func Register(c echo.Context) error {
    uid := c.FormValue("uid")
    password := c.FormValue("password")
    userName := c.FormValue("username")
    fmt.Println("uid为："+uid+"pw:"+password+"name:"+userName)
    if xorm_mysql.HasUsr(uid) {
        return c.JSON(http.StatusOK,"该用户已存在，请重新注册")
    }else {
        //pbkdf2加密
        salt := make([]byte, 32)
        _, err = rand.Read(salt)
        debug.CheckErr(err)
        key := pbkdf2.Key([]byte(password), salt, 1323, 32, sha256.New)
        UserInfo := models.User{uid, userName, hex.EncodeToString(salt), hex.EncodeToString(key)}
        if xorm_mysql.InsertMsg(UserInfo) {
            return c.JSON(http.StatusOK,"注册成功")
        }
        return c.String(http.StatusInternalServerError, "服务器可能出现内部错误")
    }
}</code></pre>