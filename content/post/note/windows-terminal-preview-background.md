---
title: "Windows Terminal Preview 背景图片美化"
author: "beihai"
description: ""
tags: [
    "Windows",
    "Terminal",
    "备忘录",
]
categories: [
    "Windows",
    "Terminal",
]
lastmod: 
date: 2019-10-13T14:26:48+08:00
draft: false
---

<div align="center">{{< figure src="/image/Windows-Terminal.png" title="Windows Terminal">}}</div>
<!--more-->

#### 打开默认图片存储位置

```bash
cd %LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\RoamingState
```

将要设置的图片放入RoamingState目录

#### 新增配置

打开配置文件并新增配置：

```json
"backgroundImage" : "ms-appdata:///roaming/test.jpg",
"backgroundImageOpacity" : 0.75
```

 `注：`设置背景图片需要关闭毛玻璃样式，设置：(默认false)

```json
"useAcrylic":false
```

#### 完整示例

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

#### 设置 WSL 版本

设置默认版本为 WSL2,这将使任何新安装的发行版将初始化为 WSL 2 发行版。 

```powershell
wsl --set-default-version 2
```

或者手动切换

```powershell
wsl --set-version Ubuntu-18.04 2
```

#### 获取日期时间字符串

```powershell
echo %date%
```

输出结果格式与 Windows 设置中的区域格式数据一致

自定义格式示例:

```powershell
echo %date:~10,4%-%date:~4,2%-%date:~7,2%
```

%date:~10,4% 表示从左向右指针向右偏10位，然后从指针偏移到的位置开始提取4位字符，结果是2019（年的值）

%date:~4,2% 表示指针从左向右偏移4位，然后从偏移处开始提取2位字符，结果是10（月）

%date:~7,2% 表示指针从左向右偏移7位，然后从偏移处开始提取2位字符，结果是18（日）

#### 解决双系统时间不一致

Windows把计算机硬件时间当作本地时间(local time)，所以在Windows系统中显示的时间跟 BIOS 中显示的时间是一样的。Linux/Unix/Mac把计算机硬件时间当作 UTC， 所以在Linux/Unix/Mac系统启动后在该时间的基础上，加上电脑设置的时区数（ 比如我们在中国，它就加上“8” ），因此，Linux/Unix/Mac系统中显示的时间总是比Windows系统中显示的时间快8个小时。所以，当你在Linux/Unix/Mac系统中，把系统现实的时间设置正确后，其实计算机硬件时间是在这个时间上减去8小时，所以当你切换成Windows系统后，会发现时间慢了8小时。

修改 Windows对硬件时间的对待方式，让 Windows把硬件时间当作UTC：（需要重启）

在 Terminal  管理员权限下输入：

```powershell
Reg add HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation /v RealTimeIsUniversal /t REG_DWORD /d 1
```

