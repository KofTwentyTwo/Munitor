version: 2.1

orbs:
  faber: ${FABER_ORB_SLUG}@${FABER_ORB_VERSION}

workflows:
  pr-checks:
    jobs:
      - faber/validate_repo:
          name: validate-repo
          filters:
            branches:
              only:
                - /feature\/.*/
                - /hotfix\/.*/
      - faber/tf_validate:
          name: tf-validate
          environments: "${FABER_TF_ENVIRONMENTS}"
          tf_path: ${FABER_TF_PATH}
          base_path: ${FABER_TF_LIVE_PATH}
          filters:
            branches:
              only:
                - /feature\/.*/
                - /hotfix\/.*/
      - faber/tf_security_scan:
          name: tf-security-scan
          tf_path: ${FABER_TF_PATH}
          checkov_skip: ${FABER_CHECKOV_SKIP}
          filters:
            branches:
              only:
                - /feature\/.*/
                - /hotfix\/.*/
      - faber/secrets_scan:
          name: secrets-scan
          filters:
            branches:
              only:
                - /feature\/.*/
                - /hotfix\/.*/
      ##IF_SAST##
      - faber/sast_scan:
          name: sast-scan
          fail_on_findings: "${FABER_SAST_FAIL_ON_FINDINGS}"
          filters:
            branches:
              only:
                - /feature\/.*/
                - /hotfix\/.*/
      ##ENDIF_SAST##

  develop:
    jobs:
      - faber/validate_repo:
          name: validate-repo
          filters:
            branches:
              only: develop
      - faber/tf_validate:
          name: tf-validate
          environments: "${FABER_TF_ENVIRONMENTS}"
          tf_path: ${FABER_TF_PATH}
          base_path: ${FABER_TF_LIVE_PATH}
          filters:
            branches:
              only: develop
      - faber/tf_security_scan:
          name: tf-security-scan
          tf_path: ${FABER_TF_PATH}
          checkov_skip: ${FABER_CHECKOV_SKIP}
          filters:
            branches:
              only: develop
      - faber/secrets_scan:
          name: secrets-scan
          filters:
            branches:
              only: develop
      ##IF_SAST##
      - faber/sast_scan:
          name: sast-scan
          fail_on_findings: "${FABER_SAST_FAIL_ON_FINDINGS}"
          filters:
            branches:
              only: develop
      ##ENDIF_SAST##

  release-candidate:
    jobs:
      - faber/validate_repo:
          name: validate-repo
          filters:
            branches:
              only:
                - /release\/.*/
      - faber/tf_validate:
          name: tf-validate
          environments: "${FABER_TF_ENVIRONMENTS}"
          tf_path: ${FABER_TF_PATH}
          base_path: ${FABER_TF_LIVE_PATH}
          filters:
            branches:
              only:
                - /release\/.*/
      - faber/tf_security_scan:
          name: tf-security-scan
          tf_path: ${FABER_TF_PATH}
          checkov_skip: ${FABER_CHECKOV_SKIP}
          filters:
            branches:
              only:
                - /release\/.*/
      - faber/secrets_scan:
          name: secrets-scan
          filters:
            branches:
              only:
                - /release\/.*/
      ##IF_SAST##
      - faber/sast_scan:
          name: sast-scan
          fail_on_findings: "${FABER_SAST_FAIL_ON_FINDINGS}"
          filters:
            branches:
              only:
                - /release\/.*/
      ##ENDIF_SAST##

  production:
    jobs:
      - faber/validate_repo:
          name: validate-repo
          filters:
            branches:
              only: main
      - faber/tf_validate:
          name: tf-validate
          environments: "${FABER_TF_ENVIRONMENTS}"
          tf_path: ${FABER_TF_PATH}
          base_path: ${FABER_TF_LIVE_PATH}
          filters:
            branches:
              only: main
