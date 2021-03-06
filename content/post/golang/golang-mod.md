---
title: Go mod 模块化管理
author: beihai
type: post
date: 2019-07-23T08:21:35+00:00
categories: [
    "Golang",
]

---
## 前言

<span>在Go语言的发展史中，2018年注定是一个重要的时间点，因为在8月正式发布了Go1.11。Go1.11语言部分虽然没有变化，但是带来了3个重量级的更新：一是</span>`amd64`<span>平台完全支持</span>`AVX512`<span>高性能的指令集；二是Go1.11开始支持模块化的特性；三是Go语言开始WebAssembly平台。这几个改进将成为后Go1时代最大的亮点。而模块是管理任何大型工程必备的工具，但是Go语言发布十年来一直缺乏官方的模块化工具。模块化的特性将彻底解决大型Go语言工程的管理问题，至此Go1除了缺少泛型等特性已经近乎完美。从Go1.13开始（2019年8月），模块化将成为默认的特性，彻底告别<code>GOPATH</code>时代；</span>

## 使用

golang 1.11版本开启服务：<code class="null">set GO111MODULE=on</code>，高于此版本不用开启

存在网络环境问题的可以设置代理：<code class="null">export GOPROXY=https://goproxy.io</code>

取消代理（设置地址为空）：<code class="null">export GOPROXY=</code>

<span>使用go mod 管理项目，就不需要非得把项目放到GOPATH指定目录下，你可以在任何目录下新建一个项目：</span>

  * <code class="null">cd Desktop/test</code>
  * <code class="null">go mod init</code> // 初始化模块，会在项目根目录下生成 <code class="null">go.mod</code>文件。
  * <code class="null">go mod tidy</code> // 根据<code class="null">go.mod</code>文件来处理依赖关系，生成<code class="null">go.sum</code>文件
  * `go mod vendor` // <span>将依赖包复制到项目下的 </span>`vendor`<span>目录。<span style="color: #ff0000;">强烈不推荐使用</span>，建议使用被墙包实在无法下载的可以这么处理，方便用户快速使用命令</span>`go build -mod=vendor`<span>编译</span>

  1. <span>go.mod 文件必须要提交到git仓库，但 go.sum 文件可以不用提交到git仓库，go.sum 文件为包签名，跨平台条件下可能会报错；</span>
  2. <span>go 模块版本控制的下载文件及信息会存储到 GOPATH/pkg/mod 文件夹里，src 目录下不再存放包；</span>
  3. <span>环境变量GOPATH不再用于解析imports包路径，即原有的GOPATH/src/下的包，通过import是找不到了。</span>
  4. 旧版 go get 取包过程类似：git clone + go install , 开启Go Module功能后 go get 只有 git clone(download)过程了。老的go get取完主包后，会对其repo下的submodule进行循环拉取。新的go get不再支持submodule子模块拉取。

## 版本问题

在执行编译指令 go build/run 或 go mod tidy 后会根据 import 的包自动索引，但是部分包的 import 路径已经改变，如：echo 的 <code class="null">import </code><code class="null">"github.com/labstack/echo/"</code>索引的包最高为 v3 版本，<code class="null">import </code><code class="null">"github.com/labstack/echo/v4"</code>为echo 的v4版本。