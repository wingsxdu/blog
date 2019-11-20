---
title: HttpURLConnection执行网络请求+json数据解析并输出到RecyclerView
author: beihai
type: post
date: 2018-11-21T12:08:55+00:00
classic-editor-remember:
  - block-editor
  - block-editor
  - block-editor
  - block-editor
categories:
  - Android studio

---
利用 HttpURLConnection 从后端拽取数据展示在app上

#### 1.获取数据

代码如下：

<pre class="pure-highlightjs"><code class="java"></code></pre>

<pre class="pure-highlightjs"><code class="java">    //开启线程来发起网络请求获取数据
    private void sendRequestWithHttpURLConnection(){
        new Thread(new Runnable() {
            @Override
            public void run() {
                HttpURLConnection connection = null;
                BufferedReader reader = null;
                try {
                    URL url = new URL("www.baidu.com");
                    connection = (HttpURLConnection) url.openConnection();
                    connection.setRequestMethod("GET");
                    connection.setConnectTimeout(8000);
                    connection.setReadTimeout(8000);
                    InputStream in = connection.getInputStream();
                    //对获取到的输入流进行读取
                    reader = new BufferedReader(new InputStreamReader(in));
                    StringBuilder response = new StringBuilder();
                    String line;
                    while ((line = reader.readLine()) != null){
                        response.append(line);
                    }
                    Log.e("测试","获取到的数据:"+response);
                } catch (Exception e) {
                    e.printStackTrace();
                }finally {
                    if (reader != null) try {
                        reader.close();
                    } catch (IOException e) {
                        e.printStackTrace();
                    }
                    if (connection != null){
                        connection.disconnect();
                    }
                }
            }
        }).start();
    }</code><code class="java"></code><code class="java"></code></pre>

分析：由于执行网络请求属于耗时操作，需要开启子线程执行，有关多线程常用方法<a href="https://blog.csdn.net/wuqingsen1/article/details/82896463" target="_blank" rel="noopener noreferrer">点击链接跳转</a>；url 为 后端地址，这里输入的是百度首页地址；设置最大请求时长为8秒:Timeout(8000)；将获取的数据读取到 response，并使用 Log.e 调试输出。运行程序后即可看到百度首页的数据构成

#### 2.json数据解析

我们从后端获取的数据是以字符串的形式传输的，但实际上它具有一定的数据结构，常用的形式有 xml 和 json；这里探究 json 数据的解析
  
首先将 <span style="display: inline !important; float: none; background-color: #ffffff; color: #333333; cursor: text; font-family: 'Noto Serif',serif; font-size: 17px; font-style: normal; font-variant: normal; font-weight: 400; letter-spacing: normal; orphans: 2; text-align: left; text-decoration: none; text-indent: 0px; text-transform: none; -webkit-text-stroke-width: 0px; white-space: normal; word-spacing: 0px;">response 转成字符串并传输到函数 showResponse中：</span>在Log.e调试修改为

<pre class="pure-highlightjs"><code class="java">Log.e("测试","获取到的数据:"+response);
showResponse(response.toString());</code></pre>

2.1便于理解但很麻烦的方法：JSONObject
  
大致写一下思路：将字符串转成json数据类型，遍历所有数据获取信息并封装为 list。但是操作过于繁琐。

<pre class="pure-highlightjs"><code class="java">    private void showResponse (final String response) {
        if(response!=null) {
            Map&lt;String, Object&gt; map;
            List&lt;Map&lt;String, Object&gt;&gt; list = new ArrayList&lt;&gt;();
            try {
                JSONArray jsonArray = new JSONArray(response);
                for (int i = 0; i &lt; jsonArray.length(); i++) {
                    JSONObject jsonObject = jsonArray.getJSONObject(i);
                    map = new HashMap&lt;&gt;();
                    if (jsonObject != null) {
                        int id = jsonObject.optInt("id");
                        String name = jsonObject.optString("name");
                        String content = jsonObject.optString("content");
                        boolean favor = jsonObject.optBoolean("favor");
                        JSONArray son = jsonObject.getJSONArray("son");
                        map.put("id", id);
                        map.put("name", name);
                        map.put("content", content);
                        map.put("favor", favor);
                    }
                    list.add(map);
                }
            } catch (JSONException e) {
                e.printStackTrace();
            }
        }
    }</code></pre>

2.2使用 Gson 解析工具
  
引入工具包

<pre class="pure-highlightjs"><code class="java">implementation 'com.google.code.gson:gson:2.8.5'</code></pre>

使用AS插件 GsonFormat
  
