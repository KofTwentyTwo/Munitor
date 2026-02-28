version: 2.1

orbs:
  munitor: ${MUNITOR_ORB_SLUG}@${MUNITOR_ORB_VERSION}

workflows:
  pr-checks:
    jobs:
      - munitor/yaml_lint_cd:
          name: yaml-lint
          paths: "${MUNITOR_YAMLLINT_PATHS}"
          filters:
            branches:
              only:
                - /feature\/.*/
                - /hotfix\/.*/
      - munitor/kustomize_validate:
          name: kustomize-validate
          kustomize_version: "${MUNITOR_KUSTOMIZE_VERSION}"
          base_path: "${MUNITOR_KUSTOMIZE_BASE_PATH}"
          overlay_dir: "${MUNITOR_KUSTOMIZE_OVERLAY_DIR}"
          overlays: "${MUNITOR_KUSTOMIZE_OVERLAYS}"
          load_restrictor: "${MUNITOR_KUSTOMIZE_LOAD_RESTRICTOR}"
          filters:
            branches:
              only:
                - /feature\/.*/
                - /hotfix\/.*/
      - munitor/kubesec_scan:
          name: kubesec-scan
          scan_overlay: "${MUNITOR_KUSTOMIZE_SCAN_OVERLAY}"
          requires:
            - kustomize-validate
          filters:
            branches:
              only:
                - /feature\/.*/
                - /hotfix\/.*/
      - munitor/kube_linter:
          name: kube-linter
          scan_overlay: "${MUNITOR_KUSTOMIZE_SCAN_OVERLAY}"
          config: "${MUNITOR_KUBE_LINTER_CONFIG}"
          requires:
            - kustomize-validate
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

  develop:
    jobs:
      - munitor/yaml_lint_cd:
          name: yaml-lint
          paths: "${MUNITOR_YAMLLINT_PATHS}"
          filters:
            branches:
              only: develop
      - munitor/kustomize_validate:
          name: kustomize-validate
          kustomize_version: "${MUNITOR_KUSTOMIZE_VERSION}"
          base_path: "${MUNITOR_KUSTOMIZE_BASE_PATH}"
          overlay_dir: "${MUNITOR_KUSTOMIZE_OVERLAY_DIR}"
          overlays: "${MUNITOR_KUSTOMIZE_OVERLAYS}"
          load_restrictor: "${MUNITOR_KUSTOMIZE_LOAD_RESTRICTOR}"
          filters:
            branches:
              only: develop
      - munitor/kubesec_scan:
          name: kubesec-scan
          scan_overlay: "${MUNITOR_KUSTOMIZE_SCAN_OVERLAY}"
          requires:
            - kustomize-validate
          filters:
            branches:
              only: develop
      - munitor/kube_linter:
          name: kube-linter
          scan_overlay: "${MUNITOR_KUSTOMIZE_SCAN_OVERLAY}"
          config: "${MUNITOR_KUBE_LINTER_CONFIG}"
          requires:
            - kustomize-validate
          filters:
            branches:
              only: develop
      - munitor/secrets_scan:
          name: secrets-scan
          filters:
            branches:
              only: develop

  release:
    jobs:
      - munitor/yaml_lint_cd:
          name: yaml-lint
          paths: "${MUNITOR_YAMLLINT_PATHS}"
          filters:
            branches:
              only: main
      - munitor/kustomize_validate:
          name: kustomize-validate
          kustomize_version: "${MUNITOR_KUSTOMIZE_VERSION}"
          base_path: "${MUNITOR_KUSTOMIZE_BASE_PATH}"
          overlay_dir: "${MUNITOR_KUSTOMIZE_OVERLAY_DIR}"
          overlays: "${MUNITOR_KUSTOMIZE_OVERLAYS}"
          load_restrictor: "${MUNITOR_KUSTOMIZE_LOAD_RESTRICTOR}"
          filters:
            branches:
              only: main
      - munitor/kubesec_scan:
          name: kubesec-scan
          scan_overlay: "${MUNITOR_KUSTOMIZE_SCAN_OVERLAY}"
          requires:
            - kustomize-validate
          filters:
            branches:
              only: main
      - munitor/kube_linter:
          name: kube-linter
          scan_overlay: "${MUNITOR_KUSTOMIZE_SCAN_OVERLAY}"
          config: "${MUNITOR_KUBE_LINTER_CONFIG}"
          requires:
            - kustomize-validate
          filters:
            branches:
              only: main
      - munitor/secrets_scan:
          name: secrets-scan
          filters:
            branches:
              only: main
