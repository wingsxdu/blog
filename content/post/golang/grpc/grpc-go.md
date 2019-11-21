---
title: Go GRPC使用
author: beihai
type: post
date: 2019-05-22T11:59:06+00:00
tags: [
    "golang",
    "grpc",
]
categories: [
    "golang",
    "grpc",
]
---
##### 1.1RPC简介

<span>RPC，全称 Remote Procedure Call——远程过程调用，主要用于分布式系统中程序间的通信，基于 TCP 或 UDP 传输协议实现。RPC 属于 IPC（进程间通信）的分支，除 RPC 外还有共享内存、channel 等。</span>
  
<span>GRPC 是谷歌开源的一个高性能、跨语言的 RPC 框架，基于 HTTP2 、Protobuf 和 Netty 4.x ; GRPC 的优势不在于性能，而是跨语言，还和 Golang 有同一个爹。。。</span>
  
GRPC 官网：<https://grpc.io/>

##### 1.2  Protobuf 简介

**Google Protocol Buffer(简称 Protobuf)是一种轻便高效的结构化数据存储格式，平台无关、语言无关、可扩展，可用于通讯协议和数据存储等领域。**
  
简言之，这是一种跨语言的结构化数据存储格式，类似于 JSON
  
官网：<a href="https://developers.google.cn/protocol-buffers/docs/proto3" target="_blank" rel="noopener noreferrer">https://developers.google.cn/protocol-buffers/docs/proto3</a>
  
中文文档：<a href="http://doc.oschina.net/grpc?t=56831" target="_blank" rel="noopener noreferrer">http://doc.oschina.net/grpc?t=56831</a>

##### 1.2 环境配置

工作环境：ubuntu 16.04

###### protobuf 安装

官方教程：<https://github.com/protocolbuffers/protobuf/blob/master/src/README.md>

<pre class="pure-highlightjs"><code class="bash">$ sudo apt-get install autoconf automake libtool curl make g++ unzip
$ git clone https://github.com/google/protobuf.git
$ cd protobuf
$ git submodule update --init --recursive
$ ./autogen.sh
$ ./configure
$ make
$ make check
$ sudo make install
$ sudo ldconfig # refresh shared library cache.</code></pre>

安装完成后输入：protoc &#8211;version 查看版本信息
  
<img src="https://www.wingsxdu.com/wp-content/uploads/2019/05/ubuntu-proto-version-1-1.png" alt="" width="737" height="216" class="alignnone size-full wp-image-1219" />

###### Go语言 Protobuf 编译

Go语言版 grpc下载：

<pre class="pure-highlightjs"><code class="null">$ go get -u google.golang.org/grpc</code></pre>

若由于网络问题无法下载，使用 github 镜像再将包移动到 google.golang.org：

<pre class="pure-highlightjs"><code class="null">$ go get -u github.com/grpc/grpc-go</code></pre>

Go语言 proto 编译环境：

<pre class="pure-highlightjs"><code class="null">$ go get -u github.com/golang/protobuf/protoc-gen-go</code></pre>

同理&#8230;使用了很多 golang.org/ 包，镜像下载参考：[Go 下载包 golang.org/x/][1]

##### 1.3实战使用

###### 定义 proto

新建 user.proto 文件

<pre class="pure-highlightjs"><code class="null">syntax = "proto3"; //Protocol Buffers Version
//定义的service
service CreateAccount{
    rpc CreateAccount(CreateAccountRequest) returns (CreateRequestResponse){}
}
//请求的结构体
message CreateAccountRequest{
    string uid = 1;
    string service = 2;
}
//返回的结构体
message CreateRequestResponse{
    string value = 1;
}</code></pre>

编译 Go 源码，生成user.pb.go（将package user改为 hello)

<pre class="pure-highlightjs"><code class="null">$ protoc --go_out=plugins=grpc:. hello.proto</code></pre>

###### Go 客户端

新建userClient.go

<pre class="pure-highlightjs"><code class="null">func CreateAccount(uid string, service string) (value string, err error){
	conn, err := grpc.Dial("localhost:1330", grpc.WithInsecure())
	if err != nil {
		fmt.Println(err)
		return "error", err
	}
	defer conn.Close()
	client := hello.NewCreateAccountClient(conn)
	Value, err := client.CreateAccount(context.Background(), &hello.CreateAccountRequest{Uid:uid,Service:service})
	if err != nil {
		fmt.Println(err)
		return "error", err
	}
	return Value.Value,nil
}</code></pre>

###### Go服务端

新建userServer.go

<pre class="pure-highlightjs"><code class="null">type server struct{}
func (s *server) CreateAccount(ctx context.Context,response *hello.CreateAccountRequest) (*hello.CreateRequestResponse, error){
	fmt.Println(response.Uid+response.Service)
	return &hello.CreateRequestResponse{Value:"hello =======&gt; " + response.Uid},nil
}
func main(){
	lis,err := net.Listen("tcp","1330")
	if err != nil {
		log.Fatal("fail to listen")
	}
	s := grpc.NewServer()
	hello.RegisterCreateAccountServer(s,&server{})
	reflection.Register(s)
	if err:= s.Serve(lis);err != nil{
		log.Fatal("fail to server")
	}
}</code></pre>

###### 调用

开启 server 端保持监听端口1330状态，调用<code class="null">CreateAccount()</code>函数传值即可。
  
&nbsp;

 [1]: https://www.wingsxdu.com/?p=1095