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
  kube.ConfigMap('argocd-cm') {
    data: {
      configManagementPlugins: |||
        - name: kapitan
          generate:
            command: [kapitan, refs, --reveal, --refs-path, ../../refs/, --file, ./]
      |||,
      repositories: '- url: ' + inv.parameters.cluster.catalog_url,
      'repository.credentials': |||
        - url: ssh://git@
          sshPrivateKeySecret:
            name: argo-ssh-key
            key: sshPrivateKey
      |||,
      'resource.customizations': |||
        admissionregistration.k8s.io/MutatingWebhookConfiguration:
          ignoreDifferences: |
            jsonPointers:
              - /webhooks/0/clientConfig/caBundle
        admissionregistration.k8s.io/ValidatingWebhookConfiguration:
          ignoreDifferences: |
            jsonPointers:
              - /webhooks/0/clientConfig/caBundle
        apiextensions.k8s.io/CustomResourceDefinition:
          ignoreDifferences: |
            jsonPointers:
              - /status
              - /spec/scope
        pkg.crossplane.io/Provider:
          health.lua: |
            hs = {}
            if obj.status ~= nil then
              if obj.status.conditions ~= nil then
                installed = false
                healthy = false
                for i, condition in ipairs(obj.status.conditions) do
                  if condition.type == "Installed" then
                    installed = condition.status == "True"
                    installed_message = condition.reason
                  elseif condition.type == "Healthy" then
                    healthy = condition.status == "True"
                    healthy_message = condition.reason
                  end
                end
                if installed and healthy then
                  hs.status = "Healthy"
                else
                  hs.status = "Degraded"
                end
                hs.message = installed_message .. " " .. healthy_message
                return hs
              end
            end

            hs.status = "Progressing"
            hs.message = "Waiting for provider to be installed"
            return hs
      |||,
      'application.instanceLabelKey': 'argocd.argoproj.io/instance',
    },
  },
  kube.ConfigMap('argocd-rbac-cm'),
  kube.ConfigMap('argocd-ssh-known-hosts-cm') {
    data: {
      ssh_known_hosts: |||
        bitbucket.org ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAubiN81eDcafrgMeLzaFPsw2kNvEcqTKl/VqLat/MaB33pZy0y3rJZtnqwR2qOOvbwKZYKiEO1O6VqNEBxKvJJelCq0dTXWT5pbO2gDXC6h6QDXCaHo6pOHGPUy+YBaGQRGuSusMEASYiWunYN0vCAI8QaXnWMXNMdFP3jHAJH0eDsoiGnLPBlBp4TNm6rYI74nMzgz3B9IikW4WVK+dc8KZJZWYjAuORU3jc1c/NPskD2ASinf8v3xnfXeukU0sJ5N6m5E8VLjObPEO+mN2t/FZTMZLiFqPWc/ALSqnMnnhwrNi2rbfg/rd/IpL8Le3pSBne8+seeFVBoGqzHM9yXw==
        github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==
        gitlab.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBFSMqzJeV9rUzU4kWitGjeR4PWSa29SPqJ1fVkhtj3Hw9xjLVXVYrU9QlYWrOLXBpQ6KWjbjTDTdDkoohFzgbEY=
        gitlab.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfuCHKVTjquxvt6CM6tdG4SLp1Btn/nOeHHE5UOzRdf
        gitlab.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCsj2bNKTBSpIYDEGk9KxsGh3mySTRgMtXL583qmBpzeQ+jqCMRgBqB98u3z++J1sKlXHWfM9dyhSevkMwSbhoR8XIq/U0tCNyokEi/ueaBMCvbcTHhO7FcwzY92WK4Yt0aGROY5qX2UKSeOvuP4D6TPqKF1onrSzH9bx9XUf2lEdWT/ia1NEKjunUqu1xOB/StKDHMoX4/OKyIzuS0q/T1zOATthvasJFoPrAjkohTyaDUz2LN5JoH839hViyEG82yB+MjcFV5MU3N1l1QL3cVUCh93xSaua1N85qivl+siMkPGbO5xR/En4iEY6K2XPASUEMaieWVNTRCtJ4S8H+9
        ssh.dev.azure.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7Hr1oTWqNqOlzGJOfGJ4NakVyIzf1rXYd4d7wo6jBlkLvCA4odBlL0mDUyZ0/QUfTTqeu+tm22gOsv+VrVTMk6vwRU75gY/y9ut5Mb3bR5BV58dKXyq9A9UeB5Cakehn5Zgm6x1mKoVyf+FFn26iYqXJRgzIZZcZ5V6hrE0Qg39kZm4az48o0AUbf6Sp4SLdvnuMa2sVNwHBboS7EJkm57XQPVU3/QpyNLHbWDdzwtrlS+ez30S3AdYhLKEOxAG8weOnyrtLJAUen9mTkol8oII1edf7mWWbWVf0nBmly21+nZcmCTISQBtdcyPaEno7fFQMDD26/s0lfKob4Kw8H
        vs-ssh.visualstudio.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7Hr1oTWqNqOlzGJOfGJ4NakVyIzf1rXYd4d7wo6jBlkLvCA4odBlL0mDUyZ0/QUfTTqeu+tm22gOsv+VrVTMk6vwRU75gY/y9ut5Mb3bR5BV58dKXyq9A9UeB5Cakehn5Zgm6x1mKoVyf+FFn26iYqXJRgzIZZcZ5V6hrE0Qg39kZm4az48o0AUbf6Sp4SLdvnuMa2sVNwHBboS7EJkm57XQPVU3/QpyNLHbWDdzwtrlS+ez30S3AdYhLKEOxAG8weOnyrtLJAUen9mTkol8oII1edf7mWWbWVf0nBmly21+nZcmCTISQBtdcyPaEno7fFQMDD26/s0lfKob4Kw8H
      ||| + params.ssh_known_hosts,
    },
  },
  kube.ConfigMap('argocd-tls-certs-cm'),
  kube.ConfigMap('argocd-gpg-keys-cm'),
  kube._Object('v1', 'Secret', 'argocd-secret') {
    type: 'Opaque',
  },
  kube._Object('v1', 'Secret', 'argo-ssh-key') {
    type: 'Opaque',
  },
];

{
  '00_namespace': namespace,
  [if params.monitoring.enabled then
    '20_monitoring']: import 'monitoring.libsonnet',
} + {
  ['10_%s' % [obj.metadata.name]]: obj {
    metadata+: {
      namespace: params.namespace,
      labels+: {
        'app.kubernetes.io/part-of': 'argocd',
      },
    },
  }
  for obj in config
}
