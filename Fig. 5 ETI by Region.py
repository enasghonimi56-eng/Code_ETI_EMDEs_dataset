# Fig. 5 ETI and its sub-index trends by IMF regional classification during 2000–2023.

import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
import matplotlib.ticker as ticker
from google.colab import files

# ── Load data ──────────────────────────────────────────────────────────────────
uploaded_data = files.upload()
filename = list(uploaded_data.keys())[0]
df = pd.read_excel(filename)
df = df.dropna(subset=['region'])

reg_order  = ['EDA', 'EDE', 'LAC', 'SSA', 'MECA']
reg_labels = {
    'EDA':  'Emerging & Developing Asia (EDA)',
    'EDE':  'Emerging & Developing Europe (EDE)',
    'LAC':  'Latin America & the Caribbean (LAC)',
    'SSA':  'Sub-Saharan Africa (SSA)',
    'MECA': 'Middle East & Central Asia (MECA)',
}
reg_short = {'EDA': 'EDA', 'EDE': 'EDE', 'LAC': 'LAC', 'SSA': 'SSA', 'MECA': 'MECA'}

colors  = {
    'EDA':  '#2980B9',
    'EDE':  '#8E44AD',
    'LAC':  '#27AE60',
    'SSA':  '#C0392B',
    'MECA': '#E67E22',
}
markers = {'EDA': 'o', 'EDE': 's', 'LAC': '^', 'SSA': 'D', 'MECA': 'P'}

mean_reg = (df.groupby(['region', 'year'])[['eti', 'esp', 'tr']]
              .mean().reset_index())

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

# panel label + region name on the same line above the panel
def add_panel_label(ax, letter, reg_name=None, reg_color='black', fontsize=11):
    if reg_name:
        # (b) Region Name — bold letter then colored region name
        ax.text(-0.08, 1.06,
                f'({letter}) ',
                transform=ax.transAxes,
                fontsize=fontsize, fontweight='bold',
                va='bottom', ha='left', color='black')
        ax.text(0.02, 1.06,
                reg_name,
                transform=ax.transAxes,
                fontsize=fontsize - 0.5, fontweight='bold',
                va='bottom', ha='left', color='black')
    else:
        ax.text(-0.08, 1.04, f'({letter})',
                transform=ax.transAxes,
                fontsize=fontsize, fontweight='bold',
                va='bottom', ha='left')

# ── Layout ─────────────────────────────────────────────────────────────────────
fig = plt.figure(figsize=(15, 15))

gs = gridspec.GridSpec(
    2, 1,
    height_ratios=[1, 1.3],
    hspace=0.32,
    left=0.07, right=0.97,
    top=0.96, bottom=0.04
)

# ══════════════════════════════════════════════════════════════════════════════
# (a) TOP PANEL — ETI by region
# ══════════════════════════════════════════════════════════════════════════════
ax1 = fig.add_subplot(gs[0])
add_panel_label(ax1, 'a')

lines, lbls = [], []
for reg in reg_order:
    sub = mean_reg[mean_reg['region'] == reg].sort_values('year')
    ln, = ax1.plot(sub['year'], sub['eti'],
                   color=colors[reg], marker=markers[reg],
                   markersize=5, linewidth=1.8,
                   label=reg_labels[reg])
    lines.append(ln)
    lbls.append(reg_labels[reg])
    last = sub.iloc[-1]
    ax1.text(last['year'] + 0.4, last['eti'],
             reg_short[reg], color=colors[reg], fontsize=8.5, va='center')

# Kyoto Protocol (2005)
ax1.axvline(2005, color=KYOTO_COLOR, linewidth=1.1, linestyle=':', zorder=1)
ax1.text(2005.25, 20.5,
         'Kyoto Protocol (2005)',
         fontsize=KYOTO_FS, color=KYOTO_COLOR, va='bottom')

# Paris Agreement (2015)
ax1.axvline(2015, color=PARIS_COLOR, linewidth=1.1, linestyle='--', zorder=1)
ax1.text(2015.25, 20.5,
         'Paris Agreement (2015)',
         fontsize=PARIS_FS, color=PARIS_COLOR, va='bottom')

