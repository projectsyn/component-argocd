local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.argocd;


local namespace = kube.Namespace(params.namespace) {
  metadata+: {
    labels+: {
      SYNMonitoring: 'main',
      'app.kubernetes.io/part-of': 'argocd',
    },
  },
};

local config = [
  kube.ConfigMap('argocd-cm'),
  kube.ConfigMap('argocd-rbac-cm'),
  kube.ConfigMap('argocd-ssh-known-hosts-cm'),
  kube.ConfigMap('argocd-tls-certs-cm'),
  kube.Secret('argocd-secret') {
    data_: {
      'admin.password': '$2a$10$Te3THhmiGj7oFi5l5z3YveRcrHXalgrbGWRPrljzgL6kqR20CFkYq',
      'admin.passwordMtime': '2019-12-10T17:55:10CET',
    },
  },
];

{
  'namespace': namespace,
} + {
  ["%s" % [obj.metadata.name]]: obj + {
    metadata+: {
      namespace: params.namespace,
      labels+: {
        'app.kubernetes.io/part-of': 'argocd',
      },
    }
  } for obj in config
}
