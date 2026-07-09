# Figure 3. Sensitivity analysis of the Energy Transition Index (ETI).

# This script reproduces Figure 3 of the study by evaluating the robustness of ETI scores and country rankings under alternative weighting schemes for the two ETI dimensions:
    - Energy System Performance (ESP)
    - Transition Readiness (TR)
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

import pandas as pd
import matplotlib.pyplot as plt
from scipy.stats import spearmanr

INPUT_PATH = "data_m25_index.dta"      
OUTPUT_FIG = "alt_weights_sensitivity.png"
OUTPUT_TABLE = "alt_weights_country_results.csv"


def load_data(path):
    if path.lower().endswith(".dta"):
        df = pd.read_stata(path)
    else:
        df = pd.read_csv(path)
    df.columns = [c.strip().lower() for c in df.columns]
    return df


def find_column(df, candidates):
    for c in candidates:
        if c in df.columns:
            return c
    raise KeyError(f"None of {candidates} found in columns: {list(df.columns)}")


raw = load_data(INPUT_PATH)

country_col = find_column(raw, ["country", "country_name", "countryname", "iso3", "country_code"])
esp_col = find_column(raw, ["esp", "esp_score", "energy_system_performance", "subindex_esp"])
tr_col = find_column(raw, ["tr", "tr_score", "transition_readiness", "subindex_tr"])

raw = raw.rename(columns={country_col: "country", esp_col: "esp", tr_col: "tr"})
raw = raw[["country", "esp", "tr"]].dropna()

df = raw.groupby("country", as_index=False).agg(esp_mean=("esp", "mean"),
                                                  tr_mean=("tr", "mean"))

df["baseline"] = 0.5 * df["esp_mean"] + 0.5 * df["tr_mean"]
df["alt1"] = 0.6 * df["esp_mean"] + 0.4 * df["tr_mean"]   
df["alt2"] = 0.4 * df["esp_mean"] + 0.6 * df["tr_mean"]   

df = df.sort_values("baseline").reset_index(drop=True)
df["x"] = range(1, len(df) + 1)

df["rank_baseline"] = df["baseline"].rank(method="min")
df["rank_alt1"] = df["alt1"].rank(method="min")
df["rank_alt2"] = df["alt2"].rank(method="min")

df.to_csv(OUTPUT_TABLE, index=False)
print(f"Saved country-level results table: {OUTPUT_TABLE}")

fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(11, 9))

score_series = [
    ("baseline", "Baseline (50/50)", "o", "#d62728"),
    ("alt1", "Alt-1 (60% ESP / 40% TR)", "^", "#1f77b4"),
    ("alt2", "Alt-2 (40% ESP / 60% TR)", "D", "#2ca02c"),
]
for col, label, marker, color in score_series:
    ax1.scatter(df["x"], df[col], s=10, marker=marker, color=color, label=label)
ax1.set_title("(a) ETI Scores under Alternative Sub-Index Weights")
ax1.set_ylabel("Mean ETI Score (2000-2023)")
ax1.set_xlabel("Countries (sorted by baseline ETI score)")
ax1.set_xticks([])
ax1.set_ylim(20, 70)
ax1.set_yticks(range(20, 71, 10))
ax1.legend(loc="upper center", bbox_to_anchor=(0.5, -0.14), ncol=3, frameon=False)

rank_series = [
    ("rank_baseline", "Baseline (50/50)", "o", "#d62728"),
    ("rank_alt1", "Alt-1 (60% ESP / 40% TR)", "^", "#1f77b4"),
    ("rank_alt2", "Alt-2 (40% ESP / 60% TR)", "D", "#2ca02c"),
]
for col, label, marker, color in rank_series:
    ax2.scatter(df["x"], df[col], s=10, marker=marker, color=color, label=label)
ax2.set_title("(b) ETI Rankings under Alternative Sub-Index Weights")
ax2.set_ylabel("Mean Rank (2000-2023)")
ax2.set_xlabel("Countries (sorted by baseline ETI score)")
ax2.set_xticks([])
ax2.set_ylim(0, max(140, len(df)))
ax2.set_yticks(range(0, max(140, len(df)) + 1, 20))
ax2.legend(loc="upper center", bbox_to_anchor=(0.5, -0.14), ncol=3, frameon=False)

plt.tight_layout()
plt.subplots_adjust(hspace=0.35)

plt.savefig(OUTPUT_FIG, dpi=600, facecolor="white", bbox_inches="tight")
print(f"Saved figure: {OUTPUT_FIG} (600 dpi, RGB, PNG)")

try:
    from google.colab import files
    files.download(OUTPUT_FIG)
except ImportError:
    pass
rho1_country, _ = spearmanr(df["baseline"], df["alt1"])
rho2_country, _ = spearmanr(df["baseline"], df["alt2"])
print(f"Spearman rho, country-mean level (N={len(df)}):")
print(f"  baseline vs Alt-1 (60/40): {rho1_country:.4f}")
print(f"  baseline vs Alt-2 (40/60): {rho2_country:.4f}")

panel_base = 0.5 * raw["esp"] + 0.5 * raw["tr"]
panel_alt1 = 0.6 * raw["esp"] + 0.4 * raw["tr"]
panel_alt2 = 0.4 * raw["esp"] + 0.6 * raw["tr"]
rho1_panel, _ = spearmanr(panel_base, panel_alt1)
rho2_panel, _ = spearmanr(panel_base, panel_alt2)
print(f"Spearman rho, country-year (panel) level (N={len(raw)}) -- matches SI S3.5 methodology:")
print(f"  baseline vs Alt-1 (60/40): {rho1_panel:.4f}")
print(f"  baseline vs Alt-2 (40/60): {rho2_panel:.4f}")
print(f"Number of countries: {len(df)}")
