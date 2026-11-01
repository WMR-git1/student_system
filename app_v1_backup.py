# -*- coding: utf-8 -*-
"""
极简版学生管理系统 —— Flask 后端（app.py）
技术栈：Python 3 + Flask + PyMySQL + MySQL 8.0 + Jinja2 + Bootstrap 5(CDN)

运行步骤：
    1. 执行 student_system.sql 建库建表
    2. 把下面 DB_CONFIG["password"] 改成你自己的 MySQL 密码
    3. pip install flask pymysql
    4. python app.py  ->  浏览器打开 http://127.0.0.1:5000
"""
from functools import wraps

import pymysql
from flask import (Flask, flash, redirect, render_template, request, session,
                   url_for)

app = Flask(__name__)
# session 加密密钥，自己随便改一串字符
app.secret_key = "student-system-secret-key-2026"

# ==================== 1. 数据库配置：只改这里 ====================
DB_CONFIG = {
    "host": "127.0.0.1",       # MySQL 地址
    "port": 3306,              # MySQL 端口
    "user": "root",            # MySQL 用户名
    "password": "root",      # ★★★ 改成你自己的 MySQL 密码 ★★★
    "database": "student_system",
    "charset": "utf8mb4",
    "cursorclass": pymysql.cursors.DictCursor,   # 查询结果自动变成字典
}


# ==================== 2. 数据库工具函数 ====================
def get_conn():
    """建立一个数据库连接"""
    return pymysql.connect(**DB_CONFIG)


def query_all(sql, args=None):
    """查询多行，返回 list[dict]"""
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(sql, args or ())
            return cur.fetchall()
    finally:
        conn.close()


def query_one(sql, args=None):
    """查询一行，返回 dict 或 None"""
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(sql, args or ())
            return cur.fetchone()
    finally:
        conn.close()


def execute(sql, args=None):
    """执行增删改，自动提交"""
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(sql, args or ())
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def login_required(view_func):
    """未登录时跳回登录页的装饰器"""
    @wraps(view_func)
    def wrapper(*args, **kwargs):
        if not session.get("username"):
            flash("请先登录", "warning")
            return redirect(url_for("login"))
        return view_func(*args, **kwargs)
    return wrapper


# ==================== 3. 登录 / 退出 ====================
@app.route("/")
@login_required
def home():
    """框架页：左侧菜单 + 顶部栏 + iframe 内容区"""
    return render_template("base.html")


@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        username = request.form.get("username", "").strip()
        password = request.form.get("password", "").strip()

        # 教学演示用明文密码；真实项目请存哈希值（werkzeug 的 generate_password_hash）
        user = query_one(
            "SELECT id, username, role FROM `user` "
            "WHERE username = %s AND password = %s",
            (username, password),
        )
        if user is None:
            flash("账号或密码错误，请重新输入", "danger")
            return render_template("login.html")

        session["username"] = user["username"]
        session["role"] = user["role"]
        # 约定：学生账号就是学号；管理员没有学号
        session["student_id"] = user["username"] if user["role"] == "学生" else ""
        flash("登录成功，欢迎你，%s！" % user["username"], "success")
        return redirect(url_for("home"))

    if session.get("username"):
        return redirect(url_for("home"))
    return render_template("login.html")


@app.route("/logout")
def logout():
    session.clear()
    flash("你已安全退出登录", "info")
    return redirect(url_for("login"))


# ==================== 4. 个人档案 ====================
@app.route("/index")
@login_required
def index():
    # 管理员：查看全部学生档案
    if session.get("role") == "管理员":
        students = query_all("SELECT * FROM student ORDER BY student_id")
        return render_template("index.html", students=students, student=None)

    # 学生：只看自己的档案
    student = query_one(
        "SELECT * FROM student WHERE student_id = %s",
        (session.get("student_id"),),
    )
    return render_template("index.html", student=student, students=[])


# ==================== 5. 课表 ====================
DAYS = ["周一", "周二", "周三", "周四", "周五"]
SLOTS = ["第1-2节", "第3-4节", "第5-6节", "第7-8节", "第9-10节"]


@app.route("/schedule")
@login_required
def schedule():
    courses = query_all("SELECT * FROM course ORDER BY day_of_week, time_slot")
    # 把课程按 “周一|第1-2节” 的格式塞进字典，模板里直接取
    grid = {}
    for c in courses:
        grid["%s|%s" % (c["day_of_week"], c["time_slot"])] = c
    return render_template("schedule.html", courses=courses, grid=grid,
                           days=DAYS, slots=SLOTS)


# ==================== 6. 成绩 ====================
@app.route("/score")
@login_required
def score():
    if session.get("role") == "管理员":
        scores = query_all("SELECT * FROM score ORDER BY student_id, id")
    else:
        scores = query_all(
            "SELECT * FROM score WHERE student_id = %s ORDER BY id",
            (session.get("student_id"),),
        )
    avg = round(sum(float(s["total_score"]) for s in scores) / len(scores), 1) if scores else 0
    return render_template("score.html", scores=scores, avg=avg)


