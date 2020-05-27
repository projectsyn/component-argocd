local com = import 'lib/commodore.libjsonnet';
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
              alert: 'ArgoCDSyncFailed',
              expr: 'rate(k8up_jobs_failed_counter[1d]) > 0',
              'for': '1m',
              labels: {
                severity: 'critical',
              },
              annotations: {
                description: 'Job in {{ $labels.namespace }} of type {{ $labels.jobType }} failed',
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
  //alert_rules,
]