新建 JavaBean 类，我这里命名为 chapter，将json数据复制到 <span style="display: inline !important; float: none; background-color: #ffffff; color: #333333; cursor: text; font-family: 'Noto Serif',serif; font-size: 17px; font-style: normal; font-variant: normal; font-weight: 400; letter-spacing: normal; orphans: 2; text-align: left; text-decoration: none; text-indent: 0px; text-transform: none; -webkit-text-stroke-width: 0px; white-space: normal; word-spacing: 0px;">GsonFormat ，点击OK，自动根据 json 结构生成 JavaBean 类。</span>
  
<img width="912" height="804" class="alignnone size-full wp-image-310" alt="" src="http://120.78.201.42/wp-content/uploads/2018/11/GsonFormat-1.jpg" />
  
声明全局变量

<pre class="pure-highlightjs"><code class="java">public ArrayList&lt;chapter&gt; list = new ArrayList&lt;&gt;();</code></pre>

解析过程

<pre class="pure-highlightjs"><code class="java">   //解析json传入list
    private void showResponse (final String response) {
        Gson gson = new Gson();
        Type listType = new TypeToken&lt;List&lt;chapter&gt;&gt;() {
        }.getType();
        list = gson.fromJson(response, listType);
        Message msg = new Message();
        msg.what = 1;
        handler.sendMessage(msg);
    }</code></pre>

注：不同结构的 json 数据写法也不太相同，<a href="https://github.com/google/gson/blob/master/UserGuide.md" target="_blank" rel="noopener noreferrer">点击链接查看官方文档</a>
  
2.3阿里的fastjson解析工具（没用过）

#### 3.在RecyclerView中展示数据

我们已经获得一个封装好的 list，使用 handler 方法更新 ui

<pre class="pure-highlightjs"><code class="java">    //在RecycleView中展示数据,点击item页面跳转
    @SuppressLint("HandlerLeak")
    public Handler handler = new Handler(){
        @Override
        public void handleMessage(Message msg) {
            switch (msg.what){
                case 1:
                    RecyclerView recyclerview = findViewById(R.id.recy);
                    if (recyclerview.getItemDecorationCount() == 0 ) {
                        recyclerview.addItemDecoration(new DividerItemDecoration(ChapterActivity.this, DividerItemDecoration.VERTICAL));
                    }
                    chapter_itemAdapter adapter = new chapter_itemAdapter(list,ChapterActivity.this,Word);
                    //设置布局格式
                    recyclerview.setLayoutManager(new LinearLayoutManager(ChapterActivity.this));
                    recyclerview.setAdapter(adapter);
                    break;
            }
        }
    };</code></pre>

创建适配器 chapter_itemAdapter

<pre class="pure-highlightjs"><code class="java">public class chapter_itemAdapter extends RecyclerView.Adapter&lt;chapter_itemAdapter.ViewHolder&gt; {
    private ArrayList&lt;chapter&gt; list;
    public Context context;
    private LayoutInflater inflater;
    chapter_itemAdapter(ArrayList&lt;chapter&gt; list, Context context){
        this.context = context;
        this.list = list;
        inflater = LayoutInflater.from(context);
    }
    @NonNull
    @Override
    public ViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = inflater.inflate( R.layout.recyclerview_item , parent, false);
        return new ViewHolder(view);
    }
    @Override
    public int getItemCount() {
        return list.size();
    }
    @Override
    public void onBindViewHolder(@NonNull final ViewHolder holder, int position) {
holder.recy_name.setText(Html.fromHtml(Objects.requireNonNull(list.get(position).getName())).toString());
    }
    class ViewHolder extends RecyclerView.ViewHolder{
        TextView recy_name;
        ViewHolder(View itemView) {
            super(itemView);
            recy_name = itemView.findViewById(R.id.recy_name);
        }
    }
}</code></pre>

对应布局 recyclerview_item

<pre class="pure-highlightjs"><code class="xml">&lt;?xml version="1.0" encoding="utf-8"?&gt;
&lt;RelativeLayout xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools"
    android:layout_width="match_parent"
    android:layout_height="wrap_content"&gt;
    &lt;LinearLayout
        android:id="@+id/LinearLayout"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:background="@drawable/touch_bg"
        android:orientation="vertical"
        tools:ignore="UselessParent"&gt;
        &lt;TextView
            android:id="@+id/recy_name"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:paddingTop="20dp"
            android:paddingBottom="5dp"
            android:paddingStart="15dp"
            android:paddingEnd="15dp"
            android:textColor="#00BBD3"
            android:textSize="17sp"/&gt;
    &lt;/LinearLayout&gt;
&lt;/RelativeLayout&gt;</code></pre>

有关RecyclerView更多用法<a href="http://120.78.201.42/?p=313&preview=true" target="_blank" rel="noopener noreferrer">点击链接跳转</a>