# <BusinessName> Router

文档 ID：`<DOCUMENT-ID>`  
状态：`Active|Proposal`  
维护计数：`0/5`  
最后更新：`YYYY-MM-DD`

## 维护规则

本功能域的任务路由、权威文档或能力边界变化时更新本文。只有成功且实质影响业务的任务才增加维护计数；失败、取消、只读分析、租约操作和纯文档维护不计数。达到 `5/5` 时复核实际实现与任务证据，更新权威文档或记录 `reviewed-no-change` 后归零。证据写入本功能域 DeveloperLog，详细文档索引在本 Router 就近维护。

## 任务线索

| 线索 | 权威文档 |
|---|---|
| `<task>` | `<Guide-or-Design.md>` |

## 下级导航

| 子类 | Router |
|---|---|
| 无 | 无 |

## 并发资源

- `workflow:<BusinessRoot>`
- `path:<owned-path>`

## 能力边界

明确 Active 能力、Proposal 和需要用户确认的事项。
