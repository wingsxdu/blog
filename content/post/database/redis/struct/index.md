---
title: "浅析 Redis 数据结构 SDS 的实现 · Analyze"
author: "beihai"
description: "浅析 Redis 数据结构"
summary: "<blockquote><p>并发这个概念由来已久，其主要思想是使多个任务可以在同一个时间段内下执行以便更快地得到结果。最早支持并发编程的语言是汇编语言，不过那时并没有任何的理论基础来支持这种编程方式，一个细微的编程错误就可能使程序变得非常不稳定，而且对程序的测试也几乎是不可能的。随着计算机软硬件技术的发展，如今并发程序的编写早已没有以前那么复杂。做为并发编程中的底层基础，本篇文章将会浅入浅出，简要分析进程与线程的设计原理。</p></blockquote>"
tags: [
    "Analyze",
    "数据库",
    "数据结构",
    "Redis",
    "线程",
]
categories: [
    "Analyze",
	"数据库",
]
date: 2020-01-04T22:43:30+08:00
draft: false

---

> *原理分析（Analyze The Principles）是一系列对计算机科学领域中的程序设计进行分析，每一篇文章都会着重于某一个实际问题。如果你有想了解的问题、错误指正，可以在文章下面留言。* 

## SDS

SDS 是 Redis 中广泛使用的字符串结构，它的全称是 Simple Dynamic String（简单动态字符串）。SDS 字符串可以看做是对 C 字符串的进一步封装，但是内部实现十分巧妙，有效避免了内存溢出、申请销毁开销过大等问题。其相关实现定义在 [sds.h](https://github.com/antirez/redis/blob/unstable/src/sds.h) 文件中。

#### 数据结构

SDS 的实现比较巧妙，直接被定义为`char *`的别名：

```c
typedef char *sds;
```

因此 SDS 和传统的 C 语言字符串保持类型兼容（可以调用 C 标准库对字符串的处理函数），在底层的类型定义都是一个指向 char 类型的指针。但两者之间并不等价，在 SDS 中还定义了一系列 SDSHeader 结构体：

```c
struct __attribute__ ((__packed__)) sdshdrX { // X 代表 bit 长度
    uintX_t len;
    uintX_t alloc;
    unsigned char flags; /* 3 lsb of type, 5 unused bits */
    char buf[];
};
//  Redis 为节约内存占用，分别定义了不同长度 buf 下的数据结构：
struct __attribute__ ((__packed__)) sdshdr5 {...} // 不再使用
struct __attribute__ ((__packed__)) sdshdr8 {...}
struct __attribute__ ((__packed__)) sdshdr16 {...}
struct __attribute__ ((__packed__)) sdshdr32 {...}
struct __attribute__ ((__packed__)) sdshdr64 {...}
```

Redis 针对长度不同的字符串做了优化，选取不同的数据类型来表示长度、申请字节的大小等。结构体中的`__attribute__ ((__packed__))` 设置是告诉编译器取消内存对齐，结构体的大小就是按照结构体成员实际大小相加得到的。其他结构体成员含义如下：

- len 变量表示字符串的实际长度，如存入一个"redis"字符串，len 值应为 5；

- alloc 变量表示为 buf[] 分配的内存空间大小，Redis 每次初始化一个 SDS 字符串时，通常会分配大于字符串实际长度的内存空间，alloc  减去 len 值为剩余空间；

- flags 用于标记 sdshdr 的数据类型，总是占用一个字节，定义如下：

  ```c
  #define SDS_TYPE_5  0
  #define SDS_TYPE_8  1
  #define SDS_TYPE_16 2
  #define SDS_TYPE_32 3
  #define SDS_TYPE_64 4
  ```

- buf[] 是字符串的实际存储区域，为了兼容 C 字符串，会在字符串的最后添加加一个空字符'\0'，其实际大小为`alloc + 1`。

![sdshdr-memory](index.assets/sdshdr-memory.png)

上文提到的`sds`就是一个指向 buf[] 的指针，而不是指向`sdshdr`结构体，这样做可以兼容部分 C 语言 API，直接对字符串进行处理。结构体`sdshdr`中的其他成员属性，可以通过指针偏移获取，例如获取当前字符串长度：

```c
// 获取 sds 当前长度
static inline size_t sdslen(const sds s) {
    // s[-1] 指向了 flags 字段
    unsigned char flags = s[-1];
    switch(flags&SDS_TYPE_MASK) {
        case SDS_TYPE_5:
            return SDS_TYPE_5_LEN(flags);
        case SDS_TYPE_8:
            return SDS_HDR(8,s)->len;
		...
    }
    return 0;
}
```

####  内存分配

Redis 作为数据库，常用于数据频繁修改的场景，因此内部采用预分配与惰性释放的方式减少内存分配与销毁开销。





Reids 为 SDS 提供数十种 API 进行数据处理，这里选择了几种比较重要的 API：

|                    API                     |                                                 |
| :----------------------------------------: | :---------------------------------------------: |
|  static inline size_t sdslen(const sds s)  |                返回 sds 当前长度                |
| static inline size_t sdsavail(const sds s) |               返回 sds 可用的长度               |
| static inline size_t sdsalloc(const sds s) |            返回 sds 分配的总内存空间            |
|            void sdsclear(sds s)            | 将 len 字段设置为 0，但内存空间不释放，可以复用 |
|            void sdsfree(sds s)             |              free 方法真正释放内存              |
|                                            |                                                 |
|                                            |                                                 |





与其它语言环境中出现的字符串相比，它具有如下显著的特点：