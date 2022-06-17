#!/bin/bash

echo
echo
echo ========================================
echo 	cGenie MyAMI fast setup on NEC HPC
echo 	17/06/2022  - Dennis Mayk          
echo 	dmayk@geomar.de                    
echo ========================================
echo
echo

if [[ -z "$c1" ]]; then
    echo
    echo "Base config is not provided - stop Mad Wizzard" 1>&2
    echo
    exit 1
fi

if [[ -z "$c2" ]]; then
    echo
    echo "USER config is not provided - stop Mad Wizzard" 1>&2
    echo
    exit 1
fi

if [[ -z "$c3" ]]; then
    echo
    echo "Experiment time is not provided - stop Mad Wizzard" 1>&2
    echo
    exit 1
fi

# Create unique project folder name
name=$(mktemp -d genie_XXX)
workDIR="/gxfs_work1/geomar/$USER/$name"
cd $workDIR

# Clone cGenie branch _DEV_FeNIP2cc
git clone -b _DEV_FeNIP2cc https://github.com/derpycode/cgenie.muffin
git clone -b dev https://github.com/dm807cam/Mad-Wizzard.git

# Copy over files from the MAd-Wizzard repo to local CGenie instance
rsync -av $workDIR/Mad-Wizzard/LABS/* $workDIR/cgenie.muffin/genie-userconfigs/LABS/
rsync -av $workDIR/Mad-Wizzard/configs/* $workDIR/cgenie.muffin/genie-main/configs/
rsync -av $workDIR/Mad-Wizzard/forcings/* $workDIR/cgenie.muffin/genie-forcings/
rsync -av $workDIR/Mad-Wizzard/SPIN/* $workDIR/cgenie_output/

cd $workDIR/cgenie.muffin/genie-main

# Add netCDF location to user.mak file
cat user.mak | sed 's/NETCDF_DIR=\/usr\/local/NETCDF_DIR=\/gxfs_home\/sw\/spack\/spack0.16.0\/usr\/opt\/spack\/linux-rhel8-x86_64\/gcc-9.3.0\/netcdf-fortran-4.4.4-zwtmg2ugcbv57auhung3ekkctuf65h7u/' > user.mak1
mv user.mak1 user.mak
cat user.mak | sed "s|\$(HOME)|${workDIR}|" > user.mak1
mv user.mak1 user.mak

# Adjust $HOME --> $WORK in user.sh
cat user.sh | sed "s|\CODEDIR=~|CODEDIR=${workDIR}|" > user.sh1; mv user.sh1 user.sh
cat user.sh | sed "s|\OUTROOT=~|OUTROOT=${workDIR}|" > user.sh1; mv user.sh1 user.sh
cat user.sh | sed "s|\ARCHIVEDIR=~|ARCHIVEDIR=${workDIR}|" > user.sh1; mv user.sh1 user.sh
cat user.sh | sed "s|\LOGDIR=~|LOGDIR=${workDIR}|" > user.sh1; mv user.sh1 user.sh
chmod +x user.sh

# Adjust runmuffin.sh script
cat runmuffin.sh | sed "15 c\HOMEDIR=$workDIR" > runmuffin.sh1; mv runmuffin.sh1 runmuffin.sh
cat runmuffin.sh | sed 's/OMP_NUM_THREADS=2/#OMP_NUM_THREADS=2/' > runmuffin.sh1; mv runmuffin.sh1 runmuffin.sh
cat runmuffin.sh | sed 's/export OMP_NUM_THREADS/#export OMP_NUM_THREADS/' > runmuffin.sh1; mv runmuffin.sh1 runmuffin.sh
chmod +x runmuffin.sh

if [[ -z "$c4" ]]; then
  submitcmd="./runmuffin.sh $c1 LABS $c2 $c3 $c4"
else
  submitcmd="./runmuffin.sh $c1 LABS $c2 $c3"
fi

# Submit job file
echo "#!/bin/bash
#SBATCH --job-name=$name
#SBATCH --nodes=1
#SBATCH --tasks-per-node=2
#SBATCH --cpus-per-task=1
#SBATCH --qos=long
#SBATCH --mem=30000mb
#SBATCH --partition=cluster
#SBATCH --output=$name.out
#SBATCH --error=$name.err
module load gcc/9.3.0 libxslt-gcc9.3.0/1.1.33 netcdf-c-gcc9.3.0/4.7.4 netcdf-cxx-gcc9.3.0/4.2 netcdf-fortran-gcc9.3.0/4.4.4 python/2.7.18
export OMP_NUM_THREADS=2

$submitcmd

jobinfo
" > submit.job

cd $workDIR/cgenie.muffin/genie-main
sbatch submit.job

echo Congratualations, you started Job $name successfully!  Hurra!
