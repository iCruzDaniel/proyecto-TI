# deploy.ps1 - Script de despliegue para Windows PowerShell

Write-Host "🚀 Iniciando despliegue desde Windows..." -ForegroundColor Green

# Verificar que terraform esté instalado
if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Terraform no está instalado." -ForegroundColor Red
    Write-Host "Descárgalo desde: https://terraform.io/downloads.html" -ForegroundColor Yellow
    exit 1
}

# Verificar que ansible esté disponible (Docker o WSL)
Write-Host "⚠️  Para Ansible necesitarás usar WSL2 o Docker" -ForegroundColor Yellow

# Paso 1: Inicializar Terraform
Write-Host "Paso 1: Inicializando Terraform..." -ForegroundColor Cyan
terraform init

# Paso 2: Planificar
Write-Host "Paso 2: Planificando despliegue..." -ForegroundColor Cyan
terraform plan

# Confirmar
$confirm = Read-Host "¿Continuar con el despliegue? (y/N)"
if ($confirm -ne "y" -and $confirm -ne "Y") {
    Write-Host "Despliegue cancelado." -ForegroundColor Yellow
    exit 0
}

# Paso 3: Aplicar
Write-Host "Paso 3: Desplegando infraestructura..." -ForegroundColor Cyan
terraform apply -auto-approve

# Paso 4: Obtener outputs
Write-Host "Paso 4: Obteniendo información..." -ForegroundColor Cyan
$appUrl = terraform output -raw app_url
$lbIp = terraform output -raw load_balancer_ip
$bucketName = terraform output -raw bucket_name

# Configurar Ansible (requiere WSL o Docker)
Write-Host "Paso 5: Configurar droplets..." -ForegroundColor Cyan
Write-Host "⚠️  Ejecuta esto en WSL2:" -ForegroundColor Yellow
Write-Host "wsl" -ForegroundColor Gray
Write-Host "ansible-playbook -i inventory_dynamic.ini playbook.yml" -ForegroundColor Gray

# Mostrar resultados
Write-Host "`n🎉 Infraestructura desplegada!" -ForegroundColor Green
Write-Host "=========================" -ForegroundColor Cyan
Write-Host "🌐 App URL: $appUrl" -ForegroundColor White
Write-Host "⚖️  Load Balancer: $lbIp" -ForegroundColor White
Write-Host "🗄️  Bucket: $bucketName" -ForegroundColor White
Write-Host "`n💡 Para completar, ejecuta Ansible en WSL2 o Linux" -ForegroundColor Yellow