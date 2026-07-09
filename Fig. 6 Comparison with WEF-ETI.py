Fig. 6 Comparison of ETI-EMDEs with the WEF-ETI 2025 across 83 common EMDEs. 


# ══════════════════════════════════════════════════════════════════════════════
# CELL 1 — Upload files
# ══════════════════════════════════════════════════════════════════════════════
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
from scipy import stats
from google.colab import files

print("Upload Data_ETI_EMEDs.xlsx")
up1 = files.upload()
eti_raw = pd.read_excel(list(up1.keys())[0])
print("✓ ETI loaded")

print("Upload WEF-ETI 2025.xlsx")
up2 = files.upload()
wef = pd.read_excel(list(up2.keys())[0])
print("✓ WEF loaded")

# ══════════════════════════════════════════════════════════════════════════════
# CELL 2 — Prepare data & statistics
# ══════════════════════════════════════════════════════════════════════════════
eti_2023 = eti_raw[eti_raw['year'] == 2023][['country','iso3','eti','income_group','region']].copy()
eti_2023['country'] = eti_2023['country'].replace('Columbia', 'Colombia')
df = pd.merge(eti_2023, wef, on='country', how='inner')
print(f"✓ Merged: {len(df)} countries")

spearman_r, _ = stats.spearmanr(df['eti'], df['wef_eti_2025'])
pearson_r,  _ = stats.pearsonr(df['eti'],  df['wef_eti_2025'])
diff      = df['eti'] - df['wef_eti_2025']
mean_diff = diff.mean()
sd_diff   = diff.std()
upper_loa = mean_diff + 1.96 * sd_diff
lower_loa = mean_diff - 1.96 * sd_diff
mean_val  = (df['eti'] + df['wef_eti_2025']) / 2
m, b      = np.polyfit(df['eti'], df['wef_eti_2025'], 1)
x_range   = np.linspace(df['eti'].min(), df['eti'].max(), 100)
lims      = [min(df['eti'].min(), df['wef_eti_2025'].min()) - 2,
             max(df['eti'].max(), df['wef_eti_2025'].max()) + 2]

DOT_COLOR  = '#2E86AB'
LINE_COLOR = '#E74C3C'
DASH_COLOR = '#E74C3C'

plt.rcParams.update({
    'font.family':       'DejaVu Sans',
    'font.size':         11,
    'axes.spines.top':   False,
    'axes.spines.right': False,
    'axes.grid':         True,
    'axes.grid.axis':    'y',
    'grid.color':        '#EEEEEE',
    'grid.linewidth':    0.8,
    'axes.axisbelow':    True,
})

def add_panel_label(ax, letter, title=None, fontsize=12):
    if title:
        ax.text(-0.08, 1.06, f'({letter}) ',
                transform=ax.transAxes, fontsize=fontsize,
                fontweight='bold', va='bottom', ha='left', color='black')
        ax.text(0.02, 1.06, title,
                transform=ax.transAxes, fontsize=fontsize - 0.5,
                fontweight='bold', va='bottom', ha='left', color='black')
    else:
        ax.text(-0.08, 1.04, f'({letter})',
                transform=ax.transAxes, fontsize=fontsize,
                fontweight='bold', va='bottom', ha='left', color='black')

# ══════════════════════════════════════════════════════════════════════════════
# CELL 3a — Figure (a): Scatter Plot — standalone
# ══════════════════════════════════════════════════════════════════════════════
fig_a, ax1 = plt.subplots(figsize=(7, 6.5))
fig_a.subplots_adjust(top=0.88, bottom=0.12, left=0.13, right=0.95)
add_panel_label(ax1, 'a', 'Scatter Plot')

ax1.scatter(df['eti'], df['wef_eti_2025'],
            color=DOT_COLOR, s=55, alpha=0.75, zorder=3)
ax1.plot(x_range, m * x_range + b,
         color=LINE_COLOR, linewidth=1.8, linestyle='--',
         label='OLS fit', zorder=4)
ax1.plot(lims, lims, color='#AAAAAA', linewidth=1.2,
         linestyle=':', label='45° reference', zorder=2)
ax1.text(0.04, 0.97,
         f"Spearman ρ = {spearman_r:.3f}\nPearson r = {pearson_r:.3f}\np < 0.001\nN = {len(df)}",
         transform=ax1.transAxes, fontsize=9, va='top', ha='left',
         bbox=dict(boxstyle='round,pad=0.4', facecolor='white',
                   edgecolor='#CCCCCC', alpha=0.9))
ax1.set_xlabel('ETI-EMDEs Score (0–100)', fontsize=11)
ax1.set_ylabel('WEF-ETI Score (0–100)', fontsize=11)
ax1.set_xlim(lims); ax1.set_ylim(lims)
ax1.tick_params(labelsize=10)
ax1.legend(fontsize=9, frameon=False, loc='lower right')

fig_a.savefig('Fig_WEF_a_Scatter.png', dpi=600, bbox_inches='tight', facecolor='white')
plt.show()
print("✓ Fig_WEF_a_Scatter.png saved")
files.download('Fig_WEF_a_Scatter.png')

