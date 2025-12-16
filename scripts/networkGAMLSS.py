#!/bin/python
# -*- coding: utf-8 -*-
"""
Fit network-wise GAMLSS models and produce publication-ready figures
for graph network metrics.
"""

import argparse
import subprocess
import os
import shutil

import pandas as pd
import matplotlib.pyplot as plt
from matplotlib import axes, font_manager
import seaborn as sns
from tqdm import tqdm


def _build_arg_parser():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawTextHelpFormatter)

    p.add_argument("in_dataframe",
                   help="Dataframe containing all network metrics data."
                   "Should be in the format:" \
                   "participant_id,session_id,metric1,metric2,...,age,sex,cohort")
    p.add_argument("output_dir",
                   help="Output directory in which results will be stored.")
    p.add_argument("--metric",
                   help="Network metric(s) for which to fit the GAMLSS model.",
                   nargs="+",
                   required=True)
    p.add_argument("--rscript",
                   help="Path to the R script that fits the GAMLSS model.",
                   required=True)
    p.add_argument("-n", "--n_cpus",
                   type=int,
                   help="Number of CPUs to use.",
                   default=1)
    p.add_argument("-f", "--force",
                   action="store_true",
                   help="Overwrite output folder.",
                   default=False)

    return p


def fetch_font(font_name="Harding"):
    """
    Fetch a font from the matplotlib font manager.
    """
    font_files = []
    for font in font_manager.findSystemFonts(fontpaths=None, fontext='ttf'):
        if font_name.lower() in font.lower():
            font_files.append(font)
    if not font_files:
        raise ValueError(f"Font {font_name} not found in system fonts.")

    for font_file in font_files:
        font_manager.fontManager.addfont(font_file)


