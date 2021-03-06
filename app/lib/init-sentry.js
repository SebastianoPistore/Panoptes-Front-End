import { init } from '@sentry/browser';
import { Integrations } from '@sentry/tracing';

export default function initSentry() {
  init({
    dsn: 'https://36a5af57df8b426ba710c0accec90544@o274434.ingest.sentry.io/5623615',
    integrations: [new Integrations.BrowserTracing()],
    tracesSampleRate: 1.0
  });
}
