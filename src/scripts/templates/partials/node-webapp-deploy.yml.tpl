  __WORKFLOW_NAME__:
    jobs:
      - munitor/npm_build_and_test:
          name: build-and-test
          node_version: "${MUNITOR_NODE_VERSION}"
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
              only: __BRANCH_FILTER__
      - munitor/secrets_scan:
          name: secrets-scan
          filters:
            branches:
              only: __BRANCH_FILTER__
      - munitor/sast_scan:
          name: sast-scan
          fail_on_findings: "${MUNITOR_SAST_FAIL_ON_FINDINGS}"
          filters:
            branches:
              only: __BRANCH_FILTER__
      - munitor/npm_code_quality:
          name: code-quality
          requires:
            - build-and-test
          filters:
            branches:
              only: __BRANCH_FILTER__
      - munitor/npm_coverage:
          name: coverage
          min_coverage: "${MUNITOR_COVERAGE_MIN}"
          coverage_tool: ${MUNITOR_COVERAGE_TOOL}
          ##IF_COVERAGE_CMD##
          coverage_command: ${MUNITOR_COVERAGE_COMMAND}
          ##ENDIF_COVERAGE_CMD##
          requires:
            - build-and-test
          filters:
            branches:
              only: __BRANCH_FILTER__
      - munitor/npm_security_scan:
          name: security-scan
          requires:
            - build-and-test
          filters:
            branches:
              only: __BRANCH_FILTER__
      ##IF_E2E##
      - munitor/npm_e2e_test:
          name: e2e-tests
          requires:
            - build-and-test
          filters:
            branches:
              only: __BRANCH_FILTER__
      ##ENDIF_E2E##
      ##IF_SONAR##
      - munitor/npm_sonar_scan:
          name: sonar-scan
          node_version: "${MUNITOR_NODE_VERSION}"
          sonar_project_key: ${MUNITOR_SONAR_PROJECT_KEY}
          requires:
            - build-and-test
            - coverage
          context:
            - ${MUNITOR_CONTEXT_SONAR}
          filters:
            branches:
              only: __BRANCH_FILTER__
      ##ENDIF_SONAR##
      - munitor/docker_build_push:
          name: docker-build-push
          image_name: ${MUNITOR_IMAGE_NAME}
          registry: ${MUNITOR_DOCKER_REGISTRY}
          health_path: ${MUNITOR_HEALTH_PATH}
          health_port: "${MUNITOR_HEALTH_PORT}"
          health_db: "${MUNITOR_HEALTH_DB}"
          ##IF_SUPPLEMENTAL##
          supplemental_images: '${MUNITOR_SUPPLEMENTAL_IMAGES_JSON}'
          ##ENDIF_SUPPLEMENTAL##
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
            - ${MUNITOR_CONTEXT_REGISTRY}
          filters:
            branches:
              only: __BRANCH_FILTER__
      ##IF_SBOM##
      - munitor/npm_sbom:
          name: sbom
          node_version: "${MUNITOR_NODE_VERSION}"
          context:
            - ${MUNITOR_CONTEXT_GITHUB}
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
              only: __BRANCH_FILTER__
      ##ENDIF_SBOM##
      ##IF_CD##
      - munitor/update_cd_repo:
          name: update-cd-repo
          cd_repo: ${MUNITOR_CD_REPO}
          environment: __CD_ENVIRONMENT__
          cd_format: ${MUNITOR_CD_FORMAT}
          cd_image_name: ${MUNITOR_DOCKER_REGISTRY}/${MUNITOR_IMAGE_NAME}
          ##IF_SUPPLEMENTAL##
          supplemental_images: '${MUNITOR_SUPPLEMENTAL_IMAGES_JSON}'
          ##ENDIF_SUPPLEMENTAL##
          ci_git_email: '${MUNITOR_CI_EMAIL}'
          ci_git_name: '${MUNITOR_CI_NAME}'
          requires:
            - docker-build-push
          context:
            - ${MUNITOR_CONTEXT_GITHUB}
          filters:
            branches:
              only: __BRANCH_FILTER__
      ##ENDIF_CD##
