# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v2.0.0]

### Changed
- Upgrade ArgoCD from v1.7.4 to 1.8.7 ([#15])

### BREAKING CHANGES
- The version v2.0.0 does use a statefulset instead of a deployment and is only compatible with ArgoCD 1.8.
- It requires the steward component v2.0.0.

## [v1.0.0]

### Changed

- Open source component ([#1])
- Update Argo CD to v1.6.1
- Update Kapitan to v0.29.1 ([#3])
- Update Argo CD to v1.7.4 ([#5])
- Update deprecated parameters ([#8])
- Run Vault agent as user ([#10])
- Pull Kapitan image from docker.io/projectsyn/kapitan by default ([#12])
- Remove dependency on synsights ([#13])

### Added

- Ignore CA bundles of webhooks ([#2])
- Syn label to alert rules ([#7])
- Health check for Crossplane provider ([#11])

### Fixed

- Remove empty `finalizers` field on root app ([#2])
- Kapitan container image digest ([#4])

[Unreleased]: https://github.com/projectsyn/component-argocd/compare/v2.0.0...HEAD
[v1.0.0]: https://github.com/projectsyn/component-argocd/releases/tag/v1.0.0
[v2.0.0]: https://github.com/projectsyn/component-argocd/releases/tag/v2.0.0

[#1]: https://github.com/projectsyn/component-argocd/pull/1
[#2]: https://github.com/projectsyn/component-argocd/pull/2
[#3]: https://github.com/projectsyn/component-argocd/pull/3
[#4]: https://github.com/projectsyn/component-argocd/pull/4
[#5]: https://github.com/projectsyn/component-argocd/pull/5
[#7]: https://github.com/projectsyn/component-argocd/pull/7
[#8]: https://github.com/projectsyn/component-argocd/pull/8
[#10]: https://github.com/projectsyn/component-argocd/pull/10
[#11]: https://github.com/projectsyn/component-argocd/pull/11
[#12]: https://github.com/projectsyn/component-argocd/pull/12
[#13]: https://github.com/projectsyn/component-argocd/pull/13
[#15]: https://github.com/projectsyn/component-argocd/pull/15
