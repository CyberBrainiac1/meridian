/* @ds-bundle: {"format":4,"namespace":"MeridianDesignSystem_91853d","components":[{"name":"BulletChart","sourcePath":"components/charts/BulletChart.jsx"},{"name":"TrendLineChart","sourcePath":"components/charts/TrendLineChart.jsx"},{"name":"Badge","sourcePath":"components/display/Badge.jsx"},{"name":"Card","sourcePath":"components/display/Card.jsx"},{"name":"Tag","sourcePath":"components/display/Tag.jsx"},{"name":"Dialog","sourcePath":"components/feedback/Dialog.jsx"},{"name":"Toast","sourcePath":"components/feedback/Toast.jsx"},{"name":"Tooltip","sourcePath":"components/feedback/Tooltip.jsx"},{"name":"Button","sourcePath":"components/forms/Button.jsx"},{"name":"Checkbox","sourcePath":"components/forms/Checkbox.jsx"},{"name":"IconButton","sourcePath":"components/forms/IconButton.jsx"},{"name":"Input","sourcePath":"components/forms/Input.jsx"},{"name":"Radio","sourcePath":"components/forms/Radio.jsx"},{"name":"Select","sourcePath":"components/forms/Select.jsx"},{"name":"Switch","sourcePath":"components/forms/Switch.jsx"},{"name":"Tabs","sourcePath":"components/navigation/Tabs.jsx"}],"sourceHashes":{"components/charts/BulletChart.jsx":"f4b0f3deffec","components/charts/TrendLineChart.jsx":"3c77cd27f4ae","components/display/Badge.jsx":"e6a24d832e01","components/display/Card.jsx":"006a3ddf07e1","components/display/Tag.jsx":"d0d99f094ca8","components/feedback/Dialog.jsx":"6602a28467d8","components/feedback/Toast.jsx":"405176668d74","components/feedback/Tooltip.jsx":"8c542c2e734d","components/forms/Button.jsx":"2394f21c9e57","components/forms/Checkbox.jsx":"0e56bdf829a8","components/forms/IconButton.jsx":"5197b2850a42","components/forms/Input.jsx":"80087650aeaa","components/forms/Radio.jsx":"e17003ff5d82","components/forms/Select.jsx":"f70202b63974","components/forms/Switch.jsx":"dc8e093cfd0e","components/navigation/Tabs.jsx":"8e96086472e5","ui_kits/meridian_care/screens.jsx":"681611eba511","ui_kits/meridian_family/screens.jsx":"076193e07c57","ui_kits/meridian_hub/kiosk.jsx":"c6287ac701ac","ui_kits/meridian_insights/dashboard.jsx":"f7d5509de8f4"},"inlinedExternals":[],"unexposedExports":[]} */

