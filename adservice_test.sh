#!/bin/bash
#

install_istio(){

	echo Installing Istio

		curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.15.1 sh -

		#
		# SETTING ISTIO PATH VARIABLE
		echo "Setting istio path variable"
		cd istio-1.15.1
		#
		#
		export PATH="$PATH:/home/james/istio-1.15.1/bin"
		#
		kubectl label namespace default istio-injection=enabled
		# istio precheck
		echo "istio precheck"
		istioctl x precheck
		#
		#install istio
		echo "install istio......"
		# istioctl install <<-EOF
		# yes
		# EOF

		cd ~
		istioctl manifest apply -f ./microservices-demo/release/currencyservices/currency-overlay-config.yaml <<-EOF
		yes
		EOF

		echo waiting to update istio-ingressgateway.....
		sleep 60
}

uninstall_istio(){
echo uninstalling ISTIO..............

 istioctl uninstall --purge<<-EOF
		y
		EOF
echo Waiting for uninstall to complete..............
 sleep 30
}

install_linkerd(){

	kubectl apply -f ./microservices-demo/release/currencyservices/currency-cpu-1.yaml

	curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install | sh
	#
	#

	export PATH=$PATH:/home/james/.linkerd2/bin
	#
	#
	# istio precheck
	echo test installation of linkerd
	linkerd version
	linkerd check --pre
	#
	#
	#install linkerd on cluster
	linkerd install --crds | kubectl apply -f -
	#
	#install linkerd
	linkerd install | kubectl apply -f -
	#
	echo "Waiting 1 minute for pods to set up..."
	sleep 60
	#check installation
	linkerd check
	#
	#inject linkerd
	#
	kubectl get -n default deploy -o yaml \
	  | linkerd inject - \
	  | kubectl apply -f -
	#
	#
	echo "Waiting again 1 minute for pods to set up..."
	sleep 60

	kubectl delete -f ./microservices-demo/release/currencyservices/currency-cpu-1.yaml

}

uninstall_linkerd(){

	echo uninstalling linkerd

	linkerd uninstall | kubectl delete -f -

	linkerd viz uninstall | kubectl delete -f -

	# To remove Linkerd Jaeger if it exists
	linkerd jaeger uninstall | kubectl delete -f -
}

run_tests_cpu() {
		for repeat in 1 2 3 4 5; do

		echo ON LOOP CPU NO SM $repeat


		echo installing deployments...
		kubectl apply -f ./microservices-demo/release/currencyservices/currency-cpu-$repeat.yaml



		echo waiting for deployments to complete........

		kubectl rollout status deployment adservice -n default --timeout=120s
		kubectl wait deployment adservice --for condition=Available=True --timeout=120s



		while [[ -z $(kubectl get service adservice-external -o jsonpath="{.status.loadBalancer.ingress}" 2>/dev/null) ]]; do
		  echo "still waiting for adservice-external  to get ingress"
		  sleep 5
		done

		echo wait 30 seconds....
		sleep 30

		echo "adservice-external now has ingress"


		IP_ADDR=$(kubectl get svc adservice-external --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}" | awk '{print $1}')

		echo IP ADDRESS IS: $IP_ADDR



		echo LOAD TESTING STARTING..

		echo "Test NO SM CPU $repeat Start: $(date)" >> start-end.txt

		 ./ghz/cmd/ghz/ghz --async --connections 5 -c 5 -n 1000000 -O html -o ./adservice-cpu-nosm-$repeat.html --load-schedule=step --load-start=1 --load-step=2 --load-step-duration=1s --insecure --proto demo.proto --call hipstershop.AdService.GetAds  $IP_ADDR:9555

		echo "Test NO SM CPU $repeat End: $(date)" >> start-end.txt

		echo LOAD TESTING ENDING...

		echo DELETING DEPLOYMENT...

		kubectl delete -f ./microservices-demo/release/adservice-cpu-$repeat.yaml



		NUM_NODES=$(kubectl get nodes -o json|jq -r '.items[]|select(.status.conditions[].type=="Ready")|select(.spec.taints|not).metadata.name' | wc -l)

		echo NUM NODES BEFORE WAIT: $NUM_NODES

		gcloud container clusters resize testing-cluster --node-pool adservice  --num-nodes 1 <<-EOF
y
EOF

		until test $NUM_NODES -eq 1
		do
		  sleep 30
		  NUM_NODES=$(kubectl get nodes -o json|jq -r '.items[]|select(.status.conditions[].type=="Ready")|select(.spec.taints|not).metadata.name' | wc -l)

		  echo NUM NODES AFTER WAIT: $NUM_NODES
		done

		done


		echo we are done
}

