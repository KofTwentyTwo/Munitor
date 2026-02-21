version: 2.1

orbs:
  munitor: ${MUNITOR_ORB_SLUG}@${MUNITOR_ORB_VERSION}

workflows:
  pr-checks:
    jobs:
      - munitor/validate_repo:
          name: validate-repo
          filters:
            branches:
              only:
                - /feature\/.*/
                - /hotfix\/.*/
      - munitor/tf_validate:
          name: tf-validate
          environments: "${MUNITOR_TF_ENVIRONMENTS}"
          tf_path: ${MUNITOR_TF_PATH}
          base_path: ${MUNITOR_TF_LIVE_PATH}
          filters:
            branches:
              only:
                - /feature\/.*/
                - /hotfix\/.*/
      - munitor/tf_security_scan:
          name: tf-security-scan
          tf_path: ${MUNITOR_TF_PATH}
          checkov_skip: ${MUNITOR_CHECKOV_SKIP}
          filters:
            branches:
              only:
                - /feature\/.*/
                - /hotfix\/.*/
      - munitor/secrets_scan:
          name: secrets-scan
          filters:
            branches:
              only:
                - /feature\/.*/
                - /hotfix\/.*/
      ##IF_SAST##
      - munitor/sast_scan:
          name: sast-scan
          fail_on_findings: "${MUNITOR_SAST_FAIL_ON_FINDINGS}"
          filters:
            branches:
              only:
                - /feature\/.*/
                - /hotfix\/.*/
      ##ENDIF_SAST##

  develop:
    jobs:
      - munitor/validate_repo:
          name: validate-repo
          filters:
            branches:
              only: develop
      - munitor/tf_validate:
          name: tf-validate
          environments: "${MUNITOR_TF_ENVIRONMENTS}"
          tf_path: ${MUNITOR_TF_PATH}
          base_path: ${MUNITOR_TF_LIVE_PATH}
          filters:
            branches:
              only: develop
      - munitor/tf_security_scan:
          name: tf-security-scan
          tf_path: ${MUNITOR_TF_PATH}
          checkov_skip: ${MUNITOR_CHECKOV_SKIP}
          filters:
            branches:
              only: develop
      - munitor/secrets_scan:
          name: secrets-scan
          filters:
            branches:
              only: develop
      ##IF_SAST##
      - munitor/sast_scan:
          name: sast-scan
          fail_on_findings: "${MUNITOR_SAST_FAIL_ON_FINDINGS}"
          filters:
            branches:
              only: develop
      ##ENDIF_SAST##

  release-candidate:
    jobs:
      - munitor/validate_repo:
          name: validate-repo
          filters:
            branches:
              only:
                - /release\/.*/
      - munitor/tf_validate:
          name: tf-validate
          environments: "${MUNITOR_TF_ENVIRONMENTS}"
          tf_path: ${MUNITOR_TF_PATH}
          base_path: ${MUNITOR_TF_LIVE_PATH}
          filters:
            branches:
              only:
                - /release\/.*/
      - munitor/tf_security_scan:
          name: tf-security-scan
          tf_path: ${MUNITOR_TF_PATH}
          checkov_skip: ${MUNITOR_CHECKOV_SKIP}
          filters:
            branches:
              only:
                - /release\/.*/
      - munitor/secrets_scan:
          name: secrets-scan
          filters:
            branches:
              only:
                - /release\/.*/
      ##IF_SAST##
      - munitor/sast_scan:
          name: sast-scan
          fail_on_findings: "${MUNITOR_SAST_FAIL_ON_FINDINGS}"
          filters:
            branches:
              only:
                - /release\/.*/
      ##ENDIF_SAST##

  production:
    jobs:
      - munitor/validate_repo:
          name: validate-repo
          filters:
            branches:
              only: main
      - munitor/tf_validate:
          name: tf-validate
          environments: "${MUNITOR_TF_ENVIRONMENTS}"
          tf_path: ${MUNITOR_TF_PATH}
          base_path: ${MUNITOR_TF_LIVE_PATH}
          filters:
            branches:
              only: main