(() => {

const __ds_ns = (window.MeridianDesignSystem_91853d = window.MeridianDesignSystem_91853d || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// components/charts/BulletChart.jsx
try { (() => {
function BulletChart({
  label,
  sublabel,
  valueSeconds,
  targetSeconds = 120,
  excellentSeconds = 90,
  maxScaleSeconds = 240,
  incidentCount = 0
}) {
  const hasData = valueSeconds !== null && valueSeconds !== undefined;
  const pct = n => Math.min(100, n / maxScaleSeconds * 100);
  const overTarget = hasData && valueSeconds > targetSeconds;
  const fmt = s => {
    const m = Math.floor(s / 60),
      r = Math.round(s % 60);
    return m > 0 ? `${m}m ${r}s` : `${r}s`;
  };
  return React.createElement('div', {
    style: {
      fontFamily: 'var(--font-body)',
      background: 'var(--color-surface)',
      border: '1px solid var(--color-border)',
      borderRadius: 'var(--radius-card)',
      boxShadow: 'var(--shadow-soft)',
      padding: 16
    }
  }, React.createElement('div', {
    style: {
      display: 'flex',
      justifyContent: 'space-between',
      gap: 8,
      marginBottom: 4
    }
  }, React.createElement('div', null, React.createElement('p', {
    style: {
      fontWeight: 600,
      fontSize: 14,
      margin: 0
    }
  }, label), React.createElement('p', {
    style: {
      fontSize: 12,
      color: 'var(--color-foreground-muted)',
      margin: 0
    }
  }, sublabel)), React.createElement('p', {
    style: {
      fontSize: 18,
      fontWeight: 600,
      margin: 0,
      color: overTarget ? 'var(--color-warning)' : 'var(--color-foreground)'
    }
  }, hasData ? fmt(valueSeconds) : 'No data')), hasData ? React.createElement('div', {
    style: {
      position: 'relative',
      height: 16,
      borderRadius: 999,
      background: 'var(--color-muted)',
      overflow: 'hidden',
      marginTop: 8
    }
  }, React.createElement('div', {
    style: {
      position: 'absolute',
      inset: '0 auto 0 0',
      width: pct(excellentSeconds) + '%',
      background: 'var(--color-success)',
      opacity: .15
    }
  }), React.createElement('div', {
    style: {
      position: 'absolute',
      top: 0,
      bottom: 0,
      left: pct(excellentSeconds) + '%',
      width: pct(targetSeconds) - pct(excellentSeconds) + '%',
      background: 'var(--color-warning)',
      opacity: .1
    }
  }), React.createElement('div', {
    style: {
      position: 'absolute',
      top: 2,
      bottom: 2,
      left: 0,
      borderRadius: 999,
      width: pct(valueSeconds) + '%',
      background: overTarget ? 'var(--color-warning)' : 'var(--color-primary)'
    }
  }), React.createElement('div', {
    style: {
      position: 'absolute',
      top: 0,
      bottom: 0,
      width: 2,
      background: 'var(--color-foreground)',
      left: pct(targetSeconds) + '%'
    }
  })) : React.createElement('div', {
    className: 'skeleton-shimmer',
    style: {
      height: 16,
      borderRadius: 999,
      marginTop: 8
    }
  }), React.createElement('div', {
    style: {
      display: 'flex',
      justifyContent: 'space-between',
      marginTop: 6,
      fontSize: 11,
      color: 'var(--color-foreground-muted)'
    }
  }, React.createElement('span', null, 'Target: ' + fmt(targetSeconds)), React.createElement('span', null, incidentCount + ' incident' + (incidentCount === 1 ? '' : 's'))));
}
Object.assign(__ds_scope, { BulletChart });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/charts/BulletChart.jsx", error: String((e && e.message) || e) }); }

// components/charts/TrendLineChart.jsx
try { (() => {
const SERIES = [{
  key: 'fall_confirmed',
  label: 'Fall confirmed',
  color: '#DC2626'
}, {
  key: 'fall_suspected',
  label: 'Fall suspected',
  color: '#B45309'
}, {
  key: 'long_lie',
  label: 'Long lie',
  color: '#0369A1'
}, {
  key: 'unusual_inactivity',
  label: 'Unusual inactivity',
  color: '#0891B2'
}];
function TrendLineChart({
  data = []
}) {
  const w = 560,
    h = 200,
    pad = 28;
  const max = Math.max(1, ...data.flatMap(d => SERIES.map(s => d.counts?.[s.key] || 0)));
  const x = i => pad + i * (w - 2 * pad) / Math.max(1, data.length - 1);
  const y = v => h - pad - v / max * (h - 2 * pad);
  return React.createElement('div', {
    style: {
      fontFamily: 'var(--font-body)'
    }
  }, React.createElement('svg', {
    width: '100%',
    viewBox: '0 0 ' + w + ' ' + h,
    style: {
      overflow: 'visible'
    }
  }, React.createElement('line', {
    x1: pad,
    x2: w - pad,
    y1: h - pad,
    y2: h - pad,
    stroke: 'var(--color-border)'
  }), SERIES.map(s => React.createElement('polyline', {
    key: s.key,
    fill: 'none',
    stroke: s.color,
    strokeWidth: 2,
    points: data.map((d, i) => x(i) + ',' + y(d.counts?.[s.key] || 0)).join(' ')
  })), data.map((d, i) => React.createElement('text', {
    key: i,
    x: x(i),
    y: h - 8,
    fontSize: 10,
    fill: 'var(--color-foreground)',
    textAnchor: 'middle'
  }, d.weekLabel))), React.createElement('div', {
    style: {
      display: 'flex',
      gap: 14,
      flexWrap: 'wrap',
      marginTop: 10,
      fontSize: 12
    }
  }, SERIES.map(s => React.createElement('span', {
    key: s.key,
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 6,
      color: 'var(--color-foreground-muted)'
    }
  }, React.createElement('span', {
    style: {
      width: 10,
      height: 2,
      background: s.color,
      display: 'inline-block'
    }
  }), s.label))), React.createElement('table', {
    style: {
      width: '100%',
      fontFamily: 'var(--font-mono-data)',
      fontSize: 12,
      marginTop: 12,
      borderCollapse: 'collapse'
    }
  }, React.createElement('thead', null, React.createElement('tr', {
    style: {
      textAlign: 'left',
      color: 'var(--color-foreground-muted)'
    }
  }, React.createElement('th', {
    style: {
      padding: '4px 12px 4px 0'
    }
  }, 'Week'), SERIES.map(s => React.createElement('th', {
    key: s.key,
    style: {
      padding: '4px 12px'
    }
  }, s.label)))), React.createElement('tbody', null, data.map((d, i) => React.createElement('tr', {
    key: i,
    style: {
      borderTop: '1px solid var(--color-border)'
    }
  }, React.createElement('td', {
    style: {
      padding: '4px 12px 4px 0'
    }
  }, d.weekLabel), SERIES.map(s => React.createElement('td', {
    key: s.key,
    style: {
      padding: '4px 12px'
    }
  }, d.counts?.[s.key] || 0)))))));
}
Object.assign(__ds_scope, { TrendLineChart });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/charts/TrendLineChart.jsx", error: String((e && e.message) || e) }); }

// components/display/Badge.jsx
try { (() => {
const TONES = {
  info: {
    bg: 'var(--color-primary)',
    text: 'var(--color-primary)'
  },
  warning: {
    bg: 'var(--color-warning)',
    text: 'var(--color-warning-strong)'
  },
  critical: {
    bg: 'var(--color-destructive)',
    text: 'var(--color-destructive-strong)'
  },
  success: {
    bg: 'var(--color-success)',
    text: 'var(--color-success-strong)'
  },
  offline: {
    bg: 'var(--color-warning)',
    text: 'var(--color-warning-strong)'
  },
  neutral: {
    bg: 'var(--color-muted)',
    text: 'var(--color-foreground-muted)'
  }
};
const LABELS = {
  info: 'Info',
  warning: 'Needs attention',
  critical: 'Emergency',
  success: 'Resolved',
  offline: 'Offline',
  neutral: 'Neutral'
};
function Badge({
  tone = 'info',
  children,
  style
}) {
  const t = TONES[tone] || TONES.info;
  return React.createElement('span', {
    style: {
      fontFamily: 'var(--font-body)',
      display: 'inline-flex',
      alignItems: 'center',
      gap: 6,
      fontSize: 13,
      fontWeight: 600,
      padding: '5px 10px',
      borderRadius: 999,
      background: tone === 'neutral' ? t.bg : t.bg + '1f',
      color: t.text,
      ...style
    }
  }, children ?? LABELS[tone]);
}
Object.assign(__ds_scope, { Badge });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/display/Badge.jsx", error: String((e && e.message) || e) }); }

// components/display/Card.jsx
try { (() => {
function Card({
  variant = 'card',
  pad = 'md',
  title,
  children,
  style
}) {
  const padding = {
    none: 0,
    sm: 12,
    md: 16,
    lg: 24
  }[pad];
  const variants = {
    card: {
      background: 'var(--color-surface)',
      border: '1px solid var(--color-border)',
      borderRadius: 'var(--radius-card)',
      boxShadow: 'var(--shadow-soft)'
    },
    muted: {
      background: 'var(--color-muted)',
      border: 'none',
      borderRadius: 'var(--radius-card)'
    },
    status: {
      background: 'var(--color-surface)',
      borderLeft: '10px solid var(--color-primary)',
      borderRadius: 'var(--radius-control)',
      boxShadow: 'var(--shadow-soft)'
    },
    plain: {
      background: 'transparent',
      border: 'none',
      borderRadius: 0
    }
  };
  return React.createElement('div', {
    style: {
      fontFamily: 'var(--font-body)',
      color: 'var(--color-foreground)',
      padding,
      boxSizing: 'border-box',
      ...variants[variant],
      ...style
    }
  }, title && React.createElement('div', {
    style: {
      fontFamily: 'var(--font-heading)',
      fontWeight: 600,
      fontSize: 14,
      marginBottom: 10
    }
  }, title), children);
}
Object.assign(__ds_scope, { Card });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/display/Card.jsx", error: String((e && e.message) || e) }); }

// components/display/Tag.jsx
try { (() => {
function Tag({
  children,
  onRemove,
  style
}) {
  return React.createElement('span', {
    style: {
      fontFamily: 'var(--font-body)',
      display: 'inline-flex',
      alignItems: 'center',
      gap: 6,
      fontSize: 12,
      fontWeight: 500,
      color: 'var(--color-foreground-muted)',
      background: 'var(--color-muted)',
      padding: '2px 10px',
      borderRadius: 999,
      ...style
    }
  }, children, onRemove && React.createElement('button', {
    onClick: onRemove,
    'aria-label': 'Remove',
    style: {
      all: 'unset',
      cursor: 'pointer',
      fontWeight: 700,
      lineHeight: 1
    }
  }, '\u00d7'));
}
Object.assign(__ds_scope, { Tag });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/display/Tag.jsx", error: String((e && e.message) || e) }); }

// components/feedback/Dialog.jsx
try { (() => {
function Dialog({
  open,
  title,
  children,
  actions,
  onClose,
  width = 440,
  style
}) {
  if (!open) return null;
  return React.createElement('div', {
    onClick: onClose,
    style: {
      position: 'fixed',
      inset: 0,
      background: 'rgba(12,74,110,.35)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      zIndex: 1000
    }
  }, React.createElement('div', {
    role: 'dialog',
    'aria-modal': true,
    onClick: e => e.stopPropagation(),
    style: {
      background: 'var(--color-surface)',
      border: '1px solid var(--color-border)',
      borderRadius: 'var(--radius-card)',
      width,
      maxWidth: 'calc(100vw - 48px)',
      padding: 24,
      fontFamily: 'var(--font-body)',
      color: 'var(--color-foreground)',
      boxShadow: 'var(--shadow-soft-hover)',
      ...style
    }
  }, title && React.createElement('div', {
    style: {
      fontFamily: 'var(--font-heading)',
      fontWeight: 600,
      fontSize: 18,
      marginBottom: 12
    }
  }, title), React.createElement('div', {
    style: {
      fontSize: 15,
      lineHeight: 1.5
    }
  }, children), actions && React.createElement('div', {
    style: {
      display: 'flex',
      gap: 10,
      justifyContent: 'flex-end',
      marginTop: 20
    }
  }, actions)));
}
Object.assign(__ds_scope, { Dialog });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/Dialog.jsx", error: String((e && e.message) || e) }); }

// components/feedback/Toast.jsx
try { (() => {
function Toast({
  open = true,
  tone = 'info',
  children,
  onDismiss,
  style
}) {
  if (!open) return null;
  const bar = {
    info: 'var(--color-primary)',
    success: 'var(--color-success)',
    critical: 'var(--color-destructive)',
    warning: 'var(--color-warning)'
  }[tone];
  return React.createElement('div', {
    role: 'status',
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 12,
      background: 'var(--color-surface)',
      border: '1px solid var(--color-border)',
      borderRadius: 'var(--radius-control)',
      padding: '12px 16px',
      fontFamily: 'var(--font-body)',
      fontSize: 15,
      color: 'var(--color-foreground)',
      boxShadow: 'var(--shadow-soft)',
      maxWidth: 420,
      ...style
    }
  }, React.createElement('span', {
    style: {
      width: 4,
      alignSelf: 'stretch',
      background: bar,
      flex: 'none',
      borderRadius: 2
    }
  }), React.createElement('span', {
    style: {
      flex: 1
    }
  }, children), onDismiss && React.createElement('button', {
    onClick: onDismiss,
    'aria-label': 'Dismiss',
    style: {
      all: 'unset',
      cursor: 'pointer',
      fontWeight: 700
    }
  }, '\u00d7'));
}
Object.assign(__ds_scope, { Toast });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/Toast.jsx", error: String((e && e.message) || e) }); }

// components/feedback/Tooltip.jsx
try { (() => {
function Tooltip({
  label,
  side = 'top',
  children,
  style
}) {
  const [show, setShow] = React.useState(false);
  const pos = {
    top: {
      bottom: 'calc(100% + 6px)',
      left: '50%',
      transform: 'translateX(-50%)'
    },
    bottom: {
      top: 'calc(100% + 6px)',
      left: '50%',
      transform: 'translateX(-50%)'
    },
    left: {
      right: 'calc(100% + 6px)',
      top: '50%',
      transform: 'translateY(-50%)'
    },
    right: {
      left: 'calc(100% + 6px)',
      top: '50%',
      transform: 'translateY(-50%)'
    }
  }[side];
  return React.createElement('span', {
    onMouseEnter: () => setShow(true),
    onMouseLeave: () => setShow(false),
    onFocus: () => setShow(true),
    onBlur: () => setShow(false),
    style: {
      position: 'relative',
      display: 'inline-flex',
      ...style
    }
  }, children, show && React.createElement('span', {
    role: 'tooltip',
    style: {
      position: 'absolute',
      ...pos,
      background: 'var(--color-foreground)',
      color: '#fff',
      fontFamily: 'var(--font-body)',
      fontSize: 12,
      fontWeight: 500,
      padding: '5px 9px',
      whiteSpace: 'nowrap',
      zIndex: 100,
      borderRadius: 6
    }
  }, label));
}
Object.assign(__ds_scope, { Tooltip });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/Tooltip.jsx", error: String((e && e.message) || e) }); }

// components/forms/Button.jsx
try { (() => {
function useHover() {
  const [h, setH] = React.useState(false);
  return [h, {
    onMouseEnter: () => setH(true),
    onMouseLeave: () => setH(false)
  }];
}
const PAL = {
  primary: {
    background: 'var(--color-primary)',
    color: 'var(--color-on-primary)'
  },
  destructive: {
    background: 'var(--color-destructive)',
    color: 'var(--color-on-destructive)'
  },
  success: {
    background: 'var(--color-success-strong)',
    color: '#fff'
  },
  secondary: {
    background: 'var(--color-surface)',
    color: 'var(--color-foreground)',
    border: '1px solid var(--color-border)'
  },
  ghost: {
    background: 'transparent',
    color: 'var(--color-foreground)'
  }
};
const SIZES = {
  sm: {
    fontSize: 14,
    padding: '6px 14px'
  },
  md: {
    fontSize: 16,
    padding: '0 16px'
  },
  lg: {
    fontSize: 16,
    padding: '0 24px'
  }
};
function Button({
  variant = 'primary',
  size = 'md',
  disabled = false,
  fullWidth = false,
  children,
  onClick,
  type = 'button',
  style
}) {
  const [h, hp] = useHover();
  return React.createElement('button', {
    type,
    disabled,
    onClick,
    ...hp,
    style: {
      fontFamily: 'var(--font-body)',
      fontWeight: 500,
      cursor: disabled ? 'not-allowed' : 'pointer',
      borderRadius: 'var(--radius-control)',
      transition: 'opacity var(--motion-duration) var(--motion-easing), background var(--motion-duration) var(--motion-easing)',
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      gap: 8,
      minHeight: 'var(--touch-target-min)',
      minWidth: 'var(--touch-target-min)',
      width: fullWidth ? '100%' : undefined,
      opacity: disabled ? 0.5 : h ? 0.85 : 1,
      border: 'none',
      ...PAL[variant],
      ...SIZES[size],
      ...style
    }
  }, children);
}
Object.assign(__ds_scope, { Button });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Button.jsx", error: String((e && e.message) || e) }); }

// components/forms/Checkbox.jsx
try { (() => {
function Checkbox({
  checked,
  defaultChecked,
  onChange,
  label,
  disabled = false,
  style
}) {
  const [inner, setInner] = React.useState(!!defaultChecked);
  const isC = checked !== undefined ? checked : inner;
  const toggle = e => {
    if (disabled) return;
    if (checked === undefined) setInner(!isC);
    onChange && onChange(!isC, e);
  };
  return React.createElement('label', {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 10,
      cursor: disabled ? 'not-allowed' : 'pointer',
      fontFamily: 'var(--font-body)',
      fontSize: 16,
      color: 'var(--color-foreground)',
      opacity: disabled ? 0.5 : 1,
      minHeight: 'var(--touch-target-min)',
      ...style
    }
  }, React.createElement('span', {
    onClick: toggle,
    role: 'checkbox',
    'aria-checked': isC,
    tabIndex: 0,
    onKeyDown: e => {
      if (e.key === ' ' || e.key === 'Enter') {
        e.preventDefault();
        toggle(e);
      }
    },
    style: {
      width: 20,
      height: 20,
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      flex: 'none',
      border: '1px solid ' + (isC ? 'var(--color-primary)' : 'var(--color-border)'),
      borderRadius: 5,
      background: isC ? 'var(--color-primary)' : 'var(--color-surface)',
      color: '#fff',
      fontSize: 13,
      fontWeight: 700,
      transition: 'background var(--motion-duration) var(--motion-easing)'
    }
  }, isC ? '\u2713' : ''), label && React.createElement('span', {
    onClick: toggle
  }, label));
}
Object.assign(__ds_scope, { Checkbox });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Checkbox.jsx", error: String((e && e.message) || e) }); }

// components/forms/IconButton.jsx
try { (() => {
function useHover() {
  const [h, setH] = React.useState(false);
  return [h, {
    onMouseEnter: () => setH(true),
    onMouseLeave: () => setH(false)
  }];
}
function IconButton({
  label,
  size = 'md',
  variant = 'ghost',
  disabled = false,
  onClick,
  children,
  style
}) {
  const [h, hp] = useHover();
  const px = {
    sm: 32,
    md: 44,
    lg: 52
  }[size];
  const pal = variant === 'primary' ? {
    background: 'var(--color-primary)',
    color: 'var(--color-on-primary)'
  } : variant === 'secondary' ? {
    background: 'transparent',
    color: 'var(--color-foreground)',
    border: '1px solid var(--color-border)'
  } : {
    background: 'transparent',
    color: 'var(--color-foreground)'
  };
  return React.createElement('button', {
    'aria-label': label,
    title: label,
    disabled,
    onClick,
    ...hp,
    style: {
      width: Math.max(px, 44),
      height: Math.max(px, 44),
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      borderRadius: 'var(--radius-control)',
      cursor: disabled ? 'not-allowed' : 'pointer',
      border: 'none',
      transition: 'opacity var(--motion-duration) var(--motion-easing)',
      opacity: disabled ? 0.5 : h ? 0.7 : 1,
      fontSize: px * 0.45,
      ...pal,
      ...style
    }
  }, children);
}
Object.assign(__ds_scope, { IconButton });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/IconButton.jsx", error: String((e && e.message) || e) }); }

// components/forms/Input.jsx
try { (() => {
function Input({
  value,
  defaultValue,
  onChange,
  placeholder,
  type = 'text',
  label,
  disabled = false,
  invalid = false,
  multiline = false,
  rows = 3,
  style
}) {
  const [focus, setFocus] = React.useState(false);
  const base = {
    fontFamily: 'var(--font-body)',
    fontSize: 16,
    color: 'var(--color-foreground)',
    background: 'var(--color-surface)',
    border: '1px solid ' + (invalid ? 'var(--color-destructive)' : 'var(--color-border)'),
    borderRadius: 'var(--radius-control)',
    padding: '11px 14px',
    outline: focus ? '2px solid var(--color-primary)' : 'none',
    outlineOffset: 2,
    minHeight: 'var(--touch-target-min)',
    width: '100%',
    transition: 'outline-color var(--motion-duration) var(--motion-easing)',
    opacity: disabled ? 0.5 : 1,
    resize: 'vertical',
    boxSizing: 'border-box'
  };
  const field = React.createElement(multiline ? 'textarea' : 'input', {
    value,
    defaultValue,
    placeholder,
    disabled,
    rows: multiline ? rows : undefined,
    type: multiline ? undefined : type,
    onChange: e => onChange && onChange(e.target.value, e),
    onFocus: () => setFocus(true),
    onBlur: () => setFocus(false),
    style: {
      ...base,
      ...style
    }
  });
  if (!label) return field;
  return React.createElement('label', {
    style: {
      display: 'block',
      fontFamily: 'var(--font-body)'
    }
  }, React.createElement('div', {
    style: {
      fontSize: 14,
      fontWeight: 600,
      color: 'var(--color-foreground)',
      marginBottom: 6
    }
  }, label), field);
}
Object.assign(__ds_scope, { Input });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Input.jsx", error: String((e && e.message) || e) }); }

// components/forms/Radio.jsx
try { (() => {
function Radio({
  options = [],
  value,
  defaultValue,
  onChange,
  direction = 'column',
  disabled = false,
  style
}) {
  const [inner, setInner] = React.useState(defaultValue);
  const cur = value !== undefined ? value : inner;
  return React.createElement('div', {
    role: 'radiogroup',
    style: {
      display: 'flex',
      flexDirection: direction,
      gap: direction === 'column' ? 10 : 20,
      fontFamily: 'var(--font-body)',
      ...style
    }
  }, options.map(o => {
    const v = typeof o === 'string' ? {
      value: o,
      label: o
    } : o;
    const on = cur === v.value;
    return React.createElement('label', {
      key: v.value,
      style: {
        display: 'inline-flex',
        alignItems: 'center',
        gap: 10,
        cursor: disabled ? 'not-allowed' : 'pointer',
        fontSize: 16,
        color: 'var(--color-foreground)',
        opacity: disabled ? 0.5 : 1,
        minHeight: 'var(--touch-target-min)'
      }
    }, React.createElement('span', {
      role: 'radio',
      'aria-checked': on,
      tabIndex: 0,
      onClick: e => {
        if (disabled) return;
        if (value === undefined) setInner(v.value);
        onChange && onChange(v.value, e);
      },
      style: {
        width: 20,
        height: 20,
        borderRadius: '50%',
        flex: 'none',
        border: '1px solid ' + (on ? 'var(--color-primary)' : 'var(--color-border)'),
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: 'var(--color-surface)'
      }
    }, on && React.createElement('span', {
      style: {
        width: 11,
        height: 11,
        borderRadius: '50%',
        background: 'var(--color-primary)'
      }
    })), v.label);
  }));
}
Object.assign(__ds_scope, { Radio });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Radio.jsx", error: String((e && e.message) || e) }); }

// components/forms/Select.jsx
try { (() => {
function Select({
  value,
  defaultValue,
  onChange,
  options = [],
  label,
  placeholder,
  disabled = false,
  style
}) {
  const [focus, setFocus] = React.useState(false);
  const sel = React.createElement('select', {
    value,
    defaultValue: value === undefined ? defaultValue ?? '' : undefined,
    disabled,
    onChange: e => onChange && onChange(e.target.value, e),
    onFocus: () => setFocus(true),
    onBlur: () => setFocus(false),
    style: {
      fontFamily: 'var(--font-body)',
      fontSize: 16,
      color: 'var(--color-foreground)',
      background: 'var(--color-surface)',
      width: '100%',
      border: '1px solid var(--color-border)',
      borderRadius: 'var(--radius-control)',
      minHeight: 'var(--touch-target-min)',
      padding: '11px 14px',
      outline: focus ? '2px solid var(--color-primary)' : 'none',
      outlineOffset: 2,
      opacity: disabled ? 0.5 : 1,
      boxSizing: 'border-box',
      ...style
    }
  }, [placeholder && React.createElement('option', {
    key: '_p',
    value: '',
    disabled: true
  }, placeholder), ...options.map(o => {
    const v = typeof o === 'string' ? {
      value: o,
      label: o
    } : o;
    return React.createElement('option', {
      key: v.value,
      value: v.value
    }, v.label);
  })]);
  if (!label) return sel;
  return React.createElement('label', {
    style: {
      display: 'block',
      fontFamily: 'var(--font-body)'
    }
  }, React.createElement('div', {
    style: {
      fontSize: 14,
      fontWeight: 600,
      marginBottom: 6,
      color: 'var(--color-foreground)'
    }
  }, label), sel);
}
Object.assign(__ds_scope, { Select });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Select.jsx", error: String((e && e.message) || e) }); }

// components/forms/Switch.jsx
try { (() => {
function Switch({
  checked,
  defaultChecked,
  onChange,
  label,
  disabled = false,
  style
}) {
  const [inner, setInner] = React.useState(!!defaultChecked);
  const on = checked !== undefined ? checked : inner;
  const toggle = e => {
    if (disabled) return;
    if (checked === undefined) setInner(!on);
    onChange && onChange(!on, e);
  };
  return React.createElement('label', {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 10,
      cursor: disabled ? 'not-allowed' : 'pointer',
      fontFamily: 'var(--font-body)',
      fontSize: 16,
      color: 'var(--color-foreground)',
      opacity: disabled ? 0.5 : 1,
      minHeight: 'var(--touch-target-min)',
      ...style
    }
  }, React.createElement('span', {
    role: 'switch',
    'aria-checked': on,
    tabIndex: 0,
    onClick: toggle,
    onKeyDown: e => {
      if (e.key === ' ' || e.key === 'Enter') {
        e.preventDefault();
        toggle(e);
      }
    },
    style: {
      width: 44,
      height: 26,
      borderRadius: 999,
      background: on ? 'var(--color-primary)' : 'var(--color-border)',
      position: 'relative',
      transition: 'background var(--motion-duration) var(--motion-easing)',
      flex: 'none'
    }
  }, React.createElement('span', {
    style: {
      position: 'absolute',
      top: 3,
      left: on ? 21 : 3,
      width: 20,
      height: 20,
      borderRadius: '50%',
      background: '#fff',
      transition: 'left var(--motion-duration) var(--motion-easing)'
    }
  })), label && React.createElement('span', {
    onClick: toggle
  }, label));
}
Object.assign(__ds_scope, { Switch });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Switch.jsx", error: String((e && e.message) || e) }); }

// components/navigation/Tabs.jsx
try { (() => {
function Tabs({
  tabs = [],
  value,
  defaultValue,
  onChange,
  variant = 'underline',
  style
}) {
  const [inner, setInner] = React.useState(defaultValue ?? (tabs[0] && (typeof tabs[0] === 'string' ? tabs[0] : tabs[0].value)));
  const cur = value !== undefined ? value : inner;
  const norm = tabs.map(t => typeof t === 'string' ? {
    value: t,
    label: t
  } : t);
  const isBar = variant === 'bar';
  return React.createElement('div', {
    role: 'tablist',
    style: {
      display: 'flex',
      fontFamily: 'var(--font-body)',
      borderBottom: isBar ? 'none' : '1px solid var(--color-border)',
      borderTop: isBar ? '1px solid var(--color-border)' : 'none',
      justifyContent: isBar ? 'space-around' : 'flex-start',
      gap: isBar ? 0 : 4,
      background: isBar ? 'var(--color-surface)' : 'transparent',
      ...style
    }
  }, norm.map(t => {
    const on = cur === t.value;
    return React.createElement('button', {
      key: t.value,
      role: 'tab',
      'aria-selected': on,
      onClick: e => {
        if (value === undefined) setInner(t.value);
        onChange && onChange(t.value, e);
      },
      style: {
        all: 'unset',
        cursor: 'pointer',
        padding: isBar ? '10px 12px' : '12px 16px',
        fontSize: isBar ? 11 : 15,
        minHeight: 'var(--touch-target-min)',
        fontWeight: on ? 600 : 500,
        color: on ? 'var(--color-primary)' : 'var(--color-foreground-muted)',
        borderBottom: isBar ? 'none' : '2px solid ' + (on ? 'var(--color-primary)' : 'transparent'),
        display: 'flex',
        flexDirection: isBar ? 'column' : 'row',
        alignItems: 'center',
        gap: isBar ? 4 : 8,
        transition: 'color var(--motion-duration) var(--motion-easing)',
        textAlign: 'center'
      }
    }, t.icon && React.createElement('span', {
      style: {
        fontSize: 18,
        lineHeight: 1
      }
    }, t.icon), t.label);
  }));
}
Object.assign(__ds_scope, { Tabs });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/Tabs.jsx", error: String((e && e.message) || e) }); }

// ui_kits/meridian_care/screens.jsx
try { (() => {
const {
  Button,
  Input,
  Badge,
  Card
} = window.MeridianDesignSystem_91853d;
const CR = 'var(--radius-card-care)',
  CC = 'var(--radius-control-care)';
const S = {
  page: {
    background: 'var(--color-background-mobile)',
    height: '100%',
    display: 'flex',
    flexDirection: 'column',
    fontFamily: 'var(--font-body)',
    color: 'var(--color-foreground)'
  },
  body: {
    flex: 1,
    overflowY: 'auto',
    padding: '16px 16px 90px'
  },
  h1: {
    fontFamily: 'var(--font-heading)',
    fontWeight: 600,
    fontSize: 22,
    margin: '4px 0 14px'
  }
};
const INCIDENTS = [{
  id: 1,
  type: 'Fall confirmed',
  severity: 'critical',
  copy: 'Maggie needs help in Room 12',
  status: 'Open',
  time: '2m ago',
  resolutionNote: null
}, {
  id: 2,
  type: 'Long lie',
  severity: 'warning',
  copy: 'Walter has been still for 20 minutes in Room 4',
  status: 'Acknowledged',
  time: '14m ago',
  resolutionNote: null
}, {
  id: 3,
  type: 'Visitor arrival',
  severity: 'info',
  copy: 'New visitor detected at Main Entrance',
  status: 'Resolved',
  time: '1h ago',
  resolutionNote: null
}];
function IncidentRow({
  incident,
  onOpen
}) {
  return /*#__PURE__*/React.createElement("div", {
    onClick: onOpen,
    style: {
      padding: '12px 2px',
      borderBottom: '1px solid var(--color-border)',
      cursor: 'pointer'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      justifyContent: 'space-between',
      marginBottom: 6
    }
  }, /*#__PURE__*/React.createElement(Badge, {
    tone: incident.severity
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 13,
      color: 'var(--color-foreground-muted)'
    }
  }, incident.time)), /*#__PURE__*/React.createElement("div", {
    style: {
      fontWeight: 500,
      fontSize: 17
    }
  }, incident.copy), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      color: 'var(--color-foreground-muted)',
      marginTop: 2
    }
  }, incident.status));
}
function AlertsScreen({
  incidents,
  onOpen
}) {
  const open = incidents.filter(i => i.status !== 'Resolved');
  return /*#__PURE__*/React.createElement("div", {
    style: S.body
  }, /*#__PURE__*/React.createElement("div", {
    style: S.h1
  }, "Alerts"), open.length === 0 ? /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: 'center',
      marginTop: 60,
      color: 'var(--color-foreground-muted)',
      fontSize: 15
    }
  }, "Everyone's accounted for right now.") : open.map(i => /*#__PURE__*/React.createElement(IncidentRow, {
    key: i.id,
    incident: i,
    onOpen: () => onOpen(i)
  })));
}
const NEXT_ACTIONS = {
  Open: ['Acknowledge', 'Mark responding', 'Resolve', 'Dismiss as false alarm', 'Escalate'],
  Acknowledged: ['Mark responding', 'Resolve', 'Dismiss as false alarm', 'Escalate'],
  Responding: ['Resolve', 'Dismiss as false alarm', 'Escalate'],
  Resolved: []
};
const KIND = {
  Acknowledge: 'secondary',
  'Mark responding': 'secondary',
  Resolve: 'success',
  'Dismiss as false alarm': 'secondary',
  Escalate: 'destructive'
};
function IncidentDetail({
  incident,
  onBack,
  onRespond
}) {
  const [note, setNote] = React.useState('');
  const [confirm, setConfirm] = React.useState(null);
  const nexts = NEXT_ACTIONS[incident.status] || [];
  return /*#__PURE__*/React.createElement("div", {
    style: S.body
  }, /*#__PURE__*/React.createElement("div", {
    onClick: onBack,
    style: {
      fontSize: 15,
      fontWeight: 500,
      cursor: 'pointer',
      marginBottom: 14,
      color: 'var(--color-primary)'
    }
  }, "\u2039 Alerts"), /*#__PURE__*/React.createElement(Badge, {
    tone: incident.severity
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-heading)',
      fontWeight: 600,
      fontSize: 20,
      margin: '10px 0 2px'
    }
  }, incident.copy), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      color: 'var(--color-foreground-muted)',
      marginBottom: 16
    }
  }, incident.type, " \xB7 ", incident.time), nexts.length === 0 ? /*#__PURE__*/React.createElement(Card, {
    style: {
      borderRadius: CR
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--color-success)'
    }
  }, "\u2713"), " This alert is closed.") : /*#__PURE__*/React.createElement(Card, {
    style: {
      borderRadius: CR
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      fontWeight: 600,
      marginBottom: 8
    }
  }, "Note (optional)"), /*#__PURE__*/React.createElement(Input, {
    multiline: true,
    rows: 2,
    placeholder: "e.g. Assisted back to bed, no injury.",
    onChange: setNote,
    style: {
      borderRadius: CC
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 8,
      marginTop: 14
    }
  }, nexts.map(a => /*#__PURE__*/React.createElement(Button, {
    key: a,
    variant: KIND[a],
    fullWidth: true,
    onClick: () => a === 'Escalate' ? setConfirm(a) : onRespond(incident, a, note),
    style: {
      borderRadius: CC
    }
  }, a)))), confirm && /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'fixed',
      inset: 0,
      background: 'rgba(12,74,110,.35)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center'
    },
    onClick: () => setConfirm(null)
  }, /*#__PURE__*/React.createElement("div", {
    onClick: e => e.stopPropagation(),
    style: {
      background: '#fff',
      borderRadius: CR,
      padding: 20,
      width: 280
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontWeight: 600,
      marginBottom: 8
    }
  }, "Escalate alert"), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14,
      color: 'var(--color-foreground-muted)',
      marginBottom: 16
    }
  }, "Notify the on-call nurse and facility director?"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 8,
      justifyContent: 'flex-end'
    }
  }, /*#__PURE__*/React.createElement(Button, {
    size: "sm",
    variant: "secondary",
    onClick: () => setConfirm(null)
  }, "Cancel"), /*#__PURE__*/React.createElement(Button, {
    size: "sm",
    variant: "destructive",
    onClick: () => {
      setConfirm(null);
      onRespond(incident, 'Escalate', note);
    }
  }, "Escalate")))));
}
function ShiftHandoff({
  incidents
}) {
  const done = incidents.filter(i => i.status === 'Resolved').length;
  return /*#__PURE__*/React.createElement("div", {
    style: S.body
  }, /*#__PURE__*/React.createElement("div", {
    style: S.h1
  }, "Shift handoff"), /*#__PURE__*/React.createElement(Card, {
    style: {
      borderRadius: CR,
      marginBottom: 14
    }
  }, incidents.length, " alerts in the last 8 hours, ", done, " resolved, ", incidents.length - done, " still open."), /*#__PURE__*/React.createElement(Card, {
    style: {
      borderRadius: CR
    }
  }, incidents.map((i, idx) => /*#__PURE__*/React.createElement("div", {
    key: i.id,
    style: {
      display: 'flex',
      gap: 10,
      alignItems: 'flex-start',
      paddingTop: idx ? 12 : 0,
      marginTop: idx ? 12 : 0,
      borderTop: idx ? '1px solid var(--color-border)' : 'none'
    }
  }, /*#__PURE__*/React.createElement(Badge, {
    tone: i.status === 'Resolved' ? 'success' : i.severity
  }), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14,
      fontWeight: 500
    }
  }, i.copy), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12,
      color: 'var(--color-foreground-muted)'
    }
  }, i.status, " \xB7 ", i.time))))));
}
function LoginScreen({
  onSignIn
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      ...S.body,
      display: 'flex',
      flexDirection: 'column',
      justifyContent: 'center',
      padding: 24
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: 'center',
      marginBottom: 20
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-heading)',
      fontWeight: 600,
      fontSize: 26
    }
  }, "Meridian Care"), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14,
      color: 'var(--color-foreground-muted)',
      marginTop: 6
    }
  }, "Sign in to see live alerts for your facility.")), /*#__PURE__*/React.createElement(Card, {
    style: {
      borderRadius: CR,
      display: 'flex',
      flexDirection: 'column',
      gap: 10
    }
  }, /*#__PURE__*/React.createElement(Input, {
    placeholder: "Email",
    defaultValue: "jane@brightoaks.example",
    style: {
      borderRadius: CC
    }
  }), /*#__PURE__*/React.createElement(Input, {
    placeholder: "Password",
    type: "password",
    defaultValue: "\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022",
    style: {
      borderRadius: CC
    }
  }), /*#__PURE__*/React.createElement(Button, {
    fullWidth: true,
    onClick: onSignIn,
    style: {
      borderRadius: CC,
      marginTop: 4
    }
  }, "Sign in")));
}
function CareApp() {
  const [signedIn, setSignedIn] = React.useState(false);
  const [tab, setTab] = React.useState('alerts');
  const [open, setOpen] = React.useState(null);
  const [incidents, setIncidents] = React.useState(INCIDENTS);
  const respond = (incident, action, note) => {
    const status = action === 'Resolve' ? 'Resolved' : action === 'Escalate' ? 'Resolved' : action === 'Mark responding' ? 'Responding' : action === 'Dismiss as false alarm' ? 'Resolved' : 'Acknowledged';
    setIncidents(incidents.map(i => i.id === incident.id ? {
      ...i,
      status,
      resolutionNote: note || i.resolutionNote
    } : i));
    setOpen(null);
  };
  if (!signedIn) return /*#__PURE__*/React.createElement("div", {
    style: S.page
  }, /*#__PURE__*/React.createElement(LoginScreen, {
    onSignIn: () => setSignedIn(true)
  }));
  return /*#__PURE__*/React.createElement("div", {
    style: S.page
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '10px 16px 0',
      display: 'flex',
      justifyContent: 'space-between',
      fontSize: 12,
      fontWeight: 600,
      color: 'var(--color-foreground-muted)'
    }
  }, /*#__PURE__*/React.createElement("span", null, "9:41"), /*#__PURE__*/React.createElement("span", null, "Meridian Care"), /*#__PURE__*/React.createElement("span", null, "\u25CF\u25CF\u25CF")), tab === 'alerts' && (open ? /*#__PURE__*/React.createElement(IncidentDetail, {
    incident: incidents.find(i => i.id === open.id),
    onBack: () => setOpen(null),
    onRespond: respond
  }) : /*#__PURE__*/React.createElement(AlertsScreen, {
    incidents: incidents,
    onOpen: setOpen
  })), tab === 'handoff' && /*#__PURE__*/React.createElement(ShiftHandoff, {
    incidents: incidents
  }), tab === 'residents' && /*#__PURE__*/React.createElement("div", {
    style: {
      ...S.body,
      textAlign: 'center',
      color: 'var(--color-foreground-muted)',
      marginTop: 60
    }
  }, "Resident profiles \u2014 name, room, risk flags, care notes."), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      left: 0,
      right: 0,
      bottom: 0,
      display: 'flex',
      borderTop: '1px solid var(--color-border)',
      background: '#fff'
    }
  }, [['alerts', 'Alerts'], ['handoff', 'Handoff'], ['residents', 'Residents']].map(([k, label]) => /*#__PURE__*/React.createElement("div", {
    key: k,
    onClick: () => {
      setTab(k);
      setOpen(null);
    },
    style: {
      flex: 1,
      textAlign: 'center',
      padding: '10px 0',
      fontSize: 11,
      fontWeight: 600,
      color: tab === k ? 'var(--color-primary)' : 'var(--color-foreground-muted)',
      cursor: 'pointer',
      minHeight: 44
    }
  }, label))));
}
window.CareApp = CareApp;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/meridian_care/screens.jsx", error: String((e && e.message) || e) }); }

// ui_kits/meridian_family/screens.jsx
try { (() => {
const {
  Button,
  Input,
  Card
} = window.MeridianDesignSystem_91853d;
const CR = 'var(--radius-card-family)',
  CC = 'var(--radius-control-family)';
const S = {
  page: {
    background: 'var(--color-background-mobile)',
    height: '100%',
    display: 'flex',
    flexDirection: 'column',
    fontFamily: 'var(--font-body)',
    color: 'var(--color-foreground)'
  },
  body: {
    flex: 1,
    overflowY: 'auto',
    padding: '20px 20px 90px'
  },
  h1: {
    fontFamily: 'var(--font-heading)',
    fontWeight: 600,
    fontSize: 22,
    margin: '4px 0 16px'
  }
};
function DailySummary() {
  return /*#__PURE__*/React.createElement("div", {
    style: S.body
  }, /*#__PURE__*/React.createElement("div", {
    style: S.h1
  }, "Today"), /*#__PURE__*/React.createElement("div", {
    style: {
      background: 'rgba(5,150,105,.06)',
      border: '1px solid rgba(5,150,105,.2)',
      borderRadius: CR,
      padding: 20
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 12,
      alignItems: 'center'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 28
    }
  }, "\u2600"), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-heading)',
      fontWeight: 600,
      fontSize: 18
    }
  }, "Maggie had a good day"), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12,
      color: 'var(--color-foreground-muted)'
    }
  }, "August 7"))), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 15,
      color: 'var(--color-foreground-muted)',
      marginTop: 12
    }
  }, "Active and social today \u2014 joined morning activities, ate all three meals, and had one visitor."), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 1,
      background: 'var(--color-border)',
      margin: '14px 0'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 8,
      fontSize: 13,
      color: 'var(--color-foreground-muted)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--color-primary)'
    }
  }, "\u25CF"), "Visitor at 2:15pm"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 8,
      fontSize: 13,
      color: 'var(--color-foreground-muted)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--color-primary)'
    }
  }, "\u25CF"), "Joined group activity, 10:30am"))));
}
function Visitors() {
  const rows = [{
    time: 'Today, 2:15pm'
  }, {
    time: 'Yesterday, 4:40pm'
  }, {
    time: 'Aug 3, 11:05am'
  }];
  return /*#__PURE__*/React.createElement("div", {
    style: S.body
  }, /*#__PURE__*/React.createElement("div", {
    style: S.h1
  }, "Visitors"), /*#__PURE__*/React.createElement(Card, {
    style: {
      borderRadius: CR,
      display: 'flex',
      alignItems: 'center',
      gap: 10,
      marginBottom: 14
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 22,
      color: 'var(--color-primary)'
    }
  }, "\uD83D\uDEB6"), /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-heading)',
      fontWeight: 600,
      fontSize: 18
    }
  }, rows.length, " visitors this week")), /*#__PURE__*/React.createElement(Card, {
    style: {
      borderRadius: CR
    }
  }, rows.map((r, i) => /*#__PURE__*/React.createElement("div", {
    key: i,
    style: {
      display: 'flex',
      gap: 10,
      padding: i ? '10px 0' : '0 0 10px',
      borderTop: i ? '1px solid var(--color-border)' : 'none',
      fontSize: 14
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--color-primary-alt)'
    }
  }, "\uD83D\uDEAA"), "Visitor at ", r.time))));
}
function Updates() {
  const staff = [{
    text: 'Maggie needs help in Room 12 — staff responded in 90 seconds.',
    time: 'Today, 2:41pm'
  }];
  const visitors = [{
    text: 'New visitor detected at Main Entrance.',
    time: 'Today, 2:15pm'
  }];
  return /*#__PURE__*/React.createElement("div", {
    style: S.body
  }, /*#__PURE__*/React.createElement("div", {
    style: S.h1
  }, "Updates"), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12,
      fontWeight: 600,
      color: 'var(--color-foreground-muted)',
      textTransform: 'uppercase',
      marginBottom: 8
    }
  }, "Staff responses"), staff.map((n, i) => /*#__PURE__*/React.createElement(Card, {
    key: i,
    style: {
      borderRadius: CR,
      marginBottom: 10,
      display: 'flex',
      gap: 10
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--color-success)'
    }
  }, "\u2713"), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14
    }
  }, n.text), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12,
      color: 'var(--color-foreground-muted)',
      marginTop: 2
    }
  }, n.time)))), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12,
      fontWeight: 600,
      color: 'var(--color-foreground-muted)',
      textTransform: 'uppercase',
      margin: '16px 0 8px'
    }
  }, "Visitors"), visitors.map((n, i) => /*#__PURE__*/React.createElement(Card, {
    key: i,
    style: {
      borderRadius: CR,
      display: 'flex',
      gap: 10
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--color-primary)'
    }
  }, "\uD83D\uDEAA"), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14
    }
  }, n.text), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12,
      color: 'var(--color-foreground-muted)',
      marginTop: 2
    }
  }, n.time)))));
}
function Privacy({
  onSignOut
}) {
  const items = [['&#128274;', 'What you can see', 'Daily summaries, alert history, and visitor counts for the residents you\'re linked to. Nothing more.', 'var(--color-success)'], ['&#128683;', 'What you never see', 'Live or recorded video. Meridian processes video on-device at the facility and only sends alert data and pose information upstream.', 'var(--color-destructive)'], ['&#128100;', 'Visitor privacy', 'Unrecognized visitors are logged as anonymous observations, never identified people. You\'ll see a count and a time, never a name or photo.', 'var(--color-primary)']];
  return /*#__PURE__*/React.createElement("div", {
    style: S.body
  }, /*#__PURE__*/React.createElement("div", {
    style: S.h1
  }, "Privacy & account"), items.map((it, i) => /*#__PURE__*/React.createElement(Card, {
    key: i,
    style: {
      borderRadius: CR,
      marginBottom: 14
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 24,
      color: it[3]
    },
    dangerouslySetInnerHTML: {
      __html: it[0]
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-heading)',
      fontWeight: 600,
      fontSize: 16,
      margin: '8px 0 4px'
    }
  }, it[1]), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14,
      color: 'var(--color-foreground-muted)'
    }
  }, it[2]))), /*#__PURE__*/React.createElement(Button, {
    variant: "destructive",
    fullWidth: true,
    onClick: onSignOut,
    style: {
      borderRadius: CC
    }
  }, "Sign out"));
}
function LoginScreen({
  onSignIn
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      ...S.body,
      display: 'flex',
      flexDirection: 'column',
      justifyContent: 'center'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: 'center',
      marginBottom: 20
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-heading)',
      fontWeight: 600,
      fontSize: 26
    }
  }, "Meridian Family"), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14,
      color: 'var(--color-foreground-muted)',
      marginTop: 6
    }
  }, "See how your family member is doing today.")), /*#__PURE__*/React.createElement(Card, {
    style: {
      borderRadius: CR,
      display: 'flex',
      flexDirection: 'column',
      gap: 10
    }
  }, /*#__PURE__*/React.createElement(Input, {
    placeholder: "Email",
    defaultValue: "son@example.com",
    style: {
      borderRadius: CC
    }
  }), /*#__PURE__*/React.createElement(Input, {
    placeholder: "Password",
    type: "password",
    defaultValue: "\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022",
    style: {
      borderRadius: CC
    }
  }), /*#__PURE__*/React.createElement(Button, {
    fullWidth: true,
    onClick: onSignIn,
    style: {
      borderRadius: CC,
      marginTop: 4
    }
  }, "Sign in")));
}
function FamilyApp() {
  const [signedIn, setSignedIn] = React.useState(false);
  const [tab, setTab] = React.useState('today');
  if (!signedIn) return /*#__PURE__*/React.createElement("div", {
    style: S.page
  }, /*#__PURE__*/React.createElement(LoginScreen, {
    onSignIn: () => setSignedIn(true)
  }));
  const PAGES = {
    today: DailySummary,
    visitors: Visitors,
    updates: Updates,
    privacy: () => /*#__PURE__*/React.createElement(Privacy, {
      onSignOut: () => setSignedIn(false)
    })
  };
  const Page = PAGES[tab];
  return /*#__PURE__*/React.createElement("div", {
    style: S.page
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '10px 16px 0',
      display: 'flex',
      justifyContent: 'space-between',
      fontSize: 12,
      fontWeight: 600,
      color: 'var(--color-foreground-muted)'
    }
  }, /*#__PURE__*/React.createElement("span", null, "9:41"), /*#__PURE__*/React.createElement("span", null, "Meridian Family"), /*#__PURE__*/React.createElement("span", null, "\u25CF\u25CF\u25CF")), /*#__PURE__*/React.createElement(Page, null), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      left: 0,
      right: 0,
      bottom: 0,
      display: 'flex',
      borderTop: '1px solid var(--color-border)',
      background: '#fff'
    }
  }, [['today', 'Today'], ['visitors', 'Visitors'], ['updates', 'Updates'], ['privacy', 'Privacy']].map(([k, label]) => /*#__PURE__*/React.createElement("div", {
    key: k,
    onClick: () => setTab(k),
    style: {
      flex: 1,
      textAlign: 'center',
      padding: '10px 0',
      fontSize: 11,
      fontWeight: 600,
      color: tab === k ? 'var(--color-primary)' : 'var(--color-foreground-muted)',
      cursor: 'pointer',
      minHeight: 44
    }
  }, label))));
}
window.FamilyApp = FamilyApp;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/meridian_family/screens.jsx", error: String((e && e.message) || e) }); }