run_tests_mem() {
		for repeat in 1 2 3 4 5; do

		echo ON LOOP MEM NO SM $repeat

		echo installing deployments...
		kubectl apply -f ./microservices-demo/release/currencyservices/currency-mem-$repeat.yaml


		echo waiting for deployments to complete........

		kubectl rollout status deployment adservice -n default --timeout=120s
		kubectl wait deployment adservice --for condition=Available=True --timeout=120s



		while [[ -z $(kubectl get service adservice-external -o jsonpath="{.status.loadBalancer.ingress}" 2>/dev/null) ]]; do
		  echo "still waiting for adservice-external  to get ingress"
		  sleep 5
		done

		echo wait 30 seconds....
		sleep 30

		echo "adservice-external now has ingress"


		IP_ADDR=$(kubectl get svc adservice-external --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}" | awk '{print $1}')

		echo IP ADDRESS IS: $IP_ADDR



		echo LOAD TESTING STARTING..

		echo "Test NO SM MEM $repeat Start: $(date)" >> start-end.txt

		 ./ghz/cmd/ghz/ghz --async --connections 5 -c 5 -n 1000000 -O html -o ./adservice-mem-nosm-$repeat.html --load-schedule=step --load-start=1 --load-step=2 --load-step-duration=1s --insecure --proto demo.proto --call hipstershop.AdService.GetAds  $IP_ADDR:9555

		echo "Test NO SM MEM $repeat End: $(date)" >> start-end.txt

		echo LOAD TESTING ENDING...

		echo DELETING DEPLOYMENT...

		kubectl delete -f ./microservices-demo/release/adservice-mem-$repeat.yaml



		NUM_NODES=$(kubectl get nodes -o json|jq -r '.items[]|select(.status.conditions[].type=="Ready")|select(.spec.taints|not).metadata.name' | wc -l)

		echo NUM NODES BEFORE WAIT: $NUM_NODES

		gcloud container clusters resize testing-cluster --node-pool adservice  --num-nodes 1 <<-EOF
y
EOF

		until test $NUM_NODES -eq 1
		do
		  sleep 30
		  NUM_NODES=$(kubectl get nodes -o json|jq -r '.items[]|select(.status.conditions[].type=="Ready")|select(.spec.taints|not).metadata.name' | wc -l)

		  echo NUM NODES AFTER WAIT: $NUM_NODES
		done

		done


		echo we are done
}

run_tests_mem_cpu() {
		for repeat in 1 2 3 4 5; do

		echo ON LOOP MEM CPU NO SM $repeat

		kubectl apply -f ./microservices-demo/release/currencyservices/currency-mem-cpu-$repeat.yaml

		echo waiting for deployments to complete........

		kubectl rollout status deployment adservice -n default --timeout=120s
		kubectl wait deployment adservice --for condition=Available=True --timeout=120s


		while [[ -z $(kubectl get service adservice-external -o jsonpath="{.status.loadBalancer.ingress}" 2>/dev/null) ]]; do
		  echo "still waiting for adservice-external  to get ingress"
		  sleep 5
		done

		echo wait 30 seconds....
		sleep 30

		echo "adservice-external now has ingress"

		IP_ADDR=$(kubectl get svc adservice-external --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}" | awk '{print $1}')

		echo IP ADDRESS IS: $IP_ADDR



		echo LOAD TESTING STARTING..

		echo "Test NO SM MEM CPU $repeat Start: $(date)" >> start-end.txt

		 ./ghz/cmd/ghz/ghz --async --connections 5 -c 5 -n 1000000 -O html -o ./adservice-mem-cpu-nosm-$repeat.html --load-schedule=step --load-start=1 --load-step=2 --load-step-duration=1s --insecure --proto demo.proto --call hipstershop.AdService.GetAds  $IP_ADDR:9555

		echo "Test NO SM MEM CPU $repeat End: $(date)" >> start-end.txt

		echo LOAD TESTING ENDING...

		echo DELETING DEPLOYMENT...

		kubectl delete -f ./microservices-demo/release/adservice-mem-cpu-$repeat.yaml



		NUM_NODES=$(kubectl get nodes -o json|jq -r '.items[]|select(.status.conditions[].type=="Ready")|select(.spec.taints|not).metadata.name' | wc -l)

		echo NUM NODES BEFORE WAIT: $NUM_NODES

		gcloud container clusters resize testing-cluster --node-pool adservice  --num-nodes 1 <<-EOF
y
EOF

		until test $NUM_NODES -eq 1
		do
		  sleep 30
		  NUM_NODES=$(kubectl get nodes -o json|jq -r '.items[]|select(.status.conditions[].type=="Ready")|select(.spec.taints|not).metadata.name' | wc -l)

		  echo NUM NODES AFTER WAIT: $NUM_NODES
		done

		done


		echo we are done
}

