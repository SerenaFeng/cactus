#!/bin/bash


if [ $# == 0 ]; then
  echo $USAGE
  exit 1
fi

FIND=$1
INCMD=bash
if [ $# -gt 1 ]; then
  INCMD=$2
fi

contids=`docker ps | grep $FIND | awk '{print $1}'`

IFS=' ' read -r -a cs <<< $contids
container=${cs[0]}
echo $container $INCMD
docker exec -ti $container $INCMD
