$srcFolder = "\\10.5.3.33\c$\Program Files\Common Files\QM\Recordings\"
$dstFolder = "\\10.5.3.34\g$\Program Files\Recording_Storage\"

function Copy-Verify {
    Param (
       [string] $src,
       [string] $dst
    )
    if ((test-path $src) -and (test-path $dst)) {
        $folders = Get-ChildItem -Path $src -Name -Attributes Directory
        foreach ($fld in $folders) {
            #write-host "$($src)\$($fld)"
            if (-not (test-path "$($dst)\$($fld)")) { new-item -Type Directory -path "$($dst)\$($fld)" | out-null }
            Copy-Verify "$($src)\$($fld)" "$($dst)\$($fld)"
        }
        $files = Get-ChildItem -Path $src -Name -Attributes !Directory
        foreach ($file in $files) {
            if (test-path "$($dst)\$($file)") {
                $srcHash = (Get-FileHash "$($src)\$($file)").hash
                $dstHash = (Get-FileHash "$($dst)\$($file)").hash
                if ($srcHash -ne $dstHash) {
                    #write-host "hash mismatch on $($dst)\$($file)"
                    remove-item "$($dst)\$($file)" -Force -Confirm:$false
                    Copy-Item "$($src)\$($file)" "$($dst)\$($file)"
                    $dstHash = (Get-FileHash "$($dst)\$($file)").hash
                }
            } else {
                Copy-Item "$($src)\$($file)" "$($dst)\$($file)"
                $srcHash = (Get-FileHash "$($src)\$($file)").hash
                $dstHash = (Get-FileHash "$($dst)\$($file)").hash
            }
            if ($srcHash -ne $dstHash) {
                write-host "File '$($src)\$($fld)' failed to copy properly."
            }
        }
    }
}
Copy-Verify $srcFolder $dstFolder 
