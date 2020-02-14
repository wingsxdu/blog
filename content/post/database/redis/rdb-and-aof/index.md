---
title: "Redis RESP 通信协议 · Analyze"
author: "beihai"
summary: "<blockquote><p>Redis 是 client-server 架构的软件，了解 Redis 客户端与服务端的通信原理，可以更好地理解 Redis 的工作方式。Redis 客户端和服务端之间使用 RESP(REdis Serialization Protocol) 二进制安全文本协议进行通信，该协议是专为 Redis 设计的，但由于该协议实现简单，也可以将其用于其他的项目中。</p></blockquote>"
tags: [
    "Analyze",
    "通信协议",
    "Redis",
]
categories: [
    "Analyze",
	"Redis",
]
date: 2020-02-12T15:00:09+08:00
draft: false

---

> 对 Redis 数据库的源码阅读，当前版本为 Redis 6.0 RC1，参考书籍《Redis 设计与实现》及其注释。项目地址：[github.com/wingsxdu](https://github.com/wingsxdu/redis)

