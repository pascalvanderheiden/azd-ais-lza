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
        
        # Update the variable for use in subsequent questions
        $azdenv | Add-Member -MemberType NoteProperty -Name DEPLOY_FRONTDOOR -Value $deployFrontDoor -Force
    }

    ###################
    ## Set WAF Rate Limit Threshold for DDoS Protection
    ###################
    if ([String]::IsNullOrEmpty($azdenv.WAF_RATE_LIMIT_THRESHOLD) -or -not (Test-Path env:WAF_RATE_LIMIT_THRESHOLD)) {
        if ($azdenv.DEPLOY_FRONTDOOR -eq "true") {
            Write-Host "Setting WAF DDoS protection rate limit threshold (requests per 5 minutes)..." -ForegroundColor Yellow
            $rateLimitDefault = "100"
            $rateLimitThreshold = Read-Host "Enter WAF rate limit threshold (default: $rateLimitDefault)"
            if ([String]::IsNullOrEmpty($rateLimitThreshold)) {
                $rateLimitThreshold = $rateLimitDefault
            }
            azd env set WAF_RATE_LIMIT_THRESHOLD $rateLimitThreshold
        } else {
            # Set default value even if Front Door is not deployed
            azd env set WAF_RATE_LIMIT_THRESHOLD "100"
        }
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
        $aseQuestion = "Do you want to deploy an App Service Environment v3?"
        $deployAse = Get-InteractiveMenuChooseUserSelection -Question $aseQuestion -Answers $answerItems -Options $options

        azd env set DEPLOY_ASE $deployAse
        
        # Update the variable for use in subsequent questions
        $azdenv | Add-Member -MemberType NoteProperty -Name DEPLOY_ASE -Value $deployAse -Force
    }
    
    ###################
    ## Deploy Logic Apps
    ###################
    if ([String]::IsNullOrEmpty($azdenv.DEPLOY_LOGIC_APPS) -or -not (Test-Path env:DEPLOY_LOGIC_APPS)) {
        $logicAppsQuestion = "Do you want to deploy a Logic Apps App Service Plan?"
        if ($azdenv.DEPLOY_ASE -eq "true") {
            $logicAppsQuestion += " (Will be deployed to ASE v3)"
        } else {
            $logicAppsQuestion += " (Will be deployed to public App Service Plan)"
        }
        $deployLogicApps = Get-InteractiveMenuChooseUserSelection -Question $logicAppsQuestion -Answers $answerItems -Options $options
        
        azd env set DEPLOY_LOGIC_APPS $deployLogicApps
        
        # Update the variable for use in subsequent questions
        $azdenv | Add-Member -MemberType NoteProperty -Name DEPLOY_LOGIC_APPS -Value $deployLogicApps -Force
    }
    
    ###################
    ## Deploy Azure Functions
    ###################
    if ([String]::IsNullOrEmpty($azdenv.DEPLOY_FUNCTIONS) -or -not (Test-Path env:DEPLOY_FUNCTIONS)) {
        $azureFunctionsQuestion = "Do you want to deploy Azure Functions?"
        if ($azdenv.DEPLOY_ASE -eq "true") {
            $azureFunctionsQuestion += " (Will be deployed to ASE v3)"
        } else {
            $azureFunctionsQuestion += " (Will be deployed to public App Service Plan)"
        }
        $deployAzureFunctions = Get-InteractiveMenuChooseUserSelection -Question $azureFunctionsQuestion -Answers $answerItems -Options $options
        
        azd env set DEPLOY_FUNCTIONS $deployAzureFunctions
        
        # Update the variable for use in subsequent questions  
        $azdenv | Add-Member -MemberType NoteProperty -Name DEPLOY_FUNCTIONS -Value $deployAzureFunctions -Force
    }
    ###################
    ## Deploy Service Bus Namespace
    ###################
    if ([String]::IsNullOrEmpty($azdenv.DEPLOY_SERVICEBUS) -or -not (Test-Path env:DEPLOY_SERVICEBUS)) {
        $serviceBusNamespaceQuestion = "Do you want to add a Service Bus Namespace to your Landing Zone?"
        $deployServiceBusNamespace = Get-InteractiveMenuChooseUserSelection -Question $serviceBusNamespaceQuestion -Answers $answerItems -Options $options
        
        azd env set DEPLOY_SERVICEBUS $deployServiceBusNamespace
    }
    ###################
    ## Deploy Azure API Center
    ###################
    if ([String]::IsNullOrEmpty($azdenv.DEPLOY_API_CENTER) -or -not (Test-Path env:DEPLOY_API_CENTER)) {
        $apiCenterQuestion = "Do you want to deploy Azure API Center with managed portal and VS Code integration?"
        $deployApiCenter = Get-InteractiveMenuChooseUserSelection -Question $apiCenterQuestion -Answers $answerItems -Options $options
        
        azd env set DEPLOY_API_CENTER $deployApiCenter
    }

    ###################
    ## Create API Center Portal App Registration
    ###################
    Write-Host "Setting up API Center portal app registration..." -ForegroundColor Yellow
    ./scripts/api-center-appreg.ps1
    if ($? -ne $true) {
        Write-Host "Warning: Failed to create API Center portal app registration. The portal may not function correctly." -ForegroundColor Yellow
    }
}
Write-Host "Finished executing preprovision.ps1"