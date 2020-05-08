---
title: "Redis RESP 通信协议 · Analyze"
author: "beihai"
summary: "<blockquote><p>Redis 是 client-server 架构的软件，了解 Redis 客户端与服务端的通信原理，可以更好地理解 Redis 的工作方式。Redis 客户端和服务端之间使用 RESP(REdis Serialization Protocol) 二进制安全文本协议进行通信，该协议是专为 Redis 设计的，但由于该协议实现简单，也可以将其用于其他的项目中。</p></blockquote>"
tags: [
    "Redis",
]
categories: [
    "Analyze",
	"Redis",
	"数据库",
]
keywords: [
    "Redis",
]
date: 2020-02-12T15:00:09+08:00
draft: false
---

> 对 Redis 数据库的源码阅读，当前版本为 Redis 6.0 RC1，参考书籍《Redis 设计与实现》及其注释。项目地址：[github.com/wingsxdu](https://github.com/wingsxdu/redis)

Redis 是 client-server 架构的软件，了解 Redis 客户端与服务端的通信原理，可以更好地理解 Redis 的工作方式。Redis 客户端和服务端之间使用 [RESP(REdis Serialization Protocol)](https://redis.io/topics/protocol) 二进制安全文本协议进行通信，该协议是专为 Redis 设计的，但由于该协议实现简单，也可以将其用于其他的项目中。

> RESP 只是客户端与服务端之间的通信方式，Redis Cluster 使用了另一种的二进制协议在集群节点间进行信息传输。

RESP 是基于 TCP 连接实现的通信协议，并没有做特殊处理，因此支持广泛，有近 50 种语言实现了自己的客户端。作者在设计 RESP 时主要考虑了以下三个要素：

- 易于实现
- 解析快速
- 易于人类阅读

下面就此进行分析。

## 约定

RESP 协议分为请求与回复两部分，并分别进行了格式约定，我们可以按照约定好的格式，自行实现一个客户端。

RESP 协议中请求与回复命令或数据一律以 `\r\n` （CRLF）结尾。

请求命令的格式如下：

```c
*<参数数量> CR LF
$<参数 1 的字节数量> CR LF
<参数 1 的数据> CR LF
...
$<参数 N 的字节数量> CR LF
<参数 N 的数据> CR LF
```

以添加一个字符串键为例：

```shell
redis> SET mykey "myvalue"
"OK"
```

请求命令的打印值如下：

```shell
*3
$3
SET
$5
mykey
$7
myvalue
```

在实际传输过程中则是一个字符串：

```
"*3\r\n$3\r\nSET\r\n$5\r\nmykey\r\n$7\r\nmyvalue\r\n"
```

Redis 提供了五种回复格式，通过检查服务器返回数据的第一个字节， 来确定回复数据的类型：

- 状态回复（status reply）的第一个字节是 `"+"`；
- 错误回复（error reply）的第一个字节是 `"-"；`
- 整数回复（integer reply）的第一个字节是 `":"；`
- 批量回复（bulk reply）的第一个字节是 `"$"；`
- 多条批量回复（multi bulk reply）的第一个字节是 `"*"`。

例如上面添加字符串键的返回值如下：

```shell
"+OK\r\n"
```

由此不难想象出错误回复与整数回复的形式，不再赘述。

## 二进制安全

服务器使用批量回复（bulk reply）来返回二进制安全的字符串，字符串的最大长度为 512 MB，例如执行命令`GET mykey`会返回`myvalue`，回复的格式为：以`$`开头，紧跟着字符串数据的总字节数，以 CRLF 结尾，然后是数据内容，最后再以 CRLF 结尾。

```
"$7\r\nmyvalue\r\n"
```

如果是类似 LRANGE 命令，需要返回一组元素，会使用多条批量回复（multi bulk reply），以数组的形式返回批量数据，数组的内容为前四种回复类型，其格式为：

```
*<数组元素数量> CR LF
<元素 1 的回复类型及数据> CR LF
<元素 2 的回复类型及数据> CR LF
...
<元素 N 的回复类型及数据> CR LF
```

例如一个由 "foo" 和 "bar" 两个批量回复构成的数组的编码：

```
"*2\r\n$3\r\nfoo\r\n$3\r\nbar\r\n"
```

一个包含有三个 integer 元素的数组的编码形式：

```
"*3\r\n:1\r\n:2\r\n:3\r\n"
```

可以看出，批量回复与多条批量回复都会在消息的最前面添加数据的长度，所以程序无须像 JSON 那样， 为了寻找某个特殊字符而扫描整个 payload ， 也无须对发送至服务器的 payload 进行转义。

程序可以在对协议文本中的字符进行处理前， 计算出批量回复或多条批量回复的长度， 这样程序只需调用一次 `read` 函数， 就可以将回复的正文数据全部读入到内存中， 而无须对这些数据做任何的处理。作者也提供了一段示例代码演示这个过程：

```c
#include <stdio.h>

int main(void) {
    unsigned char *p = "$123\r\n";
    int len = 0;

    p++;
    while(*p != '\r') {
        len = (len*10)+(*p - '0');
        p++;
    }

    /* Now p points at '\r', and the len is in bulk_len. */
    printf("%d\n", len);
    return 0;
}
```

而在回复最末尾的 CRLF 不作处理，直接丢弃它们。

## Reference

- [Redis Protocol specification](https://redis.io/topics/protocol)
- [通信协议](http://redisdoc.com/topic/protocol.html#id8)
- [用 Go 来了解一下 Redis 通讯协议](https://juejin.im/post/5b1b428c6fb9a01e5d32f35d)