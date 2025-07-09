Set mm=%DATE:~4,2%
Set dd=%DATE:~7,2%
Set yyyy=%DATE:~10,4%

rem osql -U mbobackup -P mb0Back! -i c:\bat\qmback.sql
osql -S .\QM -U mbobackup -P keepdatasafE1! -i c:\bat\backupfromMM.sql
copy c:\bat\qmsqlback.bak \\10.7.0.239\qmserver\qmsqlback%mm%%dd%%yyyy%.bak
del c:\bat\qmsqlback.bak