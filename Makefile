SHELL := /bin/bash
TF_DIR := tofu
ANSIBLE_DIR := ansible
HELM_CHART := helm/openmoodle
HELM_NS ?= moodle-prod
HELM_RELEASE ?= openmoodle-prod

.PHONY: help infra k8s deploy staging deploy-prod clean plan apply destroy

help:
	@echo "OpenMoodleScale Deployment"
	@echo ""
	@echo "Targets:"
	@echo "  make plan          - Run OpenTofu plan"
	@echo "  make apply         - Apply OpenTofu infrastructure"
	@echo "  make k8s           - Bootstrap Kubernetes with Ansible"
	@echo "  make deploy-staging - Deploy to staging"
	@echo "  make deploy-prod   - Deploy to production"
	@echo "  make destroy       - Destroy infrastructure"
	@echo "  make clean         - Remove rendered files and .terraform"

plan:
	cd $(TF_DIR) && tofu plan

apply:
	cd $(TF_DIR) && tofu apply -auto-approve

k8s: $(TF_DIR)/node_ips.txt
	@echo "Bootstrapping Kubernetes cluster..."
	@set -e; cd $(TF_DIR) && \
	node0=$$(jq -r '.[0]' node_ips.txt) && \
	node1=$$(jq -r '.[1]' node_ips.txt) && \
	node2=$$(jq -r '.[2]' node_ips.txt) && \
	if [ -z "$$node0" ] || [ -z "$$node1" ] || [ -z "$$node2" ]; then \
		echo "Error: Could not read 3 node IPs from Terraform output"; \
		exit 1; \
	fi && \
	printf 'all:\n  children:\n    k8s_master:\n      hosts:\n        node-0:\n          ansible_host: %s\n      vars:\n        ansible_user: ubuntu\n    k8s_worker:\n      hosts:\n        node-1:\n          ansible_host: %s\n        node-2:\n          ansible_host: %s\n      vars:\n        ansible_user: ubuntu\n' "$$node0" "$$node1" "$$node2" > $(ANSIBLE_DIR)/inventory/hosts.yml
	ansible-playbook -i $(ANSIBLE_DIR)/inventory/hosts.yml $(ANSIBLE_DIR)/site.yml

deploy-staging: check-registry
	@echo "Deploying staging..."
	helm upgrade --install $(HELM_RELEASE)-staging $(HELM_CHART) \
		--namespace $(HELM_NS)-staging --create-namespace \
		-f $(HELM_CHART)/values.yaml \
		-f $(HELM_CHART)/values-staging.yaml \
		--wait --atomic --timeout 15m

deploy-prod: check-registry
	@echo "Deploying production..."
	helm upgrade --install $(HELM_RELEASE) $(HELM_CHART) \
		--namespace $(HELM_NS) --create-namespace \
		-f $(HELM_CHART)/values.yaml \
		-f $(HELM_CHART)/values-prod.yaml \
		--wait --atomic --timeout 20m

lint:
	helm lint $(HELM_CHART) -f $(HELM_CHART)/values.yaml -f $(HELM_CHART)/values-staging.yaml
	helm template test $(HELM_CHART) -f $(HELM_CHART)/values.yaml -f $(HELM_CHART)/values-staging.yaml > /dev/null

check-registry:
	@if [ -z "$$(docker images registry.openmoodle.local/openmoodle/moodle-app --format '{{.Tag}}' | head -1)" ]; then \
		echo "Error: Images not found in registry.openmoodle.local. Build and push first."; \
		exit 1; \
	fi

destroy:
	cd $(TF_DIR) && tofu destroy -auto-approve

clean:
	rm -f $(TF_DIR)/node_ips.txt
	rm -rf $(TF_DIR)/.terraform
	rm -rf $(TF_DIR)/.terraform.lock.hcl
	rm -f $(ANSIBLE_DIR)/inventory/hosts.yml

$(TF_DIR)/node_ips.txt:
	cd $(TF_DIR) && tofu output -json node_ips | jq -r '.[]' > node_ips.txt
