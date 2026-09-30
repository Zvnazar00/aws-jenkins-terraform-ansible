[jenkins_master]
${master_public_ip}

[jenkins_worker]
${worker_private_ip} ansible_ssh_common_args='-o ProxyJump=ubuntu@${master_public_ip}'