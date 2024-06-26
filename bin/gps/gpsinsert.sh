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
# inserts eps file into other ps/eps files
#
#--------------------------------------------------------------

script=$(realpath $0)
FEMBIN=$(dirname $script)

gpsinsert=$FEMBIN/gpsinsert.pl

#--------------------------------------------------------------

NoFile()
{
  echo "No such file: $1"
  Usage
  exit 1
}

ErrorOption()
{
  echo "No such option : $1"
}

Usage()
{
  echo "Usage: gpsinsert [-h|-help] [options] where eps-file ps-file(s)"
}

FullUsage()
{
  echo ""
  Usage
  echo ""
  echo "  options:"
  echo "    -h|-help        this help screen"
  echo "    -relative       use relative coordinates for insert [0-1]"
  echo "    -reggrid        inserts reggrid into file for orientation"
  echo ""
  echo "  where             \"x1 y1 x2 y2\" which defines box where to insert"
  echo "  eps-file          file to be inserted (must be eps)"
  echo "  ps-file(s)        file(s) where eps-file is inserted"
  echo ""
  echo "  if one of x2,y2 is 0 the aspect ratio of eps-file is retained"
  echo "  the output is written to file incl_ps-file(s)"
  echo ""
  echo "  example:"
  echo "    gpsinsert -relative \"0.8 0.8 0.9 0\" logo.eps plot.ps"
  echo "    (output goes to incl_plot.ps)"
  echo ""
}

#--------------------------------------------------------------

options=""

while [ -n "$1" ]
do
   case $1 in
        -relative)      options="$options -relative";;
        -reggrid)       options="$options -reggrid";;
        -h|-help)       FullUsage; exit 0;;
        -*)             ErrorOption $1; exit 1;;
        *)              break;;
   esac
   shift
done

if [ $# -lt 3 ]; then
  Usage
  exit 1
fi

#--------------------------------------------------------------

prefix="incl_"
where=$1
epsfile=$2
shift
shift

#--------------------------------------------------------------

[ -f $epsfile ] || NoFile $epsfile

echo "Insert file $epsfile into: $where"

for file
do
  [ -f $file ] || NoFile $file
  echo $file
  $gpsinsert $options "$where" $epsfile $file > tmp.tmp
  [ -z "$prefix" ] && mv $file $file.bak
  mv tmp.tmp $prefix$file
done

#--------------------------------------------------------------

