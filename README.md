# WhatsApp Flows Server - n8n Integration Fork

🚀 **Fork modificado** del [whatsapp-flows-server original](https://github.com/guilhermejansen/whatsapp-flows-server) con integración para webhooks externos (n8n).

## ✨ Características Adicionales

- ✅ **Integración con n8n:** Llama webhooks externos durante `data_exchange`
- ✅ **Datos dinámicos:** Horarios, disponibilidad, validaciones en tiempo real
- ✅ **Fallback automático:** Si el webhook falla, usa comportamiento original
- ✅ **Bajo acoplamiento:** No rompe funcionalidad existente

## 🔧 Variables de Entorno Nuevas
```bash
CALLBACK_WEBHOOK_URL=http://n8n_n8n_webhook:5678/webhook/my-flow
FLOW_ENDPOINT_TIMEOUT=10000  # Timeout en ms (default: 10000)
FLOW_ID=881518257773815
```

## 📦 Instalación con Docker

### Opción 1: Usar imagen pre-construida (próximamente)
```bash
docker pull men2985/whatsapp-flows-server:n8n-patched
```

### Opción 2: Construir desde código
```bash
git clone https://github.com/men2985/whatsapp_flows.git
cd whatsapp_flows
docker build -t whatsapp-flows-server:n8n-patched .
```

## 🚀 Despliegue

### Docker Compose
```yaml
version: '3.8'
services:
  whatsapp_flows:
    image: whatsapp-flows-server:n8n-patched
    environment:
      - CALLBACK_WEBHOOK_URL=http://n8n_webhook:5678/webhook/my-flow
      - FLOW_ENDPOINT_TIMEOUT=10000
      - FLOW_ID=881518257773815
      - DATABASE_URL=postgresql://user:pass@db:5432/flows
    ports:
      - "3000:3000"
```

### Docker Swarm
```bash
docker stack deploy -c docker-compose.yml whatsapp_flows
```

## 📝 Uso con n8n

### 1. Crear Workflow en n8n
```javascript
// Nodo Code en n8n
const body = $input.item.json.body;
const action = body.action;
const screen = body.screen;
const data = body.data || {};

if (action === 'data_exchange' && screen === 'SELECT_DATE') {
  // Obtener horarios disponibles de Cal.com, base de datos, etc.
  const availableTimes = await getTimesFromCalCom(data.selected_date);
  
  return {
    json: {
      version: "6.0",
      screen: "SELECT_TIME",
      data: {
        available_times: availableTimes
      }
    }
  };
}
```

### 2. Configurar Webhook
- **URL:** `https://webhook.n8.pbxai.online/webhook/my-flow`
- **Método:** POST
- **Respuesta:** JSON con estructura de WhatsApp Flows

## 📊 Rendimiento

| Escenario | Latencia |
|-----------|----------|
| Sin webhook (estático) | 25-90ms |
| Con webhook interno (Docker) | 300-400ms |
| Con webhook externo (HTTPS) | 600-900ms |

**Recomendación:** Usar comunicación interna Docker para mejor rendimiento.

## 🔄 Casos de Uso

1. **Calendario dinámico:** Integración con Cal.com, Google Calendar
2. **Disponibilidad en tiempo real:** Consultar stock, horarios, recursos
3. **Validaciones:** Verificar datos contra API externa
4. **Personalización:** Contenido dinámico según usuario
5. **Integraciones:** CRM, ERP, bases de datos personalizadas

## 📖 Documentación Detallada

Ver [MODIFICACIONES_N8N.md](./MODIFICACIONES_N8N.md) para detalles técnicos de los cambios.

## 🛠️ Archivos Modificados

- `src/domain/flows/services/FlowEngine.ts` - Lógica de llamada a webhook
- `src/application/use-cases/flows/HandleFlowRequestUseCase.ts` - Async/await

## 🤝 Contribuciones

Este es un fork personal para uso específico. Para el proyecto original, visita:
https://github.com/guilhermejansen/whatsapp-flows-server

## 📄 Licencia

Misma licencia que el proyecto original (MIT).

## 🙏 Créditos

- **Proyecto original:** [guilhermejansen/whatsapp-flows-server](https://github.com/guilhermejansen/whatsapp-flows-server)
- **Modificaciones n8n:** men2985
- **Fecha:** Diciembre 2024

## 📞 Soporte

Para issues relacionados con la integración n8n, abre un issue en este repositorio.
Para issues del servidor original, visita el repositorio upstream.
