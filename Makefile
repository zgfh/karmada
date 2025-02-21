GOOS ?= $(shell go env GOOS)
GOARCH ?= $(shell go env GOARCH)
SOURCES := $(shell find . -type f  -name '*.go')

LDFLAGS='$(shell hack/version.sh)'

# Images management
REGISTRY?="swr.ap-southeast-1.myhuaweicloud.com/karmada"
REGISTRY_USER_NAME?=""
REGISTRY_PASSWORD?=""
REGISTRY_SERVER_ADDRESS?=""
PLATFORMS?="linux/amd64,linux/arm64"

# Set your version by env or using latest tags from git
VERSION?=""
ifeq ($(VERSION), "")
    LATEST_TAG=$(shell git describe --tags)
    ifeq ($(LATEST_TAG),)
        # Forked repo may not sync tags from upstream, so give it a default tag to make CI happy.
        VERSION="unknown"
    else
        VERSION=$(LATEST_TAG)
    endif
endif

all: karmada-aggregated-apiserver karmada-controller-manager karmada-scheduler karmada-descheduler karmadactl kubectl-karmada karmada-webhook karmada-agent karmada-scheduler-estimator karmada-interpreter-webhook-example

karmada-aggregated-apiserver: $(SOURCES)
	CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=$(GOARCH) go build \
		-ldflags $(LDFLAGS) \
		-o karmada-aggregated-apiserver \
		cmd/aggregated-apiserver/main.go

karmada-controller-manager: $(SOURCES)
	CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=$(GOARCH) go build \
		-ldflags $(LDFLAGS) \
		-o karmada-controller-manager \
		cmd/controller-manager/controller-manager.go

karmada-scheduler: $(SOURCES)
	CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=$(GOARCH) go build \
		-ldflags $(LDFLAGS) \
		-o karmada-scheduler \
		cmd/scheduler/main.go

karmada-descheduler: $(SOURCES)
	CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=$(GOARCH) go build \
		-ldflags $(LDFLAGS) \
		-o karmada-descheduler \
		cmd/descheduler/main.go

karmadactl: $(SOURCES)
	CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=$(GOARCH) go build \
		-ldflags $(LDFLAGS) \
		-o karmadactl \
		cmd/karmadactl/karmadactl.go

kubectl-karmada: $(SOURCES)
	CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=$(GOARCH) go build \
		-ldflags $(LDFLAGS) \
		-o kubectl-karmada \
		cmd/kubectl-karmada/kubectl-karmada.go

karmada-webhook: $(SOURCES)
	CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=$(GOARCH) go build \
		-ldflags $(LDFLAGS) \
		-o karmada-webhook \
		cmd/webhook/main.go

karmada-agent: $(SOURCES)
	CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=$(GOARCH) go build \
		-ldflags $(LDFLAGS) \
		-o karmada-agent \
		cmd/agent/main.go

karmada-scheduler-estimator: $(SOURCES)
	CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=$(GOARCH) go build \
		-ldflags $(LDFLAGS) \
		-o karmada-scheduler-estimator \
		cmd/scheduler-estimator/main.go

karmada-interpreter-webhook-example: $(SOURCES)
	CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=$(GOARCH) go build \
		-ldflags $(LDFLAGS) \
		-o karmada-interpreter-webhook-example \
		examples/customresourceinterpreter/webhook/main.go

clean:
	rm -rf karmada-aggregated-apiserver karmada-controller-manager karmada-scheduler karmada-descheduler karmadactl kubectl-karmada karmada-webhook karmada-agent karmada-scheduler-estimator karmada-interpreter-webhook-example

.PHONY: update
update:
	hack/update-all.sh

.PHONY: verify
verify:
	hack/verify-all.sh

.PHONY: test
test:
	go test --race --v ./pkg/...
	go test --race --v ./cmd/...
	go test --race --v ./examples/...

images: image-karmada-aggregated-apiserver image-karmada-controller-manager image-karmada-scheduler image-karmada-descheduler image-karmada-webhook image-karmada-agent image-karmada-scheduler-estimator image-karmada-interpreter-webhook-example

image-karmada-aggregated-apiserver:
	VERSION=$(VERSION) REGISTRY=$(REGISTRY) hack/docker.sh karmada-aggregated-apiserver

image-karmada-controller-manager:
	VERSION=$(VERSION) REGISTRY=$(REGISTRY) hack/docker.sh karmada-controller-manager

