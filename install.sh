#!/bin/bash
# The previous line forces this script to be run with bash, regardless of user's 
# shell.
#
# EPN, Thu Jan 17 12:59:26 2019
#
# A shell script for installing ribovore its dependencies
# for ribosomal RNA sequence analysis.
#
RIBOINSTALLDIR=$PWD
VERSION="0.35"
RVERSION="ribovore-$VERSION"
BLASTVERSION="2.8.1"

# The following line will make the script fail if any commands fail
set -e
#
echo "------------------------------------------------"
echo "INSTALLING RIBOVORE $VERSION"
echo "------------------------------------------------"
echo ""
echo "************************************************************"
echo "IMPORTANT: BEFORE YOU WILL BE ABLE TO RUN RIBOVORE"
echo "SCRIPTS, YOU NEED TO FOLLOW THE INSTRUCTIONS OUTPUT AT"
echo "THE END OF THIS SCRIPT TO UPDATE YOUR ENVIRONMENT VARIABLES."
echo "************************************************************"
echo ""
echo "Determining current directory ... "
echo "Set RIBOINSTALLDIR as current directory ($RIBOINSTALLDIR)."

echo "------------------------------------------------"
# Clone what we need from GitHub (these are all public)
# ribovore

# ribovore
echo "Installing ribovore ... "
curl -k -L -o ribovore-$VERSION.zip https://github.com/nawrockie/ribovore/archive/$VERSION.zip; unzip ribovore-$VERSION.zip; rm ribovore-$VERSION.zip

# rRNA_sensor
echo "Installing rRNA_sensor ... "
curl -k -L -o rRNA_sensor-$RVERSION.zip https://github.com/aaschaffer/rRNA_sensor/archive/$RVERSION.zip; unzip rRNA_sensor-$RVERSION.zip; rm rRNA_sensor-$RVERSION.zip

# epn-options, epn-ofile epn-test
echo "Installing required perl modules ... "
for m in epn-options epn-ofile epn-test; do 
    curl -k -L -o $m-$RVERSION.zip https://github.com/nawrockie/$m/archive/$RVERSION.zip; unzip $m-$RVERSION.zip; rm $m-$RVERSION.zip
done

##########BEGINNING OF LINES TO COMMENT OUT TO SKIP INFERNAL INSTALLATION##########################
# Install Infernal 1.1.2
# You can comment out this part if you already have Infernal installed 
# on your system.
echo "Installing Infernal 1.1.2 ... "
curl -k -L -o infernal-1.1.2.tar.gz http://eddylab.org/infernal/infernal-1.1.2.tar.gz
tar xfz infernal-1.1.2.tar.gz
cd infernal-1.1.2
sh ./configure --prefix $RIBOINSTALLDIR
make
make install
cd easel
make install
cd $RIBOINSTALLDIR
echo "Finished installing Infernal 1.1.2"
echo "------------------------------------------------"
##########END OF LINES TO COMMENT OUT TO SKIP INFERNAL INSTALLATION##########################
# 
################
# Output the final message:
echo ""
echo ""
echo "********************************************************"
echo "The final step is to update your environment variables."
echo "(See ribovore/README.txt for more information.)"
echo ""
echo "If you are using the bash shell, add the following"
echo "lines to the '.bashrc' file in your home directory:"
echo ""
echo "export RIBODIR=\"$RIBOINSTALLDIR/ribovore-$VERSION\""
echo "export RIBOINFERNALDIR=\"$RIBOINSTALLDIR/bin\""
echo "export RIBOEASELDIR=\"$RIBOINSTALLDIR/bin\""
echo "export RIBOTIMEDIR=\"/usr/bin\""
echo "export SENSORDIR=\"$RIBOINSTALLDIR/rRNA_sensor-$RVERSION\""
echo "export EPNOPTDIR=\"$RIBOINSTALLDIR/epn-options-$RVERSION\""
echo "export EPNOFILEDIR=\"$RIBOINSTALLDIR/epn-ofile-$RVERSION\""
echo "export EPNTESTDIR=\"$RIBOINSTALLDIR/epn-test-$RVERSION\""
echo "export PERL5LIB=\"\$RIBODIR:\$EPNOPTDIR:\$EPNOFILEDIR:\$EPNTESTDIR:\$PERL5LIB\""
echo "export PATH=\"\$RIBODIR:\$SENSORDIR:\$PATH\""
echo "export BLASTDB=\"\$SENSORDIR:\$BLASTDB\""
echo ""
echo "After adding the export lines to your .bashrc file, source that file"
echo "to update your current environment with the command:"
echo ""
echo "source ~/.bashrc"
echo ""
echo "---"
echo "If you are using the C shell, add the following"
echo "lines to the '.cshrc' file in your home directory:"
echo ""
echo "setenv RIBODIR \"$RIBOINSTALLDIR/ribovore-$VERSION\""
echo "setenv RIBOINFERNALDIR \"$RIBOINSTALLDIR/bin\""
echo "setenv RIBOEASELDIR \"$RIBOINSTALLDIR/bin\""
echo "setenv RIBOTIMEDIR \"/usr/bin\""
echo "setenv SENSORDIR \"$RIBOINSTALLDIR/rRNA_sensor-$RVERSION\""
echo "setenv EPNOPTDIR \"$RIBOINSTALLDIR/epn-options-$RVERSION\""
echo "setenv EPNOFILEDIR \"$RIBOINSTALLDIR/epn-ofile-$RVERSION\""
echo "setenv EPNTESTDIR \"$RIBOINSTALLDIR/epn-test-$RVERSION\""
echo "setenv PERL5LIB \"\$RIBODIR\":\"\$EPNOPTDIR\":\"\$EPNOFILEDIR\":\"\$EPNTESTDIR\":\"\$PERL5LIB\""
echo "setenv PATH \"\$RIBODIR\":\"\$SENSORDIR\":\"\$PATH\""
echo "setenv BLASTDB \"\$SENSORDIR\":\"\$BLASTDB\""
echo ""
echo "And see the notes above after the export commands about blastn and"
echo "infernal and make changes as necessary."
echo ""
echo "After adding the setenv lines to your .bashrc file, source that file"
echo "to update your current environment with the command:"
echo ""
echo "source ~/.cshrc"
echo ""
echo "(To determine which shell you use, type: 'echo \$SHELL')"
echo ""
echo ""
echo "********************************************************"
echo "IMPORTANT INFORMATION ABOUT FURTHER INSTALLATION STEPS"
echo "REQUIRED FOR FULL FUNCTIONALITY OF RIBOVORE:"
echo ""
echo "If you want to use the ribosensor.pl script you will need to"
echo "have blastn installed. If you want to use the ribodbmaker.pl"
echo "script you will need to have blastn and vecscreen_plus_taxonomy"
echo "installed. See below for instructions."
echo ""
echo "To install blastn, run the script 'install-optional-blastn-macosx.sh'"
echo "or 'install-optional-blastn-linux.sh' depending on your OS, and follow"
echo "the instructions output from that command to change the RIBOBLASTDIR"
echo " environment variable. That will install blast version $BLASTVERSION"
echo "which is compatible with this version of ribovore. Alternatively,"
echo "if you already have blastn installed and want to use that version,"
echo "add a line to your .bashrc or .cshrc file that updates the environment"
echo "variable RIBOBLASTDIR to the directory the blastn executable is."
echo ""
echo "To install vecscreen_plus_taxonomy, run the script"
echo " 'install-optional-vecscreen_plus_taxonomy.sh' and follow"
echo "the instructions output from that command to change the RIBOBLASTDIR"
echo "environment variable."
echo ""
echo "********************************************************"
echo ""