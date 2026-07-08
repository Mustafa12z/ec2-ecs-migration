// Frontend runtime configuration.
//
// API_BASE controls where API requests are sent:
//   - ""  (empty)  => same origin as the page (recommended in production,
//                     since Nginx serves this frontend AND proxies /api/ and
//                     /health to the Flask app on the same host/port).
//   - "http://<ec2-ip-or-domain>" => point the frontend at a remote API,
//                     e.g. when opening index.html locally during development.
//
// A value saved via the "Change" button in the UI (localStorage) overrides this.
window.APP_CONFIG = {
  API_BASE: "",
};
