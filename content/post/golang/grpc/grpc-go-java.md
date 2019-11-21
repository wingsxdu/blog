---
title: Go Java 跨语言通信
author: beihai
type: post
date: 2019-05-27T06:53:09+00:00
tags: [
    "golang",
    "java",
    "grpc",
]
categories: [
    "golang",
    "java",
    "grpc",
]
---
##### 前言

这两篇文章[Java Grpc 工程中使用][1]  [Go GRPC使用][1]  介绍了 golang、java 中 grpc 的使用，但仅仅是同语言的进程间通信，grpc 在性能上并没有优势。grpc 的优势在于跨语言。

##### 服务端与客户端

这里的服务端指接受数据并将处理后的结果发送回去，客户端指发送数据至另一个程序进行处理。简言之，一个是发送消息，一个是接受消息并处理，与传统的前后端交互没有区别。grpc 使得跨语言程序间的通信服务开发更加便捷。
  
在微服务中，一个程序可以是服务端也可以是客户端，其身份取决于处理的任务类型。

##### 使用

###### 开启服务

Java 程序与 Golang 程序先启动服务端，监听端口，再启动客户端发送信息。

###### 监听多项服务

多数情况下，程序间的通信不会只有一种类型的服务，添加多项任务监听：

<pre class="pure-highlightjs"><code class="null">        server = ServerBuilder.forPort(port)
                .addService(new UserServer.CreateAccountImpl())
                .addService(new UserServer.AddItemImpl())
                .addService(new UserServer.DeleteItemImpl())
                .addService(new UserServer.HasItemImpl())
                .addService(new UserServer.StoreTransactionImpl())
                .addService(new UserServer.HasTransactionImpl())
                .addService(new UserServer.RefundImpl())
                .addService(new UserServer.GetTxByTxIdImpl())
                .build()
                .start();</code></pre>

&nbsp;

 [1]: https://www.wingsxdu.com/?p=1204