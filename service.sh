#!/bin/bash
#set -x
#获取 token
ans=$(curl -s -X POST -H "Content-Type: application/json" -d '{  "app_key": "fbfa832dee2b434582cf726c6cacfcf7",  "app_secret": "495567f8becd457e9719371335f9d472"}' "https://open.c.163.com/api/v1/token")
token=`echo $ans | awk -F ',' '{print $1}' | awk -F ':' '{print $2}' | sed 's/^.//' | sed 's/.$//'`
echo "token: $token"

#获取镜像仓库id 
repos_id=$(curl -s -X GET -H "Authorization: Token ${token}" -H "Content-Type: application/json" "https://open.c.163.com/api/v1/repositories?limit=20&offset=0" | grep test | awk -F ',' '{print $2}' | awk -F ':' '{print $3}')
echo "repos_id: $repos_id"

#获取新创建镜像的status
status=$(curl -s -X GET -H "Authorization: Token ${token}" -H "Content-Type: application/json" "https://open.c.163.com/api/v1/repositories/${repos_id}" | head -n 1 | awk -F ',' '{print $3}' | awk -F ':' '{print $2}' | sed 's/.$//')
echo "image status: $status"

#获取新镜像版本号。可以考虑记录上次的最新镜像版本，与本次的镜像版本对比，判断是否是最新的镜像。
image_tag=$(curl -s -X GET -H "Authorization: Token ${token}" -H "Content-Type: application/json" "https://open.c.163.com/api/v1    /repositories/${repos_id}" | awk -F ':' '{print $3}' | awk -F ',' '{print $1}') # | sed 's/^.//' | sed 's/.$//')
echo "image_tag: $image_tag"
image_tag2=$(echo $image_tag | sed 's/^.//' | sed 's/.$//')
echo "image_tag2: $image_tag2"
#echo "hub.c.163.com/wanghongpeng0102/test:${image_tag2}"

#镜像未创建完成时
while true;do
  if [ $status -eq 0 ]||[ $status -eq 1 ];then
    sleep 2
  else
    break
  fi
done

#镜像创建失败时
if [ $status -eq 3 ];then
  echo "image error !"
  exit 0
fi

#新建公网ip并获取ip的uuid
ip_uuid=$(curl -s -X POST -H "Authorization: Token ${token}" -H "Content-Type: application/json" -d '{ "nce": 1, "nlb": 0}' "https://open.c.163.com/api/v1/ips" | awk -F ',' '{print $2}' | awk -F ':' '{print $3}') # | sed 's/^.//' | sed 's/.$//')
echo "ip_uuid: $ip_uuid"

#创建云硬盘，本示例云硬盘名称为镜像tag
disk_id=$(curl -s -X POST -H "Authorization: Token ${token}" -H "Content-Type: application/json" -d '{"size": 10,  "volume_name": '$image_tag'}' "https://open.c.163.com/api/v1/cloud-volumes" | awk -F ':' '{print $2}' | sed 's/.$//')
echo "disk_id: $disk_id"
sleep 2

#创建密钥并获取密钥名称，本示例密钥名称为镜像tag
key=$(curl -s -X POST -H "Authorization: Token ${token}" -H "Content-Type: application/json" -d '{"key_name": '$image_tag'}' "https://open.c.163.com/api/v1/secret-keys")
#echo "key: $key"

#获取密钥列表
#curl -X GET -H "Authorization: Token ${token}" -H "Content-Type: application/json" "https://open.c.163.com/api/v1/secret-keys" &>/dev/null

#获取空间id, 本示例使用命名空间default
namespace_id=$(curl -s -X GET -H "Authorization: Token ${token}" -H "Content-Type: application/json" "https://open.c.163.com/api/v1/namespaces" | awk -F '{' '{print $NF}' | awk -F ',' '{print $2}' | awk -F ':' '{print $2}')
echo "namespace_id: $namespace_id"

#镜像创建成功时新建服务并获取新建服务的id,本示例服务名称和容器名称都为新镜像tag
if [ $status -eq 2 ];then
  echo $(curl -s -X POST -H "Authorization: Token ${token}" -H "Content-Type: application/json" -d '{
    "bill_info":"default",
        "service_info": {
        "namespace_id": '$namespace_id',
        "stateful": "1",
        "replicas": 1,
        "service_name": '$image_tag',
        "port_maps": [
            {
                "dest_port": "80",
                "source_port": "8080",
                "protocol": "TCP"
            }
        ],
        "spec_id": 1,
        "state_public_net": {
            "used": true,
            "type": "flow",
            "bandwidth": 20
        },
        "disk_type": 0,
        "ip_id": '$ip_uuid'
    },
    "service_container_infos": [
        {
            "image_path": "hub.c.163.com/wanghongpeng0102/test:'$image_tag2'",
            "container_name": '$image_tag',
            "command": "",
            "envs": [
                {
                    "key": "password",
                    "value": "password"
                },
                {
                    "key": "user",
                    "value": "user"
                }
            ],
            "log_dirs": [
                "/var/log/"
            ],
            "cpu_weight": 100,
            "memory_weight": 100,
            "ssh_keys": [
                "miyao6",'$image_tag'
            ],
            "local_disk_info": [],
            "volume_info": {
                "'$disk_id'": "/data/"
            }
        }
    ]
}' "https://open.c.163.com/api/v1/microservices")
fi