def main():
    parser = _build_arg_parser()
    args = parser.parse_args()

    # Look if output folder exists.
    if os.path.exists(args.output_dir):
        if args.force:
            shutil.rmtree(args.output_dir)
            os.makedirs(args.output_dir)
        else:
            raise FileExistsError(f"Output folder {args.output_dir} exists."
                                  " Use -f to overwrite.")
    else:
        os.makedirs(args.output_dir)

    # Load dataframe.
    df = pd.read_csv(args.in_dataframe)

    # Save temporary dataframe.
    temp_csv = os.path.join(args.output_dir, "network_data.csv")
    df.to_csv(temp_csv, index=False)

    # Check for NA values in the metric, age, sex, and cohort columns
    if df[args.metric + ["age", "sex", "cohort"]].isnull().values.any():
        raise ValueError("Data contains NA values in the metric, age, sex, or cohort columns."
                         " Please remove these rows before fitting the GAMLSS model.")
    
    # Let's build a list of commands to be executed in R but in parallel.
    cmd = []
    for metric in args.metric:
        cmd.append([
            "Rscript",
            args.rscript,
            "--input", temp_csv,
            "--output", args.output_dir,
            "--metric", metric
        ])

    # Execute all commands using the allocated number of CPUs from args.n_cpus.
    processes = []
    for i in range(0, len(cmd), args.n_cpus):
        for j in range(i, min(i + args.n_cpus, len(cmd))):
            metric_name = cmd[j][-1]  # Get the metric name from the command
            log_file = os.path.join(args.output_dir, f"{metric_name}_gamlss.log")
            with open(log_file, 'w') as f:
                processes.append(subprocess.Popen(cmd[j], stdout=f, stderr=subprocess.STDOUT))
        for p in processes:
            p.wait()
        processes = []

    # Plotting
    fetch_font("Harding")
    plt.rcParams['font.family'] = 'Harding Text Web'
    rocket_cmap = sns.color_palette("rocket_r", 6)
    cohort_cmap = [rocket_cmap[0], rocket_cmap[1], rocket_cmap[2], rocket_cmap[3], rocket_cmap[4], rocket_cmap[5]]  # six cohorts

    # Load results (batch load in a dict all files ending by "_centiles_by_age.csv") and merge them.
    results_files = [f for f in os.listdir(args.output_dir) if f.endswith("_centiles_by_age.csv")]
    results_dfs = {}
    metric_names = []
    for rf in results_files:
        metric_name = rf.replace("_centiles_by_age.csv", "")
        metric_names.append(metric_name)
        temp_df = pd.read_csv(os.path.join(args.output_dir, rf))
        results_dfs[metric_name] = temp_df
        results_dfs[metric_name] = results_dfs[metric_name].pivot(index="age", columns='prob', values="metric").reset_index()

    # Dict of y labels for each metric.
    y_labels = {
        "GlobalEfficiency": "Global Efficiency",
        "LocalEfficiency": "Local Efficiency",
        "AverageStrength": "Average Strength",
        "Modularity": "Modularity",
        "AverageBetweennessCentrality": "Average BC",
        "RichClubCoefficient": "Rich Club Coefficient",
    }

    # Let's plot the data.
    fig, ax = plt.subplots(2, len(args.metric) if len(args.metric) > 1 else 2, figsize=(18, 6), sharex=True, squeeze=True)
    for i, metric in enumerate(args.metric):

        # Let's define the ylim based on the data
        # Take the max/min, and round to the next 0.1, 0.01, 0.001 or 0.0001 depending on the range.
        data_max = df[metric].max()
        data_min = df[metric].min()
        data_range = data_max - data_min
        if data_range > 0.1:
            ylim_max = round(data_max + 0.1, 1)
            ylim_min = round(max(0, data_min - 0.1), 1)
        elif data_range > 0.01:
            ylim_max = round(data_max + 0.01, 2)
            ylim_min = round(max(0, data_min - 0.01), 2)
        elif data_range > 0.001:
            ylim_max = round(data_max + 0.001, 3)
            ylim_min = round(max(0, data_min - 0.001), 3)
        else:
            ylim_max = round(data_max + 0.0001, 4)
            ylim_min = round(max(0, data_min - 0.0001), 4)

        sns.scatterplot(data=df, x="age", y=metric, ax=ax[0, i],
                        hue="cohort", style="sex", palette=cohort_cmap, legend=False,
                        hue_order=["MYRNA", "BCP", "ABCD", "GESTE", "BANDA", "PING"])
        ax[0, i].set_ylim(ylim_min, ylim_max)
        ax[0, i].set_ylabel(y_labels.get(metric, metric), fontsize=14, fontweight='bold')
        ax[0, i].set_xlabel("")
        ax[0, i].set_xticks([0, 2, 4, 6, 8, 10, 12, 14, 16, 18])
        ax[0, i].tick_params(axis='both', which='major', labelsize=10)

        # Plot the centiles.
        sns.lineplot(data=results_dfs[metric], x="age", y=0.05, ax=ax[1, i], color=rocket_cmap[0], linestyle='--', linewidth=2, legend=False)
        sns.lineplot(data=results_dfs[metric], x="age", y=0.5, ax=ax[1, i], color=rocket_cmap[5], linestyle='-', linewidth=2, legend=False)
        sns.lineplot(data=results_dfs[metric], x="age", y=0.95, ax=ax[1, i], color=rocket_cmap[0], linestyle='--', linewidth=2, legend=False)
        ax[1, i].fill_between(results_dfs[metric]['age'], results_dfs[metric][0.05], results_dfs[metric][0.95], color=rocket_cmap[0], alpha=0.4, zorder=-1)
        ax[1, i].set_ylim(ylim_min, ylim_max)
        ax[1, i].set_xlabel("Age (years)", fontsize=14, fontweight='bold')
        ax[1, i].set_ylabel(y_labels.get(metric, metric), fontsize=14, fontweight='bold')
        ax[1, i].set_xticks([0, 2, 4, 6, 8, 10, 12, 14, 16, 18])
        ax[1, i].tick_params(axis='both', which='major', labelsize=10)

        for row in ax:
            for a in row:
                a.spines['top'].set_visible(False)
                a.spines['right'].set_visible(False)
                a.spines[["left", "bottom"]].set_linewidth(2)
                if a.get_ylim()[1] < 0.01:
                    a.ticklabel_format(axis='y', style='scientific', scilimits=(0,0))

        # Add global legends: sex, cohorts and centile labels (compact)
        handles_sex = [plt.Line2D([0], [0], color="black", markersize=10, lw=0, marker="o", markeredgewidth=1, markeredgecolor='black'),
                    plt.Line2D([0], [0], color="black", markersize=10, lw=0, marker="x", markeredgewidth=3, markeredgecolor='black')]
        labels_sex = ["Male", "Female"]
        fig.legend(handles_sex, labels_sex, loc="upper left", bbox_to_anchor=(0.90, 0.86), ncol=1, fontsize=12, frameon=False, title="Sex", title_fontproperties={'size': 14, 'weight': 'bold'})

        handles_cohort = [plt.Line2D([0], [0], color=cohort_cmap[i], markersize=8, lw=0, marker="o", markeredgewidth=1, markeredgecolor='dimgrey') for i in range(len(cohort_cmap))]
        labels_cohort = ["MYRNA", "BCP", "ABCD", "GESTE", "BANDA", "PING"]
        fig.legend(handles_cohort, labels_cohort, loc="upper left", bbox_to_anchor=(0.90, 0.69), ncol=1, fontsize=12, frameon=False, title="Cohort", title_fontproperties={'size': 14, 'weight': 'bold'})

        handles_centile = [plt.Line2D([0], [0], color="black", markersize=8, lw=3, linestyle='-', label='Median'),
                            plt.Line2D([0], [0], color="black", markersize=8, lw=3, linestyle='--', label='5th/95th Percentiles')]
    for row in ax:
        for a in row:
            a.spines['top'].set_visible(False)
            a.spines['right'].set_visible(False)
            a.spines[["left", "bottom"]].set_linewidth(2)
            if a.get_ylim()[1] < 0.01:
                a.ticklabel_format(axis='y', style='scientific', scilimits=(0,0))

    # Add global legends: sex, cohorts and centile labels (compact)
    handles_sex = [plt.Line2D([0], [0], color="black", markersize=10, lw=0, marker="o", markeredgewidth=1, markeredgecolor='black'),
                plt.Line2D([0], [0], color="black", markersize=10, lw=0, marker="x", markeredgewidth=3, markeredgecolor='black')]
    labels_sex = ["Male", "Female"]
    fig.legend(handles_sex, labels_sex, loc="upper left", bbox_to_anchor=(0.90, 0.86), ncol=1, fontsize=12, frameon=False, title="Sex", title_fontproperties={'size': 14, 'weight': 'bold'})

    handles_cohort = [plt.Line2D([0], [0], color=cohort_cmap[i], markersize=8, lw=0, marker="o", markeredgewidth=1, markeredgecolor='dimgrey') for i in range(len(cohort_cmap))]
    labels_cohort = ["MYRNA", "BCP", "ABCD", "GESTE", "BANDA", "PING"]
    fig.legend(handles_cohort, labels_cohort, loc="upper left", bbox_to_anchor=(0.90, 0.69), ncol=1, fontsize=12, frameon=False, title="Cohort", title_fontproperties={'size': 14, 'weight': 'bold'})

    handles_centile = [plt.Line2D([0], [0], color="black", markersize=8, lw=3, linestyle='-', label='Median'),
                        plt.Line2D([0], [0], color="black", markersize=8, lw=3, linestyle='--', label='5th/95th Percentiles')]
    labels_centile = ["Median", "5th/95th Percentiles"]
    fig.legend(handles_centile, labels_centile, loc="upper left", bbox_to_anchor=(0.90, 0.36), ncol=1, fontsize=12, frameon=False)

    row_labels = ['a', 'b']
    ax[0, 0].text(-0.2, 1.07, row_labels[0], transform=ax[0, 0].transAxes, fontsize=18, fontweight='bold', va='top', ha='right')
    ax[1, 0].text(-0.2, 1.07, row_labels[1], transform=ax[1, 0].transAxes, fontsize=18, fontweight='bold', va='top', ha='right')

    # Some adjustements to space between subplots.
    plt.subplots_adjust(wspace=0.25)

    #plt.tight_layout(rect=[0, 0, 1, 0.97])
    plot_path = os.path.join(args.output_dir, "network_GAMLSS_centiles.png")
    plt.savefig(plot_path, dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()

if __name__ == "__main__":
    main()