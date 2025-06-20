#!/bin/bash
# ================================================================================
# Component : OEDA install script
# Version   : 1.1
# Date      : 20-Jun-2025
# Author    : Rohit Chaudhari
# Description : Installs OEDA PL/SQL & REST artifacts, uploads with FNDLOAD, irep.
# Usage     : ./install.sh
# ================================================================================


ENV_SCRIPT=/u01/install/APPS/EBSapps.env
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ ! -f "$ENV_SCRIPT" ]; then
  echo "ERROR: EBS env script not found: $ENV_SCRIPT" >&2
  exit 1
fi
. "$ENV_SCRIPT"


echo "***********************************************"
read -sp "Enter APPS password: " APPS_PWD
echo
echo
echo "***********************************************"


sqlplus -L -s apps/"${APPS_PWD}"@${TWO_TASK} >/dev/null <<EOF
EXIT
EOF
if [ $? -ne 0 ]; then
  echo "ERROR: Invalid APPS password" >&2
  exit 1
fi
echo "APPS authentication OK."


echo "Copying PL/SQL sources to $FND_TOP/sql…"
cp XX_OEDA_DOWNLOAD_UTILITY.pls $FND_TOP/patch/115/sql
for file in XX_OEDA_DOWNLOAD_UTILITY.pks XX_OEDA_DOWNLOAD_UTILITY.pkb; do
  cp "$file" "$FND_TOP/sql/" || {
    echo "ERROR: Copy failed for $file" >&2
    exit 2
  }
done
echo "PL/SQL sources copied."


echo "Deploying REST definitions with irep_parser"
$IAS_ORACLE_HOME/perl/bin/perl $FND_TOP/bin/irep_parser.pl -g -v -username=sysadmin fnd:patch/115/sql:XX_OEDA_DOWNLOAD_UTILITY.pls:12.0=XX_OEDA_DOWNLOAD_UTILITY.pls  \
|| {
  echo "ERROR: irep_parser failed" >&2
  exit 3
}
echo "REST definition deployed."


echo "Uploading ILDT via FNDLOAD…"
$FND_TOP/bin/FNDLOAD APPS/apps 0 Y UPLOAD $FND_TOP/patch/115/import/wfirep.lct XX_OEDA_DOWNLOAD_UTILITY_pls.ildt \
|| {
  echo "ERROR: FNDLOAD upload failed" >&2
  exit 4
}
echo "ILDT uploaded."

echo "============================================"
echo " OEDA install completed successfully."
echo "============================================"
exit 0