run_tests_cpu_istio() {
		for repeat in 1 2 3 4 5; do

		echo ON LOOP CPU ISTIO $repeat

		install_istio

		kubectl apply -f ./microservices-demo/release/currencyservices/currency-cpu-istio-$repeat.yaml

		echo waiting for deployments to complete........

		kubectl rollout status deployment adservice -n default --timeout=120s
		kubectl wait deployment adservice --for condition=Available=True --timeout=120s


		while [[ -z $(kubectl get service istio-ingressgateway -n istio-system -o jsonpath="{.status.loadBalancer.ingress}" 2>/dev/null) ]]; do
		  echo "still waiting for istio-ingressgateway  to get ingress"
		  sleep 5
		done

		echo wait 30 seconds....
		sleep 30

		echo "istio-ingressgateway now has ingress"

		IP_ADDR=$(kubectl get svc istio-ingressgateway -n istio-system --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}" | awk '{print $1}')

		echo IP ADDRESS IS: $IP_ADDR



		echo LOAD TESTING STARTING..

		echo "Test ISTIO $repeat Start: $(date)" >> start-end.txt

		 ./ghz/cmd/ghz/ghz --async --connections 5 -c 5 -n 1000000 -O html -o ./adservice-cpu-istio-$repeat.html --load-schedule=step --load-start=1 --load-step=2 --load-step-duration=1s --insecure --proto demo.proto --call hipstershop.AdService.GetAds  $IP_ADDR:15000

		echo "Test ISTIO $repeat End: $(date)" >> start-end.txt

		echo LOAD TESTING ENDING...

		echo DELETING DEPLOYMENT...


		uninstall_istio

		kubectl delete -f ./microservices-demo/release/adservice-cpu-istio-$repeat.yaml



		NUM_NODES=$(kubectl get nodes -o json|jq -r '.items[]|select(.status.conditions[].type=="Ready")|select(.spec.taints|not).metadata.name' | wc -l)

		echo NUM NODES BEFORE WAIT: $NUM_NODES

		gcloud container clusters resize testing-cluster --node-pool adservice  --num-nodes 1 <<-EOF
y
EOF

		until test $NUM_NODES -eq 1
		do
		  sleep 30
		  NUM_NODES=$(kubectl get nodes -o json|jq -r '.items[]|select(.status.conditions[].type=="Ready")|select(.spec.taints|not).metadata.name' | wc -l)

		  echo NUM NODES AFTER WAIT: $NUM_NODES
		done

		done



		echo we are done
}

