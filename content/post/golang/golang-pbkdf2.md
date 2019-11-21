---
title: Go实现 PBKDF2 加密算法
author: beihai
type: post
date: 2019-05-04T12:16:01+00:00
tags: [
    "golang",
    "加密算法",
    "算法",
]
categories: [
    "golang",
    "算法",
]

---
#### **PBKDF2加密算法** {.title-article}

##### 1.1 简介

PBKDF2(Password-Based Key Derivation Function)是一个用来导出密钥的函数，常用于生成加密的密码。<span>原理是通过 password 和 salt 进行 hash，然后将结果作为 salt 与 password 再进行 hash，多次重复此过程，生成最终的密文</span>。如果重复的次数足够大（几千数万次），破解的成本就会变得很高。而盐值的添加也会增加“彩虹表”攻击的难度。相关密码学知识自行了解，不多赘述。

##### 1.2 Go语言实现

需要官方库：

<pre><span>package </span>main
<span>import </span>(
   <span>"crypto/rand"
</span><span>   "crypto/sha256"
</span><span>   "encoding/hex"
</span><span>   "fmt"
</span><span>   "golang.org/x/crypto/pbkdf2"
</span><span>   "net"
</span><span>   "os"
</span>)
<span>func </span><span>main</span>(){
<span>   //生成随机盐
</span><span>   </span>salt := <span>make</span>([]<span>byte</span><span>, </span><span>32</span>)
   fmt.Println(salt)
   _<span>, </span>err := rand.Read(salt)
   checkErr(err)
   fmt.Println(salt)
   //生成密文
   dk := pbkdf2.Key([]<span>byte</span>(<span>"mimashi1323"</span>)<span>, </span>salt<span>, </span><span>1</span><span>, </span><span>32</span><span>, </span>sha256.<span>New</span>)
   fmt.Println(dk)
   fmt.Println(hex.EncodeToString(dk))
}
<span>func </span><span>checkErr</span>(err <span>error</span>){
   <span>if </span>err != nil {
      fmt.Fprintln(os.Stderr<span>,</span><span>"Fatal error: %s"</span><span>,</span>err.Error())
      os.Exit(<span>1</span>)
   }
}
//输出结果
//[0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0]
//[243 122 96 220 249 216 167 114 108 116 16 148 179 199 157 63 3 36 174 254 226 28 246 207 110 194 120 34 5 162 175 170]
//[171 217 87 102 46 50 105 195 194 191 24 221 252 88 180 21 2 214 231 71 142 251 48 51 29 127 205 93 251 139 145 155]
//abd957662e3269c3c2bf18ddfc58b41502d6e7478efb30331d7fcd5dfb8b919b</pre>

##### 1.3 生成随机盐

<p style="padding-left: 40px;">
  在Go语言中有两个包提供rand，分别为 &#8220;math/rand&#8221; 和 &#8220;crypto/rand&#8221;,  对应两种应用场景。
</p>

<li style="list-style-type: none;">
  <ol>
    <li>
      <span>&#8220;math/rand&#8221; 包实现了伪随机数生成器。也就是生成 整形和浮点型。</span>
    </li>
    <li>
      <span>&#8220;crypto/rand&#8221; 包实现了用于加解密的更安全的随机数生成器，这里使用的就是此种</span>
    </li>
  </ol>
</li>

<p style="padding-left: 40px;">
  生成一个空 []byte，使用 rand.Read 方法<span>将随机的 byte 值填充到 salt 数组中。</span>
</p>

<p style="padding-left: 40px;">
  实际使用时 salt 位数过小易被破解，常用32位。
</p>

##### 1.4 PBKDF2 参数解析

官方提供 <span>&#8220;golang.org/x/crypto/pbkdf2&#8243;包封装此加密算法</span>
  
源码：

<pre><span>func </span><span>Key</span>(password<span>, </span>salt []<span>byte</span><span>, </span>iter<span>, </span>keyLen <span>int</span><span>, </span>h <span>func</span>() hash.<span>Hash</span>) []<span>byte </span>{
   prf := hmac.New(h<span>, </span>password)
   hashLen := prf.Size()
   numBlocks := (keyLen + hashLen - <span>1</span>) / hashLen
   <span>var </span>buf [<span>4</span>]<span>byte
</span><span>   </span>dk := <span>make</span>([]<span>byte</span><span>, </span><span></span><span>, </span>numBlocks*hashLen)
   U := <span>make</span>([]<span>byte</span><span>, </span>hashLen)
   <span>for </span>block := <span>1</span><span>; </span>block &lt;= numBlocks<span>; </span>block++ {
      <span>// N.B.: || means concatenation, ^ means XOR
</span><span>      // for each block T_i = U_1 ^ U_2 ^ ... ^ U_iter
</span><span>      // U_1 = PRF(password, salt || uint(i))
</span><span>      </span>prf.Reset()
      prf.Write(salt)
      buf[<span></span>] = <span>byte</span>(block &gt;&gt; <span>24</span>)
      buf[<span>1</span>] = <span>byte</span>(block &gt;&gt; <span>16</span>)
      buf[<span>2</span>] = <span>byte</span>(block &gt;&gt; <span>8</span>)
      buf[<span>3</span>] = <span>byte</span>(block)
      prf.Write(buf[:<span>4</span>])
      dk = prf.Sum(dk)
      T := dk[len(dk)-hashLen:]
      copy(U<span>, </span>T)
      <span>// U_n = PRF(password, U_(n-1))
</span><span>      </span><span>for </span>n := <span>2</span><span>; </span>n &lt;= iter<span>; </span>n++ {
         prf.Reset()
         prf.Write(U)
         U = U[:<span></span>]
         U = prf.Sum(U)
         <span>for </span>x := <span>range </span>U {
            T[x] ^= U[x]
         }
      }
   }
   <span>return </span>dk[:keyLen]
}</pre>

  1. password：用户密码，加密的原材料，以 []byte 传入；
  2. salt：随机盐，以 []byte 传入；
  3. iter：迭代次数，次数越多加密与破解所需时间越长，
  4. keylen：期望得到的密文长度；
  5. Hash：加密所用的 hash 函数，默认使用为 sha1，本文使用 sha256。

<p style="padding-left: 40px;">
  <a href="https://godoc.org/golang.org/x/crypto/pbkdf2" target="_blank" rel="noopener noreferrer">官方文档连接</a>
</p>