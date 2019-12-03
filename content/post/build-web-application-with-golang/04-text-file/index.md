---
title: "04-文本文件处理"
author: "beihai"
description: "Build Web Application With Golang"
summary: "<blockquote><p>一个 Web 应用应该具有哪些特性，开发过程中注意哪些问题，这是我在初学 Web 时常常思考的问题。在此系列中作者不会用长长的列表指出开发者需要掌握的工具、框架，也不会刻画入微地去深究某一项程序设计的实现原理，旨在为初学者构建知识体系。如果你有想了解的问题、错误指正，可以在文章下面留言。</p></blockquote>"
tags: [
    "Golang",
    "Build Web Application With Golang",
]
categories: [
    "Build Web Application With Golang",
]
date: 2019-11-30T13:31:39+08:00
draft: false
---
![](/image/build-web-application-with-golang.png)

> 一个 Web 应用应该具有哪些特性，开发过程中注意哪些问题，这是我在初学 Web 时常常思考的问题。在此系列中作者不会用长长的列表指出开发者需要掌握的工具、框架，也不会刻画入微地去深究某一项程序设计的实现原理，旨在为初学者构建知识体系。如果你有想了解的问题、错误指正，可以在文章下面留言。

## FORM 表单

表单是客户端和服务器进行数据交互常用的工具，通常情况下可以将表单转换成 XML 或 JSON 格式再提交服务器。表单的形式一般如下：

```html
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <title>Multiple file upload</title>
</head>
<body>
<h1>Upload multiple files with fields</h1>

<form action="/upload" method="post" enctype="multipart/form-data">
    Name: <input type="text" name="name"><br>
    Email: <input type="email" name="email"><br>
    Files: <input type="file" name="files" multiple><br><br>
    <input type="submit" value="Submit">
</form>
</body>
</html>
```

form 与 XML 和 JSON 的不同之处就是能够上传文件。要使表单能够上传文件，首先要添加 form 的`enctype`属性，`enctype`属性有如下三种情况：

```http
application/x-www-form-urlencoded   表示在发送前编码所有字符（默认）
multipart/form-data      不对字符编码。在使用包含文件上传控件的表单时，必须使用该值。
text/plain      空格转换为 "+" 加号，但不对特殊字符编码。
```

上传文件需要第二种属性，对应的 HTTP header：

```http
Content-Type: multipart/form-data
```

对文件进行处理：

```go
func upload(w http.ResponseWriter, r *http.Request) {
	if r.Method == "POST" {
		r.ParseMultipartForm(32 << 20)
		file, handler, err := r.FormFile("files")
		if err != nil {
			fmt.Println(err)
			return
		}
		defer file.Close()
		fmt.Fprintf(w, "%v", handler.Header)
		f, err := os.OpenFile("./test/"+handler.Filename, os.O_WRONLY|os.O_CREATE, 0666)
		// 此处假设当前目录下已存在 test 目录
		if err != nil {
			fmt.Println(err)
			return
		}
		defer f.Close()
		io.Copy(f, file) // 存储文件
	}
}
```

上面的实例中我们处理上传文件主要有三步：

1. 表单中增加 `enctype="multipart/form-data"`
2. 服务端调用`r.ParseMultipartForm`把上传的文件存储在内存和临时文件中
3. 使用`r.FormFile`获取文件句柄，然后对文件进行存储等处理。

## XML 与 JSON

#### XML

XML 作为一种数据交换和信息传递的格式已经十分普及，如果有过 Java 相关开发经历，对 XML 一定时分熟悉。其结构如下：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<User>
    <uid>10086</uid>
    <name>beihai</name>
    <student>true</student>
</User>
```

XML 是一种树形数据结构，我们可以在 Go 中定义一个相同的结构体，使用 `encoding/xml`包进行生成或解析

 ```go
type User struct {
	Uid     int    `xml:"uid"`
	Name    string `xml:"name"`
	Collage bool   `xml:"student"`
}

// 生成 xml
func xmlMarshalIndent() {
	u := &User{
		Uid:     10086,
		Name:    "beihai",
		Collage: true,
	}
	output, err := xml.MarshalIndent(u, "", "    ")
	if err != nil {
		fmt.Println(err)
	}
	os.Stdout.Write([]byte(xml.Header))
	os.Stdout.Write(output)
}

// 解析 xml
func xmlUnmarshal() {
	data := `<?xml version="1.0" encoding="UTF-8"?>
	<User>
    	<uid>10086</uid>
    	<name>beihai</name>
    	<student>true</student>
	</User>`
	u := User{}
	err := xml.Unmarshal([]byte(data), &u)
	if err != nil {
		fmt.Println(err)
	}
	fmt.Println(u)
}
 ```

在数据生成或解析过程中常用到结构体 tags 语法，

> 结构体成员声明后面可以带有一个可选的字符文本标记，它是对应成员声明中所有字段的属性。标记通过反射获得，但在其他情况下会被忽略。

Golang 中对字段的标记可以由反射获取，所以通常在 Struct 编码转换过程利用 tags 提供一些转换规则的信息，如果去掉 tags ，其输出结果如下：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<User>
    <Uid>10086</Uid>
    <Name>beihai</Name>
    <Collage>true</Collage>
</User>
```

#### JSON

JSON（Javascript Object Notation）是一种轻量级的数据交换语言，具有自我描述性且易于阅读。JSON 与 XML 最大的不同在于 XML 是一个完整的标记语言，而 JSON 不是。因此  JSON 比 XML 更小、更快、更易解析，更适用于网络数据传输。其结构如下：

