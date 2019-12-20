---
title: "Go 语言并发模型与 Goroutine · Analyze"
author: "beihai"
description: "面向并发编程"
summary: "<blockquote><p>Go 语言最吸引人的地方是它内建的并发支持。Go 语言并发体系的理论是 C.A.R Hoare 在1978年提出的 CSP 模型。在并发编程中，目前的绝大多数语言，都是通过加锁等线程同步方案来解决数据共享问题，而 Go 语言另辟蹊径，它将共享的值通过 Channel 传递。在任意给定的时刻，最好只有一个Goroutine 能够拥有该资源。数据竞争从设计层面上就被杜绝了。</p></blockquote>"
tags: [
    "Golang",
    "实现原理",
    "底层",
]
categories: [
    "Golang",
    "Analyze",
	"并发编程",
]
toc: true
date: 2019-09-29T17:20:37+08:00
draft: false
---

> *原理分析（Analyze The Principles）是一系列对计算机科学领域中的程序设计进行分析，每一篇文章都会着重于某一个实际问题。如果你有想了解的问题、错误指正，可以在文章下面留言。* 

Go 语言最吸引人的地方是它内建的并发支持。Go 语言并发体系的理论是 C.A.R Hoare 在1978年提出的 CSP 模型（Communicating Sequential Process，通讯顺序进程）。在并发编程中，目前的绝大多数语言，都是通过加锁等线程同步方案来解决数据共享问题，而 Go 语言另辟蹊径，它将共享的值通过 Channel 传递。在任意给定的时刻，最好只有一个Goroutine 能够拥有该资源。数据竞争从设计层面上就被杜绝了。

## 概述

Go的 CSP 并发模型，是通过`goroutine`和`channel`来实现的。

- **Goroutine** ：Go 语言中并发的执行单位。是一种轻量线程，它不是操作系统的线程，而是将一个操作系统线程分段使用，通过调度器实现协作式调度。
- **Channel**：Goroutine 之间的通信机制，类似于 UNIX 中的管道。

我们会在 Go 语言中使用 Goroutine 并行执行任务并将 Channel 作为 Goroutine 之间的通信方式，虽然使用互斥锁和共享内存在 Go 语言中也可以完成 Goroutine 间的通信，但是使用 Channel 才是更推荐的做法 — **不要通过共享内存的方式进行通信，而是应该通过通信的方式共享内存**。



## Goroutine

Goroutine，是 Go 语言基于并发编程给出的解决方案。通常 Goroutine 会被当做 Coroutine（协程）的 Golang 实现，从比较粗浅的层面来看，这种认知也算是合理。但实际上，传统的协程库属于**用户级线程模型**，而 Goroutine 和它的`Go Scheduler`在底层实现上属于**两级线程模型**。有时候为了方便理解可以简单把 Goroutine 类比成协程，但心里一定要有个清晰的认知 — Goroutine 并不等同于协程。

Goroutine 使用方式非常的简单，只需使用 `go` 关键字即可启动一个协程，并且它是处于异步方式运行，你不需要等它运行完成以后在执行以后的代码。

```go
go func() // 通过go关键字启动一个协程来运行函数
```

Go的调度器内部有四个重要的结构：M，P，S，Sched，如上图所示（Sched 未给出）。

- G：表示 Goroutine，每个 Goroutine 对应一个G结构体，G 存储 Goroutine 的运行堆栈、状态以及任务函数，可重用。G并非执行体，每个 G 需要绑定到 P 才能被调度执行。
- P： Processor，表示逻辑处理器。 对G来说，P 相当于 CPU 核，G 只有绑定到 P （在 P 的 local  队列中）才能被调度。对 M 来说，P 提供了相关的执行环境（Context），如内存分配状态（mcache），任务队列（G）等， P的数量决定了系统内最大可并行的 G 的数量（前提：物理CPU核数 >= P 的数量），P 的数量由用户设置的 GOMAXPROCS 决定，但是不论 GOMAXPROCS 设置为多大，P的数量最大为256。
- M：Machine，OS线程抽象，代表着真正执行计算的资源，在绑定有效的P后，进入 schedule 循环；而 schedule 循环的机制大致是从 Global 队列、P 的 Local 队列以及 wait 队列中获取 G，切换到 G 的执行栈上并执行G 的函数，调用 goexit 做清理工作并回到 M，如此反复。M 并不保留 G 状态，这是 G 可以跨 M 调度的基础，M 的数量是不定的，由 Go Runtime调整，为了防止创建过多 OS 线程导致系统调度不过来，目前默认最大限制为10000个。
- Sched：代表调度器，它维护有存储M和G的队列以及调度器的一些状态信息等。

<div align="center">{{< figure src="/image/goroutine1.jpg" style="center">}}</div>
#### G-P-M 模型调度

<div align="center">{{< figure src="/image/goroutine-scheduler-model.png" style="center">}}</div>
Go 调度器工作时会维护两种用来保存 G 的任务队列：一种是一个 Global 任务队列，一种是每个 P 维护的 Local 任务队列。

当通过` go `关键字创建一个新的 goroutine 的时候，它会优先被放入P 的本地队列。为了运行goroutine，M 需要持有（绑定）一个 P，接着M会启动一个 OS线程，循环从P的本地队列里取出一个 goroutine 并执行。

![](https://www.wingsxdu.com/image/goroutine2.jpg)

从上图中可以看到，有2个物理线程M，每一个M都拥有一个处理器P，每一个也都有一个正在运行的goroutine。P的数量可以通过GOMAXPROCS()来设置，它其实也就代表了真正的并发度，即有多少个goroutine可以同时运行。

除此之外还有 ` work-stealing `调度算法：当 M 执行完了当前 P 的 Local 队列里的所有 G 后，P 也不会就这么在那躺尸啥都不干，它会先尝试从 Global 队列寻找 G 来执行，如果 Global队列为空，它会随机挑选另外一个 P，从它的队列里中拿走一半的 G 到自己的队列中执行。

<div align="center">{{< figure src="/image/goroutine3.jpg" style="center">}}</div>
#### 为什么要有 P(Processor) ？

你可能会想，为什么一定需要一个上下文，我们能不能直接除去上下文，让 `Goroutine` 的 `runqueues` 挂到M上呢？答案是不行，需要上下文的目的，是让我们可以直接放开其他线程，当遇到内核线程阻塞的时候。

一个很简单的例子就是系统调用 `sysall`，一个线程肯定不能同时执行代码和系统调用被阻塞，这个时候，此线程M需要放弃当前的上下文环境 P，以便可以让其他的 `Goroutine` 被调度执行。

## 相关文章

- [Go 语言并发模型与 Goroutine · Analyze](https://www.wingsxdu.com/post/linux/concurrency-oriented-programming/goroutine/)
- [浅论并发编程中的同步问题 · Analyze](https://www.wingsxdu.com/post/linux/concurrency-oriented-programming/synchronous/)
- [浅析进程与线程的设计 · Analyze](https://www.wingsxdu.com/post/linux/concurrency-oriented-programming/process-and-thread/)