# ==================== 7. 选课 ====================
def do_selection(student_id, course_id):
    """选课事务：校验重复 -> 扣容量 -> 写选课记录，返回 (提示信息, 是否成功)"""
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT course_name, capacity FROM course WHERE id = %s",
                (course_id,),
            )
            course = cur.fetchone()
            if course is None:
                return "课程不存在", False

            cur.execute(
                "SELECT id FROM selection WHERE student_id = %s AND course_id = %s",
                (student_id, course_id),
            )
            if cur.fetchone():
                return "你已经选过《%s》了" % course["course_name"], False

            # 带 capacity > 0 条件的更新，同时完成“判断满员 + 扣减容量”，避免超选
            cur.execute(
                "UPDATE course SET capacity = capacity - 1 "
                "WHERE id = %s AND capacity > 0",
                (course_id,),
            )
            if cur.rowcount == 0:
                return "《%s》已满员，换一门吧" % course["course_name"], False

            cur.execute(
                "INSERT INTO selection (student_id, course_id) VALUES (%s, %s)",
                (student_id, course_id),
            )
        conn.commit()
        return "选课成功：《%s》" % course["course_name"], True
    except Exception as exc:
        conn.rollback()
        return "选课失败：%s" % exc, False
    finally:
        conn.close()


@app.route("/selection", methods=["GET", "POST"])
@login_required
def selection():
    student_id = session.get("student_id", "")

    if request.method == "POST":
        if session.get("role") != "学生":
            flash("只有学生账号才能选课", "warning")
            return redirect(url_for("selection"))

        course_id = request.form.get("course_id", type=int)
        if not course_id:
            flash("选课参数不正确", "danger")
            return redirect(url_for("selection"))

        msg, ok = do_selection(student_id, course_id)
        flash(msg, "success" if ok else "danger")
        return redirect(url_for("selection"))

    courses = query_all("SELECT * FROM course ORDER BY id")
    my_courses = query_all(
        "SELECT c.id, c.course_name, c.teacher, c.credit, c.capacity, "
        "       c.day_of_week, c.time_slot, c.location "
        "FROM selection s JOIN course c ON s.course_id = c.id "
        "WHERE s.student_id = %s ORDER BY s.id",
        (student_id,),
    )
    selected_ids = [c["id"] for c in my_courses]
    return render_template("selection.html", courses=courses,
                           my_courses=my_courses, selected_ids=selected_ids)


# ==================== 8. 请假 ====================
@app.route("/leave", methods=["GET", "POST"])
@login_required
def leave():
    student_id = session.get("student_id", "")

    if request.method == "POST":
        if session.get("role") != "学生":
            flash("只有学生账号才能提交请假", "warning")
            return redirect(url_for("leave"))

        leave_type = request.form.get("leave_type", "").strip()
        # datetime-local 提交的格式是 2026-11-02T08:00，转成 MySQL 认识的空格
        start_time = request.form.get("start_time", "").replace("T", " ")
        end_time = request.form.get("end_time", "").replace("T", " ")
        reason = request.form.get("reason", "").strip()

        if not (leave_type and start_time and end_time and reason):
            flash("请把请假信息填写完整", "warning")
        elif start_time >= end_time:
            flash("结束时间必须晚于开始时间", "warning")
        else:
            execute(
                "INSERT INTO leave_record "
                "(student_id, leave_type, start_time, end_time, reason, status) "
                "VALUES (%s, %s, %s, %s, %s, '待审批')",
                (student_id, leave_type, start_time, end_time, reason),
            )
            flash("请假申请提交成功，当前状态：待审批", "success")
            return redirect(url_for("leave"))

    if session.get("role") == "管理员":
        records = query_all("SELECT * FROM leave_record ORDER BY id DESC")
    else:
        records = query_all(
            "SELECT * FROM leave_record WHERE student_id = %s ORDER BY id DESC",
            (student_id,),
        )
    return render_template("leave.html", records=records)


# ==================== 9. 公告 ====================
NOTICES = [
    {
        "title": "关于 2026 年秋季学期期中考试安排的通知",
        "date": "2026-10-28",
        "content": "期中考试定于第 10 周（11 月 9 日—11 月 13 日）进行，请各位同学登录教务系统查询考场安排，提前 15 分钟到达考场。",
    },
    {
        "title": "关于开展本学期学生评教工作的通知",
        "date": "2026-10-20",
        "content": "评教系统已开放，请于 11 月 15 日前完成网上评教，未完成评教将影响期末成绩查询。",
    },
    {
        "title": "国家奖学金评审结果公示",
        "date": "2026-10-12",
        "content": "2025—2026 学年国家奖学金评审结果已在学院公告栏公示，公示期 5 个工作日，如有异议请向辅导员反映。",
    },
    {
        "title": "图书馆自习室延长开放时间",
        "date": "2026-10-08",
        "content": "自本周起，图书馆三楼自习室开放时间调整为 07:30—23:00，请同学们保持安静、按时离馆。",
    },
]


@app.route("/notice")
@login_required
def notice():
    return render_template("notice.html", notices=NOTICES)


# ==================== 10. 启动 ====================
if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000, debug=True)