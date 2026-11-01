/*
 Navicat Premium Dump SQL

 Source Server         : student1
 Source Server Type    : MySQL
 Source Server Version : 80100 (8.1.0)
 Source Host           : localhost:3306
 Source Schema         : student_system

 Target Server Type    : MySQL
 Target Server Version : 80100 (8.1.0)
 File Encoding         : 65001

 Date: 01/11/2026 20:08:48
*/

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------
-- Table structure for announcements
-- ----------------------------
DROP TABLE IF EXISTS `announcements`;
CREATE TABLE `announcements`  (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '主键',
  `title` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '标题',
  `content` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '内容',
  `publish_date` date NOT NULL COMMENT '发布日期',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_announcement_date`(`publish_date` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 5 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '公告表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of announcements
-- ----------------------------
INSERT INTO `announcements` VALUES (1, '关于 2026 年秋季学期期中考试安排的通知', '期中考试定于第 10 周（11 月 9 日—11 月 13 日）进行，请各位同学登录教务系统查询具体考场与座位号，并于开考前 15 分钟到达考场。考试期间严禁携带手机等电子设备进入考场，一经发现按违纪处理。', '2026-10-28');
INSERT INTO `announcements` VALUES (2, '关于开展本学期学生评教工作的通知', '评教系统已开放，请于 11 月 15 日前完成网上评教。评教采用匿名方式，结果仅用于改进教学，不会影响成绩。未完成评教的同学将无法查询本学期期末成绩。', '2026-10-20');
INSERT INTO `announcements` VALUES (3, '国家奖学金评审结果公示', '2025—2026 学年国家奖学金评审结果已在学院公告栏公示，公示期 5 个工作日。如对结果有异议，请在公示期内向辅导员提交书面材料。', '2026-10-12');
INSERT INTO `announcements` VALUES (4, '图书馆自习室延长开放时间', '自本周起，图书馆三楼自习室开放时间调整为 07:30—23:00。请同学们保持安静、按时离馆，离开时带走个人物品。', '2026-10-08');

-- ----------------------------
-- Table structure for counselors
-- ----------------------------
DROP TABLE IF EXISTS `counselors`;
CREATE TABLE `counselors`  (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '主键',
  `name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '姓名',
  `phone` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '电话',
  `email` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '邮箱',
  `class_id` int NOT NULL COMMENT '管理的班级ID',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_counselor_class`(`class_id` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 3 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '辅导员表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of counselors
-- ----------------------------
INSERT INTO `counselors` VALUES (1, '李老师', '13900000001', 'li@school.edu.cn', 1);
INSERT INTO `counselors` VALUES (2, '王老师', '13900000002', 'wang@school.edu.cn', 2);

-- ----------------------------
-- Table structure for courses
-- ----------------------------
DROP TABLE IF EXISTS `courses`;
CREATE TABLE `courses`  (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '课程ID',
  `course_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '课程名称',
  `teacher` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '任课教师',
  `time_slot` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '上课时间，如：周一 1-2节',
  `credit` decimal(3, 1) NOT NULL DEFAULT 2.0 COMMENT '学分',
  `location` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '上课地点',
  `selected_count` int NOT NULL DEFAULT 0 COMMENT '已选人数',
  `max_count` int NOT NULL DEFAULT 50 COMMENT '最大人数',
  PRIMARY KEY (`id`) USING BTREE,
  CONSTRAINT `chk_courses_count` CHECK ((`selected_count` >= 0) and (`max_count` > 0))
) ENGINE = InnoDB AUTO_INCREMENT = 9 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '课程表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of courses
-- ----------------------------
INSERT INTO `courses` VALUES (1, '高等数学', '张老师', '周一 1-2节', 4.0, '教A101', 38, 40);
INSERT INTO `courses` VALUES (2, '大学英语', '刘老师', '周二 3-4节', 3.0, '教B202', 34, 35);
INSERT INTO `courses` VALUES (3, '数据结构', '陈老师', '周一 1-2节', 4.0, '实验楼301', 29, 30);
INSERT INTO `courses` VALUES (4, '计算机网络', '赵老师', '周四 5-6节', 3.0, '教A203', 30, 30);
INSERT INTO `courses` VALUES (5, '操作系统', '孙老师', '周五 3-4节', 3.5, '教C102', 25, 25);
INSERT INTO `courses` VALUES (6, 'Python程序设计', '周老师', '周一 5-6节', 2.5, '实验楼202', 20, 50);
INSERT INTO `courses` VALUES (7, '数据库原理', '吴老师', '周二 7-8节', 3.5, '教B301', 12, 30);
INSERT INTO `courses` VALUES (8, '人工智能导论', '钱老师', '周五 7-8节', 2.0, '教A305', 5, 40);

