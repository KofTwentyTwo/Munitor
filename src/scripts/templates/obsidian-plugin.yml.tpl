version: 2.1

orbs:
  munitor: ${MUNITOR_ORB_SLUG}@${MUNITOR_ORB_VERSION}

workflows:
  pr-checks:
    jobs:
      - munitor/node_build_and_test:
          name: build-and-test
          node_version: "${MUNITOR_NODE_VERSION}"
          package_manager: "${MUNITOR_PACKAGE_MANAGER}"
          ##IF_NPM_AUTH##
          npm_auth: true
          npm_scopes: '${MUNITOR_NPM_SCOPES}'
          npm_default_scope: '${MUNITOR_NPM_DEFAULT_SCOPE}'
          ##ENDIF_NPM_AUTH##
          ##IF_SERVICES##
          services: '${MUNITOR_SERVICES_JSON}'
          ##ENDIF_SERVICES##
          ##IF_TEST_SETUP##
          test_setup: ${MUNITOR_TEST_SETUP_SCRIPT}
          ##ENDIF_TEST_SETUP##
          ##IF_CUSTOM_TEST##
          test_commands: '${MUNITOR_TEST_COMMANDS_JSON}'
          ##ENDIF_CUSTOM_TEST##
          context:
            - ${MUNITOR_CONTEXT_GITHUB}
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
      - munitor/node_code_quality:
          name: code-quality
          node_version: "${MUNITOR_NODE_VERSION}"
          package_manager: "${MUNITOR_PACKAGE_MANAGER}"
          requires:
            - build-and-test
          filters:
            branches:
              only:
                - /feature\/.*/
                - /hotfix\/.*/
      - munitor/node_coverage:
          name: coverage
          node_version: "${MUNITOR_NODE_VERSION}"
          package_manager: "${MUNITOR_PACKAGE_MANAGER}"
          min_coverage: "${MUNITOR_COVERAGE_MIN}"
          coverage_tool: ${MUNITOR_COVERAGE_TOOL}
          coverage_summary_path: "${MUNITOR_COVERAGE_SUMMARY_PATH}"
          ##IF_COVERAGE_CMD##
          coverage_command: ${MUNITOR_COVERAGE_COMMAND}
          ##ENDIF_COVERAGE_CMD##
          requires:
            - build-and-test
          filters:
            branches:
              only:
                - /feature\/.*/
                - /hotfix\/.*/
      - munitor/node_security_scan:
          name: security-scan
          node_version: "${MUNITOR_NODE_VERSION}"
          package_manager: "${MUNITOR_PACKAGE_MANAGER}"
          requires:
            - build-and-test
          filters:
            branches:
              only:
                - /feature\/.*/
                - /hotfix\/.*/
      ##IF_E2E##
      - munitor/node_e2e_test:
          name: e2e-tests
          node_version: "${MUNITOR_NODE_VERSION}"
          package_manager: "${MUNITOR_PACKAGE_MANAGER}"
          requires:
            - build-and-test
          filters:
            branches:
              only:
                - /feature\/.*/
                - /hotfix\/.*/
      ##ENDIF_E2E##

  develop:
    jobs:
      - munitor/node_build_and_test:
          name: build-and-test
          node_version: "${MUNITOR_NODE_VERSION}"
          package_manager: "${MUNITOR_PACKAGE_MANAGER}"
          ##IF_NPM_AUTH##
          npm_auth: true
          npm_scopes: '${MUNITOR_NPM_SCOPES}'
          npm_default_scope: '${MUNITOR_NPM_DEFAULT_SCOPE}'
          ##ENDIF_NPM_AUTH##
          ##IF_SERVICES##
          services: '${MUNITOR_SERVICES_JSON}'
          ##ENDIF_SERVICES##
          ##IF_TEST_SETUP##
          test_setup: ${MUNITOR_TEST_SETUP_SCRIPT}
          ##ENDIF_TEST_SETUP##
          ##IF_CUSTOM_TEST##
          test_commands: '${MUNITOR_TEST_COMMANDS_JSON}'
          ##ENDIF_CUSTOM_TEST##
          context:
            - ${MUNITOR_CONTEXT_GITHUB}
          filters:
            branches:
              only: develop

  release-candidate:
    jobs:
      - munitor/node_build_and_test:
          name: build-and-test
          node_version: "${MUNITOR_NODE_VERSION}"
          package_manager: "${MUNITOR_PACKAGE_MANAGER}"
          ##IF_NPM_AUTH##
          npm_auth: true
          npm_scopes: '${MUNITOR_NPM_SCOPES}'
          npm_default_scope: '${MUNITOR_NPM_DEFAULT_SCOPE}'
          ##ENDIF_NPM_AUTH##
          ##IF_SERVICES##
          services: '${MUNITOR_SERVICES_JSON}'
          ##ENDIF_SERVICES##
          ##IF_TEST_SETUP##
          test_setup: ${MUNITOR_TEST_SETUP_SCRIPT}
          ##ENDIF_TEST_SETUP##
          ##IF_CUSTOM_TEST##
          test_commands: '${MUNITOR_TEST_COMMANDS_JSON}'
          ##ENDIF_CUSTOM_TEST##
          context:
            - ${MUNITOR_CONTEXT_GITHUB}
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
      - munitor/node_code_quality:
          name: code-quality
          node_version: "${MUNITOR_NODE_VERSION}"
          package_manager: "${MUNITOR_PACKAGE_MANAGER}"
          requires:
            - build-and-test
          filters:
            branches:
              only:
                - /release\/.*/
      - munitor/node_coverage:
          name: coverage
          node_version: "${MUNITOR_NODE_VERSION}"
          package_manager: "${MUNITOR_PACKAGE_MANAGER}"
          min_coverage: "${MUNITOR_COVERAGE_MIN}"
          coverage_tool: ${MUNITOR_COVERAGE_TOOL}
          coverage_summary_path: "${MUNITOR_COVERAGE_SUMMARY_PATH}"
          ##IF_COVERAGE_CMD##
          coverage_command: ${MUNITOR_COVERAGE_COMMAND}
          ##ENDIF_COVERAGE_CMD##
          requires:
            - build-and-test
          filters:
            branches:
              only:
                - /release\/.*/
      - munitor/node_security_scan:
          name: security-scan
          node_version: "${MUNITOR_NODE_VERSION}"
          package_manager: "${MUNITOR_PACKAGE_MANAGER}"
          requires:
            - build-and-test
          filters:
            branches:
              only:
                - /release\/.*/
      ##IF_E2E##
      - munitor/node_e2e_test:
          name: e2e-tests
          node_version: "${MUNITOR_NODE_VERSION}"
          package_manager: "${MUNITOR_PACKAGE_MANAGER}"
          requires:
            - build-and-test
          filters:
            branches:
              only:
                - /release\/.*/
      ##ENDIF_E2E##
      ##IF_SONAR##
      - munitor/node_sonar_scan:
          name: sonar-scan
          node_version: "${MUNITOR_NODE_VERSION}"
          package_manager: "${MUNITOR_PACKAGE_MANAGER}"
          sonar_project_key: ${MUNITOR_SONAR_PROJECT_KEY}
          requires:
            - build-and-test
            - coverage
          context:
            - ${MUNITOR_CONTEXT_SONAR}
          filters:
            branches:
              only:
                - /release\/.*/
      ##ENDIF_SONAR##
      ##IF_SBOM##
      - munitor/node_sbom:
          name: sbom
          node_version: "${MUNITOR_NODE_VERSION}"
          package_manager: "${MUNITOR_PACKAGE_MANAGER}"
          context:
            - ${MUNITOR_CONTEXT_GITHUB}
          requires:
            - code-quality
            - coverage
            - secrets-scan
            ##IF_SAST##
            - sast-scan
            ##ENDIF_SAST##
            - security-scan
            ##IF_E2E##
            - e2e-tests
            ##ENDIF_E2E##
          filters:
            branches:
              only:
                - /release\/.*/
      ##ENDIF_SBOM##
      - munitor/github_release:
          name: github-release
          release_artifacts: "main.js manifest.json styles.css"
          requires:
            - code-quality
            - coverage
            - secrets-scan
            ##IF_SAST##
            - sast-scan
            ##ENDIF_SAST##
            - security-scan
            ##IF_E2E##
            - e2e-tests
            ##ENDIF_E2E##
          context:
            - ${MUNITOR_CONTEXT_GITHUB}
          filters:
            branches:
              only:
                - /release\/.*/

  production:
    jobs:
      - munitor/node_build_and_test:
          name: build-and-test
          node_version: "${MUNITOR_NODE_VERSION}"
          package_manager: "${MUNITOR_PACKAGE_MANAGER}"
          ##IF_NPM_AUTH##
          npm_auth: true
          npm_scopes: '${MUNITOR_NPM_SCOPES}'
          npm_default_scope: '${MUNITOR_NPM_DEFAULT_SCOPE}'
          ##ENDIF_NPM_AUTH##
          ##IF_SERVICES##
          services: '${MUNITOR_SERVICES_JSON}'
          ##ENDIF_SERVICES##
          ##IF_TEST_SETUP##
          test_setup: ${MUNITOR_TEST_SETUP_SCRIPT}
          ##ENDIF_TEST_SETUP##
          ##IF_CUSTOM_TEST##
          test_commands: '${MUNITOR_TEST_COMMANDS_JSON}'
          ##ENDIF_CUSTOM_TEST##
          context:
            - ${MUNITOR_CONTEXT_GITHUB}
          filters:
            branches:
              only: main
      - munitor/github_release:
          name: github-release
          release_artifacts: "main.js manifest.json styles.css"
          requires:
            - build-and-test
          context:
            - ${MUNITOR_CONTEXT_GITHUB}
          filters:
            branches:
              only: main
