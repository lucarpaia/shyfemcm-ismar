#!/bin/sh
#
#------------------------------------------------------------------------
#
#    Copyright (C) 1985-2020  Georg Umgiesser
#
#    This file is part of SHYFEM.
#
#------------------------------------------------------------------------
#
# converts ps/eps files to pdf using pstill
#
# might also use option -2

if [ $# -le 0 ]; then
  echo "Usage gps2pdf.sh file(s)"
  exit 0
fi

for file
do
  ext=`echo $file | sed -e 's/^.*\././'`
  name=`basename $file $ext`
  pdffile=$name.pdf
  echo "gps2pdf: $file - $name - $ext -> $pdffile"

  pstill -ccc -gipt -o $pdffile $file

done

#pstill -ccc -gipt -o testfile.pdf testfile.ps