run_tests_mem_istio() {
		for repeat in 1 2 3 4 5; do

		echo ON LOOP ISTIO MEM $repeat

		install_istio

		kubectl apply -f ./microservices-demo/release/currencyservices/currency-mem-istio-$repeat.yaml


		echo waiting for deployments to complete........

		kubectl rollout status deployment adservice -n default --timeout=120s
		kubectl wait deployment adservice --for condition=Available=True --timeout=120s


		while [[ -z $(kubectl get service istio-ingressgateway -n istio-system -o jsonpath="{.status.loadBalancer.ingress}" 2>/dev/null) ]]; do
		  echo "still waiting for istio-ingressgateway  to get ingress"
		  sleep 5
		done

		echo wait 30 seconds....
		sleep 30

		echo "istio-ingressgateway now has ingress"

		IP_ADDR=$(kubectl get svc istio-ingressgateway -n istio-system --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}" | awk '{print $1}')

		echo IP ADDRESS IS: $IP_ADDR



		echo LOAD TESTING STARTING..

		echo "Test ISTIO $repeat Start: $(date)" >> start-end.txt

		 ./ghz/cmd/ghz/ghz --async --connections 5 -c 5 -n 1000000 -O html -o ./adservice-mem-istio-$repeat.html --load-schedule=step --load-start=1 --load-step=2 --load-step-duration=1s --insecure --proto demo.proto --call hipstershop.AdService.GetAds  $IP_ADDR:15000

		echo "Test ISTIO $repeat End: $(date)" >> start-end.txt

		echo LOAD TESTING ENDING...

		echo DELETING DEPLOYMENT...


		uninstall_istio

		kubectl delete -f ./microservices-demo/release/adservice-mem-istio-$repeat.yaml



		NUM_NODES=$(kubectl get nodes -o json|jq -r '.items[]|select(.status.conditions[].type=="Ready")|select(.spec.taints|not).metadata.name' | wc -l)

		echo NUM NODES BEFORE WAIT: $NUM_NODES



		gcloud container clusters resize testing-cluster --node-pool adservice  --num-nodes 1 <<-EOF
y
EOF

		until test $NUM_NODES -eq 1
		do
		  sleep 30
		  NUM_NODES=$(kubectl get nodes -o json|jq -r '.items[]|select(.status.conditions[].type=="Ready")|select(.spec.taints|not).metadata.name' | wc -l)

		  echo NUM NODES AFTER WAIT: $NUM_NODES
		done

		done


		echo we are done
}

run_tests_mem_cpu_istio() {
		for repeat in 1 2 3 4 5; do

		echo ON LOOP MEM CPU $repeat

		install_istio

		kubectl apply -f ./microservices-demo/release/currencyservices/currency-mem-cpu-istio-$repeat.yaml


		echo waiting for deployments to complete........

		kubectl rollout status deployment adservice -n default --timeout=120s
		kubectl wait deployment adservice --for condition=Available=True --timeout=120s


		while [[ -z $(kubectl get service istio-ingressgateway -n istio-system  -o jsonpath="{.status.loadBalancer.ingress}" 2>/dev/null) ]]; do
		  echo "still waiting for istio-ingressgateway  to get ingress"
		  sleep 5
		done

		echo wait 30 seconds....
		sleep 30

		echo "istio-ingressgateway now has ingress"

		IP_ADDR=$(kubectl get svc istio-ingressgateway -n istio-system --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}" | awk '{print $1}')

		echo IP ADDRESS IS: $IP_ADDR



		echo LOAD TESTING STARTING..

		echo "Test ISTIO $repeat Start: $(date)" >> start-end.txt

		 ./ghz/cmd/ghz/ghz --async --connections 5 -c 5 -n 1000000 -O html -o ./adservice-mem-cpu-istio-$repeat.html --load-schedule=step --load-start=1 --load-step=2 --load-step-duration=1s --insecure --proto demo.proto --call hipstershop.AdService.GetAds  $IP_ADDR:15000

		echo "Test ISTIO $repeat End: $(date)" >> start-end.txt

		echo LOAD TESTING ENDING...

		echo DELETING DEPLOYMENT...

		uninstall_istio

		kubectl delete -f ./microservices-demo/release/currencyservices/currency-mem-cpu-istio-$repeat.yaml


		NUM_NODES=$(kubectl get nodes -o json|jq -r '.items[]|select(.status.conditions[].type=="Ready")|select(.spec.taints|not).metadata.name' | wc -l)

		echo NUM NODES BEFORE WAIT: $NUM_NODES


		gcloud container clusters resize testing-cluster --node-pool adservice  --num-nodes 1 <<-EOF
y
EOF

		until test $NUM_NODES -eq 1
		do
		  sleep 30
		  NUM_NODES=$(kubectl get nodes -o json|jq -r '.items[]|select(.status.conditions[].type=="Ready")|select(.spec.taints|not).metadata.name' | wc -l)

		  echo NUM NODES AFTER WAIT: $NUM_NODES
		done

		done


		echo we are done
}

