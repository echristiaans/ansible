
	

This is due to a security feature known as LoopbackCheck.

Error message when you try to access a server locally by using its FQDN or its CNAME alias after you install Windows Server 2003 Service Pack 1: "Access denied" or "No network provider accepted the given network path"
http://support.microsoft.com/kb/926642

There are two resolutions:

Method 1 (recommended): Create the Local Security Authority host names that can be referenced in an NTLM authentication request. To do this, follow these steps for all the nodes on the client computer:

    Click Start, click Run, type regedit, and then click OK.
    Locate and then click the following registry subkey: HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0
    Right-click MSV1_0, point to New, and then click Multi-String Value.
    In the Name column, type BackConnectionHostNames, and then press ENTER.
    Right-click BackConnectionHostNames, and then click Modify.

    In the Value data box, type the CNAME or the DNS alias, that is used for the local shares on the computer, and then click OK.

    Note: Type each host name on a separate line.

    Note: If the BackConnectionHostNames registry entry exists as a REG_DWORD type, you have to delete the BackConnectionHostNames registry entry.

    Exit Registry Editor, and then restart the computer.

Method 2: Disable the authentication loopback check by setting the DisableLoopbackCheck registry entry in theHKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa registry subkey to 1. To set the DisableLoopbackCheck registry entry to 1, follow these steps on the client computer:

    Click Start, click Run, type regedit, and then click OK.
    Locate and then click the following registry subkey: HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa
    Right-click Lsa, point to New, and then click DWORD Value.
    Type DisableLoopbackCheck, and then press ENTER.
    Right-click DisableLoopbackCheck, and then click Modify.
    In the Value data box, type 1, and then click OK.
    Exit Registry Editor.
    Restart the computer.

