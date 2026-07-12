# PLAN: Preserve node-webapp Dockerfiles

## Goal

Allow `node-webapp` consumers to preserve a repository-owned Dockerfile without breaking existing generated-image consumers.

## Steps

1. [x] Add an opt-in `docker.use_repo_dockerfile` manifest field.
2. [x] Fail clearly when an opted-in repository has no root Dockerfile.
3. [x] Add regression coverage and update the public reference.
4. [ ] Pack, validate, test, and publish the development orb.
5. [ ] Verify the Investing in Chester production image pipeline with the new orb.
