# install docker
sudo apt update -y
sudo apt install -y docker.io

sudo systemctl start docker
sudo systemctl enable docker

# install k3d
sudo wget https://github.com/rancher/k3d/releases/download/v5.8.3/k3d-linux-amd64 -O /usr/local/bin/k3d
sudo chmod +x /usr/local/bin/k3d

echo "k3d version: $(k3d version)"

# install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# create k3d cluster
k3d cluster create dev-cluster --agents 2 -p "80:80@loadbalancer" -p "443:443@loadbalancer"

# create namespaces
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

# install argocd
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# wait for argocd
echo "Waiting for Argo CD pods to be Ready..."
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
echo "Argo CD pods are Ready."

# port forward argocd-server
kubectl -n argocd port-forward svc/argocd-server --address 0.0.0.0 8080:443 &
sleep 5

# install argocd cli
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

sleep 3

# login
argocd login localhost:8080 --insecure --username admin --password "$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode)"

# create repository secret
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
	echo "Missing SSH key: $HOME/.ssh/id_ed25519"
	exit 1
fi

kubectl create secret generic argocd-repo-ssh \
	-n argocd \
	--from-literal=type=git \
	--from-literal=url=git@github.com:0xk1/Inception-of-things.git \
	--from-file=sshPrivateKey=$HOME/.ssh/id_ed25519 \
	--dry-run=client -o yaml | kubectl apply -f -

kubectl label secret argocd-repo-ssh -n argocd argocd.argoproj.io/secret-type=repository --overwrite

# create argocd app
argocd app create playground \
  --repo 'git@github.com:0xk1/Inception-of-things.git' \
  --path 'p3/app' \
  --dest-server 'https://kubernetes.default.svc' \
  --dest-namespace 'dev' \
  --revision part3 \
  --sync-policy automated \
  --self-heal \
  --auto-prune \
  --upsert

sleep 3

# sync app
argocd app sync playground