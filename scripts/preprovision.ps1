Write-Host "Running preprovision.ps1"
$myip = curl -4 icanhazip.com
azd env set MY_IP_ADDRESS $myip

#run az login and set correct subscription if needed
./scripts/set-az-currentsubscription.ps1

if ($? -eq $true) {
    $myPrincipal = az ad signed-in-user show --query "id" -o tsv
    azd env set MY_USER_ID $myPrincipal

    # Get the values from the environment
    $azdenv = azd env get-values --output json | ConvertFrom-Json

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

    # Not yet supported
    $answerItemNo = @(
    Get-InteractiveChooseMenuOption `
        -Label "No" `
        -Value "false" `
        -Info "No"
    )

    # Read-Host -Prompt "Press any key to continue..."

    ###################
    ## Deploy Azure Front Door
    ###################
    if ([String]::IsNullOrEmpty($azdenv.DEPLOY_FRONTDOOR) -or -not (Test-Path env:DEPLOY_FRONTDOOR)) {
        $frontDoorQuestion = "Do you want to deploy Azure Front Door?"
        $deployFrontDoor = Get-InteractiveMenuChooseUserSelection -Question $frontDoorQuestion -Answers $answerItems -Options $options
        
        azd env set DEPLOY_FRONTDOOR $deployFrontDoor
    }
    ###################
    ## Deploy API Management Devoper Portal
    ###################
    if ([String]::IsNullOrEmpty($azdenv.DEPLOY_APIM_DEV_PORTAL) -or -not (Test-Path env:DEPLOY_APIM_DEV_PORTAL)) {
        $apimDeveloperPortalQuestion = "Do you want to enable the Developer Portal for Azure API Management?"
        $deployApimDeveloperPortal = Get-InteractiveMenuChooseUserSelection -Question $apimDeveloperPortalQuestion -Answers $answerItems -Options $options
        
        azd env set DEPLOY_APIM_DEV_PORTAL $deployApimDeveloperPortal
    }
    ###################
    ## Deploy App Service Environment v3
    ###################
    if ([String]::IsNullOrEmpty($azdenv.DEPLOY_ASE) -or -not (Test-Path env:DEPLOY_ASE)) {
        $aseQuestion = "Do you want to deploy an App Service Environment v3 to host you Logic Apps / Functions?"
        $deployAse = Get-InteractiveMenuChooseUserSelection -Question $aseQuestion -Answers $answerItems -Options $options

        azd env set DEPLOY_ASE $deployAse
    }
    ###################
    ## Deploy Azure Functions
    ###################
    if ([String]::IsNullOrEmpty($azdenv.DEPLOY_FUNCTIONS) -or -not (Test-Path env:DEPLOY_FUNCTIONS)) {
        $azureFunctionsQuestion = "Do you want to add Azure Functions support to your Landing Zone?"
        $deployAzureFunctions = Get-InteractiveMenuChooseUserSelection -Question $azureFunctionsQuestion -Answers $answerItems -Options $options
        
        azd env set DEPLOY_FUNCTIONS $deployAzureFunctions
    }
    ###################
    ## Deploy Service Bus Namespace
    ###################
    if ([String]::IsNullOrEmpty($azdenv.DEPLOY_SERVICEBUS) -or -not (Test-Path env:DEPLOY_SERVICEBUS)) {
        $serviceBusNamespaceQuestion = "Do you want to add a Service Bus Namespace to your Landing Zone?"
        $deployServiceBusNamespace = Get-InteractiveMenuChooseUserSelection -Question $serviceBusNamespaceQuestion -Answers $answerItems -Options $options
        
        azd env set DEPLOY_SERVICEBUS $deployServiceBusNamespace
    }
}
Write-Host "Finished executing preprovision.ps1"