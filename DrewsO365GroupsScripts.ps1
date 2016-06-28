# Establish a remote session to Exchange Online
$creds = Get-Credential
$Session = New-PSSession -ConfigurationName Microsoft.Exchange –ConnectionUri ` 	https://outlook.office365.com/powershell-liveid/ -Credential $creds -Authentication Basic -AllowRedirection
Import-PSSession $Session

# Create group
New-UnifiedGroup –DisplayName “Legal” –Alias “Legal” –EmailAddresses legal@domain.com

# Rename group
Set-UnifiedGroup -Identity “Legal” -Alias “Legal” -DisplayName “New Legal” -PrimarySmtpAddress legal@domain.com

# View all subscribers, members or owners
Get-UnifiedGroupLinks -Identity “Legal” -LinkType Subscribers

# Show detailed info for all groups
Get-UnifiedGroup | 
    select Id,Alias, AccessType, Language,Notes, PrimarySmtpAddress, `
    HiddenFromAddressListsEnabled, WhenCreated, WhenChanged, `
    @{Expression={([array](Get-UnifiedGroupLinks -Identity $_.Id -LinkType Members)).Count }; `
    Label='Members'}, `
    @{Expression={([array](Get-UnifiedGroupLinks -Identity $_.Id -LinkType Owners)).Count }; `
    Label='Owners'} |
    Format-Table Alias, Members, Owners

# Setup Azure AD Group restriction creation by allowed group ID
Connect-MsolService
$template = Get-MsolSettingTemplate –TemplateId 62375ab9-6b52-47ed-826b-58e47e0e304b
$setting = $template.CreateSettingsObject()
$setting[“EnableGroupCreation”] = “false”
$setting[“GroupCreationAllowedGroupId”] = “a53ba62d-ee1b-4764-b8a1-20bf3bc89afc”
New-MsolSettings –SettingsObject $setting

# Check Azure AD Group restriction settings
Get-MsolAllSettings | ForEach Values

# Remove Azure AD Group restriction settings
$settings = Get-MsolAllSettings | where-object {$_.displayname -eq “Group.Unified”}
Remove-MsolSettings -SettingId $settings.ObjectId 

# Set OWA Mailbox Policy to restrict group creation for exchange Only
Set-OwaMailboxPolicy -Identity test.com\OwaMailboxPolicy-Default -GroupCreationEnabled $false

# Confifure multi-domain support to set all groups under 1 domain
New-EmailAddressPolicy -Name Groups -IncludeUnifiedGroupRecipients -EnabledEmailAddressTemplates "SMTP:@groups.contoso.com" -Priority 1 

# Configure multi-domain support to set sub domains based on user parameters
# Set students domain and all other domain
New-EmailAddressPolicy -Name StudentsGroups -IncludeUnifiedGroupRecipients -EnabledEmailAddressTemplates 	"SMTP:@students.contoso.com" ManagedByFilter {Department -eq 'Students'} -Priority 1 
New-EmailAddressPolicy -Name OtherGroups -IncludeUnifiedGroupRecipients -EnabledEmailAddressTemplates 	"SMTP:@groups.contoso.com" -Priority 2

# Set access type (private or public)
Set-UnifiedGroup -Identity "Legal" -AccessType Private

# Add quota setting for Group Sites
Get-SPOSite –Identity https://contoso.sharepoint.com/sites/<groupname> -detailed |fl
Set-SPOSite –Identity https://contoso.sharepoint.com/sites/<groupname> -StorageQuota 3000 -StorageQuotaWarningLevel 2000 

# Allow users to send as the Office 365 Group
$userAlias = “User”
$groupAlias = “TestSendAs”
$groupsRecipientDetails = Get-Recipient -RecipientTypeDetails groupmailbox -Identity $groupAlias 
Add-RecipientPermission -Identity $groupsRecipientDetails.Name -Trustee $userAlias -AccessRights SendAs

# Remove groups email from GAL (global address list)
$groupAlias = “TestGAL”
Set-UnifiedGroup –Identity $groupAlias –HiddenFromAddressListsEnabled $true

# Accept/Reject certain users from sending emails to groups
# -AcceptMessagesOnlyFromSendersOrMembers or -RejectMessagesFromSendersOrMembers
$groupAlias = “TestSend”
Set-UnifiedGroup –Identity $groupAlias –RejectMesssagesFromSendersOrMembers dmadelung@concurrency.com

# Hide group members unless you are a member of the private group 
$groupAlias = “TestHide”
Set-unifiedgroup –Identity $groupAlias –HiddenGroupMembershipEnabled:$true 

# View all subscribers, members or owners of a group
# Available LinkTypes: Members | Owners | Subscribers 
$groupAlias = “TestView”
Get-UnifiedGroupLinks -Identity $groupAlias -LinkType Subscribers

# Find out which groups do not have owners
$groups = Get-UnifiedGroup
ForEach ($G in $Groups) {     
    If ($G.ManagedBy -Ne $Null)      
    {          
        $GoodGroups = $GoodGroups + 1     
    }     
    Else     
    {             
         Write-Host "Warning! The" $G.DisplayName "has no owners"          
         $BadGroups = $BadGroups + 1      
        }
    }Write-Host $GoodGroups "groups are OK but" $BadGroups "groups lack owners"


# Get all storage being used by O365 groups 
# from Juan Carlos Gonzalez https://gallery.technet.microsoft.com/How-to-get-the-storage-fe6d5b1f
$spoO365GroupSites=Get-UnifiedGroup 
ForEach ($spoO365GroupSite in $spoO365GroupSites){ 
    If($spoO365GroupSite.SharePointSiteUrl -ne $null) 
    { 
        $spoO365GroupFilesSite=Get-SPOSite -Identity $spoO365GroupSite.SharePointSiteUrl 
        $spoO365GroupFilesUsedSpace=$spoO365GroupFilesSite.StorageUsageCurrent 
        Write-Host "Office 365 Group Files Url: " $spoO365GroupSite.SharePointSiteUrl " - Storage being used (MB): " $spoO365GroupFilesUsedSpace " MB"                    
    }      
} 