$cvRole = "VM Tower Users"
$cvRoleFileID="C:\Scripts\Entradas\vmTorreUser_Privileges_ids.txt"
$viServer = Read-Host -Prompt 'Entra el nombre del servidor'
Connect-VIServer -server $viServer

#### Creacion de arreglo vacio
$roleIds = @()

     Get-Content $cvRoleFileID | Foreach-Object{
        $roleIds += $_
     }

   New-VIRole -name $cvRole -Privilege (Get-VIPrivilege -Server $viServer -id $roleIds) -Server $viServer
   Set-VIRole -Role $cvRole -AddPrivilege (Get-VIPrivilege -Server $viServer -id $roleIds) -Server $viServer
   
   
