local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.argocd;
local common = import 'common.libsonnet';
local name = 'argocd-hooks';

local role = kube.Role(name) {
  metadata+: {
    namespace: params.namespace,
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
  },
};

local roleBinding = kube.RoleBinding(name) {
  metadata+: {
    namespace: params.namespace,
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
            image: common.render_image('kubectl', include_tag=true),
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
