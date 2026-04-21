# zhihu-hot-summary-skill

知乎热榜高记忆度总结：不打开浏览器，先拉热榜列表让你选，再逐篇抓取并用高记忆度规则总结。

## 流程

1. **拉热榜** — 用 opencli 公共接口获取知乎热榜（不依赖浏览器）
2. **编号展示** — 把热榜按编号列出来给你看
3. **你来选号** — 你指定想深入看的编号
4. **逐篇抓取** — 用 zhihu detail 抓每篇正文
5. **高记忆度总结** — 用 high-memory-summary-skill 的规则输出总结

## 依赖

- `opencli-skill` — 知乎热榜和详情抓取
- `high-memory-summary-skill` — 高记忆度总结规则

## 使用方式

直接告诉 agent：

> "看看知乎热榜"
> "知乎热榜总结"
> "zhihu hot summary"

Agent 会自动执行完整流程。

## 输出

总结结果保存到：

```
~/outputs/zhihu-hot-summary-skill/YYYY-MM-DD-知乎热榜总结.md
```
