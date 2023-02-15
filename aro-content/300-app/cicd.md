Next, we'll automate deploying our application using the OpenShift Pipelines operator, which is based on the open source Tekton project.

If you would like to read more about OpenShift Pipelines, [see the Red Hat documentation](https://docs.openshift.com/container-platform/4.11/cicd/pipelines/understanding-openshift-pipelines.html){:target="_blank"}.

!!! warning "GitHub Account Required"

    This section of the workshop requires a personal [GitHub](https://github.com){:target="_blank"} account. If you do not have a GitHub account and do not wish to create one, you can skip this section and move to the next section.

## Install the OpenShift Pipelines operator

1. Return to your tab with the OpenShift Web Console. If you need to reauthenticate, follow the steps in the [Access Your Cluster](../setup/3-access-cluster/) section.

1. Using the menu on the left Select *Operator* -> *OperatorHub*.

    ![Web Console - OperatorHub Sidebar](../assets/images/web-console-operatorhub-menu.png){ align=center }

1. In the search box, search for "OpenShift Pipelines" and click on the *Red Hat OpenShift Pipelines* box.

    ![Web Console - OpenShift Pipelines Operator Selection](../assets/images/web-console-operatorhub-openshift-pipelines.png){ align=center }

1. Click on *Install* on the page that appears.

    ![Web Console - OpenShift Pipelines Simple Install](../assets/images/web-console-openshift-pipelines-simple-install.png){ align=center }

1. Accept the defaults that are presented and select *Install* to install the operator.

    ![Web Console - OpenShift Pipelines Detailed Install](../assets/images/web-console-openshift-pipelines-detailed-install.png){ align=center }

1. Allow the operator a few minutes to successfully install the OpenShift Pipelines operator into the cluster.

    ![Web Console - OpenShift Pipelines Successful Install](../assets/images/web-console-openshift-pipelines-successful-install.png){ align=center }


## Configure the GitHub integration

1. In your web browser, go to the following GitHub repositories:

    * [https://github.com/rh-mobb/common-java-dependencies](https://github.com/rh-mobb/common-java-dependencies){:target="_blank"}
    * [https://github.com/rh-mobb/aro-workshop-app](https://github.com/rh-mobb/aro-workshop-app){:target="_blank"}

    Ensure you are logged in to GitHub and select the *Fork* button for **both** repositories and then choose your own GitHub account.

    ![GitHub Repository Fork](../assets/images/github-fork.png)

1. Next, browse to [https://github.com/settings/tokens/new](https://github.com/settings/tokens/new){:target="_blank"} and create a new GitHub Personal Access Token. Set the Scope to "repo" and click *Generate Token*.

    ![GitHub Personal Access Token](../assets/images/github-personal-access-token.png)

    !!! warning

        **Do not** forget to delete this token once the workshop is over.

1. Next, save the token to your Cloud Shell instance. To do so, run the following command, ensuring you replace the `INSERT_TOKEN_HERE` with your Personal Access Token:

    ```bash
    export GH_PAT=INSERT_TOKEN_HERE
    ```

1. Then, save your GitHub username as a variable. To do so, run the following command, ensuring you replace the `GITHUB_USER_ID` with your GitHub username.

    ```bash
    export GH_USER=GITHUB_USER_ID
    ```

1. Save these to your .workshoprc in case of cloud shell timeout

    ```bash
    echo "export GH_USER=${GH_USER}" >> ~/.workshoprc
    echo "export GH_PAT=${GH_PAT}" >> ~/.workshoprc
    ```

1. Next, let's configure our Git CLI. To do so, run the following commands:

    ```bash
    git config --global user.email "${GH_USER}@github.io"
    git config --global user.name "${GH_USER}"
    ```

1. Next, we'll create a new working directory to clone our forked GitHub repositories. To do so, run the following commands:

    ```bash
    mkdir ~/gitops
    cd ~/gitops
    git clone https://github.com/${GH_USER}/common-java-dependencies.git
    git clone https://github.com/${GH_USER}/aro-workshop-app.git
    ```

## Import tasks to our pipeline

The next thing we need to do is import common tasks that our pipeline will use. These common tasks are designed to be reused across multiple pipelines.

1. Switch back to the `microsweeper-ex` project from earlier

    ```bash
    oc project microsweeper-ex
    ```

1. Let's start by taking a look at the reusable tasks that we will be using. To do so, run the following command:

    ```bash
    ls ~/gitops/aro-workshop-app/pipeline/tasks/*.yaml
    ```

    Expected output:

    ```{.txt .no-copy}
    /home/user/gitops/aro-workshop-app/pipeline/tasks/1-git-clone.yaml
    /home/user/gitops/aro-workshop-app/pipeline/tasks/2-mvn.yaml
    /home/user/gitops/aro-workshop-app/pipeline/tasks/3-mvn-build-image.yaml
    /home/user/gitops/aro-workshop-app/pipeline/tasks/4-apply-manifest.yaml
    /home/user/gitops/aro-workshop-app/pipeline/tasks/5-update-deployment.yaml
    ```

    - `1-git-clone.yaml` <br>
      Clones a given GitHub Repo.

    - `2-mvn.yaml` <br>
      This Task can be used to run a Maven build

    - `3-mvn-build-image.yaml` <br>
      Packages source with maven builds and into a container image, then pushes it to a container registry. Builds source into a container image using Project Atomic's Buildah build tool. It uses Buildah's support for building from Dockerfiles, using its buildah bud command.This command executes the directives in the Dockerfile to assemble a container image, then pushes that image to a container registry.

    - `4-apply-manifest.yaml` <br>
      Applied manifest files to the cluster

    - `5-update-deployment.yaml` <br>
      Updates a deployment with the new container image.

1. Next, we need to apply all of these tasks to our cluster.  To do so, run the following command:

    ```bash
    oc apply -n microsweeper-ex -f \
      ~/gitops/aro-workshop-app/pipeline/tasks
    ```

    Your output should match this:

    ```bash
    task.tekton.dev/git-clone configured
    task.tekton.dev/maven configured
    task.tekton.dev/build-maven-image configured
    task.tekton.dev/apply-manifests configured
    task.tekton.dev/update-deployment configured
    ```

## Configure Azure Container Registry

1. Next we need to create an Azure Container Registry. To do so, run the following command:

    ```bash
    az acr create --resource-group ${AZ_RG} \
      --name mobbws${UNIQUE} --sku Basic
    az acr update -n mobbws${UNIQUE} --admin-enabled true
    ```

1. Next, we need to create a secret to push and pull images into the Azure Container Registry. To do so, run the following command to retrieve the token:

    ```bash
    ACR_PWD=$(az acr credential show -n mobbws${UNIQUE} -g ${AZ_RG} --query 'passwords[0].value' -o tsv)
    echo "ACR Token (Sensitive Value): ${ACR_PWD}"
    ```

1. Then, create the secret using the retrieved token. To do so, run the following command:

    ```bash
    oc -n microsweeper-ex create secret docker-registry --docker-server=mobbws${UNIQUE}.azurecr.io \
      --docker-username="mobbws${UNIQUE}" --docker-password="${ACR_PWD}" \
      --docker-email=unused acr-secret
    ```

## Configure our pipeline

1. Next, create the pipeline service account and permissions that the pipeline tasks will run under. To do so, run the following command:

    ```bash
    oc create -f ~/gitops/aro-workshop-app/pipeline/1-pipeline-account.yaml
    ```

    Your output should match this:

    ```{.txt .no-copy}
    serviceaccount/pipeline configured
    secret/kube-api-secret created
    role.rbac.authorization.k8s.io/pipeline-role created
    rolebinding.rbac.authorization.k8s.io/pipeline-role-binding created
    ```

    However it's okay if you see the error:

    ```{.txt .no-copy}
    serviceaccounts "pipeline" already exists
    ```

1. Next, we need to link the ACR credential secret we just created, so the service account can mount and pull images from ACR. To do so, run the following command:

    ```bash
    oc -n microsweeper-ex secrets link pipeline acr-secret --for=pull,mount
    ```

1. Next, we should verify that our secret is linked to our service account, to do so, run the following command:

    ```bash
    oc -n microsweeper-ex describe sa pipeline | grep "acr-secret"
    ```

    You should see the following output:

    ```{.text .no-copy}
                        acr-secret
    Mountable secrets:   acr-secret
    ```

1. We need the microsweeper service account to also be able to use the acr-secret.

    ```bash
    oc -n microsweeper-ex secrets link microsweeper-appservice acr-secret --for=pull,mount
    ```

1. We also need to give the pipeline permission for certain privileged security context constraints to that it can execute builds. To grant these permissions, run the following command:

    ```bash
    oc -n microsweeper-ex adm policy add-scc-to-user anyuid -z pipeline
    oc -n microsweeper-ex adm policy add-scc-to-user privileged -z pipeline
    ```

1. Create a persistent volume claim that the pipeline will use to store build images. To do so, run the following command:

    ```bash
    oc create -f ~/gitops/aro-workshop-app/pipeline/2-pipeline-pvc.yaml
    ```

1. Next, let's review the pipeline definition. To do so, open the following link in a new tab: [https://github.com/rh-mobb/aro-hackaton-app/blob/main/pipeline/3-pipeline.yaml](https://github.com/rh-mobb/aro-hackaton-app/blob/main/pipeline/3-pipeline.yaml){:target="_blank"}.

    Browse through the file and notice all the tasks that are being executed. These are the tasks we imported in the previous step. The pipeline definition simply says which order the tasks are run and what parameters should be passed between tasks.

## Update Application Settings

1. Now that we have the source code forked, we need to copy the properties file we created in the previous section to our new code base. To do so, run the following command:

    ```bash
    cp ~/aro-workshop-app/src/main/resources/application.properties \
      ~/gitops/aro-workshop-app/src/main/resources/application.properties
    ```

1. We also want to add the Quarkus Kubernetes extensions like we did earlier

    ```bash
    quarkus ext add openshift kubernetes-config
    ```

1. Finally, let's commit our changes to GitHub. To do so, run the following set of commands:

    ```
    cd ~/gitops/aro-workshop-app
    git remote set-url origin https://${GH_USER}:${GH_PAT}@github.com/${GH_USER}/aro-workshop-app
    git add .
    git commit -am "Update Properties File"
    git push
    ```

1. In addition, let's go ahead and create a secret with our GitHub credentials that we will need later. To do so, run the following command:

    ```yaml
    cat << EOF | oc apply -f -
    apiVersion: v1
    kind: Secret
    metadata:
      name: gitsecret
      annotations:
        tekton.dev/git-0: https://github.com
      namespace: microsweeper-ex
    type: kubernetes.io/basic-auth
    stringData:
      username: ${GH_USER}
      secretToken: ${GH_PAT}
    EOF
    ```

1. Now let's proceed with creating our pipeline definition. To do so, run the following command:

    ```bash
    oc create -f ~/gitops/aro-workshop-app/pipeline/3-pipeline.yaml
    ```

1. Next, let's tell the deployment to use ACR instead of the built-in OpenShift image registry. To do so, run the following command:

    ```bash
    oc patch deploy/microsweeper-appservice \
      --patch-file ~/gitops/aro-workshop-app/pipeline/5-deployment-patch.yaml
    ```

1. Finally, we will create a pipeline run that will execute the pipeline, pull the code from your forked GitHub repositories, build the image, and deploy it to ARO. To do this, run the following command:

    ```yaml
    cat << EOF | oc create -f -
    apiVersion: tekton.dev/v1beta1
    kind: PipelineRun
    metadata:
      generateName: minesweeper-pipeline-
      namespace: microsweeper-ex
    spec:
      pipelineRef:
        name: maven-pipeline
      serviceAccountName: pipeline
      params:
      - name: application-name
        value: microsweeper-appservice
      - name: dependency-git-url
        value: https://github.com/${GH_USER}/common-java-dependencies
      - name: application-git-url
        value: https://github.com/${GH_USER}/aro-workshop-app
      - name: dockerfile-path
        value: src/main/docker/Dockerfile.jvm
      - name: image-name
        value: mobbws${UNIQUE}.azurecr.io/minesweeper
      workspaces:
      - name: source
        persistentVolumeClaim:
          claimName: minesweeper-source-pvc
    EOF
    ```

## Validate the pipeline

Let's take a look at the OpenShift Web Console to see what was created and if the application was successfully deployed.

!!! warning "Make sure your Project is set to `microsweeper-ex`"

1. From the OpenShift Web Console, click on *Pipelines* ->*Tasks*.

    ![Image](images/pipeline-tasks-ocp.png)

    Notice the 5 tasks that we imported and click into them to view the YAML definitions.

1. Next, lets look at the Pipeline. Click on *Pipelines*. Notice that it is either still running, or the last run was successful. Click on *maven-pipeline* to view the pipeline details.

    ![Image](images/pipeline-ocp.png)

1. On the following screen, click on *PipelineRuns* to view the status of each Pipeline Run.

    ![Image](images/pipeline-run-ocp.png)

1. Lastly, click on the *PipelineRun* name and you can see all the details and steps of the pipeline. If your are curious, you can also view the logs of the different tasks that were run.

    ![Image](images/pipeline-run-details-ocp.png)

1. Watch the PipelineRun page as the tasks complete and the PipelineRun finishes.

## Event Triggering

At this point, we can successfully build and deploy new code by manually running our pipeline. But how can we configure the pipeline to run automatically when we commit code to Git? We can do so with an Event Listener and a Trigger.

1. Let's start by looking at the resources we will be creating to create our event listener and trigger.

    ```bash
    ls ~/gitops/aro-workshop-app/pipeline/tasks/event-listener/*.yaml
    ```

    Your output should match:

    ```{.text .no-copy}
    /home/user/gitops/aro-workshop-app/pipeline/tasks/event-listener/1-web-trigger-binding.yaml
    /home/user/gitops/aro-workshop-app/pipeline/tasks/event-listener/2-web-trigger-template.yaml
    /home/user/gitops/aro-workshop-app/pipeline/tasks/event-listener/3-web-trigger.yaml
    /home/user/gitops/aro-workshop-app/pipeline/tasks/event-listener/4-event-listener.yaml
    ```

1. Take a look at the files listed:

    - `1-web-trigger-binding.yaml`
      This TriggerBinding allows you to extract fields, such as the git repository name, git commit number, and the git repository URL in this case.
      To learn more about TriggerBindings, click [here](https://tekton.dev/docs/triggers/triggerbindings/)

    - `2-web-trigger-template.yaml`
      The TriggerTemplate specifies how the pipeline should be run.  Browsing the file above, you will see there is a definition of the PipelineRun that looks exactly like the PipelineRun you create in the previous step.  This is by design! ... it should be the same.

    To learn more about TriggerTemplates, [review the Tekton documentation](https://tekton.dev/docs/triggers/triggertemplates/){:target="_blank"}.

    - `3-web-trigger.yaml`
      The next file we have is the Trigger.  The Trigger specifies what should happen when the EventListener detects an Event.  Looking at this file, you will see that we are looking for 'Push' events that will create an instance of the TriggerTemplate that we just created.  This in turn will start the PipelineRun.

      To learn more about Triggers, [review the Tekton documentation](https://tekton.dev/docs/triggers/triggers/){:target="_blank"}.

    - `4-event-listenter.yaml`
      The last file we have is the Event Listener.  An EventListener is a Kubernetes object that listens for events at a specified port on your OpenShift cluster. It exposes an OpenShift Route that receives incoming event and specifies one or more Triggers.

      To learn more about EventListeners, [review the Tekton documentation](https://tekton.dev/docs/triggers/eventlisteners/){:target="_blank"}.

1. Edit `~/gitops/aro-workshop-app/pipeline/tasks/event-listener/2-web-trigger-template.yaml` with your favorite text editor (vim!) and replace the `<>` sections with the values of from the following command:

    ```bash
    echo "GITHUB_USER: ${GH_USER}"
    echo "ACR_ENDPOINT: mobbws${UNIQUE}.azurecr.io/minesweeper"
    ```

    ```bash
    vim ~/gitops/aro-workshop-app/pipeline/tasks/event-listener/2-web-trigger-template.yaml
    ```

    ```{.text .no-copy}
      - name: dependency-git-url
        value: https://github.com/GITHUB_USER_ID/common-java-dependencies
      - name: application-git-url
        value: https://github.com/GITHUB_USER_ID/aro-workshop-app
    [...]
      - name: image-name
        value: ACR_ENDPOINT.azurecr.io/minesweeper
    ```

1. Now that you have reviewed all the files, let's apply them to our cluster.

    ```bash
    oc -n microsweeper-ex create -f \
      ~/gitops/aro-workshop-app/pipeline/tasks/event-listener
    ```

Before we test out our EventListener and Trigger, lets review what was created in OpenShift.

1. From the OpenShift console, under Pipelines, click on Triggers.

1. Browse the EventListener, TriggerTemplate and TriggerBindings that you just created.
![Image](images/ocp-triggers.png)

The next thing we need to do, is connect our EventListener with Git.  When an action, such as a git push, happens, git will need to call our EventListener to start the build and deploy process.

1. The first thing we need to do is expose our EventListener service to the internet. To do so, we'll run the `oc expose` command:

    ```bash
    oc -n microsweeper-ex expose svc el-minesweeper-el
    ```

    !!! note
        Since this is public cluster, we can simply use the default ingress controller. For a private cluster, you can use Azure Front Door to expose the endpoint.

1. To get the URL of the Event Listener Route that we just created, run the following command:

    ```bash
    oc -n microsweeper-ex get route el-minesweeper-el \
      -o jsonpath="http://{.spec.host}{'\n'}"
    ```

    For example, your output will look something similar to:

    ```bash
    el-minesweeper-el-microsweeper-ex.apps.ce7l3kf6.{{ azure_region }}.aroapp.io
    ```

The last step we need to do, is configure GitHub to call this event listener URL when events occur.

From your browser, go to your personal GitHub aro-workshop-app repository, and click on *Settings*.
![Image](images/git-settings.png)

On the next screen, click on *Webhooks*.
![Image](images/git-settings-webhook.png)

Click on the *Add Webhook* button.
![Image](images/git-add-webhook.png)

On the next screen, enter the following settings:

- **PayloadURL** - enter the URL you got above (for example: `http://el-minesweeper-el-microsweeper-ex.apps.ce7l3kf6.{{ azure_region }}.aroapp.io`)
- **ContentType** - select application/json
- **Secret** - this your GitHub Personal Access Token (`echo $GH_PAT`)

Where does the secret value come from?
Refer to the `~/gitops/aro-workshop-app/pipeline/tasks/event-listener/3-web-trigger.yaml` file.

You will see the following snippet that contains the secret to access git.

```bash
  interceptors:
    - ref:
        name: "github"
      params:
        - name: "secretRef"
          value:
            secretName: gitsecret
            secretKey: secretToken
        - name: "eventTypes"
          value: ["push"]
```

The secret you enter here for the git webhook, needs to match the value for the *secretToken* key of the a secret named gitsecret. If you remember in the previous step, we create this secret and used your git token as this value.

Keep the remaining defaults, and click *Add webhook*.

![Image](images/add-webhook.png)

### Test the Event Triggering

Now that we have our trigger, eventlistener and git webhook setup, lets test it out.

Make sure you are in the directory for your personal git repo where the application is, and edit the `./src/main/resources/META-INF/resources/index.html` file.

Search for Leaderboard and change it to \<YOUR NAME\> Leaderboard.

```bash
cd ~/gitops/aro-workshop-app
vi src/main/resources/META-INF/resources/index.html
```

![Image](images/html-edit.png)

Now commit and push the change

```bash
git commit -am 'Updated leaderboard title'
git push
```

Pushing the change to the your git repository will kick of the event listener which will start the pipeline.

As a bonus, if you want to look at the logs of the event listener, you can use the tekton (tkn) cli.

```bash
tkn eventlistener logs minesweeper-el
```
![Image](images/tkn.png)

Quickly switch over to your OpenShift Web Console, and watch the pipeline run.

![Image](images/watch-pipeline.png)

Once the pipeline finishes, check out the change.

From the OpenShift Web Console, click on *Networking* -> *Routes*.
![Image](images/route-2.png)

Hopefully, you will see the updated application with a new title for the leaderboard!
![Image](images/updated-minesweeper.png)
