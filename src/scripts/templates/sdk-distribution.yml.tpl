version: 2.1

orbs:
  faber: ${FABER_ORB_SLUG}@${FABER_ORB_VERSION}

workflows:
  pr-validate:
    when:
      not:
        equal: [main, << pipeline.git.branch >>]
    jobs:
      - faber/secrets_scan:
          name: secrets-scan

  release:
    jobs:
      - faber/sdk_release:
          name: sdk-release
          context:
            - ${FABER_CONTEXT_GITHUB}
          filters:
            branches:
              ignore: /.*/
            tags:
              only: /^v[0-9]+\.[0-9]+\.[0-9]+$/
