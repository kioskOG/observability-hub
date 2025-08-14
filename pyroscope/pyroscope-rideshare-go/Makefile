DOCKER_IMAGE := simonswine/rideshare-go-push
DOCKER_PLATFORMS := linux/amd64,linux/arm64
GOBIN := $(CURDIR)/bin
IMAGE_TAG := $(shell ./image-tag)

define docker_build
  docker buildx build $(2) --platform $(DOCKER_PLATFORMS) -t $(DOCKER_IMAGE):$(1) .
  docker buildx build $(2) --platform $(DOCKER_PLATFORMS) -t $(DOCKER_IMAGE)-loadgen:$(1) -f Dockerfile.load-generator .
endef

build:
	mkdir -p $(GOBIN)
	GOBIN=$(GOBIN) go install ./cmd/loadgen
	GOBIN=$(GOBIN) go install ./cmd/rideshare

docker-build:
	$(call docker_build,"dev")

release:
	$(call docker_build,$(IMAGE_TAG), "--push")
