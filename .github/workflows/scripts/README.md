# 版本检查脚本

## 功能
这个脚本用于从 GitHub 仓库获取最新版本标签，支持多种版本格式。

## 支持的版本格式
- ✅ v1.2.3
- ✅ v1.10.0
- ✅ v2.0.0
- ✅ v0.1.0
- ✅ v1.2
- ✅ v1.2.3.4

## 使用方法

### 在 GitHub Actions 工作流中使用：
```javascript
const checkVersion = require('./.github/workflows/scripts/check-version.js');

const version = await checkVersion.getLatestValidVersion(
  'owner',      // 仓库所有者
  'repo',       // 仓库名称
  github,       // GitHub API 对象
  context       // GitHub 上下文对象
);

console.log(`Latest valid version: ${version}`);
return version;
```

## 算法说明

1. 首先尝试获取最新的 release
2. 如果 release 不存在或不符合版本格式，则从 tags 获取
3. 筛选符合格式的 tags
4. 按语义化版本排序，返回最新的版本

## 主要改进：

### 1. **代码复用性**
- 将版本获取逻辑封装到单独的模块中
- 避免了重复代码
- 便于维护和扩展

### 2. **增强的错误处理**
- 优先尝试获取最新 release（通常更稳定）
- 提供详细的日志输出
- 处理各种边界情况

### 3. **灵活的架构**
- 可以轻松添加对其他仓库的版本检查
- 版本检查逻辑集中在一处
- 便于测试和调试

### 4. **更好的算法**
- 优先使用 `getLatestRelease` API，这通常更准确
- 详细的日志帮助调试
- 支持更多版本格式

### 5. **目录结构清晰**

```text

.github/
├── workflows/
│ ├── check-updates.yml # 主工作流文件
│ └── scripts/
│ ├── check-version.js # 版本检查脚本
│ └── README.md # 说明文档

```

要使用这个版本，需要：
1. 创建 `.github/workflows/scripts/` 目录
2. 将 `check-version.js` 文件放入该目录
3. 将 `check-updates.yml` 文件放入 `.github/workflows/` 目录
4. 确保您的 `.env` 文件在仓库根目录中
