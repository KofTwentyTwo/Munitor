  __WORKFLOW_NAME__:
    jobs:
      - munitor/mvn_build_and_test:
          name: build-and-test
          java_version: "${MUNITOR_JAVA_VERSION}"
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
      - munitor/mvn_code_quality:
          name: code-quality
          java_version: "${MUNITOR_JAVA_VERSION}"
          requires:
            - build-and-test
          filters:
            branches:
              only: __BRANCH_FILTER__
      - munitor/mvn_coverage:
          name: coverage
          java_version: "${MUNITOR_JAVA_VERSION}"
          min_instruction: "${MUNITOR_COVERAGE_MIN}"
          requires:
            - build-and-test
          filters:
            branches:
              only: __BRANCH_FILTER__
      - munitor/security_scan:
          name: security-scan
          java_version: "${MUNITOR_JAVA_VERSION}"
          owasp: ${MUNITOR_OWASP}
          ##IF_OWASP##
          ##IF_NVD##
          context:
            - ${MUNITOR_CONTEXT_NVD}
          ##ENDIF_NVD##
          ##ENDIF_OWASP##
          requires:
            - build-and-test
          filters:
            branches:
              only: __BRANCH_FILTER__
      ##IF_E2E##
      - munitor/mvn_e2e_test:
          name: e2e-tests
          java_version: "${MUNITOR_JAVA_VERSION}"
          requires:
            - build-and-test
          filters:
            branches:
              only: __BRANCH_FILTER__
      ##ENDIF_E2E##
      ##IF_SONAR##
      - munitor/sonar_scan:
          name: sonar-scan
          java_version: "${MUNITOR_JAVA_VERSION}"
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
            ##IF_SONAR##
            - sonar-scan
            ##ENDIF_SONAR##
            ##IF_E2E##
            - e2e-tests
            ##ENDIF_E2E##
          context:
            - ${MUNITOR_CONTEXT_REGISTRY}
          filters:
            branches:
              only: __BRANCH_FILTER__
      ##IF_SBOM##
      - munitor/sbom:
          name: sbom
          java_version: "${MUNITOR_JAVA_VERSION}"
          context:
            - ${MUNITOR_CONTEXT_GITHUB}
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
      ##IF_CD_NON_PROD##
      - munitor/update_cd_repo:
          name: update-cd-repo
          cd_repo: ${MUNITOR_CD_REPO}
          environment: __CD_ENVIRONMENT__
          cd_format: ${MUNITOR_CD_FORMAT}
          cd_image_name: ${MUNITOR_DOCKER_REGISTRY}/${MUNITOR_IMAGE_NAME}
          cd_path: ${MUNITOR_CD_PATH}
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
      ##ENDIF_CD_NON_PROD##
