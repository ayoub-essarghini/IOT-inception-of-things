# Bonus: Local GitLab for Part 3

This bonus installs a local GitLab instance in the Kubernetes cluster and makes the
Part 3 Argo CD application use a repository hosted inside that GitLab instance.

## Files

- `confs/gitlab.yaml`: Kubernetes manifests used to run the official
  `gitlab/gitlab-ce:latest` image locally in the `gitlab` namespace. It defines
  the GitLab deployment, service, and persistent volume claim.
- `Vagrantfile`: Optional VM entrypoint for the bonus environment. It forwards
  GitLab, Argo CD, the playground application, and GitLab SSH ports.
- `scripts/setup.sh`: Creates the cluster namespaces, installs Argo CD if needed,
  deploys GitLab locally, creates a local GitLab repository, pushes the Part 3
  app manifests to it, and configures Argo CD to sync from that local repository.
- `scripts/cleanup.sh`: Removes the bonus GitLab release, the GitLab namespace,
  and the Argo CD repository secret.

## Usage

Run the setup from the repository root:

```bash
bash bonus/scripts/setup.sh
```

The script prints the GitLab URL, credentials, Argo CD URL, application URL, and
the manual commands needed to update the playground deployment version through
the local GitLab repository.

After a version change is synced by Argo CD, the playground pod is recreated and
the old port-forward dies. Restart it without re-running the whole pipeline:

```bash
bash bonus/scripts/setup.sh --refresh-port-forward
```


- GitLab runs locally in the `gitlab` namespace.
- A local repository is created in GitLab.
- The Part 3 application is pushed to that local GitLab repository.
- Argo CD syncs the playground application from the local GitLab service URL.
- The version change is done manually by editing the deployment manifest in the
  local GitLab working copy, committing, and pushing.
