Role Name
=========

This role app_tentacle installs a single Octopus LISTENING Tentacle version on a Windows server.
It is tailored for a 2.x Octopus Tentacle, you can try a 3.x or adjust the playbook.

Requirements
------------

Windows Server capable for installing MSI's.
Put your desired Octopus Tentacle version on a repo you can download from.

Role Variables
--------------

@Sentia we place vars in the host.yml, you can use these variables :

vars:
  octopus:
	 installdir: 'D:\\OctopusDeploy\\Tentacle'										# Where the tentacle binaries are installed , DO NOT USE A SPACE IN THIS PATH !
	 downloadurl: 'http://sen-ans-g1/repo/Octopus.Tentacle.2.6.5.1010-x64.msi'		# Specify your download URL
	 tentaclehomedir: 'D:\\Octopus'													# Homedir for created tentacles
	 tentacledir: 'D:\\Octopus\\Tentacle'											# Directory where tentacle configs are stored
	 tentacleappdir: 'D:\\Octopus\\Applications'									# Directory where Octopus application builds are put
	 tentacleinstance: 'Tentacle'													# Tentacle instance name
	 tentacletrustkey: '1F87554E02DB886385798198791463D0B4163DDC'					# Tentacle trust key
	 tentacleport: '10933'															# Tentacle listen port.
     tentacleconfdest: 'C:\\scripts\\configure_tentacle.ps1'                        # Tentacle configuration Posh script location.
     tentacleconfigure: true                                                        # Run the configuration or not (do not forget to change this to false after succesful run!)
     tentacleremoveconfig: true                                                     # Set tentacleremoveconfig: true to delete the tentacle specified in the vars
                                                                                    # Combine this with the tentacleconfigure: false en reprovision you tentacle.

Dependencies
------------

common-win
iis

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:
This role provides a single tentacle.

---
  - hosts: fca-web-xxx.domain.nl
    roles:
     - role: common-win
     - role: iis
     - role: app_tentacle

    vars:
       octopus:
         installdir: 'D:\\OctopusDeploy\\Tentacle'
         downloadurl: 'http://sen-ans-g1/repo/Octopus.Tentacle.2.6.5.1010-x64.msi'
         downloaddest: 'C:\Scripts\Octopus.Tentacle.2.6.5.1010-x64.msi'
         tentaclehomedir: 'D:\\Octopus'
         tentacledir: 'D:\\Octopus\\Tentacle'
         tentacleappdir: 'D:\\Octopus\\Applications'
         tentacleinstance: 'Tentacle'
         tentacletrustkey: '000000000000000000000000000000000000000'
         tentacleport: '10933'
         tentacleconfdest: 'C:\\scripts\\configure_tentacle.ps1'
         tentacleconfigure: true

License
-------

BSD

Author Information
------------------

Raymond Akker Sentia B.V.
