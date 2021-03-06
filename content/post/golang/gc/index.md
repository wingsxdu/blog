---
author: "beihai"
title: "Go 语言 GC 机制 · Analyze"
description: "Golang GC 时会发生什么"
tags: [
    "Golang",
]
categories: [
    "Golang",
    "Analyze",
]
date: 2019-09-27T21:42:49+08:00
draft: false
---

内存管理是开发应用中的一大难题。传统的系统级编程语言（主要指 C/C++）中，程序开发者必须对内存小心的进行管理操作，控制内存的申请及释放。因为稍有不慎，就可能产生内存泄露问题，这种问题不易发现并且难以定位，一直成为困扰程序开发者的噩梦。

<!--more-->

## 过去常采用的两种内存管理方法

#### 内存泄露检测工具

这种工具的原理一般是静态代码扫描，通过扫描程序检测可能出现内存泄露的代码段。然而检测工具难免有疏漏和不足，只能起到辅助作用。

#### 智能指针

这是 C++ 中引入的自动内存管理方法，通过拥有自动内存管理功能的指针对象来引用对象，使程序员不用太关注内存的释放，而达到内存自动释放的目的。这种方法是最广泛的做法，但是对程序开发者有一定的学习成本（并非语言层面的原生支持），而且一旦有忘记使用的场景依然无法避免内存泄露。

为了解决这个问题，后来开发出来的很多新语言都引入了语言层面的自动内存管理 ——也就是语言的使用者只用关注内存的申请而不必关心内存的释放，内存释放由虚拟机（virtual machine）或运行时（runtime）来自动进行管理。而这种对不再使用的内存资源进行自动回收的行为就被称为垃圾回收。

## 新生代语言常用的垃圾回收的方法

#### 引用计数（Reference Counting）

这是最简单的一种垃圾回收算法，和之前提到的智能指针异曲同工。对每个对象维护一个引用计数，当引用该对象的对象被销毁或更新时被引用对象的引用计数自动减一，当被引用对象被创建或被赋值给其他对象时引用计数自动加一，当引用计数为 0 时则立即回收对象。

这种方法的优点是实现简单，并且内存的回收很及时。这种算法在内存比较紧张和实时性比较高的系统中使用的比较广泛，如 ios cocoa 框架、php、python 等。

但是简单引用计数算法也有明显的缺点：

- 频繁更新引用计数降低了性能：一种简单的解决方法就是编译器将相邻的引用计数更新操作合并到一次更新；还有一种方法是针对频繁发生的临时变量引用不进行计数，而是在引用达到0时通过扫描堆栈确认是否还有临时对象引用而决定是否释放。除此之外还有很多其他方法。

- 循环引用：当对象间发生循环引用时引用链中的对象都无法得到释放。最明显的解决办法是避免产生循环引用，如 cocoa 引入了 strong 指针和 weak 指针两种指针类型。或者系统检测循环引用并主动打破循环链，当然这也增加了垃圾回收的复杂度。

#### 标记-清除（Mark And Sweep）

标记-清除（Mark And Sweep）分为两步，标记从根变量开始迭代遍历所有被引用的对象，对能够通过引用遍历访问到的对象都进行标记为“被引用”；标记完成后进行清除操作，对没有标记过的内存进行回收（回收同时可能伴有碎片整理操作）。这种方法解决了引用计数的不足，但是也有比较明显的问题：每次启动垃圾回收都会暂停当前所有的正常代码执行(Stop the  World)，回收使系统响应能力大大降低。当然后续也出现了很多 mark&sweep 算法的变种（如三色标记法）优化了这个问题。

#### 分代搜集（Generation）

Java 的 jvm 就使用的分代回收的思路。在面向对象编程语言中，绝大多数对象的生命周期都非常短。分代收集的基本思想是，将堆划分为两个或多个称为代（Generation）的空间。新创建的对象存放在称为新生代（Young Generation）中（一般来说，新生代的大小会比 老年代小很多），随着垃圾回收的重复执行，生命周期较长的对象会被提升到老年代中.

因此，新生代垃圾回收和老年代垃圾回收两种不同的垃圾回收方式应运而生，分别用于对各自空间中的对象执行垃圾回收。新生代垃圾回收的速度非常快，比老年代快几个数量级，即使新生代垃圾回收的频率更高，执行效率也仍然比老年代垃圾回收强，这是因为大多数对象的生命周期都很短，根本无需提升到老年代。

## Golang GC

#### 三色标记法

> Golang 1.5后，采取的是**非分代的、非移动的、并发的、三色的**标记清除垃圾回收算法。
>

在Go 1.5 后采用的三色标记算法，是对标记-清除算法的改进，一共分为四个阶段：

1. 栈扫描：当垃圾回收器第⼀次启动的时候，将对象都看成白色的。初始化GC任务，包括开启写屏障(write barrier)和辅助 GC(mutator assist)，统计 root 对象的任务数量等，将扫描任务作为多个并发的 Goroutine 立即入队给调度器，进而被 CPU 处理。**这个过程需要STW**；

   <div align="center">{{< figure src="/post/golang/gc/index.assets/mark_sweep_5.png" style="center">}}</div>

