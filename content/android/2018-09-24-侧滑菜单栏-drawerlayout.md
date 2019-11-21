---
title: 侧滑菜单栏——DrawerLayout
author: beihai
type: post
date: 2018-09-24T04:03:48+00:00
categories:
  - Android studio
tags:
  - Android studio
---
使用侧滑菜单栏——SlideMenu 后发现无法为控件编写逻辑， 随即更改实现方式——DrawerLayout
  
<!--more-->

#### 1. 布局页面代码

<pre class="pure-highlightjs"><code class="java">&lt;?xml version="1.0" encoding="utf-8"?&gt;
&lt;android.support.v4.widget.DrawerLayout xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools"
    android:id="@+id/drawerlayout"
    android:background="@drawable/background4"
    android:layout_width="match_parent"
    android:layout_height="match_parent"&gt;
    &lt;!-- 主页面布局 --&gt;
    &lt;FrameLayout
        android:id="@+id/fragment_layout"
        android:layout_width="match_parent"
        android:layout_height="match_parent"&gt;
        &lt;LinearLayout
            android:layout_width="match_parent"
            android:layout_height="60dp"
            android:gravity="center_vertical"&gt;
            &lt;ImageView
                android:id="@+id/btn_back"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content" /&gt;
            &lt;View
                android:layout_width="1dp"
                android:layout_height="match_parent"
                android:layout_marginBottom="5dp"
                android:layout_marginTop="5dp" /&gt;
            &lt;Button
                android:id="@+id/btn_show"
                android:layout_width="40dp"
                android:layout_height="wrap_content"
                android:layout_marginLeft="15dp"
                android:layout_marginStart="15dp"
                android:background="@drawable/menu"
                android:text="@string/menu"
                android:textColor="#000000"
                android:textSize="22sp" /&gt;
        &lt;/LinearLayout&gt;
    &lt;/FrameLayout&gt;
    &lt;!-- 菜单布局 --&gt;
    &lt;RelativeLayout
        android:id="@+id/left"
        android:layout_width="200dp"
        android:layout_height="match_parent"
        android:layout_gravity="left"
        android:background="@android:color/white"
        tools:ignore="RtlHardcoded"&gt;
        &lt;LinearLayout
            android:layout_width="200dp"
            android:layout_height="wrap_content"
            android:orientation="vertical"
            tools:ignore="UselessParent"&gt;
            &lt;TextView
                style="@style/MenuTabText"
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:background="#e423db0b"
                android:drawablePadding="25dp"
                android:gravity="center_vertical"
                android:padding="25dp"
                android:text="@string/landing"
                android:textColor="#000000"
                android:textSize="25sp" /&gt;
            &lt;Button
                style="@style/MenuTabText"
                android:text="@string/MenuTabText1" /&gt;
            &lt;Button
                android:id="@+id/btn1"
                style="@style/MenuTabText"
                android:text="@string/MenuTabText2" /&gt;
            &lt;Button
                style="@style/MenuTabText"
                android:text="@string/MenuTabText3" /&gt;
            &lt;Button
                style="@style/MenuTabText"
                android:text="@string/MenuTabText4" /&gt;
        &lt;/LinearLayout&gt;
    &lt;/RelativeLayout&gt;
&lt;/android.support.v4.widget.DrawerLayout&gt;</code></pre>

注意：编译器要引入 v4 support

#### 2. java类代码

<pre class="pure-highlightjs"><code class="java">public class MainActivity extends AppCompatActivity {
    DrawerLayout dl;
    Button btnShow;
    RelativeLayout rlRight;
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        initView();
        initData();
    }
    private void initView() {
        btnShow = findViewById(R.id.btn_show);
        dl = findViewById(R.id.drawerlayout);
        rlRight = findViewById(R.id.left);
        // 关闭手势滑动
        dl.setDrawerLockMode(DrawerLayout.LOCK_MODE_LOCKED_CLOSED);
        dl.addDrawerListener(new DrawerLayout.DrawerListener() {
            @Override
            public void onDrawerSlide(@NonNull View drawerView, float slideOffset) { }
            @Override
            public void onDrawerOpened(@NonNull View drawerView) {
                // 打开手势滑动
                dl.setDrawerLockMode(DrawerLayout.LOCK_MODE_UNLOCKED);
            }
            @Override
            public void onDrawerClosed(@NonNull View drawerView) {
                // 关闭手势滑动
                dl.setDrawerLockMode(DrawerLayout.LOCK_MODE_LOCKED_CLOSED);
            }
            @Override
            public void onDrawerStateChanged(int newState) {
            }
        });
    }
    private void initData() {
        btnShow.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                // TODO 点击按钮打开侧滑菜单
                if (!dl.isDrawerOpen(rlRight)) {
                    dl.openDrawer(rlRight);
                }
            }
        });
    }
}</code></pre>

文字、图标等资源自行添加