-- ----------------------------
-- Table structure for evaluations
-- ----------------------------
DROP TABLE IF EXISTS `evaluations`;
CREATE TABLE `evaluations`  (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '主键',
  `student_id` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '学号',
  `course_id` int NOT NULL COMMENT '课程ID',
  `teacher_name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '教师姓名',
  `quality` tinyint NOT NULL DEFAULT 5 COMMENT '教学质量（1-5）',
  `attitude` tinyint NOT NULL DEFAULT 5 COMMENT '教学态度（1-5）',
  `process` tinyint NOT NULL DEFAULT 5 COMMENT '教学过程（1-5）',
  `ability` tinyint NOT NULL DEFAULT 5 COMMENT '教学能力（1-5）',
  `effect` tinyint NOT NULL DEFAULT 5 COMMENT '教学效果（1-5）',
  `total_score` decimal(3, 1) NOT NULL DEFAULT 5.0 COMMENT '总评分',
  `comment` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL COMMENT '评价内容',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '评价时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `unique_student_course`(`student_id` ASC, `course_id` ASC) USING BTREE,
  INDEX `idx_eval_course`(`course_id` ASC) USING BTREE,
  CONSTRAINT `fk_eval_course` FOREIGN KEY (`course_id`) REFERENCES `courses` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `fk_eval_student` FOREIGN KEY (`student_id`) REFERENCES `students` (`student_id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `chk_eval_dims` CHECK ((`quality` between 1 and 5) and (`attitude` between 1 and 5) and (`process` between 1 and 5) and (`ability` between 1 and 5) and (`effect` between 1 and 5))
) ENGINE = InnoDB AUTO_INCREMENT = 30 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '教学评价表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of evaluations
-- ----------------------------
INSERT INTO `evaluations` VALUES (27, '2023001', 1, '张老师', 4, 5, 5, 5, 5, 4.8, '', '2026-11-01 18:36:42');
INSERT INTO `evaluations` VALUES (28, '2023001', 2, '刘老师', 5, 5, 5, 5, 5, 5.0, '好', '2026-11-01 18:36:56');
INSERT INTO `evaluations` VALUES (29, '2023001', 3, '陈老师', 4, 5, 5, 5, 5, 4.8, '老师很好', '2026-11-01 18:39:58');

-- ----------------------------
-- Table structure for leaves
-- ----------------------------
DROP TABLE IF EXISTS `leaves`;
CREATE TABLE `leaves`  (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '主键',
  `student_id` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '学号',
  `leave_type` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '事假' COMMENT '请假类型：病假/事假/其他',
  `start_time` datetime NOT NULL COMMENT '开始时间',
  `end_time` datetime NOT NULL COMMENT '结束时间',
  `reason` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '请假原因',
  `status` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '待审批' COMMENT '状态：待审批/已通过/已驳回/已撤回',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '申请时间',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_leave_student_status`(`student_id` ASC, `status` ASC) USING BTREE,
  CONSTRAINT `fk_leave_student` FOREIGN KEY (`student_id`) REFERENCES `students` (`student_id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `chk_leave_status` CHECK (`status` in (_utf8mb4'待审批',_utf8mb4'已通过',_utf8mb4'已驳回',_utf8mb4'已撤回'))
) ENGINE = InnoDB AUTO_INCREMENT = 5 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '请假记录表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of leaves
-- ----------------------------
INSERT INTO `leaves` VALUES (1, '2023001', '病假', '2026-10-20 08:00:00', '2026-10-21 18:00:00', '发烧去医院就诊，需休息两天', '已通过', '2026-11-01 17:51:22');
INSERT INTO `leaves` VALUES (2, '2023001', '事假', '2026-10-28 08:00:00', '2026-10-28 18:00:00', '家中有事需要回家处理', '待审批', '2026-11-01 17:51:22');
INSERT INTO `leaves` VALUES (3, '2023002', '事假', '2026-10-15 08:00:00', '2026-10-15 12:00:00', '上午去派出所办理身份证', '已驳回', '2026-11-01 17:51:22');
INSERT INTO `leaves` VALUES (4, '2023001', '病假', '2026-11-01 18:37:00', '2026-11-05 18:37:00', '生病了老师', '待审批', '2026-11-01 18:37:55');

