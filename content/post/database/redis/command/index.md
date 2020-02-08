---
title: "Redis 命令的执行流程 · Analyze"
author: "beihai"
summary: "<blockquote><p>Redis 对外提供了六种键值对供开发者使用，而实际上在底层采用了多种基础数据结构来存储信息，并且会在必要的时刻进行类型转换。文章将会逐一介绍这些数据结构，以及它们的独特之处。</p></blockquote>"
tags: [
    "Analyze",
    "数据库",
    "Redis",
]
categories: [
    "Analyze",
	"数据库",
	"Redis",
]
date: 2020-02-08T16:55:30+08:00
draft: false
---

