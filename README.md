![Python](https://img.shields.io/badge/python-3670A0?style=for-the-badge&logo=python&logoColor=ffdd54)
![R](https://img.shields.io/badge/r-%23276DC3.svg?style=for-the-badge&logo=r&logoColor=white)

# sf-pediatric paper - Code Repository

This repository contains all code and analysis scripts accompanying our publication showcasing [sf-pediatric](https://github.com/scilus/sf-pediatric.git).

## Repository Structure

### `notebooks/`
Jupyter notebooks containing the complete analytical workflow and figures:

- **`studypop.ipynb`** - Study population characterization and demographic analyses
- **`demo_table.ipynb`** - Generation of demographic summary tables
- **`bundleModels.ipynb`** - White matter bundle-specific GAMLSS models and trajectory analyses
- **`network.ipynb`** - Graph theory network analyses and connectivity metrics
- **`fanning.ipynb`** - Analysis of white matter bundle fanning patterns
- **`priors.ipynb`** - Prior distribution analyses and model initialization

### `scripts/`

#### Python Scripts
- **`bundleGAMLSS.py`** - Fit GAMLSS models for white matter bundle metrics with publication-ready figures
- **`networkGAMLSS.py`** - Fit GAMLSS models for graph network metrics with visualization
- **`extract_first_volume.py`** - Utility for extracting first volumes from 4D images

#### R Scripts
- **`gamlss.R`** - Core GAMLSS model fitting using the `gamlss` package

#### Preprocessing Scripts
Bash scripts for data preprocessing and BIDS conversion:
- **`convert_bids.sh`** - Convert raw data to BIDS format
- **`bind_fmaps.sh`** - Bind fieldmap files for distortion correction
- **`split_fmaps.sh`** - Split multi-volume fieldmaps
- **`phase_encoding.sh`** - Handle phase encoding metadata
- **`remove_first_vol.sh`** - Remove first volume from timeseries
- **`reorganize_subject.sh`** - Reorganize subject data structure
- **`round_totalreadouttime.sh`** - Adjust total readout time metadata
- **`sanitize_runs.sh`** - Sanitize run numbering and naming

### `configs/`
Configuration files:
- **`dcm2bids_config_PING.json`** - DICOM to BIDS conversion configuration for PING dataset

## Requirements

This repository uses Python and R with the following key dependencies:

**Python (those are the core packages, a complete list is provided in the `requirements.txt` file):**
- neurostatx==0.1.0 ([installation guide](https://gagnonanthony.github.io/NeuroStatX/))
- pandas, matplotlib, seaborn
- networkx (for graph analyses)
- MNE-Python (for connectivity visualization)

**R:**
- gamlss (for trajectory modeling)
- optparse
- ggplot2

## Setup

Install the Python environment:
```bash
pip install -r requirements.txt

# Test the installation
AddNodesAttributes -h
```

## Citation

If you use this code, please cite our paper:
[Citation information to be added upon publication]

## Contact

For questions or issues, please open an issue on GitHub or contact the corresponding author.

## License

See LICENSE file for details. 