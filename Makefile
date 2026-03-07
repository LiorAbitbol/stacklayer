SHELL := C:/Program Files/Git/usr/bin/bash.exe
.PHONY: up kubeconfig verify destroy platform verify-platform gitops verify-gitops help

help:
	@echo ""
	@echo "StackLayer"
	@echo ""
	@echo "  Phase 1 — Infrastructure"
	@echo "  make up          Provision VMs and bootstrap Kubernetes cluster"
	@echo "  make kubeconfig  Copy kubeconfig from master to ~/.kube/config"
	@echo "  make verify      Smoke test cluster health"
	@echo "  make destroy     Destroy all VMs (irreversible)"
	@echo ""
	@echo "  Phase 2 — Platform"
	@echo "  make platform         Install ingress-nginx, cert-manager, MetalLB, local-path-provisioner"
	@echo "  make verify-platform  Smoke test platform health"
	@echo ""
	@echo "  Phase 3 — GitOps"
	@echo "  make gitops           Install ArgoCD"
	@echo "  make verify-gitops    Smoke test ArgoCD health"
	@echo ""

up:
	cd phase1-infrastructure && vagrant up

kubeconfig:
	$(SHELL) phase1-infrastructure/scripts/kubeconfig.sh

verify:
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
