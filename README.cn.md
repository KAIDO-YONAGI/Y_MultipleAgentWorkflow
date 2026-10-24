# Y_MultipleAgentWorkflow 中文主手册

本仓库用于分发 `multiple-agent-workflow-config` Skill。它帮助项目把经验整理成
可路由、可维护、可跨会话复用的工作知识；多个 Agent 共用工作区时，用租约协调
并发修改。租约是协作协议，不会拦截未参与的 Agent 或用户手动改文件。Skill 可供
Codex、Claude、ZCode 和 WorkBuddy 使用。

英文摘要见 `README.md`。本文件是项目构成、使用、迁移、开发和发布的中文
主手册。

## 1. 先理解三层结构

这套系统不是把同一套规则复制到各处分别维护，而是分成三层：

| 层 | 位置 | 作用 | 所有权 |
|---|---|---|---|
| 通用 Skill 源码 | `src/skills/multiple-agent-workflow-config/` | 保存跨项目方法、初始化器、校验器和工作流模板 | 本仓库唯一权威 |
| 客户端安装入口 | Codex、Claude、ZCode 的用户级 Skill 目录 | 让本地安装器管理各客户端的 Skill | Copy 安装或指向源码的 Junction |
| WorkBuddy 分发 | WorkBuddy Skill ZIP | 导入 WorkBuddy 的 Skill | WorkBuddy 自身的导入/市场流程 |
| 项目工作流实例 | `<ProjectRoot>/Y_MultipleAgentWorkflow/` | 保存目标项目自己的 Router、Guide、Design、日志和租约 | 目标项目 Git |

Skill 教 Agent **怎样配置项目**；项目工作流记录 **这个项目实际怎样工作**。
二者不能互相替代。

## 2. 仓库目录分别做什么

```text
Y_MultipleAgentWorkflow/
├─ src/                  # 唯一 Skill 源码
├─ packaging/            # 客户端清单模板与 WorkBuddy 适配说明
├─ tools/                # 仓库工具
│  ├─ build/             # 打包
│  ├─ test/              # 分发回归与 Skill 元数据校验
│  ├─ install/           # 安装、升级、卸载
│  └─ lib/               # 共用 PowerShell 函数
├─ docs/                 # 发布流程与资产构成
├─ .github/workflows/    # Windows CI
├─ dist/                 # 本地生成的 Release 资产，不进 Git
├─ .tmp/                 # 测试和打包临时目录，不进 Git
├─ distribution-manifest.json
├─ VERSION
├─ LICENSE
├─ THIRD_PARTY_NOTICES.md
├─ requirements-dev.txt
├─ README.md
└─ README.cn.md
```

### `src/`

这里是唯一需要长期维护的 Skill 实体。

```text
src/skills/multiple-agent-workflow-config/
├─ SKILL.md
├─ agents/openai.yaml
├─ references/
│  ├─ configuration-method.md
│  ├─ doc-maintenance.md
│  └─ distribution.md
├─ assets/workflow-template/
└─ scripts/
```

- `SKILL.md`：触发条件、执行顺序、确认门槛和安全边界。
- `references/configuration-method.md`：完整通用配置方法论，也是初始化项目
  `Workflow_Configuration_Guide.md` 的来源。
- `references/doc-maintenance.md`：既有工作流的维护方法，覆盖单一来源、入口薄化、章节顺序、矛盾清理和引用验证。
- `references/distribution.md`：安装与升级边界，发布流程见 `docs/Distribution_Guide.md`。
- `assets/workflow-template/`：项目 Router、日志、租约指南和托管脚本模板。
- `scripts/Initialize-Workflow.ps1`：初始化项目工作流。
- `scripts/Test-WorkflowConfiguration.ps1`：校验项目实例。
- `scripts/Update-WorkflowInstance.ps1`：升级未漂移的托管文件。

### `packaging/`

这里只保存很小的客户端适配清单模板，不复制 Skill 主体：

- `codex/plugin.json`
- `claude/plugin.json` 与 `marketplace.json`
- `zcode/plugin.json` 与 `marketplace.json`

打包时，版本号和下载信息由 `distribution-manifest.json` 渲染进去。

### `tools/`