run_tests_cpu_linkerd() {
		for repeat in 1 2 3 4 5; do

		echo ON LOOP LINKERD CPU $repeat


		echo installing deployments...
		kubectl apply -f ./microservices-demo/release/currencyservices/currency-cpu-$repeat.yaml

		echo waiting for deployments to complete........

		kubectl rollout status deployment adservice -n default --timeout=120s
		kubectl wait deployment adservice --for condition=Available=True --timeout=120s


		while [[ -z $(kubectl get service adservice-external -o jsonpath="{.status.loadBalancer.ingress}" 2>/dev/null) ]]; do
		  echo "still waiting for adservice-external  to get ingress"
		  sleep 5
		done

		echo wait 30 seconds....
		sleep 30

		echo "adservice-external now has ingress"

		echo inject linkerd
		kubectl get deploy -o yaml | linkerd inject - | kubectl apply -f -

		echo wait 30 seconds....
		sleep 30

		IP_ADDR=$(kubectl get svc adservice-external --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}" | awk '{print $1}')

		echo IP ADDRESS IS: $IP_ADDR



		echo LOAD TESTING STARTING..

		echo "Test LINKERD CPU $repeat Start: $(date)" >> start-end.txt

		 ./ghz/cmd/ghz/ghz --async --connections 5 -c 5 -n 1000000 -O html -o ./adservice-linkerd-cpu-$repeat.html --load-schedule=step --load-start=1 --load-step=2 --load-step-duration=1s --insecure --proto demo.proto --call hipstershop.AdService.GetAds  $IP_ADDR:9555

		echo "Test LINKERD CPU $repeat End: $(date)" >> start-end.txt

		echo LOAD TESTING ENDING...

		echo DELETING DEPLOYMENT...

		kubectl delete -f ./microservices-demo/release/adservice-cpu-$repeat.yaml



		NUM_NODES=$(kubectl get nodes -o json|jq -r '.items[]|select(.status.conditions[].type=="Ready")|select(.spec.taints|not).metadata.name' | wc -l)

		echo NUM NODES BEFORE WAIT: $NUM_NODES

		gcloud container clusters resize testing-cluster --node-pool adservice  --num-nodes 1 <<-EOF
y
EOF

		until test $NUM_NODES -eq 1
		do
		  sleep 30
		  NUM_NODES=$(kubectl get nodes -o json|jq -r '.items[]|select(.status.conditions[].type=="Ready")|select(.spec.taints|not).metadata.name' | wc -l)

		  echo NUM NODES AFTER WAIT: $NUM_NODES
		done

		done


		echo we are done
}

run_tests_mem_linkerd() {
		for repeat in 1 2 3 4 5; do

		echo ON LOOP LINKERD MEM $repeat

		echo installing deployments...
		kubectl apply -f ./microservices-demo/release/currencyservices/currency-mem-$repeat.yaml

		echo waiting for deployments to complete........

		kubectl rollout status deployment adservice -n default --timeout=120s
		kubectl wait deployment adservice --for condition=Available=True --timeout=120s


		while [[ -z $(kubectl get service adservice-external -o jsonpath="{.status.loadBalancer.ingress}" 2>/dev/null) ]]; do
		  echo "still waiting for adservice-external  to get ingress"
		  sleep 5
		done

		echo wait 30 seconds....
		sleep 30

		echo "adservice-external now has ingress"
		echo inject linkerd
		kubectl get deploy -o yaml | linkerd inject - | kubectl apply -f -

		echo wait 30 seconds....
		sleep 30

		IP_ADDR=$(kubectl get svc adservice-external --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}" | awk '{print $1}')

		echo IP ADDRESS IS: $IP_ADDR


		echo LOAD TESTING STARTING..

		echo "Test LINKERD MEM $repeat Start: $(date)" >> start-end.txt

		 ./ghz/cmd/ghz/ghz --async --connections 5 -c 5 -n 1000000 -O html -o ./adservice-mem-linkerd-$repeat.html --load-schedule=step --load-start=1 --load-step=2 --load-step-duration=1s --insecure --proto demo.proto --call hipstershop.AdService.GetAds  $IP_ADDR:9555

		echo "Test LINKERD MEM $repeat End: $(date)" >> start-end.txt

		echo LOAD TESTING ENDING...

		echo DELETING DEPLOYMENT...

		kubectl delete -f ./microservices-demo/release/adservice-mem-$repeat.yaml



		NUM_NODES=$(kubectl get nodes -o json|jq -r '.items[]|select(.status.conditions[].type=="Ready")|select(.spec.taints|not).metadata.name' | wc -l)

		echo NUM NODES BEFORE WAIT: $NUM_NODES

		gcloud container clusters resize testing-cluster --node-pool adservice  --num-nodes 1 <<-EOF
y
EOF

		until test $NUM_NODES -eq 1
		do
		  sleep 30
		  NUM_NODES=$(kubectl get nodes -o json|jq -r '.items[]|select(.status.conditions[].type=="Ready")|select(.spec.taints|not).metadata.name' | wc -l)

		  echo NUM NODES AFTER WAIT: $NUM_NODES
		done

		done


		echo we are done
}

