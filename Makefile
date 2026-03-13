SHELL := C:/Program Files/Git/usr/bin/bash.exe
.PHONY: infra kubeconfig verify-infra destroy platform verify-platform gitops verify-gitops observability verify-observability start stop help

help:
	@echo ""
	@echo "StackLayer"
	@echo ""
	@echo "  Cluster lifecycle"
	@echo "  make start          Power on VMs (workloads resume automatically)"
	@echo "  make stop           Graceful shutdown of all VMs"
	@echo ""
	@echo "  Phase 1 - Infrastructure"
	@echo "  make infra          Provision VMs, bootstrap Kubernetes, copy kubeconfig"
	@echo "  make verify-infra   Smoke test cluster health"
	@echo "  make destroy        Destroy all VMs (irreversible)"
	@echo ""
	@echo "  Phase 2 - Platform"
	@echo "  make platform         Install ingress-nginx, cert-manager, MetalLB, local-path-provisioner"
	@echo "  make verify-platform  Smoke test platform health"
	@echo ""
	@echo "  Phase 3 - GitOps"
	@echo "  make gitops                Install ArgoCD"
	@echo "  make verify-gitops         Smoke test ArgoCD health"
	@echo ""
	@echo "  Phase 4 - Observability"
	@echo "  make observability         Install Prometheus, Grafana, Alertmanager"
	@echo "  make verify-observability  Smoke test observability health"
	@echo ""

start:
	cd phase1-infrastructure && vagrant up

stop:
	cd phase1-infrastructure && vagrant halt

infra:
	cd phase1-infrastructure && vagrant up
	$(SHELL) phase1-infrastructure/scripts/kubeconfig.sh

kubeconfig:
	$(SHELL) phase1-infrastructure/scripts/kubeconfig.sh

verify-infra:
	$(SHELL) phase1-infrastructure/scripts/verify.sh

destroy:
	@echo "WARNING: This will destroy all VMs. Press Ctrl-C to cancel, Enter to continue."
	@read _confirm
	cd phase1-infrastructure && vagrant destroy -f

platform:
	$(SHELL) phase2-platform/scripts/install.sh

verify-platform:
	$(SHELL) phase2-platform/scripts/verify.sh

gitops:
	$(SHELL) phase3-gitops/scripts/install.sh

verify-gitops:
	$(SHELL) phase3-gitops/scripts/verify.sh

observability:
	$(SHELL) phase4-observability/scripts/install.sh

verify-observability:
	$(SHELL) phase4-observability/scripts/verify.sh
