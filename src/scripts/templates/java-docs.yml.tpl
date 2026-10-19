version: 2.1

orbs:
  munitor: ${MUNITOR_ORB_SLUG}@${MUNITOR_ORB_VERSION}

workflows:
  docs-checks:
    jobs:
      - munitor/secrets_scan:
          name: secrets-scan
      - munitor/ci_ready:
          name: ci-ready
          requires:
            - secrets-scan
