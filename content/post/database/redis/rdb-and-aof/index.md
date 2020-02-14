---
title: "Redis RDB 与 AOF 持久化 · Analyze"
author: "beihai"
summary: "<blockquote><p>Redis 是内存数据库，将数据保存在内存中，以换取更快的读取速度。但由于内存是易失性存储器，一旦进程退出或者硬件设备出现故障，Redis 存储的数据可能就会丢失。为了解决数据持久化问题，Redis 提供了 RDB 快照与 AOF 写操作记录两种方案，这篇文章就这两种分案的运行方案进行分析。</p></blockquote>"
tags: [
    "Analyze",
    "通信协议",
    "Redis",
]
categories: [
    "Analyze",
	"Redis",
]
date: 2020-02-15T11:00:09+08:00
draft: false

---

> 对 Redis 数据库的源码阅读，当前版本为 Redis 6.0 RC1，参考书籍《Redis 设计与实现》及其注释。项目地址：[github.com/wingsxdu](https://github.com/wingsxdu/redis)

Redis 是内存数据库，将数据保存在内存中，以换取更快的读取速度。但由于内存是易失性存储器，一旦进程退出或者硬件设备出现故障，Redis 存储的数据可能就会丢失。为了解决数据持久化问题，Redis 提供了 RDB 快照与 AOF 写操作记录两种方案，这篇文章就这两种分案的运行方案进行分析。

## RDB 快照

RDB（Redis DataBase）是一种快照存储持久化方式，将 Redis 某一时刻的内存数据保存到硬盘的文件中，默认的文件名为`dump.rdb`。当 Redis 服务器启动时，会重新加载`dump.rdb`文件的数据到内存当中恢复数据。

启动 RDB 快照备份的方式有两种，一种是客户端向服务端发送`SAVE`或`BGSAVE`命令手动开启备份，另一种是设置触发 RDB 快照的条件，程序自动检查是否需要备份。

无论是哪种备份方式，RDB 的备份流程如下：

1. 生成临时 rdb 文件，写入数据；
2. 数据写入完成，用临时文代替代正式 rdb 文件；
3. 删除原来的 rdb 文件。

#### 数据结构

由于有关 RDB 快照的结构定义比较庞杂，涉及 RDB 的状态、管道通信、子进程信息等，下面只列举出了比较主要的变量定义：

```c
struct redisServer {
    /* RDB persistence */
    long long dirty;                /* Changes to DB from the last save */
    long long dirty_before_bgsave;  /* Used to restore dirty on failed BGSAVE */
    pid_t rdb_child_pid;            /* PID of RDB saving child */
    struct saveparam *saveparams;   /* Save points array for RDB */
    int saveparamslen;              /* Number of saving points */
    time_t lastbgsave_try;          /* Unix time of last attempted bgsave */
    time_t rdb_save_time_last;      /* Time used by last RDB save run. */

    int rdb_bgsave_scheduled;       /* BGSAVE when possible if true. */
    // 上一次 BGSAVE 成功还是失败
    int lastbgsave_status;          /* C_OK or C_ERR */
}
```



#### 手动备份

`SAVE`命令与`BGSAVE`都可以开启 RDB 持久化功能，**区别在于`SAVE`命令使用 Redis 的主进程进行备份**，这会导致 Redis 服务器阻塞，客户端发送的所有命令请求都会被拒绝，直到 RDB 文件创建完毕。**而`BGSAVE`命令会 fork 出一个子进程执行 I/O 写入操作**，在这期间主进程仍然可以处理命令请求。需要注意的是，子进程快照备份的数据为它被创建时的数据状态，在执行备份期间添加、修改、删除的数据并不会被备份。

这两个命令最终都会调用`rdbSave()`函数将数据库保存到磁盘上，笔者当前版本的备份流程发生了一些变动，由于 module 的加入，最终将数据写入硬盘过程由`moduleFireServerEvent()`函数执行，这是一个可以被其他 module 功能中断的内部函数，以适应新版本的特性。

Redis 处于性能与避免并发问题的考虑，在执行 RDB 命令时会检查当前服务端的状态，在`BGSAVE`命令期间，不允许再执行任何 RBD 操作，AOF 命令也会被延迟到 RDB 快照完成之后执行，以避免多个进程进行大量写入操作引发冲突。除此之外，程序还会检查是否有其他子进程正在运行，如果有会返回一个错误。

```c
int rdbSaveBackground(char *filename, rdbSaveInfo *rsi) {
    if (hasActiveChildProcess()) return C_ERR;
    ...
}

int hasActiveChildProcess() {
    return server.rdb_child_pid != -1 ||
           server.aof_child_pid != -1 ||
           server.module_child_pid != -1;
}
```

#### 自动间隔备份

除了让客户端发送备份执行备份之外，Redis 也提供了自动间隔 RDB 备份功能，我们可以通过`save <seconds> <changes>  `命令设置一个或多个触发条件，表示在`seconds`秒内，如果发生了至少`changes`次数据变化，就会自动触发`bgsave`命令。

触发条件保存在`redisServer.saveparams`中，使用结构体`saveparam`表示：

```c
struct saveparam {
    time_t seconds;
    int changes;
};
```

Redis 还持有一个`redisServer.dirty`计数器，保存着自上次成功执行 RDB 以来，数据库被修改的次数，以及`redisServer.lastsave`，记录上次成功执行 RDB 的时间。在服务端的周期函数中`serverCron()`会周期性检查当前是否有子进程在执行持久化任务，如果没有则会检查是否需要执行 RDB 或 AOF 持久化

```c
int serverCron(struct aeEventLoop *eventLoop, long long id, void *clientData) {
        if (hasActiveChildProcess() || ldbPendingChildren())
    {
        checkChildrenDone();
    } else {
         // 遍历所有保存条件，检查是否需要执行 BGSAVE 命令
        for (j = 0; j < server.saveparamslen; j++) {
            struct saveparam *sp = server.saveparams+j;
            if (server.dirty >= sp->changes &&
                server.unixtime-server.lastsave > sp->seconds &&
                (server.unixtime-server.lastbgsave_try >
                 CONFIG_BGSAVE_RETRY_DELAY ||
                 server.lastbgsave_status == C_OK))
            {
                serverLog(LL_NOTICE,"%d changes in %d seconds. Saving...",
                    sp->changes, (int)sp->seconds);
                rdbSaveInfo rsi, *rsiptr;
                rsiptr = rdbPopulateSaveInfo(&rsi);
                rdbSaveBackground(server.rdb_filename,rsiptr);
                break;
            }
        }

        // 是否需要执行 AOF
        if (server.aof_state == AOF_ON &&
            !hasActiveChildProcess() &&
            server.aof_rewrite_perc &&
            server.aof_current_size > server.aof_rewrite_min_size)
        {
            long long base = server.aof_rewrite_base_size ?
                server.aof_rewrite_base_size : 1;
            long long growth = (server.aof_current_size*100/base) - 100;
            if (growth >= server.aof_rewrite_perc) {
                serverLog(LL_NOTICE,"Starting automatic rewriting of AOF on %lld%% growth",growth);
                rewriteAppendOnlyFileBackground();
            }
        }
    }
}
```





## 总结

Reids 作者 antirez 在 [Redis persistence demystified](http://antirez.com/post/redis-persistence-demystified.html) 一文中讲述了 RDB 和 AOF 各自的优缺点：

- RDB 是一个紧凑压缩的二进制文件，代表 Redis 在某个时间点上的数据备份。非常适合备份、全量复制等场景。比如每 6 小时执行`BGSAVE`备份，并把 RDB 文件拷贝到远程机器或者文件系统中，用于灾难恢复；
- Redis 加载 RDB 恢复数据远远快于 AOF 的方式；
- RDB 方式数据无法做到实时持久化，而 AOF 方式可以做到。