# -*- coding: utf-8 -*-
"""
学生管理系统 · 完整后端（MySQL + Flask）
在第一版基础上完善：
    1. 数据库改为 students / courses / selections / leaves / scores，去掉管理员角色
    2. 选课增加“时间冲突检测”，页面表单与 JSON 接口共用同一套逻辑
    3. 请假增加“撤回”，只允许撤回自己“待审批”的记录
    4. 页面仍然用 render_template 渲染，两个 JSON 接口给前端 fetch 用
"""
import re
from decimal import Decimal, ROUND_HALF_UP
from functools import wraps

import pymysql
from flask import (Flask, flash, g, jsonify, redirect, render_template,
                   request, session, url_for)

app = Flask(__name__)
# session 加密密钥，自己随便改一串字符
app.secret_key = "student-system-secret-key-2026"

# ==================== 1. 数据库配置：只改这里 ====================
DB_CONFIG = {
    "host": "127.0.0.1",       # MySQL 地址
    "port": 3306,              # MySQL 端口
    "user": "root",            # MySQL 用户名
    "password": "root",        # ★★★ 改成你自己的 MySQL 密码 ★★★
    "database": "student_system",
    "charset": "utf8mb4",
    "cursorclass": pymysql.cursors.DictCursor,   # 查询结果自动变成字典
    "autocommit": True,        # 写操作在下面显式 begin() / commit()
}


# ==================== 2. 数据库连接 ====================
def get_db():
    """取当前请求的数据库连接（请求结束自动关闭）"""
    if "db" not in g:
        g.db = pymysql.connect(**DB_CONFIG)
    return g.db


@app.teardown_appcontext
def close_db(exception=None):
    db = g.pop("db", None)
    if db is not None:
        db.close()


def query_one(sql, args=None):
    with get_db().cursor() as cur:
        cur.execute(sql, args or ())
        return cur.fetchone()


def query_all(sql, args=None):
    with get_db().cursor() as cur:
        cur.execute(sql, args or ())
        return cur.fetchall()


# ==================== 3. 登录校验 ====================
def login_required(view_func):
    """页面版：未登录跳回登录页"""
    @wraps(view_func)
    def wrapper(*args, **kwargs):
        if not session.get("student_id"):
            flash("请先登录", "warning")
            return redirect(url_for("login"))
        return view_func(*args, **kwargs)
    return wrapper


def json_login_required(view_func):
    """接口版：未登录返回 401 JSON"""
    @wraps(view_func)
    def wrapper(*args, **kwargs):
        if not session.get("student_id"):
            return jsonify(success=False, message="请先登录"), 401
        return view_func(*args, **kwargs)
    return wrapper


# ==================== 4. 上课时间解析与冲突判断 ====================
# 支持 '周一 1-2节'、'周一第1-2节'、'周一 1~2节'、'星期1 3-4节' 等写法
_TIME_PATTERN = re.compile(r"^(?:周|星期)\s*([一二三四五六日天1-7])\s*第?\s*(\d+)\s*[-—~至到]\s*(\d+)")
_DAY_ALIAS = {"1": "一", "2": "二", "3": "三", "4": "四", "5": "五", "6": "六", "7": "日"}


def parse_time_slot(text):
    """'周一 1-2节' -> ('一', 1, 2)；解析不了返回 None"""
    if not text:
        return None
    m = _TIME_PATTERN.match(str(text).strip().replace(" ", ""))
    if not m:
        return None
    day = m.group(1)
    day = _DAY_ALIAS.get(day, day).replace("天", "日")
    start, end = int(m.group(2)), int(m.group(3))
    if start > end:
        start, end = end, start
    return day, start, end


def time_conflict(slot_a, slot_b):
    """两个上课时间是否冲突：同一天，且节次区间有交集"""
    a, b = parse_time_slot(slot_a), parse_time_slot(slot_b)
    if a is None or b is None:
        # 解析不了就退化成字符串比较，保证不会漏判
        return (slot_a or "").strip() == (slot_b or "").strip()
    if a[0] != b[0]:
        return False
    return not (a[2] < b[1] or b[2] < a[1])


def _payload():
    """兼容 JSON 和表单两种提交方式"""
    return request.get_json(silent=True) or request.form or request.args


