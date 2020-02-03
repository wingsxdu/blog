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

#### 对象的数据结构

Redis 中的每个对象都由一个结构体`redisObject`表示，定义在 [server.h](https://github.com/antirez/redis/blob/unstable/src/server.h)中：

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

例如当我们用 set 命令创建一个字符串键时，就会创建对应的`OBJ_STRING`类型的字符串对象。如果我们想要查看一个键对应的值对象的类型，可以使用命令`TYPE key`获取。

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

| 类型       | 编码                   | 对象                           |
| :--------- | ---------------------- | :----------------------------- |
| OBJ_STRING | OBJ_ENCODING_INT       | 使用整数值实现的字符串对象     |
| OBJ_STRING | OBJ_ENCODING_EMBSTR    | 使用embstr编码sds的字符串对象  |
| OBJ_STRING | OBJ_ENCODING_RAW       | 使用sds实现的字符串对象        |
| OBJ_LIST   | OBJ_ENCODING_QUICKLIST | 使用quicklist实现的列表对象    |
| OBJ_HASH   | OBJ_ENCODING_ZIPLIST   | 使用压缩列表实现的哈希对象     |
| OBJ_HASH   | OBJ_ENCODING_HT        | 使用字典实现的哈希对象         |
| OBJ_SET    | OBJ_ENCODING_HT        | 使用哈希实现的集合对象         |
| OBJ_SET    | OBJ_ENCODING_INSET     | 使用整数集合实现的集合对象     |
| OBJ_ZSET   | OBJ_ENCODING_ZIPLIST   | 使用压缩列表实现的有序集合对象 |
| OBJ_ZSET   | OBJ_ENCODING_SKIPLIST  | 使用跳表实现的有序集合对象     |



`refcount`是引用计数器，Redis 采用引用计数算法进行内存回收，当创建一个新对象时会将`refcount`值设为 1，当增加或者减少引用时，就会调用相应的函数更改`refcount`，当其值变为 0 时就会调用`decrRefCount()`函数释放该对象内存。



## 字符串对象

字符串是 Redis 最基本的数据类型，Redis 中字符串对象的编码可以是 `int`、`raw` 或`embstr` ：

- embstr 编码：保存长度小于 44 字节的字符串，这种编码方式是将 sds 结构体与其对应的 redisObject 对象分配在同一块连续的内存空间中；
- int 编码：保存 long 型的 64 位有符号整数，如果 value 的大小符合 **Redis 共享整数的范围 [0, OBJ_SHARED_INTEGERS = 10000) **，将直接返回一个共享对象，而不用 int 编码；
- raw 编码：不满足上述条件的其他数据，如浮点数、长度超过 long 类型的整数。

embstr 编码方式是用来保存短字符串的一种优化的编码方式，虽然与 raw 编码方式一样都是采用 sds 来保存字符串对象，**但 embstr 调用一次内存分配函数来分配一块连续的空间**，而 raw 是调用两次，且内存空间不连续。之所以选择 44 个字节，是因为使用了`jemalloc`，需要将 embstr 类型的字符串限定在 64 字节。其中`redisObject`占用了 16 字节，sds 会采用占用 3 字节的`sdshdr8`来保存字符串，再加上字符串末尾的“\0”，一共是 64 字节。

在旧版本中 embstr 编码方式可以存储 39 字节大小的字符串，现在增加到 44 字节，原因是 Redis 对 sds 字符串进行了优化，使用`sdsdr8`（uint8_t * 2 + char = 1*2+1 = 3）代替了原有的`sdshdr`（unsigned int * 2 = 4 * 2 = 8），节约了 5 字节的内存空间。

字符串对象相关命令的实现在 [t_string.c](https://github.com/antirez/redis/blob/unstable/src/t_string.c)文件中，实现函数整理如下：

```c
// SET命令，设定键值对
void setCommand(client *c)
// SETNX 命令，key 不存在时才设置值
void setnxCommand(client *c)
// SETEX 命令，key 存在时才设置值，到期时间为秒
void setexCommand(client *c)
// PSETEX 命令，key 存在时才设置值，到期时间为毫秒
void psetexCommand(client *c)
// GET 命令，获取 key 对应的 value
void getCommand(client *c)
// GETSET命令,获取指定的键，如果存在则修改其值；反之不进行操作
void getsetCommand(client *c)
// SETRANGE 命令，范围性的设置值
void setrangeCommand(client *c)
// GETRANGE 命令，范围性的获取值
void getrangeCommand(client *c)
// 获取指定的键，如果存在则修改其值；反之不进行操作
void mgetCommand(client *c)
// MSET 命令，一次设定对个键值对
void msetCommand(client *c)
// MSETNX 命令，key 不存在时才能设置值
void msetnxCommand(client *c)
// INCR 命令,值递增 1
void incrCommand(client *c)
// DECR 命令,值递减 1
void decrCommand(client *c)
// INCRBY 命令,值增加 incr
void incrbyCommand(client *c)
// DECRBY 命令,值减少 incr
void decrbyCommand(client *c)
// INCRBYFLOAT 命令，值增加浮点数
void incrbyfloatCommand(client *c)
// APPEND 命令,追加 key 对应的值 
void appendCommand(client *c)
// STRLEN 命令,获取 key 对应的得长度
void strlenCommand(client *c)
```

除上述命令之外，在 [bitops.c](https://github.com/antirez/redis/blob/unstable/src/bitops.c)文件中还实现了六个位操作命令

```c
// SETBIT 命令,设置指定 offset 处的二进制值
void setbitCommand(client *c)
// GETBIT 命令,获取指定 offset 处的二进制值
void getbitCommand(client *c)
// BITOP 命令，对一个或多个保存二进制位的字符串键进行位元操作，并将结果保存到 destkey 上。
void bitopCommand(client *c)
// BITCOUNT 命令，统计字符串被设置为 1 的 bit 数
void bitcountCommand(client *c)
// BITPOS 命令，返回字符串里面第一个被设为 1 或 0 的 bit 位
void bitposCommand(client *c)
// BITFIELD 命令，将一个 Redis 字符串看作是一个由二进制位组成的数组，并对这个数组中储存的长度不同的整数进行访问
// 用户可以执行诸如“对偏移量 1234 上的 5 位长有符号整数进行设置”、“获取偏移量 4567 上的 31 位长无符号整数”等操作
void bitfieldCommand(client *c)
```

特殊说明一下`BITFIELD` 命令，该命令可以将 Redis 字符串当作位数组，并能对变长位宽和任意未字节对齐的指定整型位域进行寻址。例如执行“对一个有符号的5位整型数的1234位设置指定值”、 “对一个31位无符号整型数的4567位进行取值”等操作。 此外， `BITFIELD` 命令还可以对指定的整数进行自增和自减操作，该命令可以提供有保证的、可配置的上溢和下溢处理操作。

`BITFIELD`命令能操作多字节位域，它会执行一系列操作，并返回一个响应数组，在参数列表中每个响应数组匹配相应的操作。

例如，下面的命令是对一个 8 位有符号整数偏移 100 位自增 1，并获取 4 位无符号整数的值：

```shell
> BITFIELD mykey INCRBY i5 100 1 GET u4 0
1) (integer) 1
2) (integer) 0
```

`BITFIELD`命令支持以下子命令：

- `GET <type> <offset>  `：返回指定的二进制位范围。
- `SET <type> <offset> <value>   `：对指定的二进制位范围进行设置，并返回旧值。
- `INCRBY <type> <offset> <increment>   `：对指定的二进制位范围进行加法操作，并返回旧值。
- `OVERFLOW [WRAP|SAT|FAIL]`：设置溢出行为来改变调用`INCRBY`指令的后序操作
  - **WRAP**: 回环算法，适用于有符号和无符号整型两种类型。对于无符号整型，回环计数将对整型最大值进行取模操作（C语言的标准行为）。对于有符号整型，上溢从最负的负数开始取数，下溢则从最大的正数开始取数，例如，如果i8整型的值设为127，自加1后的值变为-128。
  - **SAT**: 饱和算法，下溢之后设为最小的整型值，上溢之后设为最大的整数值。例如，i8整型的值从120开始加10后，结果是127，继续增加，结果还是保持为127。下溢也是同理，但量结果值将会保持在最负的负数值。
  - **FAIL**: 失败算法，这种模式下，在检测到上溢或下溢时，不做任何操作。相应的返回值会设为NULL，并返回给调用者。

当需要一个整型时，有符号整型需在位数前加 i，无符号在位数前加 u。例如，`u8`是一个8位无符号整型，`i16`是 16 位有符号整型。

有符号整型最大支持 64 位，而无符号整型最大支持 63 位。对无符号整型的限制，是由于当前 Redis 协议不能在响应消息中返回 64 位无符号整数。

## 列表对象

在redis3.2.9之后，quicklist 取代了 ziplist 和 linkedlist，成为了列表对象的底层实现。创建一个新的列表对象：



## Reference

- 
- Redis 源码注释
- 《Redis 设计与实现》