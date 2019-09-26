---
title: android:gravity 属性说明
author: beihai
type: post
date: 2018-09-15T04:16:38+00:00
url: /?p=169
categories:
  - Android studio

---
**<span style="text-align: left; text-transform: none; line-height: 24px; text-indent: 0px; letter-spacing: normal; font-family: arial,'courier new',courier,'宋体',monospace; font-size: 14px; font-style: normal; font-variant: normal; text-decoration: none; word-spacing: 0px; display: inline !important; white-space: pre-wrap; word-break: break-all; word-wrap: break-word; orphans: 2; float: none; -webkit-text-stroke-width: 0px; background-color: #f1fedd;">android:gravity意思是这个控件自己的“重力”，在通俗点就是控件上面的东西的位置（图片，文本等）</span>**<!--more-->


  
**<span style="text-align: left; text-transform: none; line-height: 24px; text-indent: 0px; letter-spacing: normal; font-family: arial,'courier new',courier,'宋体',monospace; font-size: 14px; font-style: normal; font-variant: normal; text-decoration: none; word-spacing: 0px; display: inline !important; white-space: pre-wrap; word-break: break-all; word-wrap: break-word; orphans: 2; float: none; -webkit-text-stroke-width: 0px; background-color: #f1fedd;">举个例子：一个TextView里面的文本默认居左作对齐的，你想让这些文本居中的话，只要在这个TextView的属性里加上android:gravity=&#8221;center&#8221;</span>**

<table>
  <tr>
    <th>
      Constant常量
    </th>
    
    <th>
      Value值
    </th>
    
    <th>
      描述
    </th>
  </tr>
  
  <tr>
    <td>
      <code>top</code>
    </td>
    
    <td>
      0x30
    </td>
    
    <td>
      将对象放置在其容器的顶部（top），不改变其大小
    </td>
  </tr>
  
  <tr>
    <td>
      <code>bottom</code>
    </td>
    
    <td>
      0x50
    </td>
    
    <td>
      将对象放置在其容器的底部（bottom），不改变其大小
    </td>
  </tr>
  
  <tr>
    <td>
      <code>left</code>
    </td>
    
    <td>
      0x03
    </td>
    
    <td>
      将对象放置在其容器的左侧（left），不改变其大小
    </td>
  </tr>
  
  <tr>
    <td>
      <code>right</code>
    </td>
    
    <td>
      0x05
    </td>
    
    <td>
      将对象放置在其容器的右侧（right），不改变其大小
    </td>
  </tr>
  
  <tr>
    <td>
      <code>center_vertical</code>
    </td>
    
    <td>
      0x10
    </td>
    
    <td>
      将对象放置在其容器的垂直居中（vertical center），不改变其大小
    </td>
  </tr>
  
  <tr>
    <td>
      <code>fill_vertical</code>
    </td>
    
    <td>
      0x70
    </td>
    
    <td>
      如果需要，增大对象的垂直大小；因此，它完全填满了其容器
    </td>
  </tr>
  
  <tr>
    <td>
      <code>center_horizontal</code>
    </td>
    
    <td>
      0x01
    </td>
    
    <td>
      将对象放置在其容器的水平居中（horizontal center），不改变其大小
    </td>
  </tr>
  
  <tr>
    <td>
      <code>fill_horizontal</code>
    </td>
    
    <td>
      0x07
    </td>
    
    <td>
      如果需要，增大对象的水平大小；因此，它完全填满了其容器
    </td>
  </tr>
  
  <tr>
    <td>
      <code>center</code>
    </td>
    
    <td>
      0x11
    </td>
    
    <td>
      将对象放置在其容器的垂直居中（vertical center）和水平居中（horizontal center），不改变其大小
    </td>
  </tr>
  
  <tr>
    <td>
      <code>fill</code>
    </td>
    
    <td>
      0x77
    </td>
    
    <td>
      如果需要，增大对象的垂直大小和水平大小；因此，它完全填满了其容器
    </td>
  </tr>
  
  <tr>
    <td>
      <code>clip_vertical</code>
    </td>
    
    <td>
      0x80
    </td>
    
    <td>
      附加选项，它被设置用于依据其容器的边界，裁剪子控件的顶部或/和底部的边缘；<br /> 裁剪区域将基于垂直对齐：靠顶部的，将裁剪底部边缘；靠底部的，将裁剪顶部边缘；两这都不靠的，同时裁剪顶部和底部的边缘。
    </td>
  </tr>
  
  <tr>
    <td>
      <code>clip_horizontal</code>
    </td>
    
    <td>
      0x08
    </td>
    
    <td>
      附加选项，它被设置用于依据其容器的边界，裁剪子控件的左侧或/和右侧的边缘；<br /> 裁剪区域基于水平对齐：靠左的裁剪右边缘；靠右的裁剪左边缘；左右都不靠的，同时裁剪左边缘和右边缘。
    </td>
  </tr>
  
  <tr>
    <td>
      <code>start</code>
    </td>
    
    <td>
      0x00800003
    </td>
    
    <td>
      将对象放置在其容器的开始处（beginning），不改变其大小
    </td>
  </tr>
  
  <tr>
    <td>
      <code>end</code>
    </td>
    
    <td>
      0x00800005
    </td>
    
    <td>
      将对象放置在其容器的结束处（end），不改变其大小
    </td>
  </tr>
</table>

&nbsp;
  
&nbsp;