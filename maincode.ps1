
#-------------------------Connect to Azure-----------------------#
$subscription = Get-AutomationVariable -Name '01Subscription'
$azureTenantId= Get-AutomationVariable -Name '01Tenantid'
$credential = Get-AutomationPSCredential -Name 'Automation'

Disable-AzContextAutosave -Scope Process | Out-Null
Connect-AzAccount -ServicePrincipal -Credential $credential -TenantId $azureTenantId -Subscription $subscription | Out-Null
#----------------------------Done---------------------------------------#

#-------------------------Check 230 port exist-----------------------#
$NSG_name = Get-AutomationVariable -Name 'Network_SEcurity_Group'
$RG_name = Get-AutomationVariable -Name 'NSG_Resource_Group'
$SG = Get-AzNetworkSecurityGroup -Name $NSG_name -ResourceGroupName $RG_name

#check if 230 is exist already then use 231 to create rule

#initial values
$rule_230 = "false"
$priority = 230
$Download_file = "231.csv"
$Del_rule_name = '-'
$new_file = "230.csv"
#==================

#$SG.SecurityRules
$SG.SecurityRules | foreach {
    #$_.Priority
    if ($_.Priority -match 230){
        write-output "yes priority 230 found"
        $rule_230 = "true"
        
        $Del_rule_name = $_.Name
    }elseif ( $_.Priority -match 231 ){
        $Del_rule_name = $_.Name
    }
    
}

Write-Output "$Del_rule_name rule name that need to be removed"
Write-Output "The 230 rule exist: $rule_230"
Write-Output " "

if ( $rule_230 -eq "true" ){
    #then 230 is exist, so new rule is 231
    $priority = 231
    #exist filename
    $Download_file = "230.csv"
    #new file name that matches new priority number
    $new_file = "231.csv"
}

Write-Output "New rule priority will be: $priority"
Write-Output "The file to compare from is: $Download_file"
Write-Output "The file to compare to is: $new_file"
#$copytopath = '.\'
$copytopath = $($env:TEMP + "\")
$blob_name = ([string]$priority + ".csv")
$new_IP_file_name = $copytopath + $new_file # $($env:TEMP + "\") + $priority +".csv"

#----------------------------Done---------------------------------------#

#============================
Import-Module AWSPowerShell.NetCore

$Service = 'EC2' # 'EC2'
$Region = 'eu-west-1'

$IPRange = Get-AWSPublicIpAddressRange -Region $Region -ServiceKey $Service | where {$_.IpAddressFormat -eq "Ipv4"} | select IpPrefix
$IPRange | Export-Csv -Path $new_IP_file_name
Write-Output "New Ip has been exported to $new_IP_file_name"


#------------------------------

$storageaccount = 'nphubpa' 
$resourcegroup = 'NPHUBPA2'
$container = 'aws-ip-range-whitelisting'


$context = (Get-AzStorageAccount -Name $storageaccount -ResourceGroupName $resourcegroup).context
Get-AzStorageBlobContent -container $container -blob $Download_file -Destination $copytopath -context $context -Force


$IPRange = Import-Csv -Path $new_IP_file_name | sort IpPrefix -Unique
#$IPRange | Select -First 10 | ft
$old_IPRage = Import-Csv -Path ($copytopath + $Download_file) | sort IpPrefix -Unique
#$old_IPRage | Select -First 10 | ft

$value = Compare-Object -ReferenceObject (Get-Content -Path $new_IP_file_name) -DifferenceObject (Get-Content -Path ( $copytopath + $Download_file ))

if ( $value -ne $null ){
    write-output "changes found hence, updating the NSG rule"

    $rule_name = ("sftp_AWSIPRange_" +$(Get-Date).Day +"_"+ $(Get-Date).Hour + "_" + $(Get-Date).Minute)
    $rule = "Outbound"
    
    Write-Output " "
    
    try {
        
        $SG | Add-AzNetworkSecurityRuleConfig `
            -Name $rule_name `
            -Description $rule_name `
            -Access Allow `
            -Protocol Tcp `
            -Direction $rule `
            -Priority $priority `
            -SourceAddressPrefix * `
            -SourcePortRange * `
            -DestinationAddressPrefix $IPRange.IpPrefix `
            -DestinationPortRange 22 | Set-AzNetworkSecurityGroup | Out-Null
        Start-Sleep -s 1
    
        if ( $priority -eq 230 ){
            $Del_priority = 231
    
            #delete it
            Remove-AzNetworkSecurityRuleConfig -Name $Del_rule_name -NetworkSecurityGroup $SG | Set-AzNetworkSecurityGroup | Out-Null
            Write-Output " $Del_priority has been removed "
    
        }else{
            $Del_priority = 230
            #delete it
            Remove-AzNetworkSecurityRuleConfig -Name $Del_rule_name -NetworkSecurityGroup $SG | Set-AzNetworkSecurityGroup | Out-Null
            Write-Output " $Del_priority has been removed "
        }

        Set-AzStorageBlobContent -Container $container -File $new_IP_file_name -Blob $new_file -Context $context -Force
        Write-Output "uploaded!"
        Remove-AzStorageBlob -Container $container -Blob $Download_file -Context $context -Force
        Write-Output "Removed the old $Download_file!"
        
        }catch {
            $_
    
    
            }    

}else{
    write-output "No changes found between the files hence no action requried."
}



#Remove-Item $($copytopath + '*.csv')
Get-ChildItem $copytopath