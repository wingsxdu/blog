---
title: go 二叉搜索树实现快速数组匹配
author: beihai
type: post
date: 2018-12-11T10:16:22+00:00
tags: [
    "golang",
    "算法",
]
categories: [
	"golang",
	"算法",
]
---
#### 二叉搜索树概念

<p style="font-size: 16px;">
  二叉排序树，又叫二叉查找树，是一种快速高效的排序方式。它可以是一棵空树（没有值）；或者是具有以下性质的二叉树：<br />1. 若它的左子树不空，则左子树上所有节点的值均小于它的根节点的值；<br />2. 若它的右子树不空，则右子树上所有节点的值均大于它的根节点的值；<br />3. 它的左右子树也分别为二叉排序树。
</p>

<p style="font-size: 16px;">
  对于二叉树中的任意节点X，它的左子树中所有关键字的值小于X的关键字值，而它的右子树中所有关键字值大于X的关键字值。这也意味着二叉搜索树中的所有节点都可以按照某种方式来排序。
</p>

<p style="font-size: 16px;">
</p><figure class="wp-block-image is-resized">


<img width="225" height="188" class="wp-image-727" alt="" src="http://www.wingsxdu.com/wp-content/uploads/2018/12/Binary-Search-Tree-300x251.jpg" /> <figcaption>图例</figcaption> </figure> 

<p style="font-size: 16px;">
</p>

#### Golang 中实现

<p style="font-size: 16px;">
</p>

##### 创建结构体

<pre class="pure-highlightjs"><code class="null">type TreeNode struct {
	elem  int
	left  *TreeNode
	right *TreeNode
}</code></pre>

创建一个空树或者清空树

<span style="color: #ff99cc;">注：</span>

  * 创建一棵空树: 不像其他一些数据结构中通过一个结构体来定义一棵空树，我们直接通过空指针来定义一棵空树，所以在MakeEmpty尾部我们直接返回了空指针来代表一棵空树。
  * 清空一棵树: MakeEmpty函数还可以清空一棵树，由于Go语言中并不需要我们手动管理内存空间，所以删除树节点并不需要释放空间，只需要将指向树节点的指针置为nil即可。

<pre class="pure-highlightjs"><code class="null">func MakeEmpty(tree *TreeNode) *TreeNode {
	if tree != nil {
		MakeEmpty(tree.left)
		tree.left = nil
		MakeEmpty(tree.right)
		tree.right = nil
	}
	return nil
}</code></pre>

插入数据

<span style="color: #ff99cc;">注意</span>：如果要插入的值已经在树中存在，我们什么也不做，树中不会保存两个相同的值。

<pre class="pure-highlightjs"><code class="null">func Insert(elem int, tree *TreeNode) *TreeNode {
	if tree == nil {
		tree = &TreeNode{}
		tree.left = nil
		tree.right = nil
		tree.elem = elem
	} else if elem &lt; tree.elem {
		tree.left = Insert(elem, tree.left)
	} else if elem &gt; tree.elem {
		tree.right = Insert(elem, tree.right)
	} else {
		// 该节点已经在这颗树中了，我们什么也不做
	}
	return tree
}</code></pre>

在main函数中新建一个数组和空树，插入数据

<pre class="pure-highlightjs"><code class="null">func main() {
	var a = [10]int{9,12,5,8,35,22,9,33,1,2}
	var testTree *TreeNode
	MakeEmpty(testTree)
	for i:=0; i&lt;len(a);i++ {
		testTree = Insert(a[i], testTree)
	}
}</code></pre>

##### 判断是否存在某值，添加函数：

<pre class="pure-highlightjs"><code class="null">func Find(elem int, tree *TreeNode) bool {
	if tree == nil {
		return false
	}
	if tree.elem == elem {
		return true
	} else if elem &gt; tree.elem {// 查找节点比当前树节点要大
		return Find(elem, tree.right)
	} else { // 查找节点比当前树节点要小
		return Find(elem, tree.left)
	}
}</code></pre>

在main函数中进行配对：

<pre class="pure-highlightjs"><code class="null">exist := Find(35,testTree)&lt;br />exists := Find(3,testTree)&lt;br />fmt.Println(exist)&lt;br />fmt.Println(exists)</code></pre>

Find操作的功能是通过递归来实现的。判断当前树节点是否是要查找的节点，如果是则返回当前节点。否则，根据目标关键字的值的是否小于当前节点的<span style="color: #e91e63;">关键字值</span>分别去当前节点的左子树或右子树中去查找目标节点。打印的第一个值为 true，第二个值为 false（输出结果为 bool 型）

##### 查找最小、最大值：

<pre class="pure-highlightjs"><code class="null">func FindMin(tree *TreeNode) *TreeNode {
	if tree == nil {
		return nil
	}
	for tree.left != nil {
		tree = tree.left
	}
	return tree
}
func FindMax(tree *TreeNode) *TreeNode {
	if tree == nil {
		return nil
	}
	if tree.right == nil {
		return tree
	}
	return FindMax(tree.right)
}</code></pre>

main函数使用：

<pre class="pure-highlightjs"><code class="null">min := FindMin(testTree).elem&lt;br />max := FindMax(testTree).elem&lt;br />fmt.Println(min)&lt;br />fmt.Println(max)</code></pre>

<span>查找最小值是通过迭代实现的，由于二叉搜索树中某个树节点的<span style="color: #e91e63;">左子树</span>的关键字始终小于这个树节点的关键字值，所以我们只需要一直遍历，找到</span>最左<span>的那个树节点，它就是整个树中最小的节点。</span>

参考文章：<a href="https://blog.csdn.net/u012291393/article/details/79418723" target="_blank" rel="noopener noreferrer">Go与数据结构之二叉搜索树</a>

<p style="font-size: 16px;">
</p>