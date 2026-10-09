const options = new URLSearchParams(window.location.search);
const theme = ['green', 'night', 'sun'].includes(options.get('theme'))
  ? options.get('theme')
  : 'green';
const screen = ['today', 'projects', 'mobile'].includes(options.get('screen'))
  ? options.get('screen')
  : 'today';
document.documentElement.classList.add(`theme-${theme}`);
document.body.classList.add(`screen-${screen}`);

const icon = (name, className = '') =>
  `<svg class="icon ${className}" aria-hidden="true"><use href="#i-${name}"></use></svg>`;
const art = (type, className = '') =>
  `<img class="illustration ${className}" src="assets/${theme}/${type}.png" alt="" decoding="async">`;

const nav = [
  ['calendar', '今日', 'today'],
  ['list', '计划', 'plan'],
  ['folder', '项目', 'projects'],
  ['book', '记录', 'notes'],
  ['timer', '执行', 'focus'],
  ['growth', '成长', 'growth'],
];

function sidebar(selected) {
  return `<aside class="sidebar" aria-label="主导航">
    <div class="brand">
      <span class="brand-mark">${icon('sprout')}</span>
      <span class="brand-name">个人工作台<small>让每一步都有回声</small></span>
    </div>
    <div class="sidebar-actions">
      <button class="primary-button capture-button">${icon('plus')}<span>快速新增</span></button>
      <button class="search-button">${icon('search')}<span>全局搜索</span><kbd>⌘ K</kbd></button>
    </div>
    <div class="nav-label">工作空间</div>
    <nav class="side-links">${nav.map(([glyph, label, key]) =>
      `<a href="${key === 'today' || key === 'projects' ? `?theme=${theme}&screen=${key}` : '#'}" class="side-link ${selected === key ? 'is-active' : ''}" ${key !== 'today' && key !== 'projects' ? 'data-preview-only="true"' : ''}>${icon(glyph)}<span>${label}</span>${key === 'plan' || key === 'notes' ? icon('chevron', 'side-chevron') : ''}</a>`
    ).join('')}</nav>
    <button class="sidebar-note" data-action="capture"><span class="sidebar-note-icon">${icon('note')}</span><span class="sidebar-note-title">灵感速记 ${icon('arrow')}</span><small>把转瞬即逝的想法，留在手边。</small></button>
    <div class="sidebar-bottom">
      <div class="sync-status"><span class="sync-dot"></span>所有更改已保存</div>
      <a href="#" class="side-link settings-link">${icon('settings')}<span>设置</span></a>
    </div>
  </aside>`;
}

function topbar(title, kicker, action = '') {
  return `<header class="topbar">
    <div class="topbar-copy"><div class="kicker">${kicker}</div><h1>${title}</h1></div>
    <div class="topbar-right">${action}
      <button class="icon-button" aria-label="搜索">${icon('search')}</button>
      <span class="avatar" aria-label="个人账户">我</span>
    </div>
  </header>`;
}

function ruler() {
  const marks = Array.from({length: 12}, (_, index) =>
    `<span class="ruler-mark ${index === 5 ? 'is-current' : ''}">${String(index * 2).padStart(2, '0')}:00</span>`
  ).join('');
  return `<div class="time-ruler"><span class="ruler-sun">${icon('sun')}</span><div class="ruler-track">${marks}</div><span class="ruler-moon">${icon('moon')}</span></div>`;
}

function progressRing(value = 33) {
  return `<div class="progress-ring" style="--progress:${value}"><span>${value}%</span></div>`;
}

function task({title, meta, status, due, checked = false, secondary = ''}) {
  return `<div class="task-card ${checked ? 'is-done' : ''} ${status === '进行中' ? 'is-current' : ''}">
    <span class="task-check ${checked ? 'checked' : ''}">${checked ? icon('check') : ''}</span>
    <div class="task-copy"><div class="task-title">${title}</div><div class="task-meta">${meta}${secondary ? `<span class="meta-divider">·</span>${secondary}` : ''}</div></div>
    <span class="task-status ${checked ? 'done' : status === '进行中' ? 'active' : 'pending'}">${status}</span>
    ${due ? `<span class="task-due">${due}</span>` : ''}
    ${icon('chevron', 'task-chevron')}
  </div>`;
}

