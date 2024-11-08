**DNSZoneRecovery** is a PowerShell script designed to restore deleted DNS zones in an Active Directory environment. Through an intuitive graphical interface (WPF), it allows users to view a list of deleted DNS zones and select zones for recovery with ease.

This tool is intended for DNS administrators or domain administrators who need to recover DNS zones that may have been accidentally deleted. 

## Features
- **Interactive WPF Interface**: Displays a list of deleted DNS zones with details such as zone name, creation date, deletion date, and parent path.
- **Selection and Restoration**: Easily select a DNS zone from the list and initiate restoration with a single click.
- **DNS Service Restart**: Automatically restarts the DNS service to apply changes after restoring a zone.
- **Detailed Status Messages**: Displays console messages for tracking each step of the restoration process, including error handling.

## Prerequisites
- **Permissions**: DNS Admin or Domain Admin privileges.
- **Execution**: Must be run on the Domain Controller (DC) where the DNS zone was deleted.
- **PowerShell Version**: Requires PowerShell with WPF support.

## How It Works
1. The script retrieves deleted DNS zone objects from Active Directory, converting them into custom objects for display.
2. A WPF interface displays these zones in a DataGrid, with columns showing the zone’s name, creation date, deletion date, and parent path.
3. Users can select a zone and click the "Backup" button to restore it. Alternatively, they can cancel the action by clicking "Cancel."
4. Once a zone is selected, the script restores it in AD, removes the "..Deleted-" prefix from the object name, and restarts the DNS service.
5. The script verifies the restored zone to confirm success.

## Installation and Setup
Clone this repository or download the `DNSZoneRecovery.ps1` and run it from powershell or ISE.

## Usage
- **Testing**: It is recommended to test the script on a pre-production environment or with a test DNS zone to ensure it functions as expected.
- **Active Directory Recycle Bin**: The AD Recycle Bin must be enabled for this script to work. If it is not enabled, the script will not be able to retrieve and restore deleted zones.
- **Restoration Scope**: The script restores the DNS zone along with all associated records and child objects, reverting it to the state it was in just before deletion.
- **Keep as a Go-To Tool**: This script is a valuable tool for DNS recovery and can be useful to keep on hand in case of accidental deletions.
