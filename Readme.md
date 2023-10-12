To build:

`docker build -t edmore/cytof-pipeline-fargate .`

On amd64 architectures:

`docker build -f Dockerfile_amd64 -t edmore/cytof-pipeline-fargate .`

To run:

`docker-compose up --build`

To deploy:

```
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <accountNumber>.dkr.ecr.us-east-1.amazonaws.com

docker build <-f Dockerfile> -t edmore/cytof-pipeline-fargate .

docker tag edmore/cytof-pipeline-fargate:latest <accountNumber>.dkr.ecr.us-east-1.amazonaws.com/edmore/cytof-pipeline-fargate:latest

docker push <accountNumber>.dkr.ecr.us-east-1.amazonaws.com/edmore/cytof-pipeline-fargate:latest

```