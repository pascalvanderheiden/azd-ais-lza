Write-Host "Running preprovision.ps1"
$myip = curl -4 icanhazip.com
azd env set MY_IP_ADDRESS $myip

#run az login and set correct subscription if needed
./scripts/set-az-currentsubscription.ps1

if ($? -eq $true) {
    $myPrincipal = az ad signed-in-user show --query "id" -o tsv
    azd env set MY_USER_ID $myPrincipal

    # Define the path to the InteractiveMenu module
    $currentDir = Get-Location 
    $modulePath = "${currentDir}/scripts/InteractiveMenu/InteractiveMenu.psd1"

    # Check if the module exists
    if (Test-Path $modulePath) {
        # Remove the old module if it's already loaded
        if (Get-Module -Name InteractiveMenu) {
            Remove-Module -Name InteractiveMenu
        }

        # Import the InteractiveMenu module from the local directory
        Import-Module $modulePath
    } else {
        Write-Host "The module $modulePath does not exist."
    }

    $options = @{
        MenuInfoColor = [ConsoleColor]::DarkYellow
        QuestionColor = [ConsoleColor]::Magenta
        HelpColor = [ConsoleColor]::Cyan
        ErrorColor = [ConsoleColor]::DarkRed
        HighlightColor = [ConsoleColor]::DarkGreen
        OptionSeparator = "`n"
    }
    
    $answerItems = @(
    Get-InteractiveChooseMenuOption `
        -Label "Yes" `
        -Value "true" `
        -Info "Yes"
    Get-InteractiveChooseMenuOption `
        -Label "No" `
        -Value "false" `
        -Info "No"
    )

    ###################
    ## Deploy Azure Front Door
    ###################

    $frontDoorQuestion = "Do you want to deploy Azure Front Door?"
    $deployFrontDoor = Get-InteractiveMenuChooseUserSelection -Question $frontDoorQuestion -Answers $answerItems -Options $options
    
    azd env set DEPLOY_FRONTDOOR $deployFrontDoor
    
    ###################
    ## Deploy API Management Devoper Portal
    ###################
    
    $apimDeveloperPortalQuestion = "Do you want to enable the Developer Portal for Azure API Management?"
    $deployApimDeveloperPortal = Get-InteractiveMenuChooseUserSelection -Question $apimDeveloperPortalQuestion -Answers $answerItems -Options $options
    
    azd env set DEPLOY_APIM_DEV_PORTAL $deployApimDeveloperPortal

    ###################
    ## Deploy App Service Environment v3
    ###################

    $aseQuestion = "Do you want to deploy an App Service Environment v3 to host you Logic Apps / Functions?"
    $deployAse = Get-InteractiveMenuChooseUserSelection -Question $aseQuestion -Answers $answerItems -Options $options

    azd env set DEPLOY_ASE $deployAse

    ###################
    ## Deploy Service Bus Namespace
    ###################

    $serviceBusNamespaceQuestion = "Do you want to add a Service Bus Namespace to your Landing Zone?"
    $deployServiceBusNamespace = Get-InteractiveMenuChooseUserSelection -Question $serviceBusNamespaceQuestion -Answers $answerItems -Options $options
    
    azd env set DEPLOY_SERVICEBUS $deployServiceBusNamespace
}
Write-Host "Finished executing preprovision.ps1"