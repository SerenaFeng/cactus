ps -ef | grep deploy | grep -v grep | awk '{print $2}' | xargs -I {} sudo kill -kill {} &>/dev/null
