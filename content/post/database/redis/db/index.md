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

Redis 数据库由结构体`redisDb`表示：

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

#### 键空间

在 redisDb 中使用一个字典来存储键空间：

- 键空间字典的 key 就是键值对的键，每一个 key 都是一个字符串对象；
- 键空间字典的 value 就是键值对的值，这个 value 可以是一个字符串对象、列表对象等对象结构。

一个数据库中的所有键值对都存储在这个巨大的字典结构中

![img](index.assets/v2-83572059d2a3aeae2d5f2a69860e5d57_hd.jpg)

#### 数据库组

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

一次性创建多个数据库是为了满足不同的实际需求，但是因为 Redis 是单线程应用程序，不论创建了多少个数据库，都是由一个主线程进行处理。

## 内存回收

Redis 作为内存型数据库，在恰当的时机对键值对进行回收可以有效减轻服务器压力。目前的回收策略有两种：**过期键删除和内存淘汰机制**，下面是对这两种方法的分析。

#### 过期键删除

在我们设置键值对时，我们可以对其设定**相对过期时间或绝对过期时间**：

- 相对过期时间：使用 EXPIRE 或 PEXPIRE 命令对键值对设置秒级或毫秒级的存活时间；
- 绝对过期时间：使用 EXPIREAT 或 EXPIREAT 命令对键值设置秒级或毫秒级的被删除时间；
- 通过 TTL 或 PTTL 命令来查看键值对秒级或毫秒级的剩余过期时间；
- 

redisDb 的`expires`字段存储着所有设置了过期时间的键值对，当需要检查一个 key 是否过期时，会先从`expires` 中检查该 key 是否存在，如果存在，那么比较存储的时间戳是否小于当前系统的时间来判断是否过期。

Redis 对过期键的删除有三种策略：

1. **定时删除**：在设置键的过期时间的同时，创建一个定时器，当定时器时间到达时执行删除操作；
2. **惰性删除**：当 key 被调用时检查键值对是否过期，但是会造成内存中存储大量的过期键值对，内存不友好，但是极大的减轻CPU 的负担。
3. **定期删除**：Redis 定时扫描数据库，删除其中的过期键，至于删除多少键，根据当前 Redis 的状态决定。



惰性删除策略是由 [db.c](https://github.com/antirez/redis/blob/unstable/src/db.c)源文件中的`expireIfNeeded()`函数实现的，这个函数会先检查键是否过期，如果过期那么执行删除策略

```c
int expireIfNeeded(redisDb *db, robj *key) {
    // 如果键没有过期返回 0 
    if (!keyIsExpired(db,key)) return 0;
    // 如果当前节点不是主节点返回 1
    // 返回 1 并不是一个确切的信息，但作者觉得要比返回 0 更准确一些
    if (server.masterhost != NULL) return 1;
    // 将过期键的数量标记值加 1
    server.stat_expiredkeys++;
    propagateExpire(db,key,server.lazyfree_lazy_expire);
    notifyKeyspaceEvent(NOTIFY_EXPIRED,
        "expired",key,db->id);
    // 删除键
    return server.lazyfree_lazy_expire ? dbAsyncDelete(db,key) :
                                         dbSyncDelete(db,key);
}
```

定期删除策略由 [expire.c](https://github.com/antirez/redis/blob/unstable/src/db.c)源文件中的`activeExpireCycle()`函数执行，这个函数会定期扫描删除数据库中已经过期的键。当带有过期时间的键比较少时，这个函数运行得比较保守，如果带有过期时间的键比较多，那么函数会以更积极的方式来删除过期键，尽可能地释放被过期键占用的内存。

这个函数有**慢循环和快循环**两种工作模式：

- 慢循环：慢循环是主要的工作模式，这种情况下以`server.hz`频率进行查询（每秒执行次数，通常为 10），但是如果慢循环执行了太长时间将会因超时而退出，
- 快循环：快循环的执行时间不会长过`EXPIRE_FAST_CYCLE_DURATION`（默任值为 1000）毫秒，并且在`EXPIRE_FAST_CYCLE_DURATION`毫秒之内不会再重新执行。如果最近一次的慢速循环因为超时被终止，那么本次快循环也会拒绝运行。除此之外，在快速循环中，一旦数据库中已过期键的数量低于给定百分比将会停止检查，以避免进行了很多的检查工作却回收了很少的内存空间，致使事倍功半。





也就是说，Redis 执行删除命令时

#### 内存淘汰







#### 异步删除机制

