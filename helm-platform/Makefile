CHART      ?= charts/payments-api
REGISTRY   ?= registry.example.com/platform/charts
CHART_VER  := $(shell yq -r .version $(CHART)/Chart.yaml)
CHART_NAME := $(shell yq -r .name $(CHART)/Chart.yaml)

.PHONY: deps lint template schema policy unit package push diff-prev
deps:
	helm dependency update $(CHART)          # writes/refreshes Chart.lock

lint: deps
	helm lint $(CHART) --strict -f $(CHART)/values.yaml
	helm lint $(CHART) --strict -f $(CHART)/values.yaml -f $(CHART)/values-prod.yaml

template:
	helm template rel $(CHART) -f $(CHART)/values-prod.yaml --api-versions autoscaling/v2 > /tmp/prod.yaml

schema: template
	kubeconform -strict -summary -schema-location default \
	  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' /tmp/prod.yaml

policy: template
	kyverno apply policies/ --resource /tmp/prod.yaml
	conftest test /tmp/prod.yaml -p policies/rego

unit:
	helm unittest $(CHART)

package: lint unit schema policy
	helm package $(CHART) -d dist/

# Immutable publish: fails if the version already exists in the registry.
push: package
	@if helm show chart oci://$(REGISTRY)/$(CHART_NAME) --version $(CHART_VER) >/dev/null 2>&1; then \
	  echo "ERROR: $(CHART_NAME) $(CHART_VER) already published - bump Chart.yaml"; exit 1; fi
	helm push dist/$(CHART_NAME)-$(CHART_VER).tgz oci://$(REGISTRY)
	cosign sign --yes $(REGISTRY)/$(CHART_NAME):$(CHART_VER)

# What actually changes in the cluster between the published chart and this branch?
diff-prev:
	helm diff upgrade rel oci://$(REGISTRY)/$(CHART_NAME) --version $(CHART_VER) \
	  -f $(CHART)/values-prod.yaml --allow-unreleased