function todayDesktop() {
  return `<div class="desktop-shell">
    ${sidebar('today')}
    <main class="workspace">
      ${topbar('今日', '10月7日 · 星期三')}
      ${ruler()}
      <div class="today-grid">
        <div class="flow-column">
          <section class="daily-hero panel">
            <div class="hero-content">
              <div class="overline">今天的节奏 <span class="overline-rule"></span> 01 / 03</div>
              <h2>让想法，<br><em>稳稳向前。</em></h2>
              <p>已完成 1 件事，还有 2 件值得专注完成。</p>
              <div class="hero-stats"><span>${icon('check')}1 / 3 已完成</span><span>${icon('timer')}45 分钟专注</span><span>${icon('growth')}连续 6 天</span></div>
            </div>
            ${art('today', 'hero-art')}
            <div class="hero-progress">${progressRing(33)}</div>
          </section>

          <section class="next-card panel">
            <div class="next-label">${icon('spark')} 接下来 · 最值得推进 <span class="next-pill">专注 45 分钟</span></div>
            <div class="next-main"><div><h3>完成方案初稿</h3><p>产品体验优化 <span>·</span> 预计 45 分钟</p></div><button class="primary-button focus-button">${icon('timer')}开始专注${icon('arrow', 'button-arrow')}</button></div>
            <div class="next-progress"><span>当前进度</span><div class="mini-track"><i></i></div><strong>2 / 3 段</strong></div>
          </section>

          <section class="tasks-section">
            <div class="section-heading"><div><span class="section-index">01</span><h2>今日任务</h2><span class="section-count">3 项</span></div><a href="#">查看全部 ${icon('arrow')}</a></div>
            <div class="task-list">
              ${task({title:'整理访谈要点', meta:'产品体验优化', status:'已完成', checked:true, secondary:'今天 09:20'})}
              ${task({title:'完成方案初稿', meta:'产品体验优化', status:'进行中', due:'17:00 前'})}
              ${task({title:'阅读行业报告', meta:'产品体验优化', secondary:'资料输入', status:'待开始', due:'今天'})}
            </div>
          </section>

          <section class="agenda panel"><div class="agenda-icon">${icon('calendar')}</div><div><h3>下午的安排</h3><p>14:00 方案初稿 · 16:30 项目同步</p></div><span class="agenda-link">查看日程 ${icon('arrow')}</span></section>
        </div>
        <aside class="right-rail">
          <section class="rail-section priorities"><div class="rail-title"><h2>今日重点</h2><span>2 项待处理</span></div>
            <div class="priority-item"><span class="priority-number">01</span><div><strong>完成方案初稿</strong><small>先把核心思路写完整</small></div>${icon('arrow')}</div>
            <div class="priority-item"><span class="priority-number">02</span><div><strong>阅读行业报告</strong><small>提取 3 条可用洞察</small></div>${icon('arrow')}</div>
          </section>
          <section class="rail-section rhythm-card panel"><div class="rail-title"><h2>工作节奏</h2>${icon('more')}</div><div class="rhythm-line"><span>本周专注</span><strong>4h 35m</strong></div><div class="week-bars"><span style="--h:58%"></span><span style="--h:75%"></span><span style="--h:44%"></span><span class="today" style="--h:90%"></span><span style="--h:28%"></span><span style="--h:18%"></span><span style="--h:12%"></span></div><div class="week-labels"><span>一</span><span>二</span><span>三</span><span>四</span><span>五</span><span>六</span><span>日</span></div></section>
          <section class="rail-section project-peek panel"><div class="rail-title"><h2>正在推进</h2>${icon('folder')}</div><strong>产品体验优化</strong><p>下一里程碑：方案评审</p><div class="project-peek-track"><i></i></div><div class="peek-foot"><span>2 / 6 项任务完成</span><b>33%</b></div></section>
          <div class="rail-quote"><span>✦</span> 今天的进展已经留下痕迹。</div>
        </aside>
      </div>
    </main>
  </div>`;
}

function projectDesktop() {
  return `<div class="desktop-shell">
    ${sidebar('projects')}
    <main class="workspace project-workspace">
      ${topbar('项目', '把事情一步步推进', `<button class="primary-button header-create">${icon('plus')}新建项目</button>`)}
      <div class="project-layout">
        <aside class="project-picker">
          <div class="picker-heading"><span>我的项目</span><b>03</b></div>
          <button class="project-choice selected"><span class="choice-symbol">${icon('briefcase')}</span><span><strong>产品体验优化</strong><small>6 项任务 · 持续推进</small></span>${icon('chevron')}</button>
          <button class="project-choice"><span class="choice-symbol">${icon('book')}</span><span><strong>内容资料库</strong><small>4 项任务 · 收集中</small></span></button>
          <button class="project-choice"><span class="choice-symbol">${icon('growth')}</span><span><strong>个人成长计划</strong><small>3 项任务 · 每周复盘</small></span></button>
          <div class="picker-note">${icon('spark')}<p>每个项目，都从清晰的下一步开始。</p></div>
        </aside>
        <div class="project-content">
          <div class="project-titlebar"><div><div class="project-kicker">当前项目 / 01 <span class="project-live"><i></i>稳步推进</span></div><h2>产品体验优化</h2><p>整理洞察、打磨方案，让下一次评审更有依据。</p></div><div class="project-controls"><div class="segmented"><button class="selected">${icon('list')}清单</button><button>${icon('chart')}看板</button></div><button class="icon-button" aria-label="更多">${icon('more')}</button></div></div>
          <section class="project-hero panel"><div class="project-hero-copy"><div class="overline">项目进展 <span class="overline-rule"></span> 2026</div><h3>每一步，<em>都有脉络。</em></h3><p>从收集线索到形成方案，所有进展都在这里。</p><div class="project-hero-track"><i></i></div><div class="project-numbers"><span><strong>2 / 6</strong> 任务完成</span><span><strong>1</strong> 里程碑</span><span><strong>2</strong> 篇笔记</span></div></div>${art('project', 'project-art')}<div class="project-percent">33%<small>总进度</small></div></section>
          <div class="project-detail-grid">
            <section class="project-tasks"><div class="section-heading"><div><span class="section-index">01</span><h2>任务清单</h2><span class="section-count">6 项 · 已完成 2 项</span></div><button class="text-action">${icon('plus')} 新建任务</button></div>
              <div class="project-task-list">
                ${task({title:'整理访谈要点', meta:'研究整理', status:'已完成', checked:true, secondary:'今天 09:20'})}
                ${task({title:'梳理现有流程', meta:'问题归纳', status:'已完成', checked:true, secondary:'10月4日'})}
                ${task({title:'完成方案初稿', meta:'方案设计', status:'进行中', due:'今天 17:00'})}
                ${task({title:'阅读行业报告', meta:'资料输入', status:'待开始', due:'今天'})}
                ${task({title:'整理可用性问题', meta:'问题归纳', status:'待开始', due:'10月9日'})}
                ${task({title:'准备评审材料', meta:'方案设计', status:'待开始', due:'10月12日'})}
              </div>
            </section>
            <aside class="project-evidence"><section class="evidence-card panel"><div class="evidence-label">${icon('flag')} 下一里程碑</div><strong>方案评审</strong><p>10月12日 · 周一</p><div class="evidence-progress"><i></i></div><small>完成方案初稿后即可准备</small></section><section class="evidence-card panel"><div class="evidence-label">${icon('note')} 相关笔记</div><div class="note-link">访谈观察与机会点 ${icon('arrow')}</div><div class="note-link">可用性问题清单 ${icon('arrow')}</div></section><div class="evidence-foot">${icon('spark')} 已连接 6 项任务、1 个里程碑与 2 篇笔记</div></aside>
          </div>
        </div>
      </div>
    </main>
  </div>`;
}

