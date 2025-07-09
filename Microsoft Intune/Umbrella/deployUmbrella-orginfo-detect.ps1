#compare copied file from intune package with existing file in data folder
$newfile = "orginfo.json"
$filetocheck = "C:\ProgramData\Cisco\Cisco AnyConnect Secure Mobility Client\Umbrella\data\orginfo.json"

$newtimestamp = (Get-Item -path $filetocheck).LastWriteTime
$existingtimestamp = (Get-Item -path $newfile).LastWriteTime


if($newtimestamp -eq $existingtimestamp) {
# Executes when the condition is true
Write-Host "Umbrella JSON are Correct"


}else {
# Executes when the condition is false
exit 1

}
