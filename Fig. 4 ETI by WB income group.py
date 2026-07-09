# Fig. 4 ETI and its sub-index trends by IMF regional classification during 2000–2023.

import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
import matplotlib.ticker as ticker
from google.colab import files

# ── Load data ──────────────────────────────────────────────────────────────────
uploaded_data = files.upload()
filename = list(uploaded_data.keys())[0]
df = pd.read_excel(filename)
df = df.dropna(subset=['income_group'])

ig_order  = ['LIC', 'LMIC', 'UMIC', 'HIC']
ig_labels = {
    'LIC':  'Low Income (LIC)',
    'LMIC': 'Lower-Middle Income (LMIC)',
    'UMIC': 'Upper-Middle Income (UMIC)',
    'HIC':  'High Income (HIC)',
}
ig_short = {'LIC': 'LIC', 'LMIC': 'LMIC', 'UMIC': 'UMIC', 'HIC': 'HIC'}

colors  = {'LIC': '#C0392B', 'LMIC': '#E67E22', 'UMIC': '#27AE60', 'HIC': '#2980B9'}
markers = {'LIC': 'o',       'LMIC': 's',        'UMIC': '^',       'HIC': 'D'}

mean_ig = (df.groupby(['income_group', 'year'])[['eti', 'esp', 'tr']]
             .mean().reset_index())

# ── Gap closure calculation (ESP - TR) ──────────────────────────────────
gap_df = mean_ig[mean_ig['year'].isin([2000, 2023])].copy()
gap_df['gap'] = gap_df['esp'] - gap_df['tr']

gap_wide = gap_df.pivot(index='income_group', columns='year', values='gap')
gap_wide.columns = ['gap_2000', 'gap_2023']
gap_wide['pct_gap_closed'] = (
    (gap_wide['gap_2000'] - gap_wide['gap_2023']) / gap_wide['gap_2000'] * 100
)

gap_wide = gap_wide.reindex(ig_order)  
print(gap_wide.round(2))

plt.rcParams.update({
    'font.family':       'DejaVu Sans',
    'font.size':         10,
    'axes.spines.top':   False,
    'axes.spines.right': False,
    'axes.grid':         True,
    'axes.grid.axis':    'y',
    'grid.color':        '#E8E8E8',
    'grid.linewidth':    0.8,
    'axes.axisbelow':    True,
})

PARIS_COLOR = '#222222'   
PARIS_FS    = 8

KYOTO_COLOR = '#222222'   
KYOTO_FS    = 8

# panel label + income group name on same line above panel
def add_panel_label(ax, letter, ig_name=None, fontsize=11):
    if ig_name:
        ax.text(-0.08, 1.06, f'({letter}) ',
                transform=ax.transAxes,
                fontsize=fontsize, fontweight='bold',
                va='bottom', ha='left', color='black')
        ax.text(0.02, 1.06, ig_name,
                transform=ax.transAxes,
                fontsize=fontsize - 0.5, fontweight='bold',
                va='bottom', ha='left', color='black')
    else:
        ax.text(-0.08, 1.04, f'({letter})',
                transform=ax.transAxes,
                fontsize=fontsize, fontweight='bold',
                va='bottom', ha='left', color='black')

# ── Layout ─────────────────────────────────────────────────────────────────────
fig = plt.figure(figsize=(13, 14.5))

gs = gridspec.GridSpec(
    2, 1,
    height_ratios=[1, 1.15],
    hspace=0.32,
    left=0.07, right=0.95,
    top=0.96, bottom=0.04
)

# ══════════════════════════════════════════════════════════════════════════════
# (a) TOP PANEL — ETI by income group
# ══════════════════════════════════════════════════════════════════════════════
ax1 = fig.add_subplot(gs[0])
add_panel_label(ax1, 'a')

lines, lbls = [], []
for ig in ig_order:
    sub = mean_ig[mean_ig['income_group'] == ig].sort_values('year')
    ln, = ax1.plot(sub['year'], sub['eti'],
                   color=colors[ig], marker=markers[ig],
                   markersize=5, linewidth=1.8,
                   label=ig_labels[ig])
    lines.append(ln)
    lbls.append(ig_labels[ig])
    last = sub.iloc[-1]
    ax1.text(last['year'] + 0.3, last['eti'],
             ig_short[ig], color=colors[ig], fontsize=8.5, va='center')