- `install/Install-MAW.ps1`：Copy 或 Junction 安装。
- `install/Update-MAW.ps1`：显式下载 GitHub Release 或使用离线包升级。
- `install/Uninstall-MAW.ps1`：只删除安装记录证明由 MAW 创建的入口。
- `install/Update-WorkflowInstance.ps1`：仓库级项目实例升级入口，转发到 Skill 内实现。
- `build/Build-Distribution.ps1`：生成 Codex、Claude、ZCode、WorkBuddy 包、离线包和校验和。
- `test/Test-Distribution.ps1`：执行初始化、租约、安装、升级和打包回归。
- `test/validate_skill.py`：Skill 元数据校验。
- `test/validate_workbuddy.py`：WorkBuddy ZIP 结构与元数据校验。
- `lib/MAW.Common.ps1`：上述脚本共用的路径、JSON、哈希和安装辅助函数。
- `requirements-dev.txt`：Skill 元数据校验所需的 Python 开发依赖。
- `THIRD_PARTY_NOTICES.md`：第三方依赖与分发声明。

## 3. 一份源码，多份构建产物

Codex、Claude、ZCode 包中的 Skill 内容逐文件相同，只多出各自的插件清单。
WorkBuddy 包从同一源码生成，并按平台要求加入双语元数据、许可证和资源目录适配；
它不是另一套独立配置。

- 客户端布局只在 `.tmp/distribution/clients/` 临时展开。
- 最终 ZIP、Marketplace 元数据和 `SHA256SUMS` 只输出到 `dist/`。
- `.tmp/` 与 `dist/` 都可随时删除，再通过构建脚本重建。
- Claude Marketplace 直接引用仓库中的唯一 Skill 源码目录。

发布构建生成 Codex、Claude、ZCode 客户端 ZIP、WorkBuddy Skill ZIP 和离线包。
项目采用 MIT License 开源，许可条款见根目录 `LICENSE`；所有分发 ZIP 均携带
该许可证。WorkBuddy 包只有一个顶层技能目录，含 `SKILL.md`、references、
scripts、`templates/workflow-template.zip`、版本清单和 `LICENSE`，不含其他
客户端专用文件。平台上传解析器拒绝 Skill 根目录下超过两段的文件路径，因此
模板内部目录保存在 ZIP 中；初始化器和升级器会校验路径并临时解压，完成后清理。

WorkBuddy 的脚本面向 Windows，运行时需要 Windows PowerShell 5.1（Windows 自带）
或 PowerShell 7；PowerShell 7 不是额外必装项。WorkBuddy 的执行工具使用 Bash，
因此须由 Bash 在同一 Windows 环境调用 `powershell.exe`；若其执行环境无法访问
Windows 工作区或启动该程序，应由用户在本机运行脚本。Codex、Claude、ZCode
本地安装器不管理 WorkBuddy，WorkBuddy ZIP 需通过其自身流程导入。导入包与市场
上架是两件事；本项目仅面向免费开源分发，不会因市场资格限制改为付费发布。

运行时没有第三方模块依赖。Python 3 与 PyYAML 仅用于开发/CI 元数据校验；
Git 用于克隆仓库，Git 与 GitHub CLI (`gh`) 分别仅在对应的显式更新路径需要。
离线包带有开发依赖清单，但不包含 PyYAML 本体。

项目初始化后仍会出现一份 `Workflow_Configuration_Guide.md`。这是有意的：
目标项目需要在没有全局 Skill 或网络的情况下仍可独立理解自己的工作流。
这份项目副本属于 `projectOwned`，不会被升级器自动覆盖。

## 4. Skill 怎么触发

安装成功后，可以自然语言调用：

```text
请使用 multiple-agent-workflow-config 分析这个项目，并提出工作流分类方案。
```

在支持显式 Skill 名称的客户端中也可以写：

```text
$multiple-agent-workflow-config
```

Skill 会先只读盘点项目，然后提出：

- 一级稳定知识域和二级任务阶段；
- 应迁移、索引或保留在外部的文档；
- 并发路径和共享资源；
- 模型入口接入方式；
- 是否创建项目验证指南。

新增顶级分类、迁移旧权威文档和修改模型入口仍需用户单独确认。

当客户端是 Codex 且多个任务共享同一工作树时，Skill 还会把
WorkingAgent 租约与 Codex 原生任务消息连接起来：发现重叠租约时通知对方，
释放后通知等待任务；租约注册表、实际文件和验证结果仍然是权威，消息不会
自动授予修改权限，也不会自动接管疑似失活租约。没有原生消息能力的客户端
继续使用租约检查和用户报告。

