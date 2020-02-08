---
title: "Redis 对象的实现 · Analyze"
author: "beihai"
summary: "<blockquote><p>Redis 内部实现了一组比较全面的数据结构类型，但并没有直接使用这些数据结构来实现键值对数据库，而是构建了一个对象系统，利用对象系统将这些数据结构进一步封装。对象系统的设计不但可以针对不同的使用场景，为一种键值对设置不同的底层数据结构，还简化了键值对的回收、共享等操作。这篇文章将简要分析 Redis 对象系统的实现。</p></blockquote>"
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

> 对 Redis 数据库的源码阅读，当前版本为 Redis 6.0 RC1。注释项目地址：[github.com](https://github.com/wingsxdu/redis)

Redis 内部实现了一组比较全面的数据结构类型，但并没有直接使用这些数据结构来实现键值对数据库，而是构建了一个对象系统，利用对象系统将这些数据结构进一步封装。对象系统的设计不但可以针对不同的使用场景，为一种键值对设置不同的底层数据结构，还简化了键值对的回收、共享等操作。这篇文章将简要分析 Redis 对象系统的实现。

## Redis 对象

#### 对象的数据结构

Redis 中的每个对象都由一个结构体`redisObject`表示，定义在[server.h](https://github.com/antirez/redis/blob/unstable/src/server.h)中：

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

键类型与编码方式的对应关系如下：

| 对象类型   | 编码方式                                                 |
| :--------- | :------------------------------------------------------- |
| OBJ_STRING | OBJ_ENCODING_INT 、OBJ_ENCODING_EMBSTR、OBJ_ENCODING_RAW |
| OBJ_LIST   | OBJ_ENCODING_QUICKLIST                                   |
| OBJ_HASH   | OBJ_ENCODING_ZIPLIST、OBJ_ENCODING_HT                    |
| OBJ_SET    | OBJ_ENCODING_INTSET、OBJ_ENCODING_HT                     |
| OBJ_ZSET   | OBJ_ENCODING_ZIPLIST、OBJ_ENCODING_SKIPLIST              |
| OBJ_STREAM | OBJ_ENCODING_STREAM                                      |

#### 空转时长

`lru`字段记录了对象最后一次被访问的时间，将当前时间减去值对象的 lru 时间，就可以计算得出的指定键的空转时长。

Redis 在运行时允许用户设置最大使用内存大小 `server.maxmemory`，当内存数据集大小上升到该值时，就会实行数据淘汰策略。

当 Redis 执行 LRU 数据淘汰机制时，程序会从数据集中**随机挑选几个键值对**，取出其中`lru`值最早的数据将其删除。需要注意的是，挑选键值对的过程是随机的，并不能保证被删除数据的最后一次访问时间比较久远。

#### 引用计数

`refcount`字段是引用计数器，Redis 采用引用计数算法进行内存回收，当创建一个新对象时会将`refcount`值设为 1，这部分代码实现在 [object.c](https://github.com/antirez/redis/blob/unstable/src/object.c)文件中：

```c
robj *createObject(int type, void *ptr) {
    robj *o = zmalloc(sizeof(*o));
    o->type = type;
    o->encoding = OBJ_ENCODING_RAW;
    o->ptr = ptr;
    // 引用计数值设为 1
    o->refcount = 1;
	// ...
}
```

当增加或者减少引用时，就会调用相应的函数更改`refcount`，当其值变为 0 时就会调用`decrRefCount()`函数释放该对象内存。

```c
// 增加引用计数
void incrRefCount(robj *o) {
    if (o->refcount != OBJ_SHARED_REFCOUNT) o->refcount++;
}

// 减少引用计数，当引用计数值为 0 时，释放内存
void decrRefCount(robj *o) {
    if (o->refcount == 1) {
        switch(o->type) {
        case OBJ_STRING: freeStringObject(o); break;
        case OBJ_LIST: freeListObject(o); break;
        case OBJ_SET: freeSetObject(o); break;
        case OBJ_ZSET: freeZsetObject(o); break;
        case OBJ_HASH: freeHashObject(o); break;
        case OBJ_MODULE: freeModuleObject(o); break;
        case OBJ_STREAM: freeStreamObject(o); break;
        default: serverPanic("Unknown object type"); break;
        }
        zfree(o);
    } else {
        if (o->refcount <= 0) serverPanic("decrRefCount against refcount <= 0");
        if (o->refcount != OBJ_SHARED_REFCOUNT) o->refcount--;
    }
}

// 用作特定数据结构的释放函数包装
void decrRefCountVoid(void *o) {
    decrRefCount(o);
}
```

引用计数还有一个特殊的重置函数`resetRefCount()`，这个函数将对象的引用计数设为 0 ，但并不释放对象。

```c
robj *resetRefCount(robj *obj) {
    obj->refcount = 0;
    return obj;
}
```

这个函数在将一个对象传入一个会增加引用计数的函数中时非常有用，例如这样：

`functionThatWillIncrementRefCount(resetRefCount(CreateObject(...)));`

#### 对象共享

为了节省内存，Redis 会创建一些特殊对象用于全局共享，例如各类回复消息、常用命令、共享数据等。

在 [server.c](https://github.com/antirez/redis/blob/unstable/src/server.c)中程序会**预先创建[0,10000)的整型数据**，当要用到这些对象时，会直接取出共享对象使用：

```c
#define OBJ_SHARED_INTEGERS 10000
void createSharedObjects(void) {
	//....  
    for (j = 0; j < OBJ_SHARED_INTEGERS; j++) {
        shared.integers[j] =
            makeObjectShared(createObject(OBJ_STRING,(void*)(long)j));
        shared.integers[j]->encoding = OBJ_ENCODING_INT;
    }
    //...
}
```

在 Redis 中，让多个键共享同一个值对象需要执行以下两个步骤：

1. 将数据库键的值指针指向一个现有的值对象；
2. 将被共享的值对象的引用计数加一。

共享对象机制对于节约内存很有帮助，数据库中保存的相同值对象越多，对象共享机制就能节约越多内存。

#### 相关命令

在 [object.c](https://github.com/antirez/redis/blob/unstable/src/object.c)文件中实现了两个对对象进行处理的命令：`OBJECT`与`MEMORY`

`OBJECT`命令允许检查与键关联的 Redis 对象的内部信息，该命令由`objectCommand()`函数实现。`OBJECT`命令对于调试或了解某个键是否使用了特殊编码的数据类型来节省空间非常有用。当使用 Redis 作为缓存时，应用程序还可以通过`OBJECT`命令返回的信息来实现应用程序级的密钥收回策略。`OBJECT`命令有以下子命令：

- `OBJECT REFCOUNT <key>  `：返回对象的引用计数值；
- `OBJECT ENCODING <key>   `：返回对象的编码；
- `OBJECT IDLETIME <key>   `：返回对象的空转时间；
- `OBJECT FREQ <key>`：返回对象的访问频率；
- `OBJECT HELP`：返回子命令说明。

`MEMORY`命令用于详细的分析内存的使用情况、使用诊断，碎片回收等工作，由函数`memoryCommand()`实现，支持以下 6 种子命令：

- `MEMORY DOCKER <key>`：返回 Redis 服务器遇到的内存相关问题，并提供相应的解决建议；
- `MEMORY MALLOC-STATS <key>`：返回内存分配情况的内部统计报表，该命令目前仅实现了`jemalloc`作为内存分配器的内存统计；
- `MEMORY PURGE <key>`：尝试清除脏页以便内存分配器回收使用，该命令目前仅实现了`jemalloc`作为内存分配器的内存统计；
- `MEMORY STATS <key>`：返回服务器的内存使用情况；
- `MEMORY USAGE key [SAMPLES count]`：返回 key 使用的字节数及其值， 对于嵌套数据类型，可以使用选项`[SAMPLES count]`，其中 COUNT 表示抽样的元素个数，默认值为5。当需要抽样所有元素时，使用`SAMPLES 0`；
- `MEMORY HELP`：返回帮助信息。

## 对象类型

#### 字符串对象

字符串是 Redis 最基本的数据类型，Redis 中字符串对象的编码可以是 `int`、`raw` 或`embstr` ：

- embstr 编码：保存长度小于 44 字节的字符串，这种编码方式是将 sds 结构体与其对应的 redisObject 对象分配在同一块连续的内存空间中；
- int 编码：保存 long 型的 64 位有符号整数，如果 value 的大小符合 Redis 共享整数的范围，将直接返回一个共享对象，而不会新建一个共享；
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
  - **WRAP**: 回环算法，适用于有符号和无符号整型两种类型。对于无符号整型，回环计数将对整型最大值进行取模操作（C语言的标准行为）。对于有符号整型，上溢从最负的负数开始取数，下溢则从最大的正数开始取数，例如，如果 i8 整型的值设为127，自加1后的值变为-128。
  - **SAT**: 饱和算法，下溢之后设为最小的整型值，上溢之后设为最大的整数值。例如，i8整型的值从120开始加10后，结果是127，继续增加，结果还是保持为127。下溢也是同理，但量结果值将会保持在最负的负数值。
  - **FAIL**: 失败算法，这种模式下，在检测到上溢或下溢时，不做任何操作。相应的返回值会设为NULL，并返回给调用者。

当需要一个整型时，有符号整型需在位数前加 i，无符号在位数前加 u。例如，`u8`是一个8位无符号整型，`i16`是 16 位有符号整型。

有符号整型最大支持 64 位，而无符号整型最大支持 63 位。对无符号整型的限制，是由于当前 Redis 协议不能在响应消息中返回 64 位无符号整数。

#### 列表对象

在 Redis3.2.9 之后，quicklist 取代了 ziplist 和 linkedlist，成为了列表对象的底层实现。quicklist 是一个双向链表，链表的每个节点都是一个 ziplist，可以通过修改`list-max-ziplist-size`配置来确定一个 quicklist 节点上的 ziplist 的长度。

由于列表对象只有一种编码方式，因此只是简单调用了`quicklistCreate()`函数创建一个 quicklist 编码的对象，[t_list.c](https://github.com/antirez/redis/blob/unstable/src/t_list.c)相关实现中也没有太多的类型判断与转换：

```c
robj *createQuicklistObject(void) {
    quicklist *l = quicklistCreate();
    robj *o = createObject(OBJ_LIST,l);
    o->encoding = OBJ_ENCODING_QUICKLIST;
    return o;
}
```

列表对象也实现了一个对象迭代器，但由于目前列表对象的编码方式只有一种，这个迭代器只是对 quicklist 迭代器的封装。

```c
typedef struct {
    // 列表对象
    robj *subject;
    // 列表对象编码
    unsigned char encoding;
    // 迭代器方向
    unsigned char direction; /* Iteration direction */
    // quicklist 迭代器指针
    quicklistIter *iter;
} listTypeIterator;
```

列表对象的实现并不复杂，相关命令的实现在 [t_list.c](https://github.com/antirez/redis/blob/unstable/src/t_list.c)文件中，实现函数整理如下：

```c
// LPUSH 命令，将所有指定的值插入到列表的头部
void lpushCommand(client *c)
// RPUSH 命令，将所有指定的值插入到列表的尾部
void rpushCommand(client *c)
// LPUSHX 命令，当 key 不存在的时候不会执行 PUSH 操作
void lpushxCommand(client *c)
// RPUSHX 命令，当 key 不存在的时候不会进行任何操作
void rpushxCommand(client *c)
// LINSERT 命令，将新值插入在指定值之前或之后
void linsertCommand(client *c)
// LLEN 命令,返回 list 的长度
void llenCommand(client *c)
// LINDEX 命令，根据索引返回值
void lindexCommand(client *c)
// LSET 命令，设置索引位置处的 list 元素值
void lsetCommand(client *c) 
// LPOP 命令，移除并且返回 list 的头部元素
void lpopCommand(client *c)
// RPOP 命令，移除并且返回 list 的尾部元素
void rpopCommand(client *c)
// LRANGE 命令，返回指定范围内的元素
void lrangeCommand(client *c)
// LTRIM 命令，修剪一个 list，只保留指定范围内的元素，闭区间
void ltrimCommand(client *c)
// LREM 命令，移除前 count 次出现的值为 value 的元素
void lremCommand(client *c)
// RPOPLPUSH 命令，原子性地将 source 列表尾部元素转移至 destination 列表头部
void rpoplpushCommand(client *c)
// BLPOP 命令，是命令 LPOP 的阻塞版本，当给定列表内没有任何元素可供弹出的时候，连接将被阻塞
void blpopCommand(client *c)
// BRPOP 命令，是命令 RPOP 的阻塞版本
void brpopCommand(client *c)
// BRPOPLPUSH 命令，是命令 RPOPLPUSH 的阻塞版本
void brpoplpushCommand(client *c)
```

#### 哈希对象

哈希表的编码方式可能是`OBJ_ENCODING_ZIPLIST`或`OBJ_ENCODING_HT`，但在源码中并没有以`OBJ_ENCODING_HT`为编码方式新建哈希对象的的相关代码，这是因为一个新建的哈希对象都是以 ZIPLIST 为底层数据结构的，只有当 ZIPLIST 的大小满足配置条件时，才会进行编码方式转换。

相关的配置项有两个：

```c
hash-max-zipmap-entries 512 #键值对的最大数量
hash-max-zipmap-value 64 #value 占用的最大字节数
```

哈希对象也存在一个迭代器，用于值迭代

```c
typedef struct {
    // 被迭代的哈希对象
    robj *subject;
    // 哈希对象的编码
    int encoding;
    // 域指针和值指针，在迭代 ZIPLIST 编码的哈希对象时使用
    unsigned char *fptr, *vptr;
    // 字典迭代器和指向当前迭代字典节点的指针，在迭代 HT 编码的哈希对象时使用
    dictIterator *di;
    dictEntry *de;
} hashTypeIterator;
```

列表对象相关命令的实现在 [t_hash.c](https://github.com/antirez/redis/blob/unstable/src/t_list.c)文件中，实现函数整理如下：

```c
// HSET 命令，设置哈希对象中指定字段的值
void hsetCommand(client *c)
// HSETNX 命令，只有哈希集中不存在指定的字段时，才设置字段的值
void hsetnxCommand(client *c)
// HINCR 命令，增加哈希对象中指定字段的值
void hincrbyCommand(client *c)
// HINCRBYFLOAT 命令，指定字段的增加的值为 float 类型
void hincrbyfloatCommand(client *c)
// HGET 命令，返回哈希对象中指定字段关联的值
void hgetCommand(client *c)
// HMGET 命令，如果哈希对象中不存在指定字段，返回 nil
void hmgetCommand(client *c)
// HDEL 命令，删除哈希对象中的指定字段
void hdelCommand(client *c)
// HLEN 命令，返回哈希对象中的字段数量
void hlenCommand(client *c)
// HSTRLEN 命令，返回哈希对象中的指定字段值的字符串长度，如果 hash 或者 field 不存在，返回 0
void hstrlenCommand(client *c)
// HKEYS 命令，返回哈希对象中所有字段的名称
void hkeysCommand(client *c)
// HVALS 命令，返回哈希对象中所有字段的值
void hvalsCommand(client *c)
// HGETALL 命令，返回哈希对象中所有字段名称及其值
void hgetallCommand(client *c)
// HEXISTS 命令，判断哈希对象中某字段是否存在
void hexistsCommand(client *c)
// HSCAN 命令，基于游标的迭代器
void hscanCommand(client *c)
```

#### 集合对象

集合对象的编码方式可以是`OBJ_ENCODING_INTSET`或`OBJ_ENCODING_HT`，如果集合中的所有元素都是整型数据，那么集合对象将会采用 INTSET，否则使用 HT 编码。因此，对一个 INTSET 编码的集合对象插入字符串数据会触发类型转换，在使用时需要注意。

除此以外，和哈希表类似，当集合对象中的元素个数超过配置的`set-max-intset-entries 512`时也会触发类型转换。相关代码实现在[t_set.c](https://github.com/antirez/redis/blob/unstable/src/t_set.c)中。

集合对象的一些命令的实现比较复杂，因此文中将会分为几个类别进行分析。

常用命令：

```c
// SADD 命令，向集合中添加一个或多个新元素
void saddCommand(client *c)
// SREM 命令，移除指定的集合元素
void sremCommand(client *c)
// SMOVE 命令，将源集合中的指定元素移至目标集合
void smoveCommand(client *c)
// SISMEMBER 命令，检查元素是否存在于集合中
void sismemberCommand(client *c)
// SCARD 命令，返回集合的元素数量
void scardCommand(client *c)
// SSCAN 命令，，基于游标的迭代器
void sscanCommand(client *c)
```

有两个特殊命令`SPOP`和`SRANDMEMBER`可能含有参数 count 值，表示需要获得的元素数量，count 参数有单独的实现函数，如下：

```c
// SPOP 命令，从集合中随机移除一个元素
void spopCommand(client *c)
// SPOP key [count] 命令，从集合中随机移除 count 个元素
void spopWithCountCommand(client *c)
// SRANDMEMBER 命令，随机返回集合中的一个元素
void srandmemberCommand(client *c)
// SRANDMEMBER key [count] 命令，随机返回集合中的 count 个元素
void srandmemberWithCountCommand(client *c)
```

`SPOP key [count]` 命令的实现可能有四种情况：

1. count 为 0 ，返回一个空集合；
2. count 大小大于集合的基数，那么直接返回整个集合，并删除集合；
3. 先计算集合删除 count 个元素后的剩余元素数量 remaining，如果 remaining×5 的结果仍大于 count 值，那么需要循环 count 次, 每次随机 pop 出一个元素；
4. 如果计算结果小于等于 count，那么将循环 remining 次, 每次随机 pop 出一个元素，将 pop 出来的元素赋值给新的集合, 最后用新的集合覆盖原来的集合。

`SRANDMEMBER key [count]` 命令的实现可能有五种情况：

1. count 为 0 ，直接返回；
2. count 为负数，表示结果集可以带有重复元素，因此直接从集合中随机取出并返回 N 个元素；
3. count 大小大于集合的基数，那么直接返回整个集合；
4. count 参数乘以`SRANDMEMBER_SUB_STRATEGY_MUL=3`的积比集合的基数大，在这种情况下，程序创建一个集合的副本，并从集合中随机删除元素，直到集合的基数等于 count 参数指定的数量为止。使用这种做法的原因是，**当 count 的数量接近于集合的基数时，从集合中随机取出 count 个参数的方法是非常低效的**；
5. 如果 count 参数要比集合基数小很多，那么直接从集合中随机地取出元素，并将它添加到结果集合中，直到结果集的基数等于 count，这个过程并不会添加重复的元素。

可以看出程序对 count 的可能情况考虑得比较充分，并且做了相应的性能优化。

对集合进行交集运算的命令实际由函数`sinterGenericCommand()`执行，交集运算算法的执行流程如下：

1. 按基数大小对集合按从小到大的顺序进行排序，以提升算法的效率；
2. 从基数最小的集合中取出元素，并将它和其他集合进行比对，如果有至少一个集合不包含这个元素，那么这个元素不属于交集；
3. 重复第二步，直至遍历完基数最小的集合。

这个算法的时间复杂度为 *O(N×M)*，其中 N 为计数最小的集合的基数，而 M 则为其他集合的数量。

```c
// SINTER 命令，返回指定集合间的成员交集
void sinterCommand(client *c)
// SINTERSTORE 命令，计算指定集合间的成员交集，并将结果保存至目标集合中
void sinterstoreCommand(client *c)
```

对集合进行并差集运算的四个命令都是调用`sunionDiffGenericCommand()`函数来实现的。

如果执行的是并集计算，那么只需要遍历所有集合，将元素添加到结果集里中（**无论执行的命令是否需要将结果保存，程序都会创建一个结果集用于保存中间数据**）。

如果执行的是差集运算，该过程实现了两种算法，程序通过考察输入来决定使用那个算法。

- 算法一：程序遍历 sets[0] 集合中的所有元素，并将这个元素和其他集合的所有元素进行对比，只有这个元素不存在于其他所有集合时，才将这个元素添加到结果集。因此算法一执行最多 N×M 步，其中 N 为第一个集合的基数，而 M 则为其他集合的数量，复杂度为 *O(N×M)* 。
- 算法二：程序将 sets[0] 的所有元素都添加到结果集中，然后遍历其他所有集合，将相同的元素从结果集中删除。该算法复杂度为 *O(N)* ，N 为所有集合的基数之和。

```c
// SUNION 命令，返回给定的多个集合的并集
void sunionCommand(client *c)
// SUNIONSTORE 命令，计算给定的多个集合的并集，并将结果存储在目标集合里
void sunionstoreCommand(client *c)
// SDIFF 命令，返回给定的多个集合的差集
void sdiffCommand(client *c)
// SDIFFSTORE 命令，计算给定的多个集合的差集，并将结果存储在目标集合里
void sdiffstoreCommand(client *c)
```

#### 有序集合对象

有序集合是给每个元素设置一个分值（score）作为排序依据的数据结构，常用于一些排行榜类场景。有序集合的编码方式可以是`OBJ_ENCODING_ZIPLIST`或`OBJ_ENCODING_SKIPLIST`，**需要注意的是第二种编码实际上使用了两种数据结构： dict 与 skiplist**，而不是只使用 skiplist 做为底层实现。

当有序集合元素大小符合以下配置条件时，内部将使用 ziplist，否则将使用第二种编码方式：

```c
zset-max-ziplist-entries 128
zset-max-ziplist-value 64
```

使用 ziplist 来实现在序集合时，只需要在 ziplist 数据结构的基础上做好排序与去重就可以了。使用 skiplist 来实现有序集合也很容易理解，Redis 中的跳跃表就是为了有序集合对象而实现的，跳跃表的相关 API 实现也和有序集合实现在同一个文件[t_zset.c](https://github.com/antirez/redis/blob/unstable/src/t_zset.c)中。

`OBJ_ENCODING_SKIPLIST`编码使用两种数据结构，是因为 skiplist 按分数来索引，查找时间复杂度为*O(lgN)*；而 dict 按数据索引，查找时间复杂度为*O(1)*。如果没有字典，想根据数据查分数，就必须对跳跃表进行遍历。这两种底层数据结构只作为索引使用，数据被封装在SDS中，由跳跃表与字典共同持有。而数据的分数则由跳跃表结点直接持有（double 类型数据），由字典间接持有。	

Redis 内部也实现了一个多态的集合迭代器，可以迭代集合或有序集合对象：

```c
typedef struct {
    // 被迭代的对象
    robj *subject;
    // 对象的类型
    int type; /* Set, sorted set */
    // 编码
    int encoding;
    // 权重
    double weight;

    union {
        /* Set iterators. */
        // 集合迭代器
        union _iterset {
            // intset 迭代器
            struct {
                // 被迭代的 intset
                intset *is;
                // 当前节点索引
                int ii;
            } is;
            // 字典迭代器
            struct {
                // 被迭代的字典
                dict *dict;
                // 字典迭代器
                dictIterator *di;
                // 当前字典节点
                dictEntry *de;
            } ht;
        } set;

        /* Sorted set iterators. */
        // 有序集合迭代器
        union _iterzset {
            // ziplist 迭代器
            struct {
                // 被迭代的 ziplist
                unsigned char *zl;
                // 当前迭代到的成员指针和分值指针
                unsigned char *eptr, *sptr;
            } zl;
            // zset 迭代器
            struct {
                // 被迭代的 zset
                zset *zs;
                // 当前跳跃表节点
                zskiplistNode *node;
            } sl;
        } zset;
    } iter;
} zsetopsrc;
```

类似地，Redis 也为该迭代器实现了保存当前迭代节点值的数据结构：

```c
typedef struct {
    // 标记数据有效性
    int flags;
    // 私有缓冲区
    unsigned char _buf[32]; /* Private buffer. */
    // 可以用于保存元素的几个类型
    // sds 对象
    sds ele;
    // 字符串
    unsigned char *estr;
    //字符串长度
    unsigned int elen;
    //整型数据
    long long ell;
    // 分值
    double score;
} zsetopval;
```

这部分结构都与上面的对象类型类似。

有序集合的命令实现函数如下：

```c
// ZADD 命令，向有序集合中添加元素
void zaddCommand(client *c)
// ZINCRBY 命令，增加有序集合元素的分值，支持 int 或 double
void zincrbyCommand(client *c)
// ZREM 命令，删除有序集合中的指定元素
void zremCommand(client *c)
// ZREMRANGEBYRANK 命令，从有序集合中删除指定排名区间的元素，闭区间
void zremrangebyrankCommand(client *c)
// ZREMRANGEBYSCORE 命令，从有序集合中删除指定分值区间的元素，闭区间
void zremrangebyscoreCommand(client *c)
// ZREMRANGEBYSCORE 命令，从有序集合中删除指定字典序区间的元素，要求成员分数必须相同
void zremrangebylexCommand(client *c)
// ZUNIONSTORE 命令，计算给定有序集合间的并集，并将结果放在目标集合中
void zunionstoreCommand(client *c)
// ZINTERSTORE 命令，计算给定有序集合间的交集，并将结果放在目标集合中
void zinterstoreCommand(client *c)
// ZRANGE 命令，返回有序集合中指定范围的元素，按分数从低到高排列
void zrangeCommand(client *c)
// ZREVRANGE 命令，返回有序集合中指定范围的元素，按分数从高到低排列
void zrevrangeCommand(client *c)
// ZRANGEBYSCORE 命令，返回有序集合中指定分数范围的元素（闭区间），按分数从低到高排列
void zrangebyscoreCommand(client *c)
// ZREVRANGEBYSCORE 命令，返回有序集合中指定分数范围的元素（闭区间），按分数从高到低排列
void zrevrangebyscoreCommand(client *c)
// ZCOUNT 命令，返回有序集合中分值在[min,max]之间的元素数量
void zcountCommand(client *c)
// ZLEXCOUNT 命令，返回有序集合中成员名称在 [min，max] 之间的成员数量
void zlexcountCommand(client *c)
// ZRANGEBYLEX 命令，返回指定成员区间内的成员，按成员字典正序排序, 要求成员分数必须相同
void zrangebylexCommand(client *c)
// ZREVRANGEBYLEX 命令，返回指定成员区间内的成员，按成员字典倒序排序, 要求成员分数必须相同
void zrevrangebylexCommand(client *c)
// ZCARD 命令，返回有序集合中的元素个数
void zcardCommand(client *c)
// ZSCORE 命令，返回有序集合中指定元素的分数
void zscoreCommand(client *c)
// ZSCAN 命令，，基于游标的迭代器
void zscanCommand(client *c)
// ZPOPMIN 命令，删除并返回有序集合中的最多 count 个具有最低分的元素
void zpopminCommand(client *c)
// ZMAXPOP 命令，删除并返回有序集合中的最多 count 个具有最高分的元素
void zpopmaxCommand(client *c)
// BZPOPMIN 命令，是 ZPOPMIN 命令的阻塞版本，可设置阻塞时间
void bzpopminCommand(client *c)
// BZPOPMAX 命令，是 ZPOPMAX 命令的阻塞版本，可设置阻塞时间
void bzpopmaxCommand(client *c)
```

#### Streams 对象

Streams 是 Redis 5.0 引入的数据类型，官方把它定义为：**以更抽象的方式建模日志的数据结构**。Redis 的Streams 主要是一个append only 的数据结构，将新数据插入到旧数据的后面。

一个 Streams 对象的数据结构如下：

```c
typedef struct streamID {
    // unix 时间戳
    uint64_t ms;        /* Unix time in milliseconds. */
    // 序列号
    uint64_t seq;       /* Sequence number. */
} streamID;

typedef struct stream {
    // radix tree 存储信息
    rax *rax;               /* The radix tree holding the stream. */
    // 元素数量
    uint64_t length;        /* Number of elements inside this stream. */
    // 最新一个元素的 ID
    streamID last_id;       /* Zero if there are yet no items. */
    // 消费组
    rax *cgroups;           /* Consumer groups dictionary: name -> streamCG */
} stream;
```

Streams 对象由两部分数据结构组成，一部分是 radix tree，用作存储所有的`streamID`。由于`streamID`是一个时间戳+序列号组成的字符串，因此使用 radix tree 会更加节约内存；另一部分是紧凑列表，radix tree 内的每个`streamID`下对应的子键值对都存储在这个结构中。

迭代器：

```c
typedef struct streamIterator {
    stream *stream;         /* The stream we are iterating. */
    streamID master_id;     /* ID of the master entry at listpack head. */
    uint64_t master_fields_count;       /* Master entries # of fields. */
    unsigned char *master_fields_start; /* Master entries start in listpack. */
    unsigned char *master_fields_ptr;   /* Master field to emit next. */
    int entry_flags;                    /* Flags of entry we are emitting. */
    int rev;                /* True if iterating end to start (reverse). */
    uint64_t start_key[2];  /* Start key as 128 bit big endian. */
    uint64_t end_key[2];    /* End key as 128 bit big endian. */
    raxIterator ri;         /* Rax iterator. */
    unsigned char *lp;      /* Current listpack. */
    unsigned char *lp_ele;  /* Current listpack cursor. */
    unsigned char *lp_flags; /* Current entry flags pointer. */
    /* Buffers used to hold the string of lpGet() when the element is
     * integer encoded, so that there is no string representation of the
     * element inside the listpack itself. */
    unsigned char field_buf[LP_INTBUF_SIZE];
    unsigned char value_buf[LP_INTBUF_SIZE];
} streamIterator;
```

消费者模式相关数据结构：

```c
// 消费组
typedef struct streamCG {
    // 该组的上次交付（未确认）ID
    streamID last_id;       /* Last delivered (not acknowledged) ID for this
                               group. Consumers that will just ask for more
                               messages will served with IDs > than this. */
    // 存储已经发送给客户端，但是还没有收到 XACK 的元素
    // Pending entries list，待处理条目列表
    rax *pel;               /* Pending entries list. This is a radix tree that
                               has every message delivered to consumers (without
                               the NOACK option) that was yet not acknowledged
                               as processed. The key of the radix tree is the
                               ID as a 64 bit big endian number, while the
                               associated value is a streamNACK structure.*/
    // 消费组包含的消费者元素
    rax *consumers;         /* A radix tree representing the consumers by name
                               and their associated representation in the form
                               of streamConsumer structures. */
} streamCG;

/* A specific consumer in a consumer group.  */
// 消费者
typedef struct streamConsumer {
    // 活跃时间
    mstime_t seen_time;         /* Last time this consumer was active. */
    // 消费者名称
    sds name;                   /* Consumer name. This is how the consumer
                                   will be identified in the consumer group
                                   protocol. Case sensitive. */
    // 待 ACK 的消息列表，和 streamCG 指向的是同一个
    rax *pel;                   /* Consumer specific pending entries list: all
                                   the pending messages delivered to this
                                   consumer not yet acknowledged. Keys are
                                   big endian message IDs, while values are
                                   the same streamNACK structure referenced
                                   in the "pel" of the conumser group structure
                                   itself, so the value is shared. */
} streamConsumer;

/* Pending (yet not acknowledged) message in a consumer group. */
// 消费者组中的待处理（尚未确认）消息
typedef struct streamNACK {
    // 上次传递此消息的时间
    mstime_t delivery_time;     /* Last time this message was delivered. */
    // 此消息被传递的次数
    uint64_t delivery_count;    /* Number of times this message was delivered.*/
    // 此消息在上次传递中传递给的消费者
    streamConsumer *consumer;   /* The consumer this message was delivered to
                                   in the last delivery. */
} streamNACK;
```

命令列表：

```c
// XADD 命令，向 Streams 追加新元素
void xaddCommand(client *c)
// XLEN 命令，返回 Streams 中的元素数量
void xlenCommand(client *c)
// XDEL 命令，从 Streams 中删除指定的元素
void xdelCommand(client *c)
// MAXLEN 命令，修剪 Streams 中的元素至指定数量
void xtrimCommand(client *c)
// XINFO 命令，获取 Streams 或其消费组的信息
void xinfoCommand(client *c)
// XRANGE 命令，返回 Streams 中符合指定 ID 范围的元素，正序排列
void xrangeCommand(client *c)
// XREVRANGE 命令，返回 Streams 中符合指定 ID 范围的元素，倒叙排列
void xrevrangeCommand(client *c)
// XREAD 命令，返回 Streams 中尚未被读取过的，且比指定 ID 大的元素
void xreadCommand(client *c)
// XGROUP 命令，用来管理消费者组，创建、销毁等
void xgroupCommand(client *c)
// XACK 命令，从 Streams 消费者组的待处理条目列表中删除一条或多条消息
void xackCommand(client *c)
// XPENDING 命令，返回 Streams 中消费者组的待处理消息
void xpendingCommand(client *c)
// XCLAIM 命令，改变 Streams 待处理消息的消费者所有权
void xclaimCommand(client *c)
```

## 总结

Redis 的对象系统实现了命令多态，根据不同的编码调用不同的底层函数，但也付出了一定的代价，在源码中**存在大量的类型判断与断言**。好在 Redis 是个较为轻量的数据库，源码量并不大，在整体设计并不复杂的情况下，这种暴力而巧妙的实现方式也不难理解。

总结一下对象系统的特点：

- 简化了键值对的操作，例如内存回收、共享对象、命令多态等特性；
- 表与集合类数据都实现了对应的迭代器，便于查询操作；
- 每种对象类型可能对应多种编码方式，根据使用场景进行类型转换；
- 如果操作不当导致类型转换会造成性能损失，在使用时需要格外注意。

个人认为**多数情况下的抉择并不是好与不好，只是适合与不适合**，Redis 的取舍之间也是为了更好地适应应用场景，对此还需要更深入地理解与分析

## Reference

- [Redis Value Type之间的关系](https://www.cnblogs.com/neooelric/p/9621736.html)
- [Redis Commands](https://redis.io/commands)
- Redis 源码注释
- 《Redis 设计与实现》