# Kyoto Protocol (2005)
ax1.axvline(2005, color=KYOTO_COLOR, linewidth=1.1, linestyle=':', zorder=1)
ax1.text(2005.25, 20.8,
         'Kyoto Protocol (2005)',
         fontsize=KYOTO_FS, color=KYOTO_COLOR, va='bottom')

# Paris Agreement (2015)
ax1.axvline(2015, color=PARIS_COLOR, linewidth=1.1, linestyle='--', zorder=1)
ax1.text(2015.25, 20.8,
         'Paris Agreement (2015)',
         fontsize=PARIS_FS, color=PARIS_COLOR, va='bottom')

ax1.set_xlim(1999, 2023.8)          # ends at 2023
ax1.set_ylim(20, 72)
ax1.set_ylabel('Mean ETI Score (0–100)', fontsize=10)
ax1.set_xlabel('Year', fontsize=10)
ax1.xaxis.set_major_locator(ticker.MultipleLocator(5))
ax1.tick_params(labelsize=9)

ax1.legend(lines, lbls,
           ncol=4,
           loc='upper center',
           bbox_to_anchor=(0.5, -0.18),
           fontsize=9, frameon=False,
           columnspacing=1.5, handlelength=2.0)

# ══════════════════════════════════════════════════════════════════════════════
# (b)–(e) BOTTOM 2×2 — ESP & TR per income group
# ══════════════════════════════════════════════════════════════════════════════
gs2 = gridspec.GridSpecFromSubplotSpec(
    2, 2, subplot_spec=gs[1],
    hspace=0.55, wspace=0.28
)

panel_letters = ['b', 'c', 'd', 'e']

for i, ig in enumerate(ig_order):
    row, col = divmod(i, 2)
    ax = fig.add_subplot(gs2[row, col])

    # label + income group name above panel in black
    add_panel_label(ax, panel_letters[i], ig_labels[ig])

    sub = mean_ig[mean_ig['income_group'] == ig].sort_values('year')

    ax.plot(sub['year'], sub['esp'],
            color=colors[ig], linewidth=1.8,
            marker=markers[ig], markersize=4.5)

    ax.plot(sub['year'], sub['tr'],
            color=colors[ig], linewidth=1.5,
            linestyle=(0, (4, 2)),
            marker=markers[ig], markersize=4.5,
            markerfacecolor='white', markeredgewidth=1.3)

    last_yr = sub['year'].max()
    esp_val = sub.loc[sub['year'] == last_yr, 'esp'].values[0]
    tr_val  = sub.loc[sub['year'] == last_yr, 'tr'].values[0]
    ax.text(last_yr + 0.3, esp_val, 'ESP',
            color=colors[ig], fontsize=8.5, va='center')
    ax.text(last_yr + 0.3, tr_val,  'TR',
            color=colors[ig], fontsize=8.5, va='center', fontstyle='italic')

    # Kyoto Protocol (2005)
    ax.axvline(2005, color=KYOTO_COLOR, linewidth=1.0, linestyle=':', zorder=1)
    ax.text(2005.25, 11, 'Kyoto Protocol (2005)',
            fontsize=7, color=KYOTO_COLOR, va='bottom')

    # Paris Agreement (2015)
    ax.axvline(2015, color=PARIS_COLOR, linewidth=1.0, linestyle='--', zorder=1)
    ax.text(2015.25, 11, 'Paris Agreement (2015)',
            fontsize=7, color=PARIS_COLOR, va='bottom')

    ax.set_xlabel('Year', fontsize=8.5)
    ax.set_xlim(1999, 2023.8)       # ends at 2023
    ax.set_ylim(10, 82)
    ax.set_ylabel('Score (0–100)', fontsize=8.5)
    ax.xaxis.set_major_locator(ticker.MultipleLocator(5))
    ax.tick_params(labelsize=8)

# ── Save + Download ────────────────────────────────────────────────────────────
output_file = 'Fig_IG_combined.png'
plt.savefig(output_file, dpi=600, bbox_inches='tight',
            facecolor='white', format='png')
plt.show()
print(f"Saved — {output_file}")
files.download(output_file)
