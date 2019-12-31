---
title: "为什么进程 fork 采用写时复制 · Why"
author: "beihai"
description: "面向并发编程"
summary: "<blockquote><p>`fork`是目前使用最广泛的进程创建机制，进程通过系统调用函数`fork`能够创建若干个新的进程，前者称为父进程，后者称为子进程。为了减少进程创建的开销，操作系统会使用写时复制技术对数据“共享”，这篇文章将会分析这两个问题。</p></blockquote>"
tags: [
    "Analyze",
    "Linux",
    "fork",
    "进程",
    "写时复制",
    "COW",
]
categories: [
    "Why",
	"Linux",
]
date: 2019-12-30T22:07:48+08:00
draft: false
---
> ***为什么**（Why do this）是一系列对计算机科学领域中的选择与决策进行探究。如果你有想了解的问题、错误指正，可以在文章下面留言。* 

fork 是目前使用最广泛的进程创建机制，进程通过系统调用函数 fork 能够创建若干个新的进程，前者称为父进程，后者称为子进程。为了减少进程创建的开销，现代操作系统会使用`写时复制`技术，父进程与子进程共享同一内存空间，从而实现数据的“拷贝”，这篇文章将会分析这个问题。

![fork and cow](index.assets/fork-and-cow.png)

## 概述

Linux 系统下每一个进程都有父进程，所有进程形成了一个树形结构。当系统启动时，会建立一个 init 进程（ID 为 1），其它的进程都是 init 进程通过 fork 建立的。init 进程的父进程为它自己。如果某一个进程先于它的子进程结束，那么它的子进程将会被 init 进程“收养”，成为 init 进程的直接子进程。

![process-fork](index.assets/process-fork.png)

一个现有的进程可以通过 fork 函数来创建一个新的子进程，子进程是父进程的副本，获得父进程的数据段、堆和栈的副本。但父进程与子进程并不共享这些存储数据，每个进程之间拥有独立的内存空间。

## fork 流程

#### 内存空间



#### 系统调用 exec



#### 写时复制



## 总结

本篇文章主要介绍了进程的一些基本概念与内核对多线程的调度，对于进程与线程更详细的了解可以阅读操作系统相关的书籍。作为系统管理运行的基本单位，许多编程语言的并发模型也是基于内核线程实现。了解线程的基本原理也对语言的理解有一定的帮助。

## Reference

- 

## 相关文章

- [浅论并发编程中的同步问题 · Analyze](https://www.wingsxdu.com/post/linux/concurrency-oriented-programming/synchronous/)
- [浅析进程与线程的设计 · Analyze](https://www.wingsxdu.com/post/linux/concurrency-oriented-programming/process-and-thread/)