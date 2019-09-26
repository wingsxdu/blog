---
title: Go Echo+Nginx 搭建 https://域名服务
author: beihai
type: post
date: 2019-05-18T13:55:03+00:00
url: /?p=1106
hestia_layout_select:
  - sidebar-right
  - sidebar-right
  - sidebar-right
  - sidebar-right
categories:
  - Golang
  - 技术向

---
搭建后端服务时要适配小程序接口，<del>狗日的</del>微信要求请求链接必须为 https://域名，折腾了半天决定用 Nginx 反向 http 代理，又交了300保护费:)。其他的 Web 服务代理也适用，大致流程如下：

##### 1.1准备工作：

  1. 服务器+通过备案的域名；
  2. 前往华为云申请免费的 SSL 证书并设置 DNS 解析，或者用自签名证书；
  3. 服务器安装 Nginx

##### 1.2Nginx 开启 https 监听

  1. 下载 SSL 证书，将 .crt 和 .key 文件放在 /etc/nginx/cert/ 目录下；
  2. cd /etc/nginx/sites-available 进入 Nginx 配置文件目录，打开文件 default
  3. 在server{} 内添加或修改代码：

<pre class="pure-highlightjs"><code class="nginx">	listen 443 ssl default_server;
	listen [::]:443 ssl default_server;
	ssl    on;
	ssl_certificate    /etc/nginx/cert/server.crt;
	ssl_certificate_key    /etc/nginx/cert/server.key;
	ssl_prefer_server_ciphers	on;
	server_name ***.******.com;</code></pre>

访问https://\*\\*\*.\*\*\****.com，测试能否连接。

##### 1.2代理Golang server

若 go service 使用端口为1323，修改 server{}内容为：

<pre class="pure-highlightjs"><code class="nginx">	location / {
		root /var/www/html;
		try_files $uri $uri/ =404 $uri @backend;
 		}
   	location @backend {
    		add_header Access-Control-Allow-Origin *;
    		add_header Access-Control-Allow-Methods 'GET, POST, OPTIONS';
    		add_header Access-Control-Allow-Headers 'DNT,X-Mx-ReqToken,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Authorization';
		if ($request_method = 'OPTIONS') {
        		return 204;
    		}
        	proxy_set_header X-Forwarded-For $remote_addr;
       		proxy_set_header Host            $http_host;
        	proxy_pass http://127.0.0.1:1323;
    	}</code></pre>

即让 Nginx 监听代理本地的1323端口，并允许执行跨域请求，若不允许前台可能无法接收数据

##### 1.3http 重定向至 https

此时仍然存在一个问题，若在浏览器的地址栏中直接输入域名，如本站的 www.wingsxdu.com，默认执行的仍然是 http 请求，所以需要将 http 重定向至 https：

  * 注释掉server{}内对80端口的监听，或者直接删除

<pre class="pure-highlightjs"><code class="nginx">	#  listen 80 default_server;
	#  listen [::]:80 default_server;</code></pre>

  * 新增一个server{}：

<pre class="pure-highlightjs"><code class="nginx">server {
    listen       80;
    server_name  ***.*****.com;
    rewrite ^(.*) https://$host$1 permanent;
}</code></pre>

在新的 server{} 内监听 http 的80端口，并重定向至 https。不能在原 server{}内添加 rewrite 语句，否则会陷入死循环，导致无法访问。

##### 1.4配置文件全部代码：

<pre class="pure-highlightjs"><code class="nginx">server {
    listen       80;
    server_name  ***.wingsxdu.com;
    rewrite ^(.*) https://$host$1 permanent;
}
server {
	#  listen 80 default_server;
	#  listen [::]:80 default_server;
	listen 443 ssl default_server;
	listen [::]:443 ssl default_server;
	ssl    on;
	ssl_certificate    /etc/nginx/cert/server.crt;
	ssl_certificate_key    /etc/nginx/cert/server.key;
	ssl_prefer_server_ciphers	on;
	root /var/www/html;
	index index.html index.htm index.nginx-debian.html;
	server_name ***.wingsxdu.com;
	location / {
		root /var/www/html;
		try_files $uri $uri/ =404 $uri @backend;
 		}
   	location @backend {
    		add_header Access-Control-Allow-Origin *;
    		add_header Access-Control-Allow-Methods 'GET, POST, OPTIONS';
    		add_header Access-Control-Allow-Headers 'DNT,X-Mx-ReqToken,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Authorization';
		if ($request_method = 'OPTIONS') {
        		return 204;
    		}
        	proxy_set_header X-Forwarded-For $remote_addr;
       		proxy_set_header Host            $http_host;
        	proxy_pass http://127.0.0.1:1323;
    	}
}</code></pre>