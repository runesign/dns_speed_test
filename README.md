# DNS 测速工具
![2024-10-25-081014_hyprshot](https://github.com/user-attachments/assets/851ea78a-9827-46a5-bb52-be4c93ddd7e3)

这是一个基于 Flutter 开发的 DNS 测速应用程序，支持ipv4/6,DoH支持中英文双语界面。

## 功能特点

- 同功能的应用里面唯一一个跨全平台有GUI的（而且应该是唯一一个支持ipv6的，反正我谷歌半天没发现功能做的比我好的）
- 支持DoH！！！（web端的，由于浏览器暂不支持tcp/udp协议，只能实现DoH了）（其实最近chrome才有TCP/UDP的支持，但是开源界还没有多少跟进支持，别说生产界了）
- DNS 服务器测速
- 多语言支持（中文、英文）
- 持久化设置存储
- 简洁的用户界面

## 技术栈

- Flutter
- shared_preferences（应用数据存储记忆）
- flutter_localizations（国际化支持）

## 应用结构

应用主要包含两个主要页面：

1. DNS 测速页面 - 用于进行 DNS 服务器测速
2. 关于页面 - 显示应用相关信息

## 如何使用

1. 启动应用后，默认进入 DNS 测速页面
2. 可以通过底部导航栏切换不同页面
3. 点击右上角的语言图标可以切换应用界面语言

## 开发环境要求

- Flutter SDK
- Dart SDK

## 安装步骤

1. 克隆项目代码

```bash
git clone runesign/dns_speed_test
```

2. 安装依赖

```bash
flutter pub get
```

3. 运行应用

```bash
flutter run
```
