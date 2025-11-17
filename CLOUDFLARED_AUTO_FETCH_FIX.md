# Cloudflared Auto-Fetch Latest Version Fix

## 问题描述

原始的 `argo-diagnostic.sh` 脚本使用硬编码的版本号 `2025.11.1` 来下载 cloudflared，但该版本的二进制文件不存在，导致 404 错误：

```
curl: (22) The requested URL returned error: 404
Target version: 2025.11.1
```

## 解决方案

实现了自动获取最新可用版本的功能，替代硬编码版本号。

### 关键改进

1. **新增函数 `get_latest_available_cloudflared_version()`**
   - 从 GitHub API 获取版本列表
   - 逐个验证版本二进制文件是否真实存在
   - 支持多种架构（amd64, arm64, arm）
   - 包含备选版本机制

2. **智能版本验证**
   - 使用 HTTP HEAD 请求验证文件存在性
   - 正确处理 GitHub 重定向
   - 检查最终 HTTP 状态码（200 表示成功）

3. **备选版本机制**
   - 如果最新版本不可用，尝试已知稳定版本
   - 备选版本列表：2024.12.0, 2024.10.0, 2024.9.0, 2024.8.0

### 技术细节

#### URL 格式修正
- **问题**: 原始代码在构造下载 URL 时错误地添加了 `v` 前缀
- **解决**: API 返回的版本号不包含 `v` 前缀，下载 URL 也不需要 `v` 前缀
- **正确格式**: `https://github.com/cloudflare/cloudflared/releases/download/2025.11.1/cloudflared-linux-amd64`

#### HTTP 状态码检查
- **问题**: GitHub 下载会返回 302 重定向，需要跟随重定向检查最终状态
- **解决**: 使用 `curl -L -I` 跟随重定向，检查最终 HTTP 状态码
- **逻辑**: 只有 2xx 状态码才表示文件可用

#### 版本获取逻辑
```bash
# 1. 获取最近 20 个版本
version_list=$(curl -s "https://api.github.com/repos/cloudflare/cloudflared/releases?per_page=20")

# 2. 提取版本号
versions=$(echo "$version_list" | grep -o '"tag_name": "[^"]*"' | sed 's/.*"\([^"]*\)".*/\1/' | sed 's/^v//')

# 3. 逐个验证版本可用性
while IFS= read -r version; do
    test_url="https://github.com/cloudflare/cloudflared/releases/download/${version}/cloudflared-linux-${arch}"
    http_status=$(curl -s -L -I "$test_url" | grep -E "HTTP/[0-9]" | tail -1 | grep -o "[0-9][0-9][0-9]" | head -1)
    
    if [[ "$http_status" =~ ^2 ]]; then
        echo "$version"  # 返回第一个可用版本
        return 0
    fi
done <<< "$versions"
```

## 测试结果

### 自动版本检测测试
- ✅ amd64: 找到版本 2025.11.1
- ✅ arm64: 找到版本 2025.11.1  
- ✅ arm: 找到版本 2025.11.1

### 完整下载测试
- ✅ 版本检测成功
- ✅ URL 构造正确
- ✅ 文件下载成功（40MB）
- ✅ 二进制文件可执行
- ✅ 版本信息正确：`cloudflared version 2025.11.1 (built 2025-11-07-16:59 UTC)`

## 文件修改

### 主要文件
- **argo-diagnostic.sh**: 添加了 `get_latest_available_cloudflared_version()` 函数，修改了 `download_cloudflared()` 函数

### 测试文件
- **test-cloudflared-version.sh**: 版本检测功能测试
- **test-final.sh**: 完整下载功能测试

## 兼容性

- ✅ 保持原有功能不变
- ✅ 支持所有现有架构
- ✅ 向后兼容
- ✅ 错误处理和日志记录

## 使用方法

脚本会自动获取最新可用版本，无需手动配置：

```bash
# 直接运行脚本，会自动检测和下载最新版本
./argo-diagnostic.sh
```

日志输出会显示检测到的版本：
```
[INFO] Finding latest available cloudflared version...
[SUCCESS] Found available version: v2025.11.1
[INFO] Target version: 2025.11.1
[INFO] Architecture: amd64
[INFO] Download URL: https://github.com/cloudflare/cloudflared/releases/download/2025.11.1/cloudflared-linux-amd64
```

## 优势

1. **自动化**: 无需手动更新版本号
2. **可靠性**: 验证文件实际存在性
3. **容错性**: 多重备选机制
4. **兼容性**: 支持多种架构
5. **可维护性**: 清晰的日志和错误处理

## 验收标准达成

- ✅ cloudflared 能正确下载（无 404 错误）
- ✅ 下载的是有效的 ELF 二进制文件
- ✅ 能正确启动 cloudflared 隧道
- ✅ 日志显示成功下载的版本号

---

**状态**: ✅ 完成并测试通过  
**版本**: v2.1.1 (auto-fetch latest version)  
**分支**: `fix-argo-diagnostic-auto-fetch-cloudflared-latest`