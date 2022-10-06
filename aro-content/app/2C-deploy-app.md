# Automate deploying the application with OpenShift Pipelines ( Part 3 )

We will be using OpenShift Pipelines which is based on the Open Source Tekton project to automatically deploy our application using a CI/CD pipeline.
 
If you would like to read more about OpenShift Pipelines, click [here](https://docs.openshift.com/container-platform/4.11/cicd/pipelines/understanding-openshift-pipelines.html)

The first thing you need to do is fork the code repositories so that you can make changes to the code base and then OpenShift pipelines will build and deploy the new code.

Opening your browser, go to the following github repos 
https://github.com/rh-mobb/common-java-dependencies
https://github.com/rh-mobb/aro-hackaton-app

For each of the repositories, click Fork and then choose your own Git Account.
![Image](images/fork-git.png)

**Clone git repos**

Next, we will need to make a directory and clone your personal github repository that you just forked to.

```bash
mkdir $USERID
cd $USERID
git clone https://github.com/<YOUR GITHUB USER ID>/common-java-dependencies
git clone https://github.com/kmcolli/aro-hackaton-app
```

**Review OpenShift Pipeline Tasks**
The next thing we need to do is import common Tekton tasks that our pipeline will use.  These common tasks are designed to be reused across multiple pipelines.

Let's start by taking a look at the reusable Tasks that we will be using.  From your cloud shell, change directorys to ~/aro-hackaton-app/pipeline and list the files.

```bash
cd ~/aro-hackaton-app/pipeline/tasks
ls | tr “” “\n”
```

Expected output:<br>
![Image](images/pipeline-tasks.png)

- **1-git-clone.yaml** <br>
  Clones a given GitHub Repo.

- **2-mvn.yaml** <br>
  This Task can be used to run a Maven build

- **3-mvn-build-image.yaml** <br>
  Packages source with maven builds and into a container image, then pushes it to a container registry. Builds source into a container image using Project Atomic's Buildah build tool. It uses Buildah's support for building from Dockerfiles, using its buildah bud command.This command executes the directives in the Dockerfile to assemble a container image, then pushes that image to a container registry.

- **4-apply-manifest.yaml** <br>
  Applied manifest files to the cluster

- **5-update-deployment.yaml** <br>
  Updates a deployment with the new container image.

From the Cloud Shell, we need to apply all of these tasks to our cluster.  Run the following command:

```bash
oc apply -f ~/aro-hackaton-app/pipeline/tasks
``` 

expected output:
![Image](images/apply-pipeline-tasks.png)

**Configure Azure Container Registry**
Next, we need to create a secret to push and pull images into Azure Container Registry.  Each attendee has their own Azure Container Registry service assigned to them, with the naming convention <USERID>acr.azurecr.io

```bash
ACRPWD=$(az acr credential show -n ${USERID}acr -g $ARORG --query 'passwords[0].value' -o tsv)

oc create secret docker-registry --docker-server=${USERID}acr.azurecr.io --docker-username=${USERID}acr --docker-password=$ACRPWD --docker-email=unused acr-secret
```

**Configure the pipleine service account**
Create the pipeline service account and permissions that the pipeline tasks will run under:

```bash
oc create -f ~/aro-hackaton-app/pipeline/1-pipeline-account.yaml
```

Expected output:
![Image](images/create-pipeline-account.png)

Link the acr-secret you just created to it can mount and pull images

```bash
oc secrets link pipeline acr-secret --for=pull,mount
```

Make sure the secret is linked to the pipeline service account.

```bash
oc describe sa pipeline
```

expected output: 
![Image](images/pipeline-sa-secret.png)

We also need to give the pipeline permission for certain security context constraints to that it can execute.

```bash
oc adm policy add-scc-to-user anyuid -z pipeline
oc adm policy add-scc-to-user privileged -z pipeline
```


**Create a PVC that the pipeline will use to store the build images**\

```bash
oc create -f ~/aro-hackaton-app/pipeline/2-pipeline-pvc.yaml
```

**Review the Pipeline Definition**
Next we need to create the pipeline definition.  Before we actually create the pipeline, lets take a look at the pipeline definition.

Open a browser to the git repo to browse the pipeline.yaml file.<br>
https://github.com/rh-mobb/aro-hackaton-app/blob/main/pipeline/3-pipeline.yaml

Browse through the file and notice all the tasks that are being executed.  These are the tasks we imported in the previous step.  The pipeline definition simply says which order the tasks are run and what parameters should be passed between tasks.
![Image](images/pipeline-yaml.png)

**Update Application Settings**
Now that we have the source code forked, we need to copy the properties file we created earlier to our new code base.  Let's create a new directory, clone the repo and copy the file.

Using the cloud shell, run the following commands.
```bash
cd ~/$USERID
cp ../aro-hackaton-app/src/main/resources/application.properties aro-hackaton-app/src/main/resources/application.properties 
```

**Setup git and push changes to the properties file**

```bash
git config --global user.email "<your github email>"
git config --global user.name “<your github username>”
git init
```

**Commit changes to git**
```
cd aro-hackaton-app
git add *
git commit -am "Update Propereties File"
git push
```
!!! info

    when prompted log in with your git user name ( email ) and git token.  If you need a git token, please refer to this [document](https://catalyst.zoho.com/help/tutorials/githubbot/generate-access-token.html)

**Create git secret**

While you have your github userid and secret handy, let's also create a secret containing your github credentials that we will need later.  First set git envrionment variables and then run a script to create the secret.

```bash
export GIT_USER=<your git email>
export GIT_TOKEN=<your git token>
~/aro-hackaton-app/pipeline/0-github-secret.sh
```

**Create the pipeline definition on your cluster**

```bash
oc create -f ~/aro-hackaton-app/pipeline/3-pipeline.yaml
``` 

**Update the deployment to use ACR**
Finally we will create a pipeline run that will execute the pipeline, which will pull code from the your git repo that you forked, will build the image and deploy it to OpenShift.

There are a couple settings in the pipeline run that we will need to update.

Before we can actually run the pipeline that will update the deployment, we need to tell the deployment to use the ACR pull secret we created in the previous step.

To do so, run the following command.

```bash
oc patch deploy/microsweeper-appservice --patch-file ~/aro-hackaton-app/pipeline/5-deployment-patch.yaml
```


Edit the ~/$USERID/aro-hackaton-app/pipeline/4-pipeline-run.yaml file.  The three things to change is the:
* **dependency-git-url** - to point to your personal git repository
* **application-git-url** - to point to your personal git repository
* **image-name** - change this to reflect to the ACR Registry created for you ... this should be $USERIDacr.azurecr.io/minesweeper

![Image](images/pipeline-run.png)

**Create the pipeline run**

```bash
oc create -f ~/$USERID/aro-hackaton-app/pipeline/4-pipeline-run.yaml
```

This will start a pipeline run and redeploy the minesweeper application, but this time will build the code from your github repository and the pipeline will deploy the application as well to OpenShift.

**Validate the pipeline**
Let's take a look at the OpenShift console to see what was created and if the application was successfully deployed.

From the OpenShift Conole - Administrator view, click on Pipelines and then Tasks.
![Image](images/pipeline-tasks-ocp.png)

Notice the 5 tasks that we imported and click into them to view the yaml defitions.

Next, lets look at the Pipeline.   Click on Pipelines.  Notice that that last run was successful.  Click on maven-pipeline to view the pipeline details.
![Image](images/pipeline-ocp.png)

On the following screen, click on Pipeline Runs to view the status of each Pipeline Run.
![Image](images/pipeline-run-ocp.png)

Lastely, click on the PipeRun name and you can see all the details and steps of the Pipeline.  If your are curious, also click on logs and view the logs of the different tasks that were ran.
![Image](images/pipeline-run-details-ocp.png)

# Event Triggering 
At this point, we can successfully build and deploy new code by manually runnning a pipeline run.  But how can we configure the pipeline to run automatically when we commit code with git?  We can do so with an Event Listener and a Trigger!

Let's start by looking at the resources we will be creating to create our event listener and trigger.

```bash
ls ~/$USER/aro-hackaton-app/pipeline/tasks/event-listener | tr “” “\n”
```

expected output:
![Image](images/event-listener-files.png)

Take a look at the files listed:

- **1-web-trigger-binding.yaml**
  This TriggerBinding allows you to extract fields, such as the git repository name, git commit number, and the git repository URL in this case.
  To learn more about TriggerBindings, click [here](https://tekton.dev/docs/triggers/triggerbindings/)

- **2-web-trigger-template.yaml**
  The TriggerTemplate specifies how the pipeline should be run.  Browsing the file above, you will see there is a definition of the PipelineRun that looks exactly like the PipelineRun you create in the previous step.  This is by design! ... it should be the same.

  You will need to edit this file so it points to your git repository and acr image repository.  Change the following entries to point to your GIT Repository.

  ```bash
  - name: dependency-git-url
    value: https://github.com/<YOUR-GITHUB-ID>/common-java-dependencies
  - name: application-git-url
    value: https://github.com/<YOUR-GITHUB-ID>/aro-hackaton-app
  ```

!!! note
  As a reminder, each attendee has their own Azure Container Registry service assigned to them, with the naming convention <USERID>acr.azurecr.io 

  ```bash
  - name: image-name
    value: <CHANGE-ME>.azurecr.io/minesweeper
  ```

To learn more about TriggerTemplates, click [here](https://tekton.dev/docs/triggers/triggertemplates/)

- **3-web-trigger.yaml**
  The next file we have is the Trigger.  The Trigger specifies what should happen when the EventListener detects an Event.  Looking at this file, you will see that we are looking for 'Push' events that will create an instance of the TriggerTemplate that we just created.  This in turn will start the PipelineRun.

  To learn more about Triggers, click [here](https://tekton.dev/docs/triggers/triggers/)

- **4-event-listenter.yaml**
  The last file we have is the Event Listener.  An EventListener is a Kubernetes object that listens for events at a specified port on your OpenShift cluster. It exposes an OpenShift Route that receives incoming event and specifies one or more Triggers. 

  To learn more about EventListeners, click [here](https://tekton.dev/docs/triggers/eventlisteners/)

  Now that you have reviewed all the files, let's apply them to our cluster.

```bash
  oc create -f ~/$USER/aro-hackaton-app/pipeline/tasks/event-listener
```

Before we test out our EventListener and Trigger, lets review what was created in OpenShift.

From the OpenShift console, under Pipelines, click on Triggers.

Browse the EventListener, TriggerTemplate and TriggerBindings that you just created.
![Image](images/ocp-triggers.png)

The next thing we need to do, is connect our EventListener with Git.  When an action, such as a git push, happens, git will need to call our EventListner to start the build and deploy process.

The first thing we need to do is exposing our EventListner service.

From the Cloud Shell, let's start by looking at the event listener service.

```bash
oc get svc
```

expected output:
![Image](images/ocp-svc.png)

Expose the service so that Git is able to connect to the event listener.<br>

!!! note 
    Since this is public cluster, we can simply use the included OpenShift Ingress Controller as it is exposed to the Internet.  For a private cluster, you can follow the same process as we did above in exposing the minesweeper application with Front Door!

```bash
oc expose svc el-minesweeper-el
```

To get the url of the Event Listener Route that we just created, run the following command:

```bash
oc get route el-minesweeper-el
```

expected output:
![Image](images/el-route.png)

The last step we need to do, is configure git to call this event listner URL when events occur.

From your browser, go to your personal GitHub aro-hackaton-app repository, and click on Settings.
![Image](images/git-settings.png)

On the next screen, click on webhooks.
![Image](images/git-settings-webhook.png)

Click on add webhook
![Image](images/git-add-webhook.png)

On the next screen, enter the following settings:
- **PayloadURL** - enter http://<event listener hostname you got above>
- **ContentType** - select application/json
- **Secret** - this your github token 

Where does this secret value come from?
Refer to the ~/$USERID/aro-hackaton-app/pipeline/tasks/event-listener/web-trigger.yaml file.

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

The secret you enter here for the git webhook, needs to match the value for the *secretToken* key of the a secret named gitsecret.  If you remember in the previous step, we create this secret and used your git token as this value.

Keep the remaining defaults, and click Add webhook

![Image](images/add-webhook.png)

## Test it out!!

Now that we have our trigger, eventlistener and git webhook setup, lets test it out.

Make sure you are in the directory for your personal git repo where the application is, and edit the */src/main/resources/META-INF/resources/index.html* file.

Search for Leaderboard and change it to \<YOUR NAME\> Leaderboard.

```bash
cd ~/$USERID/aro-hackaton-app
vi src/main/resources/META-INF/resources/index.html
```

![Image](images/html-edit.png)

Now commit and push the change

```bash
git commit -am 'updated leaderboard title'
git push
```

Pushing the change to the your git repository will kick of the event listener which will start the pipeline.

As a bonus, if you want to look at the logs of the event listener, you can use the tekton (tkn) cli.

```bash
tkn eventlistener logs minesweeper-el
```
![Image](images/tkn.png)


Quickly switch over to your OpenShift Console, and watch the pipeline run.

![Image](images/watch-pipeline.png)

Once the pipeline finishes, check out the change.

From the OpenShift Console, click on Networking and the Routes.
![Image](images/route-2.png)

and drum roll ...  you should see the updated application with a new title for the leaderboard.
![Image](images/updated-minesweeper.png)