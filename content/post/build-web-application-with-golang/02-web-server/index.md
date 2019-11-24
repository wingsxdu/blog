---
title: "Web Server"
author: "beihai"
description: "Build Web Application With Golang"
tags: [
    "golang",
    "Build Web Application With Golang",
]
categories: [
    "Build Web Application With Golang",
]
date: 2019-11-24T16:34:56+08:00
draft: true
---
![](/image/build-web-application-with-golang.png)

> 学习如何 Web 编程可能正是你阅读此文章的原因，一个 Web 应用应该具有哪些特性，开发过程中注意哪些问题。在此系列中作者不会用长长的列表指出开发者需要掌握的工具、框架，也不会刻画入微地去深究某一项程序设计的实现原理，旨在为初学者构建知识体系。如果你有想了解的问题、错误指正，可以在文章下面留言。

<!--more-->

## 概述{#概述}



## Web 形式的 Hello Word{#Web 形式的 Hello Word}

序言中我们用 Gin 示例展示了一个简单的 web 服务，本次会介绍多种 web 版 hello word 的实现方式。

###  net/http{##net/http}

```go
package main

import (
	"fmt"
	"log"
	"net/http"
)

func main() {
	fmt.Println("Please visit http://localhost:1323/hello+word")
	http.HandleFunc("/", handler) // each request calls handler
	log.Fatal(http.ListenAndServe("localhost:1323", nil))
}

// handler echoes the Path component of the request URL r.
func handler(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "URL.Path = %q\n", r.URL.Path)
}
```

 我们只用了几行代码就实现了一个Web服务程序，这多亏了内置 http 库里的方法帮我们完成了大量工作。main 函数将所有发送到 “/” 路径下的请求和 handler 函数关联起来（ “/” 开头的请求表示所有发送到当前站点上的请求），服务监听 1323 端口。发送到这个服务的“请求”是一个 http.Request 类型的对象，这个对象中包含了请求中的一系列相关字段，其中就包括我们需要的 URL。当请求到达服务器时，这个请求会被传给 handler 函数来处理，这个函数会将 “hello+word”  这个路径从请求的 URL 中解析出来，然后把其发送到响应中。“hello+word” 中间有一个加号，因为在 URL 中空格以 “+”  的形式展现。

### Gin 版 {##Gin 版}

```go
package main

import (
	"fmt"
	"github.com/gin-gonic/gin"
	"log"
	"net/http"
)

func main() {
	fmt.Println("Please visit http://localhost:1323/hello+word")
	e := gin.Default()
	e.GET("/hello+word", handler)
	log.Print(e.Run(":1323"))
}

func handler(c *gin.Context) {
	c.String(http.StatusOK, fmt.Sprintf("Gin.URL.Path = %s", c.Request.URL.Path))
}
```

Gin 版内容更加具体，路径改为固定值，使用 get 方式，并在返回信息中添加了 http 状态码。

可以看出，Go 语言中的 Web 服务一贯地简洁、易读。

## 环境配置{#环境配置}

### Go{##Go}


#### GOPATH {###GOPATH}



## 总结{#总结}



## Reference{#Reference}