# ══════════════════════════════════════════════════════════════════════════════
# CELL 3b — Figure (b): Bland-Altman — standalone
# ══════════════════════════════════════════════════════════════════════════════
fig_b, ax2 = plt.subplots(figsize=(7, 6.5))
fig_b.subplots_adjust(top=0.88, bottom=0.12, left=0.13, right=0.90)
add_panel_label(ax2, 'b', 'Bland–Altman Plot')

ax2.scatter(mean_val, diff,
            color=DOT_COLOR, s=55, alpha=0.75, zorder=3)
ax2.axhline(mean_diff, color=LINE_COLOR, linewidth=1.8)
ax2.axhline(upper_loa, color=DASH_COLOR, linewidth=1.3, linestyle='--')
ax2.axhline(lower_loa, color=DASH_COLOR, linewidth=1.3, linestyle='--')
ax2.axhline(0, color='#AAAAAA', linewidth=0.8, linestyle=':')

xmax = mean_val.max() + 1
ax2.text(xmax, mean_diff + 0.3, f'Mean\n({mean_diff:.2f})',
         fontsize=8, color=LINE_COLOR, va='bottom')
ax2.text(xmax, upper_loa + 0.3, f'+1.96 SD\n({upper_loa:.2f})',
         fontsize=8, color=DASH_COLOR, va='bottom')
ax2.text(xmax, lower_loa - 0.3, f'−1.96 SD\n({lower_loa:.2f})',
         fontsize=8, color=DASH_COLOR, va='top')
ax2.set_xlabel('Mean of ETI-EMDEs and WEF-ETI (0–100)', fontsize=11)
ax2.set_ylabel('Difference (ETI-EMDEs − WEF-ETI)', fontsize=11)
ax2.tick_params(labelsize=10)
ax2.set_xlim(mean_val.min() - 2, mean_val.max() + 9)

fig_b.savefig('Fig_WEF_b_BlandAltman.png', dpi=600, bbox_inches='tight', facecolor='white')
plt.show()
print("✓ Fig_WEF_b_BlandAltman.png saved")
files.download('Fig_WEF_b_BlandAltman.png')

# ══════════════════════════════════════════════════════════════════════════════
# CELL 4 — Combined (a) + (b)
# ══════════════════════════════════════════════════════════════════════════════
fig, (axA, axB) = plt.subplots(1, 2, figsize=(14, 6.5))
fig.subplots_adjust(top=0.88, bottom=0.12, left=0.08, right=0.95, wspace=0.35)

# (a)
add_panel_label(axA, 'a', 'Scatter Plot')
axA.scatter(df['eti'], df['wef_eti_2025'],
            color=DOT_COLOR, s=50, alpha=0.75, zorder=3)
axA.plot(x_range, m * x_range + b,
         color=LINE_COLOR, linewidth=1.8, linestyle='--',
         label='OLS fit', zorder=4)
axA.plot(lims, lims, color='#AAAAAA', linewidth=1.2,
         linestyle=':', label='45° reference', zorder=2)
axA.text(0.04, 0.97,
         f"Spearman ρ = {spearman_r:.3f}\nPearson r = {pearson_r:.3f}\np < 0.001\nN = {len(df)}",
         transform=axA.transAxes, fontsize=9, va='top', ha='left',
         bbox=dict(boxstyle='round,pad=0.4', facecolor='white',
                   edgecolor='#CCCCCC', alpha=0.9))
axA.set_xlabel('ETI-EMDEs Score (0–100)', fontsize=11)
axA.set_ylabel('WEF-ETI Score (0–100)', fontsize=11)
axA.set_xlim(lims); axA.set_ylim(lims)
axA.tick_params(labelsize=10)
axA.legend(fontsize=9, frameon=False, loc='lower right')

# (b)
add_panel_label(axB, 'b', 'Bland–Altman Plot')
axB.scatter(mean_val, diff,
            color=DOT_COLOR, s=50, alpha=0.75, zorder=3)
axB.axhline(mean_diff, color=LINE_COLOR, linewidth=1.8)
axB.axhline(upper_loa, color=DASH_COLOR, linewidth=1.3, linestyle='--')
axB.axhline(lower_loa, color=DASH_COLOR, linewidth=1.3, linestyle='--')
axB.axhline(0, color='#AAAAAA', linewidth=0.8, linestyle=':')
axB.text(mean_val.max()+1, mean_diff+0.3, f'Mean\n({mean_diff:.2f})',
         fontsize=8, color=LINE_COLOR, va='bottom')
axB.text(mean_val.max()+1, upper_loa+0.3, f'+1.96 SD\n({upper_loa:.2f})',
         fontsize=8, color=DASH_COLOR, va='bottom')
axB.text(mean_val.max()+1, lower_loa-0.3, f'−1.96 SD\n({lower_loa:.2f})',
         fontsize=8, color=DASH_COLOR, va='top')
axB.set_xlabel('Mean of ETI-EMDEs and WEF-ETI (0–100)', fontsize=11)
axB.set_ylabel('Difference (ETI-EMDEs − WEF-ETI)', fontsize=11)
axB.tick_params(labelsize=10)
axB.set_xlim(mean_val.min()-2, mean_val.max()+9)

fig.savefig('Fig_WEF_Combined.png', dpi=600, bbox_inches='tight', facecolor='white')
plt.show()
print("✓ Fig_WEF_Combined.png saved")
files.download('Fig_WEF_Combined.png')
