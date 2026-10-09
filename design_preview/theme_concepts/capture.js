async (page) => {
  const base = 'http://127.0.0.1:8765/design_preview/theme_concepts/';
  const output = 'F:/Project/Personal work/Personal-workbench/design_preview/theme_concepts/renders';
  const checks = [];
  for (const theme of ['green', 'night', 'sun']) {
    for (const screen of ['today', 'projects', 'mobile']) {
      const mobile = screen === 'mobile';
      await page.setViewportSize(mobile ? {width:390,height:844} : {width:1440,height:900});
      await page.goto(`${base}?theme=${theme}&screen=${screen}`);
      await page.evaluate(async () => {
        await document.fonts.ready;
        await Promise.all([...document.images].map(image => image.decode()));
        await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
      });
      await page.waitForTimeout(120);
      const filename = `${theme}-${mobile ? 'today-mobile' : `${screen}-desktop`}.png`;
      await page.screenshot({path:`${output}/${filename}`,scale:'css',type:'png'});
      checks.push(await page.evaluate(({theme,screen,filename}) => {
        const bounds = selector => {
          const node = document.querySelector(selector);
          if (!node) return null;
          const rect = node.getBoundingClientRect();
          return {top:Math.round(rect.top),bottom:Math.round(rect.bottom),left:Math.round(rect.left),right:Math.round(rect.right)};
        };
        const image = document.querySelector('.illustration');
        return {
          theme,screen,filename,
          viewport:[innerWidth,innerHeight],
          documentWidth:document.documentElement.scrollWidth,
          imageLoaded:Boolean(image?.naturalWidth),
          hero:bounds('.daily-hero,.mobile-hero,.project-hero'),
          heroText:bounds('.hero-stats,.mobile-progress-line,.project-numbers'),
          focusCard:bounds('.next-card,.mobile-next'),
          focusButton:bounds('.focus-button,.mobile-next .primary-button'),
          bottomNav:bounds('.mobile-nav'),
          lastTask:bounds('.task-list .task-card:last-child,.project-task-list .task-card:last-child,.mobile-task-list .mobile-task:last-child')
        };
      }, {theme,screen,filename}));
    }
  }
  await page.setViewportSize({width:4800,height:2050});
  await page.goto(`${base}comparison.html`);
  await page.evaluate(async () => {
    await document.fonts.ready;
    await Promise.all([...document.images].map(image => image.decode()));
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
  });
  await page.waitForTimeout(120);
  await page.screenshot({path:`${output}/comparison.png`,scale:'css',type:'png'});
  checks.push({screen:'comparison',filename:'comparison.png',viewport:[4800,2050],imageCount:await page.locator('img').count()});
  return checks;
}
