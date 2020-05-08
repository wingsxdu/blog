---

title: "序言"
author: "beihai"
description: "Build Web Application With Golang"
summary: "<blockquote><p>一个 Web 应用应该具有哪些特性，开发过程中注意哪些问题，这是我在初学 Web 时常常思考的问题。在此系列中作者不会用长长的列表指出开发者需要掌握的工具、框架，也不会刻画入微地去深究某一项程序设计的实现原理，旨在为初学者构建知识体系。如果你有想了解的问题、错误指正，可以在文章下面留言。</p></blockquote>"
tags: [
    "Build Web Application With Golang",
]
categories: [
    "Build Web Application With Golang",
]
date: 2019-11-22T20:34:24+08:00
draft: false
---

![](/image/build-web-application-with-golang.png)

> 一个 Web 应用应该具有哪些特性，开发过程中注意哪些问题，这是我在初学 Web 时常常思考的问题。在此系列中作者不会用长长的列表指出开发者需要掌握的工具、框架，也不会刻画入微地去深究某一项程序设计的实现原理，旨在为初学者构建知识体系。如果你有想了解的问题、错误指正，可以在文章下面留言。

## 概述{#概述}

Go 语言目前已经拥有了成熟的 HTTP 处理包，这使得编写稳健、动态的 Web 程序更加方便灵活。 在本系列文章中将从以下角度分析 Web 开发：

- [Go 语言基础]( https://www.wingsxdu.com/post/build-web-application-with-golang/01-golang-base/ )
- [Web 工作方式]()
- [Web 服务]()
- [文本文件处理]()
- [Session 与 Cookie]()
- [数据库]()
- [数据加密与安全]()
- [测试与错误处理]()
- [部署维护]()

## 环境配置

### Go 安装

Go 有多种安装方式，其中三种最常的安装包，支持多种系统，推荐这种安装方式。

- Go 源码安装：对于经常使用 Unix 类系统的用户，从源码安装可以自己定制。
- 第三方工具安装：目前有很多方便的第三方软件包工具，例如 Linux 的 apt-get 和 wget 、Mac 的 homebrew 等。这种安装方式适合熟悉命令行操作的开发者。

安装 Go 时最好一并安装 Git，一些 go 命令依赖于 Git

### GOPATH 与 Go mod

#### GOPATH

$GOPATH 是 go 命令依赖一个重要的环境变量，默认为 `/user/go` 目录，约定有三个子目录：

- src：存放工程代码，即工作区（如：.go .c .js等）
- pkg：编译后生成的文件（比如：.a）
- bin：编译后生成的可执行文件（为了方便，可以把此目录加入到 $PATH 变量中）

#### Go mod

在 go 1.11 版本之前，所有的工程文件需放在 src 目录下，在 1.11 后启用新的包依赖管理工具 go mod 后即可在任意目录建立工程。启用方式：

```bash
$ export GO111MODULE=on
$ export GOPROXY=https://goproxy.io, direct #设置代理，尤其是国内用户
$ mkdir test && cd test && go mod init
```

此时目录下会生成 go.mod 文件，其内容如下

```
module test

go 1.13
```

此时还没有写入任何 go 代码，mod 文件只包含 module 名称以及 go 版本

新建 example.go，写入：

```go
package main

import "github.com/gin-gonic/gin"

func main() {
	r := gin.Default()
	r.GET("/ping", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"message": "pong",
		})
	})
	r.Run() // listen and serve on 0.0.0.0:8080
}
```

这段示例程序引入了 [Gin](https://gin-gonic.com/) Web 框架，这是 Go 语言最热门的框架之一。

再执行命令：

```bash
$ go mod tidy # 自动拉取包依赖
```

此时 go.mod 文件增加了一行，标明了引入的包及其版本信息。

```
module test

go 1.13

require github.com/gin-gonic/gin v1.4.0
```

同时根目录下也生成了 go.sum 文件，详细记载了包依赖及其所有依赖的包。

所有的依赖包都会被放在  `$GOPATH/pkg/mod` 目录下

若想更改依赖版本，可直接修改 go.mod 中的版本或参考以下命令：

```bash
$ go list -m all # 查看项目使用的所有依赖包
$ go list -m -versions github.com/gin-gonic/gin # 列出 Gin 版本历史
github.com/gin-gonic/gin v1.1.1 v1.1.2 v1.1.3 v1.1.4 v1.3.0 v1.4.0
$ go get github.com/gin-gonic/gin@v1.3 #更改版本为 1.3
```

### 框架

我们刚刚用 Gin 框架作为例子简单演示了 go mod 的使用。与其他语言不同的是，Go 语言的框架更类似于一类工具包，对一些常用方法进行封装，开发者可根据需要自行组合定制。

除 Gin 外，比较热门的还有 Echo、Beego 等十余种 Web 框架，也可以应用原生的 http 包进行 web 开发。本系列文章主要应用 [Gin](https://gin-gonic.com/) 与 [Echo](https://echo.labstack.com)。除此之外，也会介绍一些纯 go 语言编写的 orm 引擎、数据库驱动等 。

### 开发工具

几乎所有编辑器都支持 Golang ，但还是列下了几种常用的编辑器

- [Goland](https://www.jetbrains.com/go/) ：Jetbrains 家族系列产品，最强大的 Go 语言 IDE，也是我的主力编辑器。强大的集成工具使用可参考[Jetbrains 文档](https://www.jetbrains.com/zh-cn/go/features/)
- [Visual Studio Code](https://code.visualstudio.com/)：目前使用最多的开源文本编辑器
- [LiteIDE](https://github.com/visualfc/liteide)： 专门为 Go 语言开发的跨平台轻量级 IDE 

## 总结

本文简要介绍了 Go 语言的安装及其开发环境搭建，对新的包管理方式进行了示例演示。在后面的文章中会按照开发流程，进行更深入的了解。

## Reference{#Reference}

- [Go 1.11 Modules](https://github.com/golang/go/wiki/Modules)
- [Gin Web Framework](https://gin-gonic.com/docs/quickstart/)