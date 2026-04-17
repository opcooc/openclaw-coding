-- ============================================================
-- 华规绩效考评系统 - 数据库设计文档
-- 版本：P0 基线版
-- 日期：2026-04-17
-- 数据库：PostgreSQL 14+
-- ============================================================

-- 1. 部门表
CREATE TABLE departments (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,        -- 部门名称
    parent_id INTEGER REFERENCES departments(id), -- 上级部门 ID
    manager_id INTEGER,                        -- 部门负责人 ID
    employee_count INTEGER DEFAULT 0,          -- 员工人数
    status SMALLINT DEFAULT 1,                 -- 状态：1 正常，0 停用
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. 岗位表
CREATE TABLE positions (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,         -- 岗位名称
    code VARCHAR(50) NOT NULL UNIQUE,          -- 岗位代码
    level SMALLINT NOT NULL,                   -- 岗位层级（1-高管，2-中层，3-基层，4-员工）
    key_task_weight DECIMAL(5,2) DEFAULT 65,   -- 关键任务权重
    ability_weight DECIMAL(5,2) DEFAULT 25,    -- 能力态度权重
    business_weight DECIMAL(5,2) DEFAULT 10,   -- 经营指标权重
    team_weight DECIMAL(5,2) DEFAULT 0,        -- 团队管理权重
    status SMALLINT DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. 用户表
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,      -- 登录账号
    password_hash VARCHAR(255) NOT NULL,       -- 密码哈希
    real_name VARCHAR(50) NOT NULL,            -- 真实姓名
    email VARCHAR(100),                        -- 邮箱
    phone VARCHAR(20),                         -- 手机号
    department_id INTEGER REFERENCES departments(id), -- 所属部门
    position_id INTEGER REFERENCES positions(id),     -- 岗位
    role SMALLINT NOT NULL,                    -- 角色：1 员工，2 主管，3 项目经理，4 部门经理，5 营销总监，6 总经理，9 管理员
    direct_superior_id INTEGER REFERENCES users(id),  -- 直接上级
    status SMALLINT DEFAULT 1,                 -- 状态：1 正常，0 离职
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. 组织关系表（考核关系配置）
CREATE TABLE reporting_relationships (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id),        -- 被考核人
    evaluator_id INTEGER NOT NULL REFERENCES users(id),   -- 考评人
    evaluator_role SMALLINT NOT NULL,                     -- 考评人角色类型
    weight DECIMAL(5,2) NOT NULL,                         -- 打分权重
    eval_cycle SMALLINT NOT NULL,                         -- 考核周期：1 月度，2 季度，3 年度
    status SMALLINT DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, evaluator_id, eval_cycle)
);

-- 5. 月度重点任务表
CREATE TABLE monthly_key_tasks (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id),
    eval_year SMALLINT NOT NULL,               -- 考核年度
    eval_month SMALLINT NOT NULL,              -- 考核月份
    task_name VARCHAR(200) NOT NULL,           -- 任务名称
    task_description TEXT,                     -- 任务描述
    deliverable VARCHAR(200),                  -- 交付成果
    estimated_percent DECIMAL(5,2),            -- 预计完成百分比
    actual_percent DECIMAL(5,2),               -- 实际完成百分比
    status SMALLINT DEFAULT 1,                 -- 状态：1 草稿，2 已提交，3 已审核，4 已打分
    submitted_at TIMESTAMP,
    approved_at TIMESTAMP,
    approved_by INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 6. 考核打分表
CREATE TABLE evaluation_scores (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id),        -- 被考核人
    eval_year SMALLINT NOT NULL,                          -- 考核年度
    eval_month SMALLINT NOT NULL,                         -- 考核月份
    task_score DECIMAL(5,2),                              -- 关键任务得分
    ability_score DECIMAL(5,2),                           -- 能力态度得分
    business_score DECIMAL(5,2),                          -- 经营指标得分
    team_score DECIMAL(5,2),                              -- 团队管理得分
    total_score DECIMAL(5,2),                             -- 总分
    grade CHAR(1),                                        -- 等级：A/B/C/D
    evaluator_id INTEGER REFERENCES users(id),            -- 考评人
    evaluator_role SMALLINT,                              -- 考评人角色
    status SMALLINT DEFAULT 1,                            -- 状态：1 待打分，2 已打分，3 已审核，4 已公示
    comment TEXT,                                         -- 评语
    reviewed_at TIMESTAMP,
    reviewed_by INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, eval_year, eval_month, evaluator_role)
);

