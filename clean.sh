sudo rm -fr /var/cactus
docker ps | grep cactus | grep -v grep | awk '{print $1}' | xargs -I {} docker rm -f {} &>/dev/null
docker rmi cactus/dib
