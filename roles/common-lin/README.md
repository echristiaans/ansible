common-lin
=========

This is the default role for all Linux hosts.
It configures, installs and manages:
- ntp

Requirements
------------

The supported operating systems are:

- CentOS
  - 6
  - 7

These variables are read from the ansible_facts.
The keys are ansible_distribution and ansible_distribution_major_version

Role Variables
--------------

The variables that can be passed to this role and a brief description about
them are as follows.

```yaml
ntp_servers:
  - server1
  - server2
  - serverN

ntp_timezone: Europe/Amsterdam
```

Dependencies
------------

None

License
-------

BSD

Author Information
------------------

- Original : Sentia
- Modified by : Tom van Leeuwen

