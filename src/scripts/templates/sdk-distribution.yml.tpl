version: 2.1

orbs:
  munitor: ${MUNITOR_ORB_SLUG}@${MUNITOR_ORB_VERSION}

workflows:
  pr-validate:
    when:
      not:
        equal: [main, << pipeline.git.branch >>]
    jobs:
      - munitor/secrets_scan:
          name: secrets-scan

  release:
    jobs:
      - munitor/sdk_release:
          name: sdk-release
          context:
            - ${MUNITOR_CONTEXT_GITHUB}
          filters:
            branches:
              ignore: /.*/
            tags:
              only: /^v[0-9]+\.[0-9]+\.[0-9]+$/
