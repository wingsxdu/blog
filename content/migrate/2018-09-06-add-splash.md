---
title: 添加Splash启动页并显示图片
author: beihai
type: post
date: 2018-09-06T12:54:44+00:00
categories:
  - Android studio

---
#### 1.添加SplashActivity页面

<!--more-->

#### 2.配置AndroidManifest.xml

2.1 配置Splash页面

<pre class="pure-highlightjs"><code class="null">&lt;activity android:name=".SplashActivity" &gt;
    &lt;intent-filter&gt;
        &lt;action android:name="android.intent.action.MAIN" /&gt;
        &lt;category android:name="android.intent.category.LAUNCHER" /&gt;
     &lt;/intent-filter&gt;
&lt;/activity&gt;</code></pre>

2.2 配置原启动页（默认MainActivity)
  
删除这行代码

<pre class="pure-highlightjs"><code class="null">&lt;action android:name="android.intent.action.MAIN" /&gt;</code></pre>

#### 3.SplashActivity.java

在oncreate中添加如下代码

<pre class="pure-highlightjs"><code class="null">@Override
protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN, WindowManager.LayoutParams.FLAG_FULLSCREEN);
    requestWindowFeature(Window.FEATURE_NO_TITLE);
    //注意上面两行位置
    setContentView(R.layout.activity_splash);
    int SPLASH_DISPLAY_LENGTH = 4000;
    new android.os.Handler().postDelayed(new Runnable() {
        public void run() {
            Intent mainIntent = new Intent(SplashActivity.this, MainActivity.class);
            SplashActivity.this.startActivity(mainIntent);
            SplashActivity.this.finish();
        }
    }, SPLASH_DISPLAY_LENGTH);
}</code></pre>

#### 4.avtivity_splash.xml

4.1 将图片复制到/res/drawable文件夹中
  
4.2 引入图片
  
在design页面使用ImagaView控件，引入图片；
  
修改属性属性scaleType为fitXY，或者在Text中加入 android:scaleType=&#8221;fitXY&#8221; ；
  
4.3 scaleType作用
  
设置图片的填充方式。
  
ImageView的scaleType的属性有好几种，分别是matrix（默认）、center、centerCrop、centerInside、fitCenter、fitEnd、fitStart、fitXY。

  * `matrix`:不改变原图的大小，从ImageView的左上角开始绘制原图，原图超过ImageView的部分直接剪裁。
  * `center`：保持原图的大小，显示在ImageView的中心，原图超过ImageView的部分剪裁。
  * `centerCrop`:等比例放大原图，将原图显示在ImageView的中心，直到填满ImageView位置，超出部分剪裁。
  * `centerInside`：当原图宽高或等于ImageView的宽高时，按原图大小居中显示；反之将原图等比例缩放至ImageView的宽高并居中显示。
  * `fitCenter`:按比例拉伸图片，拉伸后图片的高度为ImageView的高度，且显示在ImageView的中间。
  * `fitEnd`：按比例拉伸图片，拉伸后图片的高度为ImageView的高度，且显示在ImageView的下边。
  * `fitStart`：按比例拉伸图片，拉伸后图片的高度为ImageView的高度，且显示在ImageView的上边。
  * `fitXY`:拉伸图片（不按比例）以填充ImageView的宽高。

#### 5.解决启动页白屏

方法：<span style="display: inline !important; float: none; background-color: transparent; color: #333333; font-family: 'PingFangSC','helvetica neue','hiragino sans gb','arial','microsoft yahei ui','microsoft yahei','simsun','sans-serif'; font-size: 16px; font-style: normal; font-variant: normal; font-weight: 400; letter-spacing: normal; orphans: 2; text-align: left; text-decoration: none; text-indent: 0px; text-transform: none; -webkit-text-stroke-width: 0px; white-space: normal; word-spacing: 0px;">给Splash Activity设置一个主题</span><span style="display: inline !important; float: none; background-color: transparent; color: #333333; font-family: 'PingFangSC','helvetica neue','hiragino sans gb','arial','microsoft yahei ui','microsoft yahei','simsun','sans-serif'; font-size: 16px; font-style: normal; font-variant: normal; font-weight: 400; letter-spacing: normal; orphans: 2; text-align: left; text-decoration: none; text-indent: 0px; text-transform: none; -webkit-text-stroke-width: 0px; white-space: normal; word-spacing: 0px;">,主题内容是：全屏+透明</span>
  
在styles.xml页面中加入

<pre class="pure-highlightjs"><code class="null">&lt;style name="SplashTheme" parent="AppTheme"&gt;
    &lt;item name="android:windowFullscreen"&gt;true&lt;/item&gt;
    &lt;item name="android:windowIsTranslucent"&gt;true&lt;/item&gt;
&lt;/style&gt;</code></pre>

修改AndroidManifest.xml为

<pre class="pure-highlightjs"><code class="null">&lt;activity android:name=".SplashActivity" android:theme="@style/SplashTheme"&gt;
    &lt;intent-filter&gt;
        &lt;action android:name="android.intent.action.MAIN" /&gt;
        &lt;category android:name="android.intent.category.LAUNCHER" /&gt;
    &lt;/intent-filter&gt;
&lt;/activity&gt;</code></pre>

原因：摘抄自百度
  
<span style="display: inline !important; float: none; background-color: transparent; color: #333333; font-family: 'PingFangSC','helvetica neue','hiragino sans gb','arial','microsoft yahei ui','microsoft yahei','simsun','sans-serif'; font-size: 16px; font-style: normal; font-variant: normal; font-weight: 400; letter-spacing: normal; orphans: 2; text-align: left; text-decoration: none; text-indent: 0px; text-transform: none; -webkit-text-stroke-width: 0px; white-space: normal; word-spacing: 0px;">“想要了解白屏产生的根源，就不得不去跟踪Activity组件的窗口启动过程。Activity组件在启动的过程中，会调用ActivityStack类的成语函数startActivityLocked方法。注意，在调用ActivityStack类的成语函数startActivityLocked方法的时候，Activity组件还处于启动过程中，即它的窗口尚未显示出来，不过这时候ActivityManagerService服务会检查是否需要为正在启动的Activity组件显示一个启动窗口。如果需要的话，那么ActivityManagerService服务就会请求WindowManagerService服务为正在启动的Activity组件设置一个启动窗口（ps：而这个启动窗口就是白屏的由来）。”</span>