/**
 * 获取指定仓库的最新有效版本标签
 * @param {string} owner - 仓库所有者
 * @param {string} repo - 仓库名称
 * @param {Object} github - GitHub API 对象
 * @param {Object} context - GitHub 上下文对象
 * @returns {Promise<string>} 最新版本标签，如果没有有效标签则返回空字符串
 */
async function getLatestValidVersion(owner, repo, github, context) {
  try {
    console.log(`正在获取 ${owner}/${repo} 的最新版本...`);
    
    // 先尝试获取最新的 release
    try {
      const releaseResponse = await github.rest.repos.getLatestRelease({
        owner,
        repo
      });
      
      const tag = releaseResponse.data.tag_name;
      if (isValidVersionTag(tag)) {
        console.log(`通过 getLatestRelease 获取到 ${owner}/${repo} 最新版本: ${tag}`);
        return tag;
      }
      console.log(`最新 release 标签 ${tag} 不符合版本格式要求，尝试从 tags 获取`);
    } catch (error) {
      console.log(`获取 ${owner}/${repo} 最新 release 失败，尝试从 tags 获取:`, error.message);
    }
    
    // 如果获取 release 失败或不符合要求，从 tags 获取
    const response = await github.rest.repos.listTags({
      owner,
      repo,
      per_page: 100
    });
    
    if (!response.data || response.data.length === 0) {
      console.log(`${owner}/${repo} 没有找到任何 tags`);
      return '';
    }
    
    console.log(`从 ${owner}/${repo} 获取到 ${response.data.length} 个 tags`);
    
    // 筛选有效版本并排序
    const validTags = response.data
      .map(tag => tag.name)
      .filter(tag => isValidVersionTag(tag));
    
    if (validTags.length === 0) {
      console.log(`${owner}/${repo} 没有找到符合格式的版本标签`);
      return '';
    }
    
    // 按语义化版本排序（降序，最新的在前）
    const sortedTags = validTags.sort((a, b) => compareVersions(b, a));
    
    console.log(`${owner}/${repo} 有效版本标签:`, sortedTags.slice(0, 5)); // 只显示前5个
    
    return sortedTags[0];
  } catch (error) {
    console.error(`获取 ${owner}/${repo} 版本时出错:`, error);
    return '';
  }
}

/**
 * 检查标签是否为有效的版本格式
 * @param {string} tag - 版本标签
 * @returns {boolean} 是否为有效版本
 */
function isValidVersionTag(tag) {
  // 支持以下格式：
  // v1.2.3, v1.10.0, v2.0.0, v0.1.0, v1.2, v1.2.3.4
  // 规则：以v开头，至少一个数字，然后可以有多个".数字"部分
  // 至少需要 vX.Y 格式（主版本号和次版本号）
  const pattern = /^v\d+(\.\d+)+$/;
  return pattern.test(tag);
}

/**
 * 比较两个版本号
 * @param {string} a - 版本号 a
 * @param {string} b - 版本号 b
 * @returns {number} 比较结果：a > b 返回正数，a < b 返回负数，相等返回0
 */
function compareVersions(a, b) {
  // 移除开头的v并分割版本号
  const aParts = a.substring(1).split('.').map(Number);
  const bParts = b.substring(1).split('.').map(Number);
  
  // 逐级比较版本号
  const maxLength = Math.max(aParts.length, bParts.length);
  for (let i = 0; i < maxLength; i++) {
    const aPart = aParts[i] || 0;
    const bPart = bParts[i] || 0;
    if (aPart !== bPart) {
      return aPart - bPart;
    }
  }
  return 0;
}

// 导出函数供外部使用
module.exports = {
  getLatestValidVersion,
  isValidVersionTag,
  compareVersions
};