-- 7. 考核指标模板表
CREATE TABLE indicator_templates (
    id SERIAL PRIMARY KEY,
    position_id INTEGER REFERENCES positions(id),         -- 适用岗位
    indicator_type SMALLINT NOT NULL,                     -- 指标类型：1 关键任务，2 能力态度，3 经营指标，4 团队管理
    indicator_name VARCHAR(100) NOT NULL,                 -- 指标名称
    indicator_description TEXT,                           -- 指标说明
    max_score DECIMAL(5,2) NOT NULL,                      -- 最高分值
    weight DECIMAL(5,2),                                  -- 权重
    sort_order INTEGER DEFAULT 0,                         -- 排序
    status SMALLINT DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 8. 系统配置表
CREATE TABLE system_config (
    id SERIAL PRIMARY KEY,
    config_key VARCHAR(100) NOT NULL UNIQUE,              -- 配置键
    config_value TEXT,                                    -- 配置值
    config_type SMALLINT,                                 -- 配置类型
    description VARCHAR(200),                             -- 配置说明
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_by INTEGER REFERENCES users(id)
);

-- ============================================================
-- 索引优化
-- ============================================================
CREATE INDEX idx_users_department ON users(department_id);
CREATE INDEX idx_users_position ON users(position_id);
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_tasks_user_month ON monthly_key_tasks(user_id, eval_year, eval_month);
CREATE INDEX idx_scores_user_month ON evaluation_scores(user_id, eval_year, eval_month);
CREATE INDEX idx_reporting_user ON reporting_relationships(user_id);
CREATE INDEX idx_departments_parent ON departments(parent_id);

-- ============================================================
-- 初始数据
-- ============================================================

-- 岗位初始数据
INSERT INTO positions (name, code, level, key_task_weight, ability_weight, business_weight, team_weight) VALUES
('技术执行人员', 'TECH_EXEC', 4, 65.00, 25.00, 10.00, 0.00),
('技术主管', 'TECH_LEAD', 3, 51.00, 25.00, 10.00, 14.00),
('项目经理', 'PROJ_MGR', 3, 60.00, 20.00, 20.00, 0.00),
('部门经理', 'DEPT_MGR', 2, 50.00, 20.00, 20.00, 10.00),
('营销总监', 'MKT_DIR', 2, 45.00, 20.00, 30.00, 5.00),
('总经理', 'GM', 1, 40.00, 20.00, 35.00, 5.00);

-- 管理员账号（密码：admin123，实际使用时需哈希）
INSERT INTO users (username, password_hash, real_name, role, status) VALUES
('admin', '$2b$10$...', '系统管理员', 9, 1);

-- ============================================================
-- 视图：员工考核成绩汇总
-- ============================================================
CREATE VIEW v_employee_score_summary AS
SELECT 
    u.id AS user_id,
    u.real_name,
    d.name AS department_name,
    p.name AS position_name,
    es.eval_year,
    es.eval_month,
    es.total_score,
    es.grade,
    es.status
FROM users u
LEFT JOIN departments d ON u.department_id = d.id
LEFT JOIN positions p ON u.position_id = p.id
LEFT JOIN evaluation_scores es ON u.id = es.user_id
WHERE u.status = 1;

-- ============================================================
-- 备注说明
-- ============================================================
-- 1. 所有金额字段使用 DECIMAL(10,2)，百分比使用 DECIMAL(5,2)
-- 2. 状态字段统一：SMALLINT，1=正常/启用，0=停用/禁用
-- 3. 时间字段统一使用 TIMESTAMP，默认 CURRENT_TIMESTAMP
-- 4. 外键关系统一使用 INTEGER REFERENCES
-- 5. 唯一约束使用 UNIQUE 关键字
-- 6. 密码存储使用 bcrypt 或 argon2 哈希算法
-- ============================================================
