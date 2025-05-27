#!/bin/bash

# deploy.sh - Script para desplegar toda la infraestructura

set -e  # Salir si hay algún error

echo "🚀 Iniciando despliegue de infraestructura..."

# Colores para los mensajes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Función para mostrar mensajes
show_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

show_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

show_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar que terraform esté instalado
if ! command -v terraform &> /dev/null; then
    show_error "Terraform no está instalado. Por favor instálalo primero."
    exit 1
fi

# Verificar que ansible esté instalado
if ! command -v ansible &> /dev/null; then
    show_error "Ansible no está instalado. Por favor instálalo primero."
    exit 1
fi

# Paso 1: Inicializar Terraform
show_message "Paso 1: Inicializando Terraform..."
terraform init

# Paso 2: Planificar el despliegue
show_message "Paso 2: Planificando el despliegue..."
terraform plan

# Confirmar el despliegue
read -p "¿Quieres continuar con el despliegue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    show_warning "Despliegue cancelado."
    exit 0
fi

# Paso 3: Aplicar la configuración de Terraform
show_message "Paso 3: Desplegando infraestructura con Terraform..."
terraform apply -auto-approve

# Paso 4: Obtener las IPs de los droplets
show_message "Paso 4: Obteniendo información de los droplets..."
DROPLET_IPS=$(terraform output -json droplet_ips | jq -r 'to_entries[] | "\(.key) ansible_host=\(.value.public_ip) ansible_user=root"')

# Crear inventario dinámico para Ansible
show_message "Paso 5: Creando inventario de Ansible..."
cat > inventory_dynamic.ini << EOF
[api_servers]
$DROPLET_IPS

[api_servers:vars]
ansible_ssh_private_key_file=~/.ssh/id_rsa
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

# Esperar a que los droplets estén listos
show_message "Paso 6: Esperando a que los droplets estén listos..."
sleep 30

# Obtener variables de entorno de Terraform
DATABASE_URL=$(terraform output -raw database_connection)
BUCKET_NAME=$(terraform output -raw bucket_name)

# Paso 7: Configurar droplets con Ansible
show_message "Paso 7: Configurando droplets con Ansible..."
ansible-playbook -i inventory_dynamic.ini playbook.yml \
    --extra-vars "database_url=$DATABASE_URL" \
    --extra-vars "bucket_name=$BUCKET_NAME"

# Mostrar información final
show_message "🎉 ¡Despliegue completado exitosamente!"
echo
echo "📋 Información importante:"
echo "========================="
echo "🌐 URL de la aplicación: $(terraform output -raw app_url)"
echo "⚖️  IP del Load Balancer: $(terraform output -raw load_balancer_ip)"
echo "🗄️  Nombre del Bucket: $(terraform output -raw bucket_name)"
echo
echo "🔗 Las APIs están disponibles en:"
echo "   - API 1: http://$(terraform output -raw load_balancer_ip)/api1/"
echo "   - API 2: http://$(terraform output -raw load_balancer_ip)/api2/"
echo
echo "💡 Para destruir la infraestructura ejecuta: terraform destroy"