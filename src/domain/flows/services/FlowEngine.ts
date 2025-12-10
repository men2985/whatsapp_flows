import { Flow } from '../entities/Flow';
import { FlowSession } from '../entities/FlowSession';
import { ValidationError } from '../../../shared/errors/ValidationError';
import { FLOW_ACTIONS } from '../../../shared/constants/flow-actions';
import axios from 'axios';

const CALLBACK_WEBHOOK_URL = process.env.CALLBACK_WEBHOOK_URL;
const FLOW_ENDPOINT_TIMEOUT = parseInt(process.env.FLOW_ENDPOINT_TIMEOUT || '10000');

export class FlowEngine {
  processInit(flow: Flow, session: FlowSession) {
    const firstScreen = flow.getFirstScreen();
    session.navigateToScreen(firstScreen.id);
    return {
      version: flow.version,
      screen: firstScreen.id,
      data: firstScreen.data || {},
    };
  }

  async processDataExchange(
    flow: Flow,
    session: FlowSession,
    incomingData: Record<string, any>,
    currentScreen?: string
  ) {
    session.updateSessionData(incomingData);

    // Call n8n webhook if configured
    if (CALLBACK_WEBHOOK_URL && incomingData) {
      try {
        console.log('🔗 Calling n8n webhook:', CALLBACK_WEBHOOK_URL);
        
        const response = await axios.post(
          CALLBACK_WEBHOOK_URL,
          {
            action: 'data_exchange',
            screen: currentScreen,
            data: incomingData,
            session_data: session.sessionData,
            flow_token: session.flowToken
          },
          {
            timeout: FLOW_ENDPOINT_TIMEOUT,
            headers: { 'Content-Type': 'application/json' }
          }
        );

        console.log('✅ n8n response received');
        
        if (response.data && response.data.screen) {
          return response.data;
        }
      } catch (error: any) {
        console.error('❌ n8n webhook failed:', error.message);
      }
    }

    // Fallback to default behavior
    if (!currentScreen && session.currentScreen) {
      currentScreen = session.currentScreen;
    }
    if (!currentScreen) {
      throw new ValidationError('Current screen not specified');
    }
    const screen = flow.getScreen(currentScreen);
    if (!screen) {
      throw new ValidationError(`Screen '${currentScreen}' not found in flow`);
    }
    return {
      version: flow.version,
      screen: currentScreen,
      data: {
        ...screen.data,
        ...session.sessionData,
      },
    };
  }

  processNavigate(flow: Flow, session: FlowSession, nextScreen: string, incomingData?: Record<string, any>) {
    if (incomingData) session.updateSessionData(incomingData);
    session.navigateToScreen(nextScreen);
    const screen = flow.getScreen(nextScreen);
    if (!screen) throw new ValidationError(`Screen '${nextScreen}' not found in flow`);
    return {
      version: flow.version,
      screen: nextScreen,
      data: { ...screen.data, ...session.sessionData },
    };
  }

  processComplete(flow: Flow, session: FlowSession, finalData?: Record<string, any>) {
    if (finalData) session.updateSessionData(finalData);
    session.complete();
    return { version: flow.version, data: { acknowledged: true } };
  }

  processPing() {
    return { version: '7.2', data: { status: 'active' } };
  }

  async processAction(
    action: string,
    flow: Flow,
    session: FlowSession,
    data?: Record<string, any>,
    currentScreen?: string,
    nextScreen?: string
  ) {
    switch (action) {
      case FLOW_ACTIONS.PING: return this.processPing();
      case FLOW_ACTIONS.INIT: return this.processInit(flow, session);
      case FLOW_ACTIONS.DATA_EXCHANGE: return await this.processDataExchange(flow, session, data || {}, currentScreen);
      case FLOW_ACTIONS.NAVIGATE:
        if (!nextScreen) throw new ValidationError('Next screen must be specified for navigate action');
        return this.processNavigate(flow, session, nextScreen, data);
      case FLOW_ACTIONS.COMPLETE: return this.processComplete(flow, session, data);
      default: throw new ValidationError(`Unknown action: ${action}`);
    }
  }
}
