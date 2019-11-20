---
title: Go 下载包 golang.org/x/
author: beihai
type: post
date: 2019-05-13T17:22:20+00:00
hestia_layout_select:
  - sidebar-right
  - sidebar-right
categories:
  - Golang
  - 技术向

---
由于伟大的长城防火墙的存在，我们在使用到 golang.org/x/ 下的包是万万不可能正常下载成功的。但是问题不大，我们可以面向 github 编程，<span>我们可以使用 git 指令把代码clone到创建的 golang.org/x 目录下。</span>
  
整理常用包如下：

  1. git clone https://github.com/golang/sys.git
  2. git clone https://github.com/golang/net.git
  3. git clone https://github.com/golang/text.git
  4. git clone https://github.com/golang/lint.git
  5. git clone https://github.com/golang/tools.git
  6. git clone https://github.com/golang/crypto.git