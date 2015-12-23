Role Name
=========

This role app_tentacle installs a single Octopus LISTENING Tentacle version on a Windows server.
It is tailored for a 2.x Octopus Tentacle, you can try a 3.x or adjust the playbook.

Requirements
------------

Windows Server capable for installing MSI's. win_msi ansible module.
Your desired Octopus Tentacle version in a repo you can download from.

Role Variables
--------------

@Sentia we place vars in the host.yml, you can add/use these variables :

vars:
  octopus:
	 installdir: 'D:\\OctopusDeploy\\Tentacle'										# Where the tentacle binaries are installed , DO NOT USE A SPACE IN THIS PATH !
	 downloadurl: 'http://sen-ans-g1/repo/Octopus.Tentacle.2.6.5.1010-x64.msi'		# Specify your download URL, your client needs to be able to reach this.
	 downloaddest: 'C:\Scripts\Octopus.Tentacle.2.6.5.1010-x64.msi'                 # Specifiy download destination
     tentaclehomedir: 'D:\\Octopus'													# Homedir for created tentacles
	 tentacledir: 'D:\\Octopus\\Tentacle'											# Directory where tentacle configs are stored
	 tentacleappdir: 'D:\\Octopus\\Applications'									# Directory where Octopus application builds are put
	 tentacleinstance: 'Tentacle'													# Tentacle instance name
	 tentacletrustkey: '000000000000000000000000000000000000000'					# Tentacle trust key
	 tentacleport: '10933'															# Tentacle listen port.
     tentacleconfdest: 'C:\\scripts\\configure_tentacle.ps1'                        # Tentacle configuration Posh script location.
     tentacleremoveconfdest: 'C:\\scripts\\remove_tentacle.ps1'                     # Location for the tentacle remove script
     tentacleconfigure: true                                                        # Run the configuration or not (do not forget to change this to false after succesful run!)
     tentacleremoveconfig: false                                                    # Set tentacleremoveconfig: true to delete the tentacle specified in the vars
                                                                                    # Combine this with the tentacleconfigure: false en reprovision you tentacle.
                                                                                    # Beware, setting this var destroys/deletes and eliminates the tentaclehomedir: !!

Dependencies
------------

common-win

Example Playbook
----------------

This role provides a single tentacle. It can remove the tentacle specified in the vars by toggling with the tentacleconfigure: and tentacleremoveconfig: vars.

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
         tentacletrustkey: '1F87554E02DB886385798198791463D0B4163DDC'
         tentacleport: '10933'
         tentacleconfdest: 'C:\\scripts\\configure_tentacle.ps1'
         tentacleremoveconfdest: 'C:\\scripts\\remove_tentacle.ps1'
         tentacleconfigure: true
         tentacleremoveconfig: false

 # Deleting a tentacle and create a new one.
 
 Step 1 :
     # Set accordingly to delete the current tentacle config created by the playbook.
     tentacleconfigure: false
     tentacleremoveconfig: true
 
 Step 2 :
     # Set accordingly and adjust other tentacle vars as needed to re-create the tentacle.
     tentacleconfigure: true
     tentacleremoveconfig: false

License
-------

BSD

Author Information
------------------

Raymond Akker Sentia B.V.
