[kubernetes]
${cluster_name} ansible_host=${cluster_endpoint} ansible_connection=kubectl

[kubernetes:vars]
cluster_name=${cluster_name}
environment=${environment}
aws_region=${region}
kubeconfig_cmd=aws eks update-kubeconfig --name ${cluster_name} --region ${region}
