# Changelog: zampto-start.sh Environment Parameters

## 修改日期
2024-01-XX

## 修改内容

### ✅ 添加完整的环境变量配置部分

在 `zampto-start.sh` 脚本开头（`#!/bin/bash` 之后）添加了完整清晰的环境参数声明部分。

### 📋 新增的环境变量声明（共15个参数）

#### 必填参数（3个）
1. **UUID** - Vmess 和哪吒 v1 使用
   - 如果为空，脚本会自动生成
   
2. **ARGO_DOMAIN** - Argo 隧道域名（固定隧道）
   - 格式示例：`zampto.xunda.ggff.net`
   - 如果为空，使用临时隧道
   
3. **ARGO_AUTH** - Argo 隧道 Token 或 JSON（固定隧道）
   - 格式：token 字符串或 JSON 对象
   - 如果为空，使用临时隧道

#### 可选参数 - Argo 优选节点（2个）
4. **CFIP** - CF 优选域名或 IP
   - 默认：`www.shopify.com`
   
5. **CFPORT** - CF 优选端口
   - 默认：`443`

#### 可选参数 - 哪吒监控（3个）
6. **NEZHA_SERVER** - 哪吒服务器地址
   - v1 格式：`nezha.abc.com:8008`（端口包含在域名中）
   - v0 格式：`nezha.abc.com`（端口单独配置）
   
7. **NEZHA_PORT** - 哪吒端口（仅 v0 版本需要）
   - 可选端口：443, 8443, 2096, 2087, 2083, 2053
   - v0 默认：`5555`
   
8. **NEZHA_KEY** - 哪吒密钥
   - v1：NZ_CLIENT_SECRET
   - v0：agent 密钥

#### 可选参数 - Telegram 通知（2个）
9. **CHAT_ID** - Telegram chat ID
   - 获取方法：https://t.me/laowang_serv00_bot
   
10. **BOT_TOKEN** - Telegram Bot Token
    - 格式示例：`123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11`

#### 可选参数 - 其他（5个）
11. **NAME** - 节点名称（订阅中显示）
    - 默认：`zampto`
    
12. **FILE_PATH** - 订阅文件保存路径
    - 默认：`./.npm`
    
13. **SERVER_PORT** - Node.js 服务端口
    - 默认：`3000`
    
14. **UPLOAD_URL** - 订阅自动上传地址
    - 格式示例：`https://merge.zabc.net`
    
15. **LISTEN_IP** - sing-box 监听地址（内部使用）
    - 默认：`127.0.0.1`
    
16. **LISTEN_PORT** - sing-box 监听端口（内部使用）
    - 默认：`8080`

### ✨ 功能特性

每个环境变量都包含：
- ✅ 变量名
- ✅ 中文注释说明用途
- ✅ 默认值
- ✅ 标注"必填"还是"可选"
- ✅ 格式示例
- ✅ 获取方法（Telegram）

### 📝 使用方法

用户打开 `zampto-start.sh` 文件后，在脚本开头就能清楚看到：

1. **这是什么参数** - 中文注释说明
2. **必填还是可选** - 分组标注
3. **应该填什么** - 格式示例
4. **从哪里获取** - 获取方法说明

### 🔧 技术实现

- 所有环境变量使用 `export` 声明
- 使用 `${VAR:-'default'}` 语法提供默认值
- 参数分组：必填参数、Argo 节点、哪吒监控、Telegram、其他
- 添加明确的注释和使用说明

### ✅ 验证

```bash
# 语法检查通过
bash -n zampto-start.sh
```

### 📌 兼容性

- 保持与原有脚本完全兼容
- 所有原有功能不受影响
- 用户可以选择性填写参数
- 未填写的参数使用默认值

## 影响范围

- ✅ 提升用户体验 - 清晰的参数说明
- ✅ 降低使用门槛 - 减少配置困惑
- ✅ 减少错误 - 明确格式要求
- ✅ 保持兼容 - 不影响现有功能

## 相关文件

- `zampto-start.sh` - 主要修改文件
- 其他 zampto 相关文件保持不变

## 验证清单

- [x] 语法检查通过
- [x] 所有环境变量有中文注释
- [x] 区分必填和可选参数
- [x] 提供默认值
- [x] 提供格式示例
- [x] 提供获取方法
- [x] 添加使用说明
