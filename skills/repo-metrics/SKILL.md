---
name: repo-metrics
description: 分析指定目录，输出文件总数、按后缀统计、最大文件 TopN、可选 TODO/FIXME 命中数。
---

# repo-metrics

此 Skill 用于深入分析指定目录的文件结构与质量特征。

## 触发关键词
统计仓库规模, 分析代码体量, 查看文件分布, 扫描 TODO 数量, repo-metrics

## 参数定义
- path: 扫描的目标路径（默认 .）
- top_n: 返回最大文件的数量（默认 5）
- include_patterns: 包含的文件模式（如 *.py）
- exclude_patterns: 排除的文件或目录模式
- scan_todo: 是否扫描 TODO/FIXME 关键字（布尔值）

## 使用示例

### 示例 1：基础全量统计
python scripts/repo_metrics.py --path .

### 示例 2：性能瓶颈分析（Top 10 大文件）与 TODO 统计
python scripts/repo_metrics.py --path ./src --top_n 10 --scan_todo

### 示例 3：特定类型过滤
python scripts/repo_metrics.py --include "*.py" "*.md" --exclude "tests/*"
