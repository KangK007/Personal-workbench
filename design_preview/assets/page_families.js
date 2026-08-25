(function () {
  var page = document.body.dataset.page;
  var pages = {
    projects: {
      title: "项目",
      subtitle: "概览、任务、任务群、里程碑、笔记与回顾",
      main: `
        <div class="toolbar-row"><div class="segmented"><span class="active">概览</span><span>任务</span><span>任务群</span><span>里程碑</span><span>笔记与回顾</span></div></div>
        <section class="workspace-section">
          <div class="section-head"><span class="bar"></span><h2>衍射实验论文图复核</h2><span class="spacer"></span><span class="pill primary">进行中</span></div>
          <p class="muted">整理数据、复核误差来源，并形成可追溯的论文图。</p>
          <div class="progress-line"><span style="width:55%"></span></div>
        </section>
        <section class="workspace-section">
          <div class="section-head"><span class="bar"></span><h2>项目任务</h2><span class="count pill">3</span></div>
          <div class="record-list">
            <div class="record-row done"><span class="checkbox on">✓</span><div class="record-copy"><div class="record-title">整理衍射实验数据与误差记录</div><div class="record-detail">已完成 · 预计 50 分钟</div></div><span class="pill gold">证据已记录</span></div>
            <div class="record-row"><span class="checkbox"></span><div class="record-copy"><div class="record-title">校对论文图 3 的坐标轴与单位</div><div class="record-detail">待办 · 预计 35 分钟</div></div></div>
            <div class="record-row"><span class="checkbox"></span><div class="record-copy"><div class="record-title">阅读角谱传播采样条件笔记</div><div class="record-detail">待办 · 预计 25 分钟</div></div></div>
          </div>
        </section>
        <section class="workspace-section">
          <div class="section-head"><span class="bar"></span><h2>里程碑</h2></div>
          <div class="log-rail">
            <div class="rail-row done"><span class="rail-node">✓</span><div class="rail-title">验证图像坐标与矩阵索引</div><div class="rail-detail">已完成</div></div>
            <div class="rail-row current"><span class="rail-node">●</span><div class="rail-title">Validate figure axes</div><div class="rail-detail">2026-08-16 · 进行中</div></div>
            <div class="rail-row"><span class="rail-node"></span><div class="rail-title">Complete thesis figures</div><div class="rail-detail">2026-09-08 · 待完成</div></div>
          </div>
        </section>`,
      aside: `
        <div class="section-head"><span class="bar"></span><h2>事实快照</h2></div>
        <dl class="facts"><div class="fact"><dt>进度</dt><dd class="num">55%</dd></div><div class="fact"><dt>任务</dt><dd class="num">01 / 03</dd></div><div class="fact"><dt>标签</dt><dd>论文图 · 衍射</dd></div></dl>
        <div class="section-head" style="margin-top:24px"><span class="bar"></span><h2>关联笔记</h2></div>
        <div class="record-row"><div class="record-copy"><div class="record-title">角谱传播采样检查清单</div><div class="record-detail">ASM · 采样</div></div></div>`
    },
    notes: {
      title: "笔记",
      subtitle: "稳定阅读列与项目关联",
      main: `
        <div class="note-layout">
          <aside class="note-index">
            <div class="toolbar-row"><input class="input" placeholder="搜索笔记"></div>
            <div class="note-item active"><b>角谱传播采样检查清单</b><p class="muted">ASM · 采样</p></div>
            <div class="note-item"><b>Angular spectrum notes</b><p class="muted">optics</p></div>
          </aside>
          <article class="read-column">
            <h2>角谱传播采样检查清单</h2>
            <p class="muted">关联项目：衍射实验论文图复核</p>
            <h3>本轮结论</h3>
            <ul><li>记录输入面像素尺寸和单位</li><li>核对 fftshift 顺序</li><li>保存传播距离与波长</li></ul>
            <p><a href="https://example.com/analysis">关联分析脚本</a></p>
          </article>
        </div>`,
      aside: `
        <div class="section-head"><span class="bar"></span><h2>笔记事实</h2></div>
        <dl class="facts"><div class="fact"><dt>收藏</dt><dd>是</dd></div><div class="fact"><dt>标签</dt><dd>ASM · 采样</dd></div><div class="fact"><dt>项目</dt><dd>衍射实验论文图复核</dd></div></dl>
        <div class="section-head" style="margin-top:24px"><span class="bar"></span><h2>阅读路径</h2></div>
        <div class="log-rail"><div class="rail-row done"><span class="rail-node">✓</span><div class="rail-title">记录参数</div><div class="rail-detail">像素尺寸与单位</div></div><div class="rail-row current"><span class="rail-node">●</span><div class="rail-title">核对变换</div><div class="rail-detail">fftshift 顺序</div></div><div class="rail-row"><span class="rail-node"></span><div class="rail-title">保存条件</div><div class="rail-detail">传播距离与波长</div></div></div>`
    },
    behavior: {
      title: "行为",
      subtitle: "习惯追踪、国策与协议状态",
      main: `
        <div class="toolbar-row"><div class="segmented"><span class="active">习惯追踪</span><span>国策树</span><span>国策库</span><span>轮次历史</span><span>高级分析</span></div></div>
        <section class="workspace-section">
          <div class="section-head"><span class="bar"></span><h2>实验记录复核</h2><span class="spacer"></span><span class="pill primary">每日</span></div>
          <div class="matrix" aria-label="28 日完成矩阵">${Array.from({length:28}, function (_, i) { return '<span class="' + (i < 22 ? 'hit ' : '') + (i === 27 ? 'today' : '') + '"></span>'; }).join('')}</div>
        </section>
        <section class="workspace-section">
          <div class="section-head"><span class="bar"></span><h2>协议状态</h2></div>
          <div class="record-list">
            <div class="record-row"><div class="record-copy"><div class="record-title">复核一组衍射实验参数</div><div class="record-detail">CTDP · 打开实验日志并戴上耳机</div></div><span class="pill primary">已预约</span></div>
            <div class="record-row"><div class="record-copy"><div class="record-title">每日核对一个实验参数</div><div class="record-detail">RSIP · 只核对一条参数</div></div><span class="pill gold">连续 9 次</span></div>
          </div>
        </section>`,
      aside: `
        <div class="section-head"><span class="bar"></span><h2>28 日证据</h2></div>
        <div class="metric"><div class="value">22 / 28</div><div class="label">实验记录复核</div></div>
        <dl class="facts"><div class="fact"><dt>CTDP 完成</dt><dd class="num">18</dd></div><div class="fact"><dt>CTDP 失败</dt><dd class="num">02</dd></div><div class="fact"><dt>内化进度</dt><dd class="num">36%</dd></div></dl>`
    },
    growth: {
      title: "成长",
      subtitle: "XP 仅来自已有执行证据",
      main: `
        <section class="workspace-section">
          <div class="section-head"><span class="bar"></span><h2>今日 XP 证据</h2><span class="count pill gold num">50 XP</span></div>
          <div class="log-rail">
            <div class="rail-row done"><span class="rail-node">✓</span><div class="rail-title">完成承诺 1</div><div class="rail-detail">承诺 · +20 XP</div></div>
            <div class="rail-row done"><span class="rail-node">✓</span><div class="rail-title">承诺专注 45 分钟</div><div class="rail-detail">专注 · +15 XP</div></div>
            <div class="rail-row done"><span class="rail-node">✓</span><div class="rail-title">完成计分习惯</div><div class="rail-detail">习惯 · +5 XP</div></div>
            <div class="rail-row done"><span class="rail-node">✓</span><div class="rail-title">完成每日收尾</div><div class="rail-detail">回顾 · +10 XP</div></div>
          </div>
        </section>
        <section class="workspace-section"><div class="section-head"><span class="bar"></span><h2>连续记录</h2></div><div class="matrix">${Array.from({length:14}, function (_, i) { return '<span class="hit ' + (i === 13 ? 'today' : '') + '"></span>'; }).join('')}</div></section>`,
      aside: `
        <div class="section-head"><span class="bar"></span><h2>成长快照</h2></div>
        <div class="metric"><div class="value">14</div><div class="label">连续收尾天数</div></div>
        <dl class="facts"><div class="fact"><dt>今日签到</dt><dd>已完成</dd></div><div class="fact"><dt>数据位置</dt><dd>仅本机</dd></div></dl>`
    },
    restriction: {
      title: "自律",
      subtitle: "高密度规则编辑与保护状态",
      main: `
        <section class="workspace-section"><div class="section-head"><span class="bar"></span><h2>规则</h2><span class="spacer"></span><button class="btn primary sm">新增规则</button></div>
          <div class="record-list"><div class="record-row"><div class="record-copy"><div class="record-title">时段规则</div><div class="record-detail">黑名单：命中后限制 · 默认动作：提醒</div></div><span class="toggle on" aria-label="已启用"></span></div><div class="record-row"><div class="record-copy"><div class="record-title">网站拦截</div><div class="record-detail">Windows hosts</div></div><span class="pill">Windows</span></div></div>
        </section>
        <section class="workspace-section"><div class="section-head"><span class="bar"></span><h2>保护设置</h2></div>
          <div class="setting-group"><div class="setting-row"><div class="setting-copy"><b>强保护</b><p>限制时段内固定活动快照，其他设备的削弱修改待时段结束后应用</p></div><span class="toggle on"></span></div><div class="setting-row"><div class="setting-copy"><b>敏感操作冷静期</b><p>固定为 5 分钟；一次性紧急恢复码可立即执行</p></div><span class="pill danger">5 分钟</span></div><div class="setting-row"><div class="setting-copy"><b>紧急恢复码</b><p>一次性、本机保存，生成新码会替换旧码</p></div><button class="btn outline sm">生成</button></div></div>
        </section>`,
      aside: `
        <div class="section-head"><span class="bar"></span><h2>保护状态</h2></div>
        <div class="record-row warning"><div class="record-copy"><div class="record-title">Windows 后台行为</div><div class="record-detail">实际拦截仅在 Windows 端生效</div></div></div>
        <div class="section-head" style="margin-top:24px"><span class="bar"></span><h2>例外规则</h2></div>
        <div class="record-row"><div class="record-copy"><div class="record-title">仪器安全报警</div><div class="record-detail">仅在设备或人员安全相关报警出现时允许暂停。</div></div></div>`
    },
    settings: {
      title: "设置",
      subtitle: "外观、提醒、同步与本地数据管理",
      main: `
        <section class="workspace-section"><div class="section-head"><span class="bar"></span><h2>外观与导航</h2></div><div class="setting-group"><div class="setting-row"><div class="setting-copy"><b>主题</b><p>跟随系统</p></div><span class="pill">跟随系统</span></div><div class="setting-row"><div class="setting-copy"><b>默认折叠 Windows 侧栏</b><p>仅改变八栏导航宽度，不隐藏任何页面</p></div><span class="toggle on"></span></div><div class="setting-row"><div class="setting-copy"><b>个人别名</b></div><button class="btn outline sm">编辑</button></div></div></section>
        <section class="workspace-section"><div class="section-head"><span class="bar"></span><h2>通知与后台</h2></div><div class="setting-group"><div class="setting-row"><div class="setting-copy"><b>关闭窗口时最小化到托盘</b><p>启用后请通过托盘菜单退出应用</p></div><span class="toggle on"></span></div><div class="setting-row"><div class="setting-copy"><b>任务和休息提醒</b></div><button class="btn outline sm">申请权限</button></div></div></section>
        <section class="workspace-section"><div class="section-head"><span class="bar"></span><h2>数据与备份</h2></div><div class="setting-group"><div class="setting-row"><div class="setting-copy"><b>创建加密备份</b><p>保存全部本地内容，密码至少 8 个字符</p></div><button class="btn outline sm">备份</button></div><div class="setting-row"><div class="setting-copy"><b>导出 JSON</b><p>生成可读取的完整数据副本</p></div><button class="btn outline sm">导出</button></div><div class="setting-row"><div class="setting-copy"><b>导入文件</b><p>支持 JSON、CSV、Markdown 和 TXT</p></div><button class="btn outline sm">导入</button></div></div></section>`,
      aside: `
        <div class="section-head"><span class="bar"></span><h2>账号与同步</h2></div><div class="record-row"><div class="record-copy"><div class="record-title">当前为纯本地模式</div><div class="record-detail">配置 Supabase 环境参数后可启用跨端同步</div></div></div>
        <div class="section-head" style="margin-top:24px"><span class="bar"></span><h2>回收站（1）</h2></div><div class="record-row warning"><div class="record-copy"><div class="record-title">Deleted note</div><div class="record-detail">永久删除后无法恢复</div></div><button class="btn danger sm">永久删除</button></div>`
    }
  };

  var current = pages[page];
  if (!current) return;
  var nav = [
    ["today.html", "今日", "today"], ["tasks.html", "任务", "tasks"],
    ["projects.html", "项目", "projects"], ["notes.html", "笔记", "notes"],
    ["focus.html", "专注", "focus"], ["review.html", "回顾", "review"],
    ["behavior.html", "行为", "behavior"], ["growth.html", "成长", "growth"],
    ["restriction.html", "自律", "restriction"], ["settings.html", "设置", "settings"]
  ];
  var navItems = nav.map(function (item) {
    return '<a class="nav-item ' + (item[2] === page ? 'active' : '') + '" href="' + item[0] + '"><span>' + item[1] + '</span></a>';
  }).join("");
  document.body.innerHTML = `
    <header class="preview-bar"><div class="brand"><span class="dot"></span>个人航行日志</div><nav><a href="index.html">设计令牌</a><a href="today.html">今日</a><a href="projects.html">项目</a><a href="notes.html">笔记</a><a href="behavior.html">行为</a><a href="growth.html">成长</a><a href="restriction.html">自律</a><a href="settings.html">设置</a><a href="mobile.html">移动端</a><a href="components.html">组件</a></nav><button class="theme-toggle" onclick="toggleTheme()"><span class="label">切换暗色</span></button></header>
    <div class="shell family-shell">
      <aside class="sidebar"><div class="logo-row"><div class="logo"></div><div class="name">个人工作台</div></div><div style="padding:12px 10px"><button class="btn primary" style="width:100%">快速新增</button></div><nav class="nav"><div class="nav-group">工作索引</div>${navItems}</nav><div class="record-detail" style="padding:12px 14px;border-top:1px solid var(--divider)">纯本地模式</div></aside>
      <main class="main family-main"><div class="page-header"><span class="accent-bar"></span><div><h1>${current.title}</h1><div class="sub">${current.subtitle}</div></div><span class="spacer"></span><button class="btn ghost">搜索</button><button class="btn primary">新增</button></div><div class="family-grid"><div class="work-column">${current.main}</div><aside class="evidence-rail">${current.aside}</aside></div></main>
    </div>
    <nav class="mobile-bottom"><a href="today.html">今日</a><a href="tasks.html">任务</a><a href="review.html">回顾</a><a class="${page === 'behavior' ? 'active' : ''}" href="behavior.html">行为</a><a class="${page === 'settings' ? 'active' : ''}" href="settings.html">设置</a></nav>`;
})();
