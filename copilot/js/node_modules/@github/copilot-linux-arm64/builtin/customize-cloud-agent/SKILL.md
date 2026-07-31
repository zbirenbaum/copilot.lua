---
name: customize-cloud-agent
description: >-
    Skill for customizing the Copilot cloud agent (formerly known as Copilot coding agent) environment,
    including copilot-setup-steps.yml configuration, preinstalling tools and dependencies, runners, and settings.
    Use when the user mentions copilot-setup-steps, copilot setup steps, or wants to configure the cloud agent environment.
user-invocable: false
---

# Customizing the development environment for GitHub Copilot cloud agent

Learn how to customize GitHub Copilot's development environment with additional tools.

## About customizing Copilot cloud agent's development environment

While working on a task, Copilot has access to its own ephemeral development environment, powered by GitHub Actions, where it can explore your code, make changes, execute automated tests and linters and more.

You can customize Copilot's development environment with a [Copilot setup steps file](#customizing-copilots-development-environment-with-copilot-setup-steps). You can use a Copilot setup steps file to:

- [Preinstall tools or dependencies in Copilot's environment](#preinstalling-tools-or-dependencies-in-copilots-environment)
- [Upgrade from standard GitHub-hosted GitHub Actions runners to larger runners](#upgrading-to-larger-github-hosted-github-actions-runners)
- [Run on GitHub Actions self-hosted runners](#using-self-hosted-github-actions-runners)
- [Give Copilot a Windows development environment](#switching-copilot-to-a-windows-development-environment), instead of the default Ubuntu Linux environment
- [Enable Git Large File Storage (LFS)](#enabling-git-large-file-storage-lfs)

In addition, you can:

- [Set environment variables in Copilot's environment](#setting-environment-variables-in-copilots-environment)
- [Disable or customize the agent's firewall](https://docs.github.com/enterprise-cloud@latest/copilot/customizing-copilot/customizing-or-disabling-the-firewall-for-copilot-coding-agent).

## Customizing Copilot's development environment with Copilot setup steps

You can customize Copilot's environment by creating a special GitHub Actions workflow file, located at `.github/workflows/copilot-setup-steps.yml` within your repository.

A `copilot-setup-steps.yml` file looks like a normal GitHub Actions workflow file, but must contain a single `copilot-setup-steps` job. The steps in this job will be executed in GitHub Actions before Copilot starts working. For more information on GitHub Actions workflow files, see [Workflow syntax for GitHub Actions](https://docs.github.com/enterprise-cloud@latest/actions/using-workflows/workflow-syntax-for-github-actions).

> [!NOTE]
> The `copilot-setup-steps.yml` workflow won't trigger unless it's present on your default branch.

Here is a simple example of a `copilot-setup-steps.yml` file for a TypeScript project that clones the project, installs Node.js and downloads and caches the project's dependencies. You should customize this to fit your own project's language(s) and dependencies:

```yaml
name: "Copilot Setup Steps"

# Automatically run the setup steps when they are changed to allow for easy validation, and
# allow manual testing through the repository's "Actions" tab
on:
    workflow_dispatch:
    push:
        paths:
            - .github/workflows/copilot-setup-steps.yml
    pull_request:
        paths:
            - .github/workflows/copilot-setup-steps.yml

jobs:
    # The job MUST be called `copilot-setup-steps` or it will not be picked up by Copilot.
    copilot-setup-steps:
        runs-on: ubuntu-latest

        # Set the permissions to the lowest permissions possible needed for your steps.
        # Copilot will be given its own token for its operations.
        permissions:
            # If you want to clone the repository as part of your setup steps, for example to install dependencies, you'll need the `contents: read` permission.
            # If you don't clone the repository in your setup steps, Copilot will do this for you automatically after the steps complete.
            contents: read

        # You can define any steps you want, and they will run before the agent starts.
        # If you do not check out your code, Copilot will do this for you.
        steps:
            # ...
```

In your `copilot-setup-steps.yml` file, you can only customize the following settings of the `copilot-setup-steps` job. If you try to customize other settings, your changes will be ignored.

- `steps` (see above)
- `permissions` (see above)
- `runs-on` (see below)
- `services`
- `snapshot`
- `timeout-minutes` (maximum value: `59`)

For more information on these options, see [Workflow syntax for GitHub Actions](https://docs.github.com/enterprise-cloud@latest/actions/writing-workflows/workflow-syntax-for-github-actions#jobs).

Any value that is set for the `fetch-depth` option of the `actions/checkout` action will be overridden to allow the agent to rollback commits upon request, while mitigating security risks. For more information, see [`actions/checkout/README.md`](https://github.com/actions/checkout/blob/main/README.md).

Your `copilot-setup-steps.yml` file will automatically be run as a normal GitHub Actions workflow when changes are made, so you can see if it runs successfully. This will show alongside other checks in a pull request where you create or modify the file.

Once you have merged the yml file into your default branch, you can manually run the workflow from the repository's **Actions** tab at any time to check that everything works as expected. For more information, see [Manually running a workflow](https://docs.github.com/enterprise-cloud@latest/actions/managing-workflow-runs-and-deployments/managing-workflow-runs/manually-running-a-workflow).

When Copilot starts work, your setup steps will be run, and updates will show in the session logs. See [Tracking GitHub Copilot's sessions](https://docs.github.com/enterprise-cloud@latest/copilot/how-tos/agents/copilot-coding-agent/tracking-copilots-sessions).

If any setup step fails by returning a non-zero exit code, Copilot will skip the remaining setup steps and begin working with the current state of its development environment.

## Preinstalling tools or dependencies in Copilot's environment

In its ephemeral development environment, Copilot can build or compile your project and run automated tests, linters and other tools. To do this, it will need to install your project's dependencies.

Copilot can discover and install these dependencies itself via a process of trial and error, but this can be slow and unreliable, given the non-deterministic nature of large language models (LLMs), and in some cases, it may be completely unable to download these dependencies—for example, if they are private.

You can use a Copilot setup steps file to deterministically install tools or dependencies before Copilot starts work. To do this, add `steps` to the `copilot-setup-steps` job:

```yaml
# ...

jobs:
    copilot-setup-steps:
        # ...

        # You can define any steps you want, and they will run before the agent starts.
        # If you do not check out your code, Copilot will do this for you.
        steps:
            - name: Checkout code
              uses: actions/checkout@v5

            - name: Set up Node.js
              uses: actions/setup-node@v4
              with:
                  node-version: "20"
                  cache: "npm"

            - name: Install JavaScript dependencies
              run: npm ci
```

## Upgrading to larger GitHub-hosted GitHub Actions runners

By default, Copilot works in a standard GitHub Actions runner. You can upgrade to larger runners for better performance (CPU and memory), more disk space and advanced features like Azure private networking. For more information, see [Larger runners](https://docs.github.com/enterprise-cloud@latest/actions/using-github-hosted-runners/using-larger-runners/about-larger-runners).

1. Set up larger runners for your organization. For more information, see [Managing larger runners](https://docs.github.com/enterprise-cloud@latest/actions/using-github-hosted-runners/managing-larger-runners).

2. If you are using larger runners with Azure private networking, configure your Azure private network to allow outbound access to the hosts required for Copilot cloud agent:
    - `uploads.github.com`
    - `user-images.githubusercontent.com`
    - `api.individual.githubcopilot.com` (if you expect Copilot Pro or Copilot Pro+ users to use Copilot cloud agent in your repository)
    - `api.business.githubcopilot.com` (if you expect Copilot Business users to use Copilot cloud agent in your repository)
    - `api.enterprise.githubcopilot.com` (if you expect Copilot Enterprise users to use Copilot cloud agent in your repository)
    - If you are using the OpenAI Codex third-party agent (for more information, see [About third-party agents](https://docs.github.com/enterprise-cloud@latest/copilot/concepts/agents/about-third-party-agents)):
        - `npmjs.org`
        - `npmjs.com`
        - `registry.npmjs.com`
        - `registry.npmjs.org`
        - `skimdb.npmjs.com`

3. Use a `copilot-setup-steps.yml` file in your repository to configure Copilot cloud agent to run on your chosen runners. Set the `runs-on` step of the `copilot-setup-steps` job to the label and/or group for the larger runners you want Copilot to use. For more information on specifying larger runners with `runs-on`, see [Running jobs on larger runners](https://docs.github.com/enterprise-cloud@latest/actions/using-github-hosted-runners/running-jobs-on-larger-runners).

    ```yaml
    # ...

    jobs:
        copilot-setup-steps:
            runs-on: ubuntu-4-core
            # ...
    ```

> [!NOTE]
>
> - Copilot cloud agent is only compatible with Ubuntu x64 Linux and Windows 64-bit runners. Runners with macOS or other operating systems are not supported.

## Using self-hosted GitHub Actions runners

You can run Copilot cloud agent on self-hosted runners. You may want to do this to match how you run CI/CD workflows on GitHub Actions, or to give Copilot access to internal resources on your network.

We recommend that you only use Copilot cloud agent with ephemeral, single-use runners that are not reused for multiple jobs. Most customers set this up using ARC (Actions Runner Controller) or the GitHub Actions Runner Scale Set Client. For more information, see [Self-hosted runners reference](https://docs.github.com/enterprise-cloud@latest/actions/reference/runners/self-hosted-runners#supported-autoscaling-solutions).

> [!NOTE]
> Copilot cloud agent is only compatible with Ubuntu x64 and Windows 64-bit runners. Runners with macOS or other operating systems are not supported.

1. Configure network security controls for your GitHub Actions runners to ensure that Copilot cloud agent does not have open access to your network or the public internet.

    You must configure your firewall to allow connections to the [standard hosts required for GitHub Actions self-hosted runners](https://docs.github.com/enterprise-cloud@latest/actions/reference/runners/self-hosted-runners#accessible-domains-by-function), plus the following hosts:
    - `uploads.github.com`
    - `user-images.githubusercontent.com`
    - `api.individual.githubcopilot.com` (if you expect Copilot Pro or Copilot Pro+ users to use Copilot cloud agent in your repository)
    - `api.business.githubcopilot.com` (if you expect Copilot Business users to use Copilot cloud agent in your repository)
    - `api.enterprise.githubcopilot.com` (if you expect Copilot Enterprise users to use Copilot cloud agent in your repository)
    - If you are using the OpenAI Codex third-party agent (for more information, see [About third-party agents](https://docs.github.com/enterprise-cloud@latest/copilot/concepts/agents/about-third-party-agents)):
        - `npmjs.org`
        - `npmjs.com`
        - `registry.npmjs.com`
        - `registry.npmjs.org`
        - `skimdb.npmjs.com`

2. Disable Copilot cloud agent's integrated firewall in your repository settings. The firewall is not compatible with self-hosted runners. Unless this is disabled, use of Copilot cloud agent will be blocked. For more information, see [Customizing or disabling the firewall for GitHub Copilot cloud agent](https://docs.github.com/enterprise-cloud@latest/copilot/customizing-copilot/customizing-or-disabling-the-firewall-for-copilot-coding-agent).

3. In your `copilot-setup-steps.yml` file, set the `runs-on` attribute to your ARC-managed scale set name:

    ```yaml
    # ...

    jobs:
        copilot-setup-steps:
            runs-on: arc-scale-set-name
            # ...
    ```

4. If you want to configure a proxy server for Copilot cloud agent's connections to the internet, configure the following environment variables as appropriate:

    | Variable              | Description                                                                                                                                                                             | Example                                                                                     |
    | --------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
    | `https_proxy`         | Proxy URL for HTTPS traffic. You can include basic authentication if required.                                                                                                          | `http://proxy.local`<br>`http://192.168.1.1:8080`<br>`http://username:password@proxy.local` |
    | `http_proxy`          | Proxy URL for HTTP traffic. You can include basic authentication if required.                                                                                                           | `http://proxy.local`<br>`http://192.168.1.1:8080`<br>`http://username:password@proxy.local` |
    | `no_proxy`            | A comma-separated list of hosts or IP addresses that should bypass the proxy. Some clients only honor IP addresses when connections are made directly to the IP rather than a hostname. | `example.com`<br>`example.com,myserver.local:443,example.org`                               |
    | `ssl_cert_file`       | The path to the SSL certificate presented by your proxy server. You will need to configure this if your proxy intercepts SSL connections.                                               | `/path/to/key.pem`                                                                          |
    | `node_extra_ca_certs` | The path to the SSL certificate presented by your proxy server. You will need to configure this if your proxy intercepts SSL connections.                                               | `/path/to/key.pem`                                                                          |

    You can set these environment variables by following the [instructions below](#setting-environment-variables-in-copilots-environment), or by setting them on the runner directly, for example with a custom runner image. For more information on building a custom image, see [Actions Runner Controller](https://docs.github.com/enterprise-cloud@latest/actions/concepts/runners/actions-runner-controller#creating-your-own-runner-image).

## Switching Copilot to a Windows development environment

By default, Copilot uses an Ubuntu Linux-based development environment.

You may want to use a Windows development environment if you're building software for Windows or your repository uses a Windows-based toolchain so Copilot can build your project, run tests and validate its work.

Copilot cloud agent's integrated firewall is not compatible with Windows, so we recommend that you only use self-hosted runners or larger GitHub-hosted runners with Azure private networking where you can implement your own network controls. For more information on runners with Azure private networking, see [About Azure private networking for GitHub-hosted runners in your enterprise](https://docs.github.com/enterprise-cloud@latest/admin/configuring-settings/configuring-private-networking-for-hosted-compute-products/about-azure-private-networking-for-github-hosted-runners-in-your-enterprise).

To use Windows with self-hosted runners, follow the instructions in the [Using self-hosted GitHub Actions runners](#using-self-hosted-github-actions-runners) section above, using the label for your Windows runners. To use Windows with larger GitHub-hosted runners, follow the instructions in the [Upgrading to larger runners](#upgrading-to-larger-github-hosted-github-actions-runners) section above, using the label for your Windows runners.

## Enabling Git Large File Storage (LFS)

If you use Git Large File Storage (LFS) to store large files in your repository, you will need to customize Copilot's environment to install Git LFS and fetch LFS objects.

To enable Git LFS, add a `actions/checkout` step to your `copilot-setup-steps` job with the `lfs` option set to `true`.

```yaml
# ...

jobs:
    copilot-setup-steps:
        runs-on: ubuntu-latest
        permissions:
            contents: read # for actions/checkout
        steps:
            - uses: actions/checkout@v5
              with:
                  lfs: true
```

## Setting environment variables in Copilot's environment

You may want to set environment variables in Copilot's environment to configure or authenticate tools or dependencies that it has access to.

To set an environment variable for Copilot, create a GitHub Actions variable or secret in the `copilot` environment. If the value contains sensitive information, for example a password or API key, it's best to use a GitHub Actions secret.

1. On GitHub, navigate to the main page of the repository.
2. Under your repository name, click **Settings**. If you cannot see the "Settings" tab, select the **More** dropdown menu, then click **Settings**.
3. In the left sidebar, click **Environments**.
4. Click the `copilot` environment.
5. To add a secret, under "Environment secrets," click **Add environment secret**. To add a variable, under "Environment variables," click **Add environment variable**.
6. Fill in the "Name" and "Value" fields, and then click **Add secret** or **Add variable** as appropriate.

## Further reading

- [Customizing or disabling the firewall for GitHub Copilot cloud agent](https://docs.github.com/enterprise-cloud@latest/copilot/customizing-copilot/customizing-or-disabling-the-firewall-for-copilot-coding-agent)
