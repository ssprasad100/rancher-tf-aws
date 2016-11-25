#!/bin/bash

if [ $(basename $PWD) != "scripts" ]; then
   echo "ERROR: Run this script from scripts directory. Exiting"
   exit 1
fi

#
# Adding tr to fix line ending issue of windows, relying on tr as dos2unix may not be available on all platforms. 
#
for f in install*sh
do
tr -d '\015' <$f > ${f}_1
mv ${f}_1 ${f}
done

cd ..;

step=$1;
if [ "$step" = "1" ]|| [ "$step" = "all" ]
 then
   terraform apply -target=aws_route_table_association.public -target=aws_security_group.web -target=aws_instance.rancher[0]
fi

if [ "$step" = "2" ] || [ "$step" = "all" ]

 then
echo "============== Sleeping 60 seconds =================";
sleep 60;
echo "============== Awake and on to next =============" 
masterIP=$(terraform show | grep "rancher.0.ip" | cut -d"=" -f2 | tr -d '[:space:]' | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g")

echo "Master IP is '$masterIP'";
cat <<EOF> scripts/curlstuff.sh
#
# Command to create new environment
#
curl -g \
-X POST \
-H 'Accept: application/json' \
-H 'Content-Type: application/json' \
-d '{"description":"Kubernetes Test via API", "name":"k8sapitest", "allowSystemRole":false, "members":[], "swarm":false, "kubernetes":true, "mesos":false, "virtualMachine":false, "publicDns":false, "servicesPortRange":null}' \
"http://${masterIP}:8080/v1/projects"

echo "====================  Separator ==========================";
sleep 10;
#
# Add current host as API master
#
curl \
-X PUT \
-H 'Accept: application/json' \
-H 'Content-Type: application/json' \
-d '{"activeValue":null, "id":"1as!api.host", "name":"api.host", "source":null, "value":"http://${masterIP}:8080"}' \
'http://${masterIP}:8080/v1/activesettings/1as!api.host'

echo "====================  Separator ==========================";
sleep 20;
curl \
-X POST \
-H 'Accept: application/json' \
-H 'Content-Type: application/json' \
-d '{"description":"new token for k8sapitest", "name":"token_k8sapitest"}' \
'http://${masterIP}:8080/v1/projects/1a7/registrationtokens'

echo "====================  Separator ==========================";
EOF

bash scripts/curlstuff.sh

fi

if [ "$step" = "5" ] || [ "$step" = "all" ]
 then
   terraform apply
fi

if [ "$step" = "del" ]; then
   terraform destroy
fi	
