#!/bin/sh

if [ "$1" = 'redis-cluster' ]; then
    # Allow passing in cluster IP by argument or environmental variable
    IP="${2:-$IP}"

    max_port=7007
    if [ "$CLUSTER_ONLY" = "true" ]; then
      max_port=7005
    fi

    #循环7000-max_port的整数=port
    for port in `seq 7000 $max_port`; do
      mkdir -p /redis-conf/${port}
      mkdir -p /redis-data/${port}

      #为每个节点创建nodes.conf
      if [ -e /redis-data/${port}/nodes.conf ]; then
        rm /redis-data/${port}/nodes.conf
      fi

      #小于7006的复制redis-cluster.conf配置文件，>=7006复制redis.conf
      if [ "$port" -lt "7006" ]; then
        PORT=${port} envsubst < /redis-conf/redis-cluster.tmpl > /redis-conf/${port}/redis.conf
      else
        PORT=${port} envsubst < /redis-conf/redis.tmpl > /redis-conf/${port}/redis.conf
      fi

    done
    #---------------------------------------------------------------------------
    #最大port创建supervisor进程管理工具
    bash /generate-supervisor-conf.sh $max_port > /etc/supervisor/supervisord.conf
    supervisord -c /etc/supervisor/supervisord.conf

    sleep 3

    # If IP is unset then discover it
    if [ -z "$IP" ]; then
        IP=`ifconfig | grep "inet addr:17" | cut -f2 -d ":" | cut -f1 -d " "`
    fi
    echo "yes" | ruby /redis/src/redis-trib.rb create --replicas 1 ${IP}:7000 ${IP}:7001 ${IP}:7002 ${IP}:7003 ${IP}:7004 ${IP}:7005
    tail -f /var/log/supervisor/redis*.log
else
  exec "$@"
fi
