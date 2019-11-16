---
title: Go ECHO JWT 变量类型
author: beihai
type: post
date: 2019-08-06T10:09:33+00:00
url: /?p=1364
categories:
  - Golang
  - 技术向

---
最近在写自己的开源案例时，需要在 token 里面存入用户的 uid，变量类型为 uint64,然而解析token 中的值时却报错变量不符，类型为 float。示例：

<pre class="pure-highlightjs"><code class="null">claims["uid"] = uid //编码
uid := claims["uid"].(uint64) //解码</code></pre>

但如果编码与解码统一用 string 类型即可正常取值

<pre class="pure-highlightjs"><code class="null">claims["uid"] = strconv.FormatUint(uid, 10) //编码 
uid := claims["uid"].(string) //解码</code></pre>

由于文档里没有介绍具体原因，只能类型转换存进去了