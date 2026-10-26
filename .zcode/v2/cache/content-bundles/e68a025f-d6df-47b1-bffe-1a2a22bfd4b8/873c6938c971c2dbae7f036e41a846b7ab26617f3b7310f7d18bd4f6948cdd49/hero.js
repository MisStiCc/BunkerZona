(() => {
  const rows = [
    ['repo.snapshotUpload = removed;', '仓库快照上传链路已移除', 'Snapshot upload removed'],
    ['incident.cloudData = deleted;', '涉事云端数据已删除，第三方核查确认', 'Deleted; 3rd-party verified'],
    ['', '', ''],
    ['if (!you.initiated) {', '你不发起，不上云', 'Cloud only if you initiate'],
    ['  nothing leaves your PC;', '', ''],
    ['  your code stays local;', '', ''],
    ['}', '', ''],
    ['', '', ''],
    ['openSource.version = v3.14.3;', '已更新至最新版', 'Updated to latest'],
    ['openSource.syncWith(official);', '今后同步发布', 'Synced releases'],
    ['', '', ''],
    ['if (you.paid || you.returningPaidUser) {', '1 个月内回归的付费用户同享', 'Return ≤1mo'],
    ['  gift("4 张周重置卡 + 4 张 5 小时重置卡");', '1 个月内有效', 'Valid 1 month'],
    ['}', '', ''],
    ['for (day in 09.28..10.07) {', 'ZCode 全体用户', 'All ZCode users'],
    ['  giveaway("1 亿 Token" * 10 万份);', '', ''],
    ['}', '', ''],
  ];
  const hero = document.getElementById('hero'), code = document.getElementById('code');
  const media = matchMedia('(prefers-reduced-motion: reduce)');
  let animations = [], current, destroyed = false, hostVisible = true;
  function tokenized(text, container) {
    const re = /("[^"\n]*"|\b(?:if|for|in|removed|deleted)\b|\bv\d+(?:\.\d+)+|\b\d+(?:\.\d+)*|\b(?:gift|giveaway|syncWith)\b)/g;
    let end = 0;
    for (const match of text.matchAll(re)) {
      container.append(document.createTextNode(text.slice(end, match.index)));
      const span = document.createElement('span');
      span.className = match[0][0] === '"' ? 'string' : /^(?:v?\d)/.test(match[0]) ? 'number' : /^(gift|giveaway|syncWith)$/.test(match[0]) ? 'method' : 'keyword';
      span.textContent = match[0]; container.append(span); end = match.index + match[0].length;
    }
    container.append(document.createTextNode(text.slice(end)));
  }
  function stop() { animations.forEach(a => a.cancel()); animations = []; }
  function play() {
    stop();
    if (destroyed || current.reducedMotion || media.matches) return;
    [...code.children].forEach((el, i) => {
      animations.push(el.animate([{opacity:0,transform:'translateY(3px)'},{opacity:1,transform:'translateY(0)'}],{duration:360,delay:40+i*65,fill:'both',easing:'cubic-bezier(.2,.7,.2,1)'}));
    });
    visibility();
  }
  function draw() {
      stop(); code.replaceChildren();
      const en = !current.locale.startsWith('zh');
      document.getElementById('note').textContent = en ? 'A commitment to you' : '致每一位用户';
      document.getElementById('closing').textContent = en ? 'Trust cannot be reset with one click. We will earn it back, one improvement at a time.' : '信任不能一键重置。我们会用每一次改进，慢慢赢回来。';
      rows.forEach((_,index) => {
        const [source,zh,english]=rows[index];
        const row = document.createElement('div');
        if (!source) return;
        row.className = 'row' + (index >= 3 && index <= 6 ? ' local' : '') + (index === 3 ? ' local-start' : '') + (index === 6 ? ' local-end' : '');
        row.dataset.line = String(rows.slice(0,index+1).filter(r=>r[0]).length).padStart(2,'0');
        const text = document.createElement('pre'); text.className = 'source';
        let literal = source;
        if(en) literal = literal.replace('4 张周重置卡 + 4 张 5 小时重置卡','4 weekly + 4 5h reset cards').replace('"1 亿 Token" * 10 万份','"100M Tokens" * 100000');
        tokenized(literal,text);
        const comment = en ? english : zh;
        if(comment){
          const c=document.createElement('span');c.className='comment';
          if(index===11 && !en){
            c.classList.add('comment-leading');c.textContent='// '+comment;
            row.classList.add('has-leading-comment');text.prepend(c);
          }else{c.textContent='  // '+comment;text.append(c);}
        }
        row.append(text); code.append(row);
      });
      play();
  }
  function render(state) {
    hostVisible=state.visible;
    if(state!==current){current=state;draw();}
    visibility();
  }
  function visibility() {
    const visible = hostVisible && !document.hidden;
    animations.forEach(a => { if (!visible && a.playState === 'running') a.pause(); else if (visible && a.playState === 'paused') a.play(); });
  }
  function resize() { hero.style.setProperty('--scale',Math.min(innerWidth/480,innerHeight/360)); }
  const observer = new ResizeObserver(resize); observer.observe(document.documentElement);resize();
  const motion = () => { if(current) {play();visibility();} };
  media.addEventListener('change',motion); document.addEventListener('visibilitychange',visibility);
  ZCodeResource.connect(render,() => {destroyed=true;stop();observer.disconnect();media.removeEventListener('change',motion);document.removeEventListener('visibilitychange',visibility);});
})();
