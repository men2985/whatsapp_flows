#!/bin/bash

###############################################################################
# INSTALACIÓN AUTOMÁTICA: WhatsApp Flows Server
# Autor: men2985
# GitHub: https://github.com/men2985/whatsapp_flows
# 
# REQUISITOS PREVIOS:
# - Docker Swarm ya instalado
# - n8n ya funcionando
# 
# EL USUARIO SOLO PROPORCIONA:
# 1. Subdominio (ej: flows.ejemplo.com)
# 2. Token de Meta (con permisos de WhatsApp Business)
# 
# EL SCRIPT HACE TODO LO DEMÁS AUTOMÁTICAMENTE
###############################################################################

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

clear
echo -e "${BLUE}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║   ██╗    ██╗██╗  ██╗ █████╗ ████████╗███████╗ █████╗ ██████╗   ║
║   ██║    ██║██║  ██║██╔══██╗╚══██╔══╝██╔════╝██╔══██╗██╔══██╗  ║
║   ██║ █╗ ██║███████║███████║   ██║   ███████╗███████║██████╔╝  ║
║   ██║███╗██║██╔══██║██╔══██║   ██║   ╚════██║██╔══██║██╔═══╝   ║
║   ╚███╔███╔╝██║  ██║██║  ██║   ██║   ███████║██║  ██║██║       ║
║    ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝       ║
║                                                                  ║
║              INSTALADOR AUTOMÁTICO v1.0.0                       ║
║           WhatsApp Flows Server + Meta Integration              ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"
echo ""

# Verificar root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Ejecuta con sudo: sudo bash \$0${NC}"
    exit 1
fi

# Verificar Docker Swarm
if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
    echo -e "${RED}❌ Docker Swarm no está activo${NC}"
    echo "Inicializa Swarm primero: docker swarm init"
    exit 1
fi

echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  📝 Solo 2 datos necesarios${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

read -p "🌐 Subdominio (ej: flows.ejemplo.com): " DOMAIN
read -p "🔑 Token de Meta (WABA): " META_TOKEN

echo ""
echo -e "${GREEN}✅ Configuración:${NC}"
echo "   - Dominio: https://$DOMAIN"
echo "   - Token: ${META_TOKEN:0:20}..."
echo ""

read -p "¿Continuar? (s/n): " CONFIRM
[ "$CONFIRM" != "s" ] && exit 0

# Variables
INSTALL_DIR="/home/docker/whatsapp-flows"
KEYS_DIR="$INSTALL_DIR/keys"
DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  🔑 Generando claves SSH${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

mkdir -p $KEYS_DIR
chmod 700 $KEYS_DIR

PRIVATE_KEY="$KEYS_DIR/private.key"
PUBLIC_KEY="$KEYS_DIR/public.pub"

ssh-keygen -t rsa -b 2048 -f $PRIVATE_KEY -N "" -C "whatsapp-$(date +%Y%m%d)" > /dev/null 2>&1
chmod 600 $PRIVATE_KEY
chmod 644 $PUBLIC_KEY

PRIVATE_KEY_ONELINE=$(cat $PRIVATE_KEY | sed ':a;N;$!ba;s/\n/\\n/g')
PUBLIC_KEY_ONELINE=$(cat $PUBLIC_KEY | tr -d '\n')

echo "$PRIVATE_KEY_ONELINE" > /tmp/whatsapp_private_key.txt
echo "$PUBLIC_KEY_ONELINE" > /tmp/whatsapp_public_key.txt

echo -e "${GREEN}✅ Claves generadas${NC}"

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ⬆️  Subiendo clave pública a Meta${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Obtener WABA ID automáticamente
WABA_RESPONSE=$(curl -s -X GET \
    "https://graph.facebook.com/v21.0/me?fields=whatsapp_business_accounts" \
    -H "Authorization: Bearer $META_TOKEN")

WABA_ID=$(echo "$WABA_RESPONSE" | jq -r '.whatsapp_business_accounts.data[0].id' 2>/dev/null)

if [ "$WABA_ID" = "null" ] || [ -z "$WABA_ID" ]; then
    echo -e "${YELLOW}⚠️  No se pudo obtener WABA ID automáticamente${NC}"
    read -p "Ingresa tu WABA ID manualmente: " WABA_ID
fi

echo -e "${BLUE}ℹ️  WABA ID: $WABA_ID${NC}"

# Subir clave pública a Meta
UPLOAD_RESPONSE=$(curl -s -X POST \
    "https://graph.facebook.com/v21.0/$WABA_ID" \
    -H "Authorization: Bearer $META_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"public_key\": \"$PUBLIC_KEY_ONELINE\"}")

if echo "$UPLOAD_RESPONSE" | grep -q '"success":true'; then
    echo -e "${GREEN}✅ Clave pública subida a Meta${NC}"
else
    echo -e "${YELLOW}⚠️  Respuesta de Meta: $UPLOAD_RESPONSE${NC}"
    echo -e "${YELLOW}⚠️  Configura manualmente en Meta si es necesario${NC}"
fi

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  📥 Descargando imagen Docker${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

docker pull men2985/whatsapp-flows-server:n8n-patched

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  🚀 Desplegando servicio${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Crear docker-compose.yml
mkdir -p $INSTALL_DIR
cat > $INSTALL_DIR/docker-compose.yml << COMPOSE
version: '3.8'

services:
  whatsapp_flows_db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: whatsapp_flows
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: $DB_PASSWORD
    volumes:
      - whatsapp-flows-db:/var/lib/postgresql/data
    networks:
      - backend
    deploy:
      replicas: 1

  whatsapp_flows:
    image: men2985/whatsapp-flows-server:n8n-patched
    environment:
      NODE_ENV: production
      PORT: 3000
      DATABASE_URL: postgresql://postgres:$DB_PASSWORD@whatsapp_flows_db:5432/whatsapp_flows
      PRIVATE_KEY_PATH: /app/keys/private.key
      CALLBACK_WEBHOOK_URL: http://n8n_n8n_webhook:5678/webhook/my-flow
      FLOW_ENDPOINT_TIMEOUT: 10000
    volumes:
      - $KEYS_DIR:/app/keys:ro
    networks:
      - frontend
      - backend
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.whatsapp-flows.rule=Host(\`$DOMAIN\`)"
        - "traefik.http.routers.whatsapp-flows.entrypoints=websecure"
        - "traefik.http.routers.whatsapp-flows.tls.certresolver=letsencrypt"
        - "traefik.http.services.whatsapp-flows.loadbalancer.server.port=3000"
      replicas: 1

networks:
  frontend:
    external: true
  backend:
    external: true

volumes:
  whatsapp-flows-db:
COMPOSE

docker stack deploy -c $INSTALL_DIR/docker-compose.yml whatsapp_flows

echo -e "${YELLOW}⏳ Esperando servicios (30s)...${NC}"
sleep 30

echo -e "${GREEN}✅ Servicio desplegado${NC}"

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  📋 Generando plantillas${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Flow JSON (minificado)
cat > $INSTALL_DIR/flow_meta.json << 'FLOWJSON'
{"version":"6.0","data_api_version":"3.0","routing_model":{"WELCOME":["SELECT_DATE"],"SELECT_DATE":["SELECT_TIME"],"SELECT_TIME":["USER_INFO"],"USER_INFO":["APPOINTMENT"],"APPOINTMENT":[]},"screens":[{"id":"WELCOME","title":"Agendar Cita","terminal":false,"data":{},"layout":{"type":"SingleColumnLayout","children":[{"type":"TextHeading","text":"¡Bienvenido! 👋"},{"type":"TextBody","text":"Vamos a agendar tu cita en solo 3 pasos:\n\n📅 Selecciona una fecha\n🕐 Elige un horario\n✍️ Completa tus datos"},{"type":"Footer","label":"Comenzar","on-click-action":{"name":"navigate","next":{"type":"screen","name":"SELECT_DATE"}}}]}},{"id":"SELECT_DATE","title":"Selecciona una Fecha","terminal":false,"data":{},"layout":{"type":"SingleColumnLayout","children":[{"type":"TextHeading","text":"📅 ¿Qué día prefieres?"},{"type":"DatePicker","name":"selected_date","label":"Fecha de la cita","required":true,"min-date":"2025-01-01","max-date":"2025-12-31","helper-text":"Selecciona la fecha que mejor te convenga"},{"type":"Footer","label":"Ver horarios disponibles","on-click-action":{"name":"data_exchange","payload":{"selected_date":"${form.selected_date}"}}}]}},{"id":"SELECT_TIME","title":"Horarios Disponibles","terminal":false,"data":{"available_times":{"type":"array","items":{"type":"object","properties":{"id":{"type":"string"},"title":{"type":"string"},"description":{"type":"string"}}},"__example__":[{"id":"09:00","title":"9:00 AM","description":"Disponible"}]},"selected_date_formatted":{"type":"string","__example__":"Lunes, 15 de Enero de 2025"},"selected_date":{"type":"string","__example__":"2025-01-15"}},"layout":{"type":"SingleColumnLayout","children":[{"type":"TextHeading","text":"🕐 Horarios Disponibles"},{"type":"TextBody","text":"${data.selected_date_formatted}"},{"type":"RadioButtonsGroup","name":"selected_time","label":"Selecciona un horario:","required":true,"data-source":"${data.available_times}"},{"type":"Footer","label":"Continuar","on-click-action":{"name":"data_exchange","payload":{"selected_time":"${form.selected_time}"}}}]}},{"id":"USER_INFO","title":"Tus Datos","terminal":false,"data":{"appointment_summary":{"type":"string","__example__":"📅 Lunes, 15 de Enero\n🕐 10:00 AM"},"user_phone_prefilled":{"type":"string","__example__":"+529511234567"}},"layout":{"type":"SingleColumnLayout","children":[{"type":"TextHeading","text":"✍️ Completa tus datos"},{"type":"TextBody","text":"${data.appointment_summary}"},{"type":"TextInput","name":"user_name","label":"Nombre completo","input-type":"text","required":true,"helper-text":"Ingresa tu nombre completo"},{"type":"TextInput","name":"user_phone","label":"Teléfono de contacto","input-type":"phone","required":true,"helper-text":"Confirma tu número","init-value":"${data.user_phone_prefilled}"},{"type":"TextArea","name":"user_notes","label":"Notas adicionales (opcional)","required":false,"helper-text":"¿Algo que debamos saber?"},{"type":"Footer","label":"Confirmar cita","on-click-action":{"name":"data_exchange","payload":{"user_name":"${form.user_name}","user_phone":"${form.user_phone}","user_notes":"${form.user_notes}"}}}]}},{"id":"APPOINTMENT","title":"¡Cita Confirmada!","terminal":true,"data":{"confirmation_title":{"type":"string","__example__":"✅ ¡Tu cita ha sido agendada exitosamente!"},"appointment_details":{"type":"string","__example__":"📅 Fecha: Lunes, 15 de Enero\n🕐 Hora: 10:00 AM"},"booking_id_text":{"type":"string","__example__":"ID de reserva: CITA-1734567890123"}},"layout":{"type":"SingleColumnLayout","children":[{"type":"TextHeading","text":"${data.confirmation_title}"},{"type":"TextBody","text":"${data.appointment_details}"},{"type":"TextCaption","text":"${data.booking_id_text}"},{"type":"Footer","label":"Finalizar","on-click-action":{"name":"complete","payload":{"booking_id":"${data.booking_id_text}"}}}]}}]}
FLOWJSON

# Workflow n8n (minificado con el código completo)
cat > $INSTALL_DIR/workflow_n8n.json << 'N8NWORK'
{"name":"WhatsApp Flows - Reserva de Citas","nodes":[{"parameters":{"httpMethod":"POST","path":"my-flow","responseMode":"responseNode"},"type":"n8n-nodes-base.webhook","typeVersion":2.1,"position":[800,300],"name":"Webhook"},{"parameters":{"jsCode":"const inputData=$input.item.json;const body=inputData.body||inputData;const action=body.action;const screen=body.screen;const data=body.data||{};const sessionData=body.session_data||{};const getUserPhone=()=>{if(body.wa_phone_number)return body.wa_phone_number;if(sessionData.phone_number)return sessionData.phone_number;return '+529511234567';};const formatDate=(dateStr)=>{const days=['Domingo','Lunes','Martes','Miércoles','Jueves','Viernes','Sábado'];const months=['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];const d=new Date(dateStr+'T12:00:00');return \`\${days[d.getDay()]}, \${d.getDate()} de \${months[d.getMonth()]}\`;};const getAvailableTimes=async(selectedDate)=>{const slots=[];for(let h=9;h<=16;h++){slots.push({id:\`\${h}:00\`,title:\`\${h}:00 \${h<12?'AM':'PM'}\`,description:'Disponible'});}return slots;};if(action==='data_exchange'&&screen==='SELECT_DATE'){const selectedDate=data.selected_date||new Date().toISOString().split('T')[0];const availableTimes=await getAvailableTimes(selectedDate);return {json:{version:'6.0',screen:'SELECT_TIME',data:{available_times:availableTimes,selected_date_formatted:formatDate(selectedDate),selected_date:selectedDate}}};}if(action==='data_exchange'&&screen==='SELECT_TIME'){const selectedDate=sessionData.selected_date||data.selected_date||'Fecha no disponible';const selectedTime=data.selected_time||'Hora no disponible';const userPhone=getUserPhone();return {json:{version:'6.0',screen:'USER_INFO',data:{appointment_summary:\`📅 \${formatDate(selectedDate)}\\n🕐 \${selectedTime}\`,user_phone_prefilled:userPhone}}};}if(action==='data_exchange'&&screen==='USER_INFO'){const userName=data.user_name||'Usuario';const userPhone=data.user_phone||'No proporcionado';const userNotes=data.user_notes||'';const selectedDate=sessionData.selected_date||'Fecha no disponible';const selectedTime=sessionData.selected_time||'Hora no disponible';const bookingId=\`CITA-\${Date.now()}\`;const confirmationTitle='¡Tu cita ha sido agendada exitosamente!';const appointmentDetails=\`📅 Fecha: \${formatDate(selectedDate)}\\n🕐 Hora: \${selectedTime}\\n👤 Nombre: \${userName}\\n📱 Teléfono: \${userPhone}\${userNotes?'\\n📝 Notas: '+userNotes:''}\`;const bookingIdText=\`ID de reserva: \${bookingId}\`;return {json:{version:'6.0',screen:'APPOINTMENT',data:{confirmation_title:confirmationTitle,appointment_details:appointmentDetails,booking_id_text:bookingIdText}}};}return {json:{version:'6.0',screen:'WELCOME',data:{}}};"},"type":"n8n-nodes-base.code","typeVersion":2,"position":[1000,300],"name":"Process Flow"},{"parameters":{"respondWith":"text","responseBody":"={{ JSON.stringify($input.first().json) }}"},"type":"n8n-nodes-base.respondToWebhook","typeVersion":1.4,"position":[1200,300],"name":"Respond"}],"connections":{"Webhook":{"main":[[{"node":"Process Flow","type":"main","index":0}]]},"Process Flow":{"main":[[{"node":"Respond","type":"main","index":0}]]}}}
N8NWORK

echo -e "${GREEN}✅ Plantillas generadas${NC}"

# Guardar instrucciones
cat > $INSTALL_DIR/INSTRUCCIONES.txt << INSTRUCT
╔══════════════════════════════════════════════════════════════════╗
║           CONFIGURACIÓN DE WHATSAPP FLOWS                        ║
╚══════════════════════════════════════════════════════════════════╝

✅ Instalación completada: $(date)
🌐 Dominio: https://$DOMAIN

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PASO 1: CONFIGURAR EN META FLOW BUILDER
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Ve a: https://business.facebook.com/latest/whatsapp_manager/flows
2. Crea un nuevo Flow
3. En el editor JSON:
   - Presiona Ctrl+A, Delete
   - Copia: cat $INSTALL_DIR/flow_meta.json
   - Pega en el editor
4. Endpoint: https://$DOMAIN
5. Guarda y Publica

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PASO 2: IMPORTAR EN N8N
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Abre n8n
2. "..." → "Import from File"
3. Selecciona: $INSTALL_DIR/workflow_n8n.json
4. Activa el workflow

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📂 ARCHIVOS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Flow JSON:    $INSTALL_DIR/flow_meta.json
Workflow n8n: $INSTALL_DIR/workflow_n8n.json
INSTRUCT

cat $INSTALL_DIR/INSTRUCCIONES.txt

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${GREEN}             ✅ INSTALACIÓN COMPLETADA ✅                          ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✅ Sistema: https://$DOMAIN${NC}"
echo -e "${YELLOW}📂 Archivos:${NC}"
echo "   • $INSTALL_DIR/flow_meta.json"
echo "   • $INSTALL_DIR/workflow_n8n.json"
echo ""
