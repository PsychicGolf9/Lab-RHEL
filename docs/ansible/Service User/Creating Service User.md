User is logged in over SSH.
A user is added to the system named ansible.
The directory .ssh is created for them.
On the server node, ssh-keygen is used to generate private and public keys for ansible to use.
The public key is copied to the server as authorized_keys in /home/ansible/.ssh/ using scp.
This method is chosen because password authentication is disabled in /etc/ssh/sshd_config.
The owner is changed from root to ansible using chown.
Permissions are set to 700 for the directory and 600 for the authorized_keys file.

A log file of the commands can be found at ./logs/Create Service User.log.

ansible.cfg is edited to choose ansible as the remote_user.
The path to the private key is entered in remote_private_key.

A test is performed to make sure Ansible can now use the service account to make changes to the system using a "test" playbook (/ansible/playbooks/test.yml).
Ansible succeeds, but continues to use human user account.
Looking through Ansible's files shows that the user was still set to admin in the inventory.
Test is run again to verify that the inventory file was overriding ansible.cfg.
grep is used on /etc/shadow to look for ansible's entry.
The result shows that because ansible never had a password set, its shadow entry was locked by default.
    Learning Point: Always ensure every user receives a password, even if it is never going to be used.
                    A workaround to reduce attack surface is to use usermod to set the service account to *, allowing it to have no password for an attacker to guess. This is what will be done here.
Another test is run.
Ansible is still locked out.
journalctl shows that the client side is dropping the connection.
The playbook is run using -vvv to see everything that is sent.
Ansible is trying to use admin's SSH keys.
The issue is now believed to be a non-existent variable name in ansible.cfg that doesn't get resolved, leaving the SSH key to be resolved by the system default.

The test playbook is run again.
Connection succeeds and the userspace test.txt file is written, but the escalated one runs into permission denied.
A look at /etc/sudoers.d shows ansible was not added.
The file is created using:
    echo "ansible ALL:(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/ansible

The test playbook is run again.
Everything succeeds.
Issues resolved and the service user ansible is functional.