- building minikube remotly on ec2 instance 
```sh
  git clone https://github.com/sambo2021/Jenkins-as-a-Code.git
  cd /Jenkins-as-a-Code.git/Minikube-Infra
  touch TF_key.pem
  ./Build.sh
```

- after ssh to your ec2 you can create your local registry of docker images
```sh
  cd ../Dockerfile-Plugins
  sudo docker build -t customized-jenkins .
  sudo docker run -d -p 5000:5000 --restart=always --name registry registry:2 
  sudo docker tag customized-jenkins localhost:5000/customized-jenkins
  sudo docker push localhost:5000/customized-jenkins
```
- then using image inside pod yaml file 
```sh
   spec:
    containers:
    - name: <container name>
      image: localhost:5000/customized-jenkins
      imagePullPolicy: IfNotPresent
```


- then create all yaml of jenkins 
```sh
   cd ../jenkins-yamle-files
   sudo kubectl create namespace jenkins
   sudo kubectl create -f Jenkins-Service-Account.yaml
   sudo kubectl create -f Jenkins-Cluster-Role.yaml
   sudo kubectl create -f Jenkins-Cluster-Role-Binding.yaml
   sudo kubectl create -f Jenkins-Presistent-Volume.yaml
   sudo kubectl create -f Jenkins-Service.yaml
   sudo kubectl create -f Jenkins-Pod.yaml
```
- exec jenkins pod and cp filr jenkins.yaml into /var/jenkins_home/jenkins.yaml to just test configuration as a code manually at first then we gonna automate it by volume mounting 
```sh
sudo kubectl exec -it jenkins -n jenkins  -- /bin/bash
```
- or copy that jenkins.yaml into /data/jenkins-volume inside minikube cuse it is mounted by volume claim into jenkins pod
- now you can access jenkins at ec2_public_IP with name and password admin:admin as configured in Dockerfile
- finally the purpose of this repo to build jenkins pod on kubernetes with preinstalled plugins and password as shown in Dockerfile-Plugins path
