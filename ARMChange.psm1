function Write-WithTime {
    <#
    .SYNOPSIS 
    Formats messages includign the time stamp.
    
    .DESCRIPTION
    Formats messages includign the time stamp.
    
    .PARAMETER Message 
    Specify the the text Message.
    
    .PARAMETER Level 
    Specifiy severity level. Deafult is "Info". Optional parameter. 
    
    .PARAMETER Colour 
    Specifiy Colour  of message. Deafult is "NONE". Optional parameter. 
    
    .EXAMPLE     
    $VMName = "myVM"
    Write-WithTime "Virtual Machine '$VMName' is alreaday running."
 #> 
    
    [CmdletBinding()]
    param(            
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$Message,
                  
        [string]$Level = "INFO"        
    )
    
    BEGIN {}
        
    PROCESS {
        try {   
            $DateAndTime = Get-Date -Format g
    
            $FormatedMessage = "[$DateAndTime] [$Level] $Message"

            Write-Output $FormatedMessage
            
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    
    }
    
    END {}
}

function Write-WithTime_Using_WriteHost {
    <#
    .SYNOPSIS 
    Formats messages includign the time stamp.
    
    .DESCRIPTION
    Formats messages includign the time stamp.
    
    .PARAMETER Message 
    Specify the the text Message.
    
    .PARAMETER Level 
    Specifiy severity level. Deafult is "Info". Optional parameter. 
    
    .PARAMETER Colour 
    Specifiy Colour  of message. Deafult is "NONE". Optional parameter. 
    
    .EXAMPLE     
    $VMName = "myVM"
    Write-WithTime "Virtual Machine '$VMName' is alreaday running."
 #> 
    
    [CmdletBinding()]
    param(            
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$Message,
                  
        [string]$Level = "INFO",
        
        [switch] $PrependEmptyLine,         

        [switch] $AppendEmptyLine          

        #[switch] $AddNewEmptyLine         
    )
    
    BEGIN {}
        
    PROCESS {
        try {   
            $DateAndTime = Get-Date -Format g
    
            $FormatedMessage = "[$DateAndTime] [$Level] $Message"

            if($PrependEmptyLine){
                Write-Host 
            }

            Write-Host $FormatedMessage

            if($AppendEmptyLine){
                write-host
            }
            
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    
    }
    
    END {}
}
    

function Get-AzVMManagedDisksType {
    <#
    .SYNOPSIS 
    List the disk and disk types attached to the VM.
    
    .DESCRIPTION
    List the disk and disk types attached to the VM.
    
    .PARAMETER ResourceGroupName 
    Resource Group Name of the VM.
    
    .PARAMETER VMName 
    VM name. 
    
    
    .EXAMPLE 
    # List all disk with disk type of the VM  'PR1-DB' in Azure resource group 'SAP-PR1-RG' .
    $ResourceGroupName = "SAP-PR1-RG"
    $VirtualMachineName = "PR1-DB"
    Get-AzVMManagedDisksType -ResourceGroupName $ResourceGroupName -VMName $VirtualMachineName
 #> 
 
    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName
     
    )

    BEGIN {}
    
    PROCESS {
        try {   
            
            $obj = New-Object -TypeName psobject

            $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName

            $OSDisk = $VM.StorageProfile.OsDisk 
            $OSDiskName = $OSDisk.Name
            $OSDiskAllProperties = Get-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $OSDiskName
            $OSDiskType = $OSDiskAllProperties.Sku.Name

            $obj | add-member  -NotePropertyName "DiskName" -NotePropertyValue $OSDiskName 
            $obj | add-member  -NotePropertyName "DiskType" -NotePropertyValue $OSDiskType
            $obj | add-member  -NotePropertyName "DiskRole" -NotePropertyValue "OSDisk"
            Write-Output $obj

            $DataDisks = $VM.StorageProfile.DataDisks
            $DataDisksNames = $DataDisks.Name

            foreach ($DataDiskName in $DataDisksNames) {
                $obj = New-Object -TypeName psobject
                $DataDiskAllProperties = Get-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $DataDiskName
                $obj | add-member  -NotePropertyName "DiskName" -NotePropertyValue $DataDiskName 
                $obj | add-member  -NotePropertyName "DiskType" -NotePropertyValue $DataDiskAllProperties.Sku.Name
                $obj | add-member  -NotePropertyName "DiskRole" -NotePropertyValue "DataDisk"
                Write-Output $obj
            }

        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}

function Start-AzVMTagAndCheckVMStatus {
    <#
    .SYNOPSIS 
    Starts the VM(s) with a certain tag.
    
    .DESCRIPTION
    Starts the VM(s) with a certain SAP Instance type tag.
    The expected types are:
    - SAP_ASCS
    - SAP_SCS
    - SAP_DVEBMGS
    - DBMS
    - SAP_D
    - SAP_J
    
    .PARAMETER SAPVMs 
    List of VM resources. This collection is a list of VMs with same 'SAPSID' tag.
    
    .PARAMETER SAPInstanceType 
    One of the SAP Instance types:
    - SAP_ASCS
    - SAP_SCS
    - SAP_DVEBMGS
    - DBMS
    - SAP_D
    - SAP_J
    
    .EXAMPLE 
    # Get all the VMS with SAPSID tag 'PR1', and start ALL SAP ABAP application servers 'SAP_D'
    $SAPSID = "PR1"
    $tags = @{"SAPSystemSID"=$SAPSID}
    $SAPVMs = Get-AzResource -ResourceType "Microsoft.Compute/virtualMachines"  -Tag $tags
    Start-AzVMTagAndCheckVMStatus -SAPVMs $SAPVMs -SAPInstanceType "SAP_D"

 #>
    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        $SAPVMs,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $SAPInstanceType        
    )

    BEGIN {}
    
    PROCESS {
        try {                                       
            $SAPInstanceSpecificVMResources = $SAPVMs | Where-Object { $_.SAPInstanceType -EQ $SAPInstanceType }                    
            #Write-Host " "            

            if ($SAPInstanceSpecificVMResources -eq $null) {
                Switch ($SAPInstanceType) {
                    "SAP_ASCS" { Write-WithTime "No SAP Central Service Instance 'ASCS' VMs found in VMs Tags." }
                    "SAP_SCS" { Write-WithTime "No SAP Central Service Instance 'SCS' Instance VMs found in VMs Tags." }
                    "SAP_DVEBMGS" { Write-WithTime "No SAP ABAP Central Instance 'DVEBMGS' VM found in VMs Tags." }
                    "SAP_DBMS" { Write-WithTime "No SAP DBMS Instance VMs found in VMs Tags." }
                    "SAP_D" { Write-WithTime "No SAP SAP ABAP Application Server 'D' Instance VM found in VMs Tags." }
                    "SAP_J" { Write-WithTime "No SAP Java Application Server Instance 'J' found in VMs Tags." }   
                    Default {
                        Write-WithTime "Specified SAP Instance Type '$SAPInstanceType' is not existing."
                        Write-WithTime "Use one of these SAP instance types: 'SAP_ASCS', 'SAP_SCS', 'SAP_DVEBMGS', 'SAP_D', 'SAP_J', 'DBMS'."
                    }           
                }
            }
            else {
                Switch ($SAPInstanceType) {
                    "SAP_ASCS" { Write-WithTime   "Starting SAP Central Service Instance 'ASCS' VMs ..." }
                    "SAP_SCS" { Write-WithTime   "Starting Central Service Instance 'SCS' Instance VMs ..." }
                    "SAP_DVEBMGS" { Write-WithTime   "Starting SAP ABAP Central Instance 'DVEBMGS' VM ..." }
                    "SAP_DBMS" { Write-WithTime   "Starting SAP DBMS Instance VMs ..." }
                    "SAP_D" { Write-WithTime   "Starting SAP ABAP Application Server Instance 'D' VM ..." }
                    "SAP_J" { Write-WithTime   "Starting SAP Java Application Server Instance 'J' VMs ..." }   
                    Default {
                        Write-WithTime "Specified SAP Instance Type '$SAPInstanceType' is not existing."
                        Write-WithTime "Use one of these SAP instance types: 'SAP_ASCS', 'SAP_SCS', 'SAP_DVEBMGS', 'SAP_D', 'SAP_J', 'DBMS'."
                    }             
                }
            }


            ForEach ($VMResource in $SAPInstanceSpecificVMResources) {                
                $VMName = $VMResource.VMName
                $ResourceGroupName = $VMResource.ResourceGroupName

                $VMIsRunning = Test-AzVMIsStarted -ResourceGroupName  $ResourceGroupName -VMName $VMName

                if ($VMIsRunning -eq $False) {
                    # Start VM
                    Write-WithTime "Starting VM '$VMName' in Azure Resource Group '$ResourceGroupName' ..."
                    Start-AzVM  -ResourceGroupName $ResourceGroupName -Name $VMName -WarningAction "SilentlyContinue"

                    $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status
                    $VMStatus = $VM.Statuses[1].DisplayStatus
                    
                    Write-WithTime "Virtual Machine '$VMName' status: $VMStatus"
                    
                    Start-Sleep 60   
                }
                else {
                    Write-WithTime "Virtual Machine '$VMName' is alreaday running."
                }

            }

            Write-Output " "
            
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}


function Stop-AzVMTagAndCheckVMStatus {
    <#
    .SYNOPSIS 
    Stops the VM(s) with a certain tag.
    
    .DESCRIPTION
    Stops the VM(s) with a certain SAP Instance type tag.
    The expected types are:
    - SAP_ASCS
    - SAP_SCS
    - SAP_DVEBMGS
    - DBMS
    - SAP_D
    - SAP_J
    
    .PARAMETER SAPVMs 
    List of VM resources. This collection is a list of VMs with same 'SAPSID' tag.
    
    .PARAMETER SAPInstanceType 
    One of the SAP Instance types:
    - SAP_ASCS
    - SAP_SCS
    - SAP_DVEBMGS
    - DBMS
    - SAP_D
    - SAP_J
    
    .EXAMPLE 
    # Get all the VMS with SAPSID tag 'PR1', and start ALL SAP ABAP application servers 'SAP_D'
    $SAPSID = "PR1"
    $tags = @{"SAPSystemSID"=$SAPSID}
    $SAPVMs = Get-AzResource -ResourceType "Microsoft.Compute/virtualMachines"  -Tag $tags
    Stop-AzVMTagAndCheckVMStatus -SAPVMs $SAPVMs -SAPInstanceType "SAP_D"

 #>
    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        $SAPVMs,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $SAPInstanceType        
    )

    BEGIN {}
    
    PROCESS {
        try {   

            $SAPInstanceSpecificVMResources = $SAPVMs | Where-Object { $_.SAPInstanceType -EQ $SAPInstanceType }                    
                        
            if ($SAPInstanceSpecificVMResources -eq $null) {
                Switch ($SAPInstanceType) {
                    "SAP_ASCS" { Write-WithTime "No SAP Central Service Instance 'ASCS' VMs found in VMs Tags." }
                    "SAP_SCS" { Write-WithTime "No SAP Central Service Instance 'SCS' Instance VMs found in VMs Tags." }
                    "SAP_DVEBMGS" { Write-WithTime "No SAP ABAP Central Instance 'DVEBMGS' VM found in VMs Tags ..." }
                    "SAP_DBMS" { Write-WithTime "No SAP DBMS Instance VMs found in VMs Tags ..." }
                    "SAP_D" { Write-WithTime "No SAP SAP ABAP Application Server 'D' Instance VM found in VMs Tags." }
                    "SAP_J" { Write-WithTime "No SAP Java Application Server Instance 'J' found in VMs Tags." }   
                    Default {
                        Write-WithTime "Specified SAP Instance Type '$SAPInstanceType' is not existing."
                        Write-WithTime "Use one of these SAP instance types: 'SAP_ASCS', 'SAP_SCS', 'SAP_DVEBMGS', 'SAP_D', 'SAP_J', 'DBMS'."
                    }             
                }
            }
            else {
                Switch ($SAPInstanceType) {
                    "SAP_ASCS" { Write-WithTime   "Stopping SAP Central Service Instance 'ASCS' VMs ..." }
                    "SAP_SCS" { Write-WithTime   "Stopping SAP Central Service Instance 'SCS' VMs ..." }
                    "SAP_DVEBMGS" { Write-WithTime   "Stopping SAP ABAP Central Instance 'DVEBMG' VM ..." }
                    "SAP_DBMS" { Write-WithTime   "Stopping SAP DBMS Instance VMs ..." }
                    "SAP_D" { Write-WithTime   "Stopping SAP ABAP Application Server 'D' Instance VMs ..." }
                    "SAP_J" { Write-WithTime   "Stopping SAP Java Application Server Instance 'J' VMs ..." }   
                    Default {
                        Write-WithTime "Specified SAP Instance Type '$SAPInstanceType' is not existing."
                        Write-WithTime "Use one of these SAP instance types: 'SAP_ASCS', 'SAP_SCS', 'SAP_DVEBMGS', 'SAP_D', 'SAP_J', 'DBMS'."
                    }               
                }
            }
                      
            ForEach ($VMResource in $SAPInstanceSpecificVMResources) {                
                $VMName = $VMResource.VMName
                $ResourceGroupName = $VMResource.ResourceGroupName

                #$VMIsRunning = Test-AzVMIsStarted -ResourceGroupName  $ResourceGroupName -VMName $VMName

                #if ($VMIsRunning -eq $False) {
                # Stop VM
                Write-WithTime "Stopping VM '$VMName' in Azure Resource Group '$ResourceGroupName' ..."
                Stop-AzVM  -ResourceGroupName $ResourceGroupName -Name $VMName -WarningAction "SilentlyContinue" -Force

                $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status
                $VMStatus = $VM.Statuses[1].DisplayStatus
                #Write-Host ""
                Write-WithTime "Virtual Machine '$VMName' status: $VMStatus"   
                #}
                #else {
                #Write-WithTime "Virtual Machine '$VMName' is alreaday running."
                #}

            }

            #Write-Host " "
            
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}

function Get-AzSAPInstances {
    <#
    .SYNOPSIS 
    Get ALL VMs with same SAPSID tag.
    
    .DESCRIPTION
    Get ALL VMs with same SAPSID tag.
    For each VM it will display:
    - SAPSID
    - Azure Resource Group Name
    - VM Name
    - SAP Instance Type
    - OS type
    
    .PARAMETER SAPSID 
    SAP system SID.    
    
    .EXAMPLE 
    # specify SAP SID 'PR1'
    $SAPSID = "PR1"
    
    # Collect SAP VM instances with the same Tag
    $SAPInstances = Get-AzSAPInstances -SAPSID $SAPSID

    # List all collected instances
    $SAPInstances

 #>

    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        $SAPSID         
    )

    BEGIN {}
    
    PROCESS {
        try {   
                      
            $tags = @{"SAPSystemSID" = $SAPSID }
            $SAPVMs = Get-AzResource -ResourceType "Microsoft.Compute/virtualMachines"  -Tag $tags

            foreach ($VMResource in $SAPVMs) {
                $obj = New-Object -TypeName psobject

                $OSType = Get-AzVMOSType -VMName $VMResource.Name -ResourceGroupName $VMResource.ResourceGroupName  
               
                $obj | add-member  -NotePropertyName "SAPSID" -NotePropertyValue $SAPSID  
                $obj | add-member  -NotePropertyName "ResourceGroupName" -NotePropertyValue $VMResource.ResourceGroupName  
                $obj | add-member  -NotePropertyName "VMName" -NotePropertyValue $VMResource.Name                  
                $obj | add-member  -NotePropertyName "SAPInstanceType"   -NotePropertyValue $VMResource.Tags.Item("SAPInstanceType")
                $obj | add-member  -NotePropertyName "OSType"   -NotePropertyValue $OSType 

                #Return formated object
                Write-Output $obj                                                
            }                       
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}
function Get-AzSAPApplicationInstances {
    <#
    .SYNOPSIS 
    Get ALL VMs with same SAPSID tag, that runs applictaion layer.
    
    .DESCRIPTION
   Get ALL VMs with same SAPSID tag, that runs applictaion layer.
    For each VM it will display:
    - SAPSID
    - Azure Resource Group Name
    - VM Name
    - SAP Instance Type
    - OS type
    
    .PARAMETER SAPSID 
    SAP system SID.    
    
    .EXAMPLE 
    # specify SAP SID 'PR1'
    $SAPSID = "PR1"
    
    # Collect SAP VM instances with the same Tag
    $SAPInstances = Get-AzSAPApplicationInstances -SAPSID $SAPSID

    # List all collected instances
    $SAPInstances

 #>

    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        $SAPSID         
    )

    BEGIN {}
    
    PROCESS {
        try {   
                      
            $tags = @{"SAPSystemSID" = $SAPSID }
            $SAPVMs = Get-AzResource -ResourceType "Microsoft.Compute/virtualMachines"  -Tag $tags

            $SAPApplicationInstances = $SAPVMs | Where-Object { ($_.Tags.Item("SAPApplicationInstanceType") -EQ 'SAP_D') -or ($_.Tags.Item("SAPApplicationInstanceType") -EQ 'SAP_ASCS') -or ($_.Tags.Item("SAPApplicationInstanceType") -EQ 'SAP_SCS') -or ($_.Tags.Item("SAPApplicationInstanceType") -EQ 'SAP_DVEBMGS') }          


            foreach ($VMResource in $SAPApplicationInstances) {
                $obj = New-Object -TypeName psobject
                                
                $OSType = Get-AzVMOSType -VMName $VMResource.Name -ResourceGroupName $VMResource.ResourceGroupName  
               
                $obj | add-member  -NotePropertyName "SAPSID" -NotePropertyValue $SAPSID  
                $obj | add-member  -NotePropertyName "ResourceGroupName" -NotePropertyValue $VMResource.ResourceGroupName  
                $obj | add-member  -NotePropertyName "VMName" -NotePropertyValue $VMResource.Name                                  
                $obj | add-member  -NotePropertyName "OSType"   -NotePropertyValue $OSType 
                $obj | add-member  -NotePropertyName "SAPInstanceType"   -NotePropertyValue $VMResource.Tags.Item("SAPApplicationInstanceType") 

                #Return formated object
                Write-Output $obj
                                                
            }           
            
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}

function Test-AzVMIsStarted {
    <#
    .SYNOPSIS 
    Checks if VM is started.
    
    .DESCRIPTION
    Checks if VM is started.
    If VM reachs status 'VM running', it will return $True, otherwise it will return $False
    
    .PARAMETER ResourceGroupName 
    VM Azure Resource Group Name.    
    
    .PARAMETER VMName 
    VM Name.    
    
    .EXAMPLE 
    Test-AzVMIsStarted -ResourceGroupName "PR1-RG" -VMName "PR1-DB"
 #>

    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName

        
    )

    BEGIN {}
    
    PROCESS {
        try {   
            
            $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status

            $VMStatus = $VMStatus = $VM.Statuses[1].DisplayStatus
                        
            if ($VMStatus -eq "VM running") {                    
                return $True                
            }
            else {
                return $False

            }
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }
    END {}
}

function Get-AzVMOSType {
    <#
    .SYNOPSIS 
   Get-AzVMOSType gets the VM OS type.
    
    .DESCRIPTION
    Get-AzVMOSType gets the VM OS type, as a return value.
    
    .PARAMETER ResourceGroupName 
    VM Azure Resource Group Name.    
    
    .PARAMETER VMName 
    VM Name.    
    
    .EXAMPLE 
    $OSType = Get-AzVMOSType -ResourceGroupName "PR1-RG" -VMName "PR1-DB"
 #>

    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName
        
    )

    BEGIN {}
    
    PROCESS {
        try {   
            $VM = Get-AzVM -ResourceGroupName  $ResourceGroupName -Name $VMName

            Write-Output $VM.StorageProfile.OsDisk.OsType
                        
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}


# NOT needed anymore
function Get-AzSAPHANAParametersFromTags {
    <#
    .SYNOPSIS 
    Get SAP HANA parameters from DBMS VM tags.
    
    .DESCRIPTION
    Get SAP HANA parameters from DBMS VM tags. It returns an object with:[SAPHANADBSID;SAPHANAInstanceNumber,SAPHANAResourceGroupName,SAPHANAVMName]      
    .PARAMETER SAPVMs 
    List of SAP VMs. Get all VMs bound by SAPSID with Get-AzSAPInstances          
    
    .EXAMPLE 
    $SAPSID = "PR1"
    Get-AzSAPHANAParametersFromTags -SAPSID $SAPSID
 #>

    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        $SAPSID        
    )

    BEGIN {}
    
    PROCESS {
        try {               
            $tags = @{"SAPSystemSID" = $SAPSID }
            $VMResources = Get-AzResource -ResourceType "Microsoft.Compute/virtualMachines"  -Tag $tags
            $HANAVMResource = $VMResources | Where-Object { $_.Tags.Item("SAPInstanceType") -EQ "SAP_DBMS" }

            $SAPHANADBSID = $HANAVMResource.Tags.Item("SAPHANADBSID")
            $SAPHANAInstanceNumber = $HANAVMResource.Tags.Item("SAPHANAInstanceNumber")
            $SAPHANAResourceGroupName = $HANAVMResource.ResourceGroupName
            $SAPHANAVMName = $HANAVMResource.Name

            $obj = New-Object -TypeName psobject
            $obj | add-member  -NotePropertyName "SAPHANADBSID" -NotePropertyValue $SAPHANADBSID
            $obj | add-member  -NotePropertyName "SAPHANAInstanceNumber" -NotePropertyValue $SAPHANAInstanceNumber
            $obj | add-member  -NotePropertyName "SAPHANAResourceGroupName" -NotePropertyValue $SAPHANAResourceGroupName
            $obj | add-member  -NotePropertyName "SAPHANAVMName" -NotePropertyValue $SAPHANAVMName
            Write-Output $obj
                        
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}

function Get-AzHANADBStatus {
    <#
    .SYNOPSIS 
    Get SAP HANA DB status.
    
    .DESCRIPTION
    Get SAP HANA DB status.

    .PARAMETER VMName 
    VM name where HANA is installed. 

    .PARAMETER ResourceGroupName 
    Resource Group Name of the HANA VM.
    
    .PARAMETER HANADBSID 
    SAP HANA SID 
    
    .PARAMETER HANAInstanceNumber 
    SAP HANA Instance Number  

    .PARAMETER PrintExecutionCommand 
    If set to $True, it will print execution command.
    
    .EXAMPLE     
    Get-AzHANADBStatus  -ResourceGroupName "PR1-RG"  -VMName "PR1-DB" -HANADBSID "PR1"  -HANAInstanceNumber 0
 #>
    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $True, HelpMessage = "HANA DB SID")] 
        [string] $HANADBSID,

        [Parameter(Mandatory = $True, HelpMessage = "HANA Instance Number")] 
        [string] $HANAInstanceNumber,

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False        

    )

    BEGIN {}
    
    PROCESS {
        try {   
            Write-WithTime "HANA DBMS '$HANADBSID' status:"

            $SAPSidUser = $HANADBSID.ToLower() + "adm"
            $SAPSIDUpper = $HANADBSID.ToUpper()
            $SAPControlPath = "/usr/sap/$SAPSIDUpper/SYS/exe/hdb/sapcontrol"            
            
            $Command = "su --login $SAPSidUser -c '$SAPControlPath -prot NI_HTTP -nr $HANAInstanceNumber -function GetSystemInstanceList'"

            if ($PrintExecutionCommand -eq $True) {
                Write-WithTime "Executing command '$Command' "
            }
                        
            $Command | Out-File "command.txt"

            $ret = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName  -CommandId RunShellScript  -ScriptPath command.txt
            $ret.Value[0].Message

            Start-Sleep 5            
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}


function Get-AzSQLServerDBStatus {
    <#
    .SYNOPSIS 
    Get SQL Server DB status.
    
    .DESCRIPTION
    Get SQL Server DB status.

    .PARAMETER VMName 
    VM name where SQL Server is installed. 

    .PARAMETER ResourceGroupName 
    Resource Group Name of the SQL Server VM.
    
    .PARAMETER DBSIDName 
    SAP Database SID Name
    
    .PARAMETER DBInstanceName 
    SQL Server DB Instance Name

    .PARAMETER PrintExecutionCommand 
    If set to $True, it will print execution command.
    
    .EXAMPLE  
    #Get status of default SQL Server Instance   
    Get-AzSQLServerDBStatus  -VMName pr1-db -ResourceGroupName gor-shared-disk-east-us -DBSIDName PR1 -PrintExecutionCommand $true

    .EXAMPLE  
    #Get status of default SQL Server Instance   
    Get-AzSQLServerDBStatus  -VMName pr1-db -ResourceGroupName gor-shared-disk-east-us -DBSIDName PR1 -DBInstanceName PR1 -PrintExecutionCommand $true
 #>
    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $True, HelpMessage = "SQL Server DB SID")] 
        [string] $DBSIDName,

        [Parameter(Mandatory = $False, HelpMessage = "SQL Server DB Instance Name")] 
        [string] $DBInstanceName = "",

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False        

    )

    BEGIN {}
    
    PROCESS {
        try {   
            Write-WithTime "SQL Server DBMS '$DBSIDName' status:"
            
            $Command   = "cd  'C:\Program Files\SAP\hostctrl\exe\' ; .\saphostctrl.exe -function GetDatabaseStatus -dbname $DBSIDName -dbtype mss -dbinstance $DBInstanceName"                        

            if ($PrintExecutionCommand -eq $True) {
                Write-WithTime "Executing command '$Command' "
            }
                        
            $Command | Out-File "command.txt"

            $ret = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName  -CommandId RunPowerShellScript -ScriptPath command.txt
            $ret.Value[0].Message

            Start-Sleep 10            
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}


function Get-AzDBMSStatus {
    <#
    .SYNOPSIS 
    Get DB status.
    
    .DESCRIPTION
    Get DB status.

    .PARAMETER SAPSID 
    SAP SID. 

    .PARAMETER SAPSIDDBMSVMs 
    Collection of DB VMs
        
    .PARAMETER PrintExecutionCommand 
    If set to $True, it will print execution command.
    
    .EXAMPLE     
    $SAPSIDDBMSVMs  = Get-AzSAPDBMSInstances -SAPSID "PR2"
    Get-AzDBMSStatus -SAPSIDDBMSVMs $SAPSIDDBMSVMs
 #>
    [CmdletBinding()]
    param(                    

        [Parameter(Mandatory = $True)]         
        $SAPSIDDBMSVMs,

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False 
    )

    BEGIN {}
    
    PROCESS {
        try {   
            Switch ($SAPSIDDBMSVMs.SAPDBMSType) {

                "HANA" {                    
                    # Get SAP HANA status                    
                    Get-AzHANADBStatus  -ResourceGroupName $SAPSIDDBMSVMs.ResourceGroupName -VMName $SAPSIDDBMSVMs.VMName -HANADBSID $SAPSIDDBMSVMs.SAPHANASID  -HANAInstanceNumber $SAPSIDDBMSVMs.SAPHANAInstanceNumber -PrintExecutionCommand $PrintExecutionCommand                                                    
                }

                "SQLServer" {
                    # Get SQL Server status
                    Get-AzSQLServerDBStatus -ResourceGroupName $SAPSIDDBMSVMs.ResourceGroupName -VMName $SAPSIDDBMSVMs.VMName  -DBSIDName $SAPSIDDBMSVMs.SAPSID -DBInstanceName $SAPSIDDBMSVMs.DBInstanceName -PrintExecutionCommand $PrintExecutionCommand
                }

                "Sybase" {
                    # Not yet Implemented
                    Write-WithTime "Getting Sybase DBMS status is not yet implenented."
                }

                "MaxDB" {
                    # Not yet Implemented
                    Write-WithTime "Getting MaxDB DBMS status is not yet implenented."
                }

                "Oracle" {
                    # Not yet Implemented
                    Write-WithTime "Getting Oracle DBMS status is not yet implenented."
                }

                "IBMDB2" {
                    # Not yet Implemented
                    Write-WithTime "Getting IBMDB2 DBMS status is not yet implenented."
                }

                default {
                    Write-WithTime "Couldn't find any supported DBMS type. Please check on DB VM '$($SAPSIDDBMSVMs.VMName)', Tag 'SAPDBMSType'. It must have value like: 'HANA', 'SQLServer', 'Sybase', 'MaxDB' , 'Oracle', 'IBMDB2'. Current 'SAPDBMSType' Tag value is '$($SAPSIDDBMSVMs.SAPDBMSType)'"
                }
            }    
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}

function Stop-AzHANADB {
    <#
    .SYNOPSIS 
    Stop SAP HANA DB.
    
    .DESCRIPTION
    Stop SAP HANA DB.

    .PARAMETER VMName 
    VM name where HANA is installed. 

    .PARAMETER ResourceGroupName 
    Resource Group Name of the HANA VM.
    
    .PARAMETER HANADBSID 
    SAP HANA SID     

    .PARAMETER PrintExecutionCommand 
    If set to $True, it will print execution command.
    
    .EXAMPLE     
    Stop-AzHANADB  -ResourceGroupName "PR1-RG"  -VMName "PR1-DB" -HANADBSID "PR1" -SAPHANAInstanceNumber 0
 #>

    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $True, HelpMessage = "HANA DB SID")] 
        [string] $HANADBSID,

        [Parameter(Mandatory=$True, HelpMessage="HANA Instance Number")] 
        [string] $SAPHANAInstanceNumber,

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False

    )

    BEGIN {}
    
    PROCESS {
        try {   
            Write-WithTime "Stopping SAP HANA DBMS '$HANADBSID' ... "

            $SAPSidUser = $HANADBSID.ToLower() + "adm"            
            $SAPSIDUpper = $HANADBSID.ToUpper()
            $SAPControlPath = "/usr/sap/$SAPSIDUpper/SYS/exe/hdb/sapcontrol"  
            
            # HDB wrapper aproach
            #$Command = "su --login $SAPSidUser -c 'HDB stop'"            

            # Execute stop 
            $Command = "su --login $SAPSidUser -c '$SAPControlPath -prot NI_HTTP -nr $SAPHANAInstanceNumber -function Stop 400'"

            if ($PrintExecutionCommand -eq $True) {
                Write-WithTime "Executing command '$Command' "
            }
            
            $Command | Out-File "command.txt"

            $ret = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName  -CommandId RunShellScript  -ScriptPath command.txt
            $ret.Value[0].Message

            Start-Sleep 20
            
            # Wait for 600 sec -deafult value
            $Command = "su --login $SAPSidUser -c '$SAPControlPath -prot NI_HTTP -nr $SAPHANAInstanceNumber -function WaitforStopped 600 2'"            
            
            if ($PrintExecutionCommand -eq $True) {
                Write-WithTime "Executing command '$Command' "
            }
            
            $Command | Out-File "command.txt"

            $ret = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName  -CommandId RunShellScript  -ScriptPath command.txt
            $ret.Value[0].Message

            Start-Sleep 60  

            Write-WithTime "SAP HANA DB '$HANADBSID' is stopped."          
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}

function Start-AzHANADB {
    <#
    .SYNOPSIS 
    Start SAP HANA DB.
    
    .DESCRIPTION
    Start SAP HANA DB.

    .PARAMETER VMName 
    VM name where HANA is installed. 

    .PARAMETER ResourceGroupName 
    Resource Group Name of the HANA VM.
    
    .PARAMETER SAPHANAInstanceNumber 
    SAP HANA SID     

    .PARAMETER PrintExecutionCommand 
    If set to $True, it will print execution command.
    
    .EXAMPLE     
    Start-AzHANADB  -ResourceGroupName "PR1-RG"  -VMName "PR1-DB" -HANADBSID "PR1" -SAPHANAInstanceNumber 0
 #>

    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $True, HelpMessage = "HANA DB SID")] 
        [string] $HANADBSID,

        [Parameter(Mandatory=$True, HelpMessage="HANA Instance Number")] 
        [ValidateLength(1, 2)]
        [string] $SAPHANAInstanceNumber,

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False        

    )

    BEGIN {}
    
    PROCESS {
        try {   
            Write-WithTime "Starting SAP HANA DBMS '$HANADBSID' ... "

            $SAPSidUser = $HANADBSID.ToLower() + "adm"
            
            $SAPSIDUpper = $HANADBSID.ToUpper()
            $SAPControlPath = "/usr/sap/$SAPSIDUpper/SYS/exe/hdb/sapcontrol"            
            
            $Command = "su --login $SAPSidUser -c '$SAPControlPath -prot NI_HTTP -nr $SAPHANAInstanceNumber -function StartWait 2700 2'"

            #$Command = "su --login $SAPSidUser -c 'HDB start'"            
            
            if ($PrintExecutionCommand -eq $True) {
                Write-WithTime "Executing command '$Command' "
            }
            
            $Command | Out-File "command.txt"

            $ret = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName  -CommandId RunShellScript  -ScriptPath command.txt
            $ret.Value[0].Message

            Start-Sleep 20            
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}

function Start-AzSQLServerDB {
    <#
    .SYNOPSIS 
    Start SQL Server DB status.
    
    .DESCRIPTION
    Get SQL Server DB status.

    .PARAMETER VMName 
    VM name where SQL Server is installed. 

    .PARAMETER ResourceGroupName 
    Resource Group Name of the SQL Server VM.
    
    .PARAMETER DBSIDName 
    SAP Database SID Name    
    
    .PARAMETER DBInstanceName 
    SQL Server DB Instance Name

    .PARAMETER PrintExecutionCommand 
    If set to $True, it will print execution command.
    
    .EXAMPLE     
    # Start default SQL Server Instance
    Start-AzSQLServerDB -VMName pr1-db -ResourceGroupName gor-shared-disk-east-us -DBSIDName PR1 -DBInstanceName -PrintExecutionCommand $true

    .EXAMPLE   
    # Start named SQL Server Instance  
    Start-AzSQLServerDB -VMName pr1-db -ResourceGroupName gor-shared-disk-east-us -DBSIDName PR1 -DBInstanceName PR1 -PrintExecutionCommand $true
 #>
    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $True, HelpMessage = "SQL Server DB SID")] 
        [string] $DBSIDName,

        [Parameter(Mandatory = $False, HelpMessage = "SQL Server DB Instance Name")] 
        [string] $DBInstanceName = "",

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False        

    )

    BEGIN {}
    
    PROCESS {
        try {   
            Write-WithTime "Starting SQL Server DBMS '$DBSIDName' ..."
            
            $Command   = "cd  'C:\Program Files\SAP\hostctrl\exe\' ; .\saphostctrl.exe -function StartDatabase -dbname $DBSIDName -dbtype mss -dbinstance $DBInstanceName"                        

            if ($PrintExecutionCommand -eq $True) {
                Write-WithTime "Executing command '$Command' "
            }
                        
            $Command | Out-File "command.txt"

            $ret = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName  -CommandId RunPowerShellScript -ScriptPath command.txt
            $ret.Value[0].Message

            Start-Sleep 10            
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}


function Stop-AzSQLServerDB {
    <#
    .SYNOPSIS 
    Stop SQL Server DB status.
    
    .DESCRIPTION
    Stop SQL Server DB status.

    .PARAMETER VMName 
    VM name where SQL Server is installed. 

    .PARAMETER ResourceGroupName 
    Resource Group Name of the SQL Server VM.
    
    .PARAMETER DBSIDName 
    SAP Database SID Name     

    .PARAMETER DBInstanceName 
    SQL Server DB Instance Name

    .PARAMETER PrintExecutionCommand 
    If set to $True, it will print execution command.
    
    .EXAMPLE     
    # Stop default SQL Server Instance
    Stop-AzSQLServerDB -VMName pr1-db -ResourceGroupName gor-shared-disk-east-us -DBSIDName PR1 -DBInstanceName

    .EXAMPLE     
    # Stop default SQL Server Instance
    Stop-AzSQLServerDB -VMName pr1-db -ResourceGroupName gor-shared-disk-east-us -DBSIDName PR1 -DBInstanceName PR1
 #>
    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $True, HelpMessage = "SQL Server DB SID")] 
        [string] $DBSIDName,

        [Parameter(Mandatory = $False, HelpMessage = "SQL Server DB Instance Name")] 
        [string] $DBInstanceName = "",

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False        

    )

    BEGIN {}
    
    PROCESS {
        try {   
            Write-WithTime "Stopping SQL Server DBMS '$DBSIDName'  ... :"
            
            $Command   = "cd  'C:\Program Files\SAP\hostctrl\exe\' ; .\saphostctrl.exe -function StopDatabase -dbname $DBSIDName -dbtype mss -dbinstance $DBInstanceName"                        

            if ($PrintExecutionCommand -eq $True) {
                Write-WithTime "Executing command '$Command' "
            }
                        
            $Command | Out-File "command.txt"

            $ret = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName  -CommandId RunPowerShellScript -ScriptPath command.txt
            $ret.Value[0].Message

            Start-Sleep 10            
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}





function Start-AzDBMS {
    <#
    .SYNOPSIS 
    Start DBMS.
    
    .DESCRIPTION
    Start DBMS.

    .PARAMETER SAPSID 
    SAP SID. 

    .PARAMETER DatabaseType 
    Database Type. Allowed values are: "HANA","SQLServer","MaxDB","Sybase","Oracle","IBMDB2" 

    .PARAMETER PrintExecutionCommand 
    If set to $True, it will print execution command.
    
    .EXAMPLE     
    Start-AzDBMS -SAPSID "PR1" -DatabaseType "HANA"
 #>
    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $True)]         
        $SAPSIDDBMSVMs,

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False 
    )

    BEGIN {}
    
    PROCESS {
        try {   
            Switch ($SAPSIDDBMSVMs.SAPDBMSType) {

                "HANA" {
                    # Start SAP HANA DB                    
                    Start-AzHANADB -ResourceGroupName $SAPSIDDBMSVMs.ResourceGroupName -VMName $SAPSIDDBMSVMs.VMName  -HANADBSID $SAPSIDDBMSVMs.SAPHANASID  -SAPHANAInstanceNumber $SAPSIDDBMSVMs.SAPHANAInstanceNumber -PrintExecutionCommand $PrintExecutionCommand
                }

                "SQLServer" {                    
                    # Start SQL Server DB                    
                    Start-AzSQLServerDB  -ResourceGroupName $SAPSIDDBMSVMs.ResourceGroupName -VMName $SAPSIDDBMSVMs.VMName  -DBSIDName $SAPSIDDBMSVMs.SAPSID -DBInstanceName $SAPSIDDBMSVMs.DBInstanceName  -PrintExecutionCommand $PrintExecutionCommand
                }

                "Sybase" {
                    # Not yet Implemented
                    Write-WithTime "Start of SAP Sybase is not yet implemented. Relying on automatic SAP Sybase start."
                    write-output ""
                    Write-WithTime "Waiting for 3 min for DBMS auto start."
                    Start-Sleep 180
                }

                "MaxDB" {
                    # Not yet Implemented
                    Write-WithTime "Start of SAP MaxDB is not yet implemented. Relying on automatic SAP MaxDB start."
                    write-output ""
                    Write-WithTime "Waiting for 3 min for DBMS auto start."
                    Start-Sleep 180
                }

                "Oracle" {
                    # Not yet Implemented
                    Write-WithTime "Start of Oracle is not yet implemented. Relying on automatic Oracle start."
                    write-output ""
                    Write-WithTime "Waiting for 3 min for DBMS auto start."
                    Start-Sleep 180
                }

                "IBMDB2" {
                    # Not yet Implemented
                    Write-WithTime "Start of IBM DB2 is not yet implemented. Relying on automatic IBM DB2 start."
                    write-output ""
                    Write-WithTime "Waiting for 3 min for DBMS autostart."
                    Start-Sleep 180
                }
            }    
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}

function Stop-AzDBMS {
    <#
    .SYNOPSIS 
    Start DBMS.
    
    .DESCRIPTION
    Start DBMS.

    .PARAMETER SAPSID 
    SAP SID. 

    .PARAMETER DatabaseType 
    Database Type. Allowed values are: "HANA","SQLServer","MaxDB","Sybase","Oracle","IBMDB2" 

    .PARAMETER PrintExecutionCommand 
    If set to $True, it will print execution command.
    
    .EXAMPLE     
    Stop-AzDBMS -SAPSID "PR1" -DatabaseType "HANA"
 #>
    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $True)]         
        $SAPSIDDBMSVMs,

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False 

    )

    BEGIN {}
    
    PROCESS {
        try {   
            Switch ($SAPSIDDBMSVMs.SAPDBMSType) {

                "HANA" {                                        
                    # Stop SAP HANA DBMS                        
                    Stop-AzHANADB -ResourceGroupName $SAPSIDDBMSVMs.ResourceGroupName -VMName $SAPSIDDBMSVMs.VMName -HANADBSID $SAPSIDDBMSVMs.SAPHANASID -SAPHANAInstanceNumber $SAPSIDDBMSVMs.SAPHANAInstanceNumber -PrintExecutionCommand $PrintExecutionCommand
                }

                "SQLServer" {
                    # Start SQL Server DB                    
                    Stop-AzSQLServerDB  -ResourceGroupName $SAPSIDDBMSVMs.ResourceGroupName -VMName $SAPSIDDBMSVMs.VMName  -DBSIDName $SAPSIDDBMSVMs.SAPSID  -DBInstanceName $SAPSIDDBMSVMs.DBInstanceName  -PrintExecutionCommand $PrintExecutionCommand
                }

                "Sybase" {
                    # Not yet Implemented
                    Write-WithTime "Stop of SAP Sybase is not yet implemented."                     
                }

                "MaxDB" {
                    # Not yet Implemented
                    Write-WithTime "Stop of SAP MaxDB is not yet implemented."                    
                }

                "Oracle" {
                    # Not yet Implemented
                    Write-WithTime "Stop of Oracle is not yet implemented."                    
                }

                "IBMDB2" {
                    # Not yet Implemented
                    Write-WithTime "Stop of IBM DB2 is not yet implemented."                    
                }
            }    
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}

function Get-AzONESAPApplicationInstance {
    <#
    .SYNOPSIS 
    Get one SAPSID Instance.
    
    .DESCRIPTION
    Get one SAPSID Instance. Returned object has [VMName;SAPInstanceNumber;SAPInstanceType]
        
    .PARAMETER SAPSID 
    SAP SID     
    
    .EXAMPLE     
    Get-AzONESAPApplicationInstance -SAPSID "PR1"
 #>

    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]         
        $SAPSIDApplicationVMs,

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False          
    )

    BEGIN {}
    
    PROCESS {
        try {                         
            $SAPSID = $SAPSIDApplicationVMs[0].SAPSID
            $VMName = $SAPSIDApplicationVMs[0].VMName
            $ResourceGroupName = $SAPSIDApplicationVMs[0].ResourceGroupName
            $SAPApplicationInstanceNumber = $SAPSIDApplicationVMs[0].SAPApplicationInstanceNumber
            $SAPInstanceType = $SAPSIDApplicationVMs[0].SAPInstanceType
            $OSType = Get-AzVMOSType -VMName $VMName -ResourceGroupName $ResourceGroupName

            if ($OSType -eq "Windows") {                
                #$SAPSIDPassword = Get-AzVMTagValue -ResourceGroupName $ResourceGroupName  -VMName $VMName  -KeyName "SAPSIDPassword"  
                $SIDADMUser = $SAPSID.Trim().ToLower() + "adm"
                $SAPSIDCredentials = Get-AzAutomationSAPPSCredential -CredentialName  $SIDADMUser  
                $SAPSIDPassword = $SAPSIDCredentials.Password
                $PathToSAPControl = Get-AzVMTagValue -ResourceGroupName $ResourceGroupName  -VMName $VMName  -KeyName "PathToSAPControl"  
            }

            $obj = New-Object -TypeName psobject

            $obj | add-member  -NotePropertyName "SAPSID"                       -NotePropertyValue $SAPSID  
            $obj | add-member  -NotePropertyName "VMName"                       -NotePropertyValue $VMName  
            $obj | add-member  -NotePropertyName "ResourceGroupName"            -NotePropertyValue $ResourceGroupName  
            $obj | add-member  -NotePropertyName "SAPApplicationInstanceNumber" -NotePropertyValue $SAPApplicationInstanceNumber
            $obj | add-member  -NotePropertyName "SAPInstanceType"              -NotePropertyValue $SAPInstanceType
            $obj | add-member  -NotePropertyName "OSType"                       -NotePropertyValue $OSType 

            if ($OSType -eq "Windows") {
                $obj | add-member  -NotePropertyName "SAPSIDPassword"           -NotePropertyValue $SAPSIDPassword
                $obj | add-member  -NotePropertyName "PathToSAPControl"         -NotePropertyValue $PathToSAPControl               
            }

            #Return formated object
            Write-Output $obj                                    
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}


function Get-AzSAPSystemStatusLinux {
    <#
    .SYNOPSIS 
    Get SAP System Status on Linux.
    
    .DESCRIPTION
    Get SAP System Status on Linux.

    .PARAMETER VMName 
    VM name where SAP instance is installed. 

    .PARAMETER ResourceGroupName 
    Resource Group Name of the SAP instance VM.        

    .PARAMETER InstanceNumberToConnect 
    SAP Instance Number to Connect    

    .PARAMETER SAPSID 
    SAP SID    

    .PARAMETER PrintExecutionCommand 
    If set to $True, it will print execution command.
    
    .EXAMPLE     
    Get-AzSAPSystemStatusLinux  -ResourceGroupName "PR1-RG"  -VMName "PR1-DB" -SAPSID "PR1" -InstanceNumberToConnect 1 
 #>

    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $True)]
        [ValidateLength(1, 2)]
        [string] $InstanceNumberToConnect,

        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False,

        [switch] $PrintOutputWithWriteHost
       
    )

    BEGIN {}
    
    PROCESS {
        try {   
            
            if ($PrintOutputWithWriteHost) {                
                Write-WithTime_Using_WriteHost "SAP System '$SAPSID' Status:"
            }else {                
                Write-WithTime "SAP System '$SAPSID' Status:"
            }                        

            $SAPSidUser = $SAPSID.ToLower() + "adm"            
            $Command = "su --login $SAPSidUser -c 'sapcontrol -nr $InstanceNumberToConnect -function GetSystemInstanceList'"
            
            if ($PrintExecutionCommand -eq $True) {

                if ($PrintOutputWithWriteHost) {                
                    Write-WithTime_Using_WriteHost "Executing command '$Command'"
                }else {                
                    Write-WithTime "Executing command '$Command'"
                }                
            }

            $Command | Out-File "command.txt"

            $ret = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName  -CommandId RunShellScript  -ScriptPath command.txt
            $ret.Value[0].Message

            #Write-Host "Waiting for 10 sec  ..."
            Start-Sleep 10            
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}
function Get-AzSAPSystemStatusWindows {
    <#
    .SYNOPSIS 
    Get SAP System Status on Windows.
    
    .DESCRIPTION
    Get SAP System Status on Windows.

    .PARAMETER VMName 
    VM name where SAP instance is installed. 

    .PARAMETER ResourceGroupName 
    Resource Group Name of the SAP instance VM.        

    .PARAMETER InstanceNumberToConnect 
    SAP Instance Number to Connect    

    .PARAMETER PathToSAPControl 
    Full path to SAP Control executable.        

    .PARAMETER SAPSID 
    SAP SID    

    .PARAMETER SAPSidPwd 
    SAP <sid>adm user password

    .PARAMETER PrintExecutionCommand 
    If set to $True, it will print execution command.
    
    .EXAMPLE     
    Get-AzSAPSystemStatusWindows  -ResourceGroupName "PR1-RG"  -VMName "PR1-DB" -SAPSID "PR1" -InstanceNumberToConnect 1 -PathToSAPControl "C:\usr\sap\PR2\ASCS00\exe\sapcontrol.exe" -SAPSidPwd "MyPassword12"
 #>

    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $True)]
        [ValidateLength(1, 2)] 
        [string] $InstanceNumberToConnect,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $PathToSAPControl,

        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $SAPSidPwd,        

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False,
        
        [switch] $PrintOutputWithWriteHost
    )

    BEGIN {}
    
    PROCESS {
        try {   
            $SAPSidUser = $SAPSID.ToLower() + "adm"            

            if ($PrintOutputWithWriteHost) {                
                Write-WithTime_Using_WriteHost "SAP System '$SAPSID' Status:"
            }else {                
                Write-WithTime "SAP System '$SAPSID' Status:"
            }
            
            $Command        = "$PathToSAPControl -nr $InstanceNumberToConnect -user $SAPSidUser '$SAPSidPwd'  -function GetSystemInstanceList"
            $CommandToPrint = "$PathToSAPControl -nr $InstanceNumberToConnect -user $SAPSidUser '***pwd***' -function GetSystemInstanceList"
            
            if ($PrintExecutionCommand -eq $True) {
                if ($PrintOutputWithWriteHost) {                
                    Write-WithTime_Using_WriteHost "Executing command '$CommandToPrint' "
                }else {                
                    Write-WithTime "Executing command '$CommandToPrint' "
                }                
            }

            $Command | Out-File "command.txt"

            $ret = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName  -CommandId RunPowerShellScript -ScriptPath command.txt
            $ret.Value[0].Message

            # Waiting for 10 sec  ...
            Start-Sleep 10            
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}

function Get-AzSAPSystemStatus {
    <#
    .SYNOPSIS 
    Get SAP System Status.
    
    .DESCRIPTION
    Get SAP System Status. Module will automaticaly recognize Windows or Linux OS.
    
    .PARAMETER SAPSID 
    SAP SID    

    .PARAMETER PrintExecutionCommand 
    If set to $True, it will print execution command.

    .EXAMPLE     
    $SAPSIDApplicationVMs  = Get-AzSAPApplicationInstances -SAPSID "SP1"
    Get-AzSAPSystemStatus  -SAPSIDApplicationVMs  $SAPSIDApplicationVMs
 #>

    [CmdletBinding()]
    param(       
        [Parameter(Mandatory = $True)]         
        $SAPSIDApplicationVMs,

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False   
    )

    BEGIN {}
    
    PROCESS {
        try {                       
            $ONESAPInstance = Get-AzONESAPApplicationInstance -SAPSIDApplicationVMs $SAPSIDApplicationVMs           

            if ($ONESAPInstance.OSType -eq "Linux") {
                Get-AzSAPSystemStatusLinux  -ResourceGroupName $ONESAPInstance.ResourceGroupName -VMName $ONESAPInstance.VMName -InstanceNumberToConnect $ONESAPInstance.SAPApplicationInstanceNumber -SAPSID $ONESAPInstance.SAPSID -PrintExecutionCommand $PrintExecutionCommand                            
            }
            elseif ($ONESAPInstance.OSType -eq "Windows") {
                Get-AzSAPSystemStatusWindows  -ResourceGroupName $ONESAPInstance.ResourceGroupName -VMName $ONESAPInstance.VMName -InstanceNumberToConnect $ONESAPInstance.SAPApplicationInstanceNumber -SAPSID $ONESAPInstance.SAPSID -PathToSAPControl $ONESAPInstance.PathToSAPControl -SAPSidPwd  $ONESAPInstance.SAPSIDPassword   -PrintExecutionCommand $PrintExecutionCommand

            }           
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}


function Start-AzSAPSystemLinux {
    <#
    .SYNOPSIS 
    Start SAP System on Linux.
    
    .DESCRIPTION
    Start SAP System on Linux.

    .PARAMETER VMName 
    VM name where SAP instance is installed. 

    .PARAMETER ResourceGroupName 
    Resource Group Name of the SAP instance VM.        

    .PARAMETER InstanceNumberToConnect 
    SAP Instance Number to Connect    

    .PARAMETER SAPSID 
    SAP SID    

    .PARAMETER WaitForStartTimeInSeconds
    Number of seconds to wait for SAP system to start.
    .PARAMETER PrintExecutionCommand 
    If set to $True, it will print execution command.
    
    .EXAMPLE     
    Start-AzSAPSystemLinux  -ResourceGroupName "PR1-RG"  -VMName "PR1-DB" -SAPSID "PR1" -InstanceNumberToConnect 1 
 #>

    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $True)]
        [ValidateLength(1, 2)]
        [string] $InstanceNumberToConnect,

        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,

        [Parameter(Mandatory = $False)] 
        [int] $WaitForStartTimeInSeconds = 600,

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False
    )

    BEGIN {}
    
    PROCESS {
        try {   
            $SAPSidUser = $SAPSID.ToLower() + "adm"
            #$SAPSIDUpper =  $SAPSID.ToUpper()
            
            Write-WithTime "Starting SAP '$SAPSID' System ..."

            $Command = "su --login $SAPSidUser -c 'sapcontrol -nr $InstanceNumberToConnect -function StartSystem'"
            
            if ($PrintExecutionCommand -eq $True) {
                Write-WithTime "Executing command '$Command' "
            }

            $Command | Out-File "command.txt"

            $ret = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName  -CommandId RunShellScript  -ScriptPath command.txt

            $ret.Value[0].Message

            Write-Output " "
            Write-WithTime "Waiting $WaitForStartTimeInSeconds seconds for SAP system '$SAPSID' to start ..."
            Start-Sleep $WaitForStartTimeInSeconds            
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}


function Start-AzSAPSystemWindows {
    <#
    .SYNOPSIS 
    Get SAP System Status on Windows.
    
    .DESCRIPTION
    Get SAP System Status on Windows.

    .PARAMETER VMName 
    VM name where SAP instance is installed. 

    .PARAMETER ResourceGroupName 
    Resource Group Name of the SAP instance VM.        

    .PARAMETER InstanceNumberToConnect 
    SAP Instance Number to Connect    

    .PARAMETER PathToSAPControl 
    Full path to SAP Control executable.        

    .PARAMETER SAPSID 
    SAP SID    

    .PARAMETER SAPSidPwd 
    SAP <sid>adm user password

    .PARAMETER WaitForStartTimeInSeconds
    Number of seconds to wait for SAP system to start.

    .PARAMETER PrintExecutionCommand 
    If set to $True, it will print execution command.
    
    .EXAMPLE     
    Start-AzSAPSystemWindows  -ResourceGroupName "PR1-RG"  -VMName "PR1-DB" -SAPSID "PR1" -InstanceNumberToConnect 1 -PathToSAPControl "C:\usr\sap\PR2\ASCS00\exe\sapcontrol.exe" -SAPSidPwd "MyPassword12"
 #>

    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $True)]
        [ValidateLength(1, 2)]
        [string] $InstanceNumberToConnect,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $PathToSAPControl,

        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $SAPSidPwd,     
        
        [Parameter(Mandatory = $False)] 
        [int] $WaitForStartTimeInSeconds = 600,

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False
       
    )

    BEGIN {}
    
    PROCESS {
        try {   
            $SAPSidUser = $SAPSID.ToLower() + "adm"            

            Write-WithTime "Starting SAP '$SAPSID' System ..."           
            $Command        = "$PathToSAPControl -nr $InstanceNumberToConnect -user $SAPSidUser '$SAPSidPwd'  -function StartSystem"
            $CommandToPrint = "$PathToSAPControl -nr $InstanceNumberToConnect -user $SAPSidUser '***pwd***' -function StartSystem"
            
            if ($PrintExecutionCommand -eq $True) {
                Write-WithTime "Executing command '$CommandToPrint' "
            }

            $Command | Out-File "command.txt"

            $ret = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName  -CommandId RunPowerShellScript -ScriptPath command.txt
            $ret.Value[0].Message

            Write-Output " "
            Write-WithTime "Waiting $WaitForStartTimeInSeconds seconds for SAP system '$SAPSID' to start ..."
            Start-Sleep $WaitForStartTimeInSeconds    
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}

function Start-AzSAPSystem {
    <#
    .SYNOPSIS 
    Start SAP System.
    
    .DESCRIPTION
    Start SAP System. Module will automaticaly recognize Windows or Linux OS.
    
    .PARAMETER SAPSID 
    SAP SID    

    .PARAMETER WaitForStartTimeInSeconds
    Number of seconds to wait for SAP system to start.

    .EXAMPLE     
    Start-AzSAPSystem -SAPSID "PR1" 
 #>

    [CmdletBinding()]
    param(       
        [Parameter(Mandatory = $True)]         
        $SAPSIDApplicationVMs,

        [Parameter(Mandatory = $False)] 
        [int] $WaitForStartTimeInSeconds = 600,

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False        
    )

    BEGIN {}
    
    PROCESS {
        try {   
            # get one / any SAP instance            
            $ONESAPInstance = Get-AzONESAPApplicationInstance -SAPSIDApplicationVMs $SAPSIDApplicationVMs

            if ($ONESAPInstance.OSType -eq "Linux") {                  
                Start-AzSAPSystemLinux    -ResourceGroupName $ONESAPInstance.ResourceGroupName -VMName $ONESAPInstance.VMName -InstanceNumberToConnect $ONESAPInstance.SAPApplicationInstanceNumber -SAPSID $ONESAPInstance.SAPSID -WaitForStartTimeInSeconds $WaitForStartTimeInSeconds -PrintExecutionCommand $PrintExecutionCommand                            
            }
            elseif ($ONESAPInstance.OSType -eq "Windows") {                
                Start-AzSAPSystemWindows  -ResourceGroupName $ONESAPInstance.ResourceGroupName -VMName $ONESAPInstance.VMName -InstanceNumberToConnect $ONESAPInstance.SAPApplicationInstanceNumber -SAPSID $ONESAPInstance.SAPSID -WaitForStartTimeInSeconds $WaitForStartTimeInSeconds -PathToSAPControl $ONESAPInstance.PathToSAPControl -SAPSidPwd  $ONESAPInstance.SAPSIDPassword  -PrintExecutionCommand $PrintExecutionCommand
            }           
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}

function Stop-AzSAPSystemLinux {
    <#
    .SYNOPSIS 
    Stop SAP System on Linux.
    
    .DESCRIPTION
    Stop SAP System on Linux.

    .PARAMETER VMName 
    VM name where SAP instance is installed. 

    .PARAMETER ResourceGroupName 
    Resource Group Name of the SAP instance VM.        

    .PARAMETER InstanceNumberToConnect 
    SAP Instance Number to Connect    

    .PARAMETER SAPSID 
    SAP SID    

    .PARAMETER SoftShutdownTimeInSeconds
    Soft shutdown time for SAP system to stop.

    .PARAMETER PrintExecutionCommand 
    If set to $True, it will print execution command.
    
    .EXAMPLE     
    Stop-AzSAPSystemLinux  -ResourceGroupName "PR1-RG"  -VMName "PR1-DB" -SAPSID "PR1" -InstanceNumberToConnect 1 
 #>


    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $True)]
        [ValidateLength(1, 2)]
        [string] $InstanceNumberToConnect,

        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,

        [Parameter(Mandatory = $False)] 
        [int] $SoftShutdownTimeInSeconds = "600",

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False

    )

    BEGIN {}
    
    PROCESS {
        try {   
            $SAPSidUser = $SAPSID.ToLower() + "adm"            

            # Stop SAP ABAP Application Server
            Write-WithTime "Stopping SAP '$SAPSID' System ..."

            $Command = "su --login $SAPSidUser -c 'sapcontrol -nr $InstanceNumberToConnect -function StopSystem ALL $SoftShutdownTimeInSeconds $SoftShutdownTimeInSeconds'"
            
            if ($PrintExecutionCommand -eq $True) {
                Write-WithTime "Executing command '$Command' "
            }

            $Command | Out-File "command.txt"

            $ret = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName  -CommandId RunShellScript  -ScriptPath command.txt

            $ret.Value[0].Message            

            Write-Output " "
            Write-WithTime "Waiting $SoftShutdownTimeInSeconds seconds for SAP system '$SAPSID' to stop ..."
            Start-Sleep ($SoftShutdownTimeInSeconds + 30)
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}

function Stop-AzSAPSystemWindows {
    <#
        .SYNOPSIS 
        Stop SAP System on Windows.
        
        .DESCRIPTION
        Stop SAP System Windows.
    
        .PARAMETER VMName 
        VM name where SAP instance is installed. 
    
        .PARAMETER ResourceGroupName 
        Resource Group Name of the SAP instance VM.        
    
        .PARAMETER InstanceNumberToConnect 
        SAP Instance Number to Connect    
    
        .PARAMETER PathToSAPControl 
        Full path to SAP Control executable.        
    
        .PARAMETER SAPSID 
        SAP SID    
    
        .PARAMETER SAPSidPwd 
        SAP <sid>adm user password
    
        .PARAMETER SoftShutdownTimeInSeconds
        Soft shutdown time for SAP system to stop.
    
        .PARAMETER PrintExecutionCommand 
        If set to $True, it will print execution command.
        
        .EXAMPLE     
        Stop-AzSAPSystemWindows  -ResourceGroupName "PR1-RG"  -VMName "PR1-DB" -SAPSID "PR1" -InstanceNumberToConnect 1 -PathToSAPControl "C:\usr\sap\PR2\ASCS00\exe\sapcontrol.exe" -SAPSidPwd "MyPassword12"
     #>
    
    [CmdletBinding()]
    param(
            
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,
    
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,
    
        [Parameter(Mandatory = $True)]
        [ValidateLength(1, 2)]
        [string] $InstanceNumberToConnect,
    
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $PathToSAPControl,
    
        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,
    
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $SAPSidPwd,     
            
        [Parameter(Mandatory = $False)] 
        [int] $SoftShutdownTimeInSeconds = 600,
    
        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False
           
    )
    
    BEGIN {}
        
    PROCESS {
        try {   
            $SAPSidUser = $SAPSID.ToLower() + "adm"            
    
            Write-WithTime "Stopping SAP '$SAPSID' System ..."           
            $Command        = "$PathToSAPControl -nr $InstanceNumberToConnect -user $SAPSidUser '$SAPSidPwd' -function StopSystem ALL $SoftShutdownTimeInSeconds $SoftShutdownTimeInSeconds"
            $CommandToPrint = "$PathToSAPControl -nr $InstanceNumberToConnect -user $SAPSidUser '***pwd****' -function StopSystem ALL $SoftShutdownTimeInSeconds $SoftShutdownTimeInSeconds"
                
            if ($PrintExecutionCommand -eq $True) {
                Write-WithTime "Executing command '$CommandToPrint' "
            }
    
            $Command | Out-File "command.txt"
    
            $ret = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName  -CommandId RunPowerShellScript -ScriptPath command.txt
            $ret.Value[0].Message
    
            Write-Output " "
            Write-WithTime "Waiting $SoftShutdownTimeInSeconds seconds for SAP system '$SAPSID' to stop ..."
            Start-Sleep ($SoftShutdownTimeInSeconds + 30)
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }
    
    END {}
}
    
function Stop-AzSAPSystem {
    <#
        .SYNOPSIS 
        Stop SAP System.
        
        .DESCRIPTION
        Stop SAP System. Module will automaticaly recognize Windows or Linux OS.
        
        .PARAMETER SAPSID 
        SAP SID    
    
        .PARAMETER SoftShutdownTimeInSeconds
        Soft shutdown time for SAP system to stop.
    
        .EXAMPLE     
        Stop-AzSAPSystem -SAPSID "PR1" 
     #>
    
    [CmdletBinding()]
    param(       
        [Parameter(Mandatory = $True)]         
        $SAPSIDApplicationVMs,
    
        [Parameter(Mandatory = $False)] 
        [int] $SoftShutdownTimeInSeconds = 600,
    
        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False        
    )
    
    BEGIN {}
        
    PROCESS {
        try {   
            # get one / any SAP instance                        
            $ONESAPInstance = Get-AzONESAPApplicationInstance -SAPSIDApplicationVMs $SAPSIDApplicationVMs 
                
            if ($ONESAPInstance.OSType -eq "Linux") {                
                Stop-AzSAPSystemLinux    -ResourceGroupName $ONESAPInstance.ResourceGroupName -VMName $ONESAPInstance.VMName -InstanceNumberToConnect $ONESAPInstance.SAPApplicationInstanceNumber -SAPSID $ONESAPInstance.SAPSID -SoftShutdownTimeInSeconds $SoftShutdownTimeInSeconds -PrintExecutionCommand $PrintExecutionCommand                            
            }
            elseif ($ONESAPInstance.OSType -eq "Windows") {                
                Stop-AzSAPSystemWindows  -ResourceGroupName $ONESAPInstance.ResourceGroupName -VMName $ONESAPInstance.VMName -InstanceNumberToConnect $ONESAPInstance.SAPApplicationInstanceNumber -SAPSID $ONESAPInstance.SAPSID -SoftShutdownTimeInSeconds $SoftShutdownTimeInSeconds -PathToSAPControl $ONESAPInstance.PathToSAPControl -SAPSidPwd  $ONESAPInstance.SAPSIDPassword  -PrintExecutionCommand $PrintExecutionCommand
            }           
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }
    
    END {}
}
    
function Get-AzVMTags {
    <#
    .SYNOPSIS 
    Gets Key/Value pair tags objects.
    
    .DESCRIPTION
    Gets Key/Value pair tags objects.
    
    .PARAMETER ResourceGroupName 
    ResourceGroupName.    
    
    .PARAMETER VMName 
    VMName.    

    .EXAMPLE 
    Get-AzVMTags

 #>
    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName
    )

    BEGIN {}
    
    PROCESS {
        try {   
                      
            $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -VMName $VMName
            $Tags = $VM.Tags
            
            foreach ($Tag in $Tags.GetEnumerator()) {
                $obj = New-Object -TypeName psobject
                $obj | add-member  -NotePropertyName "Key"   -NotePropertyValue $Tag.Key  
                $obj | add-member  -NotePropertyName "Value" -NotePropertyValue $Tag.Value  
                 
                #Return formated object
                Write-Output $obj                
            }                                                                                             
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}

function Get-AzVMTagValue {
    <#
    .SYNOPSIS 
    Gets Value of Key tag for specified VM.
    
    .DESCRIPTION
    Gets Value of Key tag for specified VM. If key do not exist, empty string is returned.
    
    .PARAMETER ResourceGroupName 
    ResourceGroupName.    
    
    .PARAMETER VMName 
    VMName.   

    .PARAMETER KeyName 
    KeyName.   

    .EXAMPLE
    Get-AzVMTagValue -ResourceGroupName "gor-linux-eastus2-2" -VMName "pr2-ascs"  -KeyName "PathToSAPControl"      

 #>
    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $KeyName
    )

    BEGIN {}
    
    PROCESS {
        try {                         
            $VMTags = Get-AzVMTags -ResourceGroupName $ResourceGroupName -VMName $VMName 
            
            $TagWithSpecificKey = $VMTags | Where-Object Key -EQ $KeyName
                        
            $ValueOfTheTag = $TagWithSpecificKey.Value

            Write-Output $ValueOfTheTag                                                                                    
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}
function Get-AzSAPDBMSInstances {
    <#
       .SYNOPSIS 
       Get ALL VMs with same SAPSID tag, that runs DBMS layer.
                   
       .DESCRIPTION
       Get ALL VMs with same SAPSID tag, that runs DBMS layer.
       For each VM it will display:
                   - SAPSID
                   - SAP Instance Type [DBMS]
                   - SAPDBMSType
                   - SAPHANASID (for HANA)
                   - SAPHANAInstanceNumber (for HANA)
                   - Azure Resource Group Name
                   - VM Name                
                   - OS type
   
                   
                   .PARAMETER SAPSID 
                   SAP system SID.    
                   
                   .EXAMPLE 
                   # specify SAP SID 'PR1'
                   $SAPSID = "PR1"
                   
                   # Collect SAP VM instances with the same Tag
                   $SAPDBMSInstance = Get-AzSAPDBMSInstances -SAPSID $SAPSID
               
                   # List all collected instances
                   $SAPDBMSInstance
               
                #>
               
    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        $SAPSID         
    )
               
    BEGIN {}
                   
    PROCESS {
        try {   
                                     
            $tags = @{"SAPSystemSID" = $SAPSID }
            $SAPVMs = Get-AzResource -ResourceType "Microsoft.Compute/virtualMachines"  -Tag $tags
   
            foreach ($VMResource in $SAPVMs) {
                   
                $VMTags = Get-AzVMTags -ResourceGroupName $VMResource.ResourceGroupName -VMName $VMResource.Name 
   
                #Check if VM is DBMS host
                $IsDBMSHost = $false                
                
                # If 'SAPDBMSType' Tag exist, then VM is DBMS VM
                $SAPDBMSTypeTag = $VMTags | Where-Object Key -EQ "SAPDBMSType"
                if ($SAPDBMSTypeTag -ne $Null) {                    
                    $IsDBMSHost = $True
                }
   
                if ($IsDBMSHost) {
                    $obj = New-Object -TypeName psobject
                       
                    $OSType = Get-AzVMOSType -VMName $VMResource.Name -ResourceGroupName $VMResource.ResourceGroupName  
                                      
                       
                    $obj | add-member  -NotePropertyName "SAPSID" -NotePropertyValue $SAPSID  
   
                    # Get DBMS type
                    $SAPDBMSTypeTag = $VMTags | Where-Object Key -EQ "SAPDBMSType"  
                    $SAPDBMSType = $SAPDBMSTypeTag.Value
   
                    If ($SAPDBMSType -eq "HANA") {
                        # Get HANA SID
                        $SAPHANASIDTag = $VMTags | Where-Object Key -EQ "SAPHANASID"  
                        $SAPHANASID = $SAPHANASIDTag.Value
                        $obj | add-member  -NotePropertyName "SAPHANASID" -NotePropertyValue $SAPHANASID 
                           
                        # Get SAPHANAInstanceNumber
                        $SAPHANAInstanceNumberTag = $VMTags | Where-Object Key -EQ "SAPHANAInstanceNumber"  
                        $SAPHANAInstanceNumber = $SAPHANAInstanceNumberTag.Value
                        $obj | add-member  -NotePropertyName "SAPHANAInstanceNumber" -NotePropertyValue $SAPHANAInstanceNumber                         
   
                    }elseif ($SAPDBMSType -eq "SQLServer") {
                        $SQLServerInstanceNameTag = $VMTags | Where-Object Key -EQ "DBInstanceName"  
                        $SQLServerInstanceName = $SQLServerInstanceNameTag.Value
                        $obj | add-member  -NotePropertyName "DBInstanceName" -NotePropertyValue $SQLServerInstanceName                         
                    }
   
                    $obj | add-member  -NotePropertyName "SAPInstanceType" -NotePropertyValue "SAP_DBMS"  
                    $obj | add-member  -NotePropertyName "SAPDBMSType" -NotePropertyValue $SAPDBMSType                      
                    $obj | add-member  -NotePropertyName "ResourceGroupName" -NotePropertyValue $VMResource.ResourceGroupName                 
                    $obj | add-member  -NotePropertyName "VMName" -NotePropertyValue $VMResource.Name                    
                    $obj | add-member  -NotePropertyName "OSType"   -NotePropertyValue $OSType
   
                    #Return formated object
                    Write-Output $obj                
                }
            }                                                                                                                   
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }
               
    END {}
}


function Get-AzSAPHANAInstances {
    <#
       .SYNOPSIS 
       Get ALL VMs with same SAPHANASID tag, that runs DBMS layer.
                   
       .DESCRIPTION
       Get ALL VMs with same SAPSID tag, that runs DBMS layer.
       For each VM it will display:
                   - SAP Instance Type [DBMS]
                   - SAPDBMSType
                   - SAPHANASID (for HANA)
                   - SAPHANAInstanceNumber (for HANA)
                   - Azure Resource Group Name
                   - VM Name                
                   - OS type
   
                   
        .PARAMETER SAPHANASID 
        SAP HANA SID.    
                   
        .EXAMPLE 
        # specify SAP HANA SID 'CE1'
        $SAPSID = "CE1"
                   
        # Collect SAP VM instances with the same Tag
        $SAPDBMSInstance = Get-AzSAPHANAInstances -SAPSID $SAPSID
               
        # List all collected instances
        $SAPDBMSInstance
               
#>
               
    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        $SAPHANASID         
    )
               
    BEGIN {}
                   
    PROCESS {
        try {   
                                     
            $tags = @{"SAPHANASID" = $SAPHANASID }
            $SAPVMs = Get-AzResource -ResourceType "Microsoft.Compute/virtualMachines"  -Tag $tags
   
            foreach ($VMResource in $SAPVMs) {
                   
                $VMTags = Get-AzVMTags -ResourceGroupName $VMResource.ResourceGroupName -VMName $VMResource.Name 
                        
                $obj = New-Object -TypeName psobject
                       
                $OSType = Get-AzVMOSType -VMName $VMResource.Name -ResourceGroupName $VMResource.ResourceGroupName  
                                                                                              
                $SAPDBMSType = "HANA"
                    
                $obj | add-member  -NotePropertyName "SAPHANASID" -NotePropertyValue $SAPHANASID 
                           
                # Get SAPHANAInstanceNumber
                $SAPHANAInstanceNumberTag = $VMTags | Where-Object Key -EQ "SAPHANAInstanceNumber"  
                $SAPHANAInstanceNumber = $SAPHANAInstanceNumberTag.Value

                $obj | add-member  -NotePropertyName "SAPHANAInstanceNumber" -NotePropertyValue $SAPHANAInstanceNumber                                                
                $obj | add-member  -NotePropertyName "SAPInstanceType" -NotePropertyValue "SAP_DBMS"  
                $obj | add-member  -NotePropertyName "SAPDBMSType" -NotePropertyValue $SAPDBMSType                      
                $obj | add-member  -NotePropertyName "ResourceGroupName" -NotePropertyValue $VMResource.ResourceGroupName                 
                $obj | add-member  -NotePropertyName "VMName" -NotePropertyValue $VMResource.Name                    
                $obj | add-member  -NotePropertyName "OSType"   -NotePropertyValue $OSType
   
                #Return formated object
                Write-Output $obj                
            }                                                                                                                               
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }
               
    END {}
}
function Get-AzSAPApplicationInstances {
    <#
    .SYNOPSIS 
    Get ALL VMs with same SAPSID tag, that runs application layer.
                                
    .DESCRIPTION
    Get ALL VMs with same SAPSID tag, that runs application layer.
    For each VM it will display:
        - SAPSID
        - SAP Instance Type
        - SAP Application Instance Number 
        - Azure Resource Group Name
        - VM Name
        - OS type
                                
    .PARAMETER SAPSID 
    SAP system SID.    
                                
    .EXAMPLE 
    # specify SAP SID 'PR1'
    $SAPSID = "PR1"
                                
    # Collect SAP VM instances with the same Tag
    $SAPApplicationInstances = Get-AzSAPApplicationInstances -SAPSID $SAPSID
                            
    # List all collected instances
    $SAPApplicationInstances
                            
#>
                            
    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        $SAPSID         
    )
                            
    BEGIN {}
                                
    PROCESS {
        try {   
                                                  
            $tags = @{"SAPSystemSID" = $SAPSID }
            $SAPVMs = Get-AzResource -ResourceType "Microsoft.Compute/virtualMachines"  -Tag $tags
                
            foreach ($VMResource in $SAPVMs) {
                                
                $VMTags = Get-AzVMTags -ResourceGroupName $VMResource.ResourceGroupName -VMName $VMResource.Name 
                
                $SAPApplicationInstanceTypeTag = $VMTags | Where-Object Key -EQ "SAPApplicationInstanceType"
                if ($SAPApplicationInstanceTypeTag -ne $Null) {                    
                    # it is application SAP instance
                    
                    $obj = New-Object -TypeName psobject
                    
                    # Get 'SAPApplicationInstanceType'
                    $SAPApplicationInstanceType = $SAPApplicationInstanceTypeTag.Value

                    # Get 'SAPApplicationInstanceNumber'
                    $SAPApplicationInstanceNumberTag = $VMTags | Where-Object Key -EQ "SAPApplicationInstanceNumber"
                    $SAPApplicationInstanceNumber = $SAPApplicationInstanceNumberTag.Value                    

                    $OSType = Get-AzVMOSType -VMName $VMResource.Name -ResourceGroupName $VMResource.ResourceGroupName                                                         
                    #Write-Host "OSType: $OSType"
                    $obj | add-member  -NotePropertyName "SAPSID" -NotePropertyValue $SAPSID  

                    $obj | add-member  -NotePropertyName "SAPInstanceType" -NotePropertyValue $SAPApplicationInstanceType
                    $obj | add-member  -NotePropertyName "SAPApplicationInstanceNumber" -NotePropertyValue $SAPApplicationInstanceNumber

                    $obj | add-member  -NotePropertyName "ResourceGroupName" -NotePropertyValue $VMResource.ResourceGroupName                 
                    $obj | add-member  -NotePropertyName "VMName" -NotePropertyValue $VMResource.Name                    
                    $obj | add-member  -NotePropertyName "OSType"   -NotePropertyValue $OSType

                    #Return formated object
                    Write-Output $obj  
                }                                                
            }                                                                                                                   
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }
                            
    END {}
}

function Test-AzSAPSIDTagExist {
    <#
    .SYNOPSIS 
    Test if  Tag with 'SAPSystemSID' = '$SAPSID' exist. If not, exit.
    
    .DESCRIPTION
   Test if  Tag with 'SAPSystemSID' = '$SAPSID' exist. If not, exit.
    
    .PARAMETER SAPSID 
    SAP system SID.    
    
    .EXAMPLE 
    # specify SAP SID 'PR1'
    $SAPSID = "PR1"
    
    # test if SAPSIDSystem Tag with $SAPSID value exist
    Test-AzSAPSIDTagExist -SAPSID $SAPSID

    # List all collected instances
    $SAPInstances

 #>

    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        $SAPSID         
    )

    BEGIN {}
    
    PROCESS {
        try {   
                      
            $tags = @{"SAPSystemSID" = $SAPSID }
            $SAPVMs = Get-AzResource -ResourceType "Microsoft.Compute/virtualMachines"  -Tag $tags

            if ($SAPVMs -eq $null) {
                Write-WithTime "Cannot find VMs with Tag 'SAPSystemSID' = '$SAPSID'"
                Write-WithTime "Exiting runbook."

                exit
            }
            else {
                Write-WithTime "Found VMs with Tag 'SAPSystemSID' = '$SAPSID'"
            }                                                        
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}

function Test-AzSAPHANASIDTagExist {
    <#
    .SYNOPSIS 
    Test if  Tag with 'SAPHANASID' = '$SAPHANASID' exist. If not, exit.
    
    .DESCRIPTION
    Test if  Tag with 'SAPHANASID' = '$SAPHANASID' exist. If not, exit.
    
    .PARAMETER SAPSID 
    SAP system SID.    
    
    .EXAMPLE 
    # specify SAP SIDHANA  'PR1'
    $SAPHANASID = "PR1"
    
    # test if SAPSIDSystem Tag with $SAPSID value exist
    Test-AzSAPHANASIDTagExist -SAPHANASID $SAPHANASID    

 #>

    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        $SAPHANASID         
    )

    BEGIN {}
    
    PROCESS {
        try {   
                      
            $tags = @{"SAPHANASID" = $SAPHANASID }
            $SAPVMs = Get-AzResource -ResourceType "Microsoft.Compute/virtualMachines"  -Tag $tags

            if ($SAPVMs -eq $null) {
                Write-WithTime "Cannot find VMs with Tag 'SAPHANASID' = '$SAPHANASID'"
                Write-WithTime "Exiting runbook."

                exit
            }
            else {
                Write-WithTime "Found VMs with Tag 'SAPHANASID' = '$SAPHANASID'"
            }                                                        
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}

function Show-AzSAPSIDVMApplicationInstances {
    <#
    .SYNOPSIS 
    Print the SAP VMs.
    
    .DESCRIPTION
    Print the SAP VMs.
    
    .PARAMETER SAPVMs 
    List of VM resources. This collection is a list of VMs with same 'SAPSID' tag.
    
    
    .EXAMPLE 
    $SAPSID = "PR2"
    $SAPSIDApplicationVMs = Get-AzSAPApplicationInstances -SAPSID $SAPSID
    Show-AzSAPSIDVMApplicationInstances -SAPVMs $SAPSIDApplicationVMs
 #>
    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        $SAPVMs
           
    )

    BEGIN {}
    
    PROCESS {
        try {   
                                               
            ForEach ($SAPVM in $SAPVMs) {
                Write-Output "SAPSID:                       $($SAPVM.SAPSID)"  
                Write-Output "SAPInstanceType:              $($SAPVM.SAPInstanceType)"  
                Write-Output "SAPApplicationInstanceNumber: $($SAPVM.SAPApplicationInstanceNumber)"  
                Write-Output "ResourceGroupName:            $($SAPVM.ResourceGroupName)"  
                Write-Output  "VMName:                       $($SAPVM.VMName)"  
                Write-Output "OSType:                       $($SAPVM.OSType)"                
                Write-Output ""
            }
                            

            
            
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}

function Show-AzSAPSIDVMDBMSInstances {
    <#
    .SYNOPSIS 
    Print the SAP VMs.
    
    .DESCRIPTION
    Print the SAP VMs.
    
    .PARAMETER SAPVMs 
    List of VM resources. This collection is a list of VMs with same 'SAPSID' tag.
    
    
    .EXAMPLE 
    $SAPSID = "PR2"
    $SAPSIDDBMSVMs = Get-AzSAPDBMSInstances -SAPSID $SAPSID
    Show-AzSAPSIDVMDBMSInstances -SAPVMs $SAPSIDApplicationVMs
 #>
    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        $SAPVMs
           
    )

    BEGIN {}
    
    PROCESS {
        try {                                                  
            ForEach ($SAPVM in $SAPVMs) {
                Write-Output "SAPSID:                       $($SAPVM.SAPSID)"  
                Write-Output "SAPInstanceType:              $($SAPVM.SAPInstanceType)"  
                Write-Output "SAPDBMSType:                  $($SAPVM.SAPDBMSType)"  
                
                if ($SAPVM.SAPDBMSType -eq "HANA") {
                    Write-Output "SAPHANASID:                   $($SAPVM.SAPHANASID)"  
                    Write-Output "SAPHANAInstanceNumber:        $($SAPVM.SAPHANAInstanceNumber)"  
                }

                Write-Output "ResourceGroupName:            $($SAPVM.ResourceGroupName)"  
                Write-Output "VMName:                       $($SAPVM.VMName)"  
                Write-Output "OSType:                       $($SAPVM.OSType)"                
                Write-Output ""
            }                                                    
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}

function ConvertTo-AzVMManagedDisksToPremium {
    <#
        .SYNOPSIS 
        Convert all disks of one VM to Premium type.
        
        .DESCRIPTION
        Convert all disks of one VM to Premium type.
        
        .PARAMETER ResourceGroupName 
        VM Resource Group Name.
        
        .PARAMETER VMName 
        VM Name.
        
        .EXAMPLE 
        Convert-AzVMManagedDisksToPremium  -ResourceGroupName  "gor-linux-eastus2-2" -VMName "ts2-di1"
     #>
    
    [CmdletBinding()]
    param(
            
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
                  
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName
    
            
    )
    
    BEGIN {}
        
    PROCESS {
        try {   
    
            Convert-AzVMManagedDisks -ResourceGroupName $ResourceGroupName -VMName $VMName -storageType "Premium_LRS"
    
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    
    }
    
    END {}
}
    
function ConvertTo-AzVMManagedDisksToStandard {
    <#
    .SYNOPSIS 
    Convert all disks of one vM to Standard type.
            
    .DESCRIPTION
    Convert all disks of one vM to Standard type.
            
    .PARAMETER ResourceGroupName 
    VM Resource Group Name.
            
    .PARAMETER VMName 
    VM Name.
            
    .EXAMPLE 
    Convert-AzVMManagedDisksToStandard  -ResourceGroupName  "gor-linux-eastus2-2" -VMName "ts2-di1"
#>
        
    [CmdletBinding()]
    param(
                
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
                      
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName
                
    )
        
    BEGIN {}
            
    PROCESS {
        try {   
        
            Convert-AzVMManagedDisks -ResourceGroupName $ResourceGroupName -VMName $VMName -storageType "Standard_LRS"                    
        
        }
        catch {
            Write-Error  $_.Exception.Message
        }
        
    }
        
    END {}
}
        
function Convert-AzVMCollectionManagedDisksToStandard {
    <#
        .SYNOPSIS 
        Convert all disks of VMs collection  to Standard type.
                
        .DESCRIPTION
        Convert all disks of VMs collection  to Standard type.
                
        .PARAMETER SAPVMs 
        VM collection.
            
        .EXAMPLE 
            
        $SAPSID = "TS1"
        $SAPSIDApplicationVMs = Get-AzSAPApplicationInstances -SAPSID $SAPSID
        Convert-AzVMCollectionManagedDisksToStandard -SAPVMs $SAPSIDApplicationVMs        
    #>
    
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        $SAPVMs
    )
        
    BEGIN {}
            
    PROCESS {
        try {                               
            ForEach ($VM in $SAPVMs) {                    
                Write-WithTime "Converting all managed disks of VM '$($VM.VMName)' in Azure resource group '$($VM.ResourceGroupName)' to 'Standard_LRS' type .."
                ConvertTo-AzVMManagedDisksToStandard -ResourceGroupName  $VM.ResourceGroupName -VMName $VM.VMName 
                Write-Output ""
            }
        }
        catch {
            Write-Error  $_.Exception.Message
        }
        
    }
        
    END {}
}    
    
        
function Convert-AzVMCollectionManagedDisksToPremium {
    <#
        .SYNOPSIS 
        Convert all disks of VMs collection  to Premium type.
                
        .DESCRIPTION
        Convert all disks of VMs collection  to Premium type.
                
        .PARAMETER SAPVMs 
        VM collection.
            
        .EXAMPLE         
        $SAPSID = "TS1"
        $SAPSIDApplicationVMs = Get-AzSAPApplicationInstances -SAPSID $SAPSID
        Convert-AzVMCollectionManagedDisksToPremium -SAPVMs $SAPSIDApplicationVMs        
    #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        $SAPVMs                         
    )
            
    BEGIN {}
                
    PROCESS {
        try {                               
            ForEach ($VM in $SAPVMs) {                        
                Write-WithTime "Converting all managed disks of VM '$($VM.VMName)' in Azure resource group '$($VM.ResourceGroupName)' to 'Premium_LRS' type .."
                ConvertTo-AzVMManagedDisksToPremium -ResourceGroupName  $VM.ResourceGroupName -VMName $VM.VMName 
                Write-Output ""
            }
        }
        catch {
            Write-Error  $_.Exception.Message
        }
            
    }
            
    END {}
}    
        
function Get-AzVMCollectionManagedDiskType {
    <#
        .SYNOPSIS 
        List all disks and disk type of VMs collection.
            
        .DESCRIPTION
        List all disks and disk type of VMs collection.
            
        .PARAMETER SAPVMs 
        VM collection.
            
        
        .EXAMPLE         
        $SAPSID = "TS1"
        $SAPSIDApplicationVMs = Get-AzSAPApplicationInstances -SAPSID $SAPSID
        Get-AzVMCollectionManagedDiskType -SAPVMs $SAPSIDApplicationVMs
    #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        $SAPVMs
                           
    )
        
    BEGIN {}
            
    PROCESS {
        try {                               
            ForEach ($VM in $SAPVMs) {                     
                $VMIsRunning = Test-AzVMIsStarted -ResourceGroupName  $VM.ResourceGroupName -VMName $VM.VMName
            
                if ($VMIsRunning -eq $True) {                    
                    # VM is runnign. Return to the main Runbook without listing the disks                    
                    return
                }
                    
                Write-WithTime "'$($VM.VMName)' VM in Azure resource group '$($VM.ResourceGroupName)' disks:"
                Get-AzVMManagedDiskType -ResourceGroupName  $VM.ResourceGroupName -VMName $VM.VMName 
                Write-Output ""
            }
        }
        catch {
            Write-Error  $_.Exception.Message
        }
        
    }
        
    END {}
}    
    
function Get-AzVMManagedDiskType {
    <#
            .SYNOPSIS 
            List all disks and disk type of one VM.
            
            .DESCRIPTION
            List all disks and disk type of one VM.
            
            .PARAMETER ResourceGroupName 
            Resource Group Name.
            
            .PARAMETER VMName 
            VM Name.
    
            .EXAMPLE         
            $SAPSID = "TS1"
            $SAPSIDApplicationVMs = Get-AzSAPApplicationInstances -SAPSID $SAPSID
            Get-AzVMCollectionManagedDiskType -ResourceGroupName "MyResourceGroupName"  -VMName  "myVM1"
        
    #>
    
    [CmdletBinding()]
    param(
            
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
                  
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName        
            
    )
    
    BEGIN {}
        
    PROCESS {
        try {   
    
            $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName
    
            #OS Disk
            $OSDisk = $VM.StorageProfile.OsDisk 
            $OSDiskName = $OSDisk.Name
            $OSDiskAllProperties = Get-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $OSDiskName
            Write-Output "$OSDiskName [$($OSDiskAllProperties.Sku.Name)]"
              
    
            #Data Disks
            $DataDisks = $VM.StorageProfile.DataDisks
            $DataDisksNames = $DataDisks.Name
    
            ForEach ($DataDiskName in $DataDisksNames) {
                $DataDiskAllProperties = Get-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $DataDiskName
                Write-Output "$DataDiskName [$($DataDiskAllProperties.Sku.Name)]"
            }
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    
    }
    
    END {}
}



##################

function Convert-AzVMManagedDisks {
    <#
        .SYNOPSIS 
        Convert all disks of one VM to Premium or Standard type.
        
        .DESCRIPTION
        Convert all disks of one vM to Standard type.
        
        .PARAMETER ResourceGroupName 
        VM Resource Group Name.
        
        .PARAMETER VMName 
        VM Name.
        
        .EXAMPLE 
        # Convert to Premium disks
        Convert-AzVMManagedDisks -ResourceGroupName  "gor-linux-eastus2-2" -VMName "ts2-di1" -storageType "Premium_LRS"
    
        .EXAMPLE 
        # Convert to Standard disks
        Convert-AzVMManagedDisks -ResourceGroupName  "gor-linux-eastus2-2" -VMName "ts2-di1" -storageType "Standard_LRS"
    
    #>
                
    [CmdletBinding()]
    param(
                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
                  
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,
    
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $storageType
                        
    )
                
    BEGIN {}
                    
    PROCESS {
        try {   
                
            $VMIsRunning = Test-AzVMIsStarted -ResourceGroupName  $ResourceGroupName -VMName $VMName

            if ($VMIsRunning -eq $True) {
                Write-WithTime("VM '$VMName' in resource group '$ResourceGroupName' is running. ")
                Write-WithTime("Skipping the disk conversion for the VM '$VMName' in resource group '$ResourceGroupName'. Disks cannot be converted when VM is running. ")
                
                return
            }
            

            $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName
    
            $OSDisk = $VM.StorageProfile.OsDisk 
            $OSDiskName = $OSDisk.Name
            $OSDiskAllProperties = Get-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $OSDiskName     
                
            Write-Output "Converting OS disk $OSDiskName to '$storageType' type ..."
            $OSDiskAllProperties.Sku = [Microsoft.Azure.Management.Compute.Models.DiskSku]::new($storageType)
            $OSDiskAllProperties | Update-AzDisk  > $Null                              
            Write-Output "Done!"                
    
            $DataDisks = $VM.StorageProfile.DataDisks
            $DataDisksNames = $DataDisks.Name
    
            ForEach ($DataDiskName in $DataDisksNames) {
                Write-Output "Converting data disk $DataDiskName to '$storageType' type ..."
                $DataDiskAllProperties = Get-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $DataDiskName
                $DataDiskAllProperties.Sku = [Microsoft.Azure.Management.Compute.Models.DiskSku]::new($storageType)
                $DataDiskAllProperties | Update-AzDisk  > $Null                     
                Write-Output "Done!"
            }                                        
        }
        catch {
            Write-Error  $_.Exception.Message
        }                
    }
                
    END {}
}
    
    
function Convert-AzALLSAPSystemVMsCollectionManagedDisksToPremium {
    <#
            .SYNOPSIS 
            Convert all disks of ALL SAP SID VMs  to Premium type.
                    
            .DESCRIPTION
            Convert all disks of ALL SAP SID VMs  to Premium type.
                    
            .PARAMETER SAPSIDApplicationVMs 
            Colelctions of VMs belonging to SAP apllication layer.

            .PARAMETER SAPSIDDBMSVMs 
            Colelctions of VMs belonging to SAP DBMS layer.
                
            .EXAMPLE         
            $SAPSID = "TS1"
            $SAPSIDApplicationVMs = Get-AzSAPApplicationInstances -SAPSID $SAPSID
            $SAPSIDDBMSVMs  = Get-AzSAPDBMSInstances -SAPSID $SAPSID

            Convert-AzALLSAPSystemVMsCollectionManagedDisksToPremium -SAPSIDApplicationVMs $SAPSIDApplicationVMs -SAPSIDDBMSVMs $SAPSIDDBMSVMs
        
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        $SAPSIDApplicationVMs,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        $SAPSIDDBMSVMs                
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
             
            Write-WithTime "SAP Application layer VMs disks:"
            Write-Output ""
            Get-AzVMCollectionManagedDiskType -SAPVMs $SAPSIDApplicationVMs

            Write-WithTime "Converting SAP Application layer VMs disks to 'Premium_LRS' ..."
            Convert-AzVMCollectionManagedDisksToPremium -SAPVMs $SAPSIDApplicationVMs
            Write-Output ""

            Write-WithTime "SAP Application layer VMs disks after conversion:"
            Write-Output ""
            Get-AzVMCollectionManagedDiskType -SAPVMs $SAPSIDApplicationVMs


            Write-WithTime "SAP DBMS layer VM(s)disks:"
            Write-Output ""
            Get-AzVMCollectionManagedDiskType -SAPVMs $SAPSIDDBMSVMs

            Write-WithTime "Converting DBMS layer VMs disks to 'Premium_LRS' ..."
            Convert-AzVMCollectionManagedDisksToPremium -SAPVMs $SAPSIDDBMSVMs
            Write-Output ""

            Write-WithTime "SAP DBMS layer VMs disks after conversion:"
            Write-Output ""
            Get-AzVMCollectionManagedDiskType -SAPVMs $SAPSIDDBMSVMs

        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    

function Convert-AzALLSAPVMsCollectionManagedDisksToPremium {
    <#
            .SYNOPSIS 
            Convert all disks of ALL VMs  to Premium type.
                    
            .DESCRIPTION
            Convert all disks of ALL VMs  to Premium type.
                    
            .PARAMETER SAPSIDApplicationVMs 
            Colelctions of VMs belonging to SAP apllication layer.

            .PARAMETER SAPSIDDBMSVMs 
            Colelctions of VMs belonging to SAP DBMS layer.
                
            .EXAMPLE         
            $SAPSID = "TS1"
            $SAPVMs = Get-AzSAPApplicationInstances -SAPSID $SAPSID            

            Convert-AzALLSAPVMsCollectionManagedDisksToPremium -SAPVMs $SAPVMs
        
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        $SAPVMs        
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
             
            Write-WithTime "VMs disks:"
            Write-Output ""
            Get-AzVMCollectionManagedDiskType -SAPVMs $SAPVMs

            Write-WithTime "Converting VMs disks to 'Premium_LRS' ..."
            Convert-AzVMCollectionManagedDisksToPremium -SAPVMs $SAPVMs
            Write-Output ""

            Write-WithTime "VMs disks after conversion:"
            Write-Output ""
            Get-AzVMCollectionManagedDiskType -SAPVMs $SAPVMs          

        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    

function Convert-AzALLSAPSystemVMsCollectionManagedDisksToStandard {
    <#
            .SYNOPSIS 
            Convert all disks of ALL SAP SID VMs  to Standard type.
                    
            .DESCRIPTION
            Convert all disks of ALL SAP SID VMs  to Standard type.
                    
            .PARAMETER SAPSIDApplicationVMs 
            Collrctions of VMs belonging to SAP apllication layer.

            .PARAMETER SAPSIDDBMSVMs 
            Colelctions of VMs belonging to SAP DBMS layer.
                
            .EXAMPLE         
            $SAPSID = "TS1"
            $SAPSIDApplicationVMs = Get-AzSAPApplicationInstances -SAPSID $SAPSID
            $SAPSIDDBMSVMs  = Get-AzSAPDBMSInstances -SAPSID $SAPSID

            Convert-AzALLSAPSystemVMsCollectionManagedDisksToStandard -SAPSIDApplicationVMs $SAPSIDApplicationVMs -SAPSIDDBMSVMs $SAPSIDDBMSVMs
        
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        $SAPSIDApplicationVMs,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        $SAPSIDDBMSVMs                
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
             
            Write-WithTime "SAP Application layer VMs disks:"
            Write-Output ""
            Get-AzVMCollectionManagedDiskType -SAPVMs $SAPSIDApplicationVMs

            Write-WithTime "Converting SAP Application layer VMs disks to 'Standard_LRS' ..."
            Convert-AzVMCollectionManagedDisksToStandard -SAPVMs $SAPSIDApplicationVMs
            Write-Output ""

            Write-WithTime "SAP Application layer VMs disks after conversion:"
            Write-Output ""
            Get-AzVMCollectionManagedDiskType -SAPVMs $SAPSIDApplicationVMs


            Write-WithTime "SAP DBMS layer VM(s)disks:"
            Write-Output ""
            Get-AzVMCollectionManagedDiskType -SAPVMs $SAPSIDDBMSVMs

            Write-WithTime "Converting DBMS layer VMs disks to 'Standard_LRS' ..."
            Convert-AzVMCollectionManagedDisksToStandard -SAPVMs $SAPSIDDBMSVMs
            Write-Output ""

            Write-WithTime "SAP DBMS layer VMs disks after conversion:"
            Write-Output ""
            Get-AzVMCollectionManagedDiskType -SAPVMs $SAPSIDDBMSVMs

        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    

function Convert-AzALLSAPVMsCollectionManagedDisksToStandard {
    <#
            .SYNOPSIS 
            Convert all disks of VMs  to Standard type.
                    
            .DESCRIPTION
            Convert all disks of VMs  to Standard type.
                    
            .PARAMETER SAPSIDApplicationVMs 
            Collrctions of VMs belonging to SAP apllication layer.

            .PARAMETER SAPVMs 
            Collections of VMs .
                
            .EXAMPLE         
            $SAPSID = "TS1"
            $SAPSIDApplicationVMs = Get-AzSAPApplicationInstances -SAPSID $SAPSID            

            Convert-AzALLSAPVMsCollectionManagedDisksToStandard -SAPVMs $SAPSIDApplicationVMs 
        
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        $SAPVMs
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
             
            Write-WithTime "VMs disks:"
            Write-Output ""
            Get-AzVMCollectionManagedDiskType -SAPVMs $SAPVMs

            Write-WithTime "Converting  VMs disks to 'Standard_LRS' ..."
            Convert-AzVMCollectionManagedDisksToStandard -SAPVMs $SAPVMs
            Write-Output ""

            Write-WithTime "VMs disks after conversion:"
            Write-Output ""
            Get-AzVMCollectionManagedDiskType -SAPVMs $SAPVMs            

        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    

function New-AzSAPSystemHANATags {
    <#
            .SYNOPSIS 
            Set Tags on Standalone SAP HANA belonging to an SAP SID system.
                    
            .DESCRIPTION
            Set Tags on Standalone SAP HANA belonging to an SAP SID system.
                    
            .PARAMETER ResourceGroupName 
            Resource Group Name of the VM.
    
            .PARAMETER VMName 
            VM name. 

            .PARAMETER SAPSID 
            SAP system SID. 

            .PARAMETER SAPHANASID 
            SAP HANA SID. 

            .PARAMETER SAPHANAINstanceNumber 
            SAP HANA InstanceNumber. 
                
            .EXAMPLE         
           # Set Tags on Standalone HANA belonging to an SAP system
           $ResourceGroupName = "gor-linux-eastus2"
           $VMName = "ts2-db"

           New-AzSAPSystemHANATags -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID "TS1" -SAPHANASID "TS2" -SAPHANAINstanceNumber 0         
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,
        
        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,

        [Parameter(Mandatory = $True, HelpMessage = "SAP HANA <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPHANASID,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [ValidateLength(1, 2)]
        [string] $SAPHANAInstanceNumber
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                                                                               
            $SAPDBMSType = "HANA"
            
            $tags = @{"SAPSystemSID" = $SAPSID; "SAPHANASID" = $SAPHANASID; "SAPHANAINstanceNumber" = $SAPHANAInstanceNumber; "SAPDBMSType" = $SAPDBMSType; }
            
            $resource = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceName $VMName
            #New-AzTag -ResourceId $resource.id -Tag $tags            
            Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Merge
        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    

function New-AzSAPStandaloneHANATags {
    <#
            .SYNOPSIS 
            Set Tags on Standalone SAP HANA.
                    
            .DESCRIPTION
            Set Tags on Standalone SAP HANA.
                    
            .PARAMETER ResourceGroupName 
            Resource Group Name of the VM.
    
            .PARAMETER VMName 
            VM name. 

            .PARAMETER SAPHANASID 
            SAP HANA SID. 

            .PARAMETER SAPHANAINstanceNumber 
            SAP HANA InstanceNumber. 
                
            .EXAMPLE         
           # Set Tags on Standalone HANA belonging to an SAP system
           $ResourceGroupName = "gor-linux-eastus2"
           $VMName = "ts2-db"

           New-AzSAPHANATags -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID "TS1" -SAPHANASID "TS2" -SAPHANAINstanceNumber 0         
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,
            

        [Parameter(Mandatory = $True, HelpMessage = "SAP HANA <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPHANASID,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 2)]     
        [string] $SAPHANAInstanceNumber
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                                                                               
            $SAPDBMSType = "HANA"
            
            $tags = @{"SAPHANASID" = $SAPHANASID; "SAPHANAINstanceNumber" = $SAPHANAInstanceNumber; "SAPDBMSType" = $SAPDBMSType; }
            
            $resource = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceName $VMName
            #New-AzTag -ResourceId $resource.id -Tag $tags            
            Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Merge
        }
        catch {
            Write-Error  $_.Exception.Message
        }                
    }
                
    END {}
}    

function New-AzSAPSystemHANAAndASCSTags {
    <#
            .SYNOPSIS 
            Set Tags on Standalone SAP HANA with SAP 'ASCS' instance.
                    
            .DESCRIPTION
            Set Tags on Standalone SAP HANA with SAP 'ASCS' instance. This is used with SAP Central System where complete system is isntelld on one VM, or distributed system where HANA and ASCS instance are located on the same VM
                    
            .PARAMETER ResourceGroupName 
            Resource Group Name of the VM.
    
            .PARAMETER VMName 
            VM name. 

            .PARAMETER SAPSID 
            SAP system SID. 

            .PARAMETER SAPHANASID 
            SAP HANA SID. 

            .PARAMETER SAPHANAINstanceNumber 
            SAP HANA InstanceNumber. 
                
            .PARAMETER SAPApplicationInstanceNumber 
            SAP ASCS Instance Number. 

            .EXAMPLE         
           # Set Tags on Standalone HANA belonging to an SAP system
           $ResourceGroupName = "gor-linux-eastus2"
           $VMName = "ts2-db"

           New-AzSAPSystemHANATags -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID "TS1" -SAPHANASID "TS2" -SAPHANAINstanceNumber 0  -SAPApplicationInstanceNumber 1      
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,
        
        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,

        [Parameter(Mandatory = $True, HelpMessage = "SAP HANA <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPHANASID,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 2)]      
        [string] $SAPHANAInstanceNumber,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 2)]    
        [string] $SAPApplicationInstanceNumber
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
                                    
            #$DBMSInstance = $true
            $SAPDBMSType = "HANA"            
            $SAPApplicationInstanceType = "SAP_ASCS"
            
            $tags = @{"SAPSystemSID" = $SAPSID; "SAPHANASID" = $SAPHANASID; "SAPHANAINstanceNumber" = $SAPHANAInstanceNumber; "SAPDBMSType" = $SAPDBMSType; "SAPApplicationInstanceType" = $SAPApplicationInstanceType ; "SAPApplicationInstanceNumber" = $SAPApplicationInstanceNumber }
            
            $resource = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceName $VMName
            #New-AzTag -ResourceId $resource.id -Tag $tags
            Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Merge            
        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    

function New-AzSAPSystemASCSLinuxTags {
    <#
            .SYNOPSIS 
            Set Tags on Standalone SAP 'ASCS' instance on Linux.
                    
            .DESCRIPTION
            Set Tags on Standalone SAP 'ASCS' instance on Linux.
                    
            .PARAMETER ResourceGroupName 
            Resource Group Name of the VM.
    
            .PARAMETER VMName 
            VM name. 

            .PARAMETER SAPSID 
            SAP system SID. 
                
            .PARAMETER SAPApplicationInstanceNumber 
            SAP ASCS Instance Number. 

            .EXAMPLE         
           # Set Tags on Standalone HANA belonging to an SAP system
           $ResourceGroupName = "gor-linux-eastus2"
           $VMName = "ts2-db"

           New-AzSAPSystemASCSLinux -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID "TS1" -SAPApplicationInstanceNumber 1      
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,
        
        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,
        
        [Parameter(Mandatory = $True)]
        [ValidateLength(1, 2)]
        [string] $SAPApplicationInstanceNumber
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
                                                         
            $SAPApplicationInstanceType = "SAP_ASCS"
            
            $tags = @{"SAPSystemSID" = $SAPSID; "SAPApplicationInstanceType" = $SAPApplicationInstanceType ; "SAPApplicationInstanceNumber" = $SAPApplicationInstanceNumber }
            
            $resource = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceName $VMName
            #New-AzTag -ResourceId $resource.id -Tag $tags
            Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Merge            
        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    

function New-AzSAPSystemSCSLinuxTags {
    <#
            .SYNOPSIS 
            Set Tags on Standalone SAP 'SCS' instance on Linux.
                    
            .DESCRIPTION
            Set Tags on Standalone SAP 'SCS' instance on Linux.
                    
            .PARAMETER ResourceGroupName 
            Resource Group Name of the VM.
    
            .PARAMETER VMName 
            VM name. 

            .PARAMETER SAPSID 
            SAP system SID. 
                
            .PARAMETER SAPApplicationInstanceNumber 
            SAP ASCS Instance Number. 

            .EXAMPLE         
           # Set Tags on Standalone HANA belonging to an SAP system
           $ResourceGroupName = "gor-linux-eastus2"
           $VMName = "ts2-db"

           New-AzSAPSystemSCSLinux -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID "TS1" -SAPApplicationInstanceNumber 1      
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,
        
        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,
        
        [Parameter(Mandatory = $True)]
        [ValidateLength(1, 2)]
        [string] $SAPApplicationInstanceNumber
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
                                                         
            $SAPApplicationInstanceType = "SAP_SCS"
            
            $tags = @{"SAPSystemSID" = $SAPSID; "SAPApplicationInstanceType" = $SAPApplicationInstanceType ; "SAPApplicationInstanceNumber" = $SAPApplicationInstanceNumber }
            
            $resource = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceName $VMName
            #New-AzTag -ResourceId $resource.id -Tag $tags
            Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Merge            
        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    

function New-AzSAPSystemSAPDVEBMGSLinuxTags {
    <#
            .SYNOPSIS 
            Set Tags on Standalone SAP 'DVEBMGS' instance on Linux.
                    
            .DESCRIPTION
            Set Tags on Standalone SAP 'DVEBMGS' instance on Linux.
                    
            .PARAMETER ResourceGroupName 
            Resource Group Name of the VM.
    
            .PARAMETER VMName 
            VM name. 

            .PARAMETER SAPSID 
            SAP system SID. 
                
            .PARAMETER SAPApplicationInstanceNumber 
            SAP DVEBMGS Instance Number. 

            .EXAMPLE         
           # Set Tags on Standalone HANA belonging to an SAP system
           $ResourceGroupName = "gor-linux-eastus2"
           $VMName = "ts2-db"

           New-AzSAPSystemSAPDVEBMGSLinux -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID "TS1" -SAPApplicationInstanceNumber 1          
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,
        
        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 2)]    
        [string] $SAPApplicationInstanceNumber
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
                                                         
            $SAPApplicationInstanceType = "SAP_DVEBMGS"
            
            $tags = @{"SAPSystemSID" = $SAPSID; "SAPApplicationInstanceType" = $SAPApplicationInstanceType ; "SAPApplicationInstanceNumber" = $SAPApplicationInstanceNumber }
            
            $resource = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceName $VMName
            #New-AzTag -ResourceId $resource.id -Tag $tags
            Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Merge            
        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    

function New-AzSAPSystemSAPDialogInstanceApplicationServerLinuxTags {
    <#
            .SYNOPSIS 
            Set Tags on Standalone SAP Dialog 'D' Instance Application Server instance on Linux.
                    
            .DESCRIPTION
            Set Tags on Standalone SAP Dialog 'D' Instance Application Server instance on Linux.
                    
            .PARAMETER ResourceGroupName 
            Resource Group Name of the VM.
    
            .PARAMETER VMName 
            VM name. 

            .PARAMETER SAPSID 
            SAP system SID. 
                
            .PARAMETER SAPApplicationInstanceNumber 
            SAP SAP Dialog 'D' Instance Application Server Instance Number. 

            .EXAMPLE         
           # Set Tags on Standalone HANA belonging to an SAP system
           $ResourceGroupName = "gor-linux-eastus2"
           $VMName = "ts2-db"

           New-AzSAPSystemSAPDialogInstanceApplicationServerLinux -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID "TS1" -SAPApplicationInstanceNumber 1          
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,
        
        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 2)]
        [string] $SAPApplicationInstanceNumber
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
                                                         
            $SAPApplicationInstanceType = "SAP_D"
            
            $tags = @{"SAPSystemSID" = $SAPSID; "SAPApplicationInstanceType" = $SAPApplicationInstanceType ; "SAPApplicationInstanceNumber" = $SAPApplicationInstanceNumber }
            
            $resource = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceName $VMName
            #New-AzTag -ResourceId $resource.id -Tag $tags
            Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Merge            
        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    

function New-AzSAPSystemSAPJavaApplicationServerInstanceLinuxTags {
    <#
            .SYNOPSIS 
            Set Tags on Standalone SAP Java 'J' Instance Application Server instance on Linux.
                    
            .DESCRIPTION
            Set Tags on Standalone SAP Java 'J' Instance Application Server instance on Linux.
                    
            .PARAMETER ResourceGroupName 
            Resource Group Name of the VM.
    
            .PARAMETER VMName 
            VM name. 

            .PARAMETER SAPSID 
            SAP system SID. 
                
            .PARAMETER SAPApplicationInstanceNumber 
            SAP SAP Dialog 'D' Instance Application Server Instance Number. 

            .EXAMPLE         
           # Set Tags on Standalone HANA belonging to an SAP system
           $ResourceGroupName = "gor-linux-eastus2"
           $VMName = "ts2-db"

           New-AzSAPSystemSAPJavaApplicationServerInstanceLinuxTags -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID "TS1" -SAPApplicationInstanceNumber 1          
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,
        
        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 2)]
        [string] $SAPApplicationInstanceNumber
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
                                                         
            $SAPApplicationInstanceType = "SAP_J"
            
            $tags = @{"SAPSystemSID" = $SAPSID; "SAPApplicationInstanceType" = $SAPApplicationInstanceType ; "SAPApplicationInstanceNumber" = $SAPApplicationInstanceNumber }
            
            $resource = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceName $VMName
            #New-AzTag -ResourceId $resource.id -Tag $tags
            Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Merge            
        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    

function New-AzSAPsidadmUserAutomationCredential {
    <#
            .SYNOPSIS 
           Creates new Azure Automation credentials for SAP <sid>adm user,need on Windows OS.
                    
            .DESCRIPTION
            Creates new Azure Automation credentials for SAP <sid>adm user,need on Windows OS.
                    
            .PARAMETER AutomationAccountResourceGroupName 
            Azure Automation Account Resource Group Name.
    
            .PARAMETER AutomationAccountName 
            Azure Automation Account Name. 

            .PARAMETER SAPSID 
            SAP system SID. 
                
            .PARAMETER SAPsidadmUserPassword 
            SAP <sidadm> user password.

            .EXAMPLE         
           # Set Tags on Standalone HANA belonging to an SAP system
           $ResourceGroupName = "gor-linux-eastus2"           
           New-AzSAPsidadmUserAutomationCredential -AutomationAccountResourceGroupName $ResourceGroupName -AutomationAccountName "MyAzureAutomationAccount" -SAPSID "TS1" -SAPsidadmUserPassword "MyPwd"          
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$AutomationAccountResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $AutomationAccountName,
        
        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $SAPsidadmUserPassword
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
                    
            $User = $SAPSID.Trim().ToLower() + "adm"
            $Password = ConvertTo-SecureString $SAPsidadmUserPassword  -AsPlainText -Force
            $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $Password
            New-AzAutomationCredential -AutomationAccountName $AutomationAccountName  -Name $user  -Value $Credential -ResourceGroupName $AutomationAccountResourceGroupName
            
        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    

function New-AzSAPSystemASCSWindowsTags {
    <#
            .SYNOPSIS 
            Set Tags on Standalone SAP 'ASCS' instance on Windows.
                    
            .DESCRIPTION
            Set Tags on Standalone SAP 'ASCS' instance on Windows.
                    
            .PARAMETER ResourceGroupName 
            Resource Group Name of the VM.
    
            .PARAMETER VMName 
            VM name. 

            .PARAMETER SAPSID 
            SAP system SID. 
                
            .PARAMETER SAPApplicationInstanceNumber 
            SAP ASCS Instance Number. 

            .EXAMPLE         
           # Set Tags on Standalone HANA belonging to an SAP system
           $ResourceGroupName = "gor-linux-eastus2"
           $VMName = "ts2-db"

           New-AzSAPSystemASCSWindowsTags -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID "TS1" -SAPApplicationInstanceNumber 1 -PathToSAPControl "S:\usr\sap\ASCS00\exe\sapcontrol.exe"  -AutomationAccountResourceGroupName "RG-AutomationAccount" -AutomationAccountName "my-sap-autoamtion-account" -SAPsidadmUserPassword "MyPwd374"
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,
        
        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 2)]   
        [string] $SAPApplicationInstanceNumber,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $PathToSAPControl,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$AutomationAccountResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $AutomationAccountName,        
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $SAPsidadmUserPassword
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
                                                         
            $SAPApplicationInstanceType = "SAP_ASCS"            

            # Create VM Tags
            Write-WithTime "Creating '$SAPApplicationInstanceType' Tags on VM '$VMName' in resource group '$ResourceGroupName' ...."
            $tags = @{"SAPSystemSID" = $SAPSID; "SAPApplicationInstanceType" = $SAPApplicationInstanceType ; "SAPApplicationInstanceNumber" = $SAPApplicationInstanceNumber; "PathToSAPControl" = $PathToSAPControl }
            
            $resource = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceName $VMName
            #New-AzTag -ResourceId $resource.id -Tag $tags
            Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Merge

            # Create Credetnials in Azure Automation Secure Area 
            $User = $SAPSID.Trim().ToLower() + "adm"
            Write-WithTime "Creating  credentials in Azure automation account secure area for user '$User' ...."
            New-AzSAPsidadmUserAutomationCredential -AutomationAccountResourceGroupName $AutomationAccountResourceGroupName -AutomationAccountName $AutomationAccountName -SAPSID $SAPSID -SAPsidadmUserPassword $SAPsidadmUserPassword                                  
        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    

function New-AzSAPSystemSCSWindowsTags {
    <#
            .SYNOPSIS 
            Set Tags on Standalone SAP Java 'SCS' instance on Windows.
                    
            .DESCRIPTION
            Set Tags on Standalone SAP Java 'SCS' instance on Windows.
                    
            .PARAMETER ResourceGroupName 
            Resource Group Name of the VM.
    
            .PARAMETER VMName 
            VM name. 

            .PARAMETER SAPSID 
            SAP system SID. 
                
            .PARAMETER SAPApplicationInstanceNumber 
            SAP ASCS Instance Number. 

            .EXAMPLE         
           # Set Tags on Standalone HANA belonging to an SAP system
           $ResourceGroupName = "gor-linux-eastus2"
           $VMName = "ts2-db"
           
           New-AzSAPSystemSCSWindowsTags -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID "TS1" -SAPApplicationInstanceNumber 1 -PathToSAPControl "S:\usr\sap\TS1\SCS01\exe\sapcontrol.exe"  -AutomationAccountResourceGroupName "RG-AutomationAccount" -AutomationAccountName "my-sap-autoamtion-account" -SAPsidadmUserPassword "MyPwd374"   
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,
        
        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 2)]   
        [string] $SAPApplicationInstanceNumber,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $PathToSAPControl,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$AutomationAccountResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $AutomationAccountName,        
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $SAPsidadmUserPassword
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
                                                         
            $SAPApplicationInstanceType = "SAP_SCS"            

            # Create VM Tags
            Write-WithTime "Creating '$SAPApplicationInstanceType' Tags on VM '$VMName' in resource group '$ResourceGroupName' ...."
            $tags = @{"SAPSystemSID" = $SAPSID; "SAPApplicationInstanceType" = $SAPApplicationInstanceType ; "SAPApplicationInstanceNumber" = $SAPApplicationInstanceNumber; "PathToSAPControl" = $PathToSAPControl }
            
            $resource = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceName $VMName
            #New-AzTag -ResourceId $resource.id -Tag $tags
            Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Merge

            # Create Credetnials in Azure Automation Secure Area 
            $User = $SAPSID.Trim().ToLower() + "adm"
            Write-WithTime "Creating  credentials in Azure automation account secure area for user '$User' ...."
            New-AzSAPsidadmUserAutomationCredential -AutomationAccountResourceGroupName $AutomationAccountResourceGroupName -AutomationAccountName $AutomationAccountName -SAPSID $SAPSID -SAPsidadmUserPassword $SAPsidadmUserPassword                                  
        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    
function New-AzSAPSystemDVEBMGSWindowsTags {
    <#
            .SYNOPSIS 
            Set Tags on Standalone SAP 'DVEBMGS' instance on Windows.
                    
            .DESCRIPTION
            Set Tags on Standalone SAP 'DVEBMGS' instance on Windows.
                    
            .PARAMETER ResourceGroupName 
            Resource Group Name of the VM.
    
            .PARAMETER VMName 
            VM name. 

            .PARAMETER SAPSID 
            SAP system SID. 
                
            .PARAMETER SAPApplicationInstanceNumber 
            SAP DVEBMGS Instance Number. 

            .EXAMPLE         
           # Set Tags on Standalone HANA belonging to an SAP system
           $ResourceGroupName = "gor-linux-eastus2"
           $VMName = "ts2-db"

           New-AzSAPSystemDVEBMGSWindows -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID "TS1" -SAPApplicationInstanceNumber 1 -PathToSAPControl "S:\usr\sap\TS1\J01\exe\sapcontrol.exe" -AutomationAccountResourceGroupName "rg-autom-account"  -AutomationAccountName "sap-automat-acc" -SAPsidadmUserPassword "MyPass789j$&"         
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,
        
        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 2)]
        [string] $SAPApplicationInstanceNumber,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $PathToSAPControl,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$AutomationAccountResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $AutomationAccountName,        
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $SAPsidadmUserPassword
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
                                                         
            $SAPApplicationInstanceType = "SAP_DVEBMGS"            

            # Create VM Tags
            Write-WithTime "Creating '$SAPApplicationInstanceType' Tags on VM '$VMName' in resource group '$ResourceGroupName' ...."
            $tags = @{"SAPSystemSID" = $SAPSID; "SAPApplicationInstanceType" = $SAPApplicationInstanceType ; "SAPApplicationInstanceNumber" = $SAPApplicationInstanceNumber; "PathToSAPControl" = $PathToSAPControl }
            
            $resource = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceName $VMName
            #New-AzTag -ResourceId $resource.id -Tag $tags
            Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Merge

            # Create Credetnials in Azure Automation Secure Area 
            $User = $SAPSID.Trim().ToLower() + "adm"
            Write-WithTime "Creating  credentials in Azure automation account secure area for user '$User' ...."
            New-AzSAPsidadmUserAutomationCredential -AutomationAccountResourceGroupName $AutomationAccountResourceGroupName -AutomationAccountName $AutomationAccountName -SAPSID $SAPSID -SAPsidadmUserPassword $SAPsidadmUserPassword          
            
            
        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    


function New-AzSAPSystemSAPDialogInstanceApplicationServerWindowsTags {
    <#
            .SYNOPSIS 
            Set Tags on Standalone Dialog Instance Application Server instance on Windows.
                    
            .DESCRIPTION
            Set Tags on Standalone Dialog Instance Application Server instance on Windows.
                    
            .PARAMETER ResourceGroupName 
            Resource Group Name of the VM.
    
            .PARAMETER VMName 
            VM name. 

            .PARAMETER SAPSID 
            SAP system SID. 
                
            .PARAMETER SAPApplicationInstanceNumber 
            SAP 'D' Dialog Instance Application Server Instance Number. 

            .EXAMPLE         
           # Set Tags on Standalone HANA belonging to an SAP system
           $ResourceGroupName = "gor-eastus2"
           $VMName = "ts2-di0"
            
           New-AzSAPSystemSAPDialogInstanceApplicationServerWindowsTags  -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID "TS1" -SAPApplicationInstanceNumber 1 -PathToSAPControl "S:\usr\sap\TS1\J01\exe\sapcontrol.exe" -AutomationAccountResourceGroupName "rg-autom-account"  -AutomationAccountName "sap-automat-acc" -SAPsidadmUserPassword "MyPass789j$&"    
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,
        
        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 2)]
        [string] $SAPApplicationInstanceNumber,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $PathToSAPControl,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$AutomationAccountResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $AutomationAccountName,        
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $SAPsidadmUserPassword
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
                                                         
            $SAPApplicationInstanceType = "SAP_D"            

            # Create VM Tags
            Write-WithTime "Creating '$SAPApplicationInstanceType' Tags on VM '$VMName' in resource group '$ResourceGroupName' ...."
            $tags = @{"SAPSystemSID" = $SAPSID; "SAPApplicationInstanceType" = $SAPApplicationInstanceType ; "SAPApplicationInstanceNumber" = $SAPApplicationInstanceNumber; "PathToSAPControl" = $PathToSAPControl }
            
            $resource = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceName $VMName
            #New-AzTag -ResourceId $resource.id -Tag $tags
            Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Merge

            # Create Credetnials in Azure Automation Secure Area 
            $User = $SAPSID.Trim().ToLower() + "adm"
            Write-WithTime "Creating  credentials in Azure automation account secure area for user '$User' ...."
            New-AzSAPsidadmUserAutomationCredential -AutomationAccountResourceGroupName $AutomationAccountResourceGroupName -AutomationAccountName $AutomationAccountName -SAPSID $SAPSID -SAPsidadmUserPassword $SAPsidadmUserPassword                                  
        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    

function New-AzSAPSystemSAPJavaApplicationServerInstanceWindowsTags {
    <#
            .SYNOPSIS 
            Set Tags on Standalone JavaApplication Server instance on Windows.
                    
            .DESCRIPTION
            Set Tags on Standalone Java Application Server instance on Windows.
                    
            .PARAMETER ResourceGroupName 
            Resource Group Name of the VM.
    
            .PARAMETER VMName 
            VM name. 

            .PARAMETER SAPSID 
            SAP system SID. 
                
            .PARAMETER SAPApplicationInstanceNumber 
            SAP 'J' Java Application Server Instance Number. 

            .EXAMPLE         
           # Set Tags on Standalone HANA belonging to an SAP system
           $ResourceGroupName = "gor-eastus2"
           $VMName = "ts2-di0"

           New-AzSAPSystemSAPJavaApplicationServerInstanceWindowsTags  -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID "TS1" -SAPApplicationInstanceNumber 1 -PathToSAPControl "S:\usr\sap\AB1\J01\exe\sapcontrol.exe" -AutomationAccountResourceGroupName "rg-autom-account"  -AutomationAccountName "sap-automat-acc" -SAPsidadmUserPassword "MyPass789j$&"
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,
        
        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 2)]
        [string] $SAPApplicationInstanceNumber,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $PathToSAPControl,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$AutomationAccountResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $AutomationAccountName,        
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $SAPsidadmUserPassword
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
                                                         
            $SAPApplicationInstanceType = "SAP_J"            

            # Create VM Tags
            Write-WithTime "Creating '$SAPApplicationInstanceType' Tags on VM '$VMName' in resource group '$ResourceGroupName' ...."
            $tags = @{"SAPSystemSID" = $SAPSID; "SAPApplicationInstanceType" = $SAPApplicationInstanceType ; "SAPApplicationInstanceNumber" = $SAPApplicationInstanceNumber; "PathToSAPControl" = $PathToSAPControl }
            
            $resource = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceName $VMName
            #New-AzTag -ResourceId $resource.id -Tag $tags
            Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Merge

            # Create Credetnials in Azure Automation Secure Area 
            $User = $SAPSID.Trim().ToLower() + "adm"
            Write-WithTime "Creating  credentials in Azure automation account secure area for user '$User' ...."
            New-AzSAPsidadmUserAutomationCredential -AutomationAccountResourceGroupName $AutomationAccountResourceGroupName -AutomationAccountName $AutomationAccountName -SAPSID $SAPSID -SAPsidadmUserPassword $SAPsidadmUserPassword                                  
        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    

function New-AzSAPStandaloneSQLServerTags {
    <#
            .SYNOPSIS 
            Set Tags on Standalone SAP SQL Server.
                    
            .DESCRIPTION
            Set Tags on Standalone SAP SQL Server in distributed SAP installation.
                    
            .PARAMETER ResourceGroupName 
            Resource Group Name of the VM.
    
            .PARAMETER VMName 
            VM name. 

            .PARAMETER SAPSID, 
            SAPSID. 

            .PARAMETER DBInstanceName 
            SQL Server DB Instance Name. Empty string is deafult SQL Server instance. 
                
            .EXAMPLE         
           # Set Tags on Standalone HANA belonging to an SAP system
           $ResourceGroupName = "gor-linux-eastus2"
           $VMName = "ts2-db"

           New-AzSAPStandaloneSQLServerTags -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID "TS1" -DBInstanceName $DBInstanceName 
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,
            
        [Parameter(Mandatory=$True, HelpMessage="SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3,3)]
        [string] $SAPSID,

        [Parameter(Mandatory=$false, HelpMessage="SQL Server DB Instance Name. Empty string is deafult SQL instance name.")] 
        [string] $DBInstanceName = ""
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                                                                               
            $SAPDBMSType = "SQLServer"
            
            $tags = @{"SAPSystemSID" = $SAPSID; "DBInstanceName" = $DBInstanceName; "SAPDBMSType" = $SAPDBMSType; }
            
            $resource = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceName $VMName
            #New-AzTag -ResourceId $resource.id -Tag $tags            
            Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Merge
        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    

function New-AzSAPCentralSystemSQLServerTags {
    <#
            .SYNOPSIS 
            Set Tags on Standalone SAP 'ASCS' instance on Windows.
                    
            .DESCRIPTION
            Set Tags on Standalone SAP 'ASCS' instance on Windows.
                    
            .PARAMETER ResourceGroupName 
            Resource Group Name of the VM.
    
            .PARAMETER VMName 
            VM name. 

            .PARAMETER SAPSID 
            SAP system SID. 
                
            .PARAMETER SAPApplicationInstanceNumber 
            SAP ASCS Instance Number. 

            .PARAMETER DBInstanceName 
            SQL Server DB Instance Name. Empty string is deafult SQL Server instance. 

            .EXAMPLE         
           # Set Tags on Standalone HANA belonging to an SAP system
           $ResourceGroupName = "gor-linux-eastus2"
           $VMName = "ts2-db"

           New-AzSAPCentralSystemSQLServerTags -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID "TS1" -SAPApplicationInstanceNumber 1  -DBInstanceName TS1   
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,
        
        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 2)]   
        [string] $SAPApplicationInstanceNumber,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $PathToSAPControl,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$AutomationAccountResourceGroupName,

        [Parameter(Mandatory=$false, HelpMessage="SQL Server DB Instance Name. Empty string is deafult SQL instance name.")] 
        [string] $DBInstanceName = "",
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $AutomationAccountName,        
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $SAPsidadmUserPassword
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
                                                         
            $SAPApplicationInstanceType = "SAP_ASCS"      
            $SAPDBMSType = "SQLServer"                     

            # Create VM Tags
            Write-WithTime "Creating '$SAPApplicationInstanceType' Tags on VM '$VMName' in resource group '$ResourceGroupName' ...."
            $tags = @{"SAPSystemSID" = $SAPSID; "SAPApplicationInstanceType" = $SAPApplicationInstanceType ; "SAPApplicationInstanceNumber" = $SAPApplicationInstanceNumber; "PathToSAPControl" = $PathToSAPControl ; "DBInstanceName" = $DBInstanceName; "SAPDBMSType" = $SAPDBMSType; }
            
            $resource = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceName $VMName

            #New-AzTag -ResourceId $resource.id -Tag $tags            
            Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Merge

            # Create Credetnials in Azure Automation Secure Area 
            $User = $SAPSID.Trim().ToLower() + "adm"
            Write-WithTime "Creating  credentials in Azure automation account secure area for user '$User' ...."
            New-AzSAPsidadmUserAutomationCredential -AutomationAccountResourceGroupName $AutomationAccountResourceGroupName -AutomationAccountName $AutomationAccountName -SAPSID $SAPSID -SAPsidadmUserPassword $SAPsidadmUserPassword                                  
        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    


function Get-AzAutomationSAPPSCredential {
    <#
            .SYNOPSIS 
            Get Azure Automation Account credential user name and password.
                    
            .DESCRIPTION
            Get Azure Automation Account credential user name and password.
                    
            .PARAMETER CredentialName 
            Credential Name.
    
            .EXAMPLE                
           Get-AzAutomationSAPPSCredential -CredentialName "pr1adm"  
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $CredentialName
      
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
                                                         
            $myCredential = Get-AutomationPSCredential -Name $CredentialName
            $userName = $myCredential.UserName
            $securePassword = $myCredential.Password
            $password = $myCredential.GetNetworkCredential().Password

            write-output "user name: $userName"
            write-output "password : $password"

            $obj = New-Object -TypeName psobject
            

            $obj | add-member  -NotePropertyName "UserName" -NotePropertyValue $userName 
            $obj | add-member  -NotePropertyName "Password" -NotePropertyValue $password
            
            Write-Output $obj
        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    

function Stop-AzSAPApplicationServerLinux {
    <#
        .SYNOPSIS 
        Stop SAP Application server on Linux.
                    
        .DESCRIPTION
        Stop SAP Application server on Linux.
                    
        .PARAMETER ResourceGroupName 
        Resource Group Name of the SAP instance VM.        

        .PARAMETER VMName 
        VM name where SAP instance is installed.             

        .PARAMETER SAPInstanceNumber 
        SAP Instance Number to Connect    

        .PARAMETER SAPSID 
        SAP SID  

        .PARAMETER SoftShutdownTimeInSeconds
        Soft shutdown time for SAP system to stop.

        .EXAMPLE                
        Stop-AzSAPApplicationServerLinux -ResourceGroupName "myRG" -VMName SAPApServerVM -SAPInstanceNumber 0 -SAPSID "TS2" -SoftShutdownTimeInSeconds 180
    #>

    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,        

        [Parameter(Mandatory = $True)]
        [ValidateRange(0, 99)]
        [ValidateLength(1, 2)]
        [string] $SAPInstanceNumber,

        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,

        [Parameter(Mandatory = $False)] 
        [int] $SoftShutdownTimeInSeconds = "300",

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False,

        [switch] $PrintOutputWithWriteHost
    )

    BEGIN {}
    
    PROCESS {
        try {   
            $SAPSidUser = $SAPSID.ToLower() + "adm"            

            # Stop SAP ABAP Application Server

            if ($PrintOutputWithWriteHost) {                
                Write-WithTime_Using_WriteHost "Stopping SAP SID '$SAPSID' application server with instance number '$SAPInstanceNumber' on VM '$VMName' , with application time out $SoftShutdownTimeInSeconds seconds ..."
            }else {                
                Write-WithTime "Stopping SAP SID '$SAPSID' application server with instance number '$SAPInstanceNumber' on VM '$VMName' , with application time out $SoftShutdownTimeInSeconds seconds ..."    
            }
            
            $Command = "su --login $SAPSidUser -c 'sapcontrol -nr $SAPInstanceNumber -function Stop $SoftShutdownTimeInSeconds $SoftShutdownTimeInSeconds'"
            
            if ($PrintExecutionCommand -eq $True) {
                if ($PrintOutputWithWriteHost) {                   
                    Write-WithTime_Using_WriteHost "Executing command '$Command' "
                }else {                    
                    Write-WithTime "Executing command '$Command' "
                }                
            }

            $Command | Out-File "command.txt"

            $ret = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName  -CommandId RunShellScript  -ScriptPath command.txt

            $ret.Value[0].Message

            [int] $SleepTime = $SoftShutdownTimeInSeconds + 60

            if ($PrintOutputWithWriteHost) {                
                Write-WithTime_Using_WriteHost "Waiting  $SoftShutdownTimeInSeconds seconds for SAP application server with SAP SID '$SAPSID' and instance number '$SAPInstanceNumber' to stop  ..."
            }else {                
                Write-WithTime "Waiting  $SoftShutdownTimeInSeconds seconds for SAP application server with SAP SID '$SAPSID' and instance number '$SAPInstanceNumber' to stop  ..."
            }
            
            Start-Sleep $SleepTime

            if ($PrintOutputWithWriteHost) {                
                Write-WithTime_Using_WriteHost "SAP Application server with SAP SID '$SAPSID' and instance number '$SAPInstanceNumber' on VM '$VMName' and Azure resource group '$ResourceGroupName' stopped."
            }else {                
                Write-WithTime "SAP Application server with SAP SID '$SAPSID' and instance number '$SAPInstanceNumber' on VM '$VMName' and Azure resource group '$ResourceGroupName' stopped."
            }
            
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}

function Stop-AzSAPApplicationServerWindows {
    <#
        .SYNOPSIS 
        Stop SAP Application server on Linux.
                    
        .DESCRIPTION
        Stop SAP Application server on Linux.
                    
        .PARAMETER ResourceGroupName 
        Resource Group Name of the SAP instance VM.        

        .PARAMETER VMName 
        VM name where SAP instance is installed.             

        .PARAMETER SAPInstanceNumber 
        SAP Instance Number to Connect    

        .PARAMETER SAPSID 
        SAP SID  

        .PARAMETER SoftShutdownTimeInSeconds
        Soft shutdown time for SAP system to stop.

        .EXAMPLE                
        Stop-AzSAPApplicationServerLinux -ResourceGroupName "myRG" -VMName SAPApServerVM -SAPSID "TS2"  -SAPInstanceNumber 0  -PathToSAPControl "C:\usr\sap\PR2\D00\exe\sapcontrol.exe" -SAPSidPwd "Mypwd36" -SoftShutdownTimeInSeconds 180
    #>

    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,        

        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,

        [Parameter(Mandatory = $True)]
        [ValidateLength(1, 2)] 
        [string] $SAPInstanceNumber,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $SAPSidPwd,    

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $PathToSAPControl,

        [Parameter(Mandatory = $False)] 
        [int] $SoftShutdownTimeInSeconds = "300",

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False,

        [switch] $PrintOutputWithWriteHost
    )

    BEGIN {}
    
    PROCESS {
        try {   
            $SAPSidUser = $SAPSID.ToLower() + "adm"            

            # Stop SAP ABAP Application Server

            if ($PrintOutputWithWriteHost) {                
                Write-WithTime_Using_WriteHost "Stopping SAP SID '$SAPSID' application server with instance number '$SAPInstanceNumber' on VM '$VMName' , with application time out $SoftShutdownTimeInSeconds seconds ..."
            }else {                
                Write-WithTime "Stopping SAP SID '$SAPSID' application server with instance number '$SAPInstanceNumber' on VM '$VMName' , with application time out $SoftShutdownTimeInSeconds seconds ..."
            }            
            
            $Command       = "$PathToSAPControl -nr $SAPInstanceNumber -user $SAPSidUser '$SAPSidPwd' -function Stop $SoftShutdownTimeInSeconds $SoftShutdownTimeInSeconds"
            $CommandToPrint = "$PathToSAPControl -nr $SAPInstanceNumber -user $SAPSidUser '***pwd****' -function Stop $SoftShutdownTimeInSeconds $SoftShutdownTimeInSeconds"

            if ($PrintExecutionCommand -eq $True) {
                if ($PrintOutputWithWriteHost) {                
                    Write-WithTime_Using_WriteHost "Executing command '$CommandToPrint' "
                }else {                
                    Write-WithTime "Executing command '$CommandToPrint' "
                }                
            }

            $Command | Out-File "command.txt"

            $ret = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName  -CommandId RunPowerShellScript -ScriptPath command.txt

            $ret.Value[0].Message

            [int] $SleepTime = $SoftShutdownTimeInSeconds + 60

            if ($PrintOutputWithWriteHost) {                
                Write-WithTime_Using_WriteHost "Waiting  $SoftShutdownTimeInSeconds seconds for SAP application server with SAP SID '$SAPSID' and instance number '$SAPInstanceNumber' to stop  ..."
            }else {                
                Write-WithTime "Waiting  $SoftShutdownTimeInSeconds seconds for SAP application server with SAP SID '$SAPSID' and instance number '$SAPInstanceNumber' to stop  ..."
            }
            
            Start-Sleep $SleepTime

            if ($PrintOutputWithWriteHost) {                
                Write-WithTime_Using_WriteHost "SAP Application server with SAP SID '$SAPSID' and instance number '$SAPInstanceNumber' on VM '$VMName' and Azure resource group '$ResourceGroupName' stopped."
            }else {                
                Write-WithTime "SAP Application server with SAP SID '$SAPSID' and instance number '$SAPInstanceNumber' on VM '$VMName' and Azure resource group '$ResourceGroupName' stopped."
            }            
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}


function Start-AzSAPApplicationServerLinux {
    <#
        .SYNOPSIS 
        Start SAP Application server on Linux.
                    
        .DESCRIPTION
        Start SAP Application server on Linux.
                    
        .PARAMETER ResourceGroupName 
        Resource Group Name of the SAP instance VM.        

        .PARAMETER VMName 
        VM name where SAP instance is installed.             

        .PARAMETER SAPInstanceNumber 
        SAP Instance Number to Connect    

        .PARAMETER SAPSID 
        SAP SID  

        .PARAMETER WaitTime
        WaitTime for SAP application server to start.

        .EXAMPLE                
        Start-AzSAPApplicationServerLinux -ResourceGroupName "myRG" -VMName SAPApServerVM -SAPInstanceNumber 0 -SAPSID "TS2" -WaitTime 180
    #>

    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $True)]
        [ValidateLength(1, 2)]        
        [string] $SAPInstanceNumber,

        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,

        [Parameter(Mandatory = $False)] 
        [int] $WaitTime = "300",

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False
    )

    BEGIN {}
    
    PROCESS {
        try {   
            $SAPSidUser = $SAPSID.ToLower() + "adm"            

            # Stop SAP ABAP Application Server
            Write-WithTime "Starting SAP SID '$SAPSID' application server with instance number '$SAPInstanceNumber' on VM '$VMName' , with wait time $WaitTime seconds ..."

            $Command = "su --login $SAPSidUser -c 'sapcontrol -nr $SAPInstanceNumber -function Start'"            
            
            if ($PrintExecutionCommand -eq $True) {
                Write-WithTime "Executing command '$Command' "
            }

            $Command | Out-File "command.txt"

            $ret = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName  -CommandId RunShellScript  -ScriptPath command.txt

            $ret.Value[0].Message            
            
            Write-WithTime "Waiting $WaitTime seconds for SAP application server with SAP SID '$SAPSID' and instance number '$SAPInstanceNumber' to start  ..."

            Start-Sleep $WaitTime

            Write-WithTime "SAP Application server with SAP SID '$SAPSID' and instance number '$SAPInstanceNumber' on VM '$VMName' and Azure resource group '$ResourceGroupName' started."
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}


function Start-AzSAPApplicationServerWindows {
   <#
        .SYNOPSIS 
        Start SAP Application server on Windows.
                    
        .DESCRIPTION
        Start SAP Application server on  Windows.
                    
        .PARAMETER ResourceGroupName 
        Resource Group Name of the SAP instance VM.        

        .PARAMETER VMName 
        VM name where SAP instance is installed.   
        
        .PARAMETER SAPSID 
        SAP SID 

        .PARAMETER SAPInstanceNumber 
        SAP Instance Number to Connect    

        .PARAMETER SAPSidPwd 
        SAP <sid>adm user password

        .PARAMETER PathToSAPControl 
        Full path to SAP Control executable.        

        .PARAMETER SoftShutdownTimeInSeconds
        Soft shutdown time for SAP system to stop.

        .EXAMPLE                
        Start-AzSAPApplicationServerWindows -ResourceGroupName "myRG" -VMName SAPApServerVM -SAPSID "TS2" -SAPInstanceNumber 0  -PathToSAPControl "C:\usr\sap\PR2\D00\exe\sapcontrol.exe" -SAPSidPwd "Mypwd36" -WaitTime 180
    #>

    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,

        [Parameter(Mandatory = $True)]
        [ValidateLength(1, 2)] 
        [string] $SAPInstanceNumber,        

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $SAPSidPwd,    

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $PathToSAPControl,

        [Parameter(Mandatory = $False)] 
        [int] $WaitTime = "300",

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False
    ) 

    BEGIN {}
    
    PROCESS {
        try {   
            $SAPSidUser = $SAPSID.ToLower() + "adm"            

            # Start SAP ABAP Application Server
            Write-WithTime "Starting SAP SID '$SAPSID' application server with instance number '$SAPInstanceNumber' on VM '$VMName' , with wait time $WaitTime seconds ..."
            
            $Command        = "$PathToSAPControl -nr $SAPInstanceNumber -user $SAPSidUser '$SAPSidPwd' -function Start"
            $CommandToPrint = "$PathToSAPControl -nr $SAPInstanceNumber -user $SAPSidUser '***pwd***' -function Start"
            
            if ($PrintExecutionCommand -eq $True) {
                Write-WithTime "Executing command '$CommandToPrint' "
            }

            $Command | Out-File "command.txt"

            $ret = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName  -CommandId RunPowerShellScript -ScriptPath command.txt

            $ret.Value[0].Message            
            
            Write-WithTime "Waiting $WaitTime seconds for SAP application server with SAP SID '$SAPSID' and instance number '$SAPInstanceNumber' to start  ..."

            Start-Sleep $WaitTime

            Write-WithTime "SAP Application server with SAP SID '$SAPSID' and instance number '$SAPInstanceNumber' on VM '$VMName' and Azure resource group '$ResourceGroupName' started."
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}

function Start-AzSAPApplicationServer {
    <#
    .SYNOPSIS 
    Start SAP application server running on VM.
    
    .DESCRIPTION
    Start SAP application server running on VM.
    
    .PARAMETER ResourceGroupName 
    Azure Resource Group Name    

    .PARAMETER ResourceGroupName 
    Azure VM  Name

    .PARAMETER WaitTime
    Number of seconds to wait for SAP system to start.

    .PARAMETER PrintExecutionCommand 
    If set to $True it will pring the run command. 

    .EXAMPLE     
    Start-AzSAPApplicationServer -ResourceGroupName  "AzResourceGroup"  -VMName "VMname" -WaitTime 60
 #>

    [CmdletBinding()]
    param(       
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,
        
        [Parameter(Mandatory = $False)] 
        [int] $WaitTime = "300",

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False        
    )

    BEGIN {}
    
    PROCESS {
        try {   
            # get SAP server datza from VM Tags            
            $SAPApplicationServerData = Get-AzSAPApplicationInstanceData -ResourceGroupName $ResourceGroupName -VMName $VMName  

            #Write-Host $SAPApplicationServerData

            if ($SAPApplicationServerData.OSType -eq "Linux") {                  
                Start-AzSAPApplicationServerLinux  -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPInstanceNumber $SAPApplicationServerData.SAPApplicationInstanceNumber -SAPSID $SAPApplicationServerData.SAPSID -WaitTime $WaitTime -PrintExecutionCommand $PrintExecutionCommand                            
            }
            elseif ($SAPAPPLicationServerData.OSType -eq "Windows") {                
                Start-AzSAPApplicationServerWindows  -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID $SAPApplicationServerData.SAPSID -SAPInstanceNumber $SAPApplicationServerData.SAPApplicationInstanceNumber  -PathToSAPControl $SAPApplicationServerData.PathToSAPControl -SAPSidPwd  $SAPApplicationServerData.SAPSIDPassword -WaitTime $WaitTime -PrintExecutionCommand $PrintExecutionCommand
            }           
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}

function Stop-AzSAPApplicationServer {
    <#
    .SYNOPSIS 
    Start SAP application server running on VM.
    
    .DESCRIPTION
    Start SAP application server running on VM.
    
    .PARAMETER ResourceGroupName 
    Azure Resource Group Name    

    .PARAMETER ResourceGroupName 
    Azure VM  Name

    .PARAMETER SoftShutdownTimeInSeconds
    Soft shutdown time for SAP system to stop.

    .PARAMETER PrintExecutionCommand 
    If set to $True it will pring the run command. 

    .EXAMPLE     
    Start-AzSAPApplicationServer -ResourceGroupName  "AzResourceGroup"  -VMName "VMname" -WaitTime 60
 #>

    [CmdletBinding()]
    param(       
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,
        
        [Parameter(Mandatory = $False)] 
        [int] $SoftShutdownTimeInSeconds = "300",

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False        
    )

    BEGIN {}
    
    PROCESS {
        try {   
            # get SAP server data from VM Tags            
            $SAPApplicationServerData = Get-AzSAPApplicationInstanceData -ResourceGroupName $ResourceGroupName -VMName $VMName  

            #Write-Host $SAPApplicationServerData

            if ($SAPApplicationServerData.OSType -eq "Linux") {                  
                Stop-AzSAPApplicationServerLinux  -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPInstanceNumber $SAPApplicationServerData.SAPApplicationInstanceNumber -SAPSID $SAPApplicationServerData.SAPSID -SoftShutdownTimeInSeconds $SoftShutdownTimeInSeconds -PrintExecutionCommand $PrintExecutionCommand                            
            }
            elseif ($SAPAPPLicationServerData.OSType -eq "Windows") {                
                Stop-AzSAPApplicationServerWindows  -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID $SAPApplicationServerData.SAPSID -SAPInstanceNumber $SAPApplicationServerData.SAPApplicationInstanceNumber  -PathToSAPControl $SAPApplicationServerData.PathToSAPControl -SAPSidPwd  $SAPApplicationServerData.SAPSIDPassword -SoftShutdownTimeInSeconds $SoftShutdownTimeInSeconds -PrintExecutionCommand $PrintExecutionCommand
            }           
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}


function Confirm-AzResoureceGroupExist {
   <#
    .SYNOPSIS 
    Check if Azure resource Group exists.
    
    .DESCRIPTION
    Check if Azure resource Group exists.
    
    .PARAMETER ResourceGroupName 
    Azure Resource Group Name        

    .EXAMPLE     
    Confirm-AzResoureceGroupExist -ResourceGroupName  "AzResourceGroupName" 
 #>

    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $ResourceGroupName                      
        
    )

    BEGIN {}
    
    PROCESS {
        try {               
            $RG = Get-AzResourceGroup -Name $ResourceGroupName -ErrorVariable -notPresent  -ErrorAction SilentlyContinue

            if ($RG -eq $null) {                
                Write-Error "Azure resource group '$ResourceGroupName' do not exists. Check your input parameter 'RESOURCEGROUPNAME'."   
                exit             
            }
            else {
                Write-WithTime "Azure resource group '$ResourceGroupName' exist."
            }
        }
        catch {
           
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}

function Confirm-AzVMExist {
<#
    .SYNOPSIS 
    Check if Azure VM exists.
    
    .DESCRIPTION
    Check if Azure VM exists.
    
    .PARAMETER ResourceGroupName 
    Azure Resource Group Name        

    .PARAMETER VMName 
    Azure VM Name

    .EXAMPLE     
    Confirm-AzVMExist -ResourceGroupName  "AzResourceGroupName"  -VMName "MyVMName"
 #>
    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName                      
        
    )

    BEGIN {}
    
    PROCESS {
        try {               
            $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName  -ErrorVariable -notPresent -ErrorAction SilentlyContinue

            if ($VM -eq $null) {                
                Write-Error "Azure virtual machine '$VMName' in Azure resource group  '$ResourceGroupName' do not exists. Check your VM name and resource group name input parameter."   
                exit             
            }
            else {
                Write-WithTime "Azure VM '$VMName' in Azure resource group '$ResourceGroupName' exist."
            }
        }
        catch {           
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}

function Get-AzSAPApplicationInstanceData {
    <#
    .SYNOPSIS 
    Get SAP Application Instance Data from tags from one VM.
    
    .DESCRIPTION
    Get SAP Application Instance Data from tags from one VM.
     
    .PARAMETER ResourceGroupName 
    Resource Group Name of the VM.
    
    .PARAMETER VMName 
    VM name. 
        
    .EXAMPLE     
    # Collect SAP VM instances with the same Tag
    $SAPAPPLicationServerData = Get-AzSAPApplicationInstanceData -ResourceGroupName "AzResourceGroup" -VMName "SAPApplicationServerVMName"    
 #>

    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
           
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName
    )

    BEGIN {}
    
    PROCESS {
        try {   
                                  
            $SAPSID = Get-AzVMTagValue -ResourceGroupName $ResourceGroupName -VMName $VMName  -KeyName "SAPSystemSID"  
            if ($SAPSID -eq $null) {
                Throw "Tag 'SAPSystemSID' on VM '$VMName' in Azure resource group $ResourceGroupName not found."
            }            
            #Write-Host "SAPSID = $SAPSID"

            $SAPApplicationInstanceNumber = Get-AzVMTagValue -ResourceGroupName $ResourceGroupName -VMName $VMName  -KeyName "SAPApplicationInstanceNumber"  
            if ($SAPApplicationInstanceNumber -eq $null) {
                Throw "Tag 'SAPApplicationInstanceNumber' on VM '$VMName' in Azure resource group $ResourceGroupName not found."

            }
            #Write-Host "SAPApplicationInstanceNumber = $SAPApplicationInstanceNumber"

            $SAPApplicationInstanceType = Get-AzVMTagValue -ResourceGroupName $ResourceGroupName -VMName $VMName  -KeyName "SAPApplicationInstanceType"  
            if ($SAPApplicationInstanceType -eq $null) {
                Throw "Tag 'SAPApplicationInstanceType' on VM '$VMName' in Azure resource group $ResourceGroupName not found."
            }            
            #Write-Host "SAPApplicationInstanceType = $SAPApplicationInstanceType"

            If (-Not (Test-SAPApplicationInstanceIsApplicationServer $SAPApplicationInstanceType)) {
                Throw "SAP Instance type '$SAPApplicationInstanceType' is not an SAP application server."
            }

            $OSType = Get-AzVMOSType -VMName $VMName -ResourceGroupName $ResourceGroupName

            if ($OSType -eq "Windows") {                                
                $SIDADMUser = $SAPSID.Trim().ToLower() + "adm"
                $SAPSIDCredentials = Get-AzAutomationSAPPSCredential -CredentialName  $SIDADMUser  
                $SAPSIDPassword = $SAPSIDCredentials.Password
                $PathToSAPControl = Get-AzVMTagValue -ResourceGroupName $ResourceGroupName  -VMName $VMName  -KeyName "PathToSAPControl"  
            }

            $obj = New-Object -TypeName psobject

            $obj | add-member  -NotePropertyName "SAPSID"                       -NotePropertyValue $SAPSID  
            $obj | add-member  -NotePropertyName "VMName"                       -NotePropertyValue $VMName  
            $obj | add-member  -NotePropertyName "ResourceGroupName"            -NotePropertyValue $ResourceGroupName  
            $obj | add-member  -NotePropertyName "SAPApplicationInstanceNumber" -NotePropertyValue $SAPApplicationInstanceNumber
            $obj | add-member  -NotePropertyName "SAPInstanceType"              -NotePropertyValue $SAPApplicationInstanceType
            $obj | add-member  -NotePropertyName "OSType"                       -NotePropertyValue $OSType 

            if ($OSType -eq "Windows") {
                $obj | add-member  -NotePropertyName "SAPSIDPassword"           -NotePropertyValue $SAPSIDPassword
                $obj | add-member  -NotePropertyName "PathToSAPControl"         -NotePropertyValue $PathToSAPControl               
            }

            # Return formated object
            Write-Output $obj            
                                
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}
function Test-SAPApplicationInstanceIsApplicationServer {
    <#
    .SYNOPSIS 
    If SAP Application Instance is application server['SAP_D','SAP_DVEBMGS','SAP_J'] , retruns $True. Otherwise return $False.
    
    .DESCRIPTION
   If SAP Application Instance is application server['SAP_D','SAP_DVEBMGS','SAP_J'] , retruns $True. Otherwise return $False.
    
    .PARAMETER SAPApplicationInstanceType 
    SAP ApplicationInstance Type ['SAP_D','SAP_DVEBMGS','SAP_J']  
    
    .EXAMPLE     
   Test-SAPApplicationInstanceIsApplicationServer "SAP_D"
    
 #>

    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$SAPApplicationInstanceType
                
    )

    BEGIN {}
    
    PROCESS {
        try {   
                      
            switch ($SAPApplicationInstanceType) {
                "SAP_D" { return $True }
                "SAP_DVEBMGS" { return $True }
                "SAP_J" { return $True }
                Default { return $False }
            }
            
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}

function Stop-AzVMAndPrintStatus {
    <#
    .SYNOPSIS 
    Stop Azure VM and printa status.
    
    .DESCRIPTION
    Stop Azure VM and printa status.
    
    .PARAMETER ResourceGroupName 
    VM Azure Resource Group Name.    
    
    .PARAMETER VMName 
    VM Name.    
    
    .EXAMPLE 
    Stop-AzVMAndPrintStatus -ResourceGroupName "PR1-RG" -VMName "PR1-DB"
 #>

    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName

        
    )

    BEGIN {}
    
    PROCESS {
        try {   
            
            Write-WithTime "Stopping VM '$VMName' in Azure Resource Group '$ResourceGroupName' ..."
            Stop-AzVM  -ResourceGroupName $ResourceGroupName -Name $VMName -WarningAction "SilentlyContinue" -Force

            $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status
            $VMStatus = $VM.Statuses[1].DisplayStatus
            Write-WithTime "Virtual Machine '$VMName' status: $VMStatus" 
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }
    END {}
}

function Start-AzVMAndPrintStatus {
    <#
    .SYNOPSIS 
    Start Azure VM and printa status.
    
    .DESCRIPTION
    Start Azure VM and printa status.
    
    .PARAMETER ResourceGroupName 
    VM Azure Resource Group Name.    
    
    .PARAMETER VMName 
    VM Name.  
    
    .PARAMETER SleepTimeAfterVMStart 
    Wait time in seconds after VM is started. 
    
    .EXAMPLE 
    # Start VM and wait for 60 seconds [default]
    Start-AzVMAndPrintStatus  -ResourceGroupName "PR1-RG" -VMName "PR1-DB"

    .EXAMPLE 
    # Start VM and do not wait 
    Start-AzVMAndPrintStatus  -ResourceGroupName "PR1-RG" -VMName "PR1-DB" -SleepTimeAfterVMStart 0
 #>

    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,

        [Parameter(Mandatory = $false)]             
        [int] $SleepTimeAfterVMStart = 60

        
    )

    BEGIN {}
    
    PROCESS {
        try {   
             # Start VM
             Write-WithTime "Starting VM '$VMName' in Azure Resource Group '$ResourceGroupName' ..."
             Start-AzVM  -ResourceGroupName $ResourceGroupName -Name $VMName -WarningAction "SilentlyContinue"

             $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status
             $VMStatus = $VM.Statuses[1].DisplayStatus
             #Write-Host ""
             Write-WithTime "Virtual Machine '$VMName' status: $VMStatus"

            # Wait for $SleepTimeAfterVMStart seconds after VM is started
            Start-Sleep $SleepTimeAfterVMStart
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }
    END {}
}

# https://docs.microsoft.com/en-us/azure/load-balancer/quickstart-create-standard-load-balancer-powershell
# https://docs.microsoft.com/en-us/azure/load-balancer/upgrade-basicinternal-standard


Function Move-AzVMToAvailabilitySetAndOrProximityPlacementGroup {
<#
.SYNOPSIS
    Moves a VM into an:

    - Availability Set
    - Proximity Placement Group
    - Availability Set and Proximity Placement Group
    

.DESCRIPTION
    The script deletes the VM and recreates it preserving networking and storage configuration.        

    There is no need to reinstall the operating system.
    
    IMPORTANT: The script does not preserve VM extensions.  
                Also, the script does not spport VMs with public IP addresses.
                Zonal VMs are not supported, because you cannot combine Availability Set and Zone. 
                VM, Availabity Set and VM must be members of the same Azure resource group.
                Proximity Placement Group can be member of some other resource group.
        
    IMPORTANT: SAP context

    You can use the script to:

    - Move SAP Application Servers to new Availability Set 

    - Move SAP Application Servers to new Availability Set and Proximity Placement Group:

        - It can be used in Azure Zones context, where you move SAP Application Server to Zone.
            One group of SAP Application Servers are indirectly part of Zone1 (via AvSet1 and PPGZone1), and other part of  SAP Application Servers are indirectly part of Zone2 (via AvSet2 and PPGZone2).
            First ancor VM (this is DBMS VM) is alreday deplyed in a Zone and same Proximity Placement Group

        - It can be used to move an SAP Application Server from current AvSet1 and PPGZone1 to AvSet2 and PPGZone2, e.g. indirectly from Zone1 to Zone2.
            First ancor VM (this is DBMS VM) is alreday deplyed in a Zone2 and same Proximity Placement Group 2 (PPGZone2).

        - It can be used in non-Zonal context, where group of SAP Application Servers are part of new Av Set and Proximity Placement Group, together with the SAP ASCS and DB VM that are part of one SAP SID.

    - Group all VMs to Proximity Placement Group

.PARAMETER VMResourceGroupName 
Resource Group Name of the VM, and Availability Set.
    
.PARAMETER VirtualMachineName 
Virtual Machine Name. 

.PARAMETER AvailabilitySetName
Availability Set Name.

.PARAMETER PPGResourceGroupName
Resource Group Name of the Proximity Placemen tGroup

.PARAMETER ProximityPlacementGroupName
Proximity PlacementGroup Name

.PARAMETER DoNotCopyTags
Switch paramater. If specified, VM tags will NOT be copied.

.PARAMETER NewVMSize
If NewVMSize is specified , VM will be set to a new VM size. Otherwise, original VM size will be used. 

.PARAMETER KeepSameDiskNames
Keep the original disk names. If not specified, generate new disk names.

.PARAMETER Force
Forces the command to run without asking for user confirmation. 
    
.EXAMPLE
# THis is example that can be used for moving (indirectly via PPG) SAP Application Servers to a desired Azure zone
# Move VM 'VM1' to Azure Availability Set  and Proximity Placement GroupName (PPG)
# Proximity Placement Group must alreday exist
# Availability Set must exist and be associated to Proximity Placement Group
# VM tags will not be copied : swicth parameter -DoNotCopyTags is set

# If Av Set doesn't exist, you can create it like this:
$Location = "eastus"
$AzureAvailabilitySetName = "TargetAvSetZone1"
$ResourceGroupName = "gor-Zone-Migration"
$ProximityPlacementGroupName = "PPGZone1"
$PPGResourceGroupName "MyPPGResourceGroupName"
$PlatformFaultDomainCount = 3
$PlatformUpdateDomainCount = 2

$PPG = Get-AzProximityPlacementGroup -ResourceGroupName $PPGResourceGroupName -Name $ProximityPlacementGroupName
New-AzAvailabilitySet -Location $Location -Name $AzureAvailabilitySetName -ResourceGroupName $ResourceGroupName -PlatformFaultDomainCount $PlatformFaultDomainCount -PlatformUpdateDomainCount $PlatformUpdateDomainCount -ProximityPlacementGroupId $PPG.Id  -Sku Aligned

# Move VM
Move-AzVMToAvailabilitySetAndOrProximityPlacementGroup -VMResourceGroupName "gor-Zone-Migration" -VirtualMachineName "VM1" -AvailabilitySetName "TargetAvSetZone1" -ProximityPlacementGroupName "PPGZone1" -PPGResourceGroupName "MyPPGResourceGroupName" -DoNotCopyTags


.EXAMPLE
# Move VM to Proximity Placement Group
# Proximity Placement Group must alreday exist
# VM will be set to NEW VM size, e.g. not original VM size , because 'NewVMSize' is specified
Move-AzVMToAvailabilitySetAndOrProximityPlacementGroup -ResourceGroupName "gor-Zone-Migration" -VirtualMachineName "VM1" -ProximityPlacementGroupName "PPGZone1" -NewVMSize "Standard_E4s_v3"


.EXAMPLE
# Move VM to Azure Availability Set 
# If Av Set doesn't exist, you can create it like this:

# If Av Set doesn't exist, you can create it like this:
$Location = "westeurope"
$AzureAvailabilitySetName = "sap-app-servers-zone1"
$VMResourceGroupName = "gor-Zone-Migration"

$ProximityPlacementGroupName = "PPGZone1"
$PPGResourceGroupName "MyPPGResourceGroupName"
$PlatformFaultDomainCount = 3
$PlatformUpdateDomainCount = 2

$PPG = Get-AzProximityPlacementGroup -ResourceGroupName $PPGResourceGroupName -Name $ProximityPlacementGroupName
New-AzAvailabilitySet -Location $Location -Name $AzureAvailabilitySetName -ResourceGroupName $VMResourceGroupName -PlatformFaultDomainCount $PlatformFaultDomainCount -PlatformUpdateDomainCount $PlatformUpdateDomainCount -ProximityPlacementGroupId $PPG.Id  -Sku Aligned

    
.EXAMPLE
# Move SAP application server VM to Azure Availability Set and PPG

# If Av Set doesn't exist, you can create it like this:

# If Av Set doesn't exist, you can create it like this:
$Location = "westeurope"
$AzureAvailabilitySetName = "sap-app-servers-zone1"
$VMResourceGroupName = "gor-Zone-Migration"

$ProximityPlacementGroupName = "PPGZone1"
$PPGResourceGroupName "MyPPGResourceGroupName"
$PlatformFaultDomainCount = 3
$PlatformUpdateDomainCount = 2

$PPG = Get-AzProximityPlacementGroup -ResourceGroupName $PPGResourceGroupName -Name $ProximityPlacementGroupName
New-AzAvailabilitySet -Location $Location -Name $AzureAvailabilitySetName -ResourceGroupName $VMResourceGroupName -PlatformFaultDomainCount $PlatformFaultDomainCount -PlatformUpdateDomainCount $PlatformUpdateDomainCount -ProximityPlacementGroupId $PPG.Id  -Sku Aligned


#  Option 1 -  you will be asked for confirmation for stopping VM and removing the VM definitition 
# This will move SAP application server VM to new Availability Set and PPG
$VMName = "sap-as-3"
Move-AzVMToAvailabilitySetAndOrProximityPlacementGroup -VMResourceGroupName  $VMResourceGroupName -VirtualMachineName $VMName  -AvailabilitySetName  $AzureAvailabilitySetName -PPGResourceGroupName $PPGResourceGroupName -ProximityPlacementGroupName $ProximityPlacementGroupName

#  Option 2 -  you will NOT be asked for confirmation for stopping VM and removing the VM definitition 
# This will move SAP application server VM to new Availability Set and PPG        
Move-AzVMToAvailabilitySetAndOrProximityPlacementGroup -VMResourceGroupName  $VMResourceGroupName -VirtualMachineName $VMName  -AvailabilitySetName  $AzureAvailabilitySetName -PPGResourceGroupName $PPGResourceGroupName -ProximityPlacementGroupName $ProximityPlacementGroupName -Force

.LINK
    

.NOTES
    v0.1 - Initial version

#>

#Requires -Modules Az.Compute
#Requires -Version 5.1

    
        [CmdletBinding()]
        param(
            
            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            [string] $VMResourceGroupName,
                  
            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            [string] $VirtualMachineName,
                                   
            [Parameter(Mandatory=$False)]
            [string] $AvailabilitySetName,

            [Parameter(Mandatory=$False)]
            [string] $PPGResourceGroupName,
    
            [Parameter(Mandatory=$False)]
            [string] $ProximityPlacementGroupName,
    
            [switch] $DoNotCopyTags,

            [Parameter(Mandatory=$False)]
            [string] $NewVMSize,

            [switch] $KeepSameDiskNames,

            [switch] $Force
        )
    
        BEGIN{
            $AvailabilitySetExist = $False
            $ProximityPlacementGroupExist = $False    
        }
        
        PROCESS{
            try{                                             

               if(($AvailabilitySetName -eq "") -and ($ProximityPlacementGroupName -eq "")){
                    Write-Error "Availability Set Name and Proximity Placement Group Name are not specified. You need to specify at least one of the parameters." 
                    return
                }
    
                # Proximity Placement Group must exist
                if (($ProximityPlacementGroupName -ne "") -and ($PPGResourceGroupName -ne "")){           
                    $ppg = Get-AzProximityPlacementGroup -ResourceGroupName $PPGResourceGroupName -Name $ProximityPlacementGroupName -ErrorAction Stop

                    $ProximityPlacementGroupExist = $True

                    Write-Host
                    Write-WithTime_Using_WriteHost "Proximity Placement Group '$ProximityPlacementGroupName' in resource group '$PPGResourceGroupName' exist."
                }else{
                    if (($ProximityPlacementGroupName -ne "") -and ($PPGResourceGroupName -eq "")) {
                        Write-Host
                        Throw "Only '-ProximityPlacementGroupName' PowerShell parameter is specified. Please specify also parameter '-PPGResourceGroupName'." 
                    }elseif (($ProximityPlacementGroupName -eq "") -and ($PPGResourceGroupName -ne "")) {
                        Write-Host
                        Throw "Only '-PPGResourceGroupName' PowerShell parameter is specified. Please specify also parameter '-ProximityPlacementGroupName'." 
                    }else{
                        Write-Host
                        Write-WithTime_Using_WriteHost "Proximity Placement Group is not specified."
                    }                    
                }

                # Availabity Set Must exist
                if ($AvailabilitySetName -ne ""){           
                    $AvailabilitySet = Get-AzAvailabilitySet -ResourceGroupName $VMResourceGroupName -Name $AvailabilitySetName -ErrorAction Stop
                    $AvailabilitySetExist = $True    
                    
                    Write-Host
                    Write-WithTime_Using_WriteHost "Availability Set '$AvailabilitySetName' in Azure resource group '$VMResourceGroupName' exist."           

                    # Check if Av Set is in the proper PPG
                    if($ProximityPlacementGroupExist){
                        if($AvailabilitySet.ProximityPlacementGroup.id -ne $ppg.Id){           
                            Write-Host         
                            Throw "Existing Availability Set '$AvailabilitySetName' is not member of Proximity Placement Group '$ProximityPlacementGroupName'. Please configure Availability Set '$AvailabilitySetName' (go to 'Configuration' tab of '$AvailabilitySetName') to use Proximity Placement Group '$ProximityPlacementGroupName'. "                    
                        }
                        Write-Host
                        Write-WithTime_Using_WriteHost "Availability Set '$AvailabilitySetName' is configured in appropriate Proximity Placement Group '$ProximityPlacementGroupName'."
                    }
                }else{                    
                    Write-Host
                    Write-WithTime_Using_WriteHost "Availability Set is not specified."                                        
                }                            
                
                Write-Host
                Write-WithTime_Using_WriteHost  "Starting Virtual Machine '$VirtualMachineName' ..."
                $StartVMStatus = Start-AzVM -ResourceGroupName $VMResourceGroupName -Name $VirtualMachineName -ErrorAction Stop 
                
                # Get the VM and check existance
                Write-Host
                Write-WithTime_Using_WriteHost  "Getting Virtual Machine '$VirtualMachineName' configuration ..."
                $originalVM = Get-AzVM -ResourceGroupName $VMResourceGroupName -Name $VirtualMachineName -ErrorAction Stop           
                
                [string] $osType      = $originalVM.StorageProfile.OsDisk.OsType
                [string] $location    = $originalVM.Location
                [string] $storageType = $originalVM.StorageProfile.OsDisk.ManagedDisk.StorageAccountType
                [string] $OSDiskName  = $originalVM.StorageProfile.OsDisk.Name                                
                # when non-Zonal disk / VM this value is an empty string
                [string] $VMDiskZone  = $originalVM.Zones   

                $IsVMZonal = Test-AzVMIsZonalVM -ResourceGroupName $VMResourceGroupName -VirtualMachineName $VirtualMachineName
                
                # Do not delete OS and Data disks during the VM deletion - set DeleteOption to 'Detach'
                Set-AzVMDisksDeleteOption -VM $originalVM -DeleteOption "Detach"                                
    
                # Do not delete NIC cards during the VM deletion - Set NIC Cards to 'Detach'
                Set-AzVMNICsDeleteOption -VM $originalVM -DeleteOption "Detach"                
                
                # Shutdown the original VM
                $ToStop = $true

                if(-not $Force){
                    Write-Host
                    $ToStop = Get-AzVMStopAnswer -VirtualMachineName $VirtualMachineName -ResourceGroupName $VMResourceGroupName
                }                                        

                if($ToStop){
                    Write-Host
                    Write-WithTime_Using_WriteHost  "Stopping Virtual Machine '$VirtualMachineName' in resource group '$VMResourceGroupName' ..."
                    $ReturnStopVM =  Stop-AzVM -ResourceGroupName $VMResourceGroupName -Name $VirtualMachineName -force -ErrorAction Stop 

                    Write-WithTime_Using_WriteHost  "Stopping Virtual Machine '$VirtualMachineName' in resource group '$VMResourceGroupName' stoped."
                }elseif (!$ToStop) {                    
                    Return                 
                }                 
                    
                # Get the VM size
                $OriginalVMSize =  $originalVM.HardwareProfile.VmSize
                if($NewVMSize -eq ""){
                    # if $NewVMSIze is not specified, use the orgonal VM size
                    Write-Host
                    Write-WithTime_Using_WriteHost "VM type is '$OriginalVMSize'."

                    $VMSize = $OriginalVMSize
                }
                else{
                    # if $NewVMSIze is  specified, use it as VM size                      
                    Write-Host
                    Write-WithTime_Using_WriteHost "Changing VM type from original '$OriginalVMSize' to new type '$NewVMSize' ..."

                    $VMSize = $NewVMSize
                }               
                
                # Export original VM configuration
                Write-Host
                Export-VMConfigurationToJSONFile -VM  $originalVM                          
                
                # We don't support moving machines with public IPs, since those are zone specific.  
                foreach ($nic in $originalVM.NetworkProfile.NetworkInterfaces) {
                    $thenic = $nic.id
                    $nicname = $thenic.substring($thenic.LastIndexOf("/")+1)
                    $othernic = Get-AzNetworkInterface -name $nicname -ResourceGroupName $VMResourceGroupName 
        
                    foreach ($ipc in $othernic.IpConfigurations) {
                        $pip = $ipc.PublicIpAddress
                        if ($pip) { 
                            Throw  "Sorry, machines with public IPs are not supported by this script"                             
                        }
                    }
                }                        

                #  Create the basic configuration for the replacement VM with PPG +  Av Set           
                if(($AvailabilitySetExist) -and ($ProximityPlacementGroupExist)){
                    Write-Host
                    Write-WithTime_Using_WriteHost "Configuring Virtual Machine to use Availability Set '$AvailabilitySetName' and Proximity Placement Group '$ProximityPlacementGroupName' ..."
                    $newVM = New-AzVMConfig -VMName $VirtualMachineName -VMSize $VMSize -AvailabilitySetId $AvailabilitySet.Id -ProximityPlacementGroupId $ppg.Id 
                }elseif($AvailabilitySetExist){
                    Write-Host
                    Write-WithTime_Using_WriteHost "Configuring Virtual Machine to use Availability Set '$AvailabilitySetName'  ..."
                    $newVM = New-AzVMConfig -VMName $VirtualMachineName -VMSize $VMSize -AvailabilitySetId $AvailabilitySet.Id 
                }elseif($ProximityPlacementGroupExist){
                    Write-Host
                    "Configuring Virtual Machine to use Proximity Placement Group '$ProximityPlacementGroupName' ..."
                    $newVM = New-AzVMConfig -VMName $VirtualMachineName -VMSize $VMSize -ProximityPlacementGroupId $ppg.Id 
                }             
                

               if($IsVMZonal){
                    # VM IS ZONAL VM
                    # move ZONAL VM to Non Zonal                                        
                    # Snapshot all of the OS and Data disks, create NEW non-zonal disk from snapshot, and add to the VM
                    
                    Write-Host
                    Write-WithTime_Using_WriteHost  "Virtual machine  '$VirtualMachineName' in resource group '$VMResourceGroupName' is ZONAL VM."
                    
                    # smap and copy OS disk
                    if($KeepSameDiskNames){
                        #  Snap and copy the os disk               
                        $snapshot = New-AzUniqueNameSnapshot -ResourceGroupName $VMResourceGroupName -Location $location -DiskName $originalVM.StorageProfile.OsDisk.Name -SourceDiskResourceId $originalVM.StorageProfile.OsDisk.ManagedDisk.Id

                        # Create / Copy the exsiting OS Disk with new name as non-zonal disk
                        Copy-AzUniqueNameDiskFromSnapshot -ResourceGroupName $VMResourceGroupName -Location $location -Snapshot $snapshot -OriginalDiskName $OSDiskName -StorageType $storageType -VMDiskZone $VMDiskZone -DiskNamePosfix "orig"  
                    }                    
                    
                    # Remove the original VM -this is a prerequisit to delete orignial OS and data disks
                    $ToDelete = $true
    
                    if(-not $Force){
                        Write-Host
                        $ToDelete = Get-AzVMDeleteAnswer -VirtualMachineName $VirtualMachineName -ResourceGroupName $VMResourceGroupName
                    }
                    
                    if($ToDelete){
                        Write-Host
                        Write-WithTime_Using_WriteHost  "Removing Virtual Machine '$VirtualMachineName' ..." -AppendEmptyLine                        
                        Remove-AzVM -ResourceGroupName $VMResourceGroupName -Name $VirtualMachineName -force            
                    }else {
                        # Exit
                        Return   
                    }                                                      

                    if($KeepSameDiskNames){
                        # Delete Original OS Disk                
                        Write-WithTime_Using_WriteHost  "Removing original OS disk '$osdiskname' ..." -AppendEmptyLine
                        Remove-AzDisk -ResourceGroupName $VMResourceGroupName -DiskName  $osdiskname -Force  

                        # new OS disk is non-zonal
                        $newdiskConfig = New-AzDiskConfig -AccountType $storageType -Location $location -CreateOption Copy -SourceResourceId $snapshot.Id # -zone $AzureZone    
                        $newdiskName = $osdiskname 
                    
                        Write-WithTime_Using_WriteHost  "Creating OS disk '$newdiskName' from snapshot '$($snapshot.Name)' ..." -AppendEmptyLine
                        $newdisk = New-AzDisk -Disk $newdiskConfig -ResourceGroupName $VMResourceGroupName -DiskName $newdiskName 


                    }else{
                         #  Snap and copy the os disk
                        $snapshotcfg =  New-AzSnapshotConfig -Location $location -CreateOption copy -SourceResourceId $originalVM.StorageProfile.OsDisk.ManagedDisk.Id
                        $osdiskname = $originalVM.StorageProfile.OsDisk.Name
                        $snapshotName = $osdiskname + "-snap"
                    
                        Write-Host
                        Write-WithTime_Using_WriteHost  "Creating OS disk snapshot '$snapshotName' ..."
                        $snapshot = New-AzSnapshot -Snapshot $snapshotcfg -SnapshotName $snapshotName -ResourceGroupName $VMResourceGroupName
                        $newdiskConfig = New-AzDiskConfig -AccountType $storageType -Location $location -CreateOption Copy -SourceResourceId $snapshot.Id #-zone $AzureZone
                        
                        $newdiskName = $osdiskname + "-new" #+ $AzureZone
                        Write-Host
                        Write-WithTime_Using_WriteHost  "Creating regional OS disk '$newdiskName' from snapshot '$snapshotName' ..."
                        $newdisk = New-AzDisk -Disk $newdiskConfig -ResourceGroupName $VMResourceGroupName -DiskName $newdiskName
                    }

                   
            
                    # Configure new REGIONAL OS Disk
                    if ($osType -eq "Linux")
                    {   
                        Write-Host
                        Write-WithTime_Using_WriteHost "Configuring Linux OS disk '$newdiskName' for Virtual Machine '$VirtualMachineName'... "  
                        Set-AzVMOSDisk -VM $newVM -CreateOption Attach  -ManagedDiskId $newdisk.Id -Name $newdisk.Name  -Linux -Caching $originalVM.StorageProfile.OsDisk.Caching > $null
                    }
                    if ($osType -eq "Windows")
                    {
                            Write-Host
                            Write-WithTime_Using_WriteHost "Configuring Windows OS disk '$newdiskName' Virtual Machine '$VirtualMachineName' ... " 
                            Set-AzVMOSDisk -VM $newVM -CreateOption Attach  -ManagedDiskId $newdisk.Id -Name $newdisk.Name  -Windows -Caching $originalVM.StorageProfile.OsDisk.Caching > $null	
                    }

                    # Configure Data Disks

                    if($KeepSameDiskNames){
                        # keep the same disk names
                         # Snapshot all of the Data disks, and add to the VM
                         foreach ($disk in $originalVM.StorageProfile.DataDisks){
                                    
                            $OriginalDataDiskName = $disk.Name

                            #snapshot & copy the data disk
                            $snapshot = New-AzUniqueNameSnapshot -ResourceGroupName $VMResourceGroupName -Location $location -DiskName  $disk.Name -SourceDiskResourceId $disk.ManagedDisk.Id                                                               
                        
                            $diskName = $disk.Name

                            # Create / Copy the exsiting Data disk with a new name
                            Copy-AzUniqueNameDiskFromSnapshot -ResourceGroupName $VMResourceGroupName -Location $location -Snapshot $snapshot -OriginalDiskName $OriginalDataDiskName -StorageType $storageType -VMDiskZone $VMDiskZone -DiskNamePosfix "orig"

                            # Delete Original Data disk
                            Write-Host
                            Write-WithTime_Using_WriteHost  "Removing original data disk '$OriginalDataDiskName' ..." 
                            Remove-AzDisk -ResourceGroupName $VMResourceGroupName -DiskName  $OriginalDataDiskName -Force 
                                                                            
                            $diskConfig = New-AzDiskConfig -AccountType $storageType -Location $location -CreateOption Copy -SourceResourceId $snapshot.Id #-zone $AzureZone
                            Write-Host 
                            Write-WithTime_Using_WriteHost  "Creating data disk '$diskName' from snapshot '$($snapshot.Name)' ..." -AppendEmptyLine
                            
                            $newdisk = New-AzDisk -Disk $diskConfig -ResourceGroupName $VMResourceGroupName -DiskName $diskName # > $null
                            
                            Write-WithTime_Using_WriteHost "Configuring data disk '$($newdisk.Name)' , LUN '$($disk.Lun)' for Virtual Machine '$VirtualMachineName' ... " 
        
                            if($disk.WriteAcceleratorEnabled) {
                                
                                Write-WithTime_Using_WriteHost "Adding disk '$($newdisk.Name)' to new VM with enabled Write Accelerator ...  " -AppendEmptyLine
                                Add-AzVMDataDisk -VM $newVM -Name $newdisk.Name -ManagedDiskId $newdisk.Id -Caching $disk.Caching -Lun $disk.Lun -DiskSizeInGB $newdisk.DiskSizeGB -CreateOption Attach -WriteAccelerator  > $null	
                            }else{
                                
                                Write-WithTime_Using_WriteHost "Adding disk '$($newdisk.Name)' to new VM ...  " -AppendEmptyLine
                                Add-AzVMDataDisk -VM $newVM -Name $newdisk.Name -ManagedDiskId $newdisk.Id -Caching $disk.Caching -Lun $disk.Lun -DiskSizeInGB $newdisk.DiskSizeGB -CreateOption Attach > $null	
                            }
                        }                       
                    }else{
                        # Generate new disk name with "*-new" pattern
                        foreach ($disk in $originalVM.StorageProfile.DataDisks)
                        {
                            #snapshot & copy the data disk
                            $snapshotcfg =  New-AzSnapshotConfig -Location $location -CreateOption copy -SourceResourceId $disk.ManagedDisk.Id
                            $snapshotName = $disk.Name + "-snap"		
                            Write-Host
                            Write-WithTime_Using_WriteHost  "Creating data disk snapshot '$snapshotName' ..."      
                            $snapshot = New-AzSnapshot -Snapshot $snapshotcfg -SnapshotName $snapshotName -ResourceGroupName $VMResourceGroupName
        
                            #[string] $thisdiskStorageType = $disk.StorageAccountType
                            $diskName = $disk.Name + "-new" #+ $AzureZone
                            $diskConfig = New-AzDiskConfig -AccountType $storageType -Location $location -CreateOption Copy -SourceResourceId $snapshot.Id #-zone $AzureZone
                            Write-Host 
                            Write-WithTime_Using_WriteHost  "Creating regional data disk '$diskName' from snapshot '$snapshotName' ..."
                            Write-Host 
                            $newdisk = New-AzDisk -Disk $diskConfig -ResourceGroupName $VMResourceGroupName -DiskName $diskName # > $null
                            
                            Write-WithTime_Using_WriteHost "Configuring data disk '$($newdisk.Name)' , LUN '$($disk.Lun)' for Virtual Machine '$VirtualMachineName' ... " 
        
                            if($disk.WriteAcceleratorEnabled) {
                                Write-Host 
                                Write-WithTime_Using_WriteHost "Adding disk '$($newdisk.Name)' to new VM with enabled Write Accelerator ...  "
                                Add-AzVMDataDisk -VM $newVM -Name $newdisk.Name -ManagedDiskId $newdisk.Id -Caching $disk.Caching -Lun $disk.Lun -DiskSizeInGB $newdisk.DiskSizeGB -CreateOption Attach -WriteAccelerator  > $null	
                            }else{
                                Write-Host 
                                Write-WithTime_Using_WriteHost "Adding disk '$($newdisk.Name)' to new VM ...  "
                                Add-AzVMDataDisk -VM $newVM -Name $newdisk.Name -ManagedDiskId $newdisk.Id -Caching $disk.Caching -Lun $disk.Lun -DiskSizeInGB $newdisk.DiskSizeGB -CreateOption Attach > $null	
                            }
                        }                
                    }

                        
               }else{
                    # VM is NON Zonal               
                    Write-Host
                    Write-WithTime_Using_WriteHost  "Virtual machine  '$VirtualMachineName' in resource group '$VMResourceGroupName' is NON-ZONAL regional VM."                    

                    # Attach EXISTING disks                                       
                    if ($osType -eq "Linux")
                    {   Write-Host
                        Write-WithTime_Using_WriteHost "Configuring Linux OS disk '$OSDiskName' .. "                
                        Set-AzVMOSDisk  -VM $newVM -CreateOption Attach -ManagedDiskId $originalVM.StorageProfile.OsDisk.ManagedDisk.Id -Name $OSDiskName -Linux -Caching $originalVM.StorageProfile.OsDisk.Caching > $null
                
                    }elseif ($osType -eq "Windows")
                    {   Write-Host
                        Write-WithTime_Using_WriteHost "Configuring Windows OS disk '$OSDiskName' .. " 
                        Set-AzVMOSDisk  -VM $newVM -CreateOption Attach -ManagedDiskId $originalVM.StorageProfile.OsDisk.ManagedDisk.Id -Name $OSDiskName -Windows -Caching $originalVM.StorageProfile.OsDisk.Caching	> $null	
                    }
        
                    # Add Data Disks
                    foreach ($disk in $originalVM.StorageProfile.DataDisks) { 
                        Write-Host
                        Write-WithTime_Using_WriteHost "Adding data disk '$($disk.Name)'  to Virtual Machine '$VirtualMachineName'  ..."
                        Add-AzVMDataDisk -VM $newVM -Name $disk.Name -ManagedDiskId $disk.ManagedDisk.Id -Caching $disk.Caching -Lun $disk.Lun -DiskSizeInGB $disk.DiskSizeGB -CreateOption Attach > $null
                    }                            
               }                                                    
    
                # Add NIC(s) and keep the same NIC as primary
                foreach ($nic in $originalVM.NetworkProfile.NetworkInterfaces) {	              
                    Write-Host
                    Write-WithTime_Using_WriteHost "Adding '$($nic.Id)' network card to Virtual Machine '$VirtualMachineName'  ..."
                    if ($nic.Primary -eq "True"){                
                    Add-AzVMNetworkInterface -VM $newVM -Id $nic.Id -Primary > $null
                        }
                        else{                
                        Add-AzVMNetworkInterface -VM $newVM -Id $nic.Id > $null
                    }
                }
                    
                if(-not $DoNotCopyTags){                    
                    # Copy the VM Tags
                    Write-Host
                    Write-WithTime_Using_WriteHost "Copy Tags ..."
                    $newVM.Tags = $originalVM.Tags
                    Write-Host
                    Write-WithTime_Using_WriteHost "Tags copy to new VM definition done. "
        
                }else{
                    Write-Host
                    Write-Host "Skipping copy of VM tags:"                            
                }
            
                # Configuring Boot Diagnostics
                if ($originalVM.DiagnosticsProfile.BootDiagnostics.Enabled) {
        
                    Write-Host
                    Write-WithTime_Using_WriteHost "Boot diagnostic account is enabled."
                    
                    # Get Strage URI
                    $StorageUri = $originalVM.DiagnosticsProfile.BootDiagnostics.StorageUri 
                    
                    if ($StorageUri -eq $null) {
        
                        Write-WithTime_Using_WriteHost "Boot diagnostic URI is empty." -PrependEmptyLine -AppendEmptyLine
                                
                        Write-WithTime_Using_WriteHost "Configuring boot diganostic with managed storage account ..."  -AppendEmptyLine            

                        $newVM = Set-AzVMBootDiagnostic -VM $newVM -Enable                      
        
                    }else {
                        
                        $BootDiagnosticURI = $originalVM.DiagnosticsProfile.BootDiagnostics.StorageUri.Split("/")[2]
                        Write-Host
                        Write-WithTime_Using_WriteHost "Boot diagnostic URI: '$BootDiagnosticURI'."
            
                        $staccName = $BootDiagnosticURI.Split(".")[0]
                        Write-Host
                        Write-WithTime_Using_WriteHost "Extracted storage account name: '$staccName'"
            
                        Write-Host
                        Write-WithTime_Using_WriteHost "Getting storage account '$staccName'"
                        $stacc = Get-AzStorageAccount | where-object { $_.StorageAccountName.Contains($staccName) }
                        
                        if($stacc  -eq $null ){
                            Write-WithTime_Using_WriteHost "Storage account '$staccName' used for diagonstic account on source VM do not exist." -PrependEmptyLine -AppendEmptyLine
                                
                            Write-WithTime_Using_WriteHost "Configuring boot diganostic with managed storage account ..."  -AppendEmptyLine            

                            $newVM = Set-AzVMBootDiagnostic -VM $newVM -Enable       
                        
                        }else{
        
                            Write-Host
                            Write-WithTime_Using_WriteHost "Configuring storage account '$staccName' for VM boot diagnostigs in Azure resource group '$($stacc.ResourceGroupName)' on the new VM ..."
                        
                            $newVM = Set-AzVMBootDiagnostic -VM $newVM -Enable -ResourceGroupName $stacc.ResourceGroupName -StorageAccountName $staccName
        
                            Write-Host
                            Write-WithTime_Using_WriteHost "Configuring storage account '$staccName' for VM boot diagnostigs done."    
                        }                        
                    }                    
            }
    
            if(-not $IsVMZonal){
                # Remove the original VM
                $ToDelete = $true

                if(-not $Force){
                    Write-Host
                    $ToDelete = Get-AzVMDeleteAnswer -VirtualMachineName $VirtualMachineName -ResourceGroupName $VMResourceGroupName
                }
                
                if($ToDelete){
                    Write-Host
                    Write-WithTime_Using_WriteHost  "Removing Virtual Machine '$VirtualMachineName' definition ..."
                    Write-Host
                    Remove-AzVM -ResourceGroupName $VMResourceGroupName -Name $VirtualMachineName -force            
                }else {                
                    # Exit                
                    Return                   
                }
            }            
    
            Write-Host
            if($IsVMZonal){
                Write-WithTime_Using_WriteHost "Original VM was a ZONAL VM. Recreating Virtual Machine '$VirtualMachineName' in resource group '$VMResourceGroupName' as regional VM ..."
            }else{
                Write-WithTime_Using_WriteHost "Recreating Virtual Machine '$VirtualMachineName' in resource group '$VMResourceGroupName' ..."
            }
            
            # recreate the VM
            New-AzVM -ResourceGroupName $VMResourceGroupName -Location $originalVM.Location -VM $newVM -DisableBginfoExtension 
        
            Write-WithTime_Using_WriteHost "Done!"
            
            }
            catch{
               Write-Error  $_.Exception.Message           
           }
        }
    
        END {}
    }
    
    function Export-VMConfigurationToJSONFile {
        [CmdletBinding()]
        param(
            
            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            $VM                            
        )
    
        BEGIN{}
        
        PROCESS{
            try{   
               
               $VMName = $VM.Name
               $FileName = "$VMName.json"
    
               $VM | ConvertTo-Json -depth 100 | Out-File $FileName
    
               Write-WithTime_Using_WriteHost "Virtual Machine '$VMName' configuration is exported to file '$FileName' "
    
            }
            catch{
               Write-Error  $_.Exception.Message -ErrorAction Stop 
           }
    
        }
    
        END {}
    }
    
    Function Prepare-AZNicForZonal {
    <#
    .SYNOPSIS
        Prepares a Network Interface Card Public IP addresses for zonal move of a VM
    
    .DESCRIPTION
        The script scans for Public IP addresses and validates the configuration of these. Zonal IP addresses need to be of a Standard SKU type with zones specified. Zones cannot be updated and if
        the requested zone is not on a Public IP Address a new Public IP Address object will be created. DNS FQDN will be copied to the new Public IP address and if not supressed resource tags will also be copied
        The new Pblic IP Address will have this naming convention: <OriginalName>z
        
        IMPORTANT: The new Public IP Address will have a new address. If you have Firewall rules based on IP they will need to be changed.
           
    .PARAMETER NICID 
    The ResourceID of the NIC
        
    .PARAMETER AzureZone
    Azure Zone number.
    
    .PARAMETER DoNotCopyTags
    Switch paramater. If specified, VM tags will NOT be copied.

    .EXAMPLE
        # Prepare NIC <resource ID> for zone 2
        Prepare-AZNicForZonal -AzureZone 3 -NICid /subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxx/resourceGroups/Migration/providers/Microsoft.Network/networkInterfaces/Interface1
        
    .LINK
        
    .NOTES
        v0.1 - Initial version
    
    #>
    #Requires -Modules Az.Network
    
    
    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]        
        [string] $NICID,
              
        [Parameter(Mandatory=$True)]
        [string] $AzureZone,

        [switch] $DoNotCopyTags=$False
    )

    Set-Item -Path Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value $true
    $NICObject=Get-AzNetworkInterface -ResourceId $NICID
    $nicname=$NICObject.Name
    $NICResourceGroupName=$NICObject.ResourceGroupName
    write-host ""
    Write-WithTime_Using_WriteHost "Found Network Card '$nicname' in Azure resource group '$NICResourceGroupName'."
    #Each NIC can have multiple IP Address configurations - we need to scan all of them
    #[array]$IPConfigurations=$NICObject.IpConfigurations.publicIPAddress.id
    
    for ($s=1;$s -le $NICObject.IpConfigurations.publicIPAddress.id.count ; $s++ ){
        $ChangedNICConfig=$false
        
        $IPObject=Get-AzResource -ResourceId $NICObject.IpConfigurations[$s-1].publicIPAddress.id
        $IpAddressConfig=Get-AzPublicIpAddress -Name $IPObject.Name -ResourceGroupName $IPObject.ResourceGroupName 
        if ($IpAddressConfig.sku.Name -eq 'basic' -or $IpAddressConfig.zones -notcontains $AzureZone) {
            Write-WithTime_Using_WriteHost ("IP Address is of " + $IpAddressConfig.sku.Name + " type in the " + $IpAddressConfig.sku.Tier + " - deploying new IP address with correct configuration")
                If ($IpAddressConfig.zones -notcontains $AzureZone) {
                    Write-WithTime_Using_WriteHost ("IP Address supported zones: " + [string]$IpAddressConfig.zones)
                    Write-WithTime_Using_WriteHost ("IP Address is in wrong zone deploying new IP address with correct configuration")
                }

                #setting new name
                $IpAddressNewName=$IpAddressConfig.Name + "z"
                Write-WithTime_Using_WriteHost "Requiring new Public IP address with zone configuration for VM deployment"  
    
                $PublicIPResourceGroupName=$IpAddressConfig.ResourceGroupName
                $Location=$IpAddressConfig.Location
                #preparing command - extending with DNS and tags later
                $Command="New-AzPublicIpAddress -Name $IpAddressNewName -ResourceGroupName $PublicIPResourceGroupName -Location $Location -Sku Standard -Tier Regional -AllocationMethod Static -IpAddressVersion IPv4 -Zone $AzureZone"
                
                #if DNSSettings where added - will copy and remove from old IP (if DNS based VPN's are used)
                If ( $IpAddressConfig.DnsSettings) {
                    Write-WithTime_Using_WriteHost ("DNS Name on IP: " +  $IpAddressConfig.DnsSettings)
                    $IPDNSConfig=$IpAddressConfig.DnsSettings.DomainNameLabel
                    $IpAddressConfig.DnsSettings.DomainNameLabel=$null
                    Write-WithTime_Using_WriteHost ("Removing DNS Name from old Public IP")
                    Set-AzPublicIpAddress -PublicIpAddress $IpAddressConfig
                    $Command = $Command + " -DomainNameLabel $IPDNSConfig" 
                }

                #searching for and setting tags
                If ($IpAddressConfig.Tag -and $DoNotCopyTags -eq $false){
                    Write-WithTime_Using_WriteHost "Tags have been found on the original IP - setting same on new IP"
    
                    $newtag=""
                    $TagsOnIP=$IpAddressConfig.Tag
                    #open the new tag to add
                    $newtag="@{"
                    $TagsOnIP.GetEnumerator() | ForEach-Object{
                        $message = '{0}="{1}";' -f $_.key, $_.value
                        $newtag=$newtag + $message
                    }
                    #removing last semicolon
                    $newtag=$newtag.Substring(0,$newtag.Length-1)
                    #closing newtag value
                    $newtag=$newtag +"}"
    
                    #@{key0="value0";key1=$null;key2="value2"}
                    $Command=$Command + " -tag $newtag"
                }
                $Command = [Scriptblock]::Create($Command)

                Try{
                    $Result = Invoke-Command -ScriptBlock $Command 
                }
                Catch {
                    $ErrorMessage = $_.Exception.Message
                    $Output = 'Error '+$ErrorMessage
                    Write-WithTime_Using_WriteHost $Output
                }
                Finally {
                    if ($ErrorMessage -eq $null) {
                        Write-WithTime_Using_WriteHost  "New IP Address created $IpAddressNewName"
                    } else {
                        Write-WithTime_Using_WriteHost  "Could not create new IP address $IpAddressNewName in $PublicIPResourceGroupName - permissions?"
                    }
                }
    
                #Once a new Public IP has been created - it needs to be linked to the NIC
                $NewIP=Get-AzPublicIpAddress -Name $IpAddressNewName -ResourceGroupName $PublicIPResourceGroupName
                $NICObject.IpConfigurations[$s-1].publicIPAddress.id=$NewIP.id
                $ChangedNICConfig=$true
            }
        }
        If ($ChangedNICConfig){
            #VM needs to be in shutdown state for the NIC to be updated: 
            $VMid=$NICObject.VirtualMachine.id
                If ($VMid){
                    $VMstate = (Get-AzVM -ResourceID $VMid -Status).Statuses[1].code
                    if ($VMstate -ne 'PowerState/deallocated' -and $VMstate -ne 'PowerState/Stopped')
                    {   
                        Write-WithTime_Using_WriteHost  "Stopping VM to update Network Interface Card"
                        Stop-AzVM -Id $VMid -Force | Out-Null
                    }else{
                        Write-WithTime_Using_WriteHost  "VM already in stopped / Deallocated State"
                    }
            }
            Write-WithTime_Using_WriteHost "  !! VM has at least 1 new Public IP !!" 
            Write-WithTime_Using_WriteHost "Writing new Network Interface IP Configuration information" 
            $null=Set-AzNetworkInterface -NetworkInterface $NICObject
            
        }else{
            Write-WithTime_Using_WriteHost "No Public IPs on Network Interface"
        }
    }

    function Move-AzVMToAzureZoneAndOrProximityPlacementGroup {
    <#
    .SYNOPSIS
        Moves a VM into an Azure availability zone, or move VM from one Azure zone to another Azure zone
    
    .DESCRIPTION
        The script deletes the VM and recreates it preserving networking and storage configuration.  The script will snapshot each disk, create a new Zonal disk from the snapshot, and create the new Zonal VM with the new disks attached.  
        New zonal disk names will have this naming convention: <OriginalDiskName>-z<ZoneNumber>. If you want to keep the same disk names, you need to use flag KeepSameDiskNames (see below for more information)
        Disk type are Standard or Premium managed disks.
    
        There is no need to reinstall the operating system.
        
        IMPORTANT: The script does not preserve VM extensions. Also, the script will not work for VMs with public IP addresses.
        
        If you specify -ProximityPlacementGroupName parameter, VM will be added to the Proximity Placement Group. Proximity Placement Group must exist.
    
        IMPORTANT: In case that there are other VMs that are part of Proximity Placement Group and the desired Zone, make sure that desired zone and PPG is the same zone where existing VMs are placed!
    
        If your VM is part of an Azure Internal Load Balancer (ILB),specify the name of Azure ILB  by using -AzureInternalLoadBalancerName parameter. 
    
        IMPORTANT: Script will check that Azure ILB is of Standard SKU Type, which is needed for the Zones. 
                   If Azure ILB is of type 'Basic', first you need to convert existing ILB to 'Standard' SKU Type.
        
        IMPORTANT: SAP High Availability context
    
        In SAP High Availability context, script is aplicable when moving for example clustered SAP ASCS/SCS cluster VMs, or DBMS cluster VMs from an Availability Set with Standard Azure ILB, to Azure Zone with Standard Azure ILB.
    
        If you want to add the VM to Proximity Placement Group, expectation is that:
           - Proximity Placement Group alreday exist
           - First ancor VM (this is DBMS VM) is alreday deplyed in a Zone and same Proximity Placement Group
    
           
    .PARAMETER VMResourceGroupName 
    Resource Group Name of the VM.
        
    .PARAMETER VirtualMachineName 
    Virtual Machine Name name. 
    
    .PARAMETER AzureZone
    Azure Zone number.
    
    .PARAMETER PPGResourceGroupName
    Resource group name of the Proximity Placement Group

    .PARAMETER ProximityPlacementGroupName
    Proximity Placement Group Name
    
    .PARAMETER AzureInternalLoadBalancerResourceGroupName
    Resource group name of the Internal Load Balancer.
    

    .PARAMETER AzureInternalLoadBalancerName
    Azure Internal Load Balancer Name
    
    .PARAMETER DoNotCopyTags
    Switch paramater. If specified, VM tags will NOT be copied.

    .PARAMETER NewVMSize
    If NewVMSize is specified , VM will be set to a new VM size. Otherwise, original VM size will be used.

    .PARAMETER KeepSameDiskNames
    If new ‚KeepSameDiskNames‘ flag is specified, OS and data disks names will stay the same. For each disk new unique snapshot will be created, and from snapshot will be created a copy of the original disk with unique disk name (<originalDiskName>-orig<nr> ) . 
    These disk copies can be used to restore original VM. Original disk will then be deleted, and new disk in the desired zone will be created from snapshot, using the original disk names. 

    
    .PARAMETER Force
    Forces the command to run without asking for user confirmation. 
    
    .EXAMPLE
        # Move VM 'VM1' to Azure Zone '2'
        # VM tags will not be copied : swicth parameter -DoNotCopyTags is set
    
        Move-AzVMToAzureZoneAndOrProximityPlacementGroup -VMResourceGroupName SAP-SB1-ResourceGroup -VirtualMachineName VM1 -AzureZone 2 -DoNotCopyTags
    
    .EXAMPLE
        # Move VM 'VM1' to Azure Zone '2', and add to exisiting 'PPGForZone2' 
        # VM will be set to NEW VM size, e.g. not original VM size , because 'NewVMSize' is specified
        Move-AzVMToAzureZoneAndOrProximityPlacementGroup -VMResourceGroupName SAP-SB1-ResourceGroup -VirtualMachineName VM1 -AzureZone 2 -PPGResourceGroupName ppg-group -ProximityPlacementGroupName PPGForZone2 -NewVMSize "Standard_E4s_v3"
        
    
    .EXAMPLE
        # This scenario is used to move higly available DB cluster nodes, SAP ASCS/SCS clsuter nodes, or file share cluster nodes
        # Move VM 'VM1' to Azure Zone '2', and add to exisiting 'PPGForZone2' , and check if Azure Internal Load Balancer 'SB1-ASCS-ILB' has 'Standard' SKU type
        # User is asked for confirmation to stop the VM and delete the VM
        Move-AzVMToAzureZoneAndOrProximityPlacementGroup -VMResourceGroupName SAP-SB1-ResourceGroup -VirtualMachineName sb1-ascs-cl1 -AzureZone 2 -PPGResourceGroupName ppg-group -ProximityPlacementGroupName PPGForZone2 -AzureInternalLoadBalancerResourceGroupName gor-lb-group -AzureInternalLoadBalancerName SB1-ASCS-ILB
    
    .EXAMPLE
        # This scenario is used to move higly available DB cluster nodes, SAP ASCS/SCS clsuter nodes, or file share cluster nodes
        # Move VM 'VM1' to Azure Zone '2', and add to exisiting 'PPGForZone2' , and check if Azure Internal Load Balancer 'SB1-ASCS-ILB' has 'Standard' SKU type
        # User is NOT asked for confirmation to stop the VM and delete the VM
        Move-AzVMToAzureZoneAndOrProximityPlacementGroup -VMResourceGroupName SAP-SB1-ResourceGroup -VirtualMachineName sb1-ascs-cl1 -AzureZone 2 -PPGResourceGroupName ppg-group -ProximityPlacementGroupName PPGForZone2 -AzureInternalLoadBalancerResourceGroupName gor-lb-group -AzureInternalLoadBalancerName SB1-ASCS-ILB  -Force
    

    .LINK
        
    .NOTES
        v0.1 - Initial version
    
    #>
    
    #Requires -Modules Az.Compute
    #Requires -Version 5.1
    
        [CmdletBinding()]
        param(
            
            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            [string] $VMResourceGroupName,
                  
            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            [string] $VirtualMachineName,
    
            [Parameter(Mandatory=$True)]
            [string] $AzureZone,
    
            [Parameter(Mandatory=$False)]              
            [string] $PPGResourceGroupName,

            [Parameter(Mandatory=$False)]
            [string] $ProximityPlacementGroupName,
    
            [Parameter(Mandatory=$False)]
            [ValidateNotNullOrEmpty()]        
            [string] $AzureInternalLoadBalancerResourceGroupName,

            [Parameter(Mandatory=$False)]
            [string] $AzureInternalLoadBalancerName,
    
            [switch] $DoNotCopyTags,

            [switch] $KeepSameDiskNames,

            [Parameter(Mandatory=$False)]
            [string] $NewVMSize,
            
            [switch] $Force
        )
    
        BEGIN{        
            $ProximityPlacementGroupExist = $False    
        }
        
        PROCESS{
            try{                  
                # Handle Azure Load Balancer 
                if (($AzureInternalLoadBalancerName -ne "") -and ($AzureInternalLoadBalancerResourceGroupName -ne "")) {           
                        $ILB = Get-AzLoadBalancer -ResourceGroupName $AzureInternalLoadBalancerResourceGroupName -Name $AzureInternalLoadBalancerName -ErrorAction Stop
        
                        if($ILB -ne $null){
                            $AzureInternalLoadBalancerNameExist = $True
                            Write-Host
                            Write-WithTime_Using_WriteHost "Azure Internal Load Balancer '$AzureInternalLoadBalancerName' in resource group '$AzureInternalLoadBalancerResourceGroupName' exist."
        
                            #check if ILB SKU for 'Standard'
                            if($ILB.Sku.Name -eq "Standard"){
                                Write-Host
                                Write-WithTime_Using_WriteHost "Azure Internal Load Balancer '$AzureInternalLoadBalancerName' has expected 'Standard' SKU."
                            }
                            else{
                                Throw  "Specified Azure Internal Load BalancerName is not 'Standard' load balancer. Before proceeding convert '$AzureInternalLoadBalancerName' load balancer from 'Basic' to 'Standard' SKU type." 
                            }
                        }else{
                            Throw  "Specified Azure Internal Load BalancerName '$AzureInternalLoadBalancerName' doesn't exists. Please check your input parameter 'AzureInternalLoadBalancerName' and 'AzureInternalLoadBalancerResourceGroupName'." 
                        }
                                                    
                }else{                    

                        if (($AzureInternalLoadBalancerName -ne "") -and ($AzureInternalLoadBalancerResourceGroupName -eq "")) {
                            Write-Host
                            Throw "Only '-AzureInternalLoadBalancerName' PowerShell parameter is specified. Please specify also parameter '-AzureInternalLoadBalancerResourceGroupName'." 

                        }elseif (($AzureInternalLoadBalancerName -eq "") -and ($AzureInternalLoadBalancerResourceGroupName -ne "")) {
                            Write-Host
                            Throw "Only '-AzureInternalLoadBalancerResourceGroupName' PowerShell parameter is specified. Please specify also parameter '-AzureInternalLoadBalancerName'." 
                        }else{
                            Write-Host
                            Write-WithTime_Using_WriteHost "Azure Internal Load Balancer is not specified."                         
                        }                    
                }  
               
                # Handle Proximity Placement Group 
                if (($ProximityPlacementGroupName -ne "") -and ($PPGResourceGroupName -ne "")) {        
                    $ppg = Get-AzProximityPlacementGroup -ResourceGroupName $PPGResourceGroupName -Name $ProximityPlacementGroupName -ErrorAction Stop    
                    $ProximityPlacementGroupExist = $True
                    
                    Write-Host
                    Write-WithTime_Using_WriteHost "Proximity Placement Group '$ProximityPlacementGroupName' in resource group '$PPGResourceGroupName' exist."    
                    
                    Write-Host
                    Write-WithTime_Using_WriteHost "Starting migration of Virtual Machine '$VirtualMachineName' to Azure Zone '$AzureZone', and Proximity Placement Group '$ProximityPlacementGroupName' ..."                                   
                }else {
                    if (($ProximityPlacementGroupName -ne "") -and ($PPGResourceGroupName -eq "")) {
                        Write-Host
                        Throw "Only '-ProximityPlacementGroupName' PowerShell parameter is specified. Please specify also parameter '-PPGResourceGroupName'." 

                    }elseif (($ProximityPlacementGroupName -eq "") -and ($PPGResourceGroupName -ne "")) {
                        Write-Host
                        Throw "Only '-PPGResourceGroupName' PowerShell parameter is specified. Please specify also parameter '-ProximityPlacementGroupName'." 
                    }else{
                        Write-Host                        
                        Write-WithTime_Using_WriteHost "Proximity Placement Group is not specified."

                        Write-Host
                        Write-WithTime_Using_WriteHost "Starting migration of Virtual Machine '$VirtualMachineName' to Azure Zone '$AzureZone' ..."
                    }     
                }

               Write-Host
               
               $VMstate = (Get-AzVM -ResourceGroupName $VMResourceGroupName -Name $VirtualMachineName -Status).Statuses[1].code
               if ($VMstate -eq 'PowerState/deallocated' -and $VMstate -eq 'PowerState/Stopped')
               {   
                Write-WithTime_Using_WriteHost  "Starting virtual machine '$VirtualMachineName' ..."
                Start-AzVM -ResourceGroupName $VMResourceGroupName -Name $VirtualMachineName -ErrorAction Stop 
               }else{
                Write-WithTime_Using_WriteHost  "Virtual machine '$VirtualMachineName' already started  ..."
               }
               

    
               # get VM and check existance
               $originalVM = Get-AzVM -ResourceGroupName $VMResourceGroupName -Name $VirtualMachineName -ErrorAction Stop       
               
               # Azure shared disks are not supported
               Write-Host
               Write-WithTime_Using_WriteHost  "Checking if virtual machine '$VirtualMachineName' has Azure shared data disks ... "
               $VMHasAzureSharedDisks = Test-AzVMHasAzureSharedDisks -ResourceGroupName  $VMResourceGroupName -VMName $VirtualMachineName
               if ($VMHasAzureSharedDisks) {
                    Write-Host   
                    Throw "VM '$VirtualMachineName' has Azure shared disk. Azure shared disks are not supported."
               }else {
                    Write-Host
                    Write-WithTime_Using_WriteHost  "Virtual machine '$VirtualMachineName' has no Azure shared data disks."
               }
                                                                                                                                    
               # We don't support moving machines with public IPs, since those are zone specific. 
               # added by rozome @ 5/18/2022 - support for Public IPs 
               ##foreach ($nic in $originalVM.NetworkProfile.NetworkInterfaces) {
                
                #This part was added RCZ: 5/18/2022 to support public IP movements
                Foreach ($NIC in $originalVM.NetworkProfile.NetworkInterfaces.id){
                    $null=Prepare-AZNicForZonal -NICID $NIC -AzureZone $AzureZone
                }
                
                    #$thenic = $nic.id
                    # $nicname = $thenic.substring($thenic.LastIndexOf("/")+1)
                    # $othernic = Get-AzNetworkInterface -name $nicname -ResourceGroupName $VMResourceGroupName 
                    # Write-Host
                    # Write-WithTime_Using_WriteHost "Found Network Card '$nicname' in Azure resource group  '$VMResourceGroupName'."
            
                    # foreach ($ipc in $othernic.IpConfigurations) {
                    #     $pip = $ipc.PublicIpAddress
                    #     if ($pip) { 
                    #         Throw  "Sorry, machines with public IPs are not supported by this script" 
                    #            #exit
                    #     }
                    # }
               #}
             
               [string] $osType      = $originalVM.StorageProfile.OsDisk.OsType
               [string] $location    = $originalVM.Location
               [string] $storageType = $originalVM.StorageProfile.OsDisk.ManagedDisk.StorageAccountType
               [string] $OSDiskName  = $originalVM.StorageProfile.OsDisk.Name
               # when non-Zonal disk / VM this value is an empty string
               [string] $VMDiskZone  = $originalVM.Zones

               if ($VMDiskZone -eq "") {
                   [bool] $VMIsZonal = $False
               }else {
                [bool] $VMIsZonal = $True
               }

                # Do not delete OS and Data disks during the VM deletion - set DeleteOption to 'Detach'
                Set-AzVMDisksDeleteOption -VM $originalVM -DeleteOption "Detach"                                

                # Do not delete NIC cards during the VM deletion - Set NIC Cards to 'Detach'
                Set-AzVMNICsDeleteOption -VM $originalVM -DeleteOption "Detach"                
                               
               $OriginalVMSize =  $originalVM.HardwareProfile.VmSize

               if($NewVMSize -eq ""){
                    # if $NewVMSIze is not specified, use the original VM size
                    Write-Host
                    Write-WithTime_Using_WriteHost "VM type is '$OriginalVMSize'."

                    $VMSize = $OriginalVMSize                    
                }
                else{
                    # if $NewVMSIze is specified, use it as VM size
                     
                    Write-Host
                    Write-WithTime_Using_WriteHost "Changing VM type from original '$OriginalVMSize' to new type '$NewVMSize'."

                    $VMSize = $NewVMSize
                }
        
                # Check if VM SKU is available in the desired Azure zone
                Write-Host
                Write-WithTime_Using_WriteHost "Checking VM SKU '$VMSize' availablity in Azure zone '$AzureZone' in region '$location'  ...."

                $VMSKUIsAvailableinAzureZone = Test-AzComputeSKUZonesAvailability -Location $location  -VMSKU $VMSize -AzureZone $AzureZone
                if (-not $VMSKUIsAvailableinAzureZone) {
                    $AzureZones = Get-AzComputeSKUZonesAvailability -Location $location -VMSKU $VMSize
                    if ($null -eq $AzureZones) {
                        Write-Host
                        Throw "VM SKU '$VMSize' is not available in any of the Azure zones in region '$location'. PLease use another VM SKU."                            
                    }else {
                        Write-Host
                        Write-WithTime_Using_WriteHost "VM SKU '$VMSize' is available in these Azure zone(s):"
                        Write-Host $AzureZones
                        Write-Host
                        Throw "VM SKU '$VMSize' is not available in desired Azure zone '$AzureZone' in region '$location'. PLease use another VM SKU or another zone."    
                    }
                    
                }              

                # if PPG is specified and contains VMs, check:
                 ## if region of the PPG is the same as the region of the VM
                 ## if VMs in the PPG are in the  the same zone as target zone of the migrated VM

                if ($ProximityPlacementGroupExist) {
                    
                    # Check if region of the PPG is the same as the region of the VM
                    $PPGLocation = $ppg.Location 
                    if ( $location -ne $PPGLocation) {
                        Write-Host
                        Throw "Azure region '$location' of the VM '$VirtualMachineName' is different from the Proximity Placement Group '$ProximityPlacementGroupName' region '$PPGLocation'. Choose Proximity Placement Group located in the same region '$location' as the VM '$VirtualMachineName'. "
                    }else {
                        Write-Host
                        Write-WithTime_Using_WriteHost "VM and Proximity Placement Group are located in the same Azure region '$location'."
                    }

                    # Check if VMs in the PPG are in the  the same zone as target zone of the migrated VM
                    $VMsInPPG = Get-AzVMBelongingProximityPlacementGroup -ResourceGroupName $PPGResourceGroupName -PPGName $ProximityPlacementGroupName 

                    if ($null -ne $VMsInPPG) {
                        Write-Host
                        Write-WithTime_Using_WriteHost "Found VMs in the Proximity Placement Group '$PPGResourceGroupName'."                        

                        foreach ($VMInPPG in $VMsInPPG) {
                            
                            if ($null -ne $VMInPPG.VMZone) {
                                Write-Host
                                Write-WithTime_Using_WriteHost "VM '$($VMInPPG.VMName)' (anchor VM) asociated with Proximity Placement Group '$ProximityPlacementGroupName' is in Azure zone $($VMInPPG.VMZone)."

                                if ($AzureZone -ne $VMInPPG.VMZone ) {
                                    Write-Host
                                    Throw "Target VM '$VirtualMachineName' zone '$AzureZone' is different from zone '$($VMInPPG.VMZone)' of the anchor VM '$($VMInPPG.VMName)' belonging to Proximity Placement Group '$ProximityPlacementGroupName'. Chose Proximity Placement Group with VM(s) belonging to the target zone '$AzureZone'."
                                }else {
                                    Write-Host
                                    Write-WithTime_Using_WriteHost "Target VM '$VirtualMachineName' zone is zone '$AzureZone', and is the same as the zone '$($VMInPPG.VMZone)' of the anchor VM '$($VMInPPG.VMName)' belonging to Proximity Placement Group '$ProximityPlacementGroupName'. "
                                    break
                                }

                            }
                        }

                    }else {
                        Write-Host
                        Write-WithTime_Using_WriteHost "No (anchor) VMs found in the Proximity Placement Group '$ProximityPlacementGroupName'."
                    }
                }
                
               # Shutdown the original VM
               $ToStop = $true               

               if(-not $Force){
                Write-Host
                $ToStop = Get-AzVMStopAnswer -VirtualMachineName $VirtualMachineName -ResourceGroupName $VMResourceGroupName
               }
                              
               if($ToStop){
                    Write-Host
                    Write-WithTime_Using_WriteHost  "Stopping Virtual Machine '$VirtualMachineName' in resource group '$VMResourceGroupName' ..."
                    Stop-AzVM -ResourceGroupName $VMResourceGroupName -Name $VirtualMachineName -force -ErrorAction Stop 
               }else {
                    # Exit
                    Return   
               }
               
    
               # Export original VM configuration
               Write-Host
               Export-VMConfigurationToJSONFile -VM  $originalVM      
                          
               #  Create the basic configuration for the replacement VM with Zone and / or PPG
               if($ProximityPlacementGroupExist){
                    Write-Host
                    Write-WithTime_Using_WriteHost "Configuring Virtual Machine to use Azure Zone '$AzureZone' and Proximity Placement Group '$ProximityPlacementGroupName' ..."
                    $newVM = New-AzVMConfig -VMName $VirtualMachineName -VMSize $VmSize -ProximityPlacementGroupId $ppg.Id -Zone $AzureZone
               }else{
                    Write-Host
                    Write-WithTime_Using_WriteHost "Configuring Virtual Machine to use Azure Zone '$AzureZone' ..."
                    $newVM = New-AzVMConfig -VMName $VirtualMachineName -VMSize $VmSize -Zone $AzureZone 
               }
                            
               #  Snap and copy the os disk               
               $snapshot = New-AzUniqueNameSnapshot -ResourceGroupName $VMResourceGroupName -Location $location -DiskName $originalVM.StorageProfile.OsDisk.Name -SourceDiskResourceId $originalVM.StorageProfile.OsDisk.ManagedDisk.Id
               
               if($KeepSameDiskNames){
                    Write-Host
                    Write-WithTime_Using_WriteHost  "Specified flag 'KeepSameDiskNames'."

                    # Create / Copy the exsiting OS Disk with new name
                    Copy-AzUniqueNameDiskFromSnapshot -ResourceGroupName $VMResourceGroupName -Location $location -Snapshot $snapshot -OriginalDiskName $OSDiskName -StorageType $storageType -VMDiskZone $VMDiskZone -DiskNamePosfix "orig"
                    
                    # Remove the original VM -this is a prerequisit to delete orignial OS and data disks
                    $ToDelete = $true

                    if(-not $Force){
                        Write-Host
                        $ToDelete = Get-AzVMDeleteAnswer -VirtualMachineName $VirtualMachineName -ResourceGroupName $VMResourceGroupName
                    }
                    
                    if($ToDelete){
                        Write-Host
                        Write-WithTime_Using_WriteHost  "Removing Virtual Machine '$VirtualMachineName' ..."
                        Write-Host
                        Remove-AzVM -ResourceGroupName $VMResourceGroupName -Name $VirtualMachineName -force            
                    }else {
                        # Exit
                        Return   
                    }              

                    # Delete Original OS Disk
                    Write-Host
                    Write-WithTime_Using_WriteHost  "Removing original OS disk '$osdiskname' ..."
                    Remove-AzDisk -ResourceGroupName $VMResourceGroupName -DiskName  $osdiskname -Force                                         
               }else {
                   
               }
            
               $newdiskConfig = New-AzDiskConfig -AccountType $storageType -Location $location -CreateOption Copy -SourceResourceId $snapshot.Id -zone $AzureZone
               
               if($KeepSameDiskNames){
                # use the same disk name
                $newdiskName = $osdiskname 
               }else {
                $newdiskName = $osdiskname + "-z" + $AzureZone
               }
               
               Write-Host
               Write-WithTime_Using_WriteHost  "Creating OS zonal disk '$newdiskName' from snapshot '$($snapshot.Name)' ..."
               $newdisk = New-AzDisk -Disk $newdiskConfig -ResourceGroupName $VMResourceGroupName -DiskName $newdiskName
    
               # Configure new Zonal OS Disk
               if ($osType -eq "Linux")
               {
                    Write-Host
                    Write-WithTime_Using_WriteHost "Configuring Linux OS disk '$newdiskName' for Virtual Machine '$VirtualMachineName'... "  
                    Set-AzVMOSDisk -VM $newVM -CreateOption Attach  -ManagedDiskId $newdisk.Id -Name $newdisk.Name  -Linux -Caching $originalVM.StorageProfile.OsDisk.Caching > $null
               }
               if ($osType -eq "Windows")
               {
                    Write-Host
                    Write-WithTime_Using_WriteHost "Configuring Windows OS disk '$newdiskName' Virtual Machine '$VirtualMachineName' ... " 
                    Set-AzVMOSDisk -VM $newVM -CreateOption Attach  -ManagedDiskId $newdisk.Id -Name $newdisk.Name  -Windows -Caching $originalVM.StorageProfile.OsDisk.Caching > $null	
               }
    
               # Snapshot all of the Data disks, and add to the VM
               foreach ($disk in $originalVM.StorageProfile.DataDisks)
               {        
                        $OriginalDataDiskName = $disk.Name

                        #snapshot & copy the data disk
                        $snapshot = New-AzUniqueNameSnapshot -ResourceGroupName $VMResourceGroupName -Location $location -DiskName  $disk.Name -SourceDiskResourceId $disk.ManagedDisk.Id                                                               

                        if($KeepSameDiskNames){
                            # use the same disk name
                            $diskName = $disk.Name

                            # Create / Copy the exsiting Data disk with a new name
                            Copy-AzUniqueNameDiskFromSnapshot -ResourceGroupName $VMResourceGroupName -Location $location -Snapshot $snapshot -OriginalDiskName $OriginalDataDiskName -StorageType $storageType -VMDiskZone $VMDiskZone -DiskNamePosfix "orig"

                            # Delete Original Data disk
                            Write-Host
                            Write-WithTime_Using_WriteHost  "Removing original data disk '$OriginalDataDiskName' ..."
                            Remove-AzDisk -ResourceGroupName $VMResourceGroupName -DiskName  $OriginalDataDiskName -Force 
                           }else {
                            $diskName = $disk.Name + "-z" + $AzureZone
                        }                        
                                                                        
                        $diskConfig = New-AzDiskConfig -AccountType $storageType -Location $location -CreateOption Copy -SourceResourceId $snapshot.Id -zone $AzureZone
                        Write-Host 
                        Write-WithTime_Using_WriteHost  "Creating zonal data disk '$diskName' from snapshot '$($snapshot.Name)' ..."
                        Write-Host 
                        $newdisk = New-AzDisk -Disk $diskConfig -ResourceGroupName $VMResourceGroupName -DiskName $diskName # > $null
                        
                        Write-WithTime_Using_WriteHost "Configuring data disk '$($newdisk.Name)' , LUN '$($disk.Lun)' for Virtual Machine '$VirtualMachineName' ... " 
    
                        if($disk.WriteAcceleratorEnabled) {
                            Write-Host 
                            Write-WithTime_Using_WriteHost "Adding disk '$($newdisk.Name)' to new VM with enabled Write Accelerator ...  "
                            Add-AzVMDataDisk -VM $newVM -Name $newdisk.Name -ManagedDiskId $newdisk.Id -Caching $disk.Caching -Lun $disk.Lun -DiskSizeInGB $newdisk.DiskSizeGB -CreateOption Attach -WriteAccelerator  > $null	
                        }else{
                            Write-Host 
                            Write-WithTime_Using_WriteHost "Adding disk '$($newdisk.Name)' to new VM ...  "
                            Add-AzVMDataDisk -VM $newVM -Name $newdisk.Name -ManagedDiskId $newdisk.Id -Caching $disk.Caching -Lun $disk.Lun -DiskSizeInGB $newdisk.DiskSizeGB -CreateOption Attach > $null	
                        }
             }
    
             # Add NIC(s) and keep the same NIC as primary
             foreach ($nic in $originalVM.NetworkProfile.NetworkInterfaces) {	              
                Write-Host
                Write-WithTime_Using_WriteHost "Configuring '$($nic.Id)' network card to Virtual Machine '$VirtualMachineName'  ..."
                if ($nic.Primary -eq "True"){                
                    Write-Host 
                    Write-WithTime_Using_WriteHost "NIC is primary."
                    Add-AzVMNetworkInterface -VM $newVM -Id $nic.Id -Primary > $null
                }
                else{                
                    Write-Host 
                    Write-WithTime_Using_WriteHost "NIC is secondary."
                    Add-AzVMNetworkInterface -VM $newVM -Id $nic.Id > $null
                }
            }
    
            if(-not $DoNotCopyTags){
                # Copy the Tags
                Write-Host
                Write-WithTime_Using_WriteHost "Listing VM '$VirtualMachineName' tags: "
                Write-Host
                $originalVM.Tags
        
                Write-Host
                Write-WithTime_Using_WriteHost "Copy Tags ..."
                $newVM.Tags = $originalVM.Tags
                Write-Host
                Write-WithTime_Using_WriteHost "Tags copy to new VM definition done. "
            }else{            
                Write-Host
                Write-WithTime_Using_WriteHost "Skipping copy of VM tags:"            
                Write-Host
                $originalVM.Tags
            }
        
            #Configure Boot Diagnostic account
            if ($originalVM.DiagnosticsProfile.BootDiagnostics.Enabled) {
                Write-Host
                Write-WithTime_Using_WriteHost "Boot diagnostic account is enabled."
                
                # Get Strage URI
                $StorageUri = $originalVM.DiagnosticsProfile.BootDiagnostics.StorageUri            
    
                if ($StorageUri -eq $null) {
    
                    Write-WithTime_Using_WriteHost "Boot diagnostic URI is empty." -PrependEmptyLine -AppendEmptyLine
                                
                    Write-WithTime_Using_WriteHost "Configuring boot diganostic with managed storage account ..."  -AppendEmptyLine            

                    $newVM = Set-AzVMBootDiagnostic -VM $newVM -Enable
                }else {
                    
                    $BootDiagnosticURI = $originalVM.DiagnosticsProfile.BootDiagnostics.StorageUri.Split("/")[2]
                    Write-Host
                    Write-WithTime_Using_WriteHost "Boot diagnostic URI: '$BootDiagnosticURI'."
        
                    $staccName = $BootDiagnosticURI.Split(".")[0]
                    Write-Host
                    Write-WithTime_Using_WriteHost "Extracted storage account name: '$staccName'"
        
                    Write-Host
                    Write-WithTime_Using_WriteHost "Getting storage account '$staccName'"
                    $stacc = Get-AzStorageAccount | where-object { $_.StorageAccountName.Contains($staccName) }
                    
                    if($stacc  -eq $null ){
                        Write-WithTime_Using_WriteHost "Storage account '$staccName' used for diagonstic account on source VM do not exist." -PrependEmptyLine -AppendEmptyLine
                                
                        Write-WithTime_Using_WriteHost "Configuring boot diganostic with managed storage account ..."  -AppendEmptyLine            

                        $newVM = Set-AzVMBootDiagnostic -VM $newVM -Enable  
                    }else{
    
                        Write-Host
                        Write-WithTime_Using_WriteHost "Configuring storage account '$staccName' for VM boot diagnostigs in Azure resource group '$($stacc.ResourceGroupName)' on the new VM ..."
                    
                        $newVM = Set-AzVMBootDiagnostic -VM $newVM -Enable -ResourceGroupName $stacc.ResourceGroupName -StorageAccountName $staccName
    
                        Write-Host
                        Write-WithTime_Using_WriteHost "Configuring storage account '$staccName' for VM boot diagnostigs done."    
                    }
                    
                }
            }
    
            # Remove the original VM
            $ToDelete = $true

            if(-not $Force){
                Write-Host
                $ToDelete = Get-AzVMDeleteAnswer -VirtualMachineName $VirtualMachineName -ResourceGroupName $VMResourceGroupName
            }
            
            if($ToDelete){
                Write-Host
                Write-WithTime_Using_WriteHost  "Removing Virtual Machine '$VirtualMachineName' ..."
                Write-Host
                Remove-AzVM -ResourceGroupName $VMResourceGroupName -Name $VirtualMachineName -force            
            }else {
                # Exit
                Return   
            }              
    
            # Create the new VM
            Write-Host
            Write-WithTime_Using_WriteHost "Recreating Virtual Machine '$VirtualMachineName' as zonal VM in Azure zone '$AzureZone' ..."
            New-AzVM -ResourceGroupName $VMResourceGroupName -Location $originalVM.Location -VM $newVM -DisableBginfoExtension -zone $AzureZone
    
            Write-WithTime_Using_WriteHost "Done!"
    
            }
            catch{
               Write-Error  $_.Exception.Message           
           }
    
        }
    
        END {}
    }
    
    function New-AzUniqueNameSnapshot {
    <#
    .SYNOPSIS
        Cmdlet will create a disk snapshot with unique name “<DiskName>-snap” . 
        If the snapshot with this name exists in the resource group, it will add a number to snapshot name “<DiskName>-snap<Nr>”, starting with 0, and continuing with 1, 2 etc.
    
    .DESCRIPTION
        Cmdlet will create a disk snapshot with unique name “<DiskName>-snap” . 
        If the snapshot with this name exists in the resource group, it will add a number to snapshot name “<DiskName>-snap<Nr>”, starting with 0, and continuing with 1, 2 etc.
    
    .EXAMPLE            
    
    .LINK
        
    
    .NOTES
        v0.1 - Initial version
    
    #>
    
    #Requires -Modules Az.Compute
    #Requires -Version 5.1
    
        [CmdletBinding()]
        param(
                        
            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            [string] $ResourceGroupName,
            
            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            [string] $Location,
            
            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            [string] $DiskName,

            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            [string] $SourceDiskResourceId,

            [Parameter(Mandatory=$False)]                    
            [string] $SnapshotPosfix = "snap"

        )
    
        BEGIN{        
                
        }
        
        PROCESS{
            try{   
                               
                $snapshotName = $DiskName + "-$($SnapshotPosfix)"    
               
                # Check if the  snapshot with the same name exists               
                # Generate autmaticaly new snapshot name by adding 0, 1 , 2 etc.
                $i = 0
                $SnapshotNameIsNotUnique = $True
                do {
                    
                    Write-Host
                    Write-WithTime_Using_WriteHost  "Checking existance of snapshot '$snapshotName' in resource group '$ResourceGroupName' ..."
                    $CheckSnapshot = Get-AzSnapshot -ResourceGroupName $ResourceGroupName -SnapshotName $snapshotName  -ErrorVariable -notPresent  -ErrorAction SilentlyContinue

                    if ($null -ne $CheckSnapshot ) {
                        Write-Host
                        Write-WithTime_Using_WriteHost  "Snapshot '$snapshotName' in resource group '$ResourceGroupName' alredy exist."

                        # Create a new snapshot name
                        $snapshotName = $DiskName + "-$($SnapshotPosfix)" + "$i"
                        $i = ++$i
                    }else {
                        Write-Host
                        Write-WithTime_Using_WriteHost  "Snapshot '$snapshotName' in resource group '$ResourceGroupName' do not exist."

                        Write-Host
                        Write-WithTime_Using_WriteHost  "Found uniqueu snapshot name '$snapshotName'."
                        $SnapshotNameIsNotUnique = $False
                    }
                } while ($SnapshotNameIsNotUnique)
               
                $snapshotCfg =  New-AzSnapshotConfig -Location $Location -CreateOption copy -SourceResourceId $SourceDiskResourceId  

                Write-Host
                Write-WithTime_Using_WriteHost  "Creating disk snapshot '$snapshotName' of the disk '$DiskName' ..."
                $snapshot = New-AzSnapshot -Snapshot $snapshotCfg -SnapshotName $snapshotName -ResourceGroupName $ResourceGroupName     
               
                # Return snapshot object
               Write-Output $snapshot
            }
            catch{
                Write-Error  $_.Exception.Message           
            }
    
        }
    
        END {}
}

function Copy-AzUniqueNameDiskFromSnapshot {
    <#
    .SYNOPSIS
        Cmdlet will copy original disk to a new disk from existing disk snapshot, with unique disk name “<OriginalDiskName>-orig”. 
        If this with this name already exist,  it will add a number to disk name “<DiskName >-orig<Nr>”, starting with 0, and continuing with 1, 2 etc. 
    
    .DESCRIPTION
        Cmdlet will copy original disk to a new disk from existing disk snapshot, with unique disk name “<OriginalDiskName>-orig”. 
        If this with this name already exist,  it will add a number to disk name “<DiskName >-orig<Nr>”, starting with 0, and continuing with 1, 2 etc. 
    
    .EXAMPLE    
        #Example
    
    .LINK
    
    .NOTES
        v0.1 - Initial version
    
    #>
    
    #Requires -Modules Az.Compute
    #Requires -Version 5.1
    
        [CmdletBinding()]
        param(
                        
            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            [string] $ResourceGroupName,
            
            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            [string] $Location,

            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            $Snapshot,
            
            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            [string] $OriginalDiskName,

            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            [string] $StorageType,

            [Parameter(Mandatory=$False)]                
            [string] $VMDiskZone = "",

            [Parameter(Mandatory=$False)]                    
            [string] $DiskNamePosfix = "orig"

        )
    
        BEGIN{        
                
        }
        
        PROCESS{
            try{   
                                               
                if ($VMDiskZone -eq "") {
                    [bool] $VMIsZonal = $False
                }else {
                 [bool] $VMIsZonal = $True
                }

                # Check if the disk with the same name exists               
                # Generate autmaticaly new disk name by adding 0, 1 , 2 etc.
                $i = 0
                $DiskNameIsNotUnique = $True

                $NewDiskName = $OriginalDiskName + "-$DiskNamePosfix"

                do {
                    
                    Write-Host
                    Write-WithTime_Using_WriteHost  "Checking existance of the disk  '$NewDiskName' in resource group '$ResourceGroupName' ..."
                    $CheckDisk = Get-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $NewDiskName  -ErrorVariable -notPresent  -ErrorAction SilentlyContinue

                    if ($null -ne $CheckDisk ) {
                        Write-Host
                        Write-WithTime_Using_WriteHost  "Disk '$NewDiskName' in resource group '$ResourceGroupName' alredy exist."

                        # Create a new snapshot name
                        $NewDiskName = $OriginalDiskName + "-$($DiskNamePosfix)" + "$i"
                        $i = ++$i
                    }else {
                        Write-Host
                        Write-WithTime_Using_WriteHost  "Disk '$NewDiskName' in resource group '$ResourceGroupName' do not exist."

                        Write-Host
                        Write-WithTime_Using_WriteHost  "Found uniqueu disk name '$NewDiskName'."
                        $DiskNameIsNotUnique = $False
                    }
                } while ($DiskNameIsNotUnique)

                 # Create / Copy the exsiting Disks with new name
                 if ($VMIsZonal) {
                     Write-Host
                     Write-WithTime_Using_WriteHost  "Original disk '$OriginalDiskName' is zonal in zone '$VMDiskZone'."
                     $CopyOSDiskConfig = New-AzDiskConfig -AccountType $StorageType -Location $Location -CreateOption Copy -SourceResourceId $Snapshot.Id -zone $VMDiskZone    
                 }else {
                     Write-Host
                     Write-WithTime_Using_WriteHost  "Original disk '$OriginalDiskName' is not zonal."
                     $CopyOSDiskConfig = New-AzDiskConfig -AccountType $StorageType -Location $Location -CreateOption Copy -SourceResourceId $Snapshot.Id 
                 }
                                                
                 Write-Host
                 Write-WithTime_Using_WriteHost  "Copy original disk '$OriginalDiskName' to new disk '$NewDiskName' from snapshot '$($Snapshot.Name)' ..."
                 $Disk = New-AzDisk -Disk $CopyOSDiskConfig -ResourceGroupName $ResourceGroupName -DiskName $NewDiskName -ErrorAction Stop | Out-Null

                 Write-Host
                 Write-WithTime_Using_WriteHost  "Copied disk '$NewDiskName' can be used to restore original VM."

                 Write-Output $Disk
            }
            catch{
                Write-Error  $_.Exception.Message           
            }
    
        }
    
        END {}
}


function Get-AzComputeSKUZonesAvailability {
    <#
    .SYNOPSIS
        This cmdlet returns list of all zones that are available for the VM SKU in certain Azure region.  In case that VM SKU is not available in any zone, an exception with error is thrown. 
    
    .DESCRIPTION
        This cmdlet returns list of all zones that are available for the VM SKU in certain Azure region.  In case that VM SKU is not available in any zone, an exception with error is thrown.
    
    .EXAMPLE    
        # get list of all all zones supporting VM SKU "Standard_D64s_v3"
        Get-AzComputeSKUZonesAvailability -Location "westeurope" -VMSKU "Standard_D64s_v3"
    
    
    .EXAMPLE
        
        Example
    
    .LINK
        
    
    .NOTES
        v0.1 - Initial version
    
    #>
    
    #Requires -Modules Az.Compute
    #Requires -Version 5.1
    
        [CmdletBinding()]
        param(
                                   
            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            [string] $Location,

            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            $VMSKU            
        )
    
        BEGIN{        
                
        }
        
        PROCESS{
            try{   
                                               
                $SKU = Get-AzComputeResourceSku -Location $Location | where  { ($_.Name -eq $VMSKU) }

                if ($null -eq $SKU) {
                    Write-Host
                    Throw "VM SKU '$VMSKU' not found in Azure region '$Location'. Please check your VM SKU size."
                }

                $Zones = $SKU.LocationInfo.Zones

                Write-Output $Zones
            }
            catch{
                Write-Error  $_.Exception.Message           
            }
    
        }
    
        END {}
}

function Test-AzComputeSKUZonesAvailability {
    <#
    .SYNOPSIS
        This cmdlet checks a VM SKU is available in certain Azure zone in an Azure region, and it returns $True or $False.
    
    .DESCRIPTION
      This cmdlet checks a VM SKU is available in certain Azure zone in an Azure region, and it returns $True or $False.
        
    .EXAMPLE    
        # Checkign if VM SKU Standard_D64s_v3  is availble in zone 1 in West Europe region
        Test-AzComputeSKUZonesAvailabilit -Location "westeurope" -VMSKU "Standard_D64s_v3"  -AzureZone 1    
    
    .LINK
        
    .NOTES
        v0.1 - Initial version
    
    #>
    
    #Requires -Modules Az.Compute
    #Requires -Version 5.1
    
        [CmdletBinding()]
        param(
                                   
            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            [string] $Location,

            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            $VMSKU,
            
            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            $AzureZone  
        )
    
        BEGIN{        
                
        }
        
        PROCESS{
            try{   
                                               
                $VMAvailabilityZones = Get-AzComputeSKUZonesAvailability -Location $Location -VMSKU $VMSKU

                $VMSKUIsAvailableInZone = $False

                foreach ($VMAvailabilityZone in $VMAvailabilityZones) {                    
                    if ($VMAvailabilityZone -eq $AzureZone) {
                        Write-Host
                        Write-WithTime_Using_WriteHost "VM SKU '$VMSize' is available in the Azure zone '$AzureZone' in region '$Location'."

                        $VMSKUIsAvailableInZone = $True

                        break
                    }
                }

                # return $true or $false
                Write-Output $VMSKUIsAvailableInZone
            }
            catch{
                Write-Error  $_.Exception.Message           
            }
    
        }
    
        END {}
}


    function Test-AzVMIsZonalVM {
    <#
    .SYNOPSIS
        Check if VM is Zonal VM or not. 
    
    .DESCRIPTION
        Commanlet check if VM is Zonal VM or not, e.g. it retruns boolian $True or $False
        
    
    .EXAMPLE    
        Test-AzVMIsZonalVM -ResourceGroupName gor-Zone-Migration  -VirtualMachineName mig-c2
    
    
    .EXAMPLE
        
        $IsVMZonal = Test-AzVMIsZonalVM -ResourceGroupName gor-Zone-Migration  -VirtualMachineName mig-c2
        if($IsVMZonal){
            Write-Host "Virtutal Machine is zonal VM."
        }else{
            Write-Host "Virtutal Machine is not zonal VM."
        }
    
    .LINK
        
    
    .NOTES
        v0.1 - Initial version
    
    #>
    
    #Requires -Modules Az.Compute
    #Requires -Version 5.1
    
        [CmdletBinding()]
        param(
            
            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            [string]$ResourceGroupName,
                  
            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            [string] $VirtualMachineName
        )
    
        BEGIN{        
              
        }
        
        PROCESS{
            try{   
               
               # get VM and check existance
               $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VirtualMachineName -ErrorAction Stop   
               
               $Zone = $VM.Zones
               
               if($Zone -eq $Null){
                    return $False           
               }else{
                    return $True
               }                                     
            }
            catch{
               Write-Error  $_.Exception.Message           
           }
    
        }
    
        END {}
    }
    

    
    
function Get-AzVMStopAnswer {
<#
        .SYNOPSIS
           Get-AzVMStopAnswer gets an asnwer to stop or not the VM.
        
        .DESCRIPTION
            Get-AzVMStopAnswer gets an asnwer to stop or not the VM.
            
        
        .EXAMPLE    
            Get-AzVMStopAnswer -ResourceGroupName gor-Zone-Migration  -VirtualMachineName mig-c2
        
            
        .LINK
            
        
        .NOTES
            v0.1 - Initial version
        
#>
        
#Requires -Modules Az.Compute
#Requires -Version 5.1
        
    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
                
        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VirtualMachineName
    )

    BEGIN{        
            
    }
    
    PROCESS{
        try{   
            
            write-host ""
            write-host  "Virtual machine '$VirtualMachineName' in the resource group '$ResourceGroupName' will be stopped. Do you want to continue?" 
            $Answer = Read-Host "[Y] Yes  [N] No  (default is "Y") "

            switch ($Answer) {
                'Y'   { $return = $True  }
                'y'   { $return = $True  }
                'Yes' { $return = $True  }
                'yes' { $return = $True  }
                'N'   { $return = $False }
                'n'   { $return = $False }
                'No'  { $return = $False }
                'no'  { $return = $False }
                Default {$return = $True}                       
            }
            
            return $return           
                                                
        }
        catch{
            Write-Error  $_.Exception.Message           
        }

    }

    END {}
}
        
function Get-AzVMDeleteAnswer {
    <#
            .SYNOPSIS
            Get-AzVMDeleteAnswer gets an asnwer to confirm deletion of the VM.
            
            .DESCRIPTION
            Get-AzVMDeleteAnswer gets an asnwer to confirm deletion of the VM.                
            
            .EXAMPLE    
            Get-AzVMDeleteAnswer -ResourceGroupName gor-Zone-Migration  -VirtualMachineName mig-c2
                            
            .LINK                
            
            .NOTES
                v0.1 - Initial version
            
    #>
            
    #Requires -Modules Az.Compute
    #Requires -Version 5.1
            
        [CmdletBinding()]
        param(
            
            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            [string] $ResourceGroupName,
                    
            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            [string] $VirtualMachineName
        )
    
        BEGIN{        
                
        }
        
        PROCESS{
            try{   
                
                write-host ""
                write-host  "Virtual machine '$VirtualMachineName' in the resource group '$ResourceGroupName' will be deleted. Do you want to continue?" 
                $Answer = Read-Host "[Y] Yes  [N] No  (default is "Y") "
    
                switch ($Answer) {
                    'Y'   { $return = $True  }
                    'Yes' { $return = $True  }
                    'yes' { $return = $True  }
                    'N'   { $return = $False }
                    'No'  { $return = $False }
                    'no'  { $return = $False }
                    Default {$return = $True}                       
                }
                
                return $return           
                                                    
            }
            catch{
                Write-Error  $_.Exception.Message           
            }
    
        }
    
        END {}
    }
            

function Get-Answer {
    <#
            .SYNOPSIS
            Get-Answer gets an asnwer.
            
            .DESCRIPTION
            Get-Answer gets an asnwer.
            
            .EXAMPLE    
            Get-Answer "Do you really want to do XYZ?"
                            
            .LINK                
            
            .NOTES
                v0.1 - Initial version
            
    #>
            
    #Requires -Modules Az.Compute
    #Requires -Version 5.1
            
        [CmdletBinding()]
        param(
            
            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            [string] $TextQuestion
                    
            
        )
    
        BEGIN{        
                
        }
        
        PROCESS{
            try{   
                
                write-host ""
                write-host  $TextQuestion
                $Answer = Read-Host "[Y] Yes  [N] No  (default is "Y") "
                write-host ""

    
                switch ($Answer) {
                    'Y'   { $return = $True  }
                    'Yes' { $return = $True  }
                    'yes' { $return = $True  }
                    'N'   { $return = $False }
                    'No'  { $return = $False }
                    'no'  { $return = $False }
                    Default {$return = $True}                       
                }
                
                return $return           
                                                    
            }
            catch{
                Write-Error  $_.Exception.Message           
            }
    
        }
    
        END {}
}
            
    
function Get-AzSAPApplicationServerStopAnswer {
<#
        .SYNOPSIS
        Get-AzSAPApplicationServerStopAnswer gets an asnwer to confirm SAP application server stop.
        
        .DESCRIPTION
        Get-AzSAPApplicationServerStopAnswer gets an asnwer to confirm SAP application server stop.
        
        .EXAMPLE    
        Get-AzSAPApplicationServerStopAnswer -SAPSID "TS1" -SAPInstanceNumber 1 -VMResourceGroupName "ts1-resource-group" -VirtualMachineName "ts1-di-0"
                        
        .LINK                
        
        .NOTES
            v0.1 - Initial version
        
#>
        
#Requires -Modules Az.Compute
#Requires -Version 5.1
        
    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,
    
        [Parameter(Mandatory = $True)]
        [ValidateRange(0, 99)]
        [ValidateLength(1, 2)]
        [string] $SAPInstanceNumber,

        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMResourceGroupName,
                        
        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VirtualMachineName


    )

    BEGIN{        
            
    }
    
    PROCESS{
        try{   
            
            write-host ""
            write-host  "SAP application server with instance number '$SAPInstanceNumber' and SAP SID '$SAPSID' on virtual machine '$VirtualMachineName' in the resource group '$VMResourceGroupName' will be stopped. Do you want to continue?" 
            $Answer = Read-Host "[Y] Yes  [N] No  (default is "Y") "

            switch ($Answer) {
                'Y'   { $return = $True  }
                'Yes' { $return = $True  }
                'yes' { $return = $True  }
                'N'   { $return = $False }
                'No'  { $return = $False }
                'no'  { $return = $False }
                Default {$return = $True}                       
            }
            
            return $return           
                                                
        }
        catch{
            Write-Error  $_.Exception.Message           
        }

    }

    END {}
}
function Move-AzSAPApplicationServerVMToAzureAvaialbilitySetAndOrProximityPlacementGroup {
    <#
    
    .SYNOPSIS
    Cmdlet moves an SAP application server (AS) VM into an Availability Set and/or Proximity Placement Group. SAP AS is gracefully stopped and after VM migration SAP AS is started. 
    
    .DESCRIPTION
    
    Cmdlet moves an SAP application server (AS) VM into an:
    
    - Availability Set
    - Proximity Placement Group
    - Availability Set and Proximity Placement Group
    
    SAP application server (AS) is gracefully stopped and after VM migration SAP AS is started.   
    
    You can use the Cmdlet to:
    
    - Move SAP Application Server VM to new Availability Set 
    
    - Move SAP Application Server VM to new Availability Set and Proximity Placement Group:
    
        - It can be used in Azure Zones context, where you move SAP Application Server to Zone.
            One group of SAP Application Servers are indirectly part of Zone1 (via AvSet1 and PPGZone1), and other part of  SAP Application Servers are indirectly part of Zone2 (via AvSet2 and PPGZone2).
            First anchor VM (this is DBMS VM) is already deployed in a Zone and same Proximity Placement Group
    
        - It can be used to move an SAP Application Server from current AvSet1 and PPGZone1 to AvSet2 and PPGZone2, e.g. indirectly from Zone1 to Zone2.
            First anchor VM (this is DBMS VM) is already deployed in a Zone2 and same Proximity Placement Group 2 (PPGZone2).
    
        - It can be used in non-Zonal context, where group of SAP Application Servers are part of new Av Set and Proximity Placement Group, together with the SAP ASCS and DB VM that are part of one SAP SID.
    
    - Group SAP Application Server VM to Proximity Placement Group
    
    The Cmdlet deletes the VM definition and recreates it preserving networking and storage configuration.        
    
    There is no need to reinstall the operating system.
    
    VM can be with Windows or Linux OS.
    
    IMPORTANT: The Cmdlet does not preserve VM extensions.  
                Also, the Cmdlet does not support VMs with public IP addresses.
                Zonal VMs are not supported, because you cannot combine Availability Set and Zone. 
                Availability Set and VM must be members of the same Azure resource group.
                Proximity Placement Group can be member of some other resource group.
    
    MORE INFO:
        - SAP workload configurations with Azure Availability Zones : https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-ha-availability-zones
        - Regions and Availability Zones in Azure: https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-ha-availability-zones
    
            
    .PARAMETER SAPSID
    SAP SID
    
    .PARAMETER SAPInstanceNumber
    SAP Instance Number to connect    
    
    .PARAMETER SIDADMUserCredential
    SAP <sid>adm user name and password. Need ONLY on WIndows.
    
    .PARAMETER PathToSAPControl
    Full path to SAP Control executable. Need ONLY on WIndows.
    
    .PARAMETER SoftShutdownTimeInSeconds
    Soft / gracefull shutdown time for SAP application server to stop. Deafult is 300 sec.
    
    .PARAMETER SAPApplicationServerStartWaitTimeInSeconds
    Time to wait for SAP application server to start aftre VM is migrated. Deafult is 300 sec.
    
    .PARAMETER PrintExecutionCommand
    If set to $True, it will print execution command.
    
    .PARAMETER VMResourceGroupName 
    Resource Group Name of the VM and Availability Set.
        
    .PARAMETER VirtualMachineName 
    Virtual Machine Name name. 
    
    .PARAMETER AvailabilitySetName
    Availability Set Name
    
    .PARAMETER PPGResourceGroupName
    Resource group name of the Proximity Placement Group
    
    .PARAMETER ProximityPlacementGroupName
    Proximity Placement Group Name
    
    .PARAMETER DoNotCopyTags
    Switch paramater. If specified, VM tags will NOT be copied.
    
    .PARAMETER NewVMSize
    If NewVMSize is specified , VM will be set to a new VM size. Otherwise, original VM size will be used.
    
    .PARAMETER Force
    Forces the command to run without asking for user confirmation. 
    If not set, user will be asked for confirmation to:
        - Stop SAP application server
        - Stop VM
        - Recreate VM
    
    .EXAMPLE
        # Move SAP applictaion sever with LINUX VM
        # you will need to confirm stopping of SAP application server, stopping of VM, and VM deletion. 
        
        $SAPSID = "TS1"
        $SAPInstanceNumber = 3
        $SAPApplicationServerGracefullSoftShutdownTimeInSeconds = 600
        $VMResourceGroupName = "gor-linux-eastus2"
        $VirtualMachineName = "ts2-di2"
        $AvailabilitySetName=  "TS1-AV-SET-ZONE2"
        $PPGResourceGroupName = "gor-linux-eastus2-2" 
        $ProximityPlacementGroupName = "TS1-PPG-Zone2"

        Move-AzSAPApplicationServerVMToAzureAvaialbilitySetAndOrProximityPlacementGroup -SAPSID $SAPSID -SAPInstanceNumber $SAPInstanceNumber  -SoftShutdownTimeInSeconds $SAPApplicationServerGracefullSoftShutdownTimeInSeconds -VMResourceGroupName $VMResourceGroupName -VirtualMachineName $VirtualMachineName -AvailabilitySetName $AvailabilitySetName  -PPGResourceGroupName $PPGResourceGroupName -ProximityPlacementGroupName $ProximityPlacementGroupName

    .EXAMPLE
        # Move SAP applictaion sever with LINUX VM
        # As '-Force' swith parameter is used, user will not be asked for any confirmation
        
        $SAPSID = "TS1"
        $SAPInstanceNumber = 3
        $SAPApplicationServerGracefullSoftShutdownTimeInSeconds = 600
        $VMResourceGroupName = "gor-linux-eastus2"
        $VirtualMachineName = "ts2-di2"
        $AvailabilitySetName=  "TS1-AV-SET-ZONE2"
        $PPGResourceGroupName = "gor-linux-eastus2-2" 
        $ProximityPlacementGroupName = "TS1-PPG-Zone2"

        Move-AzSAPApplicationServerVMToAzureAvaialbilitySetAndOrProximityPlacementGroup -SAPSID $SAPSID -SAPInstanceNumber $SAPInstanceNumber  -SoftShutdownTimeInSeconds $SAPApplicationServerGracefullSoftShutdownTimeInSeconds -VMResourceGroupName $VMResourceGroupName -VirtualMachineName $VirtualMachineName -AvailabilitySetName $AvailabilitySetName  -PPGResourceGroupName $PPGResourceGroupName -ProximityPlacementGroupName $ProximityPlacementGroupName -Force

    
    .EXAMPLE
        # Move SAP applictaion sever with Windows VM
        # As '-Force' swith parameter is used, user will not be asked for any confirmation
    
        $SAPSID = "PR2"
        $SIDADM = $SAPSID.ToLower() + "adm"
        $SAPSIDADMUserCred = Get-Credential -UserName $SIDADM -Message 'Enter Password:'


        $SAPInstanceNumber = 2
        $SAPApplicationServerGracefullSoftShutdownTimeInSeconds = 600
        $FullPathToSAPControl = "C:\usr\sap\PR2\D02\exe\sapcontrol.exe"

        $VMResourceGroupName = "gor-linux-eastus2-2"
        $VirtualMachineName = "pr2-di-1"
        $AvailabilitySetName=  "PR2-AvSet-Zone3"
        $PPGResourceGroupName = "gor-linux-eastus2"
        $ProximityPlacementGroupName = "PR2-PPG_Zone3" 

        Move-AzSAPApplicationServerWindowsVMToAzureAvaialbilitySetAndOrProximityPlacementGroup -SAPSID $SAPSID -SAPInstanceNumber $SAPInstanceNumber -SIDADMUserCredential $SAPSIDADMUserCred -PathToSAPControl $FullPathToSAPControl -SoftShutdownTimeInSeconds $SAPApplicationServerGracefullSoftShutdownTimeInSeconds -VMResourceGroupName $VMResourceGroupName -VirtualMachineName $VirtualMachineName -AvailabilitySetName $AvailabilitySetName  -PPGResourceGroupName $PPGResourceGroupName -ProximityPlacementGroupName $ProximityPlacementGroupName -Force

    
    .LINK
        https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-ha-availability-zones    
    
    .NOTES
        v0.1 - Initial version
    
    #>
    
    #Requires -Modules Az.Compute
    #Requires -Version 5.1
    
            [CmdletBinding()]
            param(            
                
                [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
                [ValidateLength(3, 3)]
                [string] $SAPSID,
            
                [Parameter(Mandatory = $True)]
                [ValidateRange(0, 99)]
                [ValidateLength(1, 2)]
                [string] $SAPInstanceNumber,

                [Parameter(Mandatory=$False)]
                [ValidateNotNull()]
                [System.Management.Automation.PSCredential]
                [System.Management.Automation.Credential()]
                $SIDADMUserCredential,                  
        
                [Parameter(Mandatory = $False)]
                [ValidateNotNullOrEmpty()] 
                [string] $PathToSAPControl,
                
                [Parameter(Mandatory = $False)] 
                [int] $SoftShutdownTimeInSeconds = "300",
    
                [Parameter(Mandatory = $False)] 
                [int] $SAPApplicationServerStartWaitTimeInSeconds = "300",
        
                [Parameter(Mandatory = $False)] 
                [bool] $PrintExecutionCommand = $False,
                
                [Parameter(Mandatory=$True)]
                [ValidateNotNullOrEmpty()]        
                [string] $VMResourceGroupName,
                                
                [Parameter(Mandatory=$True)]
                [ValidateNotNullOrEmpty()]        
                [string] $VirtualMachineName,
                                                
                [Parameter(Mandatory=$False)]
                [string] $AvailabilitySetName,
        
                [Parameter(Mandatory=$False)]
                [string] $PPGResourceGroupName,
                    
                [Parameter(Mandatory=$False)]
                [string] $ProximityPlacementGroupName,
                    
                [switch] $DoNotCopyTags,
        
                [Parameter(Mandatory=$False)]
                [string] $NewVMSize,
        
                [switch] $Force
            )
        
            BEGIN{        
                $ProximityPlacementGroupExist = $False    
            }
            
            PROCESS{
                try{                  
        
                    # Check if resource group exists. If $False exit
                    Confirm-AzResoureceGroupExist -ResourceGroupName $VMResourceGroupName             
        
                    # Check if VM. If $False exit
                    Write-Host
                    Confirm-AzVMExist -ResourceGroupName $VMResourceGroupName -VMName $VirtualMachineName            
        
                    $OSType = Get-AzVMOSType -VMName $VirtualMachineName -ResourceGroupName $VMResourceGroupName                
    
                    if ($OSType -eq "Windows") {                              
                        Move-AzSAPApplicationServerWindowsVMToAzureAvaialbilitySetAndOrProximityPlacementGroup -SAPSID $SAPSID -SAPInstanceNumber $SAPInstanceNumber  -SIDADMUserCredential $SIDADMUserCredential -PathToSAPControl $PathToSAPControl -SoftShutdownTimeInSeconds $SoftShutdownTimeInSeconds -SAPApplicationServerStartWaitTimeInSeconds $SAPApplicationServerStartWaitTimeInSeconds -PrintExecutionCommand $PrintExecutionCommand -VMResourceGroupName $VMResourceGroupName -VirtualMachineName $VirtualMachineName -AvailabilitySetName $AvailabilitySetName -PPGResourceGroupName $PPGResourceGroupName -ProximityPlacementGroupName $ProximityPlacementGroupName -NewVMSize $NewVMSize -DoNotCopyTags:$DoNotCopyTags -Force:$Force
                    }else{
                        # Linux
                        Move-AzSAPApplicationServerLinuxVMToAzureAvaialbilitySetAndOrProximityPlacementGroup   -SAPSID $SAPSID -SAPInstanceNumber $SAPInstanceNumber -SoftShutdownTimeInSeconds $SoftShutdownTimeInSeconds -SAPApplicationServerStartWaitTimeInSeconds $SAPApplicationServerStartWaitTimeInSeconds -PrintExecutionCommand $PrintExecutionCommand -VMResourceGroupName $VMResourceGroupName -VirtualMachineName $VirtualMachineName -AvailabilitySetName $AvailabilitySetName -PPGResourceGroupName $PPGResourceGroupName -ProximityPlacementGroupName $ProximityPlacementGroupName -NewVMSize $NewVMSize -DoNotCopyTags:$DoNotCopyTags -Force:$Force   
                    }
                }
                catch{
                    Write-Error  $_.Exception.Message           
                }
        
            }
        
            END {}
        }            
    
    ###
function Move-AzSAPApplicationServerLinuxVMToAzureAvaialbilitySetAndOrProximityPlacementGroup {
    <#
    .SYNOPSIS
        Cmdlet moves an SAP application server (AS) on Linux VM into an Availability Set and/or Proximity Placement Group. SAP AS is gracefully stopped and after VM migration SAP AS is started. 
    
    .DESCRIPTION
        Cmdlet moves an SAP application server (AS) on Linux VM into an Availability Set and/or Proximity Placement Group. SAP AS is gracefully stopped and after VM migration SAP AS is started. This functionality should be called from cmdlet Move-AzSAPApplicationServerVMToAzureAvaialbilitySetAndOrProximityPlacementGroup.
            
    .PARAMETER SAPSID
    SAP SID

    .PARAMETER SAPInstanceNumber
    SAP Instance Number to connect    
    
    .PARAMETER SoftShutdownTimeInSeconds
    Soft / gracefull shutdown time for SAP application server to stop. Deafult is 300 sec.

    .PARAMETER SAPApplicationServerStartWaitTimeInSeconds
    Time to wait for SAP application server to start aftre VM is migrated. Deafult is 300 sec.

    .PARAMETER PrintExecutionCommand
    If set to $True, it will print execution command.

    .PARAMETER VMResourceGroupName 
    Resource Group Name of the VM and Availability Set.
        
    .PARAMETER VirtualMachineName 
    Virtual Machine Name name. 

    .PARAMETER AvailabilitySetName
    Availability Set Name

    .PARAMETER PPGResourceGroupName
    Resource group name of the Proximity Placement Group

    .PARAMETER ProximityPlacementGroupName
    Proximity Placement Group Name

    .PARAMETER DoNotCopyTags
    Switch paramater. If specified, VM tags will NOT be copied.

    .PARAMETER NewVMSize
    If NewVMSize is specified , VM will be set to a new VM size. Otherwise, original VM size will be used.

    .PARAMETER Force
    Forces the command to run without asking for user confirmation. 
    If not set, user will be asked for confirmation to:
    - Stop SAP application server
    - Stop VM
    - Recreate VM
    
    .LINK
        
    .NOTES
        v0.1 - Initial version
    
    #>
    
    #Requires -Modules Az.Compute
    #Requires -Version 5.1
    
        [CmdletBinding()]
        param(            
            
            [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
            [ValidateLength(3, 3)]
            [string] $SAPSID,
        
            [Parameter(Mandatory = $True)]
            [ValidateRange(0, 99)]
            [ValidateLength(1, 2)]
            [string] $SAPInstanceNumber,
            
            [Parameter(Mandatory = $False)] 
            [int] $SoftShutdownTimeInSeconds = "300",

            [Parameter(Mandatory = $False)] 
            [int] $SAPApplicationServerStartWaitTimeInSeconds = "300",
    
            [Parameter(Mandatory = $False)] 
            [bool] $PrintExecutionCommand = $False,
            
            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            [string] $VMResourceGroupName,
                            
            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            [string] $VirtualMachineName,
                                            
            [Parameter(Mandatory=$False)]
            [string] $AvailabilitySetName,
    
            [Parameter(Mandatory=$False)]              
            [string] $PPGResourceGroupName,
                
            [Parameter(Mandatory=$False)]
            [string] $ProximityPlacementGroupName,
                
            [switch] $DoNotCopyTags,
    
            [Parameter(Mandatory=$False)]
            [string] $NewVMSize,
    
            [switch] $Force            
        )
    
        BEGIN{        
            $ProximityPlacementGroupExist = $False    
        }
        
        PROCESS{
            try{                                  
            
                Write-Host
                Write-WithTime_Using_WriteHost "Virtual machine '$VirtualMachineName' is Linux machine."
                                
                $VMIsRunning = Test-AzVMIsStarted -ResourceGroupName  $VMResourceGroupName -VMName $VirtualMachineName                       

                # Stop SAP Application server
                if ($VMIsRunning -eq $True) {
                    # Get SAP System Status
                    Write-Host
                    Write-WithTime_Using_WriteHost "Getting SAP system instances and status ...."
                    Write-Host            
                    Get-AzSAPSystemStatusLinux  -ResourceGroupName $VMResourceGroupName -VMName $VirtualMachineName -InstanceNumberToConnect $SAPInstanceNumber -SAPSID $SAPSID -PrintExecutionCommand $PrintExecutionCommand -PrintOutputWithWriteHost
                    
                    # Stop SAP application server
                    $ToStopSAPApplicationServer = $true
                    if(-not $Force){
                        Write-Host
                        $ToStopSAPApplicationServer = Get-AzSAPApplicationServerStopAnswer -SAPSID $SAPSID -SAPInstanceNumber $SAPInstanceNumber -VMResourceGroupName $VMResourceGroupName -VirtualMachineName $VirtualMachineName 
                    }
                
                    if($ToStopSAPApplicationServer){                    
                        Write-Host                    
                        Stop-AzSAPApplicationServerLinux  -ResourceGroupName $VMResourceGroupName -VMName $VirtualMachineName -SAPInstanceNumber $SAPInstanceNumber -SAPSID $SAPSID -SoftShutdownTimeInSeconds $SoftShutdownTimeInSeconds -PrintExecutionCommand $PrintExecutionCommand -PrintOutputWithWriteHost                                                

                    }else {                        
                        Return  
                    }     

                    # Get SAP System Status
                    Write-Host
                    Write-WithTime_Using_WriteHost "Getting SAP system instances and status after SAP application server stop ...."
                    Write-Host            
                    Get-AzSAPSystemStatusLinux  -ResourceGroupName $VMResourceGroupName -VMName $VirtualMachineName -InstanceNumberToConnect $SAPInstanceNumber -SAPSID $SAPSID -PrintExecutionCommand $PrintExecutionCommand -PrintOutputWithWriteHost                         
                }
                
                # Move VM to Av Set / PPG               
                $ret = Move-AzVMToAvailabilitySetAndOrProximityPlacementGroup -VMResourceGroupName $VMResourceGroupName -VirtualMachineName $VirtualMachineName -AvailabilitySetName $AvailabilitySetName -PPGResourceGroupName $PPGResourceGroupName -ProximityPlacementGroupName $ProximityPlacementGroupName -DoNotCopyTags:$DoNotCopyTags -NewVMSize $NewVMSize -Force:$Force -ErrorAction Stop                
                
                # Exit 
                if($null -eq $ret ){                                                        
                    return
                }               

                # Start VM
                Write-Host
                Write-WithTime_Using_WriteHost "Starting VM '$VirtualMachineName' in Azure Resource Group '$VMResourceGroupName' ..."
                Start-AzVM  -ResourceGroupName $VMResourceGroupName -Name $VirtualMachineName -WarningAction "SilentlyContinue"

                $VM = Get-AzVM -ResourceGroupName $VMResourceGroupName -Name $VirtualMachineName -Status
                $VMStatus = $VM.Statuses[1].DisplayStatus
                #Write-Host ""
                Write-Host "Virtual Machine '$VirtualMachineName' status: $VMStatus"
           
                # Wait for 180 sec
                Write-Host
                Write-WithTime_Using_WriteHost  "Waiting for 180 seconds to start operating system SAP services ...."
                Start-Sleep 180   
                                    
                Write-Host
                Start-AzSAPApplicationServerLinux -ResourceGroupName $VMResourceGroupName -VMName $VirtualMachineName -SAPInstanceNumber $SAPInstanceNumber -SAPSID $SAPSID -WaitTime $SAPApplicationServerStartWaitTimeInSeconds  -PrintExecutionCommand $PrintExecutionCommand 

                # Get SAP System Status
                Write-Host
                Write-WithTime_Using_WriteHost "Getting SAP system instances and status ...."
                Write-Host            
                Get-AzSAPSystemStatusLinux  -ResourceGroupName $VMResourceGroupName -VMName $VirtualMachineName -InstanceNumberToConnect $SAPInstanceNumber -SAPSID $SAPSID -PrintExecutionCommand $PrintExecutionCommand     
                
            }
            catch{
                Write-Error  $_.Exception.Message           
            }
    
        }
    
        END {}
}            

function Move-AzSAPApplicationServerWindowsVMToAzureAvaialbilitySetAndOrProximityPlacementGroup {
    <#
    .SYNOPSIS
        Cmdlet moves an SAP application server (AS) on Windows VM into an Availability Set and/or Proximity Placement Group. SAP AS is gracefully stopped and after VM migration SAP AS is started. 
    
    .DESCRIPTION
        Cmdlet moves an SAP application server (AS) on Windows VM into an Availability Set and/or Proximity Placement Group. SAP AS is gracefully stopped and after VM migration SAP AS is started. This functionality should be called from cmdlet Move-AzSAPApplicationServerVMToAzureAvaialbilitySetAndOrProximityPlacementGroup.
    
    .PARAMETER SAPSID
    SAP SID

    .PARAMETER SAPInstanceNumber
    SAP Instance Number to connect    

    .PARAMETER SAPsidadmUserPassword
    SAP <sid>adm user password. Need ONLY on WIndows.

    .PARAMETER PathToSAPControl
    Full path to SAP Control executable. Need ONLY on WIndows.

    .PARAMETER SoftShutdownTimeInSeconds
    Soft / gracefull shutdown time for SAP application server to stop. Deafult is 300 sec.

    .PARAMETER SAPApplicationServerStartWaitTimeInSeconds
    Time to wait for SAP application server to start aftre VM is migrated. Deafult is 300 sec.

    .PARAMETER PrintExecutionCommand
    If set to $True, it will print execution command.

    .PARAMETER VMResourceGroupName 
    Resource Group Name of the VM and Availability Set.
        
    .PARAMETER VirtualMachineName 
    Virtual Machine Name name. 

    .PARAMETER AvailabilitySetName
    Availability Set Name

    .PARAMETER PPGResourceGroupName
    Resource group name of the Proximity Placement Group

    .PARAMETER ProximityPlacementGroupName
    Proximity Placement Group Name

    .PARAMETER DoNotCopyTags
    Switch paramater. If specified, VM tags will NOT be copied.

    .PARAMETER NewVMSize
    If NewVMSize is specified , VM will be set to a new VM size. Otherwise, original VM size will be used.

    .PARAMETER Force
    Forces the command to run without asking for user confirmation. 
    If not set, user will be asked for confirmation to:
    - Stop SAP application server
    - Stop VM
    - Recreate VM            
    
    .LINK
        
    .NOTES
        v0.1 - Initial version
    
    #>
    
    #Requires -Modules Az.Compute
    #Requires -Version 5.1
    
        [CmdletBinding()]
        param(            
            
            [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
            [ValidateLength(3, 3)]
            [string] $SAPSID,
        
            [Parameter(Mandatory = $True)]
            [ValidateRange(0, 99)]
            [ValidateLength(1, 2)]
            [string] $SAPInstanceNumber,

            [Parameter(Mandatory=$True)]
            [ValidateNotNull()]
            [System.Management.Automation.PSCredential]
            [System.Management.Automation.Credential()]
            $SIDADMUserCredential,                    
    
            [Parameter(Mandatory = $False)]
            [ValidateNotNullOrEmpty()] 
            [string] $PathToSAPControl,
            
            [Parameter(Mandatory = $False)] 
            [int] $SoftShutdownTimeInSeconds = "300",

            [Parameter(Mandatory = $False)] 
            [int] $SAPApplicationServerStartWaitTimeInSeconds = "300",
    
            [Parameter(Mandatory = $False)] 
            [bool] $PrintExecutionCommand = $False,
            
            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            [string] $VMResourceGroupName,
                            
            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            [string] $VirtualMachineName,
                                            
            [Parameter(Mandatory=$False)]
            [string] $AvailabilitySetName,
    
            [Parameter(Mandatory=$False)]            
            [string] $PPGResourceGroupName,
                
            [Parameter(Mandatory=$False)]
            [string] $ProximityPlacementGroupName,
                
            [switch] $DoNotCopyTags,
    
            [Parameter(Mandatory=$False)]
            [string] $NewVMSize,
    
            [switch] $Force
        )
    
        BEGIN{        
            $ProximityPlacementGroupExist = $False    
        }
        
        PROCESS{
            try{                                         
                    
                #Write-Verbose "Passed parameters: SAPSID = '$SAPSID' ; SAPInstanceNumber = '$SAPInstanceNumber' ; SAPsidadmUserPassword = '$SAPsidadmUserPassword' ; PathToSAPControl = '$PathToSAPControl' ; SoftShutdownTimeInSeconds = '$SoftShutdownTimeInSeconds' ; SAPApplicationServerStartWaitTimeInSeconds = '$SAPApplicationServerStartWaitTimeInSeconds' ; PrintExecutionCommand = '$PrintExecutionCommand' ; VMResourceGroupName = '$VMResourceGroupName' ; VirtualMachineName = '$VirtualMachineName' ; AvailabilitySetName = '$AvailabilitySetName' ; PPGResourceGroupName = '$PPGResourceGroupName' ; ProximityPlacementGroupName = '$ProximityPlacementGroupName' ; DoNotCopyTags = '$DoNotCopyTags' ; NewVMSize = '$NewVMSize' ; Force = '$Force'"

                # Windows                  
                Write-Host
                Write-WithTime_Using_WriteHost "Virtual machine '$VirtualMachineName' is Windows machine."

                $VMIsRunning = Test-AzVMIsStarted -ResourceGroupName  $VMResourceGroupName -VMName $VirtualMachineName                       

                # Stop SAP Application server
                if ($VMIsRunning -eq $True) {

                    #$SIDADMUser = $SAPSID.ToLower() + "adm"          

                    #$SIDADMUserName = $SIDADMUserCredential.UserName
                    $SAPsidadmUserPassword = $SAPSIDADMUserCred.GetNetworkCredential().Password
                    
                    #if($SAPsidadmUserPassword -eq ""){
                    #    Write-Host
                    #    Write-Error  "On Windows you need to specify '$SIDADMUser' password using '-SAPsidadmUserPassword' parameter." -ErrorAction Stop                    
                    }if ( $PathToSAPControl -EQ "") {
                        Write-Host
                        Write-Error  "On Windows you need to full local path to sapcontrol.exe executable using '-PathToSAPControl' parameter." -ErrorAction Stop
                                        
                    }else{
                        # Get SAP System Status
                        Write-Host
                        Write-WithTime_Using_WriteHost "Getting SAP system instances and status ...."
                        Write-Host                                

                        Get-AzSAPSystemStatusWindows -ResourceGroupName $VMResourceGroupName -VMName $VirtualMachineName -InstanceNumberToConnect $SAPInstanceNumber -SAPSID $SAPSID -PathToSAPControl $PathToSAPControl -SAPSidPwd  $SAPsidadmUserPassword  -PrintExecutionCommand $PrintExecutionCommand -PrintOutputWithWriteHost                    

                        # Stop SAP application server
                        $ToStopSAPApplicationServer = $true
                        if(-not $Force){
                            Write-Host
                            $ToStopSAPApplicationServer = Get-AzSAPApplicationServerStopAnswer -SAPSID $SAPSID -SAPInstanceNumber $SAPInstanceNumber -VMResourceGroupName $VMResourceGroupName -VirtualMachineName $VirtualMachineName 
                        }

                        if($ToStopSAPApplicationServer){                        
                            Write-Host
                            Stop-AzSAPApplicationServerWindows -ResourceGroupName $VMResourceGroupName -VMName $VirtualMachineName -SAPSID $SAPSID -SAPInstanceNumber $SAPInstanceNumber  -PathToSAPControl $PathToSAPControl -SAPSidPwd  $SAPsidadmUserPassword -SoftShutdownTimeInSeconds $SoftShutdownTimeInSeconds -PrintExecutionCommand $PrintExecutionCommand -PrintOutputWithWriteHost   
                        }else {                            
                            Return   
                        }    

                            # Get SAP System Status
                            Write-Host
                            Write-WithTime_Using_WriteHost "Getting SAP system instances and status after SAP application server stop ...."
                            Write-Host                                
    
                            Get-AzSAPSystemStatusWindows -ResourceGroupName $VMResourceGroupName -VMName $VirtualMachineName -InstanceNumberToConnect $SAPInstanceNumber -SAPSID $SAPSID -PathToSAPControl $PathToSAPControl -SAPSidPwd  $SAPsidadmUserPassword  -PrintExecutionCommand $PrintExecutionCommand -PrintOutputWithWriteHost                    
    
                    }
                #}                      

                $ret = Move-AzVMToAvailabilitySetAndOrProximityPlacementGroup -VMResourceGroupName $VMResourceGroupName -VirtualMachineName $VirtualMachineName -AvailabilitySetName $AvailabilitySetName -PPGResourceGroupName $PPGResourceGroupName -ProximityPlacementGroupName $ProximityPlacementGroupName -DoNotCopyTags:$DoNotCopyTags -NewVMSize $NewVMSize -Force:$Force -ErrorAction Stop                

                # Exit 
                if($null -eq $ret ){                                                        
                    return
                }

                # Start VM
                Write-Host
                Write-WithTime_Using_WriteHost "Starting VM '$VirtualMachineName' in Azure Resource Group '$VMResourceGroupName' ..."
                Start-AzVM  -ResourceGroupName $VMResourceGroupName -Name $VirtualMachineName -WarningAction "SilentlyContinue"

                $VM = Get-AzVM -ResourceGroupName $VMResourceGroupName -Name $VirtualMachineName -Status
                $VMStatus = $VM.Statuses[1].DisplayStatus
                #Write-Host ""
                Write-WithTime_Using_WriteHost "Virtual Machine '$VirtualMachineName' status: $VMStatus"

                #Wait for 180 sec
                Write-Host
                Write-WithTime_Using_WriteHost  "Waiting for 300 seconds to start operating system SAP services ...."
                Start-Sleep 300   
                                    
                Write-Host
                Start-AzSAPApplicationServerWindows -ResourceGroupName $VMResourceGroupName -VMName $VirtualMachineName -SAPSID $SAPSID -SAPInstanceNumber $SAPInstanceNumber -PathToSAPControl $PathToSAPControl -SAPSidPwd $SAPsidadmUserPassword -WaitTime $SAPApplicationServerStartWaitTimeInSeconds -PrintExecutionCommand $PrintExecutionCommand 
                        
                # Get SAP System Status
                Write-Host
                Write-WithTime_Using_WriteHost "Getting SAP system instances and status ...."
                Write-Host            
                Get-AzSAPSystemStatusWindows -ResourceGroupName $VMResourceGroupName -VMName $VirtualMachineName -InstanceNumberToConnect $SAPInstanceNumber -SAPSID $SAPSID -PathToSAPControl $PathToSAPControl -SAPSidPwd  $SAPsidadmUserPassword  -PrintExecutionCommand $PrintExecutionCommand -PrintOutputWithWriteHost                    
                        
                
            }
            catch{
                Write-Error  $_.Exception.Message           
            }
    
        }
    
        END {}
    }
                

function Get-AzVMBelongingProximityPlacementGroup {
    <#
    .SYNOPSIS
        Cmdlet is getting list of VMs which belongs to certain Proximity Placement Group (PPG).         
    
    .DESCRIPTION
        Cmdlet is getting list of VMs which belongs to certain Proximity Placement Group (PPG). 
        If PPG do not contain any VM, and no object is returned. 
    
    .PARAMETER ResourceGroupName 
    Resource Group Name of Proximity Placement Group.
        
    .PARAMETER PPGName 
    Proximity Placement Group name. 

    .EXAMPLE    
        Get-AzVMBelongingProximityPlacementGroup -ResourceGroupName gor-zrs-westeurope -PPGName ppg-we-z1
    
    .LINK
    
    .NOTES
        v0.1 - Initial version
    
    #>    
    
        [CmdletBinding()]
        param(
                        
            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            [string] $ResourceGroupName,
            
            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            [string] $PPGName

        )
    
        BEGIN{        
                
        }
        
        PROCESS{
            try{   
                                
                $PPG = Get-AzProximityPlacementGroup -ResourceGroupName $ResourceGroupName -Name $PPGName
                
                $PPGVMsIds =  $PPG.VirtualMachines.Id
                
                foreach ($PPGVMId in $PPGVMsIds) {
                    
                    $obj = New-Object -TypeName psobject

                    $VMResource = Get-AzResource -ResourceId  $PPGVMId
                    $VMName                 = $VMResource.Name
                    $VMResourceGroupName    = $VMResource.ResourceGroupName
                    $VMLocation             = $VMResource.Location
                    $VMId                   = $VMResource.ResourceId

                    $VM = Get-AzVM -ResourceGroupName $VMResourceGroupName -Name $VMName
                    $VMZone = $VM.Zones

                    $obj | add-member  -NotePropertyName "VMName" -NotePropertyValue $VMName 
                    $obj | add-member  -NotePropertyName "VMResourceGroupName" -NotePropertyValue $VMResourceGroupName
                    $obj | add-member  -NotePropertyName "VMLocation" -NotePropertyValue $VMLocation
                    $obj | add-member  -NotePropertyName "VMZone" -NotePropertyValue $VMZone
                    $obj | add-member  -NotePropertyName "VMId" -NotePropertyValue $VMId

                    #Return formated object
                    Write-Output $obj      
                }                                  
            }
            catch{
                Write-Error  $_.Exception.Message           
            }
    
        }
    
        END {}
}

function Test-AzVMHasAzureSharedDisks {
    <#
    .SYNOPSIS
                
    
    .DESCRIPTION
         
    
    .PARAMETER ResourceGroupName 
    
        
    .PARAMETER PPGName 
    

    .EXAMPLE    
        
    
    .LINK
    
    .NOTES
        v0.1 - Initial version
    
    #>    
    
        [CmdletBinding()]
        param(
                        
            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            [string] $ResourceGroupName,
            
            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            [string] $VMName

        )
    
        BEGIN{        
                
        }
        
        PROCESS{
            try{   
                   
                $VMHasSharedDataDisks = $false

                $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName

                # Get the data disks atatched to VM
                $DataDisks =  $VM.StorageProfile.DataDisks

                foreach ($DataDisk in $DataDisks) {
                    $DataDiskId = $DataDisk.ManagedDisk.Id
                   
                    # get info on disk name and RG
                    $DiskInfo = Get-AzResource -ResourceId $DataDiskId
                    $DiskName = $DiskInfo.Name
                    $DiskResourceGroupName = $DiskInfo.ResourceGroupName

                    # Get info on MaxShares - is it Azure shared disk
                    $DetailedDiskInfo = Get-AzDisk -ResourceGroupName $DiskResourceGroupName -DiskName $DiskName                    

                    if ($DetailedDiskInfo.MaxShares -ge 1) {
                        Write-Host
                        Write-WithTime_Using_WriteHost  "Azure VM '$VMName' data disk '$DiskName' is Azure shared disk with MaxShared value of '$($DetailedDiskInfo.MaxShares)'"
                        $VMHasSharedDataDisks = $True
                    }
                }

                return $VMHasSharedDataDisks                        
            }
            catch{
                Write-Error  $_.Exception.Message           
            }
    
        }
    
        END {}
}
Function Move-AzVMVMSS {
<#
    .SYNOPSIS
    Move-AzVMVMSS cmdlet move an VM to an Virtual MachineScale Set (VMSS).     

    .DESCRIPTION
    Move-AzVMVMSS cmdlet move an VM to an Virtual MachineScale Set (VMSS). 
    
    If -AzureZone is specified, VM will be moved also to the zone, and if needed converted to the zonal VM (in case of non-zonal source VM).         

    If -AzureZone is NOT specified, VM will be moved to the non-zone/regional VM. If needed converted to the non-zonal VM (in case of zonal source VM).         
    
    .PARAMETER VMResourceGroupName 
    Virtual Machine Resource Group Name
            
    .PARAMETER VirtualMachineName 
    Virtual Machine Name

    .PARAMETER VMSSGResourceGroupName 
    Virtual MachineScale Set (VMSS)  Resource Group Name

    .PARAMETER VMSSName 
    Virtual MachineScale Set (VMSS) Name

    .PARAMETER FaultDomainNumber 
    Fault Domain Number

    .PARAMETER AzureZone
    Azure zone number - 1, 2 or 3.
    
    .PARAMETER PPGResourceGroupName
    Resource Group Name of the Proximity Placement Group

    .PARAMETER ProximityPlacementGroupName
    Proximity PlacementGroup Name
 
    .PARAMETER DoNotCopyTags
    Switch paramater. If specified, VM tags will NOT be copied.
        
    .PARAMETER Force
    Forces the command to run without asking for user confirmation. 
        
    .EXAMPLE
    # Get Maximum Platform Fault Domain Count in 'West Europe' region.
    $Location = "westeurope"
    Get-AzComputeResourceSku -Location $Location | where {($_.ResourceType -EQ "availabilitySets") -and ($_.Name -eq "Aligned")} | Format-Table @{ Label = "Location";  Expression={$_.LocationInfo.Location}}, @{ Label = "MaximumPlatformFaultDomainCount";  Expression={$_.Capabilities.Value}}

    .EXAMPLE
    # Get Maximum Platform Fault Domain Count in all Azure regions.    
    Get-AzComputeResourceSku  | where {($_.ResourceType -EQ "availabilitySets") -and ($_.Name -eq "Aligned")} | Format-Table @{ Label = "Location";  Expression={$_.LocationInfo.Location}}, @{ Label = "MaximumPlatformFaultDomainCount";  Expression={$_.Capabilities.Value}}

    .EXAMPLE
    # move VM to an VMSS as non-zonal VM in west , with fault domain 3

    # Create VMSS with -PlatformFaultDomainCount = 3
    $RGName = "gor-vmssflex1"
    $VMSSName = "sap-ab1-vmss"
    $Location = "westeurope"

    $vmssConfig = New-AzVmssConfig -Location $Location -PlatformFaultDomainCount 3
    New-AzVmss -ResourceGroupName $RGName -Name $VMSSName -VirtualMachineScaleSet $vmssConfig 

    # move ab1-db VM
    Move-AzVMVMSS -VMResourceGroupName gor-vmssflex1 -VirtualMachineName ab1-db -VMSSGResourceGroupName gor-vmssflex1 -VMSSName sap-ab1-vmss 
    
    .EXAMPLE
    # move VM to an VMSS as non-zonal VM in west , with fault domain 3 and Proximity Placement Group

    $RGName = "gor-vmssflex1"
    $VMSSName = "sap-flex-ppg-pr2"
    $Location = "westeurope"

    $PPGRGName = "gor-vmssflex1"
    $PPGName = "PR2-PPG"

    $PPG = Get-AzProximityPlacementGroup -ResourceGroupName $PPGRGName -Name $PPGName

    # Create VMSS with 3 Platform Fault Domains and add it to the -ProximityPlacementGroup
    $vmssConfig = New-AzVmssConfig -Location $Location -PlatformFaultDomainCount 3 -ProximityPlacementGroupId $PPG.Id
    $VMSS = New-AzVmss -ResourceGroupName $RGName -VMScaleSetName $VMSSName  -VirtualMachineScaleSet $vmssConfig -Verbose

    # Move VM to the VMSS in fault domain 2, and the PPG
    Move-AzVMVMSS -VMResourceGroupName gor-vmssflex1 -VirtualMachineName testvm3 -VMSSGResourceGroupName $RGName -VMSSName $VMSSName -PPGResourceGroupName $PPGRGName -ProximityPlacementGroupName $PPGName  -FaultDomainNumber 2

    .EXAMPLE
    # move VM to an VMSS and Azure zone

    $RGName = "gor-vmssflex1"
    $VMSSName = "sap-ab2-vmss"
    $Location = "westeurope"

    # Create zonal for zones 1, 2 and 3.  VMSS -PlatformFaultDomainCount is ALWAYS 1
    $vmssConfig = New-AzVmssConfig -Location $Location -PlatformFaultDomainCount 1 -Zone @(1,2,3)  
    $VMSS = New-AzVmss -ResourceGroupName $RGName -Name $VMSSName -VirtualMachineScaleSet $vmssConfig 

    # move ab2-db VM to VMSS sap-ab2-vmss and zone 3
    Move-AzVMVMSS -VMResourceGroupName gor-vmssflex1 -VirtualMachineName ab2-db -VMSSGResourceGroupName gor-vmssflex1 -VMSSName sap-ab2-vmss -AzureZone 3    
    
    .LINK        
    
    .NOTES
        v0.1 - Initial version
    
#>
    
    #Requires -Modules Az.Compute
    #Requires -Version 5.1
    
        
            [CmdletBinding()]
            param(
                                
                [Parameter(Mandatory, ParameterSetName="Regional")]
                [Parameter(Mandatory, ParameterSetName="RegionalAndPPG")]
                [Parameter(Mandatory, ParameterSetName="Zonal")]
                [ValidateNotNullOrEmpty()]        
                [string] $VMResourceGroupName,
                      
                [Parameter(Mandatory, ParameterSetName="Regional")]
                [Parameter(Mandatory, ParameterSetName="RegionalAndPPG")]
                [Parameter(Mandatory, ParameterSetName="Zonal")]                
                [ValidateNotNullOrEmpty()]        
                [string] $VirtualMachineName,
                                                       
                [Parameter(Mandatory, ParameterSetName="Regional")]
                [Parameter(Mandatory, ParameterSetName="RegionalAndPPG")]
                [Parameter(Mandatory, ParameterSetName="Zonal")]                     
                [string] $VMSSGResourceGroupName,   

                [Parameter(Mandatory, ParameterSetName="Regional")]
                [Parameter(Mandatory, ParameterSetName="RegionalAndPPG")]
                [Parameter(Mandatory, ParameterSetName="Zonal")]     
                [string] $VMSSName,   
                                                
                [Parameter(Mandatory, ParameterSetName="RegionalAndPPG")]
                [string] $PPGResourceGroupName,
                        
                [Parameter(Mandatory, ParameterSetName="RegionalAndPPG")]
                [string] $ProximityPlacementGroupName,
                
                [Parameter(Mandatory, ParameterSetName="Regional")]   
                [Parameter(Mandatory, ParameterSetName="RegionalAndPPG")]
                [ValidateNotNullOrEmpty()]             
                [int] $FaultDomainNumber,
                                
                [Parameter(Mandatory, ParameterSetName="Zonal")]    
                [ValidateRange(1,3)]
                [int] $AzureZone,
    
                [Parameter(ParameterSetName="Regional")]
                [Parameter(ParameterSetName="RegionalAndPPG")]
                [Parameter(ParameterSetName="Zonal")]                     
                [switch] $DoNotCopyTags,       

                [Parameter(ParameterSetName="Regional")]
                [Parameter(ParameterSetName="RegionalAndPPG")]
                [Parameter(ParameterSetName="Zonal")]                                     
                [switch] $Force                
            )
        
            BEGIN{
            }
            
            PROCESS{
                try{                                             
                    
                    if($AzureZone){                        
                        Write-WithTime_Using_WriteHost  "Starting migration of Virtual Machine '$VirtualMachineName' to the Virtual Machine Scale Set '$VMSSName' and Azure zone '$AzureZone' ..." -AppendEmptyLine
                    }else{                        
                        Write-WithTime_Using_WriteHost  "Starting migration of Virtual Machine '$VirtualMachineName' to the Virtual Machine Scale Set '$VMSSName' ..." -AppendEmptyLine
                    }
                    
                    # Check if VM. If $False exit
                    #Write-Host
                    Confirm-AzVMExist -ResourceGroupName $VMResourceGroupName -VMName $VirtualMachineName

                    # get VMSS Flex
                    #Write-Host
                    Write-WithTime_Using_WriteHost  "Getting Virtual Machine Scale Set '$VMSSName' in Azure resource group '$VMSSGResourceGroupName' ..." -PrependEmptyLine -AppendEmptyLine
                    $VmssFlex = Get-AzVmss -ResourceGroupName $VMSSGResourceGroupName -VMScaleSetName $VMSSName -ErrorAction Stop

                    # Check if VMSS is Flex type
                    $VMSSIsFlexType = Test-AzVMSSIsFlexType -VMSSGResourceGroupName $VMSSGResourceGroupName  -VMSSName $VMSSName 
                    if($VMSSIsFlexType){                    
                        Write-WithTime_Using_WriteHost  "Orchestration mode of the Virtual Machine Scale Set '$VMSSName' in Azure resource group '$VMSSGResourceGroupName' is 'Flexible'. This is supported for SAP deplyments." 
                    }else{
                        Throw "Orchestration mode of the Virtual Machine Scale Set '$VMSSName' in Azure resource group '$VMSSGResourceGroupName' is not 'Flexible'. This is NOT suported for SAP deplyments. For SAP deplyments you need 'Flexible' orchestration mode."
                    }
                
                    Write-WithTime_Using_WriteHost  "Starting Virtual Machine '$VirtualMachineName' ..." -PrependEmptyLine -AppendEmptyLine
                    $StartVMStatus = Start-AzVM -ResourceGroupName $VMResourceGroupName -Name $VirtualMachineName -ErrorAction Stop 
                    
                    # Get the VM and check existance                
                    Write-WithTime_Using_WriteHost  "Getting Virtual Machine '$VirtualMachineName' configuration ..." -PrependEmptyLine #-AppendEmptyLine
                    $originalVM = Get-AzVM -ResourceGroupName $VMResourceGroupName -Name $VirtualMachineName -ErrorAction Stop      
                    
                    # CHeck if VM is zonal VM
                    Write-WithTime_Using_WriteHost  "Checking if  Virtual Machine '$VirtualMachineName' is zonal VM ..." -PrependEmptyLine #-AppendEmptyLine
                    $VMIsZonal = Test-AzVMIsZonalVM -ResourceGroupName $VMResourceGroupName  -VirtualMachineName $VirtualMachineName
                    
                    # Check if VM is using Standard Load Balancer
                    $VMIsUsingStandardLoadBalancer =  Test-AzVMLoadbBalancerIsStandard -VMResourceGroupName $VMResourceGroupName -VirtualMachineName $VirtualMachineName
                    if (-not $VMIsUsingStandardLoadBalancer ) {
                        Throw "Virtual machine '$VirtualMachineName' in resource group '$VMResourceGroupName' is configured with Azure load balancer which is NOT Standard . This is NOT supported for Azure Virtual Machine Scale Set. Please convert Azure Load Blancer to standard type before you proceed."
                    }
                    
                    # Azure shared disks are not supported                    
                    Write-WithTime_Using_WriteHost  "Checking if virtual machine '$VirtualMachineName' has Azure shared data disks ... " -AppendEmptyLine
                    $VMHasAzureSharedDisks = Test-AzVMHasAzureSharedDisks -ResourceGroupName  $VMResourceGroupName -VMName $VirtualMachineName
                    if ($VMHasAzureSharedDisks) {
                            Write-Host   
                            Throw "VM '$VirtualMachineName' has Azure shared disk. Azure shared disks are not supported."
                    }else {                            
                            Write-WithTime_Using_WriteHost  "Virtual machine '$VirtualMachineName' has no Azure shared data disks." -AppendEmptyLine
                    }

                    # move to the zonal VM
                    if($AzureZone){                    

                        # Get confiramtion to migrate to the zone
                        if (-not $VMIsZonal) {
                            Write-WithTime_Using_WriteHost  "Virtual Machine '$VirtualMachineName' is not zonal VM." -PrependEmptyLine -AppendEmptyLine

                            $ToContinue = $true               

                            if(-not $Force){
                                Write-Host
                                $ToContinue = Get-Answer "Virtual Machine '$VirtualMachineName' in resource group '$VMResourceGroupName' is not zonal VM. You chose to move VM to the zone VM. VM will be convered to the zonal VM. Do you agree to continue?"    
                            }
                                            
                            if(-not $ToContinue){             
                                Return   
                            }
                            
                        }
                                            
                        # Check if VMSS has PlatformFaultDomainCount = 1
                        if($VmssFlex.PlatformFaultDomainCount -ne 1){
                            Write-Host
                            Throw  "Virtual Machine Scale Set '$VMSSName' in Azure resource group '$VMSSGResourceGroupName' Platform Fault Domain Count is '$($VmssFlex.PlatformFaultDomainCount)'. As you migrate VM to the Azure zone, Platform Fault Domain Count must be set to '1'."
                        }                                                                   

                        # We don't support moving machines with public IPs, since those are zone specific.  
                        foreach ($nic in $originalVM.NetworkProfile.NetworkInterfaces) {
                            $thenic = $nic.id
                            $nicname = $thenic.substring($thenic.LastIndexOf("/")+1)
                            $othernic = Get-AzNetworkInterface -name $nicname -ResourceGroupName $VMResourceGroupName 
                            #Write-Host
                            Write-WithTime_Using_WriteHost "Found Network Card '$nicname' in Azure resource group  '$VMResourceGroupName'." -AppendEmptyLine
                
                            foreach ($ipc in $othernic.IpConfigurations) {
                                $pip = $ipc.PublicIpAddress
                                if ($pip) { 
                                    Throw  "Sorry, machines with public IPs are not supported by this script" 
                                    #exit
                                }
                            }
                        }
            
                        [string] $osType      = $originalVM.StorageProfile.OsDisk.OsType
                        [string] $location    = $originalVM.Location
                        [string] $storageType = $originalVM.StorageProfile.OsDisk.ManagedDisk.StorageAccountType
                        [string] $OSDiskName  = $originalVM.StorageProfile.OsDisk.Name
                        # when non-Zonal disk / VM this value is an empty string
                        [string] $VMDiskZone  = $originalVM.Zones

                        if ($VMDiskZone -eq "") {
                            [bool] $VMIsZonal = $False
                        }else {
                            [bool] $VMIsZonal = $True
                        }

                        $OriginalVMSize =  $originalVM.HardwareProfile.VmSize
                        $VMSize = $OriginalVMSize                                        
                                
                        # Check if VM SKU is available in the desired Azure zone
                        $VMSKUIsAvailableinZone = Test-AzVMSKUZonalAvailability -VMSize $VMSize -location $location -AzureZone $AzureZone
                        if(-not $VMSKUIsAvailableinZone){
                            #exit the cmdlet
                            return
                        }                                      
                        
                        # Check if target zone is configured in VMSS                        
                        $Zones = Get-AzVMSSZones -VMSSName $VMSSName -VMSSGResourceGroupName $VMSSGResourceGroupName

                        if($null -eq $Zones){
                            Throw "Virtual Machine Scale Set '$VMSSName' in Azure resource group '$VMSSGResourceGroupName' has no configured zones! "
                        }else{
                            $foundZone = $false
                            foreach($zone in $Zones){
                                if($zone -eq $AzureZone){
                                    $foundZone = $True
                                    
                                    Write-WithTime_Using_WriteHost "Desired target Azure zone '$AzureZone' is configured in Virtual Machine Scale Set '$VMSSName' in Azure resource group '$VMSSGResourceGroupName'." -PrependEmptyLine 
                                    break
                                }
                            }
                            if (-not $foundZone) {
                                Throw "Desired target Azure $AzureZone' NOT configured in Virtual Machine Scale Set '$VMSSName' in Azure resource group '$VMSSGResourceGroupName'! Virtual Machine Scale Set '$VMSSName' is configured with these zones: $Zones"
                            }

                        }

                        # Shutdown the original VM
                        $ToStop = $true               

                        if(-not $Force){
                            Write-Host
                            $ToStop = Get-AzVMStopAnswer -VirtualMachineName $VirtualMachineName -ResourceGroupName $VMResourceGroupName
                        }
                                    
                        if($ToStop){             
                                Write-Host               
                                Write-WithTime_Using_WriteHost  "Stopping Virtual Machine '$VirtualMachineName' in resource group '$VMResourceGroupName' ..." -PrependEmptyLine -AppendEmptyLine
                                Stop-AzVM -ResourceGroupName $VMResourceGroupName -Name $VirtualMachineName -force -ErrorAction Stop 
                        }else {
                                # Exit
                                Return   
                        }
                                    
                        # Export original VM configuration
                        Write-Host
                        Export-VMConfigurationToJSONFile -VM  $originalVM      
                                            
                        Write-WithTime_Using_WriteHost "Configuring Virtual Machine to use Azure Zone '$AzureZone' ..." -PrependEmptyLine 
                        #$newVM = New-AzVMConfig -VMName $VirtualMachineName -VMSize $VmSize -Zone $AzureZone 
                        $newVM = New-AzVMConfig -VMName $VirtualMachineName -VMSize $VMSize  -VmssId $VmssFlex.Id -PlatformFaultDomain $FaultDomainNumber -Zone $AzureZone 

                        #  Snap and copy the os disk               
                        $snapshot = New-AzUniqueNameSnapshot -ResourceGroupName $VMResourceGroupName -Location $location -DiskName $originalVM.StorageProfile.OsDisk.Name -SourceDiskResourceId $originalVM.StorageProfile.OsDisk.ManagedDisk.Id

                        # Create / Copy the exsiting OS Disk with new name
                        Copy-AzUniqueNameDiskFromSnapshot -ResourceGroupName $VMResourceGroupName -Location $location -Snapshot $snapshot -OriginalDiskName $OSDiskName -StorageType $storageType -VMDiskZone $VMDiskZone -DiskNamePosfix "orig"

                        # Do not delete OS and Data disks during the VM deletion - set DeleteOption to 'Detach'
                        Set-AzVMDisksDeleteOption -VM $originalVM -DeleteOption "Detach"                                

                        # Do not delete NIC cards during the VM deletion - Set NIC Cards to 'Detach'
                        Set-AzVMNICsDeleteOption -VM $originalVM -DeleteOption "Detach"                
                        
                        # Remove the original VM -this is a prerequisit to delete orignial OS and data disks
                        $ToDelete = $true

                        if(-not $Force){
                            Write-Host
                            $ToDelete = Get-AzVMDeleteAnswer -VirtualMachineName $VirtualMachineName -ResourceGroupName $VMResourceGroupName
                        }
                        
                        if($ToDelete){
                            Write-Host
                            Write-WithTime_Using_WriteHost  "Removing Virtual Machine '$VirtualMachineName' ..." -AppendEmptyLine                        
                            Remove-AzVM -ResourceGroupName $VMResourceGroupName -Name $VirtualMachineName -force            
                        }else {
                            # Exit
                            Return   
                        }              

                        # Delete Original OS Disk                
                        Write-WithTime_Using_WriteHost  "Removing original OS disk '$osdiskname' ..." -AppendEmptyLine
                        Remove-AzDisk -ResourceGroupName $VMResourceGroupName -DiskName  $osdiskname -Force                                         

                        $newdiskConfig = New-AzDiskConfig -AccountType $storageType -Location $location -CreateOption Copy -SourceResourceId $snapshot.Id -zone $AzureZone
                        $newdiskName = $osdiskname 

                        #Write-Host
                        Write-WithTime_Using_WriteHost  "Creating OS zonal disk '$newdiskName' from snapshot '$($snapshot.Name)' ..." -AppendEmptyLine
                        $newdisk = New-AzDisk -Disk $newdiskConfig -ResourceGroupName $VMResourceGroupName -DiskName $newdiskName                    

                        # Configure new Zonal OS Disk
                        if ($osType -eq "Linux")
                        {                            
                                Write-WithTime_Using_WriteHost "Configuring Linux OS disk '$newdiskName' for Virtual Machine '$VirtualMachineName'... "  -AppendEmptyLine
                                Set-AzVMOSDisk -VM $newVM -CreateOption Attach  -ManagedDiskId $newdisk.Id -Name $newdisk.Name  -Linux -Caching $originalVM.StorageProfile.OsDisk.Caching > $null
                        }
                        if ($osType -eq "Windows")
                        {
                                #Write-Host
                                Write-WithTime_Using_WriteHost "Configuring Windows OS disk '$newdiskName' Virtual Machine '$VirtualMachineName' ... " -AppendEmptyLine
                                Set-AzVMOSDisk -VM $newVM -CreateOption Attach  -ManagedDiskId $newdisk.Id -Name $newdisk.Name  -Windows -Caching $originalVM.StorageProfile.OsDisk.Caching > $null	
                        }
                
                        # Snapshot all of the Data disks, and add to the VM
                        foreach ($disk in $originalVM.StorageProfile.DataDisks)
                        {        
                            $OriginalDataDiskName = $disk.Name

                            #snapshot & copy the data disk
                            $snapshot = New-AzUniqueNameSnapshot -ResourceGroupName $VMResourceGroupName -Location $location -DiskName  $disk.Name -SourceDiskResourceId $disk.ManagedDisk.Id                                                               
                            
                            $diskName = $disk.Name

                            # Create / Copy the exsiting Data disk with a new name
                            Copy-AzUniqueNameDiskFromSnapshot -ResourceGroupName $VMResourceGroupName -Location $location -Snapshot $snapshot -OriginalDiskName $OriginalDataDiskName -StorageType $storageType -VMDiskZone $VMDiskZone -DiskNamePosfix "orig"

                            # Delete Original Data disk
                            Write-Host
                            Write-WithTime_Using_WriteHost  "Removing original data disk '$OriginalDataDiskName' ..." 
                            Remove-AzDisk -ResourceGroupName $VMResourceGroupName -DiskName  $OriginalDataDiskName -Force 
                                                                            
                            $diskConfig = New-AzDiskConfig -AccountType $storageType -Location $location -CreateOption Copy -SourceResourceId $snapshot.Id -zone $AzureZone
                            Write-Host 
                            Write-WithTime_Using_WriteHost  "Creating zonal data disk '$diskName' from snapshot '$($snapshot.Name)' ..." -AppendEmptyLine
                            
                            $newdisk = New-AzDisk -Disk $diskConfig -ResourceGroupName $VMResourceGroupName -DiskName $diskName # > $null
                            
                            Write-WithTime_Using_WriteHost "Configuring data disk '$($newdisk.Name)' , LUN '$($disk.Lun)' for Virtual Machine '$VirtualMachineName' ... " 
        
                            if($disk.WriteAcceleratorEnabled) {
                                
                                Write-WithTime_Using_WriteHost "Adding disk '$($newdisk.Name)' to new VM with enabled Write Accelerator ...  " -AppendEmptyLine
                                Add-AzVMDataDisk -VM $newVM -Name $newdisk.Name -ManagedDiskId $newdisk.Id -Caching $disk.Caching -Lun $disk.Lun -DiskSizeInGB $newdisk.DiskSizeGB -CreateOption Attach -WriteAccelerator  > $null	
                            }else{
                                
                                Write-WithTime_Using_WriteHost "Adding disk '$($newdisk.Name)' to new VM ...  " -AppendEmptyLine
                                Add-AzVMDataDisk -VM $newVM -Name $newdisk.Name -ManagedDiskId $newdisk.Id -Caching $disk.Caching -Lun $disk.Lun -DiskSizeInGB $newdisk.DiskSizeGB -CreateOption Attach > $null	
                            }
                        }
                
                        # Add NIC(s) and keep the same NIC as primary
                        foreach ($nic in $originalVM.NetworkProfile.NetworkInterfaces) {	              
                            
                            Write-WithTime_Using_WriteHost "Configuring '$($nic.Id)' network card to Virtual Machine '$VirtualMachineName'  ..." -AppendEmptyLine
                            if ($nic.Primary -eq "True"){                
                                
                                Write-WithTime_Using_WriteHost "NIC is primary." -AppendEmptyLine
                                Add-AzVMNetworkInterface -VM $newVM -Id $nic.Id -Primary > $null
                            }
                            else{                                            
                                Write-WithTime_Using_WriteHost "NIC is secondary." -AppendEmptyLine
                                Add-AzVMNetworkInterface -VM $newVM -Id $nic.Id > $null
                            }
                        }
        
                        # Copy VM Tags
                        if(-not $DoNotCopyTags){
                            # Copy the Tags
                            Write-Host
                            Write-WithTime_Using_WriteHost "Listing VM '$VirtualMachineName' tags: " -AppendEmptyLine                        
                            $originalVM.Tags
                    
                            Write-Host
                            Write-WithTime_Using_WriteHost "Copy Tags ..." -AppendEmptyLine
                            $newVM.Tags = $originalVM.Tags
                            Write-Host
                            Write-WithTime_Using_WriteHost "Tags copy to new VM definition done. " -AppendEmptyLine
                        }else{            
                            Write-Host
                            Write-WithTime_Using_WriteHost "Skipping copy of VM tags:"    -AppendEmptyLine        
                            
                            $originalVM.Tags
                        }
                        
                        #Configure Boot Diagnostic account
                        if ($originalVM.DiagnosticsProfile.BootDiagnostics.Enabled) {
                            
                            Write-WithTime_Using_WriteHost "Boot diagnostic account is enabled." -AppendEmptyLine
                            
                            # Get Strage URI
                            $StorageUri = $originalVM.DiagnosticsProfile.BootDiagnostics.StorageUri            
                
                            if ($StorageUri -eq $null) {
                                            
                                Write-WithTime_Using_WriteHost "Boot diagnostic URI is empty." -AppendEmptyLine
                                
                                Write-WithTime_Using_WriteHost "Configuring boot diganostic with managed storage account ..."  -AppendEmptyLine            

                                $newVM = Set-AzVMBootDiagnostic -VM $newVM -Enable                                                                             
                
                            }else {
                                
                                $BootDiagnosticURI = $originalVM.DiagnosticsProfile.BootDiagnostics.StorageUri.Split("/")[2]
                                
                                Write-WithTime_Using_WriteHost "Boot diagnostic URI: '$BootDiagnosticURI'." -AppendEmptyLine
                    
                                $staccName = $BootDiagnosticURI.Split(".")[0]
                                
                                Write-WithTime_Using_WriteHost "Extracted storage account name: '$staccName'" -AppendEmptyLine
                                                
                                Write-WithTime_Using_WriteHost "Getting storage account '$staccName'" -AppendEmptyLine
                                $stacc = Get-AzStorageAccount | where-object { $_.StorageAccountName.Contains($staccName) }
                                
                                if($stacc  -eq $null ){
                                    
                                    Write-WithTime "Storage account '$staccName' used for diagonstic account on source VM do not exist. Skipping configuration of boot diagnostic on the new VM." -AppendEmptyLine
                                
                                }else{
            
                                    Write-WithTime_Using_WriteHost "Configuring storage account '$staccName' for VM boot diagnostigs in Azure resource group '$($stacc.ResourceGroupName)' on the new VM ..." -AppendEmptyLine
                                
                                    $newVM = Set-AzVMBootDiagnostic -VM $newVM -Enable -ResourceGroupName $stacc.ResourceGroupName -StorageAccountName $staccName
                                                
                                    Write-WithTime_Using_WriteHost "Configuring storage account '$staccName' for VM boot diagnostigs done." -AppendEmptyLine
                                }
                                
                            }
                        }                         
            
                        # Create the new VM                    
                        Write-WithTime_Using_WriteHost "Recreating Virtual Machine '$VirtualMachineName' as zonal VM in Azure zone '$AzureZone' ..." -AppendEmptyLine
                        New-AzVM -ResourceGroupName $VMResourceGroupName -Location $originalVM.Location -VM $newVM -DisableBginfoExtension # -zone $AzureZone
                
                    #########################################
                    # move to the regional (NON-zonal) VM
                    #########################################

                    }else{
                        
                        $VMSSZones = Get-AzVMSSZones -VMSSName $VMSSName -VMSSGResourceGroupName $VMSSGResourceGroupName
                        if ($VMSSZones -ne $null) {
                            # VMSS is cinfigured for the zones, and VM goes to region - NOT supported
                            Throw "Your Virtual Macine Scale Set (VMSS) '$VMSSName' in resource group  '$VMSSGResourceGroupName' is configured for zonal deployment. You chose to move VM in an non-zonal conetxt. This is not supported. Please chose VMSS that has no configured zones."
                        }

                        # Check PPG
                        if ($ProximityPlacementGroupName) {
                            $ppg = Get-AzProximityPlacementGroup -ResourceGroupName $PPGResourceGroupName -Name $ProximityPlacementGroupName -ErrorAction Stop
        
                            $ProximityPlacementGroupExist = $True
            
                            Write-Host
                            Write-WithTime_Using_WriteHost "Proximity Placement Group '$ProximityPlacementGroupName' in resource group '$PPGResourceGroupName' exist." 
                            
                            # Check if VMSSS  is configured withthe same PPG
                            if ($VmssFlex.ProximityPlacementGroup.Id -ne $ppg.Id) {
                                Write-Host         
                                Throw "Existing Virtual Machine Scale Set '$VMSSName' is not member of Proximity Placement Group '$ProximityPlacementGroupName'. Please configure Virtual Machine Scale Set '$VMSSName' to use Proximity Placement Group '$ProximityPlacementGroupName'. "                    
                            }else{
                                Write-WithTime_Using_WriteHost "Virtual Machine Scale Set '$VMSSName' is configured in appropriate Proximity Placement Group '$ProximityPlacementGroupName'." -PrependEmptyLine    
                            }
                            
                        }                                     

                        # Get confiramtion to migrate to the zone
                        if ($VMIsZonal) {
                            Write-WithTime_Using_WriteHost  "Virtual Machine '$VirtualMachineName' is zonal VM." -PrependEmptyLine -AppendEmptyLine

                            $ToContinue = $true               

                            if(-not $Force){
                                Write-Host
                                $ToContinue = Get-Answer "Virtual Machine '$VirtualMachineName' in resource group '$VMResourceGroupName' is zonal VM. You chose to move VM to the non-zone VM. VM will be converted to the non-zonal VM. Do you agree to continue?"    
                            }
                                            
                            if(-not $ToContinue){             
                                Return   
                            }                            
                        }                    
                                                
                        [string] $osType      = $originalVM.StorageProfile.OsDisk.OsType
                        [string] $location    = $originalVM.Location
                        [string] $storageType = $originalVM.StorageProfile.OsDisk.ManagedDisk.StorageAccountType
                        [string] $OSDiskName  = $originalVM.StorageProfile.OsDisk.Name                    
                        # when non-Zonal disk / VM this value is an empty string
                        [string] $VMDiskZone  = $originalVM.Zones                  

                        # Shutdown the original VM
                        $ToStop = $true

                        if(-not $Force){
                            Write-Host
                            $ToStop = Get-AzVMStopAnswer -VirtualMachineName $VirtualMachineName -ResourceGroupName $VMResourceGroupName
                        }                                        

                        if($ToStop){                        
                            Write-WithTime_Using_WriteHost  "Stopping Virtual Machine '$VirtualMachineName' in resource group '$VMResourceGroupName' ..." -AppendEmptyLine
                            $ReturnStopVM =  Stop-AzVM -ResourceGroupName $VMResourceGroupName -Name $VirtualMachineName -force -ErrorAction Stop 
                            
                            Write-WithTime_Using_WriteHost  "Stopping Virtual Machine '$VirtualMachineName' in resource group '$VMResourceGroupName' stoped." -AppendEmptyLine
                        }elseif (!$ToStop) {                    
                            Return                 
                        }         

                        $OriginalVMSize =  $originalVM.HardwareProfile.VmSize
                        $VMSize =  $originalVM.HardwareProfile.VmSize

                        # We don't support moving machines with public IPs, since those are zone specific.  
                        foreach ($nic in $originalVM.NetworkProfile.NetworkInterfaces) {
                            $thenic = $nic.id
                            $nicname = $thenic.substring($thenic.LastIndexOf("/")+1)
                            $othernic = Get-AzNetworkInterface -name $nicname -ResourceGroupName $VMResourceGroupName 

                            foreach ($ipc in $othernic.IpConfigurations) {
                                $pip = $ipc.PublicIpAddress
                                if ($pip) { 
                                    Throw  "Sorry, machines with public IPs are not supported by this script"                             
                                }
                            }
                        }                     
                                            
                        if ($ProximityPlacementGroupName) {      
                            # If PPG is specified                                        
                            $newVM = New-AzVMConfig -VMName $VirtualMachineName -VMSize $VMSize  -VmssId $VmssFlex.Id -PlatformFaultDomain $FaultDomainNumber -ProximityPlacementGroupId $ppg.Id                                 
                        }else{
                            $newVM = New-AzVMConfig -VMName $VirtualMachineName -VMSize $VMSize  -VmssId $VmssFlex.Id -PlatformFaultDomain $FaultDomainNumber      
                        }
                        
                        # Copy VM Tags
                        if(-not $DoNotCopyTags){
                            # Copy the Tags
                            Write-Host
                            Write-WithTime_Using_WriteHost "Listing VM '$VirtualMachineName' tags: " -AppendEmptyLine                        
                            $originalVM.Tags
                    
                            Write-Host
                            Write-WithTime_Using_WriteHost "Copy Tags ..." -AppendEmptyLine
                            $newVM.Tags = $originalVM.Tags
                            Write-Host
                            Write-WithTime_Using_WriteHost "Tags copy to new VM definition done. " -AppendEmptyLine
                        }else{            
                            Write-Host
                            Write-WithTime_Using_WriteHost "Skipping copy of VM tags:"    -AppendEmptyLine        
                            
                            $originalVM.Tags
                        }

                        if ($VMIsZonal) {
                            #  Snap and copy the os disk               
                            $snapshot = New-AzUniqueNameSnapshot -ResourceGroupName $VMResourceGroupName -Location $location -DiskName $originalVM.StorageProfile.OsDisk.Name -SourceDiskResourceId $originalVM.StorageProfile.OsDisk.ManagedDisk.Id

                            # Create / Copy the exsiting OS Disk with new name as non-zonal disk
                            Copy-AzUniqueNameDiskFromSnapshot -ResourceGroupName $VMResourceGroupName -Location $location -Snapshot $snapshot -OriginalDiskName $OSDiskName -StorageType $storageType -VMDiskZone $VMDiskZone -DiskNamePosfix "orig"   
                        }
                        
                        # Do not delete OS and Data disks during the VM deletion - set DeleteOption to 'Detach'
                        Set-AzVMDisksDeleteOption -VM $originalVM -DeleteOption "Detach"                                
    
                        # Do not delete NIC cards during the VM deletion - Set NIC Cards to 'Detach'
                        Set-AzVMNICsDeleteOption -VM $originalVM -DeleteOption "Detach"                
                        
                        # Remove the original VM -this is a prerequisit to delete orignial OS and data disks
                        $ToDelete = $true
    
                        if(-not $Force){
                            Write-Host
                            $ToDelete = Get-AzVMDeleteAnswer -VirtualMachineName $VirtualMachineName -ResourceGroupName $VMResourceGroupName
                        }
                        
                        if($ToDelete){
                            Write-Host
                            Write-WithTime_Using_WriteHost  "Removing Virtual Machine '$VirtualMachineName' ..." -AppendEmptyLine                        
                            Remove-AzVM -ResourceGroupName $VMResourceGroupName -Name $VirtualMachineName -force            
                        }else {
                            # Exit
                            Return   
                        }              
                        
                        if ($VMIsZonal) {
                            # Delete Original OS Disk                
                            Write-WithTime_Using_WriteHost  "Removing original OS disk '$osdiskname' ..." -AppendEmptyLine
                            Remove-AzDisk -ResourceGroupName $VMResourceGroupName -DiskName  $osdiskname -Force  
                        }
                        
                        if ($VMIsZonal) {
                            # new OS disk is non-zonal
                            $newdiskConfig = New-AzDiskConfig -AccountType $storageType -Location $location -CreateOption Copy -SourceResourceId $snapshot.Id # -zone $AzureZone    

                            $newdiskName = $osdiskname 
                        
                            Write-WithTime_Using_WriteHost  "Creating OS disk '$newdiskName' from snapshot '$($snapshot.Name)' ..." -AppendEmptyLine
                            $newdisk = New-AzDisk -Disk $newdiskConfig -ResourceGroupName $VMResourceGroupName -DiskName $newdiskName 
                        }
                                                            
                        if ($osType -eq "Linux")
                        {  
                            Write-WithTime_Using_WriteHost "Configuring Linux OS disk '$OSDiskName' .. " -AppendEmptyLine          
                            if ($VMIsZonal) {
                                Set-AzVMOSDisk -VM $newVM -CreateOption Attach  -ManagedDiskId $newdisk.Id -Name $newdisk.Name  -Linux -Caching $originalVM.StorageProfile.OsDisk.Caching > $null
                            }else{
                                Set-AzVMOSDisk  -VM $newVM -CreateOption Attach -ManagedDiskId $originalVM.StorageProfile.OsDisk.ManagedDisk.Id -Name $OSDiskName -Linux -Caching $originalVM.StorageProfile.OsDisk.Caching > $null
                            }                        
                        }elseif ($osType -eq "Windows"){                    
                            Write-WithTime_Using_WriteHost "Configuring Windows OS disk '$OSDiskName' .. " -AppendEmptyLine     
                            if ($VMIsZonal) {
                                Set-AzVMOSDisk -VM $newVM -CreateOption Attach  -ManagedDiskId $newdisk.Id -Name $newdisk.Name  -Windows -Caching $originalVM.StorageProfile.OsDisk.Caching > $null	
                            }else{
                                Set-AzVMOSDisk  -VM $newVM -CreateOption Attach -ManagedDiskId $originalVM.StorageProfile.OsDisk.ManagedDisk.Id -Name $OSDiskName -Windows -Caching $originalVM.StorageProfile.OsDisk.Caching	> $null	
                            }                        
                        }                    

                        if ($VMIsZonal) {
                            # Snapshot all of the Data disks, and add to the VM
                            foreach ($disk in $originalVM.StorageProfile.DataDisks){
                                    
                                        $OriginalDataDiskName = $disk.Name

                                        #snapshot & copy the data disk
                                        $snapshot = New-AzUniqueNameSnapshot -ResourceGroupName $VMResourceGroupName -Location $location -DiskName  $disk.Name -SourceDiskResourceId $disk.ManagedDisk.Id                                                               
                                    
                                        $diskName = $disk.Name

                                        # Create / Copy the exsiting Data disk with a new name
                                        Copy-AzUniqueNameDiskFromSnapshot -ResourceGroupName $VMResourceGroupName -Location $location -Snapshot $snapshot -OriginalDiskName $OriginalDataDiskName -StorageType $storageType -VMDiskZone $VMDiskZone -DiskNamePosfix "orig"

                                        # Delete Original Data disk
                                        Write-Host
                                        Write-WithTime_Using_WriteHost  "Removing original data disk '$OriginalDataDiskName' ..." 
                                        Remove-AzDisk -ResourceGroupName $VMResourceGroupName -DiskName  $OriginalDataDiskName -Force 
                                                                                        
                                        $diskConfig = New-AzDiskConfig -AccountType $storageType -Location $location -CreateOption Copy -SourceResourceId $snapshot.Id #-zone $AzureZone
                                        Write-Host 
                                        Write-WithTime_Using_WriteHost  "Creating data disk '$diskName' from snapshot '$($snapshot.Name)' ..." -AppendEmptyLine
                                        
                                        $newdisk = New-AzDisk -Disk $diskConfig -ResourceGroupName $VMResourceGroupName -DiskName $diskName # > $null
                                        
                                        Write-WithTime_Using_WriteHost "Configuring data disk '$($newdisk.Name)' , LUN '$($disk.Lun)' for Virtual Machine '$VirtualMachineName' ... " 
                    
                                        if($disk.WriteAcceleratorEnabled) {
                                            
                                            Write-WithTime_Using_WriteHost "Adding disk '$($newdisk.Name)' to new VM with enabled Write Accelerator ...  " -AppendEmptyLine
                                            Add-AzVMDataDisk -VM $newVM -Name $newdisk.Name -ManagedDiskId $newdisk.Id -Caching $disk.Caching -Lun $disk.Lun -DiskSizeInGB $newdisk.DiskSizeGB -CreateOption Attach -WriteAccelerator  > $null	
                                        }else{
                                            
                                            Write-WithTime_Using_WriteHost "Adding disk '$($newdisk.Name)' to new VM ...  " -AppendEmptyLine
                                            Add-AzVMDataDisk -VM $newVM -Name $newdisk.Name -ManagedDiskId $newdisk.Id -Caching $disk.Caching -Lun $disk.Lun -DiskSizeInGB $newdisk.DiskSizeGB -CreateOption Attach > $null	
                                        }
                            }                          
                        }else{
                            # Add exisitng Data Disks
                            foreach ($disk in $originalVM.StorageProfile.DataDisks) { 
                                Write-Host
                                Write-WithTime_Using_WriteHost "Adding data disk '$($disk.Name)'  to Virtual Machine '$VirtualMachineName'  ..."
                                Add-AzVMDataDisk -VM $newVM -Name $disk.Name -ManagedDiskId $disk.ManagedDisk.Id -Caching $disk.Caching -Lun $disk.Lun -DiskSizeInGB $disk.DiskSizeGB -CreateOption Attach > $null
                            }          
                        }
                        
                        # Add NIC(s) and keep the same NIC as primary
                        foreach ($nic in $originalVM.NetworkProfile.NetworkInterfaces) {	                                      
                            Write-WithTime_Using_WriteHost "Adding '$($nic.Id)' network card to Virtual Machine '$VirtualMachineName'  ..." -AppendEmptyLine
                            if ($nic.Primary -eq "True"){                
                            Add-AzVMNetworkInterface -VM $newVM -Id $nic.Id -Primary > $null
                                }
                                else{                
                                Add-AzVMNetworkInterface -VM $newVM -Id $nic.Id > $null
                            }
                        }

                        # Configuring Boot Diagnostics
                        if ($originalVM.DiagnosticsProfile.BootDiagnostics.Enabled) {
                                                    
                            Write-WithTime_Using_WriteHost "Boot diagnostic account is enabled." -AppendEmptyLine
                            
                            # Get Strage URI
                            $StorageUri = $originalVM.DiagnosticsProfile.BootDiagnostics.StorageUri 
                            
                            if ($StorageUri -eq $null) {

                                Write-WithTime_Using_WriteHost "Boot diagnostic URI is empty." -AppendEmptyLine
                                
                                Write-WithTime_Using_WriteHost "Configuring boot diganostic with managed storage account ..."  -AppendEmptyLine            

                                $newVM = Set-AzVMBootDiagnostic -VM $newVM -Enable       

                            }else {
                                
                                $BootDiagnosticURI = $originalVM.DiagnosticsProfile.BootDiagnostics.StorageUri.Split("/")[2]
                                
                                Write-WithTime_Using_WriteHost "Boot diagnostic URI: '$BootDiagnosticURI'." -AppendEmptyLine

                                $staccName = $BootDiagnosticURI.Split(".")[0]
                                
                                Write-WithTime_Using_WriteHost "Extracted storage account name: '$staccName'" -AppendEmptyLine
                                
                                Write-WithTime_Using_WriteHost "Getting storage account '$staccName'" -AppendEmptyLine
                                $stacc = Get-AzStorageAccount | where-object { $_.StorageAccountName.Contains($staccName) }
                                
                                if($stacc  -eq $null ){                                
                                    Write-WithTime_Using_WriteHost "Storage account '$staccName' used for diagonstic account on source VM do not exist. Skipping configuration of boot diagnostic on the new VM." -AppendEmptyLine
                                
                                }else{

                                    Write-WithTime_Using_WriteHost "Configuring storage account '$staccName' for VM boot diagnostigs in Azure resource group '$($stacc.ResourceGroupName)' on the new VM ..." -AppendEmptyLine
                                
                                    $newVM = Set-AzVMBootDiagnostic -VM $newVM -Enable -ResourceGroupName $stacc.ResourceGroupName -StorageAccountName $staccName
                                    
                                    Write-WithTime_Using_WriteHost "Configuring storage account '$staccName' for VM boot diagnostigs done." -AppendEmptyLine
                                }
                                
                            }                    
                        }                                    
                                            
                        Write-WithTime_Using_WriteHost "Recreating the '$VirtualMachineName' VM and adding to the Virtual Machine Scale Set '$VMSSName' with Fault Domain '$FaultDomainNumber' ..." -AppendEmptyLine

                        New-AzVM -ResourceGroupName $VMResourceGroupName -Location $originalVM.Location -VM $newVM -ErrorAction Stop
                    }
            
                    Write-WithTime_Using_WriteHost "Done!"
                
                }
                catch{
                   Write-Error  $_.Exception.Message           
               }
            }
        
            END {}
}


function Set-AzVMDisksDeleteOption {
    <#
    .SYNOPSIS 
    
    
    .DESCRIPTION
    
    
    .PARAMETER Message 
    
    
    .PARAMETER Level 
    
    
    .PARAMETER Colour 
    
    
    .EXAMPLE     
    
 #> 
    
    [CmdletBinding()]
    param(            
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        $VM,    
                  
        [string] $DeleteOption = "Detach"        
    )
    
    BEGIN {}
        
    PROCESS {
        try {   
                      
            # Set OS Disk to # Set OS Disk to '"Detach"'
            $VM.StorageProfile.OsDisk.DeleteOption = $DeleteOption
            
            Write-WithTime_Using_WriteHost "Setting OS disk to 'DeleteOption' to '$DeleteOption'  ..." -PrependEmptyLine -AppendEmptyLine

            # Set Data Disks to 'Detach'
            foreach ($disk in $VM.StorageProfile.DataDisks) {                 
                Write-WithTime_Using_WriteHost "Setting data disk '$($disk.Name)' 'DeleteOption' to '$DeleteOption'  ..." -AppendEmptyLine
                $disk.DeleteOption = $DeleteOption            
            }     
            
            Write-WithTime_Using_WriteHost "Updating VM with new disk 'DeleteOption' settings ..." -AppendEmptyLine
            
            Update-AzVM -ResourceGroupName $VM.ResourceGroupName -VM $VM

        }
        catch {
            Write-Error  $_.Exception.Message
        }
    
    }
    
    END {}
}


function Set-AzVMNICsDeleteOption {
    <#
    .SYNOPSIS 
    
    
    .DESCRIPTION
    
    
    .PARAMETER Message 
    
    
    .PARAMETER Level 
    
    
    .PARAMETER Colour 
    
    
    .EXAMPLE     
    
 #> 
    
    [CmdletBinding()]
    param(            
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        $VM,          
                  
        [string] $DeleteOption = "Detach"        
    )
    
    BEGIN {}
        
    PROCESS {
        try {   
                      
            foreach ($nic in $VM.NetworkProfile.NetworkInterfaces) {	                              
                Write-WithTime_Using_WriteHost "Setting '$($nic.Id)' network card 'DeleteOption' to '$DeleteOption' ..." -AppendEmptyLine
                $nic.DeleteOption = "Detach"
            }
                        
            Write-WithTime_Using_WriteHost "Updating VM with new NICs 'DeleteOption' settings ..." -AppendEmptyLine
               
            Update-AzVM -ResourceGroupName $VM.ResourceGroupName -VM $VM

        }
        catch {
            Write-Error  $_.Exception.Message
        }    
    }
    
    END {}
}

function Test-AzVMSSIsFlexType {
    <#
    .SYNOPSIS 
    
    
    .DESCRIPTION
    
    .EXAMPLE     
    
 #> 
    
    [CmdletBinding()]
    param(            

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMSSName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMSSGResourceGroupName
    )
    
    BEGIN {}
        
    PROCESS {
        try {   
                    
            $VMSS = Get-AzVmss -ResourceGroupName $VMSSGResourceGroupName -VMScaleSetName $VMSSName -ErrorAction Stop

            if ("Flexible" -eq $VMSS.OrchestrationMode  ) {
                return $True
            }  else {
                return $false
            }
            

        }
        catch {
            Write-Error  $_.Exception.Message
        }    
    }
    
    END {}
}


function Get-AzVMSSZones {
    <#
    .SYNOPSIS 
    
    
    .DESCRIPTION
    
    
    .PARAMETER Message 
    
    
    .PARAMETER Level 
    
    
    .PARAMETER Colour 
    
    
    .EXAMPLE     
    
 #> 
    
    [CmdletBinding()]
    param(            

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMSSName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMSSGResourceGroupName
    )
    
    BEGIN {}
        
    PROCESS {
        try {   
                    
            $VMSS = Get-AzVmss -ResourceGroupName $VMSSGResourceGroupName -VMScaleSetName $VMSSName -ErrorAction Stop

            $Zones = $VMSS.Zones

            return $Zones

        }
        catch {
            Write-Error  $_.Exception.Message
        }    
    }
    
    END {}
}


function Test-AzVMSKUZonalAvailability {
    <#
    .SYNOPSIS 
    Test-AzVMSKUZonalAvailability ckeck if VM SKU is avaible in the specifed zone.
    
    .DESCRIPTION
    Test-AzVMSKUZonalAvailability returns $true if VM SKU is avaibel in the specifed zone, othewise returns $false and writes an error. 
    
    .PARAMETER VMSize 
    VM size.
    
    .PARAMETER location 
    Azure region.
    
    .PARAMETER AzureZone 
    Azure zone number.
    
    
    .EXAMPLE     
    
 #> 
    
    [CmdletBinding()]
    param(            
        [Parameter(Mandatory)]        
        [string] $VMSize,
    
        [Parameter(Mandatory)]
        [string] $location,

        [Parameter(Mandatory)]
        [string] $AzureZone
            
    )
    
    BEGIN {}
        
    PROCESS {
        try {   
                                  
            Write-WithTime_Using_WriteHost "Checking VM SKU '$VMSize' availablity in Azure zone '$AzureZone' in region '$location'  ...." -AppendEmptyLine

            $VMSKUIsAvailableinAzureZone = Test-AzComputeSKUZonesAvailability -Location $location  -VMSKU $VMSize -AzureZone $AzureZone
            if (-not $VMSKUIsAvailableinAzureZone) {
                $AzureZones = Get-AzComputeSKUZonesAvailability -Location $location -VMSKU $VMSize
                if ($null -eq $AzureZones) {
                    Write-Host
                    Write-Error "VM SKU '$VMSize' is not available in any of the Azure zones in region '$location'. PLease use another VM SKU."   
                    return $false                         
                }else {
                    
                    Write-WithTime_Using_WriteHost "VM SKU '$VMSize' is available in these Azure zone(s):"
                    Write-Host $AzureZones
                    Write-Host
                    Write-Error "VM SKU '$VMSize' is not available in desired Azure zone '$AzureZone' in region '$location'. PLease use another VM SKU or another zone."  
                    return $false
                }                        
            }         

            return $true                        

        }
        catch {
            Write-Error  $_.Exception.Message
        }
    
    }
    
    END {}
}



###endregion


function Get-AzVMNetworkInterfacesCards {
    <#
    .SYNOPSIS 
    Get-AzVMNetworkInterfacesCards gest virtual machine all network cards
    
    .DESCRIPTION
     Get-AzVMNetworkInterfacesCards gest virtual machine all network cards
    
    .PARAMETER VMResourceGroupName 
    VM Resource Group Name.
    
    .PARAMETER VirtualMachineName 
    Virtual Machine Name.
    
    
    .EXAMPLE   
    $NICs = Get-AzVMNetworkInterfacesCards -VMResourceGroupName gor-vmssflex1 -VirtualMachineName test1  

    # Get NIC 0 Id
    $NICs[0].Id

    # Get NIC 1 Id
    $NICs[1].Id
    
 #> 
    
    [CmdletBinding()]
    param(       
        [Parameter(Mandatory)]    
        [string] $VMResourceGroupName,
                                  
        [Parameter(Mandatory)]    
        [string] $VirtualMachineName
            
    )
    
    BEGIN {}
        
    PROCESS {
        try {   
                                  
            #Write-WithTime_Using_WriteHost "Checking VM SKU '$VMSize' availablity in Azure zone '$AzureZone' in region '$location'  ...." -AppendEmptyLine

            $VM = Get-AzVM -resourceGroup $VMResourceGroupName -Name $VirtualMachineName       

            return $VM.NetworkProfile.NetworkInterfaces            

        }
        catch {
            Write-Error  $_.Exception.Message
        }
    
    }
    
    END {}
}


function Get-AzVMNetworkInterfacesCardLoadBalancerBackendAddressPools {
    <#
    .SYNOPSIS 
    Get-AzVMNetworkInterfacesCards gest virtual machine all network cards
    
    .DESCRIPTION
     Get-AzVMNetworkInterfacesCards gest virtual machine all network cards
    
    .PARAMETER VMResourceGroupName 
    VM Resource Group Name.
    
    .PARAMETER VirtualMachineName 
    Virtual Machine Name.
    
    
    .EXAMPLE   
    $NICs = Get-AzVMNetworkInterfacesCards -VMResourceGroupName gor-vmssflex1 -VirtualMachineName test1  

    # Get NIC 0 Id
    $NICs[0].Id

    # Get NIC 1 Id
    $NICs[1].Id
    
 #> 
    
    [CmdletBinding()]
    param(       
        [Parameter(Mandatory)]    
        [string] $NetworkInterfaceCardId                                          
            
    )
    
    BEGIN {}
        
    PROCESS {
        try {   
                                  
            #Write-WithTime_Using_WriteHost "Checking VM SKU '$VMSize' availablity in Azure zone '$AzureZone' in region '$location'  ...." -AppendEmptyLine

            $NIC = Get-AzNetworkInterface -ResourceId $NetworkInterfaceCardId 
                        
            return $NIC.IpConfigurations.LoadBalancerBackendAddressPools

        }
        catch {
            Write-Error  $_.Exception.Message
        }
    
    }
    
    END {}
}



function Get-AzLoadbBalancerIdFromBackendPoolId {
    <#
    .SYNOPSIS 
    
    
    .DESCRIPTION
    
    
    .PARAMETER VMResourceGroupName 
    
    
    .PARAMETER VirtualMachineName 
    
    
    
    .EXAMPLE   
    
 #> 
    
    [CmdletBinding()]
    param(       
        [Parameter(Mandatory)]    
        [string] $LoadBalancerBackendAddressPoolId
                                              
    )
    
    BEGIN {}
        
    PROCESS {
        try {   
                                  
            #Write-WithTime_Using_WriteHost "Checking VM SKU '$VMSize' availablity in Azure zone '$AzureZone' in region '$location'  ...." -AppendEmptyLine

            $LoadbBalancerId=  $LoadBalancerBackendAddressPoolId -replace '/backendAddressPools/.+', ''   

            return $LoadbBalancerId           

        }
        catch {
            Write-Error  $_.Exception.Message
        }
    
    }
    
    END {}
}



function Test-AzLoadbBalancerIsStandard {
    <#
    .SYNOPSIS 
    
    
    .DESCRIPTION
    
    
    .PARAMETER VMResourceGroupName 
    
    
    .PARAMETER VirtualMachineName 
    
    
    
    .EXAMPLE   
    
 #> 
    
    [CmdletBinding()]
    param(       
        [Parameter(Mandatory)]    
        [string] $LoadBalancerId
                                              
    )
    
    BEGIN {}
        
    PROCESS {
        try {   
                                  
            #Write-WithTime_Using_WriteHost "Checking VM SKU '$VMSize' availablity in Azure zone '$AzureZone' in region '$location'  ...." -AppendEmptyLine

            $LoadBalancerResource = Get-AzResource -ResourceId $LoadBalancerId -ErrorAction Stop

            $ILB = Get-AzLoadBalancer -ResourceGroupName $LoadBalancerResource.ResourceGroupName -Name $LoadBalancerResource.Name -ErrorAction Stop

            #check if ILB SKU for 'Standard'
            if($ILB.Sku.Name -eq "Standard"){
                return $True
            }
            else{
                return $False
            }
       

        }
        catch {
            Write-Error  $_.Exception.Message
        }
    
    }
    
    END {}
}






function Test-AzVMLoadbBalancerIsStandard {
    <#
    .SYNOPSIS 
    
    
    .DESCRIPTION
    
    
    .PARAMETER VMResourceGroupName 
    
    
    .PARAMETER VirtualMachineName 
    
    
    
    .EXAMPLE   
    
 #> 
    
    [CmdletBinding()]
    param(       
        [Parameter(Mandatory)]    
        [string] $VMResourceGroupName,

        [Parameter(Mandatory)]    
        [string] $VirtualMachineName
                                              
    )
    
    BEGIN {}
        
    PROCESS {
        try {   
                                  
            Write-WithTime_Using_WriteHost "Checking if VM SKU '$VirtualMachineName' in resource group '$VMResourceGroupName' is using standard load balancer  ...." -AppendEmptyLine
            

            $NICs = Get-AzVMNetworkInterfacesCards -VMResourceGroupName $VMResourceGroupName -VirtualMachineName $VirtualMachineName

            foreach ($nic in $NICs) {
                Write-WithTime_Using_WriteHost "Checking if NIC card '$($nic.Id)' has configured load balancer backend address pools  ...." -AppendEmptyLine

                $NICBackendLBPools = Get-AzVMNetworkInterfacesCardLoadBalancerBackendAddressPools -NetworkInterfaceCardId $nic.Id

                if($null -eq $NICBackendLBPools){
                    Write-WithTime_Using_WriteHost "NIC card '$($nic.Id)' has no configured load balancer backend address pool and no configured Azure load balancer." -AppendEmptyLine
                }

                foreach($NICBackendLBPool in $NICBackendLBPools){
                    Write-WithTime_Using_WriteHost "NIC card '$($nic.Id)' has configured load balancer backend address pool '$($NICBackendLBPool.Id)'." -AppendEmptyLine
                    
                    $AzureLoadBalancerId = Get-AzLoadbBalancerIdFromBackendPoolId -LoadBalancerBackendAddressPoolId $NICBackendLBPool.Id

                    Write-WithTime_Using_WriteHost "Backend address pool '$($NICBackendLBPool.Id)' is configured with Azure Load Balancer '$AzureLoadBalancerId'." -AppendEmptyLine
                    
                    # Check is Azure load balancer is Standart type
                    $LoadBalancerIsStandardType = Test-AzLoadbBalancerIsStandard -LoadBalancerId $AzureLoadBalancerId

                    if ($LoadBalancerIsStandardType) {
                        Write-WithTime_Using_WriteHost  "Azure Load Balancer '$AzureLoadBalancerId' is Standard type. This is supported for Azure Virtual Machine Scale Set. " -AppendEmptyLine
                    }else{
                        Write-Error "Azure Load Balancer '$AzureLoadBalancerId' is not Standard type. "
                        return $false
                    }
                }
            }
            
            return $true

        }
        catch {
            Write-Error  $_.Exception.Message
        }
    
    }
    
    END {}
}

