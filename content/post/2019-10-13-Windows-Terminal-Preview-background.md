---
title: "Windows Terminal Preview 背景图片美化"
author: "beihai"
description: ""
tags: [
    "windows",
    "terminal",
    "随便写写",
]
categories: [
    "windows",
    "terminal",
    "随便写写",
]
lastmod: 
date: 2019-10-13T14:26:48+08:00
draft: false
---

<div align="center">{{< figure src="/image/Windows-Terminal.png" title="Windows Terminal">}}</div>
<!--more-->

## 打开默认图片存储位置{#打开默认图片存储位置}

```bash
 cd %LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\RoamingState
```

将要设置的图片放入RoamingState目录

## 新增配置{#新增配置}

打开配置文件并新增配置：

```json
"backgroundImage" : "ms-appdata:///roaming/test.jpg",
"backgroundImageOpacity" : 0.75
```

 `注：`设置背景图片需要关闭毛玻璃样式，设置：(默认false)

```json
"useAcrylic":false
```

## 完整示例{#完整示例}

```json
        {
            "acrylicOpacity" : 0.5,
            "closeOnExit" : false,
            "colorScheme" : "One Half Dark",
            "commandline" : "powershell.exe",
            "cursorColor" : "#FFFFFF",
            "cursorShape" : "bar",
            "backgroundImage" : "ms-appdata:///roaming/space_5760×1080.png",
            "backgroundImageOpacity" : 0.75,
            "fontFace" : "Cascadia Code",
            "fontSize" : 12,
            "guid" : "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}",
            "historySize" : 9001,
            "icon" : "ms-appx:///ProfileIcons/{61c54bbd-c2c6-5271-96e7-009a87ff44bf}.png",
            "name" : "Windows PowerShell",
            "padding" : "0, 0, 0, 0",
            "snapOnInput" : true,
            "startingDirectory" : "%USERPROFILE%",
            "useAcrylic" : false
        },
```