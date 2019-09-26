---
title: Ubuntu FISCO BCOS Web3 应用开发环境搭建
author: beihai
type: post
date: 2019-05-29T03:08:31+00:00
url: /?p=1250
hestia_layout_select:
  - sidebar-right
  - sidebar-right
categories:
  - Java
  - 技术向

---
Java 应用的开发环境太繁琐了， 记一下搭建流程。（简化版）

##### 环境搭建

###### 安装JDK

FISCO BCOS 要求 JDK 为Oracle 版本，下载链接：<a href="https://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html" target="_blank" rel="noopener noreferrer">https://www.oracle.com/</a>
  
安装：<code class="null">sudo tar -zxvf jdk-8u211-linux-x64.tar.gz -C /usr/local</code>
  
配置环境变量：vi /etc/profile
  
添加以下代码：

<pre class="pure-highlightjs"><code class="null">export JAVA_HOME=/usr/local/jdk1.8.0_211
export JRE_HOME=${JAVA_HOME}/jre
export CLASSPATH=.:${JAVA_HOME}/lib:${JRE_HOME}/lib
export PATH=${JAVA_HOME}/bin:$PATH</code></pre>

重加载配置文件：<code class="null">source /etc/profile</code>

###### 安装 Gradle

下载链接：<a href="https://gradle.org/releases/" target="_blank" rel="noopener noreferrer">https://gradle.org/releases/</a>
  
安装：<code class="null">sudo unzip -d /opt gradle.zip</code>
  
配置环境变量：vi /etc/profile

<pre class="pure-highlightjs"><code class="null">export GRADLE_HOME=/opt/gradle-5.4.1
export PATH=$GRADLE_HOME/bin:$PATH</code></pre>

重加载配置文件：<code class="null">source /etc/profile</code>

##### 应用开发

IDE：idea

###### 获取 web3 应用开发包，cd 到工程目录下。执行<code class="null">gradle build</code>。

&nbsp;