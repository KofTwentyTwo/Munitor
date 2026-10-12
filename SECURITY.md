# Security Policy

## Reporting a vulnerability

**Do not open a public issue for a security problem.**

Report it privately through GitHub's
[private vulnerability reporting](https://github.com/KofTwentyTwo/Munitor/security/advisories/new)
(the repository's **Security** tab, then **Report a vulnerability**). If that form is
unavailable, contact the maintainer privately through GitHub before disclosing anything.

Security contact: **James Maes** ([@KofTwentyTwo](https://github.com/KofTwentyTwo)),
maintainer.

Please include the affected orb version, the `.munitor.yml` pipeline type, how to
reproduce it, and the impact you see. Never include secrets or CircleCI context values.

## What to expect

KofTwentyTwo follows coordinated vulnerability disclosure. Timeframes are counted
from the day the report arrives and come from the
[KofTwentyTwo security program](https://github.com/KofTwentyTwo/standards/blob/main/policies/security-program.md):

| Step | Target |
| --- | --- |
| Acknowledge the report | 7 days |
| Assess it: confirm or reject, with a severity | 14 days |
| Release a fix for a CRITICAL vulnerability | 7 days |
| Release a fix for a HIGH vulnerability | 30 days |
| Release a fix for a MEDIUM vulnerability | 90 days |
| Release a fix for a LOW vulnerability | The next release |
| Publish the advisory (GitHub Security Advisory, CVE where applicable) | When the fix ships, or 90 days after the report, whichever comes first |

Reporters are credited in the advisory unless they ask not to be.

## Supported versions

| Version | Security fixes |
| --- | --- |
| 0.3.x (`kof22/munitor@0.3`) | Yes |
| Older | No; upgrade to the latest release |

Only the latest minor line receives fixes; a line ends when the next minor version is
published to the CircleCI orb registry.

## Scope notes

Munitor runs inside the consumer's CircleCI project with the consumer's contexts
(registry, GitHub, SonarCloud, NVD). Issues that let a generated pipeline leak context
secrets, push an image or GitOps change for the wrong commit, or bypass a security
gate are in scope.

## Published vulnerabilities

Fixed vulnerabilities are published as
[GitHub Security Advisories](https://github.com/KofTwentyTwo/Munitor/security/advisories).
