local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.argocd;

local serviceMonitor(name) =
  kube._Object('monitoring.coreos.com/v1', 'ServiceMonitor', name) {
    metadata+: {
      namespace: params.namespace,
      labels+: {
        'app.kubernetes.io/name': name,
        'app.kubernetes.io/part-of': 'argocd',
      },
    },
    spec: {
      endpoints: [{
        port: 'metrics',
      }],
      selector: {
        matchLabels: {
          'app.kubernetes.io/name': name,
          'app.kubernetes.io/part-of': 'argocd',
        },
      },
    },
  };

local alert_rules =
  kube._Object('monitoring.coreos.com/v1', 'PrometheusRule', 'argocd') {
    metadata+: {
      namespace: params.namespace,
      labels+: {
        prometheus: inv.parameters.synsights.prometheus.name,
        role: 'alert-rules',
      },
    },
    spec: {
      groups: [
        {
          name: 'argocd.rules',
          rules: [
            {
              alert: 'ArgoCDAppUnsynced',
              expr: 'argocd_app_info{exported_namespace="' + params.namespace + '", sync_status!="Synced"} > 0',
              'for': '10m',
              labels: {
                severity: 'warning',
              },
              annotations: {
                description: 'Argo CD app {{ $labels.name }} is not synced',
              },
            },
            {
              alert: 'ArgoCDAppUnhealthy',
              expr: 'argocd_app_info{exported_namespace="' + params.namespace + '", health_status!="Healthy"} > 0',
              'for': '10m',
              labels: {
                severity: 'critical',
              },
              annotations: {
                description: 'Argo CD app {{ $labels.name }} is not healthy',
              },
            },
            {
              alert: 'ArgoCDDown',
              expr: 'up{namespace="' + params.namespace + '", job=~"^argocd-.+$"} != 1',
              'for': '5m',
              labels: {
                severity: 'critical',
              },
              annotations: {
                description: 'Argo CD job {{ $labels.job }} is down',
              },
            },
          ],
        },
      ],
    },
  };

[
  serviceMonitor('argocd-metrics'),
  serviceMonitor('argocd-server-metrics'),
  serviceMonitor('argocd-repo-server'),
  alert_rules,
]
