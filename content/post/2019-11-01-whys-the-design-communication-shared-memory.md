---
title: "为什么使用通信来共享内存？· Why's THE Design?"
author: "beihai"
description: ""
tags: [
    "技术向",
    "golang",
    "底层",
    "科普",
	"转载",
]
categories: [
    "技术向",
    "golang",
    "底层",
    "科普",
	"转载",
]
lastmod: 
date: 2019-11-01T14:24:34+08:00
draft: false
---

> 为什么这么设计（Why’s THE Design）是一系列关于计算机领域中程序设计决策的文章，我们在这个系列的每一篇文章中都会提出一个具体的问题并从不同的角度讨论这种设计的优缺点、对具体实现造成的影响。如果你有想要了解的问题，可以在文章下面留言。

<!--more-->

##### **注：转载文章，原文链接为：[https://draveness.me]( https://draveness.me/whys-the-design-communication-shared-memory ) 推荐关注原作者**

 『不要通过共享内存来通信，我们应该使用通信来共享内存』，这是一句使用 Go 语言编程的人经常能听到的观点，然而我们可能从来都没有仔细地思考过 Go 语言为什么鼓励我们遵循这一设计哲学，我们在这篇文章中就会介绍为什么我们应该更倾向于使用通信的方式交换消息，而不是使用共享内存的方式。 

## 概述{#概述}

使用通信来共享内存其实不只是 Go 语言推崇的哲学，更为古老的 Erlang 语言其实也遵循了同样的设计，然而这两者在具体实现上其实有一些不同，其中前者使用通信顺序进程（Communication Sequential Process），而后者使用 Actor 模型进行设计；这两种不同的并发模型都是『使用通信来共享内存』的具体实现，它们的主要作用都是在不同的线程或者协程之间交换信息。

<div align="center">{{< figure src="/image/concurrency-model.png" title="concurrency-model">}}</div>
从本质上来看，计算机上线程和协程同步信息其实都是通过『共享内存』来进行的，因为无论是哪种通信模型，线程或者协程最终都会从内存中获取数据，所以更为准确的说法是『为什么我们使用发送消息的方式来同步信息，而不是多个线程或者协程直接共享内存？』

为了理解今天的问题，我们需要了解这两种不同的信息同步机制的优点和缺点，对它们之间的优劣进行比较，这样我们才能充分理解 Go 语言和其他语言以及框架决策时背后的原因。

## 设计{#设计}

这篇文章主要会从以下的几个方面介绍为什么我们应该选择使用通信的方式在多个线程或者协程之间保证信息的同步：

- 不同的同步机制具有不同的抽象层级；
- 通过消息同步信息能够降低不同组件的耦合；
- 使用消息来共享内存不会导致线程竞争的问题；

作者相信虽然这三个角度可能有一些重叠或者不够完善，但是也能够为我们提供足够的信息作出判断和选择，理解 Go 语言如何被这条设计哲学影响并将并发模型设计成现在的这种形式。

### 抽象层级{##抽象层级}

发送消息和共享内存这两种方式其实是用来传递信息的不同方式，但是它们两者有着不同的抽象层级，发送消息是一种相对『高级』的抽象，但是不同语言在实现这一机制时也都会使用操作系统提供的锁机制来实现，共享内存这种最原始和最本质的信息传递方式就是使用锁这种并发机制实现的。