class _CourseFullError(Exception):
    """并发下课程被别人抢满时抛出的内部异常"""


# ==================== 5. 选课核心逻辑 ====================
def do_select_course(student_id, course_id):
    """
    选课：存在性 -> 重复 -> 满员 -> 时间冲突 -> 事务写库
    返回 dict：{success, message, status, ...}
    """
    course = query_one("SELECT * FROM courses WHERE id = %s", (course_id,))
    if course is None:
        return {"success": False, "message": "课程不存在", "status": 404}

    # 是否重复选课
    if query_one(
        "SELECT 1 FROM selections WHERE student_id = %s AND course_id = %s",
        (student_id, course_id),
    ):
        return {"success": False, "message": "选课失败：您已经选过这门课程", "status": 200}

    # 人数是否已满
    if course["selected_count"] >= course["max_count"]:
        return {"success": False, "message": "选课失败：该课程人数已满", "status": 200}

    # 时间冲突检测：当前学生已选课程的全部上课时间
    my_courses = query_all(
        "SELECT c.course_name, c.time_slot "
        "FROM selections s JOIN courses c ON c.id = s.course_id "
        "WHERE s.student_id = %s",
        (student_id,),
    )
    for row in my_courses:
        if time_conflict(course["time_slot"], row["time_slot"]):
            return {
                "success": False,
                "message": "选课失败：与您已选的课程时间冲突",
                "status": 200,
                "conflict_course": row["course_name"],
                "conflict_time": row["time_slot"],
            }

    # 事务：插入选课记录 + 已选人数 +1
    conn = get_db()
    try:
        conn.begin()
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO selections (student_id, course_id) VALUES (%s, %s)",
                (student_id, course_id),
            )
            cur.execute(
                "UPDATE courses SET selected_count = selected_count + 1 "
                "WHERE id = %s AND selected_count < max_count",
                (course_id,),
            )
            if cur.rowcount == 0:          # 并发下被别人抢满了
                raise _CourseFullError()
        conn.commit()
    except _CourseFullError:
        conn.rollback()
        return {"success": False, "message": "选课失败：该课程人数已满", "status": 200}
    except pymysql.err.IntegrityError:
        conn.rollback()
        return {"success": False, "message": "选课失败：您已经选过这门课程", "status": 200}

    return {
        "success": True,
        "message": "选课成功：%s" % course["course_name"],
        "status": 200,
        "course_id": course_id,
        "selected_count": course["selected_count"] + 1,
        "max_count": course["max_count"],
    }


# ==================== 6. 请假撤回核心逻辑 ====================
def do_cancel_leave(student_id, leave_id):
    """撤回请假：属于本人 + 状态为待审批，返回 dict 同 do_select_course"""
    record = query_one("SELECT * FROM leaves WHERE id = %s", (leave_id,))
    if record is None:
        return {"success": False, "message": "请假记录不存在", "status": 404}

    if record["student_id"] != student_id:
        return {"success": False, "message": "无权操作他人的请假记录", "status": 403}

    if record["status"] != "待审批":
        return {
            "success": False,
            "message": "只能撤回【待审批】的请假，当前状态：%s" % record["status"],
            "status": 200,
        }

    conn = get_db()
    try:
        conn.begin()
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE leaves SET status = '已撤回' "
                "WHERE id = %s AND student_id = %s AND status = '待审批'",
                (leave_id, student_id),
            )
            affected = cur.rowcount
        conn.commit()
    except pymysql.MySQLError:
        conn.rollback()
        return {"success": False, "message": "撤回失败，请稍后重试", "status": 500}

    if affected == 0:
        return {"success": False, "message": "撤回失败：记录状态已变更，请刷新后重试", "status": 200}

    return {
        "success": True,
        "message": "请假已撤回",
        "status": 200,
        "leave_id": leave_id,
        "leave_status": "已撤回",
    }


# ==================== 7. 框架页 / 登录 / 退出 ====================
@app.route("/")
@login_required
def home():
    """框架页：左侧菜单 + 顶栏 + iframe 内容区"""
    return render_template("base.html")


