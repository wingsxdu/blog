---
title: "Redis 数据库的实现 · Analyze"
author: "beihai"
summary: "<blockquote><p>Redis 对外提供了六种键值对供开发者使用，而实际上在底层采用了多种基础数据结构来存储信息，并且会在必要的时刻进行类型转换。文章将会逐一介绍这些数据结构，以及它们的独特之处。</p></blockquote>"
tags: [
    "Analyze",
    "数据库",
    "Redis",
]
categories: [
    "Analyze",
	"数据库",
	"Redis",
]
date: 2020-02-08T19:30:30+08:00
draft: false
---

在了解 Redis 的底层数据结构之后，Redis 是如何将这些碎片化的数据以键值对的形式存储在数据库中，并进行销毁、等操作。

## 数据结构

Redis 服务在启动时，会创建可配置量`dbnum`个数据库，`dbnum`的默认值为 16。Redis 会为每个数据库分配 ID，当我们启动一个客户端时，会默认使用 0 号数据库。

```c
struct redisServer{
    ...
    // 当前使用的数据库
    redisDb *db;
    // 创建的数据库数量
    int dbnum;
    ...
}
```

我们可以使用 Select 命令来切换当前客户端使用的数据库，这个命令最终调用的是`selectDb`函数来执行切换步骤。

```c
int selectDb(client *c, int id) {
    if (id < 0 || id >= server.dbnum)
        return C_ERR;
    // 设置当前 client 使用的数据库
    c->db = &server.db[id];
    return C_OK;
}
```

Redis 数据库由结构体`redisDb`表示

```c
typedef struct redisDb {
    // 数据库键空间
    dict *dict;                 /* The keyspace for this DB */
    // 键的过期时间
    dict *expires;              /* Timeout of keys with a timeout set */
    // 正处于阻塞状态的键
    dict *blocking_keys;        /* Keys with clients waiting for data (BLPOP)*/
    // 可以解除阻塞的键
    dict *ready_keys;           /* Blocked keys that received a PUSH */
    // 正在被 WATCH 命令监视的键
    dict *watched_keys;         /* WATCHED keys for MULTI/EXEC CAS */
    // 数据库 ID 
    int id;                     /* Database ID */
    // 数据库的键的平均 TTL，统计信息
    long long avg_ttl;          /* Average TTL, just for stats */
    // 仍存活的过期键游标
    unsigned long expires_cursor; /* Cursor of the active expire cycle. */
    // 尝试进行碎片整理的键名称列表
    list *defrag_later;         /* List of key names to attempt to defrag one by one, gradually. */
} redisDb;
```

- `blocking_keys` 和`ready_keys`用于阻塞型命令（BLPOP等）；
- `watched_keys` 用于事务模块；
- `dict`和`expires`用于存储和销毁键；

在 redisDb 中使用一个字典来存储键空间：

- 键空间字典的 key 就是键值对的键，每一个 key 都是一个字符串对象；
- 键空间字典的 value 就是键值对的值，这个 value 可以是一个字符串对象、列表对象等对象结构。

一个数据库中的所有键值对都存储在这个巨大的字典结构中

![img](index.assets/v2-83572059d2a3aeae2d5f2a69860e5d57_hd.jpg)

`expires`字段则存储着键的过期时间，用于



## 内存回收

Redis 作为内存型数据库，在恰当的时机对键值对进行回收可以有效减轻服务器压力。目前的回收策略有两种：**过期键删除和内存淘汰机制**，下面是对这两种方法的分析

#### 过期键删除

在我们设置键值对时，我们可以对其设定**相对过期时间或绝对过期时间**：

- 相对过期时间：使用 EXPIRE 或 PEXPIRE 命令对键值对设置秒级或毫秒级的存活时间；
- 绝对过期时间：使用 EXPIREAT 或 EXPIREAT 命令对键值设置秒级或毫秒级的被删除时间；
- 通过 TTL 或 PTTL 命令来查看键值对秒级或毫秒级的剩余过期时间。

redisDb 的`expires`字段存储着所有设置了过期时间的键值对，当需要检查一个 key 是否过期时，会先从`expires` 中检查该 key 是否存在，如果存在，那么比较存储的时间戳是否小于当前系统的时间。



#### 内存淘汰





