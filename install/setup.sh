#!/bin/sh

pushd ..

printf "\nDeploy HTTPBin service ...\n"
kubectl apply -f apis/httpbin.yaml
kubectl apply -f apis/httpbin2.yaml
kubectl apply -f apis/bookstore/bookstore.yaml

printf "\Deploy gRPC Upstream ...\n"
kubectl apply -f upstreams/httpbin2-upstream.yaml
kubectl apply -f upstreams/bookstore-upstream.yaml

printf "\nDeploy Routetables ...\n"
kubectl apply -f routetables/httpbin2-routetable.yaml
kubectl apply -f routetables/bookstore-routetable.yaml

printf "\nDeploy VirtualServices ...\n"
kubectl apply -f virtualservices/api-example-com-vs.yaml
kubectl apply -f virtualservices/grpc-example-com-vs.yaml

popd