ax1.set_xlim(1999, 2023.8)
ax1.set_ylim(20, 72)
ax1.set_ylabel('Mean ETI Score (0–100)', fontsize=10)
ax1.set_xlabel('Year', fontsize=10)
ax1.xaxis.set_major_locator(ticker.MultipleLocator(5))
ax1.tick_params(labelsize=9)

ax1.legend(lines, lbls,
           ncol=5,
           loc='upper center',
           bbox_to_anchor=(0.5, -0.18),
           fontsize=8.5, frameon=False,
           columnspacing=1.2, handlelength=2.0)

# ══════════════════════════════════════════════════════════════════════════════
# (b)–(f) BOTTOM panels — ESP & TR per region
# ══════════════════════════════════════════════════════════════════════════════
gs2 = gridspec.GridSpecFromSubplotSpec(
    2, 3, subplot_spec=gs[1],
    hspace=0.55, wspace=0.30
)

def make_region_ax(ax, reg, letter):
    sub = mean_reg[mean_reg['region'] == reg].sort_values('year')

    ax.plot(sub['year'], sub['esp'],
            color=colors[reg], linewidth=1.8,
            marker=markers[reg], markersize=4.5)
    ax.plot(sub['year'], sub['tr'],
            color=colors[reg], linewidth=1.5,
            linestyle=(0, (4, 2)),
            marker=markers[reg], markersize=4.5,
            markerfacecolor='white', markeredgewidth=1.3)

    last_yr = sub['year'].max()
    esp_val = sub.loc[sub['year'] == last_yr, 'esp'].values[0]
    tr_val  = sub.loc[sub['year'] == last_yr, 'tr'].values[0]
    ax.text(last_yr + 0.4, esp_val, 'ESP',
            color=colors[reg], fontsize=8.5, va='center')
    ax.text(last_yr + 0.4, tr_val, 'TR',
            color=colors[reg], fontsize=8.5, va='center', fontstyle='italic')

    # Kyoto Protocol (2005)
    ax.axvline(2005, color=KYOTO_COLOR, linewidth=1.0, linestyle=':', zorder=1)
    ax.text(2005.25, 11, 'Kyoto Protocol (2005)',
            fontsize=7, color=KYOTO_COLOR, va='bottom')

    # Paris Agreement (2015)
    ax.axvline(2015, color=PARIS_COLOR, linewidth=1.0, linestyle='--', zorder=1)
    ax.text(2015.25, 11, 'Paris Agreement (2015)',
            fontsize=7, color=PARIS_COLOR, va='bottom')

    # region name as x-label (below panel) — kept for axis clarity
    ax.set_xlabel('Year', fontsize=8.5)
    ax.set_xlim(1999, 2023.8)
    ax.set_ylim(10, 82)
    ax.set_ylabel('Score (0–100)', fontsize=8.5)
    ax.xaxis.set_major_locator(ticker.MultipleLocator(5))
    ax.tick_params(labelsize=8)

    # panel label + region name ABOVE panel
    add_panel_label(ax, letter, reg_labels[reg], colors[reg])

# Row 1: b, c, d
for i, (reg, ltr) in enumerate(zip(['EDA', 'EDE', 'LAC'], ['b', 'c', 'd'])):
    ax = fig.add_subplot(gs2[0, i])
    make_region_ax(ax, reg, ltr)

# Row 2: e, f — placed in col 0 & 1 then shifted to center
for i, (reg, ltr) in enumerate(zip(['SSA', 'MECA'], ['e', 'f'])):
    ax = fig.add_subplot(gs2[1, i])
    make_region_ax(ax, reg, ltr)

# Center the two bottom panels
fig.canvas.draw()
axes_list = fig.get_axes()
ax_e = axes_list[-2]
ax_f = axes_list[-1]

pos_e = ax_e.get_position()
pos_f = ax_f.get_position()
col_width = pos_e.width
shift = col_width * 0.55

ax_e.set_position([pos_e.x0 + shift, pos_e.y0, pos_e.width, pos_e.height])
ax_f.set_position([pos_f.x0 + shift, pos_f.y0, pos_f.width, pos_f.height])

# ── Save + Download ────────────────────────────────────────────────────────────
output_file = 'Fig_Region_combined.png'
plt.savefig(output_file, dpi=600, bbox_inches='tight',
            facecolor='white', format='png')
plt.show()
print(f"Saved — {output_file}")
files.download(output_file)
