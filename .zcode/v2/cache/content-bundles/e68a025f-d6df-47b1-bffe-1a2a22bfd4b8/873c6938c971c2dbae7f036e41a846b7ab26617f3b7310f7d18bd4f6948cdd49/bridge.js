// 新模板共用通信层；迁移的 Weekend 动效保留原通信实现，避免改变交互时序。
globalThis.ZCodeResource = {
  connect(render, dispose = () => {}, hover = () => {}) {
    const channel = 'zcode-cloud-hero-v1';
    let instanceId = null, state = {}, destroyed = false;
    const send = (type, extra = {}) => {
      if (instanceId) parent.postMessage({ channel, instanceId, type, ...extra }, '*');
    };
    const receive = event => {
      const m = event.data;
      if (destroyed || event.source !== parent || !m || m.channel !== channel || typeof m.instanceId !== 'string') return;
      if (instanceId && m.instanceId !== instanceId) return;
      if (m.type === 'init') {
        instanceId = m.instanceId;
        state = { theme: m.theme === 'dark' ? 'dark' : 'light', locale: typeof m.locale === 'string' ? m.locale : 'en-US', data: m.data && typeof m.data === 'object' ? m.data : {}, reducedMotion: m.reducedMotion === true, visible: true };
      } else if (!instanceId) return;
      else if (m.type === 'theme') state.theme = m.theme === 'dark' ? 'dark' : 'light';
      else if (m.type === 'hover') {
        // App 隔离 iframe 点击，hover 走可信宿主消息且不重渲染权益。
        if (typeof m.hovered === 'boolean') hover(m.hovered && state.visible && !state.reducedMotion);
        return;
      }
      else if (m.type === 'visibility') state.visible = m.visible === true;
      else if (m.type === 'destroy') { destroyed = true; removeEventListener('message', receive); dispose(); document.body.replaceChildren(); return; }
      else return;
      if (m.type === 'init' || !state.visible) hover(false);
      document.documentElement.dataset.theme = state.theme;
      document.documentElement.lang = state.locale;
      try { render(state); if (m.type === 'init') send('ready'); }
      catch { send('error', { code: 'render_failed' }); }
    };
    addEventListener('message', receive);
    return { action: id => send('action', { id }) };
  }
};