run_tests_mem_cpu_linkerd() {
		for repeat in 1 2 3 4 5; do

		echo ON LOOP MEM CPU LINKERD $repeat

		kubectl apply -f ./microservices-demo/release/currencyservices/currency-mem-cpu-$repeat.yaml

		echo waiting for deployments to complete........

		kubectl rollout status deployment adservice -n default --timeout=120s
		kubectl wait deployment adservice --for condition=Available=True --timeout=120s



		while [[ -z $(kubectl get service adservice-external -o jsonpath="{.status.loadBalancer.ingress}" 2>/dev/null) ]]; do
		  echo "still waiting for adservice-external  to get ingress"
		  sleep 5
		done

		echo wait 30 seconds....
		sleep 30

		echo "adservice-external now has ingress"

		echo inject linkerd
		kubectl get deploy -o yaml | linkerd inject - | kubectl apply -f -

		echo wait 30 seconds....
		sleep 30

		IP_ADDR=$(kubectl get svc adservice-external --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}" | awk '{print $1}')

		echo IP ADDRESS IS: $IP_ADDR



		echo LOAD TESTING STARTING..

		echo "Test LINKERD MEM CPU $repeat Start: $(date)" >> start-end.txt

		 ./ghz/cmd/ghz/ghz --async --connections 5 -c 5 -n 1000000 -O html -o ./adservice-mem-cpu-linkerd-$repeat.html --load-schedule=step --load-start=1 --load-step=2 --load-step-duration=1s --insecure --proto demo.proto --call hipstershop.AdService.GetAds  $IP_ADDR:9555

		echo "Test LINKERD MEM CPU $repeat End: $(date)" >> start-end.txt

		echo LOAD TESTING ENDING...

		echo DELETING DEPLOYMENT...

		kubectl delete -f ./microservices-demo/release/adservice-mem-cpu-$repeat.yaml



		NUM_NODES=$(kubectl get nodes -o json|jq -r '.items[]|select(.status.conditions[].type=="Ready")|select(.spec.taints|not).metadata.name' | wc -l)

		echo NUM NODES BEFORE WAIT: $

		gcloud container clusters resize testing-cluster --node-pool adservice  --num-nodes 1 <<-EOF
y
EOF

		until test $NUM_NODES -eq 1
		do
		  sleep 30
		  NUM_NODES=$(kubectl get nodes -o json|jq -r '.items[]|select(.status.conditions[].type=="Ready")|select(.spec.taints|not).metadata.name' | wc -l)

		  echo NUM NODES AFTER WAIT: $NUM_NODES
		done

		done


		echo we are done
}


run_tests_cpu

run_tests_mem

run_tests_mem_cpu

echo INSTALLING LINKERD

install_linkerd

run_tests_cpu_linkerd

run_tests_mem_linkerd

run_tests_mem_cpu_linkerd

uninstall_linkerd

echo STARTING ISTIO TESTS

run_tests_cpu_istio

run_tests_mem_istio

run_tests_mem_cpu_istio
