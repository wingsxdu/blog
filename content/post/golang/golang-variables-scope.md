---
title: Go 全局变量作用域于变量覆盖问题
author: beihai
type: post
date: 2019-07-23T10:55:16+00:00
tags: [
    "golang",
]
categories: [
    "golang",
]

---
##### 全局变量作用域

<span>全局变量的作用域是整个包，局部变量的作用域是该变量所在的花括号内。最近使用 gorm 时遇到了使用全局变量赋值作用域的问题。</span>

<pre class="pure-highlightjs"><code class="null">var db *gorm.DB // 全局变量用 =

func Init() {
	db, err := gorm.Open("mysql", "//")
	debug.CheckErr(err)
	//defer db.Close()
}
</code></pre>

如果使用语法糖 := 赋值，全局变量 db 的作用域只在 Init{} 函数内，其他函数内调用会报错空指针。

因此若避免全局变量变成局部变量，应采用 “=&#8221; 写法：

<pre class="pure-highlightjs"><code class="null">var db *gorm.DB // 全局变量用 =

func Init() {
	var err error
	db, err = gorm.Open("mysql", "//")
	debug.CheckErr(err)
	//defer db.Close()
}
</code></pre>

&nbsp;

此时 db 可在包内的其他函数中调用

##### 变量覆盖

如下代码

<pre class="pure-highlightjs"><code class="null">package main

func main() {
	x := 1
	println(x)      // 1
	{
		println(x)  // 1
		x := 2
		println(x)  // 2    // 新的 x 变量的作用域只在代码块内部
	}
	println(x)      // 1
}</code></pre>

  1. <span>代码引用变量时总会最优先查找当前代码块中（不包含任何子代码块）的那个变量；</span>
  2. <span>如果当前代码块中没有声明以此为名的变量，那么程序会沿着代码块的嵌套关系，一层一层的查找；</span>