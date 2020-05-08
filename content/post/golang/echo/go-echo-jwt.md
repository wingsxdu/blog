---
title: Go Echo JWT
author: beihai
type: post
date: 2019-05-19T05:58:55+00:00
categories: [
   "Golang",
]
---
##### 1.1 简介

JWT 全称 <span>JSON Web Token ，是一个开放标准(RFC 7519)，它定义了一种紧凑的、自包含的方式，用于作为 JSON 对象在各方之间安全地传输信息。该信息是数字签名的，可以被验证和信任。</span>

###### 使用场景：

  * <span><strong>Authorization</strong> (授权) : 这是使用JWT的最常见场景。一旦用户登录，后续每个请求都将包含JWT，允许用户访问该令牌允许的路由、服务和资源。单点登录是现在广泛使用的JWT的一个特性，因为它的开销很小，并且可以轻松地跨域使用。</span>
  * <span><strong>Information Exchange</strong> (信息交换) : 对于安全的在各方之间传输信息而言，JSON Web Tokens无疑是一种很好的方式。因为JWTs可以被签名，例如，用公钥/私钥对，你可以确定发送人就是它们所说的那个人。另外，由于签名是使用头和有效负载计算的，您还可以验证内容没有被篡改。</span>

##### 1.2Echo 中使用（配合官方教程）

###### 1.token 生成：

```go
func login(c echo.Context) error {
   username := c.FormValue("username")
   password := c.FormValue("password")
   // Throws unauthorized error
   if username == "beihai" && password == "mima" {
      fmt.Println(username)
      // Create token
      token := jwt.New(jwt.SigningMethodHS256)
      // Set claims
      claims := token.Claims.(jwt.MapClaims)
      claims["name"] = username
      claims["exp"] = time.Now().Add(time.Hour * 72).Unix()
      // Generate encoded token and send it as response.
      t, err := token.SignedString([]byte("secret"))//密钥
      if err != nil {
         return err
      }
      return c.JSON(http.StatusOK, map[string]string{"token": t,})
   } else {
      return echo.ErrUnauthorized
   }
}
```

###### 2.token 解析：

```go
func GetUsrName(c echo.Context) error {
	user := c.Get("user").(*jwt.Token)
	claims := user.Claims.(jwt.MapClaims)
	name := claims["name"].(string)
	return c.String(http.StatusOK, "Welcome "+name+"!")
}
```

3.启动服务：

```go
func main() {
	e := echo.New()
	// Middleware
	e.Use(middleware.Logger())
	e.Use(middleware.Recover())
	// Login route
	e.POST("/login", login)
	// Restricted group
	r := e.Group("/restricted")
	r.Use(middleware.JWT([]byte("secret")))//密钥与login中保持一致
	r.POST("/getusrname", GetUsrName)
	e.Logger.Fatal(e.Start(":1323"))
}
```

我们创建一个 r  路由组，使用 JWT 中间件，该路由组统一前缀路径为：/restricted，所以/getusrname 的实际路由为：/restricted/getusrname
