envsubst << EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: gitsecret
  annotations:
    tekton.dev/git-0: https://github.com
type: kubernetes.io/basic-auth
stringData:
  username: $GIT_USER
  password: $GIT_TOKEN
EOF