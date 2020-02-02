---
title: "Redis Object 的实现原理 · Analyze"
author: "beihai"
description: "Redis Object 的实现原理"
summary: "<blockquote><p> </p></blockquote>"
tags: [
    "Analyze",
    "数据库",
    "数据结构",
    "Redis",
]
categories: [
    "Analyze",
	"数据库",
	"Redis",
]
date: 2020-02-02T13:34:56+08:00
draft: false
---

#### 数据结构

Redis 中的每个对象都由一个结构体`redisObject`表示：

```c
#define LRU_BITS 24
typedef struct redisObject {
    // 对象的类型：字符串/列表/集合等
    unsigned type:4;
    // 编码方式
    unsigned encoding:4;
    // 对象最后一次被访问的时间，当内存紧张淘汰数据时用到
    unsigned lru:LRU_BITS; /* LRU time (relative to global lru_clock) or
                            * LFU data (least significant 8 bits frequency
                            * and most significant 16 bits access time). */
    // 引用计数
    int refcount;
    // 数据指针
    void *ptr;
} robj;
```

其中`type`字段记录了对象的键类型，目前有七种：

```c
#define OBJ_STRING 0    /* String object. */
#define OBJ_LIST 1      /* List object. */
#define OBJ_SET 2       /* Set object. */
#define OBJ_ZSET 3      /* Sorted set object. */
#define OBJ_HASH 4      /* Hash object. */
#define OBJ_MODULE 5    /* Module object. */
#define OBJ_STREAM 6    /* Stream object. */
```

例如当我们用 set 命令创建一个字符串键时，就会创建对应的`OBJ_STRING`类型的对象。如果我们想要查看一个键对应的值对象的类型，可以使用命令`TYPE key`获取。

由于`ptr`是一个指向底层数据结构的指针，而且一种键类型可以有多种存储方式，例如集合键的底层数据结构可能是哈希表或者整数集合，因此 Redis 使用`encoding`字段来标记编码方式，这个字段有以下取值：

```c
#define OBJ_ENCODING_RAW 0     /* Raw representation */
#define OBJ_ENCODING_INT 1     /* Encoded as integer */
#define OBJ_ENCODING_HT 2      /* Encoded as hash table */
#define OBJ_ENCODING_ZIPMAP 3  /* Encoded as zipmap */
#define OBJ_ENCODING_LINKEDLIST 4 /* No longer used: old list encoding. */
#define OBJ_ENCODING_ZIPLIST 5 /* Encoded as ziplist */
#define OBJ_ENCODING_INTSET 6  /* Encoded as intset */
#define OBJ_ENCODING_SKIPLIST 7  /* Encoded as skiplist */
#define OBJ_ENCODING_EMBSTR 8  /* Embedded sds string encoding */
#define OBJ_ENCODING_QUICKLIST 9 /* Encoded as linked list of ziplists */
#define OBJ_ENCODING_STREAM 10 /* Encoded as a radix tree of listpacks */
```

Redis 通过`encoding`字段来标记对象所使用的编码方式，而不是为每一种编码方式都关联一种特定的对象，使得编码类型转换操作更加方便，利用多种不同的编码对存储数据进行优化，提升了程序的灵活性与效率。

`lru`字段记录了对象最后一次被访问的时间，Redis 在运行时允许用户设置最大使用内存大小 `server.maxmemory`，当内存数据集大小上升到该值时，就会施行数据淘汰策略。

当 Redis 执行 LRU 数据淘汰机制时，程序会从数据集中**随机挑选几个键值对**，取出其中`lru`值最早的数据将其删除，需要注意的是，挑选键值对的过程是随机的，并不能保证被删除数据的最后一次访问时间比较久远。

| 类型           | 编码                        | 对象                                                 |
| :------------- | :-------------------------- | :--------------------------------------------------- |
| `REDIS_STRING` | `REDIS_ENCODING_INT`        | 使用整数值实现的字符串对象。                         |
| `REDIS_STRING` | `REDIS_ENCODING_EMBSTR`     | 使用 `embstr` 编码的简单动态字符串实现的字符串对象。 |
| `REDIS_STRING` | `REDIS_ENCODING_RAW`        | 使用简单动态字符串实现的字符串对象。                 |
| `REDIS_LIST`   | `REDIS_ENCODING_ZIPLIST`    | 使用压缩列表实现的列表对象。                         |
| `REDIS_LIST`   | `REDIS_ENCODING_LINKEDLIST` | 使用双端链表实现的列表对象。                         |
| `REDIS_HASH`   | `REDIS_ENCODING_ZIPLIST`    | 使用压缩列表实现的哈希对象。                         |
| `REDIS_HASH`   | `REDIS_ENCODING_HT`         | 使用字典实现的哈希对象。                             |
| `REDIS_SET`    | `REDIS_ENCODING_INTSET`     | 使用整数集合实现的集合对象。                         |
| `REDIS_SET`    | `REDIS_ENCODING_HT`         | 使用字典实现的集合对象。                             |
| `REDIS_ZSET`   | `REDIS_ENCODING_ZIPLIST`    | 使用压缩列表实现的有序集合对象。                     |
| `REDIS_ZSET`   | `REDIS_ENCODING_SKIPLIST`   | 使用跳跃表和字典实现的有序集合对象。                 |

`refcount`是引用计数器，Redis 采用引用计数算法进行内存回收，当创建一个新对象时会将`refcount`值设为 1，当增加或者减少引用时，就会调用相应的函数更改`refcount`，当其值变为 0 时就会调用`decrRefCount()`函数释放该对象内存。



## Reference

- 
- Redis 源码注释
- 《Redis 设计与实现》