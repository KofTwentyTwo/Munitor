version: 2.1

orbs:
  faber: ${FABER_ORB_SLUG}@${FABER_ORB_VERSION}

workflows:
  pr-checks:
    jobs:
      - faber/yaml_lint_cd:
          name: yaml-lint
          paths: "${FABER_YAMLLINT_PATHS}"
          filters:
            branches:
              only:
                - /feature\/.*/
                - /hotfix\/.*/
      - faber/kustomize_validate:
          name: kustomize-validate
          kustomize_version: "${FABER_KUSTOMIZE_VERSION}"
          base_path: "${FABER_KUSTOMIZE_BASE_PATH}"
          overlays: "${FABER_KUSTOMIZE_OVERLAYS}"
          load_restrictor: "${FABER_KUSTOMIZE_LOAD_RESTRICTOR}"
          filters:
            branches:
              only:
                - /feature\/.*/
                - /hotfix\/.*/
      - faber/kubesec_scan:
          name: kubesec-scan
          scan_overlay: "${FABER_KUSTOMIZE_SCAN_OVERLAY}"
          requires:
            - kustomize-validate
          filters:
            branches:
              only:
                - /feature\/.*/
                - /hotfix\/.*/
      - faber/kube_linter:
          name: kube-linter
          scan_overlay: "${FABER_KUSTOMIZE_SCAN_OVERLAY}"
          config: "${FABER_KUBE_LINTER_CONFIG}"
          requires:
            - kustomize-validate
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

  develop:
    jobs:
      - faber/yaml_lint_cd:
          name: yaml-lint
          paths: "${FABER_YAMLLINT_PATHS}"
          filters:
            branches:
              only: develop
      - faber/kustomize_validate:
          name: kustomize-validate
          kustomize_version: "${FABER_KUSTOMIZE_VERSION}"
          base_path: "${FABER_KUSTOMIZE_BASE_PATH}"
          overlays: "${FABER_KUSTOMIZE_OVERLAYS}"
          load_restrictor: "${FABER_KUSTOMIZE_LOAD_RESTRICTOR}"
          filters:
            branches:
              only: develop
      - faber/kubesec_scan:
          name: kubesec-scan
          scan_overlay: "${FABER_KUSTOMIZE_SCAN_OVERLAY}"
          requires:
            - kustomize-validate
          filters:
            branches:
              only: develop
      - faber/kube_linter:
          name: kube-linter
          scan_overlay: "${FABER_KUSTOMIZE_SCAN_OVERLAY}"
          config: "${FABER_KUBE_LINTER_CONFIG}"
          requires:
            - kustomize-validate
          filters:
            branches:
              only: develop
      - faber/secrets_scan:
          name: secrets-scan
          filters:
            branches:
              only: develop

  release:
    jobs:
      - faber/yaml_lint_cd:
          name: yaml-lint
          paths: "${FABER_YAMLLINT_PATHS}"
          filters:
            branches:
              only: main
      - faber/kustomize_validate:
          name: kustomize-validate
          kustomize_version: "${FABER_KUSTOMIZE_VERSION}"
          base_path: "${FABER_KUSTOMIZE_BASE_PATH}"
          overlays: "${FABER_KUSTOMIZE_OVERLAYS}"
          load_restrictor: "${FABER_KUSTOMIZE_LOAD_RESTRICTOR}"
          filters:
            branches:
              only: main
      - faber/kubesec_scan:
          name: kubesec-scan
          scan_overlay: "${FABER_KUSTOMIZE_SCAN_OVERLAY}"
          requires:
            - kustomize-validate
          filters:
            branches:
              only: main
      - faber/kube_linter:
          name: kube-linter
          scan_overlay: "${FABER_KUSTOMIZE_SCAN_OVERLAY}"
          config: "${FABER_KUBE_LINTER_CONFIG}"
          requires:
            - kustomize-validate
          filters:
            branches:
              only: main
      - faber/secrets_scan:
          name: secrets-scan
          filters:
            branches:
              only: main