function mobileToday() {
  return `<div class="mobile-shell">
    <header class="mobile-header"><button class="mobile-icon" aria-label="菜单">${icon('menu')}</button><div class="mobile-heading"><small>10月7日 · 星期三</small><h1>今日</h1></div><button class="mobile-icon" aria-label="记录">${icon('book')}</button><button class="mobile-icon" aria-label="搜索">${icon('search')}</button><span class="mobile-avatar">我</span></header>
    <div class="mobile-scroll">
      <section class="mobile-hero panel"><div class="mobile-hero-copy"><div class="mobile-overline">今天的节奏 <span>01 / 03</span></div><h2>一步一步，<br>向前走。</h2><p>已完成 1 件，还有 2 件待推进</p><div class="mobile-progress-line"><i></i></div></div>${art('today', 'mobile-art')}<span class="mobile-progress-value">33%</span></section>
      <section class="mobile-next panel"><div class="next-label">${icon('spark')} 接下来</div><h3>完成方案初稿</h3><p>产品体验优化 · 预计 45 分钟</p><button class="primary-button">${icon('timer')}开始专注${icon('arrow', 'button-arrow')}</button></section>
      <section class="mobile-tasks"><div class="mobile-section-title"><h2>今日任务</h2><span>1 / 3 已完成</span><a href="#">全部 ${icon('arrow')}</a></div>
        <div class="mobile-task-list"><div class="mobile-task is-done"><span class="task-check checked">${icon('check')}</span><div><strong>整理访谈要点</strong><small>产品体验优化 · 已完成</small></div></div><div class="mobile-task is-current"><span class="task-check"></span><div><strong>完成方案初稿</strong><small>进行中 · 今天 17:00 前</small></div><span class="mobile-priority-dot"></span></div><div class="mobile-task"><span class="task-check"></span><div><strong>阅读行业报告</strong><small>产品体验优化 · 资料输入</small></div></div></div>
      </section>
      <section class="mobile-bottom-content"><div>${icon('growth')}<span><strong>今日重点</strong><small>先完成方案初稿，再梳理 3 条洞察</small></span></div><span>2 项</span></section>
    </div>
    <button class="mobile-fab" data-action="capture" aria-label="快速记录">${icon('plus')}<span>速记</span></button>
    <nav class="mobile-nav"><a href="?theme=${theme}&screen=mobile" class="selected">${icon('calendar')}<span>今日</span></a><a href="#" data-preview-only="true">${icon('list')}<span>计划</span></a><a href="#" data-preview-only="true">${icon('timer')}<span>执行</span></a><a href="#" data-preview-only="true">${icon('growth')}<span>成长</span></a></nav>
  </div>`;
}

const compactViewport = window.matchMedia('(max-width: 650px)');
function renderScreen() {
  document.getElementById('app').innerHTML = screen === 'mobile' || (screen === 'today' && compactViewport.matches)
    ? mobileToday()
    : screen === 'projects'
      ? projectDesktop()
      : todayDesktop();
}
renderScreen();
compactViewport.addEventListener('change', renderScreen);
document.title = `${theme === 'green' ? '柔壤图鉴' : theme === 'night' ? '夜航工作室' : '日光编辑室'} · ${screen === 'projects' ? '项目' : '今日'} · 个人工作台`;