```json
{"uid":10086,"name":"beihai","student":true}
```

JSON 的生成与解析

```go
type User struct {
	Uid     int    `xml:"uid" json:"uid"`
	Name    string `xml:"name" json:"name"`
	Collage bool   `xml:"student" json:"student"`
}

// 生成 json
func jsonMarshal() {
	u := &User{
		Uid:     10086,
		Name:    "beihai",
		Collage: true,
	}
	data, err :=json.Marshal(u)
	if err != nil {
		fmt.Println(err)
	}
	fmt.Println(string(data)) //返回数据格式为 []byte,转换为 string
}

// 解析 json
func jsonUnmarshal() {
	data := `{"uid":10086,"name":"beihai","student":true}`
	u := User{}
	err := json.Unmarshal([]byte(data), &u)
	if err != nil {
		fmt.Println(err)
	}
	fmt.Println(u)
}
```

###### json.Decoder

json.Decoder 是 go 中解析 JSON 数据的另一中方法，常用于读取数据量较大的 JSON 文件。Decoder 对元素一个一个进行加载，而不是把整个 json 流读到内存里。

```go
func jsonDecoder() {
	data := `{"uid":10086,"name":"beihai","student":true}`
	dataStream := strings.NewReader(data)// strings.NewReader 方法将字符串变成一个 Stream 对象
	u := new(User)
	err := json.NewDecoder(dataStream).Decode(u)
	if err != nil {
		fmt.Println(err)
	}
	fmt.Println(u)
}
```

###### 动态解析

预先定义 JSON 的结构进行解析是理想的情况。在实际开发中，JSON 可能非但格式不确定，还可能是动态数据类型。例如登录的时候，用户名可以是手机号也可以是邮箱，客户端传的 JSON 可能是字符串，也可能是数字。此时可以使用空接口 interface{} 对数据进行解析，并利用类型断言获取数据。

```go
func jsonDecoder() {
	data := `{"uid":10086,"name":"beihai","student":true}`
	dataStream := strings.NewReader(data) // strings.NewReader 方法将字符串变成一个 Stream 对象
	u := new(User)
	err := json.NewDecoder(dataStream).Decode(u)
	if err != nil {
		fmt.Println(err)
	}
	switch t := u.Uid.(type) {
	case string:
		fmt.Println("uid is string:",t)
	case float64: // 解析后是 float64 而不是 int
		fmt.Println("uid is float64:",t)
	}
}
```



## RegExp 正则表达式

正则表达式是一种进行模式匹配和文本操纵的复杂而又强大的工具。虽然正则表达式比纯粹的文本匹配效率低，但是它却更灵活。按照正则语法规则，随需构造出的匹配模式就能够从原始文本中筛选出几乎任何你想要得到的字符组合。

对于性能要求很高的开发者来说，他们认为应该尽量避免使用正则表达式，因为使用正则表达式的速度会比较慢——这是一个老生常谈的问题了。但就现在的机器性能，对于这种简单的正则表达式的效率和类型转换函数相比几乎没有差别。

其实字符串处理我们可以使用`strings`包来进行搜索(Contains、Index)、替换(Replace)和解析(Split、Join)等操作，但是他们的搜索都是大小写敏感、而且固定的字符串，如果我们需要匹配可变的字符就难以实现了。当然如果`strings`包能解决你的问题，那就尽量使用它来解决。因为他们足够简单，性能和可读性都比正则好。

#### 通过正则判断是否匹配

**`regexp`**包中含有三个函数用来判断是否匹配，如果匹配返回 true，否则返回 false。

```Go
func Match(pattern string, b []byte) (matched bool, error error)
func MatchReader(pattern string, r io.RuneReader) (matched bool, error error)
func MatchString(pattern string, s string) (matched bool, error error)
```

上面的三个函数实现的是同一个功能，判断`pattern`是否和输入源匹配，匹配的话就返回true。不同之处在于输入源分别是 byte slice、RuneReader 和 string。

比如验证一个 Email 地址是否正确：

```Go
if m, _ := regexp.MatchString(`^([\w\.\_]{2,10})@(\w{1,}).([a-z]{2,4})$`, r.Form.Get("email")); !m {
	fmt.Println("no")
}else{
	fmt.Println("yes")
}
```

验证身份证号码：

```Go
// 验证 15 位身份证，全部为数字
if m, _ := regexp.MatchString(`^(\d{15})$`, r.Form.Get("usercard")); !m {
	return false
}

// 验证 18 位身份证，18 位前 17 位为数字，最后一位是校验位，可能为数字或字符 X。
if m, _ := regexp.MatchString(`^(\d{17})([0-9]|X)$`, r.Form.Get("usercard")); !m {
	return false
}
```

## Template 模板

官方定义**`template`**包是数据驱动的文本输出模板，说白了就是在写好的模板中填充数据。下面是一个简单的模板示例：

```go
func main() {
	temp := "Time is {{ . }}"
	// 创建新模板
	tmpl, _ := template.New("example").Parse(temp)
	// 数据驱动模板
	data :=time.Now()
	_ = tmpl.Execute(os.Stdout, data)
}
// output:Time is 2019-12-02 21:36:46.1615279 +0800 CST m=+0.003995501
```

{{ }} 中间的`.`代表传入模板的数据，根据传入的数据不同渲染不同的内容。`.`可以是 Go 语言中的任何数据类型，如结构体、切片等。

由于前后端分离的 Restful 架构大行其道，传统的模板技术已经很少使用了。

## Reference

- [Golang 处理 JSON](https://www.jianshu.com/p/31757e530144)