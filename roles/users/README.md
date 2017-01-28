#  ATBank Users

This role installs user accounts for teams and individual users authorized to login to and administor systems.  

While its primary purpose is to add infrastructure team member accounts to all systems using the role, it can also be used by teams to individually add users and teams to specific systems if so desired. This role will also delete user accounts.

All users within this role created on systems via will be granted root privleges.

## Requirements

None.

## Role Variables

This role contains multiple variable files to control the creation of user accounts.

### users.yml

This var file contains a list or all users that may be granted access to any system that is a member of this role. Inclusion of a user in this file does NOT by default grant a user access to a system but just enables the user defined to be declared elsewhere within this role or playbook calling this role.

#### Usage
```yaml
    firstname_tussen_voegsel_lastname:
      - username: "firstnamel"
        linux_pw_hash: "$6$passwordhashetcetcetc/"
        ssh_rsa_key: "ssh-rsa AAAAblahblahbkeystuffkeystufftimes6linesofblah== name@somthing"
    2ndname_lastname_etc:
      - username "person2"
        ...
```

The linux_pw_hash is a SHA512 hash of a users chosen password. See the Generating Password Hashes section for details on how to do this.

### teams.yml

This var file is where users are referenced in their teams.

#### Usage
```yaml
    team_infra:
      - "{{ firstname_tussen_voegsel_lastname }}"
      - "{{ 2ndname_lastname_etc}}"

    team_xray:
      - "{{ firstname_lastname }}"
      ...
```

### Defaults

*senadmins:*  - This variable defines the name of the group all users are added to, which is in turn added to sudoers

*auth_allow_always:* - Teams listed in this array will have team members always be granted access to systems

*auth_allow_teams:* - A variable included as a placeholder in case extra team users are not defined in a playbook file.

*auth_allow_users:* - A variable included as a placeholder in case extra individual users are not defined in a playbook file.

*auth_delete_teams:* - A variable included as a placeholder in case teams to be have all their users removed from a server.

*auth_delete_users:* - A variable included as a placeholder in case individual users are to be removed from a server.

*auth_delete_extra_users:* - A variable used as a placeholder for deletion of usernames be string match rather than defined in the users.yml file.

## Playbook usage

To have all users defined in infrausers.yml to be created and granted root privleges on a system included in a playbook, simply add the role:
```yaml
    role: atbank-users
```

To have additional users not listed in infrausers.yml that you want to be granted access to an individual systems in more restrictive playbooks, but not all systems using the role, you can include the eaxtra variables.

```yaml
    role: atbank-users

    vars:
      auth_allow_teams:
          - "{{ team_xray }}"
          - "{{ team_zebra }}"
      auth_allow_users:
          - "{{ firstname_lastname }}"
      auth_delete_teams:
          - "{{ team_november }}"
      auth_delete_users:
          - "{{ 2ndname_lastname }}"
      auth_delete_extra_users:
          - "wilcoe"
          - "wilcotest"
```
## Generating Password Hashes

If you are running linux you can install the *mkpaswd* utility to generate a password hash.
```
[user@localhost]$ mkpasswd --method=SHA-512
```

If not, you can also use Python. First make sure the *passlib* module is installed:

```
MacBook-Pro:~ user$ pip install passlib
```

Then generate your password using this easy to read line:

```
MacBook-Pro:~ user$ python -c "from passlib.hash import sha512_crypt; import getpass; print sha512_crypt.encrypt(getpass.getpass())"
```

To create the bsd password, install the bcypt module and run the python command:
```
MacBook-Pro:~ user$ pip install bcrypt
MacBook-Pro:~ user$ python -c 'import bcrypt; import getpass; print bcrypt.hashpw(getpass.getpass(), bcrypt.gensalt(prefix=b"2a",rounds=14))'
```

### Another alternative -- Via Web

* https://quickhash.com/crypt3-sha512-online

# OpenBSD sudo, become and python

Since OpenBSD 5.8 sudo has been replaced by doas, to use this in Ansible you need to add something extra to the hosts parameters.

In your yml for the host add:
ansible_become_method: doas

Besides this the python path seems to be different in some versions of OpenBSD, make sure you add the python interpreter in your hosts inventory as well.
Set this under the vars:
ansible_python_interpreter: /usr/local/bin/python2.7

As an example:
```
- hosts: sen-myhost
  become_method: doas

  roles:
    - role: atbank-users

  vars:
    auth_allow_teams:
      - "{{ team_infra }}"
    ansible_python_interpreter: /usr/local/bin/python2.7
```    
