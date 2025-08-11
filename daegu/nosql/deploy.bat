@echo off
echo Starting deployment...

echo Getting DAX endpoint from Terraform...
for /f "tokens=*" %%i in ('terraform output -raw dax_endpoint 2^>nul') do set DAX_ENDPOINT=%%i

if "%DAX_ENDPOINT%"=="" (
    echo Warning: Could not get DAX endpoint from Terraform
    set DAX_ENDPOINT=placeholder-endpoint
)

echo DAX Endpoint: %DAX_ENDPOINT%

echo Updating app.py with DAX endpoint...
powershell -Command "(Get-Content src\app.py) -replace '\$\{dax_endpoint\}', '%DAX_ENDPOINT%' | Set-Content src\app.py"

echo Running terraform apply...
terraform apply -auto-approve

echo Deployment completed!