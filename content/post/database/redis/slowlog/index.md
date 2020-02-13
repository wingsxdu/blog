---
title: "Redis 慢查询日志 · Analyze"
author: "beihai"
summary: "<blockquote><p>Redis 的慢查询日志功能用来记录执行时间超过给定时长的命令请求，我们可以利用这个功能分析和优化查询速度。本篇文章将会对 Redis 的慢查询日志功能的实现原理进行分析。</p></blockquote>"
tags: [
    "Analyze",
    "通信协议",
    "Redis",
]
categories: [
    "Analyze",
	"Redis",
]
date: 2020-02-13T17:16:59+08:00
draft: false

---

> 对 Redis 数据库的源码阅读，当前版本为 Redis 6.0 RC1。注释项目地址：[github.com](https://github.com/wingsxdu/redis)

Redis 的慢查询日志功能用来记录执行时间超过给定时长的命令请求，我们可以利用这个功能分析和优化查询速度。本篇文章将会对 Redis 的慢查询日志功能的实现原理进行分析。

Redis 提供了两个有关慢查询日志的配置项：

- **slowlog-log-slower-than**：指定执行时间超过多少微秒的命令请求将会被记录到日志上，默认为 10000 微秒；
- **slowlog-max-len**：指定服务器最多保存多少条慢查询日志， 当 Redis 储存的慢查询日志数量达到指定值时， 服务器在添加新的慢查询日志之前，会先将最旧的一条慢查询日志删除。

我们可以使用 CONFIG SET/GET 命令来设置/获取这两个选项的值，需要注意的是，**慢查询日志保存在内存而不是日志文件中**，这确保了慢查询日志不会成为速度的瓶颈。

## 数据结构

在`redisServer`结构体中定义了 slowlog 的数据结构：

```c
struct redisServer {
    ...
    // 保存了所有慢查询日志的链表
    list *slowlog;                  /* SLOWLOG list of commands */
    // 下一条慢查询日志的 ID
    long long slowlog_entry_id;     /* SLOWLOG current entry ID */
    // 服务器配置 slowlog-log-slower-than 选项的值
    long long slowlog_log_slower_than; /* SLOWLOG time limit (to get logged) */
    // 服务器配置 slowlog-max-len 选项的值
    ...
};
```

由此可以看出，slowlog 存储在一个双向链表里面，以方便我们在表头插入新的日志，当日志量达到设定的存储上限时，会从表尾进行删除。

一条慢查询日志的数据存储在结构体`slowlogEntry`中，保存了超时命令的参数、时长、日志 ID、客户端等信息。

```c
typedef struct slowlogEntry {
    // 命令与参数
    robj **argv;
    // 命令与命令参数的数量
    int argc;
    // 日志 ID
    long long id;       /* Unique entry identifier. */
    // 执行命令消耗的时间，以微秒为单位
    long long duration; /* Time spent by the query, in microseconds. */
    // 命令执行时的 UNIX 时间戳
    time_t time;        /* Unix time at which the query was executed. */
    // 客户端名称
    sds cname;          /* Client name. */
    // 客户端地址
    sds peerid;         /* Client network address. */
} slowlogEntry;
```

而一个`slowlog`链表的值就是指向日志节点`slowlogEntry`的指针，共同组成了慢查询日志的数据结构。当需要添加新的日志时，调用链表的添加新节点函数，将指针添加到链表头部。

```c
slowlogEntry *slowlogCreateEntry(client *c, robj **argv, int argc, long long duration) {
    slowlogEntry *se = zmalloc(sizeof(*se));
    ...
    return se;
}
listAddNodeHead(server.slowlog,slowlogCreateEntry(c,argv,argc,duration));
```

而`redisServer.slowlog_entry_id`为什么是下一条日志的 ID？这是一个 C 语言语法问题，在设置日志 ID 时的具体代码为：

```c
se->id = server.slowlog_entry_id++;
```

这行代码会先将`server.slowlog_entry_id`的值赋值给`se.id`，然否再将自身值加一。（总感觉这样写有点别扭）

## 添加日志

在 Redis 服务初始化过程中，也会执行慢查询功能的初始化函数，创建一个空的双向链表：

```c
void slowlogInit(void) {
    server.slowlog = listCreate();
    server.slowlog_entry_id = 0;
    listSetFreeMethod(server.slowlog,slowlogFreeEntry);
}
```

当客户端向服务端发送一条命令时，控制流程将交给`server.c/call`，这个函数会调用命令的实现函数执行命令，并计算执行命令所花费的时间，交由 slowlog 函数处理：

```c
void call(client *c, int flags) {
    start = server.ustime;
    // 执行命令实现函数
    c->cmd->proc(c);
    // 计算命令执行耗费的时间
    duration = ustime()-start;
    slowlogPushEntryIfNeeded(c,c->argv,c->argc,duration);
    ...
}

void slowlogPushEntryIfNeeded(client *c, robj **argv, int argc, long long duration) {
    // 慢查询功能未开启，直接返回
    if (server.slowlog_log_slower_than < 0) return; /* Slowlog disabled */
    // 如果执行时间超过服务器设置的上限，那么将命令添加到慢查询日志
    if (duration >= server.slowlog_log_slower_than)
        // 新日志添加到链表表头
        listAddNodeHead(server.slowlog,
                        slowlogCreateEntry(c,argv,argc,duration));

    /* Remove old entries if needed. */
    // 如果日志数量过多，那么进行删除
    while (listLength(server.slowlog) > server.slowlog_max_len)
        listDelNode(server.slowlog,listLast(server.slowlog));
}
```

从上面的摘要代码可以看出，具体的逻辑判断都交给`slowlogPushEntryIfNeeded()`函数执行，当命令超时会添加新的日志，如果日志数量达到上限还会执行删除操作。

slowlog 的实现逻辑不难理解，如果超时就在链表表头加入新元素，如果日志数量达到上限就从链表表尾移除一个元素，这大概也是得益于 Redis 的单线程设计，避免了并发问题。

## Reference

- 《Redis 设计与实现》