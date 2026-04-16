-- ============================================================
-- 绩效考核系统 - PostgreSQL 数据库 Schema
-- 版本：1.0
-- 创建时间：2026-04-16
-- ============================================================

-- 启用 UUID 扩展
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 1. 用户表 (系统基础表)
-- ============================================================
CREATE TABLE sys_user (
    id              BIGSERIAL PRIMARY KEY,
    username        VARCHAR(50) NOT NULL UNIQUE,
    real_name       VARCHAR(100) NOT NULL,
    email           VARCHAR(100),
    phone           VARCHAR(20),
    password_hash   VARCHAR(255) NOT NULL,
    position_id     BIGINT,
    department_id   BIGINT,
    supervisor_id   BIGINT REFERENCES sys_user(id),
    status          SMALLINT DEFAULT 1, -- 1:active, 0:inactive
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_user_department ON sys_user(department_id);
CREATE INDEX idx_user_supervisor ON sys_user(supervisor_id);

-- ============================================================
-- 2. 部门表 (系统基础表)
-- ============================================================
CREATE TABLE sys_department (
    id              BIGSERIAL PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    parent_id       BIGINT REFERENCES sys_department(id),
    manager_id      BIGINT REFERENCES sys_user(id),
    level           SMALLINT DEFAULT 1,
    sort_order      INT DEFAULT 0,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- 3. 岗位考核模板表
-- ============================================================
CREATE TABLE perf_template (
    id                  BIGSERIAL PRIMARY KEY,
    post_name           VARCHAR(100) NOT NULL,
    post_code           VARCHAR(50) NOT NULL UNIQUE,
    weight_business     SMALLINT NOT NULL CHECK (weight_business BETWEEN 0 AND 100),
    weight_task         SMALLINT NOT NULL CHECK (weight_task BETWEEN 0 AND 100),
    weight_management   SMALLINT NOT NULL CHECK (weight_management BETWEEN 0 AND 100),
    weight_attitude     SMALLINT NOT NULL CHECK (weight_attitude BETWEEN 0 AND 100),
    description         TEXT,
    is_active           BOOLEAN DEFAULT TRUE,
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE perf_template IS '岗位考核模板 - 定义各岗位类型的权重配置';
COMMENT ON COLUMN perf_template.weight_business IS '经营指标权重 (10-30)';
COMMENT ON COLUMN perf_template.weight_task IS '关键任务权重 (50-65)';
COMMENT ON COLUMN perf_template.weight_management IS '团队管理权重 (0-14)';
COMMENT ON COLUMN perf_template.weight_attitude IS '能力态度权重 (20-30)';

CREATE INDEX idx_template_active ON perf_template(is_active);

-- ============================================================
-- 4. 考核指标库表
-- ============================================================
CREATE TABLE perf_indicator (
    id              BIGSERIAL PRIMARY KEY,
    template_id     BIGINT NOT NULL REFERENCES perf_template(id) ON DELETE CASCADE,
    dimension       VARCHAR(20) NOT NULL CHECK (dimension IN ('business', 'task', 'management', 'attitude')),
    indicator_name  VARCHAR(200) NOT NULL,
    default_weight  SMALLINT NOT NULL,
    is_dynamic      BOOLEAN DEFAULT FALSE,
    calculation_rule TEXT,
    max_score       SMALLINT DEFAULT 100,
    sort_order      INT DEFAULT 0,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE perf_indicator IS '考核指标库 - 各维度下的具体指标定义';
COMMENT ON COLUMN perf_indicator.dimension IS '维度：business=经营指标，task=关键任务，management=团队管理，attitude=能力态度';
COMMENT ON COLUMN perf_indicator.is_dynamic IS '是否动态配置，true 表示重点任务可自定义';
COMMENT ON COLUMN perf_indicator.calculation_rule IS '计算规则，用于经营指标自动算分';

CREATE INDEX idx_indicator_template ON perf_indicator(template_id);
CREATE INDEX idx_indicator_dimension ON perf_indicator(dimension);

-- ============================================================
-- 5. 月度考核表
-- ============================================================
CREATE TABLE perf_assessment (
    id                  BIGSERIAL PRIMARY KEY,
    employee_id         BIGINT NOT NULL REFERENCES sys_user(id) ON DELETE CASCADE,
    template_id         BIGINT NOT NULL REFERENCES perf_template(id),
    period              VARCHAR(7) NOT NULL, -- 格式：YYYY-MM
    evaluator_id        BIGINT REFERENCES sys_user(id), -- 评分人（上级）
    reviewer_id         BIGINT REFERENCES sys_user(id), -- 复审人（上上级）
    status              VARCHAR(20) DEFAULT 'draft' CHECK (status IN ('draft', 'submitted', 'confirmed', 'scored', 'reviewed', 'published')),
    
    target_submit_date  TIMESTAMP,
    target_confirm_date TIMESTAMP,
    result_submit_date  TIMESTAMP,
    score_confirm_date  TIMESTAMP,
    
    score_business      DECIMAL(5,2) DEFAULT 0,
    score_task          DECIMAL(5,2) DEFAULT 0,
    score_management    DECIMAL(5,2) DEFAULT 0,
    score_attitude      DECIMAL(5,2) DEFAULT 0,
    total_score         DECIMAL(5,2) DEFAULT 0,
    
    performance_level   VARCHAR(2), -- A/B/C/D
    performance_comment TEXT,
    
    is_locked           BOOLEAN DEFAULT FALSE,
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(employee_id, period)
);

COMMENT ON TABLE perf_assessment IS '月度考核表 - 每个员工每月的考核记录';
COMMENT ON COLUMN perf_assessment.status IS '状态流转：draft→submitted→confirmed→scored→reviewed→published';
COMMENT ON COLUMN perf_assessment.is_locked IS '是否锁定，锁定后不可修改';

CREATE INDEX idx_assessment_employee ON perf_assessment(employee_id);
CREATE INDEX idx_assessment_period ON perf_assessment(period);
CREATE INDEX idx_assessment_evaluator ON perf_assessment(evaluator_id);
CREATE INDEX idx_assessment_status ON perf_assessment(status);

-- ============================================================
-- 6. 目标任务记录表
-- ============================================================
CREATE TABLE perf_target (
    id              BIGSERIAL PRIMARY KEY,
    assessment_id   BIGINT NOT NULL REFERENCES perf_assessment(id) ON DELETE CASCADE,
    indicator_id    BIGINT REFERENCES perf_indicator(id),
    dimension       VARCHAR(20) NOT NULL,
    task_name       VARCHAR(200),
    target_value    VARCHAR(500),
    weight          SMALLINT NOT NULL,
    description     TEXT,
    deliverable     TEXT,
    sort_order      INT DEFAULT 0,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE perf_target IS '目标任务记录 - 每月初填报的重点任务目标';
COMMENT ON COLUMN perf_target.dimension IS '冗余字段，便于查询';
COMMENT ON COLUMN perf_target.task_name IS '任务名称，动态任务使用';
COMMENT ON COLUMN perf_target.target_value IS '目标值，可以是数值或描述';

CREATE INDEX idx_target_assessment ON perf_target(assessment_id);
CREATE INDEX idx_target_dimension ON perf_target(dimension);

-- ============================================================
-- 7. 实际完成记录表
-- ============================================================
CREATE TABLE perf_result (
    id              BIGSERIAL PRIMARY KEY,
    assessment_id   BIGINT NOT NULL REFERENCES perf_assessment(id) ON DELETE CASCADE,
    target_id       BIGINT REFERENCES perf_target(id),
    indicator_id    BIGINT REFERENCES perf_indicator(id),
    dimension       VARCHAR(20) NOT NULL,
    actual_value    VARCHAR(500),
    self_score      DECIMAL(5,2),
    score           DECIMAL(5,2),
    comment         TEXT,
    scored_by       BIGINT REFERENCES sys_user(id),
    scored_at       TIMESTAMP,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE perf_result IS '实际完成记录 - 月底反馈的实际完成情况及评分';
COMMENT ON COLUMN perf_result.self_score IS '员工自评分';
COMMENT ON COLUMN perf_result.score IS '上级评定的最终得分';

CREATE INDEX idx_result_assessment ON perf_result(assessment_id);
CREATE INDEX idx_result_target ON perf_result(target_id);

-- ============================================================
-- 8. 经营指标数据表
-- ============================================================
CREATE TABLE perf_business_data (
    id              BIGSERIAL PRIMARY KEY,
    assessment_id   BIGINT NOT NULL REFERENCES perf_assessment(id) ON DELETE CASCADE,
    indicator_id    BIGINT NOT NULL REFERENCES perf_indicator(id),
    indicator_name  VARCHAR(200) NOT NULL,
    plan_value      DECIMAL(12,2) NOT NULL, -- 累计计划值
    actual_value    DECIMAL(12,2) NOT NULL, -- 累计实际值
    completion_rate DECIMAL(5,2),           -- 完成率
    max_score       SMALLINT NOT NULL,      -- 最高分值
    calculated_score DECIMAL(5,2),          -- 计算得分
    data_source     VARCHAR(50),            -- 数据来源：manual/system
    confirmed_by    BIGINT REFERENCES sys_user(id),
    confirmed_at    TIMESTAMP,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE perf_business_data IS '经营指标数据 - 用于自动计算经营分';
COMMENT ON COLUMN perf_business_data.plan_value IS '累计计划值 = 年度保底目标 ÷ 12 × 月数';
COMMENT ON COLUMN perf_business_data.actual_value IS '累计实际值 = 年初至今实际完成值';
COMMENT ON COLUMN perf_business_data.calculated_score IS '计算得分 = (actual/plan) × max_score，封顶 100%';

CREATE INDEX idx_business_assessment ON perf_business_data(assessment_id);

-- ============================================================
-- 9. 评分记录表 (审计用)
-- ============================================================
CREATE TABLE perf_score_record (
    id              BIGSERIAL PRIMARY KEY,
    assessment_id   BIGINT NOT NULL REFERENCES perf_assessment(id) ON DELETE CASCADE,
    scorer_id       BIGINT NOT NULL REFERENCES sys_user(id),
    dimension       VARCHAR(20) NOT NULL,
    indicator_id    BIGINT REFERENCES perf_indicator(id),
    score           DECIMAL(5,2) NOT NULL,
    comment         TEXT,
    scored_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address      VARCHAR(45),
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE perf_score_record IS '评分记录 - 记录所有评分操作，用于审计';

CREATE INDEX idx_score_record_assessment ON perf_score_record(assessment_id);
CREATE INDEX idx_score_record_scorer ON perf_score_record(scorer_id);

-- ============================================================
-- 10. 绩效等级配置表
-- ============================================================
CREATE TABLE perf_grade_config (
    id              BIGSERIAL PRIMARY KEY,
    min_score       DECIMAL(5,2) NOT NULL,
    max_score       DECIMAL(5,2) NOT NULL,
    grade           VARCHAR(2) NOT NULL UNIQUE,
    coefficient     DECIMAL(3,2) DEFAULT 1.0, -- 绩效系数
    description     VARCHAR(100),
    is_active       BOOLEAN DEFAULT TRUE,
    effective_date  DATE,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE perf_grade_config IS '绩效等级配置 - 定义分数段对应的等级和系数';

-- 初始化默认等级配置
INSERT INTO perf_grade_config (min_score, max_score, grade, coefficient, description) VALUES
(90, 100, 'A', 1.2, '优秀'),
(75, 89.99, 'B', 1.0, '良好'),
(60, 74.99, 'C', 0.8, '合格'),
(0, 59.99, 'D', 0.5, '待改进');

-- ============================================================
-- 视图：员工考核汇总
-- ============================================================
CREATE VIEW v_employee_assessment_summary AS
SELECT 
    a.id,
    a.period,
    u.real_name AS employee_name,
    u.username,
    d.name AS department_name,
    p.post_name AS position,
    a.status,
    a.score_business,
    a.score_task,
    a.score_management,
    a.score_attitude,
    a.total_score,
    a.performance_level,
    a.created_at
FROM perf_assessment a
JOIN sys_user u ON a.employee_id = u.id
LEFT JOIN sys_department d ON u.department_id = d.id
LEFT JOIN perf_template p ON a.template_id = p.id
WHERE a.status != 'draft';

-- ============================================================
-- 触发器：自动更新 updated_at
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS \$\$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
\$\$ LANGUAGE plpgsql;

CREATE TRIGGER update_perf_template_updated_at
    BEFORE UPDATE ON perf_template
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_perf_assessment_updated_at
    BEFORE UPDATE ON perf_assessment
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_perf_target_updated_at
    BEFORE UPDATE ON perf_target
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_perf_result_updated_at
    BEFORE UPDATE ON perf_result
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 初始化数据：岗位模板示例
-- ============================================================
INSERT INTO perf_template (post_name, post_code, weight_business, weight_task, weight_management, weight_attitude, description) VALUES
('技术执行人员', 'TECH_EXEC', 10, 65, 0, 25, '普通技术人员，无管理职责'),
('技术主管', 'TECH_LEAD', 10, 51, 14, 25, '技术团队负责人'),
('项目经理', 'PM', 20, 60, 0, 20, '项目管理岗位'),
('营销总监', 'SALES_DIR', 30, 50, 0, 20, '营销部门负责人'),
('建模算量部经理', 'MODELING_MGR', 30, 50, 0, 20, '业务部门负责人'),
('职能部门员工', 'FUNC_STAFF', 10, 60, 0, 30, '行政/人事/财务等职能岗位'),
('职能部门主管', 'FUNC_MGR', 15, 50, 10, 25, '职能部门负责人');
