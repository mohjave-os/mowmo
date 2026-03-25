IMAGE_NAME := mowmo
REGISTRY := registry.core.mohjave.com
DATE := $(shell date +%Y-%m-%d)

.PHONY: build test push clean

build:
	docker build -t $(IMAGE_NAME):latest .

test: build
	docker run --rm $(IMAGE_NAME):latest /bin/bash /usr/local/share/mowmo/tests/integration/run-tests.sh

push: build
	docker tag $(IMAGE_NAME):latest $(REGISTRY)/$(IMAGE_NAME):latest
	docker tag $(IMAGE_NAME):latest $(REGISTRY)/$(IMAGE_NAME):$(DATE)
	docker push $(REGISTRY)/$(IMAGE_NAME):latest
	docker push $(REGISTRY)/$(IMAGE_NAME):$(DATE)

clean:
	docker rmi $(IMAGE_NAME):latest $(REGISTRY)/$(IMAGE_NAME):latest $(REGISTRY)/$(IMAGE_NAME):$(DATE) 2>/dev/null || true
