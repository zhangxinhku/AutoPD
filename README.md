# AutoPD
AutoPD is an automatic biological macromolecular crystallography data processing and structure determination pipeline for high-performance synchrotron radiation sources and academic users. Requiring only diffraction data and a sequence file for input, this pipeline efficiently generates high-precision structural models.

## Requirements
To utilize the full capabilities of AutoPD, the following software packages must be installed:
### CCP4
Downloads website: [https://www.ccp4.ac.uk/](https://www.ccp4.ac.uk/)
### Phenix
Downloads website: [https://phenix-online.org/download](https://phenix-online.org/download)
### XDS
Downloads website: [https://xds.mr.mpg.de/html_doc/downloading.html](https://xds.mr.mpg.de/html_doc/downloading.html)
### DIALS
Downloads website: [https://dials.github.io/installation.html](https://dials.github.io/installation.html)
### autoPROC
Downloads website: [https://www.globalphasing.com/autoproc/](https://www.globalphasing.com/autoproc/)
### parallel
```
sudo apt install parallel
```
### gnuplot
```
sudo apt install gnuplot
```
### pandas
```
sudo apt install python3-pip
pip install pandas
```
### IPCAS (optional)
The installation package for IPCAS can be found on the main page. Follow these commands to install:
```
tar xvf Ipcas_source_3.0beta_for_22_03_25.tar.gz
cd Ipcas_source_3.0beta_for_22_03_25.tar.gz
./ipcas_install.tcsh
```

To enable these software packages for bash users, add the following lines to your ~/.bashrc file:
```
#CCP4
source <path>/ccp4-8.0/bin/ccp4.setup-sh
#Phenix
source <path>/phenix-1.21-5207/phenix_env.sh
#XDS
export PATH=<path>/XDS-INTEL64_Linux_x86_64/:$PATH
#DIALS
source <path>/dials-v3-17-0/dials_env.sh
#autoPROC
source <path>/autoPROC_snapshot_20240123/setup.sh
#IPCAS
export oasisbin=<path>/ccp4-8.0/share/ccp4i/ipcas
export LD_LIBRARY_PATH=<path>/ccp4-8.0/share/ccp4i/ipcas/lib/:$LD_LIBRARY_PATH
```

## Installation
To install AutoPD, download and unpack the repository. Remember to add the following line to your ~/.bashrc file to ensure the path is correctly set:
```
export PATH=<path>/AutoPD/:$PATH
```

Please note an issue with the ProvideAsuContents.py file in the CCP4 installation folder. For Buccaneer to run successfully, replace the existing ProvideAsuContents.py (located at `$CCP4/lib/python3.9/site-packages/ccp4i2/wrappers/ProvideAsuContents/script/ProvideAsuContents.py`) and CCP4I2Runner.py (located at `$CCP4/lib/python3.9/site-packages/ccp4i2/core/CCP4I2Runner.py`) with the version provided in the main branch (contributed by Stuart McNicholas). These files are only applicable to CCP4-9.

## Usage
AutoPD is straightforward to use. Provide the path to your diffraction data and sequence file, then execute the command as follows:
```
autopipeline.sh data_path=<path_to_diffraction_data> seq_file=<path_to_sequence>/sequence.fasta out_dir=<output_folder_name> | tee output.log
```
AutoPD supports optional parameters for enhanced flexibility:  
- **mtz_file=<path_to_mtz_file>/data.mtz**:   Skips data reduction if provided. AutoPD assumes that the labels in mtz file are F SIGF FreeR_flag or FP SIGFP FreeR_flag.
- **pdb_path=<path_to_pdb_files>**:           Uses provided PDB files for MR, skipping search model generation.
- **image_start=91 image_end=1300**:          Custom image range.
- **rotation_axis=0,0,1**:                    Custom rotation axis for data reduction.
- **beam_x=1200 beam_y=1300**:                Custom beam center in pixels.
- **distance=320**:                           Crystal to detector distance in mm.
- **space_group=P121**:                       Space group.
- **cell=30,40,50,70,80,90**:                 Unit cell parameters.
- **z=1**:                                    The number of asymmetric unit copies.
- **atom=Se**:                                The atom type of anomalous scattering.
- **mp_date=yyyy-mm-dd**:                     Excludes homologs released after this date for MrParse, useful for data tests.
- **pae_split=true**:                         AlphaFold models will be split according to PAE matrix.
- **af_predict=true**:                        Enforce AlphaFold prediction.
- **sad=true**:                               Enforce SAD phasing.

## Note
Currently, AutoPD supports only command-line executions and has been tested exclusively on the Ubuntu 22.04 operating system. The compatibility with other operating systems has not been established. If you have any questions or issues, please contact Xin at zx2020@connect.hku.hk.
