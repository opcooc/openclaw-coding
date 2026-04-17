# 华规绩效考评系统 - 数据库设计说明

## 📋 文档信息
- **版本**：P0 基线版
- **日期**：2026-04-17
- **数据库**：PostgreSQL 14+
- **状态**：待审核

## 🗂️ 数据表清单

| 表名 | 说明 | 核心字段 |
|------|------|----------|
| `departments` | 部门表 | id, name, parent_id, manager_id |
| `positions` | 岗位表 | id, name, code, level, 权重配置 |
| `users` | 用户表 | id, username, real_name, department_id, position_id, role |
| `reporting_relationships` | 组织关系表 | user_id, evaluator_id, weight, eval_cycle |
| `monthly_key_tasks` | 月度重点任务表 | user_id, eval_year, eval_month, task_name, status |
| `evaluation_scores` | 考核打分表 | user_id, eval_year, eval_month, 各项得分，总分，等级 |
| `indicator_templates` | 考核指标模板表 | position_id, indicator_type, indicator_name, max_score |
| `system_config` | 系统配置表 | config_key, config_value |

## 🔑 核心设计要点

### 1. 岗位权重配置
岗位表 (`positions`) 预置 4 项权重：
- `key_task_weight` - 关键任务权重（默认 65%）
- `ability_weight` - 能力态度权重（默认 25%）
- `business_weight` - 经营指标权重（默认 10%）
- `team_weight` - 团队管理权重（默认 0%）

### 2. 用户角色体系
用户表 (`users`) 的 `role` 字段定义 7 种角色：
- `1` - 普通员工
- `2` - 技术主管
- `3` - 项目经理
- `4` - 部门经理
- `5` - 营销总监
- `6` - 总经理
- `9` - 系统管理员

### 3. 考核关系配置
组织关系表 (`reporting_relationships`) 支持：
- 多考评人配置（直接上级 + 项目经理）
- 权重灵活分配（100% 或 50%+50%）
- 分考核周期（月度/季度/年度）

### 4. 考核流程状态
月度重点任务表 (`monthly_key_tasks`) 状态流转：
```
1 草稿 → 2 已提交 → 3 已审核 → 4 已打分
```

考核打分表 (`evaluation_scores`) 状态流转：
```
1 待打分 → 2 已打分 → 3 已审核 → 4 已公示
```

### 5. 成绩等级划分
考核打分表 (`evaluation_scores`) 的 `grade` 字段：
- `A` - 90-100 分（优秀）
- `B` - 80-89 分（良好）
- `C` - 70-79 分（合格）
- `D` - 0-69 分（待改进）

## 📊 ER 关系图

```
departments (1) ──< (N) users
positions   (1) ──< (N) users
users       (1) ──< (N) monthly_key_tasks
users       (1) ──< (N) evaluation_scores
users       (1) ──< (N) reporting_relationships
positions   (1) ──< (N) indicator_templates
```

## ⚠️ 待确认事项

1. **密码加密算法**：bcrypt 或 argon2？
2. **考核周期配置**：是否需要支持自定义周期？
3. **经营指标数据来源**：是否需要对接财务/CRM 系统？
4. **数据归档策略**：历史考核数据保留年限？

## 📝 审核意见栏

**审核人**：谌工
**审核日期**：__________
**审核结果**：□ 通过  □ 需修改  □ 重新设计

**修改意见**：
_________________________________
_________________________________

---

**文件路径**：`database/schema.sql`
**Git 分支**：`main`
**提交记录**：待提交
