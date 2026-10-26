// 按单位分组，每组一次性优先；不同单位不相加。
function resolveMarketingQuota(data, locale) {
  if (!data.zcode_plan || typeof data.zcode_plan !== 'object') return null;
  const all = Array.isArray(data.zcode_plan.entitlements) ? data.zcode_plan.entitlements : [];
  const zh = locale.startsWith('zh');
  const compact = new Intl.NumberFormat(locale, { notation: 'compact', maximumFractionDigits: 2 });
  const normalize = value => {
    if (typeof value !== 'string' || !value.trim()) return 'tokens';
    const unit = value.trim();
    if (['token', 'tokens'].includes(unit.toLowerCase())) return 'tokens';
    if (['credit', 'credits'].includes(unit.toLowerCase())) return 'credits';
    return unit;
  };
  const label = (unit, daily) => `${unit === 'credits' && zh ? '积分' : unit}${daily ? (zh ? ' / 天' : ' / day') : ''}`;
  const byUnit = new Map();
  for (const e of all) {
    if (!e || e.meter !== 'model_usage' || typeof e.grant_units !== 'number' ||
        !Number.isFinite(e.grant_units) || e.grant_units < 0 || !['one_time', 'daily'].includes(e.period)) continue;
    const unit = normalize(e.unit_type);
    if (!byUnit.has(unit)) byUnit.set(unit, []);
    byUnit.get(unit).push(e);
  }
  const groups = [...byUnit].map(([unit, values]) => {
    const once = values.filter(e => e.period === 'one_time');
    const entries = once.length ? once : values.filter(e => e.period === 'daily');
    const daily = !once.length;
    return { entries, total: entries.reduce((sum, e) => sum + e.grant_units, 0), unit: label(unit, daily) };
  });
  const mixed = groups.length > 1;
  return {
    amountValue: mixed ? groups.map(g => `${compact.format(g.total)} ${g.unit}`).join(' + ') : new Intl.NumberFormat(locale).format(groups[0]?.total ?? 0),
    amountUnit: mixed ? '' : groups[0]?.unit ?? 'tokens',
    mixed,
    entries: groups.flatMap(g => g.entries),
    benefits: groups.flatMap(g => g.entries.map(e => `${typeof e.show_name === 'string' ? e.show_name : ''} · ${compact.format(e.grant_units)} ${g.unit}`)),
  };
}
