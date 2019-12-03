---
title: Go 实现 PBKDF2 加密算法
author: beihai
type: post
date: 2019-05-04T12:16:01+00:00
tags: [
    "Golang",
    "加密算法",
    "算法",
]
categories: [
    "Golang",
    "算法",
]

---
#### **PBKDF2加密算法** {.title-article}

##### 1.1 简介

PBKDF2(Password-Based Key Derivation Function) 是一个用来导出密钥的函数，常用于生成加密的密码。<span>原理是通过 password 和 salt 进行 hash，然后将结果作为 salt 与 password 再进行 hash，多次重复此过程，生成最终的密文</span>。如果重复的次数足够大（几千数万次），破解的成本就会变得很高。而盐值的添加也会增加“彩虹表”攻击的难度。

##### 1.2 Go语言实现

```go
package main
import (
   "crypto/rand"
   "crypto/sha256"
   "encoding/hex"
   "fmt"
   "golang.org/x/crypto/pbkdf2"
   "net"
   "os"
)
func main(){
   //生成随机盐
   salt := make([]byte, 32)
   fmt.Println(salt)
   _, err := rand.Read(salt)
   checkErr(err)
   fmt.Println(salt)
   //生成密文
   dk := pbkdf2.Key([]byte("mimashi1323"), salt, 1, 32, sha256.New)
   fmt.Println(dk)
   fmt.Println(hex.EncodeToString(dk))
}
func checkErr(err error){
   if err != nil {
      fmt.Fprintln(os.Stderr,"Fatal error: %s",err.Error())
      os.Exit(1)
   }
}
//输出结果
//[0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0]
//[243 122 96 220 249 216 167 114 108 116 16 148 179 199 157 63 3 36 174 254 226 28 246 207 110 194 120 34 5 162 175 170]
//[171 217 87 102 46 50 105 195 194 191 24 221 252 88 180 21 2 214 231 71 142 251 48 51 29 127 205 93 251 139 145 155]
//abd957662e3269c3c2bf18ddfc58b41502d6e7478efb30331d7fcd5dfb8b919b
```

##### 1.3 生成随机盐

 在Go语言中有两个包提供rand，分别为 &#8220;math/rand&#8221; 和 &#8220;crypto/rand&#8221;,  对应两种应用场景。

1.  “math/rand” 包实现了伪随机数生成器。也就是生成 整形和浮点型。
2. “crypto/rand” 包实现了用于加解密的更安全的随机数生成器，这里使用的就是此种。

#### 1.4 PBKDF2 参数解析

官方提供 <span>&#8220;golang.org/x/crypto/pbkdf2&#8243; 包封装此加密算法</span>

源码：

```go
func Key(password, salt []byte, iter, keyLen int, h func() hash.Hash) []byte {
   prf := hmac.New(h, password)
   hashLen := prf.Size()
   numBlocks := (keyLen + hashLen - 1) / hashLen
   var buf [4]byte
   dk := make([]byte, , numBlocks*hashLen)
   U := make([]byte, hashLen)
   for block := 1; block <= numBlocks; block++ {
      // N.B.: || means concatenation, ^ means XOR
      // for each block T_i = U_1 ^ U_2 ^ ... ^ U_iter
      // U_1 = PRF(password, salt || uint(i))
      prf.Reset()
      prf.Write(salt)
      buf[] = byte(block >> 24)
      buf[1] = byte(block >> 16)
      buf[2] = byte(block >> 8)
      buf[3] = byte(block)
      prf.Write(buf[:4])
      dk = prf.Sum(dk)
      T := dk[len(dk)-hashLen:]
      copy(U, T)
      // U_n = PRF(password, U_(n-1))
      for n := 2; n <= iter; n++ {
         prf.Reset()
         prf.Write(U)
         U = U[:]
         U = prf.Sum(U)
         for x := range U {
            T[x] ^= U[x]
         }
      }
   }
   return dk[:keyLen]
}
```

  1. password：用户密码，加密的原材料，以 []byte 传入；
  2. salt：随机盐，以 []byte 传入；
  3. iter：迭代次数，次数越多加密与破解所需时间越长，
  4. keylen：期望得到的密文长度；
  5. Hash：加密所用的 hash 函数，默认使用为 sha1，本文使用 sha256。

<p style="padding-left: 40px;">
  <a href="https://godoc.org/golang.org/x/crypto/pbkdf2" target="_blank" rel="noopener noreferrer">官方文档连接</a>
</p>