# install docker
sudo apt update -y && sudo apt install docker.io -y
systemctl start docker && systemctl enable docker

# install k3d
sudo wget https://github.com/rancher/k3d/releases/download/v5.8.3/k3d-linux-amd64 -O /usr/local/bin/k3d
sudo chmod +x /usr/local/bin/k3d

echo "k3d version: $(k3d version)"


# install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# create k3d cluster
k3d cluster create dev-cluster --agents 2


#install helm
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# wait for argocd pods to be Running
echo "Waiting for Argo CD pods to be Running..."
while true; do
	pods_status=$(kubectl get pods -n argocd --no-headers 2>/dev/null || true)
	if [ -z "$pods_status" ]; then
		sleep 5
		continue
	fi
	echo "$pods_status" | awk '$3 != "Running" {exit 1}'
	if [ $? -eq 0 ]; then
		break
	fi
	sleep 5
done
echo "Argo CD pods are Running."


# port forward argocd-server
kubectl -n argocd port-forward svc/argocd-server --address 0.0.0.0 8080:443 &
sleep 5


# install argocd cli
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

sleep 3

# get argocd initial admin password and login directly
argocd login localhost:8080 --insecure --username admin --password "$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode)"

sleep 3

kubectl create ns dev 

# create argocd app
argocd app create playground \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace dev

sleep 3

# sync the app
argocd app sync playground

