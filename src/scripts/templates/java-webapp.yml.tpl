version: 2.1

orbs:
  munitor: ${MUNITOR_ORB_SLUG}@${MUNITOR_ORB_VERSION}

workflows:
  pr-checks:
    jobs:
      - munitor/mvn_build_and_test:
          name: build-and-test
          java_version: "${MUNITOR_JAVA_VERSION}"
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
      - munitor/sast_scan:
          name: sast-scan
          fail_on_findings: "${MUNITOR_SAST_FAIL_ON_FINDINGS}"
          filters:
            branches:
              only:
                - /feature\/.*/
                - /hotfix\/.*/
      - munitor/mvn_code_quality:
          name: code-quality
          java_version: "${MUNITOR_JAVA_VERSION}"
          requires:
            - build-and-test
          filters:
            branches:
              only:
                - /feature\/.*/
                - /hotfix\/.*/
      - munitor/mvn_coverage:
          name: coverage
          java_version: "${MUNITOR_JAVA_VERSION}"
          min_instruction: "${MUNITOR_COVERAGE_MIN}"
          requires:
            - build-and-test
          filters:
            branches:
              only:
                - /feature\/.*/
                - /hotfix\/.*/
      - munitor/security_scan:
          name: security-scan
          java_version: "${MUNITOR_JAVA_VERSION}"
          context:
            - ${MUNITOR_CONTEXT_NVD}
          requires:
            - build-and-test
          filters:
            branches:
              only:
                - /feature\/.*/
                - /hotfix\/.*/
      ##IF_E2E##
      - munitor/mvn_e2e_test:
          name: e2e-tests
          java_version: "${MUNITOR_JAVA_VERSION}"
          requires:
            - build-and-test
          filters:
            branches:
              only:
                - /feature\/.*/
                - /hotfix\/.*/
      ##ENDIF_E2E##

  ##INCLUDE_DEPLOY java-webapp-deploy develop develop ${MUNITOR_CD_ENV_DEVELOP}##
  ##INCLUDE_DEPLOY java-webapp-deploy staging staging ${MUNITOR_CD_ENV_STAGING}##

  release-candidate:
    jobs:
      - munitor/mvn_build_and_test:
          name: build-and-test
          java_version: "${MUNITOR_JAVA_VERSION}"
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
      - munitor/sast_scan:
          name: sast-scan
          fail_on_findings: "${MUNITOR_SAST_FAIL_ON_FINDINGS}"
          filters:
            branches:
              only:
                - /release\/.*/
      - munitor/mvn_code_quality:
          name: code-quality
          java_version: "${MUNITOR_JAVA_VERSION}"
          requires:
            - build-and-test
          filters:
            branches:
              only:
                - /release\/.*/
      - munitor/mvn_coverage:
          name: coverage
          java_version: "${MUNITOR_JAVA_VERSION}"
          min_instruction: "${MUNITOR_COVERAGE_MIN}"
          requires:
            - build-and-test
          filters:
            branches:
              only:
                - /release\/.*/
      - munitor/security_scan:
          name: security-scan
          java_version: "${MUNITOR_JAVA_VERSION}"
          context:
            - ${MUNITOR_CONTEXT_NVD}
          requires:
            - build-and-test
          filters:
            branches:
              only:
                - /release\/.*/
      ##IF_E2E##
      - munitor/mvn_e2e_test:
          name: e2e-tests
          java_version: "${MUNITOR_JAVA_VERSION}"
          requires:
            - build-and-test
          filters:
            branches:
              only:
                - /release\/.*/
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
              only:
                - /release\/.*/
      ##ENDIF_SONAR##
      - munitor/docker_build_push:
          name: docker-build-push
          image_name: ${MUNITOR_IMAGE_NAME}
          registry: ${MUNITOR_DOCKER_REGISTRY}
          health_path: ${MUNITOR_HEALTH_PATH}
          health_port: "${MUNITOR_HEALTH_PORT}"
          health_db: "${MUNITOR_HEALTH_DB}"
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
              only:
                - /release\/.*/
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
              only:
                - /release\/.*/
      ##ENDIF_SBOM##
      ##IF_CD##
      - munitor/update_cd_repo:
          name: update-cd-repo
          cd_repo: ${MUNITOR_CD_REPO}
          environment: ${MUNITOR_CD_ENV_RELEASE}
          cd_format: ${MUNITOR_CD_FORMAT}
          cd_image_name: ${MUNITOR_DOCKER_REGISTRY}/${MUNITOR_IMAGE_NAME}
          ci_git_email: '${MUNITOR_CI_EMAIL}'
          ci_git_name: '${MUNITOR_CI_NAME}'
          requires:
            - docker-build-push
          context:
            - ${MUNITOR_CONTEXT_GITHUB}
          filters:
            branches:
              only:
                - /release\/.*/
      ##ENDIF_CD##
      ##IF_GITHUB_RELEASE##
      - munitor/github_release:
          name: github-release
          requires:
            - docker-build-push
          context:
            - ${MUNITOR_CONTEXT_GITHUB}
          filters:
            branches:
              only:
                - /release\/.*/
      ##ENDIF_GITHUB_RELEASE##

  production:
    jobs:
      - munitor/mvn_build_and_test:
          name: build-and-test
          java_version: "${MUNITOR_JAVA_VERSION}"
          context:
            - ${MUNITOR_CONTEXT_GITHUB}
          filters:
            branches:
              only: main
      - munitor/docker_build_push:
          name: docker-build-push
          image_name: ${MUNITOR_IMAGE_NAME}
          registry: ${MUNITOR_DOCKER_REGISTRY}
          health_path: ${MUNITOR_HEALTH_PATH}
          health_port: "${MUNITOR_HEALTH_PORT}"
          health_db: "${MUNITOR_HEALTH_DB}"
          requires:
            - build-and-test
          context:
            - ${MUNITOR_CONTEXT_REGISTRY}
          filters:
            branches:
              only: main
      ##IF_CD##
      - munitor/update_cd_repo:
          name: update-cd-repo
          cd_repo: ${MUNITOR_CD_REPO}
          environment: ${MUNITOR_CD_ENV_PROD}
          cd_format: ${MUNITOR_CD_FORMAT}
          cd_image_name: ${MUNITOR_DOCKER_REGISTRY}/${MUNITOR_IMAGE_NAME}
          ci_git_email: '${MUNITOR_CI_EMAIL}'
          ci_git_name: '${MUNITOR_CI_NAME}'
          requires:
            - docker-build-push
          context:
            - ${MUNITOR_CONTEXT_GITHUB}
          filters:
            branches:
              only: main
      ##ENDIF_CD##
      ##IF_GITHUB_RELEASE##
      - munitor/github_release:
          name: github-release
          requires:
            - docker-build-push
          context:
            - ${MUNITOR_CONTEXT_GITHUB}
          filters:
            branches:
              only: main
      ##ENDIF_GITHUB_RELEASE##
