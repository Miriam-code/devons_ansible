[linux_hosts]
${ubuntu_name} ansible_host=${ubuntu_ip} ansible_user=${ubuntu_user} ansible_port=${ubuntu_port} ansible_connection=ssh ansible_ssh_private_key_file=${ubuntu_ssh_key} ansible_python_interpreter=${ubuntu_python}

[windows_hosts]
${windows_name} ansible_host=${windows_ip} ansible_user=${windows_user} ansible_port=${windows_port} ansible_connection=winrm ansible_winrm_scheme=${windows_winrm_scheme} ansible_winrm_transport=${windows_winrm_transport} ansible_password=${windows_password} ansible_winrm_server_cert_validation=ignore

[managed_nodes:children]
linux_hosts
windows_hosts

[controller]
localhost ansible_connection=local ansible_python_interpreter=/usr/bin/python3