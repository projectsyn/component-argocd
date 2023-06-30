local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.argocd;
local name = 'argocd-hooks';

local role = kube.Role(name) {
  metadata+: {
    namespace: params.namespace,
    annotations+: {
      'argocd.argoproj.io/hook': 'PreSync',
    },
  },
  rules: [
    {
      apiGroups: [ 'apps' ],
      resources: [ 'deployments', 'statefulsets' ],
      verbs: [ 'list', 'get', 'update', 'patch' ],
    },
    {
      apiGroups: [ '' ],
      resources: [ 'services' ],
      verbs: [ 'list', 'get', 'update', 'patch' ],
    },
  ],
};

local serviceAccount = kube.ServiceAccount(name) {
  metadata+: {
    namespace: params.namespace,
    annotations+: {
      'argocd.argoproj.io/hook': 'PreSync',
    },
  },
};

local roleBinding = kube.RoleBinding(name) {
  metadata+: {
    namespace: params.namespace,
    annotations+: {
      'argocd.argoproj.io/hook': 'PreSync',
    },
  },
  subjects_: [ serviceAccount ],
  roleRef_: role,
};


local createJob(jobName, hook, args) = kube.Job(jobName) {
  metadata+: {
    namespace: params.namespace,
    name:: '',
    generateName: std.format('%s-', jobName),
    labels+: {
      name:: '',
    },
    annotations+: {
      'argocd.argoproj.io/hook': hook,
      'argocd.argoproj.io/hook-delete-policy': 'HookSucceeded',
    },
  },
  spec+: {
    template+: {
      spec+: {
        serviceAccountName: serviceAccount.metadata.name,
        containers_+: {
          annotate_argocd: kube.Container(jobName) {
            workingDir: '/home',
            image: '%(registry)s/%(repository)s:%(tag)s' % params.images.kubectl,
            command: [ 'kubectl' ],
            args: args,
            env: [
              { name: 'HOME', value: '/home' },
            ],
            volumeMounts: [
              { name: 'home', mountPath: '/home' },
            ],
          },
        },
        volumes+: [
          { name: 'home', emptyDir: {} },
        ],
      },
    },
  },
};

local postSyncJob = createJob(
  'argocd-post-sync', 'PostSync', [
    '-n',
    params.namespace,
    'annotate',
    'deployment,statefulset,service',
    '-l',
    'steward.syn.tools/bootstrap=true',
    'argocd.argoproj.io/sync-options-',
  ]
);

[ role, serviceAccount, roleBinding, postSyncJob ]
