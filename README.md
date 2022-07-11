- after ssh to your ec2 you can create your local registry of docker images
```sh
  cd /Dockerfile-Plugins
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

- finally the purpose of this repo to build jenkins pod on kubernetes with preinstalled plugins and password as shown in Dockerfile-Plugins path