-- ----------------------------
-- Table structure for scores
-- ----------------------------
DROP TABLE IF EXISTS `scores`;
CREATE TABLE `scores`  (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '主键',
  `student_id` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '学号',
  `course_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '课程名称',
  `regular_score` decimal(5, 1) NOT NULL DEFAULT 0.0 COMMENT '平时成绩',
  `final_score` decimal(5, 1) NOT NULL DEFAULT 0.0 COMMENT '期末成绩',
  `total_score` decimal(5, 1) NOT NULL DEFAULT 0.0 COMMENT '总评成绩',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_score_student`(`student_id` ASC) USING BTREE,
  CONSTRAINT `fk_score_student` FOREIGN KEY (`student_id`) REFERENCES `students` (`student_id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 10 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '成绩表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of scores
-- ----------------------------
INSERT INTO `scores` VALUES (1, '2023001', '高等数学', 85.0, 92.0, 89.9);
INSERT INTO `scores` VALUES (2, '2023001', '大学英语', 78.0, 85.0, 82.9);
INSERT INTO `scores` VALUES (3, '2023001', '数据结构', 90.0, 88.0, 88.6);
INSERT INTO `scores` VALUES (4, '2023001', 'Python程序设计', 95.0, 96.0, 95.7);
INSERT INTO `scores` VALUES (5, '2023002', '高等数学', 70.0, 75.0, 73.5);
INSERT INTO `scores` VALUES (6, '2023001', '操作系统', 82.0, 78.0, 79.2);
INSERT INTO `scores` VALUES (7, '2023001', '计算机网络', 76.0, 88.0, 84.4);
INSERT INTO `scores` VALUES (8, '2023001', '数据库原理', 90.0, 85.0, 86.5);
INSERT INTO `scores` VALUES (9, '2023001', '人工智能导论', 88.0, 92.0, 90.8);

-- ----------------------------
-- Table structure for selections
-- ----------------------------
DROP TABLE IF EXISTS `selections`;
CREATE TABLE `selections`  (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '主键',
  `student_id` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '学号',
  `course_id` int NOT NULL COMMENT '课程ID',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '选课时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_selection_student_course`(`student_id` ASC, `course_id` ASC) USING BTREE,
  INDEX `idx_selection_course`(`course_id` ASC) USING BTREE,
  CONSTRAINT `fk_selection_course` FOREIGN KEY (`course_id`) REFERENCES `courses` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `fk_selection_student` FOREIGN KEY (`student_id`) REFERENCES `students` (`student_id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 4 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '选课记录表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of selections
-- ----------------------------
INSERT INTO `selections` VALUES (1, '2023001', 1, '2026-11-01 17:51:22');
INSERT INTO `selections` VALUES (2, '2023001', 6, '2026-11-01 17:51:22');
INSERT INTO `selections` VALUES (3, '2023002', 2, '2026-11-01 17:51:22');

-- ----------------------------
-- Table structure for students
-- ----------------------------
DROP TABLE IF EXISTS `students`;
CREATE TABLE `students`  (
  `student_id` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '学号（登录账号）',
  `name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '姓名',
  `password` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '密码（演示用明文，生产请存哈希）',
  `class_name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '班级',
  `major` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '专业',
  `class_id` int NULL DEFAULT NULL COMMENT '班级ID（关联 counselors.class_id）',
  `phone` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '联系方式',
  `email` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '邮箱',
  `dormitory` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '宿舍号',
  `enrollment_year` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '入学年度',
  `political_status` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '政治面貌',
  `birth_date` date NULL DEFAULT NULL COMMENT '出生日期',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`student_id`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '学生表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of students
-- ----------------------------
INSERT INTO `students` VALUES ('2023001', '张三', '123456', '计算机2301', '计算机科学与技术', 1, '13800000002', 'zhangsan@stu.edu.cn', '3号楼 502', '2023', '共青团员', '2005-05-20', '2026-11-01 17:51:22');
INSERT INTO `students` VALUES ('2023002', '李四', '123456', '计算机2301', '计算机科学与技术', 1, '13800000002', 'lisi@stu.edu.cn', NULL, NULL, NULL, NULL, '2026-11-01 17:51:22');
INSERT INTO `students` VALUES ('2023003', '王五', '123456', '软件2302', '软件工程', 2, '13800000003', 'wangwu@stu.edu.cn', NULL, NULL, NULL, NULL, '2026-11-01 17:51:22');

SET FOREIGN_KEY_CHECKS = 1;
