#-------------------------------------------------------------------------
# Copyright (c) Microsoft.  All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#--------------------------------------------------------------------------

#region Sign-in with Azure account

    $Error.Clear()

    Login-AzureRmAccount

#endregion

#region Select Azure Subscription

    $subscriptionId = 
        ( Get-AzureRmSubscription |
            Out-GridView `
              -Title "Select an Azure Subscription ..." `
              -PassThru
        ).SubscriptionId

    Select-AzureRmSubscription `
        -SubscriptionId $subscriptionId

#endregion

#region Specify unique deployment name prefix (up to 6 alphanum chars)

    $NamePrefix = -join ((97..122) | Get-Random -Count 6 | % {[char]$_})

#endregion

#region Specify deployment parameter values that are common to both regions

    $VMSize = "Standard_DS2_v2"

    $VMCount = 2

    $VMDiskSize = 128

    $VMDiskCount = 2

    $SRLogSize = 8

    $SRAsyncRPO = 300

    $DomainName = "contoso.com"

    $AdminCreds = Get-Credential -Message "Enter Admin Username and Password for existing AD Domain"

    $AdminUsername = $AdminCreds.UserName

    $AdminPassword = $AdminCreds.GetNetworkCredential().Password

    $sofsNameSuffix = "fs01"

    $shareName = "data"

    $artifactsLocation = "https://raw.githubusercontent.com/robotechredmond/301-s2d-sr-dr-md/master"

    $artifactsLocationSasToken = ""

#endregion

#region Specify deployment values for Region A

    $RegionATemplateName = "azuredeploya.json"

    $RegionADeploymentName = "${NamePrefix}-a-s2d-deploy"

    $RegionARGName =
        ( Get-AzureRmResourceGroup |
            Out-GridView `
              -Title "Select Azure Resource Group for Region A" `
              -PassThru
        ).ResourceGroupName

    $RegionARG = 
        Get-AzureRmResourceGroup `
            -Name $RegionARGName

    $RegionA =
        $RegionARG.Location

    $RegionAVnetName = 
        ( Get-AzureRmVirtualNetwork `
            -ResourceGroupName $RegionARGName 
        ).Name | 
        Out-GridView `
            -Title "Select a VNET in Region A" `
            -PassThru

    $RegionAVnet = 
        Get-AzureRmVirtualNetwork `
            -ResourceGroupName $RegionARGName `
            -Name $RegionAVnetName

    $RegionASubnetName = 
        ( Get-AzureRmVirtualNetworkSubnetConfig `
            -VirtualNetwork $RegionAVnet
        ).Name | 
        Out-GridView `
            -Title "Select a Subnet in Region A." `
            -PassThru

    $RegionASubnet =
        Get-AzureRmVirtualNetworkSubnetConfig `
          -VirtualNetwork $RegionAVnet `
          -Name $RegionASubnetName

#endregion

#region Specify deployment values for Region B

    $RegionBTemplateName = "azuredeployb.json"

    $RegionBDeploymentName = "${NamePrefix}-b-s2d-deploy"

    $RegionBRGName =
        ( Get-AzureRmResourceGroup |
            Out-GridView `
              -Title "Select Azure Resource Group for Region B" `
              -PassThru
        ).ResourceGroupName

    $RegionBRG = 
        Get-AzureRmResourceGroup `
            -Name $RegionBRGName

    $RegionB =
        $RegionBRG.Location

    $RegionBVnetName = 
        ( Get-AzureRmVirtualNetwork `
            -ResourceGroupName $RegionBRGName 
        ).Name | 
        Out-GridView `
            -Title "Select a VNET in Region B" `
            -PassThru

    $RegionBVnet = 
        Get-AzureRmVirtualNetwork `
            -ResourceGroupName $RegionBRGName `
            -Name $RegionBVnetName

    $RegionBSubnetName = 
        ( Get-AzureRmVirtualNetworkSubnetConfig `
            -VirtualNetwork $RegionBVnet
        ).Name | 
        Out-GridView `
            -Title "Select a Subnet in Region B." `
            -PassThru

    $RegionBSubnet =
        Get-AzureRmVirtualNetworkSubnetConfig `
          -VirtualNetwork $RegionBVnet `
          -Name $RegionBSubnetName

#endregion

#region Define hash table for parameter values

    $ARMTemplateParams = @{
        "namePrefix" = "$NamePrefix";
        "vmSize" = "$VMSize";
        "vmCount" = $VMCount;
        "vmDiskSize" = $VMDiskSize;
        "vmDiskCount" = $VMDiskCount;
        "srLogSize" = $SRLogSize;
        "srAsyncRPO" = $SRAsyncRPO;
        "existingDomainName" = "$DomainName";
        "adminUsername" = "$AdminUsername";
        "adminPassword" = "$AdminPassword";
        "existingRegionAVirtualNetworkRGName" = "$RegionARGName";
        "existingRegionAVirtualNetworkName" = "$RegionAVnetName";
        "existingRegionASubnetName" = "$RegionASubnetName";
        "existingRegionBVirtualNetworkRGName" = "$RegionBRGName";
        "existingRegionBVirtualNetworkName" = "$RegionBVnetName";
        "existingRegionBSubnetName" = "$RegionBSubnetName";
        "sofsNameSuffix" = "$sofsNameSuffix";
        "shareName" = "$shareName";
        "_artifactsLocation" = "$artifactsLocation";
        "_artifactsLocationSasToken" = "$artifactsLocationSasToken"
    }

#endregion

try
{

    #region First template deployment to Region B 

    New-AzureRmResourceGroupDeployment `
        -Name $RegionBDeploymentName `
        -ResourceGroupName $RegionBRGName `
        -TemplateParameterObject $ARMTemplateParams `
        -TemplateUri "${artifactsLocation}/${RegionBTemplateName}${artifactsLocationSasToken}" `
        -Mode Incremental `
        -ErrorAction Stop `
        -Confirm

    #endregion


    #region Second template deployment to Region A

    New-AzureRmResourceGroupDeployment `
        -Name $RegionADeploymentName `
        -ResourceGroupName $RegionARGName `
        -TemplateParameterObject $ARMTemplateParams `
        -TemplateUri "${artifactsLocation}/${RegionATemplateName}${artifactsLocationSasToken}" `
        -Mode Incremental `
        -ErrorAction Stop `
        -Confirm

    #endregion

}
catch 
{
    Write-Error -Exception $_.Exception
}


#region Clear deployment parameters

    $ARMTemplateParams = @{}

#endregion
