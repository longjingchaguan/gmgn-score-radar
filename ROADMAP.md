# GMGN 选币评分 Roadmap

目标：把 `aitrader` 里真正有价值的部分沉淀成一个 macOS 原生选币评分工具：

- 抓取 GMGN OpenAPI 的趋势代币。
- 解析安全、筹码、动能、共识字段。
- 用确定性规则过滤高风险代币。
- 用评分规则给候选排序。
- 把每个候选为什么通过或淘汰讲清楚。
- 只在系统分达到 70 时打扰用户，并用系统通知直达 GMGN。

明确不做：

- 不做实盘交易。
- 不做下单、签名、swap、order query。
- 不做正式分发、公证、自动更新。
- 不做 Web/GitHub Pages 演示。

## 当前状态

已完成：

- SwiftUI 原生 macOS 菜单栏 App。
- 中文 UI。
- 不依赖 Python、FastAPI、浏览器页面或 `gmgn-cli` 运行时。
- App 通过 `URLSession` 直连 `https://openapi.gmgn.ai`。
- API key 存 macOS Keychain。
- 兼容读取旧 `~/.config/gmgn/.env` 的 API key。
- `/v1/market/rank` 抓取趋势代币。
- 扫描设置持久化：
  - chain
  - interval
  - limit
  - order_by
  - direction
  - per-chain platforms / filters
- 核心评分逻辑已移植：
  - feature extraction
  - hard gates
  - priority score
  - heuristic verdict
  - 系统分 70 通过线
- 产品化主体验：
  - 无主面板
  - 菜单栏只显示状态、70+ 候选、手动扫描、设置和退出
  - 不显示买入、卖出、持仓、实盘入口
- 常驻雷达体验：
  - 启动后自动扫描
  - 默认每 30 秒扫描一次
  - 菜单栏显示强候选数量
  - 扫描到新的 70+ 候选发送 macOS 系统通知
  - 点击通知或菜单栏代币打开 GMGN 代币交易页
- JSONL 日志：
  - SCREEN
  - FILTER
- 本地 `.app` 打包脚本：
  - `scripts/build-app.sh`
  - ad-hoc signed `dist/GMGN 选币评分.app`

## 剩余工作

### 1. 抓取能力增强

- 给平台 filters 做原生编辑控件，而不是只靠配置结构。
- 给常用 presets：
  - SOL Pump
  - BSC FourMeme
  - 全平台 volume
  - smart/KOL 优先
- 增加 OpenAPI 错误解释：
  - API key 缺失
  - IP 白名单
  - rate limit
  - 字段为空

### 2. 评分规则可视化

- 以轻量方式展示分数拆解，不恢复重型面板：
  - 5m 动能
  - 1h 动能
  - 买盘压力
  - 换手
  - 共识
  - 安全筹码
- 给 hard gate 显示闸门位置：
  - 避雷
  - 共识
  - 排序
  - 解释
- 支持一键导出本轮评分结果为 JSON/CSV。

### 3. 规则调参

- 设置页暴露更多评分参数：
  - bundler 上限
  - dev 持仓上限
  - top10 上限
  - buy ratio 通过线
  - min smart/KOL
  - rank weights
- 增加“恢复默认规则”按钮。
- 增加规则配置导入/导出。

### 4. 验证与测试

- 保存一批 OpenAPI fixture。
- 给以下逻辑加单测：
  - decoder 容错
  - feature extraction
  - hard gates
  - priority score
  - verdict engine
- 用 fixture 对比旧 Python 版输出，确保规则迁移没有明显偏差。

## 交付定义

自用交付标准：

- 双击 `GMGN 选币评分.app` 可运行。
- 填入 API key 后能抓取实时代币。
- 默认每 30 秒后台扫描一次。
- 系统分低于 70 不通知。
- 新出现的 70+ 候选会发 macOS 系统通知。
- 点击通知可直接打开 GMGN 代币交易页。
- 菜单栏不变成交易面板，只保留必要控制。
- 不出现任何买入、卖出、实盘、持仓操作入口。

当前状态：已达到菜单栏自用版。后续重点是抓取 presets、规则调参和测试。
