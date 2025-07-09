wmic product get name | sort

@echo off
echo y|wmic process where "name like '%%acumbrellaagent%%'" delete
echo y|wmic product where "name like '%%umbrella roaming%%'" call uninstall
echo y|wmic process where "name like '%%vpnui%%'" delete
echo y|wmic process call create "C:\Program Files (x86)\Cisco\Cisco AnyConnect Secure Mobility Client\vpnui.exe"
