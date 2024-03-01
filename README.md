# AutoPD
AutoPD is an automatic biological macromolecular crystallography data processing and structure determination pipeline for high-performance synchrotron radiation sources and academic users. Requiring only diffraction data and a sequence file for input, this pipeline efficiently generates high-precision structural models.

## Requirements
To access the full features of AutoPD, the following software packages should be installed:
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
### IPCAS (optional)
The IPCAS installation package is included on the main page. To install, execute the following commands:
```
tar xvf Ipcas_source_3.0beta_for_22_03_25.tar.gz
cd Ipcas_source_3.0beta_for_22_03_25.tar.gz
./ipcas_install.tcsh
```

After the successful installation of these softwares, bash users can enable access to these softwares by adding the following lines to their ~/.bashrc file:
```
#CCP4
source <path>/ccp4-8.0/bin/ccp4.setup-sh
#Phenix
source <path>/home/programs/phenix-1.21-5207/phenix_env.sh
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
To install AutoPD, simply download and unpack the repository, and make a note of the path to the folder and adding the following lines to the ~/.bashrc file:
```
export PATH=<path>/AutoPD/:$PATH
```

## Usage
To use AutoPD, you just need to provide your diffraction image path and sequence file and run like this:
```
autopipeline.sh data_path=<path_to_diffraction_data> seq_file=<path_to_sequence>/sequence.fasta out_dir=<output_folder_name> | tee output.log
```

## Note
AutoPD now only supports command-line executions. AutoPD only be tested on the Ubuntu22.04 operation system, the usage on other operation systems are not clear now. If you have any inquiries or problems, please contact Xin via zx2020@connect.hku.hk
