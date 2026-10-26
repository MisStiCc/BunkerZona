// Hero 与 Banner 共用：一次性优先，同周期叠加；未知周期不混入合计。
function resolveMarketingQuota(data, locale) {
  if (!data.zcode_plan || typeof data.zcode_plan !== 'object') return null;
  const all = Array.isArray(data.zcode_plan.entitlements) ? data.zcode_plan.entitlements : [];
  const eligible = all.filter(e => e && e.meter === 'model_usage' &&
    typeof e.grant_units === 'number' && Number.isFinite(e.grant_units) && e.grant_units >= 0 &&
    ['one_time', 'daily'].includes(e.period));
  const once = eligible.filter(e => e.period === 'one_time');
  const entries = once.length ? once : eligible.filter(e => e.period === 'daily');
  const daily = !once.length && entries.length > 0;
  const total = entries.reduce((sum, e) => sum + e.grant_units, 0);
  return {
    amountValue: new Intl.NumberFormat(locale).format(total),
    amountUnit: daily ? (locale.startsWith('zh') ? 'Tokens / 天' : 'Tokens / day') : 'Tokens',
    entries,
    benefits: entries.map(e => `${typeof e.show_name === 'string' ? e.show_name : ''} · ${new Intl.NumberFormat(locale, { notation: 'compact', maximumFractionDigits: 2 }).format(e.grant_units)} ${daily ? (locale.startsWith('zh') ? 'Tokens / 天' : 'Tokens / day') : 'Tokens'}`),
  };
}
