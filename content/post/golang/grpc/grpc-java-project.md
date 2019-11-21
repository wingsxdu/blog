---
title: Java Grpc 工程中使用
author: beihai
type: post
date: 2019-05-23T07:06:40+00:00
tags: [
    "java",
    "grpc",
]
categories: [
    "java",
    "grpc",
]
---
##### 续上篇介绍

<a href="https://www.wingsxdu.com/?p=1216" target="_blank" rel="noopener noreferrer">Java GRPC proto 编译</a>
  
现在我们拿到了编译的 Java 文件，其中 User.java 为 rpc 通信，文件名同 .proto 文件名称；CreateAccountGrpc.java 为定义的服务名称，定义几个服务就会编译出几个**Grpc.java 文件
  
<img src="https://www.wingsxdu.com/wp-content/uploads/2019/05/java-proto-1-name-1-1.png" alt="" width="646" height="340" class="size-full wp-image-1228 aligncenter" />

##### 工程中使用

在 src 目录下新建 package grpc.user，将proto 编译得到的 java类文件都复制到目录下
  
<img src="https://www.wingsxdu.com/wp-content/uploads/2019/05/java-proto-1-use-1-1.png" alt="" width="457" height="437" class="size-full wp-image-1229 aligncenter" />

###### build.gradle环境配置

和 proto 编译配置保持一致即可

<pre class="pure-highlightjs"><code class="null">apply plugin: 'java'
apply plugin: 'com.google.protobuf'
apply plugin: 'idea'
repositories {
    maven { url "https://maven.aliyun.com/repository/central/" }
}
dependencies {
    compile "io.grpc:grpc-netty:1.20.0"
    compile "io.grpc:grpc-protobuf:1.20.0"
    compile "io.grpc:grpc-stub:1.20.0"
}
buildscript {
    repositories {
        maven { url "https://maven.aliyun.com/repository/central/" }
    }
    dependencies {
        classpath 'com.google.protobuf:protobuf-gradle-plugin:0.8.8'
    }
}
protobuf {
    protoc {
        artifact = 'com.google.protobuf:protoc:3.7.1'
    }
    plugins {
        grpc {
            artifact = 'io.grpc:protoc-gen-grpc-java:1.20.0'
        }
    }
    generateProtoTasks {
        ofSourceSet('main')*.plugins {
            grpc { }
        }
    }
}</code></pre>

###### 客户端

在目录下新建 UserClient.java

<pre class="pure-highlightjs"><code class="java">package grpc.user;
import io.grpc.ManagedChannel;
import io.grpc.ManagedChannelBuilder;
import java.util.concurrent.TimeUnit;
public class UserClient {
    private final ManagedChannel channel;
    private final CreateAccountGrpc.CreateAccountBlockingStub blockingStub;
    private final CreateAccountGrpc.CreateAccountStub Stub;
    public static void main(String[] args) {
        try {
            UserClient service = new UserClient("localhost", 1330);
            System.out.println(service.creatAccount("beihai"));
            service.shutdown();
        } catch (Exception e) {
            System.out.println("出现错误："+e);
        }
    }
    public UserClient(String host, int port) {
        this(ManagedChannelBuilder.forAddress(host, port).usePlaintext());
    }
    /** Construct client for accessing RouteGuide server using the existing channel. */
    public UserClient(ManagedChannelBuilder&lt;?&gt; channelBuilder) {
        channel = channelBuilder.build();
        blockingStub = CreateAccountGrpc.newBlockingStub(channel);
        Stub = CreateAccountGrpc.newStub(channel);
    }
    public void shutdown() throws InterruptedException{
        channel.shutdown().awaitTermination(5, TimeUnit.SECONDS);
    }
    public String creatAccount(String uid){
        User.CreateAccountRequest request = User.CreateAccountRequest.newBuilder().setUid(uid).setService("Register").build();
        User.CreateRequestResponse response = blockingStub.createAccount(request);
        return response.getValue();
    }
}</code></pre>

###### 服务端

在目录下新建 UserServer.java

<pre class="pure-highlightjs"><code class="null">package grpc.user;
import io.grpc.Server;
import io.grpc.ServerBuilder;
import io.grpc.stub.StreamObserver;
import java.io.IOException;
import org.bcosliteclient.demoDataTransaction;
public class UserServer {
    private Server server;
    public void start() throws IOException {
        /* The port on which the server should run */
        int port = 1330;
        server = ServerBuilder.forPort(port)
                .addService(new UserServer.CreateAccountImpl())
                .build()
                .start();
        Runtime.getRuntime().addShutdownHook(new Thread(() -&gt; {
            // Use stderr here since the logger may have been reset by its JVM shutdown hook.
            System.err.println("*** shutting down gRPC server since JVM is shutting down");
            UserServer.this.stop();
            System.err.println("*** server shut down");
        }));
    }
    private void stop() {
        if (server != null) {
            server.shutdown();
        }
    }
    /**
     * Await termination on the main thread since the grpc library uses daemon threads.
     */
    public void blockUntilShutdown() throws InterruptedException {
        if (server != null) {
            server.awaitTermination();
        }
    }
    /**
     * Main launches the server from the command line.
     */
    public static void main(String[] args) throws IOException, InterruptedException {
        final UserServer server = new UserServer();
        server.start();
        server.blockUntilShutdown();
    }
    static class CreateAccountImpl extends CreateAccountGrpc.CreateAccountImplBase {
        @Override
        public void createAccount(User.CreateAccountRequest req, StreamObserver&lt;User.CreateRequestResponse&gt; responseObserver) {
            //System.out.println(req.getUid());
            String value ;
            if (req.getService().equals("Register")) {
                try {
                    value = "Register";
                } catch (Exception e) {
                    value = "error";
                    e.printStackTrace();
                }
            } else if (req.getService().equals("TokenQuery")) {
                try {
                    value = "TokenQuery";
                } catch (Exception e) {
                    value = "error";
                    e.printStackTrace();
                }
            } else {
                value = "error";
            }
            User.CreateRequestResponse response = User.CreateRequestResponse.newBuilder().setValue(value).build();
            responseObserver.onNext(response);
            responseObserver.onCompleted();
        }
    }
}</code></pre>

先运行 server 端监听端口，再运行客户端发送信息，可在控制台看到输出。