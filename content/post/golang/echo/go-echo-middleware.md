---
title: Go Echo 中间件
author: beihai
type: post
date: 2019-05-20T07:41:36+00:00
tags: [
   "golang",
   "echo",
]
categories: [
    "golang",
]
---
##### 1.1简介

中间价是指在 Request 与 Response 之间对数据进行处理，Echo 中间件的存在极大提高了开发效率，可定制化、可自制中间件，十分实用。

##### 1.2使用

###### Static 静态文件

<pre class="pure-highlightjs"><code class="null">e.Use(middleware.StaticWithConfig(middleware.StaticConfig{
	Root:   "dist",
	Browse: true,
}))</code></pre>

返回目录内 dist 文件夹下的静态文件，并在浏览器内打开。

<pre class="pure-highlightjs"><code class="null">e.Static("/download", "data")</code></pre>

路由为/download/filename，返回 data 目录内的静态文件

###### Logger 控制台日志

<pre class="pure-highlightjs"><code class="null">e.Use(middleware.LoggerWithConfig(middleware.LoggerConfig{
	Format: `{"time":"${time_rfc3339_nano}","host":"${host}","remote_ip":"${remote_ip}",` +
		`"method":"${method}","uri":"${uri}","status":${status},"error":"${error}" ` +
		`"latency_human":"${latency_human}","bytes_in":${bytes_in},` +
		`"bytes_out":${bytes_out}}` + "\n",
	Output: os.Stdout,
}))</code></pre>

可选配置：

<pre class="pure-highlightjs"><code class="null">  // - time_unix
  // - time_unix_nano
  // - time_rfc3339
  // - time_rfc3339_nano
  // - id (Request ID)
  // - remote_ip
  // - uri
  // - host
  // - method
  // - path
  // - referer
  // - user_agent
  // - status
  // - error
  // - latency (In nanoseconds)
  // - latency_human (Human readable)
  // - bytes_in (Bytes received)
  // - bytes_out (Bytes sent)
  // - header:&lt;NAME&gt;
  // - query:&lt;NAME&gt;
  // - form:&lt;NAME&gt;
  // - cookie:&lt;NAME&gt;</code></pre>

###### Recover 错误恢复

<pre class="pure-highlightjs"><code class="null">e.Use(middleware.RecoverWithConfig(middleware.RecoverConfig{
  StackSize:  2 &lt;&lt; 10, // 2 KB
}))</code></pre>