## 5. 当前开发机安装

仓库开发者适合使用 Junction，使三个客户端始终读取当前源码：

```powershell
& '.\tools\install\Install-MAW.ps1' `
  -Clients Codex,Claude,ZCode `
  -Mode Junction `
  -SourceRoot $PWD `
  -Replace `
  -WhatIf
```

检查输出后移除 `-WhatIf`。Junction 只用于用户级 Skill 入口，不应用于项目
中的 `Y_MultipleAgentWorkflow/`。

查看入口是否指向同一源码：

```powershell
Get-Item `
  "$HOME\.agents\skills\multiple-agent-workflow-config", `
  "$HOME\.claude\skills\multiple-agent-workflow-config", `
  "$HOME\.zcode\skills\multiple-agent-workflow-config" |
  Select-Object FullName,LinkType,Target
```

客户端发现目录可能随版本变化；安装器中的客户端目标解析是实际权威。

## 6. 迁移到另一台电脑

### 在线迁移

1. 使用 Windows PowerShell 5.1（Windows 自带）或 PowerShell 7；WorkBuddy 还要求
   Bash 工具能在同一 Windows 主机访问工作区并启动 `powershell.exe`。
2. 仅从源码克隆时需要 Git；GitHub CLI (`gh`) 只在显式下载 GitHub Release 更新时需要。
3. 克隆本仓库。
4. 在仓库根运行 `Install-MAW.ps1`。
5. 普通用户使用 `-Mode Copy`；只有准备直接开发 Skill 时使用 Junction。

```powershell
& '.\tools\install\Install-MAW.ps1' `
  -Clients Codex,Claude,ZCode `
  -Mode Copy `
  -SourceRoot $PWD `
  -WhatIf
```

### 离线迁移

从 GitHub Release 取得：

```text
Y_MultipleAgentWorkflow-<version>-offline.zip
SHA256SUMS
```

核验 SHA-256、解压，然后运行包内安装器：

```powershell
& '.\tools\install\Install-MAW.ps1' `
  -Clients Codex,Claude,ZCode `
  -Mode Copy `
  -PackagePath '<offline-zip>' `
  -WhatIf
```

安装完成后重启或重新载入对应客户端，使其重新扫描 Skill。

## 7. 给新项目初始化工作流

先让 Skill 分析项目并确认分类，再预览初始化：

```powershell
$skillRoot = '<客户端解析出的 Skill 根目录>'

& "$skillRoot\scripts\Initialize-Workflow.ps1" `
  -ProjectRoot '<目标项目根>' `
  -Categories @('Workflow', 'GUI', 'Resources.Load') `
  -ProjectValidationMode None `
  -WhatIf
```

这里的分类只是调用示例。真实分类必须来自目标项目事实。

- `ProjectValidationMode=None`：不创建也不强制任何构建、发布或运行流程。
- `ProjectValidationMode=Guide`：创建独立验证指南，具体命令仍需用户确认。
- 已存在工作流时默认拒绝覆盖。
- `-Merge` 只补缺失文件，不重写已有 Router、Guide 或日志。

确认预览后移除 `-WhatIf`，再校验：

```powershell
& "$skillRoot\scripts\Test-WorkflowConfiguration.ps1" `
  -ProjectRoot '<目标项目根>' `
  -RunWorkingAgentTests
```

## 8. 给已有项目迁移

不要直接把模板覆盖到旧项目。推荐顺序：

1. 盘点 Router、Guide、Design、日志、入口文件和外部证据。
2. 找出双重权威、失效路径和硬编码项目根。
3. 按稳定知识域提出一级分类，按重复任务阶段提出二级分类。
4. 明确哪些文档迁移、哪些只索引、哪些标记 Proposal。
5. 先执行初始化 `-WhatIf`。
6. 初始化空结构或使用 `-Merge` 补缺失项。
7. 人工迁移项目权威内容并同步 Router 索引。
8. 用户选择后再修改 `AGENTS.md`、`CLAUDE.md` 等入口。
9. 运行结构校验和 WorkingAgent 回归。

通用分类方法与 GUI、Resources、Load、MatchClean 等已验证判断案例见
`src/skills/multiple-agent-workflow-config/references/configuration-method.md`。
案例用于解释“为什么拆分”，不是要求所有项目照抄目录。

