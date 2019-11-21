---
title: "一些经常忘记的命令"
author: "beihai"
description: ""
tags: [
    "linux",
    "windows",
    "备忘录",
    "terminal"
]
categories: [
    "linux",
    "windows",
    "terminal"
]
lastmod: 
date: 2019-10-18T12:50:20+08:00
draft: false
---

## Ubuntu{#Ubuntu}

#### Ubuntu 后台运行程序{##Ubuntu 后台运行程序}

```bash
nohup ./test
```

输出 appendding output to 'nohub.out'  大意为将命令行输出的信息写入到'nohub.out'文件

 如何关闭进程?

```bash
ps -A  # 列出所有的进程

kill 1234 # 杀死进程命令
```

#### Ubuntu 18.04 更改阿里源{##Ubuntu 18.04 更改阿里源}

备份源文件

```bash
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak 
```

清空文件

```bash
sudo > /etc/apt/sources.list
```

写入阿里源

```bash
sudo vim /etc/apt/sources.list
```

```
deb http://mirrors.aliyun.com/ubuntu/ trusty main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ trusty-security main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ trusty-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ trusty-proposed main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ trusty-backports main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ trusty main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ trusty-security main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ trusty-updates main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ trusty-proposed main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ trusty-backports main restricted universe multiverse
```



## Windows{#Windows}

#### 获取日期时间字符串{##获取日期时间字符串}

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

#### 设置 WSL 版本{##设置 WSL 版本}

设置默认版本为 WSL2,这将使任何新安装的发行版将初始化为 WSL 2 发行版。 

```powershell
wsl --set-default-version 2
```

或者手动切换

```powershell
wsl --set-version Ubuntu-18.04 2
```

#### 解决双系统时间不一致{##解决双系统时间不一致}

Windows把计算机硬件时间当作本地时间(local time)，所以在Windows系统中显示的时间跟 BIOS 中显示的时间是一样的。Linux/Unix/Mac把计算机硬件时间当作 UTC， 所以在Linux/Unix/Mac系统启动后在该时间的基础上，加上电脑设置的时区数（ 比如我们在中国，它就加上“8” ），因此，Linux/Unix/Mac系统中显示的时间总是比Windows系统中显示的时间快8个小时。所以，当你在Linux/Unix/Mac系统中，把系统现实的时间设置正确后，其实计算机硬件时间是在这个时间上减去8小时，所以当你切换成Windows系统后，会发现时间慢了8小时。

修改 Windows对硬件时间的对待方式，让 Windows把硬件时间当作UTC：（需要重启）

在 Terminal  管理员权限下输入：

```powershell
Reg add HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation /v RealTimeIsUniversal /t REG_DWORD /d 1
```

