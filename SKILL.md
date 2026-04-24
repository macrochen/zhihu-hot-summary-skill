---
name: zhihu-hot-summary-skill
description: 获取知乎热榜 → 编号展示 → 用户选号 → 并行抓取+高记忆度总结。基于 opencli 后台无头浏览器。
---

# 知乎热榜高记忆度总结

两步交互式流程：先拉热榜列表让用户选，再逐篇抓取并做高记忆度总结。

## 前置依赖

- `opencli-skill`（负责 zhihu hot / zhihu detail）
- `high-memory-summary-skill`（负责总结规则）

## 流程

### 第零步：确保已登录知乎（仅首次需要）

知乎详情需要通过 opencli 的后台浏览器抓取（需登录态）。热榜列表有公开 API，不强制要求登录，但如果 opencli 命令返回 403，可直接回退到公开 API。**登录一次后 cookie 持久保存，后续无需重复登录。**

**重要**：`background-browser` 使用独立 Chrome Profile，与用户日常 Chrome 的登录状态**不共享**。即使用户已在常规 Chrome 中登录知乎，无头浏览器侧仍然是未登录状态，必须通过 `background-browser login` 在专属窗口中单独登录一次。

**首次使用（需要打开浏览器登录一次）：**

1. 如果 headless 浏览器正在运行，先停止：
   ```bash
   ~/.agents/skills/opencli-skill/scripts/run-opencli.sh zhihu background-browser stop
   ```

2. 打开可见的 Chrome 窗口让用户登录知乎：
   ```bash
   ~/.agents/skills/opencli-skill/scripts/run-opencli.sh zhihu background-browser login
   ```

3. 用户在弹出的 Chrome 窗口中手动登录知乎（扫码或密码）。

4. 登录完成后，通知 agent 继续。

**后续使用（无需打开浏览器，全自动无头）：**

登录 cookie 已保存在 profile 目录中。后续所有操作只需启动无头浏览器：
```bash
~/.agents/skills/opencli-skill/scripts/run-opencli.sh zhihu background-browser start
```
无头浏览器会自动加载已保存的 cookie，所有 `zhihu hot` / `zhihu detail` 命令都走无头会话，用户全程无需干预。

**踩坑记录：** `login` 和 `start` 使用同一个端口（9333），不能同时运行。如果 headless 浏览器正在运行，必须先 `stop` 再 `login`，否则可见登录窗口会因端口被占而静默失败。

### 第一步：获取热榜并编号展示

**优先尝试** opencli 后台静默浏览器：

```bash
~/.agents/skills/opencli-skill/scripts/run-opencli.sh zhihu hot --limit 50 -f json
```

**回退方案**：如果上述命令返回 HTTP 403 或其他错误，直接调用知乎公开 API（无需登录）：

```bash
curl -s "https://api.zhihu.com/topstory/hot-list?limit=50" \
  -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
  -o /tmp/zhihu_hot.json
```

然后用 Python 解析 JSON：

```python
import json
with open('/tmp/zhihu_hot.json', 'r') as f:
    data = json.load(f)
items = data.get('data', [])
for i, item in enumerate(items, 1):
    target = item.get('target', {})
    title = target.get('title', '无标题')
    qid = target.get('id', '')
    excerpt = target.get('excerpt', '')[:80]
    hot_text = item.get('detail_text', '')
    url = f'https://www.zhihu.com/question/{qid}' if qid else ''
    # 编号+标题+热度+摘要
```

**注意**：公开 API 只能获取热榜列表，详情页抓取仍需走 opencli 的 `zhihu detail`（需登录态）。

走 opencli 后台静默浏览器，不接管前台 Chrome。

拿到 JSON 后，解析每条记录的 `title`、`url`、`excerpt`（如有），按顺序编号输出给用户：

```
📋 知乎热榜（共 N 条）

1. 标题A — 一句话摘要
2. 标题B — 一句话摘要
3. 标题C — 一句话摘要
...
```

