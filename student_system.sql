-- ============================================================
-- 学生管理系统 · MySQL 8.0 数据库脚本
-- 特点：没有管理员角色，学生用学号登录
-- 执行方式：Navicat 里整个文件运行，或命令行 source
-- ⚠ 本脚本会先 DROP DATABASE，重复执行会清空原有数据
-- ============================================================

SET NAMES utf8mb4;

DROP DATABASE IF EXISTS `student_system`;
CREATE DATABASE `student_system`
    DEFAULT CHARACTER SET utf8mb4
    COLLATE utf8mb4_general_ci;
USE `student_system`;

-- ------------------------------------------------------------
-- 1. students 学生表（学号即登录账号）
-- ------------------------------------------------------------
CREATE TABLE `students` (
    `student_id` VARCHAR(20)  NOT NULL                COMMENT '学号（登录账号）',
    `name`       VARCHAR(50)  NOT NULL                COMMENT '姓名',
    `password`   VARCHAR(100) NOT NULL                COMMENT '密码（演示用明文，生产请存哈希）',
    `class_name` VARCHAR(50)  DEFAULT NULL            COMMENT '班级',
    `major`      VARCHAR(50)  DEFAULT NULL            COMMENT '专业',
    `phone`      VARCHAR(30)  DEFAULT NULL            COMMENT '联系方式',
    `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (`student_id`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '学生表';

-- ------------------------------------------------------------
-- 2. courses 课程表（selected_count = 已选人数，max_count = 最大人数）
-- ------------------------------------------------------------
CREATE TABLE `courses` (
    `id`             INT          NOT NULL AUTO_INCREMENT COMMENT '课程ID',
    `course_name`    VARCHAR(100) NOT NULL                COMMENT '课程名称',
    `teacher`        VARCHAR(50)  DEFAULT NULL            COMMENT '任课教师',
    `time_slot`      VARCHAR(50)  NOT NULL                COMMENT '上课时间，如：周一 1-2节',
    `credit`         DECIMAL(3,1) NOT NULL DEFAULT 2.0    COMMENT '学分',
    `location`       VARCHAR(50)  DEFAULT NULL            COMMENT '上课地点',
    `selected_count` INT          NOT NULL DEFAULT 0      COMMENT '已选人数',
    `max_count`      INT          NOT NULL DEFAULT 50     COMMENT '最大人数',
    PRIMARY KEY (`id`),
    CONSTRAINT `chk_courses_count` CHECK (`selected_count` >= 0 AND `max_count` > 0)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '课程表';

-- ------------------------------------------------------------
-- 3. selections 选课记录（同一学生同一课程只能有一条）
-- ------------------------------------------------------------
CREATE TABLE `selections` (
    `id`         INT         NOT NULL AUTO_INCREMENT COMMENT '主键',
    `student_id` VARCHAR(20) NOT NULL                COMMENT '学号',
    `course_id`  INT         NOT NULL                COMMENT '课程ID',
    `created_at` DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '选课时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_selection_student_course` (`student_id`, `course_id`),
    KEY `idx_selection_course` (`course_id`),
    CONSTRAINT `fk_selection_student` FOREIGN KEY (`student_id`)
        REFERENCES `students` (`student_id`) ON DELETE CASCADE,
    CONSTRAINT `fk_selection_course` FOREIGN KEY (`course_id`)
        REFERENCES `courses` (`id`) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '选课记录表';

-- ------------------------------------------------------------
-- 4. leaves 请假记录（状态：待审批 / 已通过 / 已驳回 / 已撤回）
-- ------------------------------------------------------------
CREATE TABLE `leaves` (
    `id`         INT          NOT NULL AUTO_INCREMENT COMMENT '主键',
    `student_id` VARCHAR(20)  NOT NULL                COMMENT '学号',
    `leave_type` VARCHAR(20)  NOT NULL DEFAULT '事假'  COMMENT '请假类型：病假/事假/其他',
    `start_time` DATETIME     NOT NULL                COMMENT '开始时间',
    `end_time`   DATETIME     NOT NULL                COMMENT '结束时间',
    `reason`     VARCHAR(255) NOT NULL                COMMENT '请假原因',
    `status`     VARCHAR(10)  NOT NULL DEFAULT '待审批' COMMENT '状态：待审批/已通过/已驳回/已撤回',
    `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '申请时间',
    PRIMARY KEY (`id`),
    KEY `idx_leave_student_status` (`student_id`, `status`),
    CONSTRAINT `fk_leave_student` FOREIGN KEY (`student_id`)
        REFERENCES `students` (`student_id`) ON DELETE CASCADE,
    CONSTRAINT `chk_leave_status`
        CHECK (`status` IN ('待审批', '已通过', '已驳回', '已撤回'))
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '请假记录表';

-- ------------------------------------------------------------
-- 5. scores 成绩表（可选；保留给已有的“成绩页”，新需求不需要可删）
-- ------------------------------------------------------------
CREATE TABLE `scores` (
    `id`            INT          NOT NULL AUTO_INCREMENT COMMENT '主键',
    `student_id`    VARCHAR(20)  NOT NULL                COMMENT '学号',
    `course_name`   VARCHAR(100) NOT NULL                COMMENT '课程名称',
    `regular_score` DECIMAL(5,1) NOT NULL DEFAULT 0.0    COMMENT '平时成绩',
    `final_score`   DECIMAL(5,1) NOT NULL DEFAULT 0.0    COMMENT '期末成绩',
    `total_score`   DECIMAL(5,1) NOT NULL DEFAULT 0.0    COMMENT '总评成绩',
    PRIMARY KEY (`id`),
    KEY `idx_score_student` (`student_id`),
    CONSTRAINT `fk_score_student` FOREIGN KEY (`student_id`)
        REFERENCES `students` (`student_id`) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '成绩表';

-- ============================================================
-- 测试数据（密码统一 123456）
-- ============================================================

INSERT INTO `students` (`student_id`, `name`, `password`, `class_name`, `major`, `phone`) VALUES
('2023001', '张三', '123456', '计算机2301', '计算机科学与技术', '13800000001'),
('2023002', '李四', '123456', '计算机2301', '计算机科学与技术', '13800000002'),
('2023003', '王五', '123456', '软件2302',   '软件工程',         '13800000003');

-- selected_count 是“已选人数”，这里按演示需要给好初始值
INSERT INTO `courses`
(`course_name`, `teacher`, `time_slot`, `credit`, `location`, `selected_count`, `max_count`) VALUES
('高等数学',       '张老师', '周一 1-2节', 4.0, '教A101',    38, 40),
('大学英语',       '刘老师', '周二 3-4节', 3.0, '教B202',    34, 35),
('数据结构',       '陈老师', '周一 1-2节', 4.0, '实验楼301', 29, 30),
('计算机网络',     '赵老师', '周四 5-6节', 3.0, '教A203',    30, 30),
('操作系统',       '孙老师', '周五 3-4节', 3.5, '教C102',    25, 25),
('Python程序设计', '周老师', '周一 5-6节', 2.5, '实验楼202', 20, 50),
('数据库原理',     '吴老师', '周二 7-8节', 3.5, '教B301',    12, 30),
('人工智能导论',   '钱老师', '周五 7-8节', 2.0, '教A305',     5, 40);

-- 张三：高等数学（周一 1-2节）、Python程序设计（周一 5-6节）
-- 所以张三再选“数据结构”（同样是周一 1-2节）会被判为时间冲突
INSERT INTO `selections` (`student_id`, `course_id`) VALUES
('2023001', 1),
('2023001', 6),
('2023002', 2);

INSERT INTO `leaves`
(`student_id`, `leave_type`, `start_time`, `end_time`, `reason`, `status`) VALUES
('2023001', '病假', '2026-10-20 08:00:00', '2026-10-21 18:00:00', '发烧去医院就诊，需休息两天', '已通过'),
('2023001', '事假', '2026-10-28 08:00:00', '2026-10-28 18:00:00', '家中有事需要回家处理',       '待审批'),
('2023002', '事假', '2026-10-15 08:00:00', '2026-10-15 12:00:00', '上午去派出所办理身份证',     '已驳回');

INSERT INTO `scores`
(`student_id`, `course_name`, `regular_score`, `final_score`, `total_score`) VALUES
('2023001', '高等数学',       85.0, 92.0, 89.9),
('2023001', '大学英语',       78.0, 85.0, 82.9),
('2023001', '数据结构',       90.0, 88.0, 88.6),
('2023001', 'Python程序设计', 95.0, 96.0, 95.7),
('2023002', '高等数学',       70.0, 75.0, 73.5);

-- ============================================================
-- 学生管理系统 · 数据库补充脚本（在已有的 student_system 库上执行）
-- 内容：students 加 email / class_id、新建 counselors、announcements
-- 注意：ALTER TABLE 只能执行一次，重复执行会报字段已存在
-- ============================================================

USE `student_system`;

-- ------------------------------------------------------------
-- 1. students 增加邮箱 + 班级ID
--    （counselors 表按 class_id 关联，学生这边必须也有 class_id 才能查）
-- ------------------------------------------------------------
ALTER TABLE `students`
    ADD COLUMN `email`    VARCHAR(100) DEFAULT NULL COMMENT '邮箱' AFTER `phone`,
    ADD COLUMN `class_id` INT          DEFAULT NULL COMMENT '班级ID（关联 counselors.class_id）' AFTER `major`;

-- ------------------------------------------------------------
-- 2. counselors 辅导员表（一个班级一个辅导员）
-- ------------------------------------------------------------
CREATE TABLE `counselors` (
    `id`       INT          NOT NULL AUTO_INCREMENT COMMENT '主键',
    `name`     VARCHAR(50)  NOT NULL                COMMENT '姓名',
    `phone`    VARCHAR(30)  DEFAULT NULL            COMMENT '电话',
    `email`    VARCHAR(100) DEFAULT NULL            COMMENT '邮箱',
    `class_id` INT          NOT NULL                COMMENT '管理的班级ID',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_counselor_class` (`class_id`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '辅导员表';

-- ------------------------------------------------------------
-- 3. announcements 公告表
-- ------------------------------------------------------------
CREATE TABLE `announcements` (
    `id`           INT          NOT NULL AUTO_INCREMENT COMMENT '主键',
    `title`        VARCHAR(200) NOT NULL                COMMENT '标题',
    `content`      TEXT         NOT NULL                COMMENT '内容',
    `publish_date` DATE         NOT NULL                COMMENT '发布日期',
    PRIMARY KEY (`id`),
    KEY `idx_announcement_date` (`publish_date`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '公告表';

-- ------------------------------------------------------------
-- 4. 测试数据
-- ------------------------------------------------------------

-- 班级：1 = 计算机2301，2 = 软件2302
UPDATE `students` SET `class_id` = 1, `email` = 'zhangsan@stu.edu.cn' WHERE `student_id` = '2023001';
UPDATE `students` SET `class_id` = 1, `email` = 'lisi@stu.edu.cn'     WHERE `student_id` = '2023002';
UPDATE `students` SET `class_id` = 2, `email` = 'wangwu@stu.edu.cn'   WHERE `student_id` = '2023003';

INSERT INTO `counselors` (`name`, `phone`, `email`, `class_id`) VALUES
('李老师', '13900000001', 'li@school.edu.cn',   1),
('王老师', '13900000002', 'wang@school.edu.cn', 2);

INSERT INTO `announcements` (`title`, `content`, `publish_date`) VALUES
('关于 2026 年秋季学期期中考试安排的通知',
 '期中考试定于第 10 周（11 月 9 日—11 月 13 日）进行，请各位同学登录教务系统查询具体考场与座位号，并于开考前 15 分钟到达考场。考试期间严禁携带手机等电子设备进入考场，一经发现按违纪处理。',
 '2026-10-28'),
('关于开展本学期学生评教工作的通知',
 '评教系统已开放，请于 11 月 15 日前完成网上评教。评教采用匿名方式，结果仅用于改进教学，不会影响成绩。未完成评教的同学将无法查询本学期期末成绩。',
 '2026-10-20'),
('国家奖学金评审结果公示',
 '2025—2026 学年国家奖学金评审结果已在学院公告栏公示，公示期 5 个工作日。如对结果有异议，请在公示期内向辅导员提交书面材料。',
 '2026-10-12'),
('图书馆自习室延长开放时间',
 '自本周起，图书馆三楼自习室开放时间调整为 07:30—23:00。请同学们保持安静、按时离馆，离开时带走个人物品。',
 '2026-10-08');

-- ------------------------------------------------------------
-- 5. 自查
-- ------------------------------------------------------------
SELECT s.student_id, s.name, s.class_name, s.class_id, s.email,
       c.name AS counselor, c.phone, c.email AS counselor_email
FROM `students` s
LEFT JOIN `counselors` c ON c.class_id = s.class_id
ORDER BY s.student_id;

-- ============================================================
-- 自查
-- ============================================================
SELECT 'students'   AS 表名, COUNT(*) AS 行数 FROM `students`
UNION ALL SELECT 'courses',    COUNT(*) FROM `courses`
UNION ALL SELECT 'selections', COUNT(*) FROM `selections`
UNION ALL SELECT 'leaves',     COUNT(*) FROM `leaves`
UNION ALL SELECT 'scores',     COUNT(*) FROM `scores`;