@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        student_id = (request.form.get("student_id")
                      or request.form.get("username") or "").strip()
        password = request.form.get("password", "").strip()

        # 教学演示用明文密码；真实项目请存哈希值
        row = query_one(
            "SELECT * FROM students WHERE student_id = %s AND password = %s",
            (student_id, password),
        )
        if row is None:
            flash("学号或密码错误，请重新输入", "danger")
            return render_template("login.html")

        session.clear()
        session["student_id"] = row["student_id"]
        session["name"] = row["name"]
        flash("登录成功，欢迎你，%s！" % row["name"], "success")
        return redirect(url_for("home"))

    if session.get("student_id"):
        return redirect(url_for("home"))
    return render_template("login.html")


@app.route("/logout")
def logout():
    session.clear()
    flash("你已安全退出登录", "info")
    return redirect(url_for("login"))


# ==================== 8. 个人档案 ====================
@app.route("/index")
@login_required
def index():
    # LEFT JOIN 辅导员：即使班级还没配辅导员，学生本人的信息依然能显示
    student = query_one(
        "SELECT s.*, c.name AS counselor_name, c.phone AS counselor_phone "
        "FROM students s "
        "LEFT JOIN counselors c ON c.class_id = s.class_id "
        "WHERE s.student_id = %s",
        (session["student_id"],),
    )
    return render_template("index.html", student=student)


@app.post("/profile/update")
@login_required
def update_profile():
    """更新个人信息：邮箱 + 联系方式（JSON 接口；不带 JSON 时兼容普通表单提交）"""
    payload = request.get_json(silent=True) or request.form
    email = (payload.get("email") or "").strip()
    phone = (payload.get("phone") or "").strip()

    error = None
    if len(email) > 100:
        error = "邮箱长度不能超过 100 个字符"
    elif email and not re.match(r"^[^@\s]+@[^@\s]+\.[^@\s]+$", email):
        error = "邮箱格式不正确，请检查后重新输入"
    elif len(phone) > 30:
        error = "联系方式长度不能超过 30 个字符"
    elif phone and not re.match(r"^[0-9+\-\s]{6,30}$", phone):
        error = "联系方式格式不正确，只能包含数字、空格、+ 和 -"

    if error:
        if request.is_json:
            return jsonify(status="error", message=error), 400
        flash(error, "warning")
        return redirect(url_for("index"))

    conn = get_db()
    with conn.cursor() as cur:
        cur.execute(
            "UPDATE students SET email = %s, phone = %s WHERE student_id = %s",
            (email or None, phone or None, session["student_id"]),
        )

    if request.is_json:
        return jsonify(
            status="success",
            message="修改成功",
            data={"email": email or None, "phone": phone or None},
        )

    flash("个人信息已更新", "success")
    return redirect(url_for("index"))


# ==================== 9. 课表 ====================
DAYS = ["周一", "周二", "周三", "周四", "周五"]
SLOTS = ["第1-2节", "第3-4节", "第5-6节", "第7-8节", "第9-10节"]


@app.route("/schedule")
@login_required
def schedule():
    courses = query_all("SELECT * FROM courses ORDER BY id")

    # 把 "周一 1-2节" 解析成 (周一, 第1-2节) 放进网格
    grid = {}
    for c in courses:
        parsed = parse_time_slot(c["time_slot"])
        if parsed is None:
            continue
        day, start, end = parsed
        day_label = "周" + day
        for slot in SLOTS:
            m = re.match(r"第(\d+)-(\d+)节", slot)
            s, e = int(m.group(1)), int(m.group(2))
            if not (end < s or e < start):
                grid.setdefault("%s|%s" % (day_label, slot), []).append(c)

    return render_template("schedule.html", courses=courses, grid=grid,
                           days=DAYS, slots=SLOTS)


# ==================== 10. 成绩 ====================
@app.route("/score")
@login_required
def score():
    scores = query_all(
        "SELECT * FROM scores WHERE student_id = %s ORDER BY id",
        (session["student_id"],),
    )
    # 平均分交给 MySQL 算，避免 Python 的银行家舍入和 SQL 的四舍五入对不上
    summary = query_one(
        "SELECT COUNT(*) AS cnt, ROUND(AVG(total_score), 1) AS avg_score "
        "FROM scores WHERE student_id = %s",
        (session["student_id"],),
    )
    avg = float(summary["avg_score"]) if summary and summary["avg_score"] is not None else 0
    return render_template("score.html", scores=scores, avg=avg)


