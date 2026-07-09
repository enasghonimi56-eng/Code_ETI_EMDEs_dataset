# ETI Spatial Distribution Maps
This script generates static and interactive world maps for the Energy Transition Index (ETI).

## Required file
Data_ETI_EMEDs.xlsx

## Run on
Google Colab

# ── STEP 1: Install libraries ────────────────────────────────
!pip install geopandas openpyxl plotly -q

import pandas as pd
import geopandas as gpd
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import plotly.express as px
import warnings
warnings.filterwarnings('ignore')
from google.colab import files

# ── STEP 2: Upload data ──────────────────────────────────────
print("Upload: Data_ETI_EMEDs.xlsx")
uploaded = files.upload()
df = pd.read_excel(list(uploaded.keys())[0])
df.columns = ['Country', 'ISO3', 'Year', 'ESP', 'TR', 'ETI']
print(f"✓ Data loaded: {len(df)} rows — "
      f"{df['Country'].nunique()} countries — "
      f"{df['Year'].nunique()} years")

# ── STEP 3: Load shapefile ───────────────────────────────────
url = ("https://naciscdn.org/naturalearth/110m/cultural/"
       "ne_110m_admin_0_countries.zip")
world = gpd.read_file(url)
world = world[world['CONTINENT'] != 'Antarctica']
world = world[['ISO_A3', 'geometry']].rename(columns={'ISO_A3': 'ISO3'})
print(f"✓ Shapefile loaded: {len(world)} countries")

# ── STEP 4: Classification scheme ───────────────────────────
bins = [0, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 100]
labels_legend = ['<30', '30–35', '35–40', '40–45', '45–50',
                 '50–55', '55–60', '60–65', '65–70', '70–75', '>75']

# ✅ FIX: الأحمر الغامق = score عالي / الأزرق الغامق = score منخفض
colors_static = [
    '#084594',  # <30      (أزرق غامق)
    '#2171b5',  # 30–35
    '#6baed6',  # 35–40
    '#9ecae1',  # 40–45
    '#c6dbef',  # 45–50    (أزرق فاتح)
    '#fcbba1',  # 50–55    (برتقالي فاتح)
    '#fc9272',  # 55–60
    '#fb6a4a',  # 60–65
    '#ef3b2c',  # 65–70
    '#cb181d',  # 70–75
    '#67000d',  # >75      (أحمر غامق)
]

def get_merged(year):
    d = df[df['Year'] == year][['ISO3', 'ETI']].copy()
    m = world.merge(d, on='ISO3', how='left')
    m['cidx'] = pd.cut(m['ETI'], bins=bins,
                       labels=False, include_lowest=True)
    return m

# ── STEP 5: Legend patches ───────────────────────────────────
patches = [
    mpatches.Patch(facecolor=colors_static[i],
                   edgecolor='black', linewidth=0.5,
                   label=labels_legend[i])
    for i in range(len(labels_legend))
]
patches.append(
    mpatches.Patch(facecolor='#d9d9d9',
                   edgecolor='black', linewidth=0.5,
                   label='Non-EMDE / No data')
)

# ── STEP 6: Draw function ────────────────────────────────────
def draw_map(ax, year, panel_letter):
    merged = get_merged(year)

    # Base — all countries gray
    world.plot(ax=ax, color='#d9d9d9',
               edgecolor='black', linewidth=0.4, aspect=None)

    # Classified countries
    for i, color in enumerate(colors_static):
        s = merged[merged['cidx'] == i]
        if len(s) > 0:
            s.plot(ax=ax, color=color,
                  edgecolor='black', linewidth=0.4, aspect=None)

    ax.set_xlim(-180, 180)
    ax.set_ylim(-60, 85)
    ax.axis('off')

    # Panel label
    ax.text(-175, 82,
            f'({panel_letter}) ETI {year}',
            fontsize=13, fontweight='bold',
            va='top', ha='left')

    # Legend — right side
    ax.legend(
        handles=patches,
        title='ETI score',
        title_fontsize=9,
        fontsize=8,
        loc='center left',
        bbox_to_anchor=(1.01, 0.5),
        frameon=True,
        framealpha=0.9,
        edgecolor='gray',
        ncol=1
    )

