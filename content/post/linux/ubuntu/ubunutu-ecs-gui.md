---
title: Ubunutu ECS服务器安装界面图形
author: beihai
type: post
date: 2019-05-29T03:52:24+00:00
tags: [
    "Linux",
    "Ubuntu",
]
categories: [
    "Linux",
]

---
linux 服务器都是没有界面图形的——当然也不需要界面图形，会消耗多余的资源。但是为了方便演示和开发调试，也会有界面图形的开发需求。

###### 安装流程

连接服务器：

<pre class="pure-highlightjs"><code class="null">apt-get update
apt-get upgrade
# 安装ubuntu桌面系统，一路默认
apt-get install ubuntu-desktop
# 重启服务器
reb0ot</code></pre>

登录：
  
这时发现只能用 guest 用户登录，需要更改登录用户
  
用 xshell 或putty 以 root 用户登录服务器（我直接用 winscp 修改文件）
  
编辑：<code class="null">/usr/share/lightdm/lightdm.conf.d/50-ubuntu.conf</code>

<pre class="pure-highlightjs"><code class="null"># 修改前
[Seat:*]
user-session=ubuntu
# 修改后
[Seat:*]
user-session=ubuntu
greeter-show-manual-login=true
allow-guest=false</code></pre>

编辑：<code class="null">/root/.profile</code>

<pre class="pure-highlightjs"><code class="null"># 修改前
	# ~/.profile: executed by Bourne-compatible login shells.
	if [ "$BASH" ]; then
	  if [ -f ~/.bashrc ]; then
	    . ~/.bashrc
	  fi
	fi
	mesg n || true
# 修改后
	# ~/.profile: executed by Bourne-compatible login shells.
	if [ "$BASH" ]; then
	  if [ -f ~/.bashrc ]; then
	    . ~/.bashrc
	  fi
	fi
	tty -s && mesg n || true</code></pre>

重启服务器：reboot
  
&nbsp;
  
&nbsp;