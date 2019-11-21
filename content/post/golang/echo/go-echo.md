---
title: Go echo 使用
author: beihai
type: post
date: 2018-12-10T12:30:45+00:00
tags: [
    "golang",
]
categories: [
    "golang",
]
---
<p class="has-body-font-size">
  <strong>1.安装</strong>
</p>

<p style="font-size: 16px;">
  虽然echo框架托管在github，但是一些必要的运行组件package需要到官网去下载，然而官网又在墙外。。。首先确定cmd能否ping通外网，打开cmd输入命令：www.google.com  注意ie代理只能浏览器上外网，cmd代理自行百度。ping通后输入指令：
</p>

<p class="has-text-color has-accent-color">
  go get -u github.com/labstack/echo/…
</p>

<p style="font-size: 16px;">
  后面的 &#8230; 为自行检查包文件结构，不要省略。如果没有梯子是不可能用这么简单的方法安装成功的，但是可以通过 github 或者 git clone 手动下载package再执行go install 安装，相当之麻烦。
</p>

<p style="font-size: 16px;">
  下载完成后在 echo package 内打开cmd，执行  go test，通过则安装成功。
</p>

若无法连接外网，可参考此篇文章手动下载包：[Go 下载包 golang.org/x/][1]

<p class="has-body-font-size">
  <strong>2.Hello Word</strong>
</p>

<p style="font-size: 16px;">
  开发环境：Goland。新建一个工程，新建文件  serve.go，输入代码：
</p>

<pre class="pure-highlightjs"><code class="null">package main
import (
	"net/http"
	"github.com/labstack/echo"
)
func main() {
	e := echo.New()
	e.GET("/", func(c echo.Context) error {
		return c.String(http.StatusOK, "Hello, World!")
	})
	e.Logger.Fatal(e.Start(":1323"))
}</code></pre>

<p style="font-size: 12px;">
  <span style="font-size: 12pt;">执行 go run serve.go 或点击运行按钮，打开<a href="http://localhost:1323/" target="_blank" rel="noreferrer noopener">http://localhost:1323/</a></span>
</p>

<span style="font-size: 14pt;"><strong>3. e.get 方法</strong></span>

<span style="font-size: 12pt;">Hello Word 中使用的是匿名函数，现在我们修改代码为：</span>

<pre class="pure-highlightjs"><code class="null">package main
import (
	"net/http"
	"github.com/labstack/echo"
)
func main() {
	e := echo.New()
        e.GET("/users/:id", getUser)
	e.Logger.Fatal(e.Start(":1323"))
}
func getUser(c echo.Context) error {
  	// User ID from path `users/:id`
  	id := c.Param("id")
	return c.String(http.StatusOK, id)
}</code></pre>

<span style="font-size: 12pt;">执行 go run serve.go 或点击运行按钮，打开<a href="http://localhost:1323/users/Joe" target="_blank" rel="noopener noreferrer">http://localhost:1323/users/Joe</a>。</span>

<span style="font-size: 12pt;">更多使用方法可以仿照官网:<a href="https://echo.labstack.com/guide" target="_blank" rel="noopener noreferrer">https://echo.labstack.com/guide</a></span>

<p style="font-size: 12px;">
</p>

 [1]: https://www.wingsxdu.com/blog/tech/1095/