years_info = [(2000, 'a'), (2012, 'b'), (2023, 'c')]

# ════════════════════════════════════════════════════════════════
# STEP 7: Individual Static PNGs
# ════════════════════════════════════════════════════════════════
print("\n── Generating individual static maps ──")

for year, letter in years_info:
    fig, ax = plt.subplots(figsize=(14, 7), facecolor='white')
    draw_map(ax, year, letter)
    plt.tight_layout()
    fname = f'ETI_{year}_static.png'
    plt.savefig(fname, dpi=300,
                bbox_inches='tight', facecolor='white')
    plt.show()
    files.download(fname)
    print(f"✓ {fname} saved")

# ════════════════════════════════════════════════════════════════
# STEP 8: Combined Figure (a + b + c)
# ════════════════════════════════════════════════════════════════
print("\n── Generating combined figure ──")

fig, axes = plt.subplots(3, 1, figsize=(16, 21), facecolor='white')

for ax, (year, letter) in zip(axes, years_info):
    draw_map(ax, year, letter)

plt.tight_layout(h_pad=1.5)

fname_combined = 'Fig2_ETI_Maps_Combined.png'
plt.savefig(fname_combined, dpi=300,
            bbox_inches='tight', facecolor='white')
plt.show()
files.download(fname_combined)
print(f"✓ {fname_combined} saved")

# ════════════════════════════════════════════════════════════════
# STEP 9: Interactive HTML maps
# ════════════════════════════════════════════════════════════════
print("\n── Generating interactive maps ──")

# ✅ FIX: نفس عكس الألوان في colorscale
colorscale = [
    [0/100,  '#084594'], [30/100, '#084594'],
    [30/100, '#2171b5'], [35/100, '#2171b5'],
    [35/100, '#6baed6'], [40/100, '#6baed6'],
    [40/100, '#9ecae1'], [45/100, '#9ecae1'],
    [45/100, '#c6dbef'], [50/100, '#c6dbef'],
    [50/100, '#fcbba1'], [55/100, '#fcbba1'],
    [55/100, '#fc9272'], [60/100, '#fc9272'],
    [60/100, '#fb6a4a'], [65/100, '#fb6a4a'],
    [65/100, '#ef3b2c'], [70/100, '#ef3b2c'],
    [70/100, '#cb181d'], [75/100, '#cb181d'],
    [75/100, '#67000d'], [100/100,'#67000d'],
]

for year, letter in years_info:
    d = df[df['Year'] == year][['Country', 'ISO3', 'ETI']].copy()
    d['ETI_r'] = d['ETI'].round(2)

    fig_int = px.choropleth(
        d,
        locations='ISO3',
        color='ETI',
        hover_name='Country',
        hover_data={'ETI_r': True, 'ISO3': False, 'ETI': False},
        color_continuous_scale=colorscale,
        range_color=[0, 100],
        title=f'<b>Energy Transition Index (ETI) — {year}</b>',
        labels={'ETI_r': 'ETI Score'}
    )
    fig_int.update_traces(
        hovertemplate=(
            '<b>%{hovertext}</b><br>'
            'ETI Score: %{customdata[0]:.2f}'
            '<extra></extra>'
        )
    )
    fig_int.update_layout(
        font=dict(family='Arial', size=12),
        title_font_size=15,
        paper_bgcolor='white',
        geo=dict(
            showframe=False,
            showcoastlines=True,
            coastlinecolor='#aaaaaa',
            showland=True,
            landcolor='#d9d9d9',
            showocean=True,
            oceancolor='#eaf4fb',
            projection_type='natural earth',
            lataxis_range=[-60, 85],
        ),
        coloraxis_colorbar=dict(
            title='ETI Score',
            tickvals=[0, 30, 35, 40, 45, 50,
                      55, 60, 65, 70, 75, 100],
            ticktext=['0', '30', '35', '40', '45', '50',
                      '55', '60', '65', '70', '75', '100'],
            thickness=15,
            len=0.7,
        ),
        margin=dict(l=0, r=0, t=50, b=0),
        width=1200,
        height=600,
    )

    fname_html = f'ETI_{year}_interactive.html'
    fig_int.write_html(fname_html)
    fig_int.show()
    files.download(fname_html)
    print(f"✓ {fname_html} saved")
