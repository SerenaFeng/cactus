#!/usr/bin/env bash

set +x

#echo $(python deploy/parse_pdf.py -y ./config/lab/basic/lab.yaml 2>&1)

#node=master01

#n="nodes_${node}_node_type"
#echo ${n}


function parse_yaml {
  local s
  local w
  local fs
  s='[[:space:]]*'
  w='[a-zA-Z0-9_]*'
  fs="$(echo @|tr @ '\034')"

  sed -e 's|---||g' -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
      -e "s|^\($s\)\($w\)$s[:-]$s\(.*\)$s\$|\1$fs\2$fs\3|p" "$1" |
  awk -F"$fs" '{
    ret = index($0, "name:")
    if (ret == 5) {
      gsub("name:", "", $0)
      print $0
    }
  }'
}

function get_vnodes {
  vnodes="$@"
  for vnode in "${vnodes[@]}"; do
    echo -e "$vnode\n"
  done
}

vnodes=`parse_yaml ./config/lab/basic/lab.yaml`

get_vnodes "${vnodes[@]}"

