---
title: "浅析 Redis 数据结构的设计与实现 · Analyze"
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

`sds`的实现比较巧妙，直接被定义为`char *`的别名：

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

Redis 针对长度不同的字符串做了优化，选取不同的数据类型来表示长度、申请字节的大小等。结构体中的`__attribute__ ((__packed__))` 设置是告诉编译器取消内存对齐，结构体的大小就是按照结构体成员实际大小相加得到的，以便进行指针偏移操作。其结构体成员含义如下：

- len 变量表示字符串的实际长度，如存入一个"redis"字符串，len 值应为 5；

- alloc 变量表示为 buf[] 分配的内存空间大小，Redis 每次初始化一个 SDS 字符串时，通常会分配大于字符串实际长度的内存空间，alloc  减去 len 值为剩余空间；

- flags 用于标记 sdshdr 的结构体类型，总是占用一个字节，定义如下：

  ```c
  #define SDS_TYPE_5  0 // 不再使用
  #define SDS_TYPE_8  1
  #define SDS_TYPE_16 2
  #define SDS_TYPE_32 3
  #define SDS_TYPE_64 4
  ```

- buf[] 是字符串的实际存储区域，为了兼容 C 字符串，会在字符串的最后添加加一个空字符'\0'，其实际大小为`alloc+1`。

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

传统的 C 字符串使用长度为 N+1 的字符串数组来表示长度为 N 的字符串，所以为了获取一个长度为 C 字符串的长度，必须遍历整个字符串。但在`SDSHeader`数据结构中，有专门用于保存字符串长度的变量，我们可以通过获取len 属性的值，直接知道字符串长度。其时间复杂度由*O*(*n*) 降至*O*(*1*)。

C 字符串中的字符必须符合某种编码，并且字符串中间不能包含空字符，否则最先被程序读入的空字符将被误认为是字符串结尾，这些限制使得 C 字符串只能保存文本数据，而不能保存图片、音视频、压缩文件这样的二进制数据。但在 Redis 中，是通过 len 属性字符串结束位置，即便是中间出现了空字符也不会影响读取。所以 SDS 也是二进制安全的。

####  内存分配

Redis 作为数据库，常用于数据频繁修改的场景，为减小内存分配与销毁开销，在内部了采用预分配与惰性释放的方式。

###### 内存预分配

当将长度为 addlen 的二进制数据追加到  buf[] 后面时，会先调用`sdsMakeRoomFor`函数来保证有足够的空余空间来追加数据，其分配策略如下：

- 如果原字符串中的空余空间足够使用（avail >= addlen），那么它什么也不做，直接返回；
- 如果需要分配空间，且追加后字符串总长度小于定义的`SDS_MAX_PREALLOC(1MB)`，其分配的实际内存大小为所需的两倍，以防备接下来继续追加；
- 如果追加后字符串总长度大于 1MB，那么多分配的内存大小为 1MB；

```c
newlen = (len+addlen);
if (newlen < SDS_MAX_PREALLOC)
    newlen *= 2;
else
    newlen += SDS_MAX_PREALLOC;
```

通过内存预分配策略，SDS 将修改字符串 N 次所需内存分配次数从必定 N 次降低为最多执行 N 次。

###### 惰性释放

惰性空间释放用于优化 SDS 字符串缩短操作：当需要缩短 SDS 保存的字符串时， 程序并不立即使用内存重分配来回收缩短后多出来的字节， 而是减小 len 值， 以等待将来使用。

如果我们需要清空某个字符串，只会将 len 属性设置为 0，但并不释放内存空间，可以下次直接复用。

```c
void sdsclear(sds s) {
    sdssetlen(s, 0);
    s[0] = '\0';
}
```

#### 小结

SDS 的设计策略为尽可能降低响应时间，降低某些操作的时间复杂度，并可能兼容一些 C语言字符串 API，不得不说这种实现十分巧妙。其特点如下表：

| C 字符串                                   | SDS                                    |
| ------------------------------------------ | -------------------------------------- |
| 获取字符串长度的复杂度为*O*(*N*)           | 获取字符串长度的复杂度为*O*(*1*)       |
| API 是不安全的，可能会造成缓冲区溢出       | API 安全，不会造成缓冲区溢出           |
| 修改字符串 N 次必然需要执行 N 次内存重分配 | 修改字符串 N 次最多执行 N 次内存重分配 |
| 只能保存文本数据                           | 二进制安全，可以保存二进制和文本数据   |

## 