// ui_kits/meridian_hub/kiosk.jsx
try { (() => {
const S = {
  shell: {
    width: 'min(100%,720px)',
    margin: '0 auto',
    padding: '28px 24px 48px',
    fontFamily: 'var(--font-body)',
    color: 'var(--color-foreground)',
    background: 'var(--color-background-mobile)',
    minHeight: '100vh',
    boxSizing: 'border-box'
  },
  actionBtn: (bg, color) => ({
    minHeight: 112,
    width: '100%',
    border: 'none',
    borderRadius: 18,
    padding: 20,
    background: bg,
    color,
    fontSize: 22,
    fontWeight: 800,
    textAlign: 'left',
    cursor: 'pointer',
    display: 'flex',
    flexDirection: 'column',
    gap: 6
  })
};
function ActionGrid({
  onRequest
}) {
  return /*#__PURE__*/React.createElement("section", {
    style: {
      display: 'grid',
      gap: 16,
      gridTemplateColumns: 'repeat(auto-fit,minmax(230px,1fr))',
      marginTop: 28
    }
  }, /*#__PURE__*/React.createElement("button", {
    style: S.actionBtn('var(--color-primary)', '#fff'),
    onClick: () => onRequest('assistance')
  }, "Request assistance", /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 15,
      fontWeight: 600
    }
  }, "Ask a caregiver to come to your room.")), /*#__PURE__*/React.createElement("button", {
    style: S.actionBtn('#fff', 'var(--color-foreground)'),
    onClick: () => onRequest('family')
  }, "Call family", /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 15,
      fontWeight: 600,
      color: 'var(--color-foreground-muted)'
    }
  }, "Ask your consented family contact to call you.")), /*#__PURE__*/React.createElement("button", {
    style: S.actionBtn('var(--color-destructive)', '#fff'),
    onClick: () => onRequest('emergency')
  }, "Emergency help", /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 15,
      fontWeight: 600
    }
  }, "Send an urgent alert to the care team now.")));
}
function HelpStatus({
  kind,
  onReset
}) {
  const copy = {
    assistance: 'Your request was sent to the care team.',
    family: 'Your request was sent to the care team.',
    emergency: 'A fall was detected. Help was requested automatically.'
  }[kind] || 'Help is coming.';
  return /*#__PURE__*/React.createElement("section", {
    style: {
      marginTop: 24,
      padding: 28,
      background: '#fff',
      borderRadius: 20,
      boxShadow: '0 4px 18px rgba(12,74,110,.12)',
      borderLeft: '10px solid var(--color-primary)'
    }
  }, /*#__PURE__*/React.createElement("p", {
    style: {
      color: 'var(--color-foreground-muted)',
      fontWeight: 700,
      margin: '0 0 8px'
    }
  }, "Live help status"), /*#__PURE__*/React.createElement("h2", {
    style: {
      fontSize: 32,
      lineHeight: 1.15,
      margin: 0
    }
  }, copy), /*#__PURE__*/React.createElement("p", {
    style: {
      fontSize: 18,
      color: 'var(--color-foreground-muted)',
      margin: '12px 0 0'
    }
  }, "Status: open"), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 18,
      padding: 16,
      background: 'var(--color-border)',
      borderRadius: 12,
      fontWeight: 800
    }
  }, "Estimated response time: about 2 minutes", /*#__PURE__*/React.createElement("small", {
    style: {
      display: 'block',
      color: 'var(--color-foreground-muted)',
      fontWeight: 600,
      marginTop: 6
    }
  }, "Based on this facility's recent staff acknowledgement times.")), /*#__PURE__*/React.createElement("button", {
    onClick: onReset,
    style: {
      marginTop: 18,
      background: 'none',
      border: 'none',
      color: 'var(--color-primary)',
      fontWeight: 700,
      fontSize: 15,
      cursor: 'pointer'
    }
  }, "Cancel request"));
}
function VisitorVerification({
  onAnswer
}) {
  return /*#__PURE__*/React.createElement("section", {
    style: {
      marginTop: 24,
      padding: 28,
      background: '#fff',
      borderRadius: 20,
      border: '4px solid var(--color-primary)'
    }
  }, /*#__PURE__*/React.createElement("p", {
    style: {
      color: 'var(--color-foreground-muted)',
      fontWeight: 700,
      margin: '0 0 8px'
    }
  }, "Visitor check"), /*#__PURE__*/React.createElement("h2", {
    style: {
      fontSize: 28,
      lineHeight: 1.1,
      margin: 0
    }
  }, "Is this person expected?"), /*#__PURE__*/React.createElement("p", {
    style: {
      color: 'var(--color-foreground-muted)',
      fontSize: 19,
      margin: '18px 0'
    }
  }, "An unfamiliar visitor was detected at your assigned entry camera. Detected at 2:15pm."), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: '1fr 1fr',
      gap: 16
    }
  }, /*#__PURE__*/React.createElement("button", {
    onClick: () => onAnswer(true),
    style: {
      minHeight: 88,
      borderRadius: 16,
      border: 'none',
      color: '#fff',
      background: 'var(--color-success)',
      fontSize: 20,
      fontWeight: 800,
      cursor: 'pointer'
    }
  }, "Yes, expected"), /*#__PURE__*/React.createElement("button", {
    onClick: () => onAnswer(false),
    style: {
      minHeight: 88,
      borderRadius: 16,
      border: 'none',
      color: '#fff',
      background: 'var(--color-destructive)',
      fontSize: 20,
      fontWeight: 800,
      cursor: 'pointer'
    }
  }, "No, get help")));
}
function HubApp() {
  const [request, setRequest] = React.useState(null);
  const [prompt, setPrompt] = React.useState(true);
  const [msg, setMsg] = React.useState(null);
  return /*#__PURE__*/React.createElement("main", {
    style: S.shell
  }, /*#__PURE__*/React.createElement("header", null, /*#__PURE__*/React.createElement("p", {
    style: {
      color: 'var(--color-foreground-muted)',
      fontWeight: 700,
      margin: '0 0 8px'
    }
  }, "MeridianHub \xB7 Room 12"), /*#__PURE__*/React.createElement("h1", {
    style: {
      fontSize: 'clamp(2.25rem,6vw,3.5rem)',
      lineHeight: 1.08,
      margin: 0,
      fontWeight: 800,
      letterSpacing: '-0.03em'
    }
  }, "Hello, Maggie"), /*#__PURE__*/React.createElement("p", {
    style: {
      color: 'var(--color-foreground-muted)',
      fontSize: 'clamp(1.1rem,3vw,1.4rem)',
      margin: '16px 0 0'
    }
  }, "Choose what you need. Your care team is here to help.")), msg && /*#__PURE__*/React.createElement("div", {
    style: {
      margin: '18px 0',
      padding: 16,
      border: '3px solid var(--color-destructive)',
      borderRadius: 14,
      background: '#fff',
      color: 'var(--color-destructive)',
      fontWeight: 800
    }
  }, msg), request ? /*#__PURE__*/React.createElement(HelpStatus, {
    kind: request,
    onReset: () => setRequest(null)
  }) : /*#__PURE__*/React.createElement(ActionGrid, {
    onRequest: k => {
      setRequest(k);
      setMsg(null);
    }
  }), prompt && /*#__PURE__*/React.createElement(VisitorVerification, {
    onAnswer: ok => {
      setPrompt(false);
      setMsg(ok ? null : 'The care team has been notified to check in.');
    }
  }));
}
window.HubApp = HubApp;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/meridian_hub/kiosk.jsx", error: String((e && e.message) || e) }); }