2. 第一次标记：第一轮先扫描 root 对象，包括全局指针和 Goroutine 栈上的指针，标记为灰色放入队列：

   <div align="center">{{< figure src="/post/golang/gc/index.assets/mark_sweep_6.png" style="center">}}</div>

3. 第二次标记：第二轮标记将第一步队列中的对象引用的对象置为灰色加入队列，一个对象引用的所有对象都置灰并加入队列后，将这个对象置为黑色（表示扫描完成），**这个过程也会开启STW的**。

   <div align="center">{{< figure src="/post/golang/gc/index.assets/mark_sweep_7.png" style="center">}}</div>
一级一级执行下去，最后灰色队列为空时，整个图剩下的白色内存空间即不可到达的对象，即没有被引用的对象；
   
<div align="center">{{< figure src="/post/golang/gc/index.assets/mark_sweep_8.png" style="center">}}</div>
4. 清除：此时，GC 回收白色对象。

   <div align="center">{{< figure src="/post/golang/gc/index.assets/mark_sweep_9.png" style="center">}}</div>
最后，将所有黑色对象变为白色，并重复以上所有过程。


<div align="center">{{< figure src="/post/golang/gc/index.assets/mark_sweep_10.png" style="center">}}</div>
在传统的标记-清除算法中 STW 操作时，要把所有的线程全部冻结掉，这意味着在 STW 期间用户逻辑是暂停的。
而 Golang 三色标记法中最后只剩下的黑白两种对象，黑色对象是程序恢复后继续使用的对象，如果不碰触黑色对象，只清除白色的对象，就不会影响程序逻辑。清除操作和用户逻辑可以并发执行，有效缩短了 STW 时间。

#### 混合写屏障

由于标记操作和用户逻辑是并发执行的，用户逻辑会时常生成对象或者改变对象的引用。例如把⼀个对象标记为⽩⾊准备回收时，⽤户逻辑突然引⽤了它，或者⼜创建了新的对象。由于对象初始时都看为白色，会被 GC 回收掉，为了解决这个问题，引入了写屏障机制。

GC 对扫描过后的对象使⽤操作系统写屏障功能来监控这段内存。如果这段内存发⽣引⽤改变，写屏障会给垃圾回收期发送⼀个信号，垃圾回收器捕获到信号后就知道这个对象发⽣改变，然后重新扫描这个对象，看看它的引⽤或者被引⽤是否改变。利⽤状态的重置实现当对象状态发⽣改变的时候，依然可以再次其引用的对象。

<div align="center">{{< figure src="/post/golang/gc/index.assets/mark_sweep_12.png" style="center">}}</div>
#### 辅助GC

从上面的 GC 工作的完整流程可以看出 Golang GC 实际上把单次暂停时间分散掉了，本来程序执⾏可能是“⽤户代码-->⼤段 GC-->⽤户代码”，分散以后实际上变成了“⽤户代码-->⼩段 GC-->⽤户代码-->⼩段 GC-->⽤户代码”。如果 GC 回收的速度跟不上用户代码分配对象的速度呢？
Go 语⾔如果发现扫描后回收的速度跟不上分配的速度它依然会把⽤户逻辑暂停，⽤户逻辑暂停了以后也就意味着不会有新的对象出现，同时会把⽤户线程抢过来加⼊到垃圾回收⾥⾯加快垃圾回收的速度。这样⼀来原来的并发还是变成了 STW，还是得把⽤户线程暂停掉，要不然扫描和回收没完没了了停不下来，因为新分配对象⽐回收快，所以这种东⻄叫做辅助回收。

#### GC 触发时机

自动垃圾回收的触发条件有两个：

1. 超过内存大小阈值
2. 达到定时时间
   阈值是由一个gcpercent的变量控制的,当新分配的内存占已在使用中的内存的比例超过gcprecent时就会触发。比如一次回收完毕后，内存的使用量为5M，那么下次回收的时机则是内存分配达到10M的时候。也就是说，并不是内存分配越多，垃圾回收频率越高。
   如果一直达不到内存大小的阈值呢？这个时候GC就会被定时时间触发，比如一直达不到10M，那就定时（默认2min触发一次）触发一次GC保证资源的回收。

通常小对象过多会导致 GC 三色法消耗过多的GPU。在编程过程中，尽可能减少对象分配，如使用结构体变量、减少值传递等。

## Reference 与图片来源

- [图解Golang的GC算法](https://i6448038.github.io/2019/03/04/golang-garbage-collector/)

## 相关文章

- [内存空洞](https://www.wingsxdu.com/post/golang/golang-memory-holes/)
- [Go 语言 GC 机制 · Analyze](https://www.wingsxdu.com/post/golang/gc)
- [Goroutine 与 Go 语言并发模型 · Analyze](https://www.wingsxdu.com/post/golang/goroutine)