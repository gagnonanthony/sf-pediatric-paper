![Python](https://img.shields.io/badge/python-3670A0?style=for-the-badge&logo=python&logoColor=ffdd54)
![R](https://img.shields.io/badge/r-%23276DC3.svg?style=for-the-badge&logo=r&logoColor=white)


## Setting up

This repository is using multiple virutal environment to access uncompatible dependencies. Please create individual virtualenv for the following package below:

`neurostatx`: Official instruction can be seen [here](https://gagnonanthony.github.io/NeuroStatX/)
```bash
pip install neurostatx==0.1.0

# Test the installation by calling the help of a CLI script.

AddNodesAttributes -h
```

## Structure

### `notebooks/`
Jupyter notebooks containing the complete analytical workflow.



### `scripts/`
R and Python scripts for specific analyses:

- **`mlcmm.R`** - Latent class mixed models for trajectory analysis using `lcmm` package
- **`evaluateTrajectories.R`** - Model evaluation and trajectory characterization
- **`trajectoryPredictors.R`** - Predictors of trajectory class membership
- **`posteriorProbabilities.R`** - Posterior probability calculations for class assignment
- **`bestModel.R`** - Model selection based on fit statistics
- **`plotForest.R`** - Forest plot generation for odds ratios with publication-ready formatting
- **`generateSurfaceOverlay.py`** - Brain surface visualization overlays
- **`cmd_mlcmm.sh`** - Wrapper script for running trajectory models on HCP servers.

### `atlas/`
Brainnetome Child atlas files and conversion scripts:

- **`atlas-BrainnetomeChild/`** - BIDS-compliant atlas files (fsaverage and fsLR-32k spaces)
- **`create_atlas_fsLR_32k.sh`** - Bash script for atlas conversion to fsLR surface space
- **`refs/`** - Reference files including FreeSurfer labels and lookup tables
- **`readme.md`** - Detailed atlas documentation and usage instructions

## Contact

For questions or issues, please open an issue! 