- 标题保持原文，不翻译不改写
- 摘要从 `excerpt` 或 `detail_text` 提取，截取前 60 字
- 编号从 1 开始连续递增
- 不要自动选中任何条目，等用户指定

### 第二步：用户指定编号 → 串行抓取 + 并行总结

用户会给出编号，格式可能是："1、3、5" 或 "2-6" 或 "7"。

**抓取阶段（串行）：**

对每个编号，依次执行：
```bash
~/.agents/skills/opencli-skill/scripts/run-opencli.sh zhihu detail "<url>" -f json
```
共用一个 headless Chrome 实例，必须串行，不能并发（并发会导致超时或结果为空）。

**总结阶段（并行）：**

全部抓取完成后，使用 `delegate_task` 并行总结：
- 将抓取到的文章按批次分配给子 agent
- 每个子 agent 拿到 1-3 篇文章内容（纯文本，无需浏览器）
- 子 agent 按 `high-memory-summary-skill` 规则输出总结
- 主 agent 收集所有总结，按编号顺序合并输出

**并行批次建议：**
- 3-5 篇：每篇一个子 agent
- 6-10 篇：每 2 篇一个子 agent
- 10+ 篇：每 3 篇一个子 agent
- 同时最多 3-4 个子 agent 并行

### 第三步：高记忆度总结输出

对每篇抓取到的内容，严格按 `high-memory-summary-skill` 的规则输出：

核心原则：
- 找到单条主线（governing thread）
- 只保留 3-5 个最值得记住的支持点
- 每个支持点带一个记忆锚点（数据、金句、反转、场景）
- 砍掉信息性细节，保留记忆性细节
- 语气像已经消化过内容的人在转述，不像笔记机器

输出结构（不要用机械前缀如"解释："、"关系："等）：

```
## [编号]. 标题

🔗 原文链接
👤 作者（如有）
📅 发布时间（如有）

### 值得记住的部分

（用自然段落写出主线 + 3-5 个支持点，每点带记忆锚点）

### 多想一层（仅在内容有观点/判断/预测时才加）

（简短一段，指出最容易误解的地方，或条件限制）
```

### 多篇处理

- 每篇独立一个 `##` 小节
- 各篇之间不合并、不交叉
- 按用户指定的编号顺序输出
- 如果某篇抓取失败，明确标注"抓取失败"并跳过

## 输出保存

全部总结完成后，同时保存一份到：

```
~/outputs/zhihu-hot-summary-skill/YYYY-MM-DD-知乎热榜总结.md
```

## 故障排查

### `zhihu hot` 返回 HTTP 403

这是最常见的问题，通常意味着 background-browser 的 cookie 已过期或从未登录。

**排查顺序**：
1. 先确认是否曾通过 `background-browser login` 登录过（不是普通 Chrome）
2. 如果不确定，直接回退到公开 API 拉热榜列表（无需登录）：
   ```bash
   curl -s "https://api.zhihu.com/topstory/hot-list?limit=50" \
     -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
     -o /tmp/zhihu_hot.json
   ```
3. 公开 API **只能获取列表**，详情页仍需走 `zhihu detail`（需登录态）
4. 如果详情也 403，执行 `stop` → `login` → 用户手动登录 → `start` 的完整流程

### 登录状态不共享

用户在常规 Chrome 登录知乎 ≠ 无头浏览器已登录。`background-browser` 使用独立 Chrome Profile（路径见 login 命令输出），必须专门登录。

## 注意事项

- 首次使用需通过 `background-browser login` 专门登录一次，后续全自动走无头浏览器
- 抓取阶段串行执行（共用一个 headless Chrome 实例），避免触发反爬
- 总结阶段可并行处理（每篇总结是纯 LLM 工作，无需浏览器）
- 如果 `zhihu detail` 抓到的是软文、广告或正文缺失，明确说明"无法正常总结"并给出原因
- 非中文内容先翻译为简体中文再总结
- 繁体中文统一转为简体中文
