version: 2.1

orbs:
  faber: ${FABER_ORB_SLUG}@${FABER_ORB_VERSION}

workflows:
  pr-checks:
    jobs:
      - faber/npm_build_and_test:
          name: build-and-test
          node_version: "${FABER_NODE_VERSION}"
          ##IF_NPM_AUTH##
          npm_auth: true
          npm_scopes: '${FABER_NPM_SCOPES}'
          npm_default_scope: '${FABER_NPM_DEFAULT_SCOPE}'
          ##ENDIF_NPM_AUTH##
          ##IF_SERVICES##
          services: '${FABER_SERVICES_JSON}'
          ##ENDIF_SERVICES##
          ##IF_TEST_SETUP##
          test_setup: ${FABER_TEST_SETUP_SCRIPT}
          ##ENDIF_TEST_SETUP##
          ##IF_CUSTOM_TEST##
          test_commands: '${FABER_TEST_COMMANDS_JSON}'
          ##ENDIF_CUSTOM_TEST##
          context:
            - ${FABER_CONTEXT_GITHUB}
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
      - faber/sast_scan:
          name: sast-scan
          fail_on_findings: "${FABER_SAST_FAIL_ON_FINDINGS}"
          filters:
            branches:
              only:
                - /feature\/.*/
                - /hotfix\/.*/
      - faber/npm_code_quality:
          name: code-quality
          requires:
            - build-and-test
          filters:
            branches:
              only:
                - /feature\/.*/
                - /hotfix\/.*/
      - faber/npm_coverage:
          name: coverage
          min_coverage: "${FABER_COVERAGE_MIN}"
          coverage_tool: ${FABER_COVERAGE_TOOL}
          ##IF_COVERAGE_CMD##
          coverage_command: ${FABER_COVERAGE_COMMAND}
          ##ENDIF_COVERAGE_CMD##
          requires:
            - build-and-test
          filters:
            branches:
              only:
                - /feature\/.*/
                - /hotfix\/.*/
      - faber/npm_security_scan:
          name: security-scan
          requires:
            - build-and-test
          filters:
            branches:
              only:
                - /feature\/.*/
                - /hotfix\/.*/
      ##IF_E2E##
      - faber/npm_e2e_test:
          name: e2e-tests
          requires:
            - build-and-test
          filters:
            branches:
              only:
                - /feature\/.*/
                - /hotfix\/.*/
      ##ENDIF_E2E##

  ##INCLUDE_DEPLOY node-api-deploy develop develop ${FABER_CD_ENV_DEVELOP}##
  ##INCLUDE_DEPLOY node-api-deploy staging staging ${FABER_CD_ENV_STAGING}##

  release-candidate:
    jobs:
      - faber/npm_build_and_test:
          name: build-and-test
          node_version: "${FABER_NODE_VERSION}"
          ##IF_NPM_AUTH##
          npm_auth: true
          npm_scopes: '${FABER_NPM_SCOPES}'
          npm_default_scope: '${FABER_NPM_DEFAULT_SCOPE}'
          ##ENDIF_NPM_AUTH##
          ##IF_SERVICES##
          services: '${FABER_SERVICES_JSON}'
          ##ENDIF_SERVICES##
          ##IF_TEST_SETUP##
          test_setup: ${FABER_TEST_SETUP_SCRIPT}
          ##ENDIF_TEST_SETUP##
          ##IF_CUSTOM_TEST##
          test_commands: '${FABER_TEST_COMMANDS_JSON}'
          ##ENDIF_CUSTOM_TEST##
          context:
            - ${FABER_CONTEXT_GITHUB}
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
      - faber/sast_scan:
          name: sast-scan
          fail_on_findings: "${FABER_SAST_FAIL_ON_FINDINGS}"
          filters:
            branches:
              only:
                - /release\/.*/
      - faber/npm_code_quality:
          name: code-quality
          requires:
            - build-and-test
          filters:
            branches:
              only:
                - /release\/.*/
      - faber/npm_coverage:
          name: coverage
          min_coverage: "${FABER_COVERAGE_MIN}"
          coverage_tool: ${FABER_COVERAGE_TOOL}
          ##IF_COVERAGE_CMD##
          coverage_command: ${FABER_COVERAGE_COMMAND}
          ##ENDIF_COVERAGE_CMD##
          requires:
            - build-and-test
          filters:
            branches:
              only:
                - /release\/.*/
      - faber/npm_security_scan:
          name: security-scan
          requires:
            - build-and-test
          filters:
            branches:
              only:
                - /release\/.*/
      ##IF_E2E##
      - faber/npm_e2e_test:
          name: e2e-tests
          requires:
            - build-and-test
          filters:
            branches:
              only:
                - /release\/.*/
      ##ENDIF_E2E##
      ##IF_SONAR##
      - faber/npm_sonar_scan:
          name: sonar-scan
          node_version: "${FABER_NODE_VERSION}"
          sonar_project_key: ${FABER_SONAR_PROJECT_KEY}
          requires:
            - build-and-test
            - coverage
          context:
            - ${FABER_CONTEXT_SONAR}
          filters:
            branches:
              only:
                - /release\/.*/
      ##ENDIF_SONAR##
      - faber/docker_build_push:
          name: docker-build-push
          image_name: ${FABER_IMAGE_NAME}
          registry: ${FABER_DOCKER_REGISTRY}
          health_path: ${FABER_HEALTH_PATH}
          health_port: "${FABER_HEALTH_PORT}"
          health_db: "${FABER_HEALTH_DB}"
          requires:
            - code-quality
            - coverage
            - secrets-scan
            - sast-scan
            - security-scan
            ##IF_E2E##
            - e2e-tests
            ##ENDIF_E2E##
          context:
            - ${FABER_CONTEXT_REGISTRY}
          filters:
            branches:
              only:
                - /release\/.*/
      ##IF_SBOM##
      - faber/npm_sbom:
          name: sbom
          node_version: "${FABER_NODE_VERSION}"
          context:
            - ${FABER_CONTEXT_GITHUB}
          requires:
            - code-quality
            - coverage
            - secrets-scan
            - sast-scan
            - security-scan
            ##IF_E2E##
            - e2e-tests
            ##ENDIF_E2E##
          filters:
            branches:
              only:
                - /release\/.*/
      ##ENDIF_SBOM##
      ##IF_CD##
      - faber/update_cd_repo:
          name: update-cd-repo
          cd_repo: ${FABER_CD_REPO}
          environment: ${FABER_CD_ENV_RELEASE}
          cd_format: ${FABER_CD_FORMAT}
          cd_image_name: ${FABER_DOCKER_REGISTRY}/${FABER_IMAGE_NAME}
          ci_git_email: '${FABER_CI_EMAIL}'
          ci_git_name: '${FABER_CI_NAME}'
          requires:
            - docker-build-push
          context:
            - ${FABER_CONTEXT_GITHUB}
          filters:
            branches:
              only:
                - /release\/.*/
      ##ENDIF_CD##
      ##IF_GITHUB_RELEASE##
      - faber/github_release:
          name: github-release
          requires:
            - docker-build-push
          context:
            - ${FABER_CONTEXT_GITHUB}
          filters:
            branches:
              only:
                - /release\/.*/
      ##ENDIF_GITHUB_RELEASE##

  production:
    jobs:
      - faber/npm_build_and_test:
          name: build-and-test
          node_version: "${FABER_NODE_VERSION}"
          ##IF_NPM_AUTH##
          npm_auth: true
          npm_scopes: '${FABER_NPM_SCOPES}'
          npm_default_scope: '${FABER_NPM_DEFAULT_SCOPE}'
          ##ENDIF_NPM_AUTH##
          ##IF_SERVICES##
          services: '${FABER_SERVICES_JSON}'
          ##ENDIF_SERVICES##
          ##IF_TEST_SETUP##
          test_setup: ${FABER_TEST_SETUP_SCRIPT}
          ##ENDIF_TEST_SETUP##
          ##IF_CUSTOM_TEST##
          test_commands: '${FABER_TEST_COMMANDS_JSON}'
          ##ENDIF_CUSTOM_TEST##
          context:
            - ${FABER_CONTEXT_GITHUB}
          filters:
            branches:
              only: main
      - faber/docker_build_push:
          name: docker-build-push
          image_name: ${FABER_IMAGE_NAME}
          registry: ${FABER_DOCKER_REGISTRY}
          health_path: ${FABER_HEALTH_PATH}
          health_port: "${FABER_HEALTH_PORT}"
          health_db: "${FABER_HEALTH_DB}"
          requires:
            - build-and-test
          context:
            - ${FABER_CONTEXT_REGISTRY}
          filters:
            branches:
              only: main
      ##IF_CD##
      - faber/update_cd_repo:
          name: update-cd-repo
          cd_repo: ${FABER_CD_REPO}
          environment: ${FABER_CD_ENV_PROD}
          cd_format: ${FABER_CD_FORMAT}
          cd_image_name: ${FABER_DOCKER_REGISTRY}/${FABER_IMAGE_NAME}
          ci_git_email: '${FABER_CI_EMAIL}'
          ci_git_name: '${FABER_CI_NAME}'
          requires:
            - docker-build-push
          context:
            - ${FABER_CONTEXT_GITHUB}
          filters:
            branches:
              only: main
      ##ENDIF_CD##
      ##IF_GITHUB_RELEASE##
      - faber/github_release:
          name: github-release
          requires:
            - docker-build-push
          context:
            - ${FABER_CONTEXT_GITHUB}
          filters:
            branches:
              only: main
      ##ENDIF_GITHUB_RELEASE##