# ==================== 教学评价 ====================
@app.route("/evaluation")
@login_required
def evaluation():
    """列出全部课程（即全部任课教师），并带上当前学生的评教记录"""
    courses = query_all(
        "SELECT c.id AS course_id, c.course_name, c.teacher, "
        "       e.id AS eval_id, e.quality, e.attitude, e.process, "
        "       e.ability, e.effect, e.total_score, e.comment, e.create_time "
        "FROM courses c "
        "LEFT JOIN evaluations e "
        "       ON e.course_id = c.id AND e.student_id = %s "
        "ORDER BY c.id",
        (session["student_id"],),
    )
    return render_template("evaluation.html", courses=courses)


@app.route("/evaluation/form/<int:course_id>")
@login_required
def evaluation_form(course_id):
    """评教表单页：带出课程信息 + 该生已有的评价（有则只读展示）"""
    course = query_one(
        "SELECT id, course_name, teacher FROM courses WHERE id = %s",
        (course_id,),
    )
    if course is None:
        flash("课程不存在", "warning")
        return redirect(url_for("evaluation"))

    record = query_one(
        "SELECT * FROM evaluations WHERE student_id = %s AND course_id = %s",
        (session["student_id"], course_id),
    )
    return render_template(
        "evaluation_form.html",
        record=record,
        course_id=course["id"],
        course_name=course["course_name"],
        teacher=course["teacher"],
    )


# ==================== 11. 选课 ====================
@app.route("/selection", methods=["GET", "POST"])
@login_required
def selection():
    student_id = session["student_id"]

    if request.method == "POST":
        course_id = request.form.get("course_id", type=int)
        if not course_id:
            flash("选课参数不正确", "danger")
            return redirect(url_for("selection"))

        result = do_select_course(student_id, course_id)
        message = result["message"]
        if result.get("conflict_course"):
            message += "（冲突课程：%s %s）" % (result["conflict_course"], result["conflict_time"])
        flash(message, "success" if result["success"] else "danger")
        return redirect(url_for("selection"))

    courses = query_all("SELECT * FROM courses ORDER BY id")
    my_courses = query_all(
        "SELECT c.id, c.course_name, c.teacher, c.credit, c.time_slot, c.location "
        "FROM selections s JOIN courses c ON c.id = s.course_id "
        "WHERE s.student_id = %s ORDER BY s.id",
        (student_id,),
    )
    selected_ids = [c["id"] for c in my_courses]
    return render_template("selection.html", courses=courses,
                           my_courses=my_courses, selected_ids=selected_ids)


# ==================== 12. 请假 ====================
@app.route("/leave", methods=["GET", "POST"])
@login_required
def leave():
    student_id = session["student_id"]

    if request.method == "POST":
        leave_type = request.form.get("leave_type", "").strip()
        # datetime-local 提交的是 2026-11-02T08:00，转成 MySQL 的格式
        start_time = request.form.get("start_time", "").replace("T", " ").strip()
        end_time = request.form.get("end_time", "").replace("T", " ").strip()
        reason = request.form.get("reason", "").strip()

        if not (leave_type and start_time and end_time and reason):
            flash("请把请假信息填写完整", "warning")
        elif start_time >= end_time:
            flash("结束时间必须晚于开始时间", "warning")
        else:
            conn = get_db()
            with conn.cursor() as cur:
                cur.execute(
                    "INSERT INTO leaves "
                    "(student_id, leave_type, start_time, end_time, reason, status) "
                    "VALUES (%s, %s, %s, %s, %s, '待审批')",
                    (student_id, leave_type, start_time, end_time, reason),
                )
            flash("请假申请提交成功，当前状态：待审批", "success")
            return redirect(url_for("leave"))

    records = query_all(
        "SELECT * FROM leaves WHERE student_id = %s ORDER BY id DESC",
        (student_id,),
    )
    return render_template("leave.html", records=records)


# ==================== 13. 公告 ====================
@app.route("/notice")
@login_required
def notice():
    announcements = query_all(
        "SELECT id, title, content, publish_date FROM announcements "
        "ORDER BY publish_date DESC, id DESC"
    )
    return render_template("notice.html", notices=announcements)


