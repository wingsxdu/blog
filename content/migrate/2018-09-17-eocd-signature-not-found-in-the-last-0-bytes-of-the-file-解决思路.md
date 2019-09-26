---
title: EOCD signature not found in the last 0 bytes of the file.解决思路
author: beihai
type: post
date: 2018-09-17T13:59:03+00:00
url: /?p=181
classic-editor-remember:
  - classic-editor
  - classic-editor
  - classic-editor
  - classic-editor
categories:
  - Android studio

---
Gradle编译时报错：EOCD signature not found in the last 0 bytes of the file.<!--more-->


  
我出现此问题的原因<span style="display: inline !important; float: none; background-color: transparent; color: #333333; cursor: text; font-family: 'Noto Serif',serif; font-size: 17px; font-style: normal; font-variant: normal; font-weight: 400; letter-spacing: normal; orphans: 2; text-align: left; text-decoration: none; text-indent: 0px; text-transform: none; -webkit-text-stroke-width: 0px; white-space: normal; word-spacing: 0px;">：引入外部 </span>litapal <span style="display: inline !important; float: none; background-color: transparent; color: #333333; cursor: text; font-family: 'Noto Serif',serif; font-size: 17px; font-style: normal; font-variant: normal; font-weight: 400; letter-spacing: normal; orphans: 2; text-align: left; text-decoration: none; text-indent: 0px; text-transform: none; -webkit-text-stroke-width: 0px; white-space: normal; word-spacing: 0px;">包冲突</span>
  
解决方法：删除/app/libs中的jar包，删除app/build.gradle 页面下的相关引用代码，并重新引入jar包，输入以下代码（不用再人为放入jar包到libs里面）

<pre class="pure-highlightjs"><code class="java">implementation 'org.litepal.android:core:2.0.0'</code></pre>

思路：编译器报错，再 build 里面一层一层地找提示错误的包名，重新引入或更换引入方式。
  
&nbsp;