## 9. 模型入口怎么处理

初始化器默认 `EntryMode=None`，不会修改入口。Agent 应先扫描现有内容，再让
用户选择：

1. 保留原规则，加入可重复维护的根 Router 导航块。
2. 替换为只要求读取根 Router 的精简入口。

安装 Skill 和修改项目入口是两个独立动作。安装成功不代表项目已接入 Router。

## 10. 升级与卸载

显式检查并下载 GitHub Release：

```powershell
& '.\tools\install\Update-MAW.ps1' -Clients Codex,Claude,ZCode
```

使用本地离线包：

```powershell
& '.\tools\install\Update-MAW.ps1' `
  -Clients Codex,Claude,ZCode `
  -PackagePath '<offline-zip>' `
  -ExpectedSha256 '<sha256>'
```

升级某个已经初始化的项目：

```powershell
& '.\tools\install\Update-WorkflowInstance.ps1' `
  -ProjectRoot '<目标项目根>'
```

预览确认后增加 `-Apply`。升级器只更新未漂移的 `managed` 文件：

- WorkingAgent 脚本与回归测试；
- 业务 Router/日志模板；
- 租约忽略配置。

Router、DeveloperLog、Guide、Design 和 Proposal 是 `projectOwned`，不会自动
覆盖。卸载客户端入口：

```powershell
& '.\tools\install\Uninstall-MAW.ps1' -Clients Codex,Claude,ZCode
```

卸载 Skill 不会删除任何项目工作流实例。

## 11. 开发、测试与发布

长期修改只应发生在：

- `src/`：通用 Skill 和项目模板；
- `packaging/`：客户端清单模板；
- `tools/`：分发工具、安装器和验证；
- `docs/`、`README.md`、`README.cn.md`：说明文档。

不要编辑 `.tmp/` 或 `dist/` 中的文件，它们会在下次构建时被清理。

完整验证：

```powershell
python .\tools\test\validate_skill.py `
  .\src\skills\multiple-agent-workflow-config

& '.\tools\test\Test-Distribution.ps1'
& '.\tools\build\Build-Distribution.ps1'
```

发布前确认：

- Codex、Claude、ZCode ZIP 中的 Skill 与 `src` 逐文件哈希一致；
- WorkBuddy ZIP 只有预期的单一顶层目录、必需双语字段、版本、作者和 `LICENSE`；
- WorkBuddy ZIP 的 `references/`、`scripts/`、`templates/` 与正文引用一致；
- Claude Marketplace 指向当前标签下的唯一源码目录；
- ZCode Marketplace 中的包 SHA-256 与 ZIP 一致；
- 所有 ZIP 包含 `LICENSE`；
- 离线包包含安装器、版本清单、中英文 README、`docs/`、第三方声明和开发依赖清单；
- `THIRD_PARTY_NOTICES.md` 记录依赖范围、许可证和是否随包分发；
- 发布前检查新增依赖、模板和资源的来源及再分发条件；
- `SHA256SUMS` 覆盖全部发布资产；
- Git 工作树只包含有意修改；
- 标签与 `distribution-manifest.json` 版本一致。
- WorkBuddy 开放平台的技能规范和发布/定价规则可能变化；当前技术 ZIP 校验不等于
  市场审核通过。免费开源仓库分发与 WorkBuddy 市场免费上架是两件事，上架前须在
  账号实际发布流程确认可选的免费模式及平台要求。

## 12. 常见误区

**看到项目里也有 Guide，是不是重复权威？**

不是。Skill 中的是跨项目方法源；项目中的 Guide 是初始化时复制的、自包含的
项目文档。项目副本归项目所有，不会随 Skill 自动改写。

**能否只安装 Skill，不初始化项目？**

可以。Skill 安装只提供能力；项目是否采用 Router、租约或维护计数由用户决定。

**是否强制使用 WorkingAgent？**

通用方法不要求所有项目启用并发租约。初始化模板包含经过验证的实现，但是否
在目标项目中作为强制流程，应在配置阶段确认。

**是否强制 Build/Publish/Run？**

不强制。初始化时必须单独选择项目验证模式，命令不能从其他项目案例推断。

**为什么不使用 Submodule 或把项目目录 Junction 到本仓库？**

项目 Router、日志和业务指南会持续产生项目事实，必须随项目 Git 独立演进。
全局仓库只拥有通用方法和可升级的托管模板。