@app.route("/notice_detail/<int:id>")
@login_required
def notice_detail(id):
    announcement = query_one(
        "SELECT id, title, content, publish_date FROM announcements WHERE id = %s",
        (id,),
    )
    if announcement is None:
        flash("公告不存在或已被删除", "warning")
        return redirect(url_for("notice"))
    return render_template("notice_detail.html", notice=announcement)


# ==================== 14. JSON 接口 ====================
@app.post("/api/select_course")
@json_login_required
def api_select_course():
    try:
        course_id = int(_payload().get("course_id"))
    except (TypeError, ValueError):
        return jsonify(success=False, message="参数错误：course_id 必须是整数"), 400

    result = do_select_course(session["student_id"], course_id)
    status = result.pop("status", 200)
    return jsonify(result), status


@app.route("/api/cancel_leave", methods=["POST", "GET"])
@json_login_required
def api_cancel_leave():
    try:
        leave_id = int(_payload().get("leave_id"))
    except (TypeError, ValueError):
        return jsonify(success=False, message="参数错误：leave_id 必须是整数"), 400

    result = do_cancel_leave(session["student_id"], leave_id)
    status = result.pop("status", 200)
    return jsonify(result), status



# 获取辅导员信息：POST /api/get_counselor
# 说明：登录页「忘记密码」也要用它，所以不要求登录；只返回辅导员的联系方式
@app.post("/api/get_counselor")
def api_get_counselor():
    """按学号查所在班级的辅导员：姓名、电话、邮箱"""
    student_id = str(_payload().get("student_id")
                     or session.get("student_id") or "").strip()
    if not student_id:
        return jsonify(success=False, message="参数错误：缺少 student_id"), 400

    row = query_one(
        "SELECT s.student_id, s.name AS student_name, s.class_id, "
        "       c.name AS counselor_name, c.phone, c.email "
        "FROM students s "
        "LEFT JOIN counselors c ON c.class_id = s.class_id "
        "WHERE s.student_id = %s",
        (student_id,),
    )
    if row is None:
        return jsonify(success=False, message="学生不存在"), 404
    if not row["counselor_name"]:
        return jsonify(success=False, message="该学生所在班级暂未分配辅导员"), 404

    return jsonify(
        success=True,
        message="查询成功",
        student_id=row["student_id"],
        student_name=row["student_name"],
        class_id=row["class_id"],
        name=row["counselor_name"],
        phone=row["phone"],
        email=row["email"],
    )

@app.post("/api/submit_evaluation")
@json_login_required
def api_submit_evaluation():
    """提交教学评价：只能评自己选过的课，同一门课只能评一次"""
    payload = _payload()
    dims = ("quality", "attitude", "process", "ability", "effect")
    try:
        course_id = int(payload.get("course_id"))
        scores = {dim: int(payload.get(dim)) for dim in dims}
    except (TypeError, ValueError):
        return jsonify(success=False, message="参数错误：course_id 和五项评分必须是整数"), 400

    for dim in dims:
        if not 1 <= scores[dim] <= 5:
            return jsonify(success=False, message="每项评分必须是 1~5 分"), 400

    comment = (payload.get("comment") or "").strip()
    if len(comment) > 1000:
        return jsonify(success=False, message="评价内容不能超过 1000 字"), 400

    student_id = session["student_id"]

    # 课程必须存在（评教覆盖全部课程，不要求学生先选课）
    course = query_one(
        "SELECT course_name, teacher FROM courses WHERE id = %s",
        (course_id,),
    )
    if course is None:
        return jsonify(success=False, message="课程不存在"), 404

    # 总评分 = 五项平均，保留一位小数（用 Decimal，避免 4.2 变成 4.19999）
    total = (Decimal(sum(scores.values())) / Decimal(len(dims))).quantize(
        Decimal("0.1"), rounding=ROUND_HALF_UP
    )

    conn = get_db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO evaluations "
                "(student_id, course_id, teacher_name, quality, attitude, process, "
                " ability, effect, total_score, comment) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (student_id, course_id, course["teacher"],
                 scores["quality"], scores["attitude"], scores["process"],
                 scores["ability"], scores["effect"], total, comment),
            )
    except pymysql.err.IntegrityError:
        return jsonify(success=False, message="您已经评价过这门课程了"), 409

    return jsonify(success=True, message="评价提交成功", total_score=float(total))


# ==================== 15. 启动 ====================
if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000, debug=True)