我们可以这么理解：更为高级和抽象的信息传递方式其实也只是对低抽象级别接口的组合和封装，Go 语言中的 [Channel](https://draveness.me/golang/concurrency/golang-channel.html) 就提供了 Goroutine 之间用于传递信息的方式，它在内部实现时就广泛用到了共享内存和锁，通过对两者进行的组合提供了更高级的同步机制。

<div align="center">{{< figure src="/image/concurrency-model.png" title="concurrency-model">}}</div>
既然两种方式都能够帮助我们在不同的线程或者协程之间传递信息，那么我们应该尽量使用抽象层级更高的方法，因为这些方法往往提供了更良好的封装和与领域更相关和契合的设计；只有在高级抽象无法满足我们需求时才应该考虑抽象层级更低的方法，例如：当我们遇到对资源进行更细粒度的控制或者对性能有极高要求的场景。

### 耦合{##耦合}

使用发送消息的方式替代共享内存也能够帮助我们减少多个模块之间的耦合，假设我们使用共享内存的方式在多个 Goroutine 之间传递信息，每个 Goroutine 都可能是资源的生产者和消费者，它们需要在读取或者写入数据时先获取保护该资源的互斥锁。

<div align="center">{{< figure src="/image/shared-memory-with-multiple-threads.png" title="shared-memory-with-multiple-threads">}}</div>
然而我们使用发送消息的方式却可以将多个线程或者协程解耦，以前需要依赖同一个片内存的多个线程，现在可以成为消息的生产者和消费者，多个线程也不需要自己手动处理资源的获取和释放，其中 Go 语言实现的 CSP 机制通过引入 Channel 来解耦 Goroutine：

<div align="center">{{< figure src="/image/15719046090667.jpg" title="15719046090667">}}</div>
另一种使用消息发送的并发控制机制 [Actor 模型](https://en.wikipedia.org/wiki/Actor_model) 就省略了 Channel 这一概念，每一个 Actor 都在本地持有一个待处理信息的邮箱，多个 Actor 可以直接通过目标 Actor 的标识符发送信息，所有的信息都会在本地的信箱中等待当前 Actor 的处理。

这种通过发送信息的解耦方式，尤其是 Go 语言实现的 CSP 模型其实与消息队列非常相似，我们引入 Channel 这一中间层让资源的生产者和消费者更加清晰，当我们需要增加新的生产者或者消费者时也只需要直接增加 Channel 的发送方和接收方。

### 线程竞争{##线程竞争}

在很多环境中，并发编程带来的很多问题都是因为没有正确实现访问共享编程的逻辑，而 Go 语言却鼓励我们将需要共享的变量传入 Channel 中，所有被共享的变量并不会同时被多个**活跃的** Goroutine 访问，这种方式可以保证在同一时间只有一个 Goroutine 能够访问对应的值，所以数据冲突和线程竞争的问题在设计上就不可能出现。

> Do not communicate by sharing memory; instead, share memory by communicating.

『不要通过共享内存来通信，我们应该通过通信来共享内存』，Go 语言鼓励我们使用这种方式设计能够处理高并发请求的程序。

Go 语言在实现上通过 Channel 保证被共享的变量不会同时被多个活跃的 Goroutine 访问，一旦某个消息被发送到了 Channel 中，我们就失去了当前消息的控制权，作为接受者的 Goroutine 在收到这条消息之后就可以根据该消息进行一些计算任务；从这个过程来看，消息在被发送前只由发送方进行访问，在发送之后仅可被唯一的接受者访问，所以从这个设计上来看我们就避免了线程竞争。

<div align="center">{{< figure src="/image/data-race.png" title="data-race">}}</div>
需要注意的是，如果我们向 Channel 中发送了一个指针而不是值的话，发送方在发送该条消息之后其实也**保留了修改指针对应值的权利**，如果这时发送方和接收方都尝试修改指针对应的值，仍然会造成数据冲突的问题。

对于在同一个机器和进程上运行的程序来说，由于内存对于当前进程都是可见的，所以我们没有办法避免这种问题的发生，只能说这并不是一种被鼓励的做法和常规的行为，当我们需要处理这种场景时使用更为底层的互斥锁才是一种正确的方式，然而在大多数时候这都意味着不正确的设计，我们需要重新思考线程之间的关系。

## 总结{#总结}

Go 语言并发模型的设计深受 CSP 模型的影响，我们简单总结一下为什么我们应该使用通信的方式来共享内存。

> Do not communicate by sharing memory; instead, share memory by communicating.

1. 首先，使用发送消息来同步信息相比于直接使用共享内存和互斥锁是一种更高级的抽象，使用更高级的抽象能够为我们在程序设计上提供更好的封装，让程序的逻辑更加清晰；
2. 其次，消息发送在解耦方面与共享内存相比也有一定优势，我们可以将线程的职责分成生产者和消费者，并通过消息传递的方式将它们解耦，不需要再依赖共享内存；
3. 最后，Go 语言选择消息发送的方式，通过保证同一时间只有一个活跃的线程能够访问数据，能够从设计上天然地避免线程竞争和数据冲突的问题；

上面的这几点虽然不能完整地解释 Go 语言选择这种设计的方方面面，但是也给出了鼓励使用通信同步信息的充分原因，我们在设计和实现 Go 语言的程序中也应该学会这种思考方式，通过这种并发模型让我们的程序变得更容易理解。到了现在我们其实可以讨论一些更加开放的问题，各位读者可以想一想下面问题的答案：

- 除了使用发送消息和共享内存的方式，我们还可以选择哪些方式在不同的线程之间传递消息呢？
- 共享内存和共享数据库作为同步信息的机制是不是有一些相似性，它们之间有什么异同呢？

> 如果对文章中的内容有疑问或者想要了解更多软件工程上一些设计决策背后的原因，可以在博客下面留言，作者会及时回复本文相关的疑问并选择其中合适的主题作为后续的内容。

## Reference{#Reference}

- [Why build concurrency on the ideas of CSP?](https://golang.org/doc/faq#csp)
- [Concurrency in Golang](http://www.minaandrawos.com/2015/12/06/concurrency-in-golang/)
- [Communicating Sequential Processes & Golang.](https://medium.com/@niteshagarwal_/communicating-sequential-processes-golang-a3d6d5d4b25e)
- [Explain: Don’t communicate by sharing memory; share memory by communicating](https://stackoverflow.com/questions/36391421/explain-dont-communicate-by-sharing-memory-share-memory-by-communicating)
- [Communicating sequential processes](https://en.wikipedia.org/wiki/Communicating_sequential_processes)
- [Share Memory By Communicating](https://blog.golang.org/share-memory-by-communicating)
- [What is the actual meaning of Go’s “Don’t communicate by sharing memory, share memory by communicating.”?](https://www.quora.com/What-is-the-actual-meaning-of-Gos-Dont-communicate-by-sharing-memory-share-memory-by-communicating)
- [What operations are atomic? What about mutexes?](https://golang.org/doc/faq#What_operations_are_atomic_What_about_mutexes)
- [Share by communicating](https://golang.org/doc/effective_go.html#sharing)
- [The actor model in 10 minutes](https://www.brianstorti.com/the-actor-model/)

## {#Title}

