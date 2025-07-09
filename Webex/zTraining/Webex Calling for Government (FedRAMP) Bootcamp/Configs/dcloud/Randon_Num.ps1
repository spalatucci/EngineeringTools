for($i=1;$i -le 40;$i++)
{$num=Get-Random -Minimum 4112223333 -Maximum 9999999999
 $num = "$num"+","
 if ($i -eq 40) {$num = $num.Substring(0, $num.Length-1)}
 Add-Content -Path C:\Users\cholland\Desktop\DID_numbers.txt "$num"
 }