function dev_docker_tools() {
  docker_dir=$HOME/go/src/github.com/docker/docker
  state=$(docker-machine ls --filter name=docker-dev -f '{{.State}}')

  if [ "$1" == 'create' ]; then
    docker-machine create -d virtualbox --virtualbox-disk-size "20000" --virtualbox-cpu-count "4" --virtualbox-memory "3024" docker-dev # --virtualbox-no-share
  elif [ "$1" == 'rm' ]; then
    docker-machine rm docker-dev
  elif [ "$1" == 'start' ]; then
    docker-machine start docker-dev
  elif [ "$1" == 'stop' ]; then
    docker-machine stop docker-dev
  elif [ "$1" == 'regen' ]; then
    docker-machine regenerate-certs docker-dev
  elif [ "$1" == 'env' ]; then
    eval "$(docker-machine env docker-dev)"
  elif [ "$1" == 'ssh' ]; then
    shift
    docker-machine ssh docker-dev $@
  elif [ "$1" == 'test' ]; then
    (
      cd $docker_dir
      echo "[[[[[$(date)]]]]]" >> /tmp/docker-current-build
      make test | tee -a /tmp/docker-current-build | grep -v PASS:
    )
  elif [ "$1" == 'integration' ]; then
    (
      cd $docker_dir
      make test-integration-cli | grep -v PASS:
    )
  elif [ "$1" == 'clean' ]; then
    (
      docker rm -v $(docker ps -a -q -f status=exited)
      docker rmi $(docker images -q -f dangling=true)
    )
  elif [ "$1" == 'build' ]; then
    (
      cd $docker_dir
      make BIND_DIR=. cross && docker_tools_copy && docker_tools_restart_server
    )
  elif [ "$1" == 'copy' ]; then
    docker_tools_copy
    docker_tools_restart_server
  elif [ "$1" == 'docs' ]; then
    (
      cd $docker_dir/docs
      make docs &
      pid=$!
      fswatch -ro0 . | while read -d "" line
      do
        kill -2 $pid
        make docs &
        pid=$!
      done
    )
  elif [ "$1" == 'exec' -o "$1" == 'docker' ]; then
    shift
    $docker_dir/bundles/latest/cross/darwin/amd64/docker $@
  else
    echo "Unrecognized command"
    return 1
  fi
}

function docker_tools_copy() {
  docker-machine ssh docker-dev -- 'rm -rf ~/docker-binaries; mkdir ~/docker-binaries'
  docker-machine scp $docker_dir/bundles/latest/binary-client/docker docker-dev:/home/docker/docker-binaries
  docker-machine scp $docker_dir/bundles/latest/binary-daemon/dockerd docker-dev:/home/docker/docker-binaries
  docker-machine scp $docker_dir/bundles/latest/binary-daemon/docker-containerd docker-dev:/home/docker/docker-binaries
  docker-machine ssh docker-dev -- 'sudo cp ~/docker-binaries/docker* /usr/local/bin'
}

function docker_tools_restart_server() {
  docker-machine ssh docker-dev -- 'sudo /etc/init.d/docker restart'
}

export -f dev_docker_tools
alias ddev=dev_docker_tools
alias ddev=dev_docker_tools
