<#
.SYNOPSIS
    PowerShell script for restoring deleted DNS zones in an Active Directory environment.

.DESCRIPTION
    DNSZoneRecovery is an interactive script designed to recover deleted DNS zones in Active Directory.
    It uses a WPF graphical interface to display deleted DNS zones and allows the user to select and restore 
    zones intuitively.

.FEATURES
    - Displays a list of deleted DNS zones with information such as zone name, creation date, 
      deletion date, and parent path.
    - Allows selection of a zone and restoration with a simple click on the "Backup" button.
    - Includes a "Cancel" button to close the window without performing any actions.
    - Restarts the DNS service to apply changes after restoration.
    - Provides status and confirmation messages in the console to facilitate action tracking.

.PARAMETERS
    No input parameters are required. Information is retrieved directly from AD.

.NOTES
    Prerequisites: This script requires administrative permissions as a DNS Admin or Domain Admin.
    It must be executed on the Domain Controller (DC) where the zone was deleted.
    
    Testing: It’s recommended to test this script on a pre-production DC or with a test DNS zone 
    to verify functionality. This code can be kept as a useful tool for DNS zone recovery tasks.

.EXAMPLE
    To run the script, start it in an administrative PowerShell session:
    
    .\DNSZoneRecovery.ps1

.Version 1

.Author : Dakhama Mehdi

#>


Add-Type -AssemblyName PresentationFramework
$domainInfo = Get-ADDomain
$domainDN = $domainInfo.DistinguishedName

# Function to backup DNS Zone
function Restore-DnsZone {
    param (
        [Parameter(Mandatory=$true)]
        [pscustomobject]$dnsZoneObject
    )

    Write-Host "Starting DNS zone restoration : $($dnsZoneObject.CN)" -ForegroundColor Green

    # Restore the deleted DNS object
    try {
        Write-Host $dnsZoneObject.DistinguishedName
        $dnsZoneObject.DistinguishedName | Restore-ADObject 
        
    } catch {
        Write-Error "DNS zone restoration failed : $($dnsZoneObject.CN). Erreur : $_"
        return
    }

    # Reformat the DN of the restored object
    $prefix = $dnsZoneObject.DistinguishedName.split("\")[0]
    $zoneDN = $prefix + "," + $dnsZoneObject.LastKnownParent

    # Restore the deleted child objects under the restored DNS zone
    Get-ADObject -Filter {
        isdeleted -eq $true -and
        LastKnownParent -like $zoneDN
    } -IncludeDeletedObjects -SearchBase "DC=DomainDnsZones,$domainDN" | Restore-ADObject -ErrorAction SilentlyContinue

    # Rename the restored object to remove the prefix '..Deleted-'
    try {
        $zoneName = ($zoneDN -split ("Deleted-",0) -split (","))[1]
        Rename-ADObject -identity $zoneDN -NewName $zoneName
    } catch {
        Write-Error "Failed to rename the restored DNS zone : $($dnsZoneObject.CN). Erreur : $_"
        returne
    }

    # Restart the DNS service to apply the changes
    Restart-Service DNS -Force
    Write-Host "DNS service has been restarted" -ForegroundColor Yellow

    # Check if the DNS zone has been successfully restored
    Start-Sleep -Seconds 5
    Write-Host "Check if the DNS zone has been successfully restored" -ForegroundColor Yellow

    try {
        $zone = Get-DnsServerZone -Name $zoneName -ErrorAction Stop
        if ($zone) {
        Write-Host "The DNS zone '$zoneName' has been successfully restored" -ForegroundColor Green
         } else {
        Write-Host "The DNS zone '$zoneName' was not found after restoration" -ForegroundColor Red
       }

    } catch {
        Write-Error "The DNS zone '$zoneName' was not found after restoration."
    }
}

#region WPF
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" 
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="ADDNS Backup" Height="200" Width="700" Background="#F0F0F5">
    <Grid>
        <DataGrid x:Name="ServiceGrid" AutoGenerateColumns="False" Height="Auto" Margin="10,10,10,50" VerticalAlignment="Top" SelectionMode="Single">
            <DataGrid.Columns>
                <DataGridTextColumn Header="Zone" Binding="{Binding CN}" />
                <DataGridTextColumn Header="Name" Binding="{Binding Name}" />
                <DataGridTextColumn Header="Created" Binding="{Binding Created}" />
                <DataGridTextColumn Header="Deleted" Binding="{Binding Modified}" />
                <DataGridTextColumn Header="Path Parent" Binding="{Binding LastKnownParent}" />
            </DataGrid.Columns>
        </DataGrid>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Bottom" Margin="10">
            <Button x:Name="RestoreButton" Content="Backup" Width="100" Margin="0,0,10,0"/>
            <Button x:Name="CancelButton" Content="Cancel" Width="100"/>
        </StackPanel>
    </Grid>
</Window>
"@

# Load WPF
$reader = [System.Xml.XmlNodeReader]::new($xaml)
$window = [System.Windows.Markup.XamlReader]::Load($reader)

#endregion WPF

# Retrieve the deleted DNS objects, convert them into PSCustomObject, and enforce them as a collection
$deletedDnsZone = @(Get-ADObject -Filter {
    isdeleted -eq $true -and
    msds-lastKnownRdn -like "*Deleted-*" -and
    ObjectClass -eq "dnsZone"
} -IncludeDeletedObjects -SearchBase "DC=DomainDnsZones,$domainDN" -Properties CN, Modified, Created, LastKnownParent, DistinguishedName |
    Select-Object CN, @{Name='Name'; Expression={ ($_.Name -split ("..Deleted-")).Split([Environment]::NewLine)[1]}}, Created, Modified, LastKnownParent, DistinguishedName |
    ForEach-Object {
        [PSCustomObject]@{
            CN               = $_.CN
            Name             = $_.Name
            Created          = $_.Created
            Modified         = $_.Modified
            LastKnownParent  = $_.LastKnownParent
            DistinguishedName = $_.DistinguishedName
        }
    })

# Load data in gridview
$window.FindName("ServiceGrid").ItemsSource = $deletedDnsZone

$restoreButton = $window.FindName("RestoreButton")
$restoreButton.Add_Click({
    # Get selected line
    $selectedZone = $window.FindName("ServiceGrid").SelectedItem
    if ($selectedZone -ne $null) {
        Write-Host "Zone Selected : $($selectedZone.CN)"
        Write-Host "DistinguishedName : $($selectedZone.DistinguishedName)"
        $window.Close()  # Close Windows after select
        Restore-DnsZone -dnsZoneObject $selectedZone
    } else {
        [System.Windows.MessageBox]::Show("Pls select zone to list.", "Alerte", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
    }
})

$CancelButton = $window.FindName("CancelButton")
$CancelButton.Add_Click({
    $window.Close()
})

# Load Form
$dialogResult = $window.ShowDialog()

