---
title: Java GRPC proto 编译
author: beihai
type: post
date: 2019-05-23T06:04:45+00:00
tags: [
    "Java",
    "Grpc",
]
categories: [
    "Java",
    "Grpc",
]
---
相较于Go，Java 中的使用步骤就繁琐了很多，我也是折腾了很久才搞清楚。、

#### 环境

ubuntu 16.04

IDE：Intellig IDEA

Java 编译：Gradle

#### proto 编译

使用 Gradle 新建工程，们只用这个工程编译 proto，和工作工程分开操作

###### build.gradle 配置

```java
apply plugin: 'java'
apply plugin: 'com.google.protobuf'
apply plugin: 'idea'
repositories {
    maven { url "https://maven.aliyun.com/repository/central/" }
}
dependencies {
    compile "io.grpc:grpc-netty:1.20.0"
    compile "io.grpc:grpc-protobuf:1.20.0"
    compile "io.grpc:grpc-stub:1.20.0"
}
buildscript {
    repositories {
        maven { url "https://maven.aliyun.com/repository/central/" }
    }
    dependencies {
        classpath 'com.google.protobuf:protobuf-gradle-plugin:0.8.8'
    }
}
protobuf {
    protoc {
        artifact = 'com.google.protobuf:protoc:3.7.1'
    }
    plugins {
        grpc {
            artifact = 'io.grpc:protoc-gen-grpc-java:1.20.0'
        }
    }
    generateProtoTasks {
        ofSourceSet('main')*.plugins {
            grpc { }
        }
    }
}
```

grpc-java 版本信息查看：<a href="https://github.com/grpc/grpc-java" target="_blank" rel="noopener noreferrer">https://github.com/grpc/grpc-java</a>

protobuf-gradle-plugin 版本信息查看：<a href="https://plugins.gradle.org/plugin/com.google.protobuf" target="_blank" rel="noopener noreferrer">https://plugins.gradle.org/plugin/com.google.protobuf</a>

protoc 版本信息查看：在命令行输入：<code class="bash">protoc --version</code>

<img src="https://www.wingsxdu.com/wp-content/uploads/2019/05/ubuntu-proto-version-1.png" alt="" width="737" height="216" class="aligncenter size-full wp-image-1219" /><img src="https://www.wingsxdu.com/wp-content/uploads/2019/05/ubuntu-proto-version-1-1.png" alt="" width="737" height="216" class="size-full wp-image-1219 aligncenter" />

将 user.proto 文件复制到 src/main/proto文件夹下，如图所示：

<img src="https://www.wingsxdu.com/wp-content/uploads/2019/05/java-proto-1.png" alt="" width="1343" height="525" class="aligncenter size-full wp-image-1221" />

右键 user.proto，选择 Recompile&#8221;user.proto&#8221;（第一次编译可能是compile)

<img src="https://www.wingsxdu.com/wp-content/uploads/2019/05/java-proto-1-build-1-1.png" alt="" width="270" height="300" class="size-medium wp-image-1222 aligncenter" /><img src="https://www.wingsxdu.com/wp-content/uploads/2019/05/java-proto-build-1.png" alt="" width="716" height="797" class="aligncenter size-full wp-image-1222" />编译完成后会在 build 目录内生成 grpc和 java 文件夹，将目录内的文件复制到工程内。

<img src="https://www.wingsxdu.com/wp-content/uploads/2019/05/java-proto-get-1.png" alt="" width="677" height="737" class="aligncenter size-full wp-image-1223" />
