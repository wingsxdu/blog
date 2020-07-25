---
title: "Redis ll2string 算法"
author: "beihai"
summary: "<blockquote><p>Redis 内部一个有趣的小算法，将`long long` 类型转换为 `string` 类型数据。这个算法的原理十分巧妙，在一些编程语言中也有类似的实现方式。</p></blockquote>"
tags: [
    "Redis",
]
categories: [
	"算法",
	"Redis",
]
keywords: [
    "Redis",
]
date: 2020-02-06T17:53:43+08:00
draft: false

---

> 对 Redis 数据库的源码阅读，当前版本为 Redis 6.0 RC1，参考书籍《Redis 设计与实现》及其注释。项目地址：[github.com/wingsxdu](https://github.com/wingsxdu/redis)

Redis 内部一个有趣的小算法，将`long long` 类型转换为 `string` 类型数据。这个算法的原理十分巧妙，在一些编程语言中的类型转换也采用了类似的实现方式。

这个算法是根据这篇文章 [Three Optimization Tips for C++](https://www.facebook.com/notes/facebook-engineering/three-optimization-tips-for-c/10151361643253920) 实现的。

首先实现了一个求 uint64 数字长度的函数：

```c
uint32_t digits10(uint64_t v) {
    if (v < 10) return 1;
    if (v < 100) return 2;
    if (v < 1000) return 3;
    if (v < 1000000000000UL) {
        if (v < 100000000UL) {
            if (v < 1000000) {
                if (v < 10000) return 4;
                return 5 + (v >= 100000);
            }
            return 7 + (v >= 10000000UL);
        }
        if (v < 10000000000UL) {
            return 9 + (v >= 1000000000UL);
        }
        return 11 + (v >= 100000000000UL);
    }
    return 12 + digits10(v / 1000000000000UL);
}
```

通俗地将，就是通过大小比较来确定整数的长度，对于大于等于 1000 的整数利用二分比较的思想来优化效率。

接下来是转换函数

```c
int ll2string(char *dst, size_t dstlen, long long svalue) {
    // 从 00 到 99 的字符数组
    // 对 100 取模的所有值组成的字符串
    static const char digits[201] =
        "0001020304050607080910111213141516171819"
        "2021222324252627282930313233343536373839"
        "4041424344454647484950515253545556575859"
        "6061626364656667686970717273747576777879"
        "8081828384858687888990919293949596979899";
    // 负数标记
    int negative;
    // 将 svalue 换成 value 表示，以解决当 svalue 为 LLONG_MIN 时转成正数时溢出问题
    unsigned long long value;

    /* The main loop works with 64bit unsigned integers for simplicity, so
     * we convert the number here and remember if it is negative. */
    // 判断是否是负数，若是负数则标记，并转成正数表示
    if (svalue < 0) {
        if (svalue != LLONG_MIN) {
            value = -svalue;
        } else {
            value = ((unsigned long long) LLONG_MAX)+1;
        }
        negative = 1;
    } else {
        value = svalue;
        negative = 0;
    }

    /* Check length. */
    // 长度检查 
    uint32_t const length = digits10(value)+negative;
    if (length >= dstlen) return 0;

    /* Null term. */
    uint32_t next = length;
    dst[next] = '\0';
    next--;
    // 每次取 100 的余数，然后参照 digits 找到对应的字符赋值
    while (value >= 100) {
        // 乘以 2 可以直接找到下标
        int const i = (value % 100) * 2;
        value /= 100;
        // 相邻的两位代表取模后对应的字符
        dst[next] = digits[i + 1];
        dst[next - 1] = digits[i];
        next -= 2;
    }

    /* Handle last 1-2 digits. */
    // 处理最后剩下的 1~2 位数字
    // 个位数 
    if (value < 10) {
        dst[next] = '0' + (uint32_t) value;
    // 两位数
    } else {
        int i = (uint32_t) value * 2;
        dst[next] = digits[i + 1];
        dst[next - 1] = digits[i];
    }

    /* Add sign. */
    // 若为负数，在前头加负号
    if (negative) dst[0] = '-';
    return length;
}
```

- 首先，`digits[]`是对 100 取模得到的所有值组成的字符串数组，从 00-99；
- `negative`是负数标记，用于将负数转换为正数时做标记；
- `dst[]`是转换后的字符串，长度为数字的长度，最后一个字节存储着结束符'\0'；

将转换为正数的数据循环取 100 的模，将模乘以 2 可以直接找到下标。例如 101 取模乘以 2 后值为 2，`digits[2]`与`digits[3]`组合刚好为 01，将这两个字符分别赋值给`dst[1]`和`dst[2]`（`dst[3]`为结束符）。

循环重复上述步骤，直至 value 小于 100，最后处理剩下的数字。

如果原数据为负数，还要在字符串前面加一个负号'-'。