  __WORKFLOW_NAME__:
    jobs:
      - faber/mvn_build_and_test:
          name: build-and-test
          java_version: "${FABER_JAVA_VERSION}"
          context:
            - ${FABER_CONTEXT_GITHUB}
          filters:
            branches:
              only: __BRANCH_FILTER__
      - faber/secrets_scan:
          name: secrets-scan
          filters:
            branches:
              only: __BRANCH_FILTER__
      - faber/sast_scan:
          name: sast-scan
          fail_on_findings: "${FABER_SAST_FAIL_ON_FINDINGS}"
          filters:
            branches:
              only: __BRANCH_FILTER__
      - faber/mvn_code_quality:
          name: code-quality
          java_version: "${FABER_JAVA_VERSION}"
          requires:
            - build-and-test
          filters:
            branches:
              only: __BRANCH_FILTER__
      - faber/mvn_coverage:
          name: coverage
          java_version: "${FABER_JAVA_VERSION}"
          min_instruction: "${FABER_COVERAGE_MIN}"
          requires:
            - build-and-test
          filters:
            branches:
              only: __BRANCH_FILTER__
      - faber/security_scan:
          name: security-scan
          java_version: "${FABER_JAVA_VERSION}"
          context:
            - ${FABER_CONTEXT_NVD}
          requires:
            - build-and-test
          filters:
            branches:
              only: __BRANCH_FILTER__
      ##IF_E2E##
      - faber/mvn_e2e_test:
          name: e2e-tests
          java_version: "${FABER_JAVA_VERSION}"
          requires:
            - build-and-test
          filters:
            branches:
              only: __BRANCH_FILTER__
      ##ENDIF_E2E##
      ##IF_SONAR##
      - faber/sonar_scan:
          name: sonar-scan
          java_version: "${FABER_JAVA_VERSION}"
          sonar_project_key: ${FABER_SONAR_PROJECT_KEY}
          requires:
            - build-and-test
            - coverage
          context:
            - ${FABER_CONTEXT_SONAR}
          filters:
            branches:
              only: __BRANCH_FILTER__
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
            ##IF_SONAR##
            - sonar-scan
            ##ENDIF_SONAR##
            ##IF_E2E##
            - e2e-tests
            ##ENDIF_E2E##
          context:
            - ${FABER_CONTEXT_REGISTRY}
          filters:
            branches:
              only: __BRANCH_FILTER__
      ##IF_SBOM##
      - faber/sbom:
          name: sbom
          java_version: "${FABER_JAVA_VERSION}"
          context:
            - ${FABER_CONTEXT_GITHUB}
          requires:
            - code-quality
            - coverage
            - secrets-scan
            - sast-scan
            - security-scan
            ##IF_SONAR##
            - sonar-scan
            ##ENDIF_SONAR##
            ##IF_E2E##
            - e2e-tests
            ##ENDIF_E2E##
          filters:
            branches:
              only: __BRANCH_FILTER__
      ##ENDIF_SBOM##
      ##IF_CD##
      - faber/update_cd_repo:
          name: update-cd-repo
          cd_repo: ${FABER_CD_REPO}
          environment: __CD_ENVIRONMENT__
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
              only: __BRANCH_FILTER__
      ##ENDIF_CD##