image-karmada-scheduler:
	VERSION=$(VERSION) REGISTRY=$(REGISTRY) hack/docker.sh karmada-scheduler

image-karmada-descheduler:
	VERSION=$(VERSION) REGISTRY=$(REGISTRY) hack/docker.sh karmada-descheduler

image-karmada-webhook:
	VERSION=$(VERSION) REGISTRY=$(REGISTRY) hack/docker.sh karmada-webhook

image-karmada-agent:
	VERSION=$(VERSION) REGISTRY=$(REGISTRY) hack/docker.sh karmada-agent

image-karmada-scheduler-estimator:
	VERSION=$(VERSION) REGISTRY=$(REGISTRY) hack/docker.sh karmada-scheduler-estimator

image-karmada-interpreter-webhook-example:
	VERSION=$(VERSION) REGISTRY=$(REGISTRY) hack/docker.sh karmada-interpreter-webhook-example

upload-images: images
	@echo "push images to $(REGISTRY)"
ifneq ($(REGISTRY_USER_NAME), "")
	docker login -u ${REGISTRY_USER_NAME} -p ${REGISTRY_PASSWORD} ${REGISTRY_SERVER_ADDRESS}
endif
	docker push ${REGISTRY}/karmada-controller-manager:${VERSION}
	docker push ${REGISTRY}/karmada-scheduler:${VERSION}
	docker push ${REGISTRY}/karmada-descheduler:${VERSION}
	docker push ${REGISTRY}/karmada-webhook:${VERSION}
	docker push ${REGISTRY}/karmada-agent:${VERSION}
	docker push ${REGISTRY}/karmada-scheduler-estimator:${VERSION}
	docker push ${REGISTRY}/karmada-interpreter-webhook-example:${VERSION}
	docker push ${REGISTRY}/karmada-aggregated-apiserver:${VERSION}

# Build and push multi-platform image to DockerHub
mp-image-karmada-controller-manager:
	docker buildx build --push --platform=${PLATFORMS} --tag=karmada/karmada-controller-manager:${VERSION} --file=cluster/images/karmada-controller-manager/Dockerfile .

# Build and push multi-platform image to DockerHub
mp-image-karmada-scheduler:
	docker buildx build --push --platform=${PLATFORMS} --tag=karmada/karmada-scheduler:${VERSION} --file=cluster/images/karmada-scheduler/Dockerfile .

# Build and push multi-platform image to DockerHub
mp-image-karmada-descheduler:
	docker buildx build --push --platform=${PLATFORMS} --tag=karmada/karmada-descheduler:${VERSION} --file=cluster/images/karmada-descheduler/Dockerfile .

# Build and push multi-platform image to DockerHub
mp-image-karmada-webhook:
	docker buildx build --push --platform=${PLATFORMS} --tag=karmada/karmada-webhook:${VERSION} --file=cluster/images/karmada-webhook/Dockerfile .

# Build and push multi-platform image to DockerHub
mp-image-karmada-agent:
	docker buildx build --push --platform=${PLATFORMS} --tag=karmada/karmada-agent:${VERSION} --file=cluster/images/karmada-agent/Dockerfile .

# Build and push multi-platform image to DockerHub
mp-image-karmada-scheduler-estimator:
	docker buildx build --push --platform=${PLATFORMS} --tag=karmada/karmada-scheduler-estimator:${VERSION} --file=cluster/images/karmada-scheduler-estimator/Dockerfile .

# Build and push multi-platform image to DockerHub
mp-image-karmada-interpreter-webhook-example:
	docker buildx build --push --platform=${PLATFORMS} --tag=karmada/karmada-interpreter-webhook-example:${VERSION} --file=cluster/images/karmada-interpreter-webhook-example/Dockerfile .

# Build and push multi-platform image to DockerHub
mp-image-karmada-aggregated-apiserver:
	docker buildx build --push --platform=${PLATFORMS} --tag=karmada/karmada-aggregated-apiserver:${VERSION} --file=cluster/images/karmada-aggregated-apiserver/Dockerfile .

# Build and push multi-platform images to DockerHub.
multi-platform-images: mp-image-karmada-controller-manager \
 mp-image-karmada-scheduler \
 mp-image-karmada-descheduler \
 mp-image-karmada-webhook \
 mp-image-karmada-agent \
 mp-image-karmada-scheduler-estimator \
 mp-image-karmada-interpreter-webhook-example \
 mp-image-karmada-aggregated-apiserver