// ui_kits/meridian_insights/dashboard.jsx
try { (() => {
const {
  Badge,
  Card,
  BulletChart,
  TrendLineChart,
  Tag
} = window.MeridianDesignSystem_91853d;
const S = {
  shell: {
    display: 'flex',
    minHeight: '100vh',
    fontFamily: 'var(--font-body)',
    background: 'var(--color-background)',
    color: 'var(--color-foreground)'
  },
  aside: {
    width: 240,
    flex: 'none',
    borderRight: '1px solid var(--color-border)',
    background: 'rgba(255,255,255,.6)',
    padding: 16,
    display: 'flex',
    flexDirection: 'column'
  },
  main: {
    flex: 1,
    minWidth: 0,
    padding: '28px 32px'
  },
  navItem: active => ({
    display: 'flex',
    alignItems: 'center',
    gap: 10,
    borderRadius: 'var(--radius-control)',
    padding: '10px 14px',
    fontSize: 14,
    fontWeight: 500,
    cursor: 'pointer',
    background: active ? 'var(--color-primary)' : 'transparent',
    color: active ? 'var(--color-on-primary)' : 'var(--color-foreground)',
    marginBottom: 2
  })
};
const NAV = [['floor', 'Floor status'], ['analytics', 'Response analytics'], ['incidents', 'Incident reports'], ['visitors', 'Visitor observations']];
const RESIDENTS = [{
  id: 'r1',
  name: 'Maggie Chen',
  room: 'Room 12',
  incident: {
    id: 'i1',
    type: 'Fall confirmed',
    severity: 'critical',
    detected: '2m ago'
  },
  flags: ['fall history']
}, {
  id: 'r2',
  name: 'Walter Osei',
  room: 'Room 4',
  incident: null,
  flags: ['mobility aid']
}, {
  id: 'r3',
  name: 'Ruth Alvarez',
  room: 'Room 9',
  incident: {
    id: 'i2',
    type: 'Long lie',
    severity: 'warning',
    detected: '14m ago'
  },
  flags: []
}, {
  id: 'r4',
  name: 'Dorothy Lin',
  room: 'Room 7',
  incident: null,
  flags: ['dementia']
}, {
  id: 'r5',
  name: 'Sam Idris',
  room: 'Room 18',
  incident: null,
  flags: []
}, {
  id: 'r6',
  name: 'Camera 3 (Hallway)',
  room: 'Device',
  incident: null,
  flags: [],
  offline: true
}];
function FloorStatus() {
  return /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("h1", {
    style: {
      fontFamily: 'var(--font-heading)',
      fontSize: 24,
      fontWeight: 600,
      margin: 0
    }
  }, "Live floor status"), /*#__PURE__*/React.createElement("p", {
    style: {
      fontSize: 14,
      color: 'var(--color-foreground-muted)',
      marginTop: 4
    }
  }, "One card per resident, updating live as incidents are detected and resolved."), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 8,
      fontSize: 12,
      color: 'var(--color-foreground-muted)',
      margin: '16px 0'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: 8,
      height: 8,
      borderRadius: 999,
      background: 'var(--color-success)',
      display: 'inline-block'
    }
  }), "Live"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: 'repeat(auto-fit,minmax(220px,1fr))',
      gap: 16
    }
  }, RESIDENTS.map(r => {
    const status = r.offline ? 'offline' : r.incident ? 'critical' : 'success';
    return /*#__PURE__*/React.createElement(Card, {
      key: r.id,
      style: {
        cursor: 'pointer',
        outline: r.incident && r.incident.severity === 'critical' ? '2px solid rgba(220,38,38,.4)' : 'none'
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        display: 'flex',
        justifyContent: 'space-between',
        gap: 8,
        marginBottom: 10
      }
    }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
      style: {
        fontWeight: 600
      }
    }, r.name), /*#__PURE__*/React.createElement("div", {
      style: {
        fontSize: 12,
        color: 'var(--color-foreground-muted)'
      }
    }, r.room)), /*#__PURE__*/React.createElement(Badge, {
      tone: r.offline ? 'offline' : r.incident ? r.incident.severity : 'success'
    }, r.offline ? 'Offline' : r.incident ? undefined : 'Normal')), r.incident ? /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
      style: {
        fontWeight: 500,
        fontSize: 14
      }
    }, r.incident.type), /*#__PURE__*/React.createElement("div", {
      style: {
        fontSize: 12,
        color: 'var(--color-foreground-muted)'
      }
    }, r.incident.detected)) : /*#__PURE__*/React.createElement("div", {
      style: {
        fontSize: 14,
        color: 'var(--color-foreground-muted)'
      }
    }, "No open incidents"), r.flags.length > 0 && /*#__PURE__*/React.createElement("div", {
      style: {
        display: 'flex',
        gap: 6,
        flexWrap: 'wrap',
        marginTop: 10
      }
    }, r.flags.map(f => /*#__PURE__*/React.createElement(Tag, {
      key: f
    }, f))));
  })));
}
function Analytics() {
  return /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("h1", {
    style: {
      fontFamily: 'var(--font-heading)',
      fontSize: 24,
      fontWeight: 600,
      margin: 0
    }
  }, "Response-time analytics"), /*#__PURE__*/React.createElement("p", {
    style: {
      fontSize: 14,
      color: 'var(--color-foreground-muted)',
      marginTop: 4
    }
  }, "Average time from alert detected to caregiver acknowledgment, by shift."), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: 'repeat(auto-fit,minmax(220px,1fr))',
      gap: 16,
      marginTop: 20
    }
  }, /*#__PURE__*/React.createElement(BulletChart, {
    label: "Night shift",
    sublabel: "Aug 6",
    valueSeconds: 92,
    incidentCount: 2
  }), /*#__PURE__*/React.createElement(BulletChart, {
    label: "Day shift",
    sublabel: "Aug 6",
    valueSeconds: 142,
    incidentCount: 4
  }), /*#__PURE__*/React.createElement(BulletChart, {
    label: "Evening shift",
    sublabel: "Aug 6",
    valueSeconds: null,
    incidentCount: 0
  })), /*#__PURE__*/React.createElement("h2", {
    style: {
      fontFamily: 'var(--font-heading)',
      fontSize: 18,
      fontWeight: 600,
      marginTop: 32
    }
  }, "Weekly incident trend"), /*#__PURE__*/React.createElement(TrendLineChart, {
    data: [{
      weekLabel: 'Jul 14',
      counts: {
        fall_confirmed: 1,
        fall_suspected: 2,
        long_lie: 0,
        unusual_inactivity: 1
      }
    }, {
      weekLabel: 'Jul 21',
      counts: {
        fall_confirmed: 0,
        fall_suspected: 1,
        long_lie: 1,
        unusual_inactivity: 2
      }
    }, {
      weekLabel: 'Jul 28',
      counts: {
        fall_confirmed: 2,
        fall_suspected: 1,
        long_lie: 1,
        unusual_inactivity: 1
      }
    }]
  }));
}
function Incidents() {
  const rows = RESIDENTS.filter(r => r.incident).concat([{
    id: 'r9',
    name: 'Ruth Alvarez',
    room: 'Room 9',
    incident: {
      id: 'i3',
      type: 'Fall suspected',
      severity: 'warning',
      detected: 'Aug 5, 9:14pm'
    },
    flags: [],
    resolved: true
  }]);
  return /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("h1", {
    style: {
      fontFamily: 'var(--font-heading)',
      fontSize: 24,
      fontWeight: 600,
      margin: 0
    }
  }, "Incident reports"), /*#__PURE__*/React.createElement("p", {
    style: {
      fontSize: 14,
      color: 'var(--color-foreground-muted)',
      marginTop: 4
    }
  }, "Auto-generated for compliance and liability documentation."), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 20,
      background: 'var(--color-surface)',
      border: '1px solid var(--color-border)',
      borderRadius: 'var(--radius-card)',
      boxShadow: 'var(--shadow-soft)',
      overflow: 'hidden'
    }
  }, rows.map((r, i) => /*#__PURE__*/React.createElement("div", {
    key: r.id,
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 16,
      padding: '14px 18px',
      borderTop: i ? '1px solid var(--color-border)' : 'none'
    }
  }, /*#__PURE__*/React.createElement(Badge, {
    tone: r.resolved ? 'success' : r.incident.severity
  }, r.resolved ? 'Resolved' : undefined), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontWeight: 500,
      fontSize: 14
    }
  }, r.incident.type, " \u2014 ", r.name), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12,
      color: 'var(--color-foreground-muted)'
    }
  }, r.room, " \xB7 ", r.incident.detected))))));
}
function Visitors() {
  const rows = [{
    time: 'Today, 2:41pm',
    camera: 'Main Entrance'
  }, {
    time: 'Today, 11:02am',
    camera: 'Side Door'
  }, {
    time: 'Yesterday, 6:15pm',
    camera: 'Main Entrance'
  }];
  return /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("h1", {
    style: {
      fontFamily: 'var(--font-heading)',
      fontSize: 24,
      fontWeight: 600,
      margin: 0
    }
  }, "Visitor observations"), /*#__PURE__*/React.createElement("p", {
    style: {
      fontSize: 14,
      color: 'var(--color-foreground-muted)',
      marginTop: 4,
      maxWidth: 560
    }
  }, "Unrecognized faces at entry points are logged as anonymous observations \u2014 never a name or photo, per the privacy architecture."), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 20,
      background: 'var(--color-surface)',
      border: '1px solid var(--color-border)',
      borderRadius: 'var(--radius-card)',
      boxShadow: 'var(--shadow-soft)',
      overflow: 'hidden'
    }
  }, rows.map((r, i) => /*#__PURE__*/React.createElement("div", {
    key: i,
    style: {
      display: 'flex',
      justifyContent: 'space-between',
      padding: '14px 18px',
      borderTop: i ? '1px solid var(--color-border)' : 'none',
      fontSize: 14
    }
  }, /*#__PURE__*/React.createElement("span", null, "New visitor detected at ", r.camera), /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--color-foreground-muted)'
    }
  }, r.time)))));
}
function LoginPage({
  onLogin
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      minHeight: '100vh',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      background: 'var(--color-background)'
    }
  }, /*#__PURE__*/React.createElement("form", {
    onSubmit: e => {
      e.preventDefault();
      onLogin();
    },
    style: {
      background: 'var(--color-surface)',
      border: '1px solid var(--color-border)',
      borderRadius: 'var(--radius-card)',
      boxShadow: 'var(--shadow-soft)',
      padding: 28,
      width: 340
    }
  }, /*#__PURE__*/React.createElement("p", {
    style: {
      fontFamily: 'var(--font-heading)',
      fontWeight: 600,
      fontSize: 20,
      margin: '0 0 4px'
    }
  }, "Meridian Insights"), /*#__PURE__*/React.createElement("p", {
    style: {
      fontSize: 13,
      color: 'var(--color-foreground-muted)',
      margin: '0 0 20px'
    }
  }, "Sign in to your facility dashboard."), /*#__PURE__*/React.createElement("label", {
    style: {
      display: 'block',
      fontSize: 14,
      fontWeight: 500,
      marginBottom: 6
    }
  }, "Email"), /*#__PURE__*/React.createElement("input", {
    type: "email",
    required: true,
    defaultValue: "director@brightoaks.example",
    style: {
      width: '100%',
      borderRadius: 'var(--radius-control)',
      border: '1px solid var(--color-border)',
      padding: '10px 14px',
      fontSize: 16,
      marginBottom: 14,
      boxSizing: 'border-box'
    }
  }), /*#__PURE__*/React.createElement("label", {
    style: {
      display: 'block',
      fontSize: 14,
      fontWeight: 500,
      marginBottom: 6
    }
  }, "Password"), /*#__PURE__*/React.createElement("input", {
    type: "password",
    required: true,
    defaultValue: "\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022",
    style: {
      width: '100%',
      borderRadius: 'var(--radius-control)',
      border: '1px solid var(--color-border)',
      padding: '10px 14px',
      fontSize: 16,
      marginBottom: 20,
      boxSizing: 'border-box'
    }
  }), /*#__PURE__*/React.createElement("button", {
    type: "submit",
    style: {
      width: '100%',
      borderRadius: 'var(--radius-control)',
      border: 'none',
      background: 'var(--color-primary)',
      color: 'var(--color-on-primary)',
      padding: '11px',
      fontSize: 16,
      fontWeight: 500,
      cursor: 'pointer'
    }
  }, "Sign in")));
}
function InsightsApp() {
  const [signedIn, setSignedIn] = React.useState(false);
  const [tab, setTab] = React.useState('floor');
  if (!signedIn) return /*#__PURE__*/React.createElement(LoginPage, {
    onLogin: () => setSignedIn(true)
  });
  const PAGES = {
    floor: FloorStatus,
    analytics: Analytics,
    incidents: Incidents,
    visitors: Visitors
  };
  const Page = PAGES[tab];
  return /*#__PURE__*/React.createElement("div", {
    style: S.shell
  }, /*#__PURE__*/React.createElement("aside", {
    style: S.aside
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 2px 20px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontWeight: 600,
      fontSize: 17
    }
  }, "Meridian"), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12,
      color: 'var(--color-foreground-muted)'
    }
  }, "Insights")), NAV.map(([k, label]) => /*#__PURE__*/React.createElement("div", {
    key: k,
    style: S.navItem(tab === k),
    onClick: () => setTab(k)
  }, label)), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 'auto',
      paddingTop: 16,
      borderTop: '1px solid var(--color-border)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      fontWeight: 500
    }
  }, "Bright Oaks Assisted Living"), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12,
      color: 'var(--color-foreground-muted)'
    }
  }, "director@brightoaks.example \xB7 admin"), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 10,
      fontSize: 14,
      cursor: 'pointer',
      color: 'var(--color-foreground)'
    },
    onClick: () => setSignedIn(false)
  }, "Sign out"))), /*#__PURE__*/React.createElement("main", {
    style: S.main
  }, /*#__PURE__*/React.createElement(Page, null)));
}
window.InsightsApp = InsightsApp;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/meridian_insights/dashboard.jsx", error: String((e && e.message) || e) }); }

__ds_ns.BulletChart = __ds_scope.BulletChart;

__ds_ns.TrendLineChart = __ds_scope.TrendLineChart;

__ds_ns.Badge = __ds_scope.Badge;

__ds_ns.Card = __ds_scope.Card;

__ds_ns.Tag = __ds_scope.Tag;

__ds_ns.Dialog = __ds_scope.Dialog;

__ds_ns.Toast = __ds_scope.Toast;

__ds_ns.Tooltip = __ds_scope.Tooltip;

__ds_ns.Button = __ds_scope.Button;

__ds_ns.Checkbox = __ds_scope.Checkbox;

__ds_ns.IconButton = __ds_scope.IconButton;

__ds_ns.Input = __ds_scope.Input;

__ds_ns.Radio = __ds_scope.Radio;

__ds_ns.Select = __ds_scope.Select;

__ds_ns.Switch = __ds_scope.Switch;

__ds_ns.Tabs = __ds_scope.Tabs;

})();
